import 'package:hive/hive.dart';

part 'device_model_hive.g.dart';

/// Box name for devices
const kDevicesBoxName = 'devices_box';

@HiveType(typeId: 1)
class DeviceModelHive {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String roomId;

  @HiveField(2)
  final String type; // e.g. 'bulb', 'lamp', 'fan'

  @HiveField(3)
  final String name;

  @HiveField(4)
  final bool isOn;

  @HiveField(5)
  final Map<String, dynamic> state;

  @HiveField(6)
  final DateTime lastSeen;

  @HiveField(7)
  final DateTime updatedAt;

  @HiveField(8)
  final int version;

  DeviceModelHive({
    required this.id,
    required this.roomId,
    required this.type,
    required this.name,
    this.isOn = false,
    Map<String, dynamic>? state,
    DateTime? lastSeen,
    DateTime? updatedAt,
    this.version = 0,
  })  : state = state ?? <String, dynamic>{},
        lastSeen = lastSeen ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  DeviceModelHive copyWith({
    bool? isOn,
    Map<String, dynamic>? state,
    DateTime? lastSeen,
    DateTime? updatedAt,
    int? version,
    String? name,
  }) {
    return DeviceModelHive(
      id: id,
      roomId: roomId,
      type: type,
      name: name ?? this.name,
      isOn: isOn ?? this.isOn,
      state: state ?? this.state,
      lastSeen: lastSeen ?? this.lastSeen,
      updatedAt: updatedAt ?? DateTime.now(),
      version: version ?? this.version,
    );
  }
}
