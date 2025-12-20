# Second 10% Phase 2: Prepare for Sync Without Introducing Sync

## Overview

This phase implements the foundational infrastructure for future sync implementation.
By establishing contracts, interfaces, and enforcement mechanisms NOW, we ensure:

1. Queue processor is decoupled from sync implementation
2. Failure handling is consistent and intelligent
3. Duplicate operations are prevented
4. Future sync can be added without touching queue code

**Estimated Improvement**: +5% (from ~83% to ~88%)

---

## Completed Tasks

### Task 5: Canonical PendingOp Contract (+2%)

**File**: `lib/persistence/queue/pending_op_payload.dart`

Established a canonical schema for all pending operation payloads:

```dart
/// Domain types for categorization
enum DomainType {
  automation,  // Home automation operations
  chat,        // Chat/messaging operations
  vitals,      // Health vitals operations
  user,        // User profile operations
  system,      // System-level operations
}

/// Action types for all domains
enum ActionType {
  create,
  update,
  delete,
  sync,
  ack,
}

/// Canonical payload contract
class PendingOpPayload {
  final DomainType domain;
  final ActionType action;
  final Map<String, dynamic> data;
  final String idempotencyKey;

  /// Validates the payload and returns list of errors
  List<String> validate() { ... }
}
```

**Benefits**:
- Consistent payload structure across all modules
- Validation at enqueue time catches issues early
- Idempotency key built into payload
- Easy to route operations to correct handlers

---

### Task 6: Idempotency Enforcement (Local) (+1%)

**File**: `lib/persistence/queue/idempotency_cache.dart`

Prevents duplicate operation enqueue with TTL-based cleanup:

```dart
class IdempotencyCache {
  /// Check if key exists (not expired)
  bool contains(String idempotencyKey);
  
  /// Record a new key with timestamp
  Future<bool> record(String idempotencyKey);
  
  /// Atomic check-and-record
  Future<bool> checkAndRecord(String idempotencyKey);
  
  /// Remove expired entries
  Future<int> cleanup();
}
```

**Features**:
- Hive-backed persistence
- 24-hour default TTL
- Automatic cleanup during queue processing
- Telemetry for duplicate rejections

**Integration in PendingQueueService**:
```dart
Future<bool> enqueue(PendingOp op) async {
  // Check idempotency - prevent duplicate enqueue
  if (_idempotencyCache.contains(op.id)) {
    TelemetryService.I.increment('enqueue.duplicate_rejected');
    return false;
  }
  // ... enqueue operation
  await _idempotencyCache.record(op.id);
  return true;
}
```

---

### Task 7: Sync Handshake Interface (+1%)

**File**: `lib/sync/sync_consumer.dart`

Defines the contract between queue processor and sync implementation:

```dart
/// Result of sync operation
class SyncResult {
  final bool isSuccess;
  final FailureType? failureType;
  final String? errorMessage;
  final String? serverId;
  
  bool get shouldRetry => !isSuccess && failureType == FailureType.transient;
  bool get shouldEscalate => !isSuccess && failureType != FailureType.transient;
}

/// Failure classification
enum FailureType {
  transient,   // Retry with backoff (network, 5xx)
  permanent,   // Do not retry (400, 404, 409)
  auth,        // Re-auth required (401, 403)
  schema,      // App update required (version mismatch)
}

/// Abstract sync consumer interface
abstract class SyncConsumer {
  Future<SyncResult> process(PendingOp op);
  Future<bool> isReady();
  Future<void> onQueueStart();
  Future<void> onQueueEnd();
}
```

**Test Implementations Provided**:
- `NoOpSyncConsumer` - Always succeeds (for offline mode)
- `FailingSyncConsumer` - Configurable failure type (for testing)

**Integration in PendingQueueService**:
```dart
void setSyncConsumer(SyncConsumer consumer) {
  _syncConsumer = consumer;
}

// In process():
if (_syncConsumer != null) {
  final result = await _syncConsumer!.process(op);
  if (result.isSuccess) {
    await _markProcessed(op);
  } else {
    await _handleSyncFailure(op, result);
  }
}
```

---

### Task 8: Failure Classification (+1%)

**File**: `lib/sync/failure_classifier.dart`

Comprehensive failure classification system:

```dart
/// Rich failure info with user-facing messages
class FailureClassification {
  final FailureType type;
  final String technicalMessage;
  final String userMessage;
  
  bool get shouldRetry => type == FailureType.transient;
  bool get shouldEscalate => type != FailureType.transient;
  bool get requiresAuth => type == FailureType.auth;
  bool get requiresUpdate => type == FailureType.schema;
  
  Duration get suggestedDelay { ... }
}

/// Classifier for mapping exceptions to failure types
class FailureClassifier {
  /// Main entry point - classifies any error
  static FailureClassification classify(Object error, [StackTrace? stackTrace]);
  
  /// HTTP-specific classification
  static FailureClassification classifyHttpStatus(int statusCode, String? body);
}
```

**HTTP Status Mapping**:
| Status Code | Failure Type | Action |
|-------------|--------------|--------|
| 401, 403 | auth | Pause queue, prompt re-auth |
| 408, 429, 5xx | transient | Retry with backoff |
| 400, 404, 409, 422 | permanent | Move to failed_ops |

**Exception Mapping**:
- `SocketException`, `TimeoutException` → transient
- `FormatException`, `TypeError` → schema
- `StateError` → permanent
- Unknown → permanent (safe default)

---

## PendingQueueService Integration

The queue service now integrates all Phase 2 components:

```dart
class PendingQueueService {
  final IdempotencyCache _idempotencyCache;
  SyncConsumer? _syncConsumer;
  
  // Idempotency-aware enqueue
  Future<bool> enqueue(PendingOp op) async {
    if (_idempotencyCache.contains(op.id)) {
      return false; // Duplicate rejected
    }
    // ... enqueue
    await _idempotencyCache.record(op.id);
    return true;
  }
  
  // Sync consumer integration
  void setSyncConsumer(SyncConsumer consumer) {
    _syncConsumer = consumer;
  }
  
  // Failure classification in error handling
  Future<void> _handleFailure(PendingOp op, Object error, [StackTrace? stackTrace]) async {
    final classification = FailureClassifier.classify(error, stackTrace);
    
    if (!classification.shouldRetry) {
      // Move to failed_ops immediately
      await _moveToPermanentFailure(op, classification);
      if (classification.requiresAuth) {
        _setState(QueueState.paused);
      }
      return;
    }
    // Apply backoff for transient failures
    // ...
  }
  
  // Queue control
  void resume() { ... }  // Resume after re-auth
  void pause() { ... }   // Pause for offline mode
}
```

---

## Test Results

```
✅ 27 persistence tests passing
✅ 22 unit backoff tests passing
✅ flutter analyze - no errors in new files
```

---

## Files Created/Modified

### New Files
| File | Purpose | Lines |
|------|---------|-------|
| `lib/persistence/queue/pending_op_payload.dart` | Canonical payload schema | ~150 |
| `lib/persistence/queue/idempotency_cache.dart` | Duplicate prevention | ~133 |
| `lib/sync/sync_consumer.dart` | Sync interface contract | ~412 |
| `lib/sync/failure_classifier.dart` | Exception → failure type mapping | ~350 |

### Modified Files
| File | Changes |
|------|---------|
| `lib/persistence/queue/pending_queue_service.dart` | Added idempotency, sync consumer, failure classification |

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                      Module (Automation, Chat, etc)              │
│                                ↓                                 │
│                    PendingOpPayload.validate()                   │
└────────────────────────────────┬────────────────────────────────┘
                                 ↓
┌─────────────────────────────────────────────────────────────────┐
│                    PendingQueueService.enqueue()                 │
│                                ↓                                 │
│              IdempotencyCache.contains() ──────→ REJECT if dup   │
│                                ↓                                 │
│                         Hive pending_ops                         │
└────────────────────────────────┬────────────────────────────────┘
                                 ↓
┌─────────────────────────────────────────────────────────────────┐
│                    PendingQueueService.process()                 │
│                                ↓                                 │
│                  SyncConsumer.process(op)                        │
│                         ↓           ↓                            │
│                    SyncResult   Exception                        │
│                         ↓           ↓                            │
│                  shouldRetry?   FailureClassifier.classify()     │
│                    ↓       ↓              ↓                      │
│                 true    false        Classification              │
│                  ↓        ↓                ↓                     │
│              backoff   failed_ops     shouldRetry?               │
└─────────────────────────────────────────────────────────────────┘
```

---

## What's Next

The local backend is now **~88% complete**. The remaining ~12% consists of:

1. **Actual Sync Implementation** (~5%)
   - Implement `HttpSyncConsumer` against real backend
   - Wire up auth token management
   - Handle server-assigned IDs

2. **Conflict Resolution** (~4%)
   - Detect and resolve local vs server conflicts
   - Implement merge strategies

3. **Full E2E Testing** (~3%)
   - Integration tests with mock server
   - Stress tests with realistic data volumes

---

## Summary

Phase 2 establishes the **interface layer** between the local queue and future sync:

| Component | Purpose | Benefit |
|-----------|---------|---------|
| PendingOpPayload | Canonical schema | Consistent structure, early validation |
| IdempotencyCache | Duplicate prevention | No duplicate enqueues |
| SyncConsumer | Sync abstraction | Queue decoupled from sync impl |
| FailureClassifier | Intelligent retry | Right action for each failure type |

The queue processor is now **sync-ready** without containing any sync logic.
When real sync is implemented, it simply implements `SyncConsumer` and calls
`setSyncConsumer()` - zero changes to queue code.
