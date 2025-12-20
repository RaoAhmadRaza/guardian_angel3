import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';

import 'package:guardian_angel_fyp/sync/pending_queue_service.dart';
import 'package:guardian_angel_fyp/sync/models/pending_op.dart';

void main() {
  group('PendingQueueService', () {
    late PendingQueueService queue;
    late String tempDir;

    setUp(() async {
      // Create temp directory for Hive
      tempDir = Directory.systemTemp.createTempSync('queue_test_').path;
      await Hive.initFlutter(tempDir);

      // Open boxes
      final pendingBox = await Hive.openBox('pending_ops');
      final indexBox = await Hive.openBox('pending_ops_index');
      final failedBox = await Hive.openBox('failed_ops');

      queue = PendingQueueService(pendingBox, indexBox, failedBox);
    });

    tearDown(() async {
      await Hive.close();
      Directory(tempDir).deleteSync(recursive: true);
    });

    group('enqueue', () {
      test('Adds operation to queue atomically', () async {
        final op = PendingOp(
          id: 'test-op-1',
          opType: 'CREATE',
          entityType: 'USER',
          payload: {'name': 'John'},
        );

        await queue.enqueue(op);

        final oldest = await queue.getOldest();
        expect(oldest, isNotNull);
        expect(oldest!.id, op.id);
        expect(oldest.opType, 'CREATE');
        expect(oldest.entityType, 'USER');
      });

      test('Maintains FIFO order with multiple operations', () async {
        final op1 = PendingOp(
          id: 'test-op-alice',
          opType: 'CREATE',
          entityType: 'USER',
          payload: {'name': 'Alice'},
        );
        await Future.delayed(const Duration(milliseconds: 10));

        final op2 = PendingOp(
          id: 'test-op-bob',
          opType: 'CREATE',
          entityType: 'USER',
          payload: {'name': 'Bob'},
        );
        await Future.delayed(const Duration(milliseconds: 10));

        final op3 = PendingOp(
          id: 'test-op-charlie',
          opType: 'CREATE',
          entityType: 'USER',
          payload: {'name': 'Charlie'},
        );

        await queue.enqueue(op1);
        await queue.enqueue(op2);
        await queue.enqueue(op3);

        // Should process in FIFO order
        final first = await queue.getOldest();
        expect(first!.id, op1.id);

        await queue.markProcessed(first.id);

        final second = await queue.getOldest();
        expect(second!.id, op2.id);

        await queue.markProcessed(second.id);

        final third = await queue.getOldest();
        expect(third!.id, op3.id);
      });

      test('Updates index atomically with operation', () async {
        final op = PendingOp(
          id: 'test-op-room',
          opType: 'UPDATE',
          entityType: 'ROOM',
          payload: {'id': 'room-123'},
        );

        await queue.enqueue(op);

        final indexBox = Hive.box('pending_ops_index');
        final index = indexBox.get('order', defaultValue: <Map>[]) as List;

        expect(index.length, 1);
        expect(index[0]['id'], op.id);
        expect(index[0]['created_at'], isA<String>());
      });
    });

    group('getOldest', () {
      test('Returns null when queue is empty', () async {
        final oldest = await queue.getOldest();
        expect(oldest, isNull);
      });

      test('Returns oldest operation without removing it', () async {
        final op = PendingOp(
          id: 'test-op-device',
          opType: 'DELETE',
          entityType: 'DEVICE',
          payload: {'id': 'device-456'},
        );

        await queue.enqueue(op);

        final oldest1 = await queue.getOldest();
        final oldest2 = await queue.getOldest();

        expect(oldest1!.id, oldest2!.id);
      });

      test('Returns oldest operation even after multiple enqueues', () async {
        final op1 = PendingOp(
          id: 'test-op-first',
          opType: 'CREATE',
          entityType: 'USER',
          payload: {'name': 'First'},
        );
        await Future.delayed(const Duration(milliseconds: 10));

        final op2 = PendingOp(
          id: 'test-op-second',
          opType: 'CREATE',
          entityType: 'USER',
          payload: {'name': 'Second'},
        );

        await queue.enqueue(op1);
        await queue.enqueue(op2);

        final oldest = await queue.getOldest();
        expect(oldest!.id, op1.id);
      });
    });

    group('markProcessed', () {
      test('Removes operation from queue', () async {
        final op = PendingOp(
          id: 'test-op-automation',
          opType: 'CREATE',
          entityType: 'AUTOMATION',
          payload: {'name': 'Turn on lights'},
        );

        await queue.enqueue(op);
        await queue.markProcessed(op.id);

        final oldest = await queue.getOldest();
        expect(oldest, isNull);
      });

      test('Removes operation from index', () async {
        final op = PendingOp(
          id: 'test-op-room789',
          opType: 'UPDATE',
          entityType: 'ROOM',
          payload: {'id': 'room-789'},
        );

        await queue.enqueue(op);
        await queue.markProcessed(op.id);

        final indexBox = Hive.box('pending_ops_index');
        final index = indexBox.get('order', defaultValue: <Map>[]) as List;

        expect(index, isEmpty);
      });

      test('Does not affect other operations in queue', () async {
        final op1 = PendingOp(
          id: 'test-op-alice2',
          opType: 'CREATE',
          entityType: 'USER',
          payload: {'name': 'Alice'},
        );
        await Future.delayed(const Duration(milliseconds: 10));

        final op2 = PendingOp(
          id: 'test-op-bob2',
          opType: 'CREATE',
          entityType: 'USER',
          payload: {'name': 'Bob'},
        );

        await queue.enqueue(op1);
        await queue.enqueue(op2);

        await queue.markProcessed(op1.id);

        final oldest = await queue.getOldest();
        expect(oldest!.id, op2.id);
      });
    });

    group('markFailed', () {
      test('Moves operation to failed_ops box', () async {
        final op = PendingOp(
          id: 'test-op-device999',
          opType: 'DELETE',
          entityType: 'DEVICE',
          payload: {'id': 'device-999'},
        );

        await queue.enqueue(op);
        await queue.markFailed(
          op.id,
          {'reason': 'network_error'},
          attempts: 5,
        );

        final failedBox = Hive.box('failed_ops');
        final failedOp = failedBox.get(op.id);

        expect(failedOp, isNotNull);
        expect(failedOp['operation']['id'], op.id);
        expect(failedOp['error']['reason'], 'network_error');
        expect(failedOp['attempts'], 5);
      });

      test('Removes operation from pending queue', () async {
        final op = PendingOp(
          id: 'test-op-health',
          opType: 'UPDATE',
          entityType: 'HEALTH_DATA',
          payload: {'heart_rate': 75},
        );

        await queue.enqueue(op);
        await queue.markFailed(
          op.id,
          {'reason': 'validation_error'},
          attempts: 1,
        );

        final oldest = await queue.getOldest();
        expect(oldest, isNull);
      });

      test('Removes operation from index', () async {
        final op = PendingOp(
          id: 'test-op-bedroom',
          opType: 'CREATE',
          entityType: 'ROOM',
          payload: {'name': 'Bedroom'},
        );

        await queue.enqueue(op);
        await queue.markFailed(
          op.id,
          {'reason': 'permission_denied'},
          attempts: 2,
        );

        final indexBox = Hive.box('pending_ops_index');
        final index = indexBox.get('order', defaultValue: <Map>[]) as List;

        expect(index, isEmpty);
      });
    });

    group('update', () {
      test('Updates operation in pending box', () async {
        final op = PendingOp(
          id: 'test-op-original',
          opType: 'CREATE',
          entityType: 'USER',
          payload: {'name': 'Original'},
        );

        await queue.enqueue(op);

        op.attempts = 3;
        op.nextAttemptAt = DateTime.now().toUtc().add(const Duration(seconds: 60));
        op.status = 'queued';

        await queue.update(op);

        final pendingBox = Hive.box('pending_ops');
        final updated = pendingBox.get(op.id);

        expect(updated['attempts'], 3);
        expect(updated['status'], 'queued');
      });

      test('Does not affect index order', () async {
        final op1 = PendingOp(
          id: 'test-op-first-update',
          opType: 'CREATE',
          entityType: 'USER',
          payload: {'name': 'First'},
        );
        await Future.delayed(const Duration(milliseconds: 10));

        final op2 = PendingOp(
          id: 'test-op-second-update',
          opType: 'CREATE',
          entityType: 'USER',
          payload: {'name': 'Second'},
        );

        await queue.enqueue(op1);
        await queue.enqueue(op2);

        op1.attempts = 5;
        await queue.update(op1);

        final oldest = await queue.getOldest();
        expect(oldest!.id, op1.id); // Still first in FIFO order
      });
    });

    group('rebuildIndex', () {
      test('Rebuilds index from pending operations', () async {
        final op1 = PendingOp(
          id: 'test-op-rebuild-alice',
          opType: 'CREATE',
          entityType: 'USER',
          payload: {'name': 'Alice'},
        );
        await Future.delayed(const Duration(milliseconds: 10));

        final op2 = PendingOp(
          id: 'test-op-rebuild-bob',
          opType: 'CREATE',
          entityType: 'USER',
          payload: {'name': 'Bob'},
        );

        await queue.enqueue(op1);
        await queue.enqueue(op2);

        // Corrupt index
        final indexBox = Hive.box('pending_ops_index');
        await indexBox.clear();

        // Rebuild
        await queue.rebuildIndex();

        final index = indexBox.get('order', defaultValue: <Map>[]) as List;
        expect(index.length, 2);

        // Check FIFO order preserved
        final oldest = await queue.getOldest();
        expect(oldest!.id, op1.id);
      });

      test('Rebuilds empty index when no operations exist', () async {
        await queue.rebuildIndex();

        final indexBox = Hive.box('pending_ops_index');
        final index = indexBox.get('order', defaultValue: <Map>[]) as List;

        expect(index, isEmpty);
      });

      test('Sorts operations by created_at timestamp', () async {
        // Create operations with explicit timestamps
        final now = DateTime.now().toUtc();

        final op1 = PendingOp(
          id: 'test-op-third',
          opType: 'CREATE',
          entityType: 'USER',
          payload: {'name': 'Third'},
          createdAt: now.add(const Duration(seconds: 20)),
        );

        final op2 = PendingOp(
          id: 'test-op-first-sort',
          opType: 'CREATE',
          entityType: 'USER',
          payload: {'name': 'First'},
          createdAt: now,
        );

        final op3 = PendingOp(
          id: 'test-op-second-sort',
          opType: 'CREATE',
          entityType: 'USER',
          payload: {'name': 'Second'},
          createdAt: now.add(const Duration(seconds: 10)),
        );

        // Enqueue in wrong order
        await queue.enqueue(op1);
        await queue.enqueue(op2);
        await queue.enqueue(op3);

        await queue.rebuildIndex();

        // Should process in chronological order
        final first = await queue.getOldest();
        expect(first!.id, op2.id);

        await queue.markProcessed(first.id);

        final second = await queue.getOldest();
        expect(second!.id, op3.id);

        await queue.markProcessed(second.id);

        final third = await queue.getOldest();
        expect(third!.id, op1.id);
      });
    });

    group('Integration Tests', () {
      test('Complete workflow: enqueue → process → remove', () async {
        final op = PendingOp(
          id: 'test-op-living-room',
          opType: 'CREATE',
          entityType: 'ROOM',
          payload: {'name': 'Living Room'},
        );

        await queue.enqueue(op);

        final oldest = await queue.getOldest();
        expect(oldest, isNotNull);

        await queue.markProcessed(oldest!.id);

        final afterRemoval = await queue.getOldest();
        expect(afterRemoval, isNull);
      });

      test('Retry workflow: enqueue → fail → update → retry', () async {
        final op = PendingOp(
          id: 'test-op-device-retry',
          opType: 'UPDATE',
          entityType: 'DEVICE',
          payload: {'id': 'device-123'},
        );

        await queue.enqueue(op);

        final oldest = await queue.getOldest();
        expect(oldest, isNotNull);

        // Simulate retry
        oldest!.attempts = 1;
        oldest.nextAttemptAt = DateTime.now().toUtc().add(const Duration(seconds: 5));
        await queue.update(oldest);

        final retried = await queue.getOldest();
        expect(retried!.attempts, 1);
      });

      test('Failed operation workflow: enqueue → markFailed', () async {
        final op = PendingOp(
          id: 'test-op-user-failed',
          opType: 'DELETE',
          entityType: 'USER',
          payload: {'id': 'user-456'},
        );

        await queue.enqueue(op);

        await queue.markFailed(
          op.id,
          {'reason': 'max_attempts_exhausted'},
          attempts: 5,
        );

        final oldest = await queue.getOldest();
        expect(oldest, isNull);

        final failedBox = Hive.box('failed_ops');
        final failedOp = failedBox.get(op.id);
        expect(failedOp, isNotNull);
      });
    });
  });
}
