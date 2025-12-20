/// SettingsRepository - Abstract interface for settings data access.
///
/// Part of PHASE 2: Backend is the only source of truth.
///
/// Data Flow:
/// UI → settingsProvider → SettingsRepository → BoxAccessor.settings() → Hive
library;

import '../../../models/settings_model.dart';

/// Abstract repository for settings operations.
///
/// All settings access MUST go through this interface.
abstract class SettingsRepository {
  /// Watch settings as a reactive stream.
  Stream<SettingsModel> watchSettings();

  /// Get current settings (one-time read).
  Future<SettingsModel> getSettings();

  /// Save settings.
  Future<void> saveSettings(SettingsModel settings);

  /// Update a single setting field.
  Future<void> updateNotificationsEnabled(bool enabled);

  /// Update vitals retention days.
  Future<void> updateVitalsRetentionDays(int days);

  /// Update dev tools enabled flag.
  Future<void> updateDevToolsEnabled(bool enabled);

  /// Update user role.
  Future<void> updateUserRole(String role);

  /// Reset settings to defaults.
  Future<void> resetToDefaults();
}
