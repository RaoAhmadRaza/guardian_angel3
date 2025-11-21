# Runbook: Persistence Layer Operations & Recovery

## Critical Concepts

- **Encrypted Boxes**: All sensitive boxes use a Hive AES key stored in secure storage.
- **Schema Version**: Stored in `persistence_metadata_box` and validated during migrations & restore.
- **FIFO Queue**: `pending_ops_box` + `pending_index_box` maintain monotonic processing order.
- **Processing Lock**: Persistent lock in meta box ensures single queue processor; stale after 2 minutes.
- **Backups**: Encrypted tar archive containing JSON dumps + metadata file (`backup_meta.json`).

## Common Procedures

### Rebuild Pending Index

1. Open Admin Debug Screen (dev build only).
2. Tap `Rebuild Index`.
3. Verify log entry: `Index rebuilt`.
4. If corruption persists, export backup, wipe `pending_index_box`, restart app.

### Restore From Encrypted Backup

1. Obtain backup file (`*.tar.enc`).
2. Acquire AES key (check secure storage, rotate if compromised).
3. Call `BackupService.restoreEncryptedBackup()` with expected schemaVersion.
4. On mismatch: run migrations first, then retry restore.
5. Validate record counts vs metadata.

### Key Rotation (Planned Stub)

1. Generate new 32-byte key; store as `hive_key_new`.
2. For each encrypted box: read all -> write to temp box decrypted -> re-encrypt under new key.
3. Swap key reference atomically; delete old key after verification.
4. Log rotation event in `audit_logs_box`.

### Handling Corrupted Box

1. Detect open failure or malformed records.
2. Export encrypted backup (if partial data accessible).
3. Move corrupted `.hive` file to `_corrupted_YYYYMMDD.bak`.
4. Restore from latest known good backup.
5. Re-run migrations; confirm schema version.
6. Add audit log entry `corruption_recovery`.

### Failed Ops Retry & Purge

1. Inspect failed ops in Admin screen (future enhancement).
2. Retry individual: re-enqueue preserving idempotency key.
3. Purge policy: archive + delete records older than retention (default 30d).

### Migration Execution Manual Run

1. Ensure backup taken: `BoxRegistry.backupAllBoxes()`.
2. Invoke migration runner (Admin screen action planned).
3. Check meta box for updated schemaVersion & timestamps.
4. Audit log entry `migration_applied` created per migration.

### Incident: Multiple Processors Detected

1. Check `processing_lock` record; note `startedAt`.
2. If stale (>2m), force acquire by restarting processing component.
3. Log `stale_lock_recovered` in audit logs.

## Monitoring & Alerts

- Track counts: `pending_ops.count`, `failed_ops.count`.
- Alert if `failed_ops.count > threshold` (e.g., 20).
- Migration duration metrics: alert if first-run > 10s.

## Fuzz & Load Testing (Planned)

- Fuzz harness injects truncated JSON into temp boxes, then opens them to validate resilience.
- Load script generates thousands of pending ops; measure enqueue/dequeue latency.

## GDPR/HIPAA Considerations

- Provide export & erasure endpoints for user data.
- Secure deletion requires wiping box files then removing Hive key.
- Audit logs redaction on export (payload replaced with `{redacted: true}`).

## Troubleshooting

| Symptom | Action |
|---------|--------|
| Index missing IDs | Run rebuild; if persists, inspect pending ops for malformed timestamps. |
| Restore fails schema mismatch | Update app / run migrations; retry restore. |
| Encrypted backup decrypt error | Verify AES key bytes length (32) & IV strategy. |
| Persistent lock never releases | Check device clock skew; manually delete `processing_lock` after backup. |
| High failed ops growth | Investigate network/service status; run retry batch; consider exponential backoff. |

## TypeId Collision Recovery

### Symptom
```
HiveError: There is already a TypeAdapter for typeId X
```

### Root Cause
Multiple model classes using the same typeId value, causing adapter registration conflict.

### Immediate Actions

**1. Identify Collisions:**
```bash
# Search for all typeId declarations
grep -rn "typeId:" lib/services/models/ lib/models/ lib/persistence/

# Look for duplicates in TypeIds class
grep -A 20 "class TypeIds" lib/persistence/box_registry.dart
```

**2. Verify Current Allocation:**
```
Domain Models (10-19):   RoomModel(10), PendingOp(11), DeviceModel(12)...
Sync Models (24-26):      SyncFailure(24), Status(25), Severity(26)
Transaction (30-39):      TransactionRecord(30), State(31), LockRecord(32)...
```

**3. Reassign Conflicting TypeIds:**

If pre-production (no user data exists):
```dart
// lib/services/models/your_model.dart
@HiveType(typeId: 30) // Was 10 - moved to new range
class YourModel {
  // ...
}
```

If production (requires migration):
```dart
// Create migration to handle typeId change
class Migration00XTypeIdUpdate implements Migration {
  @override
  Future<void> run(MigrationContext ctx) async {
    // 1. Read all data from old adapter
    final oldBox = await Hive.openBox('your_box_old');
    final allData = oldBox.values.toList();
    
    // 2. Close old box
    await oldBox.close();
    
    // 3. Delete old box file
    await oldBox.deleteFromDisk();
    
    // 4. Register new adapter with new typeId
    Hive.registerAdapter(YourModelAdapterNew());
    
    // 5. Re-create box and restore data
    final newBox = await Hive.openBox('your_box');
    for (final item in allData) {
      await newBox.put(item.id, item);
    }
  }
}
```

**4. Regenerate Adapters:**
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

**5. Update Registration:**
```dart
// lib/persistence/hive_service.dart
Hive
  ..registerAdapter(YourModelAdapter()) // New adapter with new typeId
  // Remove old adapter registration
```

**6. Verify No Conflicts:**
```bash
# Run full test suite
flutter test test/persistence/ test/unit/adapters/

# Check for adapter registration errors
flutter run --verbose 2>&1 | grep -i "typeid"
```

### Rollback Procedure

If migration fails:

```bash
# 1. Stop application
flutter stop

# 2. Restore from backup
# Via Admin UI: Settings → Debug → Restore Backup
# Or programmatically:
await BackupService.restoreEncryptedBackup(
  backupPath: '/path/to/pre_migration_backup.tar.enc',
  aesKey: encryptionKey,
);

# 3. Revert code changes
git revert <commit-hash>

# 4. Rebuild adapters
flutter pub run build_runner build --delete-conflicting-outputs

# 5. Restart application
flutter run
```

### Safe Adapter Removal

**When to Remove Old Adapters:**
- ✅ After successful migration in all environments (dev/staging/prod)
- ✅ After retention period (e.g., 30 days post-migration)
- ✅ After verifying no rollback needed
- ❌ NEVER remove before migration completes
- ❌ NEVER remove if users on old app versions exist

**How to Remove:**

```bash
# 1. Locate legacy adapter files
find lib/persistence/adapters/legacy -name "*_adapter_old.dart"

# 2. Verify no imports reference legacy adapters
grep -rn "adapter_old" lib/ test/

# 3. Remove files
rm lib/persistence/adapters/legacy/your_model_adapter_old.dart

# 4. Update generated files
flutter pub run build_runner build --delete-conflicting-outputs

# 5. Run full test suite
flutter test

# 6. Commit removal
git add .
git commit -m "chore: remove legacy adapters after successful migration"
```

**Legacy Adapter Checklist:**
- [ ] All users migrated to new schema version
- [ ] Backup retention period expired
- [ ] No references in codebase to old adapter
- [ ] Full test suite passes
- [ ] Rollback plan documented
- [ ] Stakeholder approval obtained

### Prevention

**TypeId Allocation Policy:**
1. **Check allocation map** before assigning new typeId
2. **Document immediately** in `docs/persistence.md` and code comments
3. **Review during PR** - require typeId verification
4. **Automated check** in CI:
```yaml
# .github/workflows/ci.yml
- name: Check TypeId Collisions
  run: |
    # Extract all typeIds and check for duplicates
    grep -roh "typeId: [0-9]*" lib/ | sort | uniq -d | tee duplicates.txt
    if [ -s duplicates.txt ]; then
      echo "TypeId collision detected!"
      exit 1
    fi
```

## Future Enhancements

- Key rotation automation.
- Retention scheduler for vitals & audit logs.
- Structured metrics ingestion.
- Admin UI for failed ops management.
- Automated typeId collision detection in pre-commit hooks.
