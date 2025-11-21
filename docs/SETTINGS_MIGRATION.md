# Settings Model Migration Guide

## Overview

`SettingsModel` has been extended with two new security fields:
- `devToolsEnabled` (bool, default: false)
- `userRole` (String, default: 'patient')

These fields control admin UI access.

## Adapter Changes

### Field Index Update

The `SettingsModelAdapter` now writes **5 fields** (previously 3):

| Index | Field | Type |
|-------|-------|------|
| 0 | notificationsEnabled | bool |
| 1 | vitalsRetentionDays | int |
| 2 | updatedAt | String (ISO8601) |
| 3 | devToolsEnabled | bool |
| 4 | userRole | String |

### Backward Compatibility

The adapter's `read()` method provides safe defaults for missing fields:

```dart
devToolsEnabled: fields[3] as bool? ?? false,
userRole: fields[4] as String? ?? 'patient',
```

Existing persisted settings (written with 3 fields) will automatically get:
- `devToolsEnabled = false`
- `userRole = 'patient'`

## Migration Scenarios

### Scenario 1: Fresh Install

No action needed. Default values are secure:

```dart
SettingsModel(
  notificationsEnabled: true,
  vitalsRetentionDays: 30,
  updatedAt: DateTime.now().toUtc(),
  // devToolsEnabled: false (implicit)
  // userRole: 'patient' (implicit)
)
```

### Scenario 2: Existing Production App

On first access after update, settings will auto-migrate:

1. Old record: `{0: true, 1: 30, 2: '2025-01-01T00:00:00Z'}`
2. Read by new adapter: Adds defaults for fields 3 & 4
3. Next write: Persists all 5 fields

**Result**: Admin UI remains disabled (secure default).

### Scenario 3: Development/Testing Environment

Explicitly enable admin access:

```dart
final box = Hive.box<SettingsModel>(BoxRegistry.settingsBox);
final current = box.get('app_settings');

await box.put('app_settings', SettingsModel(
  notificationsEnabled: current?.notificationsEnabled ?? true,
  vitalsRetentionDays: current?.vitalsRetentionDays ?? 30,
  updatedAt: DateTime.now().toUtc(),
  devToolsEnabled: true,  // Enable for dev
  userRole: 'admin',       // Grant admin role
));
```

### Scenario 4: Multi-User App

Assign roles during login:

```dart
Future<void> onUserLogin(User user) async {
  final role = switch (user.type) {
    UserType.staff => 'admin',
    UserType.caregiver => 'caregiver',
    UserType.patient => 'patient',
  };

  final settings = SettingsModel(
    notificationsEnabled: true,
    vitalsRetentionDays: 30,
    updatedAt: DateTime.now().toUtc(),
    devToolsEnabled: user.isDeveloper,
    userRole: role,
  );

  final box = Hive.box<SettingsModel>(BoxRegistry.settingsBox);
  await box.put('app_settings', settings);
}
```

## Testing Migration

### Unit Test Coverage

Run adapter round-trip test to verify compatibility:

```bash
flutter test test/persistence/adapters/adapter_roundtrip_test.dart
```

### Manual Verification

```dart
// 1. Create settings with old adapter (3 fields)
final oldSettings = SettingsModel(
  notificationsEnabled: true,
  vitalsRetentionDays: 30,
  updatedAt: DateTime.now().toUtc(),
);

// 2. Persist
final box = Hive.box<SettingsModel>(BoxRegistry.settingsBox);
await box.put('test', oldSettings);

// 3. Read with new adapter
final restored = box.get('test');

// 4. Verify defaults applied
assert(restored.devToolsEnabled == false);
assert(restored.userRole == 'patient');
```

## Rollback Plan

If you need to revert to old adapter:

### 1. Restore Old Adapter Code

```dart
@override
void write(BinaryWriter writer, SettingsModel obj) {
  writer
    ..writeByte(3)  // Back to 3 fields
    ..writeByte(0)
    ..write(obj.notificationsEnabled)
    ..writeByte(1)
    ..write(obj.vitalsRetentionDays)
    ..writeByte(2)
    ..write(obj.updatedAt.toUtc().toIso8601String());
  // Remove fields 3 & 4
}
```

### 2. Remove Fields from Model

```dart
class SettingsModel {
  final bool notificationsEnabled;
  final int vitalsRetentionDays;
  final DateTime updatedAt;
  // Remove devToolsEnabled and userRole
}
```

### 3. Rebuild & Deploy

```bash
flutter clean
flutter build apk --release
```

**Note**: Settings will lose admin security fields. Admin UI will be disabled.

## Migration Script (Optional)

For bulk user migration:

```dart
import 'package:hive/hive.dart';
import 'package:guardian_angel_fyp/models/settings_model.dart';
import 'package:guardian_angel_fyp/persistence/box_registry.dart';

Future<void> migrateAllSettings() async {
  final box = Hive.box<SettingsModel>(BoxRegistry.settingsBox);
  
  for (final key in box.keys) {
    final current = box.get(key);
    if (current == null) continue;
    
    // Check if already migrated (has userRole set)
    if (current.userRole != 'patient' && current.devToolsEnabled != false) {
      continue; // Already migrated
    }
    
    // Determine role from user data (pseudocode)
    final userId = key.toString();
    final userRole = await fetchUserRole(userId);
    
    // Update with proper role
    await box.put(key, SettingsModel(
      notificationsEnabled: current.notificationsEnabled,
      vitalsRetentionDays: current.vitalsRetentionDays,
      updatedAt: DateTime.now().toUtc(),
      devToolsEnabled: userRole == 'admin',
      userRole: userRole,
    ));
  }
  
  print('Migrated ${box.length} settings records');
}
```

Run once after deployment:

```dart
void main() async {
  await initHive();
  await migrateAllSettings();
}
```

## Validation Checklist

After migration, verify:

- [ ] Existing users can still access app
- [ ] Settings UI shows correct values
- [ ] Admin users see `userRole='admin'`
- [ ] Non-admin users see `userRole='patient'` or `'caregiver'`
- [ ] Admin UI accessible only with correct flags
- [ ] Biometric auth works for admin actions
- [ ] No data loss in existing settings

## Support

If migration issues occur:

1. Check adapter version: `SettingsModelAdapter().typeId == 18`
2. Verify field count: `writer.writeByte(5)`
3. Review test output: `flutter test test/ui/admin_auth_guard_test.dart`
4. Audit log: Check `AuditService` for migration events

## Related Documentation

- [Admin UI Security](ADMIN_UI_SECURITY.md)
- [Admin UI Runbook](ADMIN_UI_RUNBOOK.md)
- [Settings Model Source](../lib/models/settings_model.dart)
- [Adapter Source](../lib/persistence/adapters/settings_adapter.dart)
