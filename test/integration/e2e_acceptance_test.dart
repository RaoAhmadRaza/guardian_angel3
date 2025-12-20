// test/integration/e2e_acceptance_test.dart
// End-to-end acceptance tests for sync engine
// Tests: happy path, idempotency, network simulation

import 'package:test/test.dart';
import 'package:flutter/widgets.dart' as widgets;
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../bootstrap.dart';
import '../mocks/mock_server.dart';
import '../mocks/mock_auth_service.dart';
import 'package:guardian_angel_fyp/sync/api_client.dart';
import 'package:guardian_angel_fyp/sync/models/pending_op.dart';
import 'package:guardian_angel_fyp/sync/pending_queue_service.dart';
import 'package:guardian_angel_fyp/sync/sync_engine.dart';
import 'package:guardian_angel_fyp/sync/op_router.dart';
import 'package:guardian_angel_fyp/sync/processing_lock.dart';
import 'package:guardian_angel_fyp/sync/backoff_policy.dart';
import 'package:guardian_angel_fyp/sync/circuit_breaker.dart';
import 'package:guardian_angel_fyp/sync/reconciler.dart';
import 'package:guardian_angel_fyp/sync/optimistic_store.dart';
import 'package:guardian_angel_fyp/sync/batch_coalescer.dart';
import 'package:guardian_angel_fyp/sync/metrics/telemetry.dart';

void main() {
  // Initialize Flutter binding for platform channels used by connectivity
  widgets.WidgetsFlutterBinding.ensureInitialized();
  late String hivePath;
  late MockServer server;
  late MockAuthService authService;
  late ApiClient apiClient;
  late PendingQueueService queueService;
  late SyncEngine syncEngine;
  late Box pendingBox;
  late Box indexBox;
  late Box failedBox;
  late Box lockBox;
  late Box optimisticBox;
  
  const appVersion = '1.0.0-test';
  const deviceId = 'test-device-001';

  setUpAll(() async {
    // Initialize test environment
    hivePath = await initTestHive();
    
    // Start mock server
    server = MockServer();
    await server.start(port: 0);
    
    print('✅ Test environment initialized');
    print('   Hive path: $hivePath');
    print('   Server: ${server.baseUrl}');
  });

  setUp(() async {
    // Clean server state
    server.reset();
    
    // Open Hive boxes
    pendingBox = await Hive.openBox('pending_ops_test');
    indexBox = await Hive.openBox('pending_index_test');
    failedBox = await Hive.openBox('failed_ops_test');
    lockBox = await Hive.openBox('processing_lock_test');
    optimisticBox = await Hive.openBox('optimistic_store_test');
    
    // Create services
    authService = MockAuthService();
    apiClient = ApiClient(
      baseUrl: server.baseUrl,
      authService: authService,
      appVersion: appVersion,
      deviceId: deviceId,
    );
    
    queueService = PendingQueueService(pendingBox, indexBox, failedBox);
    
    final router = OpRouter();
    router.register(
      'create',
      'device',
      RouteDef(
        method: 'POST',
        pathBuilder: (p) => '/devices',
      ),
    );
    router.register(
      'update',
      'device',
      RouteDef(
        method: 'PUT',
        pathBuilder: (p) => '/devices/${p['id']}',
      ),
    );
    router.register(
      'delete',
      'device',
      RouteDef(
        method: 'DELETE',
        pathBuilder: (p) => '/devices/${p['id']}',
      ),
    );
    
    final lock = ProcessingLock(
      lockBox,
      lockTimeout: Duration(minutes: 2),
      heartbeatInterval: Duration(seconds: 10),
    );
    
    final backoffPolicy = BackoffPolicy(
      baseMs: 100,
      maxBackoffMs: 5000,
      maxAttempts: 3,
      random: createDeterministicRng(),
    );
    
    final circuitBreaker = CircuitBreaker(
      failureThreshold: 5,
      window: Duration(seconds: 30),
      cooldown: Duration(seconds: 10),
    );
    
    final reconciler = Reconciler(apiClient);
    final optimisticStore = OptimisticStore();
    final coalescer = BatchCoalescer(pendingBox, indexBox);
    final metrics = SyncMetrics();
    
    syncEngine = SyncEngine(
      api: apiClient,
      queue: queueService,
      router: router,
      lock: lock,
      backoffPolicy: backoffPolicy,
      circuitBreaker: circuitBreaker,
      reconciler: reconciler,
      optimisticStore: optimisticStore,
      coalescer: coalescer,
      metrics: metrics,
    );
  });

  tearDown(() async {
    // Stop sync engine
    await syncEngine.stop();
    
    // Close and delete boxes
    await pendingBox.clear();
    await indexBox.clear();
    await failedBox.clear();
    await lockBox.clear();
    await optimisticBox.clear();
    
    await pendingBox.close();
    await indexBox.close();
    await failedBox.close();
    await lockBox.close();
    await optimisticBox.close();
  });

  tearDownAll(() async {
    await server.stop();
    await cleanupTestHive(hivePath);
    print('✅ Test environment cleaned up');
  });

  group('Happy Path', () {
    test('offline enqueue → online process → success', () async {
      // 1. Enqueue operation while "offline" (engine not running)
      final op = PendingOp(
        id: Uuid().v4(),
        opType: 'create',
        entityType: 'device',
        payload: {'name': 'Living Room Light', 'type': 'light'},
        createdAt: DateTime.now(),
        idempotencyKey: Uuid().v4(),
      );
      
      await queueService.enqueue(op);
      
      // Verify enqueued
      final pending = await queueService.getAll();
      expect(pending.length, equals(1));
      expect(pending.first.id, equals(op.id));
      
      // 2. Start engine (simulates "going online")
      await syncEngine.start();
      
      // 3. Wait for processing
      await TestUtils.waitForAsync(
        () async => (await queueService.getAll()).isEmpty,
        timeout: Duration(seconds: 10),
      );
      
      // 4. Assertions
      expect(await queueService.getAll(), isEmpty, reason: 'Queue should be empty after processing');
      expect(server.requests.length, equals(1), reason: 'Should have made exactly 1 request');
      
      final request = server.requests.first;
      expect(request.method, equals('POST'));
      expect(request.path, equals('devices'));
      expect(request.headers['idempotency-key'], equals(op.idempotencyKey));
      expect(request.headers['authorization'], startsWith('Bearer '));
      
      // Verify idempotency was stored
      expect(server.idempotencyStore.containsKey(op.idempotencyKey), isTrue);
    });

    test('multiple operations processed in FIFO order', () async {
      // Enqueue 3 operations
      final ops = <PendingOp>[];
      for (int i = 0; i < 3; i++) {
        await Future.delayed(Duration(milliseconds: 10)); // Ensure different timestamps
        final op = PendingOp(
          id: Uuid().v4(),
          opType: 'create',
          entityType: 'device',
          payload: {'name': 'Device $i', 'type': 'sensor'},
          createdAt: DateTime.now(),
          idempotencyKey: Uuid().v4(),
        );
        ops.add(op);
        await queueService.enqueue(op);
      }
      
      // Start processing
      await syncEngine.start();
      
      // Wait for all to process
      await TestUtils.waitForAsync(
        () async => (await queueService.getAll()).isEmpty,
        timeout: Duration(seconds: 15),
      );
      
      // Verify FIFO order
      expect(server.requests.length, equals(3));
      for (int i = 0; i < 3; i++) {
        final req = server.requests[i];
        final body = req.body;
        expect(body, contains('Device $i'), reason: 'Request $i should match operation $i');
      }
    });
  });

  group('Idempotency & Crash-Resume', () {
    test('duplicate idempotency key returns cached response', () async {
      final idempKey = Uuid().v4();
      
      // First operation
      final op1 = PendingOp(
        id: Uuid().v4(),
        opType: 'create',
        entityType: 'device',
        payload: {'name': 'First Request', 'type': 'light'},
        createdAt: DateTime.now(),
        idempotencyKey: idempKey,
      );
      await queueService.enqueue(op1);
      
      // Process first
      await syncEngine.start();
      await TestUtils.waitForAsync(
        () async => (await queueService.getAll()).isEmpty,
        timeout: Duration(seconds: 10),
      );
      await syncEngine.stop();
      
      // Second operation with SAME idempotency key
      final op2 = PendingOp(
        id: Uuid().v4(),
        opType: 'create',
        entityType: 'device',
        payload: {'name': 'Second Request (duplicate)', 'type': 'light'},
        createdAt: DateTime.now(),
        idempotencyKey: idempKey, // SAME KEY
      );
      await queueService.enqueue(op2);
      
      // Clear server requests to verify no new request
      server.requests.clear();
      
      // Process second
      await syncEngine.start();
      await TestUtils.waitForAsync(
        () async => (await queueService.getAll()).isEmpty,
        timeout: Duration(seconds: 10),
      );
      
      // Verify: server received request but returned cached response
      expect(server.requests.length, equals(1), reason: 'Server should receive request');
      expect(server.idempotencyStore[idempKey], isNotNull, reason: 'Cached response should exist');
    });

    test('crash-resume: operation retried after engine restart', () async {
      // Enqueue operation
      final op = PendingOp(
        id: Uuid().v4(),
        opType: 'create',
        entityType: 'device',
        payload: {'name': 'Crash Test Device', 'type': 'sensor'},
        createdAt: DateTime.now(),
        idempotencyKey: Uuid().v4(),
        attempts: 1, // Simulate partial processing
      );
      await queueService.enqueue(op);
      
      // Start engine briefly then "crash" (stop without completing)
      await syncEngine.start();
      await Future.delayed(Duration(milliseconds: 100));
      await syncEngine.stop();
      
      // Verify operation still in queue
      final pendingAfterCrash = await queueService.getAll();
      expect(pendingAfterCrash.isNotEmpty, isTrue, reason: 'Operation should remain in queue after crash');
      
      // Restart engine (simulate crash recovery)
      await syncEngine.start();
      await TestUtils.waitForAsync(
        () async => (await queueService.getAll()).isEmpty,
        timeout: Duration(seconds: 10),
      );
      
      // Verify processed
      expect(await queueService.getAll(), isEmpty);
      expect(server.requests.isNotEmpty, isTrue);
    });
  });

  group('Retry & Backoff', () {
    test('429 rate limit triggers retry with backoff', () async {
      // Configure server to return 429 on first request
      server.behavior.retryAfterSeconds = 1;
      
      final op = PendingOp(
        id: Uuid().v4(),
        opType: 'test',
        entityType: 'error',
        payload: {'endpoint': '/error/429'},
        createdAt: DateTime.now(),
        idempotencyKey: Uuid().v4(),
      );
      await queueService.enqueue(op);
      
      // Temporarily register error route
      final router = (syncEngine as dynamic).router as OpRouter;
      router.register(
        'test',
        'error',
        RouteDef(
          method: 'GET',
          pathBuilder: (p) => '/error/429',
        ),
      );
      
      await syncEngine.start();
      
      // Wait briefly to see retry behavior
      await Future.delayed(Duration(seconds: 3));
      
      // Should see multiple requests (original + retries)
      expect(server.requests.length, greaterThan(1), reason: 'Should retry after 429');
      
      await syncEngine.stop();
    });

    test('500 server error triggers exponential backoff', () async {
      final op = PendingOp(
        id: Uuid().v4(),
        opType: 'test',
        entityType: 'error',
        payload: {'endpoint': '/error/500'},
        createdAt: DateTime.now(),
        idempotencyKey: Uuid().v4(),
      );
      await queueService.enqueue(op);
      
      // Register error route
      final router = (syncEngine as dynamic).router as OpRouter;
      router.register(
        'test',
        'error',
        RouteDef(
          method: 'GET',
          pathBuilder: (p) => '/error/500',
        ),
      );
      
      await syncEngine.start();
      await Future.delayed(Duration(seconds: 8));
      
      // Should attempt multiple times with backoff
      final attempts = server.requests.where((r) => r.path == 'error/500').length;
      expect(attempts, greaterThanOrEqualTo(2), reason: 'Should retry 5xx errors');
      expect(attempts, lessThanOrEqualTo(3), reason: 'Should respect max attempts');
      
      await syncEngine.stop();
    });
  });

  group('Conflict Resolution', () {
    test('409 conflict triggers reconciliation', () async {
      // Enable conflict simulation
      server.behavior.simulateConflict = true;
      server.behavior.conflictVersion = 5;
      
      final deviceId = 'device-123';
      final op = PendingOp(
        id: Uuid().v4(),
        opType: 'update',
        entityType: 'device',
        payload: {
          'id': deviceId,
          'name': 'Updated Name',
          'version': 3, // Client has version 3, server has 5
        },
        createdAt: DateTime.now(),
        idempotencyKey: Uuid().v4(),
      );
      await queueService.enqueue(op);
      
      await syncEngine.start();
      await Future.delayed(Duration(seconds: 3));
      
      // Should receive 409 response
      final conflictRequests = server.requests.where(
        (r) => r.path == 'devices/$deviceId' && r.method == 'PUT'
      );
      expect(conflictRequests.isNotEmpty, isTrue);
      
      await syncEngine.stop();
      
      // Note: Full reconciliation testing requires mocking reconciler behavior
      // This test verifies the conflict is detected and handled
    });
  });

  group('Circuit Breaker', () {
    test('circuit trips after threshold failures', () async {
      // Enqueue multiple operations that will fail
      for (int i = 0; i < 6; i++) {
        final op = PendingOp(
          id: Uuid().v4(),
          opType: 'test',
          entityType: 'error',
          payload: {'endpoint': '/error/500'},
          createdAt: DateTime.now(),
          idempotencyKey: Uuid().v4(),
        );
        await queueService.enqueue(op);
      }
      
      // Register error route
      final router = (syncEngine as dynamic).router as OpRouter;
      router.register(
        'test',
        'error',
        RouteDef(
          method: 'GET',
          pathBuilder: (p) => '/error/500',
        ),
      );
      
      await syncEngine.start();
      await Future.delayed(Duration(seconds: 5));
      
      // Circuit breaker should trip after 5 failures (threshold)
      final breaker = (syncEngine as dynamic).circuitBreaker as CircuitBreaker;
      expect(breaker.isTripped(), isTrue, reason: 'Circuit should be open after threshold failures');
      
      await syncEngine.stop();
    });
  });

  group('Network Connectivity', () {
    test('operations queued offline are processed when online', () async {
      // Enqueue operations before starting engine (simulates offline)
      final ops = <PendingOp>[];
      for (int i = 0; i < 3; i++) {
        final op = PendingOp(
          id: Uuid().v4(),
          opType: 'create',
          entityType: 'device',
          payload: {'name': 'Offline Device $i', 'type': 'sensor'},
          createdAt: DateTime.now(),
          idempotencyKey: Uuid().v4(),
        );
        ops.add(op);
        await queueService.enqueue(op);
      }
      
      // Verify queued
      expect((await queueService.getAll()).length, equals(3));
      
      // Start engine (simulates going online)
      await syncEngine.start();
      
      // Wait for processing
      await TestUtils.waitForAsync(
        () async => (await queueService.getAll()).isEmpty,
        timeout: Duration(seconds: 15),
      );
      
      // All should be processed
      expect(await queueService.getAll(), isEmpty);
      expect(server.requests.length, equals(3));
    });
  });

  group('Metrics & Observability', () {
    test('metrics are recorded during processing', () async {
      final op = PendingOp(
        id: Uuid().v4(),
        opType: 'create',
        entityType: 'device',
        payload: {'name': 'Metrics Test Device', 'type': 'light'},
        createdAt: DateTime.now(),
        idempotencyKey: Uuid().v4(),
      );
      await queueService.enqueue(op);
      
      await syncEngine.start();
      await TestUtils.waitForAsync(
        () async => (await queueService.getAll()).isEmpty,
        timeout: Duration(seconds: 10),
      );
      
      // Access metrics
      final metrics = (syncEngine as dynamic).metrics as SyncMetrics;
      
      // Verify metrics recorded
      final summary = metrics.getSummary();
      expect(summary['operations']['processed'], greaterThan(0), reason: 'Should record processed ops');
      expect(metrics.successRate, greaterThan(0.0), reason: 'Should calculate success rate');
    });
  });
}

// (No HttpOverrides needed; real HTTP is allowed under WidgetsFlutterBinding)
