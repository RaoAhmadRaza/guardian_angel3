/// Subsystem Signal Models for Health Stability Score
///
/// These models represent normalized inputs from each health subsystem.
/// All values are normalized to 0.0-1.0 range for consistent processing.
library;

import 'package:flutter/foundation.dart';

// ═══════════════════════════════════════════════════════════════════════════
// PHYSICAL SIGNALS (From Fall Detection)
// ═══════════════════════════════════════════════════════════════════════════

/// Physical mobility signals from fall detection subsystem.
@immutable
class PhysicalSignals {
  /// Fall probability from CNN model (0.0 = no fall risk, 1.0 = high fall risk)
  final double fallProbability;

  /// Average fall probability over last 24 hours
  final double averageFallProbability24h;

  /// Maximum fall probability spike in last 24 hours
  final double maxFallProbability24h;

  /// Number of high-risk events (prob > 0.7) in last 24 hours
  final int highRiskEventCount;

  /// Timestamp of last reading
  final DateTime timestamp;

  /// Whether data is available
  final bool hasData;

  const PhysicalSignals({
    required this.fallProbability,
    required this.averageFallProbability24h,
    required this.maxFallProbability24h,
    required this.highRiskEventCount,
    required this.timestamp,
    this.hasData = true,
  });

  /// Create empty signals when no data available
  const PhysicalSignals.empty()
      : fallProbability = 0.0,
        averageFallProbability24h = 0.0,
        maxFallProbability24h = 0.0,
        highRiskEventCount = 0,
        timestamp = const _EpochDateTime(),
        hasData = false;

  /// Compute physical risk score (0.0 = healthy, 1.0 = high risk)
  double get riskScore {
    if (!hasData) return 0.0;
    // Weight current reading heavily, but factor in trend
    return (fallProbability * 0.5 +
            averageFallProbability24h * 0.3 +
            (highRiskEventCount / 10.0).clamp(0.0, 1.0) * 0.2)
        .clamp(0.0, 1.0);
  }

  /// Compute physical stability (inverse of risk)
  double get stabilityScore => 1.0 - riskScore;

  PhysicalSignals copyWith({
    double? fallProbability,
    double? averageFallProbability24h,
    double? maxFallProbability24h,
    int? highRiskEventCount,
    DateTime? timestamp,
    bool? hasData,
  }) {
    return PhysicalSignals(
      fallProbability: fallProbability ?? this.fallProbability,
      averageFallProbability24h:
          averageFallProbability24h ?? this.averageFallProbability24h,
      maxFallProbability24h:
          maxFallProbability24h ?? this.maxFallProbability24h,
      highRiskEventCount: highRiskEventCount ?? this.highRiskEventCount,
      timestamp: timestamp ?? this.timestamp,
      hasData: hasData ?? this.hasData,
    );
  }

  @override
  String toString() =>
      'PhysicalSignals(risk=${riskScore.toStringAsFixed(2)}, current=${fallProbability.toStringAsFixed(2)})';
}

// ═══════════════════════════════════════════════════════════════════════════
// CARDIAC SIGNALS (From Arrhythmia Service)
// ═══════════════════════════════════════════════════════════════════════════

/// Cardiac risk signals from arrhythmia detection subsystem.
@immutable
class CardiacSignals {
  /// Arrhythmia risk probability from XGBoost model (0.0-1.0)
  final double arrhythmiaRisk;

  /// Current heart rate in BPM
  final int heartRateBpm;

  /// Resting heart rate trend (7-day average)
  final double restingHeartRateTrend;

  /// HRV SDNN value in milliseconds
  final double hrvSdnn;

  /// HRV RMSSD value in milliseconds
  final double hrvRmssd;

  /// Confidence level of the reading (0.0-1.0)
  final double confidence;

  /// Timestamp of last reading
  final DateTime timestamp;

  /// Whether data is available
  final bool hasData;

  const CardiacSignals({
    required this.arrhythmiaRisk,
    required this.heartRateBpm,
    required this.restingHeartRateTrend,
    required this.hrvSdnn,
    required this.hrvRmssd,
    required this.confidence,
    required this.timestamp,
    this.hasData = true,
  });

  /// Create empty signals when no data available
  const CardiacSignals.empty()
      : arrhythmiaRisk = 0.0,
        heartRateBpm = 0,
        restingHeartRateTrend = 0.0,
        hrvSdnn = 0.0,
        hrvRmssd = 0.0,
        confidence = 0.0,
        timestamp = const _EpochDateTime(),
        hasData = false;

  /// Compute cardiac risk score (0.0 = healthy, 1.0 = high risk)
  double get riskScore {
    if (!hasData) return 0.0;

    // Heart rate risk (too low or too high)
    double hrRisk = 0.0;
    if (heartRateBpm > 0) {
      if (heartRateBpm < 50 || heartRateBpm > 100) {
        hrRisk = ((heartRateBpm - 75).abs() / 75.0).clamp(0.0, 1.0);
      }
    }

    // HRV risk (low HRV indicates stress/poor health)
    double hrvRisk = 0.0;
    if (hrvSdnn > 0) {
      // SDNN < 50ms is concerning, < 20ms is high risk
      hrvRisk = (1.0 - (hrvSdnn / 100.0)).clamp(0.0, 1.0);
    }

    // Weighted combination
    return (arrhythmiaRisk * 0.5 + hrRisk * 0.25 + hrvRisk * 0.25)
        .clamp(0.0, 1.0);
  }

  /// Compute cardiac stability (inverse of risk)
  double get stabilityScore => 1.0 - riskScore;

  CardiacSignals copyWith({
    double? arrhythmiaRisk,
    int? heartRateBpm,
    double? restingHeartRateTrend,
    double? hrvSdnn,
    double? hrvRmssd,
    double? confidence,
    DateTime? timestamp,
    bool? hasData,
  }) {
    return CardiacSignals(
      arrhythmiaRisk: arrhythmiaRisk ?? this.arrhythmiaRisk,
      heartRateBpm: heartRateBpm ?? this.heartRateBpm,
      restingHeartRateTrend:
          restingHeartRateTrend ?? this.restingHeartRateTrend,
      hrvSdnn: hrvSdnn ?? this.hrvSdnn,
      hrvRmssd: hrvRmssd ?? this.hrvRmssd,
      confidence: confidence ?? this.confidence,
      timestamp: timestamp ?? this.timestamp,
      hasData: hasData ?? this.hasData,
    );
  }

  @override
  String toString() =>
      'CardiacSignals(risk=${riskScore.toStringAsFixed(2)}, arrhythmia=${arrhythmiaRisk.toStringAsFixed(2)}, hr=$heartRateBpm)';
}

// ═══════════════════════════════════════════════════════════════════════════
// SLEEP SIGNALS (From NormalizedSleepSession)
// ═══════════════════════════════════════════════════════════════════════════

/// Sleep stability signals computed from sleep sessions.
@immutable
class SleepSignals {
  /// Average sleep duration in hours (7-day)
  final double averageDurationHours;

  /// Sleep duration variance (standard deviation in hours)
  final double durationVariance;

  /// Percentage of time in deep sleep (ideal: 15-25%)
  final double deepSleepPercent;

  /// Percentage of time in REM sleep (ideal: 20-25%)
  final double remSleepPercent;

  /// Sleep efficiency: time asleep / time in bed (0.0-1.0)
  final double sleepEfficiency;

  /// Average bedtime consistency score (0.0-1.0)
  final double bedtimeConsistency;

  /// Number of sleep sessions in last 7 days
  final int sessionsCount;

  /// Timestamp of last session
  final DateTime lastSessionEnd;

  /// Whether data is available
  final bool hasData;

  const SleepSignals({
    required this.averageDurationHours,
    required this.durationVariance,
    required this.deepSleepPercent,
    required this.remSleepPercent,
    required this.sleepEfficiency,
    required this.bedtimeConsistency,
    required this.sessionsCount,
    required this.lastSessionEnd,
    this.hasData = true,
  });

  /// Create empty signals when no data available
  const SleepSignals.empty()
      : averageDurationHours = 0.0,
        durationVariance = 0.0,
        deepSleepPercent = 0.0,
        remSleepPercent = 0.0,
        sleepEfficiency = 0.0,
        bedtimeConsistency = 0.0,
        sessionsCount = 0,
        lastSessionEnd = const _EpochDateTime(),
        hasData = false;

  /// Compute sleep stability score (0.0 = poor, 1.0 = excellent)
  double get stabilityScore {
    if (!hasData || sessionsCount == 0) return 0.5; // Neutral if no data

    double score = 0.0;

    // Duration score (ideal: 7-9 hours)
    if (averageDurationHours >= 7 && averageDurationHours <= 9) {
      score += 0.25;
    } else if (averageDurationHours >= 6 && averageDurationHours <= 10) {
      score += 0.15;
    } else {
      score += 0.05;
    }

    // Variance score (lower is better)
    final varianceScore = (1.0 - (durationVariance / 2.0)).clamp(0.0, 1.0);
    score += varianceScore * 0.20;

    // Deep sleep score (ideal: 15-25%)
    if (deepSleepPercent >= 15 && deepSleepPercent <= 25) {
      score += 0.15;
    } else if (deepSleepPercent >= 10 && deepSleepPercent <= 30) {
      score += 0.10;
    } else {
      score += 0.05;
    }

    // REM sleep score (ideal: 20-25%)
    if (remSleepPercent >= 20 && remSleepPercent <= 25) {
      score += 0.15;
    } else if (remSleepPercent >= 15 && remSleepPercent <= 30) {
      score += 0.10;
    } else {
      score += 0.05;
    }

    // Efficiency score
    score += sleepEfficiency * 0.15;

    // Consistency score
    score += bedtimeConsistency * 0.10;

    return score.clamp(0.0, 1.0);
  }

  /// Compute sleep instability (inverse of stability)
  double get instabilityScore => 1.0 - stabilityScore;

  SleepSignals copyWith({
    double? averageDurationHours,
    double? durationVariance,
    double? deepSleepPercent,
    double? remSleepPercent,
    double? sleepEfficiency,
    double? bedtimeConsistency,
    int? sessionsCount,
    DateTime? lastSessionEnd,
    bool? hasData,
  }) {
    return SleepSignals(
      averageDurationHours: averageDurationHours ?? this.averageDurationHours,
      durationVariance: durationVariance ?? this.durationVariance,
      deepSleepPercent: deepSleepPercent ?? this.deepSleepPercent,
      remSleepPercent: remSleepPercent ?? this.remSleepPercent,
      sleepEfficiency: sleepEfficiency ?? this.sleepEfficiency,
      bedtimeConsistency: bedtimeConsistency ?? this.bedtimeConsistency,
      sessionsCount: sessionsCount ?? this.sessionsCount,
      lastSessionEnd: lastSessionEnd ?? this.lastSessionEnd,
      hasData: hasData ?? this.hasData,
    );
  }

  @override
  String toString() =>
      'SleepSignals(stability=${stabilityScore.toStringAsFixed(2)}, avgHrs=${averageDurationHours.toStringAsFixed(1)})';
}

// ═══════════════════════════════════════════════════════════════════════════
// COGNITIVE/BEHAVIORAL SIGNALS
// ═══════════════════════════════════════════════════════════════════════════

/// Cognitive and behavioral stability signals.
@immutable
class CognitiveSignals {
  /// Medication adherence rate (0.0-1.0)
  final double medicationAdherence;

  /// Number of medications taken vs scheduled in last 7 days
  final int medicationsTaken;
  final int medicationsScheduled;

  /// Self-reported mood score (1-5, normalized to 0.0-1.0)
  final double moodScore;

  /// Mood trend over 7 days (-1.0 declining, 0.0 stable, 1.0 improving)
  final double moodTrend;

  /// Check-in completion rate (0.0-1.0)
  final double checkInRate;

  /// Timestamp of last check-in
  final DateTime lastCheckIn;

  /// Whether data is available
  final bool hasData;

  const CognitiveSignals({
    required this.medicationAdherence,
    required this.medicationsTaken,
    required this.medicationsScheduled,
    required this.moodScore,
    required this.moodTrend,
    required this.checkInRate,
    required this.lastCheckIn,
    this.hasData = true,
  });

  /// Create empty signals when no data available
  const CognitiveSignals.empty()
      : medicationAdherence = 0.0,
        medicationsTaken = 0,
        medicationsScheduled = 0,
        moodScore = 0.5,
        moodTrend = 0.0,
        checkInRate = 0.0,
        lastCheckIn = const _EpochDateTime(),
        hasData = false;

  /// Compute cognitive stability score (0.0 = poor, 1.0 = excellent)
  double get stabilityScore {
    if (!hasData) return 0.5; // Neutral if no data

    double score = 0.0;

    // Medication adherence (weight: 40%)
    score += medicationAdherence * 0.40;

    // Mood score (weight: 30%)
    score += moodScore * 0.30;

    // Mood trend bonus/penalty (weight: 15%)
    final trendContribution = (moodTrend + 1.0) / 2.0; // Normalize -1..1 to 0..1
    score += trendContribution * 0.15;

    // Check-in rate (weight: 15%)
    score += checkInRate * 0.15;

    return score.clamp(0.0, 1.0);
  }

  /// Compute cognitive instability (inverse of stability)
  double get instabilityScore => 1.0 - stabilityScore;

  CognitiveSignals copyWith({
    double? medicationAdherence,
    int? medicationsTaken,
    int? medicationsScheduled,
    double? moodScore,
    double? moodTrend,
    double? checkInRate,
    DateTime? lastCheckIn,
    bool? hasData,
  }) {
    return CognitiveSignals(
      medicationAdherence: medicationAdherence ?? this.medicationAdherence,
      medicationsTaken: medicationsTaken ?? this.medicationsTaken,
      medicationsScheduled: medicationsScheduled ?? this.medicationsScheduled,
      moodScore: moodScore ?? this.moodScore,
      moodTrend: moodTrend ?? this.moodTrend,
      checkInRate: checkInRate ?? this.checkInRate,
      lastCheckIn: lastCheckIn ?? this.lastCheckIn,
      hasData: hasData ?? this.hasData,
    );
  }

  @override
  String toString() =>
      'CognitiveSignals(stability=${stabilityScore.toStringAsFixed(2)}, medAdherence=${(medicationAdherence * 100).toStringAsFixed(0)}%)';
}

// ═══════════════════════════════════════════════════════════════════════════
// AGGREGATED INPUT
// ═══════════════════════════════════════════════════════════════════════════

/// Complete input to the HSS fusion engine.
@immutable
class StabilityInput {
  final PhysicalSignals physical;
  final CardiacSignals cardiac;
  final SleepSignals sleep;
  final CognitiveSignals cognitive;
  final DateTime collectedAt;

  const StabilityInput({
    required this.physical,
    required this.cardiac,
    required this.sleep,
    required this.cognitive,
    required this.collectedAt,
  });

  /// Create empty input with no data
  StabilityInput.empty()
      : physical = const PhysicalSignals.empty(),
        cardiac = const CardiacSignals.empty(),
        sleep = const SleepSignals.empty(),
        cognitive = const CognitiveSignals.empty(),
        collectedAt = DateTime.now();

  /// Check which subsystems have data
  int get subsystemsWithData =>
      (physical.hasData ? 1 : 0) +
      (cardiac.hasData ? 1 : 0) +
      (sleep.hasData ? 1 : 0) +
      (cognitive.hasData ? 1 : 0);

  /// Check if we have minimum data for scoring
  bool get hasMinimumData => subsystemsWithData >= 2;

  StabilityInput copyWith({
    PhysicalSignals? physical,
    CardiacSignals? cardiac,
    SleepSignals? sleep,
    CognitiveSignals? cognitive,
    DateTime? collectedAt,
  }) {
    return StabilityInput(
      physical: physical ?? this.physical,
      cardiac: cardiac ?? this.cardiac,
      sleep: sleep ?? this.sleep,
      cognitive: cognitive ?? this.cognitive,
      collectedAt: collectedAt ?? this.collectedAt,
    );
  }

  @override
  String toString() =>
      'StabilityInput(subsystems=$subsystemsWithData/4, collected=${collectedAt.toIso8601String()})';
}

// Helper class for const DateTime
class _EpochDateTime implements DateTime {
  const _EpochDateTime();

  @override
  int get millisecondsSinceEpoch => 0;
  @override
  int get microsecondsSinceEpoch => 0;
  @override
  bool get isUtc => true;
  @override
  int get year => 1970;
  @override
  int get month => 1;
  @override
  int get day => 1;
  @override
  int get hour => 0;
  @override
  int get minute => 0;
  @override
  int get second => 0;
  @override
  int get millisecond => 0;
  @override
  int get microsecond => 0;
  @override
  int get weekday => DateTime.thursday;
  @override
  String get timeZoneName => 'UTC';
  @override
  Duration get timeZoneOffset => Duration.zero;

  @override
  DateTime add(Duration duration) => DateTime.fromMillisecondsSinceEpoch(duration.inMilliseconds);
  @override
  DateTime subtract(Duration duration) => DateTime.fromMillisecondsSinceEpoch(-duration.inMilliseconds);
  @override
  Duration difference(DateTime other) => Duration(milliseconds: -other.millisecondsSinceEpoch);
  @override
  bool isAfter(DateTime other) => false;
  @override
  bool isAtSameMomentAs(DateTime other) => other.millisecondsSinceEpoch == 0;
  @override
  bool isBefore(DateTime other) => other.millisecondsSinceEpoch > 0;
  @override
  int compareTo(DateTime other) => -other.millisecondsSinceEpoch.sign;
  @override
  String toIso8601String() => '1970-01-01T00:00:00.000Z';
  @override
  DateTime toLocal() => DateTime.fromMillisecondsSinceEpoch(0);
  @override
  DateTime toUtc() => DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  @override
  String toString() => '1970-01-01 00:00:00.000Z';
}
