# Second 10% - Phase 1: Queue Hardening

**Target:** Turn pending-ops from passive container into self-governing engine  
**Impact:** +5% completeness  
**Status:** ✅ Complete

---

## Summary

This phase hardens the queue with retries, backoff, and poison control. No refactors, no new architecture - just finishing what already exists.

After this phase, the queue:
- ✅ Ops retry intelligently with exponential backoff
- ✅ Poison ops stop burning CPU
- ✅ Queue can handshake cleanly with sync later
- ✅ Debugging becomes boring (which is good)

---

## Deliverables

### 1️⃣ Backoff Metadata (Deterministic, Local) - `+2%`

**Files Created:**
- `lib/persistence/queue/backoff.dart` - Pure, testable backoff functions

**Model Updates:**
- `lib/models/pending_op.dart` - Added `nextEligibleAt` field
- `lib/persistence/adapters/pending_op_adapter.dart` - Serialize field 11

**Backoff Formula:**
```dart
Duration computeBackoff(int attempts) {
  const base = Duration(seconds: 2);
  const maxBackoff = Duration(minutes: 10);
  final backoff = base * (1 << attempts); // 2^attempts
  return backoff > maxBackoff ? maxBackoff : backoff;
}
```

**Backoff Progression:**
| Attempt | Backoff |
|---------|---------|
| 0 | 2s |
| 1 | 4s |
| 2 | 8s |
| 3 | 16s |
| 4 | 32s |
| 5 | 64s (~1 min) |
| 6 | 128s (~2 min) |
| 7 | 256s (~4 min) |
| 8 | 512s (~8.5 min) |
| 9+ | 600s (10 min ceiling) |

**Edge Cases Handled:**
- App restarts: `nextEligibleAt` persisted in Hive
- Clock skew: Uses UTC everywhere
- Power loss mid-failure: Worst case = retry too early

---

### 2️⃣ Skip Ineligible Ops (No Busy Waiting) - `+1%`

**File:** `lib/persistence/queue/pending_queue_service.dart`

**Logic:**
```dart
// Check if op is eligible for processing (backoff elapsed)
if (!op.isEligibleNow) {
  skipped++;
  TelemetryService.I.increment('queue.op.skipped_backoff');
  continue;
}
```

**Key Features:**
- No sleeping, no timers - just ordering discipline
- Fetches 2x batch size to handle skips
- Telemetry tracks skipped count

**Edge Cases Handled:**
- Mixed fresh + failed ops: Fresh ops processed while failed wait
- Queue starvation: Backoff ceiling prevents infinite waits

---

### 3️⃣ Poison Op Threshold (Fail Loud, Not Forever) - `+1%`

**Constant:**
```dart
const int maxAttempts = 7;
```

**File:** `lib/models/failed_op_model.dart` - Added `fromPendingOp` factory

**Poison Detection:**
```dart
if (op.attempts >= maxAttempts) {
  await _moveToPoisonOps(op);
  poisoned++;
  continue;
}
```

**Poison Handling:**
1. Create `FailedOpModel` from `PendingOp`
2. Store in `failed_ops_box` (preserves data for debugging)
3. Remove from `pending_ops_box`
4. Remove from `pending_index`
5. Log to telemetry + audit

**Edge Cases Handled:**
- Corrupt payloads: Caught before infinite retries
- Incompatible schema: Fails fast after 7 attempts
- Auth failures: Stops burning tokens

---

### 4️⃣ Queue Processing State Machine (Minimal) - `+1%`

**File:** `lib/persistence/queue/queue_state.dart`

**States:**
```dart
enum QueueState {
  idle,       // Ready to start
  processing, // Actively processing
  blocked,    // Lock held by another runner
  paused,     // App backgrounded, network offline
  error,      // Encountered error
}
```

**Integration:**
```dart
class PendingQueueService {
  QueueState _state = QueueState.idle;
  QueueState get state => _state;
  Stream<QueueState> get stateStream => _stateController.stream;
}
```

**Prevention:**
- Double processors: State check before acquiring lock
- Re-entrancy bugs: `canStartProcessing` guard
- Hidden deadlocks: State exposed to telemetry

---

## Files Created/Modified

| File | Change |
|------|--------|
| `lib/persistence/queue/backoff.dart` | Created - backoff functions |
| `lib/persistence/queue/queue_state.dart` | Created - state enum |
| `lib/models/pending_op.dart` | Added `nextEligibleAt`, `isEligibleNow` |
| `lib/models/failed_op_model.dart` | Added `fromPendingOp` factory |
| `lib/persistence/adapters/pending_op_adapter.dart` | Serialize field 11 |
| `lib/persistence/queue/pending_queue_service.dart` | Full rewrite with all features |

---

## Telemetry Keys Added

| Key | Description |
|-----|-------------|
| `queue.state` | Current state (0=idle, 1=processing, etc.) |
| `queue.process.skipped_not_idle` | Rejected due to state |
| `queue.process.blocked` | Lock held by another |
| `queue.op.skipped_backoff` | Skipped - in backoff |
| `queue.poison_ops.count` | Total poison ops moved |
| `queue.poison_ops.by_type.{type}` | Poison ops by op type |
| `queue.last_processed` | Ops processed in last batch |
| `queue.last_skipped` | Ops skipped in last batch |
| `queue.last_poisoned` | Ops poisoned in last batch |
| `failed_ops.last_backoff_seconds` | Last backoff duration |

---

## Testing

```bash
# All persistence tests pass
flutter test test/persistence/ -r compact

# Verify backoff function
dart run test/unit/backoff_test.dart
```

---

## API Changes

### PendingQueueService

**New Properties:**
- `QueueState get state` - Current queue state
- `Stream<QueueState> get stateStream` - State change stream
- `int get backoffCount` - Ops currently in backoff
- `int get nearPoisonCount` - Ops nearing poison threshold

**New Method:**
- `void dispose()` - Close stream controller

**Modified Method:**
- `process()` - Now skips ineligible ops, detects poison, uses state machine

---

## Result

The queue is now:
- ⚡ **Backoff-aware** - Failed ops wait before retrying
- 🔋 **Battery-safe** - No hot loops burning CPU
- ☠️ **Poison-resistant** - Bad ops moved to failed box
- 👁️ **Observable** - State machine exposes what's happening

It behaves like an **engine**, not a list.
