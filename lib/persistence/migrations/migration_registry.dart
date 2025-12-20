import 'migration_runner.dart';
import 'migrations/001_add_idempotency_key.dart';
import 'migrations/002_upgrade_vitals_schema.dart';
import 'migrations/003_add_room_index.dart';
import 'migrations/004_device_lastseen_cleanup.dart';
import 'hive_migration.dart';

List<Migration> buildMigrationRegistry() {
  return [
    Migration(
      fromVersion: 0,
      toVersion: 1,
      id: '001_add_idempotency_key',
      run: (registry) async => await migration001EnsureIdempotencyKey(),
    ),
    Migration(
      fromVersion: 1,
      toVersion: 2,
      id: '002_upgrade_vitals_schema',
      run: (registry) async => await migration002UpgradeVitalsSchema(registry),
    ),
    Migration(
      fromVersion: 2,
      toVersion: 3,
      id: '003_add_room_index',
      run: (registry) async {
        final migration = AddRoomIndexMigration();
        final dryRunResult = await migration.dryRun();
        if (!dryRunResult.canMigrate) {
          throw Exception('Migration dry run failed: ${dryRunResult.errors}');
        }
        final result = await migration.migrate();
        if (!result.success) {
          throw Exception('Migration failed: ${result.errors}');
        }
        final verification = await migration.verifySchema();
        if (!verification.isValid) {
          await migration.rollback();
          throw Exception('Migration verification failed: ${verification.violations}');
        }
      },
    ),
    Migration(
      fromVersion: 3,
      toVersion: 4,
      id: '004_device_lastseen_cleanup',
      run: (registry) async {
        final migration = DeviceLastSeenCleanupMigration();
        final dryRunResult = await migration.dryRun();
        if (!dryRunResult.canMigrate) {
          throw Exception('Migration dry run failed: ${dryRunResult.errors}');
        }
        final result = await migration.migrate();
        if (!result.success) {
          throw Exception('Migration failed: ${result.errors}');
        }
        final verification = await migration.verifySchema();
        if (!verification.isValid) {
          throw Exception('Migration verification failed: ${verification.violations}');
        }
      },
    ),
  ];
}

/// Returns a list of HiveMigration implementations for the MigrationExecutor.
List<HiveMigration> buildHiveMigrations() {
  return [
    AddRoomIndexMigration(),
    DeviceLastSeenCleanupMigration(),
  ];
}
