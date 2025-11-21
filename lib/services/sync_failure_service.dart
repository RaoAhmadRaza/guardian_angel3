import 'dart:async';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/sync_failure.dart';
import 'telemetry_service.dart';
import 'audit_log_service.dart';

/// Service for managing sync failures and user notifications
class SyncFailureService {
  static final I = SyncFailureService._();
  SyncFailureService._();

  final _telemetry = TelemetryService.I;
  static const String _boxName = 'sync_failures';
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(minutes: 5);

  late Box<SyncFailure> _box;
  bool _initialized = false;

  final _uuid = const Uuid();
  final _failureStreamController = StreamController<SyncFailure>.broadcast();
  final _resolvedStreamController = StreamController<SyncFailure>.broadcast();

  /// Stream of new sync failures
  Stream<SyncFailure> get onFailure => _failureStreamController.stream;

  /// Stream of resolved failures
  Stream<SyncFailure> get onResolved => _resolvedStreamController.stream;

  /// Initialize the service
  Future<void> init() async {
    if (_initialized) return;

    try {
      _box = await Hive.openBox<SyncFailure>(_boxName);
      _initialized = true;
      _telemetry.increment('sync_failure.service_initialized');
      
      // Clean up old resolved failures (older than 7 days)
      await _cleanupOldFailures();
    } catch (e) {
      _telemetry.increment('sync_failure.init_failed');
      rethrow;
    }
  }

  /// Record a sync failure
  Future<SyncFailure> recordFailure({
    required String entityType,
    required String entityId,
    required String operation,
    required String reason,
    required String errorMessage,
    String? userId,
    Map<String, dynamic>? metadata,
    SyncFailureSeverity severity = SyncFailureSeverity.medium,
    bool requiresUserAction = false,
    String? suggestedAction,
  }) async {
    _ensureInitialized();

    // Check if a failure already exists for this entity/operation
    final existingKey = _getFailureKey(entityType, entityId, operation);
    final existing = _box.get(existingKey);

    final now = DateTime.now();
    final SyncFailure failure;

    if (existing != null) {
      // Update existing failure
      failure = existing.copyWith(
        lastAttemptAt: now,
        retryCount: existing.retryCount + 1,
        errorMessage: errorMessage,
        reason: reason,
        metadata: {...existing.metadata, ...?metadata},
        severity: severity,
        requiresUserAction: requiresUserAction,
        suggestedAction: suggestedAction,
        status: existing.retryCount + 1 >= _maxRetries
            ? SyncFailureStatus.failed
            : SyncFailureStatus.pending,
      );
    } else {
      // Create new failure
      failure = SyncFailure(
        id: _uuid.v4(),
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        reason: reason,
        errorMessage: errorMessage,
        firstFailedAt: now,
        lastAttemptAt: now,
        retryCount: 1,
        status: SyncFailureStatus.pending,
        metadata: metadata ?? {},
        userId: userId,
        severity: severity,
        requiresUserAction: requiresUserAction,
        suggestedAction: suggestedAction,
      );
    }

    // Save to storage
    await _box.put(existingKey, failure);

    // Track telemetry
    _telemetry.increment('sync_failure.recorded');
    _telemetry.increment('sync_failure.severity.${severity.name}');
    _telemetry.increment('sync_failure.entity_type.${entityType}');

    // Notify listeners
    _failureStreamController.add(failure);

    // Log to audit system
    try {
      await AuditLogService.I.log(
        userId: userId ?? 'system',
        action: 'sync_failure_recorded',
        entityType: entityType,
        entityId: entityId,
        severity: _mapSeverity(severity),
        metadata: {
          'operation': operation,
          'reason': reason,
          'retryCount': failure.retryCount,
          'requiresUserAction': requiresUserAction,
        },
      );
    } catch (e) {
      // Don't fail if audit logging fails
      _telemetry.increment('sync_failure.audit_log_failed');
    }

    return failure;
  }

  /// Get all pending failures
  List<SyncFailure> getPendingFailures() {
    _ensureInitialized();
    return _box.values
        .where((f) =>
            f.status == SyncFailureStatus.pending ||
            f.status == SyncFailureStatus.retrying)
        .toList()
      ..sort((a, b) => b.lastAttemptAt.compareTo(a.lastAttemptAt));
  }

  /// Get all failures (including resolved)
  List<SyncFailure> getAllFailures({
    bool includeResolved = false,
    bool includeDismissed = false,
  }) {
    _ensureInitialized();
    return _box.values.where((f) {
      if (!includeResolved && f.status == SyncFailureStatus.resolved) {
        return false;
      }
      if (!includeDismissed && f.status == SyncFailureStatus.dismissed) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.lastAttemptAt.compareTo(a.lastAttemptAt));
  }

  /// Get failures by severity
  List<SyncFailure> getFailuresBySeverity(SyncFailureSeverity severity) {
    _ensureInitialized();
    return _box.values
        .where((f) =>
            f.severity == severity &&
            f.status != SyncFailureStatus.resolved &&
            f.status != SyncFailureStatus.dismissed)
        .toList()
      ..sort((a, b) => b.lastAttemptAt.compareTo(a.lastAttemptAt));
  }

  /// Get failure count by status
  int getCount({SyncFailureStatus? status}) {
    _ensureInitialized();
    if (status == null) {
      return _box.length;
    }
    return _box.values.where((f) => f.status == status).length;
  }

  /// Mark a failure as resolved
  Future<void> markResolved(
    String failureId, {
    String? resolutionNote,
  }) async {
    _ensureInitialized();

    final key = _findKeyById(failureId);
    if (key == null) return;

    final failure = _box.get(key);
    if (failure == null) return;

    final resolved = failure.copyWith(
      status: SyncFailureStatus.resolved,
      resolvedAt: DateTime.now(),
      resolutionNote: resolutionNote,
    );

    await _box.put(key, resolved);

    _telemetry.increment('sync_failure.resolved');
    _resolvedStreamController.add(resolved);

    // Log to audit
    try {
      await AuditLogService.I.log(
        userId: failure.userId ?? 'system',
        action: 'sync_failure_resolved',
        entityType: failure.entityType,
        entityId: failure.entityId,
        severity: 'info',
        metadata: {
          'failureId': failureId,
          'operation': failure.operation,
          'resolutionNote': resolutionNote,
          'retryCount': failure.retryCount,
        },
      );
    } catch (e) {
      _telemetry.increment('sync_failure.audit_log_failed');
    }
  }

  /// Dismiss a failure (user action)
  Future<void> dismiss(String failureId) async {
    _ensureInitialized();

    final key = _findKeyById(failureId);
    if (key == null) return;

    final failure = _box.get(key);
    if (failure == null) return;

    final dismissed = failure.copyWith(
      status: SyncFailureStatus.dismissed,
    );

    await _box.put(key, dismissed);

    _telemetry.increment('sync_failure.dismissed');

    // Log to audit
    try {
      await AuditLogService.I.log(
        userId: failure.userId ?? 'system',
        action: 'sync_failure_dismissed',
        entityType: failure.entityType,
        entityId: failure.entityId,
        severity: 'info',
        metadata: {
          'failureId': failureId,
          'operation': failure.operation,
        },
      );
    } catch (e) {
      _telemetry.increment('sync_failure.audit_log_failed');
    }
  }

  /// Retry a specific failure (user-triggered)
  Future<bool> retry(
    String failureId, {
    required Future<void> Function() retryOperation,
  }) async {
    _ensureInitialized();

    final key = _findKeyById(failureId);
    if (key == null) return false;

    final failure = _box.get(key);
    if (failure == null) return false;

    // Mark as retrying
    await _box.put(
      key,
      failure.copyWith(status: SyncFailureStatus.retrying),
    );

    _telemetry.increment('sync_failure.retry_attempt');

    try {
      // Execute retry operation
      await retryOperation();

      // Success - mark as resolved
      await markResolved(failureId, resolutionNote: 'Manual retry successful');
      return true;
    } catch (e) {
      // Failed - update failure record
      await _box.put(
        key,
        failure.copyWith(
          lastAttemptAt: DateTime.now(),
          retryCount: failure.retryCount + 1,
          errorMessage: e.toString(),
          status: failure.retryCount + 1 >= _maxRetries
              ? SyncFailureStatus.failed
              : SyncFailureStatus.pending,
        ),
      );

      _telemetry.increment('sync_failure.retry_failed');
      return false;
    }
  }

  /// Retry all pending failures
  Future<Map<String, bool>> retryAll({
    required Future<void> Function(SyncFailure failure) retryOperation,
  }) async {
    _ensureInitialized();

    final pending = getPendingFailures();
    final results = <String, bool>{};

    for (final failure in pending) {
      if (failure.hasExceededMaxRetries(_maxRetries)) {
        continue; // Skip failures that exceeded max retries
      }

      final success = await retry(
        failure.id,
        retryOperation: () => retryOperation(failure),
      );
      results[failure.id] = success;

      // Add delay between retries
      if (failure != pending.last) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    return results;
  }

  /// Clean up old resolved/dismissed failures
  Future<int> _cleanupOldFailures() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    int cleaned = 0;

    final keysToDelete = <String>[];
    for (final entry in _box.toMap().entries) {
      final failure = entry.value;
      if ((failure.status == SyncFailureStatus.resolved ||
              failure.status == SyncFailureStatus.dismissed) &&
          failure.lastAttemptAt.isBefore(cutoff)) {
        keysToDelete.add(entry.key);
      }
    }

    for (final key in keysToDelete) {
      await _box.delete(key);
      cleaned++;
    }

    if (cleaned > 0) {
      _telemetry.increment('sync_failure.cleanup_count', cleaned);
    }

    return cleaned;
  }

  /// Generate unique key for failure storage
  String _getFailureKey(String entityType, String entityId, String operation) {
    return '${entityType}_${entityId}_$operation';
  }

  /// Find box key by failure ID
  String? _findKeyById(String failureId) {
    for (final entry in _box.toMap().entries) {
      if (entry.value.id == failureId) {
        return entry.key;
      }
    }
    return null;
  }

  /// Map severity to audit log severity
  String _mapSeverity(SyncFailureSeverity severity) {
    switch (severity) {
      case SyncFailureSeverity.low:
        return 'debug';
      case SyncFailureSeverity.medium:
        return 'info';
      case SyncFailureSeverity.high:
        return 'warning';
      case SyncFailureSeverity.critical:
        return 'error';
    }
  }

  /// Ensure service is initialized
  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('SyncFailureService not initialized. Call init() first.');
    }
  }

  /// Dispose resources
  void dispose() {
    _failureStreamController.close();
    _resolvedStreamController.close();
  }

  /// Get statistics
  SyncFailureStats getStats() {
    _ensureInitialized();

    final all = _box.values.toList();
    return SyncFailureStats(
      total: all.length,
      pending: all.where((f) => f.status == SyncFailureStatus.pending).length,
      retrying: all.where((f) => f.status == SyncFailureStatus.retrying).length,
      failed: all.where((f) => f.status == SyncFailureStatus.failed).length,
      resolved: all.where((f) => f.status == SyncFailureStatus.resolved).length,
      dismissed: all.where((f) => f.status == SyncFailureStatus.dismissed).length,
      lowSeverity: all.where((f) => f.severity == SyncFailureSeverity.low).length,
      mediumSeverity: all.where((f) => f.severity == SyncFailureSeverity.medium).length,
      highSeverity: all.where((f) => f.severity == SyncFailureSeverity.high).length,
      criticalSeverity: all.where((f) => f.severity == SyncFailureSeverity.critical).length,
      requiresUserAction: all.where((f) => f.requiresUserAction && 
                                           f.status != SyncFailureStatus.resolved &&
                                           f.status != SyncFailureStatus.dismissed).length,
    );
  }
}

/// Statistics about sync failures
class SyncFailureStats {
  final int total;
  final int pending;
  final int retrying;
  final int failed;
  final int resolved;
  final int dismissed;
  final int lowSeverity;
  final int mediumSeverity;
  final int highSeverity;
  final int criticalSeverity;
  final int requiresUserAction;

  SyncFailureStats({
    required this.total,
    required this.pending,
    required this.retrying,
    required this.failed,
    required this.resolved,
    required this.dismissed,
    required this.lowSeverity,
    required this.mediumSeverity,
    required this.highSeverity,
    required this.criticalSeverity,
    required this.requiresUserAction,
  });

  Map<String, dynamic> toJson() => {
        'total': total,
        'pending': pending,
        'retrying': retrying,
        'failed': failed,
        'resolved': resolved,
        'dismissed': dismissed,
        'lowSeverity': lowSeverity,
        'mediumSeverity': mediumSeverity,
        'highSeverity': highSeverity,
        'criticalSeverity': criticalSeverity,
        'requiresUserAction': requiresUserAction,
      };
}
