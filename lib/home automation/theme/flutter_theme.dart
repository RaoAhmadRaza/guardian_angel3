import 'package:flutter/material.dart';

/// Auto-generated color theme based on the provided UI screenshot.
/// Use `AppTheme.theme` in MaterialApp.

class AppColors {
  AppColors._();

  // Extracted neutral palette
  static const Color white = Color(0xFFFFFFFF);
  static const Color snow = Color(0xFFF2F3F7);
  static const Color lightGrey = Color(0xFFD8DCE3);
  static const Color midGrey = Color(0xFFA6AAB4);
  static const Color darkGrey = Color(0xFF4A4A4C);
  static const Color black = Color(0xFF1D1D1F);

  // Derived accent
  static const Color accent = Color(0xFF2B7DF1); // subtle blue for active states

  // Semantic colors
  static const Color surface = white;
  static const Color card = snow;
  static const Color border = lightGrey;
  static const Color onSurface = black;
  static const Color onPrimary = white;
}

class AppTheme {
  AppTheme._();

  static final ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.accent,
    onPrimary: AppColors.onPrimary,
    secondary: AppColors.midGrey,
    onSecondary: AppColors.white,
    error: Colors.red,
    onError: Colors.white,
    background: AppColors.surface,
    onBackground: AppColors.onSurface,
    surface: AppColors.card,
    onSurface: AppColors.onSurface,
    primaryContainer: AppColors.accent.withOpacity(0.12),
    secondaryContainer: AppColors.lightGrey,
    tertiary: AppColors.midGrey,
    onTertiary: AppColors.black,
    shadow: AppColors.darkGrey,
  );

  static final ThemeData theme = ThemeData.from(colorScheme: lightColorScheme).copyWith(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.surface,
    cardColor: AppColors.card,
    canvasColor: AppColors.surface,

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.onSurface,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: AppColors.onSurface,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: AppColors.onSurface),
    ),

    // Text (Material 3 nomenclature)
    textTheme: const TextTheme(
      titleLarge: TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(color: AppColors.darkGrey),
      bodyMedium: TextStyle(color: AppColors.midGrey),
      bodySmall: TextStyle(color: AppColors.midGrey, fontSize: 12),
    ),

    // Elevated buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    // Outlined buttons / Cards
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.darkGrey,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    // Switch / Toggle
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) return AppColors.black;
        return AppColors.lightGrey;
      }),
      trackColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) return AppColors.accent.withOpacity(0.4);
        return AppColors.lightGrey.withOpacity(0.6);
      }),
    ),

    // Icons
    iconTheme: const IconThemeData(color: AppColors.darkGrey),

    // Dividers/lines
    dividerColor: AppColors.border,

    // Cards
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: const EdgeInsets.all(8),
    ),

    // Slider
    sliderTheme: const SliderThemeData(
      trackHeight: 6,
      thumbColor: AppColors.black,
      activeTrackColor: AppColors.accent,
      inactiveTrackColor: AppColors.lightGrey,
    ),

    // FAB
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.accent,
      foregroundColor: AppColors.onPrimary,
    ),
  );
}
