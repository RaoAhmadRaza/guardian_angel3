import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_angel_fyp/sync/circuit_breaker.dart';
import 'package:guardian_angel_fyp/sync/reconciler.dart';
import 'package:guardian_angel_fyp/sync/optimistic_store.dart';
import 'package:guardian_angel_fyp/sync/batch_coalescer.dart';
import 'package:guardian_angel_fyp/sync/metrics/telemetry.dart';
import 'package:guardian_angel_fyp/sync/models/pending_op.dart';

/// Phase 3 Integration Tests - Unit tests for Phase 3 components
/// 
/// These tests verify the integration of Phase 3 components without
/// requiring Hive initialization or full SyncEngine setup.

void main() {
  group('CircuitBreaker Integration', () {
    late CircuitBreaker breaker;

    setUp(() {
      breaker = CircuitBreaker(
        failureThreshold: 3,
        window: const Duration(seconds: 10),
        cooldown: const Duration(seconds: 5),
      );
    });

    test('Circuit breaker trips after threshold failures', () {
      expect(breaker.isTripped(), false);

      // Record failures
      breaker.recordFailure();
      breaker.recordFailure();
      expect(breaker.isTripped(), false);

      breaker.recordFailure();
      expect(breaker.isTripped(), true);

      final cooldown = breaker.getCooldownRemaining();
      expect(cooldown, isNotNull);
      expect(cooldown!.inSeconds, greaterThan(0));
    });

    test('Circuit breaker resets after successful request', () {
      breaker.recordFailure();
      breaker.recordFailure();
      breaker.recordSuccess();

      expect(breaker.isTripped(), false);
    });

    test('Circuit breaker cooldown expires', () async {
      // Record enough failures to trip
      for (int i = 0; i < 3; i++) {
        breaker.recordFailure();
      }
      expect(breaker.isTripped(), true);

      // Wait for cooldown
      await Future.delayed(const Duration(seconds: 6));
      
      expect(breaker.isTripped(), false);
    });
  });

  group('OptimisticStore Integration', () {
    late OptimisticStore store;

    setUp(() {
      store = OptimisticStore();
    });

    test('Register and commit transaction', () {
      var callbackExecuted = false;
      final originalState = {'value': 1};

      store.register(
        txnToken: 'txn-1',
        originalState: originalState,
        rollbackHandler: () {},
        onSuccess: () {
          callbackExecuted = true;
        },
      );

      expect(store.isPending('txn-1'), true);

      store.commit('txn-1');

      expect(store.isPending('txn-1'), false);
      expect(callbackExecuted, true);
    });

    test('Register and rollback transaction', () {
      var rollbackExecuted = false;
      var errorReceived = '';
      final originalState = {'value': 1};

      store.register(
        txnToken: 'txn-2',
        originalState: originalState,
        rollbackHandler: () {
          rollbackExecuted = true;
        },
        onError: (error) {
          errorReceived = error;
        },
      );

      store.rollback('txn-2', errorMessage: 'Test error');

      expect(store.isPending('txn-2'), false);
      expect(rollbackExecuted, true);
      expect(errorReceived, 'Test error');
    });

    test('Rollback all transactions', () {
      var rollback1 = false;
      var rollback2 = false;

      store.register(
        txnToken: 'txn-1',
        originalState: {},
        rollbackHandler: () { rollback1 = true; },
      );

      store.register(
        txnToken: 'txn-2',
        originalState: {},
        rollbackHandler: () { rollback2 = true; },
      );

      expect(store.getPendingTransactions().length, 2);

      store.rollbackAll();

      expect(store.getPendingTransactions().length, 0);
      expect(rollback1, true);
      expect(rollback2, true);
    });
  });

  group('SyncMetrics Integration', () {
    late SyncMetrics metrics;

    setUp(() {
      metrics = SyncMetrics();
    });

    test('Record operation lifecycle', () {
      metrics.recordEnqueue();
      metrics.recordSuccess(latencyMs: 250);

      final summary = metrics.getSummary();
      final ops = summary['operations'] as Map;

      expect(ops['enqueued'], 1);
      expect(ops['processed'], 1);
      expect(ops['failed'], 0);
      expect(ops['success_rate'], 100.0);
    });

    test('Calculate success rate correctly', () {
      metrics.recordEnqueue();
      metrics.recordEnqueue();
      metrics.recordEnqueue();

      metrics.recordSuccess(latencyMs: 100);
      metrics.recordSuccess(latencyMs: 150);
      metrics.recordFailure();

      final summary = metrics.getSummary();
      final ops = summary['operations'] as Map;

      expect(ops['enqueued'], 3);
      expect(ops['processed'], 3);
      expect(ops['success_rate'], closeTo(66.7, 0.1));
    });

    test('Track latency metrics', () {
      metrics.recordSuccess(latencyMs: 100);
      metrics.recordSuccess(latencyMs: 200);
      metrics.recordSuccess(latencyMs: 300);
      metrics.recordSuccess(latencyMs: 400);
      metrics.recordSuccess(latencyMs: 500);

      final summary = metrics.getSummary();
      final latency = summary['latency'] as Map;

      expect(latency['avg_ms'], 300);
      expect(latency['p95_ms'], greaterThan(400));
    });

    test('Track queue depth', () {
      metrics.recordQueueDepth(5);
      metrics.recordQueueDepth(10);
      metrics.recordQueueDepth(3);

      final summary = metrics.getSummary();
      final queue = summary['queue'] as Map;

      expect(queue['current_depth'], 3);
      expect(queue['avg_depth'], 6);
      expect(queue['peak_depth'], 10);
    });

    test('Calculate network health score', () {
      // All successful - 100% health
      for (int i = 0; i < 10; i++) {
        metrics.recordSuccess(latencyMs: 100);
      }

      var summary = metrics.getSummary();
      var network = summary['network'] as Map;
      expect(network['health_score'], 100);

      // Half failures - lower health
      for (int i = 0; i < 10; i++) {
        metrics.recordFailure(isNetworkError: true);
      }

      summary = metrics.getSummary();
      network = summary['network'] as Map;
      expect(network['health_score'], lessThan(60));
    });

    test('Record specialized events', () {
      metrics.recordRetry();
      metrics.recordConflictResolved();
      metrics.recordLockTakeover();
      metrics.recordCircuitBreakerTrip();

      final summary = metrics.getSummary();
      final ops = summary['operations'] as Map;

      expect(ops['retries'], 1);
      expect(ops['conflicts_resolved'], 1);
    });
  });

  group('Phase 3 Integration - Full Workflow', () {
    test('Optimistic update with circuit breaker protection', () async {
      final breaker = CircuitBreaker(failureThreshold: 2);
      final store = OptimisticStore();
      final metrics = SyncMetrics();

      var uiState = 'off';
      final txnToken = 'txn-optimistic-1';

      // Register optimistic update
      store.register(
        txnToken: txnToken,
        originalState: {'state': 'off'},
        rollbackHandler: () {
          uiState = 'off';
        },
        onSuccess: () {
          // Success callback
        },
      );

      // Apply optimistic update
      uiState = 'on';
      metrics.recordEnqueue();

      // Simulate successful processing
      if (!breaker.isTripped()) {
        breaker.recordSuccess();
        metrics.recordSuccess(latencyMs: 150);
        store.commit(txnToken);

        expect(uiState, 'on');
        expect(store.isPending(txnToken), false);
      }
    });

    test('Circuit breaker prevents processing during failure storm', () {
      final breaker = CircuitBreaker(failureThreshold: 2);
      final metrics = SyncMetrics();

      // Simulate failure storm
      breaker.recordFailure();
      metrics.recordFailure();
      breaker.recordFailure();
      metrics.recordFailure();

      expect(breaker.isTripped(), true);

      // Should not process new operations
      if (breaker.isTripped()) {
        final cooldown = breaker.getCooldownRemaining();
        expect(cooldown, isNotNull);
        expect(cooldown!.inSeconds, greaterThan(0));
      }

      final summary = metrics.getSummary();
      final network = summary['network'] as Map;
      expect(network['health_score'], lessThan(50));
    });

    test('Metrics track complete operation lifecycle', () {
      final metrics = SyncMetrics();

      // Operation 1: Success
      metrics.recordEnqueue();
      metrics.recordSuccess(latencyMs: 100);

      // Operation 2: Retry then success
      metrics.recordEnqueue();
      metrics.recordFailure(isNetworkError: true);
      metrics.recordRetry();
      metrics.recordSuccess(latencyMs: 200);

      // Operation 3: Conflict resolved
      metrics.recordEnqueue();
      metrics.recordConflictResolved();
      metrics.recordRetry();
      metrics.recordSuccess(latencyMs: 150);

      final summary = metrics.getSummary();
      final ops = summary['operations'] as Map;

      expect(ops['enqueued'], 3);
      expect(ops['processed'], 4); // 1 + 2 + 1
      expect(ops['retries'], 2);
      expect(ops['conflicts_resolved'], 1);
      expect(ops['success_rate'], 75.0); // 3 successes / 4 processed
    });
  });

  group('Error Recovery Scenarios', () {
    test('Rollback on max retry attempts', () async {
      final store = OptimisticStore();
      var rollbackCalled = false;
      var errorMessage = '';

      store.register(
        txnToken: 'txn-retry',
        originalState: {'value': 1},
        rollbackHandler: () {
          rollbackCalled = true;
        },
        onError: (error) {
          errorMessage = error;
        },
      );

      // Simulate max retries exhausted
      store.rollback('txn-retry', errorMessage: 'Max retry attempts exhausted');

      expect(rollbackCalled, true);
      expect(errorMessage, contains('Max retry'));
    });

    test('Circuit breaker recovery after cooldown', () async {
      final breaker = CircuitBreaker(
        failureThreshold: 2,
        cooldown: const Duration(milliseconds: 100),
      );

      // Trip the breaker
      breaker.recordFailure();
      breaker.recordFailure();
      expect(breaker.isTripped(), true);

      // Wait for cooldown
      await Future.delayed(const Duration(milliseconds: 150));

      // Should be reset
      expect(breaker.isTripped(), false);

      // Can record new success
      breaker.recordSuccess();
      expect(breaker.isTripped(), false);
    });

    test('Multiple optimistic updates rollback correctly', () {
      final store = OptimisticStore();
      final rollbackStates = <String>[];

      // Register multiple transactions
      store.register(
        txnToken: 'txn-1',
        originalState: {'id': '1'},
        rollbackHandler: () => rollbackStates.add('1'),
      );

      store.register(
        txnToken: 'txn-2',
        originalState: {'id': '2'},
        rollbackHandler: () => rollbackStates.add('2'),
      );

      store.register(
        txnToken: 'txn-3',
        originalState: {'id': '3'},
        rollbackHandler: () => rollbackStates.add('3'),
      );

      // Rollback all
      store.rollbackAll();

      expect(rollbackStates.length, 3);
      expect(rollbackStates, containsAll(['1', '2', '3']));
    });
  });
}
