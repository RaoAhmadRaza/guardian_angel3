# Backoff Policy Specification

**Version:** 1.0.0  
**Last Updated:** November 22, 2025

---

## Overview

This document defines the exponential backoff strategy for retrying failed sync operations. The policy balances timely retries with server load reduction and battery conservation.

---

## Backoff Algorithm

### Formula

```
delay_ms = min(MAX_BACKOFF_MS, BASE_MS * 2^(attempts - 1) * jitter)
```

Where:
- `BASE_MS` = Base delay in milliseconds (configurable, default 1000ms)
- `attempts` = Current retry attempt number (1-indexed)
- `MAX_BACKOFF_MS` = Maximum delay cap (configurable, default 30000ms)
- `jitter` = Random multiplier between 0.5 and 1.5 (uniform distribution)

### Components

#### Base Delay (`BASE_MS`)
**Default:** 1000ms (1 second)  
**Purpose:** Starting point for exponential growth  
**Tuning:** Lower for latency-sensitive operations, higher for battery conservation

**Example Values:**
- **Aggressive:** 500ms (faster retries, more network usage)
- **Standard:** 1000ms (balanced)
- **Conservative:** 2000ms (slower retries, battery-friendly)

#### Exponential Growth (`2^(attempts - 1)`)
**Purpose:** Progressively increase delay to reduce server load  
**Behavior:**
- Attempt 1: 2^0 = 1x base delay
- Attempt 2: 2^1 = 2x base delay
- Attempt 3: 2^2 = 4x base delay
- Attempt 4: 2^3 = 8x base delay
- Attempt 5: 2^4 = 16x base delay

**Rationale:** Exponential growth prevents "thundering herd" during outages

#### Jitter (`0.5 to 1.5`)
**Purpose:** Randomize delays to avoid synchronized retries  
**Distribution:** Uniform random between 0.5 and 1.5  
**Generation:**
```dart
final jitter = 0.5 + Random().nextDouble(); // 0.5 to 1.5
```

**Rationale:** Prevents multiple clients from retrying at exact same time

#### Maximum Backoff (`MAX_BACKOFF_MS`)
**Default:** 30000ms (30 seconds)  
**Purpose:** Cap delay to avoid indefinite waits  
**Tuning:** Lower for user-facing operations, higher for background sync

**Example Values:**
- **User-initiated:** 10000ms (10s max wait)
- **Background sync:** 30000ms (30s max wait)
- **Batch operations:** 60000ms (1m max wait)

---

## Retry Limits

### Maximum Attempts
**Default:** 5 attempts  
**Purpose:** Prevent infinite retry loops  
**Rationale:** After 5 attempts with exponential backoff (~1 minute total), operation likely permanently failed

**Calculation:**
```
Total time ≈ BASE_MS * (2^0 + 2^1 + 2^2 + 2^3 + 2^4)
           = BASE_MS * (1 + 2 + 4 + 8 + 16)
           = BASE_MS * 31
           = 31 seconds (with BASE_MS = 1000)
```

**After Exhaustion:**
- Move operation to `failed_ops` queue
- Log permanent failure
- Notify user (if applicable)

---

## Delay Calculation Examples

### Example 1: Standard Backoff (BASE_MS = 1000, MAX_BACKOFF_MS = 30000)

| Attempt | Formula | Delay (no jitter) | Delay Range (with jitter) | Cumulative Time |
|---------|---------|-------------------|---------------------------|-----------------|
| 1 | 1000 * 2^0 * jitter | 1000ms | 500ms - 1500ms | 0.5s - 1.5s |
| 2 | 1000 * 2^1 * jitter | 2000ms | 1000ms - 3000ms | 1.5s - 4.5s |
| 3 | 1000 * 2^2 * jitter | 4000ms | 2000ms - 6000ms | 3.5s - 10.5s |
| 4 | 1000 * 2^3 * jitter | 8000ms | 4000ms - 12000ms | 7.5s - 22.5s |
| 5 | 1000 * 2^4 * jitter | 16000ms | 8000ms - 24000ms | 15.5s - 46.5s |

**Total Time:** ~15.5s to 46.5s before exhaustion

### Example 2: Aggressive Backoff (BASE_MS = 500, MAX_BACKOFF_MS = 10000)

| Attempt | Formula | Delay (no jitter) | Delay Range (with jitter) | Cumulative Time |
|---------|---------|-------------------|---------------------------|-----------------|
| 1 | 500 * 2^0 * jitter | 500ms | 250ms - 750ms | 0.25s - 0.75s |
| 2 | 500 * 2^1 * jitter | 1000ms | 500ms - 1500ms | 0.75s - 2.25s |
| 3 | 500 * 2^2 * jitter | 2000ms | 1000ms - 3000ms | 1.75s - 5.25s |
| 4 | 500 * 2^3 * jitter | 4000ms | 2000ms - 6000ms | 3.75s - 11.25s |
| 5 | min(500 * 2^4 * jitter, 10000) | 8000ms (capped at 10000) | 5000ms - 10000ms | 8.75s - 21.25s |

**Total Time:** ~8.75s to 21.25s before exhaustion

### Example 3: Conservative Backoff (BASE_MS = 2000, MAX_BACKOFF_MS = 30000)

| Attempt | Formula | Delay (no jitter) | Delay Range (with jitter) | Cumulative Time |
|---------|---------|-------------------|---------------------------|-----------------|
| 1 | 2000 * 2^0 * jitter | 2000ms | 1000ms - 3000ms | 1s - 3s |
| 2 | 2000 * 2^1 * jitter | 4000ms | 2000ms - 6000ms | 3s - 9s |
| 3 | 2000 * 2^2 * jitter | 8000ms | 4000ms - 12000ms | 7s - 21s |
| 4 | 2000 * 2^3 * jitter | 16000ms | 8000ms - 24000ms | 15s - 45s |
| 5 | min(2000 * 2^4 * jitter, 30000) | 30000ms (capped) | 16000ms - 30000ms | 31s - 75s |

**Total Time:** ~31s to 75s before exhaustion

---

## Special Cases

### Retry-After Header Override

When server returns `Retry-After` header (e.g., 429 or 503):

**Rule:** MUST respect `Retry-After` value, ignoring exponential backoff

**Example:**
```http
HTTP/1.1 429 Too Many Requests
Retry-After: 120

{
  "error": {
    "code": "RATE_LIMITED",
    "message": "Too many requests"
  }
}
```

**Client Behavior:**
```dart
if (response.headers['retry-after'] != null) {
  final retryAfterSeconds = int.parse(response.headers['retry-after']!);
  final delayMs = retryAfterSeconds * 1000;
  
  // Use Retry-After value, NOT exponential backoff
  await Future.delayed(Duration(milliseconds: delayMs));
  return retry();
}
```

**Rationale:** Server knows its capacity better than client heuristic

### Rate Limit Cascade Prevention

If multiple operations hit rate limit simultaneously:

**Problem:** All operations retry at same time, causing another rate limit

**Solution:** Add per-operation jitter to Retry-After value

```dart
final retryAfterMs = retryAfterSeconds * 1000;
final jitter = Random().nextDouble() * 5000; // 0-5s additional jitter
final delayMs = retryAfterMs + jitter;

await Future.delayed(Duration(milliseconds: delayMs.toInt()));
```

**Effect:** Spreads retries across 5-second window

### Auth Token Refresh (401)

**Special Case:** First retry after 401 should be immediate (after token refresh)

```dart
if (exception is UnauthorizedException && attemptCount == 1) {
  // Attempt token refresh
  await authService.refreshToken();
  
  // Immediate retry (no backoff)
  return retry();
}

// If second 401, use normal backoff
final delayMs = calculateBackoffDelay(attemptCount);
await Future.delayed(Duration(milliseconds: delayMs));
```

**Rationale:** Token refresh is quick; no need to wait

### Conflict Resolution (409)

**Special Case:** Don't retry automatically; trigger reconciliation flow

```dart
if (exception is ConflictException) {
  // Do NOT retry with backoff
  // Trigger conflict resolution UI
  await conflictResolver.resolve(operation);
  return; // User action required
}
```

**Rationale:** Automated retries won't resolve conflicts

---

## Implementation

### Dart Code

```dart
class BackoffManager {
  final int baseMs;
  final int maxBackoffMs;
  final int maxAttempts;
  final Random _random;
  
  BackoffManager({
    this.baseMs = 1000,
    this.maxBackoffMs = 30000,
    this.maxAttempts = 5,
    Random? random,
  }) : _random = random ?? Random();
  
  /// Calculate delay for given attempt number
  int calculateDelay(int attemptCount) {
    if (attemptCount < 1) {
      throw ArgumentError('attemptCount must be >= 1');
    }
    
    // Exponential component: 2^(attempts - 1)
    final exponential = math.pow(2, attemptCount - 1);
    
    // Jitter: random value between 0.5 and 1.5
    final jitter = 0.5 + _random.nextDouble();
    
    // Calculate delay with jitter
    final delayMs = (baseMs * exponential * jitter).toInt();
    
    // Cap at maximum
    return math.min(delayMs, maxBackoffMs);
  }
  
  /// Check if should retry based on attempt count
  bool shouldRetry(int attemptCount) {
    return attemptCount < maxAttempts;
  }
  
  /// Calculate delay respecting Retry-After header
  int calculateDelayWithRetryAfter(int attemptCount, int? retryAfterSeconds) {
    if (retryAfterSeconds != null) {
      // Honor server's Retry-After value
      final baseDelay = retryAfterSeconds * 1000;
      
      // Add small jitter (0-5s) to prevent cascade
      final jitter = _random.nextDouble() * 5000;
      
      return (baseDelay + jitter).toInt();
    }
    
    // Use exponential backoff
    return calculateDelay(attemptCount);
  }
  
  /// Total time until exhaustion (approximate, assuming average jitter)
  int estimateTotalTime() {
    int total = 0;
    for (int i = 1; i <= maxAttempts; i++) {
      final exponential = math.pow(2, i - 1);
      total += (baseMs * exponential).toInt();
    }
    return total;
  }
}

// Usage example
final backoffManager = BackoffManager();

for (int attempt = 1; attempt <= backoffManager.maxAttempts; attempt++) {
  try {
    final response = await apiClient.post('/users', payload);
    return response; // Success
  } on SyncException catch (e) {
    if (!e.isRetryable || !backoffManager.shouldRetry(attempt)) {
      rethrow; // Permanent error or exhausted retries
    }
    
    // Calculate delay
    final delayMs = e is RateLimitException
        ? backoffManager.calculateDelayWithRetryAfter(attempt, e.retryAfterSeconds)
        : backoffManager.calculateDelay(attempt);
    
    // Wait before retry
    await Future.delayed(Duration(milliseconds: delayMs));
  }
}
```

---

## Configuration

### Default Configuration

```dart
class BackoffConfig {
  final int baseMs;
  final int maxBackoffMs;
  final int maxAttempts;
  
  const BackoffConfig({
    this.baseMs = 1000,
    this.maxBackoffMs = 30000,
    this.maxAttempts = 5,
  });
  
  static const BackoffConfig standard = BackoffConfig();
  
  static const BackoffConfig aggressive = BackoffConfig(
    baseMs: 500,
    maxBackoffMs: 10000,
    maxAttempts: 5,
  );
  
  static const BackoffConfig conservative = BackoffConfig(
    baseMs: 2000,
    maxBackoffMs: 30000,
    maxAttempts: 5,
  );
  
  static const BackoffConfig background = BackoffConfig(
    baseMs: 2000,
    maxBackoffMs: 60000,
    maxAttempts: 7,
  );
}
```

### Per-Operation Configuration

Different operation types may use different backoff strategies:

```dart
final backoffConfig = switch (operation.type) {
  OperationType.userLogin => BackoffConfig.aggressive, // Fast retry for login
  OperationType.heartRate => BackoffConfig.standard, // Normal for health data
  OperationType.analytics => BackoffConfig.background, // Relaxed for non-critical
  _ => BackoffConfig.standard,
};
```

---

## Monitoring & Metrics

### Key Metrics

**Backoff Delays**
- `sync.backoff.delay.avg` - Average delay across all retries
- `sync.backoff.delay.p50` - Median delay
- `sync.backoff.delay.p99` - 99th percentile delay

**Retry Attempts**
- `sync.retries.count` - Total retry attempts
- `sync.retries.by_attempt` - Distribution by attempt number (1-5)
- `sync.retries.exhausted` - Operations that hit max attempts

**Success After Retry**
- `sync.retries.success_on_attempt_1` - Success on first retry
- `sync.retries.success_on_attempt_2` - Success on second retry
- `sync.retries.success_on_attempt_3` - Success on third retry
- `sync.retries.success_on_attempt_4` - Success on fourth retry
- `sync.retries.success_on_attempt_5` - Success on fifth retry

**Retry-After Respect**
- `sync.retry_after.honored` - Times Retry-After header was respected
- `sync.retry_after.value.avg` - Average Retry-After duration

### Logging

**What to Log:**
```dart
logger.info('Retrying operation after backoff', extra: {
  'operation_id': operation.id,
  'attempt': attemptCount,
  'delay_ms': delayMs,
  'exception_type': exception.runtimeType.toString(),
  'trace_id': operation.traceId,
});
```

**What NOT to Log:**
- User PII
- Full operation payloads
- Auth tokens

---

## Testing Recommendations

### Unit Tests

**Test Delay Calculation**
```dart
test('calculates exponential backoff correctly', () {
  final backoff = BackoffManager(baseMs: 1000, maxBackoffMs: 30000);
  
  // Attempt 1: 1000 * 2^0 = 1000 (with jitter: 500-1500)
  final delay1 = backoff.calculateDelay(1);
  expect(delay1, inRange(500, 1500));
  
  // Attempt 3: 1000 * 2^2 = 4000 (with jitter: 2000-6000)
  final delay3 = backoff.calculateDelay(3);
  expect(delay3, inRange(2000, 6000));
});

test('respects maximum backoff', () {
  final backoff = BackoffManager(baseMs: 1000, maxBackoffMs: 10000);
  
  // Attempt 5: 1000 * 2^4 = 16000, capped at 10000
  final delay5 = backoff.calculateDelay(5);
  expect(delay5, lessThanOrEqualTo(10000));
});

test('honors Retry-After header', () {
  final backoff = BackoffManager();
  
  final delay = backoff.calculateDelayWithRetryAfter(1, 120); // 120 seconds
  expect(delay, greaterThanOrEqualTo(120000)); // At least 2 minutes
  expect(delay, lessThan(125000)); // Less than 2m5s (jitter)
});
```

**Test Retry Logic**
```dart
test('stops after max attempts', () {
  final backoff = BackoffManager(maxAttempts: 3);
  
  expect(backoff.shouldRetry(1), true);
  expect(backoff.shouldRetry(2), true);
  expect(backoff.shouldRetry(3), false);
  expect(backoff.shouldRetry(4), false);
});
```

### Integration Tests

**Test Retry with Backoff**
```dart
testWidgets('retries operation with exponential backoff', (tester) async {
  final mockClient = MockApiClient();
  
  // Fail first 2 attempts, succeed on 3rd
  when(() => mockClient.post(any(), any()))
      .thenAnswer((invocation) async {
        final attempt = invocation.callCount;
        if (attempt < 3) {
          throw ServerException(message: 'Server error', httpStatus: 500);
        }
        return Response(data: {'status': 'success'});
      });
  
  final result = await retryWithBackoff(
    () => mockClient.post('/users', {}),
    backoffManager: BackoffManager(baseMs: 100), // Faster for testing
  );
  
  expect(result.data['status'], 'success');
  verify(() => mockClient.post(any(), any())).called(3);
});
```

### Performance Tests

**Verify Timing**
```dart
test('backoff delay is within expected range', () async {
  final backoff = BackoffManager(baseMs: 1000);
  final stopwatch = Stopwatch()..start();
  
  await Future.delayed(Duration(milliseconds: backoff.calculateDelay(2)));
  
  stopwatch.stop();
  // Attempt 2: 2000ms with jitter (1000-3000ms)
  expect(stopwatch.elapsedMilliseconds, inRange(900, 3100)); // Allow 100ms tolerance
});
```

---

## Best Practices

### Do's
✅ Use exponential backoff for all transient errors  
✅ Apply jitter to prevent thundering herd  
✅ Respect `Retry-After` headers  
✅ Cap delays with `MAX_BACKOFF_MS`  
✅ Limit retry attempts to prevent infinite loops  
✅ Log retry attempts for debugging  
✅ Configure backoff per operation criticality

### Don'ts
❌ Don't retry permanent errors (400, 404, etc.)  
❌ Don't ignore `Retry-After` headers  
❌ Don't use linear backoff (increases server load)  
❌ Don't retry indefinitely  
❌ Don't use fixed delays (causes synchronized retries)  
❌ Don't retry conflicts automatically (needs reconciliation)  
❌ Don't log sensitive data during retries

---

## Trade-offs

### Faster Retries (Lower BASE_MS)
**Pros:**
- Quicker recovery from transient failures
- Better user experience
- Lower perceived latency

**Cons:**
- Higher server load during outages
- More battery drain
- Higher network usage

### Slower Retries (Higher BASE_MS)
**Pros:**
- Lower server load
- Better battery life
- Reduced network usage

**Cons:**
- Slower recovery
- Higher perceived latency
- User may think operation failed

### Higher Max Attempts
**Pros:**
- More resilient to intermittent failures
- Better success rate

**Cons:**
- Longer total time before giving up
- More resource usage
- Delayed error feedback to user

### Lower Max Attempts
**Pros:**
- Faster feedback to user
- Less resource waste on doomed operations

**Cons:**
- May give up too early on transient issues
- Lower success rate

---

## References

- [Exponential Backoff And Jitter (AWS)](https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/)
- [RFC 7231 - Retry-After](https://tools.ietf.org/html/rfc7231#section-7.1.3)
- [Error Mapping Specification](error_mapping.md)
- [Test Matrix](test_matrix.md)

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-11-22 | Initial specification |
