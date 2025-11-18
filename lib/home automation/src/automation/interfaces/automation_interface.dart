// automation_interface.dart
import 'dart:async';

class DeviceState {
  final bool isOn;
  final int? level; // 0..100 brightness or fan speed
  final Map<String, dynamic>? raw;

  DeviceState({required this.isOn, this.level, this.raw});
}

class DeviceEvent {
  final String deviceId;
  final DeviceState state;
  final DateTime timestamp;

  DeviceEvent({required this.deviceId, required this.state, DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();
}

abstract class AutomationDriver {
  /// Connect/initialize the driver (e.g., connect to broker or authenticate)
  Future<void> init();

  /// Turn device on/off. Return true if outcome accepted (may be queued).
  Future<bool> turnOn(String deviceId);
  Future<bool> turnOff(String deviceId);

  /// For bulbs/fans: 0..100. If unsupported by hardware, driver should map to nearest.
  Future<bool> setIntensity(String deviceId, int value);

  /// Returns latest state (may be local cached or fetched)
  Future<DeviceState> getState(String deviceId);

  /// Real-time notifications for device changes (driver controls .watchDevice)
  Stream<DeviceEvent> watchDevice(String deviceId);

  /// Graceful shutdown
  Future<void> dispose();
}
