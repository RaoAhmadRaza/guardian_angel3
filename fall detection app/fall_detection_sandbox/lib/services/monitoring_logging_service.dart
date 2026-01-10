import 'dart:async';
import 'dart:collection';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import '../models/log_entry.dart';
import '../models/monitoring_report.dart';

/// High-performance logging service using ring buffers.
/// 
/// Features:
/// - O(1) insert/remove operations
/// - Fixed memory footprint
/// - Non-blocking design for real-time inference
/// - Automatic 2-minute report generation
/// - Thread-safe operations via isolates (if needed)
class MonitoringLoggingService extends ChangeNotifier {
  // Configuration
  static const int _maxLogEntries = 240; // ~2 minutes at 0.5s inference rate
  static const Duration _reportInterval = Duration(minutes: 2);
  static const int _maxStoredReports = 30; // Keep last hour of reports
  
  // Ring buffer for log entries (efficient circular buffer)
  final Queue<InferenceLogEntry> _logBuffer = Queue<InferenceLogEntry>();
  
  // Stored reports
  final List<MonitoringReport> _reports = [];
  
  // Session tracking
  DateTime? _sessionStartTime;
  int _sequenceCounter = 0;
  int _totalWindowsProcessed = 0;
  int _thresholdCrossings = 0;
  int _alertsTriggered = 0;
  int _alertsSuppressed = 0;
  
  // Probability tracking for reports
  final List<double> _probabilitiesForReport = [];
  
  // Report generation timer
  Timer? _reportTimer;
  
  // Callbacks
  final List<void Function(InferenceLogEntry)> _logListeners = [];
  final List<void Function(MonitoringReport)> _reportListeners = [];

  // Public getters
  List<InferenceLogEntry> get logs => _logBuffer.toList();
  List<MonitoringReport> get reports => List.unmodifiable(_reports);
  DateTime? get sessionStartTime => _sessionStartTime;
  int get totalWindowsProcessed => _totalWindowsProcessed;
  bool get isActive => _sessionStartTime != null;
  
  /// Start a new monitoring session.
  void startSession() {
    _sessionStartTime = DateTime.now();
    _sequenceCounter = 0;
    _totalWindowsProcessed = 0;
    _thresholdCrossings = 0;
    _alertsTriggered = 0;
    _alertsSuppressed = 0;
    _probabilitiesForReport.clear();
    _logBuffer.clear();
    
    // Start automatic report generation
    _reportTimer?.cancel();
    _reportTimer = Timer.periodic(_reportInterval, (_) => _generatePeriodicReport());
    
    dev.log('MonitoringLoggingService: Session started');
    notifyListeners();
  }
  
  /// End the current monitoring session.
  void endSession() {
    _reportTimer?.cancel();
    _reportTimer = null;
    
    // Generate final report if we have data
    if (_probabilitiesForReport.isNotEmpty) {
      _generatePeriodicReport();
    }
    
    _sessionStartTime = null;
    dev.log('MonitoringLoggingService: Session ended');
    notifyListeners();
  }
  
  /// Add a new log entry (called after each inference).
  /// 
  /// This method is optimized to be non-blocking:
  /// - O(1) ring buffer operations
  /// - Minimal memory allocations
  /// - No I/O operations
  void addLogEntry({
    required SensorStatistics sensorStats,
    required InferenceResult inferenceResult,
    required SystemState systemState,
  }) {
    _sequenceCounter++;
    _totalWindowsProcessed++;
    
    final entry = InferenceLogEntry.create(
      sequenceNumber: _sequenceCounter,
      sensorStats: sensorStats,
      inferenceResult: inferenceResult,
      systemState: systemState,
    );
    
    // Add to ring buffer (O(1) operation)
    _logBuffer.addLast(entry);
    
    // Maintain max size (O(1) operation)
    while (_logBuffer.length > _maxLogEntries) {
      _logBuffer.removeFirst();
    }
    
    // Track statistics for reports
    _probabilitiesForReport.add(inferenceResult.fallProbability);
    if (inferenceResult.thresholdExceeded) {
      _thresholdCrossings++;
    }
    if (inferenceResult.finalDecision == FallDecision.fall) {
      _alertsTriggered++;
    }
    if (inferenceResult.finalDecision == FallDecision.suppressed) {
      _alertsSuppressed++;
    }
    
    // Notify listeners
    for (final listener in _logListeners) {
      listener(entry);
    }
    
    notifyListeners();
  }
  
  /// Generate a periodic report (every 2 minutes).
  void _generatePeriodicReport() {
    if (_probabilitiesForReport.isEmpty) return;
    
    final now = DateTime.now();
    final reportStartTime = now.subtract(_reportInterval);
    
    // Get logs from the last 2 minutes
    final recentLogs = _logBuffer.where((log) => 
      log.timestamp.isAfter(reportStartTime)
    ).toList();
    
    if (recentLogs.isEmpty) return;
    
    // Calculate statistics
    final probabilities = recentLogs.map((l) => l.inferenceResult.fallProbability).toList();
    final avgProbability = probabilities.reduce((a, b) => a + b) / probabilities.length;
    final maxProbability = probabilities.reduce((a, b) => a > b ? a : b);
    final minProbability = probabilities.reduce((a, b) => a < b ? a : b);
    
    // Sensor statistics aggregation
    final sensorStats = _aggregateSensorStats(recentLogs);
    
    final report = MonitoringReport(
      id: 'report_${now.millisecondsSinceEpoch}',
      generatedAt: now,
      periodStart: reportStartTime,
      periodEnd: now,
      totalWindowsProcessed: recentLogs.length,
      averageFallProbability: avgProbability,
      maxFallProbability: maxProbability,
      minFallProbability: minProbability,
      thresholdCrossings: recentLogs.where((l) => l.inferenceResult.thresholdExceeded).length,
      alertsTriggered: recentLogs.where((l) => l.inferenceResult.finalDecision == FallDecision.fall).length,
      alertsSuppressed: recentLogs.where((l) => l.inferenceResult.finalDecision == FallDecision.suppressed).length,
      sensorSummary: sensorStats,
      modelVersion: 'best_fall_model_v2.tflite',
      thresholdUsed: recentLogs.isNotEmpty ? recentLogs.last.inferenceResult.thresholdUsed : 0.35,
    );
    
    // Store report
    _reports.add(report);
    while (_reports.length > _maxStoredReports) {
      _reports.removeAt(0);
    }
    
    // Clear tracked probabilities for next period
    _probabilitiesForReport.clear();
    
    // Notify listeners
    for (final listener in _reportListeners) {
      listener(report);
    }
    
    dev.log('MonitoringLoggingService: Generated periodic report ${report.id}');
    notifyListeners();
  }
  
  /// Aggregate sensor statistics from multiple log entries.
  SensorSummary _aggregateSensorStats(List<InferenceLogEntry> logs) {
    if (logs.isEmpty) return SensorSummary.empty();
    
    double accelMagMin = double.infinity;
    double accelMagMax = 0;
    double accelMagSum = 0;
    double gyroMagMin = double.infinity;
    double gyroMagMax = 0;
    double gyroMagSum = 0;
    
    for (final log in logs) {
      final s = log.sensorStats;
      accelMagMin = accelMagMin < s.accelMagnitude ? accelMagMin : s.accelMagnitude;
      accelMagMax = accelMagMax > s.accelMagnitudePeak ? accelMagMax : s.accelMagnitudePeak;
      accelMagSum += s.accelMagnitude;
      gyroMagMin = gyroMagMin < s.gyroMagnitude ? gyroMagMin : s.gyroMagnitude;
      gyroMagMax = gyroMagMax > s.gyroMagnitudePeak ? gyroMagMax : s.gyroMagnitudePeak;
      gyroMagSum += s.gyroMagnitude;
    }
    
    return SensorSummary(
      accelMagnitudeMin: accelMagMin == double.infinity ? 0 : accelMagMin,
      accelMagnitudeMax: accelMagMax,
      accelMagnitudeMean: accelMagSum / logs.length,
      gyroMagnitudeMin: gyroMagMin == double.infinity ? 0 : gyroMagMin,
      gyroMagnitudeMax: gyroMagMax,
      gyroMagnitudeMean: gyroMagSum / logs.length,
    );
  }
  
  /// Get logs from the last N minutes.
  List<InferenceLogEntry> getLogsFromLastMinutes(int minutes) {
    final cutoff = DateTime.now().subtract(Duration(minutes: minutes));
    return _logBuffer.where((log) => log.timestamp.isAfter(cutoff)).toList();
  }
  
  /// Get the latest N log entries.
  List<InferenceLogEntry> getLatestLogs(int count) {
    final logs = _logBuffer.toList();
    if (logs.length <= count) return logs;
    return logs.sublist(logs.length - count);
  }
  
  /// Manually trigger report generation.
  MonitoringReport? generateReportNow() {
    if (_logBuffer.isEmpty) return null;
    
    final now = DateTime.now();
    final logs = _logBuffer.toList();
    
    final probabilities = logs.map((l) => l.inferenceResult.fallProbability).toList();
    final avgProbability = probabilities.reduce((a, b) => a + b) / probabilities.length;
    final maxProbability = probabilities.reduce((a, b) => a > b ? a : b);
    final minProbability = probabilities.reduce((a, b) => a < b ? a : b);
    
    final sensorStats = _aggregateSensorStats(logs);
    
    final report = MonitoringReport(
      id: 'report_manual_${now.millisecondsSinceEpoch}',
      generatedAt: now,
      periodStart: _sessionStartTime ?? logs.first.timestamp,
      periodEnd: now,
      totalWindowsProcessed: logs.length,
      averageFallProbability: avgProbability,
      maxFallProbability: maxProbability,
      minFallProbability: minProbability,
      thresholdCrossings: logs.where((l) => l.inferenceResult.thresholdExceeded).length,
      alertsTriggered: logs.where((l) => l.inferenceResult.finalDecision == FallDecision.fall).length,
      alertsSuppressed: logs.where((l) => l.inferenceResult.finalDecision == FallDecision.suppressed).length,
      sensorSummary: sensorStats,
      modelVersion: 'best_fall_model_v2.tflite',
      thresholdUsed: logs.isNotEmpty ? logs.last.inferenceResult.thresholdUsed : 0.35,
    );
    
    _reports.add(report);
    notifyListeners();
    
    return report;
  }
  
  /// Add a listener for new log entries.
  void addLogListener(void Function(InferenceLogEntry) listener) {
    _logListeners.add(listener);
  }
  
  /// Remove a log listener.
  void removeLogListener(void Function(InferenceLogEntry) listener) {
    _logListeners.remove(listener);
  }
  
  /// Add a listener for new reports.
  void addReportListener(void Function(MonitoringReport) listener) {
    _reportListeners.add(listener);
  }
  
  /// Remove a report listener.
  void removeReportListener(void Function(MonitoringReport) listener) {
    _reportListeners.remove(listener);
  }
  
  /// Clear all logs and reports.
  void clearAll() {
    _logBuffer.clear();
    _reports.clear();
    _probabilitiesForReport.clear();
    _sequenceCounter = 0;
    notifyListeners();
  }
  
  @override
  void dispose() {
    _reportTimer?.cancel();
    _logListeners.clear();
    _reportListeners.clear();
    super.dispose();
  }
}
