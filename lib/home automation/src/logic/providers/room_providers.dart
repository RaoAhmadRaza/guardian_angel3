import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/room_model.dart';
import '../../data/repositories/room_repository.dart';
import '../controllers/rooms_controller.dart';
import 'hive_providers.dart';

/// Repository provider – NOW USES HIVE-BACKED REPOSITORY.
/// 
/// PHASE 2: Backend is the only source of truth.
/// ❌ OLD: return InMemoryRoomRepository();
/// ✅ NEW: return ref.watch(hiveRoomRepositoryProvider);
final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  // Use Hive-backed repository - NO MORE IN-MEMORY!
  return ref.watch(hiveRoomRepositoryProvider);
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
