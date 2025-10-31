/// Home Automation Data Models
/// Defines the structure for rooms, devices, and controls

enum DeviceType {
  light,
  fan,
  airConditioner,
  tv,
  router,
  thermostat,
  securitySystem,
}

enum DeviceStatus {
  on,
  off,
  idle,
  error,
}

enum RoomType {
  livingRoom,
  kitchen,
  bedRoom,
  bathRoom,
  guestRoom,
}

/// Base Device Model
class Device {
  final String id;
  final String name;
  final DeviceType type;
  final String roomId;
  DeviceStatus status;
  final Map<String, dynamic> properties;

  Device({
    required this.id,
    required this.name,
    required this.type,
    required this.roomId,
    this.status = DeviceStatus.off,
    this.properties = const {},
  });

  /// Toggle device on/off
  void togglePower() {
    status = status == DeviceStatus.on ? DeviceStatus.off : DeviceStatus.on;
  }

  /// Update device property
  void updateProperty(String key, dynamic value) {
    properties[key] = value;
  }

  /// Get device property
  T? getProperty<T>(String key) {
    return properties[key] as T?;
  }
}

/// Smart Light Device
class SmartLight extends Device {
  SmartLight({
    required String id,
    required String name,
    required String roomId,
    int brightness = 100,
  }) : super(
          id: id,
          name: name,
          type: DeviceType.light,
          roomId: roomId,
          properties: {'brightness': brightness},
        );

  int get brightness => getProperty<int>('brightness') ?? 100;
  set brightness(int value) => updateProperty('brightness', value);
}

/// Air Conditioner Device
class AirConditioner extends Device {
  AirConditioner({
    required String id,
    required String name,
    required String roomId,
    int temperature = 24,
    String mode = 'cool',
    int fanSpeed = 3,
  }) : super(
          id: id,
          name: name,
          type: DeviceType.airConditioner,
          roomId: roomId,
          properties: {
            'temperature': temperature,
            'mode': mode,
            'fanSpeed': fanSpeed,
          },
        );

  int get temperature => getProperty<int>('temperature') ?? 24;
  set temperature(int value) => updateProperty('temperature', value);

  String get mode => getProperty<String>('mode') ?? 'cool';
  set mode(String value) => updateProperty('mode', value);

  int get fanSpeed => getProperty<int>('fanSpeed') ?? 3;
  set fanSpeed(int value) => updateProperty('fanSpeed', value);
}

/// Ceiling Fan Device
class CeilingFan extends Device {
  CeilingFan({
    required String id,
    required String name,
    required String roomId,
    int speed = 0,
  }) : super(
          id: id,
          name: name,
          type: DeviceType.fan,
          roomId: roomId,
          properties: {'speed': speed},
        );

  int get speed => getProperty<int>('speed') ?? 0;
  set speed(int value) => updateProperty('speed', value);
}

/// Smart TV Device
class SmartTV extends Device {
  SmartTV({
    required String id,
    required String name,
    required String roomId,
    int volume = 50,
    String channel = '1',
  }) : super(
          id: id,
          name: name,
          type: DeviceType.tv,
          roomId: roomId,
          properties: {
            'volume': volume,
            'channel': channel,
          },
        );

  int get volume => getProperty<int>('volume') ?? 50;
  set volume(int value) => updateProperty('volume', value);

  String get channel => getProperty<String>('channel') ?? '1';
  set channel(String value) => updateProperty('channel', value);
}

/// Room Model
class Room {
  final String id;
  final String name;
  final RoomType type;
  final List<Device> devices;
  final String iconPath;
  final int colorCode;

  Room({
    required this.id,
    required this.name,
    required this.type,
    this.devices = const [],
    required this.iconPath,
    required this.colorCode,
  });

  /// Get devices by type
  List<Device> getDevicesByType(DeviceType type) {
    return devices.where((device) => device.type == type).toList();
  }

  /// Get device by ID
  Device? getDeviceById(String deviceId) {
    try {
      return devices.firstWhere((device) => device.id == deviceId);
    } catch (e) {
      return null;
    }
  }

  /// Get active devices count
  int get activeDevicesCount {
    return devices.where((device) => device.status == DeviceStatus.on).length;
  }

  /// Get total devices count
  int get totalDevicesCount => devices.length;
}

/// Home Model
class Home {
  final String id;
  final String name;
  final String ownerId;
  final List<Room> rooms;
  final Map<String, dynamic> globalSettings;

  Home({
    required this.id,
    required this.name,
    required this.ownerId,
    this.rooms = const [],
    this.globalSettings = const {},
  });

  /// Get room by ID
  Room? getRoomById(String roomId) {
    try {
      return rooms.firstWhere((room) => room.id == roomId);
    } catch (e) {
      return null;
    }
  }

  /// Get all devices across all rooms
  List<Device> get allDevices {
    return rooms.expand((room) => room.devices).toList();
  }

  /// Get device by ID across all rooms
  Device? getDeviceById(String deviceId) {
    for (Room room in rooms) {
      Device? device = room.getDeviceById(deviceId);
      if (device != null) return device;
    }
    return null;
  }

  /// Get total active devices
  int get totalActiveDevices {
    return allDevices
        .where((device) => device.status == DeviceStatus.on)
        .length;
  }

  /// Get energy consumption status
  String get energyStatus {
    int activeDevices = totalActiveDevices;
    if (activeDevices <= 2) return 'Low';
    if (activeDevices <= 5) return 'Medium';
    return 'High';
  }

  /// Get security status
  bool get isSecurityActivated {
    return globalSettings['securityActivated'] ?? false;
  }

  /// Get current temperature
  int get currentTemperature {
    return globalSettings['currentTemperature'] ?? 20;
  }
}
