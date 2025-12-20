/// Queue Stall Detector & Auto-Recovery
///
/// Detects when the queue is stalled (processing but no progress)
/// and automatically recovers by:
/// 1. Releasing stale locks
/// 2. Rebuilding the index
/// 3. Resuming processing
///
/// This is the self-healing layer for queue reliability.
///
/// See also: docs/LOCAL_BACKEND_PHASE2_STABILIZATION.md
library;

import 'dart:async';
import 'package:hive/hive.dart';
import '../../models/pending_op.dart';
import '../../services/audit_log_service.dart';
import '../../services/telemetry_service.dart';
import '../box_registry.dart';
import '../index/pending_index.dart';
import '../locking/processing_lock.dart';
import '../wrappers/box_accessor.dart';
import 'queue_state.dart';

// ═══════════════════════════════════════════════════════════════════════════
// STALL CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════

/// Configuration for stall detection.
class StallConfig {
  /// Duration after which a queue is considered stalled.
  final Duration stallThreshold;
  
  /// Duration after which a lock is considered stale.
  final Duration lockStaleThreshold;
  
  /// How often to check for stalls.
  final Duration checkInterval;
  
  /// Maximum number of auto-recovery attempts before giving up.
  final int maxRecoveryAttempts;
  
  /// Cooldown between recovery attempts.
  final Duration recoveryCooldown;
  
  const StallConfig({
    this.stallThreshold = const Duration(minutes: 10),
    this.lockStaleThreshold = const Duration(minutes: 5),
    this.checkInterval = const Duration(minutes: 1),
    this.maxRecoveryAttempts = 3,
    this.recoveryCooldown = const Duration(minutes: 2),
  });
  
  /// Default configuration for production.
  static const StallConfig production = StallConfig();
  
  /// Aggressive configuration for testing.
  static const StallConfig testing = StallConfig(
    stallThreshold: Duration(seconds: 30),
    lockStaleThreshold: Duration(seconds: 15),
    checkInterval: Duration(seconds: 5),
    maxRecoveryAttempts: 5,
    recoveryCooldown: Duration(seconds: 10),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// STALL STATUS
// ═══════════════════════════════════════════════════════════════════════════

/// Current stall detection status.
class StallStatus {
  /// Whether the queue is currently stalled.
  final bool isStalled;
  
  /// Duration the queue has been stalled (null if not stalled).
  final Duration? stallDuration;
  
  /// ID of the oldest pending operation (null if queue empty).
  final String? oldestOpId;
  
  /// Age of the oldest pending operation (null if queue empty).
  final Duration? oldestOpAge;
  
  /// Whether a lock is held.
  final bool lockHeld;
  
  /// Duration the lock has been held (null if not locked).
  final Duration? lockDuration;
  
  /// Whether the lock is stale.
  final bool lockIsStale;
  
  /// Number of recovery attempts made.
  final int recoveryAttempts;
  
  /// Last recovery attempt time (null if never).
  final DateTime? lastRecoveryAt;
  
  /// Timestamp when this status was captured.
  final DateTime capturedAt;
  
  const StallStatus({
    required this.isStalled,
    this.stallDuration,
    this.oldestOpId,
    this.oldestOpAge,
    required this.lockHeld,
    this.lockDuration,
    required this.lockIsStale,
    required this.recoveryAttempts,
    this.lastRecoveryAt,
    required this.capturedAt,
  });
  
  /// Whether auto-recovery should be attempted.
  bool get shouldAttemptRecovery => isStalled && recoveryAttempts < 3;
  
  @override
  String toString() => 'StallStatus('
      'stalled=$isStalled, '
      'stallDuration=${stallDuration?.inMinutes}m, '
      'lockHeld=$lockHeld, '
      'lockStale=$lockIsStale, '
      'recoveryAttempts=$recoveryAttempts)';
}

// ═══════════════════════════════════════════════════════════════════════════
// RECOVERY RESULT
// ═══════════════════════════════════════════════════════════════════════════

/// Result of an auto-recovery attempt.
class RecoveryResult {
  /// Whether recovery was successful.
  final bool success;
  
  /// Actions taken during recovery.
  final List<String> actionsTaken;
  
  /// Duration of the recovery process.
  final Duration duration;
  
  /// Error message if failed.
  final String? error;
  
  const RecoveryResult({
    required this.success,
    required this.actionsTaken,
    required this.duration,
    this.error,
  });
  
  factory RecoveryResult.success({
    required List<String> actionsTaken,
    required Duration duration,
  }) {
    return RecoveryResult(
      success: true,
      actionsTaken: actionsTaken,
      duration: duration,
    );
  }
  
  factory RecoveryResult.failure({
    required String error,
    required List<String> actionsTaken,
    required Duration duration,
  }) {
    return RecoveryResult(
      success: false,
      actionsTaken: actionsTaken,
      duration: duration,
      error: error,
    );
  }
  
  @override
  String toString() => success
      ? 'RecoveryResult.success(actions=$actionsTaken)'
      : 'RecoveryResult.failure($error)';
}

// ═══════════════════════════════════════════════════════════════════════════
// QUEUE STALL DETECTOR
// ═══════════════════════════════════════════════════════════════════════════

/// Queue Stall Detector with Auto-Recovery.
///
/// Monitors the queue for stalls and automatically recovers when detected.
class QueueStallDetector {
  final StallConfig config;
  final TelemetryService _telemetry;
  final AuditLogService _auditLog;
  
  Timer? _checkTimer;
  bool _isMonitoring = false;
  int _recoveryAttempts = 0;
  DateTime? _lastRecoveryAt;
  DateTime? _stallDetectedAt;
  
  /// Stream controller for stall events.
  final _eventController = StreamController<StallEvent>.broadcast();
  
  /// Stream of stall events for observability.
  Stream<StallEvent> get eventStream => _eventController.stream;
  
  /// Callback when recovery is needed.
  /// 
  /// Set this to integrate with the queue service for actual recovery.
  Future<void> Function()? onRecoveryNeeded;
  
  QueueStallDetector({
    this.config = const StallConfig(),
    TelemetryService? telemetry,
    AuditLogService? auditLog,
  }) : _telemetry = telemetry ?? TelemetryService.I,
       _auditLog = auditLog ?? AuditLogService.I;
  
  /// Start monitoring for stalls.
  void startMonitoring() {
    if (_isMonitoring) return;
    
    _isMonitoring = true;
    _checkTimer = Timer.periodic(config.checkInterval, (_) => _checkForStall());
    
    _telemetry.increment('stall_detector.started');
  }
  
  /// Stop monitoring.
  void stopMonitoring() {
    _checkTimer?.cancel();
    _checkTimer = null;
    _isMonitoring = false;
    
    _telemetry.increment('stall_detector.stopped');
  }
  
  /// Get current stall status.
  StallStatus getStatus() {
    final now = DateTime.now().toUtc();
    
    // Check oldest op age
    String? oldestOpId;
    Duration? oldestOpAge;
    bool isStalled = false;
    
    if (Hive.isBoxOpen(BoxRegistry.pendingOpsBox)) {
      try {
        final pendingBox = Hive.box<PendingOp>(BoxRegistry.pendingOpsBox);
        
        DateTime? oldestCreated;
        for (final op in pendingBox.values) {
          if (oldestCreated == null || op.createdAt.isBefore(oldestCreated)) {
            oldestCreated = op.createdAt;
            oldestOpId = op.id;
          }
        }
        
        if (oldestCreated != null) {
          oldestOpAge = now.difference(oldestCreated);
          isStalled = oldestOpAge > config.stallThreshold;
        }
      } catch (e) {
        _telemetry.increment('stall_detector.pending_box_error');
      }
    }
    
    // Check lock status
    bool lockHeld = false;
    Duration? lockDuration;
    bool lockIsStale = false;
    
    if (Hive.isBoxOpen(BoxRegistry.metaBox)) {
      try {
        final metaBox = BoxAccess.I.meta();
        final lockData = metaBox.get('processing_lock') as Map?;
        
        if (lockData != null) {
          lockHeld = true;
          final startedAtStr = lockData['startedAt'] as String?;
          final acquiredAt = startedAtStr != null ? DateTime.tryParse(startedAtStr) : null;
          
          if (acquiredAt != null) {
            lockDuration = now.difference(acquiredAt);
            lockIsStale = lockDuration > config.lockStaleThreshold;
          }
        }
      } catch (e) {
        _telemetry.increment('stall_detector.meta_box_error');
      }
    }
    
    // Calculate stall duration
    Duration? stallDuration;
    if (isStalled) {
      if (_stallDetectedAt == null) {
        _stallDetectedAt = now;
      }
      stallDuration = now.difference(_stallDetectedAt!);
    } else {
      _stallDetectedAt = null;
    }
    
    return StallStatus(
      isStalled: isStalled,
      stallDuration: stallDuration,
      oldestOpId: oldestOpId,
      oldestOpAge: oldestOpAge,
      lockHeld: lockHeld,
      lockDuration: lockDuration,
      lockIsStale: lockIsStale,
      recoveryAttempts: _recoveryAttempts,
      lastRecoveryAt: _lastRecoveryAt,
      capturedAt: now,
    );
  }
  
  /// Check for stall and trigger recovery if needed.
  Future<void> _checkForStall() async {
    final status = getStatus();
    
    if (!status.isStalled) {
      // Clear recovery attempts on successful unstall
      if (_recoveryAttempts > 0) {
        _recoveryAttempts = 0;
        _eventController.add(StallEvent.unstalled());
        _telemetry.increment('stall_detector.unstalled');
      }
      return;
    }
    
    // Emit stall detected event
    _eventController.add(StallEvent.stallDetected(status));
    _telemetry.increment('stall_detector.stall_detected');
    _telemetry.gauge('stall_detector.stall_duration_seconds', status.stallDuration?.inSeconds ?? 0);
    
    // Check if we should attempt recovery
    if (_recoveryAttempts >= config.maxRecoveryAttempts) {
      _eventController.add(StallEvent.maxRecoveryAttemptsReached(_recoveryAttempts));
      _telemetry.increment('stall_detector.max_recovery_reached');
      return;
    }
    
    // Check cooldown
    if (_lastRecoveryAt != null) {
      final timeSinceLastRecovery = DateTime.now().toUtc().difference(_lastRecoveryAt!);
      if (timeSinceLastRecovery < config.recoveryCooldown) {
        return; // Still in cooldown
      }
    }
    
    // Attempt recovery
    await _attemptRecovery(status);
  }
  
  /// Attempt auto-recovery.
  Future<RecoveryResult> _attemptRecovery(StallStatus status) async {
    final sw = Stopwatch()..start();
    final actionsTaken = <String>[];
    
    _recoveryAttempts++;
    _lastRecoveryAt = DateTime.now().toUtc();
    
    _eventController.add(StallEvent.recoveryStarted(_recoveryAttempts));
    _telemetry.increment('stall_detector.recovery_started');
    
    // Log to audit (gracefully handle if not initialized)
    try {
      await _auditLog.log(
        userId: 'system',
        action: 'queueStallRecovered',
        entityType: 'queue',
        metadata: {
          'stall_duration_seconds': status.stallDuration?.inSeconds,
          'oldest_op_id': status.oldestOpId,
          'lock_held': status.lockHeld,
          'lock_stale': status.lockIsStale,
          'recovery_attempt': _recoveryAttempts,
        },
        severity: 'warning',
      );
    } catch (e) {
      // Audit log may not be initialized - continue with recovery
      _telemetry.increment('stall_detector.audit_log_unavailable');
    }
    
    try {
      // Step 1: Release stale lock if present
      if (status.lockHeld && status.lockIsStale) {
        await _releaseStaleLock();
        actionsTaken.add('released_stale_lock');
      }
      
      // Step 2: Rebuild index
      await _rebuildIndex();
      actionsTaken.add('rebuilt_index');
      
      // Step 3: Call recovery callback if set
      if (onRecoveryNeeded != null) {
        await onRecoveryNeeded!();
        actionsTaken.add('called_recovery_callback');
      }
      
      sw.stop();
      
      final result = RecoveryResult.success(
        actionsTaken: actionsTaken,
        duration: sw.elapsed,
      );
      
      _eventController.add(StallEvent.recoveryCompleted(result));
      _telemetry.increment('stall_detector.recovery_success');
      _telemetry.gauge('stall_detector.recovery_duration_ms', sw.elapsedMilliseconds);
      
      return result;
    } catch (e) {
      sw.stop();
      
      final result = RecoveryResult.failure(
        error: e.toString(),
        actionsTaken: actionsTaken,
        duration: sw.elapsed,
      );
      
      _eventController.add(StallEvent.recoveryFailed(result));
      _telemetry.increment('stall_detector.recovery_failed');
      
      return result;
    }
  }
  
  /// Release a stale processing lock.
  Future<void> _releaseStaleLock() async {
    if (!Hive.isBoxOpen(BoxRegistry.metaBox)) return;
    
    final metaBox = BoxAccess.I.meta();
    await metaBox.delete('processing_lock');
    
    _telemetry.increment('stall_detector.stale_lock_released');
  }
  
  /// Rebuild the pending index.
  Future<void> _rebuildIndex() async {
    final index = await PendingIndex.create();
    await index.rebuild();
    
    _telemetry.increment('stall_detector.index_rebuilt');
  }
  
  /// Force a recovery attempt (for admin use).
  Future<RecoveryResult> forceRecovery() async {
    final status = getStatus();
    return await _attemptRecovery(status);
  }
  
  /// Reset recovery attempts (for admin use).
  void resetRecoveryAttempts() {
    _recoveryAttempts = 0;
    _lastRecoveryAt = null;
    _telemetry.increment('stall_detector.recovery_reset');
  }
  
  /// Dispose resources.
  void dispose() {
    stopMonitoring();
    _eventController.close();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// STALL EVENTS
// ═══════════════════════════════════════════════════════════════════════════

/// Types of stall events.
enum StallEventType {
  stallDetected,
  recoveryStarted,
  recoveryCompleted,
  recoveryFailed,
  unstalled,
  maxRecoveryAttemptsReached,
}

/// Stall event for observability.
class StallEvent {
  final StallEventType type;
  final StallStatus? status;
  final RecoveryResult? recoveryResult;
  final int? recoveryAttempt;
  final DateTime timestamp;
  
  StallEvent._({
    required this.type,
    this.status,
    this.recoveryResult,
    this.recoveryAttempt,
  }) : timestamp = DateTime.now().toUtc();
  
  factory StallEvent.stallDetected(StallStatus status) => StallEvent._(
    type: StallEventType.stallDetected,
    status: status,
  );
  
  factory StallEvent.recoveryStarted(int attempt) => StallEvent._(
    type: StallEventType.recoveryStarted,
    recoveryAttempt: attempt,
  );
  
  factory StallEvent.recoveryCompleted(RecoveryResult result) => StallEvent._(
    type: StallEventType.recoveryCompleted,
    recoveryResult: result,
  );
  
  factory StallEvent.recoveryFailed(RecoveryResult result) => StallEvent._(
    type: StallEventType.recoveryFailed,
    recoveryResult: result,
  );
  
  factory StallEvent.unstalled() => StallEvent._(
    type: StallEventType.unstalled,
  );
  
  factory StallEvent.maxRecoveryAttemptsReached(int attempts) => StallEvent._(
    type: StallEventType.maxRecoveryAttemptsReached,
    recoveryAttempt: attempts,
  );
  
  @override
  String toString() => 'StallEvent($type)';
}
