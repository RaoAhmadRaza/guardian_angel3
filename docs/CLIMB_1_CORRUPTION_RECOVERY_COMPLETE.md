# 🔥 10% CLIMB #1 — 75% → 85% COMPLETE

## Theme: Survive Corruption and Crashes

**Implementation Date**: December 19, 2025

---

## Summary

This CLIMB implements crash resilience and corruption recovery mechanisms for the local backend persistence layer. The implementation ensures the app can survive Hive box corruption and crash-induced incomplete transactions.

---

## Phase 1.1: Hive Corruption Recovery ✅

**Status**: Already implemented in `HiveService._openBoxSafely()` and `_attemptBoxRecovery()`

### Existing Implementation

```dart
// lib/persistence/hive_service.dart

/// Opens a single box with try/catch recovery.
/// 
/// On corruption:
/// 1. Marks box as corrupted (telemetry)
/// 2. Attempts backup of corrupt file
/// 3. Attempts to delete and recreate empty box
/// 4. If all fails, logs and continues (non-fatal for most boxes)
Future<Box<T>?> _openBoxSafely<T>(String boxName, {HiveAesCipher? cipher}) async {
  try {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<T>(boxName);
    }
    
    final box = await Hive.openBox<T>(boxName, encryptionCipher: cipher);
    
    // Register box encryption status for policy enforcement
    if (cipher != null) {
      EncryptionPolicyEnforcer.registerEncryptedBox(boxName);
    }
    
    TelemetryService.I.increment('hive.box_open.success.$boxName');
    return box;
  } catch (e) {
    // Mark box as corrupted
    TelemetryService.I.increment('hive.box_open.failed.$boxName');
    TelemetryService.I.increment('corruption.events');
    
    // Attempt recovery
    await _attemptBoxRecovery<T>(boxName, cipher, e);
    return null;
  }
}

/// Attempts to recover a corrupted box.
/// 
/// Recovery steps:
/// 1. Backup the corrupt file
/// 2. Delete the corrupt file
/// 3. Try to open fresh empty box
Future<void> _attemptBoxRecovery<T>(
  String boxName,
  HiveAesCipher? cipher,
  Object originalError,
) async {
  // ... backup to corruption_backups/$boxName.$timestamp.corrupt.bak
  // ... delete corrupt file
  // ... open fresh box
}
```

### Recovery Flow

```
┌─────────────────┐
│ Open Box        │
└────────┬────────┘
         │
    ┌────▼────┐
    │ Success │──────────► Box Ready
    └────┬────┘
         │ Failure
         ▼
┌─────────────────────┐
│ TelemetryService    │
│ increment(failed)   │
└────────┬────────────┘
         │
         ▼
┌─────────────────────┐
│ Backup corrupt file │
│ to corruption_backups│
└────────┬────────────┘
         │
         ▼
┌─────────────────────┐
│ Delete corrupt file │
└────────┬────────────┘
         │
         ▼
┌─────────────────────┐
│ Open fresh box      │
└────────┬────────────┘
         │
         ▼
     Box Ready (empty)
```

---

## Phase 1.2: Atomic Multi-Box Transactions ✅ (NEW)

**Status**: Newly implemented in `lib/persistence/transactions/transaction_journal.dart`

### TransactionJournal

Provides ACID-like semantics for operations spanning multiple Hive boxes using Write-Ahead Logging (WAL).

```dart
// lib/persistence/transactions/transaction_journal.dart

class TransactionJournal {
  static TransactionJournal get I => _instance;
  
  /// Begin a new transaction
  Future<TransactionHandle> begin(String transactionId);
  
  /// Record a write BEFORE applying it (saves old value for rollback)
  Future<void> record(TransactionHandle handle, String boxName, dynamic key, dynamic currentValue);
  
  /// Commit - mark complete and delete journal entry
  Future<void> commit(TransactionHandle handle);
  
  /// Rollback - restore all entries to their snapshots (LIFO order)
  Future<void> rollback(TransactionHandle handle);
  
  /// Replay incomplete transactions on startup (auto-rollback)
  Future<int> replayPendingJournals();
}
```

### Usage Pattern

```dart
// Atomic batch operation spanning multiple boxes
final txn = await TransactionJournal.I.begin('sync_batch_123');
try {
  // Record BEFORE each write
  await TransactionJournal.I.record(txn, BoxRegistry.pendingOpsBox, opKey, oldOp);
  await pendingBox.put(opKey, newOp);
  
  await TransactionJournal.I.record(txn, BoxRegistry.vitalsBox, vitalKey, oldVital);
  await vitalsBox.put(vitalKey, newVital);
  
  // All writes succeeded - commit
  await TransactionJournal.I.commit(txn);
} catch (e) {
  // Something failed - rollback all changes
  await TransactionJournal.I.rollback(txn);
  rethrow;
}
```

### Transaction States

```
          begin()
             │
             ▼
        ┌─────────┐
        │ ACTIVE  │
        └────┬────┘
             │
      ┌──────┴──────┐
      │             │
  commit()      rollback()
      │             │
      ▼             ▼
┌───────────┐ ┌────────────┐
│ COMMITTING│ │ ROLLING_BACK│
└─────┬─────┘ └──────┬─────┘
      │              │
      ▼              ▼
┌───────────┐ ┌────────────┐
│ COMMITTED │ │ ROLLED_BACK│
└───────────┘ └────────────┘
```

### Startup Recovery

On app startup, `replayPendingJournals()` checks for incomplete transactions and automatically rolls them back:

```dart
// In local_backend_bootstrap.dart
await TransactionJournal.I.init();
final rolledBack = await TransactionJournal.I.replayPendingJournals();
if (rolledBack > 0) {
  TelemetryService.I.increment('local_backend.transaction_journal.replayed');
}
```

---

## Phase 1.3: Auto-run Migrations & TTL Compaction ✅ (NEW)

**Status**: Wired into `local_backend_bootstrap.dart`

### MigrationRunner.runAllPending()

New static convenience method for bootstrap:

```dart
// lib/persistence/migrations/migration_runner.dart

class MigrationRunner {
  /// Static convenience method for bootstrap - runs all pending migrations.
  ///
  /// Creates MetaStore and BoxRegistry internally, suitable for calling
  /// from app_bootstrap.dart without manual wiring.
  static Future<int> runAllPending({bool skipBackup = false}) async {
    // Opens meta box, creates MetaStore, runs migrations
    // Returns count of migrations applied
  }
}
```

### TtlCompactionService.runIfNeeded()

New static convenience method for bootstrap:

```dart
// lib/services/ttl_compaction_service.dart

class TtlCompactionService {
  /// Static convenience method for bootstrap - run TTL purge and compaction if needed.
  ///
  /// Safe to call on every startup; will only compact if conditions are met.
  static Future<Map<String, dynamic>> runIfNeeded({
    int? retentionDays,
    int? compactionThresholdBytes,
  }) async {
    // Purges old vitals, compacts if threshold met
    // Returns summary of actions taken
  }
}
```

### Bootstrap Integration

```dart
// lib/bootstrap/local_backend_bootstrap.dart

Future<void> initLocalBackend() async {
  // ... existing steps 1-6 ...

  // Step 7: Run pending migrations (auto-upgrade schema)
  try {
    final migrationsApplied = await MigrationRunner.runAllPending();
    if (migrationsApplied > 0) {
      TelemetryService.I.increment('local_backend.migrations.ran');
    }
  } catch (e) {
    TelemetryService.I.increment('local_backend.migrations.failed');
    // Non-fatal - app may still work with older schema
  }

  // Step 8: Initialize TransactionJournal and replay incomplete transactions
  try {
    await TransactionJournal.I.init();
    final rolledBack = await TransactionJournal.I.replayPendingJournals();
    if (rolledBack > 0) {
      TelemetryService.I.increment('local_backend.transaction_journal.replayed');
    }
  } catch (e) {
    TelemetryService.I.increment('local_backend.transaction_journal.failed');
    // Non-fatal
  }

  // Step 9: TTL compaction - purge old vitals and compact if needed
  try {
    await TtlCompactionService.runIfNeeded();
    TelemetryService.I.increment('local_backend.ttl_compaction.ran');
  } catch (e) {
    TelemetryService.I.increment('local_backend.ttl_compaction.failed');
    // Non-fatal - will run again next startup
  }

  _localBackendInitialized = true;
}
```

---

## Files Changed

| File | Change |
|------|--------|
| `lib/persistence/transactions/transaction_journal.dart` | **NEW** - TransactionJournal with WAL pattern |
| `lib/persistence/migrations/migration_runner.dart` | Added `runAllPending()` static method |
| `lib/services/ttl_compaction_service.dart` | Added `runIfNeeded()` static method |
| `lib/bootstrap/local_backend_bootstrap.dart` | Added Steps 7-9 for migrations, transactions, TTL |
| `lib/persistence/box_registry.dart` | Added `transactionJournalBox` constant |
| `test/persistence/transactions/transaction_journal_test.dart` | **NEW** - Unit tests |

---

## Telemetry Events Added

| Event | Description |
|-------|-------------|
| `transaction_journal.initialized` | Journal box opened |
| `transaction_journal.begun` | New transaction started |
| `transaction_journal.entry_recorded` | Write recorded to journal |
| `transaction_journal.committed` | Transaction committed |
| `transaction_journal.rollback_started` | Rollback initiated |
| `transaction_journal.rollback_completed` | Rollback finished |
| `transaction_journal.startup_rollbacks` | Count of auto-rollbacks on startup |
| `transaction_journal.corrupt_entry_deleted` | Corrupt journal entry cleaned up |
| `local_backend.migrations.ran` | Migrations executed on startup |
| `local_backend.migrations.failed` | Migration execution failed |
| `local_backend.transaction_journal.replayed` | Journal replay completed |
| `local_backend.transaction_journal.failed` | Journal init/replay failed |
| `local_backend.ttl_compaction.ran` | TTL compaction executed |
| `local_backend.ttl_compaction.failed` | TTL compaction failed |
| `migrations.applied_count` | Number of migrations applied |
| `migrations.total_duration_ms` | Total migration time |
| `ttl_compaction.startup_duration_ms` | TTL compaction time |

---

## Bootstrap Sequence (Updated)

```
┌─────────────────────────────────────────────────────────┐
│                    initLocalBackend()                    │
└─────────────────────────────────────────────────────────┘
                           │
    ┌──────────────────────┼──────────────────────┐
    │                      │                      │
    ▼                      ▼                      ▼
Step 1-3               Step 4-6              Step 7-9
HiveService.init()     Encryption Policy     MigrationRunner.runAllPending()
AdapterCollisionGuard  Queue Integrity       TransactionJournal.init()
HomeAutomation Bridge  Lock Authority        TransactionJournal.replayPendingJournals()
                                             TtlCompactionService.runIfNeeded()
```

---

## Score Impact

| Criteria | Before | After | Notes |
|----------|--------|-------|-------|
| Corruption Recovery | ✅ | ✅ | Already implemented |
| Transaction Atomicity | ❌ | ✅ | NEW: TransactionJournal |
| Auto Migrations | ❌ | ✅ | NEW: Bootstrap wiring |
| TTL Compaction | ❌ | ✅ | NEW: Bootstrap wiring |
| Crash Recovery | ⚠️ | ✅ | Journal replay on startup |

**Estimated Score**: 75% → 85%

---

## Next Steps (CLIMB #2)

Potential focus areas for the next 10% climb:
- Conflict resolution with vector clocks
- Background sync worker with exponential backoff
- Health check aggregation and alerting
- Backup/restore functionality
