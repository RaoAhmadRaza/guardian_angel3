/// UserBaseModel - Auth basics for local-first onboarding.
///
/// This is the FIRST table written after authentication success.
/// Contains only auth-provided data: email, fullName, profileImageUrl.
///
/// NO role assignment happens here.
/// NO Firestore writes happen at this step.
library;

class UserBaseModel {
  /// Firebase UID - primary key
  final String uid;
  
  /// Email from auth provider (may be null for phone auth)
  final String? email;
  
  /// Full name from auth provider
  final String? fullName;
  
  /// Profile image URL from auth provider
  final String? profileImageUrl;
  
  /// Timestamp when this record was created
  final DateTime createdAt;
  
  /// Timestamp when this record was last updated
  final DateTime updatedAt;

  const UserBaseModel({
    required this.uid,
    this.email,
    this.fullName,
    this.profileImageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Validates this model.
  /// Throws [ArgumentError] if invalid.
  UserBaseModel validate() {
    if (uid.isEmpty) {
      throw ArgumentError('uid cannot be empty');
    }
    if (updatedAt.isBefore(createdAt)) {
      throw ArgumentError('updatedAt cannot be before createdAt');
    }
    return this;
  }

  /// Creates a copy with updated fields.
  UserBaseModel copyWith({
    String? uid,
    String? email,
    String? fullName,
    String? profileImageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserBaseModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'email': email,
    'full_name': fullName,
    'profile_image_url': profileImageUrl,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  }..removeWhere((k, v) => v == null);

  factory UserBaseModel.fromJson(Map<String, dynamic> json) => UserBaseModel(
    uid: json['uid'] as String,
    email: json['email'] as String?,
    fullName: json['full_name'] as String?,
    profileImageUrl: json['profile_image_url'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
    updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
  );

  @override
  String toString() => 'UserBaseModel(uid: $uid, email: $email, fullName: $fullName)';
}
