/// Normalized Health Data Models — Platform-Agnostic Output
///
/// These models are the OUTPUT of the health extraction layer.
/// They are:
/// - READ-ONLY value objects
/// - IN-MEMORY only (no Hive, no Firestore)
/// - Platform-agnostic (no HealthKit or Health Connect references)
/// - Suitable for downstream processing
///
/// SCOPE: Data extraction layer only.
/// DO NOT add persistence, sync, or UI logic here.
library;

/// Data source identifier
enum HealthDataSource {
  appleHealth,
  healthConnect,
  unknown,
}

/// Reliability classification based on data freshness and source
enum DataReliability {
  /// Recent data from primary wearable
  high,

  /// Data may be delayed or from secondary source
  medium,

  /// Old data, manual entry, or unverified source
  low,
}

/// Device type (when detectable from source metadata)
enum DetectedDeviceType {
  appleWatch,
  samsungGalaxyWatch,
  xiaomiBand,
  xiaomiAmazfit,
  fitbit,
  garmin,
  withings,
  oura,
  manual,
  unknown,
}

// ═══════════════════════════════════════════════════════════════════════════
// HEART RATE
// ═══════════════════════════════════════════════════════════════════════════

/// Normalized heart rate reading from any wearable platform.
class NormalizedHeartRateReading {
  /// Patient's Firebase UID
  final String patientUid;

  /// When this reading was recorded by the device
  final DateTime timestamp;

  /// Heart rate in beats per minute
  final int bpm;

  /// Source platform
  final HealthDataSource dataSource;

  /// Detected device type (if available)
  final DetectedDeviceType deviceType;

  /// Data reliability classification
  final DataReliability reliability;

  /// Whether this is a resting heart rate measurement
  final bool isResting;

  const NormalizedHeartRateReading({
    required this.patientUid,
    required this.timestamp,
    required this.bpm,
    required this.dataSource,
    this.deviceType = DetectedDeviceType.unknown,
    this.reliability = DataReliability.medium,
    this.isResting = false,
  });

  /// Check if reading is within valid physiological range
  bool get isValid => bpm >= 30 && bpm <= 250;

  /// Check if reading is recent (within last 5 minutes)
  bool get isRecent =>
      DateTime.now().difference(timestamp).inMinutes <= 5;

  @override
  String toString() =>
      'HeartRate($bpm bpm @ ${timestamp.toIso8601String()}, $dataSource)';
}

// ═══════════════════════════════════════════════════════════════════════════
// BLOOD OXYGEN (SpO₂)
// ═══════════════════════════════════════════════════════════════════════════

/// Normalized blood oxygen (SpO₂) reading from any wearable platform.
class NormalizedOxygenReading {
  /// Patient's Firebase UID
  final String patientUid;

  /// When this reading was recorded by the device
  final DateTime timestamp;

  /// Blood oxygen saturation percentage (0-100)
  final int percentage;

  /// Source platform
  final HealthDataSource dataSource;

  /// Detected device type (if available)
  final DetectedDeviceType deviceType;

  /// Data reliability classification
  final DataReliability reliability;

  const NormalizedOxygenReading({
    required this.patientUid,
    required this.timestamp,
    required this.percentage,
    required this.dataSource,
    this.deviceType = DetectedDeviceType.unknown,
    this.reliability = DataReliability.medium,
  });

  /// Check if reading is within valid range
  bool get isValid => percentage >= 70 && percentage <= 100;

  /// Check if reading indicates potential hypoxemia
  bool get isLow => percentage < 94;

  /// Check if reading is recent (within last 15 minutes)
  bool get isRecent =>
      DateTime.now().difference(timestamp).inMinutes <= 15;

  @override
  String toString() =>
      'SpO2($percentage% @ ${timestamp.toIso8601String()}, $dataSource)';
}

// ═══════════════════════════════════════════════════════════════════════════
// SLEEP DATA
// ═══════════════════════════════════════════════════════════════════════════

/// Sleep stage classification (standardized across platforms)
enum NormalizedSleepStage {
  /// Awake during sleep session
  awake,

  /// Light sleep (N1/N2)
  light,

  /// Deep sleep (N3/slow wave)
  deep,

  /// REM sleep
  rem,

  /// Generic "asleep" when stages not available
  asleep,

  /// Unknown or unclassified
  unknown,
}

/// A single sleep segment within a session
class NormalizedSleepSegment {
  final DateTime startTime;
  final DateTime endTime;
  final NormalizedSleepStage stage;

  const NormalizedSleepSegment({
    required this.startTime,
    required this.endTime,
    required this.stage,
  });

  /// Duration of this segment
  Duration get duration => endTime.difference(startTime);

  /// Check if segment has valid time ordering
  bool get isValid => endTime.isAfter(startTime);

  @override
  String toString() =>
      'SleepSegment(${stage.name}, ${duration.inMinutes} min)';
}

/// Complete sleep session with optional stage breakdown.
class NormalizedSleepSession {
  /// Patient's Firebase UID
  final String patientUid;

  /// When sleep started
  final DateTime sleepStart;

  /// When sleep ended
  final DateTime sleepEnd;

  /// Individual sleep stage segments (may be empty if stages unavailable)
  final List<NormalizedSleepSegment> segments;

  /// Source platform
  final HealthDataSource dataSource;

  /// Detected device type (if available)
  final DetectedDeviceType deviceType;

  /// Data reliability classification
  final DataReliability reliability;

  /// Whether this session has stage-level detail
  final bool hasStageData;

  const NormalizedSleepSession({
    required this.patientUid,
    required this.sleepStart,
    required this.sleepEnd,
    required this.segments,
    required this.dataSource,
    this.deviceType = DetectedDeviceType.unknown,
    this.reliability = DataReliability.medium,
    this.hasStageData = false,
  });

  /// Total sleep duration
  Duration get totalDuration => sleepEnd.difference(sleepStart);

  /// Total hours slept
  double get totalHours => totalDuration.inMinutes / 60;

  /// Check if session has valid time ordering
  bool get isValid => sleepEnd.isAfter(sleepStart);

  /// Check if session is at least 30 minutes
  bool get isMinimumLength => totalDuration.inMinutes >= 30;

  /// Duration in a specific stage
  Duration durationInStage(NormalizedSleepStage stage) {
    return segments
        .where((s) => s.stage == stage)
        .fold(Duration.zero, (total, s) => total + s.duration);
  }

  /// Percentage of time in each stage
  Map<NormalizedSleepStage, double> get stagePercentages {
    if (!hasStageData || segments.isEmpty) return {};

    final totalMinutes = totalDuration.inMinutes;
    if (totalMinutes == 0) return {};

    final result = <NormalizedSleepStage, double>{};
    for (final stage in NormalizedSleepStage.values) {
      final stageMinutes = durationInStage(stage).inMinutes;
      if (stageMinutes > 0) {
        result[stage] = (stageMinutes / totalMinutes) * 100;
      }
    }
    return result;
  }

  @override
  String toString() =>
      'SleepSession(${totalHours.toStringAsFixed(1)}h, ${segments.length} segments, $dataSource)';
}

// ═══════════════════════════════════════════════════════════════════════════
// HEART RATE VARIABILITY
// ═══════════════════════════════════════════════════════════════════════════

/// Normalized HRV reading (SDNN metric).
class NormalizedHRVReading {
  /// Patient's Firebase UID
  final String patientUid;

  /// When this reading was recorded
  final DateTime timestamp;

  /// SDNN value in milliseconds (standard deviation of NN intervals)
  final double sdnnMs;

  /// Source platform
  final HealthDataSource dataSource;

  /// Detected device type (if available)
  final DetectedDeviceType deviceType;

  /// Data reliability classification
  final DataReliability reliability;

  /// Optional: R-R intervals if available (in milliseconds)
  final List<int>? rrIntervals;

  const NormalizedHRVReading({
    required this.patientUid,
    required this.timestamp,
    required this.sdnnMs,
    required this.dataSource,
    this.deviceType = DetectedDeviceType.unknown,
    this.reliability = DataReliability.medium,
    this.rrIntervals,
  });

  /// Check if reading is within typical range
  bool get isValid => sdnnMs >= 0 && sdnnMs <= 300;

  /// General HRV classification
  String get classification {
    if (sdnnMs < 20) return 'Very Low';
    if (sdnnMs < 50) return 'Low';
    if (sdnnMs < 100) return 'Normal';
    return 'High';
  }

  @override
  String toString() =>
      'HRV(SDNN: ${sdnnMs.toStringAsFixed(1)} ms @ ${timestamp.toIso8601String()}, $dataSource)';
}

// ═══════════════════════════════════════════════════════════════════════════
// AGGREGATE VITALS SNAPSHOT
// ═══════════════════════════════════════════════════════════════════════════

/// Aggregated snapshot of recent vitals for quick UI display.
///
/// This is a convenience wrapper when you need "latest everything".
class NormalizedVitalsSnapshot {
  /// Patient's Firebase UID
  final String patientUid;

  /// When this snapshot was created
  final DateTime fetchedAt;

  /// Most recent heart rate reading (nullable if no data)
  final NormalizedHeartRateReading? latestHeartRate;

  /// Most recent SpO₂ reading (nullable if no data)
  final NormalizedOxygenReading? latestOxygen;

  /// Most recent HRV reading (nullable if no data)
  final NormalizedHRVReading? latestHRV;

  /// Last night's sleep session (nullable if no data)
  final NormalizedSleepSession? lastSleepSession;

  /// Whether any data was available
  final bool hasAnyData;

  /// Metadata about the fetch operation
  final VitalsSnapshotMetadata metadata;

  const NormalizedVitalsSnapshot({
    required this.patientUid,
    required this.fetchedAt,
    this.latestHeartRate,
    this.latestOxygen,
    this.latestHRV,
    this.lastSleepSession,
    required this.hasAnyData,
    required this.metadata,
  });

  /// Check if heart rate data is available
  bool get hasHeartRate => latestHeartRate != null;

  /// Check if SpO₂ data is available
  bool get hasOxygen => latestOxygen != null;

  /// Check if HRV data is available
  bool get hasHRV => latestHRV != null;

  /// Check if sleep data is available
  bool get hasSleep => lastSleepSession != null;
}

/// Metadata about how the vitals snapshot was fetched.
class VitalsSnapshotMetadata {
  /// Platform used for extraction
  final HealthDataSource source;

  /// Time range that was queried
  final Duration queryWindow;

  /// Number of raw data points processed
  final int rawDataPointsProcessed;

  /// Number of duplicates filtered out
  final int duplicatesFiltered;

  /// Any warnings during extraction
  final List<String> warnings;

  const VitalsSnapshotMetadata({
    required this.source,
    required this.queryWindow,
    this.rawDataPointsProcessed = 0,
    this.duplicatesFiltered = 0,
    this.warnings = const [],
  });
}
