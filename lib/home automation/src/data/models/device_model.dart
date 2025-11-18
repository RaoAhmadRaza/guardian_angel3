enum DeviceType { bulb, lamp, fan }

class DeviceModel {
  final String id;
  final String roomId;
  final DeviceType type;
  final String name;
  final bool isOn;
  final Map<String, dynamic> state; // e.g. {'brightness': 0.8}
  final DateTime lastSeen;

  DeviceModel({
    required this.id,
    required this.roomId,
    required this.type,
    required this.name,
    this.isOn = false,
    this.state = const {},
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();

  DeviceModel copyWith({
    bool? isOn,
    Map<String, dynamic>? state,
    DateTime? lastSeen,
    String? name,
  }) => DeviceModel(
        id: id,
        roomId: roomId,
        type: type,
        name: name ?? this.name,
        isOn: isOn ?? this.isOn,
        state: state ?? this.state,
        lastSeen: lastSeen ?? this.lastSeen,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'roomId': roomId,
        'type': type.toString(),
        'name': name,
        'isOn': isOn,
        'state': state,
        'lastSeen': lastSeen.toIso8601String(),
      };

  static DeviceModel fromMap(Map<String, dynamic> m) => DeviceModel(
        id: m['id'] as String,
        roomId: m['roomId'] as String,
        type: _deviceTypeFromString(m['type'] as String),
        name: m['name'] as String,
        isOn: m['isOn'] as bool? ?? false,
        state: (m['state'] as Map<String, dynamic>?) ?? const {},
        lastSeen: DateTime.parse(m['lastSeen'] as String),
      );

  static DeviceType _deviceTypeFromString(String raw) {
    return DeviceType.values.firstWhere(
      (e) => e.toString() == raw,
      orElse: () => DeviceType.bulb,
    );
  }
}
