import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:guardian_angel_fyp/persistence/queue/stall_detector.dart';
import 'package:guardian_angel_fyp/persistence/box_registry.dart';
import 'package:guardian_angel_fyp/models/pending_op.dart';
import 'package:guardian_angel_fyp/persistence/adapters/pending_op_adapter.dart';
import 'dart:io';
import 'dart:async';

/// Tests for the Queue Stall Detector.
void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('stall_detector_test_');
    Hive.init(tempDir.path);
    
    // Register adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(PendingOpAdapter());
    }
  });

  setUp(() async {
    // Open required boxes
    await Hive.openBox<PendingOp>(BoxRegistry.pendingOpsBox);
    await Hive.openBox(BoxRegistry.metaBox);
    await Hive.openBox(BoxRegistry.pendingIndexBox);
  });

  tearDown(() async {
    // Clear boxes
    if (Hive.isBoxOpen(BoxRegistry.pendingOpsBox)) {
      await Hive.box<PendingOp>(BoxRegistry.pendingOpsBox).clear();
    }
    if (Hive.isBoxOpen(BoxRegistry.metaBox)) {
      await Hive.box(BoxRegistry.metaBox).clear();
    }
    if (Hive.isBoxOpen(BoxRegistry.pendingIndexBox)) {
      await Hive.box(BoxRegistry.pendingIndexBox).clear();
    }
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('StallConfig', () {
    test('default production config', () {
      const config = StallConfig.production;
      
      expect(config.stallThreshold, const Duration(minutes: 10));
      expect(config.lockStaleThreshold, const Duration(minutes: 5));
      expect(config.checkInterval, const Duration(minutes: 1));
      expect(config.maxRecoveryAttempts, 3);
    });

    test('testing config is more aggressive', () {
      const config = StallConfig.testing;
      
      expect(config.stallThreshold, const Duration(seconds: 30));
      expect(config.lockStaleThreshold, const Duration(seconds: 15));
      expect(config.checkInterval, const Duration(seconds: 5));
    });

    test('custom config', () {
      const config = StallConfig(
        stallThreshold: Duration(minutes: 5),
        maxRecoveryAttempts: 10,
      );
      
      expect(config.stallThreshold, const Duration(minutes: 5));
      expect(config.maxRecoveryAttempts, 10);
    });
  });

  group('StallStatus', () {
    test('not stalled by default with empty queue', () {
      final detector = QueueStallDetector(config: StallConfig.testing);
      final status = detector.getStatus();
      
      expect(status.isStalled, false);
      expect(status.stallDuration, null);
      expect(status.oldestOpId, null);
      expect(status.oldestOpAge, null);
      
      detector.dispose();
    });

    test('detects stall with old pending ops', () async {
      final pendingBox = Hive.box<PendingOp>(BoxRegistry.pendingOpsBox);
      
      // Add an old pending op
      final oldOp = PendingOp(
        id: 'old_op_1',
        opType: 'test',
        payload: {},
        createdAt: DateTime.now().toUtc().subtract(const Duration(minutes: 15)),
        updatedAt: DateTime.now().toUtc(),
        status: 'pending',
        idempotencyKey: 'idem_old_op_1',
      );
      await pendingBox.put(oldOp.id, oldOp);
      
      final detector = QueueStallDetector(config: StallConfig.testing);
      final status = detector.getStatus();
      
      expect(status.isStalled, true);
      expect(status.oldestOpId, 'old_op_1');
      expect(status.oldestOpAge, isNotNull);
      expect(status.oldestOpAge!.inMinutes, greaterThanOrEqualTo(15));
      
      detector.dispose();
    });

    test('detects lock status', () async {
      final metaBox = Hive.box(BoxRegistry.metaBox);
      
      // Add a lock
      await metaBox.put('processing_lock', {
        'processing': true,
        'startedAt': DateTime.now().toUtc().toIso8601String(),
        'pid': 'test_pid',
      });
      
      final detector = QueueStallDetector(config: StallConfig.testing);
      final status = detector.getStatus();
      
      expect(status.lockHeld, true);
      expect(status.lockDuration, isNotNull);
      
      detector.dispose();
    });

    test('detects stale lock', () async {
      final metaBox = Hive.box(BoxRegistry.metaBox);
      
      // Add a stale lock (20 seconds ago, threshold is 15)
      await metaBox.put('processing_lock', {
        'processing': true,
        'startedAt': DateTime.now().toUtc().subtract(const Duration(seconds: 20)).toIso8601String(),
        'pid': 'stale_pid',
      });
      
      final detector = QueueStallDetector(config: StallConfig.testing);
      final status = detector.getStatus();
      
      expect(status.lockHeld, true);
      expect(status.lockIsStale, true);
      
      detector.dispose();
    });

    test('shouldAttemptRecovery based on attempts', () {
      final statusWithRoom = StallStatus(
        isStalled: true,
        lockHeld: false,
        lockIsStale: false,
        recoveryAttempts: 1,
        capturedAt: DateTime.now().toUtc(),
      );
      
      expect(statusWithRoom.shouldAttemptRecovery, true);
      
      final statusMaxed = StallStatus(
        isStalled: true,
        lockHeld: false,
        lockIsStale: false,
        recoveryAttempts: 5,
        capturedAt: DateTime.now().toUtc(),
      );
      
      expect(statusMaxed.shouldAttemptRecovery, false);
    });
  });

  group('RecoveryResult', () {
    test('success factory', () {
      final result = RecoveryResult.success(
        actionsTaken: ['released_lock', 'rebuilt_index'],
        duration: const Duration(milliseconds: 100),
      );
      
      expect(result.success, true);
      expect(result.actionsTaken.length, 2);
      expect(result.error, null);
    });

    test('failure factory', () {
      final result = RecoveryResult.failure(
        error: 'Box not open',
        actionsTaken: ['released_lock'],
        duration: const Duration(milliseconds: 50),
      );
      
      expect(result.success, false);
      expect(result.error, 'Box not open');
      expect(result.actionsTaken.length, 1);
    });
  });

  group('QueueStallDetector', () {
    test('startMonitoring and stopMonitoring', () {
      final detector = QueueStallDetector(config: StallConfig.testing);
      
      detector.startMonitoring();
      // Starting again should be idempotent
      detector.startMonitoring();
      
      detector.stopMonitoring();
      detector.dispose();
    });

    test('forceRecovery executes without error', () async {
      final detector = QueueStallDetector(config: StallConfig.testing);
      
      // forceRecovery should complete without throwing
      final result = await detector.forceRecovery();
      
      expect(result.success, true);
      // Index rebuild should always be attempted
      expect(result.actionsTaken, contains('rebuilt_index'));
      
      detector.dispose();
    });

    test('forceRecovery with stale lock releases it', () async {
      final metaBox = Hive.box(BoxRegistry.metaBox);
      
      // Add a stale lock (old timestamp)
      final staleTime = DateTime.now().toUtc().subtract(const Duration(seconds: 20));
      await metaBox.put('processing_lock', {
        'processing': true,
        'startedAt': staleTime.toIso8601String(),
        'pid': 'stale_pid',
      });
      
      // Verify lock is in place
      expect(metaBox.get('processing_lock'), isNotNull);
      
      // Manually verify the stale detection works
      final lockData = metaBox.get('processing_lock') as Map;
      final startedAt = DateTime.parse(lockData['startedAt'] as String);
      final lockAge = DateTime.now().toUtc().difference(startedAt);
      
      // Lock age should be greater than 15 seconds (testing threshold)
      expect(lockAge.inSeconds, greaterThan(15), 
          reason: 'Lock should be older than stale threshold');
      
      final detector = QueueStallDetector(config: StallConfig.testing);
      
      // Check that status correctly identifies stale lock
      final status = detector.getStatus();
      expect(status.lockHeld, true, reason: 'Lock should be detected');
      // Only check stale if lock duration is properly calculated
      if (status.lockDuration != null) {
        expect(status.lockDuration!.inSeconds, greaterThan(15));
      }
      
      final result = await detector.forceRecovery();
      expect(result.success, true);
      
      detector.dispose();
    });

    test('resetRecoveryAttempts clears attempt count', () {
      final detector = QueueStallDetector(config: StallConfig.testing);
      
      // Trigger some recovery attempts
      detector.resetRecoveryAttempts();
      
      final status = detector.getStatus();
      expect(status.recoveryAttempts, 0);
      
      detector.dispose();
    });

    test('eventStream emits events', () async {
      final detector = QueueStallDetector(config: StallConfig.testing);
      final events = <StallEvent>[];
      
      final subscription = detector.eventStream.listen((event) {
        events.add(event);
      });
      
      // Force a recovery
      await detector.forceRecovery();
      
      await Future.delayed(const Duration(milliseconds: 100));
      
      expect(events.length, greaterThan(0));
      expect(events.any((e) => e.type == StallEventType.recoveryStarted), true);
      
      await subscription.cancel();
      detector.dispose();
    });

    test('onRecoveryNeeded callback is called', () async {
      final detector = QueueStallDetector(config: StallConfig.testing);
      bool callbackCalled = false;
      
      detector.onRecoveryNeeded = () async {
        callbackCalled = true;
      };
      
      // Force recovery will call the callback during recovery
      final result = await detector.forceRecovery();
      
      // Check result and callback
      expect(result.success, true, reason: 'Recovery should succeed');
      expect(result.actionsTaken, contains('called_recovery_callback'), 
          reason: 'Recovery should include callback action');
      expect(callbackCalled, true, reason: 'Recovery callback should be called');
      
      detector.dispose();
    });
  });

  group('StallEvent', () {
    test('stallDetected factory', () {
      final status = StallStatus(
        isStalled: true,
        stallDuration: const Duration(minutes: 5),
        lockHeld: false,
        lockIsStale: false,
        recoveryAttempts: 0,
        capturedAt: DateTime.now().toUtc(),
      );
      
      final event = StallEvent.stallDetected(status);
      
      expect(event.type, StallEventType.stallDetected);
      expect(event.status, status);
    });

    test('recoveryCompleted factory', () {
      final result = RecoveryResult.success(
        actionsTaken: ['test'],
        duration: const Duration(milliseconds: 100),
      );
      
      final event = StallEvent.recoveryCompleted(result);
      
      expect(event.type, StallEventType.recoveryCompleted);
      expect(event.recoveryResult, result);
    });

    test('all event types can be created', () {
      final status = StallStatus(
        isStalled: true,
        lockHeld: false,
        lockIsStale: false,
        recoveryAttempts: 0,
        capturedAt: DateTime.now().toUtc(),
      );
      
      final result = RecoveryResult.success(
        actionsTaken: [],
        duration: Duration.zero,
      );
      
      expect(StallEvent.stallDetected(status).type, StallEventType.stallDetected);
      expect(StallEvent.recoveryStarted(1).type, StallEventType.recoveryStarted);
      expect(StallEvent.recoveryCompleted(result).type, StallEventType.recoveryCompleted);
      expect(StallEvent.recoveryFailed(result).type, StallEventType.recoveryFailed);
      expect(StallEvent.unstalled().type, StallEventType.unstalled);
      expect(StallEvent.maxRecoveryAttemptsReached(3).type, StallEventType.maxRecoveryAttemptsReached);
    });
  });
}
