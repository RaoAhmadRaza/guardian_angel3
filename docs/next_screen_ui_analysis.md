# next_screen.dart — UI Analysis

## Overview

`NextScreen` is the main multi-tab dashboard for the Guardian Angel app. It presents a patient-centric Home feed with heart health summaries, safety status, medication reminders, and a comprehensive Home Automation dashboard. Navigation between Home, Chat, Automation, and Settings is handled via an Animated Notch Bottom Bar. The screen is fully theme-aware and adapts visual styles for both light and dark modes.

---

## UI Components Breakdown

- Scaffold
  - backgroundColor: light `#FDFDFD`, dark `#1A1A1A`
  - body: Container with themed gradient (`theme.AppTheme`)
    - PageView (non-scrollable)

Component specifics:

- Bottom bar background (light): `#FDFDFD`
- Bottom bar notch (light): `#475569`
- Bottom bar inactive icon: `#475569` @ 0.6 opacity
- Bottom bar active icon: `#0F172A`
- Medication/automation icon containers often use accent color @ 0.1–0.15 opacity

---

## Color Scheme (Dark Theme)

Core surfaces and text:

- App background: `#1A1A1A`
- Main container background: `#1C1C1E`
- Card/background surfaces: `#2C2C2E`
- Subtle border/outline: `#3C3C3E`
- Primary text: `#FFFFFF`
- Secondary text: `#FFFFFF` @ 0.7 (labels), 0.5 (tertiary)
- Inactive gray (labels/icons): iOS system gray `#8E8E93`
- Shadows: `Colors.black` @ 0.2–0.4 depending on depth

Component specifics:

- Gradient: `theme.AppTheme.getPrimaryGradient(context)`
- Bottom bar background (dark): `#2C2C2E`
- Bottom bar notch (dark): `#3C3C3E`
- Bottom bar label color (dark): `#8E8E93`
- Bottom bar inactive icon: `#8E8E93`
- Bottom bar active icon: `#FFFFFF`
- Toggle active: `#3B82F6`

Glassmorphism:

- Frost layers often use `Colors.white` @ 0.05–0.1 atop dark cards.

---

## Typography

- Fonts: default Material typography with explicit `TextStyle` overrides.
- Weight usage: 400 (regular), 500 (medium), 600 (semibold), 700 (bold).
- Common sizes:

  - Page/section titles: 24–32 (e.g., "Heart Health" 32, Automation title 24)
  - Card headings: 14–18
  - Primary values: 16–20
  - Captions: 11–14

- Examples:

```dart
TextStyle(fontSize: 32, fontWeight: FontWeight.w700); // Heart Health title
TextStyle(fontSize: 24, fontWeight: FontWeight.w700); // Section titles
TextStyle(fontSize: 14, fontWeight: FontWeight.w600); // Card titles
TextStyle(fontSize: 16, fontWeight: FontWeight.w700); // Emphasized values
TextStyle(fontSize: 11, fontWeight: FontWeight.w400); // Sub-captions
```

- Kerning/line height: Many labels use tight letter-spacing (-0.4 to -0.1) and height 1.1–1.2 to achieve the iOS look.

---

## Icons & Imagery

- Cupertino icons:

  - Navigation: house / house_fill, chat_bubble / chat_bubble_fill, lightbulb / lightbulb_fill, gear / gear_solid
  - Health: heart, heart_fill, waveform
  - Automation/UX: bell, thermometer, lightbulb, bolt, shield, person_fill, phone_fill, wind, scissors, bed_double

- Material icons:

  - UI controls: light_mode/dark_mode, info_outline, help_outline, logout, person, chevron_right, arrow_back_ios_new, security, thermostat, tv, notifications_outlined, dark_mode_outlined, refresh, bug_report, check_circle_outline

- Images/assets:

  - `images/heart.png`
  - `images/male.jpg`, `images/female.jpg`
  - `images/newspaper.png`
  - Fallbacks provided where appropriate (e.g., `CupertinoIcons.person_fill`)

---

## State Management / Dynamic UI Behavior

- Theme detection: `final isDarkMode = Theme.of(context).brightness == Brightness.dark;`
- Bottom bar controller: `NotchBottomBarController` with lifecycle fixes
  - Recreated on brightness change to avoid disposed animation callbacks
  - `_controller.jumpTo(index)` called immediately on tap for instant notch movement
  - `PageView.animateToPage` keeps content transition in sync with indicator
- Page coordination: `PageView` (NeverScrollableScrollPhysics); taps control navigation.
- Health data: `Timer.periodic` updates `_heartRate`, `_heartPressureSystolic`, `_heartPressureDiastolic` for dynamic readings.
- Haptics: `HapticFeedback.lightImpact()` on key interactions.
- Settings: Dark mode toggle via `ThemeProvider.instance.toggleTheme()`; session reset via `SessionService`.
- Navigation: `CupertinoPageRoute` and custom `PageRouteBuilder` slide transitions.

---

## Animations & Transitions

- Bottom bar notch indicator:
  - Duration: 220 ms, movement synced with PageView (`easeOutCubic`).
- Heart icon pulse:
  - `TweenAnimationBuilder<double>`; duration ~`1200 + heartRate*8` ms; scale 0.98→1.02.
- Health/Medication cards:
  - `BackdropFilter` with `ImageFilter.blur(sigmaX: 10, sigmaY: 10)` (glass effect).
  - Value changes via `AnimatedSwitcher` (500 ms, `Curves.easeOut`, fade + slight slide up).
- Automation/Medication sections entrance:
  - `TweenAnimationBuilder<double>`; 600 ms fade-in + 8px upward slide.
- Toggle/controls:
  - `AnimatedAlign` for switches (200–300 ms).
  - `AnimatedContainer` for theme toggle track (300 ms).
- Page transitions:
  - `PageView.animateToPage`: 220 ms, `Curves.easeOutCubic`.
  - Route transitions: 300 ms, `Curves.easeInOutCubic` slide-in.

---

## Theme Integration

- Pattern: `isDarkMode` computed from `Theme.of(context).brightness`.
- Color, border, shadow, and background logic branch on `isDarkMode` across all cards.
- Gradients sourced from `theme.AppTheme` methods for each mode.
- Bottom bar lifecycle-safe: controller recreated on brightness changes, disposed in `dispose()`.

Key snippet:

```dart
final brightness = Theme.of(context).brightness;
final isDarkMode = brightness == Brightness.dark;
if (_lastBrightness != brightness) {
  _lastBrightness = brightness;
  final old = _controller;
  _controller = NotchBottomBarController(index: _currentIndex);
  old.dispose();
}
```

---

## Code Dependencies

Imports influencing UI/styling:

- `package:flutter/material.dart`, `package:flutter/cupertino.dart`
- `dart:ui` (for `ImageFilter.blur`)
- `package:animated_notch_bottom_bar/...` (bottom navigation)
- Local modules:
  - `theme/app_theme.dart` (gradients)
  - `providers/theme_provider.dart` (theme toggling)
  - `services/session_service.dart` (session/reset UI)
  - `controllers/home_automation_controller.dart`
  - Screens: `chat_screen_new.dart`, `room_details_screen.dart`, `all_rooms_screen.dart`, `diagnostic_screen.dart`, `main.dart`

---

## UX Notes

- Visual language: iOS-inspired with glassmorphism, tight letter-spacing, and rounded, elevated surfaces.
- Bottom navigation: prominent notch with instant indicator movement and synced page animation.
- Hierarchy: larger titles (24–32), bold weights for key values, smaller captions for context.
- Feedback: Haptic cues on actions; subtle animations on value changes to indicate live data.
- Consistency: Dark theme uses `#1C1C1E` and `#2C2C2E` surfaces, `#3C3C3E` outlines, `#8E8E93` inactive labels, and white for active elements.
- Accessibility considerations: increased contrast in dark mode (recently adjusted), consistent sizes (18/24 px icons), and clear sectioning via padding and shadows.

---

## Example Structural Snippets

### Scaffold + PageView + Bottom Bar

```dart
return Scaffold(
  backgroundColor: isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFFDFDFD),
  body: Container(
    decoration: BoxDecoration(
      gradient: isDarkMode
          ? theme.AppTheme.getPrimaryGradient(context)
          : theme.AppTheme.lightPrimaryGradient,
    ),
    child: PageView(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      children: bottomBarPages,
    ),
  ),
  bottomNavigationBar: AnimatedNotchBottomBar(
    notchBottomBarController: _controller,
    color: isDarkMode ? const Color(0xFF2C2C2E) : const Color(0xFFFDFDFD),
    notchColor: isDarkMode ? const Color(0xFF3C3C3E) : const Color(0xFF475569),
    durationInMilliSeconds: 220,
    onTap: (index) {
      _controller.jumpTo(index);
      _pageController.animateToPage(index,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    },
  ),
);
```

### Glassmorphism Card Pattern

```dart
Container(
  decoration: isDarkMode ? _getCardDecorationDark() : _getCardDecorationLight(),
  child: ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: ...,
    ),
  ),
)
```

---

Document generated from `lib/next_screen.dart` (updated on 2025-11-01).
