import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'exceptions.dart';
import 'auth_service.dart';
import 'security/security_utils.dart';
import 'telemetry/production_metrics.dart';

/// API Client - Central HTTP wrapper for all sync operations
/// 
/// Follows the specification from specs/sync/api_envelope.md
/// 
/// Features:
/// - Automatic header injection (auth, idempotency, tracing)
/// - Token refresh on 401
/// - Error mapping to typed exceptions
/// - Request/response envelope handling
class ApiClient {
  final http.Client _http;
  final String baseUrl;
  final AuthService authService;
  final String appVersion;
  final String deviceId;
  final ProductionMetrics? metrics;
  final SecureLogger logger;

  ApiClient({
    required this.baseUrl,
    required this.authService,
    required this.appVersion,
    required this.deviceId,
    http.Client? client,
    this.metrics,
    SecureLogger? logger,
  })  : _http = client ?? http.Client(),
        logger = logger ?? const SecureLogger(enabled: kDebugMode, redactPii: true);

  /// Execute an HTTP request with full error handling
  /// 
  /// [method] - HTTP method (GET, POST, PUT, PATCH, DELETE)
  /// [path] - API path (e.g., '/api/v1/users')
  /// [headers] - Additional headers (merged with defaults)
  /// [body] - Request body (for POST/PUT/PATCH)
  /// [timeout] - Request timeout
  /// [retryAuth] - Whether to retry on 401 after token refresh
  Future<Map<String, dynamic>> request({
    required String method,
    required String path,
    Map<String, String>? headers,
    dynamic body,
    Duration timeout = const Duration(seconds: 30),
    bool retryAuth = true,
  }) async {
    final token = await authService.getAccessToken();
    final traceId = headers?['Trace-Id'] ?? const Uuid().v4();

    final baseHeaders = {
      'Content-Type': 'application/json; charset=utf-8',
      if (token != null) 'Authorization': 'Bearer $token',
      'X-App-Version': appVersion,
      'X-Device-Id': deviceId,
      'Trace-Id': traceId,
      ...?headers,
    };

    final uri = Uri.parse('$baseUrl$path');
    
    // Secure logging - BEFORE request
    final sanitizedPath = SecurityUtils.sanitizePath(path);
    logger.debug(SecurityUtils.createSafeRequestLog(
      method: method,
      path: sanitizedPath,
      headers: baseHeaders,
      body: body,
    ));

    http.Response resp;

    try {
      switch (method.toUpperCase()) {
        case 'GET':
          resp = await _http
              .get(uri, headers: baseHeaders)
              .timeout(timeout);
          break;
        case 'POST':
          resp = await _http
              .post(uri, headers: baseHeaders, body: jsonEncode(body))
              .timeout(timeout);
          break;
        case 'PUT':
          resp = await _http
              .put(uri, headers: baseHeaders, body: jsonEncode(body))
              .timeout(timeout);
          break;
        case 'PATCH':
          resp = await _http
              .patch(uri, headers: baseHeaders, body: jsonEncode(body))
              .timeout(timeout);
          break;
        case 'DELETE':
          resp = await _http
              .delete(uri, headers: baseHeaders)
              .timeout(timeout);
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }
    } on TimeoutException {
      logger.error('Request timed out: $sanitizedPath');
      metrics?.recordCircuitTripped(reason: 'timeout'); // Count network failures
      throw NetworkException(
        message: 'Request timed out',
        errorType: 'timeout',
        traceId: traceId,
      );
    } on http.ClientException catch (e) {
      logger.error('Network error: $e | Path: $sanitizedPath');
      metrics?.recordCircuitTripped(reason: 'connection_refused'); // Count network failures
      throw NetworkException(
        message: 'Network error: $e',
        errorType: 'connection_refused',
        traceId: traceId,
      );
    } catch (e) {
      logger.error('Unexpected network error: $e | Path: $sanitizedPath');
      metrics?.recordCircuitTripped(reason: 'unknown'); // Count network failures
      throw NetworkException(
        message: 'Unexpected network error: $e',
        errorType: 'unknown',
        traceId: traceId,
      );
    }

    // Secure logging - AFTER response
    logger.debug(SecurityUtils.createSafeResponseLog(
      statusCode: resp.statusCode,
      headers: resp.headers,
      body: resp.body,
    ));

    return _handleResponse(resp, traceId, retryAuth, () {
      return request(
        method: method,
        path: path,
        headers: headers,
        body: body,
        timeout: timeout,
        retryAuth: false,
      );
    });
  }

  /// Handle HTTP response and map to exceptions
  Future<Map<String, dynamic>> _handleResponse(
    http.Response resp,
    String traceId,
    bool retryAuth,
    Future<Map<String, dynamic>> Function() retryFn,
  ) async {
    final status = resp.statusCode;
    final bodyStr = resp.body.isNotEmpty ? resp.body : '{}';

    Map<String, dynamic> jsonBody;
    try {
      jsonBody = jsonDecode(bodyStr) as Map<String, dynamic>;
    } catch (_) {
      jsonBody = {'error': {'code': 'PARSE_ERROR', 'message': bodyStr}};
    }

    // Success (2xx)
    if (status >= 200 && status < 300) {
      return jsonBody;
    }

    // Extract error details
    final error = jsonBody['error'] as Map<String, dynamic>?;
    final message = error?['message'] as String? ?? 'Unknown error';
    final details = error?['details'] as Map<String, dynamic>? ?? {};

    // Map status codes to exceptions (following specs/sync/error_mapping.md)
    switch (status) {
      case 400:
      case 422:
        throw ValidationException(
          message: message,
          field: details['field'] as String?,
          constraint: details['constraint'] as String?,
          httpStatus: status,
          traceId: traceId,
        );

      case 401:
        // Try token refresh once
        if (retryAuth) {
          logger.info('Token expired, attempting refresh...');
          final refreshed = await authService.tryRefresh();
          if (refreshed) {
            logger.info('Token refresh successful, retrying request');
            metrics?.recordAuthRefresh(success: true);
            return await retryFn();
          } else {
            logger.warning('Token refresh failed');
            metrics?.recordAuthRefresh(success: false);
          }
        }
        throw AuthException(
          message: message,
          requiresLogin: true,
          httpStatus: status,
          traceId: traceId,
        );

      case 403:
        throw PermissionDeniedException(
          message: message,
          requiredPermission: details['required_permission'] as String?,
          httpStatus: status,
          traceId: traceId,
        );

      case 404:
        throw ResourceNotFoundException(
          message: message,
          resourceType: details['resource_type'] as String? ?? 'Resource',
          resourceId: details['resource_id'] as String? ?? 'unknown',
          httpStatus: status,
          traceId: traceId,
        );

      case 409:
        throw ConflictException(
          message: message,
          conflictType: details['conflict_type'] as String? ?? 'version',
          serverVersion: details['server_version'] as int?,
          clientVersion: details['client_version'] as int?,
          lastModifiedBy: details['last_modified_by'] as String?,
          httpStatus: status,
          traceId: traceId,
        );

      case 429:
        final retryAfterSeconds = _parseRetryAfter(resp);
        throw RetryableException(
          message: message,
          retryAfter: retryAfterSeconds != null
              ? Duration(seconds: retryAfterSeconds)
              : null,
          limit: details['limit'] as int?,
          window: details['window'] as String?,
          resetAt: details['reset_at'] != null
              ? DateTime.parse(details['reset_at'] as String)
              : null,
          httpStatus: status,
          traceId: traceId,
        );

      case 500:
      case 502:
        // Retry using exponential backoff (no Retry-After header expected)
        throw ServerException(
          message: message,
          retryAfter: null,
          httpStatus: status,
          traceId: traceId,
        );

      case 503:
        final retryAfterSeconds = _parseRetryAfter(resp);
        throw ServiceUnavailableException(
          message: message,
          retryAfter: retryAfterSeconds != null
              ? Duration(seconds: retryAfterSeconds)
              : null,
          httpStatus: status,
          traceId: traceId,
        );

      case 504:
        throw TimeoutException(
          message: message,
          retryAfter: null,
          httpStatus: status,
          traceId: traceId,
        );

      default:
        // Other 4xx client errors
        if (status >= 400 && status < 500) {
          throw ClientException(
            code: status,
            message: message,
            traceId: traceId,
          );
        }
        // Other 5xx server errors
        throw ServerException(
          message: 'Server error ($status): $message',
          retryAfter: null,
          httpStatus: status,
          traceId: traceId,
        );
    }
  }

  /// Parse Retry-After header (RFC 7231)
  /// 
  /// Returns delay in seconds, or null if not present/invalid
  int? _parseRetryAfter(http.Response resp) {
    final header = resp.headers['retry-after'];
    if (header == null) return null;

    // Try parsing as seconds
    final seconds = int.tryParse(header);
    if (seconds != null) return seconds;

    // Try parsing as HTTP date
    try {
      final parsed = DateTime.parse(header);
      final now = DateTime.now().toUtc();
      final diff = parsed.toUtc().difference(now);
      return diff.inSeconds > 0 ? diff.inSeconds : null;
    } catch (_) {
      return null;
    }
  }

  /// Close the underlying HTTP client
  void close() {
    _http.close();
  }
}
