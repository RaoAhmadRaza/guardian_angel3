import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_angel_fyp/persistence/box_registry.dart';

void main() {
  group('BoxRegistry - Dual Box Issue Fix', () {
    group('Home Automation Box Names', () {
      test('legacy room box name is defined', () {
        expect(BoxRegistry.homeAutomationRoomsBoxLegacy, equals('rooms_v1'));
      });

      test('canonical room box name is defined', () {
        expect(BoxRegistry.homeAutomationRoomsBox, equals('ha_rooms_box'));
      });

      test('legacy device box name is defined', () {
        expect(BoxRegistry.homeAutomationDevicesBoxLegacy, equals('devices_v1'));
      });

      test('canonical device box name is defined', () {
        expect(BoxRegistry.homeAutomationDevicesBox, equals('ha_devices_box'));
      });

      test('allBoxes contains canonical home automation boxes', () {
        expect(BoxRegistry.allBoxes, contains(BoxRegistry.homeAutomationRoomsBox));
        expect(BoxRegistry.allBoxes, contains(BoxRegistry.homeAutomationDevicesBox));
      });

      test('legacyBoxes contains legacy home automation boxes', () {
        expect(BoxRegistry.legacyBoxes, contains(BoxRegistry.homeAutomationRoomsBoxLegacy));
        expect(BoxRegistry.legacyBoxes, contains(BoxRegistry.homeAutomationDevicesBoxLegacy));
      });
    });

    group('Core Box Names vs Home Automation Box Names', () {
      test('core roomsBox is different from home automation rooms', () {
        // This was the original bug - confusion between these two
        expect(BoxRegistry.roomsBox, isNot(equals(BoxRegistry.homeAutomationRoomsBoxLegacy)));
        expect(BoxRegistry.roomsBox, equals('rooms_box'));
        expect(BoxRegistry.homeAutomationRoomsBoxLegacy, equals('rooms_v1'));
      });

      test('core devicesBox is different from home automation devices', () {
        expect(BoxRegistry.devicesBox, isNot(equals(BoxRegistry.homeAutomationDevicesBoxLegacy)));
        expect(BoxRegistry.devicesBox, equals('devices_box'));
        expect(BoxRegistry.homeAutomationDevicesBoxLegacy, equals('devices_v1'));
      });

      test('all box names are unique', () {
        final allNames = [
          ...BoxRegistry.allBoxes,
          ...BoxRegistry.legacyBoxes,
        ];
        final uniqueNames = allNames.toSet();
        expect(uniqueNames.length, equals(allNames.length),
            reason: 'Duplicate box names found');
      });
    });

    group('Box Name Single Source of Truth', () {
      test('BoxRegistry is the authoritative source for all box names', () {
        // Verify key box names are defined
        expect(BoxRegistry.roomsBox, isNotEmpty);
        expect(BoxRegistry.devicesBox, isNotEmpty);
        expect(BoxRegistry.pendingOpsBox, isNotEmpty);
        expect(BoxRegistry.failedOpsBox, isNotEmpty);
        expect(BoxRegistry.homeAutomationRoomsBoxLegacy, isNotEmpty);
        expect(BoxRegistry.homeAutomationDevicesBoxLegacy, isNotEmpty);
        expect(BoxRegistry.homeAutomationRoomsBox, isNotEmpty);
        expect(BoxRegistry.homeAutomationDevicesBox, isNotEmpty);
      });

      test('allBoxes has expected count', () {
        // 16 original + 2 new home automation boxes = 18
        expect(BoxRegistry.allBoxes.length, equals(18));
      });

      test('legacyBoxes has expected count', () {
        expect(BoxRegistry.legacyBoxes.length, equals(2));
      });
    });
  });
}
