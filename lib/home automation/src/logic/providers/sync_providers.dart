import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../sync/sync_models.dart';

/// Tracks in-flight device operations (e.g., toggles) per room.
final devicesPendingOpsProvider = StateProvider.family<Set<String>, String>(
  (ref, roomId) => <String>{},
  name: 'devicesPendingOpsProvider',
);

/// Room-level sync state for device operations.
final roomSyncStateProvider = StateProvider.family<SyncState, String>(
  (ref, roomId) => const SyncState(),
  name: 'roomSyncStateProvider',
);
