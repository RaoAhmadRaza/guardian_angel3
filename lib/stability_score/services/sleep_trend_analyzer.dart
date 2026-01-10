/// Sleep Trend Analyzer Service
///
/// Analyzes sleep data from NormalizedSleepSession to compute
/// SleepSignals for the HSS fusion engine.
library;

import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../../health/models/normalized_health_data.dart';
import '../models/subsystem_signals.dart';

/// Service that analyzes sleep sessions and computes stability signals.
class SleepTrendAnalyzer {
  SleepTrendAnalyzer._();
  static final SleepTrendAnalyzer _instance = SleepTrendAnalyzer._();
  static SleepTrendAnalyzer get instance => _instance;

  /// Number of days to analyze for trend computation
  static const int _analysisWindowDays = 7;

  /// Analyze sleep sessions and produce stability signals.
  ///
  /// [sessions] - List of normalized sleep sessions from the last 7 days
  /// Returns [SleepSignals] ready for HSS computation
  SleepSignals analyze(List<NormalizedSleepSession> sessions) {
    if (sessions.isEmpty) {
      debugPrint('[SleepTrendAnalyzer] No sessions to analyze');
      return const SleepSignals.empty();
    }

    // Filter to last 7 days and valid sessions
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: _analysisWindowDays));
    final recentSessions = sessions
        .where((s) => s.isValid && s.isMinimumLength && s.sleepEnd.isAfter(cutoff))
        .toList()
      ..sort((a, b) => b.sleepEnd.compareTo(a.sleepEnd)); // Most recent first

    if (recentSessions.isEmpty) {
      debugPrint('[SleepTrendAnalyzer] No valid recent sessions');
      return const SleepSignals.empty();
    }

    // Calculate average duration
    final durations = recentSessions.map((s) => s.totalHours).toList();
    final averageDuration = _calculateMean(durations);

    // Calculate duration variance (standard deviation)
    final durationVariance = _calculateStandardDeviation(durations);

    // Calculate sleep stage percentages (if stage data available)
    double deepSleepPercent = 0.0;
    double remSleepPercent = 0.0;
    int sessionsWithStages = 0;

    for (final session in recentSessions) {
      if (session.hasStageData) {
        final percentages = session.stagePercentages;
        deepSleepPercent += percentages[NormalizedSleepStage.deep] ?? 0.0;
        remSleepPercent += percentages[NormalizedSleepStage.rem] ?? 0.0;
        sessionsWithStages++;
      }
    }

    if (sessionsWithStages > 0) {
      deepSleepPercent /= sessionsWithStages;
      remSleepPercent /= sessionsWithStages;
    }

    // Calculate sleep efficiency (simplified: ratio of sleep time to expected time)
    // Assuming 8 hours in bed, calculate what fraction was actual sleep
    final sleepEfficiency = (averageDuration / 8.0).clamp(0.0, 1.0);

    // Calculate bedtime consistency
    final bedtimeConsistency = _calculateBedtimeConsistency(recentSessions);

    final lastSessionEnd = recentSessions.first.sleepEnd;

    debugPrint(
        '[SleepTrendAnalyzer] Analyzed ${recentSessions.length} sessions: '
        'avgDuration=${averageDuration.toStringAsFixed(1)}h, '
        'variance=${durationVariance.toStringAsFixed(2)}, '
        'deepSleep=${deepSleepPercent.toStringAsFixed(1)}%, '
        'rem=${remSleepPercent.toStringAsFixed(1)}%');

    return SleepSignals(
      averageDurationHours: averageDuration,
      durationVariance: durationVariance,
      deepSleepPercent: deepSleepPercent,
      remSleepPercent: remSleepPercent,
      sleepEfficiency: sleepEfficiency,
      bedtimeConsistency: bedtimeConsistency,
      sessionsCount: recentSessions.length,
      lastSessionEnd: lastSessionEnd,
      hasData: true,
    );
  }

  /// Calculate bedtime consistency score (0.0-1.0)
  /// Lower variance in bedtime = higher consistency
  double _calculateBedtimeConsistency(List<NormalizedSleepSession> sessions) {
    if (sessions.length < 2) return 1.0; // Single session = perfectly consistent

    // Extract bedtime hours (normalized to 0-24 with wrap-around handling)
    final bedtimes = sessions.map((s) {
      var hour = s.sleepStart.hour + s.sleepStart.minute / 60.0;
      // Handle late night times (11 PM - 2 AM) by normalizing
      if (hour < 6) hour += 24; // 1 AM becomes 25, 2 AM becomes 26
      return hour;
    }).toList();

    final variance = _calculateStandardDeviation(bedtimes);

    // Convert variance to consistency score
    // 0 hours variance = 1.0 consistency
    // 2+ hours variance = 0.0 consistency
    final consistency = (1.0 - (variance / 2.0)).clamp(0.0, 1.0);

    return consistency;
  }

  /// Calculate mean of a list of values
  double _calculateMean(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// Calculate standard deviation of a list of values
  double _calculateStandardDeviation(List<double> values) {
    if (values.length < 2) return 0.0;

    final mean = _calculateMean(values);
    final squaredDiffs = values.map((v) => (v - mean) * (v - mean));
    final variance = squaredDiffs.reduce((a, b) => a + b) / values.length;

    return math.sqrt(variance);
  }
}
