import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing onboarding state and preferences
class OnboardingService {
  static const String _onboardingCompletedKey = 'onboarding_completed';
  static const String _onboardingVersionKey = 'onboarding_version';
  static const int _currentOnboardingVersion = 1; // Increment this to force re-onboarding
  
  static OnboardingService? _instance;

  /// Get singleton instance
  static OnboardingService get instance {
    _instance ??= OnboardingService._internal();
    return _instance!;
  }

  OnboardingService._internal();

  /// Check if onboarding has been completed for the current version
  Future<bool> hasCompletedOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isCompleted = prefs.getBool(_onboardingCompletedKey) ?? false;
      final version = prefs.getInt(_onboardingVersionKey) ?? 0;
      
      // Return true only if completed AND version matches
      return isCompleted && version >= _currentOnboardingVersion;
    } catch (e) {
      print('Error checking onboarding status: $e');
      // If there's an error, assume onboarding not completed
      return false;
    }
  }

  /// Mark onboarding as completed for the current version
  Future<bool> completeOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final success1 = await prefs.setBool(_onboardingCompletedKey, true);
      final success2 = await prefs.setInt(_onboardingVersionKey, _currentOnboardingVersion);
      
      print('Onboarding completion saved: $success1 && $success2');
      return success1 && success2;
    } catch (e) {
      print('Error saving onboarding completion status: $e');
      return false;
    }
  }

  /// Reset onboarding state (useful for testing or user preference)
  Future<bool> resetOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final success1 = await prefs.remove(_onboardingCompletedKey);
      final success2 = await prefs.remove(_onboardingVersionKey);
      
      print('Onboarding reset: $success1 && $success2');
      return success1 && success2;
    } catch (e) {
      print('Error resetting onboarding status: $e');
      return false;
    }
  }

  /// Get debug information about onboarding state
  Future<Map<String, dynamic>> getDebugInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'completed': prefs.getBool(_onboardingCompletedKey) ?? false,
        'version': prefs.getInt(_onboardingVersionKey) ?? 0,
        'currentVersion': _currentOnboardingVersion,
        'shouldShow': !(await hasCompletedOnboarding()),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Force show onboarding (for development/testing)
  Future<void> forceShowOnboarding() async {
    await resetOnboarding();
  }
}
