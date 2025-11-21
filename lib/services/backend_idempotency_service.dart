import 'package:dio/dio.dart';
import '../services/telemetry_service.dart';

/// Result of backend idempotency capability detection.
enum IdempotencySupport {
  supported,    // Backend accepts and validates idempotency keys
  unsupported,  // Backend does not support idempotency
  unknown,      // Not yet tested
}

/// Service to verify backend idempotency support via handshake.
/// Tests if backend accepts `X-Idempotency-Key` header and responds with
/// `X-Idempotency-Accepted: true`.
class BackendIdempotencyService {
  final Dio _client;
  IdempotencySupport _support = IdempotencySupport.unknown;
  DateTime? _lastHandshakeAt;

  BackendIdempotencyService({Dio? client})
      : _client = client ?? Dio();

  IdempotencySupport get support => _support;

  /// Perform handshake with backend to detect idempotency support.
  /// 
  /// Sends a test request with `X-Idempotency-Key` header to [handshakeEndpoint].
  /// If response contains `X-Idempotency-Accepted: true`, marks as supported.
  /// Otherwise, marks as unsupported and enables local fallback.
  /// 
  /// Returns true if backend supports idempotency.
  Future<bool> performHandshake({
    required String handshakeEndpoint,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final sw = Stopwatch()..start();
    try {
      final testKey = 'handshake-test-${DateTime.now().millisecondsSinceEpoch}';
      final response = await _client.post(
        handshakeEndpoint,
        options: Options(
          headers: {'X-Idempotency-Key': testKey},
          validateStatus: (status) => status != null && status < 500,
          sendTimeout: timeout,
          receiveTimeout: timeout,
        ),
        data: {'type': 'idempotency_handshake'},
      );

      final accepted = _checkIdempotencyHeader(response);
      _support = accepted ? IdempotencySupport.supported : IdempotencySupport.unsupported;
      _lastHandshakeAt = DateTime.now().toUtc();
      
      sw.stop();
      TelemetryService.I.time('backend_idempotency.handshake.duration_ms', () => sw.elapsed);
      TelemetryService.I.gauge('backend_idempotency.supported', accepted ? 1 : 0);
      
      return accepted;
    } on DioException {
      // Network error or backend unavailable - assume unsupported
      _support = IdempotencySupport.unsupported;
      _lastHandshakeAt = DateTime.now().toUtc();
      sw.stop();
      TelemetryService.I.time('backend_idempotency.handshake.duration_ms', () => sw.elapsed);
      TelemetryService.I.gauge('backend_idempotency.supported', 0);
      TelemetryService.I.increment('backend_idempotency.handshake.errors');
      return false;
    } catch (e) {
      // Other error - also treat as unsupported
      _support = IdempotencySupport.unsupported;
      _lastHandshakeAt = DateTime.now().toUtc();
      sw.stop();
      TelemetryService.I.increment('backend_idempotency.handshake.errors');
      return false;
    }
  }

  /// Verify if a specific operation response indicates idempotency acceptance.
  /// Checks for `X-Idempotency-Accepted: true` header in response.
  bool verifyOperationResponse(Response response) {
    final accepted = _checkIdempotencyHeader(response);
    if (!accepted && _support == IdempotencySupport.supported) {
      // Backend previously supported but now doesn't - log degradation
      TelemetryService.I.increment('backend_idempotency.support_degraded');
    }
    return accepted;
  }

  /// Check response headers for idempotency acceptance.
  bool _checkIdempotencyHeader(Response response) {
    // Try to get header value (case-insensitive)
    final acceptedValue = response.headers.value('x-idempotency-accepted') ??
                          response.headers.value('X-Idempotency-Accepted');
    
    if (acceptedValue == 'true' || acceptedValue == '1') {
      return true;
    }

    // Alternative: check body field
    if (response.data is Map) {
      final bodyAccepted = response.data['idempotencyAccepted'] as bool?;
      if (bodyAccepted == true) return true;
    }

    return false;
  }

  /// Build request options with idempotency key header.
  Options buildIdempotentOptions({
    required String idempotencyKey,
    Options? baseOptions,
  }) {
    final headers = Map<String, dynamic>.from(baseOptions?.headers ?? {});
    headers['X-Idempotency-Key'] = idempotencyKey;
    
    return Options(
      headers: headers,
      method: baseOptions?.method,
      sendTimeout: baseOptions?.sendTimeout,
      receiveTimeout: baseOptions?.receiveTimeout,
      extra: baseOptions?.extra,
      responseType: baseOptions?.responseType,
      contentType: baseOptions?.contentType,
      validateStatus: baseOptions?.validateStatus,
      receiveDataWhenStatusError: baseOptions?.receiveDataWhenStatusError,
      followRedirects: baseOptions?.followRedirects,
      maxRedirects: baseOptions?.maxRedirects,
      requestEncoder: baseOptions?.requestEncoder,
      responseDecoder: baseOptions?.responseDecoder,
      listFormat: baseOptions?.listFormat,
    );
  }

  /// Check if handshake should be re-run (e.g., after 24 hours).
  bool shouldRevalidate({Duration revalidateAfter = const Duration(hours: 24)}) {
    if (_lastHandshakeAt == null) return true;
    return DateTime.now().toUtc().difference(_lastHandshakeAt!) > revalidateAfter;
  }

  /// Get human-readable support status.
  String get supportStatus {
    switch (_support) {
      case IdempotencySupport.supported:
        return 'Backend supports idempotency (validated ${_lastHandshakeAt?.toIso8601String() ?? 'never'})';
      case IdempotencySupport.unsupported:
        return 'Backend does not support idempotency - using local fallback';
      case IdempotencySupport.unknown:
        return 'Idempotency support not yet tested';
    }
  }
}
