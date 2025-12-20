# Final 10% Phase 1: Observability, Admin Power & Operational Truth

## Overview

This phase completes the local backend stabilization journey from 98% → 100% by adding:
1. **Enhanced Local Backend Health Dashboard** (+1.5%)
2. **Admin Console: Repair Actions** (+1.5%)
3. **Full Audit Trail Completion** (+1%)
4. **Queue Stall Detection & Auto-Recovery** (+1%)

**Total Progress: +5% → 100% Local Backend Complete**

## Components Implemented

### 1. Enhanced LocalBackendStatus

**File:** `lib/persistence/local_backend_status.dart`

The `LocalBackendStatus` class has been expanded with actionable metrics:

#### New Fields

| Field | Type | Description |
|-------|------|-------------|
| `emergencyOps` | `int` | Emergency ops in fast lane queue |
| `escalatedOps` | `int` | Escalated emergency ops (max retries exceeded) |
| `queueStallDuration` | `Duration?` | How long queue has been stalled |
| `lastSuccessfulSync` | `DateTime?` | Last successful cloud sync |
| `adaptersHealthy` | `bool` | Whether Hive adapters are registered |
| `lockStatus` | `LockStatus` | Processing lock details |
| `opsByPriority` | `Map<String, int>` | Ops count by priority level |
| `queueState` | `String` | Current queue state |
| `entityLockCount` | `int` | Entity ordering locks held |
| `safetyFallbackActive` | `bool` | Network blackout mode active |

#### New Health Assessment

```dart
// Three-level health assessment
bool get isHealthy => encryptionHealthy && !queueStalled && failedOps == 0 
                     && adaptersHealthy && !safetyFallbackActive;

bool get isCritical => !encryptionHealthy 
                      || (emergencyOps > 0 && escalatedOps > 0)
                      || (queueStallDuration?.inMinutes ?? 0) > 30
                      || failedOps > 10;

bool get isWarning => !isHealthy && !isCritical;

int get healthSeverity => isCritical ? 2 : (isWarning ? 1 : 0);
```

#### LockStatus Class

```dart
class LockStatus {
  final bool isLocked;
  final String? holderPid;
  final DateTime? acquiredAt;
  final bool wasStaleRecovered;
  final Duration? lockDuration;
}
```

### 2. RepairService - Admin Surgical Kit

**File:** `lib/persistence/repair/repair_service.dart`

Controlled repair actions with:
- Confirmation tokens
- Audit logging
- Telemetry
- Idempotent operations

#### Available Actions

| Action | Severity | Queue Stop Required |
|--------|----------|---------------------|
| `rebuildPendingIndex` | info | ✅ |
| `retryFailedOps` | warning | ❌ |
| `purgePoisonOps` | critical | ✅ |
| `verifyEncryption` | critical | ❌ |
| `releaseStaleLocks` | warning | ❌ |
| `releaseEntityLocks` | warning | ❌ |
| `resetQueueState` | warning | ❌ |
| `compactBoxes` | info | ✅ |

#### Usage

```dart
final repairService = RepairService(queueService: queueService);

// Generate confirmation token
final token = repairService.generateConfirmationToken(RepairAction.rebuildPendingIndex);

// Execute with confirmation
final result = await repairService.execute(
  action: RepairAction.rebuildPendingIndex,
  userId: currentUser.id,
  confirmationToken: token,
  reason: 'Index corruption suspected',
);

if (result.success) {
  print('Rebuilt ${result.affectedCount} entries in ${result.duration}');
}
```

### 3. Audit Types & Standardized Logging

**File:** `lib/services/models/audit_types.dart`

#### AuditType Enum

Canonical types for all audit events:

```dart
// Emergency & Safety
AuditType.sosTrigger        // SOS triggered
AuditType.sosEscalated      // Cloud unreachable, local alert
AuditType.emergencyEnqueued // Emergency op added
AuditType.emergencyEscalated // Max retries, local escalation

// Queue Operations
AuditType.queueStallDetected // Stall detected
AuditType.queueStallRecovered // Auto-recovery succeeded

// Repair Actions
AuditType.repairStarted     // Admin action started
AuditType.repairCompleted   // Admin action completed

// Security
AuditType.secureEraseStarted // Data deletion started
AuditType.encryptionKeyRotated // Key rotation
```

#### Type Properties

```dart
AuditType.sosTrigger.action       // 'sosTrigger'
AuditType.sosTrigger.severity     // 'critical'
AuditType.sosTrigger.isMandatory  // true - always logged
AuditType.sosTrigger.defaultEntityType // 'sos'
```

#### AuditEvent Factories

```dart
// SOS trigger
AuditEvent.sosTrigger(
  userId: userId,
  sosId: sosId,
  location: 'Home',
);

// Emergency operation
AuditEvent.emergency(
  type: AuditType.emergencyEscalated,
  userId: userId,
  opId: opId,
  error: 'Network timeout',
  attempts: 5,
);

// Queue stall
AuditEvent.queueStall(
  type: AuditType.queueStallDetected,
  userId: 'system',
  stallDuration: Duration(minutes: 15),
  pendingCount: 10,
);

// Repair action
AuditEvent.repair(
  type: AuditType.repairCompleted,
  userId: adminUserId,
  action: 'rebuildPendingIndex',
  affectedCount: 50,
);
```

### 4. Queue Stall Detector & Auto-Recovery

**File:** `lib/persistence/queue/stall_detector.dart`

Self-healing queue monitoring with automatic recovery.

#### Configuration

```dart
const StallConfig.production = StallConfig(
  stallThreshold: Duration(minutes: 10),
  lockStaleThreshold: Duration(minutes: 5),
  checkInterval: Duration(minutes: 1),
  maxRecoveryAttempts: 3,
  recoveryCooldown: Duration(minutes: 2),
);

const StallConfig.testing = StallConfig(
  stallThreshold: Duration(seconds: 30),
  lockStaleThreshold: Duration(seconds: 15),
  checkInterval: Duration(seconds: 5),
);
```

#### Usage

```dart
final detector = QueueStallDetector(config: StallConfig.production);

// Set recovery callback
detector.onRecoveryNeeded = () async {
  await queueService.process();
};

// Start monitoring
detector.startMonitoring();

// Listen for events
detector.eventStream.listen((event) {
  switch (event.type) {
    case StallEventType.stallDetected:
      print('Stall detected: ${event.status?.stallDuration}');
      break;
    case StallEventType.recoveryCompleted:
      print('Recovery succeeded: ${event.recoveryResult?.actionsTaken}');
      break;
    case StallEventType.maxRecoveryAttemptsReached:
      // Alert admin
      break;
  }
});
```

#### Auto-Recovery Steps

When a stall is detected:
1. Check if lock is stale → Release if yes
2. Rebuild pending index
3. Call recovery callback (if set)
4. Log to audit trail
5. Emit telemetry

#### StallStatus

```dart
final status = detector.getStatus();

print('Stalled: ${status.isStalled}');
print('Stall duration: ${status.stallDuration?.inMinutes}m');
print('Lock held: ${status.lockHeld}');
print('Lock stale: ${status.lockIsStale}');
print('Recovery attempts: ${status.recoveryAttempts}');
print('Should recover: ${status.shouldAttemptRecovery}');
```

## Test Coverage

New test files:
- `test/persistence/local_backend_status_test.dart` - Status and health assessment
- `test/persistence/repair_service_test.dart` - Repair actions and tokens
- `test/persistence/stall_detector_test.dart` - Stall detection and recovery
- `test/services/audit_types_test.dart` - Audit type properties

Run all tests:
```bash
flutter test test/persistence/local_backend_status_test.dart
flutter test test/persistence/repair_service_test.dart
flutter test test/persistence/stall_detector_test.dart
flutter test test/services/audit_types_test.dart
```

## Integration Points

### With PendingQueueService

```dart
// In PendingQueueService.create()
final stallDetector = QueueStallDetector();
stallDetector.onRecoveryNeeded = () async {
  await _queueService.rebuildIndex();
  await _queueService.resume();
};
stallDetector.startMonitoring();
```

### With App Initialization

```dart
// Set emergency queue instance for status collection
LocalBackendStatusCollector.setEmergencyQueue(queueService.emergencyQueue);
```

### With Admin UI

```dart
// Show health dashboard
final status = ref.watch(localBackendStatusProvider);

StatusCard(
  title: 'Backend Health',
  severity: status.healthSeverity,
  details: [
    'Pending: ${status.pendingOps}',
    'Emergency: ${status.emergencyOps}',
    'Failed: ${status.failedOps}',
    'Stalled: ${status.queueStalled}',
    'State: ${status.queueState}',
  ],
);

// Repair actions
RepairButton(
  action: RepairAction.rebuildPendingIndex,
  onConfirm: (token) => repairService.execute(
    action: RepairAction.rebuildPendingIndex,
    userId: currentUser.id,
    confirmationToken: token,
  ),
);
```

## Telemetry Keys

### Health Dashboard
- `local_backend.pending_ops`
- `local_backend.failed_ops`
- `local_backend.emergency_ops`
- `local_backend.escalated_ops`
- `local_backend.queue_stalled`

### Repair Service
- `repair.<action>.started`
- `repair.<action>.completed`
- `repair.<action>.failed`
- `repair.<action>.duration_ms`
- `repair.<action>.affected`

### Stall Detector
- `stall_detector.started`
- `stall_detector.stall_detected`
- `stall_detector.stall_duration_seconds`
- `stall_detector.recovery_started`
- `stall_detector.recovery_success`
- `stall_detector.recovery_failed`
- `stall_detector.stale_lock_released`
- `stall_detector.index_rebuilt`

## Audit Log Keys

All events use canonical `AuditType` actions:
- `sosTrigger`, `sosCancel`, `sosDelivered`, `sosEscalated`
- `emergencyEnqueued`, `emergencyProcessed`, `emergencyEscalated`
- `queueStallDetected`, `queueStallRecovered`
- `repairStarted`, `repairCompleted`, `repairFailed`
- `secureEraseStarted`, `secureEraseCompleted`

## Migration Notes

This phase is backward compatible:
- New fields in `LocalBackendStatus` have default values
- New services are opt-in
- No schema changes to Hive boxes
- Existing tests continue to pass

## Summary

The local backend is now **100% complete** with:
- ✅ Full observability through enhanced status
- ✅ Admin repair capabilities with confirmation tokens
- ✅ Standardized audit trail for compliance
- ✅ Self-healing queue through stall detection

The system is production-ready, observable, self-healing, and auditable.
