import 'dart:async';
import 'package:hive/hive.dart';
import '../../logic/sync/control_op_helper.dart';
import '../models/device_model.dart' as domain;
import '../hive_adapters/device_model_hive.dart';
import 'package:guardian_angel_fyp/persistence/models/pending_op.dart';
import '../../core/utils/id_generator.dart';
import 'device_repository.dart';

class DeviceRepositoryHive implements DeviceRepository {
  final Box<DeviceModelHive> _box;
  final Box<PendingOp> _pendingBox;
  final String _clientId;
  DeviceRepositoryHive(this._box, this._pendingBox, this._clientId);

  DeviceModelHive _toHive(domain.DeviceModel d, {String? overrideId}) => DeviceModelHive(
    id: overrideId ?? d.id,
        roomId: d.roomId,
        type: d.type.toString().split('.').last,
        name: d.name,
        isOn: d.isOn,
        state: d.state,
        lastSeen: d.lastSeen,
        updatedAt: d.lastSeen,
        version: 0,
      );

  domain.DeviceModel _toDomain(DeviceModelHive h) => domain.DeviceModel(
        id: h.id,
        roomId: h.roomId,
        type: _typeFrom(h.type),
        name: h.name,
        isOn: h.isOn,
        state: h.state,
        lastSeen: h.lastSeen,
      );

  domain.DeviceType _typeFrom(String raw) {
    return domain.DeviceType.values.firstWhere(
      (e) => e.toString().split('.').last == raw,
      orElse: () => domain.DeviceType.bulb,
    );
  }

  @override
  Future<List<domain.DeviceModel>> getDevicesForRoom(String roomId) async {
    // Iterate with keys so we can repair any legacy entries that have empty IDs
    final List<domain.DeviceModel> results = [];
    for (final entry in _box.toMap().entries) {
      final key = entry.key;
      final value = entry.value;
      if (value.roomId != roomId) continue;
      // Repair: if stored id is empty, set it to the box key and persist
      if ((value.id).isEmpty && key is String) {
        final repaired = DeviceModelHive(
          id: key,
          roomId: value.roomId,
          type: value.type,
          name: value.name,
          isOn: value.isOn,
          state: value.state,
          lastSeen: value.lastSeen,
          updatedAt: DateTime.now(),
          version: value.version,
        );
        await _box.put(key, repaired);
        results.add(_toDomain(repaired));
      } else {
        results.add(_toDomain(value));
      }
    }
    return results;
  }

  @override
  Future<domain.DeviceModel> createDevice(domain.DeviceModel device) async {
    final id = device.id.isEmpty ? generateId() : device.id;
    // Ensure the stored record carries the same id as the box key
    final hive = _toHive(device, overrideId: id);
    final stored = hive.copyWith(version: hive.version + 1, updatedAt: DateTime.now());
    await _box.put(id, stored);
    _enqueuePendingOp(entityId: stored.id, opType: 'create', payload: _deviceToMap(stored));
    _tryFlushPending();
    return _toDomain(stored);
  }

  @override
  Future<void> updateDevice(domain.DeviceModel device) async {
    final existing = _box.get(device.id);
    if (existing == null) throw StateError('Device not found: ${device.id}');
    final updated = existing.copyWith(
      isOn: device.isOn,
      state: device.state,
      name: device.name,
      lastSeen: DateTime.now(),
      updatedAt: DateTime.now(),
      version: existing.version + 1,
    );
    await _box.put(device.id, updated);
    _enqueuePendingOp(entityId: updated.id, opType: 'update', payload: _deviceToMap(updated));
    _tryFlushPending();
  }

  @override
  Future<void> deleteDevice(String deviceId) async {
    await _box.delete(deviceId);
    _enqueuePendingOp(entityId: deviceId, opType: 'delete', payload: {'id': deviceId});
    _tryFlushPending();
  }

  @override
  Stream<domain.DeviceModel> watchDevice(String deviceId) async* {
    final initial = _box.get(deviceId);
    if (initial != null) yield _toDomain(initial);
    yield* _box.watch(key: deviceId).map((event) {
      final value = _box.get(deviceId);
      if (value == null) throw StateError('Device removed');
      return _toDomain(value);
    });
  }

  @override
  Stream<List<domain.DeviceModel>> watchDevicesForRoom(String roomId) async* {
    // Initial emit (also repairs legacy IDs)
    yield await getDevicesForRoom(roomId);
    // On any box change, recompute the room list to avoid emitting stale/duplicated entries
    yield* _box.watch().asyncMap((_) => getDevicesForRoom(roomId));
  }

  @override
  Future<void> toggleDevice(String deviceId, bool value) async {
    final existing = _box.get(deviceId);
    if (existing == null) throw StateError('Device not found: $deviceId');
    final updated = existing.copyWith(
      isOn: value,
      lastSeen: DateTime.now(),
      updatedAt: DateTime.now(),
      version: existing.version + 1,
    );
    await _box.put(deviceId, updated);
    // Backend toggle op (legacy/general sync)
    _enqueuePendingOp(entityId: deviceId, opType: 'toggle', payload: {'id': deviceId, 'isOn': value});
    // Automation control op (standardized shape for AutomationSyncService)
    ControlOpHelper.enqueueControlOp(
      pendingBox: _pendingBox,
      deviceId: deviceId,
      action: value ? 'turnOn' : 'turnOff',
      value: value,
      // Optionally inline protocolData snapshot here if desired
      protocolData: null,
      clientId: _clientId,
    );
    _tryFlushPending();
  }

  Map<String, dynamic> _deviceToMap(DeviceModelHive d) => {
        'id': d.id,
        'roomId': d.roomId,
        'type': d.type,
        'name': d.name,
        'isOn': d.isOn,
        'state': d.state,
        'lastSeen': d.lastSeen.toIso8601String(),
        'updatedAt': d.updatedAt.toIso8601String(),
        'version': d.version,
      };

  void _enqueuePendingOp({required String entityId, required String opType, required Map<String, dynamic> payload}) {
    final opId = 'op_${DateTime.now().millisecondsSinceEpoch}_$entityId';
    final mergedPayload = Map<String, dynamic>.from(payload);
    mergedPayload.putIfAbsent('operationId', () => opId);
    mergedPayload['clientId'] = _clientId;

    final op = PendingOp.forHomeAutomation(
      opId: opId,
      entityId: entityId,
      entityType: 'device',
      opType: opType,
      payload: mergedPayload,
    );
    _pendingBox.put(op.opId, op);
  }

  void _tryFlushPending() {
    // Placeholder for sync logic / background flusher.
  }
}
