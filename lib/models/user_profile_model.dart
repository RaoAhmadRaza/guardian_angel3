/// Validation error for data integrity checks.
class UserProfileValidationError implements Exception {
  final String message;
  UserProfileValidationError(this.message);
  @override
  String toString() => 'UserProfileValidationError: $message';
}

/// Valid roles for user profiles.
const validUserRoles = {'patient', 'caregiver', 'admin', 'doctor'};

/// Valid gender values for user profiles.
const validGenders = {'male', 'female', 'other', 'prefer_not_to_say'};

class UserProfileModel {
  final String id;
  final String role; // patient, caregiver, admin
  final String displayName;
  final String? email;
  final String? gender; // male, female, other, prefer_not_to_say
  final int? age;
  final String? address;
  final String? medicalHistory;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfileModel({
    required this.id,
    required this.role,
    required this.displayName,
    this.email,
    this.gender,
    this.age,
    this.address,
    this.medicalHistory,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Validates this user profile model.
  /// Throws [UserProfileValidationError] if invalid.
  /// Returns this instance for method chaining.
  UserProfileModel validate() {
    if (id.isEmpty) {
      throw UserProfileValidationError('id cannot be empty');
    }
    if (role.isEmpty) {
      throw UserProfileValidationError('role cannot be empty');
    }
    if (!validUserRoles.contains(role)) {
      throw UserProfileValidationError('role must be one of: ${validUserRoles.join(", ")}');
    }
    if (displayName.isEmpty) {
      throw UserProfileValidationError('displayName cannot be empty');
    }
    if (displayName.length > 100) {
      throw UserProfileValidationError('displayName too long (max 100 characters)');
    }
    if (email != null && email!.isNotEmpty && !email!.contains('@')) {
      throw UserProfileValidationError('email format invalid');
    }
    if (gender != null && gender!.isNotEmpty && !validGenders.contains(gender)) {
      throw UserProfileValidationError('gender must be one of: ${validGenders.join(", ")}');
    }
    if (age != null && (age! < 0 || age! > 150)) {
      throw UserProfileValidationError('age must be between 0 and 150');
    }
    if (address != null && address!.length > 500) {
      throw UserProfileValidationError('address too long (max 500 characters)');
    }
    if (medicalHistory != null && medicalHistory!.length > 5000) {
      throw UserProfileValidationError('medicalHistory too long (max 5000 characters)');
    }
    if (updatedAt.isBefore(createdAt)) {
      throw UserProfileValidationError('updatedAt cannot be before createdAt');
    }
    return this;
  }

  factory UserProfileModel.fromJson(Map<String, dynamic> json) => UserProfileModel(
        id: json['id'] as String,
        role: json['role'] as String,
        displayName: json['display_name'] as String,
        email: json['email'] as String?,
        gender: json['gender'] as String?,
        age: json['age'] as int?,
        address: json['address'] as String?,
        medicalHistory: json['medical_history'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
        updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'display_name': displayName,
        'email': email,
        'gender': gender,
        'age': age,
        'address': address,
        'medical_history': medicalHistory,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      }..removeWhere((k, v) => v == null);
  
  /// Creates a copy of this model with the given fields replaced.
  UserProfileModel copyWith({
    String? id,
    String? role,
    String? displayName,
    String? email,
    String? gender,
    int? age,
    String? address,
    String? medicalHistory,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfileModel(
      id: id ?? this.id,
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      address: address ?? this.address,
      medicalHistory: medicalHistory ?? this.medicalHistory,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}