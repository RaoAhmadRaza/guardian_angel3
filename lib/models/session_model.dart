/// Validation error for data integrity checks.
class SessionValidationError implements Exception {
  final String message;
  SessionValidationError(this.message);
  @override
  String toString() => 'SessionValidationError: $message';
}

class SessionModel {
  final String id;
  final String userId;
  final String authToken;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SessionModel({
    required this.id,
    required this.userId,
    required this.authToken,
    required this.issuedAt,
    required this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Validates this session model.
  /// Throws [SessionValidationError] if invalid.
  /// Returns this instance for method chaining.
  SessionModel validate() {
    if (id.isEmpty) {
      throw SessionValidationError('id cannot be empty');
    }
    if (userId.isEmpty) {
      throw SessionValidationError('userId cannot be empty');
    }
    if (authToken.isEmpty) {
      throw SessionValidationError('authToken cannot be empty');
    }
    if (expiresAt.isBefore(issuedAt)) {
      throw SessionValidationError('expiresAt must be after issuedAt');
    }
    if (updatedAt.isBefore(createdAt)) {
      throw SessionValidationError('updatedAt cannot be before createdAt');
    }
    return this;
  }

  /// Returns true if this session has expired.
  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);

  factory SessionModel.fromJson(Map<String, dynamic> json) => SessionModel(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        authToken: json['auth_token'] as String,
        issuedAt: DateTime.parse(json['issued_at'] as String).toUtc(),
        expiresAt: DateTime.parse(json['expires_at'] as String).toUtc(),
        createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
        updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'auth_token': authToken,
        'issued_at': issuedAt.toUtc().toIso8601String(),
        'expires_at': expiresAt.toUtc().toIso8601String(),
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };
}