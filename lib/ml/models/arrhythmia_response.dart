import 'package:flutter/foundation.dart';

import 'arrhythmia_risk_level.dart';

/// Response model for arrhythmia analysis API.
@immutable
class ArrhythmiaAnalysisResponse {
  /// Request ID for tracing.
  final String requestId;

  /// Response status ('success' or 'error').
  final String status;

  /// Analysis results (null if error).
  final ArrhythmiaAnalysis? analysis;

  /// Feature summary (null if error).
  final FeatureSummary? featureSummary;

  /// Model information (null if error).
  final ModelInfo? modelInfo;

  /// Timing information (null if error).
  final TimingInfo? timing;

  /// Audit information (null if error).
  final AuditInfo? audit;

  /// Error details (null if success).
  final ArrhythmiaError? error;

  const ArrhythmiaAnalysisResponse({
    required this.requestId,
    required this.status,
    this.analysis,
    this.featureSummary,
    this.modelInfo,
    this.timing,
    this.audit,
    this.error,
  });

  /// Whether the analysis was successful.
  bool get isSuccess => status == 'success' && analysis != null;

  /// Whether there was an error.
  bool get isError => status == 'error' || error != null;

  /// Parse from JSON response.
  factory ArrhythmiaAnalysisResponse.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as String? ?? 'error';

    if (status == 'success') {
      return ArrhythmiaAnalysisResponse(
        requestId: json['request_id'] as String,
        status: status,
        analysis: json['analysis'] != null
            ? ArrhythmiaAnalysis.fromJson(json['analysis'] as Map<String, dynamic>)
            : null,
        featureSummary: json['feature_summary'] != null
            ? FeatureSummary.fromJson(json['feature_summary'] as Map<String, dynamic>)
            : null,
        modelInfo: json['model_info'] != null
            ? ModelInfo.fromJson(json['model_info'] as Map<String, dynamic>)
            : null,
        timing: json['timing'] != null
            ? TimingInfo.fromJson(json['timing'] as Map<String, dynamic>)
            : null,
        audit: json['audit'] != null
            ? AuditInfo.fromJson(json['audit'] as Map<String, dynamic>)
            : null,
      );
    } else {
      return ArrhythmiaAnalysisResponse(
        requestId: json['request_id'] as String? ?? 'unknown',
        status: status,
        error: json['error'] != null
            ? ArrhythmiaError.fromJson(json['error'] as Map<String, dynamic>)
            : null,
      );
    }
  }
}

/// Core analysis results.
@immutable
class ArrhythmiaAnalysis {
  /// Probability of elevated arrhythmia risk (0.0 - 1.0).
  final double riskProbability;

  /// Categorical risk level.
  final ArrhythmiaRiskLevel riskLevel;

  /// Analysis confidence.
  final ArrhythmiaConfidence confidence;

  /// Clinical recommendation.
  final ArrhythmiaRecommendation recommendation;

  const ArrhythmiaAnalysis({
    required this.riskProbability,
    required this.riskLevel,
    required this.confidence,
    required this.recommendation,
  });

  factory ArrhythmiaAnalysis.fromJson(Map<String, dynamic> json) {
    return ArrhythmiaAnalysis(
      riskProbability: (json['risk_probability'] as num).toDouble(),
      riskLevel: ArrhythmiaRiskLevel.fromString(json['risk_level'] as String),
      confidence: ArrhythmiaConfidence.fromString(json['confidence'] as String),
      recommendation:
          ArrhythmiaRecommendation.fromString(json['recommendation'] as String),
    );
  }

  /// Risk as percentage string.
  String get riskPercentage => '${(riskProbability * 100).toStringAsFixed(1)}%';
}

/// Summary of extracted HRV features.
@immutable
class FeatureSummary {
  final TimeDomainFeatures timeDomain;
  final FrequencyDomainFeatures frequencyDomain;
  final FeatureInterpretation interpretation;

  const FeatureSummary({
    required this.timeDomain,
    required this.frequencyDomain,
    required this.interpretation,
  });

  factory FeatureSummary.fromJson(Map<String, dynamic> json) {
    return FeatureSummary(
      timeDomain:
          TimeDomainFeatures.fromJson(json['time_domain'] as Map<String, dynamic>),
      frequencyDomain: FrequencyDomainFeatures.fromJson(
          json['frequency_domain'] as Map<String, dynamic>),
      interpretation:
          FeatureInterpretation.fromJson(json['interpretation'] as Map<String, dynamic>),
    );
  }
}

/// Time-domain HRV features.
@immutable
class TimeDomainFeatures {
  /// Mean RR interval in ms.
  final double meanRrMs;

  /// Standard deviation of NN intervals.
  final double sdnnMs;

  /// Root mean square of successive differences.
  final double rmssdMs;

  /// Percentage of successive differences > 50ms.
  final double pnn50Percent;

  const TimeDomainFeatures({
    required this.meanRrMs,
    required this.sdnnMs,
    required this.rmssdMs,
    required this.pnn50Percent,
  });

  factory TimeDomainFeatures.fromJson(Map<String, dynamic> json) {
    return TimeDomainFeatures(
      meanRrMs: (json['mean_rr_ms'] as num).toDouble(),
      sdnnMs: (json['sdnn_ms'] as num).toDouble(),
      rmssdMs: (json['rmssd_ms'] as num).toDouble(),
      pnn50Percent: (json['pnn50_percent'] as num).toDouble(),
    );
  }

  /// Estimated heart rate from mean RR.
  double get estimatedHeartRate => 60000 / meanRrMs;
}

/// Frequency-domain HRV features.
@immutable
class FrequencyDomainFeatures {
  /// LF/HF power ratio.
  final double lfHfRatio;

  /// Total spectral power in ms².
  final double totalPowerMs2;

  const FrequencyDomainFeatures({
    required this.lfHfRatio,
    required this.totalPowerMs2,
  });

  factory FrequencyDomainFeatures.fromJson(Map<String, dynamic> json) {
    return FrequencyDomainFeatures(
      lfHfRatio: (json['lf_hf_ratio'] as num).toDouble(),
      totalPowerMs2: (json['total_power_ms2'] as num).toDouble(),
    );
  }
}

/// Human-readable interpretation of features.
@immutable
class FeatureInterpretation {
  /// Overall HRV status.
  final String hrvStatus;

  /// Primary concern if any.
  final String? dominantConcern;

  const FeatureInterpretation({
    required this.hrvStatus,
    this.dominantConcern,
  });

  factory FeatureInterpretation.fromJson(Map<String, dynamic> json) {
    return FeatureInterpretation(
      hrvStatus: json['hrv_status'] as String,
      dominantConcern: json['dominant_concern'] as String?,
    );
  }

  /// Human-readable HRV status.
  String get hrvStatusDisplay => switch (hrvStatus) {
        'severely_reduced' => 'Severely Reduced',
        'reduced' => 'Reduced',
        'normal' => 'Normal',
        'elevated' => 'Elevated',
        _ => hrvStatus,
      };
}

/// Information about the model used.
@immutable
class ModelInfo {
  final String modelVersion;
  final String modelHash;
  final int featureCount;
  final String trainedAt;

  const ModelInfo({
    required this.modelVersion,
    required this.modelHash,
    required this.featureCount,
    required this.trainedAt,
  });

  factory ModelInfo.fromJson(Map<String, dynamic> json) {
    return ModelInfo(
      modelVersion: json['model_version'] as String,
      modelHash: json['model_hash'] as String,
      featureCount: json['feature_count'] as int,
      trainedAt: json['trained_at'] as String,
    );
  }
}

/// Performance timing information.
@immutable
class TimingInfo {
  final int featureExtractionMs;
  final int inferenceMs;
  final int totalMs;

  const TimingInfo({
    required this.featureExtractionMs,
    required this.inferenceMs,
    required this.totalMs,
  });

  factory TimingInfo.fromJson(Map<String, dynamic> json) {
    return TimingInfo(
      featureExtractionMs: json['feature_extraction_ms'] as int,
      inferenceMs: json['inference_ms'] as int,
      totalMs: json['total_ms'] as int,
    );
  }
}

/// Audit trail information.
@immutable
class AuditInfo {
  final DateTime analyzedAt;
  final int rrCountReceived;
  final double windowDurationS;

  const AuditInfo({
    required this.analyzedAt,
    required this.rrCountReceived,
    required this.windowDurationS,
  });

  factory AuditInfo.fromJson(Map<String, dynamic> json) {
    return AuditInfo(
      analyzedAt: DateTime.parse(json['analyzed_at_iso'] as String),
      rrCountReceived: json['rr_count_received'] as int,
      windowDurationS: (json['window_duration_s'] as num).toDouble(),
    );
  }
}

/// Error details from the API.
@immutable
class ArrhythmiaError {
  final String code;
  final String message;
  final Map<String, dynamic>? details;

  const ArrhythmiaError({
    required this.code,
    required this.message,
    this.details,
  });

  factory ArrhythmiaError.fromJson(Map<String, dynamic> json) {
    return ArrhythmiaError(
      code: json['code'] as String,
      message: json['message'] as String,
      details: json['details'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() => 'ArrhythmiaError($code: $message)';
}

/// Health check response.
@immutable
class ArrhythmiaHealthResponse {
  final String status;
  final bool modelLoaded;
  final String? modelVersion;
  final double uptimeSeconds;
  final DateTime? lastInferenceAt;

  const ArrhythmiaHealthResponse({
    required this.status,
    required this.modelLoaded,
    this.modelVersion,
    required this.uptimeSeconds,
    this.lastInferenceAt,
  });

  bool get isHealthy => status == 'healthy' && modelLoaded;

  factory ArrhythmiaHealthResponse.fromJson(Map<String, dynamic> json) {
    return ArrhythmiaHealthResponse(
      status: json['status'] as String,
      modelLoaded: json['model_loaded'] as bool,
      modelVersion: json['model_version'] as String?,
      uptimeSeconds: (json['uptime_seconds'] as num).toDouble(),
      lastInferenceAt: json['last_inference_at'] != null
          ? DateTime.parse(json['last_inference_at'] as String)
          : null,
    );
  }
}
