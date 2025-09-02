import 'package:flutter/material.dart';

/// Centralized spacing system for Guardian Angel application
/// Following a consistent 4px base unit scale for optimal visual rhythm
class AppSpacing {
  AppSpacing._(); // Private constructor to prevent instantiation

  // ============================================================================
  // BASE SPACING CONSTANTS - 4px base unit
  // ============================================================================

  /// Base unit for spacing calculations (4px)
  static const double baseUnit = 4.0;

  /// Extra small spacing - 4px
  static const double xs = baseUnit * 1; // 4px

  /// Small spacing - 8px
  static const double sm = baseUnit * 2; // 8px

  /// Medium spacing - 12px
  static const double md = baseUnit * 3; // 12px

  /// Large spacing - 16px
  static const double lg = baseUnit * 4; // 16px

  /// Extra large spacing - 20px
  static const double xl = baseUnit * 5; // 20px

  /// 2x Extra large spacing - 24px
  static const double xl2 = baseUnit * 6; // 24px

  /// 3x Extra large spacing - 32px
  static const double xl3 = baseUnit * 8; // 32px

  /// 4x Extra large spacing - 40px
  static const double xl4 = baseUnit * 10; // 40px

  /// 5x Extra large spacing - 48px
  static const double xl5 = baseUnit * 12; // 48px

  /// 6x Extra large spacing - 56px
  static const double xl6 = baseUnit * 14; // 56px

  /// 7x Extra large spacing - 64px
  static const double xl7 = baseUnit * 16; // 64px

  /// 8x Extra large spacing - 80px
  static const double xl8 = baseUnit * 20; // 80px

  // ============================================================================
  // SEMANTIC SPACING - Contextual spacing with clear purpose
  // ============================================================================

  /// Minimum touch target size (44px) for accessibility
  static const double minTouchTarget = 44.0;

  /// Standard button height
  static const double buttonHeight = 56.0;

  /// Standard input field height
  static const double inputHeight = 56.0;

  /// App bar height
  static const double appBarHeight = 56.0;

  /// Bottom navigation bar height
  static const double bottomNavHeight = 60.0;

  /// Standard card padding
  static const double cardPadding = lg; // 16px

  /// Screen horizontal padding
  static const double screenPadding = xl2; // 24px

  /// Section spacing between major content blocks
  static const double sectionSpacing = xl4; // 40px

  /// Page margin for content
  static const double pageMargin = xl2; // 24px

  // ============================================================================
  // BORDER RADIUS SCALE
  // ============================================================================

  /// No radius
  static const double radiusNone = 0.0;

  /// Small radius - 4px
  static const double radiusXs = xs; // 4px

  /// Small radius - 8px
  static const double radiusSm = sm; // 8px

  /// Medium radius - 12px
  static const double radiusMd = md; // 12px

  /// Large radius - 16px
  static const double radiusLg = lg; // 16px

  /// Extra large radius - 20px
  static const double radiusXl = xl; // 20px

  /// 2x Extra large radius - 24px
  static const double radiusXl2 = xl2; // 24px

  /// 3x Extra large radius - 32px
  static const double radiusXl3 = xl3; // 32px

  /// Pill radius for fully rounded elements
  static const double radiusPill = 999.0;

  /// Circular radius for perfect circles
  static const double radiusCircular = 999.0;

  // ============================================================================
  // EDGE INSETS HELPERS - Pre-defined EdgeInsets for common use cases
  // ============================================================================

  /// All sides extra small - 4px
  static const EdgeInsets allXs = EdgeInsets.all(xs);

  /// All sides small - 8px
  static const EdgeInsets allSm = EdgeInsets.all(sm);

  /// All sides medium - 12px
  static const EdgeInsets allMd = EdgeInsets.all(md);

  /// All sides large - 16px
  static const EdgeInsets allLg = EdgeInsets.all(lg);

  /// All sides extra large - 20px
  static const EdgeInsets allXl = EdgeInsets.all(xl);

  /// All sides 2x extra large - 24px
  static const EdgeInsets allXl2 = EdgeInsets.all(xl2);

  /// Horizontal small - 8px left/right
  static const EdgeInsets horizontalSm = EdgeInsets.symmetric(horizontal: sm);

  /// Horizontal medium - 12px left/right
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);

  /// Horizontal large - 16px left/right
  static const EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);

  /// Horizontal extra large - 20px left/right
  static const EdgeInsets horizontalXl = EdgeInsets.symmetric(horizontal: xl);

  /// Horizontal 2x extra large - 24px left/right
  static const EdgeInsets horizontalXl2 = EdgeInsets.symmetric(horizontal: xl2);

  /// Vertical small - 8px top/bottom
  static const EdgeInsets verticalSm = EdgeInsets.symmetric(vertical: sm);

  /// Vertical medium - 12px top/bottom
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);

  /// Vertical large - 16px top/bottom
  static const EdgeInsets verticalLg = EdgeInsets.symmetric(vertical: lg);

  /// Vertical extra large - 20px top/bottom
  static const EdgeInsets verticalXl = EdgeInsets.symmetric(vertical: xl);

  /// Vertical 2x extra large - 24px top/bottom
  static const EdgeInsets verticalXl2 = EdgeInsets.symmetric(vertical: xl2);

  /// Standard page padding - 24px horizontal, 16px vertical
  static const EdgeInsets pagePadding = EdgeInsets.symmetric(
    horizontal: xl2,
    vertical: lg,
  );

  /// Card content padding - 16px all sides
  static const EdgeInsets cardPaddingInsets = EdgeInsets.all(cardPadding);

  /// Button padding - 24px horizontal, 16px vertical
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: xl2,
    vertical: lg,
  );

  /// Input field padding - 20px horizontal, 18px vertical
  static const EdgeInsets inputPadding = EdgeInsets.symmetric(
    horizontal: xl,
    vertical: 18.0,
  );

  // ============================================================================
  // RESPONSIVE SPACING METHODS
  // ============================================================================

  /// Get responsive spacing based on screen width
  /// Scales spacing up for larger screens
  static double getResponsiveSpacing(double baseSpacing, double screenWidth) {
    // Breakpoints for different screen sizes
    if (screenWidth >= 1200) {
      // Desktop/Large tablet
      return baseSpacing * 1.5;
    } else if (screenWidth >= 768) {
      // Tablet
      return baseSpacing * 1.25;
    } else if (screenWidth >= 600) {
      // Small tablet/Large phone
      return baseSpacing * 1.1;
    } else {
      // Phone
      return baseSpacing;
    }
  }

  /// Get responsive horizontal padding based on screen width
  static double getResponsiveHorizontalPadding(double screenWidth) {
    return getResponsiveSpacing(screenPadding, screenWidth);
  }

  /// Get responsive section spacing based on screen width
  static double getResponsiveSectionSpacing(double screenWidth) {
    return getResponsiveSpacing(sectionSpacing, screenWidth);
  }

  /// Get responsive edge insets for page content
  static EdgeInsets getResponsivePagePadding(double screenWidth) {
    final horizontalPadding = getResponsiveHorizontalPadding(screenWidth);
    return EdgeInsets.symmetric(
      horizontal: horizontalPadding,
      vertical: lg,
    );
  }

  /// Get responsive edge insets for cards
  static EdgeInsets getResponsiveCardPadding(double screenWidth) {
    final basePadding = getResponsiveSpacing(cardPadding, screenWidth);
    return EdgeInsets.all(basePadding);
  }

  // ============================================================================
  // BORDER RADIUS HELPERS
  // ============================================================================

  /// Get border radius for small components
  static BorderRadius get smallRadius => BorderRadius.circular(radiusSm);

  /// Get border radius for medium components
  static BorderRadius get mediumRadius => BorderRadius.circular(radiusMd);

  /// Get border radius for large components
  static BorderRadius get largeRadius => BorderRadius.circular(radiusLg);

  /// Get border radius for extra large components
  static BorderRadius get extraLargeRadius => BorderRadius.circular(radiusXl);

  /// Get pill border radius for fully rounded components
  static BorderRadius get pillRadius => BorderRadius.circular(radiusPill);

  /// Get circular border radius
  static BorderRadius get circularRadius =>
      BorderRadius.circular(radiusCircular);

  /// Get responsive border radius based on screen size
  static BorderRadius getResponsiveBorderRadius(
    double screenWidth, {
    double baseRadius = radiusMd,
  }) {
    final responsiveRadius = getResponsiveSpacing(baseRadius, screenWidth);
    return BorderRadius.circular(responsiveRadius);
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Create symmetric EdgeInsets with custom horizontal and vertical values
  static EdgeInsets symmetric({
    double horizontal = 0.0,
    double vertical = 0.0,
  }) {
    return EdgeInsets.symmetric(
      horizontal: horizontal,
      vertical: vertical,
    );
  }

  /// Create EdgeInsets with individual values for each side
  static EdgeInsets only({
    double left = 0.0,
    double top = 0.0,
    double right = 0.0,
    double bottom = 0.0,
  }) {
    return EdgeInsets.only(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
    );
  }

  /// Create uniform EdgeInsets with same value for all sides
  static EdgeInsets all(double value) {
    return EdgeInsets.all(value);
  }

  /// Get spacing value by name (useful for configuration-driven UI)
  static double getSpacingByName(String name) {
    switch (name.toLowerCase()) {
      case 'xs':
        return xs;
      case 'sm':
        return sm;
      case 'md':
        return md;
      case 'lg':
        return lg;
      case 'xl':
        return xl;
      case 'xl2':
        return xl2;
      case 'xl3':
        return xl3;
      case 'xl4':
        return xl4;
      case 'xl5':
        return xl5;
      case 'xl6':
        return xl6;
      case 'xl7':
        return xl7;
      case 'xl8':
        return xl8;
      default:
        return md; // Default fallback
    }
  }

  /// Get border radius value by name
  static double getBorderRadiusByName(String name) {
    switch (name.toLowerCase()) {
      case 'none':
        return radiusNone;
      case 'xs':
        return radiusXs;
      case 'sm':
        return radiusSm;
      case 'md':
        return radiusMd;
      case 'lg':
        return radiusLg;
      case 'xl':
        return radiusXl;
      case 'xl2':
        return radiusXl2;
      case 'xl3':
        return radiusXl3;
      case 'pill':
        return radiusPill;
      case 'circular':
        return radiusCircular;
      default:
        return radiusMd; // Default fallback
    }
  }
}

/// Screen size breakpoints for responsive design
class AppBreakpoints {
  AppBreakpoints._();

  /// Mobile breakpoint (up to 480px)
  static const double mobile = 480.0;

  /// Tablet breakpoint (481px to 768px)
  static const double tablet = 768.0;

  /// Desktop breakpoint (769px to 1024px)
  static const double desktop = 1024.0;

  /// Large desktop breakpoint (1025px and above)
  static const double largeDesktop = 1200.0;

  /// Check if screen width is mobile size
  static bool isMobile(double width) => width <= mobile;

  /// Check if screen width is tablet size
  static bool isTablet(double width) => width > mobile && width <= tablet;

  /// Check if screen width is desktop size
  static bool isDesktop(double width) => width > tablet && width <= desktop;

  /// Check if screen width is large desktop size
  static bool isLargeDesktop(double width) => width > desktop;

  /// Get current device type based on screen width
  static DeviceType getDeviceType(double width) {
    if (isMobile(width)) return DeviceType.mobile;
    if (isTablet(width)) return DeviceType.tablet;
    if (isDesktop(width)) return DeviceType.desktop;
    return DeviceType.largeDesktop;
  }
}

/// Device type enumeration for responsive design
enum DeviceType {
  mobile,
  tablet,
  desktop,
  largeDesktop,
}
