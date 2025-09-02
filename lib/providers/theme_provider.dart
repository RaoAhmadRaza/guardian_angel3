import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme provider for managing dark/light mode switching with persistence
///
/// This provider handles:
/// - Theme state management using ChangeNotifier
/// - Persistent storage using SharedPreferences
/// - Seamless theme switching without app restart
class ThemeProvider with ChangeNotifier {
  static const String _themePreferenceKey = 'theme_mode';
  static ThemeProvider? _instance;

  ThemeMode _themeMode = ThemeMode.system;
  bool _isInitialized = false;

  /// Get singleton instance
  static ThemeProvider get instance {
    _instance ??= ThemeProvider._internal();
    return _instance!;
  }

  /// Get theme provider from context
  static ThemeProvider of(BuildContext context) {
    return instance;
  }

  /// Private constructor
  ThemeProvider._internal();

  /// Current theme mode
  ThemeMode get themeMode => _themeMode;

  /// Whether the current theme is dark mode
  bool get isDarkMode {
    return _themeMode == ThemeMode.dark;
  }

  /// Whether the current theme is light mode
  bool get isLightMode {
    return _themeMode == ThemeMode.light;
  }

  /// Whether the current theme follows system setting
  bool get isSystemMode {
    return _themeMode == ThemeMode.system;
  }

  /// Check if the provider has been initialized
  bool get isInitialized => _isInitialized;

  /// Initialize theme provider and load saved preference
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedThemeIndex = prefs.getInt(_themePreferenceKey);

      if (savedThemeIndex != null) {
        _themeMode = ThemeMode.values[savedThemeIndex];
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing theme provider: $e');
      _isInitialized = true;
    }
  }

  /// Set theme mode and persist to storage
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themePreferenceKey, mode.index);
    } catch (e) {
      debugPrint('Error saving theme preference: $e');
    }
  }

  /// Toggle between light, dark, and system themes
  Future<void> toggleTheme() async {
    switch (_themeMode) {
      case ThemeMode.light:
        await setThemeMode(ThemeMode.dark);
        break;
      case ThemeMode.dark:
        await setThemeMode(ThemeMode.system);
        break;
      case ThemeMode.system:
        await setThemeMode(ThemeMode.light);
        break;
    }
  }

  /// Get appropriate icon for current theme mode
  IconData get themeIcon {
    switch (_themeMode) {
      case ThemeMode.light:
        return Icons.light_mode_outlined;
      case ThemeMode.dark:
        return Icons.dark_mode_outlined;
      case ThemeMode.system:
        return Icons.brightness_auto_outlined;
    }
  }

  /// Get theme description for current mode
  String get themeDescription {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Light Mode';
      case ThemeMode.dark:
        return 'Dark Mode';
      case ThemeMode.system:
        return 'System Mode';
    }
  }

  /// Reset to system default
  Future<void> resetToSystem() async {
    await setThemeMode(ThemeMode.system);
  }

  /// Clear all preferences (for logout/reset scenarios)
  Future<void> clearPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_themePreferenceKey);
      _themeMode = ThemeMode.system;
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing theme preferences: $e');
    }
  }
}
