/// Health Extraction Result Types — Error Handling & Status
///
/// This module defines:
/// - Permission status enums
/// - Health availability status
/// - Result wrapper for all extraction operations
///
/// SCOPE: Data extraction layer only.
/// DO NOT add persistence, sync, or UI logic here.
library;

// ═══════════════════════════════════════════════════════════════════════════
// PERMISSION STATUS
// ═══════════════════════════════════════════════════════════════════════════

/// Overall health permission status.
enum HealthPermissionStatus {
  /// All requested permissions were granted
  granted,

  /// Some permissions granted, some denied
  partiallyGranted,

  /// All permissions were denied
  denied,

  /// User hasn't been asked yet
  notDetermined,

  /// Platform doesn't support health data (e.g., non-mobile)
  platformUnsupported,

  /// Health app/service not installed
  healthServiceUnavailable,

  /// User previously granted but later revoked in settings
  revoked,
}

/// Detailed permission status for each data type.
class HealthPermissionDetails {
  final HealthPermissionStatus overall;
  final bool heartRateGranted;
  final bool oxygenGranted;
  final bool sleepGranted;
  final bool hrvGranted;
  final String? denialReason;

  const HealthPermissionDetails({
    required this.overall,
    this.heartRateGranted = false,
    this.oxygenGranted = false,
    this.sleepGranted = false,
    this.hrvGranted = false,
    this.denialReason,
  });

  /// Check if at least one data type is available
  bool get hasAnyPermission =>
      heartRateGranted || oxygenGranted || sleepGranted || hrvGranted;

  /// Check if all requested data types are available
  bool get hasAllPermissions =>
      heartRateGranted && oxygenGranted && sleepGranted && hrvGranted;

  /// List of granted permission types
  List<String> get grantedTypes {
    final types = <String>[];
    if (heartRateGranted) types.add('heart_rate');
    if (oxygenGranted) types.add('oxygen');
    if (sleepGranted) types.add('sleep');
    if (hrvGranted) types.add('hrv');
    return types;
  }

  /// List of denied permission types
  List<String> get deniedTypes {
    final types = <String>[];
    if (!heartRateGranted) types.add('heart_rate');
    if (!oxygenGranted) types.add('oxygen');
    if (!sleepGranted) types.add('sleep');
    if (!hrvGranted) types.add('hrv');
    return types;
  }

  /// Factory for fully granted permissions
  static const allGranted = HealthPermissionDetails(
    overall: HealthPermissionStatus.granted,
    heartRateGranted: true,
    oxygenGranted: true,
    sleepGranted: true,
    hrvGranted: true,
  );

  /// Factory for no permissions
  static const noneGranted = HealthPermissionDetails(
    overall: HealthPermissionStatus.denied,
    heartRateGranted: false,
    oxygenGranted: false,
    sleepGranted: false,
    hrvGranted: false,
  );

  /// Factory for platform unsupported
  static const platformUnsupported = HealthPermissionDetails(
    overall: HealthPermissionStatus.platformUnsupported,
    denialReason: 'Platform does not support health data extraction',
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// HEALTH AVAILABILITY
// ═══════════════════════════════════════════════════════════════════════════

/// What health data capabilities are available on this device.
class HealthAvailability {
  /// Whether the platform supports health data at all
  final bool platformSupported;

  /// Whether the health service is installed (Health Connect on Android)
  final bool healthServiceInstalled;

  /// Whether a wearable device appears to be paired
  final bool wearableDetected;

  /// Available data types
  final bool heartRateAvailable;
  final bool oxygenAvailable;
  final bool sleepAvailable;
  final bool hrvAvailable;

  /// Detected platform
  final String platform;

  /// Human-readable status message
  final String statusMessage;

  const HealthAvailability({
    required this.platformSupported,
    required this.healthServiceInstalled,
    required this.wearableDetected,
    required this.heartRateAvailable,
    required this.oxygenAvailable,
    required this.sleepAvailable,
    required this.hrvAvailable,
    required this.platform,
    required this.statusMessage,
  });

  /// Check if any data type is available
  bool get hasAnyDataType =>
      heartRateAvailable || oxygenAvailable || sleepAvailable || hrvAvailable;

  /// Check if all data types are available
  bool get hasAllDataTypes =>
      heartRateAvailable && oxygenAvailable && sleepAvailable && hrvAvailable;

  /// Factory for unsupported platform
  static const unsupported = HealthAvailability(
    platformSupported: false,
    healthServiceInstalled: false,
    wearableDetected: false,
    heartRateAvailable: false,
    oxygenAvailable: false,
    sleepAvailable: false,
    hrvAvailable: false,
    platform: 'unknown',
    statusMessage: 'Platform does not support health data',
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// EXTRACTION ERROR CODES
// ═══════════════════════════════════════════════════════════════════════════

/// Standardized error codes for health extraction failures.
enum HealthExtractionErrorCode {
  /// Operation succeeded
  none,

  /// Platform not supported (not iOS or Android)
  platformUnsupported,

  /// Health service not available (Health Connect not installed)
  healthServiceUnavailable,

  /// Required permissions not granted
  permissionDenied,

  /// Permission was revoked after initial grant
  permissionRevoked,

  /// No wearable device paired
  noDevicePaired,

  /// Device paired but no data available for time range
  noDataAvailable,

  /// Data exists but is too old to be useful
  dataStale,

  /// Network or service timeout
  timeout,

  /// Unexpected platform error
  platformError,

  /// Invalid time range requested
  invalidTimeRange,

  /// Rate limited by health service
  rateLimited,

  /// Unknown error
  unknown,
}

// ═══════════════════════════════════════════════════════════════════════════
// RESULT WRAPPER
// ═══════════════════════════════════════════════════════════════════════════

/// Generic result wrapper for all health extraction operations.
///
/// Use this instead of throwing exceptions for cleaner error handling.
class HealthExtractionResult<T> {
  /// Whether the operation succeeded
  final bool success;

  /// The extracted data (null if failed)
  final T? data;

  /// Error code if failed
  final HealthExtractionErrorCode errorCode;

  /// Human-readable error message
  final String? errorMessage;

  /// Additional metadata about the extraction
  final HealthExtractionMetadata? metadata;

  const HealthExtractionResult._({
    required this.success,
    this.data,
    this.errorCode = HealthExtractionErrorCode.none,
    this.errorMessage,
    this.metadata,
  });

  /// Factory for successful result with data
  factory HealthExtractionResult.success(
    T data, {
    HealthExtractionMetadata? metadata,
  }) {
    return HealthExtractionResult._(
      success: true,
      data: data,
      metadata: metadata,
    );
  }

  /// Factory for failed result
  factory HealthExtractionResult.failure(
    HealthExtractionErrorCode code, {
    String? message,
    HealthExtractionMetadata? metadata,
  }) {
    return HealthExtractionResult._(
      success: false,
      errorCode: code,
      errorMessage: message ?? _defaultErrorMessage(code),
      metadata: metadata,
    );
  }

  /// Factory for empty result (no error, but no data)
  factory HealthExtractionResult.empty({
    String? message,
    HealthExtractionMetadata? metadata,
  }) {
    return HealthExtractionResult._(
      success: true,
      data: null,
      errorCode: HealthExtractionErrorCode.noDataAvailable,
      errorMessage: message ?? 'No data available for the requested time range',
      metadata: metadata,
    );
  }

  /// Check if result has data
  bool get hasData => data != null;

  /// Check if result is empty (success but no data)
  bool get isEmpty => success && data == null;

  /// Get data or throw if not available
  T get dataOrThrow {
    if (data == null) {
      throw StateError('No data available: $errorMessage');
    }
    return data as T;
  }

  /// Get data or default value
  T dataOr(T defaultValue) => data ?? defaultValue;

  /// Map the data if present
  HealthExtractionResult<R> map<R>(R Function(T) mapper) {
    if (success && data != null) {
      return HealthExtractionResult.success(
        mapper(data as T),
        metadata: metadata,
      );
    }
    return HealthExtractionResult.failure(
      errorCode,
      message: errorMessage,
      metadata: metadata,
    );
  }

  static String _defaultErrorMessage(HealthExtractionErrorCode code) {
    switch (code) {
      case HealthExtractionErrorCode.none:
        return 'No error';
      case HealthExtractionErrorCode.platformUnsupported:
        return 'This platform does not support health data extraction';
      case HealthExtractionErrorCode.healthServiceUnavailable:
        return 'Health service is not available. Please install Health Connect (Android) or ensure HealthKit is enabled (iOS)';
      case HealthExtractionErrorCode.permissionDenied:
        return 'Health data access was denied. Please grant permissions in Settings';
      case HealthExtractionErrorCode.permissionRevoked:
        return 'Health data permissions were revoked. Please re-grant in Settings';
      case HealthExtractionErrorCode.noDevicePaired:
        return 'No wearable device is paired. Please connect a health device';
      case HealthExtractionErrorCode.noDataAvailable:
        return 'No health data available for the requested time range';
      case HealthExtractionErrorCode.dataStale:
        return 'Health data is too old to be useful';
      case HealthExtractionErrorCode.timeout:
        return 'Health data request timed out';
      case HealthExtractionErrorCode.platformError:
        return 'An unexpected platform error occurred';
      case HealthExtractionErrorCode.invalidTimeRange:
        return 'Invalid time range specified';
      case HealthExtractionErrorCode.rateLimited:
        return 'Too many requests. Please try again later';
      case HealthExtractionErrorCode.unknown:
        return 'An unknown error occurred';
    }
  }

  @override
  String toString() {
    if (success) {
      return 'HealthExtractionResult.success($data)';
    }
    return 'HealthExtractionResult.failure($errorCode: $errorMessage)';
  }
}

/// Metadata about the extraction operation.
class HealthExtractionMetadata {
  /// When the extraction was performed
  final DateTime extractedAt;

  /// Time range that was queried
  final DateTime queryStart;
  final DateTime queryEnd;

  /// Number of raw data points found
  final int rawDataPoints;

  /// Number of duplicates filtered
  final int duplicatesFiltered;

  /// Extraction duration in milliseconds
  final int extractionDurationMs;

  /// Platform-specific source identifier
  final String sourceIdentifier;

  /// Any warnings (non-fatal issues)
  final List<String> warnings;

  const HealthExtractionMetadata({
    required this.extractedAt,
    required this.queryStart,
    required this.queryEnd,
    this.rawDataPoints = 0,
    this.duplicatesFiltered = 0,
    this.extractionDurationMs = 0,
    this.sourceIdentifier = 'unknown',
    this.warnings = const [],
  });

  /// Check if there were any warnings
  bool get hasWarnings => warnings.isNotEmpty;

  /// Time range as duration
  Duration get queryDuration => queryEnd.difference(queryStart);
}
