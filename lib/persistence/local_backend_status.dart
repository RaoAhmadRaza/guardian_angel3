/// Local Backend Status Provider
///
/// Provides a read-only observability surface for the local backend.
/// Exposes key metrics without admin UI, enabling monitoring and debugging.
///
/// Usage:
/// ```dart
/// final status = ref.watch(localBackendStatusProvider);
/// if (status.queueStalled) {
///   // Handle stalled queue
/// }
/// ```
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../models/pending_op.dart';
import '../persistence/box_registry.dart';
import '../persistence/encryption_policy.dart';
import '../persistence/wrappers/box_accessor.dart';
import '../services/telemetry_service.dart';
import 'queue/emergency_queue_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// LOCK STATUS - Processing lock observability
// ═══════════════════════════════════════════════════════════════════════════

/// Status of the processing lock.
class LockStatus {
  /// Whether the lock is currently held
  final bool isLocked;
  
  /// PID of the current lock holder (if locked)
  final String? holderPid;
  
  /// When the lock was acquired (if locked)
  final DateTime? acquiredAt;
  
  /// Whether this lock was recovered from a stale state
  final bool wasStaleRecovered;
  
  /// Duration the lock has been held (if locked)
  final Duration? lockDuration;

  const LockStatus({
    required this.isLocked,
    this.holderPid,
    this.acquiredAt,
    this.wasStaleRecovered = false,
    this.lockDuration,
  });

  const LockStatus.unlocked() : 
    isLocked = false,
    holderPid = null,
    acquiredAt = null,
    wasStaleRecovered = false,
    lockDuration = null;

  @override
  String toString() => isLocked 
      ? 'LockStatus(locked by $holderPid for ${lockDuration?.inSeconds}s)'
      : 'LockStatus(unlocked)';
}

/// Read-only status of the local backend.
///
/// This class aggregates key health metrics without exposing
/// mutation capabilities. For debugging and monitoring only.
class LocalBackendStatus {
  /// Number of pending operations waiting to sync
  final int pendingOps;

  /// Number of failed operations (exceeded retry limit)
  final int failedOps;

  /// Number of operations currently being retried
  final int retryingOps;

  /// Whether encryption is properly configured
  final bool encryptionHealthy;

  /// Whether the queue appears stalled (old ops not processing)
  final bool queueStalled;

  /// Age of the oldest pending operation (null if queue empty)
  final Duration? oldestOpAge;

  /// Last time the queue was processed (null if never)
  final DateTime? lastProcessedAt;

  /// Number of boxes currently open
  final int openBoxCount;

  /// Timestamp when this status was captured
  final DateTime capturedAt;

  // ═══════════════════════════════════════════════════════════════════════════
  // NEW FIELDS - Final 10% Phase 1: Observability Enhancement
  // ═══════════════════════════════════════════════════════════════════════════

  /// Number of emergency operations in the fast lane queue
  final int emergencyOps;

  /// Number of escalated emergency ops (failed max attempts, local alert triggered)
  final int escalatedOps;

  /// Duration the queue has been stalled (null if not stalled)
  final Duration? queueStallDuration;

  /// Last time an operation was successfully synced to cloud (null if never)
  final DateTime? lastSuccessfulSync;

  /// Whether all Hive adapters are properly registered
  final bool adaptersHealthy;

  /// Processing lock status
  final LockStatus lockStatus;

  /// Count of ops by priority level
  final Map<String, int> opsByPriority;

  /// Current queue state (idle, processing, blocked, paused, error)
  final String queueState;

  /// Number of entity locks currently held
  final int entityLockCount;

  /// Whether safety fallback mode is active (network blackout)
  final bool safetyFallbackActive;

  const LocalBackendStatus({
    required this.pendingOps,
    required this.failedOps,
    required this.retryingOps,
    required this.encryptionHealthy,
    required this.queueStalled,
    required this.oldestOpAge,
    required this.lastProcessedAt,
    required this.openBoxCount,
    required this.capturedAt,
    // New fields
    this.emergencyOps = 0,
    this.escalatedOps = 0,
    this.queueStallDuration,
    this.lastSuccessfulSync,
    this.adaptersHealthy = true,
    this.lockStatus = const LockStatus.unlocked(),
    this.opsByPriority = const {},
    this.queueState = 'unknown',
    this.entityLockCount = 0,
    this.safetyFallbackActive = false,
  });

  /// Whether the backend is in a healthy state
  bool get isHealthy =>
      encryptionHealthy && 
      !queueStalled && 
      failedOps == 0 && 
      adaptersHealthy &&
      !safetyFallbackActive;

  /// Whether the backend is in critical state (needs immediate attention)
  bool get isCritical =>
      !encryptionHealthy ||
      (emergencyOps > 0 && escalatedOps > 0) ||
      (queueStallDuration != null && queueStallDuration!.inMinutes > 30) ||
      (failedOps > 10);

  /// Whether the backend is in warning state (should be monitored)
  bool get isWarning =>
      !isHealthy && !isCritical;

  /// Health severity level (0 = healthy, 1 = warning, 2 = critical)
  int get healthSeverity {
    if (isCritical) return 2;
    if (isWarning) return 1;
    return 0;
  }

  /// Quick summary for logging
  String get summary =>
      'pending=$pendingOps, failed=$failedOps, emergency=$emergencyOps, '
      'stalled=$queueStalled, healthy=$isHealthy, state=$queueState';

  @override
  String toString() => 'LocalBackendStatus($summary)';

  /// Create a copy with updated fields
  LocalBackendStatus copyWith({
    int? pendingOps,
    int? failedOps,
    int? retryingOps,
    bool? encryptionHealthy,
    bool? queueStalled,
    Duration? oldestOpAge,
    DateTime? lastProcessedAt,
    int? openBoxCount,
    DateTime? capturedAt,
    int? emergencyOps,
    int? escalatedOps,
    Duration? queueStallDuration,
    DateTime? lastSuccessfulSync,
    bool? adaptersHealthy,
    LockStatus? lockStatus,
    Map<String, int>? opsByPriority,
    String? queueState,
    int? entityLockCount,
    bool? safetyFallbackActive,
  }) {
    return LocalBackendStatus(
      pendingOps: pendingOps ?? this.pendingOps,
      failedOps: failedOps ?? this.failedOps,
      retryingOps: retryingOps ?? this.retryingOps,
      encryptionHealthy: encryptionHealthy ?? this.encryptionHealthy,
      queueStalled: queueStalled ?? this.queueStalled,
      oldestOpAge: oldestOpAge ?? this.oldestOpAge,
      lastProcessedAt: lastProcessedAt ?? this.lastProcessedAt,
      openBoxCount: openBoxCount ?? this.openBoxCount,
      capturedAt: capturedAt ?? this.capturedAt,
      emergencyOps: emergencyOps ?? this.emergencyOps,
      escalatedOps: escalatedOps ?? this.escalatedOps,
      queueStallDuration: queueStallDuration ?? this.queueStallDuration,
      lastSuccessfulSync: lastSuccessfulSync ?? this.lastSuccessfulSync,
      adaptersHealthy: adaptersHealthy ?? this.adaptersHealthy,
      lockStatus: lockStatus ?? this.lockStatus,
      opsByPriority: opsByPriority ?? this.opsByPriority,
      queueState: queueState ?? this.queueState,
      entityLockCount: entityLockCount ?? this.entityLockCount,
      safetyFallbackActive: safetyFallbackActive ?? this.safetyFallbackActive,
    );
  }
}

/// Service to collect local backend status.
///
/// This is separate from the provider to allow testing and
/// non-Riverpod usage.
class LocalBackendStatusCollector {
  /// Stale threshold: ops older than this are considered "stalled"
  static const Duration staleThreshold = Duration(minutes: 10);

  /// Singleton emergency queue instance for status collection
  static EmergencyQueueService? _emergencyQueueInstance;

  /// Set the emergency queue instance for status collection.
  /// 
  /// Call this during app initialization after creating PendingQueueService.
  static void setEmergencyQueue(EmergencyQueueService queue) {
    _emergencyQueueInstance = queue;
  }

  /// Collect current backend status.
  ///
  /// Safe to call even if some boxes aren't open.
  static LocalBackendStatus collect() {
    final now = DateTime.now().toUtc();
    
    int pendingOps = 0;
    int failedOps = 0;
    int retryingOps = 0;
    Duration? oldestOpAge;
    DateTime? lastProcessedAt;
    bool queueStalled = false;
    Duration? queueStallDuration;
    DateTime? lastSuccessfulSync;
    int emergencyOps = 0;
    int escalatedOps = 0;
    final opsByPriority = <String, int>{
      'emergency': 0,
      'high': 0,
      'normal': 0,
      'low': 0,
    };

    // Collect emergency queue stats
    if (_emergencyQueueInstance != null) {
      emergencyOps = _emergencyQueueInstance!.pendingCount;
      escalatedOps = _emergencyQueueInstance!.escalatedCount;
      opsByPriority['emergency'] = emergencyOps;
    } else if (Hive.isBoxOpen(emergencyOpsBoxName)) {
      try {
        final emergencyBox = Hive.box<PendingOp>(emergencyOpsBoxName);
        emergencyOps = emergencyBox.values.where((op) => op.status != 'escalated').length;
        escalatedOps = emergencyBox.values.where((op) => op.status == 'escalated').length;
        opsByPriority['emergency'] = emergencyOps;
      } catch (e) {
        TelemetryService.I.increment('local_backend_status.emergency_box_error');
      }
    }

    // Count pending operations
    if (Hive.isBoxOpen(BoxRegistry.pendingOpsBox)) {
      try {
        final pendingBox = Hive.box<PendingOp>(BoxRegistry.pendingOpsBox);
        pendingOps = pendingBox.length;

        // Find oldest op and check for retrying
        DateTime? oldestCreated;
        for (final op in pendingBox.values) {
          if (oldestCreated == null || op.createdAt.isBefore(oldestCreated)) {
            oldestCreated = op.createdAt;
          }
          if (op.attempts > 0) {
            retryingOps++;
          }
          // Track last processed time from lastTriedAt
          if (op.lastTriedAt != null) {
            if (lastProcessedAt == null || op.lastTriedAt!.isAfter(lastProcessedAt)) {
              lastProcessedAt = op.lastTriedAt;
            }
          }
          
          // Count by priority
          final priorityName = op.priority.name;
          opsByPriority[priorityName] = (opsByPriority[priorityName] ?? 0) + 1;
        }

        if (oldestCreated != null) {
          oldestOpAge = now.difference(oldestCreated);
          queueStalled = oldestOpAge > staleThreshold;
          if (queueStalled) {
            queueStallDuration = oldestOpAge;
          }
        }
      } catch (e) {
        // Box might be in inconsistent state
        TelemetryService.I.increment('local_backend_status.pending_box_error');
      }
    }

    // Count failed operations
    if (Hive.isBoxOpen(BoxRegistry.failedOpsBox)) {
      try {
        final failedBox = BoxAccess.I.failedOps();
        failedOps = failedBox.length;
      } catch (e) {
        TelemetryService.I.increment('local_backend_status.failed_box_error');
      }
    }

    // Check encryption health
    final encryptionSummary = BoxPolicyRegistry.getSummary();
    final encryptionHealthy = encryptionSummary.isHealthy;

    // Count open boxes
    int openBoxCount = 0;
    for (final boxName in BoxRegistry.allBoxes) {
      if (Hive.isBoxOpen(boxName)) {
        openBoxCount++;
      }
    }

    // Check lock status
    LockStatus lockStatus = const LockStatus.unlocked();
    if (Hive.isBoxOpen(BoxRegistry.metaBox)) {
      try {
        final metaBox = BoxAccess.I.meta();
        final lockData = metaBox.get('processing_lock') as Map?;
        if (lockData != null) {
          final startedAtStr = lockData['startedAt'] as String?;
          final acquiredAt = startedAtStr != null ? DateTime.tryParse(startedAtStr) : null;
          lockStatus = LockStatus(
            isLocked: true,
            holderPid: lockData['pid'] as String?,
            acquiredAt: acquiredAt,
            wasStaleRecovered: lockData['staleRecovered'] == true,
            lockDuration: acquiredAt != null ? now.difference(acquiredAt) : null,
          );
        }
      } catch (e) {
        TelemetryService.I.increment('local_backend_status.lock_check_error');
      }
    }

    // Check adapters health
    bool adaptersHealthy = true;
    try {
      // Key adapters for local backend
      final requiredAdapters = [0, 1, 2, 15]; // PendingOp, FailedOpModel, etc.
      for (final typeId in requiredAdapters) {
        if (!Hive.isAdapterRegistered(typeId)) {
          adaptersHealthy = false;
          break;
        }
      }
    } catch (e) {
      adaptersHealthy = false;
    }

    // Get queue state from meta box
    String queueState = 'unknown';
    if (Hive.isBoxOpen(BoxRegistry.metaBox)) {
      try {
        final metaBox = BoxAccess.I.meta();
        final state = metaBox.get('queue_state') as String?;
        if (state != null) {
          queueState = state;
        } else if (lockStatus.isLocked) {
          queueState = 'processing';
        } else if (pendingOps == 0) {
          queueState = 'idle';
        } else {
          queueState = 'idle';
        }
      } catch (_) {}
    }

    // Check safety fallback state
    bool safetyFallbackActive = false;
    if (Hive.isBoxOpen(BoxRegistry.metaBox)) {
      try {
        final metaBox = BoxAccess.I.meta();
        safetyFallbackActive = metaBox.get('safety_fallback_active') == true;
      } catch (_) {}
    }

    // Record telemetry
    TelemetryService.I.gauge('local_backend.pending_ops', pendingOps);
    TelemetryService.I.gauge('local_backend.failed_ops', failedOps);
    TelemetryService.I.gauge('local_backend.retrying_ops', retryingOps);
    TelemetryService.I.gauge('local_backend.emergency_ops', emergencyOps);
    TelemetryService.I.gauge('local_backend.escalated_ops', escalatedOps);
    TelemetryService.I.gauge('local_backend.open_boxes', openBoxCount);
    if (queueStalled) {
      TelemetryService.I.increment('local_backend.queue_stalled');
    }

    return LocalBackendStatus(
      pendingOps: pendingOps,
      failedOps: failedOps,
      retryingOps: retryingOps,
      encryptionHealthy: encryptionHealthy,
      queueStalled: queueStalled,
      oldestOpAge: oldestOpAge,
      lastProcessedAt: lastProcessedAt,
      openBoxCount: openBoxCount,
      capturedAt: now,
      emergencyOps: emergencyOps,
      escalatedOps: escalatedOps,
      queueStallDuration: queueStallDuration,
      lastSuccessfulSync: lastSuccessfulSync,
      adaptersHealthy: adaptersHealthy,
      lockStatus: lockStatus,
      opsByPriority: opsByPriority,
      queueState: queueState,
      entityLockCount: 0, // Populated at runtime by PendingQueueService
      safetyFallbackActive: safetyFallbackActive,
    );
  }
}

/// Riverpod provider for local backend status.
///
/// This is a read-only provider that collects status on demand.
/// For real-time updates, consider using a StreamProvider with periodic refresh.
final localBackendStatusProvider = Provider<LocalBackendStatus>((ref) {
  return LocalBackendStatusCollector.collect();
});

/// Auto-refreshing provider that updates every 30 seconds.
///
/// Use this for UI that needs to show live status.
final localBackendStatusStreamProvider = StreamProvider<LocalBackendStatus>((ref) {
  return Stream.periodic(
    const Duration(seconds: 30),
    (_) => LocalBackendStatusCollector.collect(),
  );
});

/// Provider for checking if backend is healthy (simple boolean).
final localBackendHealthyProvider = Provider<bool>((ref) {
  final status = ref.watch(localBackendStatusProvider);
  return status.isHealthy;
});
