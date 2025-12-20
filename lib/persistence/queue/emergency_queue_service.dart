/// Emergency Queue Service
///
/// Provides a fast lane for emergency operations that bypasses the normal queue.
/// Emergency ops get:
/// - Separate Hive box for isolation
/// - Immediate processing attempt
/// - Aggressive retry (short backoff)
/// - Local escalation if cloud unreachable
///
/// Edge cases handled:
/// - Sync engine stalled
/// - Normal queue blocked
/// - Cloud unreachable
/// - Battery-saving mode
library;

import 'dart:async';
import 'package:hive/hive.dart';
import '../../models/pending_op.dart';
import '../../services/telemetry_service.dart';
import 'op_priority.dart';

/// Box name for emergency operations (separate from normal pending_ops_box)
const String emergencyOpsBoxName = 'emergency_ops_box';

/// Maximum attempts for emergency ops before escalation
const int emergencyMaxAttempts = 5;

/// Aggressive backoff for emergency ops (much shorter than normal)
Duration computeEmergencyBackoff(int attempts) {
  // Much shorter backoff: 1s, 2s, 4s, 8s, 15s max
  const base = Duration(seconds: 1);
  const maxBackoff = Duration(seconds: 15);
  
  if (attempts < 0) return base;
  
  final multiplier = attempts >= 4 ? 16 : (1 << attempts);
  final backoff = base * multiplier;
  
  return backoff > maxBackoff ? maxBackoff : backoff;
}

/// Result of emergency processing attempt.
class EmergencyProcessResult {
  final bool success;
  final bool requiresEscalation;
  final String? errorMessage;
  final int attemptsRemaining;
  
  const EmergencyProcessResult._({
    required this.success,
    required this.requiresEscalation,
    this.errorMessage,
    required this.attemptsRemaining,
  });
  
  factory EmergencyProcessResult.success() => const EmergencyProcessResult._(
    success: true,
    requiresEscalation: false,
    attemptsRemaining: 0,
  );
  
  factory EmergencyProcessResult.retry({
    required String errorMessage,
    required int attemptsRemaining,
  }) => EmergencyProcessResult._(
    success: false,
    requiresEscalation: false,
    errorMessage: errorMessage,
    attemptsRemaining: attemptsRemaining,
  );
  
  factory EmergencyProcessResult.escalate({
    required String errorMessage,
  }) => EmergencyProcessResult._(
    success: false,
    requiresEscalation: true,
    errorMessage: errorMessage,
    attemptsRemaining: 0,
  );
}

/// Listener for emergency escalations.
typedef EmergencyEscalationCallback = Future<void> Function(
  PendingOp op,
  String reason,
);

/// Emergency Queue Service for safety-critical operations.
///
/// Provides immediate processing with aggressive retry for emergency ops.
/// Triggers local escalation (notifications, alarms) when network unavailable.
class EmergencyQueueService {
  Box<PendingOp>? _box;
  bool _isInitialized = false;
  final TelemetryService _telemetry;
  
  /// Callback for escalating failed emergency ops.
  EmergencyEscalationCallback? onEscalation;
  
  // ═══════════════════════════════════════════════════════════════════════
  // CONSTRUCTORS
  // ═══════════════════════════════════════════════════════════════════════
  
  /// Creates an EmergencyQueueService with injected TelemetryService.
  EmergencyQueueService({TelemetryService? telemetry})
      : _telemetry = telemetry ?? TelemetryService.I;
  
  /// Timer for aggressive retry loop.
  Timer? _retryTimer;
  
  /// Whether the service is currently processing.
  bool _isProcessing = false;
  
  /// Stream controller for emergency events.
  final _eventController = StreamController<EmergencyEvent>.broadcast();
  
  /// Stream of emergency events for UI/alerting.
  Stream<EmergencyEvent> get eventStream => _eventController.stream;

  /// Initialize the emergency queue service.
  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      if (!Hive.isBoxOpen(emergencyOpsBoxName)) {
        _box = await Hive.openBox<PendingOp>(emergencyOpsBoxName);
      } else {
        _box = Hive.box<PendingOp>(emergencyOpsBoxName);
      }
      _isInitialized = true;
      
      // Start aggressive retry loop
      _startRetryLoop();
      
      _telemetry.increment('emergency_queue.init');
    } catch (e) {
      _telemetry.increment('emergency_queue.init_error');
      rethrow;
    }
  }

  /// Enqueue an emergency operation for immediate processing.
  ///
  /// Returns true if enqueued, false if not an emergency priority.
  Future<bool> enqueueEmergency(PendingOp op) async {
    if (!_isInitialized) await init();
    
    // Only accept emergency priority ops
    if (op.priority != OpPriority.emergency) {
      return false;
    }
    
    await _box!.put(op.id, op);
    
    _telemetry.increment('emergency_queue.enqueue');
    _telemetry.gauge('emergency_queue.count', _box!.length);
    
    _eventController.add(EmergencyEvent.enqueued(op));
    
    // Trigger immediate processing
    _scheduleImmediateProcessing();
    
    return true;
  }

  /// Process all pending emergency ops with provided handler.
  ///
  /// Handler should attempt to send to cloud/backend.
  /// Returns number of successfully processed ops.
  Future<int> processAll(Future<bool> Function(PendingOp op) handler) async {
    if (!_isInitialized) await init();
    if (_isProcessing) return 0;
    
    _isProcessing = true;
    int processed = 0;
    
    try {
      final ops = _box!.values.toList();
      
      for (final op in ops) {
        final result = await _processOne(op, handler);
        
        if (result.success) {
          await _box!.delete(op.id);
          processed++;
          _eventController.add(EmergencyEvent.processed(op));
        } else if (result.requiresEscalation) {
          await _escalate(op, result.errorMessage ?? 'Max attempts exceeded');
        }
        // If retry needed, op stays in box with updated attempts
      }
    } finally {
      _isProcessing = false;
    }
    
    _telemetry.gauge('emergency_queue.processed', processed);
    return processed;
  }

  /// Process a single emergency op.
  Future<EmergencyProcessResult> _processOne(
    PendingOp op,
    Future<bool> Function(PendingOp op) handler,
  ) async {
    try {
      final success = await handler(op);
      
      if (success) {
        return EmergencyProcessResult.success();
      } else {
        return _handleFailure(op, 'Handler returned false');
      }
    } catch (e) {
      return _handleFailure(op, e.toString());
    }
  }

  /// Handle a failed emergency op.
  Future<EmergencyProcessResult> _handleFailure(PendingOp op, String error) async {
    final newAttempts = op.attempts + 1;
    
    if (newAttempts >= emergencyMaxAttempts) {
      // Max attempts reached - escalate
      _telemetry.increment('emergency_queue.max_attempts');
      return EmergencyProcessResult.escalate(errorMessage: error);
    }
    
    // Update op with new attempt count and short backoff
    final nextEligible = DateTime.now().toUtc().add(computeEmergencyBackoff(newAttempts));
    
    final updatedOp = op.copyWith(
      attempts: newAttempts,
      lastError: error,
      lastTriedAt: DateTime.now().toUtc(),
      nextEligibleAt: nextEligible,
      updatedAt: DateTime.now().toUtc(),
    );
    
    await _box!.put(op.id, updatedOp);
    
    _telemetry.increment('emergency_queue.retry');
    
    return EmergencyProcessResult.retry(
      errorMessage: error,
      attemptsRemaining: emergencyMaxAttempts - newAttempts,
    );
  }

  /// Escalate a failed emergency op.
  Future<void> _escalate(PendingOp op, String reason) async {
    _telemetry.increment('emergency_queue.escalated');
    
    _eventController.add(EmergencyEvent.escalated(op, reason));
    
    // Call escalation callback if registered
    if (onEscalation != null) {
      try {
        await onEscalation!(op, reason);
      } catch (e) {
        _telemetry.increment('emergency_queue.escalation_callback_error');
      }
    }
    
    // Mark as escalated but keep in box for audit
    final escalatedOp = op.copyWith(
      status: 'escalated',
      lastError: 'ESCALATED: $reason',
      updatedAt: DateTime.now().toUtc(),
    );
    await _box!.put(op.id, escalatedOp);
  }

  /// Start the aggressive retry loop.
  void _startRetryLoop() {
    // Check every 2 seconds for eligible emergency ops
    _retryTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!_isProcessing && hasEligibleOps) {
        _eventController.add(EmergencyEvent.retryLoopTriggered());
      }
    });
  }

  /// Schedule immediate processing (debounced).
  void _scheduleImmediateProcessing() {
    // Notify listeners that immediate processing is needed
    _eventController.add(EmergencyEvent.immediateProcessingRequested());
  }

  /// Check if there are ops eligible for processing.
  bool get hasEligibleOps {
    if (!_isInitialized || _box == null) return false;
    
    final now = DateTime.now().toUtc();
    for (final op in _box!.values) {
      if (op.status == 'escalated') continue;
      if (op.nextEligibleAt == null || now.isAfter(op.nextEligibleAt!)) {
        return true;
      }
    }
    return false;
  }

  /// Get count of pending emergency ops.
  int get pendingCount {
    if (!_isInitialized || _box == null) return 0;
    return _box!.values.where((op) => op.status != 'escalated').length;
  }

  /// Get count of escalated ops.
  int get escalatedCount {
    if (!_isInitialized || _box == null) return 0;
    return _box!.values.where((op) => op.status == 'escalated').length;
  }

  /// Get all pending emergency ops.
  List<PendingOp> get pendingOps {
    if (!_isInitialized || _box == null) return [];
    return _box!.values.where((op) => op.status != 'escalated').toList();
  }

  /// Clear all emergency ops (for testing).
  Future<void> clear() async {
    if (!_isInitialized) return;
    await _box!.clear();
    _telemetry.gauge('emergency_queue.count', 0);
  }

  /// Dispose resources.
  void dispose() {
    _retryTimer?.cancel();
    _eventController.close();
  }
}

/// Events emitted by the emergency queue.
enum EmergencyEventType {
  enqueued,
  processed,
  escalated,
  retryLoopTriggered,
  immediateProcessingRequested,
}

/// Emergency event for observability.
class EmergencyEvent {
  final EmergencyEventType type;
  final PendingOp? op;
  final String? reason;
  final DateTime timestamp;
  
  EmergencyEvent._({
    required this.type,
    this.op,
    this.reason,
  }) : timestamp = DateTime.now().toUtc();
  
  factory EmergencyEvent.enqueued(PendingOp op) => EmergencyEvent._(
    type: EmergencyEventType.enqueued,
    op: op,
  );
  
  factory EmergencyEvent.processed(PendingOp op) => EmergencyEvent._(
    type: EmergencyEventType.processed,
    op: op,
  );
  
  factory EmergencyEvent.escalated(PendingOp op, String reason) => EmergencyEvent._(
    type: EmergencyEventType.escalated,
    op: op,
    reason: reason,
  );
  
  factory EmergencyEvent.retryLoopTriggered() => EmergencyEvent._(
    type: EmergencyEventType.retryLoopTriggered,
  );
  
  factory EmergencyEvent.immediateProcessingRequested() => EmergencyEvent._(
    type: EmergencyEventType.immediateProcessingRequested,
  );
}
