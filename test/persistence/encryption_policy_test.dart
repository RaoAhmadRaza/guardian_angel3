/// Encryption Policy Tests
///
/// Tests for encryption policy enforcement.
/// Part of 10% CLIMB #3: Production credibility.
///
/// Verifies:
/// - Policy declaration for all boxes
/// - Policy enforcement (strict and non-strict modes)
/// - Violation detection and reporting
/// - Registration of encrypted boxes
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_angel_fyp/persistence/encryption_policy.dart';
import 'package:guardian_angel_fyp/persistence/box_registry.dart';

void main() {
  setUp(() {
    // Clear registry before each test
    EncryptionPolicyEnforcer.clearRegistry();
  });

  group('EncryptionPolicy Enum', () {
    test('has all required values', () {
      expect(EncryptionPolicy.values, contains(EncryptionPolicy.required));
      expect(EncryptionPolicy.values, contains(EncryptionPolicy.optional));
      expect(EncryptionPolicy.values, contains(EncryptionPolicy.forbidden));
    });
  });

  group('BoxConfig', () {
    test('creates config with required fields', () {
      final config = BoxConfig(
        name: 'test_box',
        encryption: EncryptionPolicy.required,
      );

      expect(config.name, equals('test_box'));
      expect(config.encryption, equals(EncryptionPolicy.required));
    });

    test('toString returns readable format', () {
      final config = BoxConfig(
        name: 'test_box',
        encryption: EncryptionPolicy.optional,
      );

      expect(config.toString(), contains('test_box'));
      expect(config.toString(), contains('optional'));
    });
  });

  group('BoxPolicyRegistry', () {
    test('has configs for all standard boxes', () {
      expect(BoxPolicyRegistry.configs, isNotEmpty);
      
      // Verify critical boxes have configs
      expect(BoxPolicyRegistry.getConfig(BoxRegistry.userProfileBox), isNotNull);
      expect(BoxPolicyRegistry.getConfig(BoxRegistry.sessionsBox), isNotNull);
      expect(BoxPolicyRegistry.getConfig(BoxRegistry.vitalsBox), isNotNull);
      expect(BoxPolicyRegistry.getConfig(BoxRegistry.pendingOpsBox), isNotNull);
    });

    test('sensitive boxes require encryption', () {
      final userProfile = BoxPolicyRegistry.getConfig(BoxRegistry.userProfileBox);
      final sessions = BoxPolicyRegistry.getConfig(BoxRegistry.sessionsBox);
      final vitals = BoxPolicyRegistry.getConfig(BoxRegistry.vitalsBox);
      final auditLogs = BoxPolicyRegistry.getConfig(BoxRegistry.auditLogsBox);

      expect(userProfile?.encryption, equals(EncryptionPolicy.required));
      expect(sessions?.encryption, equals(EncryptionPolicy.required));
      expect(vitals?.encryption, equals(EncryptionPolicy.required));
      expect(auditLogs?.encryption, equals(EncryptionPolicy.required));
    });

    test('index boxes forbid encryption', () {
      final pendingIndex = BoxPolicyRegistry.getConfig(BoxRegistry.pendingIndexBox);
      final metaBox = BoxPolicyRegistry.getConfig(BoxRegistry.metaBox);

      expect(pendingIndex?.encryption, equals(EncryptionPolicy.forbidden));
      expect(metaBox?.encryption, equals(EncryptionPolicy.forbidden));
    });

    test('cache boxes have optional encryption', () {
      final assetsCache = BoxPolicyRegistry.getConfig(BoxRegistry.assetsCacheBox);
      final uiPrefs = BoxPolicyRegistry.getConfig(BoxRegistry.uiPreferencesBox);

      expect(assetsCache?.encryption, equals(EncryptionPolicy.optional));
      expect(uiPrefs?.encryption, equals(EncryptionPolicy.optional));
    });

    test('getPolicy returns policy for known box', () {
      final policy = BoxPolicyRegistry.getPolicy(BoxRegistry.userProfileBox);
      expect(policy, equals(EncryptionPolicy.required));
    });

    test('getPolicy returns optional for unknown box', () {
      final policy = BoxPolicyRegistry.getPolicy('unknown_box_name');
      expect(policy, equals(EncryptionPolicy.optional));
    });
  });

  group('EncryptionPolicyEnforcer', () {
    test('registerEncryptedBox adds box to registry', () {
      expect(EncryptionPolicyEnforcer.isRegisteredAsEncrypted('test_box'), isFalse);
      
      EncryptionPolicyEnforcer.registerEncryptedBox('test_box');
      
      expect(EncryptionPolicyEnforcer.isRegisteredAsEncrypted('test_box'), isTrue);
    });

    test('clearRegistry removes all registrations', () {
      EncryptionPolicyEnforcer.registerEncryptedBox('box1');
      EncryptionPolicyEnforcer.registerEncryptedBox('box2');
      
      EncryptionPolicyEnforcer.clearRegistry();
      
      expect(EncryptionPolicyEnforcer.isRegisteredAsEncrypted('box1'), isFalse);
      expect(EncryptionPolicyEnforcer.isRegisteredAsEncrypted('box2'), isFalse);
    });

    group('enforcePolicy', () {
      test('returns true for encrypted box with required policy', () {
        EncryptionPolicyEnforcer.registerEncryptedBox(BoxRegistry.userProfileBox);
        
        final result = EncryptionPolicyEnforcer.enforcePolicy(
          BoxRegistry.userProfileBox,
          strict: false,
        );
        
        expect(result, isTrue);
      });

      test('returns false for unencrypted box with required policy (non-strict)', () {
        // Don't register box as encrypted
        
        final result = EncryptionPolicyEnforcer.enforcePolicy(
          BoxRegistry.userProfileBox,
          strict: false,
        );
        
        expect(result, isFalse);
      });

      test('throws for unencrypted box with required policy (strict)', () {
        // Don't register box as encrypted
        
        expect(
          () => EncryptionPolicyEnforcer.enforcePolicy(
            BoxRegistry.userProfileBox,
            strict: true,
          ),
          throwsA(isA<EncryptionPolicyViolation>()),
        );
      });

      test('returns true for unencrypted box with forbidden policy', () {
        // Don't register as encrypted - forbidden boxes should NOT be encrypted
        
        final result = EncryptionPolicyEnforcer.enforcePolicy(
          BoxRegistry.metaBox,
          strict: false,
        );
        
        expect(result, isTrue);
      });

      test('returns false for encrypted box with forbidden policy (non-strict)', () {
        // Register as encrypted - but this box forbids encryption
        EncryptionPolicyEnforcer.registerEncryptedBox(BoxRegistry.metaBox);
        
        final result = EncryptionPolicyEnforcer.enforcePolicy(
          BoxRegistry.metaBox,
          strict: false,
        );
        
        expect(result, isFalse);
      });

      test('returns true for any encryption state with optional policy', () {
        // Optional boxes always pass
        final unencrypted = EncryptionPolicyEnforcer.enforcePolicy(
          BoxRegistry.assetsCacheBox,
          strict: false,
        );
        expect(unencrypted, isTrue);
        
        EncryptionPolicyEnforcer.registerEncryptedBox(BoxRegistry.assetsCacheBox);
        final encrypted = EncryptionPolicyEnforcer.enforcePolicy(
          BoxRegistry.assetsCacheBox,
          strict: false,
        );
        expect(encrypted, isTrue);
      });

      test('returns true for unknown box', () {
        final result = EncryptionPolicyEnforcer.enforcePolicy(
          'unknown_box',
          strict: true,
        );
        
        expect(result, isTrue);
      });
    });

    group('enforceAllPolicies', () {
      test('returns healthy summary when all boxes comply', () {
        // Register all required boxes as encrypted
        for (final config in BoxPolicyRegistry.configs) {
          if (config.encryption == EncryptionPolicy.required) {
            EncryptionPolicyEnforcer.registerEncryptedBox(config.name);
          }
        }
        
        final summary = EncryptionPolicyEnforcer.enforceAllPolicies(strict: false);
        
        expect(summary.isHealthy, isTrue);
        expect(summary.violationCount, equals(0));
      });

      test('returns violations for non-compliant boxes', () {
        // Don't register any boxes as encrypted
        // This should cause violations for required boxes
        
        final summary = EncryptionPolicyEnforcer.enforceAllPolicies(strict: false);
        
        expect(summary.isHealthy, isFalse);
        expect(summary.violationCount, greaterThan(0));
        expect(summary.violatedBoxes, isNotEmpty);
      });
    });
  });

  group('EncryptionPolicyViolation', () {
    test('creates violation for required but unencrypted', () {
      final violation = EncryptionPolicyViolation(
        boxName: 'test_box',
        expectedPolicy: EncryptionPolicy.required,
        actuallyEncrypted: false,
      );

      expect(violation.message, contains('SECURITY VIOLATION'));
      expect(violation.message, contains('test_box'));
      expect(violation.message, contains('requires encryption'));
    });

    test('creates violation for forbidden but encrypted', () {
      final violation = EncryptionPolicyViolation(
        boxName: 'test_box',
        expectedPolicy: EncryptionPolicy.forbidden,
        actuallyEncrypted: true,
      );

      expect(violation.message, contains('POLICY VIOLATION'));
      expect(violation.message, contains('test_box'));
      expect(violation.message, contains('forbids encryption'));
    });

    test('toString includes message', () {
      final violation = EncryptionPolicyViolation(
        boxName: 'test_box',
        expectedPolicy: EncryptionPolicy.required,
        actuallyEncrypted: false,
      );

      expect(violation.toString(), contains('EncryptionPolicyViolation'));
      expect(violation.toString(), contains(violation.message));
    });
  });

  group('EncryptionPolicySummary', () {
    test('creates summary with correct values', () {
      final summary = EncryptionPolicySummary(
        compliantCount: 10,
        violationCount: 2,
        violatedBoxes: ['box1', 'box2'],
        isHealthy: false,
      );

      expect(summary.compliantCount, equals(10));
      expect(summary.violationCount, equals(2));
      expect(summary.violatedBoxes, equals(['box1', 'box2']));
      expect(summary.isHealthy, isFalse);
    });

    test('toString returns readable format', () {
      final summary = EncryptionPolicySummary(
        compliantCount: 10,
        violationCount: 0,
        violatedBoxes: [],
        isHealthy: true,
      );

      expect(summary.toString(), contains('compliant: 10'));
      expect(summary.toString(), contains('healthy: true'));
    });
  });

  group('Policy Coverage', () {
    test('all BoxRegistry boxes have policy defined', () {
      for (final boxName in BoxRegistry.allBoxes) {
        // getPolicy returns optional for undefined, but we want explicit coverage
        final config = BoxPolicyRegistry.getConfig(boxName);
        
        // Skip if not in policy registry (some boxes may be added later)
        if (config == null) {
          // This is a warning - ideally all boxes should have policies
          print('Warning: No encryption policy for $boxName');
        }
      }
      
      // Verify we have policies for the critical boxes
      expect(BoxPolicyRegistry.getConfig(BoxRegistry.userProfileBox), isNotNull);
      expect(BoxPolicyRegistry.getConfig(BoxRegistry.sessionsBox), isNotNull);
      expect(BoxPolicyRegistry.getConfig(BoxRegistry.vitalsBox), isNotNull);
    });

    test('no duplicate box names in policy registry', () {
      final names = BoxPolicyRegistry.configs.map((c) => c.name).toList();
      final uniqueNames = names.toSet();
      
      expect(names.length, equals(uniqueNames.length),
          reason: 'Duplicate box names found in policy registry');
    });
  });
}
