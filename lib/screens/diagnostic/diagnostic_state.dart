/// DiagnosticState - Screen-level state model for Diagnostic Screen.
///
/// This is a view-model that holds all diagnostic data for the UI.
/// For first-time users, ALL values should be null/empty.
/// NO fake data, NO simulated values, NO default vitals.
library;

/// Blood pressure measurement data
class BloodPressureData {
  final int systolic;
  final int diastolic;
  final DateTime measurementTime;
  final String? status; // "Optimal", "Normal", "Elevated", etc.

  const BloodPressureData({
    required this.systolic,
    required this.diastolic,
    required this.measurementTime,
    this.status,
  });

  /// Display string for blood pressure
  String get displayValue => '$systolic/$diastolic mmHg';
}

/// Body temperature data
class TemperatureData {
  final double value; // Temperature value
  final String unit; // "C" or "F"
  final DateTime measurementTime;
  final String? status; // "Normal", "Low", "High", etc.

  const TemperatureData({
    required this.value,
    this.unit = 'C',
    required this.measurementTime,
    this.status,
  });

  /// Display string for temperature
  String get displayValue => '${value.toStringAsFixed(1)}°$unit';
}

/// Sleep quality data
class SleepQualityData {
  final int qualityScore; // 0-100
  final double hoursSlept;
  final DateTime date;
  final String? quality; // "Good", "Fair", "Poor", etc.

  const SleepQualityData({
    required this.qualityScore,
    required this.hoursSlept,
    required this.date,
    this.quality,
  });

  /// Display string for sleep quality
  String get displayValue => '${hoursSlept.toStringAsFixed(1)} hours';
}

/// AI Analysis confidence breakdown
class AIConfidenceBreakdown {
  final double rhythm;
  final double variability;
  final double pattern;
  final double overall;

  const AIConfidenceBreakdown({
    required this.rhythm,
    required this.variability,
    required this.pattern,
    required this.overall,
  });
}

/// Complete diagnostic screen state
class DiagnosticState {
  // === DEVICE STATUS ===
  
  /// Whether a wearable/ECG device is connected
  final bool hasDeviceConnected;
  
  /// Whether any diagnostic data exists (from any source)
  final bool hasAnyDiagnosticData;

  // === HEART DATA (all nullable - no data for first-time users) ===
  
  /// Current heart rate in BPM (null if no device/data)
  final int? heartRate;
  
  /// Target heart rate for comparison (null if not set)
  final int? targetHeartRate;
  
  /// R-R intervals in milliseconds (null if no data)
  final List<int>? rrIntervals;
  
  /// ECG sample data for visualization (null if no data)
  final List<double>? ecgSamples;
  
  /// Selected ECG lead (null if no device)
  final String? selectedLead;

  // === AI ANALYSIS (all nullable - no analysis for first-time users) ===
  
  /// Heart rhythm classification (e.g., "Normal Sinus Rhythm")
  final String? heartRhythm;
  
  /// AI analysis status message
  final String? aiStatusMessage;
  
  /// AI analysis status (e.g., "Analysis complete")
  final String? aiAnalysisStatus;
  
  /// Overall AI confidence (0.0 - 1.0)
  final double? aiConfidence;
  
  /// Detailed confidence breakdown
  final AIConfidenceBreakdown? confidenceBreakdown;
  
  /// Whether stress is detected
  final bool? isStressDetected;

  // === CRITICAL ALERTS ===
  
  /// Whether there's a critical health alert requiring emergency action
  final bool hasCriticalAlert;

  // === OTHER DIAGNOSTICS (all nullable) ===
  
  /// Blood pressure data
  final BloodPressureData? bloodPressure;
  
  /// Body temperature data
  final TemperatureData? temperature;
  
  /// Sleep quality data
  final SleepQualityData? sleep;

  // === DIAGNOSTIC HISTORY ===
  
  /// Whether user has any previous diagnostic reports
  final bool hasDiagnosticHistory;

  const DiagnosticState({
    required this.hasDeviceConnected,
    required this.hasAnyDiagnosticData,
    this.heartRate,
    this.targetHeartRate,
    this.rrIntervals,
    this.ecgSamples,
    this.selectedLead,
    this.heartRhythm,
    this.aiStatusMessage,
    this.aiAnalysisStatus,
    this.aiConfidence,
    this.confidenceBreakdown,
    this.isStressDetected,
    this.hasCriticalAlert = false,
    this.bloodPressure,
    this.temperature,
    this.sleep,
    this.hasDiagnosticHistory = false,
  });

  /// Initial state for first-time users - NO DATA
  /// This is the ONLY factory method and it returns empty state
  factory DiagnosticState.initial() {
    return const DiagnosticState(
      hasDeviceConnected: false,
      hasAnyDiagnosticData: false,
      hasDiagnosticHistory: false,
      hasCriticalAlert: false,
      // All other fields are null by default
    );
  }

  // === DISPLAY HELPERS ===

  /// Heart rate display string
  String get heartRateDisplay => heartRate != null ? '$heartRate' : '--';

  /// Heart rate unit
  String get heartRateUnit => 'bpm';

  /// R-R interval display (first value)
  String get rrIntervalDisplay {
    if (rrIntervals == null || rrIntervals!.isEmpty) return '--';
    return '${rrIntervals!.first}';
  }

  /// R-R interval unit
  String get rrIntervalUnit => 'ms';

  /// AI confidence display percentage
  String get aiConfidenceDisplay {
    if (aiConfidence == null) return '--%';
    return '${(aiConfidence! * 100).toInt()}%';
  }

  /// Blood pressure status text
  String get bloodPressureStatus {
    if (bloodPressure == null) return 'No data';
    // In production, this would evaluate actual BP values
    return 'Measured';
  }

  /// Temperature status text
  String get temperatureStatus {
    if (temperature == null) return 'No data';
    return 'Measured';
  }

  /// Sleep quality status text
  String get sleepStatus {
    if (sleep == null) return 'No data';
    return 'Recorded';
  }

  /// Whether heartbeat card should show data
  bool get hasHeartData => heartRate != null;

  /// Whether R-R intervals should be displayed
  bool get hasRRData => rrIntervals != null && rrIntervals!.isNotEmpty;

  /// Whether ECG visualization should animate
  bool get hasECGData => ecgSamples != null && ecgSamples!.isNotEmpty;

  /// Whether AI analysis is available
  bool get hasAIAnalysis => aiConfidence != null && heartRhythm != null;

  /// Whether emergency actions should be shown (NEVER for first-time users)
  bool get shouldShowEmergencyActions {
    // Only show if we have real data AND critical thresholds are exceeded
    if (!hasAnyDiagnosticData || heartRate == null) return false;
    // In production: check actual critical thresholds
    return false; // For now, never show
  }

  /// Create a copy with updated fields
  DiagnosticState copyWith({
    bool? hasDeviceConnected,
    bool? hasAnyDiagnosticData,
    int? heartRate,
    int? targetHeartRate,
    List<int>? rrIntervals,
    List<double>? ecgSamples,
    String? selectedLead,
    String? heartRhythm,
    String? aiStatusMessage,
    String? aiAnalysisStatus,
    double? aiConfidence,
    AIConfidenceBreakdown? confidenceBreakdown,
    bool? isStressDetected,
    bool? hasCriticalAlert,
    BloodPressureData? bloodPressure,
    TemperatureData? temperature,
    SleepQualityData? sleep,
    bool? hasDiagnosticHistory,
  }) {
    return DiagnosticState(
      hasDeviceConnected: hasDeviceConnected ?? this.hasDeviceConnected,
      hasAnyDiagnosticData: hasAnyDiagnosticData ?? this.hasAnyDiagnosticData,
      heartRate: heartRate ?? this.heartRate,
      targetHeartRate: targetHeartRate ?? this.targetHeartRate,
      rrIntervals: rrIntervals ?? this.rrIntervals,
      ecgSamples: ecgSamples ?? this.ecgSamples,
      selectedLead: selectedLead ?? this.selectedLead,
      heartRhythm: heartRhythm ?? this.heartRhythm,
      aiStatusMessage: aiStatusMessage ?? this.aiStatusMessage,
      aiAnalysisStatus: aiAnalysisStatus ?? this.aiAnalysisStatus,
      aiConfidence: aiConfidence ?? this.aiConfidence,
      confidenceBreakdown: confidenceBreakdown ?? this.confidenceBreakdown,
      isStressDetected: isStressDetected ?? this.isStressDetected,
      hasCriticalAlert: hasCriticalAlert ?? this.hasCriticalAlert,
      bloodPressure: bloodPressure ?? this.bloodPressure,
      temperature: temperature ?? this.temperature,
      sleep: sleep ?? this.sleep,
      hasDiagnosticHistory: hasDiagnosticHistory ?? this.hasDiagnosticHistory,
    );
  }
}
