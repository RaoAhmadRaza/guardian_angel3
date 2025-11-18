import 'dart:async';
import '../models/device_model.dart';
import '../../core/utils/id_generator.dart';

abstract class DeviceRepository {
  Future<List<DeviceModel>> getDevicesForRoom(String roomId);
  Future<DeviceModel> createDevice(DeviceModel device);
  Future<void> updateDevice(DeviceModel device);
  Future<void> deleteDevice(String deviceId);
  Stream<DeviceModel> watchDevice(String deviceId);
  Stream<List<DeviceModel>> watchDevicesForRoom(String roomId);
  Future<void> toggleDevice(String deviceId, bool value);
}

class InMemoryDeviceRepository implements DeviceRepository {
  final Map<String, List<DeviceModel>> _roomDevices = {
    '1': [
      DeviceModel(id: 'd1', roomId: '1', type: DeviceType.bulb, name: 'Bulb', isOn: true),
      DeviceModel(id: 'd2', roomId: '1', type: DeviceType.lamp, name: 'Lamp', isOn: false),
      DeviceModel(id: 'd3', roomId: '1', type: DeviceType.fan, name: 'Fan', isOn: true),
    ],
  };

  final Map<String, StreamController<DeviceModel>> _deviceControllers = {};
  final Map<String, StreamController<List<DeviceModel>>> _roomControllers = {};

  StreamController<DeviceModel> _controllerFor(String id) =>
      _deviceControllers.putIfAbsent(id, () => StreamController<DeviceModel>.broadcast());

  StreamController<List<DeviceModel>> _roomController(String roomId) =>
      _roomControllers.putIfAbsent(roomId, () => StreamController<List<DeviceModel>>.broadcast());

  void _emitRoom(String roomId) {
    _roomController(roomId).add(List.unmodifiable(_roomDevices[roomId] ?? []));
  }

  @override
  Future<List<DeviceModel>> getDevicesForRoom(String roomId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return List.unmodifiable(_roomDevices[roomId] ?? []);
  }

  @override
  Future<DeviceModel> createDevice(DeviceModel device) async {
    final id = generateId();
    final saved = DeviceModel(
      id: id,
      roomId: device.roomId,
      type: device.type,
      name: device.name,
      isOn: device.isOn,
      state: device.state,
      lastSeen: DateTime.now(),
    );
    final list = _roomDevices.putIfAbsent(device.roomId, () => []);
    list.add(saved);
    _controllerFor(saved.id).add(saved);
    _emitRoom(device.roomId);
    return saved;
  }

  @override
  Future<void> updateDevice(DeviceModel device) async {
    final list = _roomDevices[device.roomId];
    if (list == null) throw StateError('No devices for room: ${device.roomId}');
    final index = list.indexWhere((d) => d.id == device.id);
    if (index == -1) throw StateError('Device not found: ${device.id}');
    list[index] = device.copyWith(lastSeen: DateTime.now());
    _controllerFor(device.id).add(list[index]);
    _emitRoom(device.roomId);
  }

  @override
  Future<void> deleteDevice(String deviceId) async {
    for (final entry in _roomDevices.entries) {
      entry.value.removeWhere((d) => d.id == deviceId);
    }
    _deviceControllers[deviceId]?.close();
    _deviceControllers.remove(deviceId);
    // emit for all rooms (inefficient but fine for small data)
    for (final roomId in _roomDevices.keys) {
      _emitRoom(roomId);
    }
  }

  @override
  Stream<DeviceModel> watchDevice(String deviceId) => _controllerFor(deviceId).stream;

  @override
  Stream<List<DeviceModel>> watchDevicesForRoom(String roomId) => _roomController(roomId).stream;

  @override
  Future<void> toggleDevice(String deviceId, bool value) async {
    for (final entry in _roomDevices.entries) {
      final index = entry.value.indexWhere((d) => d.id == deviceId);
      if (index != -1) {
        final updated = entry.value[index].copyWith(isOn: value, lastSeen: DateTime.now());
        entry.value[index] = updated;
        _controllerFor(deviceId).add(updated);
        _emitRoom(entry.key);
        return;
      }
    }
    throw StateError('Device not found: $deviceId');
  }
}
