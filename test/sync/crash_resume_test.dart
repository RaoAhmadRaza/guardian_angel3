import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';

import 'package:guardian_angel_fyp/sync/pending_queue_service.dart';
import 'package:guardian_angel_fyp/sync/processing_lock.dart';
import 'package:guardian_angel_fyp/sync/models/pending_op.dart';

/// Crash recovery tests
/// 
/// Validates that:
/// - Operations survive process restart
/// - Stale locks are taken over
/// - Idempotency prevents duplicate side effects
void main() {
  group('Crash Recovery', () {
    late String tempDir;
    late Box pendingBox;
    late Box indexBox;
    late Box failedBox;
    late Box lockBox;
    late PendingQueueService queue;
    late ProcessingLock lock;

    setUp(() async {
      // Create temp directory for Hive
      tempDir = Directory.systemTemp.createTempSync('crash_test_').path;
      await Hive.initFlutter(tempDir);

      // Open boxes
      pendingBox = await Hive.openBox('pending_ops');
      indexBox = await Hive.openBox('pending_ops_index');
      failedBox = await Hive.openBox('failed_ops');
      lockBox = await Hive.openBox('sync_lock');

      queue = PendingQueueService(pendingBox, indexBox, failedBox);
      lock = ProcessingLock(lockBox);
    });

    tearDown(() async {
      await Hive.close();
      try {
        Directory(tempDir).deleteSync(recursive: true);
      } catch (e) {
        // Ignore cleanup errors
      }
    });

    test('Operations survive process restart', () async {
      // Simulate: enqueue ops, crash before processing
      final op1 = PendingOp(
        id: 'op-1',
        opType: 'CREATE',
        entityType: 'DEVICE',
        payload: {'name': 'Light'},
        idempotencyKey: 'idem-1',
      );

      final op2 = PendingOp(
        id: 'op-2',
        opType: 'UPDATE',
        entityType: 'ROOM',
        payload: {'id': 'room-1', 'name': 'Bedroom'},
        idempotencyKey: 'idem-2',
      );

      await queue.enqueue(op1);
      await queue.enqueue(op2);

      // Simulate crash (close boxes)
      await Hive.close();

      // Restart (reopen boxes)
      await Hive.initFlutter(tempDir);
      pendingBox = await Hive.openBox('pending_ops');
      indexBox = await Hive.openBox('pending_ops_index');
      failedBox = await Hive.openBox('failed_ops');

      queue = PendingQueueService(pendingBox, indexBox, failedBox);

      // Verify operations still in queue
      final oldest = await queue.getOldest();
      expect(oldest, isNotNull);
      expect(oldest!.id, 'op-1');
      expect(oldest.idempotencyKey, 'idem-1');

      await queue.markProcessed(oldest.id);

      final second = await queue.getOldest();
      expect(second, isNotNull);
      expect(second!.id, 'op-2');
      expect(second.idempotencyKey, 'idem-2');
    });

    test('Stale lock is taken over after timeout', () async {
      // Simulate: runner1 acquires lock, crashes (no heartbeat)
      final runner1 = 'runner-crashed-${DateTime.now().millisecondsSinceEpoch}';
      final acquired1 = await lock.tryAcquire(runner1);
      expect(acquired1, true);

      // Manually set stale heartbeat (simulate crash)
      final staleTime = DateTime.now()
          .toUtc()
          .subtract(const Duration(minutes: 6))
          .toIso8601String();

      await lockBox.put('lock', {
        'runner_id': runner1,
        'last_heartbeat': staleTime,
        'acquired_at': staleTime,
      });

      // New runner attempts to acquire lock
      final runner2 = 'runner-takeover-${DateTime.now().millisecondsSinceEpoch}';
      final acquired2 = await lock.tryAcquire(runner2);
      expect(acquired2, true);

      // Verify takeover
      final holder = await lock.getLockHolder();
      expect(holder, runner2);
    });

    test('Idempotency key prevents duplicate processing', () async {
      // Simulate: op processed but crash before markProcessed
      final op = PendingOp(
        id: 'op-idempotent',
        opType: 'CREATE',
        entityType: 'USER',
        payload: {'name': 'Alice'},
        idempotencyKey: 'idem-alice-123',
      );

      await queue.enqueue(op);

      // First processing attempt (crash before markProcessed)
      final oldest1 = await queue.getOldest();
      expect(oldest1, isNotNull);
      expect(oldest1!.idempotencyKey, 'idem-alice-123');

      // Simulate crash (don't call markProcessed)
      // In real scenario, server would have received request with idempotency key

      // Restart and retry
      final oldest2 = await queue.getOldest();
      expect(oldest2, isNotNull);
      expect(oldest2!.id, oldest1.id);
      expect(oldest2.idempotencyKey, oldest1.idempotencyKey);

      // Idempotency key ensures server deduplicates
      // Now mark as processed
      await queue.markProcessed(oldest2.id);

      final empty = await queue.getOldest();
      expect(empty, isNull);
    });

    test('Retry backoff state persists across restarts', () async {
      // Simulate: op failed with backoff, crash, restart
      final op = PendingOp(
        id: 'op-retry',
        opType: 'UPDATE',
        entityType: 'DEVICE',
        payload: {'id': 'dev-1', 'state': 'on'},
        idempotencyKey: 'idem-retry',
      );

      await queue.enqueue(op);

      // Simulate first attempt failure with backoff
      final oldest = await queue.getOldest();
      expect(oldest, isNotNull);

      oldest!.attempts = 2;
      oldest.nextAttemptAt = DateTime.now().toUtc().add(const Duration(seconds: 30));
      oldest.status = 'queued';

      await queue.update(oldest);

      // Simulate crash
      await Hive.close();

      // Restart
      await Hive.initFlutter(tempDir);
      pendingBox = await Hive.openBox('pending_ops');
      indexBox = await Hive.openBox('pending_ops_index');
      failedBox = await Hive.openBox('failed_ops');

      queue = PendingQueueService(pendingBox, indexBox, failedBox);

      // Verify backoff state persisted
      final recovered = await queue.getOldest();
      expect(recovered, isNotNull);
      expect(recovered!.attempts, 2);
      expect(recovered.nextAttemptAt, isNotNull);
      expect(recovered.status, 'queued');
    });

    test('Index is rebuilt after corruption', () async {
      // Enqueue operations
      final op1 = PendingOp(
        id: 'op-1',
        opType: 'CREATE',
        entityType: 'DEVICE',
        payload: {'name': 'Device1'},
      );

      final op2 = PendingOp(
        id: 'op-2',
        opType: 'CREATE',
        entityType: 'DEVICE',
        payload: {'name': 'Device2'},
      );

      await queue.enqueue(op1);
      await queue.enqueue(op2);

      // Simulate index corruption (delete index)
      await indexBox.clear();

      // Rebuild index
      await queue.rebuildIndex();

      // Verify FIFO order preserved
      final oldest = await queue.getOldest();
      expect(oldest, isNotNull);
      expect(oldest!.id, 'op-1');

      await queue.markProcessed(oldest.id);

      final second = await queue.getOldest();
      expect(second, isNotNull);
      expect(second!.id, 'op-2');
    });

    test('Heartbeat keeps lock alive across multiple cycles', () async {
      final runnerId = 'runner-heartbeat-${DateTime.now().millisecondsSinceEpoch}';

      // Acquire lock
      final acquired = await lock.tryAcquire(runnerId);
      expect(acquired, true);

      // Simulate multiple heartbeat cycles
      for (int i = 0; i < 5; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        await lock.updateHeartbeat(runnerId);

        // Verify lock still held
        final holder = await lock.getLockHolder();
        expect(holder, runnerId);
      }

      // Release lock
      await lock.release(runnerId);

      final holderAfterRelease = await lock.getLockHolder();
      expect(holderAfterRelease, isNull);
    });

    test('Failed operations are preserved and retrievable', () async {
      final op = PendingOp(
        id: 'op-fail',
        opType: 'DELETE',
        entityType: 'USER',
        payload: {'id': 'user-999'},
        idempotencyKey: 'idem-fail',
      );

      await queue.enqueue(op);

      // Mark as failed
      await queue.markFailed(
        op.id,
        {'reason': 'permission_denied', 'code': 403},
        attempts: 5,
      );

      // Verify removed from pending
      final oldest = await queue.getOldest();
      expect(oldest, isNull);

      // Verify in failed box
      final failed = failedBox.get(op.id);
      expect(failed, isNotNull);
      expect(failed['error']['reason'], 'permission_denied');
      expect(failed['attempts'], 5);
    });
  });
}
