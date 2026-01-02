/// Health Firestore Service — Local-First Mirror to Cloud
///
/// This service mirrors health readings from local Hive storage to Firestore.
///
/// CRITICAL ARCHITECTURAL RULES:
/// 1. Hive is ALWAYS the source of truth — Firestore is a non-blocking mirror
/// 2. All operations are fire-and-forget — errors NEVER propagate to UI
/// 3. Sync failures NEVER affect patient experience
/// 4. Idempotent — re-syncing same reading is always safe
///
/// Firestore Structure:
/// ```
/// patients/{patientUid}/health_readings/{readingId}
/// ```
///
/// Where `readingId` equals the Hive composite key:
/// `{patientUid}_{readingType}_{ISO8601TimestampUTC}`
///
/// SCOPE RULES:
/// ✅ Mirror Hive → Firestore (one-way)
/// ✅ Batch operations (≤500 per batch)
/// ✅ Idempotent via set(merge: true)
/// ✅ Telemetry instrumentation
/// ✅ GDPR deletion support
/// ❌ NO Firestore → Hive writes
/// ❌ NO conflict resolution (local always wins)
/// ❌ NO UI blocking
/// ❌ NO background workers (Step 4)
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../services/telemetry_service.dart';
import '../models/stored_health_reading.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SYNC RESULT MODELS
// ═══════════════════════════════════════════════════════════════════════════

/// Result of a single mirror operation.
class MirrorResult {
  final bool success;
  final String? error;
  final String readingId;

  const MirrorResult({
    required this.success,
    required this.readingId,
    this.error,
  });

  factory MirrorResult.success(String readingId) =>
      MirrorResult(success: true, readingId: readingId);

  factory MirrorResult.failure(String readingId, String error) =>
      MirrorResult(success: false, readingId: readingId, error: error);
}

/// Result of a batch mirror operation.
class BatchMirrorResult {
  final int successCount;
  final int failureCount;
  final int skippedCount;
  final List<String> failedIds;
  final Duration elapsed;

  const BatchMirrorResult({
    required this.successCount,
    required this.failureCount,
    required this.skippedCount,
    required this.failedIds,
    required this.elapsed,
  });

  int get totalProcessed => successCount + failureCount + skippedCount;
  bool get hasFailures => failureCount > 0;
  bool get allSucceeded => failureCount == 0;
  double get successRate =>
      totalProcessed > 0 ? successCount / totalProcessed : 1.0;
}

/// Sync status for UI display.
class HealthSyncStatus {
  final int totalLocal;
  final int syncedCount;
  final int unsyncedCount;
  final int unknownCount;
  final DateTime? lastSyncAttempt;
  final DateTime? lastSuccessfulSync;
  final bool isSyncing;
  final String? lastError;

  const HealthSyncStatus({
    required this.totalLocal,
    required this.syncedCount,
    required this.unsyncedCount,
    this.unknownCount = 0,
    this.lastSyncAttempt,
    this.lastSuccessfulSync,
    this.isSyncing = false,
    this.lastError,
  });

  factory HealthSyncStatus.empty() => const HealthSyncStatus(
        totalLocal: 0,
        syncedCount: 0,
        unsyncedCount: 0,
      );

  factory HealthSyncStatus.unknown() => const HealthSyncStatus(
        totalLocal: -1,
        syncedCount: -1,
        unsyncedCount: -1,
        unknownCount: -1,
      );

  bool get isFullySynced => unsyncedCount == 0 && totalLocal >= 0;
  bool get hasUnsynced => unsyncedCount > 0;
  bool get isUnknown => totalLocal < 0;

  double get syncProgress {
    if (totalLocal <= 0) return 1.0;
    return syncedCount / totalLocal;
  }

  HealthSyncStatus copyWith({
    int? totalLocal,
    int? syncedCount,
    int? unsyncedCount,
    int? unknownCount,
    DateTime? lastSyncAttempt,
    DateTime? lastSuccessfulSync,
    bool? isSyncing,
    String? lastError,
  }) {
    return HealthSyncStatus(
      totalLocal: totalLocal ?? this.totalLocal,
      syncedCount: syncedCount ?? this.syncedCount,
      unsyncedCount: unsyncedCount ?? this.unsyncedCount,
      unknownCount: unknownCount ?? this.unknownCount,
      lastSyncAttempt: lastSyncAttempt ?? this.lastSyncAttempt,
      lastSuccessfulSync: lastSuccessfulSync ?? this.lastSuccessfulSync,
      isSyncing: isSyncing ?? this.isSyncing,
      lastError: lastError,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// RETRY CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════

/// Configuration for retry behavior.
class SyncRetryConfig {
  /// Maximum number of retry attempts per reading.
  final int maxRetries;

  /// Base delay for exponential backoff (milliseconds).
  final int baseDelayMs;

  /// Maximum delay cap (milliseconds).
  final int maxDelayMs;

  /// Jitter factor (0.0 - 1.0) to randomize delays.
  final double jitterFactor;

  const SyncRetryConfig({
    this.maxRetries = 3,
    this.baseDelayMs = 1000,
    this.maxDelayMs = 30000,
    this.jitterFactor = 0.2,
  });

  /// Calculate delay for a given retry attempt (0-indexed).
  Duration getDelay(int attempt) {
    // Exponential backoff: base * 2^attempt
    final exponentialDelay = baseDelayMs * math.pow(2, attempt).toInt();
    final cappedDelay = math.min(exponentialDelay, maxDelayMs);

    // Add jitter
    final jitter = (cappedDelay * jitterFactor * (math.Random().nextDouble() - 0.5)).toInt();
    final finalDelay = cappedDelay + jitter;

    return Duration(milliseconds: finalDelay.clamp(0, maxDelayMs));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HEALTH FIRESTORE SERVICE
// ═══════════════════════════════════════════════════════════════════════════

/// Mirrors health readings from Hive to Firestore.
///
/// This service provides:
/// - Single reading mirror
/// - Batch mirror (≤500 per batch)
/// - Exponential backoff retry
/// - Telemetry tracking
/// - GDPR deletion
///
/// Usage:
/// ```dart
/// // Mirror a single reading
/// await HealthFirestoreService.instance.mirrorReading(reading);
///
/// // Mirror multiple readings
/// final result = await HealthFirestoreService.instance.mirrorBatch(readings);
/// print('Synced ${result.successCount} readings');
/// ```
class HealthFirestoreService {
  // ═══════════════════════════════════════════════════════════════════════════
  // SINGLETON
  // ═══════════════════════════════════════════════════════════════════════════

  HealthFirestoreService._();

  static final HealthFirestoreService _instance = HealthFirestoreService._();
  static HealthFirestoreService get instance => _instance;

  /// Factory constructor for dependency injection (testing).
  factory HealthFirestoreService.withDependencies({
    FirebaseFirestore? firestore,
    TelemetryService? telemetry,
    SyncRetryConfig? retryConfig,
  }) {
    final service = HealthFirestoreService._();
    if (firestore != null) service._firestore = firestore;
    if (telemetry != null) service._telemetry = telemetry;
    if (retryConfig != null) service._retryConfig = retryConfig;
    return service;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DEPENDENCIES
  // ═══════════════════════════════════════════════════════════════════════════

  FirebaseFirestore _firestore = FirebaseFirestore.instance;
  TelemetryService _telemetry = TelemetryService.I;
  SyncRetryConfig _retryConfig = const SyncRetryConfig();

  // ═══════════════════════════════════════════════════════════════════════════
  // RETRY STATE (in-memory, transient)
  // ═══════════════════════════════════════════════════════════════════════════

  final Map<String, int> _retryAttempts = {};
  final Map<String, DateTime> _nextRetryTime = {};

  // ═══════════════════════════════════════════════════════════════════════════
  // COLLECTION REFERENCES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get health readings collection for a patient.
  ///
  /// Path: `patients/{patientUid}/health_readings`
  CollectionReference<Map<String, dynamic>> _healthReadingsCollection(
      String patientUid) {
    return _firestore
        .collection('patients')
        .doc(patientUid)
        .collection('health_readings');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MIRROR OPERATIONS (Fire-and-Forget)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Mirror a single health reading to Firestore.
  ///
  /// NON-BLOCKING. Errors are logged but NEVER propagate.
  /// Uses `set(merge: true)` for idempotent create/update.
  ///
  /// The document ID in Firestore equals the Hive composite key,
  /// ensuring re-syncing is always safe.
  Future<MirrorResult> mirrorReading(StoredHealthReading reading) async {
    final readingId = reading.id;
    debugPrint('[HealthFirestoreService] Mirroring: $readingId');
    _telemetry.increment('health.firestore.mirror.attempt');

    try {
      // Check if we should wait (backoff)
      if (!_isEligibleForSync(readingId)) {
        debugPrint('[HealthFirestoreService] Skipping (backoff): $readingId');
        _telemetry.increment('health.firestore.mirror.backoff_skipped');
        return MirrorResult.failure(readingId, 'In backoff period');
      }

      // Build Firestore document data
      final docData = _buildFirestoreDocument(reading);

      // Write to Firestore with merge (idempotent)
      await _healthReadingsCollection(reading.patientUid)
          .doc(readingId)
          .set(docData, SetOptions(merge: true));

      // Success — clear retry state
      _clearRetryState(readingId);

      debugPrint('[HealthFirestoreService] Mirror success: $readingId');
      _telemetry.increment('health.firestore.mirror.success');
      return MirrorResult.success(readingId);
    } catch (e) {
      // Handle failure with retry tracking
      _recordFailure(readingId);

      debugPrint('[HealthFirestoreService] Mirror failed: $e');
      _telemetry.increment('health.firestore.mirror.error');

      // NEVER rethrow — Firestore failures must not affect local operations
      return MirrorResult.failure(readingId, e.toString());
    }
  }

  /// Mirror multiple readings in optimized batches.
  ///
  /// Firestore batch limit is 500 operations.
  /// Returns detailed result with success/failure counts.
  ///
  /// [readings] — Readings to mirror
  /// [continueOnError] — If true, continue with remaining batches on failure
  Future<BatchMirrorResult> mirrorBatch(
    List<StoredHealthReading> readings, {
    bool continueOnError = true,
  }) async {
    final stopwatch = Stopwatch()..start();

    if (readings.isEmpty) {
      return BatchMirrorResult(
        successCount: 0,
        failureCount: 0,
        skippedCount: 0,
        failedIds: [],
        elapsed: Duration.zero,
      );
    }

    debugPrint('[HealthFirestoreService] Batch mirror: ${readings.length} readings');
    _telemetry.increment('health.firestore.batch.attempt');
    _telemetry.gauge('health.firestore.batch.size', readings.length);

    int successCount = 0;
    int failureCount = 0;
    int skippedCount = 0;
    final failedIds = <String>[];

    // Firestore batch limit
    const batchSize = 500;

    // Process in chunks
    for (var i = 0; i < readings.length; i += batchSize) {
      final chunk = readings.skip(i).take(batchSize).toList();
      final eligibleReadings = <StoredHealthReading>[];

      // Filter out readings in backoff
      for (final reading in chunk) {
        if (_isEligibleForSync(reading.id)) {
          eligibleReadings.add(reading);
        } else {
          skippedCount++;
        }
      }

      if (eligibleReadings.isEmpty) continue;

      // Create batch
      final batch = _firestore.batch();

      for (final reading in eligibleReadings) {
        final docRef =
            _healthReadingsCollection(reading.patientUid).doc(reading.id);
        final docData = _buildFirestoreDocument(reading);
        batch.set(docRef, docData, SetOptions(merge: true));
      }

      try {
        await batch.commit();

        // Clear retry state for all successful readings
        for (final reading in eligibleReadings) {
          _clearRetryState(reading.id);
        }

        successCount += eligibleReadings.length;
        _telemetry.increment('health.firestore.batch.chunk.success');
        debugPrint(
            '[HealthFirestoreService] Batch chunk success: ${eligibleReadings.length}');
      } catch (e) {
        debugPrint('[HealthFirestoreService] Batch chunk failed: $e');
        _telemetry.increment('health.firestore.batch.chunk.error');

        // Record failures
        for (final reading in eligibleReadings) {
          _recordFailure(reading.id);
          failedIds.add(reading.id);
        }
        failureCount += eligibleReadings.length;

        if (!continueOnError) {
          // Abort remaining batches
          break;
        }
      }
    }

    stopwatch.stop();

    _telemetry.gauge('health.firestore.batch.success_count', successCount);
    _telemetry.gauge('health.firestore.batch.failure_count', failureCount);
    _telemetry.gauge('health.firestore.batch.elapsed_ms', stopwatch.elapsedMilliseconds);

    final result = BatchMirrorResult(
      successCount: successCount,
      failureCount: failureCount,
      skippedCount: skippedCount,
      failedIds: failedIds,
      elapsed: stopwatch.elapsed,
    );

    debugPrint(
        '[HealthFirestoreService] Batch complete: ${result.successCount} success, '
        '${result.failureCount} failed, ${result.skippedCount} skipped');

    return result;
  }

  /// Mirror a single reading with retry support.
  ///
  /// Retries with exponential backoff on transient failures.
  /// Returns after first success or max retries exhausted.
  Future<MirrorResult> mirrorWithRetry(StoredHealthReading reading) async {
    final readingId = reading.id;
    final maxAttempts = _retryConfig.maxRetries + 1; // +1 for initial attempt

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final result = await mirrorReading(reading);

      if (result.success) {
        return result;
      }

      // Check if we should retry
      final retries = _retryAttempts[readingId] ?? 0;
      if (retries >= _retryConfig.maxRetries) {
        _telemetry.increment('health.firestore.mirror.max_retries_exhausted');
        return MirrorResult.failure(readingId, 'Max retries exhausted');
      }

      // Wait before retry
      final delay = _retryConfig.getDelay(attempt);
      debugPrint('[HealthFirestoreService] Retrying in ${delay.inMilliseconds}ms');
      await Future.delayed(delay);
    }

    return MirrorResult.failure(readingId, 'Retry loop exhausted');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // READ OPERATIONS (For Verification & Doctor Portal)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fetch a single reading from Firestore (for verification).
  ///
  /// Returns null if not found or on error.
  Future<Map<String, dynamic>?> fetchReading(
      String patientUid, String readingId) async {
    try {
      final doc =
          await _healthReadingsCollection(patientUid).doc(readingId).get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      debugPrint('[HealthFirestoreService] Fetch reading failed: $e');
      _telemetry.increment('health.firestore.fetch.error');
      return null;
    }
  }

  /// Check if a reading exists in Firestore.
  Future<bool> exists(String patientUid, String readingId) async {
    try {
      final doc =
          await _healthReadingsCollection(patientUid).doc(readingId).get();
      return doc.exists;
    } catch (e) {
      debugPrint('[HealthFirestoreService] Exists check failed: $e');
      return false;
    }
  }

  /// Fetch readings for a patient with optional filters.
  ///
  /// Used by doctor portal and caregiver apps.
  Future<List<Map<String, dynamic>>> fetchReadings({
    required String patientUid,
    StoredHealthReadingType? type,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    _telemetry.increment('health.firestore.fetch_readings.attempt');

    try {
      Query<Map<String, dynamic>> query =
          _healthReadingsCollection(patientUid)
              .orderBy('recorded_at', descending: true);

      if (type != null) {
        query = query.where('reading_type', isEqualTo: type.name);
      }
      if (startDate != null) {
        query = query.where('recorded_at',
            isGreaterThanOrEqualTo: startDate.toUtc().toIso8601String());
      }
      if (endDate != null) {
        query = query.where('recorded_at',
            isLessThanOrEqualTo: endDate.toUtc().toIso8601String());
      }

      final snapshot = await query.limit(limit).get();

      _telemetry.increment('health.firestore.fetch_readings.success');
      _telemetry.gauge('health.firestore.fetch_readings.count', snapshot.docs.length);

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('[HealthFirestoreService] Fetch readings failed: $e');
      _telemetry.increment('health.firestore.fetch_readings.error');
      return [];
    }
  }

  /// Get IDs of all readings in Firestore for a patient.
  ///
  /// Used for sync status calculation.
  Future<Set<String>> getSyncedIds(String patientUid) async {
    try {
      // Fetch only document IDs by limiting fields returned
      // Note: Firestore charges for reads regardless of field count,
      // but this reduces network transfer
      final snapshot = await _healthReadingsCollection(patientUid)
          .get();

      return snapshot.docs.map((doc) => doc.id).toSet();
    } catch (e) {
      debugPrint('[HealthFirestoreService] Get synced IDs failed: $e');
      _telemetry.increment('health.firestore.get_synced_ids.error');
      return {};
    }
  }

  /// Calculate sync status by comparing local and remote IDs.
  Future<HealthSyncStatus> calculateSyncStatus({
    required String patientUid,
    required List<String> localIds,
  }) async {
    _telemetry.increment('health.firestore.sync_status.attempt');

    try {
      final syncedIds = await getSyncedIds(patientUid);
      final localSet = localIds.toSet();

      final syncedCount = localSet.intersection(syncedIds).length;
      final unsyncedCount = localSet.difference(syncedIds).length;

      _telemetry.increment('health.firestore.sync_status.success');

      return HealthSyncStatus(
        totalLocal: localIds.length,
        syncedCount: syncedCount,
        unsyncedCount: unsyncedCount,
        lastSyncAttempt: DateTime.now().toUtc(),
      );
    } catch (e) {
      debugPrint('[HealthFirestoreService] Sync status failed: $e');
      _telemetry.increment('health.firestore.sync_status.error');

      return HealthSyncStatus(
        totalLocal: localIds.length,
        syncedCount: -1,
        unsyncedCount: -1,
        unknownCount: localIds.length,
        lastError: e.toString(),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DELETE OPERATIONS (GDPR Compliance)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Delete all health readings for a patient from Firestore.
  ///
  /// Called when patient requests data deletion (GDPR).
  /// Hive deletion should happen BEFORE calling this.
  ///
  /// Returns count of deleted documents.
  Future<int> deleteAllForPatient(String patientUid) async {
    debugPrint('[HealthFirestoreService] GDPR delete for: $patientUid');
    _telemetry.increment('health.firestore.delete_all.attempt');

    int deletedCount = 0;

    try {
      // Fetch all document references
      final snapshot = await _healthReadingsCollection(patientUid).get();

      if (snapshot.docs.isEmpty) {
        debugPrint('[HealthFirestoreService] No documents to delete');
        return 0;
      }

      // Delete in batches (Firestore limit: 500)
      const batchSize = 500;
      for (var i = 0; i < snapshot.docs.length; i += batchSize) {
        final batch = _firestore.batch();
        final chunk = snapshot.docs.skip(i).take(batchSize);

        for (final doc in chunk) {
          batch.delete(doc.reference);
          deletedCount++;
        }

        await batch.commit();
        debugPrint('[HealthFirestoreService] Deleted batch of ${chunk.length}');
      }

      _telemetry.gauge('health.firestore.delete_all.count', deletedCount);
      _telemetry.increment('health.firestore.delete_all.success');

      debugPrint('[HealthFirestoreService] GDPR delete complete: $deletedCount');
      return deletedCount;
    } catch (e) {
      debugPrint('[HealthFirestoreService] GDPR delete failed: $e');
      _telemetry.increment('health.firestore.delete_all.error');
      // Return partial count — caller can retry
      return deletedCount;
    }
  }

  /// Delete a single reading from Firestore.
  Future<bool> deleteReading(String patientUid, String readingId) async {
    try {
      await _healthReadingsCollection(patientUid).doc(readingId).delete();
      _telemetry.increment('health.firestore.delete.success');
      return true;
    } catch (e) {
      debugPrint('[HealthFirestoreService] Delete failed: $e');
      _telemetry.increment('health.firestore.delete.error');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Build Firestore document from StoredHealthReading.
  Map<String, dynamic> _buildFirestoreDocument(StoredHealthReading reading) {
    return {
      'id': reading.id,
      'patient_uid': reading.patientUid,
      'reading_type': reading.readingType.name,
      'recorded_at': reading.recordedAt.toUtc().toIso8601String(),
      'persisted_at': reading.persistedAt.toUtc().toIso8601String(),
      'synced_at': FieldValue.serverTimestamp(),
      'data_source': reading.dataSource,
      'device_type': reading.deviceType,
      'reliability': reading.reliability,
      'data': reading.data,
      'schema_version': reading.schemaVersion,
    };
  }

  /// Check if a reading is eligible for sync (not in backoff).
  bool _isEligibleForSync(String readingId) {
    final nextRetry = _nextRetryTime[readingId];
    if (nextRetry == null) return true;
    return DateTime.now().toUtc().isAfter(nextRetry);
  }

  /// Record a sync failure and update retry state.
  void _recordFailure(String readingId) {
    final attempts = (_retryAttempts[readingId] ?? 0) + 1;
    _retryAttempts[readingId] = attempts;

    // Calculate next eligible retry time
    final delay = _retryConfig.getDelay(attempts - 1);
    _nextRetryTime[readingId] = DateTime.now().toUtc().add(delay);

    _telemetry.gauge('health.firestore.retry.attempt', attempts);
  }

  /// Clear retry state after successful sync.
  void _clearRetryState(String readingId) {
    _retryAttempts.remove(readingId);
    _nextRetryTime.remove(readingId);
  }

  /// Reset all retry state (for testing or manual reset).
  void resetRetryState() {
    _retryAttempts.clear();
    _nextRetryTime.clear();
  }

  /// Get current retry statistics.
  Map<String, dynamic> getRetryStats() {
    return {
      'pending_retries': _retryAttempts.length,
      'readings_in_backoff': _nextRetryTime.entries
          .where((e) => DateTime.now().toUtc().isBefore(e.value))
          .length,
    };
  }
}
