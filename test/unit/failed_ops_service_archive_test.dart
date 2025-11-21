import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:guardian_angel_fyp/services/failed_ops_service.dart';
import 'package:guardian_angel_fyp/models/failed_op_model.dart';
import 'package:guardian_angel_fyp/models/pending_op.dart';
import 'package:guardian_angel_fyp/persistence/box_registry.dart';
import 'package:guardian_angel_fyp/persistence/index/pending_index.dart';
import 'package:guardian_angel_fyp/persistence/adapters/failed_op_adapter.dart';
import 'package:guardian_angel_fyp/persistence/adapters/pending_op_adapter.dart';

void main() {
  late FailedOpsService service;
  late BoxRegistry registry;
  late PendingIndex index;

  // Register adapters once before all tests
  setUpAll(() {
    Hive.registerAdapter(FailedOpModelAdapter());
    Hive.registerAdapter(PendingOpAdapter());
  });

  setUp(() async {
    await setUpTestHive();
    
    await Hive.openBox<FailedOpModel>(BoxRegistry.failedOpsBox);
    await Hive.openBox<PendingOp>(BoxRegistry.pendingOpsBox);
    await Hive.openBox(BoxRegistry.pendingIndexBox);
    
    registry = BoxRegistry();
    index = await PendingIndex.create();
    service = FailedOpsService(
      registry: registry,
      index: index,
      maxAttempts: 5,
      maxBackoffSeconds: 300,
      retentionDays: 30,
    );
  });

  tearDown(() async {
    await tearDownTestHive();
  });

  group('FailedOpsService.archive()', () {
    test('archives failed ops older than default retention (30 days)', () async {
      final box = Hive.box<FailedOpModel>(BoxRegistry.failedOpsBox);
      final now = DateTime.now().toUtc();
      
      // Create failed ops at various ages
      final old1 = FailedOpModel(
        id: 'old-1',
        opType: 'create',
        payload: {},
        attempts: 3,
        archived: false,
        createdAt: now.subtract(Duration(days: 35)),
        updatedAt: now.subtract(Duration(days: 35)),
      );
      
      final old2 = FailedOpModel(
        id: 'old-2',
        opType: 'update',
        payload: {},
        attempts: 2,
        archived: false,
        createdAt: now.subtract(Duration(days: 45)),
        updatedAt: now.subtract(Duration(days: 45)),
      );
      
      final recent = FailedOpModel(
        id: 'recent-1',
        opType: 'delete',
        payload: {},
        attempts: 1,
        archived: false,
        createdAt: now.subtract(Duration(days: 15)),
        updatedAt: now.subtract(Duration(days: 15)),
      );
      
      final alreadyArchived = FailedOpModel(
        id: 'archived-1',
        opType: 'create',
        payload: {},
        attempts: 5,
        archived: true,
        createdAt: now.subtract(Duration(days: 60)),
        updatedAt: now.subtract(Duration(days: 50)),
      );
      
      await box.put('old-1', old1);
      await box.put('old-2', old2);
      await box.put('recent-1', recent);
      await box.put('archived-1', alreadyArchived);
      
      final archivedCount = await service.archive();
      
      expect(archivedCount, 2); // old-1 and old-2
      expect(box.get('old-1')!.archived, isTrue);
      expect(box.get('old-2')!.archived, isTrue);
      expect(box.get('recent-1')!.archived, isFalse);
      expect(box.get('archived-1')!.archived, isTrue); // unchanged
    });

    test('archives failed ops older than custom age', () async {
      final box = Hive.box<FailedOpModel>(BoxRegistry.failedOpsBox);
      final now = DateTime.now().toUtc();
      
      final op1 = FailedOpModel(
        id: 'op-1',
        opType: 'create',
        payload: {},
        attempts: 1,
        archived: false,
        createdAt: now.subtract(Duration(days: 8)),
        updatedAt: now.subtract(Duration(days: 8)),
      );
      
      final op2 = FailedOpModel(
        id: 'op-2',
        opType: 'update',
        payload: {},
        attempts: 2,
        archived: false,
        createdAt: now.subtract(Duration(days: 5)),
        updatedAt: now.subtract(Duration(days: 5)),
      );
      
      final op3 = FailedOpModel(
        id: 'op-3',
        opType: 'delete',
        payload: {},
        attempts: 1,
        archived: false,
        createdAt: now.subtract(Duration(days: 3)),
        updatedAt: now.subtract(Duration(days: 3)),
      );
      
      await box.put('op-1', op1);
      await box.put('op-2', op2);
      await box.put('op-3', op3);
      
      // Archive ops older than 7 days
      final archivedCount = await service.archive(ageDays: 7);
      
      expect(archivedCount, 1); // only op-1
      expect(box.get('op-1')!.archived, isTrue);
      expect(box.get('op-2')!.archived, isFalse);
      expect(box.get('op-3')!.archived, isFalse);
    });

    test('returns zero when no ops need archiving', () async {
      final box = Hive.box<FailedOpModel>(BoxRegistry.failedOpsBox);
      final now = DateTime.now().toUtc();
      
      final recent1 = FailedOpModel(
        id: 'recent-1',
        opType: 'create',
        payload: {},
        attempts: 1,
        archived: false,
        createdAt: now.subtract(Duration(days: 5)),
        updatedAt: now.subtract(Duration(days: 5)),
      );
      
      final recent2 = FailedOpModel(
        id: 'recent-2',
        opType: 'update',
        payload: {},
        attempts: 2,
        archived: false,
        createdAt: now.subtract(Duration(days: 10)),
        updatedAt: now.subtract(Duration(days: 10)),
      );
      
      await box.put('recent-1', recent1);
      await box.put('recent-2', recent2);
      
      final archivedCount = await service.archive();
      
      expect(archivedCount, 0);
      expect(box.get('recent-1')!.archived, isFalse);
      expect(box.get('recent-2')!.archived, isFalse);
    });

    test('returns zero when box is empty', () async {
      final archivedCount = await service.archive();
      expect(archivedCount, 0);
    });

    test('skips already archived ops', () async {
      final box = Hive.box<FailedOpModel>(BoxRegistry.failedOpsBox);
      final now = DateTime.now().toUtc();
      
      final alreadyArchived = FailedOpModel(
        id: 'archived-old',
        opType: 'create',
        payload: {},
        attempts: 5,
        archived: true,
        createdAt: now.subtract(Duration(days: 60)),
        updatedAt: now.subtract(Duration(days: 50)),
      );
      
      await box.put('archived-old', alreadyArchived);
      
      final archivedCount = await service.archive();
      
      expect(archivedCount, 0);
      expect(box.get('archived-old')!.archived, isTrue);
      // Verify updatedAt wasn't changed
      expect(
        box.get('archived-old')!.updatedAt,
        now.subtract(Duration(days: 50)),
      );
    });

    test('archives multiple ops in single call', () async {
      final box = Hive.box<FailedOpModel>(BoxRegistry.failedOpsBox);
      final now = DateTime.now().toUtc();
      
      // Create 10 old failed ops
      for (int i = 0; i < 10; i++) {
        final op = FailedOpModel(
          id: 'bulk-$i',
          opType: 'create',
          payload: {'index': i},
          attempts: i % 5,
          archived: false,
          createdAt: now.subtract(Duration(days: 40 + i)),
          updatedAt: now.subtract(Duration(days: 40 + i)),
        );
        await box.put('bulk-$i', op);
      }
      
      // Add some recent ops
      for (int i = 0; i < 5; i++) {
        final op = FailedOpModel(
          id: 'recent-$i',
          opType: 'update',
          payload: {'index': i},
          attempts: i % 3,
          archived: false,
          createdAt: now.subtract(Duration(days: i + 1)),
          updatedAt: now.subtract(Duration(days: i + 1)),
        );
        await box.put('recent-$i', op);
      }
      
      final archivedCount = await service.archive();
      
      expect(archivedCount, 10);
      
      // Verify all old ops are archived
      for (int i = 0; i < 10; i++) {
        expect(box.get('bulk-$i')!.archived, isTrue);
      }
      
      // Verify recent ops are not archived
      for (int i = 0; i < 5; i++) {
        expect(box.get('recent-$i')!.archived, isFalse);
      }
    });

    test('updates updatedAt timestamp when archiving', () async {
      final box = Hive.box<FailedOpModel>(BoxRegistry.failedOpsBox);
      final now = DateTime.now().toUtc();
      final createdTime = now.subtract(Duration(days: 40));
      
      final op = FailedOpModel(
        id: 'timestamp-test',
        opType: 'create',
        payload: {},
        attempts: 2,
        archived: false,
        createdAt: createdTime,
        updatedAt: createdTime,
      );
      
      await box.put('timestamp-test', op);
      
      final beforeArchive = DateTime.now().toUtc();
      await service.archive();
      final afterArchive = DateTime.now().toUtc();
      
      final archived = box.get('timestamp-test')!;
      expect(archived.archived, isTrue);
      expect(archived.createdAt, createdTime); // unchanged
      expect(archived.updatedAt.isAfter(beforeArchive) || 
             archived.updatedAt.isAtSameMomentAs(beforeArchive), isTrue);
      expect(archived.updatedAt.isBefore(afterArchive) || 
             archived.updatedAt.isAtSameMomentAs(afterArchive), isTrue);
    });

    test('preserves all other fields when archiving', () async {
      final box = Hive.box<FailedOpModel>(BoxRegistry.failedOpsBox);
      final now = DateTime.now().toUtc();
      
      final original = FailedOpModel(
        id: 'preserve-test',
        sourcePendingOpId: 'pending-123',
        opType: 'update_device',
        payload: {'device_id': 'dev-001', 'status': 'active'},
        errorCode: 'NETWORK_TIMEOUT',
        errorMessage: 'Connection timed out after 30s',
        idempotencyKey: 'idem-key-xyz',
        attempts: 3,
        archived: false,
        createdAt: now.subtract(Duration(days: 45)),
        updatedAt: now.subtract(Duration(days: 45)),
      );
      
      await box.put('preserve-test', original);
      await service.archive();
      
      final archived = box.get('preserve-test')!;
      expect(archived.id, original.id);
      expect(archived.sourcePendingOpId, original.sourcePendingOpId);
      expect(archived.opType, original.opType);
      expect(archived.payload, original.payload);
      expect(archived.errorCode, original.errorCode);
      expect(archived.errorMessage, original.errorMessage);
      expect(archived.idempotencyKey, original.idempotencyKey);
      expect(archived.attempts, original.attempts);
      expect(archived.archived, isTrue); // changed
      expect(archived.createdAt, original.createdAt);
      expect(archived.updatedAt.isAfter(original.updatedAt), isTrue); // updated
    });

    test('archive with ageDays=0 archives all non-archived ops', () async {
      final box = Hive.box<FailedOpModel>(BoxRegistry.failedOpsBox);
      final now = DateTime.now().toUtc();
      
      final veryRecent = FailedOpModel(
        id: 'very-recent',
        opType: 'create',
        payload: {},
        attempts: 1,
        archived: false,
        createdAt: now.subtract(Duration(hours: 1)),
        updatedAt: now.subtract(Duration(hours: 1)),
      );
      
      final old = FailedOpModel(
        id: 'old',
        opType: 'update',
        payload: {},
        attempts: 2,
        archived: false,
        createdAt: now.subtract(Duration(days: 100)),
        updatedAt: now.subtract(Duration(days: 100)),
      );
      
      await box.put('very-recent', veryRecent);
      await box.put('old', old);
      
      final archivedCount = await service.archive(ageDays: 0);
      
      expect(archivedCount, 2);
      expect(box.get('very-recent')!.archived, isTrue);
      expect(box.get('old')!.archived, isTrue);
    });

    test('archive boundary condition - exactly 30 days old', () async {
      final box = Hive.box<FailedOpModel>(BoxRegistry.failedOpsBox);
      final now = DateTime.now().toUtc();
      
      // Op created exactly 30 days ago (minus 1 second to ensure it's before cutoff)
      final exactly30Days = FailedOpModel(
        id: 'exactly-30',
        opType: 'create',
        payload: {},
        attempts: 1,
        archived: false,
        createdAt: now.subtract(Duration(days: 30, seconds: 1)),
        updatedAt: now.subtract(Duration(days: 30, seconds: 1)),
      );
      
      // Op created 30 days ago (plus 1 second to ensure it's after cutoff)
      final almostThirty = FailedOpModel(
        id: 'almost-30',
        opType: 'update',
        payload: {},
        attempts: 1,
        archived: false,
        createdAt: now.subtract(Duration(days: 29, hours: 23, minutes: 59)),
        updatedAt: now.subtract(Duration(days: 29, hours: 23, minutes: 59)),
      );
      
      await box.put('exactly-30', exactly30Days);
      await box.put('almost-30', almostThirty);
      
      final archivedCount = await service.archive();
      
      expect(archivedCount, 1);
      expect(box.get('exactly-30')!.archived, isTrue);
      expect(box.get('almost-30')!.archived, isFalse);
    });
  });

  group('FailedOpsService.archiveOp() - individual operation', () {
    test('archives single failed op by id', () async {
      final box = Hive.box<FailedOpModel>(BoxRegistry.failedOpsBox);
      final now = DateTime.now().toUtc();
      
      final op = FailedOpModel(
        id: 'single-op',
        opType: 'create',
        payload: {},
        attempts: 2,
        archived: false,
        createdAt: now.subtract(Duration(days: 5)),
        updatedAt: now.subtract(Duration(days: 5)),
      );
      
      await box.put('single-op', op);
      await service.archiveOp('single-op');
      
      final archived = box.get('single-op')!;
      expect(archived.archived, isTrue);
    });

    test('archiveOp does nothing if op not found', () async {
      // Should not throw
      await service.archiveOp('non-existent');
    });

    test('archiveOp does nothing if already archived', () async {
      final box = Hive.box<FailedOpModel>(BoxRegistry.failedOpsBox);
      final now = DateTime.now().toUtc();
      final originalUpdatedAt = now.subtract(Duration(days: 10));
      
      final op = FailedOpModel(
        id: 'already-archived',
        opType: 'create',
        payload: {},
        attempts: 3,
        archived: true,
        createdAt: now.subtract(Duration(days: 20)),
        updatedAt: originalUpdatedAt,
      );
      
      await box.put('already-archived', op);
      await service.archiveOp('already-archived');
      
      final retrieved = box.get('already-archived')!;
      expect(retrieved.archived, isTrue);
      // updatedAt should not change
      expect(retrieved.updatedAt, originalUpdatedAt);
    });
  });

  group('FailedOpsService.purgeExpired() integration with archive', () {
    test('purgeExpired archives before deleting', () async {
      final box = Hive.box<FailedOpModel>(BoxRegistry.failedOpsBox);
      final now = DateTime.now().toUtc();
      
      final expired = FailedOpModel(
        id: 'expired-op',
        opType: 'create',
        payload: {},
        attempts: 2,
        archived: false,
        createdAt: now.subtract(Duration(days: 35)),
        updatedAt: now.subtract(Duration(days: 35)),
      );
      
      await box.put('expired-op', expired);
      
      final purged = await service.purgeExpired();
      
      expect(purged, 1);
      expect(box.get('expired-op'), isNull); // deleted
    });

    test('purgeExpired skips archiving if already archived', () async {
      final box = Hive.box<FailedOpModel>(BoxRegistry.failedOpsBox);
      final now = DateTime.now().toUtc();
      
      final expiredArchived = FailedOpModel(
        id: 'expired-archived',
        opType: 'create',
        payload: {},
        attempts: 2,
        archived: true,
        createdAt: now.subtract(Duration(days: 35)),
        updatedAt: now.subtract(Duration(days: 30)),
      );
      
      await box.put('expired-archived', expiredArchived);
      
      final purged = await service.purgeExpired();
      
      expect(purged, 1);
      expect(box.get('expired-archived'), isNull);
    });
  });
}
