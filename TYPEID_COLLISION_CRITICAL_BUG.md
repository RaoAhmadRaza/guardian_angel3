# CRITICAL: Hive TypeId Collision Detected

## Summary
A critical typeId collision exists between transaction models and domain models in the Hive adapter registration system.

## Details

### Conflicting TypeIds

| TypeId | Model 1 (Transaction) | Model 2 (Domain) |
|--------|----------------------|------------------|
| 10 | TransactionRecord | RoomModel |
| 11 | TransactionState | PendingOp |
| 12 | LockRecord | DeviceModel |
| 13 | AuditLogEntry | VitalsModel |
| 14 | AuditLogArchive | UserProfileModel |
| 15 | (unassigned) | SessionModel |
| 16 | (unassigned) | FailedOpModel |
| 17 | (unassigned) | AuditLog |
| 18 | (unassigned) | SettingsModel |
| 19 | (unassigned) | AssetsCacheEntry |

### Source Locations

**Transaction Models:**
- `lib/services/models/transaction_record.dart`:
  ```dart
  @HiveType(typeId: 10)
  class TransactionRecord extends HiveObject { ... }
  
  @HiveType(typeId: 11)
  enum TransactionState { ... }
  ```
- `lib/services/models/lock_record.dart`: typeId 12
- `lib/services/models/audit_log_entry.dart`: typeIds 13, 14

**Domain Models:**
- `lib/persistence/box_registry.dart`:
  ```dart
  class TypeIds {
    static const room = 10;
    static const pendingOp = 11;
    static const device = 12;
    static const vitals = 13;
    static const userProfile = 14;
    static const session = 15;
    static const failedOp = 16;
    static const auditLog = 17;
    static const settings = 18;
    static const assetsCache = 19;
  }
  ```

### Impact

1. **Test Failures**: Adapter round-trip tests fail due to typeId collision
2. **Runtime Risk**: If both sets of adapters are registered in the same Hive instance, only the first registration wins, causing serialization failures for the second
3. **Data Corruption**: Potential for reading wrong data if typeIds are mismatched

### Current Status

- The collision is mitigated in production by careful registration order (TransactionService checks `isAdapterRegistered` before registering)
- Tests that register multiple adapters encounter "already registered" errors
- The adapter_round_trip_test.dart exposed this issue when trying to test all adapters

## Resolution Required

### Short-term (P0):
1. Skip adapter round-trip test OR test adapters individually in isolated files
2. Document the collision and ensure teams are aware

### Long-term (P1):
1. **Option A**: Reassign transaction model typeIds to 30-39 range
   - Requires data migration for existing transaction_log boxes
   - Update TransactionRecord, TransactionState, LockRecord, AuditLogEntry, AuditLogArchive
   
2. **Option B**: Reassign domain model typeIds to 20-29 range
   - Requires data migration for ALL production boxes
   - Much higher risk and effort

3. **Option C**: Use separate Hive instances for transactions vs domain data
   - Most architecturally clean but requires significant refactoring

### Recommended Approach
**Option A** - Move transaction models to typeIds 30-39:
- TransactionRecord: 30
- TransactionState: 31
- LockRecord: 32
- AuditLogEntry: 33
- AuditLogArchive: 34

**Migration Steps:**
1. Create migration script to:
   - Read all records from transaction_log box
   - Re-register adapters with new typeIds
   - Write records back
2. Update all adapter typeId annotations
3. Test thoroughly in staging environment

## Test Status

### P0 Tasks Complete:
✅ Task 2: FailedOpsService.archive() - 15/15 tests passing
✅ Task 3: Idempotency E2E tests - 7/7 tests passing  
⚠️ Task 1: Adapter round-trip tests - BLOCKED by typeId collision

### Workaround for Task 1:
Created comprehensive adapter round-trip test that would validate all adapters IF the typeId collision is resolved. Test is ready to run once collision is fixed.

## Files Affected

### Test Files:
- `test/unit/adapters/adapter_round_trip_test.dart` - Comprehensive adapter tests (currently failing)
- `test/unit/failed_ops_service_archive_test.dart` - ✅ Passing
- `test/integration/idempotency_e2e_test.dart` - ✅ Passing
- `test/persistence/migration_runner_test.dart` - ✅ Passing

### Production Files:
- `lib/services/models/transaction_record.dart`
- `lib/services/models/lock_record.dart`
- `lib/services/models/audit_log_entry.dart`
- `lib/persistence/box_registry.dart`
- All adapter files in `lib/persistence/adapters/`

## Next Actions

1. **Immediate**: Acknowledge this collision and decide on resolution approach
2. **P0**: Complete P0 tasks 2 & 3 (already done ✅)
3. **P1**: Plan and execute typeId remapping migration
4. **P2**: Re-enable adapter round-trip tests after collision resolution

---
*Discovered during P0 task implementation - 2025*
*Test stabilization revealed this architectural issue*
