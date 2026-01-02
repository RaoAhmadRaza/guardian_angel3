/// DoctorUserModel - Doctor role assignment for local-first onboarding.
///
/// This table is written when user selects "Doctor" role.
/// Contains only role assignment, NOT full details.
///
/// NO Firestore writes happen at this step.
library;

class DoctorUserModel {
  /// Firebase UID - primary key
  final String uid;
  
  /// Role is always 'doctor' for this table
  final String role;
  
  /// Timestamp when role was assigned
  final DateTime createdAt;
  
  /// Timestamp when this record was last updated
  final DateTime updatedAt;

  const DoctorUserModel({
    required this.uid,
    this.role = 'doctor',
    required this.createdAt,
    required this.updatedAt,
  });

  /// Validates this model.
  DoctorUserModel validate() {
    if (uid.isEmpty) {
      throw ArgumentError('uid cannot be empty');
    }
    if (role != 'doctor') {
      throw ArgumentError('role must be "doctor"');
    }
    if (updatedAt.isBefore(createdAt)) {
      throw ArgumentError('updatedAt cannot be before createdAt');
    }
    return this;
  }

  DoctorUserModel copyWith({
    String? uid,
    String? role,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DoctorUserModel(
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

  factory DoctorUserModel.fromJson(Map<String, dynamic> json) => DoctorUserModel(
    uid: json['uid'] as String,
    role: json['role'] as String? ?? 'doctor',
    createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
    updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
  );

  @override
  String toString() => 'DoctorUserModel(uid: $uid, role: $role)';
}
