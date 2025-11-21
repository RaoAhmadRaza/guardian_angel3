import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:guardian_angel_fyp/services/lock_service.dart';
import 'package:guardian_angel_fyp/services/models/lock_record.dart';
import 'dart:io';

void main() {
  group('LockService Tests', () {
    late String testPath;
    late LockService lockService1;
    late LockService lockService2;

    setUp(() async {
      testPath = Directory.systemTemp
          .createTempSync('lock_service_test_')
          .path;
      Hive.init(testPath);

      // Register adapters
      if (!Hive.isAdapterRegistered(12)) {
        Hive.registerAdapter(LockRecordAdapter());
      }

      lockService1 = LockService();
      await lockService1.init();

      // Close and reopen Hive with different runner ID for second instance
      // Force new runner ID by deleting the runner metadata
      final runnerBox = Hive.box('runner_metadata');
      await runnerBox.delete('runnerId');
      
      // Second service instance (simulates different process/device)
      lockService2 = LockService();
      await lockService2.init();
    });

    tearDown(() async {
      lockService1.dispose();
      lockService2.dispose();
      await Hive.close();

      try {
        Directory(testPath).deleteSync(recursive: true);
      } catch (_) {}
    });

    test('runner IDs are unique per instance', () {
      expect(lockService1.runnerId, isNotEmpty);
      expect(lockService2.runnerId, isNotEmpty);
      expect(lockService1.runnerId, isNot(equals(lockService2.runnerId)));
    });

    test('acquireLock succeeds when no lock exists', () async {
      final acquired = await lockService1.acquireLock('test_lock');
      expect(acquired, isTrue);

      final lockInfo = lockService1.getLockInfo('test_lock');
      expect(lockInfo, isNotNull);
      expect(lockInfo!.runnerId, equals(lockService1.runnerId));
    });

    test('acquireLock fails when lock held by another runner', () async {
      // Runner 1 acquires lock
      final acquired1 = await lockService1.acquireLock('test_lock');
      expect(acquired1, isTrue);

      // Runner 2 attempts to acquire same lock
      final acquired2 = await lockService2.acquireLock('test_lock');
      expect(acquired2, isFalse);
    });

    test('acquireLock succeeds for same runner (idempotent)', () async {
      final acquired1 = await lockService1.acquireLock('test_lock');
      expect(acquired1, isTrue);

      // Same runner acquires again
      final acquired2 = await lockService1.acquireLock('test_lock');
      expect(acquired2, isTrue);
    });

    test('releaseLock allows another runner to acquire', () async {
      // Runner 1 acquires and releases
      await lockService1.acquireLock('test_lock');
      await lockService1.releaseLock('test_lock');

      // Runner 2 can now acquire
      final acquired = await lockService2.acquireLock('test_lock');
      expect(acquired, isTrue);
    });

    test('renewHeartbeat updates lastHeartbeat timestamp', () async {
      await lockService1.acquireLock('test_lock');

      final lockBefore = lockService1.getLockInfo('test_lock')!;
      final heartbeatBefore = lockBefore.lastHeartbeat;
      final renewalsBefore = lockBefore.renewalCount;

      // Wait a bit and renew
      await Future.delayed(const Duration(milliseconds: 100));
      await lockService1.renewHeartbeat('test_lock');

      final lockAfter = lockService1.getLockInfo('test_lock')!;
      final heartbeatAfter = lockAfter.lastHeartbeat;

      expect(heartbeatAfter.isAfter(heartbeatBefore), isTrue);
      expect(lockAfter.renewalCount, equals(renewalsBefore + 1));
    });

    test('stale lock takeover - lock expires and another runner acquires', () async {
      // Runner 1 acquires lock
      await lockService1.acquireLock('test_lock');

      // Manually set last heartbeat to 10 seconds ago (stale)
      final lockBox = Hive.box<LockRecord>('distributed_locks');
      final lock = lockBox.get('test_lock')!;
      final staleLock = lock.copyWith(
        lastHeartbeat: DateTime.now().subtract(const Duration(seconds: 10)),
      );
      await lockBox.put('test_lock', staleLock);

      // Runner 2 can now take over stale lock
      final acquired = await lockService2.acquireLock('test_lock');
      expect(acquired, isTrue);

      final newLock = lockService2.getLockInfo('test_lock')!;
      expect(newLock.runnerId, equals(lockService2.runnerId));
    });

    test('automatic heartbeat renewal keeps lock alive', () async {
      await lockService1.acquireLock('test_lock');
      lockService1.startHeartbeat('test_lock');

      // Wait for several heartbeat intervals
      await Future.delayed(const Duration(milliseconds: 2500));

      final lock = lockService1.getLockInfo('test_lock')!;
      
      // Heartbeat should have been renewed at least once
      expect(lock.renewalCount, greaterThan(1));
      
      // Lock should not be stale
      expect(lock.isStale(LockService.stalenessThreshold), isFalse);

      lockService1.stopHeartbeat('test_lock');
    });

    test('stopHeartbeat prevents further renewals', () async {
      await lockService1.acquireLock('test_lock');
      lockService1.startHeartbeat('test_lock');

      // Wait for initial heartbeat
      await Future.delayed(const Duration(milliseconds: 1200));
      
      final renewalsBefore = lockService1.getLockInfo('test_lock')!.renewalCount;

      // Stop heartbeat
      lockService1.stopHeartbeat('test_lock');

      // Wait and verify no more renewals
      await Future.delayed(const Duration(milliseconds: 2000));
      
      final renewalsAfter = lockService1.getLockInfo('test_lock')!.renewalCount;
      expect(renewalsAfter, equals(renewalsBefore));
    });

    test('isLockHeld returns correct state', () async {
      expect(lockService1.isLockHeld('test_lock'), isFalse);

      await lockService1.acquireLock('test_lock');
      expect(lockService1.isLockHeld('test_lock'), isTrue);

      await lockService1.releaseLock('test_lock');
      expect(lockService1.isLockHeld('test_lock'), isFalse);
    });

    test('isLockHeldByMe distinguishes between runners', () async {
      await lockService1.acquireLock('test_lock');

      expect(lockService1.isLockHeldByMe('test_lock'), isTrue);
      expect(lockService2.isLockHeldByMe('test_lock'), isFalse);
    });

    test('multiple locks can be held simultaneously', () async {
      await lockService1.acquireLock('lock_a');
      await lockService1.acquireLock('lock_b');
      await lockService2.acquireLock('lock_c');

      expect(lockService1.isLockHeldByMe('lock_a'), isTrue);
      expect(lockService1.isLockHeldByMe('lock_b'), isTrue);
      expect(lockService1.isLockHeldByMe('lock_c'), isFalse);
      expect(lockService2.isLockHeldByMe('lock_c'), isTrue);
    });

    test('releaseAllMyLocks releases all locks for current runner', () async {
      await lockService1.acquireLock('lock_a');
      await lockService1.acquireLock('lock_b');
      await lockService1.acquireLock('lock_c');

      await lockService1.releaseAllMyLocks();

      expect(lockService1.isLockHeldByMe('lock_a'), isFalse);
      expect(lockService1.isLockHeldByMe('lock_b'), isFalse);
      expect(lockService1.isLockHeldByMe('lock_c'), isFalse);
    });

    test('cleanupStaleLocks removes expired locks', () async {
      // Create multiple locks
      await lockService1.acquireLock('lock_1');
      await lockService2.acquireLock('lock_2');

      // Make lock_1 stale
      final lockBox = Hive.box<LockRecord>('distributed_locks');
      final lock1 = lockBox.get('lock_1')!;
      await lockBox.put('lock_1', lock1.copyWith(
        lastHeartbeat: DateTime.now().subtract(const Duration(seconds: 10)),
      ));

      // Cleanup
      final cleaned = await lockService1.cleanupStaleLocks();

      expect(cleaned, equals(1));
      expect(lockService1.isLockHeld('lock_1'), isFalse);
      expect(lockService1.isLockHeld('lock_2'), isTrue);
    });

    test('getStats returns accurate lock statistics', () async {
      await lockService1.acquireLock('lock_a');
      await lockService1.acquireLock('lock_b');
      await lockService2.acquireLock('lock_c');

      final stats = lockService1.getStats();

      expect(stats['runnerId'], equals(lockService1.runnerId));
      expect(stats['totalLocks'], equals(3));
      expect(stats['myLocks'], equals(2));
      expect(stats['activeLocks'], equals(3));
      expect(stats['staleLocks'], equals(0));
    });

    test('lock metadata is stored and retrievable', () async {
      final metadata = {
        'service': 'sync_service',
        'version': '1.0.0',
      };

      await lockService1.acquireLock('test_lock', metadata: metadata);

      final lock = lockService1.getLockInfo('test_lock')!;
      expect(lock.metadata, isNotNull);
      expect(lock.metadata!['service'], equals('sync_service'));
      expect(lock.metadata!['version'], equals('1.0.0'));
    });

    test('concurrent lock attempts - only one succeeds', () async {
      // Simulate concurrent attempts
      final futures = [
        lockService1.acquireLock('contested_lock'),
        lockService2.acquireLock('contested_lock'),
      ];

      final results = await Future.wait(futures);

      // Only one should succeed
      final successCount = results.where((r) => r).length;
      expect(successCount, equals(1));
    });

    test('lock age is tracked correctly', () async {
      await lockService1.acquireLock('test_lock');

      await Future.delayed(const Duration(milliseconds: 100));

      final lock = lockService1.getLockInfo('test_lock')!;
      expect(lock.age.inMilliseconds, greaterThanOrEqualTo(100));
    });

    test('heartbeat failure stops automatic renewal', () async {
      await lockService1.acquireLock('test_lock');
      lockService1.startHeartbeat('test_lock');

      // Wait for heartbeat to start
      await Future.delayed(const Duration(milliseconds: 1200));

      // Release lock (simulates external release or conflict)
      await lockService1.releaseLock('test_lock');

      // Wait for next heartbeat attempt
      await Future.delayed(const Duration(milliseconds: 1200));

      // Heartbeat timer should have stopped due to renewal failure
      final stats = lockService1.getStats();
      expect(stats['activeHeartbeats'], equals(0));
    });

    test('lock persistence across service restarts', () async {
      // Service 1 acquires lock
      await lockService1.acquireLock('persistent_lock');
      lockService1.startHeartbeat('persistent_lock');

      // Create new service instance (simulates restart)
      final lockService3 = LockService();
      await lockService3.init();

      // Lock still exists from previous instance
      final lock = lockService3.getLockInfo('persistent_lock');
      expect(lock, isNotNull);
      expect(lock!.runnerId, equals(lockService1.runnerId));

      lockService3.dispose();
    });

    test('stale threshold configuration is enforced', () async {
      await lockService1.acquireLock('test_lock');

      final lockBox = Hive.box<LockRecord>('distributed_locks');
      final lock = lockBox.get('test_lock')!;

      // 4 seconds ago - not stale yet (threshold is 5s)
      final almostStale = lock.copyWith(
        lastHeartbeat: DateTime.now().subtract(const Duration(seconds: 4)),
      );
      expect(almostStale.isStale(LockService.stalenessThreshold), isFalse);

      // 6 seconds ago - now stale
      final stale = lock.copyWith(
        lastHeartbeat: DateTime.now().subtract(const Duration(seconds: 6)),
      );
      expect(stale.isStale(LockService.stalenessThreshold), isTrue);
    });

    test('getAllLocks returns all lock records', () async {
      await lockService1.acquireLock('lock_a');
      await lockService1.acquireLock('lock_b');
      await lockService2.acquireLock('lock_c');

      final allLocks = lockService1.getAllLocks();

      expect(allLocks.length, equals(3));
      expect(allLocks.map((l) => l.lockName).toSet(), equals({'lock_a', 'lock_b', 'lock_c'}));
    });

    test('lock contention with rapid acquire attempts', () async {
      // Runner 1 holds lock
      await lockService1.acquireLock('hot_lock');

      // Runner 2 attempts multiple times rapidly
      for (int i = 0; i < 10; i++) {
        final acquired = await lockService2.acquireLock('hot_lock');
        expect(acquired, isFalse);
      }

      // Lock still held by runner 1
      expect(lockService1.isLockHeldByMe('hot_lock'), isTrue);
    });

    test('lock takeover timing - just before staleness threshold', () async {
      await lockService1.acquireLock('edge_lock');

      final lockBox = Hive.box<LockRecord>('distributed_locks');
      final lock = lockBox.get('edge_lock')!;

      // Set heartbeat to 4.9 seconds ago (just before 5s threshold)
      await lockBox.put('edge_lock', lock.copyWith(
        lastHeartbeat: DateTime.now().subtract(const Duration(milliseconds: 4900)),
      ));

      // Should NOT be able to take over yet
      final acquired = await lockService2.acquireLock('edge_lock');
      expect(acquired, isFalse);

      // Wait 200ms more to cross threshold
      await Future.delayed(const Duration(milliseconds: 200));

      // Now should be able to take over
      final acquired2 = await lockService2.acquireLock('edge_lock');
      expect(acquired2, isTrue);
    });
  });
}
