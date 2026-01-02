/// PatientHealthExtractionService — Unified Health Data Extraction Layer
///
/// This service provides platform-agnostic health data extraction for patients.
///
/// SUPPORTED PLATFORMS:
/// - iOS: Apple HealthKit (Apple Watch, manual entries)
/// - Android: Health Connect (Samsung, Xiaomi, Fitbit, etc.)
///
/// SUPPORTED DATA TYPES:
/// - Heart Rate (bpm)
/// - Blood Oxygen (SpO₂ %)
/// - Sleep Sessions (with stages where available)
/// - Heart Rate Variability (SDNN)
///
/// SCOPE RULES (STRICTLY ENFORCED):
/// ❌ NO Hive writes
/// ❌ NO Firestore writes
/// ❌ NO BLE/direct device communication
/// ❌ NO raw ECG/PPG waveforms
/// ❌ NO background workers
/// ❌ NO real-time streaming guarantees
/// ✅ READ-ONLY from OS health stores
/// ✅ Returns normalized in-memory objects only
///
/// ARCHITECTURE:
/// UI → PatientHealthExtractionService → health package → OS Health API
///                                            ↓
///                              Normalized Dart objects (in-memory)
library;

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import '../models/normalized_health_data.dart';
import '../models/health_extraction_result.dart';

/// Singleton service for patient health data extraction.
///
/// Usage:
/// ```dart
/// final service = PatientHealthExtractionService.instance;
/// final availability = await service.checkAvailability();
/// if (availability.hasAnyDataType) {
///   final permissions = await service.requestPermissions();
///   if (permissions.hasAnyPermission) {
///     final vitals = await service.fetchRecentVitals(patientUid: 'abc123');
///   }
/// }
/// ```
class PatientHealthExtractionService {
  PatientHealthExtractionService._();

  static final PatientHealthExtractionService _instance =
      PatientHealthExtractionService._();

  /// Singleton instance
  static PatientHealthExtractionService get instance => _instance;

  /// Internal health package instance
  final Health _health = Health();

  /// Track if we've already requested permissions this session
  bool _permissionsRequested = false;

  /// Cached permission status (cleared on app restart)
  HealthPermissionDetails? _cachedPermissions;

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC API — AVAILABILITY CHECK
  // ═══════════════════════════════════════════════════════════════════════════

  /// Check what health data capabilities are available on this device.
  ///
  /// This does NOT request permissions — it only checks platform support.
  /// Safe to call repeatedly.
  ///
  /// Returns [HealthAvailability] with details about:
  /// - Platform support
  /// - Health service installation status
  /// - Available data types
  Future<HealthAvailability> checkAvailability() async {
    _log('CheckingAvailability');

    // Platform check
    if (!Platform.isIOS && !Platform.isAndroid) {
      _log('PlatformUnsupported', details: 'Running on ${Platform.operatingSystem}');
      return HealthAvailability.unsupported;
    }

    final platform = Platform.isIOS ? 'ios' : 'android';

    try {
      // On iOS, HealthKit is always available (built into the OS)
      // On Android, we need to check if Health Connect is installed
      if (Platform.isAndroid) {
        // Health Connect availability check
        final status = await _health.getHealthConnectSdkStatus();
        if (status == null || status != HealthConnectSdkStatus.sdkAvailable) {
          _log('HealthServiceUnavailable', details: 'Health Connect status: $status');
          return HealthAvailability(
            platformSupported: true,
            healthServiceInstalled: false,
            wearableDetected: false,
            heartRateAvailable: false,
            oxygenAvailable: false,
            sleepAvailable: false,
            hrvAvailable: false,
            platform: platform,
            statusMessage: _getHealthConnectStatusMessage(status ?? HealthConnectSdkStatus.sdkUnavailable),
          );
        }
      }

      // Platform supported, health service available
      // Data type availability depends on device capabilities and what's synced
      _log('AvailabilityCheckComplete', details: 'Platform: $platform, service installed');

      return HealthAvailability(
        platformSupported: true,
        healthServiceInstalled: true,
        // We can't reliably detect wearable pairing without permissions
        wearableDetected: true, // Assume true if service is available
        // All data types are theoretically available
        heartRateAvailable: true,
        oxygenAvailable: true,
        sleepAvailable: true,
        hrvAvailable: Platform.isIOS, // HRV SDNN more reliable on iOS
        platform: platform,
        statusMessage: 'Health data extraction available',
      );
    } catch (e) {
      _log('AvailabilityCheckError', details: e.toString());
      return HealthAvailability(
        platformSupported: true,
        healthServiceInstalled: false,
        wearableDetected: false,
        heartRateAvailable: false,
        oxygenAvailable: false,
        sleepAvailable: false,
        hrvAvailable: false,
        platform: platform,
        statusMessage: 'Error checking health availability: $e',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC API — PERMISSION HANDLING
  // ═══════════════════════════════════════════════════════════════════════════

  /// Request health data permissions from the user.
  ///
  /// This will show the system permission dialog (HealthKit on iOS,
  /// Health Connect on Android).
  ///
  /// Returns [HealthPermissionDetails] with:
  /// - Overall status
  /// - Per-data-type grant status
  /// - Denial reason if applicable
  ///
  /// NOTE: On iOS, we cannot detect which specific types were denied.
  /// iOS only tells us if authorization was requested, not the result.
  Future<HealthPermissionDetails> requestPermissions() async {
    _log('RequestingPermissions');

    // Platform check
    if (!Platform.isIOS && !Platform.isAndroid) {
      _log('PlatformUnsupported');
      return HealthPermissionDetails.platformUnsupported;
    }

    // Data types to request
    final types = _getRequiredHealthTypes();

    try {
      // Request authorization
      final granted = await _health.requestAuthorization(
        types,
        permissions: types.map((_) => HealthDataAccess.READ).toList(),
      );

      _permissionsRequested = true;

      if (granted) {
        _log('PermissionsGranted');
        _cachedPermissions = HealthPermissionDetails.allGranted;
        return _cachedPermissions!;
      }

      // Check which permissions we actually have
      final details = await _checkIndividualPermissions(types);
      _cachedPermissions = details;

      if (details.hasAnyPermission) {
        _log('PermissionsPartiallyGranted', details: 'Granted: ${details.grantedTypes}');
      } else {
        _log('PermissionsDenied');
      }

      return details;
    } catch (e) {
      _log('PermissionRequestError', details: e.toString());
      return HealthPermissionDetails(
        overall: HealthPermissionStatus.denied,
        denialReason: 'Error requesting permissions: $e',
      );
    }
  }

  /// Check current permission status without requesting.
  ///
  /// Returns cached status if available, otherwise checks with OS.
  Future<HealthPermissionDetails> checkPermissionStatus() async {
    if (_cachedPermissions != null) {
      return _cachedPermissions!;
    }

    if (!Platform.isIOS && !Platform.isAndroid) {
      return HealthPermissionDetails.platformUnsupported;
    }

    final types = _getRequiredHealthTypes();
    return _checkIndividualPermissions(types);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC API — DATA EXTRACTION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fetch recent vitals (heart rate, SpO₂) for a patient.
  ///
  /// Parameters:
  /// - [patientUid]: Firebase UID of the patient
  /// - [windowMinutes]: How far back to look (default: 60 minutes)
  ///
  /// Returns [HealthExtractionResult] with [NormalizedVitalsSnapshot].
  Future<HealthExtractionResult<NormalizedVitalsSnapshot>> fetchRecentVitals({
    required String patientUid,
    int windowMinutes = 60,
  }) async {
    _log('FetchingRecentVitals', details: 'window: ${windowMinutes}min');

    final stopwatch = Stopwatch()..start();
    final now = DateTime.now();
    final start = now.subtract(Duration(minutes: windowMinutes));

    // Validate input
    if (patientUid.isEmpty) {
      return HealthExtractionResult.failure(
        HealthExtractionErrorCode.unknown,
        message: 'Patient UID cannot be empty',
      );
    }

    // Platform check
    if (!Platform.isIOS && !Platform.isAndroid) {
      return HealthExtractionResult.failure(
        HealthExtractionErrorCode.platformUnsupported,
      );
    }

    // Permission check
    final permissions = await checkPermissionStatus();
    if (!permissions.hasAnyPermission && !_permissionsRequested) {
      return HealthExtractionResult.failure(
        HealthExtractionErrorCode.permissionDenied,
        message: 'Permissions not granted. Call requestPermissions() first.',
      );
    }

    try {
      final warnings = <String>[];
      int totalRawPoints = 0;
      int duplicatesFiltered = 0;

      // Fetch heart rate
      NormalizedHeartRateReading? latestHR;
      if (permissions.heartRateGranted || _permissionsRequested) {
        final hrResult = await _fetchHeartRateData(
          patientUid: patientUid,
          start: start,
          end: now,
        );
        if (hrResult.isNotEmpty) {
          totalRawPoints += hrResult.length;
          // Deduplicate and get latest
          final deduped = _deduplicateByTimestamp(hrResult);
          duplicatesFiltered += hrResult.length - deduped.length;
          latestHR = deduped.isNotEmpty ? deduped.last : null;
        } else {
          warnings.add('No heart rate data in time window');
        }
      }

      // Fetch SpO₂
      NormalizedOxygenReading? latestO2;
      if (permissions.oxygenGranted || _permissionsRequested) {
        final o2Result = await _fetchOxygenData(
          patientUid: patientUid,
          start: start,
          end: now,
        );
        if (o2Result.isNotEmpty) {
          totalRawPoints += o2Result.length;
          final deduped = _deduplicateOxygenByTimestamp(o2Result);
          duplicatesFiltered += o2Result.length - deduped.length;
          latestO2 = deduped.isNotEmpty ? deduped.last : null;
        } else {
          warnings.add('No SpO2 data in time window');
        }
      }

      // Fetch HRV (if available)
      NormalizedHRVReading? latestHRV;
      if ((permissions.hrvGranted || _permissionsRequested) && Platform.isIOS) {
        final hrvResult = await _fetchHRVDataInternal(
          patientUid: patientUid,
          start: start,
          end: now,
        );
        if (hrvResult.isNotEmpty) {
          totalRawPoints += hrvResult.length;
          latestHRV = hrvResult.last;
        }
      }

      stopwatch.stop();

      final metadata = HealthExtractionMetadata(
        extractedAt: now,
        queryStart: start,
        queryEnd: now,
        rawDataPoints: totalRawPoints,
        duplicatesFiltered: duplicatesFiltered,
        extractionDurationMs: stopwatch.elapsedMilliseconds,
        sourceIdentifier: Platform.isIOS ? 'apple_health' : 'health_connect',
        warnings: warnings,
      );

      final hasAnyData = latestHR != null || latestO2 != null || latestHRV != null;

      if (!hasAnyData) {
        _log('NoDataAvailable', details: 'No vitals found in ${windowMinutes}min window');
        return HealthExtractionResult.empty(
          message: 'No vitals data available in the requested time window',
          metadata: metadata,
        );
      }

      final snapshot = NormalizedVitalsSnapshot(
        patientUid: patientUid,
        fetchedAt: now,
        latestHeartRate: latestHR,
        latestOxygen: latestO2,
        latestHRV: latestHRV,
        lastSleepSession: null, // Sleep fetched separately
        hasAnyData: hasAnyData,
        metadata: VitalsSnapshotMetadata(
          source: Platform.isIOS
              ? HealthDataSource.appleHealth
              : HealthDataSource.healthConnect,
          queryWindow: Duration(minutes: windowMinutes),
          rawDataPointsProcessed: totalRawPoints,
          duplicatesFiltered: duplicatesFiltered,
          warnings: warnings,
        ),
      );

      _log('VitalsFetchComplete', details: 'HR: ${latestHR?.bpm}, O2: ${latestO2?.percentage}');
      return HealthExtractionResult.success(snapshot, metadata: metadata);
    } catch (e) {
      _log('VitalsFetchError', details: e.toString());
      return HealthExtractionResult.failure(
        HealthExtractionErrorCode.platformError,
        message: 'Error fetching vitals: $e',
      );
    }
  }

  /// Fetch sleep sessions for a time range.
  ///
  /// Parameters:
  /// - [patientUid]: Firebase UID of the patient
  /// - [start]: Start of time range (default: yesterday 6pm)
  /// - [end]: End of time range (default: now)
  ///
  /// Returns [HealthExtractionResult] with list of [NormalizedSleepSession].
  Future<HealthExtractionResult<List<NormalizedSleepSession>>> fetchSleepSessions({
    required String patientUid,
    DateTime? start,
    DateTime? end,
  }) async {
    final now = DateTime.now();
    // Default: look from yesterday 6pm to now (captures last night's sleep)
    final queryStart = start ?? DateTime(now.year, now.month, now.day - 1, 18);
    final queryEnd = end ?? now;

    _log('FetchingSleepSessions', details: 'range: ${queryStart.toIso8601String()} to ${queryEnd.toIso8601String()}');

    final stopwatch = Stopwatch()..start();

    // Validate
    if (patientUid.isEmpty) {
      return HealthExtractionResult.failure(
        HealthExtractionErrorCode.unknown,
        message: 'Patient UID cannot be empty',
      );
    }

    if (queryEnd.isBefore(queryStart)) {
      return HealthExtractionResult.failure(
        HealthExtractionErrorCode.invalidTimeRange,
        message: 'End time must be after start time',
      );
    }

    // Platform check
    if (!Platform.isIOS && !Platform.isAndroid) {
      return HealthExtractionResult.failure(
        HealthExtractionErrorCode.platformUnsupported,
      );
    }

    try {
      // Fetch sleep data from health package
      final sleepTypes = <HealthDataType>[
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_AWAKE,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_REM,
        HealthDataType.SLEEP_SESSION,
      ];

      final healthData = await _health.getHealthDataFromTypes(
        types: sleepTypes,
        startTime: queryStart,
        endTime: queryEnd,
      );

      stopwatch.stop();

      final metadata = HealthExtractionMetadata(
        extractedAt: now,
        queryStart: queryStart,
        queryEnd: queryEnd,
        rawDataPoints: healthData.length,
        extractionDurationMs: stopwatch.elapsedMilliseconds,
        sourceIdentifier: Platform.isIOS ? 'apple_health' : 'health_connect',
      );

      if (healthData.isEmpty) {
        _log('NoSleepDataAvailable');
        return HealthExtractionResult.empty(
          message: 'No sleep data available for the requested time range',
          metadata: metadata,
        );
      }

      // Convert to normalized sleep sessions
      final sessions = _convertToSleepSessions(patientUid, healthData);

      if (sessions.isEmpty) {
        _log('NoValidSleepSessions');
        return HealthExtractionResult.empty(
          message: 'No valid sleep sessions found',
          metadata: metadata,
        );
      }

      _log('SleepFetchComplete', details: '${sessions.length} sessions found');
      return HealthExtractionResult.success(sessions, metadata: metadata);
    } catch (e) {
      _log('SleepFetchError', details: e.toString());
      return HealthExtractionResult.failure(
        HealthExtractionErrorCode.platformError,
        message: 'Error fetching sleep data: $e',
      );
    }
  }

  /// Fetch HRV (Heart Rate Variability) data.
  ///
  /// Parameters:
  /// - [patientUid]: Firebase UID of the patient
  /// - [windowMinutes]: How far back to look (default: 24 hours)
  ///
  /// Returns [HealthExtractionResult] with list of [NormalizedHRVReading].
  ///
  /// NOTE: HRV data is more reliably available on iOS (Apple Watch).
  /// Android support varies by device manufacturer.
  Future<HealthExtractionResult<List<NormalizedHRVReading>>> fetchHRVData({
    required String patientUid,
    int windowMinutes = 1440, // 24 hours default
  }) async {
    _log('FetchingHRVData', details: 'window: ${windowMinutes}min');

    final stopwatch = Stopwatch()..start();
    final now = DateTime.now();
    final start = now.subtract(Duration(minutes: windowMinutes));

    // Validate
    if (patientUid.isEmpty) {
      return HealthExtractionResult.failure(
        HealthExtractionErrorCode.unknown,
        message: 'Patient UID cannot be empty',
      );
    }

    // Platform check
    if (!Platform.isIOS && !Platform.isAndroid) {
      return HealthExtractionResult.failure(
        HealthExtractionErrorCode.platformUnsupported,
      );
    }

    try {
      final readings = await _fetchHRVDataInternal(
        patientUid: patientUid,
        start: start,
        end: now,
      );

      stopwatch.stop();

      final metadata = HealthExtractionMetadata(
        extractedAt: now,
        queryStart: start,
        queryEnd: now,
        rawDataPoints: readings.length,
        extractionDurationMs: stopwatch.elapsedMilliseconds,
        sourceIdentifier: Platform.isIOS ? 'apple_health' : 'health_connect',
      );

      if (readings.isEmpty) {
        _log('NoHRVDataAvailable');
        return HealthExtractionResult.empty(
          message: 'No HRV data available. HRV requires a compatible wearable.',
          metadata: metadata,
        );
      }

      _log('HRVFetchComplete', details: '${readings.length} readings');
      return HealthExtractionResult.success(readings, metadata: metadata);
    } catch (e) {
      _log('HRVFetchError', details: e.toString());
      return HealthExtractionResult.failure(
        HealthExtractionErrorCode.platformError,
        message: 'Error fetching HRV data: $e',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE — DATA FETCHING HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<NormalizedHeartRateReading>> _fetchHeartRateData({
    required String patientUid,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: start,
        endTime: end,
      );

      return data.map((point) {
        final value = (point.value as NumericHealthValue).numericValue;
        return NormalizedHeartRateReading(
          patientUid: patientUid,
          timestamp: point.dateFrom,
          bpm: value.toInt(),
          dataSource: Platform.isIOS
              ? HealthDataSource.appleHealth
              : HealthDataSource.healthConnect,
          deviceType: _detectDeviceType(point.sourceName),
          reliability: _assessReliability(point.dateFrom),
          isResting: point.type == HealthDataType.RESTING_HEART_RATE,
        );
      }).where((r) => r.isValid).toList();
    } catch (e) {
      _log('HeartRateFetchError', details: e.toString());
      return [];
    }
  }

  Future<List<NormalizedOxygenReading>> _fetchOxygenData({
    required String patientUid,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.BLOOD_OXYGEN],
        startTime: start,
        endTime: end,
      );

      return data.map((point) {
        final value = (point.value as NumericHealthValue).numericValue;
        // SpO2 is returned as decimal (0.97) or percentage (97) depending on source
        final percentage = value > 1 ? value.toInt() : (value * 100).toInt();
        return NormalizedOxygenReading(
          patientUid: patientUid,
          timestamp: point.dateFrom,
          percentage: percentage,
          dataSource: Platform.isIOS
              ? HealthDataSource.appleHealth
              : HealthDataSource.healthConnect,
          deviceType: _detectDeviceType(point.sourceName),
          reliability: _assessReliability(point.dateFrom),
        );
      }).where((r) => r.isValid).toList();
    } catch (e) {
      _log('OxygenFetchError', details: e.toString());
      return [];
    }
  }

  Future<List<NormalizedHRVReading>> _fetchHRVDataInternal({
    required String patientUid,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE_VARIABILITY_SDNN],
        startTime: start,
        endTime: end,
      );

      return data.map((point) {
        final value = (point.value as NumericHealthValue).numericValue;
        return NormalizedHRVReading(
          patientUid: patientUid,
          timestamp: point.dateFrom,
          sdnnMs: value.toDouble(),
          dataSource: Platform.isIOS
              ? HealthDataSource.appleHealth
              : HealthDataSource.healthConnect,
          deviceType: _detectDeviceType(point.sourceName),
          reliability: _assessReliability(point.dateFrom),
        );
      }).where((r) => r.isValid).toList();
    } catch (e) {
      _log('HRVFetchError', details: e.toString());
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE — CONVERSION & PROCESSING
  // ═══════════════════════════════════════════════════════════════════════════

  List<NormalizedSleepSession> _convertToSleepSessions(
    String patientUid,
    List<HealthDataPoint> data,
  ) {
    if (data.isEmpty) return [];

    // Group sleep data by session
    // A session is defined by SLEEP_SESSION type or by continuous sleep segments
    final sessions = <NormalizedSleepSession>[];
    final sessionPoints = data.where((p) => p.type == HealthDataType.SLEEP_SESSION).toList();

    if (sessionPoints.isNotEmpty) {
      // Use explicit session markers
      for (final session in sessionPoints) {
        final sessionStart = session.dateFrom;
        final sessionEnd = session.dateTo;

        // Find segments within this session
        final segments = data
            .where((p) =>
                p.type != HealthDataType.SLEEP_SESSION &&
                !p.dateFrom.isBefore(sessionStart) &&
                !p.dateTo.isAfter(sessionEnd))
            .map((p) => NormalizedSleepSegment(
                  startTime: p.dateFrom,
                  endTime: p.dateTo,
                  stage: _healthTypeToSleepStage(p.type),
                ))
            .where((s) => s.isValid)
            .toList();

        sessions.add(NormalizedSleepSession(
          patientUid: patientUid,
          sleepStart: sessionStart,
          sleepEnd: sessionEnd,
          segments: segments,
          dataSource: Platform.isIOS
              ? HealthDataSource.appleHealth
              : HealthDataSource.healthConnect,
          deviceType: _detectDeviceType(session.sourceName),
          reliability: DataReliability.high,
          hasStageData: segments.isNotEmpty,
        ));
      }
    } else {
      // No explicit sessions — construct from segments
      final stageData = data.where((p) => p.type != HealthDataType.SLEEP_SESSION).toList();
      if (stageData.isEmpty) return [];

      stageData.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));

      // Find continuous sleep periods (gaps < 2 hours indicate same session)
      final segments = <NormalizedSleepSegment>[];
      DateTime? sessionStart;
      DateTime? sessionEnd;

      for (var i = 0; i < stageData.length; i++) {
        final point = stageData[i];

        if (sessionStart == null) {
          sessionStart = point.dateFrom;
          sessionEnd = point.dateTo;
        } else {
          final gap = point.dateFrom.difference(sessionEnd!);
          if (gap.inHours >= 2) {
            // End current session, start new one
            if (segments.isNotEmpty) {
              sessions.add(NormalizedSleepSession(
                patientUid: patientUid,
                sleepStart: sessionStart,
                sleepEnd: sessionEnd,
                segments: List.from(segments),
                dataSource: Platform.isIOS
                    ? HealthDataSource.appleHealth
                    : HealthDataSource.healthConnect,
                hasStageData: true,
                reliability: DataReliability.medium,
              ));
            }
            segments.clear();
            sessionStart = point.dateFrom;
          }
          sessionEnd = point.dateTo;
        }

        segments.add(NormalizedSleepSegment(
          startTime: point.dateFrom,
          endTime: point.dateTo,
          stage: _healthTypeToSleepStage(point.type),
        ));
      }

      // Add final session
      if (segments.isNotEmpty && sessionStart != null && sessionEnd != null) {
        sessions.add(NormalizedSleepSession(
          patientUid: patientUid,
          sleepStart: sessionStart,
          sleepEnd: sessionEnd,
          segments: segments,
          dataSource: Platform.isIOS
              ? HealthDataSource.appleHealth
              : HealthDataSource.healthConnect,
          hasStageData: true,
          reliability: DataReliability.medium,
        ));
      }
    }

    // Filter out sessions shorter than 30 minutes
    return sessions.where((s) => s.isMinimumLength).toList();
  }

  NormalizedSleepStage _healthTypeToSleepStage(HealthDataType type) {
    switch (type) {
      case HealthDataType.SLEEP_AWAKE:
        return NormalizedSleepStage.awake;
      case HealthDataType.SLEEP_LIGHT:
        return NormalizedSleepStage.light;
      case HealthDataType.SLEEP_DEEP:
        return NormalizedSleepStage.deep;
      case HealthDataType.SLEEP_REM:
        return NormalizedSleepStage.rem;
      case HealthDataType.SLEEP_ASLEEP:
        return NormalizedSleepStage.asleep;
      default:
        return NormalizedSleepStage.unknown;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE — DEDUPLICATION
  // ═══════════════════════════════════════════════════════════════════════════

  List<NormalizedHeartRateReading> _deduplicateByTimestamp(
    List<NormalizedHeartRateReading> readings,
  ) {
    if (readings.isEmpty) return readings;

    // Sort by timestamp
    readings.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Remove duplicates within 1 second
    final deduped = <NormalizedHeartRateReading>[];
    for (final reading in readings) {
      if (deduped.isEmpty) {
        deduped.add(reading);
      } else {
        final last = deduped.last;
        if (reading.timestamp.difference(last.timestamp).inSeconds > 1) {
          deduped.add(reading);
        }
      }
    }
    return deduped;
  }

  List<NormalizedOxygenReading> _deduplicateOxygenByTimestamp(
    List<NormalizedOxygenReading> readings,
  ) {
    if (readings.isEmpty) return readings;

    readings.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final deduped = <NormalizedOxygenReading>[];
    for (final reading in readings) {
      if (deduped.isEmpty) {
        deduped.add(reading);
      } else {
        final last = deduped.last;
        // SpO2 readings are less frequent, use 30 second threshold
        if (reading.timestamp.difference(last.timestamp).inSeconds > 30) {
          deduped.add(reading);
        }
      }
    }
    return deduped;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE — HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  List<HealthDataType> _getRequiredHealthTypes() {
    final types = <HealthDataType>[
      HealthDataType.HEART_RATE,
      HealthDataType.BLOOD_OXYGEN,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_AWAKE,
      HealthDataType.SLEEP_DEEP,
      HealthDataType.SLEEP_LIGHT,
      HealthDataType.SLEEP_REM,
      HealthDataType.SLEEP_SESSION,
      HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    ];

    // Add iOS-specific types
    if (Platform.isIOS) {
      types.add(HealthDataType.RESTING_HEART_RATE);
    }

    return types;
  }

  Future<HealthPermissionDetails> _checkIndividualPermissions(
    List<HealthDataType> types,
  ) async {
    try {
      // Check heart rate
      final hrTypes = [HealthDataType.HEART_RATE];
      final hrGranted = await _health.hasPermissions(hrTypes) ?? false;

      // Check oxygen
      final o2Types = [HealthDataType.BLOOD_OXYGEN];
      final o2Granted = await _health.hasPermissions(o2Types) ?? false;

      // Check sleep
      final sleepTypes = [
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_SESSION,
      ];
      final sleepGranted = await _health.hasPermissions(sleepTypes) ?? false;

      // Check HRV
      final hrvTypes = [HealthDataType.HEART_RATE_VARIABILITY_SDNN];
      final hrvGranted = await _health.hasPermissions(hrvTypes) ?? false;

      final hasAny = hrGranted || o2Granted || sleepGranted || hrvGranted;
      final hasAll = hrGranted && o2Granted && sleepGranted && hrvGranted;

      return HealthPermissionDetails(
        overall: hasAll
            ? HealthPermissionStatus.granted
            : hasAny
                ? HealthPermissionStatus.partiallyGranted
                : HealthPermissionStatus.denied,
        heartRateGranted: hrGranted,
        oxygenGranted: o2Granted,
        sleepGranted: sleepGranted,
        hrvGranted: hrvGranted,
      );
    } catch (e) {
      _log('PermissionCheckError', details: e.toString());
      return HealthPermissionDetails.noneGranted;
    }
  }

  DetectedDeviceType _detectDeviceType(String sourceName) {
    final name = sourceName.toLowerCase();

    if (name.contains('apple') || name.contains('watch')) {
      return DetectedDeviceType.appleWatch;
    }
    if (name.contains('samsung') || name.contains('galaxy')) {
      return DetectedDeviceType.samsungGalaxyWatch;
    }
    if (name.contains('xiaomi') || name.contains('mi band')) {
      return DetectedDeviceType.xiaomiBand;
    }
    if (name.contains('amazfit')) {
      return DetectedDeviceType.xiaomiAmazfit;
    }
    if (name.contains('fitbit')) {
      return DetectedDeviceType.fitbit;
    }
    if (name.contains('garmin')) {
      return DetectedDeviceType.garmin;
    }
    if (name.contains('withings')) {
      return DetectedDeviceType.withings;
    }
    if (name.contains('oura')) {
      return DetectedDeviceType.oura;
    }
    if (name.contains('manual') || name.contains('user')) {
      return DetectedDeviceType.manual;
    }

    return DetectedDeviceType.unknown;
  }

  DataReliability _assessReliability(DateTime timestamp) {
    final age = DateTime.now().difference(timestamp);

    if (age.inMinutes <= 5) {
      return DataReliability.high;
    }
    if (age.inHours <= 1) {
      return DataReliability.medium;
    }
    return DataReliability.low;
  }

  String _getHealthConnectStatusMessage(HealthConnectSdkStatus status) {
    switch (status) {
      case HealthConnectSdkStatus.sdkAvailable:
        return 'Health Connect is available';
      case HealthConnectSdkStatus.sdkUnavailable:
        return 'Health Connect is not available on this device';
      case HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired:
        return 'Health Connect requires an update. Please update Google Play Services';
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE — LOGGING
  // ═══════════════════════════════════════════════════════════════════════════

  void _log(String event, {String? details}) {
    final message = details != null
        ? '[HealthExtract] $event: $details'
        : '[HealthExtract] $event';
    debugPrint(message);
  }
}
