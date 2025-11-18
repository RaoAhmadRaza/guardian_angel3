import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:guardian_angel_fyp/main.dart' as test_app;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:guardian_angel_fyp/home%20automation/src/core/keys.dart';
import 'package:guardian_angel_fyp/home%20automation/src/utils/network_status_provider.dart';
import 'package:guardian_angel_fyp/home%20automation/src/data/local_hive_service.dart';
import 'package:guardian_angel_fyp/home%20automation/src/data/hive_adapters/device_model_hive.dart';
import 'package:guardian_angel_fyp/home%20automation/src/data/hive_adapters/pending_op_hive.dart';
import 'package:guardian_angel_fyp/home%20automation/src/logic/providers/device_providers.dart';
// room_providers not needed explicitly here
import 'package:guardian_angel_fyp/home%20automation/src/data/models/device_model.dart' as domain;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('E2E: add room → add MQTT device → toggle → offline → pending queued → online → flushed', (tester) async {
    // Ensure test app booted (adapter registration guarded in test_main)
    test_app.main();
    await tester.pumpAndSettle();

    // Open drawer then go to Rooms screen
    final menuIcon = find.byType(AnimatedIcon).first;
    expect(menuIcon, findsOneWidget);
    await tester.tap(menuIcon);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rooms'));
    await tester.pumpAndSettle();

    // 1) Add Room via popup menu (three dots)
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.addRoomButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(AppKeys.roomNameField), 'Integration Room');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.saveRoomButton));
    await tester.pumpAndSettle();

    // Go to room detail
    await tester.tap(find.text('Integration Room'));
    await tester.pumpAndSettle();

    // Open edit dialog
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    // 2) Add Device (MQTT)
    await tester.tap(find.byKey(AppKeys.addDeviceButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(AppKeys.deviceNameField), 'Test MQTT Bulb');
    // Ensure protocol = MQTT
    await tester.tap(find.byKey(AppKeys.deviceProtocolDropdown));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MQTT').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(AppKeys.deviceBrokerField), '127.0.0.1');
    await tester.enterText(find.byKey(AppKeys.deviceTopicField), 'test/e2e/light1');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.saveDeviceButton));
    await tester.pumpAndSettle();

    // Device tile appears
    final deviceLabel = find.text('Test MQTT Bulb');
    expect(deviceLabel, findsOneWidget);

    // Find the switch within the device card
    final deviceCard = find.ancestor(of: deviceLabel, matching: find.byType(PhysicalModel));
    final toggleFinder = find.descendant(of: deviceCard, matching: find.byType(Switch));
    expect(toggleFinder, findsOneWidget);

    // 3) Toggle ON
    await tester.tap(toggleFinder);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(toggleFinder).value, isTrue);

    // Lookup roomId and deviceId from Hive
    final deviceBox = Hive.box<DeviceModelHive>(LocalHiveService.deviceBoxName);
    final deviceEntry = deviceBox.values.firstWhere((d) => d.name == 'Test MQTT Bulb');
    final roomId = deviceEntry.roomId;
    final deviceId = deviceEntry.id;

    // 4) Simulate offline
    final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    container.read(networkStatusProvider.notifier).state = false;

    // 5) Toggle OFF while offline (should enqueue pending op)
    await tester.tap(toggleFinder);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(toggleFinder).value, isFalse);

    // Assert at least one toggle op queued for this device
    final pendingBox = Hive.box<PendingOp>(LocalHiveService.pendingOpsBoxName);
    bool hasToggleForDevice() => pendingBox.values.any((op) => op.opType == 'toggle' && op.entityId == deviceId);
    expect(hasToggleForDevice(), isTrue);

    // 6) Go online and trigger SyncService by updating the device name via controller
    container.read(networkStatusProvider.notifier).state = true;
    final devicesNotifier = container.read(devicesControllerProvider(roomId).notifier);
    // Build a domain model from the hive entry (no-op name update to trigger write)
    domain.DeviceType _mapType(String t) {
      final key = t.toLowerCase();
      if (key == 'lamp') return domain.DeviceType.lamp;
      if (key == 'fan') return domain.DeviceType.fan;
      return domain.DeviceType.bulb;
    }
    final domainDevice = domain.DeviceModel(
      id: deviceEntry.id,
      roomId: deviceEntry.roomId,
      type: _mapType(deviceEntry.type),
      name: 'Test MQTT Bulb',
      isOn: deviceEntry.isOn,
      state: deviceEntry.state,
      lastSeen: deviceEntry.lastSeen,
    );
    await devicesNotifier.updateDevice(domainDevice);

    // Wait for sync to flush
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // 7) Confirm pending toggle op flushed
    expect(hasToggleForDevice(), isFalse);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
