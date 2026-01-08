/// Arrhythmia Analysis Providers — Riverpod DI for ML Inference
///
/// These providers expose the arrhythmia analysis service to the UI layer.
///
/// DESIGN PRINCIPLES:
/// - Service provider is kept as Provider (singleton-like)
/// - Analysis state uses StateNotifier for controlled updates
/// - Health check is FutureProvider (one-shot)
/// - Analysis trigger uses StateNotifier to control flow
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/arrhythmia_analysis_state.dart';
import '../models/arrhythmia_response.dart';
import '../services/arrhythmia_inference_client.dart';
import '../services/arrhythmia_analysis_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SERVICE PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

/// Provider for the ArrhythmiaInferenceClient.
///
/// This is the low-level HTTP client. Usually you'll want to use
/// [arrhythmiaAnalysisServiceProvider] instead.
final arrhythmiaInferenceClientProvider =
    Provider<ArrhythmiaInferenceClient>((ref) {
  return ArrhythmiaInferenceClient();
});

/// Provider for the ArrhythmiaAnalysisService.
///
/// This is the main orchestration service for arrhythmia analysis.
///
/// Usage:
/// ```dart
/// final service = ref.read(arrhythmiaAnalysisServiceProvider);
/// final state = await service.analyze(rrIntervalsMs: rrData);
/// ```
final arrhythmiaAnalysisServiceProvider =
    Provider<ArrhythmiaAnalysisService>((ref) {
  final client = ref.read(arrhythmiaInferenceClientProvider);
  return ArrhythmiaAnalysisService(client: client);
});

// ═══════════════════════════════════════════════════════════════════════════
// HEALTH CHECK PROVIDER
// ═══════════════════════════════════════════════════════════════════════════

/// FutureProvider for checking inference service health.
///
/// Returns health details including model status and version.
///
/// Usage:
/// ```dart
/// final healthAsync = ref.watch(arrhythmiaServiceHealthProvider);
/// healthAsync.when(
///   data: (health) => health != null
///       ? Text('Model loaded: ${health.modelLoaded}')
///       : Text('Service unavailable'),
///   loading: () => CircularProgressIndicator(),
///   error: (e, _) => Text('Error: $e'),
/// );
/// ```
final arrhythmiaServiceHealthProvider =
    FutureProvider<ArrhythmiaHealthResponse?>((ref) {
  final service = ref.read(arrhythmiaAnalysisServiceProvider);
  return service.getServiceHealth();
});

/// FutureProvider for simple service availability check.
///
/// Returns true if the Python inference service is running and healthy.
final arrhythmiaServiceAvailableProvider = FutureProvider<bool>((ref) {
  final service = ref.read(arrhythmiaAnalysisServiceProvider);
  return service.isServiceAvailable();
});

// ═══════════════════════════════════════════════════════════════════════════
// ANALYSIS STATE PROVIDER
// ═══════════════════════════════════════════════════════════════════════════

/// StateNotifierProvider for arrhythmia analysis state.
///
/// This manages the analysis workflow:
/// - Initial → Loading → Success/Failure
/// - Provides methods to trigger analysis
/// - Handles state transitions
///
/// Usage:
/// ```dart
/// // Watch current state
/// final state = ref.watch(arrhythmiaAnalysisStateProvider);
///
/// // Trigger analysis
/// await ref.read(arrhythmiaAnalysisStateProvider.notifier)
///     .analyzeRRIntervals(rrData);
///
/// // Reset state
/// ref.read(arrhythmiaAnalysisStateProvider.notifier).reset();
/// ```
final arrhythmiaAnalysisStateProvider =
    StateNotifierProvider<ArrhythmiaAnalysisNotifier, ArrhythmiaAnalysisState>(
        (ref) {
  final service = ref.read(arrhythmiaAnalysisServiceProvider);
  return ArrhythmiaAnalysisNotifier(service);
});

/// State notifier for managing arrhythmia analysis workflow.
class ArrhythmiaAnalysisNotifier extends StateNotifier<ArrhythmiaAnalysisState> {
  final ArrhythmiaAnalysisService _service;

  ArrhythmiaAnalysisNotifier(this._service)
      : super(const ArrhythmiaAnalysisInitial());

  /// Analyze RR intervals for arrhythmia risk.
  ///
  /// Parameters:
  /// - [rrIntervalsMs]: List of RR intervals in milliseconds
  /// - [patientUid]: Optional patient identifier
  /// - [useCacheOnFailure]: Whether to use cached result if service fails
  ///
  /// Updates state: Initial → Loading → Success/Failure
  Future<void> analyzeRRIntervals(
    List<int> rrIntervalsMs, {
    String? patientUid,
    bool useCacheOnFailure = true,
  }) async {
    // Don't restart if already loading
    if (state is ArrhythmiaAnalysisLoading) {
      return;
    }

    // Generate a request ID for tracking
    state = ArrhythmiaAnalysisLoading('pending-${DateTime.now().millisecondsSinceEpoch}');

    final result = await _service.analyze(
      rrIntervalsMs: rrIntervalsMs,
      patientUid: patientUid,
      useCacheOnFailure: useCacheOnFailure,
    );

    // Only update if still mounted
    if (mounted) {
      state = result;
    }
  }

  /// Reset to initial state.
  void reset() {
    state = const ArrhythmiaAnalysisInitial();
  }

  /// Clear service cache and reset state.
  void clearCacheAndReset() {
    _service.clearCache();
    reset();
  }

  /// Check if we have a successful result.
  bool get hasSuccessfulResult => state is ArrhythmiaAnalysisSuccess;

  /// Get the current risk level if analysis was successful.
  String? get currentRiskLevel {
    final s = state;
    if (s is ArrhythmiaAnalysisSuccess) {
      return s.riskLevel.name;
    }
    return null;
  }

  /// Get the current risk probability if analysis was successful.
  double? get currentRiskProbability {
    final s = state;
    if (s is ArrhythmiaAnalysisSuccess) {
      return s.riskProbability;
    }
    return null;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FAMILY PROVIDER FOR PARAMETERIZED ANALYSIS
// ═══════════════════════════════════════════════════════════════════════════

/// Parameters for on-demand arrhythmia analysis.
class ArrhythmiaAnalysisParams {
  final List<int> rrIntervalsMs;
  final String? patientUid;
  final bool useCacheOnFailure;

  const ArrhythmiaAnalysisParams({
    required this.rrIntervalsMs,
    this.patientUid,
    this.useCacheOnFailure = true,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArrhythmiaAnalysisParams &&
          runtimeType == other.runtimeType &&
          _listEquals(rrIntervalsMs, other.rrIntervalsMs) &&
          patientUid == other.patientUid &&
          useCacheOnFailure == other.useCacheOnFailure;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(rrIntervalsMs), patientUid, useCacheOnFailure);

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// FutureProvider.family for on-demand arrhythmia analysis.
///
/// Use this when you want to trigger analysis with specific parameters
/// and get a one-shot result.
///
/// Usage:
/// ```dart
/// final params = ArrhythmiaAnalysisParams(
///   rrIntervalsMs: [856, 862, 848, 870, ...],
///   patientUid: 'patient123',
/// );
/// final resultAsync = ref.watch(arrhythmiaAnalyzeProvider(params));
/// resultAsync.when(
///   data: (state) => _buildResultWidget(state),
///   loading: () => CircularProgressIndicator(),
///   error: (e, _) => Text('Error: $e'),
/// );
/// ```
final arrhythmiaAnalyzeProvider = FutureProvider.family<
    ArrhythmiaAnalysisState, ArrhythmiaAnalysisParams>((ref, params) {
  final service = ref.read(arrhythmiaAnalysisServiceProvider);
  return service.analyze(
    rrIntervalsMs: params.rrIntervalsMs,
    patientUid: params.patientUid,
    useCacheOnFailure: params.useCacheOnFailure,
  );
});

// ═══════════════════════════════════════════════════════════════════════════
// DERIVED PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

/// Provider that exposes whether analysis is in progress.
final isArrhythmiaAnalyzingProvider = Provider<bool>((ref) {
  final state = ref.watch(arrhythmiaAnalysisStateProvider);
  return state is ArrhythmiaAnalysisLoading;
});

/// Provider that exposes the latest successful risk level.
final arrhythmiaRiskLevelProvider = Provider<String?>((ref) {
  final state = ref.watch(arrhythmiaAnalysisStateProvider);
  if (state is ArrhythmiaAnalysisSuccess) {
    return state.riskLevel.name;
  }
  return null;
});

/// Provider that exposes the latest successful risk probability.
final arrhythmiaRiskProbabilityProvider = Provider<double?>((ref) {
  final state = ref.watch(arrhythmiaAnalysisStateProvider);
  if (state is ArrhythmiaAnalysisSuccess) {
    return state.riskProbability;
  }
  return null;
});

/// Provider that exposes whether we need more data.
final arrhythmiaInsufficientDataProvider = Provider<bool>((ref) {
  final state = ref.watch(arrhythmiaAnalysisStateProvider);
  return state is ArrhythmiaAnalysisInsufficientData;
});

/// Provider that exposes whether service is unavailable.
final arrhythmiaServiceUnavailableProvider = Provider<bool>((ref) {
  final state = ref.watch(arrhythmiaAnalysisStateProvider);
  return state is ArrhythmiaAnalysisServiceUnavailable;
});
