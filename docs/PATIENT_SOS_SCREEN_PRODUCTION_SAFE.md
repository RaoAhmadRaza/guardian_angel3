# Patient SOS Screen — Production-Safe Implementation

## Overview

The `PatientSosScreen` has been refactored from a fully simulated demo into a production-ready, state-driven emergency SOS screen.

**Date**: December 23, 2025
**Status**: ✅ Complete

---

## Architecture

### Files Created/Modified

| File | Purpose |
|------|---------|
| `lib/screens/patient_sos/patient_sos_state.dart` | State model with SosPhase enum |
| `lib/screens/patient_sos/patient_sos_data_provider.dart` | Event-driven data provider |
| `lib/screens/patient_sos_screen.dart` | Refactored to consume state |

---

## State Model (`PatientSosState`)

```dart
class PatientSosState {
  final SosPhase phase;           // Current SOS phase
  final Duration elapsed;          // Time since SOS started
  final int? heartRate;            // null = no device connected
  final String? caregiverName;     // null = name unavailable
  final String? locationText;      // null = location not resolved
  final List<String> transcript;   // Empty = no transcript yet
  final bool medicalIdShared;      // Only true when backend confirms
  final bool isRecording;          // Microphone recording state
  final bool locationDenied;       // Location permission denied
  final bool microphoneDenied;     // Microphone permission denied
}
```

### SOS Phases

```dart
enum SosPhase {
  idle,                // No SOS active
  contactingCaregiver, // SOS initiated, contacting caregiver
  caregiverNotified,   // Caregiver has been notified
  contactingEmergency, // Escalating to emergency services
  connected,           // Connected to emergency services
}
```

### Initial State (First-Frame)

```dart
PatientSosState.initial() → {
  phase: contactingCaregiver,
  elapsed: Duration.zero,
  heartRate: null,
  caregiverName: null,
  locationText: null,
  transcript: [],
  medicalIdShared: false,
  isRecording: true,
}
```

---

## What Was Removed (FAKE DATA)

| Removed | Replaced With |
|---------|---------------|
| `"Sarah Notified"` | `_state.mainStatusText` (uses real name or "Caregiver notified") |
| `"112"` BPM | `_state.heartRateDisplay` (shows "--" when no device) |
| `"124 Maple Ave"` | `_state.locationDisplay` (shows "Locating..." until resolved) |
| `["I've fallen...", "My leg hurts."]` | `_state.transcriptDisplay` (shows "Listening..." until real transcript) |
| `Timer.periodic` for timer | Provider manages elapsed time |
| `Future.delayed(2500ms)` for status | Phase only changes on real events |
| `Future.delayed(4000ms)` for medical ID | Only shows when `medicalIdShared == true` |
| `Future.delayed(8000ms)` for escalation | Only escalates on real backend event |
| `_statusStep` variable | `_state.progressStep` computed from phase |
| `_timerSeconds` variable | `_state.elapsed` from provider |
| `_medicalIdSent` variable | `_state.medicalIdShared` from provider |
| `_transcript` list | `_state.transcript` from provider |

---

## UI Behavior Matrix

### Timer Display

| Condition | Display |
|-----------|---------|
| SOS just started | `00:00` |
| After real elapsed time | `MM:SS` from state |

### Status Text

| Phase | Main Text | Sub Text |
|-------|-----------|----------|
| `contactingCaregiver` | "Contacting caregiver..." | "Transmitting vitals..." |
| `caregiverNotified` | "{Name} notified" or "Caregiver notified" | "Awaiting response..." |
| `contactingEmergency` | "Emergency services" | "Connecting line..." |
| `connected` | "Connected" | "Help is on the way" |

### Heart Rate Card

| Condition | Display | Waveform |
|-----------|---------|----------|
| No device | `-- BPM` | Hidden |
| Device connected | Real BPM | Animated |

### Location Card

| Condition | Display |
|-----------|---------|
| Not resolved | "Locating..." |
| Permission denied | "Location unavailable" |
| Resolved | Real address |

### Transcript Card

| Condition | Display | Waveform |
|-----------|---------|----------|
| Recording, no transcript | "Listening..." | Animated |
| Recording, has transcript | `"{last transcript}"` | Animated |
| Permission denied | "Microphone unavailable" | Static (dimmed) |

### Medical ID Badge

| Condition | Visibility |
|-----------|------------|
| `medicalIdShared == false` | Hidden |
| `medicalIdShared == true` | Visible with animation |

---

## Data Provider Events

The `PatientSosDataProvider` exposes methods that should be called by real services:

```dart
// Heart rate events
onHeartRateUpdate(int bpm)
onHeartRateDisconnected()

// Location events
onLocationResolved(String address)
onLocationDenied()

// Transcript events
onTranscriptUpdate(String text)
onMicrophoneDenied()

// SOS session events
onCaregiverResolved(String name)
onCaregiverNotified()
onContactingEmergency()
onEmergencyConnected()
onMedicalIdShared()
```

### What the Provider Does NOT Do

❌ Auto-progress phases without real events
❌ Simulate heart rate values
❌ Fake transcript messages
❌ Auto-reveal Medical ID
❌ Use `Future.delayed` for state changes

### What the Provider DOES Do

✅ Manages elapsed time counter (real time only)
✅ Listens for real service events
✅ Updates state only when events occur
✅ Exposes stream for UI updates

---

## Safety Guarantees

1. **No fake data** - All displayed values come from real sources or show honest placeholders
2. **No auto-progression** - Phase only changes when real events occur
3. **Audit-ready** - Every value shown can be traced to a real event or an honest "unavailable" state
4. **First-time safe** - New users see honest placeholders, not demo data
5. **Backend-decoupled** - If backend is unavailable, screen stays in current state (no fake progress)

---

## Testing Checklist

- [ ] Open SOS screen → shows "Contacting caregiver...", "-- BPM", "Locating...", "Listening..."
- [ ] No phase progression without calling provider events
- [ ] Heart rate shows "--" when no device connected
- [ ] Location shows "Locating..." when not resolved
- [ ] Transcript shows "Listening..." when empty
- [ ] Medical ID badge does NOT appear automatically
- [ ] Cancel slider works and calls `cancelSosSession()`
- [ ] Timer increments (elapsed time from provider)

---

## Visual Preservation

The following UI elements remain UNCHANGED:

- ✅ Red ambient glow background with pulse animation
- ✅ "Active Monitoring" badge with green shield
- ✅ Sonar pulse rings animation
- ✅ Phone icon in center with red gradient
- ✅ Horizontal step tracker (3 dots)
- ✅ Heart rate glass card layout
- ✅ 3D perspective map card
- ✅ Transcript card with mic icon
- ✅ Medical ID amber badge styling
- ✅ Frosted track slider with thumb
- ✅ Cancel confirmation popup
- ✅ All shadows, colors, spacing, animations

---

## Future Integration Points

To connect to real services, implement:

1. **Heart Rate Service** → Call `onHeartRateUpdate(bpm)`
2. **Location Service** → Call `onLocationResolved(address)`
3. **Speech Recognition** → Call `onTranscriptUpdate(text)`
4. **SOS Backend** → Call phase transition events
5. **Medical ID Service** → Call `onMedicalIdShared()`

The screen will automatically update when these events fire.
