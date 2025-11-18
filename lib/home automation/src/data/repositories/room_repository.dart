import 'dart:async';
import '../models/room_model.dart';
import '../../core/utils/id_generator.dart';

abstract class RoomRepository {
  Future<List<RoomModel>> getAllRooms();
  Future<RoomModel> createRoom(RoomModel room);
  Future<void> updateRoom(RoomModel room);
  Future<void> deleteRoom(String roomId);
  Stream<List<RoomModel>> watchRooms();
}

class InMemoryRoomRepository implements RoomRepository {
  final List<RoomModel> _rooms = [
    RoomModel(id: '1', name: 'Living Room', iconId: 'sofa', color: 0xFF6C63FF),
    RoomModel(id: '2', name: 'Kitchen', iconId: 'utensils', color: 0xFF6C63FF),
    RoomModel(id: '3', name: 'Bedroom', iconId: 'bed', color: 0xFF6C63FF),
  ];

  final _controller = StreamController<List<RoomModel>>.broadcast();

  void _emit() => _controller.add(List.unmodifiable(_rooms));

  @override
  Future<List<RoomModel>> getAllRooms() async {
    await Future.delayed(const Duration(milliseconds: 120));
    return List.unmodifiable(_rooms);
  }

  @override
  Future<RoomModel> createRoom(RoomModel room) async {
    final newRoom = room.copyWith(id: generateId());
    _rooms.add(newRoom);
    _emit();
    return newRoom;
  }

  @override
  Future<void> updateRoom(RoomModel room) async {
    final index = _rooms.indexWhere((r) => r.id == room.id);
    if (index == -1) throw StateError('Room not found: ${room.id}');
    _rooms[index] = room.copyWith(updatedAt: DateTime.now());
    _emit();
  }

  @override
  Future<void> deleteRoom(String roomId) async {
    _rooms.removeWhere((r) => r.id == roomId);
    _emit();
  }

  @override
  Stream<List<RoomModel>> watchRooms() => _controller.stream;
}
