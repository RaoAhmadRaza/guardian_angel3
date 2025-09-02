import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'colors.dart' show AppColors, AppColorScheme;
import 'spacing.dart';
import 'typography.dart';

/// Comprehensive theme system for Guardian Angel application
/// Integrates Material 3 design with custom brand identity
class AppTheme {
  AppTheme._(); // Private constructor to prevent instantiation

  // ============================================================================
  // THEME BUILDERS
  // ============================================================================

  /// Build complete light theme with Material 3 integration
  static ThemeData buildLightTheme(BuildContext context) {
    final colorScheme = AppColorScheme.lightColorScheme;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,

      // Typography with responsive sizing
      textTheme: AppTypography.getLightTextTheme(context),
      primaryTextTheme: AppTypography.getLightTextTheme(context),

      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: AppTypography.titleLarge(
          context,
          color: AppColors.lightTextPrimary,
        ),
        iconTheme: const IconThemeData(
          color: AppColors.lightTextPrimary,
          size: 24,
        ),
        actionsIconTheme: const IconThemeData(
          color: AppColors.lightTextPrimary,
          size: 24,
        ),
        centerTitle: false,
        titleSpacing: AppSpacing.lg,
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.08),
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.largeRadius,
        ),
        margin: AppSpacing.allMd,
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: AppSpacing.buttonPadding,
          minimumSize: const Size(0, AppSpacing.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.largeRadius,
          ),
          textStyle: AppTypography.labelLarge(context),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          padding: AppSpacing.buttonPadding,
          minimumSize: const Size(0, AppSpacing.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.largeRadius,
          ),
          textStyle: AppTypography.labelLarge(context),
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.outline),
          padding: AppSpacing.buttonPadding,
          minimumSize: const Size(0, AppSpacing.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.largeRadius,
          ),
          textStyle: AppTypography.labelLarge(context),
        ),
      ),

      // Icon Button Theme
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          backgroundColor: Colors.transparent,
          minimumSize: const Size(
            AppSpacing.minTouchTarget,
            AppSpacing.minTouchTarget,
          ),
          padding: AppSpacing.allSm,
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.mediumRadius,
          ),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurface,
        contentPadding: AppSpacing.inputPadding,
        border: OutlineInputBorder(
          borderRadius: AppSpacing.largeRadius,
          borderSide: BorderSide(
            color: AppColors.lightBorder,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppSpacing.largeRadius,
          borderSide: BorderSide(
            color: AppColors.lightBorder,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppSpacing.largeRadius,
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppSpacing.largeRadius,
          borderSide: BorderSide(
            color: colorScheme.error,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppSpacing.largeRadius,
          borderSide: BorderSide(
            color: colorScheme.error,
            width: 2,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: AppSpacing.largeRadius,
          borderSide: BorderSide(
            color: AppColors.lightTextDisabled,
            width: 1,
          ),
        ),
        hintStyle: AppTypography.bodyMedium(
          context,
          color: AppColors.lightTextPlaceholder,
        ),
        labelStyle: AppTypography.bodyMedium(
          context,
          color: AppColors.lightTextSecondary,
        ),
        errorStyle: AppTypography.bodySmall(
          context,
          color: colorScheme.error,
        ),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 6,
        focusElevation: 8,
        hoverElevation: 8,
        highlightElevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.extraLargeRadius,
        ),
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: AppColors.lightTextTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: AppTypography.labelSmall(context),
        unselectedLabelStyle: AppTypography.labelSmall(context),
      ),

      // Navigation Bar Theme (Material 3)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        indicatorColor: colorScheme.primaryContainer,
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return IconThemeData(color: colorScheme.onPrimaryContainer);
          }
          return IconThemeData(color: AppColors.lightTextTertiary);
        }),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return AppTypography.labelSmall(context,
                color: colorScheme.primary);
          }
          return AppTypography.labelSmall(context,
              color: AppColors.lightTextTertiary);
        }),
        height: AppSpacing.bottomNavHeight,
      ),

      // Checkbox Theme
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return colorScheme.primary;
          }
          return Colors.transparent;
        }),
        checkColor: MaterialStateProperty.all(colorScheme.onPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
        ),
      ),

      // Radio Theme
      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return colorScheme.primary;
          }
          return AppColors.lightTextTertiary;
        }),
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return colorScheme.onPrimary;
          }
          return AppColors.lightTextTertiary;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return colorScheme.primary;
          }
          return AppColors.lightBorder;
        }),
      ),

      // Divider Theme
      dividerTheme: DividerThemeData(
        color: AppColors.lightDivider,
        thickness: 1,
        space: AppSpacing.sm,
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightSurfaceVariant,
        deleteIconColor: AppColors.lightTextSecondary,
        disabledColor: AppColors.lightTextDisabled,
        selectedColor: colorScheme.primaryContainer,
        secondarySelectedColor: colorScheme.secondaryContainer,
        shadowColor: Colors.transparent,
        selectedShadowColor: Colors.transparent,
        checkmarkColor: colorScheme.onPrimaryContainer,
        labelPadding: AppSpacing.horizontalSm,
        padding: AppSpacing.allSm,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.pillRadius,
        ),
        brightness: Brightness.light,
        labelStyle: AppTypography.labelMedium(context),
        secondaryLabelStyle: AppTypography.labelMedium(context),
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightSurface,
        elevation: 24,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.extraLargeRadius,
        ),
        titleTextStyle: AppTypography.headlineSmall(context),
        contentTextStyle: AppTypography.bodyMedium(context),
      ),

      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkSurface,
        contentTextStyle: AppTypography.bodyMedium(
          context,
          color: AppColors.darkTextPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.mediumRadius,
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.primaryContainer,
        circularTrackColor: colorScheme.primaryContainer,
      ),

      // Slider Theme
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.primaryContainer,
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withOpacity(0.12),
        valueIndicatorColor: colorScheme.primary,
        valueIndicatorTextStyle: AppTypography.labelSmall(
          context,
          color: colorScheme.onPrimary,
        ),
      ),
    );
  }

  /// Build complete dark theme with Material 3 integration
  static ThemeData buildDarkTheme(BuildContext context) {
    final colorScheme = AppColorScheme.darkColorScheme;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,

      // Typography with responsive sizing
      textTheme: AppTypography.getDarkTextTheme(context),
      primaryTextTheme: AppTypography.getDarkTextTheme(context),

      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: AppTypography.titleLarge(
          context,
          color: AppColors.darkTextPrimary,
        ),
        iconTheme: const IconThemeData(
          color: AppColors.darkTextPrimary,
          size: 24,
        ),
        actionsIconTheme: const IconThemeData(
          color: AppColors.darkTextPrimary,
          size: 24,
        ),
        centerTitle: false,
        titleSpacing: AppSpacing.lg,
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.25),
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.largeRadius,
        ),
        margin: AppSpacing.allMd,
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: AppSpacing.buttonPadding,
          minimumSize: const Size(0, AppSpacing.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.largeRadius,
          ),
          textStyle: AppTypography.labelLarge(context),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          padding: AppSpacing.buttonPadding,
          minimumSize: const Size(0, AppSpacing.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.largeRadius,
          ),
          textStyle: AppTypography.labelLarge(context),
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.outline),
          padding: AppSpacing.buttonPadding,
          minimumSize: const Size(0, AppSpacing.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.largeRadius,
          ),
          textStyle: AppTypography.labelLarge(context),
        ),
      ),

      // Icon Button Theme
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          backgroundColor: Colors.transparent,
          minimumSize: const Size(
            AppSpacing.minTouchTarget,
            AppSpacing.minTouchTarget,
          ),
          padding: AppSpacing.allSm,
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.mediumRadius,
          ),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        contentPadding: AppSpacing.inputPadding,
        border: OutlineInputBorder(
          borderRadius: AppSpacing.largeRadius,
          borderSide: BorderSide(
            color: AppColors.darkBorder,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppSpacing.largeRadius,
          borderSide: BorderSide(
            color: AppColors.darkBorder,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppSpacing.largeRadius,
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppSpacing.largeRadius,
          borderSide: BorderSide(
            color: colorScheme.error,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppSpacing.largeRadius,
          borderSide: BorderSide(
            color: colorScheme.error,
            width: 2,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: AppSpacing.largeRadius,
          borderSide: BorderSide(
            color: AppColors.darkTextDisabled,
            width: 1,
          ),
        ),
        hintStyle: AppTypography.bodyMedium(
          context,
          color: AppColors.darkTextPlaceholder,
        ),
        labelStyle: AppTypography.bodyMedium(
          context,
          color: AppColors.darkTextSecondary,
        ),
        errorStyle: AppTypography.bodySmall(
          context,
          color: colorScheme.error,
        ),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 6,
        focusElevation: 8,
        hoverElevation: 8,
        highlightElevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.extraLargeRadius,
        ),
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: AppColors.darkTextTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: AppTypography.labelSmall(context),
        unselectedLabelStyle: AppTypography.labelSmall(context),
      ),

      // Navigation Bar Theme (Material 3)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        indicatorColor: colorScheme.primaryContainer,
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return IconThemeData(color: colorScheme.onPrimaryContainer);
          }
          return IconThemeData(color: AppColors.darkTextTertiary);
        }),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return AppTypography.labelSmall(context,
                color: colorScheme.primary);
          }
          return AppTypography.labelSmall(context,
              color: AppColors.darkTextTertiary);
        }),
        height: AppSpacing.bottomNavHeight,
      ),

      // Checkbox Theme
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return colorScheme.primary;
          }
          return Colors.transparent;
        }),
        checkColor: MaterialStateProperty.all(colorScheme.onPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
        ),
      ),

      // Radio Theme
      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return colorScheme.primary;
          }
          return AppColors.darkTextTertiary;
        }),
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return colorScheme.onPrimary;
          }
          return AppColors.darkTextTertiary;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return colorScheme.primary;
          }
          return AppColors.darkBorder;
        }),
      ),

      // Divider Theme
      dividerTheme: DividerThemeData(
        color: AppColors.darkDivider,
        thickness: 1,
        space: AppSpacing.sm,
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkSurfaceVariant,
        deleteIconColor: AppColors.darkTextSecondary,
        disabledColor: AppColors.darkTextDisabled,
        selectedColor: colorScheme.primaryContainer,
        secondarySelectedColor: colorScheme.secondaryContainer,
        shadowColor: Colors.transparent,
        selectedShadowColor: Colors.transparent,
        checkmarkColor: colorScheme.onPrimaryContainer,
        labelPadding: AppSpacing.horizontalSm,
        padding: AppSpacing.allSm,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.pillRadius,
        ),
        brightness: Brightness.dark,
        labelStyle: AppTypography.labelMedium(context),
        secondaryLabelStyle: AppTypography.labelMedium(context),
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkSurface,
        elevation: 24,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.extraLargeRadius,
        ),
        titleTextStyle: AppTypography.headlineSmall(context),
        contentTextStyle: AppTypography.bodyMedium(context),
      ),

      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.lightSurface,
        contentTextStyle: AppTypography.bodyMedium(
          context,
          color: AppColors.lightTextPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.mediumRadius,
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.primaryContainer,
        circularTrackColor: colorScheme.primaryContainer,
      ),

      // Slider Theme
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.primaryContainer,
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withOpacity(0.12),
        valueIndicatorColor: colorScheme.primary,
        valueIndicatorTextStyle: AppTypography.labelSmall(
          context,
          color: colorScheme.onPrimary,
        ),
      ),
    );
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Get appropriate theme based on brightness
  static ThemeData getTheme(BuildContext context, Brightness brightness) {
    return brightness == Brightness.dark
        ? buildDarkTheme(context)
        : buildLightTheme(context);
  }

  /// Check if current theme is dark
  static bool isDarkTheme(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  /// Get current color scheme
  static ColorScheme getColorScheme(BuildContext context) {
    return Theme.of(context).colorScheme;
  }

  /// Get theme-appropriate gradient
  static LinearGradient getPrimaryGradient(BuildContext context) {
    return AppColors.getPrimaryGradient(Theme.of(context).brightness);
  }

  /// Get light theme primary gradient
  static LinearGradient get lightPrimaryGradient {
    return AppColors.lightPrimaryGradient;
  }

  /// Get theme-appropriate accent gradient
  static LinearGradient getAccentGradient(BuildContext context) {
    return AppColors.getAccentGradient(Theme.of(context).brightness);
  }

  /// Get theme-appropriate card shadow
  static List<BoxShadow> getCardShadow(BuildContext context) {
    return AppColors.getCardShadow(Theme.of(context).brightness);
  }

  /// Get theme-appropriate button shadow
  static List<BoxShadow> getButtonShadow(BuildContext context) {
    return AppColors.getButtonShadow(Theme.of(context).brightness);
  }

  /// Get theme-appropriate glass effect
  static BoxDecoration getGlassEffect(BuildContext context, {Color? color}) {
    return AppColors.getGlassEffect(Theme.of(context).brightness, color: color);
  }

  /// Generate dynamic gradient based on current theme
  static LinearGradient generateDynamicGradient(
    BuildContext context, {
    required Color seedColor,
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) {
    return AppColors.generateDynamicGradient(
      seedColor: seedColor,
      brightness: Theme.of(context).brightness,
      begin: begin,
      end: end,
    );
  }
}

/// Theme extension for additional custom properties
extension AppThemeExtension on ThemeData {
  /// Get primary gradient for current theme
  LinearGradient get primaryGradient {
    return AppColors.getPrimaryGradient(brightness);
  }

  /// Get accent gradient for current theme
  LinearGradient get accentGradient {
    return AppColors.getAccentGradient(brightness);
  }

  /// Get card shadow for current theme
  List<BoxShadow> get cardShadow {
    return AppColors.getCardShadow(brightness);
  }

  /// Get button shadow for current theme
  List<BoxShadow> get buttonShadow {
    return AppColors.getButtonShadow(brightness);
  }

  /// Get glass effect for current theme
  BoxDecoration getGlassEffect({Color? color}) {
    return AppColors.getGlassEffect(brightness, color: color);
  }
}
