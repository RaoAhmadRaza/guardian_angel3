import 'package:flutter/foundation.dart';

/// Request model for arrhythmia analysis API.
@immutable
class ArrhythmiaAnalysisRequest {
  /// Client-generated UUID for request tracing.
  final String requestId;

  /// RR intervals in milliseconds.
  final List<int> rrIntervalsMs;

  /// Metadata about the analysis window.
  final WindowMetadata windowMetadata;

  const ArrhythmiaAnalysisRequest({
    required this.requestId,
    required this.rrIntervalsMs,
    required this.windowMetadata,
  });

  /// Convert to JSON for API request.
  Map<String, dynamic> toJson() => {
        'request_id': requestId,
        'rr_intervals_ms': rrIntervalsMs,
        'window_metadata': windowMetadata.toJson(),
      };

  @override
  String toString() =>
      'ArrhythmiaAnalysisRequest(requestId: $requestId, rrCount: ${rrIntervalsMs.length})';
}

/// Metadata about the analysis window.
@immutable
class WindowMetadata {
  /// Start of the RR interval window.
  final DateTime startTimestamp;

  /// End of the RR interval window.
  final DateTime endTimestamp;

  /// Device that captured the data.
  final String? sourceDevice;

  /// Optional patient identifier for audit logging.
  final String? patientUid;

  const WindowMetadata({
    required this.startTimestamp,
    required this.endTimestamp,
    this.sourceDevice,
    this.patientUid,
  });

  /// Duration of the window.
  Duration get duration => endTimestamp.difference(startTimestamp);

  /// Convert to JSON for API request.
  Map<String, dynamic> toJson() => {
        'start_timestamp_iso': startTimestamp.toUtc().toIso8601String(),
        'end_timestamp_iso': endTimestamp.toUtc().toIso8601String(),
        if (sourceDevice != null) 'source_device': sourceDevice,
        if (patientUid != null) 'patient_uid': patientUid,
      };
}
