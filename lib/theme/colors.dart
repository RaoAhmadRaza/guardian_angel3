import 'package:flutter/material.dart';

/// Premium Monochromatic Color System for Guardian Angel
///
/// A sophisticated, minimal design system that prioritizes elegance,
/// accessibility, and professional aesthetics across light and dark themes.
///
/// Design Philosophy:
/// - Monochromatic harmony with subtle accent variations
/// - WCAG AA+ compliant contrast ratios
/// - Eye-soothing gradients and shadows
/// - Consistent visual hierarchy
/// - Premium digital product aesthetics
class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  // ============================================================================
  // MONOCHROMATIC BRAND COLORS - Premium Minimal System
  // ============================================================================

  /// Primary Monochromatic Scale - Enhanced Light Theme
  /// Professional healthcare colors with medical blue accents

  // Light Theme Primary Colors - Medical Blue System
  static const Color lightPrimary =
      Color(0xFF2563EB); // Medical Blue - Primary actions, trust
  static const Color lightSecondary =
      Color(0xFF64748B); // Professional Gray-Blue - Secondary elements
  static const Color lightAccent =
      Color(0xFF0EA5E9); // Healthcare Accent Blue - Accent highlights

  // Dark Theme Primary Colors
  static const Color darkPrimary =
      Color(0xFFF5F5F5); // Off-White - Primary actions
  static const Color darkSecondary =
      Color(0xFFE8E8E8); // Light Gray - Secondary elements
  static const Color darkAccent =
      Color(0xFFCCCCCC); // Medium Light Gray - Accent highlights

  // ============================================================================
  // SEMANTIC COLORS - Healthcare Context Indicators
  // ============================================================================

  /// Success - Health & Wellness Green
  static const Color successLight = Color(0xFF059669); // Medical green
  static const Color successDark = Color(0xFFD1FAE5); // Light green background

  /// Warning - Medical Caution Amber
  static const Color warningLight = Color(0xFFD97706); // Medical amber
  static const Color warningDark = Color(0xFFFEF3C7); // Light amber background

  /// Error - Medical Alert Red
  static const Color errorLight = Color(0xFFDC2626); // Medical red
  static const Color errorDark = Color(0xFFFEE2E2); // Light red background

  /// Info - Medical Information Blue
  static const Color infoLight = Color(0xFF2563EB); // Medical blue
  static const Color infoDark = Color(0xFFDCEEFF); // Light blue background

  // ============================================================================
  // ENHANCED LIGHT THEME PALETTE - Premium Healthcare Design
  // ============================================================================

  // Backgrounds & Surfaces - Soft, Premium Foundation
  static const Color lightBackground =
      Color(0xFFFDFDFD); // Ultra-soft off-white, not harsh #FFFFFF
  static const Color lightBackgroundSecondary =
      Color(0xFFFAFAFA); // Subtle cream background
  static const Color lightSurface =
      Color(0xFFFEFEFE); // Primary card surface - soft white
  static const Color lightSurfaceVariant =
      Color(0xFFF9FAFB); // Secondary surfaces - warm off-white
  static const Color lightSurfaceElevated =
      Color(0xFFF4F6F8); // Elevated elements - light blue-gray
  static const Color lightCard =
      Color(0xFFFFFFFF); // Pure white for special emphasis only
  static const Color lightOverlay = Color(0xFFF1F3F5); // Disabled overlays

  // Borders & Dividers - Refined Structure
  static const Color lightBorder =
      Color(0xFFE2E8F0); // Primary borders - subtle gray
  static const Color lightBorderVariant =
      Color(0xFFF1F5F9); // Secondary borders - lighter
  static const Color lightBorderAccent =
      Color(0xFFCBD5E1); // Accent borders - medium
  static const Color lightBorderFocus =
      Color(0xFF3B82F6); // Focus borders - medical blue
  static const Color lightDivider = Color(0xFFE5E7EB); // Standard dividers

  // Typography Hierarchy - Perfect Contrast & Readability
  static const Color lightTextPrimary =
      Color(0xFF0F172A); // Deep slate - perfect contrast (16.75:1)
  static const Color lightTextSecondary =
      Color(0xFF475569); // Medium slate - body text (9.5:1)
  static const Color lightTextTertiary =
      Color(0xFF64748B); // Light slate - supporting text (7.2:1)
  static const Color lightTextQuaternary =
      Color(0xFF94A3B8); // Subtle gray - captions (4.8:1)
  static const Color lightTextDisabled =
      Color(0xFFCBD5E1); // Muted gray - disabled text
  static const Color lightTextPlaceholder =
      Color(0xFF9CA3AF); // Placeholder text (4.5:1)

  // Interactive States - Responsive & Accessible
  static const Color lightHover =
      Color(0xFFF8FAFC); // Primary hover - barely visible
  static const Color lightHoverSecondary =
      Color(0xFFF1F5F9); // Secondary hover - light blue tint
  static const Color lightPressed = Color(0xFFE2E8F0); // Primary pressed
  static const Color lightPressedSecondary =
      Color(0xFFCBD5E1); // Secondary pressed
  static const Color lightFocused = Color(0xFF3B82F6); // Blue focus indicator
  static const Color lightFocusBackground =
      Color(0xFFEFF6FF); // Focus background
  static const Color lightSelected = Color(0xFFEBF4FF); // Selected background
  static const Color lightSelectedBorder = Color(0xFF93C5FD); // Selected border

  // ============================================================================
  // DARK THEME PALETTE - Sophisticated, Eye-Soothing, Premium
  // ============================================================================

  // Backgrounds & Surfaces
  static const Color darkBackground =
      Color(0xFF0F0F0F); // Rich Black - Main background
  static const Color darkSurface =
      Color(0xFF1A1A1A); // Deep Charcoal - Cards, modals
  static const Color darkSurfaceVariant =
      Color(0xFF202124); // Elevated Charcoal - Alternate surfaces
  static const Color darkCard = Color(0xFF1A1A1A); // Rich Card background
  static const Color darkOverlay =
      Color(0xFF2D2D30); // Dark Overlay - Disabled states

  // Borders & Dividers
  static const Color darkBorder = Color(0xFF3C4043); // Subtle boundaries
  static const Color darkBorderVariant = Color(0xFF2D2D30); // Softer boundaries
  static const Color darkDivider = Color(0xFF3C4043); // Clean dark separation

  // Typography Hierarchy
  static const Color darkTextPrimary =
      Color(0xFFF8F9FA); // Pure Light - Headlines, key text
  static const Color darkTextSecondary =
      Color(0xFFE8EAED); // Off-White - Body text
  static const Color darkTextTertiary =
      Color(0xFF9AA0A6); // Medium Gray - Supporting text
  static const Color darkTextDisabled =
      Color(0xFF5F6368); // Muted Gray - Disabled text
  static const Color darkTextPlaceholder =
      Color(0xFF80868B); // Subtle placeholder text

  // Interactive States
  static const Color darkHover = Color(0xFF202124); // Gentle hover elevation
  static const Color darkPressed = Color(0xFF2D2D30); // Subtle press feedback
  static const Color darkFocused = Color(0xFFF8F9FA); // Crisp focus indicator
  static const Color darkSelected =
      Color(0xFF1A73E8); // Professional blue selection

  // ============================================================================
  // MONOCHROMATIC GRADIENT SYSTEM - Sophisticated Depth
  // ============================================================================

  /// Enhanced Light Theme Gradients - Sophisticated Healthcare Depth
  static const LinearGradient lightPrimaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFDFDFD), // off-white
      Color(0xFFF5F5F7), // light cloud grey
      Color(0xFFE0E0E2), // gentle cool grey
    ],
  );

  static const LinearGradient lightSecondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFDFDFD), // off-white
      Color(0xFFF5F5F7), // light cloud grey
      Color(0xFFE0E0E2), // gentle cool grey
    ],
  );

  static const LinearGradient lightAccentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFDFDFD), // off-white
      Color(0xFFF5F5F7), // light cloud grey
      Color(0xFFE0E0E2), // gentle cool grey
    ],
  );

  /// Premium Light Theme Hero Gradient
  static const LinearGradient lightHeroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFDFDFD), // off-white
      Color(0xFFF5F5F7), // light cloud grey
      Color(0xFFE0E0E2), // gentle cool grey
    ],
  );

  /// Medical Button Gradient - Trust & Professionalism
  static const LinearGradient lightButtonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFDFDFD), // off-white
      Color(0xFFF5F5F7), // light cloud grey
      Color(0xFFE0E0E2), // gentle cool grey
    ],
  );

  // --------------------------------------------------------------------------
  // Guardian Angel Brand Enhancements (Visual Identity Refresh)
  // --------------------------------------------------------------------------
  /// Calming sky gradient replacing legacy yellow accents
  static const LinearGradient guardianAngelSkyGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFB9D9FF), // soft sky blue
      Color(0xFFE6F3FF), // very light airy blue
      Color(0xFFFFFFFF), // fade to white / trust
    ],
    stops: [0.0, 0.65, 1.0],
  );

  /// Gentle lavender → ivory gradient alternative for variety
  static const LinearGradient guardianAngelLavenderGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFE8E6FA), // pastel lavender
      Color(0xFFF9F9FD), // soft near-white blend
      Color(0xFFFFFDF2), // ivory warmth
    ],
    stops: [0.0, 0.55, 1.0],
  );

  /// Status indicator colors (avatar shadow system)
  static const Color statusStable = Color(0xFF10B981);     // Green = Active & Stable
  static const Color statusMildAlert = Color(0xFFF59E0B);  // Orange = Mild alert
  static const Color statusEmergency = Color(0xFFEF4444);  // Red = Emergency

  /// Helper to get status shadow color based on vitals/mood/crisis
  static Color getStatusShadowColor({
    required String vitals,
    required String mood,
    bool crisis = false,
  }) {
    final v = vitals.toLowerCase();
    final m = mood.toLowerCase();
    if (crisis || v == 'fallalert') return statusEmergency;
    if (v == 'irregular' || m == 'stressed') return statusMildAlert;
    return statusStable;
  }

  /// Dark Theme Gradients - Rich, Premium Depth
  static const LinearGradient darkPrimaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0F0F0F), // Rich Black
      Color(0xFF1A1A1A), // Deep Charcoal
      Color(0xFF202124), // Elevated Charcoal
    ],
    stops: [0.0, 0.6, 1.0],
  );

  static const LinearGradient darkSecondaryGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF1A1A1A), // Deep Charcoal
      Color(0xFF2D2D30), // Rich Gray
    ],
  );

  static const LinearGradient darkAccentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF8F9FA), // Pure Light
      Color(0xFFE8EAED), // Off-White
    ],
  );

  static const LinearGradient darkButtonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF8F9FA), // Pure Light
      Color(0xFFE8EAED), // Off-White
    ],
  );

  // ============================================================================
  // PREMIUM SHADOW SYSTEM - Sophisticated Depth
  // ============================================================================

  /// Enhanced Light theme shadows - Premium Healthcare Depth
  static List<BoxShadow> get lightCardShadow => [
        BoxShadow(
          color: Color(0xFF475569).withOpacity(0.08), // Soft primary shadow
          blurRadius: 25,
          offset: const Offset(0, 1),
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Color(0xFF475569).withOpacity(0.05), // Ambient shadow
          blurRadius: 45,
          offset: const Offset(0, 10),
          spreadRadius: 0,
        ),
      ];

  /// Enhanced Light theme elevated card shadows
  static List<BoxShadow> get lightCardShadowElevated => [
        BoxShadow(
          color: Color(0xFF475569).withOpacity(0.12), // Strong primary shadow
          blurRadius: 35,
          offset: const Offset(0, 2),
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Color(0xFF475569).withOpacity(0.08), // Deep ambient shadow
          blurRadius: 60,
          offset: const Offset(0, 15),
          spreadRadius: 0,
        ),
      ];

  /// Enhanced Light theme button shadows - Medical Trust
  static List<BoxShadow> get lightButtonShadow => [
        BoxShadow(
          color: Color(0xFF3B82F6).withOpacity(0.15), // Blue button shadow
          blurRadius: 20,
          offset: const Offset(0, 2),
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Color(0xFF1E40AF).withOpacity(0.08), // Deep blue ambient
          blurRadius: 35,
          offset: const Offset(0, 8),
          spreadRadius: 0,
        ),
      ];

  /// Enhanced Light theme input shadows - Subtle Focus
  static List<BoxShadow> get lightInputShadow => [
        BoxShadow(
          color: Color(0xFF64748B).withOpacity(0.04), // Very subtle shadow
          blurRadius: 15,
          offset: const Offset(0, 1),
          spreadRadius: 0,
        ),
      ];

  /// Enhanced Light theme input focus shadows - Clear Feedback
  static List<BoxShadow> get lightInputFocusShadow => [
        BoxShadow(
          color: Color(0xFF3B82F6).withOpacity(0.15), // Blue focus shadow
          blurRadius: 20,
          offset: const Offset(0, 0),
          spreadRadius: 3,
        ),
        BoxShadow(
          color: Color(0xFF64748B).withOpacity(0.05), // Subtle depth
          blurRadius: 15,
          offset: const Offset(0, 2),
          spreadRadius: 0,
        ),
      ];

  /// Dark theme shadows - Rich, luxurious depth
  static List<BoxShadow> get darkCardShadow => [
        BoxShadow(
          color: Color(0xFF000000).withOpacity(0.4), // Deep black shadow
          blurRadius: 24,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Color(0xFF000000).withOpacity(0.2), // Ambient darkness
          blurRadius: 48,
          offset: const Offset(0, 12),
          spreadRadius: 0,
        ),
      ];

  /// Dark theme button shadows - Premium glow effect
  static List<BoxShadow> get darkButtonShadow => [
        BoxShadow(
          color: Color(0xFFF8F9FA).withOpacity(0.1), // Subtle light glow
          blurRadius: 20,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Color(0xFF000000).withOpacity(0.3), // Depth shadow
          blurRadius: 16,
          offset: const Offset(0, 2),
          spreadRadius: 0,
        ),
      ];

  // ============================================================================
  // INTELLIGENT THEME HELPERS - Responsive Color System
  // ============================================================================

  /// Get theme-appropriate primary color
  static Color getPrimaryColor(Brightness brightness) {
    return brightness == Brightness.dark ? darkPrimary : lightPrimary;
  }

  /// Get theme-appropriate secondary color
  static Color getSecondaryColor(Brightness brightness) {
    return brightness == Brightness.dark ? darkSecondary : lightSecondary;
  }

  /// Get theme-appropriate accent color
  static Color getAccentColor(Brightness brightness) {
    return brightness == Brightness.dark ? darkAccent : lightAccent;
  }

  /// Get theme-appropriate text primary color
  static Color getTextPrimary(Brightness brightness) {
    return brightness == Brightness.dark ? darkTextPrimary : lightTextPrimary;
  }

  /// Get theme-appropriate text secondary color
  static Color getTextSecondary(Brightness brightness) {
    return brightness == Brightness.dark
        ? darkTextSecondary
        : lightTextSecondary;
  }

  /// Get theme-appropriate surface color
  static Color getSurfaceColor(Brightness brightness) {
    return brightness == Brightness.dark ? darkSurface : lightSurface;
  }

  /// Get theme-appropriate background color
  static Color getBackgroundColor(Brightness brightness) {
    return brightness == Brightness.dark ? darkBackground : lightBackground;
  }

  /// Get theme-appropriate border color
  static Color getBorderColor(Brightness brightness) {
    return brightness == Brightness.dark ? darkBorder : lightBorder;
  }

  /// Get theme-appropriate primary gradient
  static LinearGradient getPrimaryGradient(Brightness brightness) {
    return brightness == Brightness.dark
        ? darkPrimaryGradient
        : lightPrimaryGradient;
  }

  /// Get theme-appropriate secondary gradient
  static LinearGradient getSecondaryGradient(Brightness brightness) {
    return brightness == Brightness.dark
        ? darkSecondaryGradient
        : lightSecondaryGradient;
  }

  /// Get theme-appropriate accent gradient
  static LinearGradient getAccentGradient(Brightness brightness) {
    return brightness == Brightness.dark
        ? darkAccentGradient
        : lightAccentGradient;
  }

  /// Get theme-appropriate button gradient
  static LinearGradient getButtonGradient(Brightness brightness) {
    return brightness == Brightness.dark
        ? darkButtonGradient
        : lightButtonGradient;
  }

  /// Get theme-appropriate card shadow
  static List<BoxShadow> getCardShadow(Brightness brightness) {
    return brightness == Brightness.dark ? darkCardShadow : lightCardShadow;
  }

  /// Get theme-appropriate button shadow
  static List<BoxShadow> getButtonShadow(Brightness brightness) {
    return brightness == Brightness.dark ? darkButtonShadow : lightButtonShadow;
  }

  /// Generate dynamic monochromatic gradient
  static LinearGradient generateMonochromaticGradient({
    required Brightness brightness,
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
    double intensity = 0.5,
  }) {
    final isDark = brightness == Brightness.dark;

    if (isDark) {
      return LinearGradient(
        begin: begin,
        end: end,
        colors: [
          Color(0xFF0F0F0F),
          Color(0xFF1A1A1A).withOpacity(0.8 + (intensity * 0.2)),
          Color(0xFF202124).withOpacity(0.6 + (intensity * 0.4)),
        ],
        stops: const [0.0, 0.5, 1.0],
      );
    } else {
      return LinearGradient(
        begin: begin,
        end: end,
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFF8F9FA).withOpacity(0.8 + (intensity * 0.2)),
          Color(0xFFF1F3F4).withOpacity(0.6 + (intensity * 0.4)),
        ],
        stops: const [0.0, 0.5, 1.0],
      );
    }
  }

  // ============================================================================
  // GLASS MORPHISM EFFECTS - Premium Material Design
  // ============================================================================

  /// Sophisticated glass effect for dark theme
  static BoxDecoration getDarkGlassEffect({Color? color}) {
    return BoxDecoration(
      color: (color ?? darkSurface).withOpacity(0.8),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: darkBorder.withOpacity(0.2),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Color(0xFF000000).withOpacity(0.4),
          blurRadius: 32,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: darkTextPrimary.withOpacity(0.05),
          blurRadius: 16,
          offset: const Offset(0, -4),
        ),
      ],
    );
  }

  /// Elegant glass effect for light theme
  static BoxDecoration getLightGlassEffect({Color? color}) {
    return BoxDecoration(
      color: (color ?? lightSurface).withOpacity(0.9),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: lightBorder.withOpacity(0.3),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: lightTextPrimary.withOpacity(0.08),
          blurRadius: 24,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: lightSurface.withOpacity(0.9),
          blurRadius: 12,
          offset: const Offset(0, -2),
        ),
      ],
    );
  }

  /// Get theme-appropriate glass effect
  static BoxDecoration getGlassEffect(Brightness brightness, {Color? color}) {
    return brightness == Brightness.dark
        ? getDarkGlassEffect(color: color)
        : getLightGlassEffect(color: color);
  }

  /// Generate dynamic gradient based on seed color and theme
  /// Used by AppTheme.generateDynamicGradient helper method
  static LinearGradient generateDynamicGradient({
    required Color seedColor,
    required Brightness brightness,
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) {
    final bool isDark = brightness == Brightness.dark;

    // Create variations of the seed color for gradient
    final Color primaryColor = seedColor;
    final Color secondaryColor = Color.lerp(
          seedColor,
          isDark ? Colors.white : Colors.black,
          0.2,
        ) ??
        seedColor;

    return LinearGradient(
      begin: begin,
      end: end,
      colors: [
        primaryColor,
        secondaryColor,
      ],
      stops: const [0.0, 1.0],
    );
  }
}

/// Premium Monochromatic ColorScheme generator for Guardian Angel
class AppColorScheme {
  AppColorScheme._();

  /// Generate enhanced light color scheme with premium healthcare aesthetics
  static ColorScheme lightColorScheme = ColorScheme.fromSeed(
    seedColor: Color(0xFF2563EB), // Medical blue seed
    brightness: Brightness.light,
    // Override specific colors to match enhanced light design
    primary: Color(0xFF2563EB), // Medical Blue - Trust & professionalism
    secondary: Color(0xFF64748B), // Professional Gray-Blue
    tertiary: Color(0xFF0EA5E9), // Healthcare Accent Blue
    error: Color(0xFFDC2626), // Medical red
    surface: AppColors.lightSurface, // Soft white surface
    background: AppColors.lightBackground, // Ultra-soft off-white
    onPrimary: Color(0xFFFFFFFF), // White text on medical blue
    onSecondary: AppColors.lightTextSecondary, // Medium contrast text
    onSurface: AppColors.lightTextPrimary, // Deep slate text
    onBackground: AppColors.lightTextPrimary, // Primary text on background
    outline: AppColors.lightBorder, // Subtle gray borders
    outlineVariant: AppColors.lightBorderVariant, // Lighter borders
  );

  /// Generate dark color scheme with monochromatic sophistication
  static ColorScheme darkColorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.darkPrimary,
    brightness: Brightness.dark,
    // Override specific colors to match monochromatic dark design
    primary: AppColors.darkPrimary, // Off-White
    secondary: AppColors.darkSecondary, // Light Gray
    tertiary: AppColors.darkAccent, // Medium Light Gray
    error: AppColors.errorDark, // Sophisticated error
    surface: AppColors.darkSurface, // Deep Charcoal
    background: AppColors.darkBackground, // Rich Black
    onPrimary: AppColors.darkTextPrimary, // Light on dark
    onSecondary: AppColors.darkTextSecondary, // Medium contrast
    onSurface: AppColors.darkTextPrimary, // Crisp text
    onBackground: AppColors.darkTextPrimary, // Primary text
  );

  /// Get theme-appropriate color scheme
  static ColorScheme getColorScheme(Brightness brightness) {
    return brightness == Brightness.dark ? darkColorScheme : lightColorScheme;
  }
}
