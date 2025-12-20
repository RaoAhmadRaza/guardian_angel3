// ignore_for_file: avoid_print, deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'welcome.dart';
// Home Automation screen imports (init handled by bootstrapApp)
import 'home automation/navigation/drawer_wrapper.dart';
import 'home automation/main.dart' show HomeAutomationScreen;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home automation/src/logic/sync/sync_service.dart';
import 'home automation/src/logic/sync/automation_sync_service.dart';
import 'home automation/src/logic/providers/weather_location_providers.dart';
import 'theme.dart';
import 'colors.dart';
import 'providers/theme_provider.dart';
import 'providers/global_provider_observer.dart';
import 'services/onboarding_service.dart';
import 'services/session_service.dart';
import 'screens/onboarding_screen.dart';
import 'next_screen.dart';
import 'caregiver_main_screen.dart';
import 'settings_screen.dart';
import 'caregiver_settings_screen.dart';
// Single mandatory bootstrap
import 'bootstrap/app_bootstrap.dart';
import 'bootstrap/fatal_startup_error.dart';
import 'bootstrap/global_error_boundary.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // GLOBAL ERROR BOUNDARY
  // ═══════════════════════════════════════════════════════════════════════════
  // All errors are caught and logged. App never crashes silently.
  // See lib/bootstrap/global_error_boundary.dart for full implementation.
  // ═══════════════════════════════════════════════════════════════════════════
  GlobalErrorBoundary.instance.initialize();

  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // ═════════════════════════════════════════════════════════════════════════
      // SINGLE MANDATORY STARTUP PIPELINE
      // ═════════════════════════════════════════════════════════════════════════
      // All persistence, validation, and service initialization happens here.
      // If this fails, the app shows a recovery UI instead of crashing.
      // ═════════════════════════════════════════════════════════════════════════
      FatalStartupError? startupError;
      try {
        await bootstrapApp();
      } on FatalStartupError catch (e) {
        startupError = e;
      } catch (e, stackTrace) {
        startupError = FatalStartupError(
          message: 'Unexpected startup failure: $e',
          component: 'main',
          cause: e,
          causeStackTrace: stackTrace,
        );
      }

      // 2. Initialize theme provider (Guardian Angel)
      await ThemeProvider.instance.initialize();

      // 3. System UI styling
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );

      // 4. Run combined app under a single ProviderScope with error observer
      // If startup failed, we'll show the recovery UI instead
      runApp(
        ProviderScope(
          observers: [globalProviderErrorObserver],
          child: startupError != null 
              ? FatalStartupErrorApp(error: startupError)
              : const MyApp(),
        ),
      );
    },
    (error, stack) {
      // Zone-level error handler for uncaught async errors
      GlobalErrorBoundary.instance.handleZoneError(error, stack);
    },
  );
}

/// Shows recovery UI when bootstrap fails.
class FatalStartupErrorApp extends StatelessWidget {
  final FatalStartupError error;
  
  const FatalStartupErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guardian Angel - Recovery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: FatalStartupErrorScreen(error: error),
    );
  }
}

/// Recovery screen shown when bootstrap fails.
class FatalStartupErrorScreen extends StatefulWidget {
  final FatalStartupError error;
  
  const FatalStartupErrorScreen({super.key, required this.error});

  @override
  State<FatalStartupErrorScreen> createState() => _FatalStartupErrorScreenState();
}

class _FatalStartupErrorScreenState extends State<FatalStartupErrorScreen> {
  bool _isRecovering = false;
  String? _recoveryStatus;

  Future<void> _attemptRecovery() async {
    setState(() {
      _isRecovering = true;
      _recoveryStatus = 'Attempting recovery...';
    });

    final result = await attemptRecovery();

    if (result == FatalErrorRecoveryResult.recovered) {
      // Restart the app by navigating to main screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MyApp()),
        );
      }
    } else {
      setState(() {
        _isRecovering = false;
        _recoveryStatus = 'Recovery failed. Please clear app data.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              
              // Error icon
              const Center(
                child: Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 80,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Title
              const Center(
                child: Text(
                  'Startup Failed',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Error message
              Center(
                child: Text(
                  widget.error.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Recovery steps
              if (widget.error.recoverySteps.isNotEmpty) ...[
                const Text(
                  'Recovery Steps:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ...widget.error.recoverySteps.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${entry.key + 1}. ',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              
              // Spacer removed to avoid overflow in smaller viewports
              
              // Recovery status
              if (_recoveryStatus != null)
                Center(
                  child: Text(
                    _recoveryStatus!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ),
              
              const SizedBox(height: 16),
              
              // Retry button
              if (widget.error.isUserRecoverable)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isRecovering ? null : _attemptRecovery,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.eliteBlue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isRecovering
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Try Again',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              
              const SizedBox(height: 24),
              
              // Debug info (only in debug mode)
              if (kDebugMode) ...[
                ExpansionTile(
                  title: const Text(
                    'Debug Info',
                    style: TextStyle(color: Colors.white54),
                  ),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Component: ${widget.error.component}\n'
                        'Telemetry Key: ${widget.error.telemetryKey}\n'
                        'Cause: ${widget.error.cause ?? "N/A"}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep automation engines alive (sync, MQTT/Tuya, location)
    ref.watch(syncServiceProvider);
    ref.watch(automationSyncServiceProvider);
    ref.watch(deviceLocationProvider);
    return ListenableBuilder(
      listenable: ThemeProvider.instance,
      builder: (context, child) {
        return MaterialApp(
          title: 'Guardian Angel',
          debugShowCheckedModeBanner: false,
          theme: AppThemeData.lightTheme,
          darkTheme: AppThemeData.darkTheme,
          themeMode: ThemeProvider.instance.themeMode,
          routes: {
            '/settings': (context) => const SettingsScreen(),
            '/caregiver-settings': (context) => const CaregiverSettingsScreen(),
            '/home-automation': (context) => const DrawerWrapper(homeScreen: HomeAutomationScreen()),
          },
          home: const AppInitializer(),
        );
      },
    );
  }
}

/// Widget that determines the initial screen based on onboarding status
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isLoading = true;
  bool _shouldShowOnboarding = true;
  bool _hasValidSession = false;
  String? _userType;
  String _debugInfo = '';
  bool _showResetButton = kDebugMode;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  /// Initialize app and check onboarding status
  Future<void> _initializeApp() async {
    try {
      print('🚀 AppInitializer: Starting app initialization...');

      // Add a small delay to ensure SharedPreferences is ready
      await Future.delayed(const Duration(milliseconds: 100));

      // Check session first
      final hasValidSession = await SessionService.instance.hasValidSession();
      print('🔐 AppInitializer: Valid session: $hasValidSession');

      // If user has valid session, go directly to main screen
      if (hasValidSession) {
        // Get user type to determine which screen to show
        final userType = await SessionService.instance.getUserType();

        if (mounted) {
          setState(() {
            _hasValidSession = true;
            _userType = userType;
            _shouldShowOnboarding = false;
            _isLoading = false;
            _debugInfo = 'Valid session found for $userType';
          });
        }
        print(
            '🎯 AppInitializer: Will show MAIN screen (valid session for $userType)');
        return;
      }

      // Check onboarding status if no valid session
      final hasCompleted =
          await OnboardingService.instance.hasCompletedOnboarding();
      final debugInfo = await OnboardingService.instance.getDebugInfo();

      print('📱 AppInitializer: Onboarding check complete');
      print('✅ Has completed onboarding: $hasCompleted');
      print('🔍 Debug info: $debugInfo');

      if (mounted) {
        setState(() {
          _shouldShowOnboarding = !hasCompleted;
          _hasValidSession = false;
          _isLoading = false;
          _debugInfo = debugInfo.toString();
        });

        print(
            '🎯 AppInitializer: Will show ${_shouldShowOnboarding ? "ONBOARDING" : "WELCOME"} screen');
      }
    } catch (e, stackTrace) {
      print('❌ AppInitializer Error: $e');
      print('📜 Stack trace: $stackTrace');

      // On error, default to showing onboarding for safety
      if (mounted) {
        setState(() {
          _shouldShowOnboarding = true;
          _hasValidSession = false;
          _isLoading = false;
          _debugInfo = 'Error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: AppTheme.primaryCharcoal,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.eliteBlue),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Initializing Guardian Angel...',
                  style: TextStyle(
                    color: AppTheme.primaryText,
                    fontSize: 16,
                  ),
                ),
                if (_debugInfo.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Debug: $_debugInfo',
                      style: TextStyle(
                        color: AppTheme.primaryText.withOpacity(0.7),
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (_showResetButton)
                  Padding(
                    padding: const EdgeInsets.only(top: 24.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.eliteBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      onPressed: () async {
                        await SessionService.instance.resetSession();
                        await OnboardingService.instance.resetOnboarding();
                        setState(() {
                          _showResetButton = false;
                          _shouldShowOnboarding = true;
                          _hasValidSession = false;
                        });
                      },
                      child: const Text('Reset Onboarding (Debug)'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return _shouldShowOnboarding
        ? const OnboardingScreen()
        : _hasValidSession
            ? (_userType == 'caregiver'
                ? const CaregiverMainScreen()
                : const NextScreen())
            : const WelcomePage();
  }
}
