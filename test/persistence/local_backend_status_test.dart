import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:guardian_angel_fyp/persistence/local_backend_status.dart';
import 'package:guardian_angel_fyp/persistence/adapters/pending_op_adapter.dart';
import 'dart:io';

/// Tests for the enhanced Local Backend Status.
void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('local_backend_status_test_');
    Hive.init(tempDir.path);
    
    // Register adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(PendingOpAdapter());
    }
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('LocalBackendStatus', () {
    test('should have all required fields', () {
      final status = LocalBackendStatus(
        pendingOps: 5,
        failedOps: 2,
        retryingOps: 1,
        encryptionHealthy: true,
        queueStalled: false,
        oldestOpAge: const Duration(minutes: 5),
        lastProcessedAt: DateTime.now(),
        openBoxCount: 3,
        capturedAt: DateTime.now().toUtc(),
        emergencyOps: 1,
        escalatedOps: 0,
        queueStallDuration: null,
        lastSuccessfulSync: DateTime.now(),
        adaptersHealthy: true,
        lockStatus: const LockStatus.unlocked(),
        opsByPriority: {'emergency': 1, 'high': 2, 'normal': 2, 'low': 0},
        queueState: 'idle',
        entityLockCount: 0,
        safetyFallbackActive: false,
      );

      expect(status.pendingOps, 5);
      expect(status.failedOps, 2);
      expect(status.emergencyOps, 1);
      expect(status.escalatedOps, 0);
      expect(status.adaptersHealthy, true);
      expect(status.queueState, 'idle');
      expect(status.safetyFallbackActive, false);
    });

    test('isHealthy should consider new fields', () {
      // Healthy status
      final healthy = LocalBackendStatus(
        pendingOps: 5,
        failedOps: 0,
        retryingOps: 0,
        encryptionHealthy: true,
        queueStalled: false,
        oldestOpAge: null,
        lastProcessedAt: null,
        openBoxCount: 3,
        capturedAt: DateTime.now().toUtc(),
        adaptersHealthy: true,
        safetyFallbackActive: false,
      );
      
      expect(healthy.isHealthy, true);
      expect(healthy.isCritical, false);
      expect(healthy.isWarning, false);
      expect(healthy.healthSeverity, 0);
      
      // Unhealthy due to safety fallback
      final unhealthy = healthy.copyWith(safetyFallbackActive: true);
      expect(unhealthy.isHealthy, false);
      
      // Unhealthy due to adapters
      final badAdapters = healthy.copyWith(adaptersHealthy: false);
      expect(badAdapters.isHealthy, false);
    });

    test('isCritical should detect critical conditions', () {
      final critical = LocalBackendStatus(
        pendingOps: 5,
        failedOps: 15, // > 10 failed ops
        retryingOps: 0,
        encryptionHealthy: true,
        queueStalled: false,
        oldestOpAge: null,
        lastProcessedAt: null,
        openBoxCount: 3,
        capturedAt: DateTime.now().toUtc(),
      );
      
      expect(critical.isCritical, true);
      expect(critical.healthSeverity, 2);
      
      // Encryption failure is critical
      final encryptionFail = LocalBackendStatus(
        pendingOps: 0,
        failedOps: 0,
        retryingOps: 0,
        encryptionHealthy: false,
        queueStalled: false,
        oldestOpAge: null,
        lastProcessedAt: null,
        openBoxCount: 3,
        capturedAt: DateTime.now().toUtc(),
      );
      
      expect(encryptionFail.isCritical, true);
    });

    test('summary should include new fields', () {
      final status = LocalBackendStatus(
        pendingOps: 5,
        failedOps: 2,
        retryingOps: 1,
        encryptionHealthy: true,
        queueStalled: false,
        oldestOpAge: null,
        lastProcessedAt: null,
        openBoxCount: 3,
        capturedAt: DateTime.now().toUtc(),
        emergencyOps: 1,
        queueState: 'processing',
      );

      expect(status.summary, contains('emergency=1'));
      expect(status.summary, contains('state=processing'));
    });

    test('copyWith should work with new fields', () {
      final original = LocalBackendStatus(
        pendingOps: 5,
        failedOps: 2,
        retryingOps: 1,
        encryptionHealthy: true,
        queueStalled: false,
        oldestOpAge: null,
        lastProcessedAt: null,
        openBoxCount: 3,
        capturedAt: DateTime.now().toUtc(),
        emergencyOps: 1,
        queueState: 'idle',
      );

      final updated = original.copyWith(
        emergencyOps: 5,
        queueState: 'processing',
        safetyFallbackActive: true,
      );

      expect(updated.emergencyOps, 5);
      expect(updated.queueState, 'processing');
      expect(updated.safetyFallbackActive, true);
      // Original unchanged
      expect(original.emergencyOps, 1);
    });
  });

  group('LockStatus', () {
    test('unlocked constructor', () {
      const status = LockStatus.unlocked();
      
      expect(status.isLocked, false);
      expect(status.holderPid, null);
      expect(status.acquiredAt, null);
      expect(status.wasStaleRecovered, false);
      expect(status.lockDuration, null);
    });

    test('locked status', () {
      final acquiredAt = DateTime.now().toUtc();
      final status = LockStatus(
        isLocked: true,
        holderPid: '12345',
        acquiredAt: acquiredAt,
        wasStaleRecovered: false,
        lockDuration: const Duration(seconds: 30),
      );
      
      expect(status.isLocked, true);
      expect(status.holderPid, '12345');
      expect(status.acquiredAt, acquiredAt);
      expect(status.lockDuration?.inSeconds, 30);
    });

    test('stale recovered status', () {
      final status = LockStatus(
        isLocked: true,
        holderPid: 'new_pid',
        acquiredAt: DateTime.now().toUtc(),
        wasStaleRecovered: true,
      );
      
      expect(status.wasStaleRecovered, true);
    });

    test('toString formats correctly', () {
      const unlocked = LockStatus.unlocked();
      expect(unlocked.toString(), 'LockStatus(unlocked)');
      
      final locked = LockStatus(
        isLocked: true,
        holderPid: '12345',
        lockDuration: const Duration(seconds: 30),
      );
      expect(locked.toString(), contains('locked by 12345'));
    });
  });
}
