# Admin UI Access Runbook

## Quick Reference

**Security Layers**: Compile flag → Runtime settings → Biometric auth

## Enabling Admin UI for Development

### 1. Build with Admin Flag

```bash
# Development build
flutter run --dart-define=ENABLE_ADMIN_UI=true

# Debug APK
flutter build apk --debug --dart-define=ENABLE_ADMIN_UI=true
```

### 2. Enable Runtime Settings

Use Flutter DevTools or debug script to set:

```dart
// In Dart DevTools console or debug script:
import 'package:hive/hive.dart';
import 'package:guardian_angel_fyp/models/settings_model.dart';
import 'package:guardian_angel_fyp/persistence/box_registry.dart';

final box = Hive.box<SettingsModel>(BoxRegistry.settingsBox);
await box.put('app_settings', SettingsModel(
  notificationsEnabled: true,
  vitalsRetentionDays: 30,
  updatedAt: DateTime.now().toUtc(),
  devToolsEnabled: true,
  userRole: 'admin',
));
```

### 3. Navigate to Admin UI

```dart
// From anywhere in app:
Navigator.of(context).pushNamed('/admin');

// Or import route:
Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => const AdminDebugRoute()),
);
```

### 4. Authenticate

- **Biometric**: Touch ID, Face ID, or device PIN
- **Fallback**: Password `dev-admin-2025` (dev builds only)

## Disabling Admin UI for Production

### 1. Build without Flag

```bash
# Release build (default: ENABLE_ADMIN_UI=false)
flutter build apk --release
flutter build ios --release
```

### 2. Verify Compile Flag

```bash
# Check that kEnableAdminUI=false
flutter test test/ui/admin_auth_guard_test.dart
# Should print: "defaults to false" test passes
```

### 3. Runtime Safety

Even if user somehow sets `devToolsEnabled=true`, the compile flag prevents access:

```dart
if (!kEnableAdminUI) {
  // Reject immediately
  return 'Admin UI disabled in this build';
}
```

## Troubleshooting

### Issue: "Admin UI disabled in this build"

**Resolution**: Rebuild with compile flag

```bash
flutter clean
flutter run --dart-define=ENABLE_ADMIN_UI=true
```

### Issue: "Dev tools disabled"

**Resolution**: Enable in settings (requires app restart):

```bash
# Using Flutter CLI
flutter run --dart-define=ENABLE_ADMIN_UI=true

# Then in app, run this via debug console:
# (See step 2 above)
```

### Issue: Biometric prompt doesn't appear

**Check**:
1. Device has biometric enrolled (Settings → Touch ID / Face ID)
2. App has biometric permission (iOS: Info.plist, Android: manifest)

**Fallback**: Use password `dev-admin-2025`

### Issue: "Admin role required. Current role: patient"

**Resolution**: Update user role:

```dart
final box = Hive.box<SettingsModel>(BoxRegistry.settingsBox);
final current = box.get('app_settings');
await box.put('app_settings', SettingsModel(
  notificationsEnabled: current!.notificationsEnabled,
  vitalsRetentionDays: current.vitalsRetentionDays,
  updatedAt: DateTime.now().toUtc(),
  devToolsEnabled: current.devToolsEnabled,
  userRole: 'admin',  // Change from 'patient' to 'admin'
));
```

## Sensitive Actions Require Additional Auth

The following admin actions require biometric confirmation:

- ✓ **Key Rotation**: Re-encrypts all boxes
- ✓ **Backup Restore**: Overwrites existing data
- ✓ **Retry Failed Ops**: Re-executes failed operations

**Each action prompts**: "Authenticate to [action]"

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Build with Admin UI

on:
  workflow_dispatch:
    inputs:
      enable_admin:
        description: 'Enable Admin UI'
        required: true
        default: 'false'
        type: choice
        options:
          - 'true'
          - 'false'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      
      - name: Build APK
        run: |
          if [ "${{ github.event.inputs.enable_admin }}" == "true" ]; then
            flutter build apk --debug --dart-define=ENABLE_ADMIN_UI=true
          else
            flutter build apk --release
          fi
```

## Security Checklist

- [ ] Production builds: `ENABLE_ADMIN_UI=false` ✓
- [ ] Test builds: Document enabled flag in release notes
- [ ] Only staff accounts have `userRole='admin'`
- [ ] Biometric authentication required for sensitive actions
- [ ] Audit logs enabled for all admin actions
- [ ] Admin UI access logged to `AuditService`
- [ ] Fallback password removed from production builds

## Emergency Admin Access (Production)

If admin access is needed in production (e.g., customer support):

1. **DO NOT** rebuild with `ENABLE_ADMIN_UI=true`
2. Use remote logging/telemetry instead
3. Export diagnostic data via standard support flow
4. If absolutely necessary:
   - Build signed dev variant with admin flag
   - Distribute via internal channel only
   - Revoke after support session

## Audit Trail

All admin actions are logged:

```dart
final audit = await AuditService.create();
final logs = audit.tail(50);

// Filter admin actions
final adminLogs = logs.where((log) => 
  log['type']?.toString().startsWith('admin_') ?? false
);

print(jsonEncode(adminLogs));
```

## Files Modified

- `lib/models/settings_model.dart`: Added `devToolsEnabled`, `userRole`
- `lib/persistence/adapters/settings_adapter.dart`: Updated for new fields
- `lib/services/biometric_auth_service.dart`: Biometric wrapper
- `lib/ui/guards/admin_auth_guard.dart`: Multi-layer auth guard
- `lib/ui/dev/admin_debug_route.dart`: Gated route
- `lib/ui/dev/admin_debug_screen.dart`: Added biometric gates
- `test/ui/admin_auth_guard_test.dart`: Security tests
