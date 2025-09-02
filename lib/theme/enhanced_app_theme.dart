import 'package:flutter/material.dart';
import 'enhanced_light_theme.dart';
import 'spacing.dart';
import 'typography.dart';
import 'app_theme.dart';

/// 🎨 Enhanced Theme Integration for Guardian Angel
///
/// Integrates the new enhanced light theme with the existing dark theme
/// to provide a cohesive, premium healthcare interface experience.

class EnhancedAppTheme {
  EnhancedAppTheme._(); // Private constructor

  // ============================================================================
  // 🌟 ENHANCED LIGHT THEME BUILDER
  // ============================================================================

  /// Build the enhanced light theme with premium healthcare aesthetics
  static ThemeData buildEnhancedLightTheme(BuildContext context) {
    final colorScheme = EnhancedLightColorScheme.colorScheme;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,

      // Typography with enhanced readability
      textTheme: AppTypography.getLightTextTheme(context),
      primaryTextTheme: AppTypography.getLightTextTheme(context),

      // Enhanced App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: AppTypography.titleLarge(
          context,
          color: EnhancedLightTheme.textPrimary,
        ),
        iconTheme: const IconThemeData(
          color: EnhancedLightTheme.textPrimary,
          size: 24,
        ),
        actionsIconTheme: const IconThemeData(
          color: EnhancedLightTheme.textPrimary,
          size: 24,
        ),
        centerTitle: false,
        titleSpacing: AppSpacing.lg,
      ),

      // Enhanced Card Theme
      cardTheme: CardThemeData(
        color: EnhancedLightTheme.surfacePrimary,
        elevation: 0,
        shadowColor: EnhancedLightTheme.textPrimary.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.largeRadius,
        ),
        margin: AppSpacing.allMd,
      ),

      // Enhanced Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: EnhancedLightTheme.primary,
          foregroundColor: EnhancedLightTheme.textInverse,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: AppSpacing.buttonPadding,
          minimumSize: const Size(0, AppSpacing.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.largeRadius,
          ),
          textStyle: AppTypography.labelLarge(context),
        ).copyWith(
          backgroundColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.pressed)) {
              return EnhancedLightTheme.primaryVariant;
            }
            if (states.contains(MaterialState.hovered)) {
              return EnhancedLightTheme.primary.withOpacity(0.9);
            }
            return EnhancedLightTheme.primary;
          }),
          shadowColor: MaterialStateProperty.all(Colors.transparent),
          overlayColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.pressed)) {
              return EnhancedLightTheme.pressedPrimary.withOpacity(0.1);
            }
            if (states.contains(MaterialState.hovered)) {
              return EnhancedLightTheme.hoverPrimary.withOpacity(0.1);
            }
            return null;
          }),
        ),
      ),

      // Enhanced Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: EnhancedLightTheme.primary,
          padding: AppSpacing.buttonPadding,
          minimumSize: const Size(0, AppSpacing.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.largeRadius,
          ),
          textStyle: AppTypography.labelLarge(context),
        ).copyWith(
          overlayColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.pressed)) {
              return EnhancedLightTheme.pressedAccent.withOpacity(0.1);
            }
            if (states.contains(MaterialState.hovered)) {
              return EnhancedLightTheme.hoverAccent.withOpacity(0.1);
            }
            return null;
          }),
        ),
      ),

      // Enhanced Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: EnhancedLightTheme.primary,
          side: BorderSide(color: EnhancedLightTheme.borderPrimary),
          padding: AppSpacing.buttonPadding,
          minimumSize: const Size(0, AppSpacing.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.largeRadius,
          ),
          textStyle: AppTypography.labelLarge(context),
        ).copyWith(
          side: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.focused)) {
              return BorderSide(
                  color: EnhancedLightTheme.borderFocus, width: 2);
            }
            if (states.contains(MaterialState.hovered)) {
              return BorderSide(color: EnhancedLightTheme.borderAccent);
            }
            return BorderSide(color: EnhancedLightTheme.borderPrimary);
          }),
          overlayColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.pressed)) {
              return EnhancedLightTheme.pressedSecondary.withOpacity(0.1);
            }
            if (states.contains(MaterialState.hovered)) {
              return EnhancedLightTheme.hoverSecondary.withOpacity(0.1);
            }
            return null;
          }),
        ),
      ),

      // Enhanced Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: EnhancedLightTheme.surfacePrimary,
        contentPadding: AppSpacing.inputPadding,
        border: OutlineInputBorder(
          borderRadius: AppSpacing.largeRadius,
          borderSide: BorderSide(
            color: EnhancedLightTheme.borderPrimary,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppSpacing.largeRadius,
          borderSide: BorderSide(
            color: EnhancedLightTheme.borderPrimary,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppSpacing.largeRadius,
          borderSide: BorderSide(
            color: EnhancedLightTheme.borderFocus,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppSpacing.largeRadius,
          borderSide: BorderSide(
            color: EnhancedLightTheme.borderError,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppSpacing.largeRadius,
          borderSide: BorderSide(
            color: EnhancedLightTheme.borderError,
            width: 2,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: AppSpacing.largeRadius,
          borderSide: BorderSide(
            color: EnhancedLightTheme.borderSecondary,
            width: 1,
          ),
        ),
        hintStyle: AppTypography.bodyMedium(
          context,
          color: EnhancedLightTheme.textPlaceholder,
        ),
        labelStyle: AppTypography.bodyMedium(
          context,
          color: EnhancedLightTheme.textSecondary,
        ),
        errorStyle: AppTypography.bodySmall(
          context,
          color: EnhancedLightTheme.error,
        ),
      ),

      // Enhanced Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: EnhancedLightTheme.primary,
        foregroundColor: EnhancedLightTheme.textInverse,
        elevation: 6,
        focusElevation: 8,
        hoverElevation: 8,
        highlightElevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.extraLargeRadius,
        ),
      ),

      // Enhanced Bottom Navigation Bar Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: EnhancedLightTheme.navBackground,
        selectedItemColor: EnhancedLightTheme.navItemActive,
        unselectedItemColor: EnhancedLightTheme.navItemInactive,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: AppTypography.labelSmall(context),
        unselectedLabelStyle: AppTypography.labelSmall(context),
      ),

      // Enhanced Divider Theme
      dividerTheme: DividerThemeData(
        color: EnhancedLightTheme.divider,
        thickness: 1,
        space: AppSpacing.sm,
      ),

      // Enhanced Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: EnhancedLightTheme.surfaceModal,
        elevation: 24,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.extraLargeRadius,
        ),
        titleTextStyle: AppTypography.headlineSmall(context),
        contentTextStyle: AppTypography.bodyMedium(context),
      ),

      // Enhanced Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: EnhancedLightTheme.textPrimary,
        contentTextStyle: AppTypography.bodyMedium(
          context,
          color: EnhancedLightTheme.textInverse,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.mediumRadius,
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Enhanced Progress Indicator Theme
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: EnhancedLightTheme.primary,
        linearTrackColor: EnhancedLightTheme.selected,
        circularTrackColor: EnhancedLightTheme.selected,
      ),

      // Enhanced Checkbox Theme
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return EnhancedLightTheme.primary;
          }
          return Colors.transparent;
        }),
        checkColor: MaterialStateProperty.all(EnhancedLightTheme.textInverse),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
        ),
      ),

      // Enhanced Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return EnhancedLightTheme.textInverse;
          }
          return EnhancedLightTheme.textTertiary;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return EnhancedLightTheme.primary;
          }
          return EnhancedLightTheme.borderPrimary;
        }),
      ),

      // Override scaffold background
      scaffoldBackgroundColor: EnhancedLightTheme.background,
    );
  }

  // ============================================================================
  // 🌙 KEEP EXISTING DARK THEME (ALREADY POLISHED)
  // ============================================================================

  /// Build dark theme (keeping existing implementation)
  static ThemeData buildDarkTheme(BuildContext context) {
    // Use existing dark theme implementation from AppTheme
    return AppTheme.buildDarkTheme(context);
  }

  // ============================================================================
  // 🎯 THEME RESOLVER
  // ============================================================================

  /// Get appropriate theme based on brightness
  static ThemeData getTheme(BuildContext context, Brightness brightness) {
    return brightness == Brightness.dark
        ? buildDarkTheme(context)
        : buildEnhancedLightTheme(context);
  }
}

/// 🎨 Enhanced Color Helper Extensions
extension EnhancedColorExtensions on Color {
  /// Get appropriate text color for this background
  Color get onColor => EnhancedLightTheme.getTextColor(this);

  /// Create a subtle tint of this color
  Color tint([double amount = 0.1]) {
    return Color.lerp(this, Colors.white, amount) ?? this;
  }

  /// Create a subtle shade of this color
  Color shade([double amount = 0.1]) {
    return Color.lerp(this, Colors.black, amount) ?? this;
  }
}
