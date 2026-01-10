/// EmergencyContactModel - Persistent emergency contact data model.
///
/// Used for SOS emergency contact notifications with Hive persistence.
library;

/// Type of emergency contact
enum EmergencyContactType {
  doctor,
  emergency,
  hospital,
  family,
  other,
}

/// Represents an emergency contact for SOS notifications.
class EmergencyContactModel {
  final String id;
  final String patientId;
  final String name;
  final String phoneNumber;
  final EmergencyContactType type;
  final int priority; // Lower number = higher priority
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EmergencyContactModel({
    required this.id,
    required this.patientId,
    required this.name,
    required this.phoneNumber,
    required this.type,
    this.priority = 0,
    this.isEnabled = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a new emergency contact with generated ID
  factory EmergencyContactModel.create({
    required String patientId,
    required String name,
    required String phoneNumber,
    required EmergencyContactType type,
    int priority = 0,
  }) {
    final now = DateTime.now().toUtc();
    return EmergencyContactModel(
      id: 'emerg_${now.millisecondsSinceEpoch}',
      patientId: patientId,
      name: name,
      phoneNumber: phoneNumber,
      type: type,
      priority: priority,
      isEnabled: true,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Get type display string
  String get typeDisplay {
    switch (type) {
      case EmergencyContactType.doctor:
        return 'Doctor';
      case EmergencyContactType.emergency:
        return 'Emergency';
      case EmergencyContactType.hospital:
        return 'Hospital';
      case EmergencyContactType.family:
        return 'Family';
      case EmergencyContactType.other:
        return 'Other';
    }
  }

  EmergencyContactModel copyWith({
    String? id,
    String? patientId,
    String? name,
    String? phoneNumber,
    EmergencyContactType? type,
    int? priority,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EmergencyContactModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'patientId': patientId,
    'name': name,
    'phoneNumber': phoneNumber,
    'type': type.name,
    'priority': priority,
    'isEnabled': isEnabled,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory EmergencyContactModel.fromJson(Map<String, dynamic> json) => EmergencyContactModel(
    id: json['id'] as String,
    patientId: json['patientId'] as String,
    name: json['name'] as String,
    phoneNumber: json['phoneNumber'] as String,
    type: EmergencyContactType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => EmergencyContactType.other,
    ),
    priority: json['priority'] as int? ?? 0,
    isEnabled: json['isEnabled'] as bool? ?? true,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmergencyContactModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
