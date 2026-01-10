/// Health Stability Score Provider
///
/// UI state management for the HSS system. Coordinates data collection
/// from all subsystems and provides reactive updates to UI.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/subsystem_signals.dart';
import '../models/personal_baseline.dart';
import '../models/stability_score_result.dart';
import '../services/stability_score_service.dart';
import '../services/sleep_trend_analyzer.dart';
import '../services/cognitive_signal_collector.dart';
import '../services/baseline_persistence_service.dart';
import '../../health/models/normalized_health_data.dart';
import '../../services/session_service.dart';
import '../../services/fall_detection/fall_detection_service.dart';

/// Provider for Health Stability Score state.
class StabilityScoreProvider extends ChangeNotifier {
  StabilityScoreProvider._();
  static final StabilityScoreProvider _instance = StabilityScoreProvider._();
  static StabilityScoreProvider get instance => _instance;

  /// Current state
  StabilityScoreResult? _currentScore;
  PersonalBaseline? _baseline;
  StabilityInput? _currentInput;
  bool _isLoading = false;
  String? _error;
  DateTime? _lastUpdated;

  /// Auto-refresh timer
  Timer? _refreshTimer;
  static const Duration _refreshInterval = Duration(minutes: 15);

  /// Getters
  StabilityScoreResult? get currentScore => _currentScore;
  PersonalBaseline? get baseline => _baseline;
  StabilityInput? get currentInput => _currentInput;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastUpdated => _lastUpdated;
  bool get hasScore => _currentScore != null;

  /// Initialize the provider for a patient
  Future<void> initialize() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final patientId = await SessionService.instance.getCurrentUid();
      if (patientId == null || patientId.isEmpty) {
        throw Exception('No patient ID available');
      }

      // Load baseline
      _baseline = await BaselinePersistenceService.instance.loadBaseline(patientId);

      // Compute initial score
      await refresh();

      // Start auto-refresh
      _startAutoRefresh();

      debugPrint('[StabilityScoreProvider] Initialized for $patientId');
    } catch (e) {
      _error = e.toString();
      debugPrint('[StabilityScoreProvider] Initialization error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh the stability score
  Future<void> refresh() async {
    try {
      _isLoading = true;
      notifyListeners();

      final patientId = await SessionService.instance.getCurrentUid();
      if (patientId == null) {
        throw Exception('No patient ID');
      }

      // Ensure baseline is loaded
      _baseline ??= await BaselinePersistenceService.instance.loadBaseline(patientId);

      // Collect signals from all subsystems
      final input = await _collectAllSignals();
      _currentInput = input;

      // Compute score
      final score = StabilityScoreService.instance.computeScore(
        input: input,
        baseline: _baseline!,
      );
      _currentScore = score;
      _lastUpdated = DateTime.now();

      // Update baseline with new observations
      if (score.isReliable) {
        _baseline = _baseline!.updateWith(
          physicalStability: input.physical.hasData ? input.physical.stabilityScore : null,
          cardiacStability: input.cardiac.hasData ? input.cardiac.stabilityScore : null,
          sleepStability: input.sleep.hasData ? input.sleep.stabilityScore : null,
          cognitiveStability: input.cognitive.hasData ? input.cognitive.stabilityScore : null,
          overallScore: score.score / 100.0,
        );
        await BaselinePersistenceService.instance.saveBaseline(_baseline!);

        // Save to history
        await BaselinePersistenceService.instance.addHistoryEntry(
          patientId,
          StabilityScoreHistoryEntry(
            score: score.score,
            level: score.level,
            timestamp: DateTime.now(),
            subsystemScores: {
              if (input.physical.hasData) 'physical': input.physical.stabilityScore,
              if (input.cardiac.hasData) 'cardiac': input.cardiac.stabilityScore,
              if (input.sleep.hasData) 'sleep': input.sleep.stabilityScore,
              if (input.cognitive.hasData) 'cognitive': input.cognitive.stabilityScore,
            },
          ),
        );
      }

      _error = null;
      debugPrint('[StabilityScoreProvider] Refreshed: score=${score.score.toStringAsFixed(1)}');
    } catch (e) {
      _error = e.toString();
      debugPrint('[StabilityScoreProvider] Refresh error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Collect signals from all subsystems
  Future<StabilityInput> _collectAllSignals() async {
    final physical = await _collectPhysicalSignals();
    final cardiac = await _collectCardiacSignals();
    final sleep = await _collectSleepSignals();
    final cognitive = await CognitiveSignalCollector.instance.collect();

    return StabilityInput(
      physical: physical,
      cardiac: cardiac,
      sleep: sleep,
      cognitive: cognitive,
      collectedAt: DateTime.now(),
    );
  }

  /// Collect physical signals from fall detection
  Future<PhysicalSignals> _collectPhysicalSignals() async {
    try {
      final fallService = FallDetectionService.instance;
      final loggingService = fallService.loggingService;

      if (loggingService == null) {
        return const PhysicalSignals.empty();
      }

      // Get latest monitoring report
      final report = loggingService.generateReportNow();
      
      if (report == null) {
        return const PhysicalSignals.empty();
      }

      // Count high-risk events (probability > 0.7)
      final recentLogs = loggingService.logs;
      final highRiskCount = recentLogs
          .where((log) => log.inferenceResult.fallProbability > 0.7)
          .length;

      return PhysicalSignals(
        fallProbability: report.averageFallProbability,
        averageFallProbability24h: report.averageFallProbability,
        maxFallProbability24h: report.maxFallProbability,
        highRiskEventCount: highRiskCount,
        timestamp: DateTime.now(),
        hasData: true,
      );
    } catch (e) {
      debugPrint('[StabilityScoreProvider] Error collecting physical signals: $e');
      return const PhysicalSignals.empty();
    }
  }

  /// Collect cardiac signals from health data
  Future<CardiacSignals> _collectCardiacSignals() async {
    try {
      // In a real implementation, this would read from the health data repository
      // For now, we return empty signals indicating no cardiac data
      // The arrhythmia service integration would go here
      
      // TODO: Integrate with arrhythmia_inference_service when available
      // TODO: Integrate with NormalizedHeartRateReading and NormalizedHRVReading
      
      return const CardiacSignals.empty();
    } catch (e) {
      debugPrint('[StabilityScoreProvider] Error collecting cardiac signals: $e');
      return const CardiacSignals.empty();
    }
  }

  /// Collect sleep signals from sleep sessions
  Future<SleepSignals> _collectSleepSignals() async {
    try {
      // In a real implementation, this would read from the health data repository
      // For now, we return empty signals indicating no sleep data
      
      // TODO: Integrate with NormalizedSleepSession from health data repository
      // Example:
      // final sessions = await HealthDataRepository.instance.getSleepSessions();
      // return SleepTrendAnalyzer.instance.analyze(sessions);
      
      return const SleepSignals.empty();
    } catch (e) {
      debugPrint('[StabilityScoreProvider] Error collecting sleep signals: $e');
      return const SleepSignals.empty();
    }
  }

  /// Update with external physical signals (for manual updates)
  void updatePhysicalSignals(PhysicalSignals signals) {
    if (_currentInput != null) {
      _currentInput = _currentInput!.copyWith(physical: signals);
      _recomputeScore();
    }
  }

  /// Update with external cardiac signals (for manual updates)
  void updateCardiacSignals(CardiacSignals signals) {
    if (_currentInput != null) {
      _currentInput = _currentInput!.copyWith(cardiac: signals);
      _recomputeScore();
    }
  }

  /// Update with sleep sessions
  void updateSleepSessions(List<NormalizedSleepSession> sessions) {
    final sleepSignals = SleepTrendAnalyzer.instance.analyze(sessions);
    if (_currentInput != null) {
      _currentInput = _currentInput!.copyWith(sleep: sleepSignals);
      _recomputeScore();
    }
  }

  /// Recompute score with current input
  void _recomputeScore() {
    if (_currentInput == null || _baseline == null) return;

    _currentScore = StabilityScoreService.instance.computeScore(
      input: _currentInput!,
      baseline: _baseline!,
    );
    _lastUpdated = DateTime.now();
    notifyListeners();
  }

  /// Start auto-refresh timer
  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      refresh();
    });
  }

  /// Stop auto-refresh
  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Get trending data for charts
  Future<TrendingData> getTrendingData({int days = 7}) async {
    final patientId = await SessionService.instance.getCurrentUid();
    if (patientId == null) {
      return TrendingData.empty();
    }
    return BaselinePersistenceService.instance.getTrendingData(patientId, days: days);
  }

  /// Record a mood check-in
  Future<void> recordMoodCheckIn(int score) async {
    await CognitiveSignalCollector.instance.recordMoodCheckIn(score);
    await refresh();
  }

  /// Record a daily check-in
  Future<void> recordDailyCheckIn() async {
    await CognitiveSignalCollector.instance.recordDailyCheckIn();
    await refresh();
  }

  /// Reset all data (for testing)
  Future<void> reset() async {
    final patientId = await SessionService.instance.getCurrentUid();
    if (patientId != null) {
      await BaselinePersistenceService.instance.clearPatientData(patientId);
      await CognitiveSignalCollector.instance.clearAllData();
    }

    _currentScore = null;
    _baseline = null;
    _currentInput = null;
    _error = null;
    _lastUpdated = null;
    notifyListeners();

    debugPrint('[StabilityScoreProvider] Reset all data');
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
