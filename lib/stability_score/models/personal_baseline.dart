/// Personal Baseline Model for Health Stability Score
///
/// Tracks per-user adaptive baselines for each subsystem.
/// Used to normalize scores relative to individual health patterns.
library;

import 'package:flutter/foundation.dart';

/// Individual subsystem baseline with 7-day rolling statistics.
@immutable
class SubsystemBaseline {
  /// Name of the subsystem
  final String name;

  /// 7-day rolling average of stability score
  final double mean;

  /// Standard deviation of stability scores
  final double standardDeviation;

  /// Minimum observed value in baseline period
  final double minValue;

  /// Maximum observed value in baseline period
  final double maxValue;

  /// Number of data points in the baseline
  final int sampleCount;

  /// Timestamp of last update
  final DateTime lastUpdated;

  const SubsystemBaseline({
    required this.name,
    required this.mean,
    required this.standardDeviation,
    required this.minValue,
    required this.maxValue,
    required this.sampleCount,
    required this.lastUpdated,
  });

  /// Create a neutral baseline for new users
  SubsystemBaseline.neutral(this.name)
      : mean = 0.5,
        standardDeviation = 0.15,
        minValue = 0.3,
        maxValue = 0.7,
        sampleCount = 0,
        lastUpdated = DateTime.now();

  /// Check if baseline has enough data to be reliable
  bool get isReliable => sampleCount >= 7;

  /// Compute z-score for a given value relative to this baseline
  double zScore(double value) {
    if (standardDeviation == 0) return 0.0;
    return (value - mean) / standardDeviation;
  }

  /// Check if a value is anomalous (> 2 standard deviations from mean)
  bool isAnomalous(double value) => zScore(value).abs() > 2.0;

  /// Check if a value indicates decline (> 1.5 std below mean)
  bool indicatesDecline(double value) => zScore(value) < -1.5;

  /// Update baseline with new observation using exponential moving average
  SubsystemBaseline addObservation(double newValue) {
    final now = DateTime.now();
    
    if (sampleCount == 0) {
      return SubsystemBaseline(
        name: name,
        mean: newValue,
        standardDeviation: 0.0,
        minValue: newValue,
        maxValue: newValue,
        sampleCount: 1,
        lastUpdated: now,
      );
    }

    // Exponential moving average with alpha = 0.2 (gives ~7 day half-life)
    const alpha = 0.2;
    final newMean = mean * (1 - alpha) + newValue * alpha;

    // Update variance using Welford's online algorithm (simplified)
    final delta = newValue - mean;
    final newVariance = standardDeviation * standardDeviation * (1 - alpha) +
        alpha * delta * delta;
    final newStdDev = newVariance > 0 ? newVariance.sqrt() : 0.0;

    return SubsystemBaseline(
      name: name,
      mean: newMean,
      standardDeviation: newStdDev,
      minValue: newValue < minValue ? newValue : minValue,
      maxValue: newValue > maxValue ? newValue : maxValue,
      sampleCount: sampleCount + 1,
      lastUpdated: now,
    );
  }

  SubsystemBaseline copyWith({
    String? name,
    double? mean,
    double? standardDeviation,
    double? minValue,
    double? maxValue,
    int? sampleCount,
    DateTime? lastUpdated,
  }) {
    return SubsystemBaseline(
      name: name ?? this.name,
      mean: mean ?? this.mean,
      standardDeviation: standardDeviation ?? this.standardDeviation,
      minValue: minValue ?? this.minValue,
      maxValue: maxValue ?? this.maxValue,
      sampleCount: sampleCount ?? this.sampleCount,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() => {
        'name': name,
        'mean': mean,
        'standardDeviation': standardDeviation,
        'minValue': minValue,
        'maxValue': maxValue,
        'sampleCount': sampleCount,
        'lastUpdated': lastUpdated.toIso8601String(),
      };

  /// Create from JSON
  factory SubsystemBaseline.fromJson(Map<String, dynamic> json) {
    return SubsystemBaseline(
      name: json['name'] as String,
      mean: (json['mean'] as num).toDouble(),
      standardDeviation: (json['standardDeviation'] as num).toDouble(),
      minValue: (json['minValue'] as num).toDouble(),
      maxValue: (json['maxValue'] as num).toDouble(),
      sampleCount: json['sampleCount'] as int,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );
  }

  @override
  String toString() =>
      'Baseline($name: mean=${mean.toStringAsFixed(2)}, std=${standardDeviation.toStringAsFixed(2)}, n=$sampleCount)';
}

/// Complete personal baseline for all subsystems.
@immutable
class PersonalBaseline {
  /// Patient ID this baseline belongs to
  final String patientId;

  /// Physical subsystem baseline
  final SubsystemBaseline physical;

  /// Cardiac subsystem baseline
  final SubsystemBaseline cardiac;

  /// Sleep subsystem baseline
  final SubsystemBaseline sleep;

  /// Cognitive subsystem baseline
  final SubsystemBaseline cognitive;

  /// Overall HSS baseline
  final SubsystemBaseline overall;

  /// Timestamp of baseline creation
  final DateTime createdAt;

  /// Timestamp of last update
  final DateTime lastUpdatedAt;

  const PersonalBaseline({
    required this.patientId,
    required this.physical,
    required this.cardiac,
    required this.sleep,
    required this.cognitive,
    required this.overall,
    required this.createdAt,
    required this.lastUpdatedAt,
  });

  /// Create neutral baselines for new user
  PersonalBaseline.forNewUser(this.patientId)
      : physical = SubsystemBaseline.neutral('physical'),
        cardiac = SubsystemBaseline.neutral('cardiac'),
        sleep = SubsystemBaseline.neutral('sleep'),
        cognitive = SubsystemBaseline.neutral('cognitive'),
        overall = SubsystemBaseline.neutral('overall'),
        createdAt = DateTime.now(),
        lastUpdatedAt = DateTime.now();

  /// Check if all baselines have reliable data
  bool get isReliable =>
      physical.isReliable &&
      cardiac.isReliable &&
      sleep.isReliable &&
      cognitive.isReliable;

  /// Get adaptive weight for a subsystem based on its reliability and variance
  double getAdaptiveWeight(String subsystem, double currentValue) {
    final baseline = _getBaseline(subsystem);
    
    // Base weight
    double weight = 0.25; // Equal weight by default (4 subsystems = 0.25 each)

    // Increase weight if current value is anomalous (indicates problem)
    if (baseline.isAnomalous(currentValue)) {
      weight *= 1.5;
    }

    // Increase weight if baseline is reliable (we trust the data)
    if (baseline.isReliable) {
      weight *= 1.1;
    }

    // Decrease weight if baseline has high variance (less predictable)
    if (baseline.standardDeviation > 0.3) {
      weight *= 0.8;
    }

    return weight;
  }

  SubsystemBaseline _getBaseline(String subsystem) {
    switch (subsystem) {
      case 'physical':
        return physical;
      case 'cardiac':
        return cardiac;
      case 'sleep':
        return sleep;
      case 'cognitive':
        return cognitive;
      case 'overall':
        return overall;
      default:
        throw ArgumentError('Unknown subsystem: $subsystem');
    }
  }

  /// Update baselines with new observations
  PersonalBaseline updateWith({
    double? physicalStability,
    double? cardiacStability,
    double? sleepStability,
    double? cognitiveStability,
    double? overallScore,
  }) {
    return PersonalBaseline(
      patientId: patientId,
      physical: physicalStability != null
          ? physical.addObservation(physicalStability)
          : physical,
      cardiac: cardiacStability != null
          ? cardiac.addObservation(cardiacStability)
          : cardiac,
      sleep: sleepStability != null
          ? sleep.addObservation(sleepStability)
          : sleep,
      cognitive: cognitiveStability != null
          ? cognitive.addObservation(cognitiveStability)
          : cognitive,
      overall: overallScore != null
          ? overall.addObservation(overallScore)
          : overall,
      createdAt: createdAt,
      lastUpdatedAt: DateTime.now(),
    );
  }

  PersonalBaseline copyWith({
    String? patientId,
    SubsystemBaseline? physical,
    SubsystemBaseline? cardiac,
    SubsystemBaseline? sleep,
    SubsystemBaseline? cognitive,
    SubsystemBaseline? overall,
    DateTime? createdAt,
    DateTime? lastUpdatedAt,
  }) {
    return PersonalBaseline(
      patientId: patientId ?? this.patientId,
      physical: physical ?? this.physical,
      cardiac: cardiac ?? this.cardiac,
      sleep: sleep ?? this.sleep,
      cognitive: cognitive ?? this.cognitive,
      overall: overall ?? this.overall,
      createdAt: createdAt ?? this.createdAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() => {
        'patientId': patientId,
        'physical': physical.toJson(),
        'cardiac': cardiac.toJson(),
        'sleep': sleep.toJson(),
        'cognitive': cognitive.toJson(),
        'overall': overall.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'lastUpdatedAt': lastUpdatedAt.toIso8601String(),
      };

  /// Create from JSON
  factory PersonalBaseline.fromJson(Map<String, dynamic> json) {
    return PersonalBaseline(
      patientId: json['patientId'] as String,
      physical:
          SubsystemBaseline.fromJson(json['physical'] as Map<String, dynamic>),
      cardiac:
          SubsystemBaseline.fromJson(json['cardiac'] as Map<String, dynamic>),
      sleep: SubsystemBaseline.fromJson(json['sleep'] as Map<String, dynamic>),
      cognitive:
          SubsystemBaseline.fromJson(json['cognitive'] as Map<String, dynamic>),
      overall:
          SubsystemBaseline.fromJson(json['overall'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastUpdatedAt: DateTime.parse(json['lastUpdatedAt'] as String),
    );
  }

  @override
  String toString() =>
      'PersonalBaseline($patientId, reliable=$isReliable, updated=${lastUpdatedAt.toIso8601String()})';
}

// Extension to add sqrt to double
extension _DoubleSqrt on double {
  double sqrt() => this >= 0 ? this.toDouble() : 0.0;
}
