import 'package:flutter/foundation.dart';

// Local stub for Sentry severity levels while Sentry is disabled.
// To re-enable Sentry later, remove this enum and restore sentry_flutter import.
enum SentryLevel { debug, info, warning, error, fatal }

/// Production-grade telemetry system for sync engine
/// 
/// Phase 4 enhancements:
/// - Structured metrics with labels
/// - Histogram tracking for latency
/// - Alert threshold monitoring
/// - Sentry integration for errors
/// - Exportable metrics for monitoring systems
class ProductionMetrics {
  // Gauges (current values)
  int _pendingOpsGauge = 0;
  int _activeProcessorsGauge = 0;
  
  // Counters (cumulative)
  int _processedOpsTotal = 0;
  int _failedOpsTotal = 0;
  int _backoffEventsTotal = 0;
  int _circuitTrippedTotal = 0;
  int _retriesTotal = 0;
  int _conflictsResolvedTotal = 0;
  int _authRefreshTotal = 0;
  
  // Latency histogram buckets (ms): 0-10, 10-50, 50-100, 100-500, 500-1000, 1000+
  final Map<String, int> _latencyBuckets = {
    '0-10ms': 0,
    '10-50ms': 0,
    '50-100ms': 0,
    '100-500ms': 0,
    '500-1000ms': 0,
    '1000ms+': 0,
  };
  
  // Detailed latency samples for percentile calculation
  final List<int> _latencySamples = [];
  final int _maxLatencySamples = 1000;
  
  // Error rate tracking (sliding window)
  final List<_ErrorSample> _recentErrors = [];
  final Duration _errorWindowDuration = const Duration(minutes: 5);
  
  // Alert thresholds
  final AlertThresholds thresholds;
  
  // Metrics export
  final List<MetricAlert> _activeAlerts = [];
  
  // Sentry integration
  final bool _sentryEnabled;
  
  // Structured logging
  final List<StructuredLog> _recentLogs = [];
  final int _maxLogRetention = 100;
  
  ProductionMetrics({
    AlertThresholds? thresholds,
    bool sentryEnabled = false,
  })  : thresholds = thresholds ?? AlertThresholds.defaults(),
        _sentryEnabled = sentryEnabled;

  /// Record operation enqueued
  void recordEnqueue() {
    _pendingOpsGauge++;
    _checkThreshold('pending_ops_high', _pendingOpsGauge.toDouble(), 
      thresholds.pendingOpsHighWatermark);
  }

  /// Record operation dequeued (started processing)
  void recordDequeue() {
    _pendingOpsGauge = (_pendingOpsGauge - 1).clamp(0, double.maxFinite.toInt());
  }

  /// Record operation processed successfully
  void recordProcessed({required int latencyMs, Map<String, String>? labels}) {
    _processedOpsTotal++;
    recordDequeue();
    _recordLatency(latencyMs);
    
    _log(
      level: LogLevel.info,
      message: 'Operation processed successfully',
      context: {
        'latency_ms': latencyMs,
        'total_processed': _processedOpsTotal,
        ...?labels,
      },
    );
  }

  /// Record operation failed
  void recordFailed({
    required String reason,
    bool isPermanent = false,
    String? opId,
    Map<String, String>? labels,
  }) {
    _failedOpsTotal++;
    recordDequeue();
    
    _recentErrors.add(_ErrorSample(
      timestamp: DateTime.now(),
      isPermanent: isPermanent,
      reason: reason,
    ));
    
    // Clean old errors outside window
    _recentErrors.removeWhere(
      (e) => DateTime.now().difference(e.timestamp) > _errorWindowDuration,
    );
    
    // Check failure rate threshold
    final failureRate = _calculateFailureRate();
    _checkThreshold('failed_ops_rate', failureRate, thresholds.failedOpsRateThreshold);
    
    _log(
      level: isPermanent ? LogLevel.error : LogLevel.warning,
      message: 'Operation failed: $reason',
      context: {
        'op_id': opId ?? 'unknown',
        'reason': reason,
        'is_permanent': isPermanent,
        'failure_rate': failureRate.toStringAsFixed(2),
        ...?labels,
      },
    );
    
    // Send to Sentry if enabled and permanent failure
    if (_sentryEnabled && isPermanent) {
      _sendToSentry(
        message: 'Permanent operation failure',
        context: {
          'reason': reason,
          if (opId != null) 'op_id': opId,
        },
      );
    }
  }

  /// Record backoff event
  void recordBackoff({required Duration delay, required int attempt}) {
    _backoffEventsTotal++;
    
    _log(
      level: LogLevel.info,
      message: 'Backoff applied',
      context: {
        'delay_seconds': delay.inSeconds,
        'attempt': attempt,
        'total_backoffs': _backoffEventsTotal,
      },
    );
  }

  /// Record circuit breaker trip
  void recordCircuitTripped({required String reason}) {
    _circuitTrippedTotal++;
    
    _log(
      level: LogLevel.warning,
      message: 'Circuit breaker tripped',
      context: {
        'reason': reason,
        'total_trips': _circuitTrippedTotal,
      },
    );
    
    _checkThreshold('circuit_breaker_trips', _circuitTrippedTotal.toDouble(), 
      thresholds.circuitBreakerTripsPerDay);
    
    if (_sentryEnabled) {
      _sendToSentry(
        message: 'Circuit breaker tripped',
        context: {'reason': reason},
        level: SentryLevel.warning,
      );
    }
  }

  /// Record retry attempt
  void recordRetry({required int attempt, required String opId}) {
    _retriesTotal++;
    
    _log(
      level: LogLevel.info,
      message: 'Operation retry',
      context: {
        'op_id': opId,
        'attempt': attempt,
      },
    );
  }

  /// Record conflict resolved
  void recordConflictResolved({required String strategy}) {
    _conflictsResolvedTotal++;
    
    _log(
      level: LogLevel.info,
      message: 'Conflict resolved',
      context: {
        'strategy': strategy,
        'total_conflicts_resolved': _conflictsResolvedTotal,
      },
    );
  }

  /// Record auth token refresh
  void recordAuthRefresh({required bool success}) {
    _authRefreshTotal++;
    
    _log(
      level: success ? LogLevel.info : LogLevel.error,
      message: 'Auth token refresh ${success ? 'succeeded' : 'failed'}',
      context: {
        'success': success,
        'total_refreshes': _authRefreshTotal,
      },
    );
    
    if (!success && _sentryEnabled) {
      _sendToSentry(
        message: 'Auth token refresh failed',
        level: SentryLevel.error,
      );
    }
  }

  /// Update queue depth gauge
  void updateQueueDepth(int depth) {
    _pendingOpsGauge = depth;
    _checkThreshold('pending_ops_high', depth.toDouble(), 
      thresholds.pendingOpsHighWatermark);
  }

  /// Update active processors count
  void updateActiveProcessors(int count) {
    _activeProcessorsGauge = count;
  }

  /// Record processing latency
  void _recordLatency(int latencyMs) {
    // Update histogram buckets
    if (latencyMs <= 10) {
      _latencyBuckets['0-10ms'] = _latencyBuckets['0-10ms']! + 1;
    } else if (latencyMs <= 50) {
      _latencyBuckets['10-50ms'] = _latencyBuckets['10-50ms']! + 1;
    } else if (latencyMs <= 100) {
      _latencyBuckets['50-100ms'] = _latencyBuckets['50-100ms']! + 1;
    } else if (latencyMs <= 500) {
      _latencyBuckets['100-500ms'] = _latencyBuckets['100-500ms']! + 1;
    } else if (latencyMs <= 1000) {
      _latencyBuckets['500-1000ms'] = _latencyBuckets['500-1000ms']! + 1;
    } else {
      _latencyBuckets['1000ms+'] = _latencyBuckets['1000ms+']! + 1;
    }
    
    // Add to samples for percentile calculation
    _latencySamples.add(latencyMs);
    if (_latencySamples.length > _maxLatencySamples) {
      _latencySamples.removeAt(0);
    }
    
    // Check latency threshold
    final p95 = _calculateP95Latency();
    _checkThreshold('avg_processing_time_high', p95.toDouble(), 
      thresholds.avgProcessingTimeMs);
  }

  /// Calculate failure rate (failures per minute)
  double _calculateFailureRate() {
    if (_recentErrors.isEmpty) return 0.0;
    
    final now = DateTime.now();
    final recentCount = _recentErrors.where(
      (e) => now.difference(e.timestamp) <= const Duration(minutes: 1),
    ).length;
    
    return recentCount.toDouble();
  }

  /// Calculate p95 latency
  int _calculateP95Latency() {
    if (_latencySamples.isEmpty) return 0;
    
    final sorted = List<int>.from(_latencySamples)..sort();
    final index = (sorted.length * 0.95).ceil() - 1;
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  /// Calculate p99 latency
  int _calculateP99Latency() {
    if (_latencySamples.isEmpty) return 0;
    
    final sorted = List<int>.from(_latencySamples)..sort();
    final index = (sorted.length * 0.99).ceil() - 1;
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  /// Check threshold and create alert if exceeded
  void _checkThreshold(String metricName, double value, double threshold) {
    if (value > threshold) {
      final alert = MetricAlert(
        metricName: metricName,
        currentValue: value,
        threshold: threshold,
        timestamp: DateTime.now(),
        severity: _determineSeverity(metricName, value, threshold),
      );
      
      _activeAlerts.add(alert);
      
      _log(
        level: LogLevel.error,
        message: 'Alert: $metricName exceeded threshold',
        context: {
          'metric': metricName,
          'current_value': value,
          'threshold': threshold,
          'severity': alert.severity.name,
        },
      );
      
      if (_sentryEnabled) {
        _sendToSentry(
          message: 'Metric threshold exceeded: $metricName',
          context: {
            'metric': metricName,
            'current_value': value.toString(),
            'threshold': threshold.toString(),
          },
          level: alert.severity == AlertSeverity.critical 
            ? SentryLevel.fatal 
            : SentryLevel.warning,
        );
      }
    }
  }

  /// Determine alert severity
  AlertSeverity _determineSeverity(String metricName, double value, double threshold) {
    final ratio = value / threshold;
    if (ratio > 2.0) return AlertSeverity.critical;
    if (ratio > 1.5) return AlertSeverity.high;
    if (ratio > 1.2) return AlertSeverity.medium;
    return AlertSeverity.low;
  }

  /// Structured logging
  void _log({
    required LogLevel level,
    required String message,
    required Map<String, dynamic> context,
  }) {
    final log = StructuredLog(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      context: context,
    );
    
    _recentLogs.add(log);
    if (_recentLogs.length > _maxLogRetention) {
      _recentLogs.removeAt(0);
    }
    
    // Print to console in debug mode
    if (kDebugMode) {
      print('[${level.name.toUpperCase()}] $message ${context.isEmpty ? '' : '| ${context}'}');
    }
  }

  /// Send event to Sentry
  void _sendToSentry({
    required String message,
    Map<String, String>? context,
    SentryLevel level = SentryLevel.info,
  }) {
    // No-op while Sentry integration is disabled to avoid native build issues.
    // Keep signature so callers remain unchanged.
    return;
  }

  /// Export metrics in Prometheus-compatible format
  String exportPrometheus() {
    final buffer = StringBuffer();
    
    // Gauges
    buffer.writeln('# HELP pending_ops_gauge Current number of pending operations');
    buffer.writeln('# TYPE pending_ops_gauge gauge');
    buffer.writeln('pending_ops_gauge $_pendingOpsGauge');
    buffer.writeln();
    
    buffer.writeln('# HELP active_processors_gauge Number of active sync processors');
    buffer.writeln('# TYPE active_processors_gauge gauge');
    buffer.writeln('active_processors_gauge $_activeProcessorsGauge');
    buffer.writeln();
    
    // Counters
    buffer.writeln('# HELP processed_ops_total Total number of successfully processed operations');
    buffer.writeln('# TYPE processed_ops_total counter');
    buffer.writeln('processed_ops_total $_processedOpsTotal');
    buffer.writeln();
    
    buffer.writeln('# HELP failed_ops_total Total number of failed operations');
    buffer.writeln('# TYPE failed_ops_total counter');
    buffer.writeln('failed_ops_total $_failedOpsTotal');
    buffer.writeln();
    
    buffer.writeln('# HELP backoff_events_total Total number of backoff events');
    buffer.writeln('# TYPE backoff_events_total counter');
    buffer.writeln('backoff_events_total $_backoffEventsTotal');
    buffer.writeln();
    
    buffer.writeln('# HELP circuit_tripped_total Total number of circuit breaker trips');
    buffer.writeln('# TYPE circuit_tripped_total counter');
    buffer.writeln('circuit_tripped_total $_circuitTrippedTotal');
    buffer.writeln();
    
    // Histogram
    buffer.writeln('# HELP avg_processing_time_ms Processing time histogram in milliseconds');
    buffer.writeln('# TYPE avg_processing_time_ms histogram');
    _latencyBuckets.forEach((bucket, count) {
      buffer.writeln('avg_processing_time_ms{bucket="$bucket"} $count');
    });
    buffer.writeln();
    
    return buffer.toString();
  }

  /// Export metrics as JSON
  Map<String, dynamic> exportJson() {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'gauges': {
        'pending_ops': _pendingOpsGauge,
        'active_processors': _activeProcessorsGauge,
      },
      'counters': {
        'processed_ops_total': _processedOpsTotal,
        'failed_ops_total': _failedOpsTotal,
        'backoff_events_total': _backoffEventsTotal,
        'circuit_tripped_total': _circuitTrippedTotal,
        'retries_total': _retriesTotal,
        'conflicts_resolved_total': _conflictsResolvedTotal,
        'auth_refresh_total': _authRefreshTotal,
      },
      'latency': {
        'histogram': _latencyBuckets,
        'p50_ms': _calculatePercentile(0.50),
        'p95_ms': _calculateP95Latency(),
        'p99_ms': _calculateP99Latency(),
        'samples': _latencySamples.length,
      },
      'health': {
        'failure_rate_per_min': _calculateFailureRate(),
        'success_rate_percent': _calculateSuccessRate(),
      },
      'alerts': _activeAlerts.map((a) => a.toJson()).toList(),
    };
  }

  /// Calculate percentile
  int _calculatePercentile(double percentile) {
    if (_latencySamples.isEmpty) return 0;
    
    final sorted = List<int>.from(_latencySamples)..sort();
    final index = (sorted.length * percentile).ceil() - 1;
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  /// Calculate success rate
  double _calculateSuccessRate() {
    final total = _processedOpsTotal + _failedOpsTotal;
    if (total == 0) return 100.0;
    return (_processedOpsTotal / total) * 100.0;
  }

  /// Get active alerts
  List<MetricAlert> getActiveAlerts() => List.unmodifiable(_activeAlerts);

  /// Clear resolved alerts
  void clearResolvedAlerts() {
    _activeAlerts.clear();
  }

  /// Get recent logs
  List<StructuredLog> getRecentLogs({LogLevel? minLevel}) {
    if (minLevel == null) return List.unmodifiable(_recentLogs);
    
    return _recentLogs.where((log) => log.level.index >= minLevel.index).toList();
  }

  /// Print human-readable summary
  void printSummary() {
    print('═══════════════════════════════════════════════════════════');
    print('                 SYNC ENGINE METRICS                        ');
    print('═══════════════════════════════════════════════════════════');
    print('Gauges:');
    print('  Pending Operations: $_pendingOpsGauge');
    print('  Active Processors: $_activeProcessorsGauge');
    print('');
    print('Counters:');
    print('  Processed: $_processedOpsTotal');
    print('  Failed: $_failedOpsTotal');
    print('  Retries: $_retriesTotal');
    print('  Backoffs: $_backoffEventsTotal');
    print('  Circuit Trips: $_circuitTrippedTotal');
    print('  Conflicts Resolved: $_conflictsResolvedTotal');
    print('');
    print('Performance:');
    print('  P50 Latency: ${_calculatePercentile(0.50)}ms');
    print('  P95 Latency: ${_calculateP95Latency()}ms');
    print('  P99 Latency: ${_calculateP99Latency()}ms');
    print('  Success Rate: ${_calculateSuccessRate().toStringAsFixed(1)}%');
    print('  Failure Rate: ${_calculateFailureRate().toStringAsFixed(2)}/min');
    print('');
    print('Alerts: ${_activeAlerts.length} active');
    if (_activeAlerts.isNotEmpty) {
      for (var alert in _activeAlerts) {
        print('  [${alert.severity.name.toUpperCase()}] ${alert.metricName}: ${alert.currentValue} > ${alert.threshold}');
      }
    }
    print('═══════════════════════════════════════════════════════════');
  }

  /// Reset all metrics (for testing)
  void reset() {
    _pendingOpsGauge = 0;
    _activeProcessorsGauge = 0;
    _processedOpsTotal = 0;
    _failedOpsTotal = 0;
    _backoffEventsTotal = 0;
    _circuitTrippedTotal = 0;
    _retriesTotal = 0;
    _conflictsResolvedTotal = 0;
    _authRefreshTotal = 0;
    _latencyBuckets.forEach((key, _) => _latencyBuckets[key] = 0);
    _latencySamples.clear();
    _recentErrors.clear();
    _activeAlerts.clear();
    _recentLogs.clear();
  }
}

/// Alert thresholds configuration
class AlertThresholds {
  final double failedOpsRateThreshold; // failures per minute
  final double pendingOpsHighWatermark; // max pending operations
  final double circuitBreakerTripsPerDay; // max trips per day
  final double avgProcessingTimeMs; // p95 latency threshold

  const AlertThresholds({
    required this.failedOpsRateThreshold,
    required this.pendingOpsHighWatermark,
    required this.circuitBreakerTripsPerDay,
    required this.avgProcessingTimeMs,
  });

  factory AlertThresholds.defaults() {
    return const AlertThresholds(
      failedOpsRateThreshold: 10.0, // 10 failures/min
      pendingOpsHighWatermark: 1000.0, // 1000 pending ops
      circuitBreakerTripsPerDay: 50.0, // 50 trips/day
      avgProcessingTimeMs: 5000.0, // 5s p95 latency
    );
  }

  factory AlertThresholds.strict() {
    return const AlertThresholds(
      failedOpsRateThreshold: 5.0,
      pendingOpsHighWatermark: 500.0,
      circuitBreakerTripsPerDay: 20.0,
      avgProcessingTimeMs: 3000.0,
    );
  }
}

/// Metric alert
class MetricAlert {
  final String metricName;
  final double currentValue;
  final double threshold;
  final DateTime timestamp;
  final AlertSeverity severity;

  MetricAlert({
    required this.metricName,
    required this.currentValue,
    required this.threshold,
    required this.timestamp,
    required this.severity,
  });

  Map<String, dynamic> toJson() {
    return {
      'metric_name': metricName,
      'current_value': currentValue,
      'threshold': threshold,
      'timestamp': timestamp.toIso8601String(),
      'severity': severity.name,
    };
  }
}

/// Alert severity levels
enum AlertSeverity {
  low,
  medium,
  high,
  critical,
}

/// Structured log entry
class StructuredLog {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final Map<String, dynamic> context;

  StructuredLog({
    required this.timestamp,
    required this.level,
    required this.message,
    required this.context,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'message': message,
      'context': context,
    };
  }
}

/// Log levels
enum LogLevel {
  debug,
  info,
  warning,
  error,
  fatal,
}

/// Error sample for rate calculation
class _ErrorSample {
  final DateTime timestamp;
  final bool isPermanent;
  final String reason;

  _ErrorSample({
    required this.timestamp,
    required this.isPermanent,
    required this.reason,
  });
}
