import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:guardian_angel_fyp/persistence/repair/repair_service.dart';
import 'package:guardian_angel_fyp/persistence/box_registry.dart';
import 'package:guardian_angel_fyp/models/pending_op.dart';
import 'package:guardian_angel_fyp/models/failed_op_model.dart';
import 'package:guardian_angel_fyp/persistence/adapters/pending_op_adapter.dart';
import 'package:guardian_angel_fyp/persistence/adapters/failed_op_adapter.dart';
import 'dart:io';

/// Tests for the Repair Service.
void main() {
  late Directory tempDir;
  late RepairService repairService;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('repair_service_test_');
    Hive.init(tempDir.path);
    
    // Register adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(PendingOpAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(FailedOpModelAdapter());
    }
  });

  setUp(() async {
    // Open required boxes
    await Hive.openBox<PendingOp>(BoxRegistry.pendingOpsBox);
    await Hive.openBox<FailedOpModel>(BoxRegistry.failedOpsBox);
    await Hive.openBox(BoxRegistry.metaBox);
    await Hive.openBox(BoxRegistry.pendingIndexBox);
    
    repairService = RepairService();
  });

  tearDown(() async {
    // Clear boxes
    if (Hive.isBoxOpen(BoxRegistry.pendingOpsBox)) {
      await Hive.box<PendingOp>(BoxRegistry.pendingOpsBox).clear();
    }
    if (Hive.isBoxOpen(BoxRegistry.failedOpsBox)) {
      await Hive.box<FailedOpModel>(BoxRegistry.failedOpsBox).clear();
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

  group('RepairAction', () {
    test('all actions have descriptions', () {
      for (final action in RepairAction.values) {
        expect(action.description, isNotEmpty);
      }
    });

    test('all actions have severity levels', () {
      for (final action in RepairAction.values) {
        expect(['info', 'warning', 'critical'], contains(action.severity));
      }
    });

    test('critical actions require queue stopped', () {
      expect(RepairAction.rebuildPendingIndex.requiresQueueStopped, true);
      expect(RepairAction.purgePoisonOps.requiresQueueStopped, true);
      expect(RepairAction.compactBoxes.requiresQueueStopped, true);
    });
  });

  group('RepairService Tokens', () {
    test('generateConfirmationToken creates valid token', () {
      final token = repairService.generateConfirmationToken(RepairAction.rebuildPendingIndex);
      
      expect(token, startsWith('CONFIRM_REPAIR_'));
      expect(token, contains('REBUILDPENDINGINDEX'));
    });

    test('validateToken accepts valid token', () {
      final token = repairService.generateConfirmationToken(RepairAction.rebuildPendingIndex);
      
      expect(repairService.validateToken(RepairAction.rebuildPendingIndex, token), true);
    });

    test('validateToken rejects invalid token', () {
      expect(repairService.validateToken(RepairAction.rebuildPendingIndex, 'invalid'), false);
      expect(repairService.validateToken(RepairAction.rebuildPendingIndex, 'CONFIRM_REPAIR_WRONGACTION_123'), false);
    });

    test('validateToken rejects token for wrong action', () {
      final token = repairService.generateConfirmationToken(RepairAction.rebuildPendingIndex);
      
      expect(repairService.validateToken(RepairAction.purgePoisonOps, token), false);
    });
  });

  group('RepairService Execute', () {
    test('execute fails with invalid token', () async {
      final result = await repairService.execute(
        action: RepairAction.rebuildPendingIndex,
        userId: 'test_user',
        confirmationToken: 'invalid_token',
      );

      expect(result.success, false);
      expect(result.error, contains('Invalid confirmation token'));
    });

    test('rebuildPendingIndex succeeds with valid token', () async {
      final token = repairService.generateConfirmationToken(RepairAction.rebuildPendingIndex);
      
      final result = await repairService.execute(
        action: RepairAction.rebuildPendingIndex,
        userId: 'test_user',
        confirmationToken: token,
      );

      expect(result.success, true);
      expect(result.action, RepairAction.rebuildPendingIndex);
    });

    test('releaseStaleLocks releases lock', () async {
      // Create a lock
      final metaBox = Hive.box(BoxRegistry.metaBox);
      await metaBox.put('processing_lock', {
        'processing': true,
        'startedAt': DateTime.now().toUtc().toIso8601String(),
        'pid': 'stale_pid',
      });

      expect(metaBox.get('processing_lock'), isNotNull);

      final token = repairService.generateConfirmationToken(RepairAction.releaseStaleLocks);
      
      final result = await repairService.execute(
        action: RepairAction.releaseStaleLocks,
        userId: 'test_user',
        confirmationToken: token,
      );

      expect(result.success, true);
      expect(result.affectedCount, 1);
      expect(metaBox.get('processing_lock'), isNull);
    });

    test('releaseStaleLocks succeeds with no lock', () async {
      final token = repairService.generateConfirmationToken(RepairAction.releaseStaleLocks);
      
      final result = await repairService.execute(
        action: RepairAction.releaseStaleLocks,
        userId: 'test_user',
        confirmationToken: token,
      );

      expect(result.success, true);
      expect(result.affectedCount, 0);
    });

    test('purgePoisonOps purges poison ops', () async {
      // Add some poison ops to failed box
      final failedBox = Hive.box<FailedOpModel>(BoxRegistry.failedOpsBox);
      
      final now = DateTime.now().toUtc();
      
      final poisonOp = FailedOpModel(
        id: 'poison_1',
        opType: 'test_op',
        payload: {},
        errorCode: 'POISON_OP',
        errorMessage: 'Exceeded max attempts',
        attempts: 8,
        archived: false,
        createdAt: now,
        updatedAt: now,
      );
      
      final regularFailed = FailedOpModel(
        id: 'regular_1',
        opType: 'test_op',
        payload: {},
        errorCode: 'NETWORK_ERROR',
        errorMessage: 'Network timeout',
        attempts: 3,
        archived: false,
        createdAt: now,
        updatedAt: now,
      );
      
      await failedBox.put(poisonOp.id, poisonOp);
      await failedBox.put(regularFailed.id, regularFailed);

      expect(failedBox.length, 2);

      final token = repairService.generateConfirmationToken(RepairAction.purgePoisonOps);
      
      final result = await repairService.execute(
        action: RepairAction.purgePoisonOps,
        userId: 'test_user',
        confirmationToken: token,
      );

      expect(result.success, true);
      expect(result.affectedCount, 1);
      expect(failedBox.length, 1);
      expect(failedBox.containsKey('regular_1'), true);
      expect(failedBox.containsKey('poison_1'), false);
    });

    test('compactBoxes compacts all open boxes', () async {
      final token = repairService.generateConfirmationToken(RepairAction.compactBoxes);
      
      final result = await repairService.execute(
        action: RepairAction.compactBoxes,
        userId: 'test_user',
        confirmationToken: token,
      );

      expect(result.success, true);
      expect(result.affectedCount, greaterThan(0));
    });
  });

  group('RepairResult', () {
    test('success factory creates successful result', () {
      final result = RepairResult.success(
        action: RepairAction.rebuildPendingIndex,
        message: 'Index rebuilt',
        affectedCount: 10,
        duration: const Duration(milliseconds: 100),
      );

      expect(result.success, true);
      expect(result.action, RepairAction.rebuildPendingIndex);
      expect(result.affectedCount, 10);
      expect(result.error, null);
    });

    test('failure factory creates failed result', () {
      final result = RepairResult.failure(
        action: RepairAction.verifyEncryption,
        error: 'Key missing',
        duration: const Duration(milliseconds: 50),
      );

      expect(result.success, false);
      expect(result.error, 'Key missing');
    });

    test('toString formats correctly', () {
      final success = RepairResult.success(
        action: RepairAction.rebuildPendingIndex,
        message: 'Done',
        affectedCount: 5,
        duration: const Duration(milliseconds: 100),
      );
      
      expect(success.toString(), contains('success'));
      expect(success.toString(), contains('affected=5'));

      final failure = RepairResult.failure(
        action: RepairAction.verifyEncryption,
        error: 'Failed',
        duration: const Duration(milliseconds: 50),
      );
      
      expect(failure.toString(), contains('failure'));
    });
  });
}
