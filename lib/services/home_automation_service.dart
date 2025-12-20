/// Home Automation Service
/// Manages the business logic for home automation features
///
/// ⚠️ DEPRECATED: PHASE 3 - This service uses hardcoded sample data.
/// Use [HomeAutomationRepositoryHive] via providers instead:
/// - roomsControllerProvider → for rooms
/// - devicesControllerProvider(roomId) → for devices
/// The Hive repository is the ONLY authoritative source of truth.
///
/// ❌ THIS CLASS WILL THROW IF ANY METHOD IS CALLED.
/// All consumers must migrate to the Hive repository.

import '../models/home_automation_models.dart';

/// Exception thrown when deprecated HomeAutomationService is used.
class DeprecatedServiceError extends Error {
  final String message;
  DeprecatedServiceError(this.message);
  @override
  String toString() => 'DeprecatedServiceError: $message\n'
      'Use HomeAutomationRepositoryHive via roomsControllerProvider/devicesControllerProvider instead.';
}

@Deprecated('PHASE 3: Use HomeAutomationRepositoryHive via domain_providers.dart')
class HomeAutomationService {
  // ═══════════════════════════════════════════════════════════════════════
  // SINGLETON (DEPRECATED - Use Riverpod provider instead)
  // ═══════════════════════════════════════════════════════════════════════
  @Deprecated('Use homeAutomationServiceProvider from service_providers.dart instead')
  static HomeAutomationService? _instance;
  @Deprecated('Use homeAutomationServiceProvider from service_providers.dart instead')
  static HomeAutomationService get instance {
    throw DeprecatedServiceError('HomeAutomationService.instance is deprecated');
  }
  HomeAutomationService._internal() {
    throw DeprecatedServiceError('HomeAutomationService is deprecated');
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PROPER DI CONSTRUCTOR (Use this via Riverpod)
  // ═══════════════════════════════════════════════════════════════════════
  /// Creates a new HomeAutomationService instance for dependency injection.
  HomeAutomationService() {
    throw DeprecatedServiceError('HomeAutomationService is deprecated');
  }

  Home? _currentHome;
  String? _selectedRoomId;
  String? _selectedDeviceId;

  /// Initialize with sample data
  void initialize() {
    throw DeprecatedServiceError('initialize() is deprecated');
  }

  /// Get current home
  Home? get currentHome => throw DeprecatedServiceError('currentHome is deprecated');

  /// Get selected room ID
  String? get selectedRoomId => throw DeprecatedServiceError('selectedRoomId is deprecated');

  /// Get selected device ID
  String? get selectedDeviceId => throw DeprecatedServiceError('selectedDeviceId is deprecated');

  /// Get selected room
  Room? get selectedRoom {
    if (_selectedRoomId == null || _currentHome == null) return null;
    return _currentHome!.getRoomById(_selectedRoomId!);
  }

  /// Get selected device
  Device? get selectedDevice {
    if (_selectedDeviceId == null || _currentHome == null) return null;
    return _currentHome!.getDeviceById(_selectedDeviceId!);
  }

  /// Navigation Methods

  /// Navigate to room selection (Level 1 → Level 2)
  void navigateToRoom(String roomId) {
    _selectedRoomId = roomId;
    _selectedDeviceId = null; // Reset device selection
    print('🏠 Navigated to room: ${selectedRoom?.name}');
  }

  /// Navigate to device control (Level 2 → Level 3)
  void navigateToDevice(String deviceId) {
    _selectedDeviceId = deviceId;
    Device? device = selectedDevice;
    if (device != null) {
      print('🔧 Navigated to device: ${device.name} (${device.type})');
    }
  }

  /// Navigate back to home dashboard (Level 2/3 → Level 1)
  void navigateToHome() {
    _selectedRoomId = null;
    _selectedDeviceId = null;
    print('🏡 Navigated back to home dashboard');
  }

  /// Navigate back to room (Level 3 → Level 2)
  void navigateBackToRoom() {
    _selectedDeviceId = null;
    print('🏠 Navigated back to room: ${selectedRoom?.name}');
  }

  /// Device Control Methods

  /// Toggle device power
  void toggleDevicePower(String deviceId) {
    Device? device = _currentHome?.getDeviceById(deviceId);
    if (device != null) {
      device.togglePower();
      print(
          '⚡ ${device.name} turned ${device.status == DeviceStatus.on ? 'ON' : 'OFF'}');
    }
  }

  /// Update device property
  void updateDeviceProperty(String deviceId, String property, dynamic value) {
    Device? device = _currentHome?.getDeviceById(deviceId);
    if (device != null) {
      device.updateProperty(property, value);
      print('🔧 ${device.name} $property updated to: $value');
    }
  }

  /// Smart Light Controls
  void adjustLightBrightness(String deviceId, int brightness) {
    Device? device = _currentHome?.getDeviceById(deviceId);
    if (device is SmartLight) {
      device.brightness = brightness;
      print('💡 ${device.name} brightness set to: $brightness%');
    }
  }

  /// Air Conditioner Controls
  void adjustACTemperature(String deviceId, int temperature) {
    Device? device = _currentHome?.getDeviceById(deviceId);
    if (device is AirConditioner) {
      device.temperature = temperature;
      print('❄️ ${device.name} temperature set to: ${temperature}°C');
    }
  }

  void changeACMode(String deviceId, String mode) {
    Device? device = _currentHome?.getDeviceById(deviceId);
    if (device is AirConditioner) {
      device.mode = mode;
      print('❄️ ${device.name} mode changed to: $mode');
    }
  }

  void adjustACFanSpeed(String deviceId, int speed) {
    Device? device = _currentHome?.getDeviceById(deviceId);
    if (device is AirConditioner) {
      device.fanSpeed = speed;
      print('🌪️ ${device.name} fan speed set to: $speed');
    }
  }

  /// Fan Controls
  void adjustFanSpeed(String deviceId, int speed) {
    Device? device = _currentHome?.getDeviceById(deviceId);
    if (device is CeilingFan) {
      device.speed = speed;
      print('🌪️ ${device.name} speed set to: $speed');
    }
  }

  /// TV Controls
  void adjustTVVolume(String deviceId, int volume) {
    Device? device = _currentHome?.getDeviceById(deviceId);
    if (device is SmartTV) {
      device.volume = volume;
      print('📺 ${device.name} volume set to: $volume');
    }
  }

  void changeTVChannel(String deviceId, String channel) {
    Device? device = _currentHome?.getDeviceById(deviceId);
    if (device is SmartTV) {
      device.channel = channel;
      print('📺 ${device.name} channel changed to: $channel');
    }
  }

  /// Data Retrieval Methods

  /// Get dashboard summary
  Map<String, dynamic> getDashboardSummary() {
    if (_currentHome == null) return {};

    return {
      'temperature': _currentHome!.currentTemperature,
      'lightsOn': _currentHome!.allDevices
          .where(
              (d) => d.type == DeviceType.light && d.status == DeviceStatus.on)
          .length,
      'energyStatus': _currentHome!.energyStatus,
      'securityActivated': _currentHome!.isSecurityActivated,
      'totalRooms': _currentHome!.rooms.length,
      'totalDevices': _currentHome!.allDevices.length,
      'activeDevices': _currentHome!.totalActiveDevices,
    };
  }

  /// Get room list for navigation
  List<Room> getRoomList() {
    return _currentHome?.rooms ?? [];
  }

  /// Get device list for selected room
  List<Device> getDeviceListForRoom(String roomId) {
    Room? room = _currentHome?.getRoomById(roomId);
    return room?.devices ?? [];
  }

  /// Create sample home data
  Home _createSampleHome() {
    // Create devices for Living Room
    List<Device> livingRoomDevices = [
      SmartLight(
        id: 'light_living_1',
        name: 'Smart Light',
        roomId: 'living_room',
        brightness: 80,
      ),
      CeilingFan(
        id: 'fan_living_1',
        name: 'Ceiling Fan',
        roomId: 'living_room',
        speed: 2,
      ),
      AirConditioner(
        id: 'ac_living_1',
        name: 'Air Conditioner',
        roomId: 'living_room',
        temperature: 22,
        mode: 'cool',
        fanSpeed: 3,
      ),
      Device(
        id: 'router_living_1',
        name: 'WiFi Router',
        type: DeviceType.router,
        roomId: 'living_room',
        status: DeviceStatus.on,
      ),
      SmartTV(
        id: 'tv_living_1',
        name: 'Smart TV',
        roomId: 'living_room',
        volume: 45,
        channel: 'Netflix',
      ),
    ];

    // Create devices for Kitchen
    List<Device> kitchenDevices = [
      SmartLight(
        id: 'light_kitchen_1',
        name: 'Kitchen Light',
        roomId: 'kitchen',
        brightness: 100,
      ),
      Device(
        id: 'exhaust_kitchen_1',
        name: 'Exhaust Fan',
        type: DeviceType.fan,
        roomId: 'kitchen',
        status: DeviceStatus.off,
      ),
    ];

    // Create devices for Bedroom
    List<Device> bedroomDevices = [
      SmartLight(
        id: 'light_bedroom_1',
        name: 'Bedroom Light',
        roomId: 'bedroom',
        brightness: 60,
      ),
      AirConditioner(
        id: 'ac_bedroom_1',
        name: 'Bedroom AC',
        roomId: 'bedroom',
        temperature: 24,
        mode: 'cool',
        fanSpeed: 2,
      ),
    ];

    // Create devices for Bathroom
    List<Device> bathroomDevices = [
      SmartLight(
        id: 'light_bathroom_1',
        name: 'Bathroom Light',
        roomId: 'bathroom',
        brightness: 90,
      ),
    ];

    // Create devices for Guest Room
    List<Device> guestRoomDevices = [
      SmartLight(
        id: 'light_guest_1',
        name: 'Guest Light',
        roomId: 'guest_room',
        brightness: 70,
      ),
    ];

    // Create rooms
    List<Room> rooms = [
      Room(
        id: 'living_room',
        name: 'Living Room',
        type: RoomType.livingRoom,
        devices: livingRoomDevices,
        iconPath: 'assets/icons/sofa.png',
        colorCode: 0xFF3B82F6, // Blue
      ),
      Room(
        id: 'kitchen',
        name: 'Kitchen',
        type: RoomType.kitchen,
        devices: kitchenDevices,
        iconPath: 'assets/icons/utensils.png',
        colorCode: 0xFFE97B47, // Orange
      ),
      Room(
        id: 'bedroom',
        name: 'Bed Room',
        type: RoomType.bedRoom,
        devices: bedroomDevices,
        iconPath: 'assets/icons/bed.png',
        colorCode: 0xFF6366F1, // Purple
      ),
      Room(
        id: 'bathroom',
        name: 'Bath Room',
        type: RoomType.bathRoom,
        devices: bathroomDevices,
        iconPath: 'assets/icons/bath.png',
        colorCode: 0xFF10B981, // Green
      ),
      Room(
        id: 'guest_room',
        name: 'Guest Room',
        type: RoomType.guestRoom,
        devices: guestRoomDevices,
        iconPath: 'assets/icons/guest.png',
        colorCode: 0xFF8B5CF6, // Violet
      ),
    ];

    return Home(
      id: 'home_1',
      name: 'Smart Home',
      ownerId: 'user_alex',
      rooms: rooms,
      globalSettings: {
        'currentTemperature': 20,
        'securityActivated': true,
      },
    );
  }

  /// Workflow Testing Methods

  /// Test complete workflow
  void testWorkflow() {
    print('\n🚀 Testing Home Automation Workflow...\n');

    // Level 1: Dashboard
    print('📊 Dashboard Summary:');
    Map<String, dynamic> dashboard = getDashboardSummary();
    dashboard.forEach((key, value) {
      print('  $key: $value');
    });

    // Level 2: Navigate to Living Room
    print('\n🏠 Navigating to Living Room...');
    navigateToRoom('living_room');

    List<Device> livingRoomDevices = getDeviceListForRoom('living_room');
    print('Devices in Living Room:');
    for (Device device in livingRoomDevices) {
      print('  - ${device.name} (${device.type}) - ${device.status}');
    }

    // Level 3: Navigate to Air Conditioner
    print('\n❄️ Navigating to Air Conditioner...');
    navigateToDevice('ac_living_1');

    // Control the device
    print('\n🔧 Controlling Air Conditioner:');
    adjustACTemperature('ac_living_1', 24);
    changeACMode('ac_living_1', 'heat');
    adjustACFanSpeed('ac_living_1', 4);

    // Navigate back
    print('\n⬅️ Navigating back to room...');
    navigateBackToRoom();

    print('\n⬅️ Navigating back to home...');
    navigateToHome();

    print('\n✅ Workflow test completed!');
  }
}
