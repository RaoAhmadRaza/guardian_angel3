# Error Mapping Specification

**Version:** 1.0.0  
**Last Updated:** November 22, 2025

---

## Overview

This document defines the complete mapping between HTTP status codes and Guardian Angel exception types. The mapping enables consistent error handling, retry logic, and user feedback across the sync engine.

---

## Error Classification

All errors fall into three categories that determine retry behavior:

### 1. Transient Errors
**Definition:** Temporary failures that may succeed on retry

**Characteristics:**
- Network issues (timeout, connection refused)
- Server overload (503, 429)
- Temporary unavailability
- Rate limiting

**Client Action:** Retry with exponential backoff

**User Impact:** Transparent (no user notification unless exhausted)

### 2. Permanent Errors
**Definition:** Failures that will never succeed without intervention

**Characteristics:**
- Invalid input (400)
- Resource not found (404)
- Authorization failures (403)
- Validation errors

**Client Action:** Move to failed_ops queue, notify user

**User Impact:** Error message, manual intervention required

### 3. Ambiguous Errors
**Definition:** Conflicts or special cases requiring reconciliation

**Characteristics:**
- State conflicts (409)
- Precondition failures (412)
- Version mismatches

**Client Action:** Trigger conflict resolution flow

**User Impact:** Conflict resolution UI

---

## HTTP Status Code Mapping

### 2xx Success

#### 200 OK
**Exception:** None (success)  
**Classification:** N/A  
**Retry:** No  
**Description:** Request succeeded, response contains data

**Example:**
```dart
// No exception thrown
final response = await apiClient.get('/users/123');
return response.data;
```

#### 201 Created
**Exception:** None (success)  
**Classification:** N/A  
**Retry:** No  
**Description:** Resource created successfully

**Example:**
```dart
// No exception thrown
final response = await apiClient.post('/users', payload);
return response.data['user_id'];
```

#### 204 No Content
**Exception:** None (success)  
**Classification:** N/A  
**Retry:** No  
**Description:** Operation succeeded, no data to return (e.g., DELETE)

**Example:**
```dart
// No exception thrown
await apiClient.delete('/users/123');
```

---

### 4xx Client Errors

#### 400 Bad Request
**Exception:** `ValidationException`  
**Classification:** Permanent  
**Retry:** No  
**Description:** Malformed request or invalid payload

**Fields:**
- `message`: User-friendly validation error
- `field`: Field name that failed validation (optional)
- `constraint`: Constraint violated (e.g., "required", "email")

**Example:**
```dart
throw ValidationException(
  message: 'Email address is required',
  field: 'email',
  constraint: 'required',
  httpStatus: 400,
  traceId: traceId,
);
```

**Backend Error:**
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Email address is required",
    "details": {
      "field": "email",
      "constraint": "required"
    }
  }
}
```

#### 401 Unauthorized
**Exception:** `UnauthorizedException`  
**Classification:** Special (attempt token refresh)  
**Retry:** Once after token refresh  
**Description:** Missing or invalid authentication token

**Fields:**
- `message`: "Authentication required" or "Token expired"
- `requiresLogin`: Boolean indicating if re-login needed

**Example:**
```dart
throw UnauthorizedException(
  message: 'Token expired',
  requiresLogin: true,
  httpStatus: 401,
  traceId: traceId,
);
```

**Client Action:**
1. Attempt token refresh
2. Retry original request once
3. If still fails, require user login

#### 403 Forbidden
**Exception:** `PermissionDeniedException`  
**Classification:** Permanent  
**Retry:** No  
**Description:** User lacks permission for this operation

**Fields:**
- `message`: User-friendly permission error
- `requiredPermission`: Permission name required (optional)

**Example:**
```dart
throw PermissionDeniedException(
  message: 'You do not have permission to delete this room',
  requiredPermission: 'rooms.delete',
  httpStatus: 403,
  traceId: traceId,
);
```

**Backend Error:**
```json
{
  "error": {
    "code": "FORBIDDEN",
    "message": "You do not have permission to delete this room",
    "details": {
      "required_permission": "rooms.delete"
    }
  }
}
```

#### 404 Not Found
**Exception:** `ResourceNotFoundException`  
**Classification:** Permanent  
**Retry:** No  
**Description:** Requested resource does not exist

**Fields:**
- `message`: User-friendly "not found" error
- `resourceType`: Type of resource (e.g., "User", "Room")
- `resourceId`: ID of missing resource

**Example:**
```dart
throw ResourceNotFoundException(
  message: 'User not found',
  resourceType: 'User',
  resourceId: '123e4567-e89b-12d3-a456-426614174000',
  httpStatus: 404,
  traceId: traceId,
);
```

**Backend Error:**
```json
{
  "error": {
    "code": "RESOURCE_NOT_FOUND",
    "message": "User not found",
    "details": {
      "resource_type": "User",
      "resource_id": "123e4567-e89b-12d3-a456-426614174000"
    }
  }
}
```

#### 409 Conflict
**Exception:** `ConflictException`  
**Classification:** Ambiguous  
**Retry:** No (requires reconciliation)  
**Description:** Resource state conflict (version mismatch, concurrent edit)

**Fields:**
- `message`: User-friendly conflict description
- `conflictType`: Type of conflict ("version", "concurrent_edit", "constraint")
- `serverVersion`: Server's current resource version
- `clientVersion`: Client's attempted version
- `lastModifiedBy`: User who last modified (optional)

**Example:**
```dart
throw ConflictException(
  message: 'Resource has been modified by another user',
  conflictType: 'version',
  serverVersion: 3,
  clientVersion: 2,
  lastModifiedBy: 'user_456',
  httpStatus: 409,
  traceId: traceId,
);
```

**Backend Error:**
```json
{
  "error": {
    "code": "CONFLICT",
    "message": "Resource has been modified by another user",
    "details": {
      "conflict_type": "version",
      "server_version": 3,
      "client_version": 2,
      "last_modified_by": "user_456",
      "last_modified_at": "2025-11-22T12:04:30.000Z"
    }
  }
}
```

**Client Action:**
1. Fetch latest server state
2. Present conflict resolution UI
3. Apply user's choice (keep server, keep local, merge)
4. Retry with updated version

#### 412 Precondition Failed
**Exception:** `PreconditionFailedException`  
**Classification:** Ambiguous  
**Retry:** No (requires re-evaluation)  
**Description:** If-Match header failed (ETag mismatch)

**Fields:**
- `message`: "Resource has been modified"
- `currentETag`: Server's current ETag
- `providedETag`: Client's provided ETag

**Example:**
```dart
throw PreconditionFailedException(
  message: 'Resource has been modified',
  currentETag: 'abc456',
  providedETag: 'abc123',
  httpStatus: 412,
  traceId: traceId,
);
```

**Client Action:**
1. Fetch latest resource with new ETag
2. Re-apply local changes
3. Retry with updated ETag

#### 415 Unsupported Media Type
**Exception:** `ValidationException`  
**Classification:** Permanent  
**Retry:** No  
**Description:** Content-Type not application/json

**Example:**
```dart
throw ValidationException(
  message: 'Content-Type must be application/json',
  httpStatus: 415,
  traceId: traceId,
);
```

#### 422 Unprocessable Entity
**Exception:** `ValidationException`  
**Classification:** Permanent  
**Retry:** No  
**Description:** Semantically invalid request (valid JSON but business rule violation)

**Example:**
```dart
throw ValidationException(
  message: 'Birth date cannot be in the future',
  field: 'birth_date',
  constraint: 'past_date',
  httpStatus: 422,
  traceId: traceId,
);
```

#### 426 Upgrade Required
**Exception:** `ClientVersionException`  
**Classification:** Permanent  
**Retry:** No  
**Description:** Client version too old, upgrade required

**Fields:**
- `message`: "Please update the app"
- `minimumVersion`: Minimum supported version
- `currentVersion`: Client's current version

**Example:**
```dart
throw ClientVersionException(
  message: 'Please update to version 1.5.0 or later',
  minimumVersion: '1.5.0',
  currentVersion: '1.2.3',
  httpStatus: 426,
  traceId: traceId,
);
```

**Client Action:**
1. Show app update prompt
2. Redirect to app store

#### 429 Too Many Requests
**Exception:** `RateLimitException`  
**Classification:** Transient  
**Retry:** Yes (after Retry-After delay)  
**Description:** Rate limit exceeded

**Fields:**
- `message`: "Too many requests"
- `retryAfterSeconds`: Delay before retry (from Retry-After header)
- `limit`: Requests per window
- `window`: Time window (e.g., "1m", "1h")
- `resetAt`: When limit resets (ISO 8601)

**Example:**
```dart
throw RateLimitException(
  message: 'Too many requests. Please retry after 60 seconds.',
  retryAfterSeconds: 60,
  limit: 100,
  window: '1m',
  resetAt: DateTime.parse('2025-11-22T12:11:00Z'),
  httpStatus: 429,
  traceId: traceId,
);
```

**Backend Error:**
```json
{
  "error": {
    "code": "RATE_LIMITED",
    "message": "Too many requests. Please retry after 60 seconds.",
    "details": {
      "limit": 100,
      "window": "1m",
      "reset_at": "2025-11-22T12:11:00Z",
      "retry_after_seconds": 60
    }
  }
}
```

**Client Action:**
1. Extract `retryAfterSeconds` from exception
2. Override backoff delay with this value
3. Schedule retry after specified delay

---

### 5xx Server Errors

#### 500 Internal Server Error
**Exception:** `ServerException`  
**Classification:** Transient  
**Retry:** Yes (with exponential backoff)  
**Description:** Unexpected server-side error

**Fields:**
- `message`: "An unexpected error occurred"
- `isRetryable`: true

**Example:**
```dart
throw ServerException(
  message: 'An unexpected error occurred. Please try again.',
  isRetryable: true,
  httpStatus: 500,
  traceId: traceId,
);
```

**Client Action:**
1. Retry with exponential backoff (max 5 attempts)
2. If exhausted, move to failed_ops

#### 502 Bad Gateway
**Exception:** `ServerException`  
**Classification:** Transient  
**Retry:** Yes (with exponential backoff)  
**Description:** Gateway/proxy error

**Example:**
```dart
throw ServerException(
  message: 'Service temporarily unavailable',
  isRetryable: true,
  httpStatus: 502,
  traceId: traceId,
);
```

#### 503 Service Unavailable
**Exception:** `ServiceUnavailableException`  
**Classification:** Transient  
**Retry:** Yes (respect Retry-After header)  
**Description:** Service is down for maintenance or overloaded

**Fields:**
- `message`: "Service temporarily unavailable"
- `retryAfterSeconds`: Delay before retry (from Retry-After header, optional)

**Example:**
```dart
throw ServiceUnavailableException(
  message: 'Service temporarily unavailable',
  retryAfterSeconds: 120,
  httpStatus: 503,
  traceId: traceId,
);
```

**Client Action:**
1. If Retry-After present, wait specified duration
2. Otherwise, use exponential backoff
3. Max 5 retry attempts

#### 504 Gateway Timeout
**Exception:** `TimeoutException`  
**Classification:** Transient  
**Retry:** Yes (with exponential backoff)  
**Description:** Gateway/proxy timeout waiting for upstream

**Example:**
```dart
throw TimeoutException(
  message: 'Request timed out. Please try again.',
  httpStatus: 504,
  traceId: traceId,
);
```

---

## Network-Level Errors

These errors occur before receiving HTTP response (no status code).

#### Connection Timeout
**Exception:** `NetworkException`  
**Classification:** Transient  
**Retry:** Yes (with exponential backoff)  
**Description:** Request timed out before server response

**Fields:**
- `message`: "Connection timeout"
- `errorType`: "timeout"

**Example:**
```dart
throw NetworkException(
  message: 'Connection timeout',
  errorType: 'timeout',
  traceId: traceId,
);
```

#### Connection Refused
**Exception:** `NetworkException`  
**Classification:** Transient  
**Retry:** Yes (with exponential backoff)  
**Description:** Server not reachable (offline, firewall, etc.)

**Fields:**
- `message`: "Unable to connect to server"
- `errorType`: "connection_refused"

**Example:**
```dart
throw NetworkException(
  message: 'Unable to connect to server',
  errorType: 'connection_refused',
  traceId: traceId,
);
```

#### DNS Resolution Failed
**Exception:** `NetworkException`  
**Classification:** Transient  
**Retry:** Yes (with exponential backoff)  
**Description:** Cannot resolve hostname

**Fields:**
- `message`: "Network unavailable"
- `errorType`: "dns_failed"

**Example:**
```dart
throw NetworkException(
  message: 'Network unavailable',
  errorType: 'dns_failed',
  traceId: traceId,
);
```

#### TLS Handshake Failed
**Exception:** `NetworkException`  
**Classification:** Permanent (likely)  
**Retry:** Yes (1-2 attempts max)  
**Description:** SSL/TLS certificate validation failed

**Fields:**
- `message`: "Secure connection failed"
- `errorType`: "tls_failed"

**Example:**
```dart
throw NetworkException(
  message: 'Secure connection failed',
  errorType: 'tls_failed',
  traceId: traceId,
);
```

**Client Action:**
1. Retry once (may be transient)
2. If fails again, treat as permanent (certificate issue)

---

## Exception Hierarchy

```dart
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
}

// Transient errors
class NetworkException extends SyncException {
  final String errorType; // timeout, connection_refused, dns_failed, tls_failed
  
  NetworkException({
    required String message,
    required this.errorType,
    String? traceId,
  }) : super(message: message, traceId: traceId, isRetryable: true);
}

class ServerException extends SyncException {
  ServerException({
    required String message,
    int? httpStatus,
    String? traceId,
  }) : super(message: message, httpStatus: httpStatus, traceId: traceId, isRetryable: true);
}

class ServiceUnavailableException extends SyncException {
  final int? retryAfterSeconds;
  
  ServiceUnavailableException({
    required String message,
    this.retryAfterSeconds,
    int? httpStatus,
    String? traceId,
  }) : super(message: message, httpStatus: httpStatus, traceId: traceId, isRetryable: true);
}

class RateLimitException extends SyncException {
  final int retryAfterSeconds;
  final int limit;
  final String window;
  final DateTime resetAt;
  
  RateLimitException({
    required String message,
    required this.retryAfterSeconds,
    required this.limit,
    required this.window,
    required this.resetAt,
    int? httpStatus,
    String? traceId,
  }) : super(message: message, httpStatus: httpStatus, traceId: traceId, isRetryable: true);
}

class TimeoutException extends SyncException {
  TimeoutException({
    required String message,
    int? httpStatus,
    String? traceId,
  }) : super(message: message, httpStatus: httpStatus, traceId: traceId, isRetryable: true);
}

// Permanent errors
class ValidationException extends SyncException {
  final String? field;
  final String? constraint;
  
  ValidationException({
    required String message,
    this.field,
    this.constraint,
    int? httpStatus,
    String? traceId,
  }) : super(message: message, httpStatus: httpStatus, traceId: traceId, isRetryable: false);
}

class ResourceNotFoundException extends SyncException {
  final String resourceType;
  final String resourceId;
  
  ResourceNotFoundException({
    required String message,
    required this.resourceType,
    required this.resourceId,
    int? httpStatus,
    String? traceId,
  }) : super(message: message, httpStatus: httpStatus, traceId: traceId, isRetryable: false);
}

class PermissionDeniedException extends SyncException {
  final String? requiredPermission;
  
  PermissionDeniedException({
    required String message,
    this.requiredPermission,
    int? httpStatus,
    String? traceId,
  }) : super(message: message, httpStatus: httpStatus, traceId: traceId, isRetryable: false);
}

class ClientVersionException extends SyncException {
  final String minimumVersion;
  final String currentVersion;
  
  ClientVersionException({
    required String message,
    required this.minimumVersion,
    required this.currentVersion,
    int? httpStatus,
    String? traceId,
  }) : super(message: message, httpStatus: httpStatus, traceId: traceId, isRetryable: false);
}

// Ambiguous errors
class ConflictException extends SyncException {
  final String conflictType; // version, concurrent_edit, constraint
  final int? serverVersion;
  final int? clientVersion;
  final String? lastModifiedBy;
  
  ConflictException({
    required String message,
    required this.conflictType,
    this.serverVersion,
    this.clientVersion,
    this.lastModifiedBy,
    int? httpStatus,
    String? traceId,
  }) : super(message: message, httpStatus: httpStatus, traceId: traceId, isRetryable: false);
}

class PreconditionFailedException extends SyncException {
  final String currentETag;
  final String providedETag;
  
  PreconditionFailedException({
    required String message,
    required this.currentETag,
    required this.providedETag,
    int? httpStatus,
    String? traceId,
  }) : super(message: message, httpStatus: httpStatus, traceId: traceId, isRetryable: false);
}

// Special case
class UnauthorizedException extends SyncException {
  final bool requiresLogin;
  
  UnauthorizedException({
    required String message,
    required this.requiresLogin,
    int? httpStatus,
    String? traceId,
  }) : super(message: message, httpStatus: httpStatus, traceId: traceId, isRetryable: true); // Retryable after token refresh
}
```

---

## Error Response Parsing

### Parsing Logic

```dart
SyncException parseErrorResponse(int statusCode, Map<String, dynamic> body, String traceId) {
  final errorCode = body['error']['code'] as String?;
  final message = body['error']['message'] as String? ?? 'An error occurred';
  final details = body['error']['details'] as Map<String, dynamic>? ?? {};
  
  switch (statusCode) {
    case 400:
    case 415:
    case 422:
      return ValidationException(
        message: message,
        field: details['field'],
        constraint: details['constraint'],
        httpStatus: statusCode,
        traceId: traceId,
      );
      
    case 401:
      return UnauthorizedException(
        message: message,
        requiresLogin: true,
        httpStatus: statusCode,
        traceId: traceId,
      );
      
    case 403:
      return PermissionDeniedException(
        message: message,
        requiredPermission: details['required_permission'],
        httpStatus: statusCode,
        traceId: traceId,
      );
      
    case 404:
      return ResourceNotFoundException(
        message: message,
        resourceType: details['resource_type'] ?? 'Resource',
        resourceId: details['resource_id'] ?? 'unknown',
        httpStatus: statusCode,
        traceId: traceId,
      );
      
    case 409:
      return ConflictException(
        message: message,
        conflictType: details['conflict_type'] ?? 'version',
        serverVersion: details['server_version'],
        clientVersion: details['client_version'],
        lastModifiedBy: details['last_modified_by'],
        httpStatus: statusCode,
        traceId: traceId,
      );
      
    case 412:
      return PreconditionFailedException(
        message: message,
        currentETag: details['current_etag'] ?? '',
        providedETag: details['provided_etag'] ?? '',
        httpStatus: statusCode,
        traceId: traceId,
      );
      
    case 426:
      return ClientVersionException(
        message: message,
        minimumVersion: details['minimum_version'] ?? '1.0.0',
        currentVersion: details['current_version'] ?? '0.0.0',
        httpStatus: statusCode,
        traceId: traceId,
      );
      
    case 429:
      return RateLimitException(
        message: message,
        retryAfterSeconds: details['retry_after_seconds'] ?? 60,
        limit: details['limit'] ?? 0,
        window: details['window'] ?? 'unknown',
        resetAt: DateTime.parse(details['reset_at'] ?? DateTime.now().toIso8601String()),
        httpStatus: statusCode,
        traceId: traceId,
      );
      
    case 500:
    case 502:
      return ServerException(
        message: message,
        httpStatus: statusCode,
        traceId: traceId,
      );
      
    case 503:
      return ServiceUnavailableException(
        message: message,
        retryAfterSeconds: details['retry_after_seconds'],
        httpStatus: statusCode,
        traceId: traceId,
      );
      
    case 504:
      return TimeoutException(
        message: message,
        httpStatus: statusCode,
        traceId: traceId,
      );
      
    default:
      // Unknown error code, treat as server error
      return ServerException(
        message: 'Unexpected error (status $statusCode)',
        httpStatus: statusCode,
        traceId: traceId,
      );
  }
}
```

---

## Retry Decision Logic

```dart
bool shouldRetry(SyncException exception, int attemptCount) {
  // Never retry permanent errors
  if (!exception.isRetryable) {
    return false;
  }
  
  // Max 5 retry attempts
  if (attemptCount >= 5) {
    return false;
  }
  
  // Retry transient errors
  if (exception is NetworkException ||
      exception is ServerException ||
      exception is ServiceUnavailableException ||
      exception is RateLimitException ||
      exception is TimeoutException) {
    return true;
  }
  
  // Special case: retry 401 once after token refresh
  if (exception is UnauthorizedException && attemptCount < 2) {
    return true;
  }
  
  return false;
}
```

---

## User-Facing Error Messages

### Transient Errors
- **Network issues:** "Unable to connect. Check your internet connection."
- **Server errors:** "Service temporarily unavailable. Retrying..."
- **Rate limits:** "Too many requests. Please wait and try again."

### Permanent Errors
- **Validation:** Display specific field error (e.g., "Email address is required")
- **Not found:** "The requested resource no longer exists."
- **Permission denied:** "You don't have permission to perform this action."
- **Version conflict:** "This resource has been updated by someone else."

### Ambiguous Errors
- **Conflict:** Show conflict resolution UI with server and local states
- **Precondition failed:** "This resource has changed. Refreshing..."

---

## Monitoring & Alerting

### Metrics

**Error Rates by Classification**
- `sync.errors.transient.rate` - Should be < 5% of requests
- `sync.errors.permanent.rate` - Should be < 1% of requests
- `sync.errors.ambiguous.rate` - Should be < 0.5% of requests

**Error Counts by Type**
- `sync.errors.network` - Network connectivity issues
- `sync.errors.server` - 5xx errors
- `sync.errors.validation` - 400/422 errors
- `sync.errors.auth` - 401/403 errors
- `sync.errors.conflict` - 409/412 errors

**Retry Metrics**
- `sync.retries.by_error_type` - Retry attempts per error type
- `sync.retries.exhausted` - Operations that exhausted retries
- `sync.retries.success_after_n` - Success rate by attempt number

### Alerts

**High Error Rate**
- Trigger: Transient error rate > 10% for 5 minutes
- Action: Check backend health, network status

**Auth Failures Spike**
- Trigger: 401 errors > 100/min
- Action: Check auth service, token validation

**Conflict Rate High**
- Trigger: Conflict errors > 5% for 10 minutes
- Action: Investigate concurrent edit patterns

---

## Testing Recommendations

### Unit Tests
- Parse every error response format
- Verify exception hierarchy
- Test retry decision logic
- Validate user message generation

### Integration Tests
- Trigger each error type from mock backend
- Verify retry behavior
- Test token refresh flow
- Validate conflict resolution

### Fault Injection
- Simulate network failures
- Force 500 errors from backend
- Inject rate limits
- Trigger conflicts

---

## References

- [RFC 7231](https://tools.ietf.org/html/rfc7231) - HTTP Status Codes
- [RFC 6585](https://tools.ietf.org/html/rfc6585) - Additional HTTP Status Codes
- [API Envelope Specification](api_envelope.md)
- [Backoff Policy](backoff_policy.md)

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-11-22 | Initial specification |
