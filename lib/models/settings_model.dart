/// Validation error for data integrity checks.
class SettingsValidationError implements Exception {
  final String message;
  SettingsValidationError(this.message);
  @override
  String toString() => 'SettingsValidationError: $message';
}

/// Valid roles for settings.
const validSettingsRoles = {'patient', 'caregiver', 'admin'};

class SettingsModel {
  final bool notificationsEnabled;
  final int vitalsRetentionDays;
  final DateTime updatedAt;
  final bool devToolsEnabled;
  final String userRole; // 'admin', 'caregiver', 'patient'

  const SettingsModel({
    required this.notificationsEnabled,
    required this.vitalsRetentionDays,
    required this.updatedAt,
    this.devToolsEnabled = false,
    this.userRole = 'patient',
  });

  /// Validates this settings model.
  /// Throws [SettingsValidationError] if invalid.
  /// Returns this instance for method chaining.
  SettingsModel validate() {
    if (vitalsRetentionDays < 1) {
      throw SettingsValidationError('vitalsRetentionDays must be at least 1');
    }
    if (vitalsRetentionDays > 365) {
      throw SettingsValidationError('vitalsRetentionDays cannot exceed 365');
    }
    if (!validSettingsRoles.contains(userRole)) {
      throw SettingsValidationError('userRole must be one of: ${validSettingsRoles.join(", ")}');
    }
    return this;
  }

  factory SettingsModel.fromJson(Map<String, dynamic> json) => SettingsModel(
        notificationsEnabled: json['notifications_enabled'] as bool? ?? true,
        vitalsRetentionDays: (json['vitals_retention_days'] as num?)?.toInt() ?? 30,
        updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
        devToolsEnabled: json['dev_tools_enabled'] as bool? ?? false,
        userRole: json['user_role'] as String? ?? 'patient',
      );

  Map<String, dynamic> toJson() => {
        'notifications_enabled': notificationsEnabled,
        'vitals_retention_days': vitalsRetentionDays,
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'dev_tools_enabled': devToolsEnabled,
        'user_role': userRole,
      };
}