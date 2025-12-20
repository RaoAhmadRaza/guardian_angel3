/// HomeAutomationRepositoryHive - Hive implementation of HomeAutomationRepository.
///
/// Part of PHASE 2: Backend is the only source of truth.
/// Updated in PHASE 1 BLOCKER FIX: HiveError handling.
///
/// Data Flow:
/// UI → automationStateProvider → HomeAutomationRepositoryHive → BoxAccessor → Hive
library;

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
// Room/Device models re-exported from home_automation_repository
import '../../home automation/src/data/hive_adapters/room_model_hive.dart';
import '../../home automation/src/data/hive_adapters/device_model_hive.dart';
import '../../home automation/src/data/local_hive_service.dart';
import '../../persistence/errors/errors.dart';
import '../../persistence/models/pending_op.dart';
import '../home_automation_repository.dart';

/// Hive-backed implementation of HomeAutomationRepository.
/// 
/// Note: This uses the home automation Hive models (RoomModelHive, DeviceModelHive)
/// and converts to/from domain models.
class HomeAutomationRepositoryHive implements HomeAutomationRepository {
  final String _clientId;

  HomeAutomationRepositoryHive({
    String? clientId,
  })  : _clientId = clientId ?? 'home-automation-app';

  // Use home automation local service boxes
  Box<RoomModelHive> get _roomsBox => LocalHiveService.roomBox();
  Box<DeviceModelHive> get _devicesBox => LocalHiveService.deviceBox();
  Box<PendingOp> get _pendingBox => LocalHiveService.pendingOpsBox();

  // ═══════════════════════════════════════════════════════════════════════
  // MODEL CONVERSIONS
  // ═══════════════════════════════════════════════════════════════════════

  RoomModel _roomToDomain(RoomModelHive h) => RoomModel(
    id: h.id,
    name: h.name,
    iconId: h.iconId,
    color: h.color,
    createdAt: h.createdAt,
    updatedAt: h.updatedAt,
  );

  RoomModelHive _roomToHive(RoomModel r) => RoomModelHive(
    id: r.id,
    name: r.name,
    iconId: r.iconId,
    color: r.color,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
    version: 0,
  );

  DeviceModel _deviceToDomain(DeviceModelHive h) => DeviceModel(
    id: h.id,
    roomId: h.roomId,
    type: _typeFrom(h.type),
    name: h.name,
    isOn: h.isOn,
    state: h.state,
    lastSeen: h.lastSeen,
  );

  DeviceType _typeFrom(String raw) {
    return DeviceType.values.firstWhere(
      (e) => e.toString().split('.').last == raw,
      orElse: () => DeviceType.bulb,
    );
  }

  DeviceModelHive _deviceToHive(DeviceModel d) => DeviceModelHive(
    id: d.id,
    roomId: d.roomId,
    type: d.type.toString().split('.').last,
    name: d.name,
    isOn: d.isOn,
    state: d.state,
    lastSeen: d.lastSeen,
    updatedAt: d.lastSeen,
    version: 0,
  );

  String _generateId() =>
      'id_${DateTime.now().millisecondsSinceEpoch}_${_roomsBox.length + _devicesBox.length}';

  @override
  Stream<AutomationState> watchState() async* {
    // Emit current state immediately
    yield await getState();

    // Watch rooms and devices boxes
    await for (final _ in _mergeBoxWatches()) {
      yield await getState();
    }
  }

  Stream<void> _mergeBoxWatches() async* {
    // Simple approach: emit on any box change
    yield* _roomsBox.watch().map((_) {});
  }

  @override
  Future<AutomationState> getState() async {
    final rooms = _roomsBox.values.toList();
    final devices = _devicesBox.values.toList();
    final activeDevices = devices.where((d) => d.isOn).length;

    // Calculate mock energy usage based on active devices
    final energyUsage = activeDevices * 0.15; // 0.15 kWh per active device

    return AutomationState(
      totalRooms: rooms.length,
      totalDevices: devices.length,
      activeDevices: activeDevices,
      energyUsage: energyUsage,
      isConnected: true, // TODO: wire to actual connectivity
      lastUpdated: DateTime.now(),
    );
  }

  @override
  Stream<List<RoomModel>> watchRooms() async* {
    // Emit current state immediately
    yield _roomsBox.values.map(_roomToDomain).toList();
    // Then emit on every change
    yield* _roomsBox.watch().map((_) => _roomsBox.values.map(_roomToDomain).toList());
  }

  @override
  Stream<List<DeviceModel>> watchDevices() async* {
    yield _devicesBox.values.map(_deviceToDomain).toList();
    yield* _devicesBox.watch().map((_) => _devicesBox.values.map(_deviceToDomain).toList());
  }

  @override
  Stream<List<DeviceModel>> watchDevicesForRoom(String roomId) async* {
    List<DeviceModel> _filter() =>
        _devicesBox.values.where((d) => d.roomId == roomId).map(_deviceToDomain).toList();
    yield _filter();
    yield* _devicesBox.watch().map((_) => _filter());
  }

  @override
  Future<List<RoomModel>> getRooms() async {
    return _roomsBox.values.map(_roomToDomain).toList();
  }

  @override
  Future<List<DeviceModel>> getDevices() async {
    return _devicesBox.values.map(_deviceToDomain).toList();
  }

  @override
  Future<List<DeviceModel>> getDevicesForRoom(String roomId) async {
    return _devicesBox.values.where((d) => d.roomId == roomId).map(_deviceToDomain).toList();
  }

  @override
  Future<RoomModel> createRoom(RoomModel room) async {
    // Validate before persisting
    room.validate();
    final id = room.id.isEmpty ? _generateId() : room.id;
    final newRoom = room.copyWith(id: id);
    final hiveRoom = _roomToHive(newRoom);
    // PHASE 1 BLOCKER FIX: Safe HiveError handling
    final result = await SafeBoxOps.put(
      _roomsBox,
      id,
      hiveRoom,
      boxName: LocalHiveService.roomBoxName,
    );
    if (result.isFailure) throw result.error!;
    _enqueuePendingOp(
      entityId: id,
      domain: 'rooms',
      opType: 'create',
      payload: newRoom.toMap(),
    );
    return newRoom;
  }

  @override
  Future<void> updateRoom(RoomModel room) async {
    // Validate before persisting
    room.validate();
    final updated = room.copyWith(updatedAt: DateTime.now());
    final hiveRoom = _roomToHive(updated);
    final result = await SafeBoxOps.put(
      _roomsBox,
      room.id,
      hiveRoom,
      boxName: LocalHiveService.roomBoxName,
    );
    if (result.isFailure) throw result.error!;
    _enqueuePendingOp(
      entityId: room.id,
      domain: 'rooms',
      opType: 'update',
      payload: updated.toMap(),
    );
  }

  @override
  Future<void> deleteRoom(String roomId) async {
    final result = await SafeBoxOps.delete(
      _roomsBox,
      roomId,
      boxName: LocalHiveService.roomBoxName,
    );
    if (result.isFailure) throw result.error!;
    
    // Also delete devices in this room
    final devicesToDelete =
        _devicesBox.values.where((d) => d.roomId == roomId).toList();
    for (final device in devicesToDelete) {
      final devResult = await SafeBoxOps.delete(
        _devicesBox,
        device.id,
        boxName: LocalHiveService.deviceBoxName,
      );
      if (devResult.isFailure) throw devResult.error!;
    }
    _enqueuePendingOp(
      entityId: roomId,
      domain: 'rooms',
      opType: 'delete',
      payload: {'id': roomId},
    );
  }

  @override
  Future<DeviceModel> createDevice(DeviceModel device) async {
    // Validate before persisting
    device.validate();
    final id = device.id.isEmpty ? _generateId() : device.id;
    final newDevice = device.copyWith(name: device.name); // preserve all fields
    final hiveDevice = _deviceToHive(DeviceModel(
      id: id,
      roomId: newDevice.roomId,
      type: newDevice.type,
      name: newDevice.name,
      isOn: newDevice.isOn,
      state: newDevice.state,
      lastSeen: newDevice.lastSeen,
    ));
    // PHASE 1 BLOCKER FIX: Safe HiveError handling
    final result = await SafeBoxOps.put(
      _devicesBox,
      id,
      hiveDevice,
      boxName: LocalHiveService.deviceBoxName,
    );
    if (result.isFailure) throw result.error!;
    _enqueuePendingOp(
      entityId: id,
      domain: 'devices',
      opType: 'create',
      payload: newDevice.toMap(),
    );
    return DeviceModel(
      id: id,
      roomId: newDevice.roomId,
      type: newDevice.type,
      name: newDevice.name,
      isOn: newDevice.isOn,
      state: newDevice.state,
      lastSeen: newDevice.lastSeen,
    );
  }

  @override
  Future<void> updateDevice(DeviceModel device) async {
    // Validate before persisting
    device.validate();
    final hiveDevice = _deviceToHive(device);
    final result = await SafeBoxOps.put(
      _devicesBox,
      device.id,
      hiveDevice,
      boxName: LocalHiveService.deviceBoxName,
    );
    if (result.isFailure) throw result.error!;
    _enqueuePendingOp(
      entityId: device.id,
      domain: 'devices',
      opType: 'update',
      payload: device.toMap(),
    );
  }

  @override
  Future<void> toggleDevice(String deviceId, bool isOn) async {
    final device = _devicesBox.get(deviceId);
    if (device == null) throw StateError('Device not found: $deviceId');
    final updated = device.copyWith(isOn: isOn);
    final result = await SafeBoxOps.put(
      _devicesBox,
      deviceId,
      updated,
      boxName: LocalHiveService.deviceBoxName,
    );
    if (result.isFailure) throw result.error!;
    _enqueuePendingOp(
      entityId: deviceId,
      domain: 'devices',
      opType: 'toggle',
      payload: {'id': deviceId, 'isOn': isOn},
    );
  }

  @override
  Future<void> deleteDevice(String deviceId) async {
    final result = await SafeBoxOps.delete(
      _devicesBox,
      deviceId,
      boxName: LocalHiveService.deviceBoxName,
    );
    if (result.isFailure) throw result.error!;
    _enqueuePendingOp(
      entityId: deviceId,
      domain: 'devices',
      opType: 'delete',
      payload: {'id': deviceId},
    );
  }

  void _enqueuePendingOp({
    required String entityId,
    required String domain,
    required String opType,
    required Map<String, dynamic> payload,
  }) {
    final now = DateTime.now().toUtc();
    final opId = 'op_${now.millisecondsSinceEpoch}_$entityId';
    final idempotencyKey = const Uuid().v4();
    
    final op = PendingOp(
      id: opId,
      opType: opType,
      idempotencyKey: idempotencyKey,
      payload: {
        ...payload,
        'operationId': opId,
        'clientId': _clientId,
        'domain': domain,
        'entityId': entityId,
      },
      attempts: 0,
      status: 'pending',
      createdAt: now,
      updatedAt: now,
    );
    _pendingBox.put(opId, op);
  }
}
