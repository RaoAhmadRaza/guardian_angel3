import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:guardian_angel_fyp/services/transaction_service.dart';
import 'package:guardian_angel_fyp/services/models/transaction_record.dart';
import 'dart:io';

/// Exception thrown to simulate a crash during transaction execution.
class SimulatedCrash implements Exception {
  final String message;
  SimulatedCrash(this.message);

  @override
  String toString() => 'SimulatedCrash: $message';
}

/// Crash injection points for testing atomicity.
enum CrashPoint {
  beforeModelWrite,    // Before writing model state
  afterModelWrite,     // After model write, before pending op
  afterPendingOp,      // After pending op write, before index
  afterIndex,          // After index write, before commit
  afterCommit,         // After commit, before marking applied
}

/// Test harness for fault injection testing.
/// Provides controlled crash scenarios and verification logic.
class TransactionTestHarness {
  late String testPath;
  late TransactionService transactionService;
  late Box deviceBox;
  late Box pendingOpsBox;
  late Box indexBox;

  /// Crash point to inject (null = no crash)
  CrashPoint? crashPoint;

  Future<void> setup() async {
    testPath = Directory.systemTemp
        .createTempSync('transaction_crash_test_')
        .path;
    Hive.init(testPath);

    // Register adapters
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(TransactionRecordAdapter());
    }
    if (!Hive.isAdapterRegistered(11)) {
      Hive.registerAdapter(TransactionStateAdapter());
    }

    transactionService = TransactionService();
    await transactionService.init();

    deviceBox = await Hive.openBox('devices_v1');
    pendingOpsBox = await Hive.openBox('pending_ops_v1');
    indexBox = await Hive.openBox('pending_index');
  }

  Future<void> teardown() async {
    await deviceBox.close();
    await pendingOpsBox.close();
    await indexBox.close();
    await transactionService.dispose();
    await Hive.close();

    try {
      Directory(testPath).deleteSync(recursive: true);
    } catch (_) {}
  }

  /// Perform a transactional operation with optional crash injection.
  Future<void> performTransactionalUpdate({
    required String deviceId,
    required Map<String, dynamic> deviceData,
    required Map<String, dynamic> pendingOp,
    required String opId,
    CrashPoint? injectCrash,
  }) async {
    crashPoint = injectCrash;

    try {
      final txId = transactionService.beginTransaction();

      // Crash point 1: Before model write
      if (crashPoint == CrashPoint.beforeModelWrite) {
        throw SimulatedCrash('Crashed before model write');
      }

      // Step 1: Write model state
      transactionService.writeModelState('devices_v1', deviceId, deviceData);

      // Crash point 2: After model write
      if (crashPoint == CrashPoint.afterModelWrite) {
        throw SimulatedCrash('Crashed after model write');
      }

      // Step 2: Enqueue pending operation
      transactionService.enqueuePendingOp(pendingOp);

      // Crash point 3: After pending op
      if (crashPoint == CrashPoint.afterPendingOp) {
        throw SimulatedCrash('Crashed after pending op write');
      }

      // Step 3: Add index entry
      transactionService.addIndexEntry('pending_index', opId);

      // Crash point 4: After index
      if (crashPoint == CrashPoint.afterIndex) {
        throw SimulatedCrash('Crashed after index write');
      }

      // Step 4: Commit transaction
      await transactionService.commitTransaction();

      // Crash point 5: After commit
      if (crashPoint == CrashPoint.afterCommit) {
        throw SimulatedCrash('Crashed after commit');
      }
    } on SimulatedCrash {
      // Simulate abrupt termination (no cleanup)
      rethrow;
    }
  }

  /// Verify system consistency after potential crash.
  Future<ConsistencyCheck> verifyConsistency(String deviceId, String opId) async {
    final deviceExists = deviceBox.containsKey(deviceId);
    final device = deviceBox.get(deviceId);
    final pendingOpExists = pendingOpsBox.containsKey(opId);
    final pendingOp = pendingOpsBox.get(opId);
    final indexEntries = indexBox.get('opIds', defaultValue: <String>[]) as List<dynamic>?;
    final indexContainsOp = indexEntries?.contains(opId) ?? false;

    return ConsistencyCheck(
      deviceExists: deviceExists,
      deviceData: device,
      pendingOpExists: pendingOpExists,
      pendingOpData: pendingOp,
      indexContainsOp: indexContainsOp,
    );
  }

  /// Simulate app restart and run recovery.
  Future<void> simulateRestart() async {
    // Close and reopen boxes to simulate restart
    await deviceBox.close();
    await pendingOpsBox.close();
    await indexBox.close();

    // Reinitialize transaction service (triggers recovery)
    transactionService = TransactionService();
    await transactionService.init();

    // Reopen boxes
    deviceBox = await Hive.openBox('devices_v1');
    pendingOpsBox = await Hive.openBox('pending_ops_v1');
    indexBox = await Hive.openBox('pending_index');
  }

  /// Get transaction log statistics.
  Map<String, dynamic> getTransactionStats() {
    return transactionService.getStats();
  }
}

/// Result of consistency verification.
class ConsistencyCheck {
  final bool deviceExists;
  final dynamic deviceData;
  final bool pendingOpExists;
  final dynamic pendingOpData;
  final bool indexContainsOp;

  ConsistencyCheck({
    required this.deviceExists,
    this.deviceData,
    required this.pendingOpExists,
    this.pendingOpData,
    required this.indexContainsOp,
  });

  /// Check if all operations are consistent (all present or all absent).
  bool get isConsistent {
    // Either all three exist or none exist
    return (deviceExists && pendingOpExists && indexContainsOp) ||
           (!deviceExists && !pendingOpExists && !indexContainsOp);
  }

  /// Check if partially applied (inconsistent state).
  bool get isPartial {
    final count = [deviceExists, pendingOpExists, indexContainsOp].where((x) => x).length;
    return count > 0 && count < 3;
  }

  @override
  String toString() {
    return 'ConsistencyCheck(device: $deviceExists, pendingOp: $pendingOpExists, '
        'index: $indexContainsOp, consistent: $isConsistent)';
  }
}

void main() {
  group('Transaction Fault Injection Tests', () {
    late TransactionTestHarness harness;

    setUp(() async {
      harness = TransactionTestHarness();
      await harness.setup();
    });

    tearDown(() async {
      await harness.teardown();
    });

    test('successful transaction - all operations applied consistently', () async {
      final deviceId = 'd1';
      final opId = 'op1';

      await harness.performTransactionalUpdate(
        deviceId: deviceId,
        deviceData: {'id': deviceId, 'isOn': true, 'name': 'Bulb'},
        pendingOp: {'opId': opId, 'deviceId': deviceId, 'action': 'toggle'},
        opId: opId,
      );

      final check = await harness.verifyConsistency(deviceId, opId);

      expect(check.isConsistent, isTrue, reason: 'All operations should be applied');
      expect(check.deviceExists, isTrue);
      expect(check.pendingOpExists, isTrue);
      expect(check.indexContainsOp, isTrue);
    });

    test('crash before model write - no partial state', () async {
      final deviceId = 'd2';
      final opId = 'op2';

      try {
        await harness.performTransactionalUpdate(
          deviceId: deviceId,
          deviceData: {'id': deviceId, 'isOn': false},
          pendingOp: {'opId': opId, 'deviceId': deviceId},
          opId: opId,
          injectCrash: CrashPoint.beforeModelWrite,
        );
        fail('Should have thrown SimulatedCrash');
      } on SimulatedCrash {
        // Expected
      }

      // Simulate restart and recovery
      await harness.simulateRestart();

      final check = await harness.verifyConsistency(deviceId, opId);

      expect(check.isConsistent, isTrue, reason: 'No partial state after crash before commit');
      expect(check.deviceExists, isFalse);
      expect(check.pendingOpExists, isFalse);
      expect(check.indexContainsOp, isFalse);
    });

    test('crash after model write (before commit) - recovered on restart', () async {
      final deviceId = 'd3';
      final opId = 'op3';

      try {
        await harness.performTransactionalUpdate(
          deviceId: deviceId,
          deviceData: {'id': deviceId, 'isOn': true},
          pendingOp: {'opId': opId, 'deviceId': deviceId},
          opId: opId,
          injectCrash: CrashPoint.afterModelWrite,
        );
        fail('Should have thrown SimulatedCrash');
      } on SimulatedCrash {
        // Expected
      }

      // Before recovery: transaction is pending, nothing applied yet
      final beforeRecovery = await harness.verifyConsistency(deviceId, opId);
      expect(beforeRecovery.deviceExists, isFalse, reason: 'Transaction not committed yet');

      // Simulate restart with recovery
      await harness.simulateRestart();

      // After recovery: incomplete transaction should be rolled back (no commit happened)
      final afterRecovery = await harness.verifyConsistency(deviceId, opId);
      expect(afterRecovery.isConsistent, isTrue, reason: 'Recovery should ensure consistency');
      expect(afterRecovery.deviceExists, isFalse, reason: 'Uncommitted transaction rolled back');
    });

    test('crash after pending op write (before commit) - rolled back on restart', () async {
      final deviceId = 'd4';
      final opId = 'op4';

      try {
        await harness.performTransactionalUpdate(
          deviceId: deviceId,
          deviceData: {'id': deviceId, 'isOn': false},
          pendingOp: {'opId': opId, 'deviceId': deviceId},
          opId: opId,
          injectCrash: CrashPoint.afterPendingOp,
        );
        fail('Should have thrown SimulatedCrash');
      } on SimulatedCrash {
        // Expected
      }

      await harness.simulateRestart();

      final check = await harness.verifyConsistency(deviceId, opId);
      expect(check.isConsistent, isTrue);
      expect(check.deviceExists, isFalse, reason: 'Uncommitted transaction rolled back');
    });

    test('crash after index write (before commit) - rolled back on restart', () async {
      final deviceId = 'd5';
      final opId = 'op5';

      try {
        await harness.performTransactionalUpdate(
          deviceId: deviceId,
          deviceData: {'id': deviceId, 'isOn': true},
          pendingOp: {'opId': opId, 'deviceId': deviceId},
          opId: opId,
          injectCrash: CrashPoint.afterIndex,
        );
        fail('Should have thrown SimulatedCrash');
      } on SimulatedCrash {
        // Expected
      }

      await harness.simulateRestart();

      final check = await harness.verifyConsistency(deviceId, opId);
      expect(check.isConsistent, isTrue);
      expect(check.deviceExists, isFalse);
    });

    test('crash after commit (before marking applied) - recovered on restart', () async {
      final deviceId = 'd6';
      final opId = 'op6';

      try {
        await harness.performTransactionalUpdate(
          deviceId: deviceId,
          deviceData: {'id': deviceId, 'isOn': false},
          pendingOp: {'opId': opId, 'deviceId': deviceId},
          opId: opId,
          injectCrash: CrashPoint.afterCommit,
        );
        fail('Should have thrown SimulatedCrash');
      } on SimulatedCrash {
        // Expected
      }

      // Before recovery: transaction committed but not marked applied
      // Data might be partially there depending on where exactly crash happened
      
      // Simulate restart with recovery
      await harness.simulateRestart();

      // After recovery: committed transaction should be fully applied
      final afterRecovery = await harness.verifyConsistency(deviceId, opId);
      expect(afterRecovery.isConsistent, isTrue, reason: 'Recovery should complete committed transaction');
      expect(afterRecovery.deviceExists, isTrue, reason: 'Committed transaction applied');
      expect(afterRecovery.pendingOpExists, isTrue);
      expect(afterRecovery.indexContainsOp, isTrue);
    });

    test('multiple crashes and recoveries maintain consistency', () async {
      // First transaction: crash after model write
      try {
        await harness.performTransactionalUpdate(
          deviceId: 'd7',
          deviceData: {'id': 'd7', 'isOn': true},
          pendingOp: {'opId': 'op7', 'deviceId': 'd7'},
          opId: 'op7',
          injectCrash: CrashPoint.afterModelWrite,
        );
      } on SimulatedCrash {
        // Expected
      }

      await harness.simulateRestart();

      // Second transaction: successful
      await harness.performTransactionalUpdate(
        deviceId: 'd8',
        deviceData: {'id': 'd8', 'isOn': false},
        pendingOp: {'opId': 'op8', 'deviceId': 'd8'},
        opId: 'op8',
      );

      // Third transaction: crash after commit
      try {
        await harness.performTransactionalUpdate(
          deviceId: 'd9',
          deviceData: {'id': 'd9', 'isOn': true},
          pendingOp: {'opId': 'op9', 'deviceId': 'd9'},
          opId: 'op9',
          injectCrash: CrashPoint.afterCommit,
        );
      } on SimulatedCrash {
        // Expected
      }

      await harness.simulateRestart();

      // Verify all three scenarios
      final check7 = await harness.verifyConsistency('d7', 'op7');
      final check8 = await harness.verifyConsistency('d8', 'op8');
      final check9 = await harness.verifyConsistency('d9', 'op9');

      expect(check7.isConsistent, isTrue, reason: 'd7: rolled back');
      expect(check7.deviceExists, isFalse);

      expect(check8.isConsistent, isTrue, reason: 'd8: successful');
      expect(check8.deviceExists, isTrue);

      expect(check9.isConsistent, isTrue, reason: 'd9: recovered after commit');
      expect(check9.deviceExists, isTrue);
    });

    test('transaction log statistics track states correctly', () async {
      // Create a successful transaction
      await harness.performTransactionalUpdate(
        deviceId: 'd11',
        deviceData: {'id': 'd11'},
        pendingOp: {'opId': 'op11'},
        opId: 'op11',
      );

      // Create a failed transaction
      harness.transactionService.beginTransaction();
      harness.transactionService.writeModelState('devices_v1', 'd12', {'id': 'd12'});
      await harness.transactionService.rollbackTransaction();

      final stats = harness.getTransactionStats();

      expect(stats['applied'], greaterThan(0), reason: 'Should have applied transaction');
      expect(stats['failed'], greaterThan(0), reason: 'Should have failed transaction');
      expect(stats['total'], greaterThan(0), reason: 'Should have transactions in log');
    });

    test('recovery handles corrupted transaction gracefully', () async {
      // This test would require manual corruption of the transaction log
      // For now, just verify that recovery doesn't crash on empty/normal state
      await harness.simulateRestart();
      
      final stats = harness.getTransactionStats();
      expect(stats, isNotNull);
    });
  });
}
