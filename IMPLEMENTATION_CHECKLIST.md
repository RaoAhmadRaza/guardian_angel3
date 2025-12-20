# Implementation Confirmation Checklist — Local API & Robust Sync Engine

**Version:** 1.0  
**Last Updated:** November 22, 2025  
**Purpose:** Comprehensive, actionable checklist for code review, QA, and deployment verification

---

## Quick Pass (Smoke Tests)

- [ ] Code compiles and app boots without runtime exceptions
- [ ] All new files in `/lib/sync/`, `/lib/persistence/` and `/test/sync/` exist and are included in project
- [ ] `flutter test` passes (no failing unit tests)
- [ ] CI pipeline runs and returns green for the branch (unit + integration tests)

---

## Phase-by-Phase Verification Checklist

### Phase 1 — Design & Specs (Pre-Implementation)

**Specification Files:**
- [x] `specs/sync/api_envelope.md` exists and includes request + response JSON envelopes
- [x] `specs/sync/error_mapping.md` maps HTTP codes → typed exceptions (AuthException, RetryableException, ClientException, ConflictException)
- [x] `specs/sync/backoff_policy.md` documents base, formula, jitter range, MAX_BACKOFF, MAX_ATTEMPTS, and Retry-After precedence
- [x] `specs/sync/idempotency_policy.md` documents idempotency window, key format (UUIDv4), server expectations and client fallback plan
- [x] `specs/sync/op_router.md` lists all opType/entityType → (method, pathBuilder, transform) mappings
- [x] `specs/sync/test_matrix.md` exists and lists unit/integration/fault/load tests

**How to Confirm:**  
Open the files and verify they include concrete values (numbers, header names), not just prose.

**Location:** `/Users/muhammadafzal/Downloads/guardian_angel2-main/specs/sync/`

---

### Phase 2 — Core Implementation (ApiClient, Queue, SyncEngine)

#### A. ApiClient

**Implementation:**
- [x] `lib/sync/api_client.dart` implemented
- [x] Headers injected on every request: Authorization, Idempotency-Key, X-App-Version, X-Device-Id, Trace-Id
- [x] `ApiClient.request()` returns parsed JSON on 2xx and throws typed exceptions on errors
- [x] Token refresh flow: on 401, ApiClient attempts `authService.tryRefresh()` once then retries original request
- [x] Retry-After header parsing implemented (seconds and HTTP-date support)

**Validation Steps:**
```bash
# Unit test location
flutter test test/sync/api_client_test.dart

# Manual test checklist
# 1. Mock HTTP responses for 200, 401 (refresh success), 401 (refresh fail)
# 2. Test 429 with Retry-After header
# 3. Test 500 server error handling
# 4. Assert correct exceptions thrown for each scenario
```

**Expected Behavior:**
- 200 OK → Returns parsed JSON
- 401 → Triggers token refresh → Retry succeeds
- 401 → Token refresh fails → AuthException thrown
- 429 with Retry-After: 5 → Client observes 5s delay
- 500 → ServerException thrown

---

#### B. OpRouter & Mapping

**Implementation:**
- [x] `lib/sync/op_router.dart` present and populated for all expected op types
- [x] Each route has method, pathBuilder, and optional payload transform
- [x] Tests exist to validate route resolution and path building for representative payloads

**Validation:**
```bash
flutter test test/sync/op_router_test.dart
```

**Test Cases:**
- Route resolution for CREATE/UPDATE/DELETE operations
- Path building with payload data (e.g., `/devices/{id}`)
- Transform functions applied correctly to payloads

---

#### C. PendingQueueService (Persistence & Index)

**Implementation:**
- [x] `pending_ops_box` and `pending_index_box` names documented in box_registry
- [x] `enqueue()` writes op to pending box and updates index atomically (index = sorted list by created_at)
- [x] `getOldest()` returns oldest op by index; if index inconsistent, `rebuildIndex()` runs
- [x] `markProcessed()` removes op from pending box and index atomically
- [x] `markFailed()` moves op to failed_ops_box with error metadata (error, attempts, failed_at)
- [x] All writes use atomic operations

**Validation Steps:**
```bash
# Integration test
flutter test test/sync/pending_queue_service_test.dart

# Manual verification
# 1. Enqueue several ops with varied timestamps
# 2. Assert getOldest() returns them in FIFO order
# 3. Simulate index inconsistency (delete an op)
# 4. Ensure rebuildIndex() corrects it
```

**Test Scenarios:**
```dart
// Test 1: FIFO ordering
await queue.enqueue(op1); // created_at: 10:00
await queue.enqueue(op2); // created_at: 10:01
await queue.enqueue(op3); // created_at: 10:02
final oldest = await queue.getOldest();
assert(oldest.id == op1.id);

// Test 2: Index rebuild
await simulateIndexCorruption();
final oldest = await queue.getOldest(); // Should trigger rebuild
assert(oldest != null);

// Test 3: Mark processed atomicity
await queue.markProcessed(op1.id);
final remaining = await queue.getPendingCount();
assert(remaining == 2);
```

---

#### D. SyncEngine (Processor)

**Implementation:**
- [x] SyncEngine respects persisted processing lock (calls `ProcessingLock.tryAcquire()` before processing)
- [x] Sync loop checks `nextAttemptAt` and skips delayed ops
- [x] Idempotency header included with every API request (generate & persist if missing)
- [x] On success: `markProcessed()` called; metrics emitted
- [x] On RetryableException: attempts++, compute delay by BackoffPolicy, persist nextAttemptAt, emit backoff metric
- [x] On AuthException: attempt token refresh once; if fails, move to failed and surface to UI
- [x] On ConflictException (409): move to failed and trigger reconciliation workflow
- [x] Sync engine uses connectivity status: processes only when network available

**Validation Steps:**
```bash
flutter test test/sync/sync_engine_test.dart
```

**Critical Test Cases:**
1. **Success Path:** Enqueue → Process → Success → Metrics emitted
2. **Retryable (429/5xx):** RetryableException → Backoff → Retry → Success
3. **Permanent (400):** ClientException → Move to failed_ops
4. **Auth Flow:** 401 → Refresh token → Retry → Success/Fail
5. **Conflict (409):** ConflictException → Trigger reconciliation

---

### Phase 3 — Reliability & Crash Recovery

#### A. Backoff & Jitter

**Implementation:**
- [x] `BackoffPolicy.computeDelay(attempts, retryAfter)` implemented
- [x] Jitter uses uniform random in range 0.5..1.5 (configurable)
- [x] Retry-After precedence honored

**Validation:**
```bash
flutter test test/sync/backoff_policy_test.dart
```

**Test Cases:**
```dart
// Test 1: Exponential backoff with jitter
final policy = BackoffPolicy(baseMs: 1000, maxBackoffMs: 30000);
final delay1 = policy.computeDelay(1, null); // ~1s ± jitter
final delay2 = policy.computeDelay(2, null); // ~2s ± jitter
final delay3 = policy.computeDelay(3, null); // ~4s ± jitter
assert(delay1.inMilliseconds >= 500 && delay1.inMilliseconds <= 1500);

// Test 2: Retry-After precedence
final retryAfter = Duration(seconds: 10);
final delay = policy.computeDelay(5, retryAfter);
assert(delay.inSeconds >= 10 && delay.inSeconds <= 15); // 10s + jitter
```

**Integration Test:**
Server returns 429 with `Retry-After: 5` → Op delayed for exactly 5s (+ small jitter)

---

#### B. Processing Lock & Heartbeat

**Implementation:**
- [x] ProcessingLock persisted to meta box with runnerId, startedAt, lastHeartbeat
- [x] SyncEngine updates heartbeat periodically
- [x] On startup, stale lock takeover logic implemented (now - lastHeartbeat > staleThreshold)
- [x] Heartbeat failure handling: no two processors perform same op

**Validation:**
```bash
flutter test test/sync/processing_lock_test.dart
```

**Integration Test Scenario:**
```
1. Start Processor A
2. Simulate crash (stop heartbeats)
3. Wait for staleThreshold (e.g., 5 minutes)
4. Start Processor B
5. Assert: B acquires lock and continues processing
6. Assert: A's operations not duplicated
```

**Manual Test:**
```bash
# Terminal 1: Start processor A
flutter run --device-id=device1

# Terminal 2: Observe lock acquisition
# Kill Terminal 1 abruptly (crash simulation)

# Terminal 3: Start processor B
flutter run --device-id=device2

# Verify: B takes over after staleThreshold
# Check logs for lock acquisition messages
```

---

#### C. Crash-Resume & Idempotency

**Implementation:**
- [x] If op was mid-processing when app crashed, on restart it is safely re-sent with same idempotency key
- [x] In-flight state persisted so attempts and nextAttemptAt reflect previous runs

**Validation:**
```bash
# Crash-resume test
flutter test test/sync/crash_resume_test.dart
```

**Test Scenario:**
```dart
// Test: Idempotent crash-resume
1. Start processing op with idempotencyKey = "key-123"
2. Intercept right before markProcessed()
3. Simulate crash (exit app)
4. Restart app
5. SyncEngine resumes processing
6. Server receives op with same idempotencyKey = "key-123"
7. Assert: Server processed at most once (check server logs)
8. Assert: No duplicate side-effects in database
```

**Expected Backend Behavior:**
```json
// First request (before crash)
POST /api/v1/devices
Headers: {
  "Idempotency-Key": "550e8400-e29b-41d4-a716-446655440000"
}

// Retry after crash
POST /api/v1/devices
Headers: {
  "Idempotency-Key": "550e8400-e29b-41d4-a716-446655440000"
}

// Server response (cached from first request)
HTTP 200 OK (deduplicated - no second insert)
```

---

#### D. Coalescing / Batching (Optional)

**Implementation:**
- [x] For configurable op types, BatchCoalescer merges redundant ops (e.g., repeated toggles for same device)
- [x] When coalescing, ensure txnToken mapping and optimistic UI mapping maintained

**Validation:**
```bash
flutter test test/sync/batch_coalescer_test.dart
```

**Test Case:**
```dart
// Enqueue 10 toggle ops in quick succession
for (int i = 0; i < 10; i++) {
  await syncEngine.enqueue(PendingOp(
    id: 'op-$i',
    opType: 'UPDATE',
    entityType: 'DEVICE',
    payload: {'id': 'device-1', 'state': i % 2 == 0 ? 'on' : 'off'},
  ));
}

// After coalescing
await coalescer.coalesce();
final pending = await queue.getPendingCount();
assert(pending == 1); // Only last state sent

final lastOp = await queue.getOldest();
assert(lastOp.payload['state'] == 'off'); // Final state
```

---

#### E. Reconciliation for 409 Conflicts

**Implementation:**
- [x] Reconciler fetches server state on 409
- [x] Computes merge strategy
- [x] Either re-enqueues modified op or marks op resolved
- [x] Reconciliation strategy documented and tested for at least one common conflict type

**Validation:**
```bash
flutter test test/sync/reconciler_test.dart
```

**Test Scenario:**
```dart
// Test: 409 conflict resolution
1. Client attempts to update device brightness: 50 → 75
2. Server returns 409 Conflict (server version: brightness = 60)
3. Reconciler triggers:
   - Fetch server state: GET /api/v1/devices/123
   - Server responds: { brightness: 60, version: 5 }
4. Merge strategy: client_wins / server_wins / merge
   - If merge: brightness = max(60, 75) = 75
5. Re-enqueue with updated payload and version
6. Retry succeeds with merged state
```

**Expected Logs:**
```
[INFO] ConflictException detected for op-123
[INFO] Fetching server state for device-123
[INFO] Server version: 5, Client version: 4
[INFO] Applying merge strategy: client_wins
[INFO] Re-enqueueing op-123 with updated version
[INFO] Retry succeeded for op-123
```

---

#### F. Real-time & Polling Fallback

**Implementation:**
- [x] RealtimeService implemented (WebSocket or MQTT) and sends push events to local state
- [x] If push unavailable, polling activates with exponential backoff
- [x] Polls when pending_ops exist
- [x] Realtime events trigger reconciliation and reduce queue pressure

**Validation:**
```bash
flutter test test/sync/realtime_service_test.dart
```

**Test Scenarios:**

**1. Real-time Push:**
```dart
// Server sends push event
{
  "event": "device.updated",
  "data": {
    "id": "device-123",
    "state": "on",
    "brightness": 80
  }
}

// Client receives and updates local state
// Pending ops reconciled immediately
```

**2. Polling Fallback:**
```dart
// WebSocket disconnects
realtime.disconnect();

// Polling activates
await Future.delayed(Duration(seconds: 5)); // First poll
await Future.delayed(Duration(seconds: 10)); // Second poll (backoff)

// When WebSocket reconnects
realtime.connect();
// Polling stops
```

---

### Phase 4 — Operationalization & Hardening

#### A. Telemetry & Logging

**Implementation:**
- [x] Metrics emitted: pending_ops_gauge, processed_ops_total, failed_ops_total, avg_processing_time_ms, backoff_count, circuit_tripped_total
- [x] Logs include structured fields: opId, opType, attempts, runnerId, traceId, event
- [x] Sensitive fields redacted before logging (PII/vitals)

**Validation:**
```bash
# Check telemetry backend for metrics
curl http://localhost:8080/metrics

# Expected output (Prometheus format)
# TYPE pending_ops_gauge gauge
pending_ops_gauge 42

# TYPE processed_ops_total counter
processed_ops_total 1523

# TYPE failed_ops_total counter
failed_ops_total 12

# TYPE circuit_tripped_total counter
circuit_tripped_total 3
```

**Log Inspection:**
```json
{
  "timestamp": "2025-11-22T10:30:45.123Z",
  "level": "info",
  "opId": "op-550e8400-e29b-41d4-a716-446655440000",
  "opType": "UPDATE",
  "entityType": "DEVICE",
  "attempts": 2,
  "runnerId": "runner-abc123",
  "traceId": "trace-xyz789",
  "event": "op_processed_success",
  "latency_ms": 245,
  "payload": {
    "id": "device-123",
    "email": "[REDACTED_EMAIL]",
    "vitals": "[REDACTED]"
  }
}
```

**PII Redaction Checklist:**
- [ ] Email addresses → `[REDACTED_EMAIL]`
- [ ] Phone numbers → `[REDACTED_PHONE]`
- [ ] SSN → `[REDACTED_SSN]`
- [ ] Credit cards → `[REDACTED_CC]`
- [ ] Patient vitals → `[REDACTED]`
- [ ] Auth tokens → `Bea...123` (masked, last 4 chars only)

---

#### B. Circuit Breaker

**Implementation:**
- [x] CircuitBreaker trips on N failures in window and prevents immediate retries
- [x] After cooldown, probe request issued
- [x] Probe success → Circuit closes and resumes normal processing
- [x] Probe failure → Circuit remains open

**Validation:**
```bash
flutter test test/sync/circuit_breaker_test.dart
```

**Test Scenario:**
```dart
// Simulate server 5xx storm
final breaker = CircuitBreaker(
  failureThreshold: 10,
  window: Duration(minutes: 1),
  cooldown: Duration(minutes: 1),
);

// Trigger failures
for (int i = 0; i < 10; i++) {
  await breaker.recordFailure();
}

// Assert: Circuit tripped
assert(breaker.isOpen == true);

// Wait for cooldown
await Future.delayed(Duration(minutes: 1));

// Assert: Probe state
assert(breaker.state == CircuitBreakerState.halfOpen);

// Probe succeeds
await breaker.recordSuccess();

// Assert: Circuit closed
assert(breaker.isOpen == false);
```

**Expected Behavior:**
1. **Closed State:** Normal operation
2. **Open State:** All requests fail-fast (no API calls)
3. **Half-Open State:** Single probe request allowed
4. **Recovery:** Probe succeeds → Circuit closes

---

#### C. Backups / Export / Admin UI

**Implementation:**
- [x] Encrypted export of pending_ops, failed_ops, audit_logs implemented
- [x] Admin debug screen allows:
  - [x] Inspect boxes
  - [x] Force rebuild index
  - [x] Export pending ops
  - [x] Release lock
  - [x] Re-enqueue failed ops
- [x] Runbook includes exact steps for each admin action

**Validation:**

**1. Export Operations:**
```bash
# CLI export
dart run scripts/export_pending_ops.dart \
  --out=/tmp/ops.csv \
  --format=csv \
  --failed-only

# Verify file created
ls -lh /tmp/ops.csv

# Verify PII redacted
cat /tmp/ops.csv | grep -i "email"
# Expected: [REDACTED_EMAIL]
```

**2. Admin UI Actions:**
```
Location: lib/sync/admin/admin_console.dart

Actions to test:
1. Navigate to Admin Console (dev builds only)
2. Click "Force Release Lock" → Confirm lock released
3. Click "Rebuild Index" → Verify index rebuilt
4. Click "Export Operations" → Verify file downloaded
5. Click "Clear Failed Ops" → Verify failed_ops_box cleared
6. Click "Retry All Failed" → Verify ops re-enqueued
7. Click "View Logs" → Verify structured logs displayed
```

**3. Runbook Verification:**
```bash
# Open runbook
open docs/runbooks/sync_runbook.md

# Verify sections exist:
- [ ] Force Release Lock procedure
- [ ] Rebuild Index procedure  
- [ ] Export Operations procedure
- [ ] Clear Failed Ops procedure
- [ ] Retry Failed Ops procedure
- [ ] Emergency procedures
```

---

#### D. Key Rotation & Secure Deletion

**Implementation:**
- [x] Key rotation path implemented: generate new key, re-encrypt boxes in background, preserve old key until finished
- [x] Secure deletion when user deletes account: wipe boxes and remove keys from flutter_secure_storage

**Validation:**

**1. Key Rotation:**
```dart
// Test key rotation
await keyManager.rotateKeys();

// Verify:
// 1. New key generated
// 2. All boxes re-encrypted with new key
// 3. Old key preserved during migration
// 4. Data readable after rotation
// 5. Old key deleted after completion

final data = await pendingBox.get('op-123');
assert(data != null); // Data still accessible
```

**Manual Test:**
```
1. Seed test data in pending_ops_box
2. Trigger key rotation: KeyManager.rotateKeys()
3. Monitor logs for re-encryption progress
4. After completion, verify data integrity
5. Verify old key removed from secure storage
```

**2. Secure Deletion:**
```dart
// Test account deletion
await userService.deleteAccount(userId);

// Verify:
// 1. All boxes cleared (pending, failed, audit)
// 2. Encryption keys removed from secure storage
// 3. Local cache cleared
// 4. No residual data in app directory

final keys = await secureStorage.readAll();
assert(keys.isEmpty); // No keys remain

final pendingCount = await pendingBox.length;
assert(pendingCount == 0); // Box empty
```

**Compliance Check:**
- [ ] GDPR Article 17 (Right to Erasure) compliance
- [ ] HIPAA secure deletion requirements met
- [ ] No data recoverable after deletion

---

## Testing Checklist (Must Pass Before Release)

### Unit Tests

**Location:** `test/sync/`

- [x] `api_client_test.dart` - HTTP client, error mapping, token refresh
- [x] `backoff_policy_test.dart` - Exponential backoff, jitter, retry-after
- [x] `op_router_test.dart` - Route resolution, path building
- [x] `pending_op_test.dart` - Model parsing, serialization
- [x] `pending_queue_service_test.dart` - FIFO ordering, atomicity
- [x] `processing_lock_test.dart` - Lock acquisition, stale takeover
- [x] `circuit_breaker_test.dart` - Failure threshold, cooldown
- [x] `reconciler_test.dart` - Conflict resolution strategies
- [x] `batch_coalescer_test.dart` - Op merging, deduplication

**Run Command:**
```bash
flutter test test/sync/
```

**Expected Output:**
```
00:02 +50: All tests passed!
```

---

### Integration Tests (Local Hive)

**Location:** `test/sync/integration/`

**Test Cases:**

**1. Happy Path:**
```dart
test('enqueue → process success', () async {
  // 1. Enqueue operation
  final op = PendingOp(
    id: 'op-test-1',
    opType: 'UPDATE',
    entityType: 'DEVICE',
    payload: {'id': 'device-123', 'state': 'on'},
  );
  await syncEngine.enqueue(op);

  // 2. Process operation
  await syncEngine.start();
  await Future.delayed(Duration(seconds: 2));

  // 3. Verify success
  final pending = await queue.getPendingCount();
  expect(pending, 0);

  final metrics = await syncEngine.metrics.exportJson();
  expect(metrics['processed_ops_total'], 1);
});
```

**2. Retry with 429:**
```dart
test('enqueue → 429 → retry → success', () async {
  // Mock API to return 429 first, then 200
  mockApi.setResponses([
    MockResponse(429, headers: {'Retry-After': '2'}),
    MockResponse(200, body: {'success': true}),
  ]);

  final op = PendingOp(
    id: 'op-test-2',
    opType: 'UPDATE',
    entityType: 'DEVICE',
    payload: {'id': 'device-123'},
  );
  await syncEngine.enqueue(op);

  // Start processing
  await syncEngine.start();

  // Wait for retry delay (2s + jitter)
  await Future.delayed(Duration(seconds: 3));

  // Verify eventual success
  final pending = await queue.getPendingCount();
  expect(pending, 0);
});
```

**3. Permanent Failure (400):**
```dart
test('enqueue → 400 → failed_ops', () async {
  // Mock API to return 400 Bad Request
  mockApi.setResponse(400, body: {
    'error': {'code': 'INVALID_PAYLOAD', 'message': 'Missing required field'}
  });

  final op = PendingOp(
    id: 'op-test-3',
    opType: 'CREATE',
    entityType: 'DEVICE',
    payload: {}, // Invalid payload
  );
  await syncEngine.enqueue(op);

  await syncEngine.start();
  await Future.delayed(Duration(seconds: 1));

  // Verify moved to failed_ops
  final pending = await queue.getPendingCount();
  expect(pending, 0);

  final failed = await queue.getFailedCount();
  expect(failed, 1);

  final failedOp = await queue.getFailedById('op-test-3');
  expect(failedOp.error, contains('INVALID_PAYLOAD'));
});
```

**Run Command:**
```bash
flutter test test/sync/integration/
```

---

### Crash/Resume Test

**Test Scenario:**
```dart
test('crash-resume with idempotency protection', () async {
  // 1. Start processing
  final op = PendingOp(
    id: 'op-crash-test',
    opType: 'UPDATE',
    entityType: 'DEVICE',
    payload: {'id': 'device-123', 'state': 'on'},
    idempotencyKey: '550e8400-e29b-41d4-a716-446655440000',
  );
  await syncEngine.enqueue(op);

  // 2. Start sync engine
  await syncEngine.start();

  // 3. Simulate crash (intercept before markProcessed)
  await Future.delayed(Duration(milliseconds: 500));
  await simulateCrash(); // Kill process

  // 4. Restart app
  final newSyncEngine = await createSyncEngine();
  await newSyncEngine.start();

  // 5. Verify idempotency
  // Server should see same idempotencyKey twice
  final serverRequests = mockServer.getRequests();
  expect(serverRequests.length, 2);
  expect(serverRequests[0].headers['Idempotency-Key'], 
         serverRequests[1].headers['Idempotency-Key']);

  // 6. Verify server processed only once
  final deviceState = await mockServer.getDeviceState('device-123');
  expect(deviceState['processCount'], 1); // Not 2!
});
```

**Manual Crash Test:**
```bash
# Terminal 1: Start app
flutter run

# Enqueue operation via UI
# Tap "Toggle Device" button

# Terminal 1: Kill app mid-processing
kill -9 <pid>

# Terminal 1: Restart app
flutter run

# Verify:
# 1. Check server logs for duplicate idempotency key
# 2. Verify no duplicate side-effect in database
# 3. Check client logs for successful retry
```

---

### Reconciliation Test

**Test Scenario:**
```dart
test('409 conflict triggers reconciliation', () async {
  // 1. Enqueue update operation
  final op = PendingOp(
    id: 'op-conflict',
    opType: 'UPDATE',
    entityType: 'DEVICE',
    payload: {'id': 'device-123', 'brightness': 75, 'version': 4},
  );
  await syncEngine.enqueue(op);

  // 2. Mock server returns 409
  mockApi.setResponse(409, body: {
    'error': {
      'code': 'CONFLICT',
      'message': 'Version mismatch',
      'details': {
        'conflict_type': 'version',
        'server_version': 5,
        'client_version': 4,
      }
    }
  });

  // 3. Start processing
  await syncEngine.start();
  await Future.delayed(Duration(seconds: 1));

  // 4. Verify reconciliation triggered
  expect(reconciler.wasTriggered, true);

  // 5. Verify resolution
  // Option A: Op re-enqueued with merged state
  final pending = await queue.getOldest();
  expect(pending?.payload['version'], 5); // Updated version

  // Option B: Op marked resolved
  final failed = await queue.getFailedById('op-conflict');
  expect(failed?.resolution, 'reconciled');
});
```

---

### Load Test

**Tool:** `tool/stress/load_test.dart`

**Test Suites:**
1. Enqueue Throughput (100, 1000, 5000, 10000 ops)
2. Processing Latency (P50, P95, P99)
3. Memory Consumption (50k ops)
4. Circuit Breaker Stress (50 failures)
5. Concurrent Processing (3 workers, 5000 ops)

**Run Command:**
```bash
flutter run tool/stress/load_test.dart
```

**Expected Results:**
```
╔═══════════════════════════════════════════════════════════╗
║           SYNC ENGINE LOAD TEST                          ║
╚═══════════════════════════════════════════════════════════╝

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Test 1: Enqueue Throughput
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Size: 100 ops
    Time: 145ms
    Throughput: 689 ops/sec
    Avg latency: 1.45ms

  Size: 1000 ops
    Time: 1234ms
    Throughput: 810 ops/sec
    Avg latency: 1.23ms

  Size: 5000 ops
    Time: 6789ms
    Throughput: 736 ops/sec
    Avg latency: 1.36ms

  Size: 10000 ops
    Time: 13456ms
    Throughput: 743 ops/sec
    Avg latency: 1.35ms

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Test 2: Processing Latency
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Processed 1000 ops in 3456ms
  Average latency: 3.45ms per op
  Throughput: 289 ops/sec
  P50 latency: 52ms
  P95 latency: 145ms
  P99 latency: 234ms

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Test 3: Memory Consumption
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Initial memory: 45.23 MB
  After seeding 50k ops: 178.56 MB
  Delta: 133.33 MB
  Memory per operation: 2.67 KB

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Test 4: Circuit Breaker Stress
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Simulating 50 failures...
  Circuit tripped after 10 failures
  Cooldown period: 60s
  Probe request succeeded
  Circuit recovered ✓

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Test 5: Concurrent Processing
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Spawning 3 workers to process 5000 ops...
  Worker 1 processed 1678 operations
  Worker 2 processed 1654 operations
  Worker 3 processed 1668 operations
  Total time: 8.45s
  Aggregate throughput: 591 ops/sec
  No duplicate processing detected ✓

╔═══════════════════════════════════════════════════════════╗
║                  LOAD TEST COMPLETE                      ║
╚═══════════════════════════════════════════════════════════╝
```

**Acceptance Criteria:**
- [ ] Enqueue throughput > 500 ops/sec
- [ ] P95 processing latency < 5000ms
- [ ] Memory per operation < 5KB
- [ ] Circuit breaker recovers after cooldown
- [ ] No duplicate processing in concurrent test

---

### Fault-Injection Test

**Network Flapping Test:**
```dart
test('network flapping recovery', () async {
  // 1. Enqueue operations
  for (int i = 0; i < 10; i++) {
    await syncEngine.enqueue(PendingOp(
      id: 'op-$i',
      opType: 'UPDATE',
      entityType: 'DEVICE',
      payload: {'id': 'device-$i'},
    ));
  }

  // 2. Start sync engine
  await syncEngine.start();

  // 3. Simulate network flapping
  for (int i = 0; i < 5; i++) {
    await Future.delayed(Duration(seconds: 2));
    await networkSimulator.disconnect(); // Network down
    await Future.delayed(Duration(seconds: 1));
    await networkSimulator.connect(); // Network up
  }

  // 4. Verify eventual consistency
  await Future.delayed(Duration(seconds: 10));
  final pending = await queue.getPendingCount();
  expect(pending, 0); // All ops processed despite flapping

  // 5. Verify backoff behavior
  final backoffEvents = metrics.getBackoffCount();
  expect(backoffEvents, greaterThan(0)); // Backoff triggered
});
```

---

### Security Tests

**1. Log Redaction Test:**
```dart
test('sensitive fields redacted in logs', () async {
  final op = PendingOp(
    id: 'op-security',
    opType: 'CREATE',
    entityType: 'USER',
    payload: {
      'email': 'user@example.com',
      'phone': '555-123-4567',
      'ssn': '123-45-6789',
      'password': 'secret123',
    },
  );

  await syncEngine.enqueue(op);
  await syncEngine.start();

  // Read logs
  final logs = await LogReader.readLogs();
  
  // Verify redaction
  expect(logs, contains('[REDACTED_EMAIL]'));
  expect(logs, contains('[REDACTED_PHONE]'));
  expect(logs, contains('[REDACTED_SSN]'));
  expect(logs, contains('[REDACTED]')); // password
  
  // Ensure no plaintext
  expect(logs, isNot(contains('user@example.com')));
  expect(logs, isNot(contains('555-123-4567')));
  expect(logs, isNot(contains('123-45-6789')));
  expect(logs, isNot(contains('secret123')));
});
```

**2. Key Storage Test:**
```dart
test('encryption keys stored securely', () async {
  // Generate and store key
  await keyManager.generateKey();

  // Verify key in secure storage (not plain files)
  final secureKeys = await FlutterSecureStorage().readAll();
  expect(secureKeys, contains('encryption_key'));

  // Verify key NOT in shared prefs or plain files
  final prefs = await SharedPreferences.getInstance();
  expect(prefs.getString('encryption_key'), isNull);

  final appDir = await getApplicationDocumentsDirectory();
  final keyFile = File('${appDir.path}/encryption_key.txt');
  expect(await keyFile.exists(), false);
});
```

**3. Key Deletion Test:**
```dart
test('keys removed on account deletion', () async {
  // Setup
  await keyManager.generateKey();
  final keysBefore = await FlutterSecureStorage().readAll();
  expect(keysBefore.isNotEmpty, true);

  // Delete account
  await userService.deleteAccount(userId);

  // Verify keys removed
  final keysAfter = await FlutterSecureStorage().readAll();
  expect(keysAfter.isEmpty, true);
});
```

---

## How to Run Tests

```bash
# All tests
flutter test

# Unit tests only
flutter test test/sync/

# Integration tests
flutter test test/sync/integration/

# Specific test file
flutter test test/sync/api_client_test.dart

# Load test (manual)
flutter run tool/stress/load_test.dart

# With coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

---

## Operational/Observability Checks (Post-Deploy)

### Monitor (First 24–72 Hours)

**Metrics Dashboard:**
```
Location: Grafana Dashboard (or equivalent)
URL: https://monitoring.example.com/d/sync-engine

Panels to watch:
1. Pending Operations Gauge
   - Trending down after test bursts
   - Alert if > 1000 for > 1 hour

2. Processed Operations (Counter)
   - Increments when devices come online
   - Expected rate: ~100-500 ops/hour

3. Failed Operations (Counter)
   - Low or within baseline (< 5%)
   - Alert if spike > 10/min

4. Average Processing Time
   - Within SLA (< 5000ms for P95)
   - Alert if > 5000ms sustained

5. Circuit Breaker Trips
   - Low frequency (< 5/day)
   - Alert if > 50/day

6. No corruption.events or key_failures
```

**Log Queries:**
```bash
# Sentry / Datadog / CloudWatch

# Query 1: Failed operations
SELECT * FROM logs
WHERE event = 'op_failed'
AND timestamp > NOW() - INTERVAL 1 HOUR
ORDER BY timestamp DESC
LIMIT 100

# Query 2: Circuit breaker trips
SELECT * FROM logs
WHERE event = 'circuit_breaker_tripped'
AND timestamp > NOW() - INTERVAL 24 HOUR

# Query 3: Auth failures
SELECT * FROM logs
WHERE event = 'auth_failed'
AND timestamp > NOW() - INTERVAL 1 HOUR

# Query 4: High latency operations
SELECT * FROM logs
WHERE latency_ms > 5000
AND timestamp > NOW() - INTERVAL 1 HOUR
ORDER BY latency_ms DESC
```

---

### Alerting Configuration

**Alert Rules:**

**1. Failed Operations Spike**
```yaml
alert: HighFailedOpsRate
expr: rate(failed_ops_total[5m]) > 0.1
for: 5m
labels:
  severity: critical
annotations:
  summary: "Failed operations rate > 10/min"
  description: "Current rate: {{ $value }}"
```

**2. Pending Queue Depth**
```yaml
alert: HighPendingOpsDepth
expr: pending_ops_gauge > 1000
for: 1h
labels:
  severity: warning
annotations:
  summary: "Pending operations > 1000 for 1 hour"
  description: "Current depth: {{ $value }}"
```

**3. Circuit Breaker Activity**
```yaml
alert: FrequentCircuitBreakerTrips
expr: increase(circuit_tripped_total[1h]) > 50
labels:
  severity: warning
annotations:
  summary: "Circuit breaker tripped > 50 times in 1 hour"
```

**4. Processing Latency**
```yaml
alert: HighProcessingLatency
expr: histogram_quantile(0.95, processing_time_seconds_bucket) > 5
for: 10m
labels:
  severity: warning
annotations:
  summary: "P95 processing latency > 5s"
```

**5. Success Rate**
```yaml
alert: LowSuccessRate
expr: (processed_ops_total / (processed_ops_total + failed_ops_total)) < 0.9
for: 30m
labels:
  severity: critical
annotations:
  summary: "Success rate < 90%"
```

---

### Runbook Verification

**Location:** `docs/runbooks/sync_runbook.md`

**Required Procedures:**

- [x] **Force Release Lock**
  - When: Lock stuck, processor crashed
  - Steps: Navigate to Admin Console → Force Release Lock → Confirm
  - Risk: May cause duplicate processing if lock valid

- [x] **Rebuild Index**
  - When: Index corruption suspected, inconsistent queue state
  - Steps: Admin Console → Rebuild Index → Wait for completion
  - Risk: Temporary performance degradation

- [x] **Export Operations**
  - When: Debugging, analysis, audit
  - Steps: CLI: `dart run scripts/export_pending_ops.dart --out=ops.csv`
  - Risk: None (read-only)

- [x] **Clear Failed Operations**
  - When: Failed ops no longer recoverable, testing
  - Steps: Admin Console → Clear Failed Ops → Confirm
  - Risk: Data loss

- [x] **Retry All Failed**
  - When: Server recovered, transient errors resolved
  - Steps: Admin Console → Retry All Failed
  - Risk: May re-trigger failures

- [x] **Emergency Procedures**
  - Mass 5xx errors: Circuit breaker trip, wait for recovery
  - Database corruption: Export → Delete → Restore
  - Processing lock deadlock: Force release → Monitor

**Team Training:**
- [ ] All team members reviewed runbook
- [ ] At least 2 team members practiced each procedure
- [ ] Emergency contact list up-to-date
- [ ] Escalation path defined

---

## Security & Compliance Checklist

### Transport Security
- [x] TLS enforced for all requests (no fallback to HTTP)
- [x] Certificate pinning implemented (optional but recommended)
- [x] Minimum TLS version 1.2
- [x] Strong cipher suites configured

**Validation:**
```dart
// Check TLS enforcement
test('TLS enforced', () {
  final httpUrl = 'http://api.example.com';
  expect(SecurityUtils.isTlsEnabled(httpUrl), false);

  final httpsUrl = 'https://api.example.com';
  expect(SecurityUtils.isTlsEnabled(httpsUrl), true);
});
```

---

### Authentication & Authorization
- [x] Tokens not logged in cleartext
- [x] Tokens masked in logs (last 4 chars only)
- [x] Token refresh flow secure
- [x] Expired tokens handled gracefully

**Validation:**
```bash
# Search logs for token leakage
grep -r "Bearer " logs/ | grep -v "Bea..."
# Expected: No results

# Check token masking
grep -r "Authorization" logs/
# Expected: Authorization: Bea...xyz
```

---

### Data Protection
- [x] Idempotency keys are UUIDv4 and not guessable
- [x] Logs redact patient vitals, PII, authentication info
- [x] Backups are AES-encrypted
- [x] Encryption keys stored in secure storage (flutter_secure_storage)
- [x] No sensitive data in crash reports

**PII Redaction Validation:**
```dart
test('PII redacted in all logs', () {
  final testCases = [
    'user@example.com',
    '555-123-4567',
    '123-45-6789',
    'patient_vital_value',
  ];

  for (final sensitive in testCases) {
    final redacted = SecurityUtils.redactPii(sensitive);
    expect(redacted, isNot(contains(sensitive)));
  }
});
```

---

### Data Deletion & Compliance
- [x] Data deletion/erasure endpoints work
- [x] Local data + keys removed on account deletion
- [x] GDPR Article 17 (Right to Erasure) compliance
- [x] HIPAA secure deletion requirements met
- [x] Audit trail for deletions

**Validation:**
```dart
test('GDPR erasure compliance', () async {
  // 1. Setup user data
  await seedUserData(userId);

  // 2. User requests deletion
  await userService.deleteAccount(userId);

  // 3. Verify data erased
  final boxes = [pendingBox, failedBox, auditBox];
  for (final box in boxes) {
    final data = await box.get(userId);
    expect(data, isNull);
  }

  // 4. Verify keys erased
  final keys = await FlutterSecureStorage().readAll();
  expect(keys, isEmpty);

  // 5. Verify audit log
  final auditLog = await getAuditLog(userId);
  expect(auditLog.events, contains('account_deleted'));
});
```

---

### Code Security
- [ ] No credentials hardcoded in source
- [ ] API keys in environment variables or secure config
- [ ] Static analysis passed (no security warnings)
- [ ] Dependency vulnerability scan passed

**Validation:**
```bash
# Search for hardcoded secrets
grep -r "api_key\|password\|secret" lib/ | grep -v "REDACTED"

# Static analysis
flutter analyze

# Dependency audit
flutter pub outdated
```

---

## Acceptance Criteria (Final Sign-Off)

**Only mark "complete" if ALL the following hold:**

### ✅ Functional
- [ ] End-to-end case validated:
  - Offline action persisted
  - Online → Server processed once
  - UI reconciled without duplicate side-effect
- [ ] All critical paths tested (success, retry, failure, conflict)

### ✅ Reliability
- [ ] Retry/backoff behavior tested under intermittent network
- [ ] System recovers automatically from 5xx storms
- [ ] Circuit breaker protects API from overload

### ✅ Safety
- [ ] Idempotency-protected (no duplicate server side-effects)
- [ ] Crash-resume test passed (at-most-once delivery)
- [ ] Lock mechanism prevents concurrent processing

### ✅ Observability
- [ ] Metrics exported (Prometheus format)
- [ ] Logs structured with required fields
- [ ] Alerting configured and tested
- [ ] Dashboards created in monitoring system

### ✅ Security
- [ ] Encryption for sensitive boxes
- [ ] Keys in secure storage
- [ ] Logs redacted (PII/tokens)
- [ ] TLS enforced
- [ ] Secure deletion works

### ✅ Documentation
- [ ] Runbook complete and reviewed
- [ ] Migration docs exist
- [ ] Admin tools documented
- [ ] Testing scripts accessible
- [ ] API documentation up-to-date

### ✅ Testing
- [ ] Unit tests pass (100% of critical paths)
- [ ] Integration tests pass
- [ ] Load tests pass (within performance SLA)
- [ ] Fault-injection tests pass
- [ ] Security tests pass
- [ ] CI/CD green

---

## Example Validation Scenarios

### Scenario 1: Happy Path

**Steps:**
1. ✅ Create device toggle while offline
2. ✅ Confirm op saved in pending_ops_box
3. ✅ Visible in Admin UI
4. ✅ Bring device online
5. ✅ SyncEngine processes op
6. ✅ Server reflects change
7. ✅ Op removed from pending_ops_box
8. ✅ UI shows success
9. ✅ Optimistic txnToken cleared

**Expected Metrics:**
- pending_ops_gauge: 1 → 0
- processed_ops_total: +1
- avg_processing_time_ms: < 5000

---

### Scenario 2: Transient Server Errors

**Steps:**
1. ✅ Mock server responds 429 with `Retry-After: 4`
2. ✅ Action enqueued
3. ✅ Processor attempts → RetryableException
4. ✅ Sets nextAttemptAt = now + 4s
5. ✅ After 4s, processor retries
6. ✅ Server responds 200
7. ✅ Op marked processed

**Expected Behavior:**
- Backoff delay observed (4s + jitter)
- No immediate retry
- Eventual success

**Expected Metrics:**
- backoff_events_total: +1
- retries_total: +1
- processed_ops_total: +1 (eventually)

---

### Scenario 3: Auth Refresh

**Steps:**
1. ✅ Simulate expired token
2. ✅ Server returns 401 on first request
3. ✅ ApiClient triggers `authService.tryRefresh()`
4. ✅ Refresh succeeds
5. ✅ Re-sends request with new token
6. ✅ Request succeeds
7. ✅ If refresh fails:
   - ✅ Op moved to failed_ops
   - ✅ Auth error surfaced to UI

**Expected Logs:**
```
[INFO] Token expired, attempting refresh...
[INFO] Token refresh successful, retrying request
[INFO] Request succeeded with new token
```

**Expected Metrics:**
- auth_refresh_total{success=true}: +1
- processed_ops_total: +1

---

### Scenario 4: Crash-Resume

**Steps:**
1. ✅ Start processing op
2. ✅ Before `markProcessed()`, crash app
3. ✅ Restart app
4. ✅ Processor resumes
5. ✅ Re-sends op with same idempotencyKey
6. ✅ Assert server processed at most once

**Server Verification:**
```sql
-- Check server database
SELECT COUNT(*) FROM devices WHERE id = 'device-123' AND state = 'on';
-- Expected: 1 (not 2)

-- Check idempotency log
SELECT COUNT(*) FROM idempotency_log 
WHERE idempotency_key = '550e8400-e29b-41d4-a716-446655440000';
-- Expected: 2 (same key sent twice)

SELECT COUNT(*) FROM idempotency_log 
WHERE idempotency_key = '550e8400-e29b-41d4-a716-446655440000' 
AND was_processed = true;
-- Expected: 1 (only first processed)
```

---

### Scenario 5: Conflict (409)

**Steps:**
1. ✅ Server responds 409
2. ✅ Reconciler fetches server resource
3. ✅ Computes merge strategy
4. ✅ Re-enqueues with merged state
5. ✅ Or marks op resolved
6. ✅ Show user readable resolution if manual input required

**Test Case:**
```dart
// Client wants: brightness = 75
// Server has: brightness = 60, version = 5

// Merge strategies:
// 1. client_wins: brightness = 75
// 2. server_wins: brightness = 60
// 3. max: brightness = max(60, 75) = 75
// 4. manual: prompt user to resolve

// Expected outcome:
final resolvedOp = await reconciler.resolve(op, serverState);
expect(resolvedOp.payload['brightness'], 75);
expect(resolvedOp.payload['version'], 5);
```

---

### Scenario 6: Mass Failures → Circuit Breaker

**Steps:**
1. ✅ Force many 5xx errors (simulate server down)
2. ✅ Breaker trips after N failures
3. ✅ Halts processing for cooldown period
4. ✅ After cooldown, sends probe request
5. ✅ If probe succeeds:
   - ✅ Circuit closes
   - ✅ Resume normal processing
6. ✅ If probe fails:
   - ✅ Circuit remains open
   - ✅ Extend cooldown

**Test Implementation:**
```dart
test('circuit breaker protects API', () async {
  // Simulate 20 consecutive 5xx errors
  for (int i = 0; i < 20; i++) {
    mockApi.setResponse(500);
    await syncEngine.processNext();
  }

  // Verify circuit tripped
  expect(circuitBreaker.isOpen, true);
  expect(circuitBreaker.state, CircuitBreakerState.open);

  // Verify processing halted
  final attemptedDuringOpen = await syncEngine.processNext();
  expect(attemptedDuringOpen, false); // Fail-fast

  // Wait for cooldown
  await Future.delayed(circuitBreaker.cooldown);

  // Verify half-open state
  expect(circuitBreaker.state, CircuitBreakerState.halfOpen);

  // Probe succeeds
  mockApi.setResponse(200);
  await syncEngine.processNext();

  // Verify circuit closed
  expect(circuitBreaker.isOpen, false);
  expect(circuitBreaker.state, CircuitBreakerState.closed);
});
```

**Expected Metrics:**
- circuit_tripped_total: +1
- failed_ops_total: 20 (before trip)
- circuit_recovered_total: +1 (after probe success)

---

## Sign-Off Template

**Project:** Guardian Angel Sync Engine  
**Phase:** 4 - Operationalization Complete  
**Date:** _____________  
**Signed By:** _____________

### Checklist Summary

| Category | Status | Notes |
|----------|--------|-------|
| Quick Pass | ☐ Pass ☐ Fail | |
| Phase 1 - Specs | ☐ Pass ☐ Fail | |
| Phase 2 - Core | ☐ Pass ☐ Fail | |
| Phase 3 - Reliability | ☐ Pass ☐ Fail | |
| Phase 4 - Hardening | ☐ Pass ☐ Fail | |
| Unit Tests | ☐ Pass ☐ Fail | |
| Integration Tests | ☐ Pass ☐ Fail | |
| Load Tests | ☐ Pass ☐ Fail | |
| Security Tests | ☐ Pass ☐ Fail | |
| Observability | ☐ Pass ☐ Fail | |
| Documentation | ☐ Pass ☐ Fail | |

### Acceptance Criteria

- [ ] Functional: End-to-end validated
- [ ] Reliability: Automatic recovery tested
- [ ] Safety: Idempotency protected
- [ ] Observability: Metrics/logs/alerts configured
- [ ] Security: Encryption, redaction, TLS enforced
- [ ] Documentation: Complete and accessible
- [ ] Testing: All tests pass

### Issues Found

| Issue | Severity | Status | Assignee |
|-------|----------|--------|----------|
| | | | |

### Approval

- [ ] **APPROVED** - Ready for production deployment
- [ ] **REJECTED** - Issues must be fixed before deployment

**Reviewer:** _____________  
**Date:** _____________  
**Signature:** _____________

---

**END OF IMPLEMENTATION CHECKLIST**

*For questions or clarifications, refer to:*
- Technical Documentation: `docs/`
- Operational Runbook: `docs/runbooks/sync_runbook.md`
- Phase 4 Summary: `PHASE_4_IMPLEMENTATION_COMPLETE.md`
