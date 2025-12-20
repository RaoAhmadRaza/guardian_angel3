import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/device_model.dart';
import '../../data/repositories/device_repository.dart';
import '../controllers/devices_controller.dart';
import 'room_providers.dart';
import 'hive_providers.dart';

/// Repository provider for devices.
/// 
/// PHASE 2: Backend is the only source of truth.
/// ❌ OLD: return InMemoryDeviceRepository();
/// ✅ NEW: return ref.watch(hiveDeviceRepositoryProvider);
final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  // Use Hive-backed repository - NO MORE IN-MEMORY!
  return ref.watch(hiveDeviceRepositoryProvider);
});

/// Family provider: each room gets its own devices controller.
final devicesControllerProvider = StateNotifierProvider.family<DevicesController, AsyncValue<List<DeviceModel>>, String>(
  (ref, roomId) {
    final repo = ref.watch(deviceRepositoryProvider);
    return DevicesController(ref, repo, roomId);
  },
);

/// Watch a single device changes via repository stream.
final deviceStreamProvider = StreamProvider.family<DeviceModel, String>((ref, deviceId) {
  final repo = ref.read(deviceRepositoryProvider);
  return repo.watchDevice(deviceId);
});

/// Aggregated list of all devices across all rooms (non-reactive for add/remove until rooms refresh).
final allDevicesProvider = Provider<List<DeviceModel>>((ref) {
  final roomsAsync = ref.watch(roomsControllerProvider);
  final rooms = roomsAsync.value ?? [];
  final List<DeviceModel> acc = [];
  for (final room in rooms) {
    final devicesAsync = ref.watch(devicesControllerProvider(room.id));
    final list = devicesAsync.value;
    if (list != null) acc.addAll(list);
  }
  return acc;
});
