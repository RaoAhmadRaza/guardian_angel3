/// PatientUserModel - Patient role assignment for local-first onboarding.
///
/// This table is written when user selects "Patient" role.
/// Contains role assignment AND age (from age selection screen).
///
/// NO Firestore writes happen at this step.
library;

/// Minimum allowed age for patients
const int minPatientAge = 60;

class PatientUserModel {
  /// Firebase UID - primary key
  final String uid;
  
  /// Role is always 'patient' for this table
  final String role;
  
  /// Patient's age (must be >= 60)
  final int age;
  
  /// Timestamp when role was assigned
  final DateTime createdAt;
  
  /// Timestamp when this record was last updated
  final DateTime updatedAt;

  const PatientUserModel({
    required this.uid,
    this.role = 'patient',
    required this.age,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Validates this model.
  PatientUserModel validate() {
    if (uid.isEmpty) {
      throw ArgumentError('uid cannot be empty');
    }
    if (role != 'patient') {
      throw ArgumentError('role must be "patient"');
    }
    if (age < minPatientAge) {
      throw ArgumentError('age must be at least $minPatientAge');
    }
    if (age > 150) {
      throw ArgumentError('age must be at most 150');
    }
    if (updatedAt.isBefore(createdAt)) {
      throw ArgumentError('updatedAt cannot be before createdAt');
    }
    return this;
  }

  PatientUserModel copyWith({
    String? uid,
    String? role,
    int? age,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PatientUserModel(
      uid: uid ?? this.uid,
      role: role ?? this.role,
      age: age ?? this.age,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'role': role,
    'age': age,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  factory PatientUserModel.fromJson(Map<String, dynamic> json) => PatientUserModel(
    uid: json['uid'] as String,
    role: json['role'] as String? ?? 'patient',
    age: json['age'] as int,
    createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
    updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
  );

  @override
  String toString() => 'PatientUserModel(uid: $uid, role: $role, age: $age)';
}
