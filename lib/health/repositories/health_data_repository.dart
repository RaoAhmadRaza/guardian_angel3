/// Health Data Repository — Interface
///
/// Defines the contract for local health data persistence.
/// Implementation is Hive-backed (HealthDataRepositoryHive).
///
/// SCOPE: Local persistence only. No Firestore, no sync.
///
/// DESIGN PRINCIPLES:
/// 1. All timestamps in UTC
/// 2. Deduplication by composite key
/// 3. TTL pruning by recorded timestamp
/// 4. GDPR-compliant deletion
library;

import '../models/normalized_health_data.dart';
import '../models/stored_health_reading.dart';

/// Repository interface for local health data persistence.
abstract class HealthDataRepository {
  // ═══════════════════════════════════════════════════════════════════════════
  // WRITE OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Persist a heart rate reading.
  ///
  /// Deduplicates by composite key (patientUid_heartRate_timestamp).
  /// If a reading with the same key exists, this is a no-op.
  ///
  /// Returns the persisted [StoredHealthReading] if saved, null if duplicate.
  Future<StoredHealthReading?> saveHeartRate(NormalizedHeartRateReading reading);

  /// Persist an SpO₂ reading.
  ///
  /// Deduplicates by composite key (patientUid_bloodOxygen_timestamp).
  /// Returns the persisted [StoredHealthReading] if saved, null if duplicate.
  Future<StoredHealthReading?> saveOxygenReading(NormalizedOxygenReading reading);

  /// Persist a sleep session.
  ///
  /// Deduplicates by composite key using sleep START time.
  /// Returns the persisted [StoredHealthReading] if saved, null if duplicate.
  Future<StoredHealthReading?> saveSleepSession(NormalizedSleepSession session);

  /// Persist an HRV reading.
  ///
  /// Deduplicates by composite key (patientUid_hrvReading_timestamp).
  /// Returns the persisted [StoredHealthReading] if saved, null if duplicate.
  Future<StoredHealthReading?> saveHRVReading(NormalizedHRVReading reading);

  /// Batch persist multiple readings.
  ///
  /// Each reading is deduplicated individually.
  /// Partial success is possible (some may be duplicates).
  Future<BatchSaveResult> saveBatch(List<dynamic> readings);

  // ═══════════════════════════════════════════════════════════════════════════
  // READ OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get heart rate readings for a patient in a date range.
  ///
  /// Returns readings sorted by timestamp descending (newest first).
  Future<List<NormalizedHeartRateReading>> getHeartRates({
    required String patientUid,
    required DateTime start,
    required DateTime end,
  });

  /// Get SpO₂ readings for a patient in a date range.
  Future<List<NormalizedOxygenReading>> getOxygenReadings({
    required String patientUid,
    required DateTime start,
    required DateTime end,
  });

  /// Get sleep sessions for a patient in a date range.
  Future<List<NormalizedSleepSession>> getSleepSessions({
    required String patientUid,
    required DateTime start,
    required DateTime end,
  });

  /// Get HRV readings for a patient in a date range.
  Future<List<NormalizedHRVReading>> getHRVReadings({
    required String patientUid,
    required DateTime start,
    required DateTime end,
  });

  /// Get latest reading of each type for a patient.
  ///
  /// This is the primary method for UI "dashboard" views.
  Future<StoredVitalsSnapshot> getLatestVitals(String patientUid);

  /// Get all stored readings for a patient.
  Future<List<StoredHealthReading>> getAllReadings(String patientUid);

  // ═══════════════════════════════════════════════════════════════════════════
  // WATCH OPERATIONS (Reactive)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Watch all readings for a patient (real-time Hive updates).
  ///
  /// Emits current state immediately, then on every change.
  Stream<List<StoredHealthReading>> watchAllForPatient(String patientUid);

  /// Watch heart rates for a patient.
  Stream<List<NormalizedHeartRateReading>> watchHeartRates(String patientUid);

  /// Watch latest vitals snapshot for a patient.
  Stream<StoredVitalsSnapshot> watchLatestVitals(String patientUid);

  // ═══════════════════════════════════════════════════════════════════════════
  // MAINTENANCE OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Delete readings older than retention period.
  ///
  /// Uses recordedAt timestamp for age calculation.
  /// Returns number of readings deleted.
  Future<int> pruneExpired({required int retentionDays});

  /// Get storage statistics for a patient.
  Future<HealthStorageStats> getStats(String patientUid);

  /// Delete all readings for a patient (GDPR compliance).
  ///
  /// This is a destructive operation. Use with caution.
  Future<void> deleteAllForPatient(String patientUid);

  /// Check if any readings exist for a patient.
  Future<bool> hasReadings(String patientUid);
}

/// Result of a batch save operation.
class BatchSaveResult {
  /// Number of readings successfully saved.
  final int savedCount;

  /// Number of readings skipped (duplicates).
  final int skippedCount;

  /// Number of readings that failed to save.
  final int failedCount;

  /// Error messages for failed saves.
  final List<String> errors;

  /// The actual saved readings (for Firestore sync).
  final List<StoredHealthReading> savedReadings;

  const BatchSaveResult({
    required this.savedCount,
    required this.skippedCount,
    required this.failedCount,
    this.errors = const [],
    this.savedReadings = const [],
  });

  /// Total readings processed.
  int get totalProcessed => savedCount + skippedCount + failedCount;

  /// Whether all saves succeeded (including duplicates as "success").
  bool get allSucceeded => failedCount == 0;

  /// Whether any new readings were saved.
  bool get anySaved => savedCount > 0;
}
