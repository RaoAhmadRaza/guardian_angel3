# Idempotency Policy Specification

**Version:** 1.0.0  
**Last Updated:** November 22, 2025

---

## Overview

This document defines Guardian Angel's idempotency strategy for sync operations. The policy ensures that retrying operations produces the same side-effect as the original request, preventing duplicate data, double-charges, and inconsistent state.

---

## Core Principles

### Idempotency Definition

**Idempotent Operation:** An operation that produces the same result when executed multiple times

**Mathematical Property:**
```
f(x) = f(f(x)) = f(f(f(x))) = ...
```

**Example (Idempotent):**
```
SET user.email = "john@example.com"
// Executing 5 times → email is "john@example.com"
```

**Example (Non-Idempotent):**
```
INCREMENT user.balance BY 100
// Executing 5 times → balance increases by 500
```

### Why Idempotency Matters

**Problem Scenarios:**
1. **Network Timeout:** Client doesn't receive response, retries → duplicate operation
2. **App Crash:** Operation sent but app crashes before marking complete → retry on restart
3. **Race Condition:** Multiple devices send same operation simultaneously → duplicates

**Without Idempotency:**
- User charged twice for same purchase
- Duplicate room created
- Device registered multiple times
- Health data recorded twice

**With Idempotency:**
- Retries produce same result as original
- No duplicates even with crashes/timeouts
- Safe to retry any operation

---

## Idempotency Key Strategy

### Key Generation

**Format:** UUID v4 (Universally Unique Identifier)

**Example:** `550e8400-e29b-41d4-a716-446655440000`

**Generation (Dart):**
```dart
import 'package:uuid/uuid.dart';

final uuid = Uuid();
final idempotencyKey = uuid.v4(); // e.g., "550e8400-e29b-41d4-a716-446655440000"
```

**Properties:**
- **Uniqueness:** Collision probability negligible (1 in 2^122)
- **Randomness:** No sequential patterns
- **Standard:** RFC 4122 compliant
- **Portable:** Works across platforms

### Key Lifecycle

**Creation:** When operation is first enqueued
```dart
final operation = PendingOp(
  id: uuid.v4(), // Operation ID
  idempotencyKey: uuid.v4(), // SEPARATE idempotency key
  type: OperationType.createUser,
  payload: {...},
  createdAt: DateTime.now(),
);

await pendingOpsBox.add(operation);
```

**Persistence:** Stored with operation in Hive
```dart
@HiveType(typeId: 30)
class PendingOp {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String idempotencyKey; // Persisted with operation
  
  @HiveField(2)
  final OperationType type;
  
  // ... other fields
}
```

**Transmission:** Sent in HTTP header on every retry
```http
POST /api/v1/users HTTP/1.1
Idempotency-Key: 550e8400-e29b-41d4-a716-446655440000
Authorization: Bearer ...
Content-Type: application/json

{
  "meta": {...},
  "payload": {...}
}
```

**Reuse:** Same key used for all retries of the same operation
```dart
// Initial attempt (attempt 1)
await apiClient.post('/users', payload, idempotencyKey: operation.idempotencyKey);

// Retry after failure (attempt 2)
await apiClient.post('/users', payload, idempotencyKey: operation.idempotencyKey); // SAME KEY

// Retry after failure (attempt 3)
await apiClient.post('/users', payload, idempotencyKey: operation.idempotencyKey); // SAME KEY
```

**Deletion:** Removed when operation completes or permanently fails
```dart
// Success: delete operation and key
await pendingOpsBox.delete(operation.id);

// Permanent failure: move to failed_ops (keeps key for debugging)
await failedOpsBox.add(FailedOp.fromPendingOp(operation));
await pendingOpsBox.delete(operation.id);
```

---

## Server-Side Requirements

### Idempotency Store

**Storage:** In-memory cache (Redis, Memcached) or database table

**Schema:**
```sql
CREATE TABLE idempotency_keys (
  key UUID PRIMARY KEY,
  user_id UUID NOT NULL,
  operation_type VARCHAR(50) NOT NULL,
  status VARCHAR(20) NOT NULL, -- 'processing', 'completed', 'failed'
  response_body JSONB,
  created_at TIMESTAMP NOT NULL,
  completed_at TIMESTAMP,
  ttl TIMESTAMP NOT NULL
);

CREATE INDEX idx_idempotency_keys_user_id ON idempotency_keys(user_id);
CREATE INDEX idx_idempotency_keys_ttl ON idempotency_keys(ttl);
```

**Key-Value Store (Redis):**
```redis
SET idempotency:550e8400-e29b-41d4-a716-446655440000 '{"status": "completed", "response": {...}}' EX 86400
```

### Request Processing

**Idempotent Request Flow:**

```
1. Receive request with Idempotency-Key header
2. Check idempotency store for key
3. If key exists:
   a. If status = 'processing': Return 409 Conflict (concurrent request)
   b. If status = 'completed': Return cached response (200 OK)
   c. If status = 'failed': Return cached error (4xx/5xx)
4. If key not found:
   a. Insert key with status = 'processing'
   b. Execute operation
   c. If success: Update status = 'completed', cache response
   d. If failure: Update status = 'failed', cache error
   e. Return response
```

**Pseudocode:**
```python
def handle_idempotent_request(idempotency_key, user_id, operation):
    # Check cache
    cached = idempotency_store.get(idempotency_key)
    
    if cached is not None:
        if cached['status'] == 'processing':
            # Concurrent request with same key
            return Response(409, {
                "error": {
                    "code": "CONCURRENT_REQUEST",
                    "message": "Request with this idempotency key is already processing"
                }
            })
        elif cached['status'] == 'completed':
            # Return cached success response
            return Response(cached['http_status'], cached['response_body'])
        elif cached['status'] == 'failed':
            # Return cached error response
            return Response(cached['http_status'], cached['error_body'])
    
    # New request: insert processing entry
    idempotency_store.set(idempotency_key, {
        'user_id': user_id,
        'operation_type': operation.type,
        'status': 'processing',
        'created_at': now(),
        'ttl': now() + 24_hours
    })
    
    try:
        # Execute operation
        result = execute_operation(operation)
        
        # Cache success response
        idempotency_store.update(idempotency_key, {
            'status': 'completed',
            'response_body': result,
            'http_status': 201,
            'completed_at': now()
        })
        
        return Response(201, result)
    except Exception as e:
        # Cache error response
        idempotency_store.update(idempotency_key, {
            'status': 'failed',
            'error_body': serialize_error(e),
            'http_status': e.http_status,
            'completed_at': now()
        })
        
        raise
```

### TTL (Time To Live)

**Default:** 24 hours

**Rationale:**
- Covers most retry scenarios (app crashes, network outages)
- Prevents unbounded cache growth
- Balances safety with storage costs

**Cleanup:**
```sql
-- Periodic cleanup job (run every hour)
DELETE FROM idempotency_keys WHERE ttl < NOW();
```

**Trade-offs:**
- **Shorter TTL (e.g., 1 hour):** Less storage, risk of duplicate if retry delayed
- **Longer TTL (e.g., 7 days):** More storage, better safety for delayed retries

---

## Client-Side Implementation

### Key Management

**Service Interface:**
```dart
class IdempotencyService {
  final _uuid = Uuid();
  
  /// Generate new idempotency key
  String generate() {
    return _uuid.v4();
  }
  
  /// Check if operation already succeeded (local tracking)
  Future<bool> hasSucceeded(String idempotencyKey) async {
    final box = await Hive.openBox<String>('idempotency_success');
    return box.containsKey(idempotencyKey);
  }
  
  /// Mark operation as succeeded locally
  Future<void> markSuccess(String idempotencyKey) async {
    final box = await Hive.openBox<String>('idempotency_success');
    await box.put(idempotencyKey, DateTime.now().toIso8601String());
    
    // Cleanup old entries (older than 24 hours)
    final cutoff = DateTime.now().subtract(Duration(hours: 24));
    final oldKeys = box.keys.where((key) {
      final timestamp = DateTime.parse(box.get(key)!);
      return timestamp.isBefore(cutoff);
    }).toList();
    
    await box.deleteAll(oldKeys);
  }
}
```

**Usage in Queue Processor:**
```dart
Future<void> processOperation(PendingOp operation) async {
  // Check if already succeeded locally
  if (await idempotencyService.hasSucceeded(operation.idempotencyKey)) {
    // Already processed successfully, skip
    await pendingOpsBox.delete(operation.id);
    return;
  }
  
  try {
    // Send request with idempotency key
    final response = await apiClient.post(
      operation.endpoint,
      operation.payload,
      headers: {
        'Idempotency-Key': operation.idempotencyKey,
      },
    );
    
    // Success: mark locally and delete from queue
    await idempotencyService.markSuccess(operation.idempotencyKey);
    await pendingOpsBox.delete(operation.id);
    
  } on ConflictException catch (e) {
    if (e.errorCode == 'CONCURRENT_REQUEST') {
      // Another request with same key is processing, retry later
      throw TransientException('Concurrent request, will retry');
    }
    rethrow;
  }
}
```

---

## Edge Cases & Handling

### Case 1: Concurrent Requests (Same Key)

**Scenario:** Two devices send same operation simultaneously

**Server Response:**
```http
HTTP/1.1 409 Conflict
Content-Type: application/json

{
  "error": {
    "code": "CONCURRENT_REQUEST",
    "message": "Request with this idempotency key is already processing"
  }
}
```

**Client Action:**
```dart
if (exception is ConflictException && exception.errorCode == 'CONCURRENT_REQUEST') {
  // Wait and retry (another device is processing)
  await Future.delayed(Duration(seconds: 2));
  return retry();
}
```

### Case 2: Partial Success

**Scenario:** Operation partially completes (e.g., user created but email not sent)

**Server Behavior:**
- If user creation succeeded: Mark idempotency key as 'completed', return success
- Retry will return cached success response
- Email send is handled by separate async job (not part of idempotent request)

**Rationale:** Idempotency applies to primary side-effect, not auxiliary actions

### Case 3: Retry After 24 Hours

**Scenario:** Client retries after idempotency key expired server-side

**Server Behavior:**
- Key not found in cache (TTL expired)
- Execute operation again
- May result in duplicate if original succeeded

**Mitigation:**
- Client tracks success locally (24h cache)
- Don't retry if local success record exists

```dart
if (await idempotencyService.hasSucceeded(operation.idempotencyKey)) {
  // Don't retry even if server cache expired
  return;
}
```

### Case 4: Operation Modified Before Retry

**Scenario:** User edits data locally before retry completes

**Problem:** Retry sends stale data with original idempotency key

**Solution:** Generate NEW idempotency key when operation is modified

```dart
Future<void> updateOperation(PendingOp operation, Map<String, dynamic> newPayload) async {
  // Update payload
  operation.payload = newPayload;
  
  // Generate NEW idempotency key (invalidates previous)
  operation.idempotencyKey = idempotencyService.generate();
  
  // Reset retry count
  operation.attempts = 0;
  
  await pendingOpsBox.put(operation.id, operation);
}
```

### Case 5: Backend Crash Mid-Processing

**Scenario:** Backend crashes after executing operation but before updating idempotency store

**Result:**
- Operation completed (e.g., user created)
- Idempotency key still marked 'processing' or not found
- Client retries → server attempts operation again

**Backend Mitigation:**
- Use database transactions to atomically update both:
  1. Primary resource (user, room, etc.)
  2. Idempotency store entry

```python
def create_user(payload, idempotency_key):
    with db.transaction():
        # Insert user
        user = db.users.insert(payload)
        
        # Update idempotency store
        db.idempotency_keys.insert({
            'key': idempotency_key,
            'status': 'completed',
            'response': serialize(user),
            'ttl': now() + 24_hours
        })
    
    return user
```

---

## Security Considerations

### Scoping by User

**Requirement:** Idempotency keys MUST be scoped per user

**Rationale:** Prevent one user from replaying another user's operation

**Implementation:**
```python
# Bad: Global key lookup
cached = idempotency_store.get(idempotency_key)

# Good: User-scoped key lookup
cached = idempotency_store.get(f"{user_id}:{idempotency_key}")
```

**Benefit:** User A cannot replay User B's key to create duplicate resources

### Key Uniqueness

**Requirement:** Keys MUST be cryptographically random (UUID v4)

**Rationale:** Prevent key prediction or collision attacks

**Validation:**
```python
def validate_idempotency_key(key):
    # Must be valid UUID v4
    try:
        uuid_obj = uuid.UUID(key, version=4)
        if uuid_obj.version != 4:
            raise ValueError("Must be UUID v4")
    except ValueError:
        raise ValidationError("Invalid idempotency key format")
```

### Replay Attack Prevention

**Scenario:** Attacker captures idempotency key, replays request

**Mitigation:**
- Scoped by user (attacker needs auth token)
- Auth token has expiry (limited replay window)
- Idempotency key has TTL (expires after 24h)

**Limitations:** 
- Cannot prevent replay within 24h window by same authenticated user
- This is acceptable (user can retry their own operations)

---

## Performance Optimization

### Caching Strategy

**In-Memory Cache (Redis):**
- **Pros:** Fast lookups (< 1ms), simple TTL management
- **Cons:** Data loss on crash (acceptable for 24h cache)
- **Recommendation:** Use for production

**Database Table:**
- **Pros:** Durable, no data loss on crash
- **Cons:** Slower lookups (10-50ms), requires cleanup jobs
- **Recommendation:** Use if durability critical

**Hybrid Approach:**
```python
# Check in-memory cache first
cached = redis.get(f"idempotency:{idempotency_key}")

if cached is None:
    # Fallback to database
    cached = db.idempotency_keys.get(idempotency_key)
    
    if cached is not None:
        # Populate cache
        redis.setex(f"idempotency:{idempotency_key}", 86400, serialize(cached))

return cached
```

### Response Compression

**Challenge:** Cached responses may be large (e.g., list of devices)

**Solution:** Compress response body in cache

```python
import zlib

def cache_response(idempotency_key, response):
    compressed = zlib.compress(json.dumps(response).encode('utf-8'))
    
    redis.setex(
        f"idempotency:{idempotency_key}",
        86400,
        compressed
    )

def get_cached_response(idempotency_key):
    compressed = redis.get(f"idempotency:{idempotency_key}")
    
    if compressed:
        decompressed = zlib.decompress(compressed)
        return json.loads(decompressed.decode('utf-8'))
    
    return None
```

---

## Monitoring & Alerting

### Key Metrics

**Idempotency Hit Rate**
```
idempotency.cache_hit_rate = cache_hits / (cache_hits + cache_misses)
```
- **Expected:** 5-15% (most requests are new)
- **Alert:** > 30% (possible retry storm)

**Concurrent Requests**
```
idempotency.concurrent_requests.count
```
- **Expected:** < 1% of requests
- **Alert:** Spike indicates race condition or bug

**Cache Size**
```
idempotency.cache_size.entries
```
- **Expected:** Proportional to daily request volume
- **Alert:** Unbounded growth (TTL cleanup not working)

**Stale Keys**
```
idempotency.stale_keys.count
```
- **Definition:** Keys older than 24h still in cache
- **Expected:** 0 (cleanup jobs working)
- **Alert:** > 1000 (cleanup job failed)

### Logging

**Log Idempotency Events:**
```python
# Cache hit (returning cached response)
logger.info('idempotency_cache_hit', extra={
    'idempotency_key': idempotency_key,
    'user_id': user_id,
    'operation_type': operation_type,
    'cached_status': cached['status'],
    'cached_at': cached['created_at']
})

# Concurrent request
logger.warn('idempotency_concurrent_request', extra={
    'idempotency_key': idempotency_key,
    'user_id': user_id,
    'operation_type': operation_type
})
```

---

## Testing Recommendations

### Unit Tests

**Test Key Generation:**
```dart
test('generates valid UUID v4', () {
  final idempotencyService = IdempotencyService();
  final key = idempotencyService.generate();
  
  // Valid UUID v4 format
  expect(key, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
});

test('generates unique keys', () {
  final idempotencyService = IdempotencyService();
  final keys = List.generate(1000, (_) => idempotencyService.generate());
  
  // All keys unique
  expect(keys.toSet().length, 1000);
});
```

**Test Local Success Tracking:**
```dart
test('tracks successful operations', () async {
  final idempotencyService = IdempotencyService();
  final key = 'test-key-123';
  
  // Initially not succeeded
  expect(await idempotencyService.hasSucceeded(key), false);
  
  // Mark as succeeded
  await idempotencyService.markSuccess(key);
  
  // Now succeeded
  expect(await idempotencyService.hasSucceeded(key), true);
});
```

### Integration Tests

**Test Duplicate Prevention:**
```dart
testWidgets('prevents duplicate operations', (tester) async {
  final mockClient = MockApiClient();
  final idempotencyKey = uuid.v4();
  
  // First request succeeds
  when(() => mockClient.post(any(), any(), headers: any(named: 'headers')))
      .thenAnswer((_) async => Response(data: {'user_id': '123'}));
  
  // Send operation
  await queueProcessor.process(PendingOp(
    id: uuid.v4(),
    idempotencyKey: idempotencyKey,
    type: OperationType.createUser,
    payload: {'email': 'test@example.com'},
  ));
  
  // Retry with same key (simulated network issue)
  await queueProcessor.process(PendingOp(
    id: uuid.v4(),
    idempotencyKey: idempotencyKey, // SAME KEY
    type: OperationType.createUser,
    payload: {'email': 'test@example.com'},
  ));
  
  // Backend called only once (second request returned cached response)
  verify(() => mockClient.post(any(), any(), headers: any(named: 'headers'))).called(1);
});
```

**Test Concurrent Requests:**
```dart
testWidgets('handles concurrent requests', (tester) async {
  final mockClient = MockApiClient();
  final idempotencyKey = uuid.v4();
  
  // First request returns processing
  when(() => mockClient.post(any(), any(), headers: {'Idempotency-Key': idempotencyKey}))
      .thenAnswer((_) async => throw ConflictException(
        message: 'Concurrent request',
        errorCode: 'CONCURRENT_REQUEST',
      ));
  
  // Second request succeeds (after first completes)
  when(() => mockClient.post(any(), any(), headers: {'Idempotency-Key': idempotencyKey}))
      .thenAnswer((_) async => Response(data: {'user_id': '123'}));
  
  // Process operation (will retry after concurrent conflict)
  await queueProcessor.process(PendingOp(
    id: uuid.v4(),
    idempotencyKey: idempotencyKey,
    type: OperationType.createUser,
    payload: {'email': 'test@example.com'},
  ));
  
  // Verify retry occurred
  verify(() => mockClient.post(any(), any(), headers: any(named: 'headers'))).called(2);
});
```

### Load Tests

**Test Cache Performance:**
```python
# Simulate 10k requests with 10% retry rate (idempotency hits)
def test_idempotency_cache_performance():
    for i in range(10000):
        idempotency_key = str(uuid.uuid4())
        
        # 10% of requests are retries (same key)
        if random.random() < 0.1:
            idempotency_key = random.choice(recent_keys)
        
        response = requests.post(
            '/api/v1/users',
            json={'email': f'user{i}@example.com'},
            headers={'Idempotency-Key': idempotency_key}
        )
        
        recent_keys.append(idempotency_key)
    
    # Verify cache hit rate
    assert metrics['idempotency.cache_hit_rate'] > 0.09
    assert metrics['idempotency.cache_hit_rate'] < 0.11
```

---

## Best Practices

### Do's
✅ Generate idempotency key when operation is created  
✅ Persist key with operation (survive app restarts)  
✅ Use same key for all retries of same operation  
✅ Track success locally to prevent stale retries  
✅ Scope keys per user on backend  
✅ Set reasonable TTL (24 hours)  
✅ Handle concurrent request conflicts gracefully

### Don'ts
❌ Don't reuse keys across different operations  
❌ Don't generate new key on each retry  
❌ Don't use sequential or predictable keys  
❌ Don't skip idempotency for "idempotent" operations (e.g., PUT)  
❌ Don't ignore CONCURRENT_REQUEST conflicts  
❌ Don't use global key namespace (must scope by user)  
❌ Don't cache keys indefinitely (causes storage bloat)

---

## Future Enhancements

### 1. Operation Fingerprinting

**Concept:** Hash payload as secondary idempotency check

```dart
String calculateFingerprint(Map<String, dynamic> payload) {
  final sorted = SplayTreeMap<String, dynamic>.from(payload);
  final json = jsonEncode(sorted);
  return sha256.convert(utf8.encode(json)).toString();
}

// Check if identical operation already succeeded
final fingerprint = calculateFingerprint(operation.payload);
if (await idempotencyService.hasSucceeded(fingerprint)) {
  return; // Skip even if idempotency key different
}
```

**Benefit:** Catches accidental duplicate operations with different keys

### 2. Multi-Level Cache

**Concept:** Client-side cache + server-side cache

```dart
// Client checks local cache first (instant)
if (await localCache.hasSucceeded(operation.idempotencyKey)) {
  return; // No network request needed
}

// Send to server (server checks its cache)
await apiClient.post(...);
```

**Benefit:** Reduces network requests for known-successful operations

### 3. Idempotency Groups

**Concept:** Link related operations (e.g., create user + create room)

```dart
final groupKey = uuid.v4();

final op1 = PendingOp(
  idempotencyKey: uuid.v4(),
  idempotencyGroup: groupKey, // Link to group
  type: OperationType.createUser,
);

final op2 = PendingOp(
  idempotencyKey: uuid.v4(),
  idempotencyGroup: groupKey, // Same group
  type: OperationType.createRoom,
);
```

**Benefit:** All-or-nothing semantics for multi-step flows

---

## References

- [RFC 4122](https://tools.ietf.org/html/rfc4122) - UUID Specification
- [Stripe API - Idempotency](https://stripe.com/docs/api/idempotent_requests)
- [PayPal API - Idempotency](https://developer.paypal.com/docs/api/reference/api-requests/#http-request-headers)
- [API Envelope Specification](api_envelope.md)
- [Error Mapping Specification](error_mapping.md)

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-11-22 | Initial specification |
