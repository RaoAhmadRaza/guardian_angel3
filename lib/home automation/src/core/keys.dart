import 'package:flutter/widgets.dart';

class AppKeys {
  static const addRoomButton = Key('addRoomButton');
  static const roomNameField = Key('roomNameField');
  static const saveRoomButton = Key('saveRoomButton');

  static const roomListTilePrefix = 'roomTile_';
  static Key roomTileKey(String roomId) => Key('$roomListTilePrefix$roomId');

  static const addDeviceButton = Key('addDeviceButton');
  static const deviceNameField = Key('deviceNameField');
  static const deviceProtocolDropdown = Key('deviceProtocolDropdown');
  static const deviceBrokerField = Key('deviceBrokerField');
  static const deviceTopicField = Key('deviceTopicField');
  static const deviceStateTopicField = Key('deviceStateTopicField');
  static const saveDeviceButton = Key('saveDeviceButton');

  static Key deviceTileKey(String deviceId) => Key('deviceTile_$deviceId');
  static const deviceToggleButtonPrefix = 'deviceToggleButton_';
  static Key deviceToggleKey(String deviceId) => Key('${deviceToggleButtonPrefix}$deviceId');

  static Key devicePendingIndicator(String deviceId) => Key('devicePending_$deviceId');
}
