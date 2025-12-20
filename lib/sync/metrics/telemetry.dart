import 'dart:async';

/// Metrics and telemetry for sync engine
/// 
/// Tracks:
/// - Operation success/failure rates
/// - Processing latencies
/// - Queue depths
/// - Network health
class SyncMetrics {
  // Counters
  int _opsEnqueued = 0;
  int _opsProcessed = 0;
  int _opsFailed = 0;
  int _opsRetried = 0;
  int _conflictsResolved = 0;
  
  // Latencies (milliseconds)
  final List<int> _processingLatencies = [];
  final int _maxLatencySamples = 100;
  
  // Queue depth over time
  final List<_QueueSnapshot> _queueSnapshots = [];
  final int _maxQueueSnapshots = 100;
  
  // Network health
  int _networkErrors = 0;
  int _networkSuccesses = 0;
  DateTime? _lastNetworkError;
  
  // Lock takeovers
  int _lockTakeovers = 0;
  
  // Circuit breaker trips
  int _circuitBreakerTrips = 0;

  /// Record operation enqueued
  void recordEnqueue() {
    _opsEnqueued++;
  }

  /// Record operation processed successfully
  void recordSuccess({int? latencyMs}) {
    _opsProcessed++;
    _networkSuccesses++;
    
    if (latencyMs != null) {
      _recordLatency(latencyMs);
    }
  }

  /// Record operation failed
  void recordFailure({bool isNetworkError = false}) {
    _opsFailed++;
    
    if (isNetworkError) {
      _networkErrors++;
      _lastNetworkError = DateTime.now();
    }
  }

  /// Record operation retry
  void recordRetry() {
    _opsRetried++;
  }

  /// Record conflict resolved
  void recordConflictResolved() {
    _conflictsResolved++;
  }

  /// Record lock takeover
  void recordLockTakeover() {
    _lockTakeovers++;
  }

  /// Record circuit breaker trip
  void recordCircuitBreakerTrip() {
    _circuitBreakerTrips++;
  }

  /// Record queue depth snapshot
  void recordQueueDepth(int depth) {
    _queueSnapshots.add(_QueueSnapshot(
      timestamp: DateTime.now(),
      depth: depth,
    ));
    
    // Keep only recent snapshots
    if (_queueSnapshots.length > _maxQueueSnapshots) {
      _queueSnapshots.removeAt(0);
    }
  }

  /// Record processing latency
  void _recordLatency(int latencyMs) {
    _processingLatencies.add(latencyMs);
    
    // Keep only recent samples
    if (_processingLatencies.length > _maxLatencySamples) {
      _processingLatencies.removeAt(0);
    }
  }

  /// Get success rate (0.0 to 1.0)
  double get successRate {
    final total = _opsProcessed + _opsFailed;
    if (total == 0) return 0.0;
    return _opsProcessed / total;
  }

  /// Get average processing latency (ms)
  double get avgLatencyMs {
    if (_processingLatencies.isEmpty) return 0.0;
    return _processingLatencies.reduce((a, b) => a + b) / _processingLatencies.length;
  }

  /// Get p95 processing latency (ms)
  int get p95LatencyMs {
    if (_processingLatencies.isEmpty) return 0;
    
    final sorted = List<int>.from(_processingLatencies)..sort();
    final index = (sorted.length * 0.95).ceil() - 1;
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  /// Get network health score (0.0 to 1.0)
  double get networkHealthScore {
    final total = _networkSuccesses + _networkErrors;
    if (total == 0) return 1.0;
    return _networkSuccesses / total;
  }

  /// Get current queue depth (most recent snapshot)
  int get currentQueueDepth {
    if (_queueSnapshots.isEmpty) return 0;
    return _queueSnapshots.last.depth;
  }

  /// Get average queue depth over recent window
  double get avgQueueDepth {
    if (_queueSnapshots.isEmpty) return 0.0;
    final sum = _queueSnapshots.map((s) => s.depth).reduce((a, b) => a + b);
    return sum / _queueSnapshots.length;
  }

  /// Get comprehensive metrics summary
  Map<String, dynamic> getSummary() {
    return {
      'operations': {
        'enqueued': _opsEnqueued,
        'processed': _opsProcessed,
        'failed': _opsFailed,
        'retried': _opsRetried,
        'success_rate': successRate,
      },
      'latency': {
        'avg_ms': avgLatencyMs.round(),
        'p95_ms': p95LatencyMs,
        'samples': _processingLatencies.length,
      },
      'queue': {
        'current_depth': currentQueueDepth,
        'avg_depth': avgQueueDepth.round(),
      },
      'network': {
        'health_score': networkHealthScore,
        'errors': _networkErrors,
        'successes': _networkSuccesses,
        'last_error': _lastNetworkError?.toIso8601String(),
      },
      'reliability': {
        'conflicts_resolved': _conflictsResolved,
        'lock_takeovers': _lockTakeovers,
        'circuit_breaker_trips': _circuitBreakerTrips,
      },
    };
  }

  /// Print metrics summary to console
  void printSummary() {
    final summary = getSummary();
    print('[SyncMetrics] ============================================');
    print('[SyncMetrics] Operations: ${summary['operations']}');
    print('[SyncMetrics] Latency: ${summary['latency']}');
    print('[SyncMetrics] Queue: ${summary['queue']}');
    print('[SyncMetrics] Network: ${summary['network']}');
    print('[SyncMetrics] Reliability: ${summary['reliability']}');
    print('[SyncMetrics] ============================================');
  }

  /// Reset all metrics (for testing)
  void reset() {
    _opsEnqueued = 0;
    _opsProcessed = 0;
    _opsFailed = 0;
    _opsRetried = 0;
    _conflictsResolved = 0;
    _processingLatencies.clear();
    _queueSnapshots.clear();
    _networkErrors = 0;
    _networkSuccesses = 0;
    _lastNetworkError = null;
    _lockTakeovers = 0;
    _circuitBreakerTrips = 0;
  }
}

/// Queue depth snapshot
class _QueueSnapshot {
  final DateTime timestamp;
  final int depth;

  _QueueSnapshot({required this.timestamp, required this.depth});
}
