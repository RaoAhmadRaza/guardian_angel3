import 'dart:async';
import 'package:hive/hive.dart';
import '../../models/pending_op.dart';
import '../../models/failed_op_model.dart';
import '../../sync/sync_consumer.dart';
import '../../sync/failure_classifier.dart';
import '../index/pending_index.dart';
import '../locking/processing_lock.dart';
import '../transactions/atomic_transaction.dart';
import '../wrappers/hive_wrapper.dart';
import '../box_registry.dart';
import '../../services/telemetry_service.dart';
import 'backoff.dart';
import 'queue_state.dart';
import 'idempotency_cache.dart';
import 'entity_ordering.dart';
import 'op_priority.dart';
import 'emergency_queue_service.dart';
import 'safety_fallback_service.dart';

/// Maximum retry attempts before an op becomes "poison" and is moved to failed.
const int maxAttempts = 7;

/// High-level queue service for pending operations providing atomic enqueue,
/// FIFO dequeue and processing under a persistent lock to prevent concurrent
/// runners. Intended for background sync.
///
/// Features:
/// - Exponential backoff for failed operations
/// - Poison op detection (ops that always fail)
/// - State machine to prevent re-entrancy
/// - Skip ineligible ops (not ready for retry)
/// - Idempotency enforcement (duplicate prevention)
/// - SyncConsumer integration for sync abstraction
/// - Failure classification for intelligent retry
/// - Entity ordering (per-entity FIFO processing)
/// - Priority-based processing (emergency → high → normal → low)
/// - Emergency fast lane for critical operations
/// - Delivery acknowledgement tracking
/// - Safety fallback for network blackouts
class PendingQueueService {
  final PendingIndex _index;
  final Box<PendingOp> _pendingBox;
  final Box<FailedOpModel>? _failedBox;
  final ProcessingLock _lock;
  final IdempotencyCache _idempotencyCache;
  final EntityOrderingService _entityOrdering;
  
  /// Emergency queue for fast lane processing.
  final EmergencyQueueService? _emergencyQueue;
  
  /// Safety fallback service for network blackout scenarios.
  final SafetyFallbackService? _safetyFallback;
  
  /// Optional sync consumer. If null, uses the handler function directly.
  SyncConsumer? _syncConsumer;

  /// Current state of the queue processor.
  QueueState _state = QueueState.idle;

  /// Get current queue state.
  QueueState get state => _state;

  /// Stream controller for state changes.
  final _stateController = StreamController<QueueState>.broadcast();

  /// Stream of state changes for observability.
  Stream<QueueState> get stateStream => _stateController.stream;

  PendingQueueService._(
    this._index,
    this._pendingBox,
    this._failedBox,
    this._lock,
    this._idempotencyCache,
    this._entityOrdering,
    this._emergencyQueue,
    this._safetyFallback,
  );

  static Future<PendingQueueService> create() async {
    final index = await PendingIndex.create();
    final lock = await ProcessingLock.create();
    final pendingBox = Hive.box<PendingOp>(BoxRegistry.pendingOpsBox);
    final idempotencyCache = await IdempotencyCache.create();
    
    // Initialize entity ordering service
    final entityOrdering = EntityOrderingService();
    await entityOrdering.init();
    
    // Initialize emergency queue service
    final emergencyQueue = EmergencyQueueService();
    await emergencyQueue.init();
    
    // Initialize safety fallback service
    final safetyFallback = SafetyFallbackService();
    await safetyFallback.init();
    
    // Open failed ops box if not already open
    Box<FailedOpModel>? failedBox;
    try {
      if (Hive.isBoxOpen(BoxRegistry.failedOpsBox)) {
        failedBox = Hive.box<FailedOpModel>(BoxRegistry.failedOpsBox);
      }
    } catch (_) {
      // Failed box may not be available
    }
    
    return PendingQueueService._(
      index, 
      pendingBox, 
      failedBox, 
      lock, 
      idempotencyCache, 
      entityOrdering,
      emergencyQueue,
      safetyFallback,
    );
  }
  
  /// Get the emergency queue service.
  EmergencyQueueService? get emergencyQueue => _emergencyQueue;
  
  /// Get the safety fallback service.
  SafetyFallbackService? get safetyFallback => _safetyFallback;
  
  /// Set the sync consumer for processing operations.
  /// 
  /// When a sync consumer is set, the queue will use it instead of
  /// the handler function for processing operations.
  void setSyncConsumer(SyncConsumer consumer) {
    _syncConsumer = consumer;
  }

  /// Update state and emit to stream.
  void _setState(QueueState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
      TelemetryService.I.gauge('queue.state', newState.index);
    }
  }

  /// Enqueue a new operation with atomic multi-box write.
  /// 
  /// Includes idempotency check - duplicate operations are silently ignored.
  /// Uses AtomicTransaction for crash-safe writes across pending_ops and index.
  /// 
  /// Returns true if the op was enqueued, false if it was a duplicate.
  Future<bool> enqueue(PendingOp op) async {
    // Check idempotency - prevent duplicate enqueue
    final idempotencyKey = op.id; // Use op ID as idempotency key
    if (_idempotencyCache.contains(idempotencyKey)) {
      TelemetryService.I.increment('enqueue.duplicate_rejected');
      return false;
    }
    
    // Route emergency ops to fast lane
    final emergencyQueue = _emergencyQueue;
    if (op.priority == OpPriority.emergency && emergencyQueue != null) {
      await emergencyQueue.enqueueEmergency(op);
      await _idempotencyCache.record(idempotencyKey);
      TelemetryService.I.increment('enqueue.emergency');
      return true;
    }
    
    // Use atomic transaction for crash-safe multi-box write
    await AtomicTransaction.executeOrThrow(
      operationName: 'pending_queue.enqueue',
      builder: (txn) async {
        await txn.write(_pendingBox, op.id, op);
        // Index is updated separately as it manages its own box
        await _index.enqueue(op.id, op.createdAt.toUtc());
      },
    );
    
    // Record in idempotency cache
    await _idempotencyCache.record(idempotencyKey);
    
    TelemetryService.I.gauge('pending_ops.count', _pendingBox.length);
    TelemetryService.I.increment('enqueue.count');
    TelemetryService.I.increment('enqueue.priority.${op.priority.name}');
    return true;
  }
  
  /// Report network availability (propagates to safety fallback).
  Future<void> reportNetworkState({required bool isAvailable}) async {
    await _safetyFallback?.reportNetworkState(isAvailable: isAvailable);
  }

  /// Process up to [batchSize] oldest operations invoking [handler].
  /// 
  /// Features:
  /// - Skips ops not eligible for retry (backoff not elapsed)
  /// - Applies exponential backoff on failure
  /// - Moves poison ops (>7 attempts) to failed box
  /// - Uses state machine to prevent re-entrancy
  /// - Uses SyncConsumer if set, otherwise falls back to handler
  /// - Classifies failures for intelligent retry decisions
  /// - Entity ordering (per-entity FIFO, only one in-flight per entity)
  /// - Priority-based processing order
  /// 
  /// Returns number of operations successfully processed.
  Future<int> process({
    Future<void> Function(PendingOp op)? handler,
    int batchSize = 10,
  }) async {
    // Require either a handler or a sync consumer
    if (handler == null && _syncConsumer == null) {
      throw StateError('Either handler or syncConsumer must be set');
    }
    
    // Check state machine - prevent re-entrancy
    if (!_state.canStartProcessing) {
      TelemetryService.I.increment('queue.process.skipped_not_idle');
      return 0;
    }

    final pid = _generatePid();
    final acquired = await _lock.tryAcquire(pid);
    if (acquired == null) {
      _setState(QueueState.blocked);
      TelemetryService.I.increment('queue.process.blocked');
      return 0;
    }

    _setState(QueueState.processing);
    
    // Call sync consumer lifecycle hook
    await _syncConsumer?.onQueueStart();
    
    int processed = 0;
    int skipped = 0;
    int poisoned = 0;
    int entityBlocked = 0;
    final sw = Stopwatch()..start();

    try {
      // Cleanup old idempotency entries and expired entity locks
      await _idempotencyCache.cleanup();
      await _entityOrdering.cleanupExpiredLocks();
      
      await _index.integrityCheckAndRebuild();
      var ops = await _index.getOldest(batchSize * 2); // Fetch extra to handle skips
      
      // Sort by priority (emergency → high → normal → low)
      ops = _sortByPriority(ops);

      for (final op in ops) {
        if (processed >= batchSize) break;

        // Check if op is eligible for processing (backoff elapsed)
        // Note: Emergency ops bypass backoff via isEligibleNow getter
        if (!op.isEligibleNow) {
          skipped++;
          TelemetryService.I.increment('queue.op.skipped_backoff');
          continue;
        }

        // Check for poison op threshold
        if (op.attempts >= maxAttempts) {
          await _moveToPoisonOps(op);
          poisoned++;
          continue;
        }
        
        // Check entity ordering - only one in-flight op per entity
        if (!await _entityOrdering.tryAcquire(op)) {
          entityBlocked++;
          TelemetryService.I.increment('queue.op.entity_blocked');
          continue;
        }

        try {
          // Use sync consumer if available, otherwise use handler
          if (_syncConsumer != null) {
            final result = await _syncConsumer!.process(op);
            if (result.isSuccess) {
              await _markProcessed(op);
              await _entityOrdering.release(op);
              processed++;
            } else {
              await _handleSyncFailure(op, result);
              await _entityOrdering.release(op);
            }
          } else {
            await handler!(op);
            await _markProcessed(op);
            await _entityOrdering.release(op);
            processed++;
          }
          TelemetryService.I.increment('processed_ops.count');
        } catch (e, stackTrace) {
          await _handleFailure(op, e, stackTrace);
          await _entityOrdering.release(op);
        }
      }
    } catch (e) {
      _setState(QueueState.error);
      TelemetryService.I.increment('queue.process.error');
      rethrow;
    } finally {
      // Call sync consumer lifecycle hook
      await _syncConsumer?.onQueueEnd();
      
      await _lock.release(pid);
      if (_state != QueueState.error) {
        _setState(QueueState.idle);
      }
    }

    sw.stop();
    TelemetryService.I.gauge('pending_ops.count', _pendingBox.length);
    TelemetryService.I.gauge('process.last_duration_ms', sw.elapsedMilliseconds);
    TelemetryService.I.gauge('queue.last_processed', processed);
    TelemetryService.I.gauge('queue.last_skipped', skipped);
    TelemetryService.I.gauge('queue.last_poisoned', poisoned);
    TelemetryService.I.gauge('queue.last_entity_blocked', entityBlocked);

    return processed;
  }
  
  /// Mark an operation as successfully processed.
  Future<void> _markProcessed(PendingOp op) async {
    await AtomicTransaction.executeOrThrow(
      operationName: 'pending_queue.mark_processed',
      builder: (txn) async {
        await txn.delete(_pendingBox, op.id);
        await _index.remove(op.id);
      },
    );
  }
  
  /// Handle a sync result failure.
  Future<void> _handleSyncFailure(PendingOp op, SyncResult result) async {
    final newAttempts = op.attempts + 1;
    
    // Check if this is a permanent failure - move to failed immediately
    if (!result.shouldRetry) {
      final failedOp = FailedOpModel.fromPendingOp(
        op,
        errorCode: result.failureType?.name.toUpperCase() ?? 'UNKNOWN',
        errorMessage: result.errorMessage ?? 'Unknown failure',
      );
      
      await AtomicTransaction.executeOrThrow(
        operationName: 'pending_queue.sync_permanent_failure',
        builder: (txn) async {
          if (_failedBox != null) {
            await txn.write(_failedBox, failedOp.id, failedOp);
          }
          await txn.delete(_pendingBox, op.id);
          await _index.remove(op.id);
        },
      );
      
      TelemetryService.I.increment('queue.permanent_failure.${result.failureType?.name}');
      
      // Check if auth is required - pause queue
      if (result.failureType == FailureType.auth) {
        _setState(QueueState.paused);
        TelemetryService.I.increment('queue.paused_for_auth');
      }
      
      return;
    }
    
    // Transient failure - apply backoff
    final nextEligible = computeNextEligibleAt(newAttempts);
    final backoffDuration = computeBackoff(newAttempts);

    final updatedOp = op.copyWith(
      attempts: newAttempts,
      lastError: result.errorMessage ?? 'Sync failed',
      lastTriedAt: DateTime.now().toUtc(),
      nextEligibleAt: nextEligible,
      status: 'retry',
      updatedAt: DateTime.now().toUtc(),
    );

    await _pendingBox.put(op.id, updatedOp);

    TelemetryService.I.increment('failed_ops.count');
    TelemetryService.I.increment('failed_ops.transient');
    TelemetryService.I.gauge('failed_ops.last_attempts', newAttempts);
    TelemetryService.I.gauge('failed_ops.last_backoff_seconds', backoffDuration.inSeconds);
  }

  /// Handle a failed operation with backoff and failure classification.
  Future<void> _handleFailure(PendingOp op, Object error, [StackTrace? stackTrace]) async {
    // Classify the failure
    final classification = FailureClassifier.classify(error, stackTrace);
    
    // If permanent failure, move to failed ops immediately
    if (!classification.shouldRetry) {
      final failedOp = FailedOpModel.fromPendingOp(
        op,
        errorCode: classification.type.name.toUpperCase(),
        errorMessage: classification.technicalMessage,
      );
      
      await AtomicTransaction.executeOrThrow(
        operationName: 'pending_queue.classified_permanent_failure',
        builder: (txn) async {
          if (_failedBox != null) {
            await txn.write(_failedBox, failedOp.id, failedOp);
          }
          await txn.delete(_pendingBox, op.id);
          await _index.remove(op.id);
        },
      );
      
      TelemetryService.I.increment('queue.permanent_failure.${classification.type.name}');
      
      // Check if auth is required - pause queue
      if (classification.requiresAuth) {
        _setState(QueueState.paused);
        TelemetryService.I.increment('queue.paused_for_auth');
      }
      
      return;
    }
    
    // Transient failure - apply backoff
    final newAttempts = op.attempts + 1;
    final nextEligible = computeNextEligibleAt(newAttempts);
    final backoffDuration = computeBackoff(newAttempts);

    final updatedOp = op.copyWith(
      attempts: newAttempts,
      lastError: classification.technicalMessage,
      lastTriedAt: DateTime.now().toUtc(),
      nextEligibleAt: nextEligible,
      status: 'retry',
      updatedAt: DateTime.now().toUtc(),
    );

    await _pendingBox.put(op.id, updatedOp);

    TelemetryService.I.increment('failed_ops.count');
    TelemetryService.I.increment('failed_ops.by_type.${op.opType}');
    TelemetryService.I.increment('failed_ops.by_classification.${classification.type.name}');
    TelemetryService.I.gauge('failed_ops.last_attempts', newAttempts);
    TelemetryService.I.gauge('failed_ops.last_backoff_seconds', backoffDuration.inSeconds);
  }

  /// Move a poison op to the failed ops box.
  Future<void> _moveToPoisonOps(PendingOp op) async {
    final failedOp = FailedOpModel.fromPendingOp(
      op,
      errorCode: 'POISON_OP',
      errorMessage: 'Exceeded max attempts ($maxAttempts): ${op.lastError}',
    );

    await AtomicTransaction.executeOrThrow(
      operationName: 'pending_queue.move_to_poison',
      builder: (txn) async {
        // Add to failed box if available
        if (_failedBox != null) {
          await txn.write(_failedBox, failedOp.id, failedOp);
        }
        // Remove from pending
        await txn.delete(_pendingBox, op.id);
        await _index.remove(op.id);
      },
    );

    TelemetryService.I.increment('queue.poison_ops.count');
    TelemetryService.I.increment('queue.poison_ops.by_type.${op.opType}');

    // Log for audit
    // ignore: avoid_print
    print('[PendingQueueService] POISON OP: ${op.id} (${op.opType}) '
        'after ${op.attempts} attempts. Last error: ${op.lastError}');
  }

  /// Get count of ops currently in backoff (not eligible).
  int get backoffCount {
    int count = 0;
    for (final op in _pendingBox.values) {
      if (!op.isEligibleNow) count++;
    }
    return count;
  }

  /// Get count of ops that are poison candidates (high attempt count).
  int get nearPoisonCount {
    int count = 0;
    for (final op in _pendingBox.values) {
      if (op.attempts >= maxAttempts - 2) count++;
    }
    return count;
  }

  Future<void> rebuildIndex() => _index.rebuild();

  String _generatePid() => DateTime.now().microsecondsSinceEpoch.toString();
  
  /// Sort operations by priority (emergency → high → normal → low).
  /// Within each priority level, maintains original order (FIFO).
  List<PendingOp> _sortByPriority(List<PendingOp> ops) {
    // Stable sort by priority value
    final sorted = List<PendingOp>.from(ops);
    sorted.sort((a, b) => a.priority.value.compareTo(b.priority.value));
    return sorted;
  }
  
  /// Get pending ops count by priority level.
  Map<OpPriority, int> get pendingCountByPriority {
    final counts = <OpPriority, int>{
      OpPriority.emergency: _emergencyQueue?.pendingCount ?? 0,
      OpPriority.high: 0,
      OpPriority.normal: 0,
      OpPriority.low: 0,
    };
    
    for (final op in _pendingBox.values) {
      counts[op.priority] = (counts[op.priority] ?? 0) + 1;
    }
    
    return counts;
  }
  
  /// Get total pending count including emergency queue.
  int get totalPendingCount {
    return (_emergencyQueue?.pendingCount ?? 0) + _pendingBox.length;
  }
  
  /// Resume the queue from paused state.
  /// 
  /// Call this after re-authentication to resume processing.
  void resume() {
    if (_state == QueueState.paused) {
      _setState(QueueState.idle);
      TelemetryService.I.increment('queue.resumed');
    }
  }
  
  /// Pause the queue.
  /// 
  /// Call this to temporarily stop processing (e.g., when going offline).
  void pause() {
    if (_state == QueueState.idle) {
      _setState(QueueState.paused);
      TelemetryService.I.increment('queue.paused');
    }
  }
  
  /// Get the count of entities currently locked for processing.
  int get lockedEntityCount => _entityOrdering.lockCount;
  
  /// Get the set of currently locked entity keys.
  Set<String> get lockedEntities => _entityOrdering.lockedEntities;
  
  /// Force release all entity locks (for emergency/testing).
  Future<void> releaseAllEntityLocks() => _entityOrdering.releaseAll();

  /// Dispose resources.
  void dispose() {
    _stateController.close();
    _emergencyQueue?.dispose();
    _safetyFallback?.dispose();
  }
}