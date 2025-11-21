import 'dart:io';
import 'package:hive/hive.dart';
import '../persistence/box_registry.dart';
import '../models/vitals_model.dart';
import '../models/settings_model.dart';
import '../services/telemetry_service.dart';

class TtlCompactionService {
  final int defaultRetentionDays;
  final int compactionSizeThresholdBytes; // trigger if > threshold
  final int lowActivityPendingThreshold;

  TtlCompactionService({
    this.defaultRetentionDays = 365,
    this.compactionSizeThresholdBytes = 512 * 1024,
    this.lowActivityPendingThreshold = 5,
  });

  Box<VitalsModel> _vitals() => Hive.box<VitalsModel>(BoxRegistry.vitalsBox);
  Box<SettingsModel> _settings() => Hive.box<SettingsModel>(BoxRegistry.settingsBox);
  Box _pendingOps() => Hive.box(BoxRegistry.pendingOpsBox);

  int _settingsRetentionDays() {
    if (!_settings().isOpen || _settings().isEmpty) return defaultRetentionDays;
    final any = _settings().values.first;
    return any.vitalsRetentionDays;
  }

  Future<int> purgeVitals() async {
    final retentionDays = _settingsRetentionDays();
    final cutoff = DateTime.now().toUtc().subtract(Duration(days: retentionDays));
    final box = _vitals();
    final toDelete = <dynamic>[];
    for (final k in box.keys) {
      final v = box.get(k);
      if (v == null) continue;
      if (v.recordedAt.isBefore(cutoff)) {
        toDelete.add(k);
      }
    }
    for (final k in toDelete) {
      await box.delete(k);
    }
    TelemetryService.I.gauge('vitals.count', box.length);
    TelemetryService.I.increment('vitals.purged.count', toDelete.length);
    return toDelete.length;
  }

  bool _isLowActivity() {
    final pendingCount = _pendingOps().length;
    return pendingCount < lowActivityPendingThreshold;
  }

  Future<bool> maybeCompact() async {
    final vitalsPath = _vitals().path; // other boxes could be compacted similarly
    if (vitalsPath == null) return false;
    final file = File(vitalsPath);
    if (!file.existsSync()) return false;
    final size = file.lengthSync();
    if (size < compactionSizeThresholdBytes) return false;
    if (!_isLowActivity()) return false;
    final sw = Stopwatch()..start();
    final before = size;
    await _vitals().compact();
    sw.stop();
    final after = file.lengthSync();
    TelemetryService.I.time('vitals.compact.duration_ms', () => sw.elapsed);
    TelemetryService.I.gauge('vitals.compact.before_bytes', before);
    TelemetryService.I.gauge('vitals.compact.after_bytes', after);
    return after < before;
  }

  /// Run both purge and conditional compaction. Intended to be invoked
  /// when app returns to foreground or via a periodic scheduler.
  Future<Map<String, dynamic>> runMaintenance() async {
    final purged = await purgeVitals();
    final compacted = await maybeCompact();
    return {
      'purged': purged,
      'compacted': compacted,
    };
  }
}