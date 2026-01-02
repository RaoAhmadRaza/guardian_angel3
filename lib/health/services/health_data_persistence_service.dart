/// Health Data Persistence Service — Extract + Store + Sync Orchestrator
///
/// This service orchestrates the flow:
/// PatientHealthExtractionService → StoredHealthReading → HealthDataRepository
///                                                      ↓
///                                          HealthFirestoreService (fire-and-forget)
///
/// SCOPE RULES:
/// ✅ Fetch from extraction service (read-only from OS)
/// ✅ Persist to local Hive box (encrypted)
/// ✅ Trigger Firestore mirror (non-blocking, fire-and-forget)
/// ✅ Return structured results with success/failure info
/// ❌ NO background workers
/// ❌ NO BLE / direct device access
///
/// SYNC PRINCIPLES:
/// - Hive is ALWAYS source of truth
/// - Firestore sync is fire-and-forget (errors logged, never thrown)
/// - UI NEVER blocks on Firestore operations
/// - Sync failures do NOT affect persistence result
///
/// DESIGN:
/// - Single responsibility: coordinate extract → persist → (async mirror) flow
/// - Handle partial failures gracefully (some types succeed, some fail)
/// - Idempotent: re-extracts deduplicate via composite key
library;

import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/stored_health_reading.dart';
import '../repositories/health_data_repository.dart';
import 'health_firestore_service.dart';
import 'patient_health_extraction_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// PERSISTENCE RESULT
// ═══════════════════════════════════════════════════════════════════════════

/// Result of a fetch-and-persist operation.
class HealthPersistenceResult {
  /// Whether the overall operation succeeded (at least partial data saved)
  final bool success;

  /// Summary of what was persisted
  final HealthPersistenceSummary summary;

  /// Any errors encountered during extraction or persistence
  final List<HealthPersistenceError> errors;

  /// Debug message
  final String message;

  const HealthPersistenceResult({
    required this.success,
    required this.summary,
    required this.errors,
    required this.message,
  });

  /// Factory for complete failure
  factory HealthPersistenceResult.failure(String reason) {
    return HealthPersistenceResult(
      success: false,
      summary: HealthPersistenceSummary.empty(),
      errors: [HealthPersistenceError(type: 'general', message: reason)],
      message: reason,
    );
  }

  /// Factory for partial success
  factory HealthPersistenceResult.partial({
    required HealthPersistenceSummary summary,
    required List<HealthPersistenceError> errors,
  }) {
    return HealthPersistenceResult(
      success: summary.totalPersisted > 0 || errors.isEmpty,
      summary: summary,
      errors: errors,
      message: errors.isEmpty
          ? 'Success: ${summary.totalPersisted} readings persisted'
          : 'Partial success: ${summary.totalPersisted} readings persisted, '
              '${errors.length} errors',
    );
  }

  /// Check if any data was persisted
  bool get hasData => summary.totalPersisted > 0;

  /// Check if there were any errors
  bool get hasErrors => errors.isNotEmpty;
}

/// Summary of persisted readings by type.
class HealthPersistenceSummary {
  /// Number of heart rate readings persisted
  final int heartRateCount;

  /// Number of SpO₂ readings persisted
  final int oxygenCount;

  /// Number of sleep sessions persisted
  final int sleepCount;

  /// Number of HRV readings persisted
  final int hrvCount;

  /// Number of duplicates skipped (already existed)
  final int duplicatesSkipped;

  /// When persistence completed
  final DateTime completedAt;

  const HealthPersistenceSummary({
    required this.heartRateCount,
    required this.oxygenCount,
    required this.sleepCount,
    required this.hrvCount,
    required this.duplicatesSkipped,
    required this.completedAt,
  });

  /// Empty summary factory
  factory HealthPersistenceSummary.empty() => HealthPersistenceSummary(
        heartRateCount: 0,
        oxygenCount: 0,
        sleepCount: 0,
        hrvCount: 0,
        duplicatesSkipped: 0,
        completedAt: DateTime.now().toUtc(),
      );

  /// Total readings persisted
  int get totalPersisted =>
      heartRateCount + oxygenCount + sleepCount + hrvCount;
}

/// Error details for persistence operations.
class HealthPersistenceError {
  /// Type of error (extraction, persistence, validation)
  final String type;

  /// Human-readable error message
  final String message;

  /// Data type that failed (if applicable)
  final StoredHealthReadingType? dataType;

  const HealthPersistenceError({
    required this.type,
    required this.message,
    this.dataType,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// PERSISTENCE SERVICE
// ═══════════════════════════════════════════════════════════════════════════

/// Orchestrates health data extraction, local persistence, and cloud sync.
///
/// Usage:
/// ```dart
/// final service = HealthDataPersistenceService(repository);
/// final result = await service.fetchAndPersistVitals(patientUid: 'abc123');
/// if (result.success) {
///   print('Saved ${result.summary.totalPersisted} readings');
///   // Note: Firestore sync happens in background (fire-and-forget)
/// }
/// ```
class HealthDataPersistenceService {
  final HealthDataRepository _repository;
  final PatientHealthExtractionService _extractionService;
  final HealthFirestoreService _firestoreService;

  /// Control whether Firestore sync is enabled.
  /// Can be disabled for testing or offline-only mode.
  bool firestoreSyncEnabled;

  HealthDataPersistenceService({
    required HealthDataRepository repository,
    PatientHealthExtractionService? extractionService,
    HealthFirestoreService? firestoreService,
    this.firestoreSyncEnabled = true,
  })  : _repository = repository,
        _extractionService =
            extractionService ?? PatientHealthExtractionService.instance,
        _firestoreService = firestoreService ?? HealthFirestoreService.instance;

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC API — FETCH + PERSIST
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fetch recent vitals from OS health store and persist locally.
  ///
  /// This is the primary method for refreshing local health data.
  /// It handles partial failures gracefully.
  ///
  /// [patientUid] — Firebase UID for the patient
  /// [windowMinutes] — How far back to fetch (default: 60 minutes)
  /// [includeSleep] — Whether to include sleep data (default: true)
  ///
  /// Firestore sync is triggered automatically after Hive persistence
  /// (fire-and-forget, errors logged but never thrown).
  ///
  /// Returns [HealthPersistenceResult] with details of what was saved.
  Future<HealthPersistenceResult> fetchAndPersistVitals({
    required String patientUid,
    int windowMinutes = 60,
    bool includeSleep = true,
  }) async {
    final errors = <HealthPersistenceError>[];
    var heartRateCount = 0;
    var oxygenCount = 0;
    var hrvCount = 0;
    var sleepCount = 0;
    var duplicatesSkipped = 0;

    // Track persisted readings for Firestore sync
    final persistedReadings = <StoredHealthReading>[];

    // 1. Fetch vitals snapshot from extraction service
    final vitalsResult = await _extractionService.fetchRecentVitals(
      patientUid: patientUid,
      windowMinutes: windowMinutes,
    );

    if (!vitalsResult.success) {
      return HealthPersistenceResult.failure(
        'Extraction failed: ${vitalsResult.errorMessage ?? vitalsResult.errorCode.name}',
      );
    }

    final snapshot = vitalsResult.data;
    if (snapshot == null || !snapshot.hasAnyData) {
      return HealthPersistenceResult(
        success: true,
        summary: HealthPersistenceSummary.empty(),
        errors: [],
        message: 'No health data available from device',
      );
    }

    // 2. Persist heart rate using normalized object
    if (snapshot.hasHeartRate) {
      try {
        final reading = await _repository.saveHeartRate(snapshot.latestHeartRate!);
        heartRateCount++;
        if (reading != null) persistedReadings.add(reading);
      } catch (e) {
        errors.add(HealthPersistenceError(
          type: 'persistence',
          message: 'Error saving heart rate: $e',
          dataType: StoredHealthReadingType.heartRate,
        ));
      }
    }

    // 3. Persist SpO₂ using normalized object
    if (snapshot.hasOxygen) {
      try {
        final reading = await _repository.saveOxygenReading(snapshot.latestOxygen!);
        oxygenCount++;
        if (reading != null) persistedReadings.add(reading);
      } catch (e) {
        errors.add(HealthPersistenceError(
          type: 'persistence',
          message: 'Error saving SpO₂: $e',
          dataType: StoredHealthReadingType.bloodOxygen,
        ));
      }
    }

    // 4. Persist HRV using normalized object
    if (snapshot.hasHRV) {
      try {
        final reading = await _repository.saveHRVReading(snapshot.latestHRV!);
        hrvCount++;
        if (reading != null) persistedReadings.add(reading);
      } catch (e) {
        errors.add(HealthPersistenceError(
          type: 'persistence',
          message: 'Error saving HRV: $e',
          dataType: StoredHealthReadingType.hrvReading,
        ));
      }
    }

    // 5. Persist sleep session using normalized object
    if (includeSleep && snapshot.hasSleep) {
      try {
        final reading = await _repository.saveSleepSession(snapshot.lastSleepSession!);
        sleepCount++;
        if (reading != null) persistedReadings.add(reading);
      } catch (e) {
        errors.add(HealthPersistenceError(
          type: 'persistence',
          message: 'Error saving sleep: $e',
          dataType: StoredHealthReadingType.sleepSession,
        ));
      }
    }

    // 6. Trigger Firestore sync (fire-and-forget)
    if (firestoreSyncEnabled && persistedReadings.isNotEmpty) {
      _triggerFirestoreSync(persistedReadings);
    }

    // 7. Build result
    final summary = HealthPersistenceSummary(
      heartRateCount: heartRateCount,
      oxygenCount: oxygenCount,
      sleepCount: sleepCount,
      hrvCount: hrvCount,
      duplicatesSkipped: duplicatesSkipped,
      completedAt: DateTime.now().toUtc(),
    );

    return HealthPersistenceResult.partial(
      summary: summary,
      errors: errors,
    );
  }

  /// Batch persist multiple readings using the repository batch API.
  ///
  /// This is more efficient for historical backfills.
  /// Firestore sync is triggered after successful Hive persistence.
  Future<HealthPersistenceResult> persistBatch(List<dynamic> readings) async {
    final batchResult = await _repository.saveBatch(readings);

    final summary = HealthPersistenceSummary(
      heartRateCount: batchResult.savedCount,
      oxygenCount: 0, // Batch doesn't track per-type
      sleepCount: 0,
      hrvCount: 0,
      duplicatesSkipped: batchResult.skippedCount,
      completedAt: DateTime.now().toUtc(),
    );

    final errors = batchResult.errors
        .map((e) => HealthPersistenceError(type: 'persistence', message: e))
        .toList();

    // Trigger Firestore sync for saved readings (fire-and-forget)
    if (firestoreSyncEnabled && batchResult.savedReadings.isNotEmpty) {
      _triggerFirestoreSync(batchResult.savedReadings);
    }

    return HealthPersistenceResult.partial(
      summary: summary,
      errors: errors,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FIRESTORE SYNC (Fire-and-Forget)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Trigger Firestore sync without blocking.
  ///
  /// CRITICAL: This is fire-and-forget. Errors are logged but NEVER thrown.
  /// The UI must NEVER block on Firestore operations.
  void _triggerFirestoreSync(List<StoredHealthReading> readings) {
    if (readings.isEmpty) return;

    // Use unawaited to make intent clear - we don't wait for this
    unawaited(_performFirestoreSync(readings));
  }

  /// Perform the actual Firestore sync.
  ///
  /// Errors are caught and logged but never propagate.
  Future<void> _performFirestoreSync(List<StoredHealthReading> readings) async {
    try {
      debugPrint(
          '[HealthDataPersistenceService] Triggering Firestore sync for ${readings.length} readings');

      if (readings.length == 1) {
        // Single reading - use direct mirror
        await _firestoreService.mirrorReading(readings.first);
      } else {
        // Batch sync
        final result = await _firestoreService.mirrorBatch(readings);
        debugPrint(
            '[HealthDataPersistenceService] Firestore sync complete: '
            '${result.successCount} success, ${result.failureCount} failed');
      }
    } catch (e) {
      // CRITICAL: Log but NEVER rethrow
      // Firestore failures must not affect local operations
      debugPrint('[HealthDataPersistenceService] Firestore sync failed: $e');
    }
  }

  /// Manually sync all unsynced readings to Firestore.
  ///
  /// Returns sync status after operation.
  /// This is for manual "sync now" buttons in UI.
  Future<HealthSyncStatus> syncUnsyncedReadings({
    required String patientUid,
  }) async {
    try {
      // Get all local readings
      final allReadings = await _repository.getAllReadings(patientUid);
      if (allReadings.isEmpty) {
        return HealthSyncStatus.empty();
      }

      // Check which are already synced
      final syncedIds = await _firestoreService.getSyncedIds(patientUid);

      // Find unsynced readings
      final unsyncedReadings = allReadings
          .where((r) => !syncedIds.contains(r.id))
          .toList();

      if (unsyncedReadings.isEmpty) {
        return HealthSyncStatus(
          totalLocal: allReadings.length,
          syncedCount: allReadings.length,
          unsyncedCount: 0,
          lastSuccessfulSync: DateTime.now().toUtc(),
        );
      }

      // Sync unsynced readings
      final result = await _firestoreService.mirrorBatch(unsyncedReadings);

      return HealthSyncStatus(
        totalLocal: allReadings.length,
        syncedCount: syncedIds.length + result.successCount,
        unsyncedCount: unsyncedReadings.length - result.successCount,
        lastSyncAttempt: DateTime.now().toUtc(),
        lastSuccessfulSync:
            result.successCount > 0 ? DateTime.now().toUtc() : null,
      );
    } catch (e) {
      debugPrint('[HealthDataPersistenceService] Manual sync failed: $e');
      return HealthSyncStatus(
        totalLocal: -1,
        syncedCount: -1,
        unsyncedCount: -1,
        lastError: e.toString(),
      );
    }
  }

  /// Get current sync status.
  Future<HealthSyncStatus> getSyncStatus({
    required String patientUid,
  }) async {
    try {
      final allReadings = await _repository.getAllReadings(patientUid);
      if (allReadings.isEmpty) {
        return HealthSyncStatus.empty();
      }

      final localIds = allReadings.map((r) => r.id).toList();
      return _firestoreService.calculateSyncStatus(
        patientUid: patientUid,
        localIds: localIds,
      );
    } catch (e) {
      debugPrint('[HealthDataPersistenceService] Get sync status failed: $e');
      return HealthSyncStatus.unknown();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC API — LOCAL DATA ACCESS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get latest vitals snapshot from local storage.
  ///
  /// This returns data WITHOUT fetching from OS health store.
  /// Use for offline display / instant UI.
  Future<StoredVitalsSnapshot> getLocalSnapshot({
    required String patientUid,
  }) {
    return _repository.getLatestVitals(patientUid);
  }

  /// Watch local vitals changes.
  ///
  /// Returns a stream that emits whenever local health data changes.
  Stream<StoredVitalsSnapshot> watchLocalVitals({
    required String patientUid,
  }) {
    return _repository.watchLatestVitals(patientUid);
  }

  /// Get storage statistics.
  Future<HealthStorageStats> getStorageStats({
    required String patientUid,
  }) {
    return _repository.getStats(patientUid);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC API — MAINTENANCE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Prune expired readings based on retention policy.
  ///
  /// Returns number of readings deleted.
  Future<int> pruneExpiredData({required int retentionDays}) {
    return _repository.pruneExpired(retentionDays: retentionDays);
  }

  /// Delete all data for a patient (GDPR compliance).
  ///
  /// IMPORTANT: Deletes from BOTH Hive (local) and Firestore (cloud).
  /// Order: Hive first, then Firestore (fire-and-forget for Firestore).
  ///
  /// [patientUid] — Firebase UID for the patient
  /// [deleteFromFirestore] — If true, also deletes from Firestore (default: true)
  Future<void> deletePatientData({
    required String patientUid,
    bool deleteFromFirestore = true,
  }) async {
    // 1. Delete from Hive FIRST (source of truth)
    await _repository.deleteAllForPatient(patientUid);

    // 2. Delete from Firestore (fire-and-forget)
    if (deleteFromFirestore && firestoreSyncEnabled) {
      _triggerFirestoreDelete(patientUid);
    }
  }

  /// Fire-and-forget Firestore deletion.
  void _triggerFirestoreDelete(String patientUid) {
    unawaited(_performFirestoreDelete(patientUid));
  }

  /// Perform actual Firestore deletion.
  Future<void> _performFirestoreDelete(String patientUid) async {
    try {
      debugPrint(
          '[HealthDataPersistenceService] GDPR: Deleting Firestore data for $patientUid');
      final deletedCount = await _firestoreService.deleteAllForPatient(patientUid);
      debugPrint(
          '[HealthDataPersistenceService] GDPR: Deleted $deletedCount documents from Firestore');
    } catch (e) {
      // Log but don't throw - Hive deletion already succeeded
      debugPrint('[HealthDataPersistenceService] GDPR Firestore delete failed: $e');
    }
  }

  /// Check if there is any locally stored data.
  Future<bool> hasLocalData({required String patientUid}) {
    return _repository.hasReadings(patientUid);
  }
}
