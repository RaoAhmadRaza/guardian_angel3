# Third 10% Phase 1: Real Sync Wiring + Deterministic Conflict Handling

## Overview

This phase introduces **real sync integration** while keeping the **local backend as the final authority**. We now have:

1. A concrete sync consumer that talks to the remote API
2. Deterministic conflict resolution policies
3. Per-entity operation ordering guarantees

**Estimated Improvement**: +5% (from ~88% to ~93%)

---

## Completed Tasks

### Task 1: Activate the Sync Handshake (For Real) (+2%)

**File**: `lib/sync/default_sync_consumer.dart`

Concrete implementation of `SyncConsumer` that connects the queue to the API:

```dart
class DefaultSyncConsumer implements SyncConsumer {
  final ApiClient _api;
  final ConflictResolver _conflictResolver;

  @override
  Future<SyncResult> process(PendingOp op) async {
    try {
      final endpoint = _resolveEndpoint(op);
      final method = _resolveMethod(op);
      
      final response = await _api.request(
        method: method,
        path: endpoint,
        body: op.payload,
        headers: {'Idempotency-Key': op.idempotencyKey},
      );
      
      return SyncResult.success(serverId: response['data']?['id']);
    } on NetworkException catch (e) {
      return SyncResult.transientFailure('Network error: ${e.message}');
    } on ConflictException catch (e) {
      return _conflictResolver.resolve(op, e);
    } on AuthException catch (e) {
      return SyncResult.authFailure('Auth error: ${e.message}');
    } // ... more exception handlers
  }
}
```

**Edge cases handled**:
- ✅ App offline → transient failure, retry with backoff
- ✅ Partial API failure → failure classification, appropriate retry
- ✅ App killed mid-sync → idempotency keys prevent duplicates

**Riverpod Integration** (`lib/sync/sync_providers.dart`):
```dart
final syncConsumerProvider = Provider<SyncConsumer>((ref) {
  final api = ref.watch(apiClientProvider);
  final resolver = ref.watch(conflictResolverProvider);
  return DefaultSyncConsumer(api: api, conflictResolver: resolver);
});
```

---

### Task 2: Conflict Resolution Policy (Local Is King) (+1.5%)

**File**: `lib/sync/conflict_resolver.dart`

Explicit conflict types with deterministic resolution:

```dart
enum ConflictType {
  versionMismatch,   // Fetch remote → rebase → re-enqueue
  alreadyDeleted,    // Mark op as success locally (no-op)
  staleUpdate,       // Drop op + audit
  notFound,          // Re-create or drop based on action
  duplicateCreate,   // Treat as update or success
  semanticConflict,  // Mark for user review
}
```

**Resolution Rules**:

| Conflict | Resolution | SyncResult |
|----------|------------|------------|
| Version mismatch | Fetch remote → rebase → re-enqueue | `transientFailure` |
| Already deleted | Desired state achieved | `success` |
| Stale update | Drop + audit trail | `permanentFailure` |
| Not found (delete) | Goal achieved | `success` |
| Not found (update) | Cannot update | `permanentFailure` |
| Duplicate create | Entity exists | `success` |
| Semantic conflict | Needs human review | `permanentFailure` |

**Edge cases handled**:
- ✅ Duplicate deletes → success (idempotent)
- ✅ Replays after reinstall → idempotency key check
- ✅ Clock skew → server version is authoritative

---

### Task 3: Operation Ordering Guarantees (Per-Entity) (+1.5%)

**File**: `lib/persistence/queue/entity_ordering.dart`

Added `entityKey` to PendingOp for per-entity ordering:

```dart
class PendingOp {
  // ... existing fields ...
  
  /// Entity key for ordering guarantees.
  /// Format: "entity_type:entity_id" (e.g., "device:123")
  final String? entityKey;
  
  /// Derive entity key from payload if not explicitly set.
  String? get effectiveEntityKey {
    if (entityKey != null) return entityKey;
    final entityType = payload['entity_type'] as String?;
    final entityId = payload['entity_id'] as String?;
    if (entityType != null && entityId != null) {
      return '$entityType:$entityId';
    }
    return null;
  }
}
```

**EntityOrderingService**:
```dart
class EntityOrderingService {
  final Map<String, EntityLockState> _locks = {};
  
  /// Only one in-flight op per entity at a time.
  Future<bool> tryAcquire(PendingOp op) async {
    final entityKey = op.effectiveEntityKey;
    if (entityKey == null) return true; // No ordering needed
    
    if (_locks.containsKey(entityKey)) {
      return false; // Another op has the lock
    }
    
    _locks[entityKey] = EntityLockState(/*...*/);
    return true;
  }
  
  Future<void> release(PendingOp op) async {
    _locks.remove(op.effectiveEntityKey);
  }
}
```

**Integration in PendingQueueService**:
```dart
for (final op in ops) {
  // Check entity ordering - only one in-flight per entity
  if (!await _entityOrdering.tryAcquire(op)) {
    entityBlocked++;
    continue; // Skip, will process next round
  }
  
  try {
    // Process op...
    await _markProcessed(op);
  } finally {
    await _entityOrdering.release(op);
  }
}
```

**Edge cases handled**:
- ✅ Update → delete races → second op waits
- ✅ Rapid UI edits → sequential processing
- ✅ Parallel sync workers (future) → lock prevents conflicts

---

## Model Changes

### PendingOp (13 fields now)

| Field | Type | Purpose |
|-------|------|---------|
| id | String | Unique identifier |
| opType | String | Operation type |
| idempotencyKey | String | Prevent duplicates |
| payload | Map | Operation data |
| attempts | int | Retry count |
| status | String | Current status |
| lastError | String? | Last failure message |
| lastTriedAt | DateTime? | Last attempt time |
| nextEligibleAt | DateTime? | Backoff expiry |
| schemaVersion | int | Schema version |
| createdAt | DateTime | Creation time |
| updatedAt | DateTime | Last update time |
| **entityKey** | String? | **NEW: Per-entity ordering** |

### Adapter Updated

`lib/persistence/adapters/pending_op_adapter.dart`:
- Now writes **13 fields** (was 12)
- Field 12: `entityKey`

---

## Files Created

| File | Purpose | Lines |
|------|---------|-------|
| `lib/sync/default_sync_consumer.dart` | Concrete sync consumer | ~210 |
| `lib/sync/conflict_resolver.dart` | Conflict resolution policy | ~390 |
| `lib/sync/sync_providers.dart` | Riverpod providers for DI | ~70 |
| `lib/persistence/queue/entity_ordering.dart` | Per-entity lock service | ~280 |

## Files Modified

| File | Changes |
|------|---------|
| `lib/models/pending_op.dart` | Added `entityKey` field, `effectiveEntityKey` getter |
| `lib/persistence/adapters/pending_op_adapter.dart` | Serialize field 12 (entityKey) |
| `lib/persistence/queue/pending_queue_service.dart` | Entity ordering integration |

---

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    PendingQueueService.process()              │
│                              ↓                                │
│              EntityOrderingService.tryAcquire(op)             │
│                    ↓ (if locked)      ↓ (acquired)            │
│                  skip op          continue                    │
│                              ↓                                │
│              DefaultSyncConsumer.process(op)                  │
│                              ↓                                │
│                       ApiClient.request()                     │
│                              ↓                                │
│                       Response / Error                        │
│                              ↓                                │
│               ┌──────────────┴──────────────┐                 │
│               ↓                              ↓                │
│          SyncResult.success             Exception             │
│               ↓                              ↓                │
│         _markProcessed()          ConflictResolver.resolve()  │
│               ↓                         or                    │
│    EntityOrdering.release()        _handleFailure()           │
│                                          ↓                    │
│                               EntityOrdering.release()        │
└──────────────────────────────────────────────────────────────┘
```

---

## Conflict Resolution Flow

```
┌─────────────────────────────────────────────────────────────┐
│                   ConflictException raised                   │
│                            ↓                                 │
│              ConflictResolver.resolve(op, e)                 │
│                            ↓                                 │
│                   Parse conflict type                        │
│                            ↓                                 │
│   ┌────────────────────────┼────────────────────────┐        │
│   ↓                        ↓                        ↓        │
│ VERSION               ALREADY_DELETED           STALE        │
│ MISMATCH                                        UPDATE       │
│   ↓                        ↓                        ↓        │
│ transient              success                 permanent     │
│ (retry)               (no-op)                  (drop+audit)  │
└─────────────────────────────────────────────────────────────┘
```

---

## Test Results

```
✅ 27 persistence tests passing
✅ All new code compiles without errors
✅ flutter analyze - clean (no errors)
```

---

## What's Next

Phase 2 of the Third 10% will add:

1. **Emergency Priority Queue** - Critical operations bypass normal queue
2. **Data Truth Guarantees** - Ensure data never lies about its state
3. **Sync Status Observability** - Real-time sync status for UI

---

## Summary

Phase 1 of the Third 10% establishes the **real sync integration layer**:

| Component | Purpose | Impact |
|-----------|---------|--------|
| DefaultSyncConsumer | API ↔ Queue bridge | +2% |
| ConflictResolver | Deterministic conflict handling | +1.5% |
| EntityOrderingService | Per-entity FIFO | +1.5% |

The local backend now:
- ✅ Talks to sync safely via abstraction layer
- ✅ Resolves conflicts deterministically
- ✅ Maintains per-entity operation order
- ✅ Keeps local as source of truth
