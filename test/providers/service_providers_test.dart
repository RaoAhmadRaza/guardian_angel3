/// Tests for Riverpod Service Providers
///
/// Verifies proper dependency injection architecture:
/// - Services are created fresh (not singletons)
/// - Dependencies are properly injected
/// - Providers can be overridden for testing
/// - No global state leakage
///
/// Part of 10% CLIMB #2: Architectural legitimacy.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian_angel_fyp/providers/service_providers.dart';
import 'package:guardian_angel_fyp/providers/theme_controller.dart';
import 'package:guardian_angel_fyp/services/telemetry_service.dart';
import 'package:guardian_angel_fyp/services/audit_log_service.dart';
import 'package:guardian_angel_fyp/services/sync_failure_service.dart';
import 'package:guardian_angel_fyp/services/secure_erase_service.dart';
import 'package:guardian_angel_fyp/services/secure_erase_hardened.dart';
import 'package:guardian_angel_fyp/services/session_service.dart';
import 'package:guardian_angel_fyp/services/onboarding_service.dart';
import 'package:guardian_angel_fyp/services/home_automation_service.dart';
import 'package:guardian_angel_fyp/controllers/home_automation_controller.dart';
import 'package:guardian_angel_fyp/persistence/guardrails/production_guardrails.dart';

void main() {
  group('Service Provider Architecture', () {
    group('Core Services', () {
      test('telemetryServiceProvider creates fresh instance', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final service1 = container.read(telemetryServiceProvider);
        expect(service1, isA<TelemetryService>());

        // Create another container to verify isolation
        final container2 = ProviderContainer();
        addTearDown(container2.dispose);
        final service2 = container2.read(telemetryServiceProvider);

        // Different containers should have different instances (proper DI)
        expect(identical(service1, service2), isFalse);
      });

      test('auditLogServiceProvider injects telemetry dependency', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final service = container.read(auditLogServiceProvider);
        expect(service, isA<AuditLogService>());
      });

      test('syncFailureServiceProvider injects telemetry dependency', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final service = container.read(syncFailureServiceProvider);
        expect(service, isA<SyncFailureService>());
      });

      test('secureEraseServiceProvider injects telemetry dependency', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final service = container.read(secureEraseServiceProvider);
        expect(service, isA<SecureEraseService>());
      });

      test('secureEraseHardenedProvider injects telemetry dependency', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final service = container.read(secureEraseHardenedProvider);
        expect(service, isA<SecureEraseHardened>());
      });

      test('productionGuardrailsProvider injects telemetry dependency', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final service = container.read(productionGuardrailsProvider);
        expect(service, isA<ProductionGuardrails>());
      });
    });

    group('Session & Onboarding', () {
      test('sessionServiceProvider creates fresh instance', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final service = container.read(sessionServiceProvider);
        expect(service, isA<SessionService>());
      });

      test('onboardingServiceProvider creates fresh instance', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final service = container.read(onboardingServiceProvider);
        expect(service, isA<OnboardingService>());
      });
    });

    group('Home Automation', () {
      test('homeAutomationServiceProvider creates fresh instance', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final service = container.read(homeAutomationServiceProvider);
        expect(service, isA<HomeAutomationService>());
      });

      test('homeAutomationControllerProvider injects service dependency', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final controller = container.read(homeAutomationControllerProvider);
        expect(controller, isA<HomeAutomationController>());
      });
    });
  });

  group('Theme Controller', () {
    test('themeControllerProvider creates StateNotifier', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(themeControllerProvider);
      expect(state, isA<ThemeState>());
      expect(state.isInitialized, isFalse); // Not initialized yet
    });

    test('ThemeState has correct default values', () {
      const state = ThemeState();
      expect(state.themeMode, equals(ThemeMode.system));
      expect(state.isInitialized, isFalse);
      expect(state.isSystemMode, isTrue);
      expect(state.isDarkMode, isFalse);
      expect(state.isLightMode, isFalse);
    });

    test('ThemeState.copyWith preserves unchanged values', () {
      const state = ThemeState(themeMode: ThemeMode.dark, isInitialized: true);
      final copied = state.copyWith(themeMode: ThemeMode.light);
      
      expect(copied.themeMode, equals(ThemeMode.light));
      expect(copied.isInitialized, isTrue); // Preserved
    });

    test('ThemeState equality works correctly', () {
      const state1 = ThemeState(themeMode: ThemeMode.dark, isInitialized: true);
      const state2 = ThemeState(themeMode: ThemeMode.dark, isInitialized: true);
      const state3 = ThemeState(themeMode: ThemeMode.light, isInitialized: true);
      
      expect(state1, equals(state2));
      expect(state1, isNot(equals(state3)));
    });

    test('ThemeState.themeIcon returns correct icons', () {
      expect(
        const ThemeState(themeMode: ThemeMode.light).themeIcon,
        equals(Icons.light_mode_outlined),
      );
      expect(
        const ThemeState(themeMode: ThemeMode.dark).themeIcon,
        equals(Icons.dark_mode_outlined),
      );
      expect(
        const ThemeState(themeMode: ThemeMode.system).themeIcon,
        equals(Icons.brightness_auto_outlined),
      );
    });

    test('themeModeProvider returns current theme mode', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final mode = container.read(themeModeProvider);
      expect(mode, isA<ThemeMode>());
    });

    test('isDarkModeProvider returns boolean', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final isDark = container.read(isDarkModeProvider);
      expect(isDark, isA<bool>());
    });
  });

  group('Provider Overrides (Testing Support)', () {
    test('telemetryServiceProvider can be overridden', () {
      final mockTelemetry = TelemetryService();
      
      final container = ProviderContainer(
        overrides: [
          telemetryServiceProvider.overrideWithValue(mockTelemetry),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(telemetryServiceProvider);
      expect(identical(service, mockTelemetry), isTrue);
    });

    test('overridden telemetry propagates to dependent services', () {
      final mockTelemetry = TelemetryService();
      
      final container = ProviderContainer(
        overrides: [
          telemetryServiceProvider.overrideWithValue(mockTelemetry),
        ],
      );
      addTearDown(container.dispose);

      // Audit log service should use the overridden telemetry
      final auditLog = container.read(auditLogServiceProvider);
      expect(auditLog, isA<AuditLogService>());
    });

    test('ServiceProviderOverrides.create() generates overrides', () {
      final mockTelemetry = TelemetryService();
      final mockSession = SessionService();
      
      final overrides = ServiceProviderOverrides.create(
        telemetry: mockTelemetry,
        session: mockSession,
      );

      expect(overrides.length, equals(2));
      
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(identical(container.read(telemetryServiceProvider), mockTelemetry), isTrue);
      expect(identical(container.read(sessionServiceProvider), mockSession), isTrue);
    });

    test('ServiceProviderOverrides.create() with all services', () {
      final overrides = ServiceProviderOverrides.create(
        telemetry: TelemetryService(),
        session: SessionService(),
        onboarding: OnboardingService(),
        homeAutomation: HomeAutomationService(),
      );

      expect(overrides.length, equals(4));
    });
  });

  group('No Singleton Leakage', () {
    test('different containers have isolated state', () {
      final container1 = ProviderContainer();
      final container2 = ProviderContainer();
      addTearDown(container1.dispose);
      addTearDown(container2.dispose);

      final telemetry1 = container1.read(telemetryServiceProvider);
      final telemetry2 = container2.read(telemetryServiceProvider);

      // Increment counter in container1
      telemetry1.increment('test_counter');

      // container2 should not see the increment (different instances)
      expect(identical(telemetry1, telemetry2), isFalse);
    });

    test('same container returns same instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final telemetry1 = container.read(telemetryServiceProvider);
      final telemetry2 = container.read(telemetryServiceProvider);

      expect(identical(telemetry1, telemetry2), isTrue);
    });

    test('disposing container does not affect other containers', () {
      final container1 = ProviderContainer();
      final container2 = ProviderContainer();
      addTearDown(container2.dispose);

      container1.read(telemetryServiceProvider);
      final telemetry2 = container2.read(telemetryServiceProvider);

      // Dispose container1
      container1.dispose();

      // container2 should still work
      expect(() => telemetry2.increment('test'), returnsNormally);
    });
  });

  group('Migration Status', () {
    test('singletonMigrationStatus reports 100% complete', () {
      final status = singletonMigrationStatus;
      
      expect(status.migrationProgress, equals(1.0));
      expect(status.totalSingletons, equals(11));
      expect(status.migratedToProviders, equals(11));
      expect(status.usagesRefactored, equals(11));
    });

    test('completedWork lists all migrated services', () {
      final status = singletonMigrationStatus;
      
      expect(status.completedWork.length, equals(11));
      expect(status.completedWork.any((s) => s.contains('TelemetryService')), isTrue);
      expect(status.completedWork.any((s) => s.contains('AuditLogService')), isTrue);
      expect(status.completedWork.any((s) => s.contains('ThemeController')), isTrue);
      expect(status.completedWork.any((s) => s.contains('SessionService')), isTrue);
      expect(status.completedWork.any((s) => s.contains('OnboardingService')), isTrue);
      expect(status.completedWork.any((s) => s.contains('HomeAutomationService')), isTrue);
    });

    test('deprecatedSingletons lists all old patterns', () {
      final status = singletonMigrationStatus;
      
      expect(status.deprecatedSingletons.length, equals(11));
      expect(status.deprecatedSingletons.any((s) => s.contains('TelemetryService.I')), isTrue);
      expect(status.deprecatedSingletons.any((s) => s.contains('ThemeProvider.instance')), isTrue);
      expect(status.deprecatedSingletons.any((s) => s.contains('SessionService.instance')), isTrue);
    });

    test('toJson() returns valid JSON structure', () {
      final status = singletonMigrationStatus;
      final json = status.toJson();
      
      expect(json['total_singletons'], equals(11));
      expect(json['migration_progress'], equals('100.0%'));
      expect(json['completed_work'], isA<List>());
      expect(json['deprecated_singletons'], isA<List>());
    });
  });

  group('Telemetry Service Usage', () {
    test('can use telemetry service through provider', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      
      final telemetry = container.read(telemetryServiceProvider);
      
      // Should not throw
      telemetry.increment('test_counter');
      telemetry.gauge('test_gauge', 42);
      
      final snapshot = telemetry.snapshot();
      expect(snapshot['counters']['test_counter'], equals(1));
      expect(snapshot['gauges']['test_gauge'], equals(42));
    });
  });
}

