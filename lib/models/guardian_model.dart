/// GuardianModel - Persistent guardian contact data model.
///
/// Used for tracking patient's guardians with Hive persistence.
library;

/// Status of guardian relationship
enum GuardianStatus {
  active,
  pending,
  inactive,
}

/// Represents a guardian relationship for a patient.
class GuardianModel {
  final String id;
  final String patientId;
  final String name;
  final String relation; // 'Daughter', 'Son', 'Spouse', 'Friend', etc.
  final String phoneNumber;
  final String? email;
  final GuardianStatus status;
  final bool isPrimary;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GuardianModel({
    required this.id,
    required this.patientId,
    required this.name,
    required this.relation,
    required this.phoneNumber,
    this.email,
    this.status = GuardianStatus.pending,
    this.isPrimary = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a new guardian with generated ID
  factory GuardianModel.create({
    required String patientId,
    required String name,
    required String relation,
    required String phoneNumber,
    String? email,
    bool isPrimary = false,
  }) {
    final now = DateTime.now().toUtc();
    return GuardianModel(
      id: 'guard_${now.millisecondsSinceEpoch}',
      patientId: patientId,
      name: name,
      relation: relation,
      phoneNumber: phoneNumber,
      email: email,
      status: GuardianStatus.pending,
      isPrimary: isPrimary,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Get status display string
  String get statusDisplay {
    switch (status) {
      case GuardianStatus.active:
        return 'Active';
      case GuardianStatus.pending:
        return 'Pending';
      case GuardianStatus.inactive:
        return 'Inactive';
    }
  }

  /// Get initials for avatar
  String get initials {
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }

  GuardianModel copyWith({
    String? id,
    String? patientId,
    String? name,
    String? relation,
    String? phoneNumber,
    String? email,
    GuardianStatus? status,
    bool? isPrimary,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GuardianModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      name: name ?? this.name,
      relation: relation ?? this.relation,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      status: status ?? this.status,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'patientId': patientId,
    'name': name,
    'relation': relation,
    'phoneNumber': phoneNumber,
    'email': email,
    'status': status.name,
    'isPrimary': isPrimary,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory GuardianModel.fromJson(Map<String, dynamic> json) => GuardianModel(
    id: json['id'] as String,
    patientId: json['patientId'] as String,
    name: json['name'] as String,
    relation: json['relation'] as String,
    phoneNumber: json['phoneNumber'] as String,
    email: json['email'] as String?,
    status: GuardianStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => GuardianStatus.pending,
    ),
    isPrimary: json['isPrimary'] as bool? ?? false,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GuardianModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
