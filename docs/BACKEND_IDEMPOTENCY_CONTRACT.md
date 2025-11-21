# Backend Idempotency Contract & Validation

## Overview

The Guardian Angel persistence system validates backend idempotency support via HTTP handshake and falls back to local deduplication if the backend does not support it.

**Goal**: Ensure operations are never duplicated, whether the backend enforces idempotency or not.

## Architecture

```
┌────────────────────────────────────────────────────┐
│  1. Perform Handshake (on app startup)            │
│     POST /handshake                                 │
│     Header: X-Idempotency-Key: handshake-test-xxx  │
│                                                     │
│     ┌─────────────────────────────────┐            │
│     │  Response includes:             │            │
│     │  X-Idempotency-Accepted: true   │            │
│     └─────────────────────────────────┘            │
│               ↓ Yes                   ↓ No         │
│        Backend mode           Fallback mode        │
└────────────────────────────────────────────────────┘
          │                              │
          ↓                              ↓
┌──────────────────────┐    ┌──────────────────────────┐
│  Backend Enforced    │    │  Local Deduplication     │
│  Idempotency         │    │  (Hive Box)              │
│                      │    │                          │
│  - Send X-Idempotency│    │  - Check local cache     │
│    -Key with every   │    │    before sending        │
│    operation         │    │  - Mark processed after  │
│  - Backend rejects   │    │    200 response          │
│    duplicates        │    │  - TTL: 24 hours         │
└──────────────────────┘    └──────────────────────────┘
```

## Backend Contract

### Request Headers

All operations should include:

```http
POST /api/operations
Content-Type: application/json
X-Idempotency-Key: <uuid or timestamp-based key>
```

The `X-Idempotency-Key` must be:
- Unique per operation
- Deterministic (same operation → same key)
- Format: UUID v4 or `{timestamp}-{operationId}`

### Response Headers

If backend supports idempotency:

```http
HTTP/1.1 200 OK
X-Idempotency-Accepted: true
Content-Type: application/json

{
  "status": "success",
  "operationId": "..."
}
```

Alternative (body field):

```json
{
  "status": "success",
  "idempotencyAccepted": true,
  "operationId": "..."
}
```

### Handshake Endpoint

**Optional but recommended**: Provide a `/handshake` endpoint for capability detection:

```http
POST /api/handshake
X-Idempotency-Key: handshake-test-1234567890

Response:
HTTP/1.1 200 OK
X-Idempotency-Accepted: true
{
  "capabilities": {
    "idempotency": true,
    "deduplication_window_seconds": 86400
  }
}
```

If no dedicated handshake endpoint exists, the client will attempt a real operation and check for the header.

## Usage

### 1. Initialize Service

```dart
import 'package:guardian_angel_fyp/services/backend_idempotency_service.dart';
import 'package:guardian_angel_fyp/services/local_idempotency_fallback.dart';
import 'package:dio/dio.dart';

final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
final idempotencyService = BackendIdempotencyService(client: dio);
final fallback = LocalIdempotencyFallback();

// Perform handshake on app startup
await fallback.init();
final backendSupported = await idempotencyService.performHandshake(
  handshakeEndpoint: 'https://api.example.com/handshake',
);

print('Backend idempotency: ${idempotencyService.supportStatus}');
```

### 2. Send Idempotent Request

```dart
import 'package:uuid/uuid.dart';

Future<void> sendOperation(Map<String, dynamic> payload) async {
  final idempotencyKey = const Uuid().v4();
  
  // Check local fallback first (if backend unsupported)
  if (idempotencyService.support == IdempotencySupport.unsupported) {
    if (await fallback.isDuplicate(idempotencyKey)) {
      print('Duplicate operation (local check)');
      return; // Skip
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
    
    // Mark as processed in fallback
    if (idempotencyService.support == IdempotencySupport.unsupported) {
      await fallback.markProcessed(idempotencyKey);
    }
    
    print('Operation succeeded');
  } catch (e) {
    print('Operation failed: $e');
    // Do NOT mark as processed on failure
  }
}
```

### 3. Periodic Maintenance

```dart
// Run daily to purge expired local dedup keys
Future<void> maintenanceTask() async {
  final purged = await fallback.purgeExpired();
  print('Purged $purged expired idempotency keys');
}
```

## Fallback Mode Details

### Local Deduplication

When backend doesn't support idempotency (`IdempotencySupport.unsupported`):

1. **Before sending**: Check `LocalIdempotencyFallback.isDuplicate(key)`
   - If true → skip operation (already processed)
   - If false → proceed with request

2. **After 200 response**: Call `fallback.markProcessed(key)`
   - Stores key with timestamp in Hive box `local_idempotency_fallback`

3. **TTL enforcement**: Keys older than 24 hours are purged automatically

### Limitations

- **Local only**: Deduplication works within single device/user session
- **No cross-device sync**: If user switches devices, duplicate may occur
- **TTL window**: After 24 hours, same key can be reused

### Best Practices

- Use deterministic keys: `{userId}-{operationId}-{timestamp}`
- Keep TTL aligned with backend retention (if backend later adds support)
- Log when fallback is used for monitoring

## Telemetry Metrics

The system tracks:

| Metric | Type | Description |
|--------|------|-------------|
| `backend_idempotency.supported` | Gauge | 1 if supported, 0 if not |
| `backend_idempotency.handshake.duration_ms` | Timer | Handshake latency |
| `backend_idempotency.handshake.errors` | Counter | Handshake failures |
| `backend_idempotency.support_degraded` | Counter | Backend stopped supporting after initial success |

Access via `TelemetryService.I.snapshot()`.

## Error Handling

### Handshake Failures

```dart
try {
  final supported = await idempotencyService.performHandshake(
    handshakeEndpoint: 'https://api.example.com/handshake',
    timeout: const Duration(seconds: 5),
  );
  if (!supported) {
    print('Backend does not support idempotency - using local fallback');
  }
} catch (e) {
  print('Handshake failed: $e');
  // Service automatically marks as unsupported on error
}
```

### Support Degradation

If backend initially supports idempotency but later stops:

```dart
final accepted = idempotencyService.verifyOperationResponse(response);
if (!accepted && idempotencyService.support == IdempotencySupport.supported) {
  // Backend degraded - consider re-running handshake or switching to fallback
  TelemetryService.I.increment('backend_idempotency.support_degraded');
}
```

## Testing

### Unit Tests

```bash
flutter test test/integration/backend_idempotency_test.dart
```

Tests cover:
- ✓ Header detection (X-Idempotency-Accepted: true)
- ✓ Body field detection (idempotencyAccepted: true)
- ✓ Network error handling
- ✓ Telemetry instrumentation
- ✓ Options builder
- ✓ Revalidation logic

### Integration Testing

Mock backend responses:

```dart
// Mock supported backend
mockInterceptor.onPost('/handshake', (req) {
  return Response(
    requestOptions: req,
    statusCode: 200,
    headers: Headers.fromMap({'X-Idempotency-Accepted': ['true']}),
  );
});

// Mock unsupported backend
mockInterceptor.onPost('/handshake', (req) {
  return Response(
    requestOptions: req,
    statusCode: 200,
    // No X-Idempotency-Accepted header
  );
});
```

## Migration from Non-Idempotent Backend

If backend adds idempotency support later:

1. **Deploy backend changes** with `X-Idempotency-Accepted` header
2. **Update handshake endpoint** (optional)
3. **Client auto-detects** on next handshake (24-hour revalidation)
4. **Fallback automatically disabled** when backend support detected

No client code changes needed - system adapts automatically.

## Security Considerations

- **Key predictability**: Use UUIDs or cryptographically strong keys
- **Key reuse attack**: Ensure keys are operation-specific
- **TTL tuning**: Balance between dedup window and storage overhead
- **Audit logging**: Track when fallback mode is used (compliance)

## FAQ

### Q: What if handshake endpoint doesn't exist?

**A**: The service will mark backend as unsupported and use local fallback. No errors thrown.

### Q: Can I force local fallback even if backend supports it?

**A**: Yes, set `IdempotencySupport.unsupported` manually:

```dart
idempotencyService._support = IdempotencySupport.unsupported;
```

### Q: How do I re-run handshake?

**A**: Call `performHandshake()` again. The service tracks last handshake time and recommends revalidation after 24 hours:

```dart
if (idempotencyService.shouldRevalidate()) {
  await idempotencyService.performHandshake(...);
}
```

### Q: What happens if local fallback box is corrupted?

**A**: Hive will return empty box. Worst case: duplicate operations until box is rebuilt. Monitor `backend_idempotency.fallback.errors`.

## Files

| File | Purpose |
|------|---------|
| `lib/services/backend_idempotency_service.dart` | Backend capability detection & header validation |
| `lib/services/local_idempotency_fallback.dart` | Local Hive-based deduplication |
| `test/integration/backend_idempotency_test.dart` | Integration tests (19 tests) |

## Next Steps

1. ✅ Implement handshake endpoint in backend (recommended)
2. ✅ Add `X-Idempotency-Accepted` header to all operation responses
3. ✅ Document idempotency window (e.g., 24 hours) in API spec
4. ✅ Monitor `backend_idempotency.supported` metric in production
5. ✅ Set up alerts for `backend_idempotency.support_degraded`
