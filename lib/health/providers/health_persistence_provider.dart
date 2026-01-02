/// Health Persistence Providers — Riverpod DI for Local Storage Layer
///
/// These providers expose the health persistence layer to the UI.
///
/// SCOPE RULES:
/// ✅ Local Hive storage via repository
/// ✅ Extract + persist orchestration via service
/// ✅ Offline-first local snapshots
/// ❌ NO Firestore / cloud sync
/// ❌ NO background workers
///
/// Data Flow:
/// UI → Provider → PersistenceService → Repository → BoxAccessor → Hive
///                        ↓
///              ExtractionService → OS Health Store (read-only)
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/stored_health_reading.dart';
import '../repositories/health_data_repository.dart';
import '../repositories/health_data_repository_hive.dart';
import '../services/health_data_persistence_service.dart';
import '../../persistence/wrappers/box_accessor.dart';

// ═══════════════════════════════════════════════════════════════════════════
// REPOSITORY PROVIDER
// ═══════════════════════════════════════════════════════════════════════════

/// Provider for the health data repository (Hive-backed).
///
/// Usage:
/// ```dart
/// final repo = ref.read(healthDataRepositoryProvider);
/// final snapshot = await repo.getLatestVitals(patientUid);
/// ```
final healthDataRepositoryProvider = Provider<HealthDataRepository>((ref) {
  final boxAccessor = ref.watch(boxAccessorProvider);
  return HealthDataRepositoryHive(boxAccessor: boxAccessor);
});

// ═══════════════════════════════════════════════════════════════════════════
// PERSISTENCE SERVICE PROVIDER
// ═══════════════════════════════════════════════════════════════════════════

/// Provider for the health data persistence service (orchestrator).
///
/// This coordinates extraction from OS health store and persistence to Hive.
///
/// Usage:
/// ```dart
/// final service = ref.read(healthPersistenceServiceProvider);
/// final result = await service.fetchAndPersistVitals(patientUid: 'abc123');
/// ```
final healthPersistenceServiceProvider =
    Provider<HealthDataPersistenceService>((ref) {
  final repository = ref.watch(healthDataRepositoryProvider);
  return HealthDataPersistenceService(repository: repository);
});

// ═══════════════════════════════════════════════════════════════════════════
// FETCH + PERSIST PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

/// Parameters for fetch and persist operations.
class FetchPersistParams {
  final String patientUid;
  final int windowMinutes;
  final bool includeSleep;

  const FetchPersistParams({
    required this.patientUid,
    this.windowMinutes = 60,
    this.includeSleep = true,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FetchPersistParams &&
          runtimeType == other.runtimeType &&
          patientUid == other.patientUid &&
          windowMinutes == other.windowMinutes &&
          includeSleep == other.includeSleep;

  @override
  int get hashCode =>
      patientUid.hashCode ^ windowMinutes.hashCode ^ includeSleep.hashCode;
}

/// FutureProvider.family for fetch + persist operations.
///
/// This fetches from OS health store and persists to local Hive.
/// Use this for on-demand refresh.
///
/// Usage:
/// ```dart
/// final params = FetchPersistParams(patientUid: 'abc123');
/// final result = ref.watch(fetchAndPersistProvider(params));
/// result.when(
///   data: (r) => r.success
///     ? Text('Saved ${r.summary.totalPersisted} readings')
///     : Text('Error: ${r.message}'),
///   loading: () => CircularProgressIndicator(),
///   error: (e, _) => Text('Error: $e'),
/// );
/// ```
final fetchAndPersistProvider =
    FutureProvider.family<HealthPersistenceResult, FetchPersistParams>(
        (ref, params) {
  final service = ref.read(healthPersistenceServiceProvider);
  return service.fetchAndPersistVitals(
    patientUid: params.patientUid,
    windowMinutes: params.windowMinutes,
    includeSleep: params.includeSleep,
  );
});

// ═══════════════════════════════════════════════════════════════════════════
// LOCAL SNAPSHOT PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

/// FutureProvider.family for local vitals snapshot.
///
/// This returns cached data from Hive WITHOUT fetching from OS.
/// Use this for instant UI display (offline-first).
///
/// Usage:
/// ```dart
/// final snapshot = ref.watch(localVitalsSnapshotProvider('abc123'));
/// snapshot.when(
///   data: (vitals) => VitalsDisplay(vitals),
///   loading: () => Shimmer(),
///   error: (e, _) => Text('Error: $e'),
/// );
/// ```
final localVitalsSnapshotProvider =
    FutureProvider.family<StoredVitalsSnapshot, String>((ref, patientUid) {
  final service = ref.read(healthPersistenceServiceProvider);
  return service.getLocalSnapshot(patientUid: patientUid);
});

/// StreamProvider.family for watching local vitals changes.
///
/// This emits whenever local health data changes in Hive.
/// Use for real-time UI updates without polling.
///
/// Usage:
/// ```dart
/// final vitals = ref.watch(localVitalsStreamProvider('abc123'));
/// vitals.when(
///   data: (snapshot) => VitalsDisplay(snapshot),
///   loading: () => Shimmer(),
///   error: (e, _) => Text('Error: $e'),
/// );
/// ```
final localVitalsStreamProvider =
    StreamProvider.family<StoredVitalsSnapshot, String>((ref, patientUid) {
  final service = ref.read(healthPersistenceServiceProvider);
  return service.watchLocalVitals(patientUid: patientUid);
});

// ═══════════════════════════════════════════════════════════════════════════
// STORAGE STATS PROVIDER
// ═══════════════════════════════════════════════════════════════════════════

/// FutureProvider.family for storage statistics.
///
/// Use this for debug/admin UI showing storage usage.
///
/// Usage:
/// ```dart
/// final stats = ref.watch(healthStorageStatsProvider('abc123'));
/// stats.when(
///   data: (s) => Text('${s.totalReadings} readings stored'),
///   loading: () => Shimmer(),
///   error: (e, _) => Text('Error: $e'),
/// );
/// ```
final healthStorageStatsProvider =
    FutureProvider.family<HealthStorageStats, String>((ref, patientUid) {
  final service = ref.read(healthPersistenceServiceProvider);
  return service.getStorageStats(patientUid: patientUid);
});

// ═══════════════════════════════════════════════════════════════════════════
// READINGS QUERY PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

/// Parameters for querying readings.
class ReadingsQueryParams {
  final String patientUid;
  final StoredHealthReadingType? type;
  final DateTime? startDate;
  final DateTime? endDate;

  const ReadingsQueryParams({
    required this.patientUid,
    this.type,
    this.startDate,
    this.endDate,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadingsQueryParams &&
          runtimeType == other.runtimeType &&
          patientUid == other.patientUid &&
          type == other.type &&
          startDate == other.startDate &&
          endDate == other.endDate;

  @override
  int get hashCode =>
      patientUid.hashCode ^
      type.hashCode ^
      startDate.hashCode ^
      endDate.hashCode;
}

/// FutureProvider.family for querying all stored readings.
///
/// Usage:
/// ```dart
/// final readings = ref.watch(allReadingsProvider('abc123'));
/// ```
final allReadingsProvider =
    FutureProvider.family<List<StoredHealthReading>, String>(
        (ref, patientUid) {
  final repo = ref.read(healthDataRepositoryProvider);
  return repo.getAllReadings(patientUid);
});

// ═══════════════════════════════════════════════════════════════════════════
// MAINTENANCE PROVIDERS (Admin)
// ═══════════════════════════════════════════════════════════════════════════

/// State for maintenance operations (prune, delete).
class HealthMaintenanceState {
  final bool isRunning;
  final String? lastOperation;
  final int? lastResult;
  final String? error;

  const HealthMaintenanceState({
    this.isRunning = false,
    this.lastOperation,
    this.lastResult,
    this.error,
  });

  HealthMaintenanceState copyWith({
    bool? isRunning,
    String? lastOperation,
    int? lastResult,
    String? error,
  }) {
    return HealthMaintenanceState(
      isRunning: isRunning ?? this.isRunning,
      lastOperation: lastOperation ?? this.lastOperation,
      lastResult: lastResult ?? this.lastResult,
      error: error,
    );
  }
}

/// StateNotifierProvider for maintenance operations.
///
/// Usage:
/// ```dart
/// // Prune expired data
/// ref.read(healthMaintenanceProvider.notifier).pruneExpired(30);
///
/// // Delete all data for a patient
/// ref.read(healthMaintenanceProvider.notifier).deletePatient('abc123');
/// ```
final healthMaintenanceProvider =
    StateNotifierProvider<HealthMaintenanceNotifier, HealthMaintenanceState>(
        (ref) {
  final service = ref.watch(healthPersistenceServiceProvider);
  return HealthMaintenanceNotifier(service);
});

/// Notifier for health maintenance operations.
class HealthMaintenanceNotifier extends StateNotifier<HealthMaintenanceState> {
  final HealthDataPersistenceService _service;

  HealthMaintenanceNotifier(this._service)
      : super(const HealthMaintenanceState());

  /// Prune expired readings based on retention days.
  Future<void> pruneExpired(int retentionDays) async {
    state = state.copyWith(isRunning: true, error: null);

    try {
      final count = await _service.pruneExpiredData(retentionDays: retentionDays);
      state = state.copyWith(
        isRunning: false,
        lastOperation: 'prune',
        lastResult: count,
      );
    } catch (e) {
      state = state.copyWith(
        isRunning: false,
        error: 'Prune failed: $e',
      );
    }
  }

  /// Delete all data for a patient (GDPR compliance).
  Future<void> deletePatient(String patientUid) async {
    state = state.copyWith(isRunning: true, error: null);

    try {
      await _service.deletePatientData(patientUid: patientUid);
      state = state.copyWith(
        isRunning: false,
        lastOperation: 'delete',
        lastResult: null, // deletePatientData returns void
      );
    } catch (e) {
      state = state.copyWith(
        isRunning: false,
        error: 'Delete failed: $e',
      );
    }
  }
}
