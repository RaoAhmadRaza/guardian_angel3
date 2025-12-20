import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import 'api_client.dart';
import 'pending_queue_service.dart';
import 'op_router.dart';
import 'processing_lock.dart';
import 'backoff_policy.dart';
import 'exceptions.dart';
import 'models/pending_op.dart';
import 'circuit_breaker.dart';
import 'reconciler.dart';
import 'optimistic_store.dart';
import 'batch_coalescer.dart';
import 'metrics/telemetry.dart';
import 'realtime_service.dart';

/// Sync Engine - FIFO operation processor
/// 
/// Core responsibilities:
/// - Process pending operations in FIFO order
/// - Handle retries with exponential backoff
/// - Respect single processor guarantee via lock
/// - React to network connectivity changes
/// 
/// Phase 3 enhancements:
/// - Circuit breaker for API protection
/// - Conflict reconciliation for 409 responses
/// - Optimistic updates with rollback
/// - Batch coalescing for optimization
/// - Comprehensive telemetry
/// - Real-time WebSocket fallback
class SyncEngine {
  final ApiClient api;
  final PendingQueueService queue;
  final OpRouter router;
  final ProcessingLock lock;
  final BackoffPolicy backoffPolicy;
  final CircuitBreaker circuitBreaker;
  final Reconciler reconciler;
  final OptimisticStore optimisticStore;
  final BatchCoalescer coalescer;
  final SyncMetrics metrics;
  final RealtimeService? realtimeService;

  bool _isRunning = false;
  String? _runnerId;
  StreamSubscription<ConnectivityResult>? _connSub;
  StreamSubscription<Map<String, dynamic>>? _realtimeSub;
  Timer? _heartbeatTimer;
  Timer? _processTimer;

  SyncEngine({
    required this.api,
    required this.queue,
    required this.router,
    required this.lock,
    required this.backoffPolicy,
    required this.circuitBreaker,
    required this.reconciler,
    required this.optimisticStore,
    required this.coalescer,
    required this.metrics,
    this.realtimeService,
  });

  /// Start the sync engine
  /// 
  /// Acquires processing lock and begins FIFO processing loop
  Future<void> start() async {
    if (_isRunning) return;

    _runnerId = DateTime.now().millisecondsSinceEpoch.toString();

    final acquired = await lock.tryAcquire(_runnerId!);
    if (!acquired) {
      print('[SyncEngine] Could not acquire lock (another processor active)');
      return;
    }

    _isRunning = true;
    print('[SyncEngine] Started with runner ID: $_runnerId');

    _startHeartbeat();
    _startConnectivityListener();
    _startRealtimeListener();
    _scheduleProcessing();
  }

  /// Stop the sync engine
  Future<void> stop() async {
    if (!_isRunning) return;

    _isRunning = false;
    await _connSub?.cancel();
    await _realtimeSub?.cancel();
    _heartbeatTimer?.cancel();
    _processTimer?.cancel();

    if (_runnerId != null) {
      await lock.release(_runnerId!);
      print('[SyncEngine] Stopped');
    }

    // Print final metrics summary
    metrics.printSummary();
  }

  /// Start heartbeat timer to keep lock alive
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) async {
        if (_runnerId != null && _isRunning) {
          await lock.updateHeartbeat(_runnerId!);
        }
      },
    );
  }

  /// Listen to connectivity changes and trigger processing
  void _startConnectivityListener() {
    _connSub = Connectivity().onConnectivityChanged.listen((result) {
      if (!_isRunning) return;

      final hasConnectivity = result != ConnectivityResult.none;
      if (hasConnectivity) {
        print('[SyncEngine] Connectivity restored, triggering processing');
        _scheduleProcessing();
      }
    });
  }

  /// Listen to real-time updates (WebSocket)
  void _startRealtimeListener() {
    if (realtimeService == null) return;

    // Listen to connection state
    realtimeService!.connectionState.listen((connected) {
      if (connected) {
        print('[SyncEngine] Real-time connection established');
      } else {
        print('[SyncEngine] Real-time connection lost, using polling');
      }
    });

    // Listen to incoming messages
    _realtimeSub = realtimeService!.messages.listen((message) {
      if (!_isRunning) return;

      print('[SyncEngine] Real-time update: ${message['type']}');

      // Trigger processing on relevant events
      if (message['type'] == 'sync_required' ||
          message['type'] == 'entity_updated' ||
          message['type'] == 'conflict_resolved') {
        _scheduleProcessing();
      }
    });
  }

  /// Schedule processing (debounced)
  void _scheduleProcessing() {
    _processTimer?.cancel();
    _processTimer = Timer(const Duration(milliseconds: 100), () {
      _processLoop();
    });
  }

  /// Main processing loop (FIFO)
  Future<void> _processLoop() async {
    if (!_isRunning) return;

    while (_isRunning) {
      // Check circuit breaker before processing
      if (circuitBreaker.isTripped()) {
        final cooldown = circuitBreaker.getCooldownRemaining();
        if (cooldown != null) {
          print('[SyncEngine] Circuit breaker tripped, waiting ${cooldown.inSeconds}s');
          _processTimer = Timer(cooldown, _processLoop);
          break;
        }
      }

      final pending = await queue.getOldest();
      if (pending == null) {
        // Queue empty
        break;
      }

      // Record queue depth metric
      final queueDepth = await queue.count();
      metrics.recordQueueDepth(queueDepth);

      // Check if we should wait (backoff delay)
      final now = DateTime.now().toUtc();
      if (pending.nextAttemptAt != null &&
          pending.nextAttemptAt!.isAfter(now)) {
        // Not ready for retry yet, schedule wake-up
        final delay = pending.nextAttemptAt!.difference(now);
        _processTimer = Timer(delay, _processLoop);
        break;
      }

      // Ensure idempotency key exists
      if (pending.idempotencyKey.isEmpty) {
        pending.idempotencyKey = const Uuid().v4();
        await queue.update(pending);
      }

      // Process operation
      await _processOperation(pending);
    }
  }

  /// Process a single operation
  Future<void> _processOperation(PendingOp op) async {
    print('[SyncEngine] Processing: ${op.opType}::${op.entityType} (${op.id})');

    final stopwatch = Stopwatch()..start();

    try {
      // Resolve route
      final route = router.resolve(op.opType, op.entityType);

      // Build request
      final traceId = op.traceId ?? const Uuid().v4();
      final headers = {
        'Trace-Id': traceId,
        if (route.requiresIdempotency)
          'Idempotency-Key': op.idempotencyKey,
      };

      final body = route.transform?.call(op.payload) ?? op.payload;
      final path = route.pathBuilder(op.payload);

      // Execute request
      final response = await api.request(
        method: route.method,
        path: path,
        headers: headers,
        body: body,
      );

      stopwatch.stop();

      // Success: record metrics
      circuitBreaker.recordSuccess();
      metrics.recordSuccess(latencyMs: stopwatch.elapsedMilliseconds);

      // Commit optimistic update if present
      if (op.txnToken != null && op.txnToken!.isNotEmpty) {
        optimisticStore.commit(op.txnToken!);
      }

      // Remove from queue
      await queue.markProcessed(op.id);
      print('[SyncEngine] Success: ${op.id} (${stopwatch.elapsedMilliseconds}ms)');

      // Emit telemetry
      _emitSuccess(op, response);
    } on RetryableException catch (re) {
      stopwatch.stop();
      circuitBreaker.recordFailure();
      // Network error if no HTTP status (connection failure, timeout)
      final isNetworkError = re.httpStatus == null;
      metrics.recordFailure(isNetworkError: isNetworkError);
      
      // Transient error: schedule retry with backoff
      await _handleRetryableError(op, re);
    } on AuthException catch (ae) {
      stopwatch.stop();
      // Auth error: try refresh, then fail if unsuccessful
      await _handleAuthError(op, ae);
    } on ConflictException catch (ce) {
      stopwatch.stop();
      // Conflict: attempt reconciliation
      await _handleConflict(op, ce);
    } on ValidationException catch (ve) {
      stopwatch.stop();
      metrics.recordFailure();
      // Validation error: permanent failure
      await _handlePermanentError(op, ve);
    } on PermissionDeniedException catch (pe) {
      stopwatch.stop();
      metrics.recordFailure();
      // Permission denied: permanent failure
      await _handlePermanentError(op, pe);
    } on ResourceNotFoundException catch (rnf) {
      stopwatch.stop();
      metrics.recordFailure();
      // Resource not found: permanent failure
      await _handlePermanentError(op, rnf);
    } on ClientException catch (ce) {
      stopwatch.stop();
      metrics.recordFailure();
      // Other client error: permanent failure
      await _handlePermanentError(op, ce);
    } catch (e) {
      stopwatch.stop();
      metrics.recordFailure();
      // Unknown error: treat as permanent
      await queue.markFailed(
        op.id,
        {'reason': 'unknown_error', 'message': e.toString()},
        attempts: op.attempts,
      );
      print('[SyncEngine] Unknown error: $e');
      
      // Rollback optimistic update if present
      if (op.txnToken != null && op.txnToken!.isNotEmpty) {
        optimisticStore.rollback(op.txnToken!, errorMessage: e.toString());
      }
    }
  }

  /// Handle retryable errors (5xx, 429, network)
  Future<void> _handleRetryableError(
    PendingOp op,
    RetryableException re,
  ) async {
    op.attempts += 1;

    if (!backoffPolicy.shouldRetry(op.attempts)) {
      // Max attempts exhausted
      await queue.markFailed(
        op.id,
        {
          'reason': 'max_attempts_exhausted',
          'message': re.message,
          'http_status': re.httpStatus,
        },
        attempts: op.attempts,
      );
      print('[SyncEngine] Max attempts exhausted: ${op.id}');
      
      // Rollback optimistic update
      if (op.txnToken != null && op.txnToken!.isNotEmpty) {
        optimisticStore.rollback(op.txnToken!, 
          errorMessage: 'Max retry attempts exhausted');
      }
      return;
    }

    // Calculate backoff delay
    final delay = backoffPolicy.computeDelay(op.attempts, re.retryAfter);
    op.nextAttemptAt = DateTime.now().toUtc().add(delay);
    op.status = 'queued';

    await queue.update(op);

    // Record retry metrics
    metrics.recordRetry();

    print('[SyncEngine] Retry scheduled: ${op.id} '
        '(attempt ${op.attempts}, delay: ${delay.inSeconds}s)');

    // Emit telemetry
    _emitRetry(op, re, delay);
  }

  /// Handle auth errors (401)
  Future<void> _handleAuthError(PendingOp op, AuthException ae) async {
    final refreshed = await api.authService.tryRefresh();

    if (refreshed) {
      // Retry immediately after successful refresh
      print('[SyncEngine] Token refreshed, retrying: ${op.id}');
      metrics.recordRetry();
      await _processOperation(op);
    } else {
      // Refresh failed: move to failed ops
      await queue.markFailed(
        op.id,
        {
          'reason': 'auth_failed',
          'message': ae.message,
          'requires_login': ae.requiresLogin,
        },
        attempts: op.attempts,
      );
      print('[SyncEngine] Auth failed: ${op.id}');
      
      // Rollback optimistic update
      if (op.txnToken != null && op.txnToken!.isNotEmpty) {
        optimisticStore.rollback(op.txnToken!, errorMessage: 'Authentication failed');
      }
    }
  }

  /// Handle conflicts (409)
  Future<void> _handleConflict(PendingOp op, ConflictException ce) async {
    print('[SyncEngine] Conflict detected: ${op.id} - Attempting reconciliation');

    try {
      // Attempt automatic reconciliation
      final canRetry = await reconciler.reconcileConflict(op, ce);

      if (canRetry) {
        // Reconciliation successful, retry with merged payload
        print('[SyncEngine] Conflict reconciled: ${op.id} - Retrying');
        metrics.recordConflictResolved();
        metrics.recordRetry();
        
        // Update operation in queue with reconciled payload
        await queue.update(op);
        
        // Retry immediately
        await _processOperation(op);
      } else {
        // Reconciliation failed, mark as permanent failure
        await queue.markFailed(
          op.id,
          {
            'reason': 'conflict_unresolvable',
            'message': ce.message,
            'conflict_type': ce.conflictType,
            'server_version': ce.serverVersion,
            'client_version': ce.clientVersion,
          },
          attempts: op.attempts,
        );
        print('[SyncEngine] Conflict unresolvable: ${op.id}');
        
        // Rollback optimistic update
        if (op.txnToken != null && op.txnToken!.isNotEmpty) {
          optimisticStore.rollback(op.txnToken!, 
            errorMessage: 'Conflict could not be resolved');
        }
        
        // Emit conflict for UI notification
        _emitConflict(op, ce);
      }
    } catch (e) {
      // Reconciliation threw error, treat as permanent failure
      await queue.markFailed(
        op.id,
        {
          'reason': 'reconciliation_error',
          'message': 'Reconciliation failed: $e',
          'original_conflict': ce.message,
        },
        attempts: op.attempts,
      );
      print('[SyncEngine] Reconciliation error: ${op.id} - $e');
      
      // Rollback optimistic update
      if (op.txnToken != null && op.txnToken!.isNotEmpty) {
        optimisticStore.rollback(op.txnToken!, 
          errorMessage: 'Reconciliation failed');
      }
    }
  }

  /// Handle permanent errors (4xx validation, permission, not found)
  Future<void> _handlePermanentError(PendingOp op, SyncException error) async {
    await queue.markFailed(
      op.id,
      {
        'reason': 'permanent_error',
        'message': error.message,
        'http_status': error.httpStatus,
      },
      attempts: op.attempts,
    );
    print('[SyncEngine] Permanent error: ${op.id} - ${error.message}');

    // Rollback optimistic update
    if (op.txnToken != null && op.txnToken!.isNotEmpty) {
      optimisticStore.rollback(op.txnToken!, errorMessage: error.message);
    }

    // Emit telemetry
    _emitPermanentError(op, error);
  }

  /// Emit success telemetry
  void _emitSuccess(PendingOp op, Map<String, dynamic> response) {
    // Metrics already recorded in _processOperation
    // Additional app-specific telemetry can be added here
  }

  /// Emit retry telemetry
  void _emitRetry(PendingOp op, RetryableException error, Duration delay) {
    // Metrics already recorded in _handleRetryableError
    // Additional app-specific telemetry can be added here
  }

  /// Emit conflict telemetry
  void _emitConflict(PendingOp op, ConflictException error) {
    // Trigger conflict resolution UI notification
    // This can be implemented as a stream or callback
    print('[SyncEngine] Conflict requires manual resolution: ${op.id}');
  }

  /// Emit permanent error telemetry
  void _emitPermanentError(PendingOp op, SyncException error) {
    // Metrics already recorded
    // Additional app-specific telemetry can be added here
  }

  /// Enqueue a new operation with coalescing
  /// 
  /// Phase 3: Attempts to coalesce with existing operations before enqueuing
  Future<void> enqueue(PendingOp op) async {
    // Try to coalesce with existing operations
    final merged = await coalescer.tryCoalesce(op);
    
    if (merged != null) {
      print('[SyncEngine] Operation coalesced: ${op.opType}::${op.entityType}');
      // Merged into existing operation, no need to enqueue
      return;
    }

    // Remove superseded operations (e.g., DELETE removes pending UPDATEs)
    if (op.opType == 'DELETE') {
      await coalescer.removeSuperseded(op);
    }

    // Enqueue new operation
    await queue.enqueue(op);
    metrics.recordEnqueue();
    
    print('[SyncEngine] Operation enqueued: ${op.id}');
    
    // Trigger immediate processing
    _scheduleProcessing();
  }

  /// Get metrics summary
  Map<String, dynamic> getMetrics() {
    return metrics.getSummary();
  }

  /// Print metrics summary to console
  void printMetrics() {
    metrics.printSummary();
  }

  /// Check if engine is running
  bool get isRunning => _isRunning;

  /// Get current runner ID
  String? get runnerId => _runnerId;
}
