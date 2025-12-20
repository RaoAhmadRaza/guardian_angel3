/// Sync Engine Exceptions
/// 
/// Typed exceptions for error handling in the sync pipeline.
/// Follows the error mapping specification from specs/sync/error_mapping.md

/// Base exception for all sync operations
abstract class SyncException implements Exception {
  final String message;
  final int? httpStatus;
  final String? traceId;
  final bool isRetryable;

  SyncException({
    required this.message,
    this.httpStatus,
    this.traceId,
    required this.isRetryable,
  });

  @override
  String toString() => '${runtimeType}: $message';
}

/// Network-level errors (timeouts, connection failures)
class NetworkException extends SyncException {
  final String errorType; // timeout, connection_refused, dns_failed, tls_failed

  NetworkException({
    required String message,
    required this.errorType,
    String? traceId,
  }) : super(
          message: message,
          traceId: traceId,
          isRetryable: true,
        );

  @override
  String toString() => 'NetworkException($errorType): $message';
}

/// Authentication errors (401)
class AuthException extends SyncException {
  final bool requiresLogin;

  AuthException({
    required String message,
    this.requiresLogin = true,
    int? httpStatus,
    String? traceId,
  }) : super(
          message: message,
          httpStatus: httpStatus,
          traceId: traceId,
          isRetryable: true, // Retryable after token refresh
        );
}

/// Permission denied (403)
class PermissionDeniedException extends SyncException {
  final String? requiredPermission;

  PermissionDeniedException({
    required String message,
    this.requiredPermission,
    int? httpStatus,
    String? traceId,
  }) : super(
          message: message,
          httpStatus: httpStatus,
          traceId: traceId,
          isRetryable: false,
        );
}

/// Resource not found (404)
class ResourceNotFoundException extends SyncException {
  final String resourceType;
  final String resourceId;

  ResourceNotFoundException({
    required String message,
    required this.resourceType,
    required this.resourceId,
    int? httpStatus,
    String? traceId,
  }) : super(
          message: message,
          httpStatus: httpStatus,
          traceId: traceId,
          isRetryable: false,
        );
}

/// Conflict errors (409)
class ConflictException extends SyncException {
  final String conflictType; // version, concurrent_edit, constraint
  final int? serverVersion;
  final int? clientVersion;
  final String? lastModifiedBy;

  ConflictException({
    required String message,
    this.conflictType = 'version',
    this.serverVersion,
    this.clientVersion,
    this.lastModifiedBy,
    int? httpStatus,
    String? traceId,
  }) : super(
          message: message,
          httpStatus: httpStatus,
          traceId: traceId,
          isRetryable: false, // Requires reconciliation
        );
}

/// Rate limiting errors (429)
class RetryableException extends SyncException {
  final Duration? retryAfter;
  final int? limit;
  final String? window;
  final DateTime? resetAt;

  RetryableException({
    required String message,
    this.retryAfter,
    this.limit,
    this.window,
    this.resetAt,
    int? httpStatus,
    String? traceId,
  }) : super(
          message: message,
          httpStatus: httpStatus,
          traceId: traceId,
          isRetryable: true,
        );
}

/// Server errors (5xx)
///
/// Treated as retryable with exponential backoff. Optionally honors
/// server-provided Retry-After if present.
class ServerException extends RetryableException {
  ServerException({
    required String message,
    Duration? retryAfter,
    int? httpStatus,
    String? traceId,
  }) : super(
          message: message,
          retryAfter: retryAfter,
          httpStatus: httpStatus,
          traceId: traceId,
        );
}

/// Service unavailable (503)
///
/// Retryable and may include a Retry-After header.
class ServiceUnavailableException extends RetryableException {
  ServiceUnavailableException({
    required String message,
    Duration? retryAfter,
    int? httpStatus,
    String? traceId,
  }) : super(
          message: message,
          retryAfter: retryAfter,
          httpStatus: httpStatus,
          traceId: traceId,
        );
}

/// Timeout errors (504)
///
/// Retryable and handled via exponential backoff.
class TimeoutException extends RetryableException {
  TimeoutException({
    required String message,
    Duration? retryAfter,
    int? httpStatus,
    String? traceId,
  }) : super(
          message: message,
          retryAfter: retryAfter,
          httpStatus: httpStatus,
          traceId: traceId,
        );
}

/// Client errors (4xx)
class ClientException extends SyncException {
  final String? field;
  final String? constraint;

  ClientException({
    required int code,
    required String message,
    this.field,
    this.constraint,
    String? traceId,
  }) : super(
          message: message,
          httpStatus: code,
          traceId: traceId,
          isRetryable: false,
        );

  @override
  String toString() => 'ClientException($httpStatus): $message';
}

/// Validation errors (400, 422)
class ValidationException extends SyncException {
  final String? field;
  final String? constraint;

  ValidationException({
    required String message,
    this.field,
    this.constraint,
    int? httpStatus,
    String? traceId,
  }) : super(
          message: message,
          httpStatus: httpStatus,
          traceId: traceId,
          isRetryable: false,
        );
}
