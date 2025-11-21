import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_test/hive_test.dart';
import 'package:hive/hive.dart';
import 'package:guardian_angel_fyp/persistence/index/pending_index.dart';

/// Performance stress tests for pending operations queue
/// 
/// Tests verify:
/// - Index rebuild performance with large datasets
/// - Query performance (getOldest)
/// - Memory usage patterns
/// 
/// These tests use simplified models (Map<String, dynamic>) to focus on
/// index and box performance rather than full PendingOp serialization.
void main() {
  setUp(() async {
    await setUpTestHive();
  });

  tearDown(() async {
    await tearDownTestHive();
  });

  group('Queue Index Performance', () {
    test('rebuild index with 5k entries completes in reasonable time', () async {
      await Hive.openBox('pending_ops_box');
      await Hive.openBox('pending_index_box');
      
      final pendingBox = Hive.box('pending_ops_box');
      final index = await PendingIndex.create();

      // Seed 5k operations as simple maps
      const totalOps = 5000;
      print('Seeding $totalOps operations...');

      for (int i = 0; i < totalOps; i++) {
        final timestamp = DateTime(2024, 1, 15, 10, 0).toUtc().add(Duration(seconds: i));
        final opId = 'op_${i.toString().padLeft(5, '0')}';

        final opData = {
          'id': opId,
          'opType': 'control',
          'idempotencyKey': 'idem_$opId',
          'payload': {'deviceId': 'dev_$i'},
          'attempts': 0,
          'status': 'pending',
          'createdAt': timestamp.toIso8601String(),
          'updatedAt': timestamp.toIso8601String(),
        };

        await pendingBox.put(opId, opData);
        await index.enqueue(opId, timestamp);
      }

      print('✓ Seeded $totalOps operations');
      expect(pendingBox.length, totalOps);

      // Measure rebuild time
      final stopwatch = Stopwatch()..start();
      await index.rebuild();
      stopwatch.stop();

      print('✓ rebuildIndex() with $totalOps ops: ${stopwatch.elapsedMilliseconds}ms');

      expect(stopwatch.elapsedMilliseconds, lessThan(15000), 
          reason: 'Rebuild should complete in under 15 seconds');

      // Verify index still works
      final oldest = await index.getOldestIds(1);
      expect(oldest.first, 'op_00000');
    });

    test('query performance with 1k entries', () async {
      await Hive.openBox('pending_ops_box');
      await Hive.openBox('pending_index_box');
      
      final pendingBox = Hive.box('pending_ops_box');
      final index = await PendingIndex.create();

      // Seed 1k operations
      const totalOps = 1000;

      for (int i = 0; i < totalOps; i++) {
        final timestamp = DateTime(2024, 1, 15, 10, 0).toUtc().add(Duration(seconds: i));
        final opId = 'op_${i.toString().padLeft(5, '0')}';

        final opData = {
          'id': opId,
          'createdAt': timestamp.toIso8601String(),
        };

        await pendingBox.put(opId, opData);
        await index.enqueue(opId, timestamp);
      }

      // Measure query performance
      final stopwatch = Stopwatch()..start();
      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        final oldest = await index.getOldestIds(1);
        expect(oldest, isNotEmpty);
      }

      stopwatch.stop();
      final avgMs = stopwatch.elapsedMilliseconds / iterations;

      print('✓ getOldestIds() performance with $totalOps ops:');
      print('  $iterations queries in ${stopwatch.elapsedMilliseconds}ms');
      print('  Average: ${avgMs.toStringAsFixed(2)}ms per query');

      expect(avgMs, lessThan(50), 
          reason: 'Should average under 50ms per query with 1k ops');
    });

    test('remove performance with 500 entries', () async {
      await Hive.openBox('pending_ops_box');
      await Hive.openBox('pending_index_box');
      
      final pendingBox = Hive.box('pending_ops_box');
      final index = await PendingIndex.create();

      // Seed 500 operations
      const totalOps = 500;

      for (int i = 0; i < totalOps; i++) {
        final timestamp = DateTime(2024, 1, 15, 10, 0).toUtc().add(Duration(seconds: i));
        final opId = 'op_${i.toString().padLeft(5, '0')}';

        final opData = {
          'id': opId,
          'createdAt': timestamp.toIso8601String(),
        };

        await pendingBox.put(opId, opData);
        await index.enqueue(opId, timestamp);
      }

      // Measure remove performance (dequeue operation)
      final stopwatch = Stopwatch()..start();
      int removed = 0;

      while (removed < 100) {
        final oldest = await index.getOldestIds(1);
        if (oldest.isEmpty) break;

        final opId = oldest.first;
        await pendingBox.delete(opId);
        await index.remove(opId);
        removed++;
      }

      stopwatch.stop();
      final avgMs = stopwatch.elapsedMilliseconds / removed;

      print('✓ Remove performance:');
      print('  $removed operations in ${stopwatch.elapsedMilliseconds}ms');
      print('  Average: ${avgMs.toStringAsFixed(2)}ms per remove');

      expect(avgMs, lessThan(30), 
          reason: 'Should average under 30ms per remove operation');
    });

    test('memory usage with 2k entries stays reasonable', () async {
      await Hive.openBox('pending_ops_box');
      await Hive.openBox('pending_index_box');
      
      final pendingBox = Hive.box('pending_ops_box');
      final index = await PendingIndex.create();

      // Record initial memory
      final initialRss = ProcessInfo.currentRss;

      // Seed 2k operations
      const totalOps = 2000;

      for (int i = 0; i < totalOps; i++) {
        final timestamp = DateTime(2024, 1, 15, 10, 0).toUtc().add(Duration(seconds: i));
        final opId = 'op_${i.toString().padLeft(5, '0')}';

        final opData = {
          'id': opId,
          'opType': 'control',
          'payload': {'deviceId': 'dev_$i', 'action': 'toggle'},
          'attempts': 0,
          'createdAt': timestamp.toIso8601String(),
        };

        await pendingBox.put(opId, opData);
        await index.enqueue(opId, timestamp);
      }

      // Record final memory
      final finalRss = ProcessInfo.currentRss;
      final memoryIncreaseMB = (finalRss - initialRss) / (1024 * 1024);

      print('✓ Memory usage with $totalOps ops:');
      print('  Initial RSS: ${(initialRss / (1024 * 1024)).toStringAsFixed(2)} MB');
      print('  Final RSS: ${(finalRss / (1024 * 1024)).toStringAsFixed(2)} MB');
      print('  Increase: ${memoryIncreaseMB.toStringAsFixed(2)} MB');

      // Memory increase should be reasonable (under 50MB for 2k ops)
      expect(memoryIncreaseMB, lessThan(50), 
          reason: 'Memory increase should be under 50MB for 2k ops');
    });

    test('batch operations performance', () async {
      await Hive.openBox('pending_ops_box');
      await Hive.openBox('pending_index_box');
      
      final pendingBox = Hive.box('pending_ops_box');
      final index = await PendingIndex.create();

      // Seed 1k operations
      const totalOps = 1000;
      final ops = <String, Map<String, dynamic>>{};

      for (int i = 0; i < totalOps; i++) {
        final timestamp = DateTime(2024, 1, 15, 10, 0).toUtc().add(Duration(seconds: i));
        final opId = 'op_${i.toString().padLeft(5, '0')}';

        ops[opId] = {
          'id': opId,
          'createdAt': timestamp.toIso8601String(),
        };
      }

      // Measure batch write
      final writeStopwatch = Stopwatch()..start();
      await pendingBox.putAll(ops);
      
      for (final entry in ops.entries) {
        final timestamp = DateTime.parse(entry.value['createdAt'] as String);
        await index.enqueue(entry.key, timestamp);
      }
      writeStopwatch.stop();

      print('✓ Batch write performance:');
      print('  $totalOps operations in ${writeStopwatch.elapsedMilliseconds}ms');

      // Measure batch delete of first 100 operations
      final idsToDelete = ops.keys.take(100).toList();

      final deleteStopwatch = Stopwatch()..start();
      
      await pendingBox.deleteAll(idsToDelete);
      
      for (final id in idsToDelete) {
        await index.remove(id);
      }

      deleteStopwatch.stop();

      print('✓ Batch delete performance:');
      print('  100 deletions in ${deleteStopwatch.elapsedMilliseconds}ms');

      expect(pendingBox.length, totalOps - 100);
      expect(deleteStopwatch.elapsedMilliseconds, lessThan(3000), 
          reason: 'Batch delete should complete in under 3 seconds');
    });
  });
}
