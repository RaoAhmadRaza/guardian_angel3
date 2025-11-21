import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:guardian_angel_fyp/persistence/migrations/migration_runner.dart';
import 'package:guardian_angel_fyp/persistence/migrations/migration_registry.dart';
import 'package:guardian_angel_fyp/persistence/meta/meta_store.dart';
import 'package:guardian_angel_fyp/persistence/box_registry.dart';
import 'package:guardian_angel_fyp/persistence/adapters/vitals_adapter.dart';
import 'package:guardian_angel_fyp/models/vitals_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await setUpTestHive();
    Hive.registerAdapter(VitalsAdapter());
    await Hive.openBox(BoxRegistry.metaBox);
    await Hive.openBox<VitalsModel>(BoxRegistry.vitalsBox);
    final meta = MetaStore(Hive.box(BoxRegistry.metaBox));
    await meta.setSchemaVersion('core', 1); // start before migration 002
  });

  tearDown(() async {
    await tearDownTestHive();
  });

  test('migration 002 upgrades vitals schema', () async {
    final vitalsBox = Hive.box<VitalsModel>(BoxRegistry.vitalsBox);
    final v = VitalsModel(
      id: 'v1',
      userId: 'u1',
      heartRate: 72,
      systolicBp: 120,
      diastolicBp: 80,
      temperatureC: null,
      oxygenPercent: 98,
      stressIndex: null,
      recordedAt: DateTime.parse('2024-01-01T00:00:00Z'),
      schemaVersion: 1,
      createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
      updatedAt: DateTime.parse('2024-01-01T00:00:00Z'),
      modelVersion: 1,
    );
    await vitalsBox.put(v.id, v);

    final meta = MetaStore(Hive.box(BoxRegistry.metaBox));
    final runner = MigrationRunner(meta: meta, migrations: buildMigrationRegistry(), registry: BoxRegistry(), skipBackup: true);
    await runner.runAll();

    final updated = vitalsBox.get(v.id)!;
    expect(updated.stressIndex, isNotNull);
    expect(updated.modelVersion, 2);
    expect(meta.getSchemaVersion('core'), 2);
  });
}