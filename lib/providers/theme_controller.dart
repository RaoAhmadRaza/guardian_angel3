/// Theme Controller - Riverpod StateNotifier
///
/// Replaces ThemeProvider singleton with proper state management.
/// Part of 10% CLIMB #2: Architectural legitimacy.
///
/// Usage:
/// ```dart
/// // Read current theme
/// final themeState = ref.watch(themeControllerProvider);
///
/// // Toggle theme
/// ref.read(themeControllerProvider.notifier).toggleTheme();
///
/// // Set specific theme
/// ref.read(themeControllerProvider.notifier).setThemeMode(ThemeMode.dark);
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

// ═══════════════════════════════════════════════════════════════════════════
// THEME STATE
// ═══════════════════════════════════════════════════════════════════════════

/// Immutable state representing current theme configuration.
@immutable
class ThemeState {
  final ThemeMode themeMode;
  final bool isInitialized;

  const ThemeState({
    this.themeMode = ThemeMode.system,
    this.isInitialized = false,
  });

  bool get isDarkMode => themeMode == ThemeMode.dark;
  bool get isLightMode => themeMode == ThemeMode.light;
  bool get isSystemMode => themeMode == ThemeMode.system;

  IconData get themeIcon {
    switch (themeMode) {
      case ThemeMode.light:
        return Icons.light_mode_outlined;
      case ThemeMode.dark:
        return Icons.dark_mode_outlined;
      case ThemeMode.system:
        return Icons.brightness_auto_outlined;
    }
  }

  String get themeDescription {
    switch (themeMode) {
      case ThemeMode.light:
        return 'Light Mode';
      case ThemeMode.dark:
        return 'Dark Mode';
      case ThemeMode.system:
        return 'System Default';
    }
  }

  ThemeState copyWith({
    ThemeMode? themeMode,
    bool? isInitialized,
  }) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThemeState &&
          runtimeType == other.runtimeType &&
          themeMode == other.themeMode &&
          isInitialized == other.isInitialized;

  @override
  int get hashCode => themeMode.hashCode ^ isInitialized.hashCode;

  @override
  String toString() => 'ThemeState(themeMode: $themeMode, isInitialized: $isInitialized)';
}

// ═══════════════════════════════════════════════════════════════════════════
// THEME CONTROLLER (StateNotifier)
// ═══════════════════════════════════════════════════════════════════════════

/// StateNotifier for theme management with Hive persistence.
class ThemeController extends StateNotifier<ThemeState> {
  static const String _boxName = 'settings';
  static const String _themeKey = 'theme_mode';

  ThemeController() : super(const ThemeState());

  /// Initialize theme from Hive storage.
  Future<void> initialize() async {
    if (state.isInitialized) return;

    try {
      final box = await Hive.openBox(_boxName);
      final savedIndex = box.get(_themeKey) as int?;

      ThemeMode mode = ThemeMode.system;
      if (savedIndex != null && savedIndex >= 0 && savedIndex < ThemeMode.values.length) {
        mode = ThemeMode.values[savedIndex];
      }

      state = state.copyWith(
        themeMode: mode,
        isInitialized: true,
      );
    } catch (e) {
      debugPrint('Error initializing theme: $e');
      state = state.copyWith(isInitialized: true);
    }
  }

  /// Set theme mode and persist to Hive.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (state.themeMode == mode) return;

    state = state.copyWith(themeMode: mode);

    try {
      final box = await Hive.openBox(_boxName);
      await box.put(_themeKey, mode.index);
    } catch (e) {
      debugPrint('Error saving theme: $e');
    }
  }

  /// Toggle between light, dark, and system themes.
  Future<void> toggleTheme() async {
    switch (state.themeMode) {
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

  /// Set light mode.
  Future<void> setLightMode() => setThemeMode(ThemeMode.light);

  /// Set dark mode.
  Future<void> setDarkMode() => setThemeMode(ThemeMode.dark);

  /// Set system mode.
  Future<void> setSystemMode() => setThemeMode(ThemeMode.system);
}

// ═══════════════════════════════════════════════════════════════════════════
// RIVERPOD PROVIDER
// ═══════════════════════════════════════════════════════════════════════════

/// Main theme controller provider.
///
/// Usage:
/// ```dart
/// // In widget build:
/// final themeState = ref.watch(themeControllerProvider);
/// return MaterialApp(
///   themeMode: themeState.themeMode,
///   ...
/// );
///
/// // To change theme:
/// ref.read(themeControllerProvider.notifier).toggleTheme();
/// ```
final themeControllerProvider = StateNotifierProvider<ThemeController, ThemeState>(
  (ref) => ThemeController(),
);

/// Convenience provider for just the ThemeMode.
final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(themeControllerProvider).themeMode;
});

/// Convenience provider for checking if dark mode is active.
final isDarkModeProvider = Provider<bool>((ref) {
  return ref.watch(themeControllerProvider).isDarkMode;
});
