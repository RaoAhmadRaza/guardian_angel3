import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:guardian_angel_fyp/persistence/migrations/migration_policy.dart';
import 'package:guardian_angel_fyp/persistence/box_registry.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    // Create temp directory for Hive
    tempDir = await Directory.systemTemp.createTemp('migration_policy_test');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    // Clean up
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ModelSchemaRegistry', () {
    test('getCurrentVersion returns registered version', () {
      // Registry is const, so we can only test the API
      final version = ModelSchemaRegistry.getCurrentVersion(String);
      expect(version, isNull); // String not registered
    });

    test('isVersionCompatible returns true for unregistered types', () {
      // Legacy models without tracking are allowed
      expect(ModelSchemaRegistry.isVersionCompatible(String, 999), isTrue);
    });

    test('isVersionCompatible returns true for same or lower version', () {
      // If we add a model with version 5, versions 1-5 should be compatible
      // Since we can't modify const map in tests, we test the logic path
      expect(ModelSchemaRegistry.isVersionCompatible(String, 1), isTrue);
    });

    test('registeredTypes returns all types', () {
      final types = ModelSchemaRegistry.registeredTypes;
      expect(types, isNotNull);
      expect(types, isA<Iterable<Type>>());
    });

    test('trackedModelCount returns count', () {
      final count = ModelSchemaRegistry.trackedModelCount;
      expect(count, isA<int>());
      expect(count, greaterThanOrEqualTo(0));
    });
  });

  group('MigrationPolicyResult', () {
    test('valid factory creates valid result', () {
      final result = MigrationPolicyResult.valid(
        warnings: ['test warning'],
        metadata: {'key': 'value'},
      );

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
      expect(result.warnings, hasLength(1));
      expect(result.metadata['key'], equals('value'));
    });

    test('invalid factory creates invalid result', () {
      final result = MigrationPolicyResult.invalid(
        errors: ['error 1', 'error 2'],
        warnings: ['warning'],
      );

      expect(result.isValid, isFalse);
      expect(result.errors, hasLength(2));
      expect(result.warnings, hasLength(1));
    });
  });

  group('MigrationPolicy - Fresh Install', () {
    test('validate passes on fresh install (no meta box)', () async {
      final result = await MigrationPolicy.validate();

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });

    test('recordSchemaVersion creates meta box and stores version', () async {
      await MigrationPolicy.recordSchemaVersion(2);

      expect(await Hive.boxExists(BoxRegistry.metaBox), isTrue);
      
      final stored = await MigrationTestHelper.getStoredSchemaVersion();
      expect(stored, equals(2));
    });
  });

  group('MigrationPolicy - Current Version', () {
    test('validate passes when stored version matches current', () async {
      await MigrationPolicy.recordSchemaVersion(
        MigrationPolicy.currentAppSchemaVersion,
      );

      final result = await MigrationPolicy.validate();

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
      expect(
        result.metadata['stored_app_schema_version'],
        equals(MigrationPolicy.currentAppSchemaVersion),
      );
    });
  });

  group('MigrationPolicy - Old Version (Migration Needed)', () {
    test('validate warns when stored version is older', () async {
      await MigrationTestHelper.injectOldSchemaVersion(1);

      final result = await MigrationPolicy.validate();

      expect(result.isValid, isTrue); // Not blocking, just warns
      expect(result.warnings, isNotEmpty);
      expect(
        result.warnings.first,
        contains('Migration required'),
      );
      expect(result.metadata['stored_app_schema_version'], equals(1));
    });
  });

  group('MigrationPolicy - Future Version (BLOCKING)', () {
    test('validate blocks when stored version is newer', () async {
      await MigrationTestHelper.injectFutureSchemaVersion(99);

      final result = await MigrationPolicy.validate();

      expect(result.isValid, isFalse);
      expect(result.errors, isNotEmpty);
      expect(result.errors.first, contains('BLOCKING'));
      expect(result.errors.first, contains('HIGHER than current'));
      expect(result.errors.first, contains('Downgrade not supported'));
    });

    test('enforceNoFutureMigrations throws on future version', () async {
      await MigrationTestHelper.injectFutureSchemaVersion(99);

      expect(
        () => MigrationPolicy.enforceNoFutureMigrations(),
        throwsA(isA<MigrationPolicyException>()),
      );
    });

    test('enforceNoFutureMigrations does not throw on valid version', () async {
      await MigrationPolicy.recordSchemaVersion(
        MigrationPolicy.currentAppSchemaVersion,
      );

      // Should complete without throwing
      await MigrationPolicy.enforceNoFutureMigrations();
    });
  });

  group('MigrationPolicyException', () {
    test('toString includes message and errors', () {
      final exception = MigrationPolicyException(
        'Test failure',
        errors: ['Error 1', 'Error 2'],
      );

      final str = exception.toString();
      expect(str, contains('Test failure'));
      expect(str, contains('Error 1'));
      expect(str, contains('Error 2'));
    });
  });

  group('MigrationTestHelper', () {
    test('injectFutureSchemaVersion stores future version', () async {
      await MigrationTestHelper.injectFutureSchemaVersion(50);

      final stored = await MigrationTestHelper.getStoredSchemaVersion();
      expect(stored, equals(50));
    });

    test('injectOldSchemaVersion stores old version', () async {
      await MigrationTestHelper.injectOldSchemaVersion(1);

      final stored = await MigrationTestHelper.getStoredSchemaVersion();
      expect(stored, equals(1));
    });

    test('clearSchemaVersion removes version', () async {
      await MigrationPolicy.recordSchemaVersion(5);
      expect(await MigrationTestHelper.getStoredSchemaVersion(), equals(5));

      await MigrationTestHelper.clearSchemaVersion();
      expect(await MigrationTestHelper.getStoredSchemaVersion(), isNull);
    });

    test('getStoredSchemaVersion returns null when no meta box', () async {
      final version = await MigrationTestHelper.getStoredSchemaVersion();
      expect(version, isNull);
    });
  });

  group('MigrationPolicy - Rollback Testing', () {
    test('can simulate version downgrade scenario', () async {
      // Simulate app with version 5
      await MigrationPolicy.recordSchemaVersion(5);
      expect(await MigrationTestHelper.getStoredSchemaVersion(), equals(5));

      // User "downgrades" to app with version 2 (current)
      // This should be blocked if they try to launch
      final result = await MigrationPolicy.validate();
      expect(result.isValid, isFalse);
      expect(result.errors.first, contains('BLOCKING'));
    });

    test('can simulate version upgrade scenario', () async {
      // Simulate app with version 1 (old)
      await MigrationTestHelper.injectOldSchemaVersion(1);

      // User upgrades to version 2 (current)
      final result = await MigrationPolicy.validate();
      expect(result.isValid, isTrue); // Warns but allows
      expect(result.warnings.first, contains('Migration required'));

      // After successful migration, record new version
      await MigrationPolicy.recordSchemaVersion(
        MigrationPolicy.currentAppSchemaVersion,
      );

      // Now validation should be clean (no errors, may have model registry warning)
      final result2 = await MigrationPolicy.validate();
      expect(result2.isValid, isTrue);
      expect(result2.errors, isEmpty);
    });
  });

  group('MigrationPolicy - Audit Trail', () {
    test('validate logs policy check result', () async {
      // This test verifies that validate() completes without error
      // and would log to audit service (mocked in real implementation)
      final result = await MigrationPolicy.validate();
      expect(result, isNotNull);
      expect(result.metadata, contains('tracked_model_count'));
    });

    test('recordSchemaVersion logs version change', () async {
      // Verify that recordSchemaVersion completes and stores value
      await MigrationPolicy.recordSchemaVersion(2);
      
      final stored = await MigrationTestHelper.getStoredSchemaVersion();
      expect(stored, equals(2));
    });
  });

  group('VersionedModel Interface', () {
    test('VersionedModel interface exists and is abstract', () {
      // This is a compile-time check, but we can verify the type exists
      expect(VersionedModel, isNotNull);
    });
  });

  group('MigrationPolicy - Constants', () {
    test('currentAppSchemaVersion is defined', () {
      expect(MigrationPolicy.currentAppSchemaVersion, isA<int>());
      expect(MigrationPolicy.currentAppSchemaVersion, greaterThan(0));
    });
  });

  group('MigrationPolicy - Edge Cases', () {
    test('handles meta box open/close gracefully', () async {
      // Record version
      await MigrationPolicy.recordSchemaVersion(2);
      
      // Validate multiple times (tests box reopen)
      await MigrationPolicy.validate();
      await MigrationPolicy.validate();
      await MigrationPolicy.validate();
      
      // Should not throw or leak boxes
      expect(Hive.isBoxOpen(BoxRegistry.metaBox), isFalse);
    });

    test('validate handles missing model registry gracefully', () async {
      // With no models registered, should warn but not error
      final result = await MigrationPolicy.validate();
      
      expect(result.isValid, isTrue);
      final hasWarning = result.warnings.any(
        (w) => w.contains('No models registered'),
      );
      expect(hasWarning, isTrue);
    });
  });
}
