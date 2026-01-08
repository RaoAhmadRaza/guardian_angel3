/// ArrhythmiaAnalysisService — Orchestration Layer for Arrhythmia Detection
///
/// This service coordinates:
/// 1. RR interval extraction from health data
/// 2. Inference client communication with Python service
/// 3. Analysis state management with caching
/// 4. Graceful degradation when service is unavailable
///
/// DESIGN PRINCIPLES:
/// - Single responsibility: Orchestration only, no ML logic
/// - Fail gracefully: Return cached results when service unavailable
/// - Audit trail: Log all analysis requests and outcomes
/// - No blocking: Async-first design
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../config/arrhythmia_config.dart';
import '../models/arrhythmia_request.dart';
import '../models/arrhythmia_response.dart';
import '../models/arrhythmia_analysis_state.dart';
import 'arrhythmia_inference_client.dart';

/// Cached analysis result for graceful degradation.
@immutable
class CachedArrhythmiaAnalysis {
  final ArrhythmiaAnalysisSuccess analysis;
  final DateTime cachedAt;

  const CachedArrhythmiaAnalysis({
    required this.analysis,
    required this.cachedAt,
  });

  /// Check if cache is still fresh.
  bool get isFresh {
    final age = DateTime.now().difference(cachedAt);
    return age < ArrhythmiaConfig.staleAnalysisThreshold;
  }

  /// Cache age in human-readable format.
  String get ageDisplay {
    final age = DateTime.now().difference(cachedAt);
    if (age.inMinutes < 1) return 'just now';
    if (age.inMinutes < 60) return '${age.inMinutes} min ago';
    return '${age.inHours} hr ago';
  }
}

/// Service for orchestrating arrhythmia analysis.
class ArrhythmiaAnalysisService {
  final ArrhythmiaInferenceClient _client;
  final _uuid = const Uuid();

  /// Last successful analysis for graceful degradation.
  CachedArrhythmiaAnalysis? _cachedAnalysis;

  /// Analysis in progress (prevents duplicate requests).
  bool _isAnalyzing = false;

  ArrhythmiaAnalysisService({
    ArrhythmiaInferenceClient? client,
  }) : _client = client ?? ArrhythmiaInferenceClient();

  /// Current cached analysis (if any).
  CachedArrhythmiaAnalysis? get cachedAnalysis => _cachedAnalysis;

  /// Whether an analysis is currently in progress.
  bool get isAnalyzing => _isAnalyzing;

  /// Analyze RR intervals for arrhythmia risk.
  ///
  /// Flow:
  /// 1. Validate input (minimum data points)
  /// 2. Send to Python inference service
  /// 3. Cache successful results
  /// 4. Return appropriate state
  ///
  /// Parameters:
  /// - [rrIntervalsMs]: List of RR intervals in milliseconds
  /// - [patientUid]: Optional patient identifier for audit trail
  /// - [sourceDevice]: Optional device that captured the data
  /// - [useCacheOnFailure]: Whether to return cached result if service fails
  ///
  /// Returns [ArrhythmiaAnalysisState] sealed class.
  Future<ArrhythmiaAnalysisState> analyze({
    required List<int> rrIntervalsMs,
    String? patientUid,
    String? sourceDevice,
    bool useCacheOnFailure = true,
  }) async {
    final requestId = _uuid.v4();

    // Prevent duplicate concurrent requests
    if (_isAnalyzing) {
      _log('AnalysisBlocked', details: 'Analysis already in progress');
      return ArrhythmiaAnalysisLoading(requestId);
    }

    _isAnalyzing = true;

    try {
      // Validate minimum data requirement
      if (rrIntervalsMs.length < ArrhythmiaConfig.minRRIntervalsRequired) {
        _log('InsufficientData',
            details:
                'Got ${rrIntervalsMs.length}, need ${ArrhythmiaConfig.minRRIntervalsRequired}');
        return ArrhythmiaAnalysisInsufficientData(
          receivedCount: rrIntervalsMs.length,
          requiredCount: ArrhythmiaConfig.minRRIntervalsRequired,
          message:
              'Need at least ${ArrhythmiaConfig.minRRIntervalsRequired} RR intervals for analysis. '
              'Received ${rrIntervalsMs.length}.',
        );
      }

      // Truncate to max if needed
      final rrData = rrIntervalsMs.length > ArrhythmiaConfig.maxRRIntervals
          ? rrIntervalsMs.sublist(0, ArrhythmiaConfig.maxRRIntervals)
          : rrIntervalsMs;

      // Build request
      final now = DateTime.now();
      final windowDuration = Duration(milliseconds: _estimateWindowDuration(rrData));

      final request = ArrhythmiaAnalysisRequest(
        requestId: requestId,
        rrIntervalsMs: rrData,
        windowMetadata: WindowMetadata(
          startTimestamp: now.subtract(windowDuration),
          endTimestamp: now,
          sourceDevice: sourceDevice,
          patientUid: patientUid,
        ),
      );

      _log('AnalysisStarted',
          details: 'requestId=$requestId, dataPoints=${rrData.length}');

      // Send to inference service
      final result = await _client.analyze(request);

      return switch (result) {
        ArrhythmiaInferenceSuccess(response: final response) =>
          _handleSuccess(response, requestId),
        ArrhythmiaInferenceFailure(
          failureType: final type,
          message: final msg,
          errorCode: final code,
        ) =>
          _handleFailure(requestId, type, msg, code, useCacheOnFailure),
      };
    } catch (e, stackTrace) {
      _log('AnalysisException', details: '$e\n$stackTrace');
      return _handleUnexpectedError(requestId, e, useCacheOnFailure);
    } finally {
      _isAnalyzing = false;
    }
  }

  /// Check if inference service is available.
  Future<bool> isServiceAvailable() async {
    return _client.isServiceAvailable();
  }

  /// Get detailed health status of inference service.
  Future<ArrhythmiaHealthResponse?> getServiceHealth() async {
    return _client.healthCheck();
  }

  /// Clear cached analysis.
  void clearCache() {
    _cachedAnalysis = null;
    _log('CacheCleared');
  }

  // ===========================================================================
  // PRIVATE HELPERS
  // ===========================================================================

  /// Estimate window duration from RR intervals sum.
  int _estimateWindowDuration(List<int> rrIntervals) {
    if (rrIntervals.isEmpty) return 0;
    return rrIntervals.reduce((a, b) => a + b);
  }

  ArrhythmiaAnalysisState _handleSuccess(
    ArrhythmiaAnalysisResponse response,
    String requestId,
  ) {
    // Check if we got a successful analysis
    final analysis = response.analysis;
    if (analysis == null) {
      return ArrhythmiaAnalysisFailure(
        failureType: InferenceFailureType.unknown,
        message: 'No analysis in response',
        requestId: requestId,
      );
    }

    final featureSummary = response.featureSummary;
    if (featureSummary == null) {
      return ArrhythmiaAnalysisFailure(
        failureType: InferenceFailureType.unknown,
        message: 'No feature summary in response',
        requestId: requestId,
      );
    }

    _log('AnalysisSuccess',
        details: 'risk=${analysis.riskProbability.toStringAsFixed(3)}, '
            'level=${analysis.riskLevel.name}');

    final success = ArrhythmiaAnalysisSuccess(
      requestId: requestId,
      riskProbability: analysis.riskProbability,
      riskLevel: analysis.riskLevel,
      confidence: analysis.confidence,
      recommendation: analysis.recommendation,
      featureSummary: featureSummary,
      modelVersion: response.modelInfo?.modelVersion ?? 'unknown',
      analyzedAt: response.audit?.analyzedAt ?? DateTime.now(),
      totalMs: response.timing?.totalMs ?? 0,
    );

    // Cache successful result
    _cachedAnalysis = CachedArrhythmiaAnalysis(
      analysis: success,
      cachedAt: DateTime.now(),
    );

    return success;
  }

  ArrhythmiaAnalysisState _handleFailure(
    String requestId,
    InferenceFailureType type,
    String message,
    String? errorCode,
    bool useCacheOnFailure,
  ) {
    _log('AnalysisFailure',
        details: 'type=$type, code=$errorCode, msg=$message');

    // Handle insufficient data from service
    if (errorCode == 'INSUFFICIENT_DATA' || type == InferenceFailureType.invalidInput) {
      return ArrhythmiaAnalysisInsufficientData(
        receivedCount: 0, // Server didn't tell us how many we sent
        requiredCount: ArrhythmiaConfig.minRRIntervalsRequired,
        message: message,
      );
    }

    // Handle service unavailable
    if (type == InferenceFailureType.serviceUnavailable ||
        type == InferenceFailureType.timeout) {
      // Try to use cache if available and allowed
      if (useCacheOnFailure && _cachedAnalysis != null && _cachedAnalysis!.isFresh) {
        _log('UsingCachedResult', details: 'age=${_cachedAnalysis!.ageDisplay}');
        return ArrhythmiaAnalysisStale(
          lastAnalysis: _cachedAnalysis!.analysis,
          analyzedAt: _cachedAnalysis!.cachedAt,
          staleReason: 'Service unavailable, using cached result',
        );
      }

      return ArrhythmiaAnalysisServiceUnavailable(
        message: message,
        attemptedAt: DateTime.now(),
      );
    }

    // Generic failure
    return ArrhythmiaAnalysisFailure(
      failureType: type,
      message: message,
      requestId: requestId,
      errorCode: errorCode,
    );
  }

  ArrhythmiaAnalysisState _handleUnexpectedError(
    String requestId,
    Object error,
    bool useCacheOnFailure,
  ) {
    // Try cache as fallback
    if (useCacheOnFailure && _cachedAnalysis != null && _cachedAnalysis!.isFresh) {
      _log('UsingCachedResultAfterError',
          details: 'age=${_cachedAnalysis!.ageDisplay}');
      return ArrhythmiaAnalysisStale(
        lastAnalysis: _cachedAnalysis!.analysis,
        analyzedAt: _cachedAnalysis!.cachedAt,
        staleReason: 'Error occurred, using cached result',
      );
    }

    return ArrhythmiaAnalysisFailure(
      failureType: InferenceFailureType.unknown,
      message: error.toString(),
      requestId: requestId,
    );
  }

  void _log(String event, {String? details}) {
    final timestamp = DateTime.now().toIso8601String();
    final message = details != null
        ? '[$timestamp] ArrhythmiaAnalysisService.$event: $details'
        : '[$timestamp] ArrhythmiaAnalysisService.$event';

    if (kDebugMode) {
      // ignore: avoid_print
      print(message);
    }
  }
}

/// Extension to extract RR intervals from health data sources.
extension RRIntervalExtraction on ArrhythmiaAnalysisService {
  /// Extract RR intervals from raw heart rate data.
  ///
  /// Converts heart rate (BPM) to RR intervals (ms):
  /// RR interval = 60000 / BPM
  ///
  /// Note: This is an approximation. True RR intervals come from
  /// ECG/PPG data, not heart rate measurements.
  static List<int> rrFromHeartRates(List<int> heartRates) {
    return heartRates
        .where((bpm) => bpm > 30 && bpm < 220) // Filter invalid
        .map((bpm) => (60000 / bpm).round())
        .toList();
  }

  /// Validate RR interval data quality.
  ///
  /// Returns true if data meets minimum quality requirements:
  /// - At least [ArrhythmiaConfig.minRRIntervalsRequired] points
  /// - Values within physiological range (200-2000 ms)
  /// - No excessive outliers
  static bool validateRRIntervals(List<int> rrIntervals) {
    if (rrIntervals.length < ArrhythmiaConfig.minRRIntervalsRequired) {
      return false;
    }

    // Check physiological range
    final validCount = rrIntervals
        .where((rr) =>
            rr >= ArrhythmiaConfig.minRRValueMs &&
            rr <= ArrhythmiaConfig.maxRRValueMs)
        .length;

    // At least 90% should be in valid range
    return validCount >= rrIntervals.length * 0.9;
  }
}
