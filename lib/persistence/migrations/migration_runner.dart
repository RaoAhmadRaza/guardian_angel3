import 'package:hive/hive.dart';
import '../box_registry.dart';
import '../meta/meta_store.dart';
import '../wrappers/box_accessor.dart';
import 'migration_registry.dart';
import '../../services/telemetry_service.dart';

typedef MigrationFn = Future<void> Function(BoxRegistry registry);

class Migration {
  final int fromVersion;
  final int toVersion;
  final String id; // e.g. '001_add_idempotency_key'
  final MigrationFn run;
  Migration({required this.fromVersion, required this.toVersion, required this.id, required this.run});
}

class MigrationRunner {
  final MetaStore meta;
  final List<Migration> migrations;
  final BoxRegistry registry;
  final bool skipBackup; // test harness flag

  MigrationRunner({required this.meta, required this.migrations, required this.registry, this.skipBackup = false});

  /// Static convenience method for bootstrap - runs all pending migrations.
  ///
  /// Creates MetaStore and BoxRegistry internally, suitable for calling
  /// from app_bootstrap.dart without manual wiring.
  ///
  /// Returns the number of migrations applied.
  static Future<int> runAllPending({bool skipBackup = false}) async {
    // Ensure meta box is open
    if (!Hive.isBoxOpen(BoxRegistry.metaBox)) {
      await Hive.openBox(BoxRegistry.metaBox);
    }
    
    final metaBox = BoxAccess.I.meta();
    final metaStore = MetaStore(metaBox);
    final registry = BoxRegistry();
    final migrations = buildMigrationRegistry();
    
    final currentVersion = metaStore.getSchemaVersion('core');
    final pendingCount = migrations.where((m) => m.fromVersion >= currentVersion).length;
    
    if (pendingCount == 0) {
      TelemetryService.I.increment('migrations.none_pending');
      return 0;
    }
    
    final runner = MigrationRunner(
      meta: metaStore,
      migrations: migrations,
      registry: registry,
      skipBackup: skipBackup,
    );
    
    final sw = Stopwatch()..start();
    await runner.runAll();
    sw.stop();
    
    final newVersion = metaStore.getSchemaVersion('core');
    final appliedCount = newVersion - currentVersion;
    
    TelemetryService.I.gauge('migrations.applied_count', appliedCount);
    TelemetryService.I.time('migrations.total_duration_ms', () => sw.elapsed);
    print('[MigrationRunner] Applied $appliedCount migrations in ${sw.elapsedMilliseconds}ms (v$currentVersion → v$newVersion)');
    
    return appliedCount;
  }

  Future<void> runAll() async {
    int current = meta.getSchemaVersion('core');
    while (true) {
      final pending = migrations.where((m) => m.fromVersion == current).toList();
      if (pending.isEmpty) break;
      for (final m in pending) {
        await _runSingle(m);
        await meta.setSchemaVersion('core', m.toVersion);
        await meta.setMigrationApplied('core', m.toVersion, DateTime.now().toUtc().toIso8601String());
        current = m.toVersion;
      }
    }
  }

  Future<void> _runSingle(Migration m) async {
    if (!skipBackup) {
      await registry.backupAllBoxes(suffix: m.id);
    }
    final sw = Stopwatch()..start();
    await m.run(registry);
    // Basic validation: ensure counts unchanged for non-additive migrations (example for pending ops)
    if (m.id.contains('idempotency') ) {
      final box = registry.pendingOps();
      for (final op in box.values) {
        // simple assertion: idempotencyKey should not be empty now
        if (op.idempotencyKey.isEmpty) {
          throw Exception('Migration ${m.id} validation failed: empty idempotencyKey');
        }
      }
    }
    sw.stop();
    TelemetryService.I.time('migration.duration_ms', () => sw.elapsed, tags: {'id': m.id});
  }
}
