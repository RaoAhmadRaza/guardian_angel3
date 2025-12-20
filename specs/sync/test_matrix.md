# Test Matrix Specification

**Version:** 1.0.0  
**Last Updated:** November 22, 2025

---

## Overview

This document defines the comprehensive test plan for the Guardian Angel Sync Engine. The matrix covers unit tests, integration tests, fault injection tests, and performance benchmarks across all sync components.

---

## Test Categories

### 1. Unit Tests
**Scope:** Individual components in isolation  
**Mocking:** External dependencies mocked  
**Coverage Target:** 85%+ line coverage

### 2. Integration Tests
**Scope:** Multiple components working together  
**Mocking:** Minimal (only backend API)  
**Coverage Target:** All critical paths tested

### 3. Fault Injection Tests
**Scope:** Failure scenarios and edge cases  
**Mocking:** Inject specific failures  
**Coverage Target:** All error types handled

### 4. Performance Tests
**Scope:** Load, throughput, latency  
**Environment:** Production-like setup  
**Coverage Target:** Meet performance SLAs

---

## Unit Test Matrix

### API Envelope Parsing

| Test Case | Input | Expected Output | Priority |
|-----------|-------|-----------------|----------|
| Parse valid request envelope | Valid JSON with meta + payload | Parsed envelope object | P0 |
| Parse valid response envelope (success) | Valid JSON with meta + data | Parsed response object | P0 |
| Parse valid response envelope (error) | Valid JSON with meta + error | Parsed error object | P0 |
| Reject missing `meta` field | JSON without meta | ValidationException | P0 |
| Reject missing `trace_id` | meta without trace_id | ValidationException | P0 |
| Reject invalid `trace_id` format | meta with non-UUID trace_id | ValidationException | P1 |
| Reject missing `timestamp` | meta without timestamp | ValidationException | P0 |
| Reject invalid `timestamp` format | meta with non-ISO8601 timestamp | ValidationException | P1 |
| Accept optional `txn_token` | meta without txn_token | Parsed successfully | P1 |
| Parse nested payload structures | Complex nested payload | All fields extracted | P1 |
| Handle UTF-8 characters | Payload with emoji/unicode | Correctly encoded | P2 |

### Error Mapping

| Test Case | HTTP Status | Expected Exception | Priority |
|-----------|-------------|-------------------|----------|
| Map 400 Bad Request | 400 | ValidationException | P0 |
| Map 401 Unauthorized | 401 | UnauthorizedException | P0 |
| Map 403 Forbidden | 403 | PermissionDeniedException | P0 |
| Map 404 Not Found | 404 | ResourceNotFoundException | P0 |
| Map 409 Conflict | 409 | ConflictException | P0 |
| Map 412 Precondition Failed | 412 | PreconditionFailedException | P1 |
| Map 415 Unsupported Media Type | 415 | ValidationException | P2 |
| Map 422 Unprocessable Entity | 422 | ValidationException | P1 |
| Map 426 Upgrade Required | 426 | ClientVersionException | P1 |
| Map 429 Too Many Requests | 429 | RateLimitException | P0 |
| Map 500 Internal Server Error | 500 | ServerException | P0 |
| Map 502 Bad Gateway | 502 | ServerException | P1 |
| Map 503 Service Unavailable | 503 | ServiceUnavailableException | P0 |
| Map 504 Gateway Timeout | 504 | TimeoutException | P1 |
| Map unknown status code | 999 | ServerException (default) | P2 |
| Parse error details (validation) | 400 with field/constraint | ValidationException with details | P1 |
| Parse error details (conflict) | 409 with versions | ConflictException with versions | P1 |
| Parse error details (rate limit) | 429 with retry_after | RateLimitException with delay | P0 |
| Classify as transient | 500/502/503/504 | isRetryable = true | P0 |
| Classify as permanent | 400/404/403 | isRetryable = false | P0 |

### Backoff Policy

| Test Case | Input | Expected Output | Priority |
|-----------|-------|-----------------|----------|
| Calculate delay for attempt 1 | attempt=1, base=1000ms | 500-1500ms (jitter) | P0 |
| Calculate delay for attempt 2 | attempt=2, base=1000ms | 1000-3000ms | P0 |
| Calculate delay for attempt 3 | attempt=3, base=1000ms | 2000-6000ms | P0 |
| Calculate delay for attempt 5 | attempt=5, base=1000ms | 8000-24000ms | P0 |
| Respect max backoff cap | attempt=10, max=30000ms | ≤30000ms | P0 |
| Apply jitter correctly | Multiple calls | Different values (0.5-1.5 range) | P1 |
| Honor Retry-After header | retryAfter=120s | 120000-125000ms (with jitter) | P0 |
| Stop after max attempts | attempt=6, max=5 | shouldRetry = false | P0 |
| Estimate total time | base=1000, max_attempts=5 | ~31 seconds | P2 |
| Handle base=0 | base=0, attempt=1 | 0ms | P2 |
| Handle attempt=0 | attempt=0 | ArgumentError | P2 |
| Aggressive config | base=500, max=10000 | Faster delays | P1 |
| Conservative config | base=2000, max=30000 | Slower delays | P1 |

### Idempotency Service

| Test Case | Input | Expected Output | Priority |
|-----------|-------|-----------------|----------|
| Generate valid UUID v4 | N/A | Valid UUID v4 format | P0 |
| Generate unique keys | Generate 1000 keys | All unique | P0 |
| Mark operation as succeeded | idempotency_key | hasSucceeded() = true | P0 |
| Check non-existent key | Random key | hasSucceeded() = false | P0 |
| Persist success across restarts | Mark, restart, check | Still succeeded | P0 |
| Cleanup old entries | Keys > 24h old | Removed from storage | P1 |
| Handle concurrent marks | Two threads mark same key | No errors | P2 |
| Storage limit | 10k+ keys | No memory overflow | P2 |

### Operation Router

| Test Case | Operation Type | Expected Endpoint | Priority |
|-----------|----------------|-------------------|----------|
| Route CREATE_USER | createUser | POST /api/v1/users | P0 |
| Route UPDATE_USER | updateUser | PUT /api/v1/users/{user_id} | P0 |
| Route DELETE_USER | deleteUser | DELETE /api/v1/users/{user_id} | P0 |
| Route CREATE_ROOM | createRoom | POST /api/v1/rooms | P0 |
| Route UPDATE_ROOM | updateRoom | PUT /api/v1/rooms/{room_id} | P0 |
| Route CREATE_DEVICE | createDevice | POST /api/v1/devices | P0 |
| Route RECORD_HEART_RATE | recordHeartRate | POST /api/v1/health/heart-rate | P0 |
| Extract path parameter | {room_id: "123"} | Path: /rooms/123 | P0 |
| Transform camelCase → snake_case | displayName | display_name | P0 |
| Transform DateTime → ISO8601 | DateTime(2025,11,22) | "2025-11-22T00:00:00.000Z" | P0 |
| Parse snake_case → camelCase | user_id | userId | P0 |
| Parse ISO8601 → DateTime | "2025-11-22T12:00:00Z" | DateTime object | P0 |
| Handle missing path param | No room_id for update | ValidationException | P0 |
| Handle unknown operation type | OperationType.unknown | ValidationException | P1 |
| Include auth header | Any operation | Authorization: Bearer ... | P0 |
| Include idempotency header | Any operation | Idempotency-Key: ... | P0 |

---

## Integration Test Matrix

### Queue Processor + API Client

| Test Case | Scenario | Expected Behavior | Priority |
|-----------|----------|-------------------|----------|
| Process single operation | 1 pending op | Successfully processed, removed from queue | P0 |
| Process multiple operations (FIFO) | 5 pending ops | Processed in order | P0 |
| Retry transient failure | Network error | Retry with backoff, eventually succeed | P0 |
| Move permanent failure to failed_ops | 400 error | Moved to failed_ops, removed from pending | P0 |
| Handle concurrent processing | Two processors | Second processor waits (lock held) | P1 |
| Survive app restart | Operation in-flight | Resumes after restart | P0 |
| Respect idempotency | Retry same operation | No duplicate side-effects | P0 |
| Handle rate limit | 429 error | Wait Retry-After duration, then retry | P0 |
| Handle token refresh | 401 error | Refresh token, retry once | P0 |
| Trigger conflict resolution | 409 error | Conflict resolver invoked | P1 |
| Process optimistic update | Operation with txn_token | UI updated on success | P1 |
| Rollback on failure | Permanent error | Optimistic update rolled back | P1 |

### Backoff + Retry Logic

| Test Case | Scenario | Expected Behavior | Priority |
|-----------|----------|-------------------|----------|
| Exponential backoff timing | 500 errors | Delays increase exponentially | P0 |
| Jitter distribution | 100 retries | Delays spread across jitter range | P1 |
| Retry-After override | 429 with Retry-After | Use Retry-After, not backoff | P0 |
| Max attempts exhaustion | 500 errors on all attempts | Stop after 5 attempts | P0 |
| Permanent error no retry | 400 error | No retry attempt | P0 |
| Auth refresh immediate retry | 401 error | Immediate retry after refresh | P1 |

### Idempotency (Client + Server)

| Test Case | Scenario | Expected Behavior | Priority |
|-----------|----------|-------------------|----------|
| Duplicate prevention (same key) | Send same key twice | Server returns cached response | P0 |
| Concurrent request handling | Two simultaneous requests | One processes, one gets 409 | P1 |
| Key expiry (after 24h) | Retry after TTL | Server processes again | P2 |
| Local success tracking | Success, retry locally | Skipped (local cache hit) | P1 |
| Modified operation new key | Payload changed | New key generated | P1 |

---

## Fault Injection Test Matrix

### Network Failures

| Test Case | Injected Fault | Expected Behavior | Priority |
|-----------|----------------|-------------------|----------|
| Connection timeout | Timeout after 30s | NetworkException, retry with backoff | P0 |
| Connection refused | Server unreachable | NetworkException, retry with backoff | P0 |
| DNS resolution failure | Hostname not found | NetworkException, retry with backoff | P1 |
| TLS handshake failure | Invalid certificate | NetworkException, retry 1-2 times | P2 |
| Intermittent connectivity | Network on/off | Queue operations, sync when online | P0 |
| Slow network | High latency | Timeout, retry with backoff | P1 |

### Server Failures

| Test Case | Injected Fault | Expected Behavior | Priority |
|-----------|----------------|-------------------|----------|
| Server 500 error | Internal server error | Retry with backoff (max 5) | P0 |
| Server 503 unavailable | Service down | Retry with backoff, respect Retry-After | P0 |
| Server 504 timeout | Gateway timeout | Retry with backoff | P1 |
| Rate limit (429) | Too many requests | Wait Retry-After, then retry | P0 |
| Rate limit cascade | Multiple ops hit limit | Spread retries with jitter | P1 |
| Server crash mid-request | No response | Timeout, retry with backoff | P1 |

### Data Corruption

| Test Case | Injected Fault | Expected Behavior | Priority |
|-----------|----------------|-------------------|----------|
| Malformed JSON response | Invalid JSON | Parsing error, retry | P1 |
| Missing required fields | Response without user_id | Parsing error, retry | P1 |
| Incorrect data types | String instead of int | Parsing error, retry | P2 |
| Corrupted Hive storage | Corrupted pending_ops box | Detect, log, skip operation | P2 |
| Invalid operation payload | Missing required field | ValidationException, move to failed_ops | P1 |

### Race Conditions

| Test Case | Injected Fault | Expected Behavior | Priority |
|-----------|----------------|-------------------|----------|
| Concurrent queue processors | Two processors start | One acquires lock, other waits | P0 |
| Stale lock takeover | Processor crashes with lock | New processor takes over after timeout | P0 |
| Concurrent idempotency keys | Same key from two devices | One processes, one gets cached response | P1 |
| Optimistic update conflict | User edits during sync | Conflict resolution triggered | P1 |

### Resource Exhaustion

| Test Case | Injected Fault | Expected Behavior | Priority |
|-----------|----------------|-------------------|----------|
| Memory limit | 10k+ pending ops | Batch processing, bounded memory | P1 |
| Storage limit | Disk full | Graceful failure, user notified | P2 |
| Battery drain | Low battery | Reduce retry frequency | P2 |
| CPU throttling | High CPU usage | Backpressure, slow processing | P2 |

---

## Performance Test Matrix

### Throughput Tests

| Test Case | Load | Success Criteria | Priority |
|-----------|------|------------------|----------|
| Single operation latency | 1 op | < 2s (p95) | P0 |
| Queue processing rate | 100 ops | > 10 ops/sec | P0 |
| Burst handling | 1000 ops in 10s | All queued, no loss | P1 |
| Sustained load | 10k ops over 1h | No memory growth | P1 |

### Latency Tests

| Test Case | Scenario | Success Criteria | Priority |
|-----------|----------|------------------|----------|
| Enqueue latency | Add to pending_ops | < 50ms (p99) | P0 |
| Process latency (success) | Network + parse | < 2s (p95) | P0 |
| Process latency (retry) | 1 retry | < 5s (p95) | P1 |
| Idempotency lookup | Cache hit | < 10ms | P1 |

### Memory Tests

| Test Case | Scenario | Success Criteria | Priority |
|-----------|----------|------------------|----------|
| Idle memory usage | No operations | < 10MB | P1 |
| Active processing | 100 ops in queue | < 50MB | P0 |
| Peak memory | 10k ops in queue | < 200MB | P1 |
| Memory leak check | Process 100k ops | No memory growth | P1 |

### Battery Tests

| Test Case | Scenario | Success Criteria | Priority |
|-----------|----------|------------------|----------|
| Active sync battery drain | 1h of syncing | < 2% battery | P1 |
| Background sync | 24h background | < 5% battery | P1 |
| Retry battery impact | 100 retries | Minimal impact (< 0.5%) | P2 |

---

## Test Vectors

See `test_vectors/` directory for JSON fixtures:

### pending_op_valid.json
**Purpose:** Valid operation example  
**Use Cases:**
- Unit tests for serialization/deserialization
- Integration tests for happy path
- Baseline for performance tests

### pending_op_retry_after.json
**Purpose:** Operation that triggers 429 rate limit  
**Use Cases:**
- Test Retry-After header handling
- Test rate limit backoff override
- Test cascade prevention

### pending_op_corrupt.json
**Purpose:** Malformed operation with invalid payload  
**Use Cases:**
- Test error handling
- Test validation logic
- Test failed_ops migration

---

## Coverage Requirements

### Code Coverage

**Minimum Coverage by Component:**
- API Client: 85%
- Queue Processor: 90%
- Backoff Manager: 95%
- Idempotency Service: 90%
- Operation Router: 85%
- Error Mapping: 100%

**Overall Target:** 85% line coverage

### Path Coverage

**Critical Paths (100% coverage required):**
- Happy path (enqueue → process → success)
- Retry path (transient error → backoff → retry → success)
- Failure path (permanent error → failed_ops)
- Idempotency path (duplicate → cached response)
- Auth refresh path (401 → refresh → retry)

**Important Paths (90% coverage required):**
- Conflict resolution
- Rate limit handling
- Lock acquisition/release
- Optimistic update rollback

---

## Test Execution Strategy

### Development (Local)

**Run Frequency:** On every commit  
**Test Scope:** Unit tests only  
**Duration:** < 2 minutes  
**Command:** `flutter test`

### Pre-Merge (CI)

**Run Frequency:** On every PR  
**Test Scope:** Unit + integration tests  
**Duration:** < 10 minutes  
**Command:** `flutter test && flutter test integration_test/`

### Nightly (CI)

**Run Frequency:** Daily at midnight  
**Test Scope:** All tests + fault injection  
**Duration:** < 30 minutes  
**Command:** `./scripts/run_full_tests.sh`

### Release (CI)

**Run Frequency:** Before each release  
**Test Scope:** All tests + performance benchmarks  
**Duration:** < 1 hour  
**Command:** `./scripts/run_release_tests.sh`

---

## Test Data Management

### Fixtures

**Location:** `test/fixtures/`  
**Format:** JSON files  
**Naming:** `{entity}_{scenario}.json`  
**Examples:**
- `user_valid.json`
- `room_with_devices.json`
- `heart_rate_batch.json`

### Mock Data

**Location:** `test/mocks/`  
**Format:** Dart classes  
**Naming:** `Mock{ClassName}`  
**Examples:**
- `MockApiClient`
- `MockIdempotencyService`
- `MockAuthService`

### Test Database

**Storage:** In-memory Hive boxes  
**Lifecycle:** Created per test, destroyed after  
**Isolation:** Each test gets fresh database

---

## Continuous Integration

### GitHub Actions Workflow

```yaml
name: Test Suite

on: [push, pull_request]

jobs:
  unit_tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter test
      
  integration_tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter test integration_test/
      
  performance_tests:
    runs-on: ubuntu-latest
    if: github.event_name == 'release'
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter test test/performance/
```

---

## Success Metrics

### Test Reliability
- **Flakiness Rate:** < 1% (tests pass/fail consistently)
- **False Positive Rate:** < 0.1% (no spurious failures)

### Test Coverage
- **Line Coverage:** > 85%
- **Branch Coverage:** > 80%
- **Critical Path Coverage:** 100%

### Test Performance
- **Unit Test Duration:** < 2 minutes
- **Integration Test Duration:** < 10 minutes
- **Full Suite Duration:** < 30 minutes

### Test Maintainability
- **Test-to-Code Ratio:** 1.5:1 to 2:1
- **Test Complexity:** Low (simple, focused tests)
- **Test Independence:** 100% (no shared state)

---

## Debugging Failed Tests

### Identify Failure Type

**Unit Test Failure:**
1. Check test assertions (expected vs actual)
2. Review mocked dependencies
3. Verify test data validity

**Integration Test Failure:**
1. Check logs for exception stack traces
2. Verify mock API responses
3. Check database state

**Fault Injection Test Failure:**
1. Verify fault was properly injected
2. Check error handling logic
3. Review retry/backoff behavior

**Performance Test Failure:**
1. Check system load during test
2. Review performance metrics
3. Compare against baseline

### Reproduction Steps

1. **Isolate:** Run failed test in isolation
2. **Debug:** Add print statements or breakpoints
3. **Verify:** Ensure test setup is correct
4. **Fix:** Address root cause
5. **Re-test:** Verify fix resolves failure

---

## References

- [API Envelope Specification](api_envelope.md)
- [Error Mapping Specification](error_mapping.md)
- [Backoff Policy Specification](backoff_policy.md)
- [Idempotency Policy Specification](idempotency_policy.md)
- [Operation Router Specification](op_router.md)

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-11-22 | Initial specification |
