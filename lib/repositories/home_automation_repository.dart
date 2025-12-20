/// HomeAutomationRepository - Abstract interface for home automation data access.
///
/// Part of PHASE 2: Backend is the only source of truth.
///
/// Data Flow:
/// UI → automationStateProvider → HomeAutomationRepository → BoxAccessor → Hive
library;

// Use the home automation domain models (which have copyWith, isOn, etc.)
import '../home automation/src/data/models/room_model.dart';
import '../home automation/src/data/models/device_model.dart';

// Re-export for convenience
export '../home automation/src/data/models/room_model.dart';
export '../home automation/src/data/models/device_model.dart';

/// Automation state summary for UI display.
class AutomationState {
  final int totalRooms;
  final int totalDevices;
  final int activeDevices;
  final double energyUsage; // kWh
  final bool isConnected;
  final DateTime? lastUpdated;

  const AutomationState({
    this.totalRooms = 0,
    this.totalDevices = 0,
    this.activeDevices = 0,
    this.energyUsage = 0.0,
    this.isConnected = true,
    this.lastUpdated,
  });

  double get activePercentage =>
      totalDevices > 0 ? (activeDevices / totalDevices) * 100 : 0;

  AutomationState copyWith({
    int? totalRooms,
    int? totalDevices,
    int? activeDevices,
    double? energyUsage,
    bool? isConnected,
    DateTime? lastUpdated,
  }) =>
      AutomationState(
        totalRooms: totalRooms ?? this.totalRooms,
        totalDevices: totalDevices ?? this.totalDevices,
        activeDevices: activeDevices ?? this.activeDevices,
        energyUsage: energyUsage ?? this.energyUsage,
        isConnected: isConnected ?? this.isConnected,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );
}

/// Abstract repository for home automation operations.
///
/// All automation state access MUST go through this interface.
abstract class HomeAutomationRepository {
  /// Watch automation state as a reactive stream.
  Stream<AutomationState> watchState();

  /// Get current automation state (one-time read).
  Future<AutomationState> getState();

  /// Watch all rooms.
  Stream<List<RoomModel>> watchRooms();

  /// Watch all devices.
  Stream<List<DeviceModel>> watchDevices();

  /// Watch devices for a specific room.
  Stream<List<DeviceModel>> watchDevicesForRoom(String roomId);

  /// Get all rooms.
  Future<List<RoomModel>> getRooms();

  /// Get all devices.
  Future<List<DeviceModel>> getDevices();

  /// Get devices for a room.
  Future<List<DeviceModel>> getDevicesForRoom(String roomId);

  /// Create a room.
  Future<RoomModel> createRoom(RoomModel room);

  /// Update a room.
  Future<void> updateRoom(RoomModel room);

  /// Delete a room.
  Future<void> deleteRoom(String roomId);

  /// Create a device.
  Future<DeviceModel> createDevice(DeviceModel device);

  /// Update a device.
  Future<void> updateDevice(DeviceModel device);

  /// Toggle a device.
  Future<void> toggleDevice(String deviceId, bool isOn);

  /// Delete a device.
  Future<void> deleteDevice(String deviceId);
}
