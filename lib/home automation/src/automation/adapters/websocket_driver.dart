// Generic WebSocket driver implementing AutomationDriver.

import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../interfaces/automation_interface.dart';

class WebSocketAutomationDriver implements AutomationDriver {
  WebSocketChannel? _channel;
  Uri? _uri;

  final Map<String, DeviceState> _cache = {};
  final Map<String, StreamController<DeviceEvent>> _controllers = {};

  WebSocketAutomationDriver({Uri? uri}) : _uri = uri;

  StreamController<DeviceEvent> _controllerFor(String id) =>
      _controllers.putIfAbsent(id, () => StreamController<DeviceEvent>.broadcast());

  @override
  Future<void> init() async {
    if (_uri == null) return;
    _channel = WebSocketChannel.connect(_uri!);
    _channel!.stream.listen((message) {
      try {
        final data = jsonDecode(message as String) as Map<String, dynamic>;
        final deviceId = data['deviceId'] as String?;
        if (deviceId != null) {
          final state = DeviceState(
            isOn: (data['isOn'] as bool?) ?? _cache[deviceId]?.isOn ?? false,
            level: data['level'] as int?,
            raw: data,
          );
          _cache[deviceId] = state;
          _controllerFor(deviceId).add(DeviceEvent(deviceId: deviceId, state: state));
        }
      } catch (_) {}
    });
  }

  @override
  Future<void> dispose() async {
    await _channel?.sink.close();
    for (final c in _controllers.values) {
      await c.close();
    }
    _controllers.clear();
  }

  @override
  Future<bool> turnOn(String deviceId) async {
    _channel?.sink.add(jsonEncode({'deviceId': deviceId, 'command': 'on'}));
    final state = DeviceState(isOn: true, level: _cache[deviceId]?.level);
    _cache[deviceId] = state;
    _controllerFor(deviceId).add(DeviceEvent(deviceId: deviceId, state: state));
    return true;
  }

  @override
  Future<bool> turnOff(String deviceId) async {
    _channel?.sink.add(jsonEncode({'deviceId': deviceId, 'command': 'off'}));
    final state = DeviceState(isOn: false, level: _cache[deviceId]?.level);
    _cache[deviceId] = state;
    _controllerFor(deviceId).add(DeviceEvent(deviceId: deviceId, state: state));
    return true;
  }

  @override
  Future<bool> setIntensity(String deviceId, int value) async {
    final clamped = value.clamp(0, 100);
    _channel?.sink.add(jsonEncode({'deviceId': deviceId, 'command': 'level', 'value': clamped}));
    final prev = _cache[deviceId];
    final state = DeviceState(isOn: prev?.isOn ?? true, level: clamped);
    _cache[deviceId] = state;
    _controllerFor(deviceId).add(DeviceEvent(deviceId: deviceId, state: state));
    return true;
  }

  @override
  Future<DeviceState> getState(String deviceId) async {
    return _cache[deviceId] ?? DeviceState(isOn: false, level: 0);
  }

  @override
  Stream<DeviceEvent> watchDevice(String deviceId) => _controllerFor(deviceId).stream;
}
