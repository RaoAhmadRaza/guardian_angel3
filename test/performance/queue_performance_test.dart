import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:guardian_angel_fyp/home automation/src/data/hive_adapters/pending_op_hive.dart';

/// Performance and load testing for queue/index operations with 10k+ PendingOps
/// 
/// Tests measure:
/// - Memory usage during bulk operations
/// - Time for enqueue operations
/// - Time for getOldestPendingOp(N) queries
/// - Time for rebuilding/sorting operations
/// - Integrity check performance

void main() {
  late Directory tempDir;
  late Box<PendingOp> pendingBox;

  setUpAll(() async {
    // Register Hive adapter
    Hive.registerAdapter(PendingOpAdapter());
  });

  setUp(() async {
    // Create temporary directory for isolated testing
    tempDir = await Directory.systemTemp.createTemp('queue_perf_test_');
    Hive.init(tempDir.path);
    
    // Open pending ops box
    pendingBox = await Hive.openBox<PendingOp>(kPendingOpsBoxName);
  });

  tearDown(() async {
    await pendingBox.clear();
    await pendingBox.close();
    await tempDir.delete(recursive: true);
  });

  group('Queue Performance Tests', () {
    test('Baseline: 1,000 operations', () async {
      final metrics = await _runPerformanceTest(pendingBox, operationCount: 1000);
      _printMetrics('1K Operations', metrics);
      
      // Baseline expectations (should be fast)
      expect(metrics.enqueueTimeMs, lessThan(500), reason: '1K enqueue should be < 500ms');
      expect(metrics.sortTimeMs, lessThan(50), reason: '1K sort should be < 50ms');
      expect(metrics.getOldest10TimeMs, lessThan(10), reason: 'Get 10 oldest should be < 10ms');
    });

    test('Medium load: 5,000 operations', () async {
      final metrics = await _runPerformanceTest(pendingBox, operationCount: 5000);
      _printMetrics('5K Operations', metrics);
      
      // Medium load expectations
      expect(metrics.enqueueTimeMs, lessThan(2000), reason: '5K enqueue should be < 2s');
      expect(metrics.sortTimeMs, lessThan(200), reason: '5K sort should be < 200ms');
      expect(metrics.getOldest100TimeMs, lessThan(50), reason: 'Get 100 oldest should be < 50ms');
    });

    test('Heavy load: 10,000 operations', () async {
      final metrics = await _runPerformanceTest(pendingBox, operationCount: 10000);
      _printMetrics('10K Operations', metrics);
      
      // Heavy load expectations
      expect(metrics.enqueueTimeMs, lessThan(5000), reason: '10K enqueue should be < 5s');
      expect(metrics.sortTimeMs, lessThan(500), reason: '10K sort should be < 500ms');
      expect(metrics.getOldest1000TimeMs, lessThan(200), reason: 'Get 1K oldest should be < 200ms');
    });

    test('Stress test: 25,000 operations', () async {
      final metrics = await _runPerformanceTest(pendingBox, operationCount: 25000);
      _printMetrics('25K Operations', metrics);
      
      // Stress test - document actual performance (no hard expectations)
      print('\n⚠️  Stress test results (informational):');
      print('   - Enqueue: ${metrics.enqueueTimeMs}ms');
      print('   - Sort: ${metrics.sortTimeMs}ms');
      print('   - Memory: ${metrics.memoryUsageMB.toStringAsFixed(2)}MB');
    });

    test('Extreme load: 50,000 operations', () async {
      final metrics = await _runPerformanceTest(pendingBox, operationCount: 50000);
      _printMetrics('50K Operations', metrics);
      
      // Extreme load - document performance characteristics
      print('\n⚠️  Extreme load results:');
      print('   - Total time: ${metrics.totalTimeMs}ms');
      print('   - Throughput: ${(50000 / (metrics.enqueueTimeMs / 1000)).toStringAsFixed(0)} ops/sec');
    });

    test('Enqueue pattern: Batched vs Individual', () async {
      print('\n📊 Comparing enqueue patterns...\n');
      
      // Test individual puts
      final individualStart = DateTime.now();
      for (int i = 0; i < 1000; i++) {
        final op = _generatePendingOp(i);
        await pendingBox.put(op.opId, op);
      }
      final individualTime = DateTime.now().difference(individualStart).inMilliseconds;
      await pendingBox.clear();
      
      // Test batched putAll
      final batchStart = DateTime.now();
      final batch = <String, PendingOp>{};
      for (int i = 0; i < 1000; i++) {
        final op = _generatePendingOp(i);
        batch[op.opId] = op;
      }
      await pendingBox.putAll(batch);
      final batchTime = DateTime.now().difference(batchStart).inMilliseconds;
      
      print('Individual puts (1000 ops): ${individualTime}ms');
      print('Batched putAll (1000 ops): ${batchTime}ms');
      print('Speedup: ${(individualTime / batchTime).toStringAsFixed(2)}x\n');
      
      expect(batchTime, lessThan(individualTime), 
        reason: 'Batched operations should be faster');
    });

    test('Query pattern: getOldestPendingOp(N) scaling', () async {
      print('\n📊 Testing query scaling with 10K operations...\n');
      
      // Load 10K operations
      await _bulkEnqueue(pendingBox, 10000);
      
      final queries = [10, 50, 100, 500, 1000, 5000];
      final results = <int, int>{};
      
      for (final n in queries) {
        final start = DateTime.now();
        final oldest = await _getOldestPendingOps(pendingBox, n);
        final timeMs = DateTime.now().difference(start).inMilliseconds;
        results[n] = timeMs;
        
        expect(oldest.length, equals(min(n, 10000)));
        print('getOldest($n): ${timeMs}ms');
      }
      
      // Verify query time scales reasonably
      expect(results[10]!, lessThan(20), reason: 'Small query should be fast');
      expect(results[5000]!, lessThan(500), reason: 'Large query should still be reasonable');
    });

    test('Integrity check performance', () async {
      print('\n📊 Testing integrity check performance...\n');
      
      final sizes = [1000, 5000, 10000];
      
      for (final size in sizes) {
        await pendingBox.clear();
        await _bulkEnqueue(pendingBox, size);
        
        final start = DateTime.now();
        final result = await _verifyIntegrity(pendingBox);
        final timeMs = DateTime.now().difference(start).inMilliseconds;
        
        print('Integrity check ($size ops): ${timeMs}ms');
        expect(result.isValid, isTrue);
        expect(result.duplicateOpIds, isEmpty);
        expect(result.invalidTimestamps, isEmpty);
      }
    });

    test('Memory usage tracking', () async {
      print('\n📊 Memory usage analysis...\n');
      
      final sizes = [1000, 5000, 10000, 25000];
      final memorySnapshots = <int, double>{};
      
      for (final size in sizes) {
        await pendingBox.clear();
        
        final beforeMB = _estimateMemoryUsageMB();
        await _bulkEnqueue(pendingBox, size);
        final afterMB = _estimateMemoryUsageMB();
        
        final usedMB = afterMB - beforeMB;
        memorySnapshots[size] = usedMB;
        
        print('$size ops: ${usedMB.toStringAsFixed(2)}MB');
        print('  - Per op: ${(usedMB * 1024 / size).toStringAsFixed(2)}KB');
      }
      
      // Note: Memory tracking with ProcessInfo.currentRss is not reliable for fine-grained
      // measurements in test environments. The test demonstrates the pattern but actual
      // memory usage should be monitored in profiler tools for accurate analysis.
      print('\nNote: Memory measurements are approximations.');
      print('Use DevTools profiler for accurate memory analysis.');
    });

    test('Sorting/Rebuild performance', () async {
      print('\n📊 Testing sort/rebuild performance...\n');
      
      await _bulkEnqueue(pendingBox, 10000);
      
      // Test multiple sort iterations to measure consistency
      final sortTimes = <int>[];
      for (int i = 0; i < 5; i++) {
        final start = DateTime.now();
        final sorted = await _rebuildIndex(pendingBox);
        final timeMs = DateTime.now().difference(start).inMilliseconds;
        sortTimes.add(timeMs);
        
        expect(sorted.length, equals(10000));
        // Verify ordering
        for (int j = 1; j < sorted.length; j++) {
          expect(sorted[j].queuedAt.isAfter(sorted[j - 1].queuedAt) || 
                 sorted[j].queuedAt.isAtSameMomentAs(sorted[j - 1].queuedAt), 
            isTrue, reason: 'Operations should be sorted by queuedAt');
        }
      }
      
      final avgSortTime = sortTimes.reduce((a, b) => a + b) / sortTimes.length;
      final minSortTime = sortTimes.reduce(min);
      final maxSortTime = sortTimes.reduce(max);
      
      print('Sort times (5 runs): ${sortTimes.join(", ")}ms');
      print('Average: ${avgSortTime.toStringAsFixed(1)}ms');
      print('Min: ${minSortTime}ms, Max: ${maxSortTime}ms');
      print('Variance: ${(maxSortTime - minSortTime)}ms');
      
      expect(avgSortTime, lessThan(500), reason: 'Average sort should be < 500ms');
    });

    test('Concurrent access stress test', () async {
      print('\n📊 Testing concurrent access patterns...\n');
      
      final start = DateTime.now();
      final futures = <Future>[];
      
      // Simulate concurrent enqueue from multiple sources
      for (int i = 0; i < 5; i++) {
        futures.add(() async {
          for (int j = 0; j < 1000; j++) {
            final op = _generatePendingOp(i * 1000 + j);
            await pendingBox.put(op.opId, op);
          }
        }());
      }
      
      await Future.wait(futures);
      final timeMs = DateTime.now().difference(start).inMilliseconds;
      
      print('Concurrent enqueue (5 writers x 1000 ops): ${timeMs}ms');
      expect(pendingBox.length, equals(5000));
      
      // Verify no data corruption
      final integrity = await _verifyIntegrity(pendingBox);
      expect(integrity.isValid, isTrue);
      expect(integrity.duplicateOpIds, isEmpty);
    });

    test('Delete pattern performance', () async {
      print('\n📊 Testing delete patterns...\n');
      
      await _bulkEnqueue(pendingBox, 10000);
      
      // Test individual deletes (first 1000)
      final individualStart = DateTime.now();
      for (int i = 0; i < 1000; i++) {
        await pendingBox.delete('op_$i');
      }
      final individualTime = DateTime.now().difference(individualStart).inMilliseconds;
      
      // Test batch deletes (next 1000)
      final batchStart = DateTime.now();
      final keysToDelete = List.generate(1000, (i) => 'op_${1000 + i}');
      await pendingBox.deleteAll(keysToDelete);
      final batchTime = DateTime.now().difference(batchStart).inMilliseconds;
      
      print('Individual deletes (1000 ops): ${individualTime}ms');
      print('Batch deleteAll (1000 ops): ${batchTime}ms');
      print('Speedup: ${(individualTime / batchTime).toStringAsFixed(2)}x');
      
      expect(pendingBox.length, equals(8000));
    });

    test('Mixed workload simulation', () async {
      print('\n📊 Simulating realistic mixed workload...\n');
      
      final start = DateTime.now();
      int enqueued = 0;
      int dequeued = 0;
      int queried = 0;
      
      // Simulate realistic pattern over 5 seconds
      final stopwatch = Stopwatch()..start();
      while (stopwatch.elapsed.inSeconds < 5) {
        // Enqueue burst (simulating user actions)
        final batch = <String, PendingOp>{};
        for (int i = 0; i < 50; i++) {
          final op = _generatePendingOp(enqueued + i);
          batch[op.opId] = op;
        }
        await pendingBox.putAll(batch);
        enqueued += 50;
        
        // Query oldest operations (simulating sync service)
        final oldest = await _getOldestPendingOps(pendingBox, 10);
        queried += oldest.length;
        
        // Dequeue some operations (simulating processing)
        if (oldest.length > 5) {
          final toDelete = oldest.take(5).map((op) => op.opId).toList();
          await pendingBox.deleteAll(toDelete);
          dequeued += 5;
        }
        
        // Small delay to simulate processing
        await Future.delayed(Duration(milliseconds: 100));
      }
      
      final totalTime = DateTime.now().difference(start).inMilliseconds;
      
      print('Mixed workload results:');
      print('  Duration: ${totalTime}ms');
      print('  Enqueued: $enqueued ops');
      print('  Dequeued: $dequeued ops');
      print('  Queries: ${queried ~/ 10} queries');
      print('  Final queue size: ${pendingBox.length}');
      print('  Throughput: ${(enqueued / (totalTime / 1000)).toStringAsFixed(0)} ops/sec');
    });
  });

  group('Performance Recommendations', () {
    test('Generate performance report', () async {
      print('\n' + '=' * 70);
      print('📋 PERFORMANCE ANALYSIS REPORT');
      print('=' * 70 + '\n');
      
      // Run comprehensive benchmark
      final results = <String, PerformanceMetrics>{};
      
      for (final size in [1000, 5000, 10000, 25000]) {
        await pendingBox.clear();
        results['${size}ops'] = await _runPerformanceTest(pendingBox, operationCount: size);
      }
      
      // Generate summary
      print('SUMMARY:');
      print('-' * 70);
      results.forEach((label, metrics) {
        print('\n$label:');
        print('  Enqueue:        ${metrics.enqueueTimeMs}ms');
        print('  Sort/Rebuild:   ${metrics.sortTimeMs}ms');
        print('  Get Oldest(10): ${metrics.getOldest10TimeMs}ms');
        print('  Memory:         ${metrics.memoryUsageMB.toStringAsFixed(2)}MB');
      });
      
      print('\n' + '-' * 70);
      print('ANALYSIS:');
      print('-' * 70);
      
      // Analyze scaling characteristics
      final scaling1k = results['1000ops']!.enqueueTimeMs;
      final scaling10k = results['10000ops']!.enqueueTimeMs;
      final scalingFactor = scaling10k / scaling1k;
      
      print('\nScaling Analysis:');
      print('  1K → 10K enqueue time ratio: ${scalingFactor.toStringAsFixed(2)}x');
      
      if (scalingFactor < 12) {
        print('  ✅ Good: Near-linear scaling (expected ~10x for 10x data)');
      } else {
        print('  ⚠️  Warning: Sub-linear scaling detected');
        print('     Consider chunked operations or alternative data structure');
      }
      
      // Memory efficiency
      final memoryPer1K = results['1000ops']!.memoryUsageMB;
      final memoryPer10K = results['10000ops']!.memoryUsageMB;
      final memoryGrowth = memoryPer10K / memoryPer1K;
      
      print('\nMemory Efficiency:');
      print('  1K: ${memoryPer1K.toStringAsFixed(2)}MB');
      print('  10K: ${memoryPer10K.toStringAsFixed(2)}MB');
      print('  Growth ratio: ${memoryGrowth.toStringAsFixed(2)}x');
      
      if (memoryGrowth < 12) {
        print('  ✅ Good: Efficient memory usage');
      } else {
        print('  ⚠️  Warning: High memory overhead detected');
      }
      
      // Query performance
      print('\nQuery Performance:');
      final query10ms = results['10000ops']!.getOldest10TimeMs;
      print('  Get oldest 10 from 10K ops: ${query10ms}ms');
      
      if (query10ms < 20) {
        print('  ✅ Excellent: Query performance is optimal');
      } else if (query10ms < 100) {
        print('  ✅ Good: Query performance is acceptable');
      } else {
        print('  ⚠️  Warning: Query performance may need optimization');
        print('     Consider pre-sorted index or B-Tree structure');
      }
      
      // Recommendations
      print('\n' + '=' * 70);
      print('RECOMMENDATIONS:');
      print('=' * 70);
      
      final recommendations = <String>[];
      
      if (scalingFactor > 15) {
        recommendations.add('• Consider batched operations (putAll/deleteAll) for bulk enqueue');
      }
      
      if (results['10000ops']!.sortTimeMs > 500) {
        recommendations.add('• Sort time high: Consider maintaining pre-sorted index');
        recommendations.add('• Alternative: Use SQLite with indexed timestamp column');
      }
      
      if (memoryGrowth > 12) {
        recommendations.add('• Memory overhead detected: Consider chunked storage');
        recommendations.add('• Alternative: Stream-based processing to avoid loading all in memory');
      }
      
      if (query10ms > 100) {
        recommendations.add('• Query performance slow: Implement B-Tree index structure');
        recommendations.add('• Alternative: Maintain separate sorted index file');
      }
      
      final maxLoad = results['25000ops']!;
      if (maxLoad.enqueueTimeMs > 20000) {
        recommendations.add('• Large queue handling: Consider splitting into multiple boxes by priority');
      }
      
      if (recommendations.isEmpty) {
        print('\n✅ Current implementation performs well for tested workloads!');
        print('   No immediate optimizations required.');
      } else {
        print('\n');
        for (final rec in recommendations) {
          print(rec);
        }
      }
      
      print('\n' + '=' * 70);
      print('END REPORT');
      print('=' * 70 + '\n');
    });
  });
}

/// Performance metrics for a test run
class PerformanceMetrics {
  final int operationCount;
  final int enqueueTimeMs;
  final int sortTimeMs;
  final int getOldest10TimeMs;
  final int getOldest100TimeMs;
  final int getOldest1000TimeMs;
  final int integrityCheckTimeMs;
  final double memoryUsageMB;
  final int totalTimeMs;

  PerformanceMetrics({
    required this.operationCount,
    required this.enqueueTimeMs,
    required this.sortTimeMs,
    required this.getOldest10TimeMs,
    required this.getOldest100TimeMs,
    required this.getOldest1000TimeMs,
    required this.integrityCheckTimeMs,
    required this.memoryUsageMB,
    required this.totalTimeMs,
  });
}

/// Run comprehensive performance test
Future<PerformanceMetrics> _runPerformanceTest(
  Box<PendingOp> box, {
  required int operationCount,
}) async {
  final totalStart = DateTime.now();
  
  // Measure enqueue time
  final enqueueStart = DateTime.now();
  await _bulkEnqueue(box, operationCount);
  final enqueueTime = DateTime.now().difference(enqueueStart).inMilliseconds;
  
  // Measure sort/rebuild time
  final sortStart = DateTime.now();
  await _rebuildIndex(box);
  final sortTime = DateTime.now().difference(sortStart).inMilliseconds;
  
  // Measure query times
  final query10Start = DateTime.now();
  await _getOldestPendingOps(box, 10);
  final query10Time = DateTime.now().difference(query10Start).inMilliseconds;
  
  final query100Start = DateTime.now();
  await _getOldestPendingOps(box, 100);
  final query100Time = DateTime.now().difference(query100Start).inMilliseconds;
  
  final query1000Start = DateTime.now();
  await _getOldestPendingOps(box, min(1000, operationCount));
  final query1000Time = DateTime.now().difference(query1000Start).inMilliseconds;
  
  // Measure integrity check time
  final integrityStart = DateTime.now();
  await _verifyIntegrity(box);
  final integrityTime = DateTime.now().difference(integrityStart).inMilliseconds;
  
  // Estimate memory usage
  final memoryMB = _estimateMemoryUsageMB();
  
  final totalTime = DateTime.now().difference(totalStart).inMilliseconds;
  
  return PerformanceMetrics(
    operationCount: operationCount,
    enqueueTimeMs: enqueueTime,
    sortTimeMs: sortTime,
    getOldest10TimeMs: query10Time,
    getOldest100TimeMs: query100Time,
    getOldest1000TimeMs: query1000Time,
    integrityCheckTimeMs: integrityTime,
    memoryUsageMB: memoryMB,
    totalTimeMs: totalTime,
  );
}

/// Bulk enqueue operations using batched putAll
Future<void> _bulkEnqueue(Box<PendingOp> box, int count) async {
  const batchSize = 1000;
  final batches = (count / batchSize).ceil();
  
  for (int b = 0; b < batches; b++) {
    final batch = <String, PendingOp>{};
    final start = b * batchSize;
    final end = min(start + batchSize, count);
    
    for (int i = start; i < end; i++) {
      final op = _generatePendingOp(i);
      batch[op.opId] = op;
    }
    
    await box.putAll(batch);
  }
}

/// Generate a pending operation with realistic data
PendingOp _generatePendingOp(int index) {
  final random = Random(index);
  final entityTypes = ['room', 'device'];
  final opTypes = ['create', 'update', 'delete', 'toggle', 'control'];
  
  return PendingOp(
    opId: 'op_$index',
    entityId: 'entity_${random.nextInt(1000)}',
    entityType: entityTypes[random.nextInt(entityTypes.length)],
    opType: opTypes[random.nextInt(opTypes.length)],
    payload: {
      'id': 'entity_${random.nextInt(1000)}',
      'timestamp': DateTime.now().toIso8601String(),
      'data': List.generate(10, (i) => 'value_$i'),
    },
    queuedAt: DateTime.now().subtract(Duration(seconds: index)),
    attempts: random.nextInt(3),
  );
}

/// Get N oldest pending operations (simulates sync service query)
Future<List<PendingOp>> _getOldestPendingOps(Box<PendingOp> box, int n) async {
  final ops = box.values.toList();
  ops.sort((a, b) => a.queuedAt.compareTo(b.queuedAt));
  return ops.take(n).toList();
}

/// Rebuild index by sorting all operations
Future<List<PendingOp>> _rebuildIndex(Box<PendingOp> box) async {
  final ops = box.values.toList();
  ops.sort((a, b) => a.queuedAt.compareTo(b.queuedAt));
  return ops;
}

/// Integrity check result
class IntegrityCheckResult {
  final bool isValid;
  final List<String> duplicateOpIds;
  final List<String> invalidTimestamps;
  final int totalOps;

  IntegrityCheckResult({
    required this.isValid,
    required this.duplicateOpIds,
    required this.invalidTimestamps,
    required this.totalOps,
  });
}

/// Verify integrity of pending operations
Future<IntegrityCheckResult> _verifyIntegrity(Box<PendingOp> box) async {
  final ops = box.values.toList();
  final seenIds = <String>{};
  final duplicates = <String>[];
  final invalidTimestamps = <String>[];
  
  for (final op in ops) {
    // Check for duplicate IDs
    if (seenIds.contains(op.opId)) {
      duplicates.add(op.opId);
    } else {
      seenIds.add(op.opId);
    }
    
    // Check for invalid timestamps
    if (op.queuedAt.isAfter(DateTime.now())) {
      invalidTimestamps.add(op.opId);
    }
  }
  
  return IntegrityCheckResult(
    isValid: duplicates.isEmpty && invalidTimestamps.isEmpty,
    duplicateOpIds: duplicates,
    invalidTimestamps: invalidTimestamps,
    totalOps: ops.length,
  );
}

/// Estimate memory usage (rough approximation)
double _estimateMemoryUsageMB() {
  // This is a simplified estimation
  // In production, use vm_service or developer.Service for accurate measurements
  final info = ProcessInfo.currentRss;
  return info / (1024 * 1024);
}

/// Print formatted metrics
void _printMetrics(String label, PerformanceMetrics metrics) {
  print('\n📊 $label Performance:');
  print('   Enqueue:        ${metrics.enqueueTimeMs}ms');
  print('   Sort/Rebuild:   ${metrics.sortTimeMs}ms');
  print('   Get Oldest(10): ${metrics.getOldest10TimeMs}ms');
  print('   Get Oldest(100): ${metrics.getOldest100TimeMs}ms');
  print('   Get Oldest(1K):  ${metrics.getOldest1000TimeMs}ms');
  print('   Integrity Check: ${metrics.integrityCheckTimeMs}ms');
  print('   Memory Usage:    ${metrics.memoryUsageMB.toStringAsFixed(2)}MB');
  print('   Total Time:      ${metrics.totalTimeMs}ms');
}
