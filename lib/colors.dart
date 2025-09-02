import 'package:flutter/material.dart';
import 'theme/colors.dart' as ThemeColors;

/// Legacy AppTheme class for backward compatibility
/// All new code should use the new theme system in lib/theme/
@deprecated
class AppTheme {
  // Redirect legacy color constants to new monochromatic theme system
  static const Color eliteBlue = ThemeColors.AppColors.lightPrimary;
  static const Color luxuryPurple = ThemeColors.AppColors.lightSecondary;
  static const Color accentColor = ThemeColors.AppColors.lightAccent;
  static const Color errorColor = ThemeColors.AppColors.errorLight;

  // Legacy dark theme colors
  static const Color backgroundColor = ThemeColors.AppColors.darkBackground;
  static const Color surfaceColor = ThemeColors.AppColors.darkSurface;
  static const Color cardColor = ThemeColors.AppColors.darkCard;
  static const Color overlayColor = ThemeColors.AppColors.darkOverlay;

  // Legacy text colors
  static const Color primaryText = ThemeColors.AppColors.darkTextPrimary;
  static const Color secondaryText = ThemeColors.AppColors.darkTextSecondary;
  static const Color tertiaryText = ThemeColors.AppColors.darkTextTertiary;
  static const Color placeholderText =
      ThemeColors.AppColors.darkTextPlaceholder;
  static const Color borderColor = ThemeColors.AppColors.darkBorder;

  // Legacy light theme colors
  static const Color lightBackgroundColor =
      ThemeColors.AppColors.lightBackground;
  static const Color lightSurfaceColor = ThemeColors.AppColors.lightSurface;
  static const Color lightCardColor = ThemeColors.AppColors.lightCard;
  static const Color lightOverlayColor = ThemeColors.AppColors.lightOverlay;

  // Legacy light text colors
  static const Color lightPrimaryText = ThemeColors.AppColors.lightTextPrimary;
  static const Color lightSecondaryText =
      ThemeColors.AppColors.lightTextSecondary;
  static const Color lightTertiaryText =
      ThemeColors.AppColors.lightTextTertiary;
  static const Color lightPlaceholderText =
      ThemeColors.AppColors.lightTextPlaceholder;
  static const Color lightBorderColor = ThemeColors.AppColors.lightBorder;

  // Legacy gradients - redirect to new theme system
  static const LinearGradient primaryGradient =
      ThemeColors.AppColors.darkPrimaryGradient;
  static const LinearGradient accentGradient =
      ThemeColors.AppColors.darkAccentGradient;
  static const LinearGradient warmGradient =
      ThemeColors.AppColors.darkPrimaryGradient; // Fallback to primary
  static const LinearGradient premiumGradient =
      ThemeColors.AppColors.darkPrimaryGradient; // Fallback to primary
  static const LinearGradient goldGradient =
      ThemeColors.AppColors.lightPrimaryGradient; // Fallback to light primary

  static const LinearGradient lightPrimaryGradient =
      ThemeColors.AppColors.lightPrimaryGradient;
  static const LinearGradient lightSecondaryGradient =
      ThemeColors.AppColors.lightSecondaryGradient;
  static const LinearGradient lightAccentGradient =
      ThemeColors.AppColors.lightAccentGradient;

  // Legacy shadow colors
  static const Color shadowColor = Color(0x40000000);

  // Legacy gradient definitions for compatibility
  static const Color primaryCharcoal = Color(0xFF1A1A1A);
  static const Color deepGraphite = Color(0xFF2C2C2E);
  static const Color richNavy = Color(0xFF1C1C2E);
  static const Color premiumGold = Color(0xFFE6B800);

  // Legacy glass morphism effect - redirect to new theme system
  static BoxDecoration glassEffect({Color? color}) {
    return ThemeColors.AppColors.getGlassEffect(Brightness.dark, color: color);
  }

  // Legacy shadow definitions - redirect to new theme system
  static List<BoxShadow> get cardShadow =>
      ThemeColors.AppColors.getCardShadow(Brightness.dark);
  static List<BoxShadow> get lightCardShadow =>
      ThemeColors.AppColors.getCardShadow(Brightness.light);
  static List<BoxShadow> get buttonShadow =>
      ThemeColors.AppColors.getButtonShadow(Brightness.dark);
  static List<BoxShadow> get socialButtonShadow => [
        // Custom grayish shadow for dark theme social login buttons
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          blurRadius: 100,
          offset: const Offset(0, 8),
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 15,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
      ];
  static List<BoxShadow> get lightSocialButtonShadow => [
        // Grayish professional shadows for light theme social buttons
        BoxShadow(
          color: const Color(0xFF475569).withOpacity(0.08),
          blurRadius: 16,
          offset: const Offset(0, 2),
          spreadRadius: 0,
        ),
        BoxShadow(
          color: const Color(0xFF64748B).withOpacity(0.05),
          blurRadius: 24,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
      ];
}

/// Legacy colors for backward compatibility
@deprecated
class CloudMistColors {
  static const Color bossGray = ThemeColors.AppColors.darkTextTertiary;
  static const Color chillBg = ThemeColors.AppColors.darkBackground;
  static const Color fullWhite = ThemeColors.AppColors.darkSurface;
  static const Color textBoss = ThemeColors.AppColors.darkTextPrimary;
  static const Color popAccent =
      ThemeColors.AppColors.lightPrimary; // Fixed mapping
  static const Color dropShadow = ThemeColors.AppColors.darkBorder;
}
