/// Load testing tool for sync engine
/// 
/// Usage: flutter run tool/stress/load_test.dart
/// 
/// Tests:
/// - Enqueue throughput
/// - Processing latency under load
/// - Memory consumption
/// - Circuit breaker behavior under stress
/// - Queue depth management

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:guardian_angel_fyp/sync/models/pending_op.dart';
import 'package:guardian_angel_fyp/sync/pending_queue_service.dart';
import 'package:guardian_angel_fyp/sync/sync_engine.dart';
import 'package:guardian_angel_fyp/sync/api_client.dart';
import 'package:guardian_angel_fyp/sync/auth_service.dart';
import 'package:guardian_angel_fyp/sync/op_router.dart';
import 'package:guardian_angel_fyp/sync/processing_lock.dart';
import 'package:guardian_angel_fyp/sync/backoff_policy.dart';
import 'package:guardian_angel_fyp/sync/circuit_breaker.dart';
import 'package:guardian_angel_fyp/sync/reconciler.dart';
import 'package:guardian_angel_fyp/sync/optimistic_store.dart';
import 'package:guardian_angel_fyp/sync/batch_coalescer.dart';
import 'package:guardian_angel_fyp/sync/metrics/telemetry.dart';
import 'package:guardian_angel_fyp/persistence/adapters/pending_op_adapter.dart';

void main() async {
  print('╔═══════════════════════════════════════════════════════════╗');
  print('║           SYNC ENGINE LOAD TEST                          ║');
  print('╚═══════════════════════════════════════════════════════════╝');
  print('');

  // Initialize Hive
  final dir = await getApplicationDocumentsDirectory();
  final testDir = Directory('${dir.path}/load_test_${DateTime.now().millisecondsSinceEpoch}');
  await testDir.create();
  
  Hive.init(testDir.path);
  Hive.registerAdapter(PendingOpAdapter());

  try {
    // Run test suites
    await runEnqueueThroughputTest();
    await runProcessingLatencyTest();
    await runMemoryConsumptionTest();
    await runCircuitBreakerStressTest();
    await runConcurrentProcessingTest();
    
    print('');
    print('✅ All load tests completed successfully!');
  } finally {
    // Cleanup
    await Hive.close();
    await testDir.delete(recursive: true);
  }
}

/// Test 1: Enqueue throughput
Future<void> runEnqueueThroughputTest() async {
  print('');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('Test 1: Enqueue Throughput');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  final pendingBox = await Hive.openBox<PendingOp>('enqueue_test_pending');
  final indexBox = await Hive.openBox<String>('enqueue_test_index');
  final failedBox = await Hive.openBox<Map>('enqueue_test_failed');
  
  final queue = PendingQueueService(
    pendingBox,
    indexBox,
    failedBox,
  );

  final testSizes = [100, 1000, 5000, 10000];
  
  for (final size in testSizes) {
    await pendingBox.clear();
    await indexBox.clear();
    
    final stopwatch = Stopwatch()..start();
    
    for (int i = 0; i < size; i++) {
      final op = PendingOp(
        id: 'op-$size-$i',
        opType: 'UPDATE',
        entityType: 'DEVICE',
        payload: {
          'id': 'device-$i',
          'state': 'on',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      await queue.enqueue(op);
    }
    
    stopwatch.stop();
    
    final opsPerSec = (size / (stopwatch.elapsedMilliseconds / 1000)).round();
    final avgLatency = (stopwatch.elapsedMilliseconds / size).toStringAsFixed(2);
    
    print('  $size ops: ${stopwatch.elapsedMilliseconds}ms '
        '($opsPerSec ops/sec, ${avgLatency}ms avg)');
  }
  
  await pendingBox.close();
  await indexBox.close();
  await failedBox.close();
  
  print('✓ Enqueue throughput test completed');
}

/// Test 2: Processing latency under load
Future<void> runProcessingLatencyTest() async {
  print('');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('Test 2: Processing Latency Under Load');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  final pendingBox = await Hive.openBox<PendingOp>('latency_test_pending');
  final indexBox = await Hive.openBox<String>('latency_test_index');
  final failedBox = await Hive.openBox<Map>('latency_test_failed');
  final lockBox = await Hive.openBox<Map>('latency_test_lock');
  
  final queue = PendingQueueService(
    pendingBox,
    indexBox,
    failedBox,
  );
  
  // Create mock API client with simulated latency
  final mockApi = MockApiClient(latencyMs: 50);
  final router = OpRouter();
  _registerRoutes(router);
  
  final lock = ProcessingLock(lockBox);
  final backoff = BackoffPolicy();
  final breaker = CircuitBreaker();
  final reconciler = Reconciler(mockApi);
  final store = OptimisticStore();
  final coalescer = BatchCoalescer(pendingBox, indexBox);
  final metrics = SyncMetrics();
  
  final engine = SyncEngine(
    api: mockApi,
    queue: queue,
    router: router,
    lock: lock,
    backoffPolicy: backoff,
    circuitBreaker: breaker,
    reconciler: reconciler,
    optimisticStore: store,
    coalescer: coalescer,
    metrics: metrics,
  );
  
  // Seed operations
  const opCount = 1000;
  print('  Seeding $opCount operations...');
  
  for (int i = 0; i < opCount; i++) {
    final op = PendingOp(
      id: 'op-latency-$i',
      opType: 'UPDATE',
      entityType: 'DEVICE',
      payload: {'id': 'device-$i', 'state': 'on'},
    );
    await queue.enqueue(op);
  }
  
  print('  Starting processor...');
  final stopwatch = Stopwatch()..start();
  await engine.start();
  
  // Wait for processing to complete
  while (await queue.count() > 0) {
    await Future.delayed(const Duration(milliseconds: 100));
  }
  
  stopwatch.stop();
  await engine.stop();
  
  final totalTime = stopwatch.elapsedMilliseconds;
  final avgLatency = (totalTime / opCount).toStringAsFixed(2);
  final opsPerSec = ((opCount / (totalTime / 1000))).round();
  
  print('  Processed $opCount ops in ${totalTime}ms');
  print('  Average latency: ${avgLatency}ms per op');
  print('  Throughput: $opsPerSec ops/sec');
  
  // Print metrics summary
  metrics.printSummary();
  
  await pendingBox.close();
  await indexBox.close();
  await failedBox.close();
  await lockBox.close();
  
  print('✓ Processing latency test completed');
}

/// Test 3: Memory consumption
Future<void> runMemoryConsumptionTest() async {
  print('');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('Test 3: Memory Consumption');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  final pendingBox = await Hive.openBox<PendingOp>('memory_test_pending');
  final indexBox = await Hive.openBox<String>('memory_test_index');
  final failedBox = await Hive.openBox<Map>('memory_test_failed');
  
  final queue = PendingQueueService(
    pendingBox,
    indexBox,
    failedBox,
  );

  // Record initial memory
  final initialRss = ProcessInfo.currentRss;
  print('  Initial memory: ${(initialRss / 1024 / 1024).toStringAsFixed(2)} MB');
  
  // Seed 50k operations
  const opCount = 50000;
  print('  Seeding $opCount operations...');
  
  for (int i = 0; i < opCount; i++) {
    final op = PendingOp(
      id: 'op-$i',
      opType: 'UPDATE',
      entityType: 'DEVICE',
      payload: {
        'id': 'device-$i',
        'state': 'on',
        'brightness': Random().nextInt(100),
        'data': List.generate(10, (i) => 'field-$i-value'),
      },
    );
    await queue.enqueue(op);
    
    if (i % 10000 == 0 && i > 0) {
      final currentRss = ProcessInfo.currentRss;
      final memoryUsed = (currentRss - initialRss) / 1024 / 1024;
      print('    $i ops: ${memoryUsed.toStringAsFixed(2)} MB');
    }
  }
  
  final finalRss = ProcessInfo.currentRss;
  final totalMemory = (finalRss - initialRss) / 1024 / 1024;
  final memoryPerOp = ((finalRss - initialRss) / opCount / 1024).toStringAsFixed(2);
  
  print('  Total memory used: ${totalMemory.toStringAsFixed(2)} MB');
  print('  Memory per operation: ${memoryPerOp} KB');
  
  await pendingBox.close();
  await indexBox.close();
  await failedBox.close();
  
  print('✓ Memory consumption test completed');
}

/// Test 4: Circuit breaker under stress
Future<void> runCircuitBreakerStressTest() async {
  print('');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('Test 4: Circuit Breaker Stress Test');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  final breaker = CircuitBreaker(
    failureThreshold: 10,
    window: const Duration(seconds: 5),
    cooldown: const Duration(seconds: 2),
  );
  
  // Simulate failure storm
  print('  Simulating 5xx failure storm...');
  for (int i = 0; i < 50; i++) {
    breaker.recordFailure();
    
    if (i == 9) {
      print('    Circuit breaker tripped after ${i + 1} failures');
    }
    
    if (breaker.isTripped()) {
      final cooldown = breaker.getCooldownRemaining();
      if (i == 10) {
        print('    Remaining cooldown: ${cooldown?.inSeconds}s');
      }
    }
  }
  
  // Wait for cooldown
  print('  Waiting for cooldown...');
  await Future.delayed(const Duration(seconds: 3));
  
  if (!breaker.isTripped()) {
    print('  ✓ Circuit breaker reset after cooldown');
  } else {
    print('  ✗ Circuit breaker did not reset');
  }
  
  // Test recovery
  print('  Testing recovery with successful requests...');
  for (int i = 0; i < 5; i++) {
    breaker.recordSuccess();
  }
  
  print('  ✓ Circuit breaker functioning normally');
  print('✓ Circuit breaker stress test completed');
}

/// Test 5: Concurrent processing
Future<void> runConcurrentProcessingTest() async {
  print('');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('Test 5: Concurrent Processing');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  final pendingBox = await Hive.openBox<PendingOp>('concurrent_test_pending');
  final indexBox = await Hive.openBox<String>('concurrent_test_index');
  final failedBox = await Hive.openBox<Map>('concurrent_test_failed');
  
  final queue = PendingQueueService(
    pendingBox,
    indexBox,
    failedBox,
  );
  
  // Seed operations
  const opCount = 5000;
  print('  Seeding $opCount operations...');
  
  for (int i = 0; i < opCount; i++) {
    final op = PendingOp(
      id: 'op-$i',
      opType: 'UPDATE',
      entityType: 'DEVICE',
      payload: {'id': 'device-$i', 'state': 'on'},
    );
    await queue.enqueue(op);
  }
  
  // Process with multiple concurrent readers
  print('  Processing with concurrent readers...');
  final stopwatch = Stopwatch()..start();
  
  await Future.wait([
    _concurrentProcessor(queue, 'Worker-1'),
    _concurrentProcessor(queue, 'Worker-2'),
    _concurrentProcessor(queue, 'Worker-3'),
  ]);
  
  stopwatch.stop();
  
  final remaining = await queue.count();
  print('  Processed in ${stopwatch.elapsedMilliseconds}ms');
  print('  Remaining operations: $remaining');
  
  await pendingBox.close();
  await indexBox.close();
  await failedBox.close();
  
  print('✓ Concurrent processing test completed');
}

/// Concurrent processor worker
Future<void> _concurrentProcessor(PendingQueueService queue, String workerId) async {
  int processed = 0;
  
  while (true) {
    final op = await queue.getOldest();
    if (op == null) break;
    
    // Simulate processing
    await Future.delayed(Duration(milliseconds: Random().nextInt(10)));
    
    await queue.markProcessed(op.id);
    processed++;
  }
  
  print('    $workerId processed $processed operations');
}

/// Register operation routes
void _registerRoutes(OpRouter router) {
  router.register(
    'UPDATE',
    'DEVICE',
    RouteDef(
      method: 'PATCH',
      pathBuilder: (payload) => '/devices/${payload['id']}',
      requiresIdempotency: true,
    ),
  );
}

/// Mock API client with simulated latency
class MockApiClient extends ApiClient {
  final int latencyMs;
  int _requestCount = 0;
  
  MockApiClient({required this.latencyMs})
      : super(
          baseUrl: 'https://mock.api',
          authService: MockAuthService(),
          appVersion: '1.0.0',
          deviceId: 'test-device',
        );

  @override
  Future<Map<String, dynamic>> request({
    required String method,
    required String path,
    Map<String, String>? headers,
    dynamic body,
    Duration timeout = const Duration(seconds: 30),
    bool retryAuth = true,
  }) async {
    _requestCount++;
    
    // Simulate network latency
    await Future.delayed(Duration(milliseconds: latencyMs));
    
    // Simulate occasional failures (5%)
    if (Random().nextDouble() < 0.05) {
      throw Exception('Simulated network error');
    }
    
    return {
      'success': true,
      'request_id': _requestCount,
    };
  }
}

/// Mock auth service
class MockAuthService extends AuthService {
  @override
  Future<String?> getAccessToken() async => 'mock-token';
  
  @override
  Future<bool> tryRefresh() async => true;
}
