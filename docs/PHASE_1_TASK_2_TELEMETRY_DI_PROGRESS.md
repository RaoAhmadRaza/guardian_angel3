# PHASE 1 TASK 2: TelemetryService.I Singleton Purge - IN PROGRESS

## Summary

**Goal**: Replace `TelemetryService.I` singleton with proper DI pattern

**Status**: 🔄 PARTIAL (~25% complete - 43 usages converted)

## Results

### Before
- **186** `TelemetryService.I.` calls across the codebase

### After
- **143** `TelemetryService.I.` calls remaining (↓43 converted to DI)
- **Zero** compilation errors
- Pattern established for ongoing migration

## Pattern Applied

```dart
// ❌ OLD - Singleton pattern (deprecated)
class MyService {
  void doSomething() {
    TelemetryService.I.increment('my_event');
  }
}

// ✅ NEW - Dependency Injection pattern
class MyService {
  final TelemetryService _telemetry;
  
  MyService({TelemetryService? telemetry})
      : _telemetry = telemetry ?? TelemetryService.I;  // Fallback for backward compat
  
  void doSomething() {
    _telemetry.increment('my_event');
  }
}
```

## Files Updated with DI

### Queue Layer (lib/persistence/queue/)
1. ✅ `emergency_queue_service.dart` - Full DI
2. ✅ `safety_fallback_service.dart` - Full DI
3. ✅ `priority_queue_processor.dart` - Full DI

### Transaction Layer
4. ✅ `lib/persistence/transactions/transaction_journal.dart` - Full DI
5. ✅ `lib/services/transaction_service.dart` - Full DI

### Core Services
6. ✅ `lib/services/lock_service.dart` - Full DI
7. ✅ `lib/services/ttl_compaction_service.dart` - Full DI (instance methods)
8. ✅ `lib/services/backend_idempotency_service.dart` - Full DI
9. ✅ `lib/persistence/hive_service.dart` - Full DI

### Sync Layer
10. ✅ `lib/sync/default_sync_consumer.dart` - Full DI

### Providers Layer
11. ✅ `lib/providers/global_provider_observer.dart` - Full DI

### Health Layer
12. ✅ `lib/persistence/health/backend_health.dart` - Optional parameter on static method

## Files Intentionally NOT Changed

### Pre-Provider Initialization (Can't use DI)
- `lib/bootstrap/app_bootstrap.dart` - Runs BEFORE providers, must use singleton
- `lib/bootstrap/local_backend_bootstrap.dart` - Same reason

### Static Utility Methods (Hard to DI)
- `lib/persistence/wrappers/hive_wrapper.dart` - Static methods
- `lib/persistence/adapter_collision_guard.dart` - Static validation
- `lib/services/ttl_compaction_service.dart` - Static `runIfNeeded()` method
- `lib/persistence/backups/backup_service.dart` - Static methods
- `lib/persistence/backups/data_export_service.dart` - Static export/import

## Remaining Work (143 usages)

### High Priority (Instance classes)
- [ ] `lib/persistence/local_backend_status.dart` - ~8 usages
- [ ] `lib/persistence/encryption_policy.dart` - ~6 usages
- [ ] `lib/persistence/migrations/migration_runner.dart` - ~4 usages
- [ ] `lib/sync/conflict_resolver.dart` - ~3 usages

### Medium Priority (Static utilities)
- [ ] `lib/persistence/adapter_collision_guard.dart` - 7 usages
- [ ] `lib/persistence/index/pending_index.dart` - 2 usages
- [ ] Various guardrail/health files

### Low Priority (Pre-provider bootstrap)
- `lib/bootstrap/app_bootstrap.dart` - 13 usages (CANNOT be changed - runs before providers)

## Benefits Achieved

1. **Testability**: Services can now accept mock telemetry for unit tests
2. **Pattern Established**: Clear pattern for ongoing migration
3. **Backward Compatibility**: Fallback to `.I` singleton when DI not provided
4. **Zero Breaking Changes**: All existing code continues to work

## How to Continue Migration

For each file with `TelemetryService.I.` usage:

1. **Add field**: `final TelemetryService _telemetry;`
2. **Update constructor**: Accept optional parameter with fallback
   ```dart
   MyClass({TelemetryService? telemetry})
       : _telemetry = telemetry ?? TelemetryService.I;
   ```
3. **Replace calls**: `TelemetryService.I.` → `_telemetry.`
4. **For static methods**: Pass telemetry as optional parameter

## Quick Commands

```bash
# Count remaining usages
grep -r "TelemetryService\.I\." lib/ --include="*.dart" | wc -l

# Find files with usages
grep -l "TelemetryService\.I\." lib/**/*.dart

# Bulk replace in a file (after adding _telemetry field)
sed -i '' 's/TelemetryService\.I\./_telemetry./g' path/to/file.dart
```

## Verification

```bash
# Verify no compilation errors
flutter analyze lib/

# Result: 0 errors
```

---
*Started: Current Session*
*Progress: 43/186 usages converted (~23%)*
*Estimated to Complete: 1-2 more sessions*
