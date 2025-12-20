/// Validation error for data integrity checks.
class UserProfileValidationError implements Exception {
  final String message;
  UserProfileValidationError(this.message);
  @override
  String toString() => 'UserProfileValidationError: $message';
}

/// Valid roles for user profiles.
const validUserRoles = {'patient', 'caregiver', 'admin'};

class UserProfileModel {
  final String id;
  final String role; // patient, caregiver, admin
  final String displayName;
  final String? email;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfileModel({
    required this.id,
    required this.role,
    required this.displayName,
    this.email,
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
        createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
        updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'display_name': displayName,
        'email': email,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      }..removeWhere((k, v) => v == null);
}