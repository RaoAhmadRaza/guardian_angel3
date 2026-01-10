/// Health Stability Score Fusion Engine
///
/// The core service that computes the HSS from subsystem signals.
/// Uses adaptive weighting based on personal baselines.
library;

import 'package:flutter/foundation.dart';
import '../models/subsystem_signals.dart';
import '../models/personal_baseline.dart';
import '../models/stability_score_result.dart';

/// Service that computes the Health Stability Score.
class StabilityScoreService {
  StabilityScoreService._();
  static final StabilityScoreService _instance = StabilityScoreService._();
  static StabilityScoreService get instance => _instance;

  /// Default weights for each subsystem
  static const _defaultWeights = {
    'physical': 0.30,
    'cardiac': 0.30,
    'sleep': 0.25,
    'cognitive': 0.15,
  };

  /// Compute the Health Stability Score from input signals.
  ///
  /// Returns a [StabilityScoreResult] containing:
  /// - Overall score (0-100)
  /// - Level classification
  /// - Subsystem contributions for explainability
  /// - Trend relative to personal baseline
  StabilityScoreResult computeScore({
    required StabilityInput input,
    required PersonalBaseline baseline,
  }) {
    final now = DateTime.now();

    // Check if we have minimum data
    if (!input.hasMinimumData) {
      return StabilityScoreResult(
        score: 0.0,
        level: StabilityLevel.moderate,
        contributions: _buildEmptyContributions(),
        detractors: const [],
        isReliable: false,
        confidence: 0.0,
        trend: 0.0,
        trendDescription: 'Insufficient data',
        computedAt: now,
        warnings: ['Need at least 2 subsystems with data'],
      );
    }

    // Calculate adaptive weights based on data availability and baseline
    final weights = _calculateAdaptiveWeights(input, baseline);

    // Calculate contributions from each subsystem
    final contributions = <SubsystemContribution>[];
    double totalScore = 0.0;
    double totalWeight = 0.0;
    final detractors = <String>[];
    final warnings = <String>[];

    // Physical subsystem
    if (input.physical.hasData) {
      final stability = input.physical.stabilityScore;
      final weight = weights['physical']!;
      final contribution = stability * weight * 100;
      totalScore += contribution;
      totalWeight += weight;

      final isDetractor = stability < 0.6;
      if (isDetractor) detractors.add('physical');

      contributions.add(SubsystemContribution(
        name: 'physical',
        displayName: 'Physical Mobility',
        stabilityScore: stability,
        weight: weight,
        contribution: contribution,
        isDetractor: isDetractor,
        hasData: true,
        insight: _generatePhysicalInsight(input.physical, stability),
      ));
    } else {
      contributions.add(_buildNoDataContribution('physical', 'Physical Mobility'));
    }

    // Cardiac subsystem
    if (input.cardiac.hasData) {
      final stability = input.cardiac.stabilityScore;
      final weight = weights['cardiac']!;
      final contribution = stability * weight * 100;
      totalScore += contribution;
      totalWeight += weight;

      final isDetractor = stability < 0.6;
      if (isDetractor) detractors.add('cardiac');

      contributions.add(SubsystemContribution(
        name: 'cardiac',
        displayName: 'Heart Health',
        stabilityScore: stability,
        weight: weight,
        contribution: contribution,
        isDetractor: isDetractor,
        hasData: true,
        insight: _generateCardiacInsight(input.cardiac, stability),
      ));
    } else {
      contributions.add(_buildNoDataContribution('cardiac', 'Heart Health'));
    }

    // Sleep subsystem
    if (input.sleep.hasData) {
      final stability = input.sleep.stabilityScore;
      final weight = weights['sleep']!;
      final contribution = stability * weight * 100;
      totalScore += contribution;
      totalWeight += weight;

      final isDetractor = stability < 0.6;
      if (isDetractor) detractors.add('sleep');

      contributions.add(SubsystemContribution(
        name: 'sleep',
        displayName: 'Sleep Quality',
        stabilityScore: stability,
        weight: weight,
        contribution: contribution,
        isDetractor: isDetractor,
        hasData: true,
        insight: _generateSleepInsight(input.sleep, stability),
      ));
    } else {
      contributions.add(_buildNoDataContribution('sleep', 'Sleep Quality'));
    }

    // Cognitive subsystem
    if (input.cognitive.hasData) {
      final stability = input.cognitive.stabilityScore;
      final weight = weights['cognitive']!;
      final contribution = stability * weight * 100;
      totalScore += contribution;
      totalWeight += weight;

      final isDetractor = stability < 0.6;
      if (isDetractor) detractors.add('cognitive');

      contributions.add(SubsystemContribution(
        name: 'cognitive',
        displayName: 'Wellness & Medication',
        stabilityScore: stability,
        weight: weight,
        contribution: contribution,
        isDetractor: isDetractor,
        hasData: true,
        insight: _generateCognitiveInsight(input.cognitive, stability),
      ));
    } else {
      contributions.add(_buildNoDataContribution('cognitive', 'Wellness & Medication'));
    }

    // Normalize score by total weight
    final normalizedScore = totalWeight > 0 ? (totalScore / totalWeight) : 0.0;
    final finalScore = normalizedScore.clamp(0.0, 100.0);

    // Determine level
    final level = _classifyLevel(finalScore);

    // Calculate trend relative to baseline
    final trend = _calculateTrend(finalScore, baseline);
    final trendDescription = _describeTrend(trend, baseline);

    // Calculate confidence based on data availability and baseline reliability
    final confidence = _calculateConfidence(input, baseline);

    // Add warnings for anomalies
    _checkForAnomalies(input, baseline, warnings);

    debugPrint('[StabilityScoreService] Computed HSS: ${finalScore.toStringAsFixed(1)}, level=${level.name}, confidence=${confidence.toStringAsFixed(2)}');

    return StabilityScoreResult(
      score: finalScore,
      level: level,
      contributions: contributions,
      detractors: detractors,
      isReliable: confidence >= 0.5,
      confidence: confidence,
      trend: trend,
      trendDescription: trendDescription,
      computedAt: now,
      warnings: warnings,
    );
  }

  /// Calculate adaptive weights based on data availability and baseline
  Map<String, double> _calculateAdaptiveWeights(
    StabilityInput input,
    PersonalBaseline baseline,
  ) {
    final weights = Map<String, double>.from(_defaultWeights);
    
    // Redistribute weights from unavailable subsystems
    final unavailable = <String>[];
    if (!input.physical.hasData) unavailable.add('physical');
    if (!input.cardiac.hasData) unavailable.add('cardiac');
    if (!input.sleep.hasData) unavailable.add('sleep');
    if (!input.cognitive.hasData) unavailable.add('cognitive');

    if (unavailable.isNotEmpty && unavailable.length < 4) {
      final redistributedWeight = unavailable.fold<double>(
        0.0,
        (sum, name) => sum + weights[name]!,
      );

      for (final name in unavailable) {
        weights[name] = 0.0;
      }

      final availableCount = 4 - unavailable.length;
      final additionalWeight = redistributedWeight / availableCount;

      for (final entry in weights.entries) {
        if (!unavailable.contains(entry.key)) {
          weights[entry.key] = entry.value + additionalWeight;
        }
      }
    }

    // Apply baseline-based adjustments
    if (baseline.isReliable) {
      // Increase weight for subsystems showing anomalous readings
      if (input.physical.hasData &&
          baseline.physical.isAnomalous(input.physical.stabilityScore)) {
        weights['physical'] = weights['physical']! * 1.2;
      }
      if (input.cardiac.hasData &&
          baseline.cardiac.isAnomalous(input.cardiac.stabilityScore)) {
        weights['cardiac'] = weights['cardiac']! * 1.2;
      }
      if (input.sleep.hasData &&
          baseline.sleep.isAnomalous(input.sleep.stabilityScore)) {
        weights['sleep'] = weights['sleep']! * 1.2;
      }
      if (input.cognitive.hasData &&
          baseline.cognitive.isAnomalous(input.cognitive.stabilityScore)) {
        weights['cognitive'] = weights['cognitive']! * 1.2;
      }

      // Re-normalize weights to sum to 1.0
      final total = weights.values.fold<double>(0.0, (a, b) => a + b);
      if (total > 0) {
        for (final key in weights.keys) {
          weights[key] = weights[key]! / total;
        }
      }
    }

    return weights;
  }

  /// Classify HSS into stability level
  StabilityLevel _classifyLevel(double score) {
    if (score >= 80) return StabilityLevel.stable;
    if (score >= 60) return StabilityLevel.moderate;
    if (score >= 40) return StabilityLevel.attention;
    return StabilityLevel.alert;
  }

  /// Calculate trend relative to baseline
  double _calculateTrend(double currentScore, PersonalBaseline baseline) {
    if (!baseline.overall.isReliable) return 0.0;

    final zScore = baseline.overall.zScore(currentScore / 100);
    // Clamp to -1..1 range
    return zScore.clamp(-3.0, 3.0) / 3.0;
  }

  /// Generate human-readable trend description
  String _describeTrend(double trend, PersonalBaseline baseline) {
    if (!baseline.overall.isReliable) {
      return 'Building your personal baseline';
    }

    if (trend > 0.3) return 'Improving from your baseline';
    if (trend > 0.1) return 'Slightly better than usual';
    if (trend < -0.3) return 'Below your baseline';
    if (trend < -0.1) return 'Slightly below usual';
    return 'Consistent with your baseline';
  }

  /// Calculate confidence in the score
  double _calculateConfidence(StabilityInput input, PersonalBaseline baseline) {
    double confidence = 0.0;

    // Base confidence from data availability (0-50%)
    confidence += (input.subsystemsWithData / 4.0) * 0.5;

    // Bonus for baseline reliability (0-30%)
    if (baseline.isReliable) {
      confidence += 0.3;
    } else {
      // Partial credit for partially reliable baselines
      final reliableCount = [
        baseline.physical.isReliable,
        baseline.cardiac.isReliable,
        baseline.sleep.isReliable,
        baseline.cognitive.isReliable,
      ].where((r) => r).length;
      confidence += (reliableCount / 4.0) * 0.3;
    }

    // Bonus for recent data (0-20%)
    final recency = DateTime.now().difference(input.collectedAt);
    if (recency.inMinutes < 5) {
      confidence += 0.2;
    } else if (recency.inMinutes < 30) {
      confidence += 0.15;
    } else if (recency.inHours < 1) {
      confidence += 0.1;
    } else if (recency.inHours < 6) {
      confidence += 0.05;
    }

    return confidence.clamp(0.0, 1.0);
  }

  /// Check for anomalies and add warnings
  void _checkForAnomalies(
    StabilityInput input,
    PersonalBaseline baseline,
    List<String> warnings,
  ) {
    if (input.physical.hasData && baseline.physical.isReliable) {
      if (baseline.physical.indicatesDecline(input.physical.stabilityScore)) {
        warnings.add('Physical stability is significantly below your baseline');
      }
    }

    if (input.cardiac.hasData && baseline.cardiac.isReliable) {
      if (baseline.cardiac.indicatesDecline(input.cardiac.stabilityScore)) {
        warnings.add('Cardiac stability is significantly below your baseline');
      }
    }

    if (input.sleep.hasData && baseline.sleep.isReliable) {
      if (baseline.sleep.indicatesDecline(input.sleep.stabilityScore)) {
        warnings.add('Sleep quality is significantly below your baseline');
      }
    }

    if (input.cognitive.hasData && baseline.cognitive.isReliable) {
      if (baseline.cognitive.indicatesDecline(input.cognitive.stabilityScore)) {
        warnings.add('Medication adherence is significantly below your baseline');
      }
    }
  }

  /// Generate insight for physical subsystem
  String? _generatePhysicalInsight(PhysicalSignals signals, double stability) {
    if (signals.highRiskEventCount > 0) {
      return '${signals.highRiskEventCount} high-risk mobility events detected';
    }
    if (stability >= 0.8) {
      return 'Mobility patterns are stable';
    }
    if (stability < 0.5) {
      return 'Increased fall risk detected';
    }
    return null;
  }

  /// Generate insight for cardiac subsystem
  String? _generateCardiacInsight(CardiacSignals signals, double stability) {
    if (signals.arrhythmiaRisk > 0.7) {
      return 'Elevated arrhythmia indicators';
    }
    if (signals.heartRateBpm > 100) {
      return 'Elevated heart rate: ${signals.heartRateBpm} BPM';
    }
    if (signals.heartRateBpm < 50 && signals.heartRateBpm > 0) {
      return 'Low heart rate: ${signals.heartRateBpm} BPM';
    }
    if (stability >= 0.8) {
      return 'Heart rhythm is stable';
    }
    return null;
  }

  /// Generate insight for sleep subsystem
  String? _generateSleepInsight(SleepSignals signals, double stability) {
    if (signals.averageDurationHours < 6) {
      return 'Sleep duration below recommended (${signals.averageDurationHours.toStringAsFixed(1)}h avg)';
    }
    if (signals.durationVariance > 1.5) {
      return 'Irregular sleep schedule detected';
    }
    if (stability >= 0.8) {
      return 'Sleep patterns are consistent';
    }
    return null;
  }

  /// Generate insight for cognitive subsystem
  String? _generateCognitiveInsight(CognitiveSignals signals, double stability) {
    if (signals.medicationAdherence < 0.7) {
      return 'Medication adherence needs attention (${(signals.medicationAdherence * 100).toStringAsFixed(0)}%)';
    }
    if (signals.moodTrend < -0.3) {
      return 'Mood trending downward';
    }
    if (stability >= 0.8) {
      return 'Wellness indicators are positive';
    }
    return null;
  }

  /// Build empty contributions list for no-data scenario
  List<SubsystemContribution> _buildEmptyContributions() {
    return [
      _buildNoDataContribution('physical', 'Physical Mobility'),
      _buildNoDataContribution('cardiac', 'Heart Health'),
      _buildNoDataContribution('sleep', 'Sleep Quality'),
      _buildNoDataContribution('cognitive', 'Wellness & Medication'),
    ];
  }

  /// Build a no-data contribution entry
  SubsystemContribution _buildNoDataContribution(String name, String displayName) {
    return SubsystemContribution(
      name: name,
      displayName: displayName,
      stabilityScore: 0.0,
      weight: 0.0,
      contribution: 0.0,
      isDetractor: false,
      hasData: false,
      insight: 'No data available',
    );
  }
}
