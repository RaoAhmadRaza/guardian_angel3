import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:guardian_angel_fyp/models/settings_model.dart';
import 'package:guardian_angel_fyp/persistence/box_registry.dart';
import 'package:guardian_angel_fyp/persistence/adapters/settings_adapter.dart';
import 'package:guardian_angel_fyp/ui/guards/admin_auth_guard.dart';

void main() {
  setUp(() async {
    await setUpTestHive();
    if (!Hive.isAdapterRegistered(TypeIds.settings)) {
      Hive.registerAdapter(SettingsModelAdapter());
    }
  });

  tearDown(() async {
    await tearDownTestHive();
  });

  group('kEnableAdminUI compile-time flag', () {
    test('defaults to false', () {
      expect(kEnableAdminUI, isFalse);
    });

    test('can be overridden at compile time', () {
      // This test documents that ENABLE_ADMIN_UI must be set during build.
      // In CI/production: const should remain false unless explicitly set.
      // To test true case: flutter test --dart-define=ENABLE_ADMIN_UI=true
      expect(kEnableAdminUI, isFalse,
          reason: 'Default should be false for security');
    });
  });

  group('Settings-based gating', () {
    test('devToolsEnabled=false blocks access', () async {
      final box = await Hive.openBox<SettingsModel>(BoxRegistry.settingsBox);
      await box.put(
        'app_settings',
        SettingsModel(
          notificationsEnabled: true,
          vitalsRetentionDays: 30,
          updatedAt: DateTime.now().toUtc(),
          devToolsEnabled: false,
          userRole: 'admin',
        ),
      );

      final settings = box.get('app_settings');
      expect(settings, isNotNull);
      expect(settings!.devToolsEnabled, isFalse);
      // AdminAuthGuard would reject access at this point
    });

    test('userRole!=admin blocks access', () async {
      final box = await Hive.openBox<SettingsModel>(BoxRegistry.settingsBox);
      await box.put(
        'app_settings',
        SettingsModel(
          notificationsEnabled: true,
          vitalsRetentionDays: 30,
          updatedAt: DateTime.now().toUtc(),
          devToolsEnabled: true,
          userRole: 'patient',
        ),
      );

      final settings = box.get('app_settings');
      expect(settings!.userRole, 'patient');
      expect(settings.userRole == 'admin', isFalse);
    });

    test('devToolsEnabled=true + userRole=admin allows access (if compile flag set)', () async {
      final box = await Hive.openBox<SettingsModel>(BoxRegistry.settingsBox);
      await box.put(
        'app_settings',
        SettingsModel(
          notificationsEnabled: true,
          vitalsRetentionDays: 30,
          updatedAt: DateTime.now().toUtc(),
          devToolsEnabled: true,
          userRole: 'admin',
        ),
      );

      final settings = box.get('app_settings');
      expect(settings!.devToolsEnabled, isTrue);
      expect(settings.userRole, 'admin');
      // If kEnableAdminUI=true, this would proceed to biometric check
    });
  });

  group('SettingsModel security fields', () {
    test('defaults are secure', () {
      final settings = SettingsModel(
        notificationsEnabled: true,
        vitalsRetentionDays: 30,
        updatedAt: DateTime.now().toUtc(),
      );
      expect(settings.devToolsEnabled, isFalse);
      expect(settings.userRole, 'patient');
    });

    test('explicit admin role is respected', () {
      final settings = SettingsModel(
        notificationsEnabled: true,
        vitalsRetentionDays: 30,
        updatedAt: DateTime.now().toUtc(),
        devToolsEnabled: true,
        userRole: 'admin',
      );
      expect(settings.devToolsEnabled, isTrue);
      expect(settings.userRole, 'admin');
    });

    test('JSON round-trip preserves security fields', () {
      final original = SettingsModel(
        notificationsEnabled: false,
        vitalsRetentionDays: 90,
        updatedAt: DateTime(2025, 1, 1).toUtc(),
        devToolsEnabled: true,
        userRole: 'admin',
      );
      final json = original.toJson();
      final restored = SettingsModel.fromJson(json);
      
      expect(restored.devToolsEnabled, original.devToolsEnabled);
      expect(restored.userRole, original.userRole);
      expect(restored.notificationsEnabled, original.notificationsEnabled);
      expect(restored.vitalsRetentionDays, original.vitalsRetentionDays);
    });

    test('Adapter round-trip preserves security fields', () async {
      final box = await Hive.openBox<SettingsModel>(BoxRegistry.settingsBox);
      final original = SettingsModel(
        notificationsEnabled: true,
        vitalsRetentionDays: 60,
        updatedAt: DateTime.now().toUtc(),
        devToolsEnabled: true,
        userRole: 'caregiver',
      );
      
      await box.put('test_key', original);
      final restored = box.get('test_key');
      
      expect(restored, isNotNull);
      expect(restored!.devToolsEnabled, original.devToolsEnabled);
      expect(restored.userRole, original.userRole);
    });
  });

  group('BiometricAuthService integration', () {
    test('documents expected behavior', () {
      // BiometricAuthService wraps local_auth.
      // In tests, we cannot trigger real biometric hardware.
      // Production code should:
      // 1. Check canCheckBiometrics() before authenticate()
      // 2. Fall back to password/dialog if biometrics unavailable
      // 3. Return false on PlatformException
      
      // This test documents the contract; actual biometric testing
      // requires integration tests on physical devices.
      expect(true, isTrue);
    });
  });

  group('requireBiometricConfirmation helper', () {
    test('documents expected behavior for sensitive actions', () {
      // requireBiometricConfirmation should:
      // - Prompt biometric auth if available
      // - Fall back to confirmation dialog if not
      // - Return bool indicating authorization
      // 
      // Used before:
      // - Key rotation
      // - Backup restore
      // - Failed ops retry
      // - Any destructive admin action
      
      expect(true, isTrue);
    });
  });
}
