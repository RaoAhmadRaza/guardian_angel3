import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AutomationSyncService queue processing', () {
    test('deletes op on success', () async {
      // TODO: Provide SuccessDriver and LocalHiveService pendingOps box
      expect(true, isTrue);
    }, skip: 'Pending service + hive setup.');

    test('increments attempts on failure', () async {
      // TODO: Provide FailingDriver and verify attempts increment
      expect(true, isTrue);
    }, skip: 'Pending service + hive setup.');
  });
}

/*
SNIPPET (for future implementation):

class SuccessDriver implements AutomationDriver {
  @override
  Future<bool> turnOn(String deviceId) async => true;
  // ... other methods
}

class FailingDriver extends SuccessDriver {
  @override
  Future<bool> turnOn(String deviceId) async => throw Exception('boom');
}

test('tryFlushOp deletes op on success', () async {
  final container = ProviderContainer(overrides: [
    automationDriverProvider.overrideWithValue(SuccessDriver()),
  ]);

  final pending = LocalHiveService.pendingOpsBox();
  final op = PendingOp(
    opId: 'op1',
    entityId: 'd1',
    entityType: 'device',
    opType: 'control',
    payload: {'deviceId': 'd1', 'action': 'turnOn'},
  );
  await pending.put(op.opId, op);

  final svc = container.read(automationSyncServiceProvider);
  await svc.tryFlushOp(op);

  expect(pending.get('op1'), isNull); // Deleted on success
});

test('tryFlushOp increments attempts on failure', () async {
  final container = ProviderContainer(overrides: [
    automationDriverProvider.overrideWithValue(FailingDriver()),
  ]);

  final pending = LocalHiveService.pendingOpsBox();
  final op = PendingOp(/* same as above */);
  await pending.put(op.opId, op);

  final svc = container.read(automationSyncServiceProvider);
  await svc.tryFlushOp(op);

  final stored = pending.get('op2');
  expect(stored!.attempts, 1); // Incremented
});
*/
