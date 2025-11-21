import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'dart:io';
import 'package:guardian_angel_fyp/persistence/index/pending_index.dart';
import 'package:guardian_angel_fyp/persistence/box_registry.dart';
import 'package:guardian_angel_fyp/persistence/adapters/pending_op_adapter.dart';
import 'package:guardian_angel_fyp/models/pending_op.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync();
    Hive.init(dir.path);
    Hive.registerAdapter(PendingOpAdapter());
    await Hive.openBox(BoxRegistry.pendingIndexBox);
    await Hive.openBox<PendingOp>(BoxRegistry.pendingOpsBox);
  });

  test('enqueue orders by createdAt asc', () async {
    final idx = await PendingIndex.create();
    final pending = Hive.box<PendingOp>(BoxRegistry.pendingOpsBox);
    final opA = PendingOp(
      id: 'a',
      opType: 'test',
      idempotencyKey: 'kA',
      payload: const {},
      createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
      updatedAt: DateTime.parse('2024-01-01T00:00:00Z'),
    );
    await pending.put(opA.id, opA);
    await idx.enqueue(opA.id, opA.createdAt);
    final opB = PendingOp(
      id: 'b',
      opType: 'test',
      idempotencyKey: 'kB',
      payload: const {},
      createdAt: DateTime.parse('2024-01-01T00:00:00.100Z'),
      updatedAt: DateTime.parse('2024-01-01T00:00:00.100Z'),
    );
    await pending.put(opB.id, opB);
    await idx.enqueue(opB.id, opB.createdAt);
    final opC = PendingOp(
      id: 'c',
      opType: 'test',
      idempotencyKey: 'kC',
      payload: const {},
      createdAt: DateTime.parse('2023-12-31T23:59:59.999Z'),
      updatedAt: DateTime.parse('2023-12-31T23:59:59.999Z'),
    );
    await pending.put(opC.id, opC);
    await idx.enqueue(opC.id, opC.createdAt);
    final ids = await idx.getOldestIds(3);
    expect(ids, ['c', 'a', 'b']);
  });
}