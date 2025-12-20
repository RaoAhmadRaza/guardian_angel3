import 'dart:async';
import 'package:hive/hive.dart';
import '../models/room_model.dart' as domain;
import '../hive_adapters/room_model_hive.dart';
import 'package:guardian_angel_fyp/persistence/models/pending_op.dart';
import '../../core/utils/id_generator.dart';
import '../../data/file_storage.dart';
import 'room_repository.dart';

class RoomRepositoryHive implements RoomRepository {
  final Box<RoomModelHive> _box;
  final Box<PendingOp> _pendingBox;
  final String _clientId;

  RoomRepositoryHive(this._box, this._pendingBox, this._clientId);

  RoomModelHive _toHive(domain.RoomModel r) => RoomModelHive(
        id: r.id,
        name: r.name,
        iconId: r.iconId,
        color: r.color,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
        version: 0,
      );

  domain.RoomModel _toDomain(RoomModelHive r) => domain.RoomModel(
        id: r.id,
        name: r.name,
        iconId: r.iconId,
        color: r.color,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      );

  @override
  Future<List<domain.RoomModel>> getAllRooms() async {
    return _box.values.map(_toDomain).toList(growable: false);
  }

  @override
  Future<domain.RoomModel> createRoom(domain.RoomModel room) async {
    final id = room.id.isEmpty ? generateId() : room.id;
    final hive = _toHive(room.copyWith(id: id));
    await _box.put(id, hive);
    _enqueuePendingOp(
      entityId: hive.id,
      opType: 'create',
      payload: _roomToMap(hive),
    );
    _tryFlushPending();
    return _toDomain(hive);
  }

  @override
  Future<void> updateRoom(domain.RoomModel room) async {
    final existing = _box.get(room.id);
    if (existing == null) throw StateError('Room not found: ${room.id}');
    final updated = existing.copyWith(
      name: room.name,
      iconId: room.iconId,
      color: room.color,
      updatedAt: DateTime.now(),
      version: existing.version + 1,
    );
    await _box.put(room.id, updated);
    _enqueuePendingOp(
      entityId: updated.id,
      opType: 'update',
      payload: _roomToMap(updated),
    );
    _tryFlushPending();
  }

  @override
  Future<void> deleteRoom(String roomId) async {
    // Clean up any associated local files (e.g., icon image)
    final existing = _box.get(roomId);
    if (existing?.iconPath != null && existing!.iconPath!.isNotEmpty) {
      await FileStorage.deleteFile(existing.iconPath!);
    }
    await _box.delete(roomId);
    _enqueuePendingOp(
      entityId: roomId,
      opType: 'delete',
      payload: {'id': roomId},
    );
    _tryFlushPending();
  }

  @override
  Stream<List<domain.RoomModel>> watchRooms() async* {
    // Emit initial
    yield await getAllRooms();
    // Then on any box change, emit new list
    yield* _box.watch().map((_) => _box.values.map(_toDomain).toList(growable: false));
  }

  Map<String, dynamic> _roomToMap(RoomModelHive r) => {
        'id': r.id,
        'name': r.name,
        'iconId': r.iconId,
        'color': r.color,
        'createdAt': r.createdAt.toIso8601String(),
        'updatedAt': r.updatedAt.toIso8601String(),
        'version': r.version,
      };

  void _enqueuePendingOp({required String entityId, required String opType, required Map<String, dynamic> payload}) {
    final opId = 'op_${DateTime.now().millisecondsSinceEpoch}_$entityId';
    final mergedPayload = Map<String, dynamic>.from(payload);
    mergedPayload.putIfAbsent('operationId', () => opId);
    mergedPayload['clientId'] = _clientId;

    final op = PendingOp.forHomeAutomation(
      opId: opId,
      entityId: entityId,
      entityType: 'room',
      opType: opType,
      payload: mergedPayload,
    );
    _pendingBox.put(op.opId, op);
  }

  void _tryFlushPending() {
    // Placeholder for sync logic; a SyncService could observe _pendingBox.watch()
  }
}
