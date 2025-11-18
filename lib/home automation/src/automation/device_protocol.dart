// Device protocol helpers and types independent of drivers.
//
// Example protocolData shapes stored inside DeviceModel.state['protocolData']
/*
MQTT:
{
  "protocol": "mqtt",
  "broker": "192.168.1.23",
  "port": 1883,
  "topic": "home/room1/light1",
  "payloadOn": "{\"state\":\"ON\"}",
  "payloadOff": "{\"state\":\"OFF\"}",
  "payloadSet": "{\"brightness\":${value}}", // template, ${value} replaced
  "username": "user",        // optional
  "passwordKey": "secureKey",// key to locate credentials in secure storage (do NOT store plaintext)
  "qos": 1,
  "retain": false
}

Tuya/Cloud:
{
  "protocol": "tuya",
  "backendDeviceId": "xxxx", // id assigned by backend
  "backend": "https://api.mybackend.example"
}

BLE:
{
  "protocol": "ble",
  "deviceAddress": "AA:BB:CC:DD:EE:FF"
}
*/

import '../data/models/device_model.dart' as domain;

/// Protocol type strings used in registry (keep lowercase).
class Protocols {
  static const String mqtt = 'mqtt';
  static const String websocket = 'websocket';
  static const String tuya = 'tuya';
  static const String mock = 'mock';
  static const String ble = 'ble';
}

/// Logical device kinds (for UI/pairing flows).
enum DeviceKind { bulb, lamp, fan }

/// Converts domain device type to DeviceKind.
DeviceKind kindFromDomain(domain.DeviceType t) {
  switch (t) {
    case domain.DeviceType.bulb:
      return DeviceKind.bulb;
    case domain.DeviceType.lamp:
      return DeviceKind.lamp;
    case domain.DeviceType.fan:
      return DeviceKind.fan;
  }
}

/// Key constants and helpers for protocolData map.
class ProtocolDataKeys {
  static const String protocol = 'protocol';

  // Common MQTT keys
  static const String broker = 'broker';
  static const String port = 'port';
  static const String topic = 'topic';
  static const String payloadOn = 'payloadOn';
  static const String payloadOff = 'payloadOff';
  static const String payloadSet = 'payloadSet'; // supports ${value}
  static const String username = 'username';
  static const String passwordKey = 'passwordKey';
  static const String qos = 'qos';
  static const String retain = 'retain';

  // Tuya
  static const String backend = 'backend';
  static const String backendDeviceId = 'backendDeviceId';

  // BLE
  static const String deviceAddress = 'deviceAddress';
}

/// Accessors for protocolData inside DeviceModel.state.
Map<String, dynamic>? getProtocolData(domain.DeviceModel d) {
  final s = d.state;
  final p = s['protocolData'];
  if (p is Map<String, dynamic>) return p;
  return null;
}

domain.DeviceModel withProtocolData(domain.DeviceModel d, Map<String, dynamic> protocolData) {
  final newState = Map<String, dynamic>.from(d.state);
  newState['protocolData'] = protocolData;
  return d.copyWith(state: newState);
}

bool isProtocol(Map<String, dynamic>? data, String protocol) =>
    (data != null && data[ProtocolDataKeys.protocol] == protocol);

/// Builders for common protocolData maps
Map<String, dynamic> buildMqttProtocolData({
  required String broker,
  int port = 1883,
  // Legacy single topic (will act as cmd+state if cmdTopic/stateTopic omitted)
  required String topic,
  String? cmdTopic,
  String? stateTopic,
  // Defaults aligned with simulator expectations (isOn true/false). Can be overridden.
  String payloadOn = '{"isOn":true}',
  String payloadOff = '{"isOn":false}',
  String payloadSetTemplate = r'{"brightness":${value}}',
  String? username,
  String? passwordKey,
  int qos = 1,
  bool retain = false,
}) {
  return {
    ProtocolDataKeys.protocol: Protocols.mqtt,
    ProtocolDataKeys.broker: broker,
    ProtocolDataKeys.port: port,
    // legacy key
    ProtocolDataKeys.topic: topic,
    if (cmdTopic != null) 'cmdTopic': cmdTopic,
    if (stateTopic != null) 'stateTopic': stateTopic,
    ProtocolDataKeys.payloadOn: payloadOn,
    ProtocolDataKeys.payloadOff: payloadOff,
    ProtocolDataKeys.payloadSet: payloadSetTemplate,
    if (username != null) ProtocolDataKeys.username: username,
    if (passwordKey != null) ProtocolDataKeys.passwordKey: passwordKey,
    ProtocolDataKeys.qos: qos,
    ProtocolDataKeys.retain: retain,
  };
}

String applyValueTemplate(String template, int value) => template.replaceAll(r'${value}', value.toString());

/// Normalize legacy protocolData maps (ensure cmdTopic/stateTopic present).
Map<String, dynamic> normalizeMqttProtocolData(Map<String, dynamic> data) {
  if (data[ProtocolDataKeys.protocol] != Protocols.mqtt) return data;
  // If cmdTopic/stateTopic missing, derive them from legacy 'topic'
  final topic = data[ProtocolDataKeys.topic] as String?;
  if (topic != null) {
    data.putIfAbsent('cmdTopic', () => topic);
    data.putIfAbsent('stateTopic', () => topic); // default: same topic
  }
  return data;
}

Map<String, dynamic> buildTuyaProtocolData({
  required String backend,
  required String backendDeviceId,
}) => {
      ProtocolDataKeys.protocol: Protocols.tuya,
      ProtocolDataKeys.backend: backend,
      ProtocolDataKeys.backendDeviceId: backendDeviceId,
    };

Map<String, dynamic> buildBleProtocolData({
  required String deviceAddress,
}) => {
      ProtocolDataKeys.protocol: Protocols.ble,
      ProtocolDataKeys.deviceAddress: deviceAddress,
    };
