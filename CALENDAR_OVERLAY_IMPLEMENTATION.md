# Calendar Overlay Implementation

## Overview
Ported `CalendarOverlay.tsx` to Flutter as `lib/screens/calendar_overlay.dart`.

## Features
- **Custom Modal**: Uses `PageRouteBuilder` with `opaque: false` for a transparent backdrop.
- **Backdrop Blur**: Implemented using `BackdropFilter` with `ImageFilter.blur`.
- **Calendar Grid**: 7-column grid for days.
- **Styling**:
  - Rounded corners (48px).
  - Custom shadows.
  - "Blocky and bold" typography (`GoogleFonts.inter`).
  - Indicator dots for specific days.
- **Integration**:
  - Linked to the "Today" text and chevron down icon in `PatientHomeScreen`.

## Files Created/Modified
- `lib/screens/calendar_overlay.dart` (New)
- `lib/screens/patient_home_screen.dart` (Modified)
