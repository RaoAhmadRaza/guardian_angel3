import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'spacing.dart';

/// Responsive typography system for Guardian Angel application
/// Implements dynamic type scaling and responsive sizing based on screen dimensions
class AppTypography {
  AppTypography._(); // Private constructor to prevent instantiation

  // ============================================================================
  // BASE FONT FAMILY
  // ============================================================================

  /// Primary font family - Inter
  static String get primaryFontFamily => GoogleFonts.inter().fontFamily!;

  /// Fallback font family
  static const String fallbackFontFamily = 'system-ui';

  // ============================================================================
  // BASE TYPE SCALE - Following Material 3 Design guidelines
  // ============================================================================

  /// Display Large - 57sp
  static const double displayLargeSize = 57.0;
  static const double displayLargeHeight = 64.0;
  static const FontWeight displayLargeWeight = FontWeight.w400;

  /// Display Medium - 45sp
  static const double displayMediumSize = 45.0;
  static const double displayMediumHeight = 52.0;
  static const FontWeight displayMediumWeight = FontWeight.w400;

  /// Display Small - 36sp
  static const double displaySmallSize = 36.0;
  static const double displaySmallHeight = 44.0;
  static const FontWeight displaySmallWeight = FontWeight.w400;

  /// Headline Large - 32sp
  static const double headlineLargeSize = 32.0;
  static const double headlineLargeHeight = 40.0;
  static const FontWeight headlineLargeWeight = FontWeight.w700;

  /// Headline Medium - 28sp
  static const double headlineMediumSize = 28.0;
  static const double headlineMediumHeight = 36.0;
  static const FontWeight headlineMediumWeight = FontWeight.w700;

  /// Headline Small - 24sp
  static const double headlineSmallSize = 24.0;
  static const double headlineSmallHeight = 32.0;
  static const FontWeight headlineSmallWeight = FontWeight.w600;

  /// Title Large - 22sp
  static const double titleLargeSize = 22.0;
  static const double titleLargeHeight = 28.0;
  static const FontWeight titleLargeWeight = FontWeight.w600;

  /// Title Medium - 16sp
  static const double titleMediumSize = 16.0;
  static const double titleMediumHeight = 24.0;
  static const FontWeight titleMediumWeight = FontWeight.w500;

  /// Title Small - 14sp
  static const double titleSmallSize = 14.0;
  static const double titleSmallHeight = 20.0;
  static const FontWeight titleSmallWeight = FontWeight.w500;

  /// Label Large - 14sp
  static const double labelLargeSize = 14.0;
  static const double labelLargeHeight = 20.0;
  static const FontWeight labelLargeWeight = FontWeight.w500;

  /// Label Medium - 12sp
  static const double labelMediumSize = 12.0;
  static const double labelMediumHeight = 16.0;
  static const FontWeight labelMediumWeight = FontWeight.w500;

  /// Label Small - 11sp
  static const double labelSmallSize = 11.0;
  static const double labelSmallHeight = 16.0;
  static const FontWeight labelSmallWeight = FontWeight.w500;

  /// Body Large - 16sp
  static const double bodyLargeSize = 16.0;
  static const double bodyLargeHeight = 24.0;
  static const FontWeight bodyLargeWeight = FontWeight.w400;

  /// Body Medium - 14sp
  static const double bodyMediumSize = 14.0;
  static const double bodyMediumHeight = 20.0;
  static const FontWeight bodyMediumWeight = FontWeight.w400;

  /// Body Small - 12sp
  static const double bodySmallSize = 12.0;
  static const double bodySmallHeight = 16.0;
  static const FontWeight bodySmallWeight = FontWeight.w400;

  // ============================================================================
  // RESPONSIVE SCALING FACTORS
  // ============================================================================

  /// Get responsive font size multiplier based on screen width
  static double getResponsiveFontScale(double screenWidth) {
    if (screenWidth >= AppBreakpoints.largeDesktop) {
      return 1.2; // 20% larger for large desktop
    } else if (screenWidth >= AppBreakpoints.desktop) {
      return 1.1; // 10% larger for desktop
    } else if (screenWidth >= AppBreakpoints.tablet) {
      return 1.05; // 5% larger for tablet
    } else {
      return 1.0; // Base size for mobile
    }
  }

  /// Get dynamic font size with accessibility scaling
  static double getDynamicFontSize(
    double baseSize,
    double screenWidth,
    double textScaleFactor,
  ) {
    final responsiveScale = getResponsiveFontScale(screenWidth);
    final scaledSize = baseSize * responsiveScale;

    // Apply text scale factor with constraints to prevent excessive scaling
    final maxScale = 1.5; // Maximum 150% scaling for readability
    final constrainedScale = textScaleFactor.clamp(0.8, maxScale);

    return scaledSize * constrainedScale;
  }

  /// Get dynamic line height based on font size
  static double getDynamicLineHeight(double fontSize) {
    // Maintain good readability with proportional line height
    return fontSize * 1.4; // 1.4x line height ratio
  }

  // ============================================================================
  // TEXT STYLE GENERATORS
  // ============================================================================

  /// Generate Display Large text style
  static TextStyle displayLarge(
    BuildContext context, {
    Color? color,
    double? letterSpacing,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final textScaleFactor = mediaQuery.textScaleFactor;

    final fontSize = getDynamicFontSize(
      displayLargeSize,
      screenWidth,
      textScaleFactor,
    );

    return GoogleFonts.inter(
      fontSize: fontSize,
      height: getDynamicLineHeight(fontSize) / fontSize,
      fontWeight: displayLargeWeight,
      color: color,
      letterSpacing: letterSpacing ?? 0.0,
    );
  }

  /// Generate Display Medium text style
  static TextStyle displayMedium(
    BuildContext context, {
    Color? color,
    double? letterSpacing,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final textScaleFactor = mediaQuery.textScaleFactor;

    final fontSize = getDynamicFontSize(
      displayMediumSize,
      screenWidth,
      textScaleFactor,
    );

    return GoogleFonts.inter(
      fontSize: fontSize,
      height: getDynamicLineHeight(fontSize) / fontSize,
      fontWeight: displayMediumWeight,
      color: color,
      letterSpacing: letterSpacing ?? 0.0,
    );
  }

  /// Generate Display Small text style
  static TextStyle displaySmall(
    BuildContext context, {
    Color? color,
    double? letterSpacing,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final textScaleFactor = mediaQuery.textScaleFactor;

    final fontSize = getDynamicFontSize(
      displaySmallSize,
      screenWidth,
      textScaleFactor,
    );

    return GoogleFonts.inter(
      fontSize: fontSize,
      height: getDynamicLineHeight(fontSize) / fontSize,
      fontWeight: displaySmallWeight,
      color: color,
      letterSpacing: letterSpacing ?? 0.0,
    );
  }

  /// Generate Headline Large text style
  static TextStyle headlineLarge(
    BuildContext context, {
    Color? color,
    double? letterSpacing,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final textScaleFactor = mediaQuery.textScaleFactor;

    final fontSize = getDynamicFontSize(
      headlineLargeSize,
      screenWidth,
      textScaleFactor,
    );

    return GoogleFonts.inter(
      fontSize: fontSize,
      height: getDynamicLineHeight(fontSize) / fontSize,
      fontWeight: headlineLargeWeight,
      color: color,
      letterSpacing: letterSpacing ?? 0.0,
    );
  }

  /// Generate Headline Medium text style
  static TextStyle headlineMedium(
    BuildContext context, {
    Color? color,
    double? letterSpacing,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final textScaleFactor = mediaQuery.textScaleFactor;

    final fontSize = getDynamicFontSize(
      headlineMediumSize,
      screenWidth,
      textScaleFactor,
    );

    return GoogleFonts.inter(
      fontSize: fontSize,
      height: getDynamicLineHeight(fontSize) / fontSize,
      fontWeight: headlineMediumWeight,
      color: color,
      letterSpacing: letterSpacing ?? 0.0,
    );
  }

  /// Generate Headline Small text style
  static TextStyle headlineSmall(
    BuildContext context, {
    Color? color,
    double? letterSpacing,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final textScaleFactor = mediaQuery.textScaleFactor;

    final fontSize = getDynamicFontSize(
      headlineSmallSize,
      screenWidth,
      textScaleFactor,
    );

    return GoogleFonts.inter(
      fontSize: fontSize,
      height: getDynamicLineHeight(fontSize) / fontSize,
      fontWeight: headlineSmallWeight,
      color: color,
      letterSpacing: letterSpacing ?? 0.0,
    );
  }

  /// Generate Title Large text style
  static TextStyle titleLarge(
    BuildContext context, {
    Color? color,
    double? letterSpacing,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final textScaleFactor = mediaQuery.textScaleFactor;

    final fontSize = getDynamicFontSize(
      titleLargeSize,
      screenWidth,
      textScaleFactor,
    );

    return GoogleFonts.inter(
      fontSize: fontSize,
      height: getDynamicLineHeight(fontSize) / fontSize,
      fontWeight: titleLargeWeight,
      color: color,
      letterSpacing: letterSpacing ?? 0.0,
    );
  }

  /// Generate Title Medium text style
  static TextStyle titleMedium(
    BuildContext context, {
    Color? color,
    double? letterSpacing,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final textScaleFactor = mediaQuery.textScaleFactor;

    final fontSize = getDynamicFontSize(
      titleMediumSize,
      screenWidth,
      textScaleFactor,
    );

    return GoogleFonts.inter(
      fontSize: fontSize,
      height: getDynamicLineHeight(fontSize) / fontSize,
      fontWeight: titleMediumWeight,
      color: color,
      letterSpacing: letterSpacing ?? 0.1,
    );
  }

  /// Generate Title Small text style
  static TextStyle titleSmall(
    BuildContext context, {
    Color? color,
    double? letterSpacing,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final textScaleFactor = mediaQuery.textScaleFactor;

    final fontSize = getDynamicFontSize(
      titleSmallSize,
      screenWidth,
      textScaleFactor,
    );

    return GoogleFonts.inter(
      fontSize: fontSize,
      height: getDynamicLineHeight(fontSize) / fontSize,
      fontWeight: titleSmallWeight,
      color: color,
      letterSpacing: letterSpacing ?? 0.1,
    );
  }

  /// Generate Body Large text style
  static TextStyle bodyLarge(
    BuildContext context, {
    Color? color,
    double? letterSpacing,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final textScaleFactor = mediaQuery.textScaleFactor;

    final fontSize = getDynamicFontSize(
      bodyLargeSize,
      screenWidth,
      textScaleFactor,
    );

    return GoogleFonts.inter(
      fontSize: fontSize,
      height: getDynamicLineHeight(fontSize) / fontSize,
      fontWeight: bodyLargeWeight,
      color: color,
      letterSpacing: letterSpacing ?? 0.2,
    );
  }

  /// Generate Body Medium text style
  static TextStyle bodyMedium(
    BuildContext context, {
    Color? color,
    double? letterSpacing,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final textScaleFactor = mediaQuery.textScaleFactor;

    final fontSize = getDynamicFontSize(
      bodyMediumSize,
      screenWidth,
      textScaleFactor,
    );

    return GoogleFonts.inter(
      fontSize: fontSize,
      height: getDynamicLineHeight(fontSize) / fontSize,
      fontWeight: bodyMediumWeight,
      color: color,
      letterSpacing: letterSpacing ?? 0.1,
    );
  }

  /// Generate Body Small text style
  static TextStyle bodySmall(
    BuildContext context, {
    Color? color,
    double? letterSpacing,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final textScaleFactor = mediaQuery.textScaleFactor;

    final fontSize = getDynamicFontSize(
      bodySmallSize,
      screenWidth,
      textScaleFactor,
    );

    return GoogleFonts.inter(
      fontSize: fontSize,
      height: getDynamicLineHeight(fontSize) / fontSize,
      fontWeight: bodySmallWeight,
      color: color,
      letterSpacing: letterSpacing ?? 0.1,
    );
  }

  /// Generate Label Large text style
  static TextStyle labelLarge(
    BuildContext context, {
    Color? color,
    double? letterSpacing,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final textScaleFactor = mediaQuery.textScaleFactor;

    final fontSize = getDynamicFontSize(
      labelLargeSize,
      screenWidth,
      textScaleFactor,
    );

    return GoogleFonts.inter(
      fontSize: fontSize,
      height: getDynamicLineHeight(fontSize) / fontSize,
      fontWeight: labelLargeWeight,
      color: color,
      letterSpacing: letterSpacing ?? 0.1,
    );
  }

  /// Generate Label Medium text style
  static TextStyle labelMedium(
    BuildContext context, {
    Color? color,
    double? letterSpacing,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final textScaleFactor = mediaQuery.textScaleFactor;

    final fontSize = getDynamicFontSize(
      labelMediumSize,
      screenWidth,
      textScaleFactor,
    );

    return GoogleFonts.inter(
      fontSize: fontSize,
      height: getDynamicLineHeight(fontSize) / fontSize,
      fontWeight: labelMediumWeight,
      color: color,
      letterSpacing: letterSpacing ?? 0.1,
    );
  }

  /// Generate Label Small text style
  static TextStyle labelSmall(
    BuildContext context, {
    Color? color,
    double? letterSpacing,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final textScaleFactor = mediaQuery.textScaleFactor;

    final fontSize = getDynamicFontSize(
      labelSmallSize,
      screenWidth,
      textScaleFactor,
    );

    return GoogleFonts.inter(
      fontSize: fontSize,
      height: getDynamicLineHeight(fontSize) / fontSize,
      fontWeight: labelSmallWeight,
      color: color,
      letterSpacing: letterSpacing ?? 0.1,
    );
  }

  // ============================================================================
  // MATERIAL 3 TEXT THEME GENERATORS
  // ============================================================================

  /// Generate complete TextTheme for Material 3 with responsive sizing
  static TextTheme getTextTheme(BuildContext context, {Color? color}) {
    return TextTheme(
      displayLarge: displayLarge(context, color: color),
      displayMedium: displayMedium(context, color: color),
      displaySmall: displaySmall(context, color: color),
      headlineLarge: headlineLarge(context, color: color),
      headlineMedium: headlineMedium(context, color: color),
      headlineSmall: headlineSmall(context, color: color),
      titleLarge: titleLarge(context, color: color),
      titleMedium: titleMedium(context, color: color),
      titleSmall: titleSmall(context, color: color),
      bodyLarge: bodyLarge(context, color: color),
      bodyMedium: bodyMedium(context, color: color),
      bodySmall: bodySmall(context, color: color),
      labelLarge: labelLarge(context, color: color),
      labelMedium: labelMedium(context, color: color),
      labelSmall: labelSmall(context, color: color),
    );
  }

  /// Generate responsive text theme for light mode
  static TextTheme getLightTextTheme(BuildContext context) {
    return getTextTheme(context); // Will use theme colors automatically
  }

  /// Generate responsive text theme for dark mode
  static TextTheme getDarkTextTheme(BuildContext context) {
    return getTextTheme(context); // Will use theme colors automatically
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Get font size by name (useful for configuration-driven UI)
  static double getFontSizeByName(String name, BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final textScaleFactor = mediaQuery.textScaleFactor;

    double baseSize;
    switch (name.toLowerCase()) {
      case 'display-large':
        baseSize = displayLargeSize;
        break;
      case 'display-medium':
        baseSize = displayMediumSize;
        break;
      case 'display-small':
        baseSize = displaySmallSize;
        break;
      case 'headline-large':
        baseSize = headlineLargeSize;
        break;
      case 'headline-medium':
        baseSize = headlineMediumSize;
        break;
      case 'headline-small':
        baseSize = headlineSmallSize;
        break;
      case 'title-large':
        baseSize = titleLargeSize;
        break;
      case 'title-medium':
        baseSize = titleMediumSize;
        break;
      case 'title-small':
        baseSize = titleSmallSize;
        break;
      case 'body-large':
        baseSize = bodyLargeSize;
        break;
      case 'body-medium':
        baseSize = bodyMediumSize;
        break;
      case 'body-small':
        baseSize = bodySmallSize;
        break;
      case 'label-large':
        baseSize = labelLargeSize;
        break;
      case 'label-medium':
        baseSize = labelMediumSize;
        break;
      case 'label-small':
        baseSize = labelSmallSize;
        break;
      default:
        baseSize = bodyMediumSize; // Default fallback
    }

    return getDynamicFontSize(baseSize, screenWidth, textScaleFactor);
  }
}
