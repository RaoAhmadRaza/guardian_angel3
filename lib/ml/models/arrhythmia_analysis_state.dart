import 'package:flutter/foundation.dart';

import 'arrhythmia_risk_level.dart';
import 'arrhythmia_response.dart';

/// Sealed class representing all possible arrhythmia analysis states.
sealed class ArrhythmiaAnalysisState {
  const ArrhythmiaAnalysisState();
}

/// Initial state - no analysis performed yet.
class ArrhythmiaAnalysisInitial extends ArrhythmiaAnalysisState {
  const ArrhythmiaAnalysisInitial();
}

/// Analysis in progress.
class ArrhythmiaAnalysisLoading extends ArrhythmiaAnalysisState {
  final String requestId;
  const ArrhythmiaAnalysisLoading(this.requestId);
}

/// Successful analysis with results.
@immutable
class ArrhythmiaAnalysisSuccess extends ArrhythmiaAnalysisState {
  final String requestId;
  final double riskProbability;
  final ArrhythmiaRiskLevel riskLevel;
  final ArrhythmiaConfidence confidence;
  final ArrhythmiaRecommendation recommendation;
  final FeatureSummary featureSummary;
  final String modelVersion;
  final DateTime analyzedAt;
  final int totalMs;

  const ArrhythmiaAnalysisSuccess({
    required this.requestId,
    required this.riskProbability,
    required this.riskLevel,
    required this.confidence,
    required this.recommendation,
    required this.featureSummary,
    required this.modelVersion,
    required this.analyzedAt,
    required this.totalMs,
  });

  /// Create from API response.
  factory ArrhythmiaAnalysisSuccess.fromResponse(
    ArrhythmiaAnalysisResponse response,
  ) {
    final analysis = response.analysis!;
    return ArrhythmiaAnalysisSuccess(
      requestId: response.requestId,
      riskProbability: analysis.riskProbability,
      riskLevel: analysis.riskLevel,
      confidence: analysis.confidence,
      recommendation: analysis.recommendation,
      featureSummary: response.featureSummary!,
      modelVersion: response.modelInfo?.modelVersion ?? 'unknown',
      analyzedAt: response.audit?.analyzedAt ?? DateTime.now(),
      totalMs: response.timing?.totalMs ?? 0,
    );
  }

  /// Display label for UI.
  String get displayLabel => riskLevel.displayLabel;

  /// Whether this requires user attention.
  bool get requiresAttention => riskLevel.requiresAttention;

  /// Heart rhythm description for DiagnosticState.
  String get heartRhythmDescription => switch (riskLevel) {
        ArrhythmiaRiskLevel.low => 'Normal Sinus Rhythm',
        ArrhythmiaRiskLevel.moderate => 'Rhythm Variation Detected',
        ArrhythmiaRiskLevel.elevated => 'Possible Arrhythmia',
        ArrhythmiaRiskLevel.high => 'Arrhythmia Risk - Consult Physician',
      };

  /// AI status message for DiagnosticState.
  String get aiStatusMessage => recommendation.displayMessage;
}

/// Insufficient RR data to perform analysis.
@immutable
class ArrhythmiaAnalysisInsufficientData extends ArrhythmiaAnalysisState {
  final int receivedCount;
  final int requiredCount;
  final String message;

  const ArrhythmiaAnalysisInsufficientData({
    required this.receivedCount,
    required this.requiredCount,
    required this.message,
  });
}

/// Service unavailable (not running locally).
@immutable
class ArrhythmiaAnalysisServiceUnavailable extends ArrhythmiaAnalysisState {
  final String message;
  final DateTime attemptedAt;

  const ArrhythmiaAnalysisServiceUnavailable({
    required this.message,
    required this.attemptedAt,
  });
}

/// Generic failure.
@immutable
class ArrhythmiaAnalysisFailure extends ArrhythmiaAnalysisState {
  final InferenceFailureType failureType;
  final String message;
  final String? requestId;
  final String? errorCode;

  const ArrhythmiaAnalysisFailure({
    required this.failureType,
    required this.message,
    this.requestId,
    this.errorCode,
  });
}

/// Stale analysis - showing cached results.
@immutable
class ArrhythmiaAnalysisStale extends ArrhythmiaAnalysisState {
  final ArrhythmiaAnalysisSuccess lastAnalysis;
  final DateTime analyzedAt;
  final String staleReason;

  const ArrhythmiaAnalysisStale({
    required this.lastAnalysis,
    required this.analyzedAt,
    required this.staleReason,
  });

  /// How long ago the analysis was performed.
  Duration get age => DateTime.now().difference(analyzedAt);

  /// Age as human-readable string.
  String get ageDisplay {
    final minutes = age.inMinutes;
    if (minutes < 1) return 'just now';
    if (minutes < 60) return '$minutes min ago';
    final hours = age.inHours;
    if (hours < 24) return '$hours hr ago';
    return '${age.inDays} days ago';
  }
}

/// Types of inference failures.
enum InferenceFailureType {
  /// Service not running on localhost.
  serviceUnavailable,

  /// Request timed out.
  timeout,

  /// Invalid input data.
  invalidInput,

  /// Model error during inference.
  modelError,

  /// Network or parsing error.
  networkError,

  /// Unknown error.
  unknown,
}

/// Extension to map state to DiagnosticState fields.
extension ArrhythmiaStateDiagnosticMapping on ArrhythmiaAnalysisState {
  /// Get heart rhythm string for DiagnosticState.
  String? get heartRhythm => switch (this) {
        ArrhythmiaAnalysisSuccess s => s.heartRhythmDescription,
        ArrhythmiaAnalysisInsufficientData _ => 'Insufficient Data',
        ArrhythmiaAnalysisServiceUnavailable _ => 'Analysis Unavailable',
        ArrhythmiaAnalysisFailure _ => 'Analysis Error',
        ArrhythmiaAnalysisStale s => s.lastAnalysis.heartRhythmDescription,
        _ => null,
      };

  /// Get AI status message for DiagnosticState.
  String? get aiStatusMessage => switch (this) {
        ArrhythmiaAnalysisSuccess s => s.aiStatusMessage,
        ArrhythmiaAnalysisInsufficientData d => d.message,
        ArrhythmiaAnalysisServiceUnavailable s => s.message,
        ArrhythmiaAnalysisFailure f => f.message,
        ArrhythmiaAnalysisStale s => '${s.lastAnalysis.aiStatusMessage} (${s.ageDisplay})',
        ArrhythmiaAnalysisLoading _ => 'Analyzing...',
        _ => null,
      };

  /// Get AI confidence for DiagnosticState.
  double? get aiConfidence => switch (this) {
        ArrhythmiaAnalysisSuccess s => s.riskProbability,
        ArrhythmiaAnalysisStale s => s.lastAnalysis.riskProbability,
        _ => null,
      };

  /// Whether to show critical alert.
  bool get hasCriticalAlert => switch (this) {
        ArrhythmiaAnalysisSuccess s => s.riskLevel == ArrhythmiaRiskLevel.high,
        ArrhythmiaAnalysisStale s =>
          s.lastAnalysis.riskLevel == ArrhythmiaRiskLevel.high,
        _ => false,
      };

  /// Get risk level if available.
  ArrhythmiaRiskLevel? get riskLevel => switch (this) {
        ArrhythmiaAnalysisSuccess s => s.riskLevel,
        ArrhythmiaAnalysisStale s => s.lastAnalysis.riskLevel,
        _ => null,
      };
}
