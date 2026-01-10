import 'dart:math';

/// Represents aggregated sensor statistics for a time window.
/// Provides human-readable summaries without raw data dumps.
class SensorStatistics {
  final DateTime timestamp;
  
  // Accelerometer statistics (m/s²)
  final double accelXMean;
  final double accelYMean;
  final double accelZMean;
  final double accelXPeak;
  final double accelYPeak;
  final double accelZPeak;
  final double accelMagnitude;
  final double accelMagnitudePeak;
  
  // Gyroscope statistics (rad/s)
  final double gyroXMean;
  final double gyroYMean;
  final double gyroZMean;
  final double gyroXPeak;
  final double gyroYPeak;
  final double gyroZPeak;
  final double gyroMagnitude;
  final double gyroMagnitudePeak;
  
  // Sample count for this window
  final int sampleCount;

  const SensorStatistics({
    required this.timestamp,
    required this.accelXMean,
    required this.accelYMean,
    required this.accelZMean,
    required this.accelXPeak,
    required this.accelYPeak,
    required this.accelZPeak,
    required this.accelMagnitude,
    required this.accelMagnitudePeak,
    required this.gyroXMean,
    required this.gyroYMean,
    required this.gyroZMean,
    required this.gyroXPeak,
    required this.gyroYPeak,
    required this.gyroZPeak,
    required this.gyroMagnitude,
    required this.gyroMagnitudePeak,
    required this.sampleCount,
  });

  /// Creates sensor statistics from a window of raw IMU data.
  /// Input: List of [ax, ay, az, gx, gy, gz] samples
  factory SensorStatistics.fromRawWindow(List<List<double>> window) {
    if (window.isEmpty) {
      return SensorStatistics.empty();
    }

    // Initialize accumulators
    double axSum = 0, aySum = 0, azSum = 0;
    double gxSum = 0, gySum = 0, gzSum = 0;
    double axPeak = 0, ayPeak = 0, azPeak = 0;
    double gxPeak = 0, gyPeak = 0, gzPeak = 0;
    double accelMagSum = 0, gyroMagSum = 0;
    double accelMagPeak = 0, gyroMagPeak = 0;

    for (final sample in window) {
      if (sample.length < 6) continue;
      
      final ax = sample[0];
      final ay = sample[1];
      final az = sample[2];
      final gx = sample[3];
      final gy = sample[4];
      final gz = sample[5];
      
      // Sums for means
      axSum += ax;
      aySum += ay;
      azSum += az;
      gxSum += gx;
      gySum += gy;
      gzSum += gz;
      
      // Peak values (absolute)
      axPeak = max(axPeak, ax.abs());
      ayPeak = max(ayPeak, ay.abs());
      azPeak = max(azPeak, az.abs());
      gxPeak = max(gxPeak, gx.abs());
      gyPeak = max(gyPeak, gy.abs());
      gzPeak = max(gzPeak, gz.abs());
      
      // Magnitudes
      final accelMag = sqrt(ax * ax + ay * ay + az * az);
      final gyroMag = sqrt(gx * gx + gy * gy + gz * gz);
      accelMagSum += accelMag;
      gyroMagSum += gyroMag;
      accelMagPeak = max(accelMagPeak, accelMag);
      gyroMagPeak = max(gyroMagPeak, gyroMag);
    }

    final n = window.length;
    
    return SensorStatistics(
      timestamp: DateTime.now(),
      accelXMean: axSum / n,
      accelYMean: aySum / n,
      accelZMean: azSum / n,
      accelXPeak: axPeak,
      accelYPeak: ayPeak,
      accelZPeak: azPeak,
      accelMagnitude: accelMagSum / n,
      accelMagnitudePeak: accelMagPeak,
      gyroXMean: gxSum / n,
      gyroYMean: gySum / n,
      gyroZMean: gzSum / n,
      gyroXPeak: gxPeak,
      gyroYPeak: gyPeak,
      gyroZPeak: gzPeak,
      gyroMagnitude: gyroMagSum / n,
      gyroMagnitudePeak: gyroMagPeak,
      sampleCount: n,
    );
  }

  factory SensorStatistics.empty() {
    return SensorStatistics(
      timestamp: DateTime.now(),
      accelXMean: 0, accelYMean: 0, accelZMean: 0,
      accelXPeak: 0, accelYPeak: 0, accelZPeak: 0,
      accelMagnitude: 0, accelMagnitudePeak: 0,
      gyroXMean: 0, gyroYMean: 0, gyroZMean: 0,
      gyroXPeak: 0, gyroYPeak: 0, gyroZPeak: 0,
      gyroMagnitude: 0, gyroMagnitudePeak: 0,
      sampleCount: 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'accelerometer': {
      'mean': {'x': accelXMean, 'y': accelYMean, 'z': accelZMean},
      'peak': {'x': accelXPeak, 'y': accelYPeak, 'z': accelZPeak},
      'magnitude': {'mean': accelMagnitude, 'peak': accelMagnitudePeak},
    },
    'gyroscope': {
      'mean': {'x': gyroXMean, 'y': gyroYMean, 'z': gyroZMean},
      'peak': {'x': gyroXPeak, 'y': gyroYPeak, 'z': gyroZPeak},
      'magnitude': {'mean': gyroMagnitude, 'peak': gyroMagnitudePeak},
    },
    'sampleCount': sampleCount,
  };
}

/// Represents the model inference result for a single window.
class InferenceResult {
  final DateTime windowStartTime;
  final DateTime windowEndTime;
  final int windowSize;
  final double fallProbability;
  final double thresholdUsed;
  final String temporalAggregationState; // e.g., "1 of 3", "2 of 3"
  final bool thresholdExceeded;
  final FallDecision finalDecision;
  final Duration inferenceLatency;

  const InferenceResult({
    required this.windowStartTime,
    required this.windowEndTime,
    required this.windowSize,
    required this.fallProbability,
    required this.thresholdUsed,
    required this.temporalAggregationState,
    required this.thresholdExceeded,
    required this.finalDecision,
    required this.inferenceLatency,
  });

  Map<String, dynamic> toJson() => {
    'windowStartTime': windowStartTime.toIso8601String(),
    'windowEndTime': windowEndTime.toIso8601String(),
    'windowSize': windowSize,
    'fallProbability': fallProbability,
    'thresholdUsed': thresholdUsed,
    'temporalAggregationState': temporalAggregationState,
    'thresholdExceeded': thresholdExceeded,
    'finalDecision': finalDecision.name,
    'inferenceLatencyMs': inferenceLatency.inMilliseconds,
  };
}

/// Fall detection decision enum
enum FallDecision {
  noFall,
  fall,
  suppressed, // Fall detected but suppressed (refractory period)
}

/// Represents the system state at a point in time.
class SystemState {
  final MonitoringState monitoringState;
  final RefractoryState refractoryState;
  final Duration? refractoryTimeRemaining;
  final AlertState alertState;
  final int bufferFillLevel; // 0-100%

  const SystemState({
    required this.monitoringState,
    required this.refractoryState,
    this.refractoryTimeRemaining,
    required this.alertState,
    required this.bufferFillLevel,
  });

  Map<String, dynamic> toJson() => {
    'monitoringState': monitoringState.name,
    'refractoryState': refractoryState.name,
    'refractoryTimeRemainingMs': refractoryTimeRemaining?.inMilliseconds,
    'alertState': alertState.name,
    'bufferFillLevel': bufferFillLevel,
  };
}

enum MonitoringState { active, paused, stopped }
enum RefractoryState { idle, active }
enum AlertState { allowed, suppressed, triggered }

/// Complete log entry for a single inference window.
/// Groups all related data for human-readable display.
class InferenceLogEntry {
  final String id;
  final DateTime timestamp;
  final int sequenceNumber;
  final SensorStatistics sensorStats;
  final InferenceResult inferenceResult;
  final SystemState systemState;

  InferenceLogEntry({
    required this.id,
    required this.timestamp,
    required this.sequenceNumber,
    required this.sensorStats,
    required this.inferenceResult,
    required this.systemState,
  });

  /// Factory constructor with auto-generated ID
  factory InferenceLogEntry.create({
    required int sequenceNumber,
    required SensorStatistics sensorStats,
    required InferenceResult inferenceResult,
    required SystemState systemState,
  }) {
    final timestamp = DateTime.now();
    final id = '${timestamp.millisecondsSinceEpoch}_$sequenceNumber';
    
    return InferenceLogEntry(
      id: id,
      timestamp: timestamp,
      sequenceNumber: sequenceNumber,
      sensorStats: sensorStats,
      inferenceResult: inferenceResult,
      systemState: systemState,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'sequenceNumber': sequenceNumber,
    'sensorStatistics': sensorStats.toJson(),
    'inferenceResult': inferenceResult.toJson(),
    'systemState': systemState.toJson(),
  };

  /// Human-readable summary string
  String get summary {
    final prob = (inferenceResult.fallProbability * 100).toStringAsFixed(1);
    final decision = inferenceResult.finalDecision.name.toUpperCase();
    return '[$sequenceNumber] $prob% → $decision (${inferenceResult.temporalAggregationState})';
  }
}
