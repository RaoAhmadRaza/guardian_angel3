import 'package:hive/hive.dart';
import '../../../models/vitals_model.dart';
import '../../box_registry.dart';

/// Migration 002: Ensure stressIndex field exists with default and upgrade modelVersion
Future<void> migration002UpgradeVitalsSchema(BoxRegistry registry) async {
  final box = Hive.box<VitalsModel>(BoxRegistry.vitalsBox);
  final entries = box.values.toList();
  for (final v in entries) {
    if (v.stressIndex == null) {
      final updated = v.copyWith(stressIndex: 0.0, modelVersion: 2, updatedAt: DateTime.now().toUtc());
      await box.put(v.id, updated);
    } else if (v.modelVersion < 2) {
      final updated = v.copyWith(modelVersion: 2, updatedAt: DateTime.now().toUtc());
      await box.put(v.id, updated);
    }
  }
}
