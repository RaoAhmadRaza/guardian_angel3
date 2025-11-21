import 'package:flutter/material.dart';
import '../guards/admin_auth_guard.dart';
import 'admin_debug_screen.dart';

/// Gated route to AdminDebugScreen with all security checks.
/// 
/// Usage in app routing:
/// ```dart
/// MaterialApp(
///   routes: {
///     '/admin': (context) => const AdminDebugRoute(),
///   },
/// )
/// ```
/// 
/// Build with admin UI enabled:
/// ```bash
/// flutter build apk --dart-define=ENABLE_ADMIN_UI=true
/// flutter run --dart-define=ENABLE_ADMIN_UI=true
/// ```
/// 
/// Runtime requirements:
/// 1. Settings.devToolsEnabled = true (set via Settings UI or debug script)
/// 2. Settings.userRole = 'admin' (set during user authentication/onboarding)
/// 3. Biometric authentication or fallback password
class AdminDebugRoute extends StatelessWidget {
  const AdminDebugRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminAuthGuard(
      requireBiometric: true,
      fallbackPassword: 'dev-admin-2025', // TODO: Remove in production
      child: AdminDebugScreen(),
    );
  }
}
