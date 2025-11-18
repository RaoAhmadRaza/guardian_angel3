import 'dart:async';
import 'package:dio/dio.dart';
import '../interfaces/automation_interface.dart';

class TuyaCloudDriver implements AutomationDriver {
  final Dio dio;
  final String baseUrl; // your backend proxy that holds private keys
  final void Function(String message)? onLog;
  final void Function(DeviceEvent event)? onEvent;
  TuyaCloudDriver({required this.dio, required this.baseUrl, this.onLog, this.onEvent});

  @override
  Future<void> init() async {
    // maybe refresh token here using your backend
    onLog?.call('Tuya: init');
  }

  @override
  Future<bool> turnOn(String deviceId) async {
    onLog?.call('Tuya: turnOn $deviceId');
    final r = await dio.post('$baseUrl/device/turnOn', data: {'deviceId': deviceId});
    return r.statusCode == 200 && r.data['ok'] == true;
  }

  @override
  Future<bool> turnOff(String deviceId) async {
    onLog?.call('Tuya: turnOff $deviceId');
    final r = await dio.post('$baseUrl/device/turnOff', data: {'deviceId': deviceId});
    return r.statusCode == 200 && r.data['ok'] == true;
  }

  @override
  Future<bool> setIntensity(String deviceId, int value) async {
    onLog?.call('Tuya: setIntensity $deviceId value=$value');
    final r = await dio.post('$baseUrl/device/set', data: {'deviceId': deviceId, 'value': value});
    return r.statusCode == 200;
  }

  @override
  Future<DeviceState> getState(String deviceId) async {
    onLog?.call('Tuya: getState $deviceId');
    final r = await dio.get('$baseUrl/device/state', queryParameters: {'deviceId': deviceId});
    final data = r.data as Map<String, dynamic>;
    final state = DeviceState(isOn: data['isOn'] == true, level: data['level'] as int? ?? 0, raw: data);
    onEvent?.call(DeviceEvent(deviceId: deviceId, state: state));
    return state;
  }

  @override
  Stream<DeviceEvent> watchDevice(String deviceId) {
    // If your backend supports SSE/WS, connect here. Else fallback to polling or rely on pending ops flush.
    // Example: poll every N seconds (simple fallback)
    final controller = StreamController<DeviceEvent>.broadcast();
    Timer? timer;
    controller.onListen = () {
      timer = Timer.periodic(const Duration(seconds: 10), (t) async {
        final s = await getState(deviceId);
        controller.add(DeviceEvent(deviceId: deviceId, state: s));
      });
    };
    controller.onCancel = () {
      timer?.cancel();
    };
    return controller.stream;
  }

  @override
  Future<void> dispose() async {}
}
