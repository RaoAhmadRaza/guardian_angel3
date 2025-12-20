enum DeviceType { bulb, lamp, fan }

/// Validation error for DeviceModel data integrity checks.
class DeviceValidationError implements Exception {
  final String message;
  DeviceValidationError(this.message);
  @override
  String toString() => 'DeviceValidationError: $message';
}

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

  /// Validates this device model.
  /// Throws [DeviceValidationError] if invalid.
  /// Returns this instance for method chaining.
  DeviceModel validate() {
    if (id.isEmpty) {
      throw DeviceValidationError('id cannot be empty');
    }
    if (roomId.isEmpty) {
      throw DeviceValidationError('roomId cannot be empty');
    }
    if (name.isEmpty) {
      throw DeviceValidationError('name cannot be empty');
    }
    if (name.length > 50) {
      throw DeviceValidationError('name too long (max 50 characters)');
    }
    // Validate brightness if present
    if (state.containsKey('brightness')) {
      final brightness = state['brightness'];
      if (brightness is num && (brightness < 0 || brightness > 1)) {
        throw DeviceValidationError('brightness must be between 0 and 1');
      }
    }
    return this;
  }

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
