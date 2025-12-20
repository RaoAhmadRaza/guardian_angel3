import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'models/audit_log_entry.dart';
import 'telemetry_service.dart';
import '../persistence/wrappers/box_accessor.dart';

// Shared instance management (avoids circular imports)
AuditLogService? _sharedAuditLogInstance;

/// Sets the shared AuditLogService instance.
void setSharedAuditLogInstance(AuditLogService instance) {
  _sharedAuditLogInstance = instance;
}

/// Gets or creates the shared AuditLogService instance.
AuditLogService getSharedAuditLogInstance() {
  return _sharedAuditLogInstance ??= AuditLogService(telemetry: TelemetryService.I);
}

/// Central audit log service with rotation, purging, and redaction
class AuditLogService {
  // ═══════════════════════════════════════════════════════════════════════
  // SINGLETON (DEPRECATED - Use ServiceInstances or Riverpod provider)
  // ═══════════════════════════════════════════════════════════════════════
  /// Legacy singleton accessor - routes to shared instance.
  @Deprecated('Use auditLogServiceProvider or ServiceInstances.auditLog instead')
  static AuditLogService get I => getSharedAuditLogInstance();
  
  final TelemetryService _telemetry;
  RetentionPolicy _retentionPolicy;
  String _archiveDirectory;
  
  late Box<AuditLogEntry> _activeLogBox;
  late Box<AuditLogArchive> _archiveMetadataBox;
  
  Timer? _rotationTimer;
  Timer? _purgeTimer;
  
  static const String _activeLogBoxName = 'audit_log_active';
  static const String _archiveMetadataBoxName = 'audit_log_archives';
  
  final _uuid = const Uuid();
  bool _initialized = false;
  
  /// Buffered entries logged before init() was called.
  /// These are flushed after initialization.
  final List<_BufferedLogEntry> _preInitBuffer = [];
  
  /// Maximum number of entries to buffer before init.
  static const int _maxBufferSize = 100;

  // ═══════════════════════════════════════════════════════════════════════
  // PROPER DI CONSTRUCTOR (Use this via Riverpod)
  // ═══════════════════════════════════════════════════════════════════════
  /// Creates a new AuditLogService instance for dependency injection.
  AuditLogService({
    required TelemetryService telemetry,
    RetentionPolicy retentionPolicy = RetentionPolicy.standard,
    String archiveDirectory = '',
  })  : _telemetry = telemetry,
        _retentionPolicy = retentionPolicy,
        _archiveDirectory = archiveDirectory;

  /// Whether the service has been initialized.
  bool get isInitialized => _initialized;
  
  /// Number of buffered entries waiting to be flushed.
  int get bufferedCount => _preInitBuffer.length;

  /// Initialize the audit log service
  Future<void> init({
    RetentionPolicy? retentionPolicy,
    String? archiveDirectory,
  }) async {
    if (retentionPolicy != null) {
      _retentionPolicy = retentionPolicy;
    }
    if (archiveDirectory != null) {
      _archiveDirectory = archiveDirectory;
    }
    
    if (_initialized) return;

    // Register Hive adapters if not already registered
    if (!Hive.isAdapterRegistered(13)) {
      Hive.registerAdapter(AuditLogEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(14)) {
      Hive.registerAdapter(AuditLogArchiveAdapter());
    }

    // Open Hive boxes
    _activeLogBox = await Hive.openBox<AuditLogEntry>(_activeLogBoxName);
    _archiveMetadataBox = await Hive.openBox<AuditLogArchive>(_archiveMetadataBoxName);

    // Ensure archive directory exists
    if (_archiveDirectory.isNotEmpty) {
      final dir = Directory(_archiveDirectory);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    }

    // Start automatic rotation and purge timers
    _startRotationTimer();
    _startPurgeTimer();

    _initialized = true;
    _telemetry.increment('audit_log.service_initialized');
    
    // Flush any buffered entries
    await _flushBuffer();
    
    print('[AuditLog] Service initialized with ${_retentionPolicy.activePeriod.inDays}d active, ${_retentionPolicy.archivePeriod.inDays}d archive retention');
  }
  
  /// Buffer an entry when service is not yet initialized.
  void _bufferEntry({
    required String userId,
    required String action,
    String? entityType,
    String? entityId,
    Map<String, dynamic>? metadata,
    String severity = 'info',
    String? ipAddress,
    String? deviceInfo,
  }) {
    // Don't buffer if already at capacity
    if (_preInitBuffer.length >= _maxBufferSize) {
      _telemetry.increment('audit_log.buffer_overflow');
      return;
    }
    
    _preInitBuffer.add(_BufferedLogEntry(
      userId: userId,
      action: action,
      entityType: entityType,
      entityId: entityId,
      metadata: metadata,
      severity: severity,
      ipAddress: ipAddress,
      deviceInfo: deviceInfo,
      bufferedAt: DateTime.now(),
    ));
    
    _telemetry.increment('audit_log.entry_buffered');
  }
  
  /// Flush all buffered entries to the actual log.
  Future<void> _flushBuffer() async {
    if (_preInitBuffer.isEmpty) return;
    
    final count = _preInitBuffer.length;
    
    for (final buffered in _preInitBuffer) {
      try {
        final entry = AuditLogEntry(
          entryId: _uuid.v4(),
          timestamp: buffered.bufferedAt,
          userId: buffered.userId,
          action: buffered.action,
          entityType: buffered.entityType,
          entityId: buffered.entityId,
          metadata: {
            ...?buffered.metadata,
            '_buffered': true,
            '_buffer_delay_ms': DateTime.now().difference(buffered.bufferedAt).inMilliseconds,
          },
          severity: buffered.severity,
          ipAddress: buffered.ipAddress,
          deviceInfo: buffered.deviceInfo,
        );

        await _activeLogBox.put(entry.entryId, entry);
      } catch (e) {
        _telemetry.increment('audit_log.flush_entry_failed');
      }
    }
    
    _preInitBuffer.clear();
    
    _telemetry.gauge('audit_log.buffer_flushed_count', count);
    print('[AuditLog] Flushed $count buffered entries');
  }

  /// Log an audit entry
  Future<void> log({
    required String userId,
    required String action,
    String? entityType,
    String? entityId,
    Map<String, dynamic>? metadata,
    String severity = 'info',
    String? ipAddress,
    String? deviceInfo,
  }) async {
    // Buffer entries if not initialized yet
    if (!_initialized) {
      _bufferEntry(
        userId: userId,
        action: action,
        entityType: entityType,
        entityId: entityId,
        metadata: metadata,
        severity: severity,
        ipAddress: ipAddress,
        deviceInfo: deviceInfo,
      );
      return;
    }

    final entry = AuditLogEntry(
      entryId: _uuid.v4(),
      timestamp: DateTime.now(),
      userId: userId,
      action: action,
      entityType: entityType,
      entityId: entityId,
      metadata: metadata ?? {},
      severity: severity,
      ipAddress: ipAddress,
      deviceInfo: deviceInfo,
    );

    await _activeLogBox.put(entry.entryId, entry);
    
    _telemetry.increment('audit_log.entry_logged');
    _telemetry.increment('audit_log.action.$action');
    _telemetry.increment('audit_log.severity.$severity');
    
    print('[AuditLog] Logged: $action by $userId (severity: $severity)');

    // Check if rotation is needed
    await _checkAndRotateIfNeeded();
  }

  /// Check if rotation is needed based on policy
  Future<void> _checkAndRotateIfNeeded() async {
    final entryCount = _activeLogBox.length;
    
    if (entryCount >= _retentionPolicy.maxActiveEntries) {
      print('[AuditLog] Rotation triggered by entry count: $entryCount >= ${_retentionPolicy.maxActiveEntries}');
      await rotateNow();
      return;
    }

    // Check if oldest entry exceeds active period
    if (entryCount > 0) {
      final entries = _activeLogBox.values.toList();
      entries.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final oldest = entries.first;
      final age = DateTime.now().difference(oldest.timestamp);
      
      if (age > _retentionPolicy.activePeriod) {
        print('[AuditLog] Rotation triggered by age: ${age.inDays}d > ${_retentionPolicy.activePeriod.inDays}d');
        await rotateNow();
      }
    }
  }

  /// Rotate active logs to archive
  Future<void> rotateNow() async {
    if (!_initialized) return;
    if (_activeLogBox.isEmpty) {
      print('[AuditLog] No entries to rotate');
      return;
    }

    final startTime = DateTime.now();
    print('[AuditLog] Starting log rotation...');

    try {
      // Get all active entries
      final entries = _activeLogBox.values.toList();
      entries.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      final startDate = entries.first.timestamp;
      final endDate = entries.last.timestamp;
      
      // Create archive ID
      final archiveId = 'archive_${startDate.millisecondsSinceEpoch}_${_uuid.v4().substring(0, 8)}';
      
      // Prepare archive file path
      final archivePath = _getArchiveFilePath(archiveId);
      
      // Write entries to archive file with encryption
      final archiveFile = File(archivePath);
      final jsonData = entries.map((e) => e.toJson()).toList();
      final jsonString = jsonEncode(jsonData);
      
      // Encrypt the data (simple XOR encryption - use stronger encryption in production)
      final encryptedData = _encryptData(jsonString);
      await archiveFile.writeAsBytes(encryptedData);
      
      // Calculate checksum
      final checksum = sha256.convert(encryptedData).toString();
      
      // Create archive metadata
      final archive = AuditLogArchive(
        archiveId: archiveId,
        createdAt: DateTime.now(),
        startDate: startDate,
        endDate: endDate,
        entryCount: entries.length,
        filePath: archivePath,
        fileSizeBytes: encryptedData.length,
        isEncrypted: true,
        checksum: checksum,
      );
      
      // Save archive metadata
      await _archiveMetadataBox.put(archive.archiveId, archive);
      
      // Clear active log
      await _activeLogBox.clear();
      
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      
      _telemetry.increment('audit_log.rotation_completed');
      _telemetry.gauge('audit_log.rotation_duration_ms', duration);
      _telemetry.gauge('audit_log.archive_entry_count', entries.length);
      _telemetry.gauge('audit_log.archive_size_bytes', encryptedData.length);
      
      print('[AuditLog] Rotation completed in ${duration}ms: ${entries.length} entries → ${archiveId}');
    } catch (e) {
      _telemetry.increment('audit_log.rotation_failed');
      print('[AuditLog] Rotation failed: $e');
      rethrow;
    }
  }

  /// Get archive file path
  String _getArchiveFilePath(String archiveId) {
    if (_archiveDirectory.isEmpty) {
      // Use Hive directory
      final hiveDir = BoxAccess.I.boxUntyped(_activeLogBoxName).path;
      final baseDir = path.dirname(hiveDir!);
      return path.join(baseDir, 'audit_archives', '$archiveId.alog');
    }
    return path.join(_archiveDirectory, '$archiveId.alog');
  }

  /// Simple encryption (use proper encryption in production)
  List<int> _encryptData(String data) {
    // In production, use encrypt package with proper key management
    final bytes = utf8.encode(data);
    final key = 0xA5; // Simple XOR key - replace with proper encryption
    return bytes.map((b) => b ^ key).toList();
  }

  /// Simple decryption
  String _decryptData(List<int> encryptedData) {
    final key = 0xA5;
    final decrypted = encryptedData.map((b) => b ^ key).toList();
    return utf8.decode(decrypted);
  }

  /// Start automatic rotation timer
  void _startRotationTimer() {
    // Check daily for rotation needs
    _rotationTimer = Timer.periodic(const Duration(hours: 24), (_) async {
      print('[AuditLog] Daily rotation check...');
      await _checkAndRotateIfNeeded();
    });
  }

  /// Start automatic purge timer
  void _startPurgeTimer() {
    // Check daily for expired archives
    _purgeTimer = Timer.periodic(const Duration(hours: 24), (_) async {
      print('[AuditLog] Daily purge check...');
      await purgeExpiredArchives();
    });
  }

  /// Purge expired archives based on retention policy
  Future<int> purgeExpiredArchives() async {
    if (!_initialized) return 0;

    final startTime = DateTime.now();
    int purgedCount = 0;

    try {
      final archives = _archiveMetadataBox.values.toList();
      
      for (final archive in archives) {
        if (archive.isExpired(_retentionPolicy.archivePeriod)) {
          // Delete archive file
          final file = File(archive.filePath);
          if (await file.exists()) {
            await file.delete();
            print('[AuditLog] Deleted expired archive file: ${archive.archiveId}');
          }
          
          // Remove metadata
          await _archiveMetadataBox.delete(archive.archiveId);
          purgedCount++;
          
          _telemetry.increment('audit_log.archive_purged');
        }
      }

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      
      if (purgedCount > 0) {
        _telemetry.gauge('audit_log.purge_duration_ms', duration);
        _telemetry.gauge('audit_log.purged_count', purgedCount);
        print('[AuditLog] Purged $purgedCount expired archives in ${duration}ms');
      }

      return purgedCount;
    } catch (e) {
      _telemetry.increment('audit_log.purge_failed');
      print('[AuditLog] Purge failed: $e');
      rethrow;
    }
  }

  /// Export logs with redaction
  Future<List<AuditLogEntry>> exportLogs({
    DateTime? startDate,
    DateTime? endDate,
    RedactionConfig redactionConfig = RedactionConfig.standard,
    bool includeArchives = true,
  }) async {
    if (!_initialized) {
      throw StateError('AuditLogService not initialized');
    }

    final allEntries = <AuditLogEntry>[];

    // Get active log entries
    final activeEntries = _activeLogBox.values.toList();
    allEntries.addAll(activeEntries);

    // Get archived entries if requested
    if (includeArchives) {
      final archives = _archiveMetadataBox.values.toList();
      
      for (final archive in archives) {
        // Skip archives outside date range
        if (startDate != null && archive.endDate.isBefore(startDate)) continue;
        if (endDate != null && archive.startDate.isAfter(endDate)) continue;
        
        // Load and decrypt archive
        final entries = await _loadArchive(archive);
        allEntries.addAll(entries);
      }
    }

    // Filter by date range
    var filtered = allEntries;
    if (startDate != null) {
      filtered = filtered.where((e) => e.timestamp.isAfter(startDate) || 
                                       e.timestamp.isAtSameMomentAs(startDate)).toList();
    }
    if (endDate != null) {
      filtered = filtered.where((e) => e.timestamp.isBefore(endDate) || 
                                       e.timestamp.isAtSameMomentAs(endDate)).toList();
    }

    // Apply redaction
    final redacted = filtered.map((entry) => entry.redact(
      maskUserId: redactionConfig.maskUserId,
      partialTimestamp: redactionConfig.partialTimestamp,
      maskIpAddress: redactionConfig.maskIpAddress,
      maskMetadata: redactionConfig.maskMetadata,
    )).toList();

    // Sort by timestamp
    redacted.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    _telemetry.increment('audit_log.export_completed');
    _telemetry.gauge('audit_log.export_entry_count', redacted.length);
    
    print('[AuditLog] Exported ${redacted.length} entries with redaction: ${redactionConfig.maskUserId ? "masked" : "full"}');

    return redacted;
  }

  /// Load entries from an archive
  Future<List<AuditLogEntry>> _loadArchive(AuditLogArchive archive) async {
    try {
      final file = File(archive.filePath);
      if (!await file.exists()) {
        print('[AuditLog] Warning: Archive file not found: ${archive.filePath}');
        return [];
      }

      // Read and decrypt
      final encryptedData = await file.readAsBytes();
      
      // Verify checksum
      final checksum = sha256.convert(encryptedData).toString();
      if (checksum != archive.checksum) {
        _telemetry.increment('audit_log.archive_checksum_mismatch');
        print('[AuditLog] Warning: Checksum mismatch for ${archive.archiveId}');
        // Continue anyway, but log the issue
      }

      final jsonString = _decryptData(encryptedData);
      final jsonData = jsonDecode(jsonString) as List;
      
      final entries = jsonData
          .map((json) => AuditLogEntry.fromJson(json as Map<String, dynamic>))
          .toList();

      return entries;
    } catch (e) {
      _telemetry.increment('audit_log.archive_load_failed');
      print('[AuditLog] Failed to load archive ${archive.archiveId}: $e');
      return [];
    }
  }

  /// Export logs to JSON file
  Future<String> exportToFile({
    required String filePath,
    DateTime? startDate,
    DateTime? endDate,
    RedactionConfig redactionConfig = RedactionConfig.standard,
    bool includeArchives = true,
  }) async {
    final entries = await exportLogs(
      startDate: startDate,
      endDate: endDate,
      redactionConfig: redactionConfig,
      includeArchives: includeArchives,
    );

    final jsonData = {
      'exportDate': DateTime.now().toIso8601String(),
      'redactionApplied': redactionConfig != RedactionConfig.none,
      'entryCount': entries.length,
      'entries': entries.map((e) => e.toJson()).toList(),
    };

    final file = File(filePath);
    await file.writeAsString(jsonEncode(jsonData));

    _telemetry.increment('audit_log.export_to_file');
    print('[AuditLog] Exported ${entries.length} entries to $filePath');

    return filePath;
  }

  /// Get statistics about audit logs
  Future<AuditLogStats> getStats() async {
    if (!_initialized) {
      throw StateError('AuditLogService not initialized');
    }

    final activeCount = _activeLogBox.length;
    final archiveCount = _archiveMetadataBox.length;
    
    int totalArchivedEntries = 0;
    int totalArchiveSizeBytes = 0;
    
    for (final archive in _archiveMetadataBox.values) {
      totalArchivedEntries += archive.entryCount;
      totalArchiveSizeBytes += archive.fileSizeBytes;
    }

    // Get oldest and newest active entries
    DateTime? oldestActive;
    DateTime? newestActive;
    
    if (activeCount > 0) {
      final entries = _activeLogBox.values.toList();
      entries.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      oldestActive = entries.first.timestamp;
      newestActive = entries.last.timestamp;
    }

    return AuditLogStats(
      activeEntryCount: activeCount,
      archiveCount: archiveCount,
      totalArchivedEntries: totalArchivedEntries,
      totalArchiveSizeBytes: totalArchiveSizeBytes,
      oldestActiveEntry: oldestActive,
      newestActiveEntry: newestActive,
      retentionPolicy: _retentionPolicy,
    );
  }

  /// Dispose of resources
  void dispose() {
    _rotationTimer?.cancel();
    _purgeTimer?.cancel();
    print('[AuditLog] Service disposed');
  }
}

/// Audit log statistics
class AuditLogStats {
  final int activeEntryCount;
  final int archiveCount;
  final int totalArchivedEntries;
  final int totalArchiveSizeBytes;
  final DateTime? oldestActiveEntry;
  final DateTime? newestActiveEntry;
  final RetentionPolicy retentionPolicy;

  AuditLogStats({
    required this.activeEntryCount,
    required this.archiveCount,
    required this.totalArchivedEntries,
    required this.totalArchiveSizeBytes,
    this.oldestActiveEntry,
    this.newestActiveEntry,
    required this.retentionPolicy,
  });

  int get totalEntries => activeEntryCount + totalArchivedEntries;

  double get totalArchiveSizeMB => totalArchiveSizeBytes / (1024 * 1024);

  @override
  String toString() {
    return '''
AuditLogStats:
  Active: $activeEntryCount entries
  Archives: $archiveCount files ($totalArchivedEntries entries, ${totalArchiveSizeMB.toStringAsFixed(2)}MB)
  Total: $totalEntries entries
  Oldest active: ${oldestActiveEntry?.toIso8601String() ?? 'N/A'}
  Newest active: ${newestActiveEntry?.toIso8601String() ?? 'N/A'}
  Retention: ${retentionPolicy.activePeriod.inDays}d active, ${retentionPolicy.archivePeriod.inDays}d archive
''';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TYPED AUDIT LOGGING EXTENSION
// ═══════════════════════════════════════════════════════════════════════════

/// Extension for typed audit logging using AuditEvent.
///
/// Provides a type-safe way to log audit events with standardized
/// types, severities, and entity types.
extension TypedAuditLogging on AuditLogService {
  /// Log a typed audit event.
  ///
  /// Use this for standardized audit logging with canonical types.
  /// Example:
  /// ```dart
  /// await AuditLogService.I.logEvent(AuditEvent.sosTrigger(
  ///   userId: userId,
  ///   sosId: sosId,
  ///   location: 'Home',
  /// ));
  /// ```
  Future<void> logEvent(dynamic event) async {
    // Import is circular, so we use dynamic and duck typing
    final type = event.type;
    final action = type.action as String;
    final severity = type.severity as String;
    final entityType = type.defaultEntityType as String;
    final userId = event.userId as String;
    final entityId = event.entityId as String?;
    final metadata = event.metadata as Map<String, dynamic>;
    final deviceInfo = event.deviceInfo as String?;
    final ipAddress = event.ipAddress as String?;
    
    await log(
      userId: userId,
      action: action,
      entityType: entityType,
      entityId: entityId,
      metadata: metadata,
      severity: severity,
      ipAddress: ipAddress,
      deviceInfo: deviceInfo,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BUFFERED LOG ENTRY (Internal)
// ═══════════════════════════════════════════════════════════════════════════

/// Internal class to hold buffered log entries before init.
class _BufferedLogEntry {
  final String userId;
  final String action;
  final String? entityType;
  final String? entityId;
  final Map<String, dynamic>? metadata;
  final String severity;
  final String? ipAddress;
  final String? deviceInfo;
  final DateTime bufferedAt;
  
  _BufferedLogEntry({
    required this.userId,
    required this.action,
    this.entityType,
    this.entityId,
    this.metadata,
    this.severity = 'info',
    this.ipAddress,
    this.deviceInfo,
    required this.bufferedAt,
  });
}
