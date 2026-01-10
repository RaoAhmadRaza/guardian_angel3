/// Cognitive Signal Collector Service
///
/// Collects and computes cognitive/behavioral signals from:
/// - Medication adherence (from MedicationService)
/// - Mood check-ins (from SharedPreferences)
/// - Daily check-in completion rate
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/medication_service.dart';
import '../../services/session_service.dart';
import '../models/subsystem_signals.dart';

/// Service that collects cognitive and behavioral signals.
class CognitiveSignalCollector {
  CognitiveSignalCollector._();
  static final CognitiveSignalCollector _instance = CognitiveSignalCollector._();
  static CognitiveSignalCollector get instance => _instance;

  /// SharedPreferences keys
  static const String _keyMoodHistory = 'hss_mood_history';
  static const String _keyCheckInHistory = 'hss_checkin_history';

  /// Number of days for analysis window
  static const int _analysisWindowDays = 7;

  /// Collect cognitive signals for a patient.
  ///
  /// Returns [CognitiveSignals] ready for HSS computation
  Future<CognitiveSignals> collect() async {
    try {
      final patientId = await SessionService.instance.getCurrentUid();
      if (patientId == null || patientId.isEmpty) {
        debugPrint('[CognitiveSignalCollector] No patient ID');
        return const CognitiveSignals.empty();
      }

      // Collect medication adherence
      final medicationData = await _collectMedicationAdherence(patientId);

      // Collect mood data
      final moodData = await _collectMoodData();

      // Collect check-in data
      final checkInData = await _collectCheckInData();

      debugPrint(
          '[CognitiveSignalCollector] Collected: '
          'medAdherence=${(medicationData.adherence * 100).toStringAsFixed(0)}%, '
          'mood=${moodData.score.toStringAsFixed(2)}, '
          'checkIn=${(checkInData.rate * 100).toStringAsFixed(0)}%');

      return CognitiveSignals(
        medicationAdherence: medicationData.adherence,
        medicationsTaken: medicationData.taken,
        medicationsScheduled: medicationData.scheduled,
        moodScore: moodData.score,
        moodTrend: moodData.trend,
        checkInRate: checkInData.rate,
        lastCheckIn: checkInData.lastCheckIn,
        hasData: true,
      );
    } catch (e) {
      debugPrint('[CognitiveSignalCollector] Error collecting signals: $e');
      return const CognitiveSignals.empty();
    }
  }

  /// Collect medication adherence data
  Future<_MedicationAdherenceData> _collectMedicationAdherence(
    String patientId,
  ) async {
    try {
      final medications = await MedicationService.instance.getMedications(patientId);

      if (medications.isEmpty) {
        // No medications = 100% adherent (nothing to take)
        return const _MedicationAdherenceData(
          adherence: 1.0,
          taken: 0,
          scheduled: 0,
        );
      }

      // Calculate adherence based on isTaken flag
      // In a real app, you'd track historical dose records
      int scheduled = 0;
      int taken = 0;

      // For each medication, count as scheduled
      // This is simplified - in production, you'd track per-day per-dose
      for (final med in medications) {
        scheduled++;
        if (med.isTaken) {
          taken++;
        }
      }

      final adherence = scheduled > 0 ? taken / scheduled : 1.0;

      return _MedicationAdherenceData(
        adherence: adherence.clamp(0.0, 1.0),
        taken: taken,
        scheduled: scheduled,
      );
    } catch (e) {
      debugPrint('[CognitiveSignalCollector] Error getting medication data: $e');
      return const _MedicationAdherenceData(
        adherence: 0.5,
        taken: 0,
        scheduled: 0,
      );
    }
  }

  /// Collect mood data from stored check-ins
  Future<_MoodData> _collectMoodData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_keyMoodHistory);

      if (historyJson == null || historyJson.isEmpty) {
        return _MoodData(
          score: 0.5, // Neutral if no data
          trend: 0.0,
        );
      }

      final List<dynamic> history = jsonDecode(historyJson);
      if (history.isEmpty) {
        return _MoodData(score: 0.5, trend: 0.0);
      }

      // Filter to last 7 days
      final now = DateTime.now();
      final cutoff = now.subtract(const Duration(days: _analysisWindowDays));

      final recentEntries = history
          .map((e) => _MoodEntry.fromJson(e as Map<String, dynamic>))
          .where((e) => e.timestamp.isAfter(cutoff))
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      if (recentEntries.isEmpty) {
        return _MoodData(score: 0.5, trend: 0.0);
      }

      // Calculate average mood score (normalized from 1-5 to 0.0-1.0)
      final scores = recentEntries.map((e) => (e.score - 1) / 4.0).toList();
      final averageScore = scores.reduce((a, b) => a + b) / scores.length;

      // Calculate trend (simple linear slope)
      double trend = 0.0;
      if (recentEntries.length >= 2) {
        final firstHalf = scores.sublist(0, scores.length ~/ 2);
        final secondHalf = scores.sublist(scores.length ~/ 2);

        final firstAvg = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
        final secondAvg = secondHalf.reduce((a, b) => a + b) / secondHalf.length;

        trend = (secondAvg - firstAvg).clamp(-1.0, 1.0);
      }

      return _MoodData(
        score: averageScore.clamp(0.0, 1.0),
        trend: trend,
      );
    } catch (e) {
      debugPrint('[CognitiveSignalCollector] Error getting mood data: $e');
      return _MoodData(score: 0.5, trend: 0.0);
    }
  }

  /// Collect check-in completion data
  Future<_CheckInData> _collectCheckInData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_keyCheckInHistory);

      if (historyJson == null || historyJson.isEmpty) {
        return _CheckInData(
          rate: 0.0,
          lastCheckIn: DateTime.fromMillisecondsSinceEpoch(0),
        );
      }

      final List<dynamic> history = jsonDecode(historyJson);
      if (history.isEmpty) {
        return _CheckInData(
          rate: 0.0,
          lastCheckIn: DateTime.fromMillisecondsSinceEpoch(0),
        );
      }

      // Parse timestamps
      final checkIns = history
          .map((e) => DateTime.parse(e as String))
          .toList()
        ..sort((a, b) => b.compareTo(a)); // Most recent first

      // Count check-ins in last 7 days
      final now = DateTime.now();
      final cutoff = now.subtract(const Duration(days: _analysisWindowDays));
      final recentCheckIns = checkIns.where((d) => d.isAfter(cutoff)).length;

      // Rate = check-ins / days (capped at 1.0)
      final rate = (recentCheckIns / _analysisWindowDays).clamp(0.0, 1.0);

      return _CheckInData(
        rate: rate,
        lastCheckIn: checkIns.first,
      );
    } catch (e) {
      debugPrint('[CognitiveSignalCollector] Error getting check-in data: $e');
      return _CheckInData(
        rate: 0.0,
        lastCheckIn: DateTime.fromMillisecondsSinceEpoch(0),
      );
    }
  }

  /// Record a mood check-in
  ///
  /// [score] - Mood score from 1 (very bad) to 5 (excellent)
  Future<void> recordMoodCheckIn(int score) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_keyMoodHistory);

      List<dynamic> history = [];
      if (historyJson != null && historyJson.isNotEmpty) {
        history = jsonDecode(historyJson);
      }

      // Add new entry
      final entry = _MoodEntry(
        score: score.clamp(1, 5),
        timestamp: DateTime.now(),
      );
      history.add(entry.toJson());

      // Keep only last 30 days
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      history = history
          .map((e) => _MoodEntry.fromJson(e as Map<String, dynamic>))
          .where((e) => e.timestamp.isAfter(cutoff))
          .map((e) => e.toJson())
          .toList();

      await prefs.setString(_keyMoodHistory, jsonEncode(history));
      debugPrint('[CognitiveSignalCollector] Recorded mood: $score');
    } catch (e) {
      debugPrint('[CognitiveSignalCollector] Error recording mood: $e');
    }
  }

  /// Record a daily check-in
  Future<void> recordDailyCheckIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_keyCheckInHistory);

      List<dynamic> history = [];
      if (historyJson != null && historyJson.isNotEmpty) {
        history = jsonDecode(historyJson);
      }

      // Add today's check-in
      history.add(DateTime.now().toIso8601String());

      // Keep only last 30 days
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      history = history
          .map((e) => DateTime.parse(e as String))
          .where((d) => d.isAfter(cutoff))
          .map((d) => d.toIso8601String())
          .toList();

      await prefs.setString(_keyCheckInHistory, jsonEncode(history));
      debugPrint('[CognitiveSignalCollector] Recorded daily check-in');
    } catch (e) {
      debugPrint('[CognitiveSignalCollector] Error recording check-in: $e');
    }
  }

  /// Clear all stored data (for testing/reset)
  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyMoodHistory);
    await prefs.remove(_keyCheckInHistory);
    debugPrint('[CognitiveSignalCollector] Cleared all data');
  }
}

/// Internal data class for medication adherence
class _MedicationAdherenceData {
  final double adherence;
  final int taken;
  final int scheduled;

  const _MedicationAdherenceData({
    required this.adherence,
    required this.taken,
    required this.scheduled,
  });
}

/// Internal data class for mood
class _MoodData {
  final double score;
  final double trend;

  const _MoodData({
    required this.score,
    required this.trend,
  });
}

/// Internal data class for check-ins
class _CheckInData {
  final double rate;
  final DateTime lastCheckIn;

  const _CheckInData({
    required this.rate,
    required this.lastCheckIn,
  });
}

/// Internal mood entry model
class _MoodEntry {
  final int score;
  final DateTime timestamp;

  const _MoodEntry({
    required this.score,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'score': score,
        'timestamp': timestamp.toIso8601String(),
      };

  factory _MoodEntry.fromJson(Map<String, dynamic> json) {
    return _MoodEntry(
      score: json['score'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
