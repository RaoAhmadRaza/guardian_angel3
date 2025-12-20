# API Envelope Specification

**Version:** 1.0.0  
**Last Updated:** November 22, 2025

---

## Overview

This document defines the standardized request and response envelope format for all Guardian Angel sync operations. The envelope provides metadata for tracing, idempotency, and debugging while keeping payloads flexible and operation-specific.

---

## Request Envelope

### Structure

```json
{
  "meta": {
    "trace_id": "550e8400-e29b-41d4-a716-446655440000",
    "timestamp": "2025-11-22T12:00:00.000Z",
    "txn_token": "txn-abc123def456"
  },
  "payload": {
    // Operation-specific payload
  }
}
```

### Required Fields

#### `meta` (object, required)
Top-level metadata container for all requests.

#### `meta.trace_id` (string, required)
- **Format:** UUID v4 (canonical 8-4-4-4-12 format)
- **Purpose:** End-to-end request tracing across client and server
- **Generation:** Client-side, unique per request
- **Example:** `"550e8400-e29b-41d4-a716-446655440000"`

#### `meta.timestamp` (string, required)
- **Format:** ISO 8601 with timezone (RFC 3339)
- **Purpose:** Client-side timestamp for operation creation
- **Timezone:** Always UTC (Z suffix)
- **Example:** `"2025-11-22T12:00:00.000Z"`
- **Validation:** Server may reject if timestamp > 5 minutes in future or past

#### `meta.txn_token` (string, optional)
- **Format:** Alphanumeric string (e.g., `txn-{ulid}` or `txn-{uuid}`)
- **Purpose:** Optimistic update transaction identifier
- **Usage:** Links server response to local pending state change
- **Example:** `"txn-01ARZ3NDEKTSV4RRFFQ69G5FAV"`
- **When Required:** Only for operations that trigger optimistic UI updates

#### `payload` (object, required)
- **Type:** JSON object (structure varies by operation)
- **Purpose:** Operation-specific data (e.g., CreateUserRequest, UpdateRoomRequest)
- **Validation:** Schema enforced per operation type

---

## Response Envelope

### Success Response

```json
{
  "meta": {
    "trace_id": "550e8400-e29b-41d4-a716-446655440000",
    "timestamp": "2025-11-22T12:00:00.123Z",
    "txn_token": "txn-abc123def456"
  },
  "data": {
    // Operation-specific response data
  }
}
```

### Error Response

```json
{
  "meta": {
    "trace_id": "550e8400-e29b-41d4-a716-446655440000",
    "timestamp": "2025-11-22T12:00:00.123Z",
    "txn_token": "txn-abc123def456"
  },
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

### Required Fields

#### `meta` (object, required)
Top-level metadata container for all responses.

#### `meta.trace_id` (string, required)
- **Value:** Must match request `trace_id`
- **Purpose:** Correlate request and response
- **Validation:** Client should verify match

#### `meta.timestamp` (string, required)
- **Format:** ISO 8601 with timezone (RFC 3339)
- **Purpose:** Server-side timestamp for response generation
- **Timezone:** Always UTC (Z suffix)
- **Example:** `"2025-11-22T12:00:00.123Z"`

#### `meta.txn_token` (string, optional)
- **Value:** Echo from request if present
- **Purpose:** Client uses to resolve optimistic updates
- **Validation:** Must match request if provided

#### Success: `data` (object, required for 2xx responses)
- **Type:** JSON object (structure varies by operation)
- **Purpose:** Operation-specific response data
- **Mutually Exclusive:** Only one of `data` or `error` present

#### Error: `error` (object, required for 4xx/5xx responses)
- **Type:** Structured error information
- **Purpose:** Machine-readable error details
- **Mutually Exclusive:** Only one of `data` or `error` present

### Error Object Structure

#### `error.code` (string, required)
- **Format:** UPPER_SNAKE_CASE enum value
- **Purpose:** Machine-readable error type
- **Examples:**
  - `VALIDATION_ERROR` - Input validation failed
  - `RESOURCE_NOT_FOUND` - Requested resource doesn't exist
  - `CONFLICT` - State conflict (409)
  - `UNAUTHORIZED` - Auth failure (401)
  - `FORBIDDEN` - Permission denied (403)
  - `RATE_LIMITED` - Too many requests (429)
  - `INTERNAL_ERROR` - Server-side error (500)

#### `error.message` (string, required)
- **Format:** Human-readable English sentence
- **Purpose:** User-displayable error message
- **Length:** 10-200 characters recommended
- **Example:** `"Email address is required"`

#### `error.details` (object, optional)
- **Type:** Key-value pairs with error context
- **Purpose:** Additional debugging information
- **Examples:**
  - Field validation: `{"field": "email", "constraint": "required"}`
  - Conflict: `{"resource_version": 3, "expected_version": 2}`
  - Rate limit: `{"limit": 100, "window": "1h", "reset_at": "2025-11-22T13:00:00Z"}`

---

## HTTP Headers

### Request Headers

#### Required Headers

**Authorization**
```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```
- **Format:** `Bearer <jwt_token>`
- **Purpose:** User authentication
- **Validation:** Server verifies signature and expiry
- **Error:** 401 if missing or invalid

**Idempotency-Key**
```
Idempotency-Key: 550e8400-e29b-41d4-a716-446655440000
```
- **Format:** UUID v4 (canonical format)
- **Purpose:** Request deduplication
- **Generation:** Client-side, unique per operation (not per retry)
- **Validation:** Server caches for 24 hours
- **Error:** 400 if malformed

**Content-Type**
```
Content-Type: application/json; charset=utf-8
```
- **Value:** Always `application/json; charset=utf-8`
- **Purpose:** Indicates JSON request body
- **Validation:** Server rejects non-JSON with 415

**X-App-Version**
```
X-App-Version: 1.2.3
```
- **Format:** Semantic versioning (major.minor.patch)
- **Purpose:** Client version for compatibility checks
- **Validation:** Server may reject unsupported versions
- **Error:** 426 (Upgrade Required) if too old

**X-Device-Id**
```
X-Device-Id: 7c9e6679-7425-40de-944b-e07fc1f90ae7
```
- **Format:** UUID v4 (stable per device)
- **Purpose:** Device identification for analytics and debugging
- **Generation:** Created once per device, stored persistently
- **Privacy:** Not linked to user identity server-side

**Trace-Id**
```
Trace-Id: 550e8400-e29b-41d4-a716-446655440000
```
- **Format:** UUID v4 (matches `meta.trace_id`)
- **Purpose:** HTTP-level tracing (duplicates envelope for middleware)
- **Validation:** Should match request body `meta.trace_id`

#### Optional Headers

**If-Match**
```
If-Match: "33a64df551425fcc55e4d42a148795d9f25f89d4"
```
- **Format:** ETag value (quoted string)
- **Purpose:** Conditional update (optimistic locking)
- **Usage:** Only for update operations
- **Error:** 412 (Precondition Failed) if mismatch

**User-Agent**
```
User-Agent: GuardianAngel/1.2.3 (iOS 17.0; iPhone 15 Pro)
```
- **Format:** `AppName/Version (OS Version; Device Model)`
- **Purpose:** Client environment debugging
- **Privacy:** No personal information

### Response Headers

#### Standard Headers

**Content-Type**
```
Content-Type: application/json; charset=utf-8
```
- **Value:** Always `application/json; charset=utf-8`
- **Purpose:** Indicates JSON response body

**X-Request-Id**
```
X-Request-Id: req_2TgFzK9bC8N3vP7mL1qR
```
- **Format:** Server-generated unique ID
- **Purpose:** Server-side request tracking
- **Usage:** Include in support tickets for debugging

**X-Rate-Limit-Limit**
```
X-Rate-Limit-Limit: 100
```
- **Format:** Integer (requests per window)
- **Purpose:** Inform client of rate limit
- **Presence:** Always (even if not rate limited)

**X-Rate-Limit-Remaining**
```
X-Rate-Limit-Remaining: 87
```
- **Format:** Integer (requests remaining in window)
- **Purpose:** Client can throttle proactively
- **Presence:** Always (even if not rate limited)

**X-Rate-Limit-Reset**
```
X-Rate-Limit-Reset: 1732281600
```
- **Format:** Unix timestamp (seconds since epoch)
- **Purpose:** When limit resets
- **Presence:** Always (even if not rate limited)

#### Conditional Headers

**Retry-After**
```
Retry-After: 120
```
- **Format:** Integer (seconds) or HTTP-date
- **Purpose:** Instruct client when to retry
- **Presence:** 429 (rate limit), 503 (service unavailable), 504 (timeout)
- **Client Action:** MUST respect this delay (override backoff)

**ETag**
```
ETag: "33a64df551425fcc55e4d42a148795d9f25f89d4"
```
- **Format:** Quoted string (usually hash of resource state)
- **Purpose:** Resource versioning for conditional updates
- **Presence:** GET and PUT responses
- **Usage:** Client includes in `If-Match` for updates

**Location**
```
Location: /api/v1/users/123e4567-e89b-12d3-a456-426614174000
```
- **Format:** Absolute or relative URI
- **Purpose:** Created resource location
- **Presence:** 201 (Created) responses

---

## Operation Examples

### Example 1: Create User (Success)

**Request**
```http
POST /api/v1/users HTTP/1.1
Host: api.guardianangel.com
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Idempotency-Key: 550e8400-e29b-41d4-a716-446655440000
Content-Type: application/json; charset=utf-8
X-App-Version: 1.2.3
X-Device-Id: 7c9e6679-7425-40de-944b-e07fc1f90ae7
Trace-Id: 550e8400-e29b-41d4-a716-446655440000

{
  "meta": {
    "trace_id": "550e8400-e29b-41d4-a716-446655440000",
    "timestamp": "2025-11-22T12:00:00.000Z",
    "txn_token": "txn-01ARZ3NDEKTSV4RRFFQ69G5FAV"
  },
  "payload": {
    "email": "john.doe@example.com",
    "display_name": "John Doe",
    "birth_date": "1990-05-15"
  }
}
```

**Response (201 Created)**
```http
HTTP/1.1 201 Created
Content-Type: application/json; charset=utf-8
X-Request-Id: req_2TgFzK9bC8N3vP7mL1qR
X-Rate-Limit-Limit: 100
X-Rate-Limit-Remaining: 99
X-Rate-Limit-Reset: 1732281600
Location: /api/v1/users/123e4567-e89b-12d3-a456-426614174000
ETag: "33a64df551425fcc55e4d42a148795d9f25f89d4"

{
  "meta": {
    "trace_id": "550e8400-e29b-41d4-a716-446655440000",
    "timestamp": "2025-11-22T12:00:00.123Z",
    "txn_token": "txn-01ARZ3NDEKTSV4RRFFQ69G5FAV"
  },
  "data": {
    "user_id": "123e4567-e89b-12d3-a456-426614174000",
    "email": "john.doe@example.com",
    "display_name": "John Doe",
    "birth_date": "1990-05-15",
    "created_at": "2025-11-22T12:00:00.123Z",
    "version": 1
  }
}
```

### Example 2: Update Room (Conflict)

**Request**
```http
PUT /api/v1/rooms/987fcdeb-51a2-43f8-b6d5-3a2e1f4b8c9a HTTP/1.1
Host: api.guardianangel.com
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Idempotency-Key: 7c9e6679-7425-40de-944b-e07fc1f90ae7
Content-Type: application/json; charset=utf-8
X-App-Version: 1.2.3
X-Device-Id: 7c9e6679-7425-40de-944b-e07fc1f90ae7
Trace-Id: 7c9e6679-7425-40de-944b-e07fc1f90ae7
If-Match: "abc123"

{
  "meta": {
    "trace_id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
    "timestamp": "2025-11-22T12:05:00.000Z",
    "txn_token": "txn-02BSA4OELUTFW5SSGGR7AH6GBW"
  },
  "payload": {
    "name": "Living Room (Updated)",
    "version": 2
  }
}
```

**Response (409 Conflict)**
```http
HTTP/1.1 409 Conflict
Content-Type: application/json; charset=utf-8
X-Request-Id: req_3UhGaL0cD9O4wQ8nM2rS
X-Rate-Limit-Limit: 100
X-Rate-Limit-Remaining: 98
X-Rate-Limit-Reset: 1732281600

{
  "meta": {
    "trace_id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
    "timestamp": "2025-11-22T12:05:00.234Z",
    "txn_token": "txn-02BSA4OELUTFW5SSGGR7AH6GBW"
  },
  "error": {
    "code": "CONFLICT",
    "message": "Resource has been modified by another user",
    "details": {
      "resource_version": 3,
      "expected_version": 2,
      "last_modified_by": "user_456",
      "last_modified_at": "2025-11-22T12:04:30.000Z"
    }
  }
}
```

### Example 3: Rate Limited

**Request**
```http
POST /api/v1/devices HTTP/1.1
Host: api.guardianangel.com
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Idempotency-Key: aabbccdd-1122-3344-5566-778899aabbcc
Content-Type: application/json; charset=utf-8
X-App-Version: 1.2.3
X-Device-Id: 7c9e6679-7425-40de-944b-e07fc1f90ae7
Trace-Id: aabbccdd-1122-3344-5566-778899aabbcc

{
  "meta": {
    "trace_id": "aabbccdd-1122-3344-5566-778899aabbcc",
    "timestamp": "2025-11-22T12:10:00.000Z"
  },
  "payload": {
    "device_type": "sensor",
    "model": "TempSensor-v2"
  }
}
```

**Response (429 Too Many Requests)**
```http
HTTP/1.1 429 Too Many Requests
Content-Type: application/json; charset=utf-8
X-Request-Id: req_5XjIcN2eE0P6xR9oO3tU
X-Rate-Limit-Limit: 100
X-Rate-Limit-Remaining: 0
X-Rate-Limit-Reset: 1732281660
Retry-After: 60

{
  "meta": {
    "trace_id": "aabbccdd-1122-3344-5566-778899aabbcc",
    "timestamp": "2025-11-22T12:10:00.567Z"
  },
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

---

## Validation Rules

### Request Validation

**Envelope Structure**
- `meta` field MUST be present
- `payload` field MUST be present (can be empty object for some operations)
- `meta.trace_id` MUST be valid UUID v4
- `meta.timestamp` MUST be valid ISO 8601 with timezone
- `meta.timestamp` MUST NOT be > 5 minutes in future or past
- `meta.txn_token` MUST be alphanumeric if present

**Header Validation**
- `Authorization` header MUST be present and valid JWT
- `Idempotency-Key` MUST be valid UUID v4
- `Content-Type` MUST be `application/json`
- `X-App-Version` MUST match semantic versioning format
- `X-Device-Id` MUST be valid UUID v4
- `Trace-Id` SHOULD match `meta.trace_id` (warning if mismatch)

**Payload Validation**
- Schema validated per operation type (e.g., CreateUserRequest)
- All required fields MUST be present
- Field types MUST match schema (string, int, bool, etc.)
- Enum values MUST be from allowed set
- String lengths MUST be within min/max bounds
- Numeric values MUST be within min/max bounds

### Response Validation

**Client-Side Checks**
- Response `meta.trace_id` MUST match request `trace_id`
- Response `meta.txn_token` MUST match request `txn_token` (if present)
- Exactly one of `data` or `error` MUST be present
- If HTTP 2xx, `data` field MUST be present
- If HTTP 4xx/5xx, `error` field MUST be present
- `error.code` MUST be valid error code enum
- `error.message` MUST be non-empty string

---

## Backward Compatibility

### Version Strategy

**Current Version:** v1 (represented in URL path `/api/v1/...`)

**Breaking Changes:**
- New required fields in request envelope
- Removal of fields from response envelope
- Change in field data types
- Change in error code semantics

**Non-Breaking Changes:**
- New optional fields in request envelope
- New fields in response envelope (clients ignore unknown fields)
- New error codes (clients treat as INTERNAL_ERROR)
- New HTTP headers

**Migration Path:**
1. Server supports both v1 and v2 simultaneously
2. Clients upgrade at their own pace
3. v1 deprecated after 6 months, removed after 12 months
4. `X-App-Version` header used to track adoption

---

## Security Considerations

### Authentication
- JWT token in `Authorization` header MUST be validated
- Token signature, expiry, and issuer MUST be verified
- Expired tokens result in 401 Unauthorized
- Invalid signatures result in 401 Unauthorized

### Idempotency Key Security
- Idempotency keys scoped per user (not global)
- Prevents replay attacks across users
- Keys expire after 24 hours
- No personally identifiable information in keys

### Trace ID Privacy
- Trace IDs are random UUIDs (no information leakage)
- Safe to include in logs and telemetry
- Not linked to user identity

### Request Tampering
- HTTPS/TLS 1.3 required for all requests
- Payload integrity protected by TLS
- Optional request signing for high-security operations (future)

### Rate Limiting
- Per-user rate limits prevent abuse
- `Retry-After` prevents amplification attacks
- Exponential backoff required on client side

---

## Performance Optimization

### Request Size
- Keep payloads under 1MB (soft limit)
- Use pagination for large result sets
- Consider compression for large payloads (gzip)

### Response Caching
- Use ETags for conditional requests (304 Not Modified)
- Cache control headers for read-only operations
- Respect cache directives

### Connection Reuse
- HTTP/2 for multiplexing
- Keep-alive connections
- Connection pooling on client

### Batch Operations
- Future: Support batch envelope with multiple operations
- Reduces round-trips for bulk updates
- Maintains idempotency per operation

---

## Testing Recommendations

### Unit Tests
- Validate envelope serialization/deserialization
- Test all error code mappings
- Verify header parsing
- Check timestamp validation

### Integration Tests
- End-to-end request/response flow
- Idempotency key deduplication
- Trace ID propagation
- Error handling scenarios

### Test Vectors
See [test_vectors/](test_vectors/) directory for JSON fixtures:
- `pending_op_valid.json` - Valid operation example
- `pending_op_retry_after.json` - Rate limit scenario
- `pending_op_corrupt.json` - Malformed request

---

## References

- [RFC 7231](https://tools.ietf.org/html/rfc7231) - HTTP/1.1 Semantics
- [RFC 3339](https://tools.ietf.org/html/rfc3339) - Date and Time on the Internet
- [RFC 4122](https://tools.ietf.org/html/rfc4122) - UUID Specification
- [RFC 6585](https://tools.ietf.org/html/rfc6585) - Additional HTTP Status Codes
- [Semantic Versioning](https://semver.org/) - Version Format

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-11-22 | Initial specification |
