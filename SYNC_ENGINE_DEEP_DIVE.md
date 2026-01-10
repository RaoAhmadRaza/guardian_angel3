# Sync Engine Deep Dive

**Purpose:** Complete technical reference for the sync engine  
**Date:** January 10, 2026

---

## 🔄 What is the Sync Engine?

The sync engine is the core system that keeps the app in sync with the backend despite network outages, crashes, conflicts, and race conditions. It's the "intelligent queue" that makes offline-first architecture possible.

### Core Principle: Work Queue

Instead of making API calls directly, all backend operations are:

1. **Enqueued** locally in Hive
2. **Dequeued** one at a time by the processor
3. **Sent** to the backend
4. **Marked** complete or failed
5. **Retried** on failure with exponential backoff

This ensures:
- ✅ No data loss (survives crashes)
- ✅ Idempotent (no duplicates)
- ✅ FIFO order (operations in sequence)
- ✅ Automatic recovery (crash-resume)

---

## 📦 Operation Model

### PendingOp Structure

```dart
class PendingOp {
  final String id;                    // Unique ID (UUID)
  final String opType;                // CREATE, UPDATE, DELETE, TOGGLE
  final String entityType;            // device, room, vitals, user
  Map<String, dynamic> payload;       // Operation data
  DateTime createdAt;                 // When created
  DateTime updatedAt;                 // Last modified
  int attempts;                       // Retry count
  String status;                      // queued, processing, completed, failed
  String? lastError;                  // Error message from last attempt
  DateTime? lastTriedAt;              // When we last tried
  DateTime? nextAttemptAt;            // When to retry (for backoff)
  String idempotencyKey;              // For server deduplication
  String? traceId;                    // For distributed tracing
  String? txnToken;                   // For optimistic UI rollback
}
```

### Operation Lifecycle

```
1. ENQUEUE
   User action (e.g., "Create device")
   ↓
   Operation created with status='queued'
   ↓
   Stored in Hive box
   ↓
   Optimistic update applied to UI

2. DEQUEUE
   Processing loop picks up operation
   ↓
   Status changed to 'processing'
   ↓
   Route resolved (opType + entityType → HTTP method + path)
   ↓
   Payload transformed (app-specific → API format)

3. SEND
   HTTP request created with headers:
   - Authorization: Bearer {token}
   - X-Idempotency-Key: {idempotencyKey}
   - Trace-Id: {traceId}
   - X-App-Version: {appVersion}
   ↓
   Request sent via ApiClient

4. RESPONSE
   Response received:
   
   ├─ 2xx Success
   │  ├─ Mark operation complete
   │  ├─ Commit optimistic update
   │  ├─ Record metrics (latency, success)
   │  └─ Move to next operation
   │
   ├─ 401 Unauthorized
   │  ├─ Refresh token via AuthService
   │  ├─ Retry request with new token
   │  └─ If refresh fails, mark failed
   │
   ├─ 409 Conflict
   │  ├─ Call Reconciler
   │  ├─ Fetch server state
   │  ├─ Merge local changes
   │  ├─ Update operation payload
   │  ├─ Retry request
   │  └─ If reconciliation succeeds, operation succeeds
   │
   ├─ 429 Rate Limited
   │  ├─ Extract Retry-After header (if present)
   │  ├─ Compute backoff delay
   │  ├─ Schedule retry
   │  └─ Move to next operation
   │
   ├─ 5xx Server Error
   │  ├─ Record error
   │  ├─ Increment failure count
   │  ├─ Check circuit breaker
   │  ├─ Compute backoff
   │  ├─ Schedule retry
   │  └─ Move to next
   │
   └─ Other Error
      ├─ Log error
      ├─ Mark operation failed
      ├─ Rollback optimistic update
      └─ Move to next

5. RETRY LOOP
   If operation not completed:
   ├─ Compute next retry time via BackoffPolicy
   ├─ Set nextAttemptAt timestamp
   ├─ Add back to queue
   ├─ Wait for scheduled time
   └─ Re-dequeue and retry
   
   Until:
   - Operation succeeds
   - Max retries exceeded (mark failed)
   - Unrecoverable error (mark failed)
```

---

## 🔐 Processing Lock

**Problem:** What if the app is running on two devices for the same user?  
**Solution:** Only one processor can run at a time

### Lock Implementation

```dart
class ProcessingLock {
  /// Acquire lock with TTL
  /// Returns: true if acquired, false if already held
  Future<bool> tryAcquire(String runnerId) async {
    final lockBox = Hive.box('processing_lock');
    
    // Check if lock exists and is valid
    if (lockBox.containsKey('lock')) {
      final lockData = lockBox.get('lock');
      final expiresAt = DateTime.parse(lockData['expires_at']);
      
      if (DateTime.now().isBefore(expiresAt)) {
        return false; // Lock still held
      }
      // Lock expired, proceed
    }
    
    // Acquire lock with 5-minute TTL
    lockBox.put('lock', {
      'runner_id': runnerId,
      'acquired_at': DateTime.now().toIso8601String(),
      'expires_at': DateTime.now().add(Duration(minutes: 5)).toIso8601String(),
    });
    
    return true;
  }

  /// Release lock
  Future<void> release(String runnerId) async {
    final lockBox = Hive.box('processing_lock');
    if (lockBox.containsKey('lock')) {
      final lockData = lockBox.get('lock');
      if (lockData['runner_id'] == runnerId) {
        await lockBox.delete('lock');
      }
    }
  }

  /// Heartbeat to extend lock TTL
  Future<void> heartbeat(String runnerId) async {
    final lockBox = Hive.box('processing_lock');
    if (lockBox.containsKey('lock')) {
      final lockData = lockBox.get('lock');
      if (lockData['runner_id'] == runnerId) {
        lockData['expires_at'] = DateTime.now()
          .add(Duration(minutes: 5))
          .toIso8601String();
        await lockBox.put('lock', lockData);
      }
    }
  }
}
```

### Lock Heartbeat

The processing loop sends a heartbeat every 30 seconds to keep the lock alive:

```
Loop:
  1. Acquire lock (5 min TTL)
  2. Process operation
  3. Send heartbeat (extend to 5 min)
  4. Sleep 30 seconds
  5. Repeat
  
If app crashes:
  1. Lock expires after 5 minutes
  2. Alternate device acquires lock
  3. Processor starts on alternate device
  4. Operations resume
```

---

## ⏱️ Backoff Policy

**Problem:** Retrying too fast hammers the backend  
**Solution:** Exponential backoff with jitter

### Algorithm

```dart
class BackoffPolicy {
  final int baseMs;           // Base delay (default: 100ms)
  final int maxBackoffMs;     // Max delay (default: 5000ms)
  final Random random;        // For jitter

  /// Compute delay for attempt N
  /// Formula: min(base * 2^N + jitter, max)
  int computeDelay(int attemptNumber, String? reason) {
    // Exponential: 100, 200, 400, 800, 1600, 3200
    final exponential = baseMs * (1 << attemptNumber); // 2^N
    
    // Jitter: random 0-100ms
    final jitter = random.nextInt(100);
    
    // Capped
    final delay = exponential + jitter;
    return delay > maxBackoffMs ? maxBackoffMs : delay;
  }
}
```

### Example Retry Schedule

```
Attempt 1: 100ms
Attempt 2: 200ms
Attempt 3: 400ms
Attempt 4: 800ms
Attempt 5: 1600ms
Attempt 6: 3200ms (capped at 5000ms)
Attempt 7: 5000ms
Attempt 8: 5000ms
... (max 5000ms for all subsequent retries)
```

### Respecting Retry-After Header

If the server returns a `Retry-After` header, we use that instead:

```dart
final response = await makeRequest();

if (response.statusCode == 429) {
  final retryAfter = response.headers['Retry-After'];
  if (retryAfter != null) {
    // Server says wait this long
    final delaySeconds = int.tryParse(retryAfter) ?? 60;
    nextAttemptAt = DateTime.now().add(Duration(seconds: delaySeconds));
  } else {
    // Use our backoff policy
    final delayMs = backoffPolicy.computeDelay(op.attempts, '429');
    nextAttemptAt = DateTime.now().add(Duration(milliseconds: delayMs));
  }
}
```

---

## 🚦 Circuit Breaker

**Problem:** If backend is down, keep hammering it = bad  
**Solution:** Stop making requests after N failures

### State Machine

```
CLOSED (normal operation)
  ├─ Success → stay CLOSED
  └─ N failures in window → trip OPEN

OPEN (stop making requests)
  ├─ Wait for cooldown
  └─ After cooldown → try HALF_OPEN

HALF_OPEN (testing recovery)
  ├─ Try one request
  ├─ Success → reset to CLOSED
  └─ Failure → go back OPEN
```

### Implementation

```dart
class CircuitBreaker {
  static const FAILURE_THRESHOLD = 10;  // Trip after 10 failures
  static const WINDOW = Duration(minutes: 1);
  static const COOLDOWN = Duration(minutes: 1);

  DateTime? _lastTrip;
  List<DateTime> _failures = [];

  void recordFailure() {
    final now = DateTime.now();
    _failures.add(now);
    
    // Remove old failures outside window
    _failures = _failures
      .where((t) => now.difference(t) <= WINDOW)
      .toList();
    
    // Trip if threshold exceeded
    if (_failures.length >= FAILURE_THRESHOLD) {
      _lastTrip = now;
      print('[CircuitBreaker] TRIPPED: ${_failures.length} failures');
    }
  }

  bool isTripped() {
    if (_lastTrip == null) return false;
    
    final elapsed = DateTime.now().difference(_lastTrip!);
    if (elapsed > COOLDOWN) {
      // Cooldown expired, reset
      _lastTrip = null;
      _failures.clear();
      print('[CircuitBreaker] Reset after cooldown');
      return false;
    }
    
    return true;
  }
}
```

### Processing Loop Check

```dart
while (_isRunning) {
  // Check circuit breaker
  if (circuitBreaker.isTripped()) {
    print('[SyncEngine] Circuit breaker tripped, sleeping');
    await Future.delayed(Duration(seconds: 5));
    continue;
  }

  // ... normal processing ...
  
  try {
    final response = await api.request(...);
    circuitBreaker.recordSuccess();
  } catch (e) {
    circuitBreaker.recordFailure();
    // ... retry logic ...
  }
}
```

---

## 🔗 Reconciliation (409 Conflict Resolution)

**Problem:** Two clients update same resource concurrently  
**Response:** Server returns 409 Conflict with current version

### Strategies

#### CREATE Conflict
```dart
// Operation: CREATE device with ID 'dev123'
// Server responds: 409 (resource already exists)

// Strategy: Check if resource exists and matches our intent
GET /devices/dev123
↓
If matches our data: Success! (idempotent create)
If differs: Failure (resource exists with different data)
```

#### UPDATE Conflict
```dart
// Operation: UPDATE device, version mismatch
// Server responds: 409 with current version

// Strategy: 3-way merge
1. Fetch current server state
2. Compare with our local state
3. Merge:
   - If we changed field X, keep our change
   - If we didn't change field Y, use server's change
   - Resolve conflicts (e.g., last-write-wins)
4. Retry with merged payload and new version
```

#### DELETE Conflict
```dart
// Operation: DELETE device
// Server responds: 409 (already deleted or changed)

// Strategy: Confirm deletion
GET /devices/{id}
↓
If not found (404): Success! (already deleted)
If found: Failure (couldn't delete)
```

### Implementation

```dart
class Reconciler {
  Future<bool> reconcileConflict(PendingOp op, ConflictException conflict) async {
    try {
      switch (op.opType.toUpperCase()) {
        case 'CREATE':
          return await _reconcileCreate(op, conflict);
        
        case 'UPDATE':
        case 'PATCH':
          return await _reconcileUpdate(op, conflict);
        
        case 'DELETE':
          return await _reconcileDelete(op, conflict);
        
        default:
          return false;
      }
    } catch (e) {
      print('[Reconciler] Failed: $e');
      return false;
    }
  }

  Future<bool> _reconcileUpdate(PendingOp op, ConflictException conflict) async {
    final id = op.payload['id'] as String?;
    if (id == null) return false;

    try {
      // Fetch server state
      final serverState = await api.request(
        method: 'GET',
        path: '/api/v1/${op.entityType}/$id',
      );

      // Merge: local changes override server
      final merged = <String, dynamic>{...serverState};
      
      for (final entry in op.payload.entries) {
        // Only override fields we explicitly set
        if (_isExplicitlySet(entry.key)) {
          merged[entry.key] = entry.value;
        }
      }

      // Update version from server
      merged['version'] = serverState['version'];

      // Update operation with merged payload
      op.payload = merged;

      return true; // Retry will use merged payload
    } catch (e) {
      return false;
    }
  }

  bool _isExplicitlySet(String field) {
    // Check if field was explicitly set by user
    // (vs. being a server-generated field)
    final systemFields = {'id', 'version', 'created_at', 'updated_at'};
    return !systemFields.contains(field);
  }
}
```

---

## 🎯 Optimistic Updates

**Problem:** User waits for network response to see UI change  
**Solution:** Update UI immediately, rollback if sync fails

### Transaction Token

Each optimistic update has a token to identify it:

```dart
final txnToken = const Uuid().v4();

// Register with optimistic store
optimisticStore.register(
  txnToken: txnToken,
  optimisticUpdate: newDevice,
  onCommit: () {
    // Called on success - UI keeps the change
    refreshDevicesList();
  },
  onRollback: () {
    // Called on failure - remove from UI
    removeFromUI(newDevice);
  },
);

// Enqueue operation
await syncEngine.enqueue(PendingOp(
  id: uuid.v4(),
  opType: 'CREATE',
  entityType: 'device',
  payload: newDevice.toMap(),
  txnToken: txnToken,  // Link to optimistic update
));
```

### UI Update Flow

```
User creates device
  ↓
txnToken = uuid.v4()
  ↓
optimisticStore.register(txnToken, ...)
  ↓
UI IMMEDIATELY shows device (optimistic)
  ↓
Operation enqueued
  ↓
Sync engine sends request
  ↓
Success:
  ├─ optimisticStore.commit(txnToken)
  ├─ onCommit callback
  ├─ UI keeps device
  └─ Next operation
  
Failure:
  ├─ optimisticStore.rollback(txnToken)
  ├─ onRollback callback
  ├─ UI removes device
  ├─ Show error toast
  └─ Mark operation failed
```

### Storage

```dart
class OptimisticStore {
  final Map<String, OptimisticUpdate> _store = {};

  void register({
    required String txnToken,
    required dynamic optimisticUpdate,
    required VoidCallback onCommit,
    required VoidCallback onRollback,
  }) {
    _store[txnToken] = OptimisticUpdate(
      token: txnToken,
      update: optimisticUpdate,
      registeredAt: DateTime.now(),
      onCommit: onCommit,
      onRollback: onRollback,
    );
  }

  Future<void> commit(String txnToken) async {
    final update = _store.remove(txnToken);
    if (update != null) {
      update.onCommit();
      print('[OptimisticStore] Committed: $txnToken');
    }
  }

  Future<void> rollback(String txnToken) async {
    final update = _store.remove(txnToken);
    if (update != null) {
      update.onRollback();
      print('[OptimisticStore] Rolled back: $txnToken');
    }
  }
}
```

---

## 🧩 Batch Coalescer

**Problem:** Multiple operations for same resource waste bandwidth  
**Solution:** Merge operations before sending

### Coalescing Rules

```
CREATE + UPDATE for same resource
  → Merge into single CREATE with combined payload

UPDATE + UPDATE for same resource
  → Merge into single UPDATE with combined payload

DELETE + any other operations for same resource
  → Keep only DELETE (supersedes all)

CREATE + DELETE for same resource
  → Remove both (net effect: nothing happened)
```

### Implementation

```dart
class BatchCoalescer {
  /// Coalesce new operation into queue
  void enqueue(PendingOp newOp) {
    final key = '${newOp.opType}::${newOp.entityType}::${newOp.payload['id']}';
    
    // Find pending operations for same resource
    final pending = _queue
      .where((op) => op.status == 'queued' && 
                     '${op.opType}::${op.entityType}::${op.payload['id']}' == key)
      .toList();
    
    // Remove operations superseded by DELETE
    if (newOp.opType == 'DELETE') {
      for (final op in pending) {
        _queue.remove(op);
      }
      _queue.add(newOp);
      return;
    }
    
    // Merge with existing CREATE
    if (newOp.opType == 'CREATE' || newOp.opType == 'UPDATE') {
      for (final op in pending) {
        if (op.opType == 'DELETE') {
          // DELETE supersedes everything
          _queue.remove(newOp);
          return;
        }
        
        // Merge payloads
        op.payload.addAll(newOp.payload);
        op.updatedAt = DateTime.now();
        return; // Coalesced
      }
    }
    
    // No coalescing possible, add as-is
    _queue.add(newOp);
  }
}
```

### Example

```
Queue before:
  [1] CREATE device {id: 'd1', name: 'Fitbit'}

New operation:
  UPDATE device {id: 'd1', name: 'Fitbit Pro'}

Queue after:
  [1] CREATE device {id: 'd1', name: 'Fitbit Pro'}
      (name merged, not sent twice)

Queue before:
  [1] CREATE device {id: 'd1', name: 'Fitbit'}
  [2] UPDATE device {id: 'd1', model: 'flex2'}

New operation:
  DELETE device {id: 'd1'}

Queue after:
  [1] DELETE device {id: 'd1'}
      (CREATE and UPDATE removed, only delete remains)
```

---

## 📊 Metrics Collection

### Metric Types

#### Counters (Monotonic Increasing)
```
processed_ops_total          # Total ops sent successfully
failed_ops_total             # Total ops failed after retries
backoff_events_total         # Times backoff applied
circuit_tripped_total        # Times circuit breaker tripped
retries_total                # Total retry attempts
conflicts_resolved_total     # 409s resolved by reconciler
auth_refresh_total           # Token refreshes
```

#### Gauges (Current Value)
```
pending_ops_gauge            # Current pending in queue
active_processors_gauge      # Currently running processors
```

#### Histograms (Distribution)
```
processing_latency_ms        # Buckets: [10, 50, 100, 500, 1000, ∞]
                             # Calculates p50, p95, p99
```

### Recording

```dart
class SyncMetrics {
  void recordEnqueue({required String operationType}) {
    _enqueueCount++;
    _telemetry.increment('sync.enqueue_total');
  }

  void recordProcessed({
    required String operationType,
    required int latencyMs,
  }) {
    _processedCount++;
    _latencies.add(latencyMs);
    
    _telemetry.increment('sync.processed_total');
    _telemetry.record('sync.processing_latency_ms', latencyMs);
  }

  void recordFailed({
    required String operationType,
    required String errorType,
  }) {
    _failedCount++;
    _telemetry.increment('sync.failed_total');
    _telemetry.increment('sync.failed_by_type.${errorType}');
  }

  Map<String, dynamic> exportPrometheus() {
    return {
      'processed_ops_total': _processedCount,
      'failed_ops_total': _failedCount,
      'processing_latency_p95': _calculateP95(_latencies),
      'pending_ops': _queue.length,
    };
  }
}
```

---

## 🔄 The Main Processing Loop

```dart
Future<void> _processLoop() async {
  while (_isRunning) {
    try {
      // 1. Check circuit breaker
      if (circuitBreaker.isTripped()) {
        await Future.delayed(Duration(seconds: 5));
        continue;
      }

      // 2. Get next operation
      final op = await queue.dequeue();
      if (op == null) {
        // No operations, sleep
        await Future.delayed(Duration(seconds: 1));
        continue;
      }

      // 3. Mark as processing
      op.status = 'processing';
      op.updatedAt = DateTime.now();
      await queue.update(op);

      // 4. Resolve route
      final route = router.resolve(op.opType, op.entityType);
      final path = route.pathBuilder(op.payload);
      final payload = route.transform?(op.payload) ?? op.payload;

      // 5. Send request
      final stopwatch = Stopwatch()..start();
      try {
        final response = await api.request(
          method: route.method,
          path: path,
          body: payload,
          headers: {
            'X-Idempotency-Key': op.idempotencyKey,
            if (op.traceId != null) 'Trace-Id': op.traceId!,
          },
        );

        // 6. Handle success
        op.status = 'completed';
        op.lastTriedAt = DateTime.now();
        await queue.update(op);
        await optimisticStore.commit(op.txnToken!);

        final latency = stopwatch.elapsedMilliseconds;
        metrics.recordProcessed(
          operationType: op.opType,
          latencyMs: latency,
        );

        circuitBreaker.recordSuccess();

      } on AuthException {
        // Token expired, refresh and retry
        await authService.refreshToken();
        // Re-enqueue (will use new token on next attempt)
        op.status = 'queued';
        await queue.update(op);

      } on ConflictException catch (e) {
        // 409 Conflict, try to reconcile
        final resolved = await reconciler.reconcileConflict(op, e);
        if (resolved) {
          // Payload updated, re-enqueue
          op.status = 'queued';
          op.attempts++;
          await queue.update(op);
        } else {
          // Couldn't reconcile
          op.status = 'failed';
          op.lastError = 'Reconciliation failed';
          await queue.update(op);
          await optimisticStore.rollback(op.txnToken!);
        }

      } on RateLimitException catch (e) {
        // 429 Rate limited
        final delayMs = backoffPolicy.computeDelay(op.attempts, '429');
        op.nextAttemptAt = DateTime.now().add(
          Duration(milliseconds: delayMs),
        );
        op.status = 'queued';
        op.attempts++;
        await queue.update(op);

      } on ServerException catch (e) {
        // 5xx Server error
        if (op.attempts >= MAX_RETRIES) {
          op.status = 'failed';
          op.lastError = e.message;
          await queue.update(op);
          await optimisticStore.rollback(op.txnToken!);
          circuitBreaker.recordFailure();
        } else {
          final delayMs = backoffPolicy.computeDelay(op.attempts, '5xx');
          op.nextAttemptAt = DateTime.now().add(
            Duration(milliseconds: delayMs),
          );
          op.status = 'queued';
          op.attempts++;
          await queue.update(op);
          circuitBreaker.recordFailure();
        }

      } catch (e) {
        // Unexpected error
        metrics.recordFailed(
          operationType: op.opType,
          errorType: 'unknown',
        );

        if (op.attempts >= MAX_RETRIES) {
          op.status = 'failed';
          op.lastError = e.toString();
          await queue.update(op);
          await optimisticStore.rollback(op.txnToken!);
        } else {
          op.status = 'queued';
          op.attempts++;
          op.nextAttemptAt = DateTime.now().add(
            Duration(seconds: 10),
          );
          await queue.update(op);
        }
      }

    } catch (e, stackTrace) {
      // Critical error in loop
      print('[SyncEngine] Critical error: $e\n$stackTrace');
      await Future.delayed(Duration(seconds: 5));
    }
  }
}
```

---

## 🚀 Starting the Sync Engine

```dart
// In main.dart or bootstrap code

final syncEngine = SyncEngine(
  api: apiClient,
  queue: queueService,
  router: opRouter,
  lock: processingLock,
  backoffPolicy: backoffPolicy,
  circuitBreaker: circuitBreaker,
  reconciler: reconciler,
  optimisticStore: optimisticStore,
  coalescer: batchCoalescer,
  metrics: metrics,
  realtimeService: realtimeService,
);

// Start processing
await syncEngine.start();

// When app closes
// (in app dispose or lifecycle hook)
await syncEngine.stop();
```

---

## 🧪 Testing the Sync Engine

### Unit Tests
```dart
test('marks operation as processing', () async {
  final op = PendingOp(...);
  await syncEngine.enqueue(op);
  
  // Sync engine picks it up
  await Future.delayed(Duration(milliseconds: 100));
  
  expect(op.status, equals('processing'));
});

test('respects Retry-After header', () async {
  mockServer.behavior.retryAfterSeconds = 120;
  
  final op = PendingOp(...);
  await syncEngine.enqueue(op);
  
  // Should schedule retry 120 seconds later
  expect(op.nextAttemptAt!.isAfter(
    DateTime.now().add(Duration(seconds: 100))
  ), isTrue);
});

test('reconciles 409 conflicts', () async {
  mockServer.behavior.simulateConflict = true;
  
  final op = PendingOp(opType: 'UPDATE', ...);
  await syncEngine.enqueue(op);
  
  // Should reconcile and retry
  await Future.delayed(Duration(seconds: 1));
  
  expect(op.status, equals('completed'));
});
```

### Integration Tests
```dart
test('crash-resume scenario', () async {
  // 1. Enqueue operation
  await syncEngine.enqueue(op1);
  
  // 2. Simulate crash (force-quit)
  await syncEngine.stop();
  
  // 3. Restart
  await syncEngine.start();
  
  // 4. Should resume processing
  await Future.delayed(Duration(milliseconds: 500));
  
  expect(op1.status, equals('completed'));
});
```

---

**Document Version:** 1.0  
**Last Updated:** January 10, 2026
