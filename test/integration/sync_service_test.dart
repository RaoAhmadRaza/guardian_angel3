import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SyncService network awareness', () {
    test('flushes ops when online', () async {
      // TODO: Provide fake API + network status provider
      expect(true, isTrue);
    }, skip: 'Pending SyncService wiring.');

    test('defers when offline and resumes online', () async {
      expect(true, isTrue);
    }, skip: 'Pending SyncService wiring.');
  });
}

/*
SNIPPET (for future implementation):

class _ApiClientFake extends ApiClient {
  int createdRooms = 0;
  
  @override
  Future<void> createRoom(Map<String, dynamic> payload) async {
    createdRooms += 1;
    return super.createRoom(payload);
  }
}

test('SyncService flushes room create op when online', () async {
  final fakeApi = _ApiClientFake();
  final container = ProviderContainer(overrides: [
    apiClientProvider.overrideWithValue(fakeApi),
    networkStatusProvider.overrideWith((ref) => true), // Online
  ]);

  container.read(syncServiceProvider); // Start service

  final pending = LocalHiveService.pendingOpsBox();
  final op = PendingOp(
    opId: 'op1_r1',
    entityId: 'r1',
    entityType: 'room',
    opType: 'create',
    payload: {
      'id': 'r1',
      'name': 'A',
      'iconId': 'sofa',
      'color': 0xffffffff,
      /* ... */
    },
  );
  await pending.put(op.opId, op);

  await waitUntil(() async => pending.isEmpty);

  expect(fakeApi.createdRooms, 1); // API called
});

*/
