# Admin UI Gating & Security

## Overview

The admin UI is protected by multiple layers of security:

1. **Compile-time flag**: `ENABLE_ADMIN_UI` (disabled by default)
2. **Runtime settings**: `Settings.devToolsEnabled` + `Settings.userRole`
3. **Biometric authentication**: Touch ID, Face ID, or device credentials
4. **Sensitive action confirmation**: Additional biometric prompt for destructive operations

## Architecture

### Components

- **`AdminAuthGuard`**: Stateful widget that enforces all security checks
- **`BiometricAuthService`**: Wrapper for `local_auth` package
- **`SettingsModel`**: Extended with `devToolsEnabled` and `userRole` fields
- **`AdminDebugRoute`**: Gated route to admin debug screen
- **`requireBiometricConfirmation()`**: Helper for sensitive action gates

### Security Layers

```
User attempts admin access
    ↓
[1] Compile-time check: kEnableAdminUI
    ├─ false → Reject (production builds)
    └─ true → Continue
        ↓
[2] Runtime Settings check
    ├─ devToolsEnabled=false → Reject
    ├─ userRole≠'admin' → Reject
    └─ Both valid → Continue
        ↓
[3] Biometric authentication
    ├─ Available → Prompt Touch ID/Face ID
    ├─ Unavailable → Fallback to password
    └─ Success → Grant access
        ↓
[4] Sensitive action confirmation
    └─ Biometric prompt before:
        - Key rotation
        - Backup restore
        - Failed ops retry
```

## Usage

### Development Build

Enable admin UI at compile time:

```bash
flutter run --dart-define=ENABLE_ADMIN_UI=true
flutter build apk --dart-define=ENABLE_ADMIN_UI=true
```

**Important**: Never enable for production/release builds.

### Runtime Configuration

Set dev tools access via Settings:

```dart
final settingsBox = Hive.box<SettingsModel>(BoxRegistry.settingsBox);
await settingsBox.put(
  'app_settings',
  SettingsModel(
    notificationsEnabled: true,
    vitalsRetentionDays: 30,
    updatedAt: DateTime.now().toUtc(),
    devToolsEnabled: true,  // Enable dev tools
    userRole: 'admin',       // Grant admin role
  ),
);
```

### Navigation

Use the gated route:

```dart
MaterialApp(
  routes: {
    '/admin': (context) => const AdminDebugRoute(),
  },
)

// Navigate to admin screen
Navigator.of(context).pushNamed('/admin');
```

### Sensitive Actions

Wrap destructive operations with biometric confirmation:

```dart
Future<void> _performDangerousAction() async {
  final authorized = await requireBiometricConfirmation(
    context: context,
    action: 'perform dangerous operation',
  );
  
  if (!authorized) {
    // User cancelled or auth failed
    return;
  }
  
  // Proceed with action
  await _dangerousOperation();
}
```

## Testing

### Unit Tests

```bash
# Test with default compile flag (false)
flutter test test/ui/admin_auth_guard_test.dart

# Test with flag enabled
flutter test --dart-define=ENABLE_ADMIN_UI=true test/ui/admin_auth_guard_test.dart
```

### Integration Tests

Biometric authentication requires physical device or simulator with biometric enrollment:

```bash
flutter drive \
  --target=integration_test/admin_ui_test.dart \
  --dart-define=ENABLE_ADMIN_UI=true
```

## Security Best Practices

### Production Builds

1. **Never** set `ENABLE_ADMIN_UI=true` for release builds
2. Use build flavors to separate dev/prod configurations
3. Verify compile flag in CI/CD pipelines

```yaml
# .github/workflows/build.yml
- name: Build Release APK
  run: flutter build apk --release
  # ENABLE_ADMIN_UI defaults to false
```

### Role Management

Assign admin role only to authenticated staff:

```dart
// During user authentication
Future<void> _onLoginSuccess(User user) async {
  final role = user.isStaff ? 'admin' : 'patient';
  final settings = SettingsModel(
    // ... other fields
    devToolsEnabled: user.isDeveloper,
    userRole: role,
  );
  await saveSettings(settings);
}
```

### Biometric Setup

Prompt users to enroll biometrics during onboarding:

```dart
final biometric = BiometricAuthService();
final available = await biometric.getAvailableBiometrics();

if (available.isEmpty) {
  // Show settings guide
  _showBiometricEnrollmentPrompt();
}
```

## Troubleshooting

### "Admin UI disabled in this build"

**Cause**: `kEnableAdminUI=false` (compile-time flag not set)

**Fix**: Rebuild with `--dart-define=ENABLE_ADMIN_UI=true`

### "Dev tools disabled. Enable in Settings."

**Cause**: `Settings.devToolsEnabled=false`

**Fix**: Update settings via debug script or Settings UI:

```dart
final box = Hive.box<SettingsModel>(BoxRegistry.settingsBox);
final current = box.get('app_settings');
await box.put('app_settings', SettingsModel(
  notificationsEnabled: current!.notificationsEnabled,
  vitalsRetentionDays: current.vitalsRetentionDays,
  updatedAt: DateTime.now().toUtc(),
  devToolsEnabled: true,  // Enable
  userRole: current.userRole,
));
```

### "Admin role required. Current role: patient"

**Cause**: `Settings.userRole != 'admin'`

**Fix**: Update user role (requires authentication):

```dart
await updateUserRole('admin');
```

### Biometric authentication fails

**Fallback**: Use password authentication:

```dart
const AdminAuthGuard(
  requireBiometric: true,
  fallbackPassword: 'your-secure-password',
  child: AdminDebugScreen(),
)
```

**Production**: Remove `fallbackPassword`, require biometric only.

## File Reference

| File | Purpose |
|------|---------|
| `lib/ui/guards/admin_auth_guard.dart` | Multi-layer auth guard widget |
| `lib/services/biometric_auth_service.dart` | Biometric wrapper |
| `lib/models/settings_model.dart` | Settings with security fields |
| `lib/ui/dev/admin_debug_route.dart` | Gated admin route |
| `lib/ui/dev/admin_debug_screen.dart` | Admin tools (gated actions) |
| `test/ui/admin_auth_guard_test.dart` | Auth guard unit tests |

## Migration from Legacy Admin Access

If you have existing admin screens without gating:

1. Wrap existing screens with `AdminAuthGuard`:

```dart
// Before
class MyAdminScreen extends StatelessWidget { ... }

// After
class MyAdminRoute extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const AdminAuthGuard(
      requireBiometric: true,
      child: MyAdminScreen(),
    );
  }
}
```

2. Add biometric confirmation to sensitive actions:

```dart
// Before
ElevatedButton(
  onPressed: _dangerousAction,
  child: Text('Delete All Data'),
)

// After
ElevatedButton(
  onPressed: () async {
    final ok = await requireBiometricConfirmation(
      context: context,
      action: 'delete all data',
    );
    if (ok) await _dangerousAction();
  },
  child: Text('Delete All Data'),
)
```

## Compliance & Audit

All admin actions are logged via `AuditService`:

```dart
// Automatically logged by BackupService, key rotation, etc.
await audit.append(
  type: 'admin_action',
  actor: 'admin_user_id',
  payload: {'action': 'key_rotation', 'timestamp': ...},
);
```

View audit logs:

```dart
final audit = await AuditService.create();
final logs = audit.tail(100);
print(jsonEncode(logs));
```

## Future Enhancements

- [ ] Remote admin feature flags (Firebase Remote Config)
- [ ] Time-based access windows (e.g., 9am-5pm only)
- [ ] Multi-factor authentication (TOTP)
- [ ] Admin session timeout (auto-lock after inactivity)
- [ ] Privileged operation approval workflow (requires two admins)
