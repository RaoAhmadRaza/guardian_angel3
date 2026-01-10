import 'log_entry.dart';

/// Summary of sensor data over a report period.
class SensorSummary {
  final double accelMagnitudeMin;
  final double accelMagnitudeMax;
  final double accelMagnitudeMean;
  final double gyroMagnitudeMin;
  final double gyroMagnitudeMax;
  final double gyroMagnitudeMean;

  const SensorSummary({
    required this.accelMagnitudeMin,
    required this.accelMagnitudeMax,
    required this.accelMagnitudeMean,
    required this.gyroMagnitudeMin,
    required this.gyroMagnitudeMax,
    required this.gyroMagnitudeMean,
  });

  factory SensorSummary.empty() {
    return const SensorSummary(
      accelMagnitudeMin: 0,
      accelMagnitudeMax: 0,
      accelMagnitudeMean: 0,
      gyroMagnitudeMin: 0,
      gyroMagnitudeMax: 0,
      gyroMagnitudeMean: 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'accelerometer': {
      'magnitude': {
        'min': accelMagnitudeMin,
        'max': accelMagnitudeMax,
        'mean': accelMagnitudeMean,
      },
    },
    'gyroscope': {
      'magnitude': {
        'min': gyroMagnitudeMin,
        'max': gyroMagnitudeMax,
        'mean': gyroMagnitudeMean,
      },
    },
  };
}

/// Monitoring report generated every 2 minutes.
class MonitoringReport {
  final String id;
  final DateTime generatedAt;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int totalWindowsProcessed;
  final double averageFallProbability;
  final double maxFallProbability;
  final double minFallProbability;
  final int thresholdCrossings;
  final int alertsTriggered;
  final int alertsSuppressed;
  final SensorSummary sensorSummary;
  final String modelVersion;
  final double thresholdUsed;

  const MonitoringReport({
    required this.id,
    required this.generatedAt,
    required this.periodStart,
    required this.periodEnd,
    required this.totalWindowsProcessed,
    required this.averageFallProbability,
    required this.maxFallProbability,
    required this.minFallProbability,
    required this.thresholdCrossings,
    required this.alertsTriggered,
    required this.alertsSuppressed,
    required this.sensorSummary,
    required this.modelVersion,
    required this.thresholdUsed,
  });

  Duration get periodDuration => periodEnd.difference(periodStart);

  Map<String, dynamic> toJson() => {
    'id': id,
    'generatedAt': generatedAt.toIso8601String(),
    'periodStart': periodStart.toIso8601String(),
    'periodEnd': periodEnd.toIso8601String(),
    'periodDurationSeconds': periodDuration.inSeconds,
    'totalWindowsProcessed': totalWindowsProcessed,
    'fallProbability': {
      'average': averageFallProbability,
      'max': maxFallProbability,
      'min': minFallProbability,
    },
    'thresholdCrossings': thresholdCrossings,
    'alertsTriggered': alertsTriggered,
    'alertsSuppressed': alertsSuppressed,
    'sensorSummary': sensorSummary.toJson(),
    'modelVersion': modelVersion,
    'thresholdUsed': thresholdUsed,
  };

  @override
  String toString() {
    return 'Report $id: ${periodDuration.inSeconds}s, '
           'windows=$totalWindowsProcessed, '
           'avgProb=${averageFallProbability.toStringAsFixed(3)}, '
           'maxProb=${maxFallProbability.toStringAsFixed(3)}, '
           'crossings=$thresholdCrossings, '
           'alerts=$alertsTriggered';
  }
}
