import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:guardian_angel_fyp/persistence/box_registry.dart';
import 'package:guardian_angel_fyp/models/vitals_model.dart';
import 'package:guardian_angel_fyp/models/settings_model.dart';
import 'package:guardian_angel_fyp/persistence/adapters/vitals_adapter.dart';
import 'package:guardian_angel_fyp/persistence/adapters/settings_adapter.dart';
import 'package:guardian_angel_fyp/services/ttl_compaction_service.dart';

void main() {
  setUp(() async {
    await setUpTestHive();
    if (!Hive.isAdapterRegistered(VitalsAdapter().typeId)) {
      Hive.registerAdapter(VitalsAdapter());
    }
    if (!Hive.isAdapterRegistered(SettingsModelAdapter().typeId)) {
      Hive.registerAdapter(SettingsModelAdapter());
    }
    await Hive.openBox<VitalsModel>(BoxRegistry.vitalsBox);
    await Hive.openBox<SettingsModel>(BoxRegistry.settingsBox);
    await Hive.openBox(BoxRegistry.pendingOpsBox); // for low activity check
  });

  tearDown(() async {
    await tearDownTestHive();
  });

  test('purgeVitals removes entries older than retention', () async {
    final vitalsBox = Hive.box<VitalsModel>(BoxRegistry.vitalsBox);
    final settingsBox = Hive.box<SettingsModel>(BoxRegistry.settingsBox);
    await settingsBox.put('settings', SettingsModel(
      notificationsEnabled: true,
      vitalsRetentionDays: 30,
      updatedAt: DateTime.now().toUtc(),
    ));
    final now = DateTime.now().toUtc();
    // old entry (60 days ago)
    final old = VitalsModel(
      id: 'old1',
      userId: 'u1',
      heartRate: 70,
      systolicBp: 120,
      diastolicBp: 80,
      temperatureC: 36.6,
      oxygenPercent: 98,
      stressIndex: null,
      recordedAt: now.subtract(const Duration(days: 60)),
      createdAt: now.subtract(const Duration(days: 60)),
      updatedAt: now.subtract(const Duration(days: 60)),
      modelVersion: 2,
    );
    final fresh = VitalsModel(
      id: 'fresh1',
      userId: 'u1',
      heartRate: 72,
      systolicBp: 118,
      diastolicBp: 78,
      temperatureC: 36.7,
      oxygenPercent: 99,
      stressIndex: null,
      recordedAt: now.subtract(const Duration(days: 5)),
      createdAt: now.subtract(const Duration(days: 5)),
      updatedAt: now.subtract(const Duration(days: 5)),
      modelVersion: 2,
    );
    await vitalsBox.put(old.id, old);
    await vitalsBox.put(fresh.id, fresh);
    expect(vitalsBox.length, 2);
    final svc = TtlCompactionService();
    final purged = await svc.purgeVitals();
    expect(purged, 1);
    expect(vitalsBox.length, 1);
    expect(vitalsBox.get('fresh1'), isNotNull);
  });

  test('maybeCompact reduces file size when threshold exceeded', () async {
    final vitalsBox = Hive.box<VitalsModel>(BoxRegistry.vitalsBox);
    final now = DateTime.now().toUtc();
    // Insert many entries then delete most to create free pages.
    for (int i = 0; i < 400; i++) {
      final v = VitalsModel(
        id: 'v$i',
        userId: 'u1',
        heartRate: 70 + (i % 5),
        systolicBp: 110 + (i % 10),
        diastolicBp: 70 + (i % 7),
        temperatureC: 36.5 + (i % 3) * 0.1,
        oxygenPercent: 95 + (i % 4),
        stressIndex: null,
        recordedAt: now,
        createdAt: now,
        updatedAt: now,
        modelVersion: 2,
      );
      await vitalsBox.put(v.id, v);
    }
    // Delete most entries to create fragmentation.
    for (int i = 0; i < 300; i++) {
      await vitalsBox.delete('v$i');
    }
    final path = vitalsBox.path;
    expect(path, isNotNull);
    final file = File(path!);
    final before = file.lengthSync();
    // Force threshold very low to trigger compaction.
    final svc = TtlCompactionService(compactionSizeThresholdBytes: 4 * 1024, lowActivityPendingThreshold: 1000);
    final compacted = await svc.maybeCompact();
    final after = file.lengthSync();
    expect(compacted, isTrue);
    expect(after < before, isTrue);
  });
}