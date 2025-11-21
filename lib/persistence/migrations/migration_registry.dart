import 'migration_runner.dart';
import 'migrations/001_add_idempotency_key.dart';
import 'migrations/002_upgrade_vitals_schema.dart';
import '../box_registry.dart';

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
  ];
}
