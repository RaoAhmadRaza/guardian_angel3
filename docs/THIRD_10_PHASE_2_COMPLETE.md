# Third 10% Phase 2 Complete: Emergency & Safety-First Prioritization

**Date:** December 19, 2025  
**Impact:** +5% (Local backend now at ~98%)

## Summary

This phase transforms Guardian Angel into a true safety-first application by implementing priority-based queue processing with emergency fast lanes and automatic safety fallbacks when network is unavailable.

---

## Task 4: Priority Queue Layers (+2%) ✅

### Implementation

**New File: `lib/persistence/queue/op_priority.dart`**

```dart
enum OpPriority {
  emergency(0),  // Life-threatening: SOS, fall detection
  high(1),       // Important: Medication, caregiver check-in
  normal(2),     // Standard: Room updates, device config
  low(3);        // Deferrable: Analytics, preferences
  
  final int value;
  const OpPriority(this.value);
  
  bool get bypassesBackoff => this == OpPriority.emergency;
}
```

### PendingOp Extensions

Added to `lib/models/pending_op.dart`:
- `priority` field (defaults to `OpPriority.normal`)
- `deliveryState` field (pending → sent → acknowledged)
- Emergency ops bypass backoff in `isEligibleNow` getter

### Adapter Updates

Updated `lib/persistence/adapters/pending_op_adapter.dart`:
- Now 15 fields (added priority at field 13, deliveryState at field 14)
- Backward compatible with existing data

### Priority Processing

Queue processing order:
1. **Emergency** - Bypasses backoff, uses fast lane
2. **High** - Standard backoff, processed before normal
3. **Normal** - Standard queue behavior
4. **Low** - Processed only when no higher priority pending

### Example Op Type Mappings

| Operation | Priority |
|-----------|----------|
| `sos`, `fall_detected` | Emergency |
| `medication_confirm`, `vital_warning` | High |
| `room_update`, `device_config` | Normal |
| `room_rename`, `analytics` | Low |

---

## Task 5: Emergency Fast Lane (+1.5%) ✅

### Implementation

**New File: `lib/persistence/queue/emergency_queue_service.dart`**

```dart
class EmergencyQueueService {
  // Separate Hive box: 'emergency_ops_box'
  // Aggressive retry: 1s → 2s → 4s → 8s → 15s max
  // Escalates after 5 failed attempts
  
  Future<bool> enqueueEmergency(PendingOp op);
  Future<int> processAll(Future<bool> Function(PendingOp) handler);
}
```

### Key Features

1. **Separate Storage**: Emergency ops stored in `emergency_ops_box` 
2. **Aggressive Backoff**: Short delays (1s base, 15s max vs 2s/10min normal)
3. **Immediate Processing**: Triggers immediate attempt on enqueue
4. **Escalation**: After 5 failures, triggers local alert
5. **Event Stream**: Observable stream for UI/alerting

### Aggressive Backoff Schedule

| Attempt | Emergency Backoff | Normal Backoff |
|---------|-------------------|----------------|
| 1 | 1 second | 2 seconds |
| 2 | 2 seconds | 4 seconds |
| 3 | 4 seconds | 8 seconds |
| 4 | 8 seconds | 16 seconds |
| 5 | 15 seconds (max) | 32 seconds |
| 5+ | Escalate | Continue to 10 min |

---

## Task 6: Strong Delivery Acknowledgement (+1%) ✅

### DeliveryState Enum

Added to `lib/models/pending_op.dart`:

```dart
enum DeliveryState {
  pending,      // Queued, not yet sent
  sent,         // Sent to server, awaiting ack
  acknowledged, // Server confirmed with idempotency key
}
```

### Protocol

1. Op starts as `pending`
2. Before sending to API, mark as `sent`
3. Server must respond with idempotency key confirmation
4. Only on `acknowledged` do we delete the op

### Edge Cases Handled

| Scenario | Behavior |
|----------|----------|
| API timeout | Revert to `pending`, retry |
| Duplicate sends | Server returns same ack, safe |
| Partial response | Keep as `sent`, retry later |
| Network drop during ack | Op remains, no duplicate |

---

## Task 7: Safety-First Fallback (+0.5%) ✅

### Implementation

**New File: `lib/persistence/queue/safety_fallback_service.dart`**

```dart
enum SafetyMode {
  normal,             // All systems operational
  limitedConnectivity, // Network degraded
  emergency,          // Emergency ops failing, alerts active
  offlineSafety,      // Total network blackout
}

class SafetyFallbackService {
  SafetyMode get currentMode;
  
  Future<void> reportNetworkState({required bool isAvailable});
  Future<void> reportEmergencyOpResult(PendingOp op, {required bool success});
}
```

### Escalation Triggers

| Condition | Threshold | Action |
|-----------|-----------|--------|
| Emergency op failures | 3 consecutive | Trigger local alert, enter emergency mode |
| Network unavailable | 5 minutes | Enter offline safety mode |
| Manual trigger | N/A | User can trigger safety mode |

### Local Alert System

When escalation triggers:
1. **Local notification** to caregiver (no cloud required)
2. **UI switches** to "limited connectivity" mode
3. **Audit log** records escalation event
4. **Alert callback** invoked for custom handling

### Escalation Types

```dart
enum EscalationType {
  emergencyOpFailed,
  networkUnavailable,
  manualTrigger,
  panicButton,
  vitalsCritical,
}
```

---

## Integration Points

### PendingQueueService Updates

```dart
class PendingQueueService {
  final EmergencyQueueService? _emergencyQueue;
  final SafetyFallbackService? _safetyFallback;
  
  // Routes emergency ops to fast lane
  Future<bool> enqueue(PendingOp op) async {
    if (op.priority == OpPriority.emergency) {
      return await _emergencyQueue?.enqueueEmergency(op) ?? false;
    }
    // Normal queue path...
  }
  
  // Sorts ops by priority before processing
  List<PendingOp> _sortByPriority(List<PendingOp> ops);
  
  // Reports network state to safety fallback
  Future<void> reportNetworkState({required bool isAvailable});
}
```

### Box Registry Updates

Added to `lib/persistence/box_registry.dart`:
```dart
static const emergencyOpsBox = 'emergency_ops_box';
static const safetyStateBox = 'safety_state_box';
```

---

## Files Created/Modified

### New Files
| File | Purpose |
|------|---------|
| `lib/persistence/queue/op_priority.dart` | Priority enum and extensions |
| `lib/persistence/queue/emergency_queue_service.dart` | Emergency fast lane |
| `lib/persistence/queue/safety_fallback_service.dart` | Safety mode management |
| `lib/persistence/queue/priority_queue_processor.dart` | Priority-aware processor |
| `test/persistence/priority_queue_test.dart` | 16 unit tests |

### Modified Files
| File | Changes |
|------|---------|
| `lib/models/pending_op.dart` | Added priority, deliveryState |
| `lib/persistence/adapters/pending_op_adapter.dart` | 15 fields (was 13) |
| `lib/persistence/queue/pending_queue_service.dart` | Priority routing, services |
| `lib/persistence/box_registry.dart` | Added emergency/safety boxes |

---

## Test Coverage

### New Tests (16 passing)

```
OpPriority
  ✓ priority ordering is correct
  ✓ emergency bypasses backoff
  ✓ fromString parses correctly

PendingOp with priority
  ✓ default priority is normal
  ✓ emergency ops bypass backoff in isEligibleNow
  ✓ copyWith preserves priority and deliveryState
  ✓ toJson/fromJson roundtrip preserves priority

EmergencyQueueService
  ✓ only accepts emergency priority ops
  ✓ processAll invokes handler and removes on success
  ✓ failed ops retry with incremented attempts

SafetyFallbackService
  ✓ starts in normal mode
  ✓ network unavailable triggers limited connectivity
  ✓ network restored returns to normal
  ✓ emergency failures trigger escalation after threshold
  ✓ acknowledge resets safety mode

DeliveryState
  ✓ delivery state transitions correctly
```

### Total Persistence Tests: 43 passing

---

## Usage Examples

### Enqueuing an Emergency Op

```dart
final sosOp = PendingOp(
  id: uuid.v4(),
  opType: 'sos',
  idempotencyKey: 'sos_${DateTime.now().millisecondsSinceEpoch}',
  payload: {'location': '...', 'vitals': '...'},
  priority: OpPriority.emergency,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

await queueService.enqueue(sosOp);
// Automatically routed to emergency fast lane
```

### Registering for Safety Alerts

```dart
safetyFallback.onLocalAlert = (mode, message, record) async {
  // Show local notification
  await LocalNotifications.show(
    title: 'Guardian Angel Alert',
    body: message,
    channel: 'emergency',
  );
  
  // Play alarm sound if in emergency mode
  if (mode == SafetyMode.emergency) {
    await AudioService.playAlarm();
  }
};

safetyFallback.onModeChange = (mode) {
  // Update UI based on safety mode
  ref.read(safetyModeProvider.notifier).state = mode;
};
```

### Monitoring Emergency Events

```dart
emergencyQueue.eventStream.listen((event) {
  switch (event.type) {
    case EmergencyEventType.enqueued:
      log('Emergency op queued: ${event.op?.opType}');
      break;
    case EmergencyEventType.escalated:
      log('ESCALATION: ${event.reason}');
      break;
    // ...
  }
});
```

---

## Edge Cases Handled

| Scenario | Behavior |
|----------|----------|
| Emergency during outage | Immediate local alert, aggressive retry |
| Battery-saving mode | Emergency ops still processed |
| Queue saturation | Emergency ops processed first |
| Sync engine stalled | Emergency fast lane independent |
| Normal queue blocked | Emergency queue unaffected |
| Cloud unreachable | Local escalation triggered |
| Total network blackout | Offline safety mode + local alerts |
| Elderly user panic | SOS processed immediately |

---

## Phase 2 Complete Summary

| Task | Description | Status | Impact |
|------|-------------|--------|--------|
| 4 | Priority Queue Layers | ✅ | +2% |
| 5 | Emergency Fast Lane | ✅ | +1.5% |
| 6 | Strong Delivery Ack | ✅ | +1% |
| 7 | Safety-First Fallback | ✅ | +0.5% |
| **Total** | | | **+5%** |

**Local Backend Progress: ~98% Complete**

---

## Next Steps (Remaining ~2%)

The local backend is nearly complete. Remaining work includes:
- Final integration testing with real hardware
- Performance optimization under load
- Documentation finalization
- Production hardening

The safety-first architecture ensures Guardian Angel provides reliable care monitoring even in degraded network conditions.
