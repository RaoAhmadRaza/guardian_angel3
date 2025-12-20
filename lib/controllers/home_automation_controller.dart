/// Home Automation Navigation Controller
/// Manages navigation states and workflow for home automation
///
/// ⚠️ DEPRECATED: PHASE 3 - This controller uses the deprecated HomeAutomationService.
/// Use roomsControllerProvider and devicesControllerProvider from device_providers.dart.
/// The Hive repository is the ONLY authoritative source of truth.
///
/// ❌ THIS CLASS WILL THROW IF ANY METHOD IS CALLED.
/// All consumers must migrate to the Hive repository providers.

import '../models/home_automation_models.dart';
import '../services/home_automation_service.dart';

enum NavigationLevel {
  dashboard, // Level 1: Main dashboard with overview
  roomDetail, // Level 2: Room-specific device list
  deviceControl // Level 3: Individual device control
}

/// Exception thrown when deprecated HomeAutomationController is used.
class DeprecatedControllerError extends Error {
  final String message;
  DeprecatedControllerError(this.message);
  @override
  String toString() => 'DeprecatedControllerError: $message\n'
      'Use roomsControllerProvider/devicesControllerProvider from device_providers.dart instead.';
}

@Deprecated('PHASE 3: Use device_providers.dart with HomeAutomationRepositoryHive')
class HomeAutomationController {
  // ═══════════════════════════════════════════════════════════════════════
  // SINGLETON (DEPRECATED - Use Riverpod provider instead)
  // ═══════════════════════════════════════════════════════════════════════
  @Deprecated('Use homeAutomationControllerProvider from service_providers.dart instead')
  static HomeAutomationController? _instance;
  @Deprecated('Use homeAutomationControllerProvider from service_providers.dart instead')
  static HomeAutomationController get instance {
    throw DeprecatedControllerError('HomeAutomationController.instance is deprecated');
  }
  HomeAutomationController._internal() : _service = _throwService();

  static HomeAutomationService _throwService() {
    throw DeprecatedControllerError('HomeAutomationController is deprecated');
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PROPER DI CONSTRUCTOR (Use this via Riverpod)
  // ═══════════════════════════════════════════════════════════════════════
  /// Creates a new HomeAutomationController instance for dependency injection.
  HomeAutomationController({required HomeAutomationService service}) : _service = service {
    throw DeprecatedControllerError('HomeAutomationController is deprecated');
  }

  final HomeAutomationService _service;

  NavigationLevel _currentLevel = NavigationLevel.dashboard;
  List<NavigationLevel> _navigationHistory = [NavigationLevel.dashboard];

  /// Current navigation level
  NavigationLevel get currentLevel => throw DeprecatedControllerError('currentLevel is deprecated');

  /// Navigation history
  List<NavigationLevel> get navigationHistory => throw DeprecatedControllerError('navigationHistory is deprecated');

  /// Initialize the controller
  void initialize() {
    throw DeprecatedControllerError('initialize() is deprecated');
    print('🎮 Home Automation Controller initialized');
  }

  /// Navigation Methods

  /// Navigate to dashboard (Level 1)
  void goToDashboard() {
    _service.navigateToHome();
    _updateNavigationState(NavigationLevel.dashboard);
  }

  /// Navigate to room detail (Level 2)
  void goToRoom(String roomId) {
    _service.navigateToRoom(roomId);
    _updateNavigationState(NavigationLevel.roomDetail);
  }

  /// Navigate to device control (Level 3)
  void goToDevice(String deviceId) {
    _service.navigateToDevice(deviceId);
    _updateNavigationState(NavigationLevel.deviceControl);
  }

  /// Navigate back to previous level
  bool goBack() {
    switch (_currentLevel) {
      case NavigationLevel.deviceControl:
        // Go back to room detail
        _service.navigateBackToRoom();
        _updateNavigationState(NavigationLevel.roomDetail);
        return true;

      case NavigationLevel.roomDetail:
        // Go back to dashboard
        _service.navigateToHome();
        _updateNavigationState(NavigationLevel.dashboard);
        return true;

      case NavigationLevel.dashboard:
        // Already at top level
        return false;
    }
  }

  /// Update navigation state
  void _updateNavigationState(NavigationLevel newLevel) {
    _currentLevel = newLevel;
    _navigationHistory.add(newLevel);

    // Keep history to reasonable size
    if (_navigationHistory.length > 10) {
      _navigationHistory.removeAt(0);
    }

    print('📍 Navigation: ${_getLevelName(newLevel)}');
  }

  /// Get navigation level name
  String _getLevelName(NavigationLevel level) {
    switch (level) {
      case NavigationLevel.dashboard:
        return 'Dashboard';
      case NavigationLevel.roomDetail:
        return 'Room Detail';
      case NavigationLevel.deviceControl:
        return 'Device Control';
    }
  }

  /// Data Access Methods

  /// Get current screen data based on navigation level
  Map<String, dynamic> getCurrentScreenData() {
    switch (_currentLevel) {
      case NavigationLevel.dashboard:
        return getDashboardData();
      case NavigationLevel.roomDetail:
        return getRoomDetailData();
      case NavigationLevel.deviceControl:
        return getDeviceControlData();
    }
  }

  /// Get dashboard data (Level 1)
  Map<String, dynamic> getDashboardData() {
    Map<String, dynamic> summary = _service.getDashboardSummary();
    List<Room> rooms = _service.getRoomList();

    return {
      'level': 'dashboard',
      'title': 'Smart Home',
      'summary': summary,
      'rooms': rooms
          .map((room) => {
                'id': room.id,
                'name': room.name,
                'type': room.type.toString(),
                'iconPath': room.iconPath,
                'colorCode': room.colorCode,
                'activeDevices': room.activeDevicesCount,
                'totalDevices': room.totalDevicesCount,
              })
          .toList(),
      'quickActions': _getQuickActions(),
    };
  }

  /// Get room detail data (Level 2)
  Map<String, dynamic> getRoomDetailData() {
    Room? room = _service.selectedRoom;
    if (room == null) return {'error': 'No room selected'};

    return {
      'level': 'roomDetail',
      'title': room.name,
      'roomId': room.id,
      'roomType': room.type.toString(),
      'devices': room.devices
          .map((device) => {
                'id': device.id,
                'name': device.name,
                'type': device.type.toString(),
                'status': device.status.toString(),
                'properties': device.properties,
                'canControl': _canControlDevice(device),
              })
          .toList(),
      'roomStats': {
        'activeDevices': room.activeDevicesCount,
        'totalDevices': room.totalDevicesCount,
      },
    };
  }

  /// Get device control data (Level 3)
  Map<String, dynamic> getDeviceControlData() {
    Device? device = _service.selectedDevice;
    if (device == null) return {'error': 'No device selected'};

    Room? room = _service.selectedRoom;

    return {
      'level': 'deviceControl',
      'title': device.name,
      'deviceId': device.id,
      'deviceType': device.type.toString(),
      'status': device.status.toString(),
      'properties': device.properties,
      'roomName': room?.name ?? 'Unknown Room',
      'controls': _getDeviceControls(device),
      'capabilities': _getDeviceCapabilities(device),
    };
  }

  /// Get quick actions for dashboard
  List<Map<String, dynamic>> _getQuickActions() {
    return [
      {
        'id': 'all_lights_off',
        'name': 'All Lights Off',
        'icon': 'lightbulb_off',
        'action': 'turnOffAllLights',
      },
      {
        'id': 'security_toggle',
        'name': 'Toggle Security',
        'icon': 'security',
        'action': 'toggleSecurity',
      },
      {
        'id': 'climate_control',
        'name': 'Climate Control',
        'icon': 'thermostat',
        'action': 'openClimateControl',
      },
    ];
  }

  /// Check if device can be controlled
  bool _canControlDevice(Device device) {
    switch (device.type) {
      case DeviceType.light:
      case DeviceType.fan:
      case DeviceType.airConditioner:
      case DeviceType.tv:
        return true;
      case DeviceType.router:
      case DeviceType.thermostat:
      case DeviceType.securitySystem:
        return false;
    }
  }

  /// Get device-specific controls
  List<Map<String, dynamic>> _getDeviceControls(Device device) {
    switch (device.type) {
      case DeviceType.light:
        return [
          {'type': 'toggle', 'property': 'power', 'label': 'Power'},
          {
            'type': 'slider',
            'property': 'brightness',
            'label': 'Brightness',
            'min': 0,
            'max': 100
          },
        ];

      case DeviceType.fan:
        return [
          {'type': 'toggle', 'property': 'power', 'label': 'Power'},
          {
            'type': 'slider',
            'property': 'speed',
            'label': 'Speed',
            'min': 0,
            'max': 5
          },
        ];

      case DeviceType.airConditioner:
        return [
          {'type': 'toggle', 'property': 'power', 'label': 'Power'},
          {
            'type': 'temperature',
            'property': 'temperature',
            'label': 'Temperature',
            'min': 16,
            'max': 30
          },
          {
            'type': 'mode',
            'property': 'mode',
            'label': 'Mode',
            'options': ['cool', 'heat', 'fan']
          },
          {
            'type': 'slider',
            'property': 'fanSpeed',
            'label': 'Fan Speed',
            'min': 1,
            'max': 5
          },
        ];

      case DeviceType.tv:
        return [
          {'type': 'toggle', 'property': 'power', 'label': 'Power'},
          {
            'type': 'slider',
            'property': 'volume',
            'label': 'Volume',
            'min': 0,
            'max': 100
          },
          {'type': 'text', 'property': 'channel', 'label': 'Channel'},
        ];

      default:
        return [
          {'type': 'toggle', 'property': 'power', 'label': 'Power'},
        ];
    }
  }

  /// Get device capabilities
  List<String> _getDeviceCapabilities(Device device) {
    switch (device.type) {
      case DeviceType.light:
        return ['power_control', 'brightness_control', 'scheduling'];
      case DeviceType.fan:
        return ['power_control', 'speed_control', 'timer'];
      case DeviceType.airConditioner:
        return [
          'power_control',
          'temperature_control',
          'mode_control',
          'fan_speed',
          'timer',
          'scheduling'
        ];
      case DeviceType.tv:
        return [
          'power_control',
          'volume_control',
          'channel_control',
          'streaming'
        ];
      default:
        return ['power_control'];
    }
  }

  /// Control Methods (Delegated to Service)

  /// Toggle device power
  void toggleDevicePower(String deviceId) {
    _service.toggleDevicePower(deviceId);
  }

  /// Update device property
  void updateDeviceProperty(String deviceId, String property, dynamic value) {
    _service.updateDeviceProperty(deviceId, property, value);
  }

  /// Workflow Testing

  /// Test the complete navigation workflow
  void testNavigationWorkflow() {
    print('\n🧪 Testing Navigation Workflow...\n');

    // Start at dashboard
    print('1. 📊 Dashboard Level:');
    Map<String, dynamic> dashboardData = getCurrentScreenData();
    print('   Title: ${dashboardData['title']}');
    print('   Rooms: ${dashboardData['rooms']?.length ?? 0}');

    // Navigate to Living Room
    print('\n2. 🏠 Navigate to Living Room:');
    goToRoom('living_room');
    Map<String, dynamic> roomData = getCurrentScreenData();
    print('   Title: ${roomData['title']}');
    print('   Devices: ${roomData['devices']?.length ?? 0}');

    // Navigate to Air Conditioner
    print('\n3. ❄️ Navigate to Air Conditioner:');
    goToDevice('ac_living_1');
    Map<String, dynamic> deviceData = getCurrentScreenData();
    print('   Title: ${deviceData['title']}');
    print('   Type: ${deviceData['deviceType']}');
    print('   Controls: ${deviceData['controls']?.length ?? 0}');

    // Test navigation back
    print('\n4. ⬅️ Navigate Back to Room:');
    goBack();
    print('   Current Level: ${_getLevelName(_currentLevel)}');

    print('\n5. ⬅️ Navigate Back to Dashboard:');
    goBack();
    print('   Current Level: ${_getLevelName(_currentLevel)}');

    print('\n✅ Navigation workflow test completed!');
    print(
        '📊 Navigation History: ${_navigationHistory.map(_getLevelName).toList()}');
  }
}
