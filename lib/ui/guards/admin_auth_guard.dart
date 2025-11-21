import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../models/settings_model.dart';
import '../../persistence/box_registry.dart';
import '../../services/biometric_auth_service.dart';

/// Compile-time flag: must be set during build with --dart-define=ENABLE_ADMIN_UI=true
const bool kEnableAdminUI = bool.fromEnvironment('ENABLE_ADMIN_UI', defaultValue: false);

/// Guards admin UI access with multi-layer checks:
/// 1. Compile-time ENABLE_ADMIN_UI flag
/// 2. Runtime Settings.devToolsEnabled
/// 3. User role == 'admin'
/// 4. Optional biometric/password authentication
class AdminAuthGuard extends StatefulWidget {
  final Widget child;
  final bool requireBiometric;
  final String? fallbackPassword; // For dev/testing; production should use biometric only

  const AdminAuthGuard({
    super.key,
    required this.child,
    this.requireBiometric = true,
    this.fallbackPassword,
  });

  @override
  State<AdminAuthGuard> createState() => _AdminAuthGuardState();
}

class _AdminAuthGuardState extends State<AdminAuthGuard> {
  bool _isAuthorized = false;
  bool _isLoading = true;
  String _errorMessage = '';
  final BiometricAuthService _biometricService = BiometricAuthService();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkAccess() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    // Check 1: Compile-time flag
    if (!kEnableAdminUI) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Admin UI disabled in this build';
      });
      return;
    }

    // Check 2: Runtime settings
    if (!Hive.isBoxOpen(BoxRegistry.settingsBox)) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Settings not available';
      });
      return;
    }

    final settingsBox = Hive.box<SettingsModel>(BoxRegistry.settingsBox);
    final settings = settingsBox.get('app_settings');
    
    if (settings == null || !settings.devToolsEnabled) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Dev tools disabled. Enable in Settings.';
      });
      return;
    }

    // Check 3: User role
    if (settings.userRole != 'admin') {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Admin role required. Current role: ${settings.userRole}';
      });
      return;
    }

    // Check 4: Biometric or password authentication
    if (widget.requireBiometric) {
      final canBiometric = await _biometricService.canCheckBiometrics();
      if (canBiometric) {
        final authenticated = await _biometricService.authenticate(
          localizedReason: 'Authenticate to access admin tools',
          biometricOnly: false,
        );
        if (authenticated) {
          setState(() {
            _isAuthorized = true;
            _isLoading = false;
          });
          return;
        }
      }
      // Fallback to password if biometric fails or unavailable
      setState(() => _isLoading = false);
      return; // Show password prompt
    }

    // No biometric required - grant access
    setState(() {
      _isAuthorized = true;
      _isLoading = false;
    });
  }

  Future<void> _authenticateWithPassword() async {
    if (widget.fallbackPassword == null) {
      setState(() => _errorMessage = 'Password authentication not configured');
      return;
    }
    
    if (_passwordController.text == widget.fallbackPassword) {
      setState(() {
        _isAuthorized = true;
        _errorMessage = '';
      });
    } else {
      setState(() => _errorMessage = 'Incorrect password');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAuthorized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Access Required')),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.lock, size: 64, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 24),
              if (_errorMessage.isNotEmpty)
                Text(
                  _errorMessage,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              if (widget.fallbackPassword != null && widget.requireBiometric) ...[
                const SizedBox(height: 32),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Admin Password',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _authenticateWithPassword(),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _authenticateWithPassword,
                  icon: const Icon(Icons.password),
                  label: const Text('Authenticate'),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _checkAccess,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Retry Biometric'),
                ),
              ],
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return widget.child;
  }
}

/// Helper to prompt biometric authentication for sensitive actions.
/// Returns true if authorized.
Future<bool> requireBiometricConfirmation({
  required BuildContext context,
  required String action,
}) async {
  final biometric = BiometricAuthService();
  final canAuth = await biometric.canCheckBiometrics();
  
  if (!canAuth) {
    // Fallback: show confirmation dialog
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Action'),
        content: Text('Are you sure you want to $action?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ?? false;
  }

  return await biometric.authenticate(
    localizedReason: 'Authenticate to $action',
    biometricOnly: false,
  );
}
