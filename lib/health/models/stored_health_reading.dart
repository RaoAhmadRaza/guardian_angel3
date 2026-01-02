/// Stored Health Reading — Hive Persistence Model
///
/// This is the LOCAL PERSISTENCE model for health data.
/// It wraps all normalized reading types into a single polymorphic model
/// using a discriminated union approach via `readingType`.
///
/// KEY DESIGN DECISIONS:
/// 1. Composite key for deduplication: {patientUid}_{readingType}_{ISO8601}
/// 2. JSON map for payload: flexible, forward-compatible
/// 3. All timestamps in UTC: deterministic, timezone-safe
/// 4. Schema versioning: enables future migrations
///
/// SCOPE: Local persistence only. No Firestore, no sync.
library;

/// Type discriminator for stored health readings.
enum StoredHealthReadingType {
  /// Heart rate reading (bpm)
  heartRate,

  /// Blood oxygen saturation (SpO₂ %)
  bloodOxygen,

  /// Sleep session with optional stage breakdown
  sleepSession,

  /// Heart rate variability (SDNN)
  hrvReading,
}

/// Extension for enum serialization.
extension StoredHealthReadingTypeExtension on StoredHealthReadingType {
  String get value => name;

  static StoredHealthReadingType fromString(String value) {
    return StoredHealthReadingType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => StoredHealthReadingType.heartRate,
    );
  }
}

/// Hive-persisted health reading.
///
/// Uses discriminated union pattern via `readingType` field.
/// All data stored in JSON map for flexibility and forward compatibility.
///
/// COMPOSITE KEY STRATEGY:
/// Keys follow pattern: {patientUid}_{readingType}_{ISO8601TimestampUTC}
/// Example: "abc123_heartRate_2026-01-02T10:30:00.000Z"
///
/// This enables:
/// 1. Natural deduplication — same key = same reading
/// 2. Efficient prefix queries — "patientUid_heartRate_*" for type filtering
/// 3. Time-ordered iteration — lexicographic sort = chronological order
/// 4. Collision-free — timestamp precision to milliseconds
class StoredHealthReading {
  /// Composite key: patientUid_readingType_timestamp
  /// This is the Hive key and must be deterministic.
  final String id;

  /// Patient Firebase UID
  final String patientUid;

  /// Type discriminator for polymorphic deserialization
  final StoredHealthReadingType readingType;

  /// Original timestamp from wearable (UTC)
  final DateTime recordedAt;

  /// When this reading was persisted locally (UTC)
  final DateTime persistedAt;

  /// Data source identifier (apple_health, health_connect, unknown)
  final String dataSource;

  /// Device type identifier (apple_watch, samsung_galaxy_watch, etc.)
  final String deviceType;

  /// Reliability classification (high, medium, low)
  final String reliability;

  /// JSON-encoded reading payload (type-specific)
  ///
  /// For heartRate: `{bpm: int, isResting: bool}`
  /// For bloodOxygen: `{percentage: int}`
  /// For sleepSession: `{sleepStart: ISO8601, sleepEnd: ISO8601, totalMinutes: int, segments: [...]}`
  /// For hrvReading: `{sdnnMs: double, rrIntervals: List<int>?}`
  final Map<String, dynamic> data;

  /// Schema version for migration support
  final int schemaVersion;

  const StoredHealthReading({
    required this.id,
    required this.patientUid,
    required this.readingType,
    required this.recordedAt,
    required this.persistedAt,
    required this.dataSource,
    required this.deviceType,
    required this.reliability,
    required this.data,
    this.schemaVersion = 1,
  });

  /// Generate deterministic composite key for deduplication.
  ///
  /// Format: {patientUid}_{readingType}_{ISO8601TimestampUTC}
  /// Example: "abc123_heartRate_2026-01-02T10:30:00.000Z"
  static String generateKey(
    String patientUid,
    StoredHealthReadingType type,
    DateTime timestamp,
  ) {
    final ts = timestamp.toUtc().toIso8601String();
    return '${patientUid}_${type.name}_$ts';
  }

  /// Create from normalized heart rate reading.
  factory StoredHealthReading.fromHeartRate({
    required String patientUid,
    required DateTime timestamp,
    required int bpm,
    required String dataSource,
    required String deviceType,
    required String reliability,
    bool isResting = false,
  }) {
    return StoredHealthReading(
      id: generateKey(patientUid, StoredHealthReadingType.heartRate, timestamp),
      patientUid: patientUid,
      readingType: StoredHealthReadingType.heartRate,
      recordedAt: timestamp.toUtc(),
      persistedAt: DateTime.now().toUtc(),
      dataSource: dataSource,
      deviceType: deviceType,
      reliability: reliability,
      data: {
        'bpm': bpm,
        'isResting': isResting,
      },
    );
  }

  /// Create from normalized oxygen reading.
  factory StoredHealthReading.fromOxygen({
    required String patientUid,
    required DateTime timestamp,
    required int percentage,
    required String dataSource,
    required String deviceType,
    required String reliability,
  }) {
    return StoredHealthReading(
      id: generateKey(patientUid, StoredHealthReadingType.bloodOxygen, timestamp),
      patientUid: patientUid,
      readingType: StoredHealthReadingType.bloodOxygen,
      recordedAt: timestamp.toUtc(),
      persistedAt: DateTime.now().toUtc(),
      dataSource: dataSource,
      deviceType: deviceType,
      reliability: reliability,
      data: {
        'percentage': percentage,
      },
    );
  }

  /// Create from normalized sleep session.
  factory StoredHealthReading.fromSleepSession({
    required String patientUid,
    required DateTime sleepStart,
    required DateTime sleepEnd,
    required String dataSource,
    required String deviceType,
    required String reliability,
    List<Map<String, dynamic>>? segments,
    bool hasStageData = false,
  }) {
    final totalMinutes = sleepEnd.difference(sleepStart).inMinutes;
    return StoredHealthReading(
      // Use sleep START as key timestamp for session identity
      id: generateKey(patientUid, StoredHealthReadingType.sleepSession, sleepStart),
      patientUid: patientUid,
      readingType: StoredHealthReadingType.sleepSession,
      recordedAt: sleepStart.toUtc(),
      persistedAt: DateTime.now().toUtc(),
      dataSource: dataSource,
      deviceType: deviceType,
      reliability: reliability,
      data: {
        'sleepStart': sleepStart.toUtc().toIso8601String(),
        'sleepEnd': sleepEnd.toUtc().toIso8601String(),
        'totalMinutes': totalMinutes,
        'hasStageData': hasStageData,
        if (segments != null && segments.isNotEmpty) 'segments': segments,
      },
    );
  }

  /// Create from normalized HRV reading.
  factory StoredHealthReading.fromHRV({
    required String patientUid,
    required DateTime timestamp,
    required double sdnnMs,
    required String dataSource,
    required String deviceType,
    required String reliability,
    List<int>? rrIntervals,
  }) {
    return StoredHealthReading(
      id: generateKey(patientUid, StoredHealthReadingType.hrvReading, timestamp),
      patientUid: patientUid,
      readingType: StoredHealthReadingType.hrvReading,
      recordedAt: timestamp.toUtc(),
      persistedAt: DateTime.now().toUtc(),
      dataSource: dataSource,
      deviceType: deviceType,
      reliability: reliability,
      data: {
        'sdnnMs': sdnnMs,
        if (rrIntervals != null && rrIntervals.isNotEmpty) 'rrIntervals': rrIntervals,
      },
    );
  }

  /// Check if this reading matches the prefix for a patient + type query.
  bool matchesPrefix(String patientUid, StoredHealthReadingType? type) {
    if (this.patientUid != patientUid) return false;
    if (type != null && readingType != type) return false;
    return true;
  }

  /// Check if this reading is within a date range.
  bool isInDateRange(DateTime start, DateTime end) {
    return recordedAt.isAfter(start) && recordedAt.isBefore(end);
  }

  /// Check if this reading is expired based on retention period.
  bool isExpired(int retentionDays) {
    final cutoff = DateTime.now().toUtc().subtract(Duration(days: retentionDays));
    return recordedAt.isBefore(cutoff);
  }

  /// Validate the reading data.
  bool get isValid {
    if (id.isEmpty) return false;
    if (patientUid.isEmpty) return false;
    if (data.isEmpty) return false;

    switch (readingType) {
      case StoredHealthReadingType.heartRate:
        final bpm = data['bpm'] as int?;
        return bpm != null && bpm >= 20 && bpm <= 300;

      case StoredHealthReadingType.bloodOxygen:
        final percentage = data['percentage'] as int?;
        return percentage != null && percentage >= 0 && percentage <= 100;

      case StoredHealthReadingType.sleepSession:
        final sleepStart = data['sleepStart'] as String?;
        final sleepEnd = data['sleepEnd'] as String?;
        return sleepStart != null && sleepEnd != null;

      case StoredHealthReadingType.hrvReading:
        final sdnn = data['sdnnMs'] as num?;
        return sdnn != null && sdnn >= 0 && sdnn <= 500;
    }
  }

  /// Copy with updated fields.
  StoredHealthReading copyWith({
    String? id,
    String? patientUid,
    StoredHealthReadingType? readingType,
    DateTime? recordedAt,
    DateTime? persistedAt,
    String? dataSource,
    String? deviceType,
    String? reliability,
    Map<String, dynamic>? data,
    int? schemaVersion,
  }) {
    return StoredHealthReading(
      id: id ?? this.id,
      patientUid: patientUid ?? this.patientUid,
      readingType: readingType ?? this.readingType,
      recordedAt: recordedAt ?? this.recordedAt,
      persistedAt: persistedAt ?? this.persistedAt,
      dataSource: dataSource ?? this.dataSource,
      deviceType: deviceType ?? this.deviceType,
      reliability: reliability ?? this.reliability,
      data: data ?? this.data,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'patientUid': patientUid,
        'readingType': readingType.name,
        'recordedAt': recordedAt.toUtc().toIso8601String(),
        'persistedAt': persistedAt.toUtc().toIso8601String(),
        'dataSource': dataSource,
        'deviceType': deviceType,
        'reliability': reliability,
        'data': data,
        'schemaVersion': schemaVersion,
      };

  /// Deserialize from JSON.
  factory StoredHealthReading.fromJson(Map<String, dynamic> json) {
    return StoredHealthReading(
      id: json['id'] as String? ?? '',
      patientUid: json['patientUid'] as String? ?? '',
      readingType: StoredHealthReadingTypeExtension.fromString(
        json['readingType'] as String? ?? 'heartRate',
      ),
      recordedAt: DateTime.tryParse(json['recordedAt'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      persistedAt: DateTime.tryParse(json['persistedAt'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      dataSource: json['dataSource'] as String? ?? 'unknown',
      deviceType: json['deviceType'] as String? ?? 'unknown',
      reliability: json['reliability'] as String? ?? 'medium',
      data: (json['data'] as Map<String, dynamic>?) ?? {},
      schemaVersion: json['schemaVersion'] as int? ?? 1,
    );
  }

  @override
  String toString() =>
      'StoredHealthReading(${readingType.name}, $patientUid, ${recordedAt.toIso8601String()})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoredHealthReading &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// ═══════════════════════════════════════════════════════════════════════════
// SNAPSHOT & STATS MODELS
// ═══════════════════════════════════════════════════════════════════════════

/// Snapshot of latest vitals from local storage.
///
/// This is a convenience wrapper for UI display of "latest everything".
class StoredVitalsSnapshot {
  /// Patient Firebase UID
  final String patientUid;

  /// When this snapshot was generated
  final DateTime generatedAt;

  /// Latest heart rate reading (if available)
  final StoredHealthReading? latestHeartRate;

  /// Latest SpO₂ reading (if available)
  final StoredHealthReading? latestOxygen;

  /// Latest HRV reading (if available)
  final StoredHealthReading? latestHRV;

  /// Latest sleep session (if available)
  final StoredHealthReading? latestSleep;

  const StoredVitalsSnapshot({
    required this.patientUid,
    required this.generatedAt,
    this.latestHeartRate,
    this.latestOxygen,
    this.latestHRV,
    this.latestSleep,
  });

  /// Check if any data is available.
  bool get hasAnyData =>
      latestHeartRate != null ||
      latestOxygen != null ||
      latestHRV != null ||
      latestSleep != null;

  /// Check if heart rate is available.
  bool get hasHeartRate => latestHeartRate != null;

  /// Check if SpO₂ is available.
  bool get hasOxygen => latestOxygen != null;

  /// Check if HRV is available.
  bool get hasHRV => latestHRV != null;

  /// Check if sleep is available.
  bool get hasSleep => latestSleep != null;

  /// Get heart rate BPM (if available).
  int? get heartRateBpm => latestHeartRate?.data['bpm'] as int?;

  /// Get SpO₂ percentage (if available).
  int? get oxygenPercentage => latestOxygen?.data['percentage'] as int?;

  /// Get HRV SDNN (if available).
  double? get hrvSdnn => (latestHRV?.data['sdnnMs'] as num?)?.toDouble();

  /// Get sleep duration in hours (if available).
  double? get sleepHours {
    final minutes = latestSleep?.data['totalMinutes'] as int?;
    return minutes != null ? minutes / 60.0 : null;
  }
}

/// Statistics about local health data storage.
class HealthStorageStats {
  /// Total number of readings stored.
  final int totalReadings;

  /// Number of heart rate readings.
  final int heartRateCount;

  /// Number of SpO₂ readings.
  final int oxygenCount;

  /// Number of sleep sessions.
  final int sleepCount;

  /// Number of HRV readings.
  final int hrvCount;

  /// Oldest reading timestamp (if any).
  final DateTime? oldestReading;

  /// Newest reading timestamp (if any).
  final DateTime? newestReading;

  /// Estimated storage size in bytes (approximate).
  final int? estimatedBytes;

  const HealthStorageStats({
    required this.totalReadings,
    required this.heartRateCount,
    required this.oxygenCount,
    required this.sleepCount,
    required this.hrvCount,
    this.oldestReading,
    this.newestReading,
    this.estimatedBytes,
  });

  /// Check if storage is empty.
  bool get isEmpty => totalReadings == 0;

  /// Get date range of stored data (if any).
  Duration? get dateRange {
    if (oldestReading == null || newestReading == null) return null;
    return newestReading!.difference(oldestReading!);
  }

  /// Get days of data stored.
  int? get daysOfData => dateRange?.inDays;
}
