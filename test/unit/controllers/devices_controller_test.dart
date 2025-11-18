import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DevicesController', () {
    test('optimistic toggle succeeds', () async {
      // TODO: Use test_harness to build container and mock repo
      expect(true, isTrue, reason: 'placeholder');
    }, skip: 'Implement after controller + repository harness is available.');

    test('optimistic toggle rolls back on failure', () async {
      // TODO: Simulate repo failure and ensure state rollback
      expect(true, isTrue, reason: 'placeholder');
    }, skip: 'Implement after controller + repository harness is available.');
  });
}

/*
SNIPPET (for future implementation):

test('toggle device optimistic rollback on failure', () async {
  final mockRepo = MockDeviceRepository();

  final initial = [
    DeviceModel(id: 'd1', roomId: 'r1', type: DeviceType.bulb, name: 'Bulb', isOn: false),
  ];

  when(() => mockRepo.getDevicesForRoom('r1')).thenAnswer((_) async => initial);
  when(() => mockRepo.watchDevicesForRoom('r1')).thenAnswer((_) => const Stream.empty());
  
  // Toggle fails
  when(() => mockRepo.toggleDevice('d1', true)).thenThrow(Exception('offline'));

  final container = ProviderContainer(overrides: [
    deviceRepositoryProvider.overrideWithValue(mockRepo),
  ]);

  // Wait for initial load
  for (var i = 0; i < 10; i++) {
    final s = container.read(devicesControllerProvider('r1'));
    if (s.value != null && s.value!.isNotEmpty) break;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }

  final controller = container.read(devicesControllerProvider('r1').notifier);
  await controller.toggleDevice('d1', true);

  final state = container.read(devicesControllerProvider('r1'));
  expect(state.value!.first.isOn, false); // Rolled back to original
});

*/
