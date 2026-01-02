/// Health Data Repository — Hive Implementation
///
/// Local-first, offline-safe persistence for health data.
///
/// DESIGN PRINCIPLES:
/// 1. Composite keys for deduplication: {patientUid}_{readingType}_{ISO8601}
/// 2. All timestamps in UTC
/// 3. Prefix-based queries for efficient filtering
/// 4. Deterministic, idempotent writes
/// 5. SafeBoxOps for all Hive operations
///
/// FOLLOWS PROJECT PATTERNS FROM:
/// - VitalsRepositoryHive
/// - ChatRepositoryHive
/// - RelationshipRepositoryHive
library;

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../persistence/box_registry.dart';
import '../../persistence/errors/safe_box_ops.dart';
import '../../persistence/wrappers/box_accessor.dart';
import '../../services/telemetry_service.dart';
import '../models/normalized_health_data.dart';
import '../models/stored_health_reading.dart';
import 'health_data_repository.dart';

/// Shared instance getters (for DI without Riverpod).
BoxAccessor getSharedBoxAccessorInstance() => BoxAccess.I;
TelemetryService getSharedTelemetryInstance() => TelemetryService.I;

/// Hive-backed implementation of HealthDataRepository.
class HealthDataRepositoryHive implements HealthDataRepository {
  final BoxAccessor _boxAccessor;
  final TelemetryService _telemetry;

  HealthDataRepositoryHive({
    BoxAccessor? boxAccessor,
    TelemetryService? telemetry,
  })  : _boxAccessor = boxAccessor ?? getSharedBoxAccessorInstance(),
        _telemetry = telemetry ?? getSharedTelemetryInstance();

  /// Access the health readings box.
  Box<StoredHealthReading> get _box => _boxAccessor.healthReadings();

  // ═══════════════════════════════════════════════════════════════════════════
  // WRITE OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<StoredHealthReading?> saveHeartRate(NormalizedHeartRateReading reading) async {
    final stored = StoredHealthReading.fromHeartRate(
      patientUid: reading.patientUid,
      timestamp: reading.timestamp,
      bpm: reading.bpm,
      dataSource: reading.dataSource.name,
      deviceType: reading.deviceType.name,
      reliability: reading.reliability.name,
      isResting: reading.isResting,
    );

    return _saveWithDeduplication(stored);
  }

  @override
  Future<StoredHealthReading?> saveOxygenReading(NormalizedOxygenReading reading) async {
    final stored = StoredHealthReading.fromOxygen(
      patientUid: reading.patientUid,
      timestamp: reading.timestamp,
      percentage: reading.percentage,
      dataSource: reading.dataSource.name,
      deviceType: reading.deviceType.name,
      reliability: reading.reliability.name,
    );

    return _saveWithDeduplication(stored);
  }

  @override
  Future<StoredHealthReading?> saveSleepSession(NormalizedSleepSession session) async {
    // Convert segments to serializable format
    final segments = session.segments.map((seg) => {
      'startTime': seg.startTime.toUtc().toIso8601String(),
      'endTime': seg.endTime.toUtc().toIso8601String(),
      'stage': seg.stage.name,
    }).toList();

    final stored = StoredHealthReading.fromSleepSession(
      patientUid: session.patientUid,
      sleepStart: session.sleepStart,
      sleepEnd: session.sleepEnd,
      dataSource: session.dataSource.name,
      deviceType: session.deviceType.name,
      reliability: session.reliability.name,
      segments: segments,
      hasStageData: session.hasStageData,
    );

    return _saveWithDeduplication(stored);
  }

  @override
  Future<StoredHealthReading?> saveHRVReading(NormalizedHRVReading reading) async {
    final stored = StoredHealthReading.fromHRV(
      patientUid: reading.patientUid,
      timestamp: reading.timestamp,
      sdnnMs: reading.sdnnMs,
      dataSource: reading.dataSource.name,
      deviceType: reading.deviceType.name,
      reliability: reading.reliability.name,
      rrIntervals: reading.rrIntervals,
    );

    return _saveWithDeduplication(stored);
  }

  @override
  Future<BatchSaveResult> saveBatch(List<dynamic> readings) async {
    int saved = 0;
    int skipped = 0;
    int failed = 0;
    final errors = <String>[];
    final savedReadings = <StoredHealthReading>[];

    for (final reading in readings) {
      try {
        if (reading is NormalizedHeartRateReading) {
          final key = StoredHealthReading.generateKey(
            reading.patientUid,
            StoredHealthReadingType.heartRate,
            reading.timestamp,
          );
          if (_box.containsKey(key)) {
            skipped++;
          } else {
            final stored = await saveHeartRate(reading);
            if (stored != null) {
              saved++;
              savedReadings.add(stored);
            } else {
              skipped++;
            }
          }
        } else if (reading is NormalizedOxygenReading) {
          final key = StoredHealthReading.generateKey(
            reading.patientUid,
            StoredHealthReadingType.bloodOxygen,
            reading.timestamp,
          );
          if (_box.containsKey(key)) {
            skipped++;
          } else {
            final stored = await saveOxygenReading(reading);
            if (stored != null) {
              saved++;
              savedReadings.add(stored);
            } else {
              skipped++;
            }
          }
        } else if (reading is NormalizedSleepSession) {
          final key = StoredHealthReading.generateKey(
            reading.patientUid,
            StoredHealthReadingType.sleepSession,
            reading.sleepStart,
          );
          if (_box.containsKey(key)) {
            skipped++;
          } else {
            final stored = await saveSleepSession(reading);
            if (stored != null) {
              saved++;
              savedReadings.add(stored);
            } else {
              skipped++;
            }
          }
        } else if (reading is NormalizedHRVReading) {
          final key = StoredHealthReading.generateKey(
            reading.patientUid,
            StoredHealthReadingType.hrvReading,
            reading.timestamp,
          );
          if (_box.containsKey(key)) {
            skipped++;
          } else {
            final stored = await saveHRVReading(reading);
            if (stored != null) {
              saved++;
              savedReadings.add(stored);
            } else {
              skipped++;
            }
          }
        } else {
          failed++;
          errors.add('Unknown reading type: ${reading.runtimeType}');
        }
      } catch (e) {
        failed++;
        errors.add('Save failed: $e');
      }
    }

    _telemetry.gauge('health.batch.saved', saved);
    _telemetry.gauge('health.batch.skipped', skipped);
    _telemetry.gauge('health.batch.failed', failed);

    return BatchSaveResult(
      savedCount: saved,
      skippedCount: skipped,
      failedCount: failed,
      errors: errors,
      savedReadings: savedReadings,
    );
  }

  /// Internal: Save with deduplication check.
  ///
  /// Returns the saved [StoredHealthReading] if saved, null if deduplicated/invalid.
  Future<StoredHealthReading?> _saveWithDeduplication(StoredHealthReading stored) async {
    // Deduplication: check if key already exists
    if (_box.containsKey(stored.id)) {
      _telemetry.increment('health.save.deduplicated');
      debugPrint('[HealthRepo] Deduplicated: ${stored.id}');
      return null;
    }

    // Validate before saving
    if (!stored.isValid) {
      _telemetry.increment('health.save.invalid');
      debugPrint('[HealthRepo] Invalid reading: ${stored.id}');
      return null;
    }

    // Use SafeBoxOps for error handling
    final result = await SafeBoxOps.put(
      _box,
      stored.id,
      stored,
      boxName: BoxRegistry.healthReadingsBox,
    );

    if (result.isFailure) {
      _telemetry.increment('health.save.hive_error');
      debugPrint('[HealthRepo] Hive error: ${result.error}');
      throw result.error!;
    }

    _telemetry.increment('health.save.${stored.readingType.name}.success');
    debugPrint('[HealthRepo] Saved: ${stored.id}');

    return stored;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // READ OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<List<NormalizedHeartRateReading>> getHeartRates({
    required String patientUid,
    required DateTime start,
    required DateTime end,
  }) async {
    return _box.values
        .where((r) =>
            r.patientUid == patientUid &&
            r.readingType == StoredHealthReadingType.heartRate &&
            r.isInDateRange(start, end))
        .map(_toHeartRateReading)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  @override
  Future<List<NormalizedOxygenReading>> getOxygenReadings({
    required String patientUid,
    required DateTime start,
    required DateTime end,
  }) async {
    return _box.values
        .where((r) =>
            r.patientUid == patientUid &&
            r.readingType == StoredHealthReadingType.bloodOxygen &&
            r.isInDateRange(start, end))
        .map(_toOxygenReading)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  @override
  Future<List<NormalizedSleepSession>> getSleepSessions({
    required String patientUid,
    required DateTime start,
    required DateTime end,
  }) async {
    return _box.values
        .where((r) =>
            r.patientUid == patientUid &&
            r.readingType == StoredHealthReadingType.sleepSession &&
            r.isInDateRange(start, end))
        .map(_toSleepSession)
        .toList()
      ..sort((a, b) => b.sleepStart.compareTo(a.sleepStart));
  }

  @override
  Future<List<NormalizedHRVReading>> getHRVReadings({
    required String patientUid,
    required DateTime start,
    required DateTime end,
  }) async {
    return _box.values
        .where((r) =>
            r.patientUid == patientUid &&
            r.readingType == StoredHealthReadingType.hrvReading &&
            r.isInDateRange(start, end))
        .map(_toHRVReading)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  @override
  Future<StoredVitalsSnapshot> getLatestVitals(String patientUid) async {
    final readings = _getForPatient(patientUid);

    StoredHealthReading? latestHR;
    StoredHealthReading? latestO2;
    StoredHealthReading? latestHRV;
    StoredHealthReading? latestSleep;

    for (final r in readings) {
      switch (r.readingType) {
        case StoredHealthReadingType.heartRate:
          if (latestHR == null || r.recordedAt.isAfter(latestHR.recordedAt)) {
            latestHR = r;
          }
        case StoredHealthReadingType.bloodOxygen:
          if (latestO2 == null || r.recordedAt.isAfter(latestO2.recordedAt)) {
            latestO2 = r;
          }
        case StoredHealthReadingType.hrvReading:
          if (latestHRV == null || r.recordedAt.isAfter(latestHRV.recordedAt)) {
            latestHRV = r;
          }
        case StoredHealthReadingType.sleepSession:
          if (latestSleep == null || r.recordedAt.isAfter(latestSleep.recordedAt)) {
            latestSleep = r;
          }
      }
    }

    return StoredVitalsSnapshot(
      patientUid: patientUid,
      generatedAt: DateTime.now().toUtc(),
      latestHeartRate: latestHR,
      latestOxygen: latestO2,
      latestHRV: latestHRV,
      latestSleep: latestSleep,
    );
  }

  @override
  Future<List<StoredHealthReading>> getAllReadings(String patientUid) async {
    return _getForPatient(patientUid);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WATCH OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Stream<List<StoredHealthReading>> watchAllForPatient(String patientUid) async* {
    // Emit current state immediately
    yield _getForPatient(patientUid);

    // Then emit on every change
    yield* _box.watch().map((_) => _getForPatient(patientUid));
  }

  @override
  Stream<List<NormalizedHeartRateReading>> watchHeartRates(String patientUid) async* {
    // Emit current state immediately
    yield _getHeartRatesSync(patientUid);

    // Then emit on every change
    yield* _box.watch().map((_) => _getHeartRatesSync(patientUid));
  }

  @override
  Stream<StoredVitalsSnapshot> watchLatestVitals(String patientUid) async* {
    // Emit current state immediately
    yield await getLatestVitals(patientUid);

    // Then emit on every change
    await for (final _ in _box.watch()) {
      yield await getLatestVitals(patientUid);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MAINTENANCE OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<int> pruneExpired({required int retentionDays}) async {
    final cutoff = DateTime.now().toUtc().subtract(Duration(days: retentionDays));
    final toDelete = <String>[];

    for (final key in _box.keys) {
      final reading = _box.get(key);
      if (reading != null && reading.recordedAt.isBefore(cutoff)) {
        toDelete.add(key as String);
      }
    }

    if (toDelete.isEmpty) {
      return 0;
    }

    // Delete in batches to avoid blocking
    for (final key in toDelete) {
      await _box.delete(key);
    }

    _telemetry.increment('health.prune.count', toDelete.length);
    debugPrint('[HealthRepo] Pruned ${toDelete.length} expired readings');

    return toDelete.length;
  }

  @override
  Future<HealthStorageStats> getStats(String patientUid) async {
    final readings = _getForPatient(patientUid);

    int heartRateCount = 0;
    int oxygenCount = 0;
    int sleepCount = 0;
    int hrvCount = 0;
    DateTime? oldest;
    DateTime? newest;

    for (final r in readings) {
      switch (r.readingType) {
        case StoredHealthReadingType.heartRate:
          heartRateCount++;
        case StoredHealthReadingType.bloodOxygen:
          oxygenCount++;
        case StoredHealthReadingType.sleepSession:
          sleepCount++;
        case StoredHealthReadingType.hrvReading:
          hrvCount++;
      }

      if (oldest == null || r.recordedAt.isBefore(oldest)) {
        oldest = r.recordedAt;
      }
      if (newest == null || r.recordedAt.isAfter(newest)) {
        newest = r.recordedAt;
      }
    }

    return HealthStorageStats(
      totalReadings: readings.length,
      heartRateCount: heartRateCount,
      oxygenCount: oxygenCount,
      sleepCount: sleepCount,
      hrvCount: hrvCount,
      oldestReading: oldest,
      newestReading: newest,
    );
  }

  @override
  Future<void> deleteAllForPatient(String patientUid) async {
    final toDelete = _box.keys
        .where((key) => (key as String).startsWith('${patientUid}_'))
        .toList();

    if (toDelete.isEmpty) {
      return;
    }

    await _box.deleteAll(toDelete);

    _telemetry.increment('health.delete_all.count', toDelete.length);
    debugPrint('[HealthRepo] Deleted ${toDelete.length} readings for $patientUid');
  }

  @override
  Future<bool> hasReadings(String patientUid) async {
    return _box.keys.any((key) => (key as String).startsWith('${patientUid}_'));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get all readings for a patient, sorted by recordedAt descending.
  List<StoredHealthReading> _getForPatient(String patientUid) {
    return _box.values
        .where((r) => r.patientUid == patientUid)
        .toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }

  /// Sync version for stream mapping.
  List<NormalizedHeartRateReading> _getHeartRatesSync(String patientUid) {
    return _box.values
        .where((r) =>
            r.patientUid == patientUid &&
            r.readingType == StoredHealthReadingType.heartRate)
        .map(_toHeartRateReading)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONVERSION HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  NormalizedHeartRateReading _toHeartRateReading(StoredHealthReading stored) {
    return NormalizedHeartRateReading(
      patientUid: stored.patientUid,
      timestamp: stored.recordedAt,
      bpm: stored.data['bpm'] as int? ?? 0,
      dataSource: _parseDataSource(stored.dataSource),
      deviceType: _parseDeviceType(stored.deviceType),
      reliability: _parseReliability(stored.reliability),
      isResting: stored.data['isResting'] as bool? ?? false,
    );
  }

  NormalizedOxygenReading _toOxygenReading(StoredHealthReading stored) {
    return NormalizedOxygenReading(
      patientUid: stored.patientUid,
      timestamp: stored.recordedAt,
      percentage: stored.data['percentage'] as int? ?? 0,
      dataSource: _parseDataSource(stored.dataSource),
      deviceType: _parseDeviceType(stored.deviceType),
      reliability: _parseReliability(stored.reliability),
    );
  }

  NormalizedSleepSession _toSleepSession(StoredHealthReading stored) {
    final data = stored.data;
    final sleepStart = DateTime.tryParse(data['sleepStart'] as String? ?? '')?.toUtc() ??
        stored.recordedAt;
    final sleepEnd = DateTime.tryParse(data['sleepEnd'] as String? ?? '')?.toUtc() ??
        stored.recordedAt.add(const Duration(hours: 8));

    // Parse segments
    final segmentsData = data['segments'] as List<dynamic>?;
    final segments = <NormalizedSleepSegment>[];
    if (segmentsData != null) {
      for (final seg in segmentsData) {
        if (seg is Map<String, dynamic>) {
          final startTime =
              DateTime.tryParse(seg['startTime'] as String? ?? '')?.toUtc();
          final endTime =
              DateTime.tryParse(seg['endTime'] as String? ?? '')?.toUtc();
          final stageName = seg['stage'] as String? ?? 'unknown';
          final stage = NormalizedSleepStage.values.firstWhere(
            (s) => s.name == stageName,
            orElse: () => NormalizedSleepStage.unknown,
          );

          if (startTime != null && endTime != null) {
            segments.add(NormalizedSleepSegment(
              startTime: startTime,
              endTime: endTime,
              stage: stage,
            ));
          }
        }
      }
    }

    return NormalizedSleepSession(
      patientUid: stored.patientUid,
      sleepStart: sleepStart,
      sleepEnd: sleepEnd,
      segments: segments,
      dataSource: _parseDataSource(stored.dataSource),
      deviceType: _parseDeviceType(stored.deviceType),
      reliability: _parseReliability(stored.reliability),
      hasStageData: data['hasStageData'] as bool? ?? segments.isNotEmpty,
    );
  }

  NormalizedHRVReading _toHRVReading(StoredHealthReading stored) {
    final rrData = stored.data['rrIntervals'] as List<dynamic>?;
    final rrIntervals = rrData?.cast<int>();

    return NormalizedHRVReading(
      patientUid: stored.patientUid,
      timestamp: stored.recordedAt,
      sdnnMs: (stored.data['sdnnMs'] as num?)?.toDouble() ?? 0.0,
      dataSource: _parseDataSource(stored.dataSource),
      deviceType: _parseDeviceType(stored.deviceType),
      reliability: _parseReliability(stored.reliability),
      rrIntervals: rrIntervals,
    );
  }

  HealthDataSource _parseDataSource(String value) {
    return HealthDataSource.values.firstWhere(
      (e) => e.name == value,
      orElse: () => HealthDataSource.unknown,
    );
  }

  DetectedDeviceType _parseDeviceType(String value) {
    return DetectedDeviceType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => DetectedDeviceType.unknown,
    );
  }

  DataReliability _parseReliability(String value) {
    return DataReliability.values.firstWhere(
      (e) => e.name == value,
      orElse: () => DataReliability.medium,
    );
  }
}
