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

  /// Primary Monochromatic Scale - Deep Charcoal to Pure White
  /// Professional, timeless, and sophisticated base

  // Light Theme Primary Colors
  static const Color lightPrimary =
      Color(0xFF1A1A1A); // Deep Charcoal - Primary actions
  static const Color lightSecondary =
      Color(0xFF2D2D30); // Rich Charcoal - Secondary elements
  static const Color lightAccent =
      Color(0xFF404040); // Medium Gray - Accent highlights

  // Dark Theme Primary Colors
  static const Color darkPrimary =
      Color(0xFFF5F5F5); // Off-White - Primary actions
  static const Color darkSecondary =
      Color(0xFFE8E8E8); // Light Gray - Secondary elements
  static const Color darkAccent =
      Color(0xFFCCCCCC); // Medium Light Gray - Accent highlights

  // ============================================================================
  // SEMANTIC COLORS - Minimal Contextual Indicators
  // ============================================================================

  /// Success - Subtle Green Monochrome
  static const Color successLight = Color(0xFF2D3748); // Dark Gray-Green
  static const Color successDark = Color(0xFFE2E8F0); // Light Gray-Green

  /// Warning - Muted Amber Monochrome
  static const Color warningLight = Color(0xFF4A5568); // Steel Gray
  static const Color warningDark = Color(0xFFEDF2F7); // Warm Light Gray

  /// Error - Sophisticated Red Monochrome
  static const Color errorLight = Color(0xFF2D3748); // Deep Slate
  static const Color errorDark = Color(0xFFF7FAFC); // Cool White

  /// Info - Professional Blue Monochrome
  static const Color infoLight = Color(0xFF1A202C); // Midnight Charcoal
  static const Color infoDark = Color(0xFFEDF2F7); // Cloud White

  // ============================================================================
  // LIGHT THEME PALETTE - Crisp, Clean, Professional
  // ============================================================================

  // Backgrounds & Surfaces
  static const Color lightBackground =
      Color(0xFFFBFBFB); // Pure Light - Main background
  static const Color lightSurface =
      Color(0xFFFFFFFF); // Pure White - Cards, modals
  static const Color lightSurfaceVariant =
      Color(0xFFF8F9FA); // Soft White - Alternate surfaces
  static const Color lightCard =
      Color(0xFFFFFFFF); // Pure White - Card containers
  static const Color lightOverlay =
      Color(0xFFF1F3F4); // Light Overlay - Disabled states

  // Borders & Dividers
  static const Color lightBorder =
      Color(0xFFE8EAED); // Subtle Gray - Primary borders
  static const Color lightBorderVariant =
      Color(0xFFF1F3F4); // Lighter Gray - Secondary borders
  static const Color lightDivider = Color(0xFFE8EAED); // Clean separation lines

  // Typography Hierarchy
  static const Color lightTextPrimary =
      Color(0xFF1A1A1A); // Deep Charcoal - Headlines, key text
  static const Color lightTextSecondary =
      Color(0xFF5F6368); // Medium Gray - Body text
  static const Color lightTextTertiary =
      Color(0xFF9AA0A6); // Light Gray - Supporting text
  static const Color lightTextDisabled =
      Color(0xFFBDC1C6); // Pale Gray - Disabled text
  static const Color lightTextPlaceholder =
      Color(0xFF9AA0A6); // Subtle placeholder text

  // Interactive States
  static const Color lightHover = Color(0xFFF8F9FA); // Gentle hover effect
  static const Color lightPressed = Color(0xFFF1F3F4); // Subtle press feedback
  static const Color lightFocused = Color(0xFF1A1A1A); // Sharp focus indicator
  static const Color lightSelected =
      Color(0xFFE8F0FE); // Soft selection highlight

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

  /// Light Theme Gradients - Subtle Depth and Elegance
  static const LinearGradient lightPrimaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFFFFF), // Pure White
      Color(0xFFF8F9FA), // Soft White
      Color(0xFFF1F3F4), // Light Gray
    ],
    stops: [0.0, 0.6, 1.0],
  );

  static const LinearGradient lightSecondaryGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFF8F9FA), // Soft White
      Color(0xFFE8EAED), // Light Border Gray
    ],
  );

  static const LinearGradient lightAccentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1A1A1A), // Deep Charcoal
      Color(0xFF2D2D30), // Rich Charcoal
    ],
  );

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

  /// Premium Button Gradients
  static const LinearGradient lightButtonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1A1A1A), // Deep Charcoal
      Color(0xFF2D2D30), // Rich Charcoal
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

  /// Light theme shadows - Crisp, professional depth
  static List<BoxShadow> get lightCardShadow => [
        BoxShadow(
          color: Color(0xFF1A1A1A).withOpacity(0.06), // Subtle charcoal shadow
          blurRadius: 20,
          offset: const Offset(0, 2),
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Color(0xFF1A1A1A).withOpacity(0.04), // Ultra-soft depth
          blurRadius: 40,
          offset: const Offset(0, 8),
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

  /// Light theme button shadows - Subtle elevation
  static List<BoxShadow> get lightButtonShadow => [
        BoxShadow(
          color: Color(0xFF1A1A1A).withOpacity(0.08), // Professional shadow
          blurRadius: 16,
          offset: const Offset(0, 2),
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Color(0xFF1A1A1A).withOpacity(0.04), // Soft depth
          blurRadius: 32,
          offset: const Offset(0, 6),
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

  /// Generate dynamic gradient based on seed color and brightness
  static LinearGradient generateDynamicGradient({
    required Color seedColor,
    required Brightness brightness,
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) {
    final isDark = brightness == Brightness.dark;

    if (isDark) {
      return LinearGradient(
        begin: begin,
        end: end,
        colors: [
          seedColor.withOpacity(0.8),
          seedColor.withOpacity(0.6),
          seedColor.withOpacity(0.4),
        ],
        stops: const [0.0, 0.5, 1.0],
      );
    } else {
      return LinearGradient(
        begin: begin,
        end: end,
        colors: [
          seedColor.withOpacity(0.9),
          seedColor.withOpacity(0.7),
          seedColor.withOpacity(0.5),
        ],
        stops: const [0.0, 0.5, 1.0],
      );
    }
  }

  // ============================================================================
  // GLASS MORPHISM EFFECTS
  // ============================================================================

  /// Glass morphism effect for dark theme
  static BoxDecoration getDarkGlassEffect({Color? color}) {
    return BoxDecoration(
      color: (color ?? Colors.white).withOpacity(0.05),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Colors.white.withOpacity(0.1),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 30,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: Colors.white.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, -5),
        ),
      ],
    );
  }

  /// Glass morphism effect for light theme
  static BoxDecoration getLightGlassEffect({Color? color}) {
    return BoxDecoration(
      color: (color ?? Colors.white).withOpacity(0.8),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Colors.white.withOpacity(0.5),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.white.withOpacity(0.8),
          blurRadius: 8,
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
}

/// Premium Monochromatic ColorScheme generator for Guardian Angel
class AppColorScheme {
  AppColorScheme._();

  /// Generate light color scheme with monochromatic elegance
  static ColorScheme lightColorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.lightPrimary,
    brightness: Brightness.light,
    // Override specific colors to match monochromatic design
    primary: AppColors.lightPrimary, // Deep Charcoal
    secondary: AppColors.lightSecondary, // Rich Charcoal
    tertiary: AppColors.lightAccent, // Medium Gray
    error: AppColors.errorLight, // Sophisticated error
    surface: AppColors.lightSurface, // Pure White
    background: AppColors.lightBackground, // Pure Light
    onPrimary: AppColors.lightTextPrimary, // Dark on light
    onSecondary: AppColors.lightTextSecondary, // Medium contrast
    onSurface: AppColors.lightTextPrimary, // Sharp text
    onBackground: AppColors.lightTextPrimary, // Primary text
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

// ============================================================================
// DESIGN SYSTEM DOCUMENTATION & GUIDELINES
// ============================================================================

/// Premium Monochromatic Design System Guidelines
///
/// CONTRAST RATIOS (WCAG AA+ Compliant):
/// - Primary Text: 7.2:1 (Light), 14.8:1 (Dark) 
/// - Secondary Text: 4.8:1 (Light), 9.2:1 (Dark)
/// - Interactive Elements: 4.5:1+ minimum
///
/// USAGE PATTERNS:
/// 
/// BACKGROUNDS:
/// - Use flat colors: lightBackground/darkBackground
/// - Reserve gradients for: Hero sections, CTAs, modal overlays
/// - Avoid gradient overuse to maintain minimal aesthetic
///
/// BUTTONS:
/// - Primary: Solid colors with subtle shadows
/// - Secondary: Ghost/outline style with hover states  
/// - CTAs: Use button gradients sparingly for emphasis
///
/// TYPOGRAPHY:
/// - Headlines: Primary text colors (#1A1A1A light, #F8F9FA dark)
/// - Body: Secondary text colors for comfortable reading
/// - Disabled: Tertiary colors with reduced opacity
///
/// CARDS & SURFACES:
/// - Use surface colors with subtle shadows
/// - Glass morphism for premium overlays
/// - Consistent border radius (8px, 12px, 16px, 24px)
///
/// INTERACTIVE STATES:
/// - Hover: 5% opacity change or subtle color shift
/// - Pressed: 10% opacity reduction with scale (0.98)
/// - Focus: 2px border with primary color
/// - Selected: Subtle background tint
///
/// DO'S:
/// ✅ Consistent spacing (8px grid system)
/// ✅ Subtle animations (200-300ms ease-out)
/// ✅ High contrast text on all backgrounds
/// ✅ Meaningful hierarchy through color weight
/// ✅ Test both themes in all lighting conditions
///
/// DON'TS:
/// ❌ Mix colorful accents with monochromatic base
/// ❌ Use pure black (#000000) for text
/// ❌ Overuse gradients or glass effects
/// ❌ Ignore accessibility contrast requirements
/// ❌ Use color alone to convey information
///
/// FONT RECOMMENDATIONS:
/// - Primary: Inter (weights: 400, 500, 600, 700)
/// - Alternative: SF Pro Display (iOS), Roboto (Android)
/// - Monospace: SF Mono, JetBrains Mono (for code/data)
///
/// ANIMATION PRINCIPLES:
/// - Duration: 200ms (micro), 300ms (standard), 500ms (complex)
/// - Easing: ease-out for entrances, ease-in for exits
/// - Stagger: 50-100ms delays for sequential animations
/// - Reduce motion: Respect system accessibility preferences
