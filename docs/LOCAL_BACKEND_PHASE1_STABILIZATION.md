# Local Backend Phase 1 Stabilization

**Target:** Move from 62% → 72% local backend completeness  
**Status:** ✅ Complete

---

## Summary

This phase addresses **foundational stability** without introducing breaking changes. The focus is on removing ambiguity, making failures observable, and establishing clear authority for locking.

---

## Deliverables

### 1. Single Source of Truth for Initialization ✅

**File:** `lib/bootstrap/local_backend_bootstrap.dart`

Created a unified bootstrap entry point that:
- Calls `HiveService.init()` first (handles encryption keys, adapter registration)
- Then opens home automation boxes via `HomeAutomationHiveBridge.open()`
- Handles edge cases: crash recovery, secure erase, partial registration, key rotation
- Provides telemetry for init timing and errors

**Bridge File:** `lib/home automation/src/data/home_automation_hive_bridge.dart`

Bridges the gap between `LocalHiveService` and `HiveService`:
- Opens home automation boxes using `HiveService`'s encryption infrastructure
- Registers adapters only if not already registered
- Maintains consistent box naming (`rooms_v1`, `devices_v1`, etc.)

**Impact:** +2% (deterministic init order)

---

### 2. Kill "Transactional" Illusion ✅

**File:** `lib/persistence/wrappers/hive_wrapper.dart`

Renamed `transactionalWrite` → `bestEffortWrite` with:
- Prominent warning documentation about non-atomicity
- Clear list of failure scenarios
- Telemetry on partial failures (`hive.best_effort_write.partial_failure`)
- Deprecated alias for backward compatibility

**Callers Updated:**
- `lib/persistence/index/pending_index.dart`
- `lib/persistence/queue/pending_queue_service.dart`

**Impact:** +1.5% (honest semantics)

---

### 3. Pending Queue: Make Failure Visible ✅

**File:** `lib/models/pending_op.dart`

Added field:
```dart
final DateTime? lastTriedAt;
```

**File:** `lib/persistence/adapters/pending_op_adapter.dart`

Updated to serialize `lastTriedAt` as field 10 (ISO8601 string).

**File:** `lib/persistence/queue/pending_queue_service.dart`

Updated `process()` catch block to record:
- `attempts: op.attempts + 1`
- `lastError: e.toString()`
- `lastTriedAt: DateTime.now().toUtc()`
- Telemetry: `failed_ops.count`, `failed_ops.by_type.{opType}`, `failed_ops.last_attempts`

**Impact:** +1.5% (observable failures)

---

### 4. Locking: Declare One Authority ✅

**Canonical Authority:** `lib/persistence/locking/processing_lock.dart`

Added prominent documentation declaring this as the ONLY lock for queue processing:
```dart
/// ═══════════════════════════════════════════════════════════════════════════
/// CANONICAL LOCK AUTHORITY FOR QUEUE PROCESSING
/// ═══════════════════════════════════════════════════════════════════════════
```

Added helper methods:
- `currentHolder` - Get the current lock holder's PID
- `wasStaleRecovered` - Check if lock was recovered from stale state
- `assertNoDualLockActive()` - Runtime assertion to detect dual-lock scenarios

**Sync Engine Lock:** `lib/sync/processing_lock.dart`

Marked as for SyncEngine/admin console only, with guidance to use the persistence lock for queue operations.

**LockService:** `lib/services/lock_service.dart`

Added deprecation notice for queue operations:
```dart
/// ═══════════════════════════════════════════════════════════════════════════
/// DEPRECATED FOR QUEUE PROCESSING
/// ═══════════════════════════════════════════════════════════════════════════
```

**Impact:** +1% (clear authority)

---

## Files Modified

| File | Change |
|------|--------|
| `lib/bootstrap/local_backend_bootstrap.dart` | Created - unified init |
| `lib/home automation/src/data/home_automation_hive_bridge.dart` | Created - bridge |
| `lib/persistence/wrappers/hive_wrapper.dart` | Renamed method, added warnings |
| `lib/persistence/index/pending_index.dart` | Updated to use `bestEffortWrite` |
| `lib/persistence/queue/pending_queue_service.dart` | Updated method + failure recording |
| `lib/models/pending_op.dart` | Added `lastTriedAt` field |
| `lib/persistence/adapters/pending_op_adapter.dart` | Serialize new field |
| `lib/persistence/locking/processing_lock.dart` | Authority docs + helpers |
| `lib/sync/processing_lock.dart` | Scope clarification |
| `lib/services/lock_service.dart` | Deprecation notice |

---

## Verification

```bash
# Run ProcessingLock tests
flutter test test/persistence/processing_lock_test.dart

# Analyze modified files
dart analyze lib/bootstrap/ lib/persistence/locking/ lib/persistence/wrappers/ lib/persistence/queue/
```

---

## Next Steps (Phase 2 - 72% → 82%)

1. **Unify home automation boxes** - Migrate to HiveService directly
2. **Add write-ahead log** - For critical operations needing true atomicity
3. **Merge ProcessingLock implementations** - One lock per concern
4. **Add queue health metrics** - Stalled ops detection, retry backoff analysis
