/// Migration Tests
///
/// Tests for the HiveMigration implementations.
/// Part of 10% CLIMB #4 - Final audit closure.
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_angel_fyp/persistence/migrations/migrations/003_add_room_index.dart';
import 'package:guardian_angel_fyp/persistence/migrations/migrations/004_device_lastseen_cleanup.dart';
import 'package:guardian_angel_fyp/persistence/migrations/hive_migration.dart';
import 'package:guardian_angel_fyp/persistence/migrations/migration_registry.dart';

void main() {
  group('AddRoomIndexMigration', () {
    late AddRoomIndexMigration migration;
    
    setUp(() {
      migration = AddRoomIndexMigration();
    });
    
    test('has correct version range', () {
      expect(migration.from, equals(2));
      expect(migration.to, equals(3));
    });
    
    test('has unique id', () {
      expect(migration.id, equals('003_add_room_index'));
    });
    
    test('has description', () {
      expect(migration.description, isNotEmpty);
      expect(migration.description.toLowerCase(), contains('index'));
    });
    
    test('affects correct boxes', () {
      expect(migration.affectedBoxes, contains('rooms_box'));
      expect(migration.affectedBoxes, contains('room_name_index'));
    });
    
    test('is reversible', () {
      expect(migration.isReversible, isTrue);
    });
    
    test('has estimated duration', () {
      expect(migration.estimatedDurationMs, greaterThan(0));
    });
    
    test('implements HiveMigration interface', () {
      expect(migration, isA<HiveMigration>());
    });
  });
  
  group('DeviceLastSeenCleanupMigration', () {
    late DeviceLastSeenCleanupMigration migration;
    
    setUp(() {
      migration = DeviceLastSeenCleanupMigration();
    });
    
    test('has correct version range', () {
      expect(migration.from, equals(3));
      expect(migration.to, equals(4));
    });
    
    test('has unique id', () {
      expect(migration.id, equals('004_device_lastseen_cleanup'));
    });
    
    test('has description', () {
      expect(migration.description, isNotEmpty);
      expect(migration.description.toLowerCase(), contains('timestamp'));
    });
    
    test('affects devices box', () {
      expect(migration.affectedBoxes, contains('devices_box'));
    });
    
    test('is not reversible', () {
      expect(migration.isReversible, isFalse);
    });
    
    test('implements HiveMigration interface', () {
      expect(migration, isA<HiveMigration>());
    });
  });
  
  group('Migration Registry', () {
    test('buildMigrationRegistry returns all migrations', () {
      final migrations = buildMigrationRegistry();
      
      expect(migrations.length, greaterThanOrEqualTo(4));
    });
    
    test('migrations have sequential versions', () {
      final migrations = buildMigrationRegistry();
      
      for (int i = 0; i < migrations.length - 1; i++) {
        expect(
          migrations[i].toVersion,
          equals(migrations[i + 1].fromVersion),
          reason: 'Migration ${migrations[i].id} toVersion should match '
              'next migration ${migrations[i + 1].id} fromVersion',
        );
      }
    });
    
    test('migrations have unique ids', () {
      final migrations = buildMigrationRegistry();
      final ids = migrations.map((m) => m.id).toSet();
      
      expect(ids.length, equals(migrations.length));
    });
    
    test('buildHiveMigrations returns HiveMigration implementations', () {
      final hiveMigrations = buildHiveMigrations();
      
      expect(hiveMigrations, isNotEmpty);
      for (final m in hiveMigrations) {
        expect(m, isA<HiveMigration>());
      }
    });
    
    test('all migrations start from version 0', () {
      final migrations = buildMigrationRegistry();
      expect(migrations.first.fromVersion, equals(0));
    });
  });

  group('DryRunResult', () {
    test('success factory creates valid result', () {
      final result = DryRunResult.success(
        recordsToMigrate: 10,
        warnings: ['Test warning'],
      );
      
      expect(result.canMigrate, isTrue);
      expect(result.recordsToMigrate, equals(10));
      expect(result.warnings, contains('Test warning'));
      expect(result.errors, isEmpty);
    });
    
    test('failure factory creates invalid result', () {
      final result = DryRunResult.failure(['Error 1', 'Error 2']);
      
      expect(result.canMigrate, isFalse);
      expect(result.errors.length, equals(2));
    });
    
    test('toJson returns complete map', () {
      final result = DryRunResult.success(recordsToMigrate: 5);
      final json = result.toJson();
      
      expect(json['canMigrate'], isTrue);
      expect(json['recordsToMigrate'], equals(5));
      expect(json.containsKey('warnings'), isTrue);
      expect(json.containsKey('errors'), isTrue);
    });
  });

  group('MigrationResult', () {
    test('success factory creates valid result', () {
      final result = MigrationResult.success(
        recordsMigrated: 100,
        duration: const Duration(milliseconds: 500),
      );
      
      expect(result.success, isTrue);
      expect(result.recordsMigrated, equals(100));
      expect(result.duration.inMilliseconds, equals(500));
      expect(result.errors, isEmpty);
    });
    
    test('failure constructor captures errors', () {
      final result = MigrationResult(
        success: false,
        errors: ['Database error'],
      );
      
      expect(result.success, isFalse);
      expect(result.errors, contains('Database error'));
    });
  });

  group('SchemaVerification', () {
    test('valid creates valid result', () {
      final result = SchemaVerification.valid(recordCounts: {'test': 50});
      
      expect(result.isValid, isTrue);
      expect(result.recordCounts['test'], equals(50));
      expect(result.violations, isEmpty);
    });
    
    test('invalid creates invalid result', () {
      final result = SchemaVerification.invalid(['Schema mismatch']);
      
      expect(result.isValid, isFalse);
      expect(result.violations, contains('Schema mismatch'));
    });
  });

  group('RollbackResult', () {
    test('success creates valid result', () {
      final result = RollbackResult.success();
      
      expect(result.success, isTrue);
      expect(result.errors, isEmpty);
    });
    
    test('failure captures errors', () {
      final result = RollbackResult(
        success: false,
        errors: ['Rollback failed'],
      );
      
      expect(result.success, isFalse);
      expect(result.errors, contains('Rollback failed'));
    });
  });
}
