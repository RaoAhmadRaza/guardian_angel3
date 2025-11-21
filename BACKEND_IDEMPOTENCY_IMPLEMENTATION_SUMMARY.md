# Backend Idempotency Contract Implementation Summary

## Overview

Implemented comprehensive backend idempotency validation with automatic fallback to local deduplication when backend support is unavailable.

**Status**: ✅ **COMPLETE** - Task #9 of persistence/security roadmap

## What Was Built

### 1. Backend Idempotency Service
**File**: `lib/services/backend_idempotency_service.dart`

A Dio-based service that validates backend idempotency support via HTTP handshake:

```dart
final service = BackendIdempotencyService(client: dio);

// Perform handshake on app startup
final supported = await service.performHandshake(
  handshakeEndpoint: 'https://api.example.com/handshake',
);

// Check support status
print(service.supportStatus); // IdempotencySupport.supported | unsupported | unknown

// Build idempotent request
final options = service.buildIdempotentOptions(
  idempotencyKey: 'unique-operation-key-123',
);

// Verify response
final accepted = service.verifyOperationResponse(response);
```

**Key Features**:
- **Handshake endpoint**: POST with `X-Idempotency-Key: handshake-test-{timestamp}` header
- **Header detection**: Checks for `X-Idempotency-Accepted: true|1` header (case-insensitive)
- **Body field detection**: Also checks for `idempotencyAccepted: true` in JSON response body
- **Revalidation**: Recommends re-running handshake after 24 hours via `shouldRevalidate()`
- **Telemetry**: Tracks handshake duration, support status, errors, degradation events

### 2. Local Idempotency Fallback
**File**: `lib/services/local_idempotency_fallback.dart`

Hive-based local deduplication for backends without idempotency support:

```dart
final fallback = LocalIdempotencyFallback();
await fallback.init();

// Check if operation already processed
if (await fallback.isDuplicate(idempotencyKey)) {
  print('Duplicate operation - skipping');
  return;
}

// Mark operation as processed after success
await fallback.markProcessed(idempotencyKey);

// Periodic maintenance
final purged = await fallback.purgeExpired(); // Removes keys older than 24h
```

**Key Features**:
- **TTL management**: 24-hour default retention, configurable via `purgeExpired(customTtl:)`
- **Timestamp tracking**: Stores milliseconds since epoch for each key
- **Efficient purge**: Removes only expired keys, returns count
- **Concurrent-safe**: Hive handles concurrent writes/reads

### 3. Integration Tests
**File**: `test/integration/backend_idempotency_test.dart`

**19 tests, all passing** covering:

✓ Handshake detection:
- Detects backend support via `X-Idempotency-Accepted` header
- Detects support via body field `idempotencyAccepted: true`
- Marks unsupported when header missing
- Handles network errors gracefully (marks as unsupported)
- Tracks telemetry metrics

✓ Operation verification:
- Validates `X-Idempotency-Accepted: true` in responses
- Detects support degradation (backend stops supporting)
- Case-insensitive header matching

✓ Options builder:
- Adds `X-Idempotency-Key` header to requests
- Preserves existing options/headers
- Creates new Options if none provided

✓ Revalidation:
- Returns false immediately after handshake
- Returns true after 24 hours
- Uses custom revalidation intervals

✓ Header detection:
- Accepts lowercase `x-idempotency-accepted`
- Accepts value `"1"` as true
- Rejects value `"false"`

### 4. Unit Tests
**File**: `test/unit/local_idempotency_fallback_test.dart`

**14 tests, all passing** covering:

✓ Deduplication:
- `isDuplicate()` returns false for new keys
- Returns true after `markProcessed()`
- Tracks multiple keys independently

✓ TTL expiration:
- Removes keys older than TTL
- Preserves recent keys
- Exact boundary testing (24h ± 1ms)
- Custom TTL support

✓ Purge logic:
- Returns count of purged keys
- Handles empty box gracefully
- Handles multiple expired keys

✓ Performance:
- 1000 keys marked in 160ms
- 1000 keys checked in 12ms

✓ Edge cases:
- Re-marking updates timestamp
- Concurrent operations don't conflict

### 5. Documentation
**File**: `docs/BACKEND_IDEMPOTENCY_CONTRACT.md`

Comprehensive documentation covering:
- Architecture diagram (handshake → backend/fallback mode)
- Backend contract (request/response headers, handshake endpoint)
- Usage examples (initialization, sending requests, maintenance)
- Fallback mode details (limitations, best practices)
- Telemetry metrics reference
- Error handling (handshake failures, support degradation)
- Testing guidelines (unit/integration patterns)
- Migration guide (adding backend support later)
- Security considerations
- FAQ

## Test Results

### Integration Tests
```
flutter test test/integration/backend_idempotency_test.dart
00:02 +19: All tests passed!
```

### Unit Tests
```
flutter test test/unit/local_idempotency_fallback_test.dart
00:02 +14: All tests passed!
```

**Total**: 33 tests passing

## Contract Specification

### Request Header
```http
POST /api/operations
X-Idempotency-Key: <uuid or deterministic key>
```

### Response Header (Option 1)
```http
HTTP/1.1 200 OK
X-Idempotency-Accepted: true
```

### Response Body Field (Option 2)
```json
{
  "status": "success",
  "idempotencyAccepted": true
}
```

### Handshake Endpoint (Optional but Recommended)
```http
POST /api/handshake
X-Idempotency-Key: handshake-test-1234567890

Response:
HTTP/1.1 200 OK
X-Idempotency-Accepted: true
```

## Telemetry Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `backend_idempotency.supported` | Gauge | 1 if backend supports, 0 if not |
| `backend_idempotency.handshake.duration_ms` | Timer | Handshake latency in milliseconds |
| `backend_idempotency.handshake.errors` | Counter | Number of handshake failures |
| `backend_idempotency.support_degraded` | Counter | Backend stopped supporting after initial success |

## Usage Example

```dart
import 'package:guardian_angel_fyp/services/backend_idempotency_service.dart';
import 'package:guardian_angel_fyp/services/local_idempotency_fallback.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

// Initialize
final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
final idempotencyService = BackendIdempotencyService(client: dio);
final fallback = LocalIdempotencyFallback();

await fallback.init();

// Handshake on app startup
final backendSupported = await idempotencyService.performHandshake(
  handshakeEndpoint: 'https://api.example.com/handshake',
);

print('Backend idempotency: ${idempotencyService.supportStatus}');

// Send idempotent operation
Future<void> sendOperation(Map<String, dynamic> payload) async {
  final idempotencyKey = const Uuid().v4();
  
  // Check local fallback first (if backend unsupported)
  if (idempotencyService.support == IdempotencySupport.unsupported) {
    if (await fallback.isDuplicate(idempotencyKey)) {
      print('Duplicate operation (local check) - skipping');
      return;
    }
  }
  
  // Build request with idempotency header
  final options = idempotencyService.buildIdempotentOptions(
    idempotencyKey: idempotencyKey,
  );
  
  try {
    final response = await dio.post('/operations', data: payload, options: options);
    
    // Verify backend acknowledgment
    if (idempotencyService.support == IdempotencySupport.supported) {
      final accepted = idempotencyService.verifyOperationResponse(response);
      if (!accepted) {
        print('Warning: Backend did not acknowledge idempotency');
      }
    }
    
    // Mark as processed in fallback (if unsupported)
    if (idempotencyService.support == IdempotencySupport.unsupported) {
      await fallback.markProcessed(idempotencyKey);
    }
    
    print('Operation succeeded');
  } catch (e) {
    print('Operation failed: $e');
    // Do NOT mark as processed on failure
  }
}

// Periodic maintenance (run daily)
Future<void> maintenanceTask() async {
  final purged = await fallback.purgeExpired();
  print('Purged $purged expired idempotency keys');
}
```

## Architecture Decisions

### Why Handshake Instead of Feature Flag?
- **Dynamic detection**: Discovers backend capabilities at runtime
- **No config changes**: Works with any backend (legacy or modern)
- **Graceful degradation**: Automatically falls back if backend doesn't support

### Why Local Fallback?
- **Zero backend changes**: Works with non-idempotent backends immediately
- **Client-side guarantee**: Prevents duplicates even without backend support
- **TTL expiration**: Balances dedup window with storage overhead

### Why 24-Hour TTL?
- **Operation window**: Most operations complete within hours
- **Storage efficiency**: Prevents unbounded growth
- **Aligned with backend**: Common idempotency window (can be customized)

### Why Dio Instead of http?
- **Interceptor support**: Clean way to inject headers
- **Options pattern**: Preserves existing request configuration
- **Headers API**: Case-insensitive header access (`headers.value()`)

## Limitations

### Local Fallback Limitations
- **Single device**: Deduplication only works on same device/session
- **No cross-user sync**: User switching devices may cause duplicates
- **TTL window**: After 24 hours, same key can be reused

### Backend Contract Limitations
- **No versioning**: Contract is fixed (no v1/v2 negotiation)
- **Binary support**: Backend either supports or doesn't (no partial support)
- **No capability details**: Doesn't discover dedup window or retry policies

## Future Enhancements

Potential improvements (not in scope for Task #9):

1. **Cross-device sync**: Store processed keys in backend account data
2. **Capability negotiation**: Discover backend dedup window, retry policies
3. **Batch operations**: Support idempotency for bulk/batch requests
4. **Admin UI**: View/purge local fallback keys manually
5. **Analytics**: Track duplicate rates, fallback usage percentage
6. **Retry strategies**: Integrate with exponential backoff for transient failures

## Files Modified/Created

### New Files
- ✅ `lib/services/backend_idempotency_service.dart` (144 lines)
- ✅ `lib/services/local_idempotency_fallback.dart` (76 lines)
- ✅ `test/integration/backend_idempotency_test.dart` (280+ lines, 19 tests)
- ✅ `test/unit/local_idempotency_fallback_test.dart` (220+ lines, 14 tests)
- ✅ `docs/BACKEND_IDEMPOTENCY_CONTRACT.md` (350+ lines)
- ✅ `BACKEND_IDEMPOTENCY_IMPLEMENTATION_SUMMARY.md` (this file)

### Modified Files
- ✅ `pubspec.yaml` - Added `http_mock_adapter: ^0.6.1` (dev_dependencies)

### Test Files (Debug)
- `test/debug/header_test.dart` - Verified Headers API behavior
- `test/debug/handshake_debug_test.dart` - Proved interceptor functionality

## Validation

### Integration Test Coverage
- ✅ Backend support detection via headers
- ✅ Backend support detection via body fields
- ✅ Unsupported backend handling
- ✅ Network error handling
- ✅ Telemetry instrumentation
- ✅ Operation response verification
- ✅ Options builder functionality
- ✅ Revalidation TTL logic
- ✅ Case-insensitive header matching
- ✅ Multiple value formats ("true", "1")

### Unit Test Coverage
- ✅ Duplicate detection (isDuplicate)
- ✅ Processing tracking (markProcessed)
- ✅ Timestamp storage validation
- ✅ TTL expiration boundaries (24h ± 1ms)
- ✅ Purge logic (expired vs. recent)
- ✅ Custom TTL support
- ✅ Concurrent operations
- ✅ Performance stress test (1000 keys)

### Documentation Coverage
- ✅ Architecture overview with diagram
- ✅ Backend contract specification
- ✅ Usage examples (initialization, requests, maintenance)
- ✅ Fallback mode details and limitations
- ✅ Telemetry metrics reference
- ✅ Error handling patterns
- ✅ Testing guidelines
- ✅ Migration guide
- ✅ Security considerations
- ✅ FAQ

## Conclusion

**Task #9 Complete**: Backend idempotency contract validation with automatic fallback to local deduplication.

**Key Achievements**:
- 33 tests passing (19 integration + 14 unit)
- Comprehensive documentation (350+ lines)
- Zero backend changes required for fallback mode
- Automatic detection and adaptation
- Production-ready telemetry instrumentation

**Next Steps** (if continuing persistence roadmap):
- Task #10: Conflict resolution strategies (CRDT/operational transforms)
- Task #11: Audit logging for data operations
- Task #12: Performance profiling for persistence layer

**For Production Deployment**:
1. Review backend contract with backend team
2. Implement `/handshake` endpoint (optional but recommended)
3. Add `X-Idempotency-Accepted` header to operation responses
4. Set up monitoring for `backend_idempotency.supported` metric
5. Configure alerts for `backend_idempotency.support_degraded`
6. Schedule daily `fallback.purgeExpired()` maintenance task
7. Document idempotency window in API specification
