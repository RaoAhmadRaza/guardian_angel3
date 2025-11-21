import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:guardian_angel_fyp/persistence/box_registry.dart';
import 'package:guardian_angel_fyp/models/failed_op_model.dart';
import 'package:guardian_angel_fyp/models/pending_op.dart';
import 'package:guardian_angel_fyp/persistence/adapters/failed_op_adapter.dart';
import 'package:guardian_angel_fyp/persistence/adapters/pending_op_adapter.dart';
import 'package:guardian_angel_fyp/services/failed_ops_service.dart';
import 'package:guardian_angel_fyp/persistence/index/pending_index.dart';

void main() {
  setUp(() async {
    await setUpTestHive();
    if (!Hive.isAdapterRegistered(FailedOpModelAdapter().typeId)) {
      Hive.registerAdapter(FailedOpModelAdapter());
    }
    if (!Hive.isAdapterRegistered(PendingOpAdapter().typeId)) {
      Hive.registerAdapter(PendingOpAdapter());
    }
    await Hive.openBox<FailedOpModel>(BoxRegistry.failedOpsBox);
    await Hive.openBox<PendingOp>(BoxRegistry.pendingOpsBox);
    await Hive.openBox(BoxRegistry.pendingIndexBox);
  });

  tearDown(() async {
    await tearDownTestHive();
  });

  test('retryOp increments attempts and re-enqueues pending op', () async {
    final failedBox = Hive.box<FailedOpModel>(BoxRegistry.failedOpsBox);
    final f = FailedOpModel(
      id: 'f1',
      sourcePendingOpId: null,
      opType: 'device_toggle',
      payload: const {'device_id': 'd1'},
      errorCode: 'TIMEOUT',
      errorMessage: 'Timeout',
      idempotencyKey: 'idem-f1',
      attempts: 1,
      archived: false,
      createdAt: DateTime.utc(2024, 1, 1),
      updatedAt: DateTime.utc(2024, 1, 1),
    );
    await failedBox.put(f.id, f);

    final index = await PendingIndex.create();
    final svc = FailedOpsService(registry: BoxRegistry(), index: index, maxAttempts: 5);
    final pending = await svc.retryOp('f1');
    expect(pending.idempotencyKey, 'idem-f1');
    final updatedFailed = failedBox.get('f1')!;
    expect(updatedFailed.attempts, 2);
    // index should contain the new pending op id
    final oldestIds = await index.getOldestIds(10);
    expect(oldestIds.contains(pending.id), isTrue);
  });

  test('purgeExpired archives then deletes', () async {
    final failedBox = Hive.box<FailedOpModel>(BoxRegistry.failedOpsBox);
    final old = FailedOpModel(
      id: 'old1',
      sourcePendingOpId: null,
      opType: 'device_toggle',
      payload: const {},
      errorCode: 'X',
      errorMessage: 'Old',
      idempotencyKey: null,
      attempts: 0,
      archived: false,
      createdAt: DateTime.now().toUtc().subtract(const Duration(days: 90)),
      updatedAt: DateTime.now().toUtc().subtract(const Duration(days: 90)),
    );
    await failedBox.put(old.id, old);
    final index = await PendingIndex.create();
    final svc = FailedOpsService(registry: BoxRegistry(), index: index, retentionDays: 30);
    final purged = await svc.purgeExpired();
    expect(purged, 1);
    expect(failedBox.get('old1'), isNull);
  });

  test('archiveOp sets archived flag', () async {
    final failedBox = Hive.box<FailedOpModel>(BoxRegistry.failedOpsBox);
    final f = FailedOpModel(
      id: 'f2',
      sourcePendingOpId: null,
      opType: 'device_toggle',
      payload: const {},
      errorCode: 'FAIL',
      errorMessage: 'Err',
      idempotencyKey: null,
      attempts: 0,
      archived: false,
      createdAt: DateTime.utc(2024, 1, 1),
      updatedAt: DateTime.utc(2024, 1, 1),
    );
    await failedBox.put(f.id, f);
    final index = await PendingIndex.create();
    final svc = FailedOpsService(registry: BoxRegistry(), index: index);
    await svc.archiveOp('f2');
    expect(failedBox.get('f2')!.archived, isTrue);
  });
}