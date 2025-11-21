# Admin UI Security - Quick Command Reference

## Build Commands

```bash
# Development build with admin UI enabled
flutter run --dart-define=ENABLE_ADMIN_UI=true

# Debug APK with admin UI
flutter build apk --debug --dart-define=ENABLE_ADMIN_UI=true

# Production build (admin UI disabled by default)
flutter build apk --release

# iOS release (admin UI disabled)
flutter build ios --release
```

## Test Commands

```bash
# Run admin auth tests
flutter test test/ui/admin_auth_guard_test.dart

# Run adapter compatibility tests
flutter test test/persistence/adapters/adapter_roundtrip_test.dart

# Full test suite
flutter test

# Test with admin flag enabled
flutter test --dart-define=ENABLE_ADMIN_UI=true
```

## Runtime Settings Commands

```dart
// Enable admin access (run in Flutter DevTools console)
import 'package:hive/hive.dart';
import 'package:guardian_angel_fyp/models/settings_model.dart';
import 'package:guardian_angel_fyp/persistence/box_registry.dart';

final box = Hive.box<SettingsModel>(BoxRegistry.settingsBox);
await box.put('app_settings', SettingsModel(
  notificationsEnabled: true,
  vitalsRetentionDays: 30,
  updatedAt: DateTime.now().toUtc(),
  devToolsEnabled: true,  // Enable
  userRole: 'admin',       // Grant role
));

// Disable admin access
await box.put('app_settings', SettingsModel(
  notificationsEnabled: true,
  vitalsRetentionDays: 30,
  updatedAt: DateTime.now().toUtc(),
  devToolsEnabled: false,  // Disable
  userRole: 'patient',     // Revoke
));

// Check current settings
final settings = box.get('app_settings');
print('Dev tools: ${settings?.devToolsEnabled}');
print('User role: ${settings?.userRole}');
```

## Navigation Commands

```dart
// Navigate to admin UI
Navigator.of(context).pushNamed('/admin');

// Or with route object
Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => const AdminDebugRoute()),
);
```

## Audit Commands

```dart
// View recent admin actions
import 'package:guardian_angel_fyp/persistence/audit/audit_service.dart';

final audit = await AuditService.create();
final logs = audit.tail(50);
print(jsonEncode(logs));

// Filter admin actions
final adminLogs = logs.where((log) => 
  log['type']?.toString().contains('admin') ?? false
);
```

## Biometric Testing

```dart
// Check biometric availability
import 'package:guardian_angel_fyp/services/biometric_auth_service.dart';

final bio = BiometricAuthService();
final canAuth = await bio.canCheckBiometrics();
final types = await bio.getAvailableBiometrics();
print('Available: $canAuth, Types: $types');

// Test authentication
final result = await bio.authenticate(
  localizedReason: 'Test authentication',
);
print('Auth result: $result');
```

## Debug Commands

```bash
# Check compile flag value
flutter run --dart-define=ENABLE_ADMIN_UI=true -v | grep ENABLE_ADMIN_UI

# Analyze code
flutter analyze

# Format code
dart format lib/ test/

# Dependency audit
flutter pub outdated

# Clean build artifacts
flutter clean
```

## CI/CD Integration

```yaml
# GitHub Actions example
name: Build Admin Build
on:
  workflow_dispatch:
    inputs:
      enable_admin:
        type: choice
        options: [true, false]
        default: false

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - name: Build
        run: |
          if [ "${{ inputs.enable_admin }}" == "true" ]; then
            flutter build apk --debug --dart-define=ENABLE_ADMIN_UI=true
          else
            flutter build apk --release
          fi
```

## Emergency Access

If admin access is needed in production:

1. **DO NOT** rebuild production app with admin flag
2. Use remote logging/telemetry for diagnostics
3. If absolutely necessary:
   - Create signed dev build with admin flag
   - Distribute via internal TestFlight/Firebase App Distribution
   - Revoke after support session complete

## Security Verification

```bash
# Verify compile flag is false in release
flutter test test/ui/admin_auth_guard_test.dart --release

# Check settings defaults
flutter test test/ui/admin_auth_guard_test.dart -r expanded

# Audit adapter migration
flutter test test/persistence/adapters/adapter_roundtrip_test.dart
```

## Troubleshooting Commands

```dart
// Reset all settings to defaults
final box = Hive.box<SettingsModel>(BoxRegistry.settingsBox);
await box.clear();

// Force reload settings
await box.close();
await Hive.openBox<SettingsModel>(BoxRegistry.settingsBox);

// Check Hive path
print(Hive.box(BoxRegistry.settingsBox).path);

// Export settings for debugging
final settings = box.get('app_settings');
print(jsonEncode(settings?.toJson()));
```

## File Locations

| Component | Path |
|-----------|------|
| Auth Guard | `lib/ui/guards/admin_auth_guard.dart` |
| Biometric Service | `lib/services/biometric_auth_service.dart` |
| Settings Model | `lib/models/settings_model.dart` |
| Admin Route | `lib/ui/dev/admin_debug_route.dart` |
| Admin Screen | `lib/ui/dev/admin_debug_screen.dart` |
| Tests | `test/ui/admin_auth_guard_test.dart` |
| Docs | `docs/ADMIN_UI_SECURITY.md` |

## Environment Variables

```bash
# Development
export ENABLE_ADMIN_UI=true
flutter run --dart-define=ENABLE_ADMIN_UI=$ENABLE_ADMIN_UI

# Production
unset ENABLE_ADMIN_UI  # Defaults to false
flutter build apk --release
```

## Quick Checklist

### Before Release

- [ ] `kEnableAdminUI` defaults to `false`
- [ ] No `--dart-define=ENABLE_ADMIN_UI=true` in release scripts
- [ ] Test suite passes: `flutter test`
- [ ] Settings defaults verified: `devToolsEnabled=false`, `userRole='patient'`
- [ ] Biometric gates functional on test devices
- [ ] Audit logs reviewed for unauthorized access attempts

### After Deployment

- [ ] Monitor audit logs for admin actions
- [ ] Track biometric auth failure rates
- [ ] Alert on `devToolsEnabled` changes
- [ ] Document any admin access incidents
