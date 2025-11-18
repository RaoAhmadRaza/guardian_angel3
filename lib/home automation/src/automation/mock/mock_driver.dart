import 'dart:async';
import '../interfaces/automation_interface.dart';

class MockDriver implements AutomationDriver {
  final Map<String, DeviceState> _states = {};
  final Map<String, StreamController<DeviceEvent>> _controllers = {};

  @override
  Future<void> init() async {}

  @override
  Future<bool> turnOn(String deviceId) async {
    final state = DeviceState(isOn: true, level: _states[deviceId]?.level, raw: null);
    _states[deviceId] = state;
    _controllers.putIfAbsent(deviceId, () => StreamController<DeviceEvent>.broadcast()).add(
      DeviceEvent(deviceId: deviceId, state: state),
    );
    return true;
  }

  @override
  Future<bool> turnOff(String deviceId) async {
    final state = DeviceState(isOn: false, level: _states[deviceId]?.level, raw: null);
    _states[deviceId] = state;
    _controllers.putIfAbsent(deviceId, () => StreamController<DeviceEvent>.broadcast()).add(
      DeviceEvent(deviceId: deviceId, state: state),
    );
    return true;
  }

  @override
  Future<bool> setIntensity(String deviceId, int value) async {
    final state = DeviceState(isOn: value > 0, level: value, raw: null);
    _states[deviceId] = state;
    _controllers.putIfAbsent(deviceId, () => StreamController<DeviceEvent>.broadcast()).add(
      DeviceEvent(deviceId: deviceId, state: state),
    );
    return true;
  }

  @override
  Future<DeviceState> getState(String deviceId) async {
    return _states[deviceId] ?? DeviceState(isOn: false, level: 0);
  }

  @override
  Stream<DeviceEvent> watchDevice(String deviceId) {
    return _controllers.putIfAbsent(deviceId, () => StreamController<DeviceEvent>.broadcast()).stream;
  }

  @override
  Future<void> dispose() async {
    for (final c in _controllers.values) await c.close();
  }
}
