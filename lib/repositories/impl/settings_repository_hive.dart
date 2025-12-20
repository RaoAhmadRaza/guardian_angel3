/// SettingsRepositoryHive - Hive implementation of SettingsRepository.
///
/// Part of PHASE 2: Backend is the only source of truth.
/// Updated in PHASE 1 BLOCKER FIX: HiveError handling.
///
/// Data Flow:
/// UI → settingsProvider → SettingsRepositoryHive → BoxAccessor.settings() → Hive
library;

import 'package:hive/hive.dart';
import '../../models/settings_model.dart';
import '../../persistence/box_registry.dart';
import '../../persistence/errors/errors.dart';
import '../../persistence/wrappers/box_accessor.dart';
import '../settings_repository.dart';

/// Hive-backed implementation of SettingsRepository.
class SettingsRepositoryHive implements SettingsRepository {
  static const String _settingsKey = 'app_settings';
  final BoxAccessor _boxAccessor;

  SettingsRepositoryHive({BoxAccessor? boxAccessor})
      : _boxAccessor = boxAccessor ?? BoxAccessor();

  Box<SettingsModel> get _box => _boxAccessor.settings();

  SettingsModel get _defaultSettings => SettingsModel(
        notificationsEnabled: true,
        vitalsRetentionDays: 30,
        updatedAt: DateTime.now(),
        devToolsEnabled: false,
        userRole: 'patient',
      );

  @override
  Stream<SettingsModel> watchSettings() async* {
    // Emit current state immediately
    yield _getSettingsSync();
    // Then emit on every change
    yield* _box.watch(key: _settingsKey).map((_) => _getSettingsSync());
  }

  SettingsModel _getSettingsSync() {
    return _box.get(_settingsKey) ?? _defaultSettings;
  }

  @override
  Future<SettingsModel> getSettings() async {
    return _getSettingsSync();
  }

  @override
  Future<void> saveSettings(SettingsModel settings) async {
    // Validate before persisting
    settings.validate();
    // PHASE 1 BLOCKER FIX: Safe HiveError handling
    final result = await SafeBoxOps.put(
      _box,
      _settingsKey,
      settings,
      boxName: BoxRegistry.settingsBox,
    );
    if (result.isFailure) throw result.error!;
  }

  @override
  Future<void> updateNotificationsEnabled(bool enabled) async {
    final current = _getSettingsSync();
    await saveSettings(SettingsModel(
      notificationsEnabled: enabled,
      vitalsRetentionDays: current.vitalsRetentionDays,
      updatedAt: DateTime.now(),
      devToolsEnabled: current.devToolsEnabled,
      userRole: current.userRole,
    ));
  }

  @override
  Future<void> updateVitalsRetentionDays(int days) async {
    final current = _getSettingsSync();
    await saveSettings(SettingsModel(
      notificationsEnabled: current.notificationsEnabled,
      vitalsRetentionDays: days,
      updatedAt: DateTime.now(),
      devToolsEnabled: current.devToolsEnabled,
      userRole: current.userRole,
    ));
  }

  @override
  Future<void> updateDevToolsEnabled(bool enabled) async {
    final current = _getSettingsSync();
    await saveSettings(SettingsModel(
      notificationsEnabled: current.notificationsEnabled,
      vitalsRetentionDays: current.vitalsRetentionDays,
      updatedAt: DateTime.now(),
      devToolsEnabled: enabled,
      userRole: current.userRole,
    ));
  }

  @override
  Future<void> updateUserRole(String role) async {
    final current = _getSettingsSync();
    await saveSettings(SettingsModel(
      notificationsEnabled: current.notificationsEnabled,
      vitalsRetentionDays: current.vitalsRetentionDays,
      updatedAt: DateTime.now(),
      devToolsEnabled: current.devToolsEnabled,
      userRole: role,
    ));
  }

  @override
  Future<void> resetToDefaults() async {
    final result = await SafeBoxOps.delete(
      _box,
      _settingsKey,
      boxName: BoxRegistry.settingsBox,
    );
    if (result.isFailure) throw result.error!;
  }
}
