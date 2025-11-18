import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/room_model.dart';
import '../../data/repositories/room_repository.dart';

/// RoomsController manages the list of rooms with optimistic updates and stream sync.
class RoomsController extends StateNotifier<AsyncValue<List<RoomModel>>> {
  final Ref read;
  final RoomRepository repo;
  StreamSubscription<List<RoomModel>>? _sub;

  RoomsController(this.read, this.repo) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final rooms = await repo.getAllRooms();
      state = AsyncValue.data(rooms);
      // Live updates
      _sub = repo.watchRooms().listen((rooms) {
        state = AsyncValue.data(rooms);
      });
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async => _init();

  Future<void> addRoom(RoomModel room) async {
    final current = state.value ?? [];
    // Optimistic append (temporary id may be blank)
    state = AsyncValue.data([...current, room]);
    try {
      final created = await repo.createRoom(room);
      // Replace placeholder if id mismatch
      final list = (state.value ?? []).map((r) => r == room ? created : r).toList();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      await _init();
    }
  }

  Future<void> updateRoom(RoomModel room) async {
    final list = state.value ?? [];
    final idx = list.indexWhere((r) => r.id == room.id);
    if (idx == -1) return; // nothing to update
    final optimistic = [...list]..[idx] = room;
    state = AsyncValue.data(optimistic);
    try {
      await repo.updateRoom(room);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      await _init();
    }
  }

  Future<void> deleteRoom(String id) async {
    final list = state.value ?? [];
    final optimistic = list.where((r) => r.id != id).toList();
    state = AsyncValue.data(optimistic);
    try {
      await repo.deleteRoom(id);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      await _init();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
