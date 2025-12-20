import 'dart:io';
import 'package:hive/hive.dart';
import '../persistence/box_registry.dart';
import '../models/vitals_model.dart';
import '../models/settings_model.dart';
import '../services/telemetry_service.dart';
import '../persistence/wrappers/box_accessor.dart';

class TtlCompactionService {
  final int defaultRetentionDays;
  final int compactionSizeThresholdBytes; // trigger if > threshold
  final int lowActivityPendingThreshold;
  final TelemetryService _telemetry;

  TtlCompactionService({
    this.defaultRetentionDays = 365,
    this.compactionSizeThresholdBytes = 512 * 1024,
    this.lowActivityPendingThreshold = 5,
    TelemetryService? telemetry,
  }) : _telemetry = telemetry ?? TelemetryService.I;

  /// Static convenience method for bootstrap - run TTL purge and compaction if needed.
  ///
  /// Safe to call on every startup; will only compact if conditions are met.
  /// Returns a summary of what was done.
  static Future<Map<String, dynamic>> runIfNeeded({
    int? retentionDays,
    int? compactionThresholdBytes,
  }) async {
    final telemetry = TelemetryService.I;
    
    // Check if vitals box is open before attempting maintenance
    if (!Hive.isBoxOpen(BoxRegistry.vitalsBox)) {
      telemetry.increment('ttl_compaction.skipped.vitals_not_open');
      return {'skipped': true, 'reason': 'vitals_box_not_open'};
    }
    
    if (!Hive.isBoxOpen(BoxRegistry.settingsBox)) {
      telemetry.increment('ttl_compaction.skipped.settings_not_open');
      return {'skipped': true, 'reason': 'settings_box_not_open'};
    }
    
    final service = TtlCompactionService(
      defaultRetentionDays: retentionDays ?? 365,
      compactionSizeThresholdBytes: compactionThresholdBytes ?? 512 * 1024,
    );
    
    final sw = Stopwatch()..start();
    final result = await service.runMaintenance();
    sw.stop();
    
    telemetry.time('ttl_compaction.startup_duration_ms', () => sw.elapsed);
    
    if ((result['purged'] as int) > 0 || (result['compacted'] as bool)) {
      print('[TtlCompactionService] Startup maintenance: purged ${result['purged']} records, compacted: ${result['compacted']} (${sw.elapsedMilliseconds}ms)');
    }
    
    return result;
  }

  Box<VitalsModel> _vitals() => BoxAccess.I.vitals();
  Box<SettingsModel> _settings() => BoxAccess.I.settings();
  Box _pendingOps() => BoxAccess.I.pendingOps();

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
    _telemetry.gauge('vitals.count', box.length);
    _telemetry.increment('vitals.purged.count', toDelete.length);
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
    _telemetry.time('vitals.compact.duration_ms', () => sw.elapsed);
    _telemetry.gauge('vitals.compact.before_bytes', before);
    _telemetry.gauge('vitals.compact.after_bytes', after);
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