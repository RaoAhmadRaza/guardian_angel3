import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/device_model.dart';

/// Currently selected room id in UI flows (e.g., navigating to Room Detail)
final selectedRoomIdProvider = StateProvider<String?>((ref) => null);

/// Optional: currently selected device id (e.g., device detail pane)
final selectedDeviceIdProvider = StateProvider<String?>((ref) => null);

/// Ephemeral editing buffer for devices of a given room.
/// Initialize this when opening an Edit Room screen with the room's current devices.
final editingDevicesProvider = StateProvider.family<List<DeviceModel>, String>(
  (ref, roomId) => <DeviceModel>[],
);
