/// Priority Queue Processor
///
/// Orchestrates priority-based queue processing with emergency fast lane.
/// Processing order: Emergency → High → Normal → Low
///
/// Features:
/// - Priority-based processing order
/// - Emergency ops bypass normal backoff
/// - Delivery state tracking (pending → sent → acknowledged)
/// - Integration with SafetyFallbackService
/// - Entity ordering within priority levels
library;

import 'dart:async';
import 'package:hive/hive.dart';
import '../../models/pending_op.dart';
import '../../services/telemetry_service.dart';
import '../index/pending_index.dart';
import 'op_priority.dart';
import 'emergency_queue_service.dart';
import 'safety_fallback_service.dart';

/// Delivery acknowledgement result.
class DeliveryAck {
  final String idempotencyKey;
  final DateTime serverTimestamp;
  final bool acknowledged;
  
  const DeliveryAck({
    required this.idempotencyKey,
    required this.serverTimestamp,
    required this.acknowledged,
  });
}

/// Priority Queue Processor.
///
/// Processes operations in priority order with emergency fast lane.
class PriorityQueueProcessor {
  final Box<PendingOp> _pendingBox;
  final PendingIndex _index;
  final EmergencyQueueService _emergencyQueue;
  final SafetyFallbackService _safetyFallback;
  final TelemetryService _telemetry;
  
  /// Whether currently processing.
  bool _isProcessing = false;
  
  PriorityQueueProcessor._({
    required Box<PendingOp> pendingBox,
    required PendingIndex index,
    required EmergencyQueueService emergencyQueue,
    required SafetyFallbackService safetyFallback,
    TelemetryService? telemetry,
  }) : _pendingBox = pendingBox,
       _index = index,
       _emergencyQueue = emergencyQueue,
       _safetyFallback = safetyFallback,
       _telemetry = telemetry ?? TelemetryService.I;
  
  static Future<PriorityQueueProcessor> create({
    required Box<PendingOp> pendingBox,
    required PendingIndex index,
    TelemetryService? telemetry,
  }) async {
    final emergencyQueue = EmergencyQueueService(telemetry: telemetry);
    await emergencyQueue.init();
    
    final safetyFallback = SafetyFallbackService(telemetry: telemetry);
    await safetyFallback.init();
    
    return PriorityQueueProcessor._(
      pendingBox: pendingBox,
      index: index,
      emergencyQueue: emergencyQueue,
      safetyFallback: safetyFallback,
      telemetry: telemetry,
    );
  }

  /// Enqueue an operation with priority routing.
  ///
  /// Emergency ops are routed to the fast lane.
  /// Other ops go to the normal pending queue.
  Future<void> enqueue(PendingOp op) async {
    if (op.priority == OpPriority.emergency) {
      // Route to emergency fast lane
      await _emergencyQueue.enqueueEmergency(op);
      _telemetry.increment('priority_queue.enqueue.emergency');
    } else {
      // Normal queue with priority stored
      await _pendingBox.put(op.id, op);
      await _index.enqueue(op.id, op.createdAt.toUtc());
      _telemetry.increment('priority_queue.enqueue.${op.priority.name}');
    }
    
    _telemetry.gauge('priority_queue.total', totalPendingCount);
  }

  /// Get operations sorted by priority.
  ///
  /// Returns ops in order: emergency → high → normal → low
  /// Within each priority, maintains FIFO order.
  List<PendingOp> getOpsByPriority({int limit = 50}) {
    final allOps = _pendingBox.values.toList();
    
    // Sort by priority (lower value = higher priority), then by createdAt
    allOps.sort((a, b) {
      final priorityCompare = a.priority.value.compareTo(b.priority.value);
      if (priorityCompare != 0) return priorityCompare;
      return a.createdAt.compareTo(b.createdAt);
    });
    
    return allOps.take(limit).toList();
  }

  /// Process operations in priority order.
  ///
  /// Emergency ops are processed first via fast lane.
  /// Then high → normal → low from the main queue.
  Future<PriorityProcessResult> process({
    required Future<DeliveryAck?> Function(PendingOp op) handler,
    int batchSize = 10,
  }) async {
    if (_isProcessing) {
      return PriorityProcessResult.skipped('Already processing');
    }
    
    _isProcessing = true;
    final sw = Stopwatch()..start();
    
    int emergencyProcessed = 0;
    int highProcessed = 0;
    int normalProcessed = 0;
    int lowProcessed = 0;
    int failed = 0;
    
    try {
      // 1. Process emergency queue first (fast lane)
      emergencyProcessed = await _emergencyQueue.processAll((op) async {
        final ack = await handler(op);
        if (ack != null && ack.acknowledged) {
          await _safetyFallback.reportEmergencyOpResult(op, success: true);
          return true;
        } else {
          await _safetyFallback.reportEmergencyOpResult(op, success: false);
          return false;
        }
      });
      
      // 2. Process main queue by priority
      final ops = getOpsByPriority(limit: batchSize * 2);
      int processed = 0;
      
      for (final op in ops) {
        if (processed >= batchSize) break;
        
        // Skip ineligible ops (unless emergency - they bypass backoff)
        if (!op.isEligibleNow) continue;
        
        // Mark as sent
        final sentOp = op.copyWith(
          deliveryState: DeliveryState.sent,
          updatedAt: DateTime.now().toUtc(),
        );
        await _pendingBox.put(op.id, sentOp);
        
        try {
          final ack = await handler(op);
          
          if (ack != null && ack.acknowledged) {
            // Successfully acknowledged - delete
            await _pendingBox.delete(op.id);
            await _index.remove(op.id);
            
            switch (op.priority) {
              case OpPriority.emergency:
                emergencyProcessed++;
                break;
              case OpPriority.high:
                highProcessed++;
                break;
              case OpPriority.normal:
                normalProcessed++;
                break;
              case OpPriority.low:
                lowProcessed++;
                break;
            }
            
            processed++;
          } else {
            // Not acknowledged - revert to pending
            final pendingOp = op.copyWith(
              deliveryState: DeliveryState.pending,
              attempts: op.attempts + 1,
              lastTriedAt: DateTime.now().toUtc(),
              updatedAt: DateTime.now().toUtc(),
            );
            await _pendingBox.put(op.id, pendingOp);
            failed++;
          }
        } catch (e) {
          // Error - revert to pending with error
          final errorOp = op.copyWith(
            deliveryState: DeliveryState.pending,
            attempts: op.attempts + 1,
            lastError: e.toString(),
            lastTriedAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          );
          await _pendingBox.put(op.id, errorOp);
          failed++;
        }
      }
    } finally {
      _isProcessing = false;
      sw.stop();
    }
    
    final total = emergencyProcessed + highProcessed + normalProcessed + lowProcessed;
    
    _telemetry.gauge('priority_queue.processed.emergency', emergencyProcessed);
    _telemetry.gauge('priority_queue.processed.high', highProcessed);
    _telemetry.gauge('priority_queue.processed.normal', normalProcessed);
    _telemetry.gauge('priority_queue.processed.low', lowProcessed);
    _telemetry.gauge('priority_queue.processed.total', total);
    _telemetry.gauge('priority_queue.failed', failed);
    _telemetry.gauge('priority_queue.duration_ms', sw.elapsedMilliseconds);
    
    return PriorityProcessResult(
      emergencyProcessed: emergencyProcessed,
      highProcessed: highProcessed,
      normalProcessed: normalProcessed,
      lowProcessed: lowProcessed,
      failed: failed,
      durationMs: sw.elapsedMilliseconds,
    );
  }

  /// Confirm delivery acknowledgement for an operation.
  ///
  /// Called when server confirms receipt with idempotency key.
  /// This is the only way an op should be deleted.
  Future<bool> confirmDelivery(String opId, DeliveryAck ack) async {
    final op = _pendingBox.get(opId);
    if (op == null) return false;
    
    if (ack.acknowledged && ack.idempotencyKey == op.idempotencyKey) {
      // Valid acknowledgement - delete op
      await _pendingBox.delete(opId);
      await _index.remove(opId);
      
      _telemetry.increment('priority_queue.delivery_confirmed');
      return true;
    }
    
    return false;
  }

  /// Get count of pending ops by priority.
  Map<OpPriority, int> get pendingCountByPriority {
    final counts = <OpPriority, int>{
      OpPriority.emergency: _emergencyQueue.pendingCount,
      OpPriority.high: 0,
      OpPriority.normal: 0,
      OpPriority.low: 0,
    };
    
    for (final op in _pendingBox.values) {
      counts[op.priority] = (counts[op.priority] ?? 0) + 1;
    }
    
    return counts;
  }

  /// Get total pending count across all priorities.
  int get totalPendingCount {
    return _emergencyQueue.pendingCount + _pendingBox.length;
  }

  /// Get the safety fallback service.
  SafetyFallbackService get safetyFallback => _safetyFallback;

  /// Get the emergency queue service.
  EmergencyQueueService get emergencyQueue => _emergencyQueue;

  /// Report network state (propagates to safety fallback).
  Future<void> reportNetworkState({required bool isAvailable}) async {
    await _safetyFallback.reportNetworkState(isAvailable: isAvailable);
  }

  /// Dispose resources.
  void dispose() {
    _emergencyQueue.dispose();
    _safetyFallback.dispose();
  }
}

/// Result of priority queue processing.
class PriorityProcessResult {
  final int emergencyProcessed;
  final int highProcessed;
  final int normalProcessed;
  final int lowProcessed;
  final int failed;
  final int durationMs;
  final String? skipReason;
  
  const PriorityProcessResult({
    this.emergencyProcessed = 0,
    this.highProcessed = 0,
    this.normalProcessed = 0,
    this.lowProcessed = 0,
    this.failed = 0,
    this.durationMs = 0,
    this.skipReason,
  });
  
  factory PriorityProcessResult.skipped(String reason) => PriorityProcessResult(
    skipReason: reason,
  );
  
  int get totalProcessed => 
      emergencyProcessed + highProcessed + normalProcessed + lowProcessed;
  
  bool get wasSkipped => skipReason != null;
  
  @override
  String toString() => wasSkipped
      ? 'PriorityProcessResult(skipped: $skipReason)'
      : 'PriorityProcessResult(emergency: $emergencyProcessed, high: $highProcessed, '
        'normal: $normalProcessed, low: $lowProcessed, failed: $failed, '
        'duration: ${durationMs}ms)';
}
