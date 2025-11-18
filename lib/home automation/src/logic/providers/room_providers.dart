import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/room_model.dart';
import '../../data/repositories/room_repository.dart';
import '../controllers/rooms_controller.dart';

/// Repository provider – swap implementation here (e.g. REST, Firebase later).
final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  return InMemoryRoomRepository();
});

/// RoomsController provider exposing AsyncValue<List<RoomModel>>.
final roomsControllerProvider = StateNotifierProvider<RoomsController, AsyncValue<List<RoomModel>>>(
  (ref) {
    final repo = ref.read(roomRepositoryProvider);
    return RoomsController(ref, repo);
  },
);

/// Convenience provider for just the list (null if loading/error).
final roomsListProvider = Provider<List<RoomModel>?>(
  (ref) => ref.watch(roomsControllerProvider).maybeWhen(
        data: (rooms) => rooms,
        orElse: () => null,
      ),
);
