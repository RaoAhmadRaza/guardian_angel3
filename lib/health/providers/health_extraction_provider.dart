/// Health Extraction Providers — Riverpod DI for Health Data Layer
///
/// These providers expose the health extraction service to the UI layer.
///
/// SCOPE RULES:
/// ✅ Read-only access to health extraction service
/// ✅ Exposes availability, permissions, and data fetching
/// ❌ NO persistence (Hive/Firestore)
/// ❌ NO background sync
/// ❌ NO real-time streaming
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/normalized_health_data.dart';
import '../models/health_extraction_result.dart';
import '../services/patient_health_extraction_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SERVICE PROVIDER
// ═══════════════════════════════════════════════════════════════════════════

/// Provider for the PatientHealthExtractionService singleton.
///
/// Usage:
/// ```dart
/// final service = ref.read(healthExtractionServiceProvider);
/// ```
final healthExtractionServiceProvider =
    Provider<PatientHealthExtractionService>((ref) {
  return PatientHealthExtractionService.instance;
});

// ═══════════════════════════════════════════════════════════════════════════
// AVAILABILITY PROVIDER
// ═══════════════════════════════════════════════════════════════════════════

/// FutureProvider for health data availability check.
///
/// This checks:
/// - Platform support
/// - Health service installation
/// - Available data types
///
/// Usage:
/// ```dart
/// final availability = ref.watch(healthAvailabilityProvider);
/// availability.when(
///   data: (avail) => Text(avail.statusMessage),
///   loading: () => CircularProgressIndicator(),
///   error: (e, _) => Text('Error: $e'),
/// );
/// ```
final healthAvailabilityProvider = FutureProvider<HealthAvailability>((ref) {
  final service = ref.read(healthExtractionServiceProvider);
  return service.checkAvailability();
});

// ═══════════════════════════════════════════════════════════════════════════
// PERMISSION PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

/// StateNotifierProvider for managing health permissions.
///
/// Usage:
/// ```dart
/// // Check current status
/// final status = ref.watch(healthPermissionProvider);
///
/// // Request permissions
/// ref.read(healthPermissionProvider.notifier).requestPermissions();
/// ```
final healthPermissionProvider =
    StateNotifierProvider<HealthPermissionNotifier, HealthPermissionState>(
        (ref) {
  final service = ref.read(healthExtractionServiceProvider);
  return HealthPermissionNotifier(service);
});

/// State for health permissions
class HealthPermissionState {
  final bool isLoading;
  final HealthPermissionDetails? details;
  final String? error;

  const HealthPermissionState({
    this.isLoading = false,
    this.details,
    this.error,
  });

  HealthPermissionState copyWith({
    bool? isLoading,
    HealthPermissionDetails? details,
    String? error,
  }) {
    return HealthPermissionState(
      isLoading: isLoading ?? this.isLoading,
      details: details ?? this.details,
      error: error,
    );
  }

  /// Check if permissions are granted
  bool get hasPermissions => details?.hasAnyPermission ?? false;

  /// Check if all permissions are granted
  bool get hasAllPermissions => details?.hasAllPermissions ?? false;
}

/// Notifier for health permission state
class HealthPermissionNotifier extends StateNotifier<HealthPermissionState> {
  final PatientHealthExtractionService _service;

  HealthPermissionNotifier(this._service)
      : super(const HealthPermissionState());

  /// Request health permissions from the user
  Future<void> requestPermissions() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final details = await _service.requestPermissions();
      state = state.copyWith(isLoading: false, details: details);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to request permissions: $e',
      );
    }
  }

  /// Check current permission status
  Future<void> checkStatus() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final details = await _service.checkPermissionStatus();
      state = state.copyWith(isLoading: false, details: details);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to check permissions: $e',
      );
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DATA FETCHING PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

/// FutureProvider.family for fetching recent vitals.
///
/// Parameter: VitalsFetchParams (patientUid, windowMinutes)
///
/// Usage:
/// ```dart
/// final params = VitalsFetchParams(patientUid: 'abc123', windowMinutes: 60);
/// final vitals = ref.watch(recentVitalsProvider(params));
/// vitals.when(
///   data: (result) => result.success
///     ? VitalsDisplay(result.data!)
///     : ErrorDisplay(result.errorMessage),
///   loading: () => LoadingIndicator(),
///   error: (e, _) => ErrorDisplay(e.toString()),
/// );
/// ```
final recentVitalsProvider = FutureProvider.family<
    HealthExtractionResult<NormalizedVitalsSnapshot>,
    VitalsFetchParams>((ref, params) {
  final service = ref.read(healthExtractionServiceProvider);
  return service.fetchRecentVitals(
    patientUid: params.patientUid,
    windowMinutes: params.windowMinutes,
  );
});

/// Parameters for fetching recent vitals
class VitalsFetchParams {
  final String patientUid;
  final int windowMinutes;

  const VitalsFetchParams({
    required this.patientUid,
    this.windowMinutes = 60,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VitalsFetchParams &&
          runtimeType == other.runtimeType &&
          patientUid == other.patientUid &&
          windowMinutes == other.windowMinutes;

  @override
  int get hashCode => patientUid.hashCode ^ windowMinutes.hashCode;
}

/// FutureProvider.family for fetching sleep sessions.
///
/// Parameter: SleepFetchParams (patientUid, start, end)
///
/// Usage:
/// ```dart
/// final params = SleepFetchParams(patientUid: 'abc123');
/// final sleep = ref.watch(sleepSessionsProvider(params));
/// ```
final sleepSessionsProvider = FutureProvider.family<
    HealthExtractionResult<List<NormalizedSleepSession>>,
    SleepFetchParams>((ref, params) {
  final service = ref.read(healthExtractionServiceProvider);
  return service.fetchSleepSessions(
    patientUid: params.patientUid,
    start: params.start,
    end: params.end,
  );
});

/// Parameters for fetching sleep sessions
class SleepFetchParams {
  final String patientUid;
  final DateTime? start;
  final DateTime? end;

  const SleepFetchParams({
    required this.patientUid,
    this.start,
    this.end,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SleepFetchParams &&
          runtimeType == other.runtimeType &&
          patientUid == other.patientUid &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => patientUid.hashCode ^ start.hashCode ^ end.hashCode;
}

/// FutureProvider.family for fetching HRV data.
///
/// Parameter: HRVFetchParams (patientUid, windowMinutes)
///
/// Usage:
/// ```dart
/// final params = HRVFetchParams(patientUid: 'abc123', windowMinutes: 1440);
/// final hrv = ref.watch(hrvDataProvider(params));
/// ```
final hrvDataProvider = FutureProvider.family<
    HealthExtractionResult<List<NormalizedHRVReading>>,
    HRVFetchParams>((ref, params) {
  final service = ref.read(healthExtractionServiceProvider);
  return service.fetchHRVData(
    patientUid: params.patientUid,
    windowMinutes: params.windowMinutes,
  );
});

/// Parameters for fetching HRV data
class HRVFetchParams {
  final String patientUid;
  final int windowMinutes;

  const HRVFetchParams({
    required this.patientUid,
    this.windowMinutes = 1440, // 24 hours default
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HRVFetchParams &&
          runtimeType == other.runtimeType &&
          patientUid == other.patientUid &&
          windowMinutes == other.windowMinutes;

  @override
  int get hashCode => patientUid.hashCode ^ windowMinutes.hashCode;
}
