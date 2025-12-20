import 'package:hive/hive.dart';
import '../persistence/box_registry.dart';
import '../persistence/wrappers/box_accessor.dart';
import 'models/audit_log_entry.dart';

/// Service for append-only audit logging with export and tail operations
/// 
/// Provides:
/// - append(): Add audit entries (append-only semantics)
/// - tail(n): Retrieve last N entries for admin UI
/// - exportRedacted(since): Export logs with PII redaction for compliance
/// 
/// All audit entries are stored in an encrypted Hive box for security.
class AuditService {
  final Box<AuditLogEntry> _auditBox;

  AuditService(this._auditBox);

  /// Create service instance with initialized audit box
  static Future<AuditService> create() async {
    final box = BoxAccess.I.box<AuditLogEntry>(BoxRegistry.auditLogsBox);
    return AuditService(box);
  }

  /// Append a new audit entry
  /// 
  /// Uses append-only semantics - entries are never updated or deleted
  /// except through automated archival/rotation policies.
  /// 
  /// Example:
  /// ```dart
  /// await auditService.append(AuditLogEntry(
  ///   entryId: 'audit_${DateTime.now().millisecondsSinceEpoch}',
  ///   timestamp: DateTime.now().toUtc(),
  ///   userId: 'user_001',
  ///   action: 'device_control',
  ///   entityType: 'device',
  ///   entityId: 'dev_001',
  ///   metadata: {'command': 'toggle', 'ipAddress': '192.168.1.100'},
  ///   severity: 'info',
  ///   ipAddress: '192.168.1.100',
  ///   deviceInfo: 'iOS 17.0',
  /// ));
  /// ```
  Future<void> append(AuditLogEntry entry) async {
    await _auditBox.put(entry.entryId, entry);
  }

  /// Retrieve the last N audit entries (most recent first)
  /// 
  /// Useful for admin debug UI to view recent activity.
  /// 
  /// Example:
  /// ```dart
  /// final recentLogs = await auditService.tail(100);
  /// for (final log in recentLogs) {
  ///   print('${log.timestamp}: ${log.userId} - ${log.action}');
  /// }
  /// ```
  Future<List<AuditLogEntry>> tail(int n) async {
    final allEntries = _auditBox.values.toList();
    
    // Sort by timestamp descending (most recent first)
    allEntries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    // Return last N entries
    return allEntries.take(n).toList();
  }

  /// Export audit logs with PII redaction for compliance
  /// 
  /// Filters entries since the specified timestamp and applies redaction:
  /// - Masks user IDs (keeps first 4 chars)
  /// - Masks IP addresses (keeps first octet)
  /// - Redacts sensitive metadata (passwords, tokens, emails)
  /// - Reduces timestamp precision to day-level
  /// 
  /// Example:
  /// ```dart
  /// final weekAgo = DateTime.now().subtract(Duration(days: 7));
  /// final redactedLogs = await auditService.exportRedacted(since: weekAgo);
  /// 
  /// // Export to JSON file for compliance audit
  /// final jsonData = redactedLogs.map((e) => e.toJson()).toList();
  /// await File('audit_export.json').writeAsString(jsonEncode(jsonData));
  /// ```
  Future<List<AuditLogEntry>> exportRedacted({
    required DateTime since,
    bool maskUserId = true,
    bool partialTimestamp = true,
    bool maskIpAddress = true,
    bool maskMetadata = true,
  }) async {
    final entries = _auditBox.values.where((entry) {
      return entry.timestamp.isAfter(since) || entry.timestamp.isAtSameMomentAs(since);
    }).toList();

    // Sort by timestamp ascending (chronological order for export)
    entries.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Apply redaction to each entry
    return entries.map((entry) => entry.redact(
      maskUserId: maskUserId,
      partialTimestamp: partialTimestamp,
      maskIpAddress: maskIpAddress,
      maskMetadata: maskMetadata,
    )).toList();
  }

  /// Get count of audit entries
  int get entryCount => _auditBox.length;

  /// Get the oldest audit entry timestamp (for retention policy checks)
  DateTime? get oldestEntryTimestamp {
    if (_auditBox.isEmpty) return null;
    
    final entries = _auditBox.values.toList();
    entries.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    return entries.first.timestamp;
  }

  /// Get the newest audit entry timestamp
  DateTime? get newestEntryTimestamp {
    if (_auditBox.isEmpty) return null;
    
    final entries = _auditBox.values.toList();
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    return entries.first.timestamp;
  }

  /// Get entries by severity level
  Future<List<AuditLogEntry>> getEntriesBySeverity(String severity) async {
    final entries = _auditBox.values
        .where((entry) => entry.severity == severity)
        .toList();
    
    // Sort by timestamp descending
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    return entries;
  }

  /// Get entries for a specific user
  Future<List<AuditLogEntry>> getEntriesForUser(String userId) async {
    final entries = _auditBox.values
        .where((entry) => entry.userId == userId)
        .toList();
    
    // Sort by timestamp descending
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    return entries;
  }

  /// Get entries for a specific action type
  Future<List<AuditLogEntry>> getEntriesByAction(String action) async {
    final entries = _auditBox.values
        .where((entry) => entry.action == action)
        .toList();
    
    // Sort by timestamp descending
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    return entries;
  }

  /// Archive old entries (for compliance retention policies)
  /// 
  /// Moves entries older than the specified age to archive storage.
  /// Returns the count of archived entries.
  /// 
  /// Note: This is a placeholder for future implementation with AuditLogArchive.
  /// Current implementation only removes old entries from main storage.
  Future<int> archiveOldEntries({required Duration maxAge}) async {
    final cutoff = DateTime.now().toUtc().subtract(maxAge);
    final entriesToArchive = _auditBox.values
        .where((entry) => entry.timestamp.isBefore(cutoff))
        .toList();

    // TODO: Implement archival to compressed storage before deletion
    // For now, we just delete (not recommended for production compliance)
    
    for (final entry in entriesToArchive) {
      await _auditBox.delete(entry.entryId);
    }

    return entriesToArchive.length;
  }

  /// Clear all audit entries (DANGEROUS - use only in tests)
  Future<void> clear() async {
    await _auditBox.clear();
  }
}
