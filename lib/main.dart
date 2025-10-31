// ignore_for_file: avoid_print, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'welcome.dart';
import 'theme.dart';
import 'colors.dart';
import 'providers/theme_provider.dart';
import 'services/onboarding_service.dart';
import 'services/session_service.dart';
import 'screens/onboarding_screen.dart';
import 'next_screen.dart';
import 'caregiver_main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize theme provider
  await ThemeProvider.instance.initialize();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeProvider.instance,
      builder: (context, child) {
        return MaterialApp(
          title: 'Guardian Angel',
          debugShowCheckedModeBanner: false,
          theme: AppThemeData.lightTheme,
          darkTheme: AppThemeData.darkTheme,
          themeMode: ThemeProvider.instance.themeMode,
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
