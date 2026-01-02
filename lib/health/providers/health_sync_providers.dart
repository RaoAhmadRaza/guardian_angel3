/// Health Sync Providers — Firestore Sync Status & Controls
///
/// Riverpod providers for health data Firestore synchronization.
///
/// PRINCIPLES:
/// - Hive is ALWAYS source of truth
/// - Sync status is informational only (never blocks UI)
/// - Manual sync is available for user-initiated refresh
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../repositories/health_data_repository.dart';
import '../repositories/health_data_repository_hive.dart';
import '../services/health_data_persistence_service.dart';
import '../services/health_firestore_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// CORE SERVICE PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

/// Current user UID from Firebase Auth.
///
/// Used for determining which patient's data to sync.
final _currentPatientUidProvider = Provider<String?>((ref) {
  return FirebaseAuth.instance.currentUser?.uid;
});

/// Provides the Firestore sync service singleton.
final healthFirestoreServiceProvider = Provider<HealthFirestoreService>((ref) {
  return HealthFirestoreService.instance;
});

/// Provides the repository instance for sync operations.
///
/// NOTE: Named differently from healthDataRepositoryProvider in
/// health_persistence_provider.dart to avoid export conflicts.
final healthSyncRepositoryProvider = Provider<HealthDataRepository>((ref) {
  return HealthDataRepositoryHive();
});

/// Provides the persistence service with Firestore sync enabled.
final healthSyncPersistenceServiceProvider =
    Provider<HealthDataPersistenceService>((ref) {
  final repository = ref.watch(healthSyncRepositoryProvider);
  final firestoreService = ref.watch(healthFirestoreServiceProvider);

  return HealthDataPersistenceService(
    repository: repository,
    firestoreService: firestoreService,
    firestoreSyncEnabled: true,
  );
});

// ═══════════════════════════════════════════════════════════════════════════
// SYNC STATUS PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

/// Current sync status for the logged-in patient.
///
/// Returns [HealthSyncStatus] with:
/// - totalLocal: Number of readings in Hive
/// - syncedCount: Number confirmed in Firestore
/// - unsyncedCount: Number pending sync
///
/// Usage:
/// ```dart
/// final status = ref.watch(healthSyncStatusProvider);
/// if (status.hasUnsynced) {
///   showBadge(status.unsyncedCount);
/// }
/// ```
final healthSyncStatusProvider = FutureProvider<HealthSyncStatus>((ref) async {
  final patientUid = ref.watch(_currentPatientUidProvider);
  if (patientUid == null) {
    return HealthSyncStatus.empty();
  }

  final service = ref.watch(healthSyncPersistenceServiceProvider);
  return service.getSyncStatus(patientUid: patientUid);
});

/// Whether there are any unsynced readings.
final hasUnsyncedReadingsProvider = Provider<bool>((ref) {
  final statusAsync = ref.watch(healthSyncStatusProvider);
  return statusAsync.maybeWhen(
    data: (status) => status.hasUnsynced,
    orElse: () => false,
  );
});

/// Sync progress as a percentage (0.0 - 1.0).
final syncProgressProvider = Provider<double>((ref) {
  final statusAsync = ref.watch(healthSyncStatusProvider);
  return statusAsync.maybeWhen(
    data: (status) => status.syncProgress,
    orElse: () => 1.0,
  );
});

// ═══════════════════════════════════════════════════════════════════════════
// MANUAL SYNC PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

/// State notifier for manual sync operations.
class ManualSyncNotifier extends StateNotifier<ManualSyncState> {
  final Ref _ref;

  ManualSyncNotifier(this._ref) : super(const ManualSyncState.idle());

  /// Trigger a manual sync of all unsynced readings.
  ///
  /// Returns updated [HealthSyncStatus] after sync completes.
  Future<HealthSyncStatus> syncNow() async {
    if (state.isSyncing) {
      debugPrint('[ManualSyncNotifier] Sync already in progress');
      return state.lastStatus ?? HealthSyncStatus.unknown();
    }

    state = const ManualSyncState.syncing();

    try {
      final patientUid = _ref.read(_currentPatientUidProvider);
      if (patientUid == null) {
        state = const ManualSyncState.error('No patient UID');
        return HealthSyncStatus.empty();
      }

      final service = _ref.read(healthSyncPersistenceServiceProvider);
      final status = await service.syncUnsyncedReadings(patientUid: patientUid);

      state = ManualSyncState.success(status);

      // Invalidate the status provider to refresh UI
      _ref.invalidate(healthSyncStatusProvider);

      return status;
    } catch (e) {
      debugPrint('[ManualSyncNotifier] Manual sync error: $e');
      state = ManualSyncState.error(e.toString());
      return HealthSyncStatus(
        totalLocal: -1,
        syncedCount: -1,
        unsyncedCount: -1,
        lastError: e.toString(),
      );
    }
  }

  /// Reset state to idle.
  void reset() {
    state = const ManualSyncState.idle();
  }
}

/// State for manual sync operations.
class ManualSyncState {
  final bool isSyncing;
  final bool hasError;
  final String? error;
  final HealthSyncStatus? lastStatus;

  const ManualSyncState._({
    required this.isSyncing,
    required this.hasError,
    this.error,
    this.lastStatus,
  });

  const ManualSyncState.idle()
      : this._(isSyncing: false, hasError: false);

  const ManualSyncState.syncing()
      : this._(isSyncing: true, hasError: false);

  const ManualSyncState.success(HealthSyncStatus status)
      : this._(isSyncing: false, hasError: false, lastStatus: status);

  const ManualSyncState.error(String message)
      : this._(isSyncing: false, hasError: true, error: message);

  bool get isIdle => !isSyncing && !hasError;
  bool get isSuccess => !isSyncing && !hasError && lastStatus != null;
}

/// Provider for manual sync controls.
///
/// Usage:
/// ```dart
/// // Trigger sync
/// await ref.read(manualSyncProvider.notifier).syncNow();
///
/// // Check if syncing
/// final state = ref.watch(manualSyncProvider);
/// if (state.isSyncing) {
///   showLoadingIndicator();
/// }
/// ```
final manualSyncProvider =
    StateNotifierProvider<ManualSyncNotifier, ManualSyncState>((ref) {
  return ManualSyncNotifier(ref);
});

// ═══════════════════════════════════════════════════════════════════════════
// RETRY STATE PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

/// Get retry statistics from the Firestore service.
final syncRetryStatsProvider = Provider<Map<String, dynamic>>((ref) {
  final service = ref.watch(healthFirestoreServiceProvider);
  return service.getRetryStats();
});

/// Reset all retry state (for debugging/manual intervention).
void resetSyncRetryState(WidgetRef ref) {
  final service = ref.read(healthFirestoreServiceProvider);
  service.resetRetryState();
}

// ═══════════════════════════════════════════════════════════════════════════
// SYNC CONFIGURATION PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

/// Enable or disable Firestore sync.
///
/// Setting to false will prevent new readings from being synced,
/// but won't delete already synced data.
final syncEnabledProvider = StateProvider<bool>((ref) => true);

/// Watch sync enabled and update service accordingly.
final syncConfigWatcherProvider = Provider<void>((ref) {
  final enabled = ref.watch(syncEnabledProvider);
  final service = ref.watch(healthSyncPersistenceServiceProvider);
  service.firestoreSyncEnabled = enabled;
});
