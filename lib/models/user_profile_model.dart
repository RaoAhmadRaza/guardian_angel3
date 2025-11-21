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