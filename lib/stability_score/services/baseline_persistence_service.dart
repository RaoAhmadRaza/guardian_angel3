/// Baseline Persistence Service
///
/// Handles saving and loading personal baselines to SharedPreferences.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/personal_baseline.dart';
import '../models/stability_score_result.dart';

/// Service for persisting personal baselines.
class BaselinePersistenceService {
  BaselinePersistenceService._();
  static final BaselinePersistenceService _instance = BaselinePersistenceService._();
  static BaselinePersistenceService get instance => _instance;

  /// SharedPreferences keys
  static const String _keyBaselinePrefix = 'hss_baseline_';
  static const String _keyHistoryPrefix = 'hss_history_';

  /// Maximum history entries to keep
  static const int _maxHistoryEntries = 90; // 90 days

  /// Load baseline for a patient
  ///
  /// Returns existing baseline or creates a new neutral one
  Future<PersonalBaseline> loadBaseline(String patientId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_keyBaselinePrefix$patientId';
      final json = prefs.getString(key);

      if (json != null && json.isNotEmpty) {
        final data = jsonDecode(json) as Map<String, dynamic>;
        final baseline = PersonalBaseline.fromJson(data);
        debugPrint('[BaselinePersistence] Loaded baseline for $patientId');
        return baseline;
      }

      // Create new baseline for new user
      final newBaseline = PersonalBaseline.forNewUser(patientId);
      debugPrint('[BaselinePersistence] Created new baseline for $patientId');
      return newBaseline;
    } catch (e) {
      debugPrint('[BaselinePersistence] Error loading baseline: $e');
      return PersonalBaseline.forNewUser(patientId);
    }
  }

  /// Save baseline for a patient
  Future<bool> saveBaseline(PersonalBaseline baseline) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_keyBaselinePrefix${baseline.patientId}';
      final json = jsonEncode(baseline.toJson());
      await prefs.setString(key, json);
      debugPrint('[BaselinePersistence] Saved baseline for ${baseline.patientId}');
      return true;
    } catch (e) {
      debugPrint('[BaselinePersistence] Error saving baseline: $e');
      return false;
    }
  }

  /// Load score history for a patient
  Future<List<StabilityScoreHistoryEntry>> loadHistory(String patientId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_keyHistoryPrefix$patientId';
      final json = prefs.getString(key);

      if (json != null && json.isNotEmpty) {
        final List<dynamic> data = jsonDecode(json);
        final history = data
            .map((e) => StabilityScoreHistoryEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        debugPrint('[BaselinePersistence] Loaded ${history.length} history entries');
        return history;
      }

      return [];
    } catch (e) {
      debugPrint('[BaselinePersistence] Error loading history: $e');
      return [];
    }
  }

  /// Add a new history entry
  Future<bool> addHistoryEntry(
    String patientId,
    StabilityScoreHistoryEntry entry,
  ) async {
    try {
      final history = await loadHistory(patientId);
      history.add(entry);

      // Keep only recent entries
      if (history.length > _maxHistoryEntries) {
        history.removeRange(0, history.length - _maxHistoryEntries);
      }

      final prefs = await SharedPreferences.getInstance();
      final key = '$_keyHistoryPrefix$patientId';
      final json = jsonEncode(history.map((e) => e.toJson()).toList());
      await prefs.setString(key, json);

      debugPrint('[BaselinePersistence] Added history entry, total=${history.length}');
      return true;
    } catch (e) {
      debugPrint('[BaselinePersistence] Error adding history entry: $e');
      return false;
    }
  }

  /// Get history for last N days
  Future<List<StabilityScoreHistoryEntry>> getRecentHistory(
    String patientId,
    int days,
  ) async {
    final history = await loadHistory(patientId);
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return history.where((e) => e.timestamp.isAfter(cutoff)).toList();
  }

  /// Clear all data for a patient (for testing/reset)
  Future<void> clearPatientData(String patientId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_keyBaselinePrefix$patientId');
      await prefs.remove('$_keyHistoryPrefix$patientId');
      debugPrint('[BaselinePersistence] Cleared data for $patientId');
    } catch (e) {
      debugPrint('[BaselinePersistence] Error clearing data: $e');
    }
  }

  /// Get trending data for charts
  Future<TrendingData> getTrendingData(String patientId, {int days = 7}) async {
    final history = await getRecentHistory(patientId, days);

    if (history.isEmpty) {
      return TrendingData.empty();
    }

    // Calculate averages and trends
    final scores = history.map((e) => e.score).toList();
    final avgScore = scores.reduce((a, b) => a + b) / scores.length;

    // Calculate trend (slope)
    double trend = 0.0;
    if (scores.length >= 2) {
      final firstHalf = scores.sublist(0, scores.length ~/ 2);
      final secondHalf = scores.sublist(scores.length ~/ 2);
      final firstAvg = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
      final secondAvg = secondHalf.reduce((a, b) => a + b) / secondHalf.length;
      trend = secondAvg - firstAvg;
    }

    // Get subsystem trends
    final subsystemTrends = <String, double>{};
    for (final subsystem in ['physical', 'cardiac', 'sleep', 'cognitive']) {
      final subsystemScores = history
          .where((e) => e.subsystemScores.containsKey(subsystem))
          .map((e) => e.subsystemScores[subsystem]!)
          .toList();

      if (subsystemScores.isNotEmpty) {
        subsystemTrends[subsystem] =
            subsystemScores.reduce((a, b) => a + b) / subsystemScores.length;
      }
    }

    return TrendingData(
      averageScore: avgScore,
      trend: trend,
      dataPoints: history.length,
      subsystemAverages: subsystemTrends,
      history: history,
    );
  }
}

/// Data class for trending analysis
class TrendingData {
  final double averageScore;
  final double trend;
  final int dataPoints;
  final Map<String, double> subsystemAverages;
  final List<StabilityScoreHistoryEntry> history;

  const TrendingData({
    required this.averageScore,
    required this.trend,
    required this.dataPoints,
    required this.subsystemAverages,
    required this.history,
  });

  factory TrendingData.empty() => const TrendingData(
        averageScore: 0.0,
        trend: 0.0,
        dataPoints: 0,
        subsystemAverages: {},
        history: [],
      );

  bool get hasData => dataPoints > 0;

  String get trendDescription {
    if (trend > 5) return 'Improving significantly';
    if (trend > 2) return 'Improving';
    if (trend < -5) return 'Declining significantly';
    if (trend < -2) return 'Declining';
    return 'Stable';
  }
}
