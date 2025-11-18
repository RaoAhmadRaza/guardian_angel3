import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RoomsController', () {
    test('loads initial rooms', () async {
      // TODO: Use test_harness with mock repository
      expect(true, isTrue, reason: 'placeholder');
    }, skip: 'Pending rooms controller + repo wiring.');

    test('addRoom updates state optimistically', () async {
      expect(true, isTrue, reason: 'placeholder');
    }, skip: 'Pending rooms controller + repo wiring.');

    test('updateRoom mutates state', () async {
      expect(true, isTrue, reason: 'placeholder');
    }, skip: 'Pending rooms controller + repo wiring.');

    test('deleteRoom removes from state', () async {
      expect(true, isTrue, reason: 'placeholder');
    }, skip: 'Pending rooms controller + repo wiring.');
  });
}

/*
SNIPPET (for future implementation):

test('initial load returns rooms', () async {
  when(() => mockRepo.getAllRooms()).thenAnswer((_) async => [
    RoomModel(id: 'r1', name: 'Living', iconId: 'sofa', color: 0xFF123456),
  ]);
  when(() => mockRepo.watchRooms()).thenAnswer((_) => const Stream.empty());

  final container = makeContainer(overrides: [
    roomRepositoryProvider.overrideWithValue(mockRepo),
  ]);

  // Wait for initial load
  for (var i = 0; i < 10; i++) {
    final s = container.read(roomsControllerProvider);
    if (s.value != null) break;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  
  final state = container.read(roomsControllerProvider);
  expect(state.value, isNotNull);
  expect(state.value!.length, 1);
  disposeContainer(container);
});
*/
