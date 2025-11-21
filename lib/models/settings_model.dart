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