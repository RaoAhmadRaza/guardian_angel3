/// CaregiverUserModel - Caregiver role assignment for local-first onboarding.
///
/// This table is written when user selects "Caregiver" role.
/// Contains only role assignment, NOT full details.
///
/// NO Firestore writes happen at this step.
library;

class CaregiverUserModel {
  /// Firebase UID - primary key
  final String uid;
  
  /// Role is always 'caregiver' for this table
  final String role;
  
  /// Timestamp when role was assigned
  final DateTime createdAt;
  
  /// Timestamp when this record was last updated
  final DateTime updatedAt;

  const CaregiverUserModel({
    required this.uid,
    this.role = 'caregiver',
    required this.createdAt,
    required this.updatedAt,
  });

  /// Validates this model.
  CaregiverUserModel validate() {
    if (uid.isEmpty) {
      throw ArgumentError('uid cannot be empty');
    }
    if (role != 'caregiver') {
      throw ArgumentError('role must be "caregiver"');
    }
    if (updatedAt.isBefore(createdAt)) {
      throw ArgumentError('updatedAt cannot be before createdAt');
    }
    return this;
  }

  CaregiverUserModel copyWith({
    String? uid,
    String? role,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CaregiverUserModel(
      uid: uid ?? this.uid,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'role': role,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  factory CaregiverUserModel.fromJson(Map<String, dynamic> json) => CaregiverUserModel(
    uid: json['uid'] as String,
    role: json['role'] as String? ?? 'caregiver',
    createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
    updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
  );

  @override
  String toString() => 'CaregiverUserModel(uid: $uid, role: $role)';
}
