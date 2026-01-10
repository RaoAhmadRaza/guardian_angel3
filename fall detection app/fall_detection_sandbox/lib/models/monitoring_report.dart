/// Summary of sensor statistics for a report period.
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

  factory SensorSummary.empty() => const SensorSummary(
    accelMagnitudeMin: 0,
    accelMagnitudeMax: 0,
    accelMagnitudeMean: 0,
    gyroMagnitudeMin: 0,
    gyroMagnitudeMax: 0,
    gyroMagnitudeMean: 0,
  );

  Map<String, dynamic> toJson() => {
    'accelerometerMagnitude': {
      'min': accelMagnitudeMin,
      'max': accelMagnitudeMax,
      'mean': accelMagnitudeMean,
    },
    'gyroscopeMagnitude': {
      'min': gyroMagnitudeMin,
      'max': gyroMagnitudeMax,
      'mean': gyroMagnitudeMean,
    },
  };
}

/// Comprehensive monitoring report generated every 2 minutes.
/// Suitable for clinical review, debugging, and audit trails.
class MonitoringReport {
  final String id;
  final DateTime generatedAt;
  final DateTime periodStart;
  final DateTime periodEnd;
  
  // Processing statistics
  final int totalWindowsProcessed;
  final double averageFallProbability;
  final double maxFallProbability;
  final double minFallProbability;
  final int thresholdCrossings;
  final int alertsTriggered;
  final int alertsSuppressed;
  
  // Sensor statistics
  final SensorSummary sensorSummary;
  
  // Model information
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
    'processing': {
      'totalWindowsProcessed': totalWindowsProcessed,
      'averageFallProbability': averageFallProbability,
      'maxFallProbability': maxFallProbability,
      'minFallProbability': minFallProbability,
      'thresholdCrossings': thresholdCrossings,
      'alertsTriggered': alertsTriggered,
      'alertsSuppressed': alertsSuppressed,
    },
    'sensorSummary': sensorSummary.toJson(),
    'model': {
      'version': modelVersion,
      'threshold': thresholdUsed,
    },
  };

  /// Generate a human-readable text report.
  String toTextReport({
    required String appName,
    required String appVersion,
    required String deviceModel,
    required String osVersion,
  }) {
    final buffer = StringBuffer();
    
    buffer.writeln('═' * 60);
    buffer.writeln('          FALL DETECTION MONITORING REPORT');
    buffer.writeln('═' * 60);
    buffer.writeln();
    
    // Header
    buffer.writeln('┌─────────────────────────────────────────────────────────┐');
    buffer.writeln('│ REPORT INFORMATION                                      │');
    buffer.writeln('├─────────────────────────────────────────────────────────┤');
    buffer.writeln('│ Report ID:      $id');
    buffer.writeln('│ Generated:      ${_formatDateTime(generatedAt)}');
    buffer.writeln('│ Period:         ${_formatDateTime(periodStart)}');
    buffer.writeln('│                 to ${_formatDateTime(periodEnd)}');
    buffer.writeln('│ Duration:       ${_formatDuration(periodDuration)}');
    buffer.writeln('└─────────────────────────────────────────────────────────┘');
    buffer.writeln();
    
    // Device & App Info
    buffer.writeln('┌─────────────────────────────────────────────────────────┐');
    buffer.writeln('│ APPLICATION & DEVICE                                    │');
    buffer.writeln('├─────────────────────────────────────────────────────────┤');
    buffer.writeln('│ App:            $appName v$appVersion');
    buffer.writeln('│ Device:         $deviceModel');
    buffer.writeln('│ OS:             $osVersion');
    buffer.writeln('│ Model:          $modelVersion');
    buffer.writeln('│ Threshold:      ${(thresholdUsed * 100).toStringAsFixed(1)}%');
    buffer.writeln('└─────────────────────────────────────────────────────────┘');
    buffer.writeln();
    
    // Processing Statistics
    buffer.writeln('┌─────────────────────────────────────────────────────────┐');
    buffer.writeln('│ PROCESSING STATISTICS                                   │');
    buffer.writeln('├─────────────────────────────────────────────────────────┤');
    buffer.writeln('│ Windows Processed:    $totalWindowsProcessed');
    buffer.writeln('│ Inference Rate:       ${(totalWindowsProcessed / (periodDuration.inSeconds / 60)).toStringAsFixed(1)}/min');
    buffer.writeln('│');
    buffer.writeln('│ Fall Probability:');
    buffer.writeln('│   • Average:          ${(averageFallProbability * 100).toStringAsFixed(2)}%');
    buffer.writeln('│   • Maximum:          ${(maxFallProbability * 100).toStringAsFixed(2)}%');
    buffer.writeln('│   • Minimum:          ${(minFallProbability * 100).toStringAsFixed(2)}%');
    buffer.writeln('│');
    buffer.writeln('│ Alert Statistics:');
    buffer.writeln('│   • Threshold Crossings:  $thresholdCrossings');
    buffer.writeln('│   • Alerts Triggered:     $alertsTriggered');
    buffer.writeln('│   • Alerts Suppressed:    $alertsSuppressed');
    buffer.writeln('└─────────────────────────────────────────────────────────┘');
    buffer.writeln();
    
    // Sensor Statistics
    buffer.writeln('┌─────────────────────────────────────────────────────────┐');
    buffer.writeln('│ SENSOR STATISTICS                                       │');
    buffer.writeln('├─────────────────────────────────────────────────────────┤');
    buffer.writeln('│ Accelerometer Magnitude (m/s²):');
    buffer.writeln('│   • Min:   ${sensorSummary.accelMagnitudeMin.toStringAsFixed(3)}');
    buffer.writeln('│   • Max:   ${sensorSummary.accelMagnitudeMax.toStringAsFixed(3)}');
    buffer.writeln('│   • Mean:  ${sensorSummary.accelMagnitudeMean.toStringAsFixed(3)}');
    buffer.writeln('│');
    buffer.writeln('│ Gyroscope Magnitude (rad/s):');
    buffer.writeln('│   • Min:   ${sensorSummary.gyroMagnitudeMin.toStringAsFixed(3)}');
    buffer.writeln('│   • Max:   ${sensorSummary.gyroMagnitudeMax.toStringAsFixed(3)}');
    buffer.writeln('│   • Mean:  ${sensorSummary.gyroMagnitudeMean.toStringAsFixed(3)}');
    buffer.writeln('└─────────────────────────────────────────────────────────┘');
    buffer.writeln();
    
    // Footer
    buffer.writeln('═' * 60);
    buffer.writeln('         END OF REPORT');
    buffer.writeln('═' * 60);
    
    return buffer.toString();
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
           '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }
}
