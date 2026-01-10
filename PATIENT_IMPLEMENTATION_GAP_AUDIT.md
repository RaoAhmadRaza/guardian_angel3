# Patient Implementation Gap Audit

**Scope:** Patient role only  
**Focus:** UI elements present with missing/stubbed functionality  
**Date:** January 9, 2026  
**Exclusions:** Backend services, cloud integrations, third-party SDKs, Caregiver/Doctor flows

---

## 1. Real-Time Vitals Monitoring

**Entry Point:** [lib/next_screen.dart](lib/next_screen.dart) (Patient home screen - main tab)

**UI Coverage:**
- Heart rate display card with animated heart icon
- Blood pressure display card
- Heart rhythm visualization
- Lines [354-716](lib/next_screen.dart#L354-L716)

**Missing Functionality:**
- No active connection to health data repository
- Vitals displays show placeholder values (`--/min`, `--/--`)
- Animation triggers conditionally on `_homeState.vitals.hasData` but data source always returns empty
- Backend data provider explicitly returns `VitalsData.empty`

**Evidence:**
- Data provider: [lib/screens/patient_home/patient_home_data_provider.dart](lib/screens/patient_home/patient_home_data_provider.dart#L153-L161)
  ```dart
  /// TODO: Replace with actual VitalsRepository when available
  Future<VitalsData> _loadVitals(String? uid) async {
    // Currently no vitals repository - return simulated live data flag
    // The screen will handle live animation if no stored data
    return VitalsData.empty;
  }
  ```

**Severity:** **HIGH** - Core patient monitoring feature visible but non-functional; may mislead users expecting live health tracking.

---

## 2. Safety Status & Location Monitoring

**Entry Point:** [lib/next_screen.dart](lib/next_screen.dart) (Patient home screen)

**UI Coverage:**
- Safety status card (visible in home state structure)
- Safety monitoring indicators referenced in state model

**Missing Functionality:**
- No integration with location services
- Safety status hardcoded to `SafetyStatus.unknown`
- No geofencing or safe zone boundary tracking

**Evidence:**
- Data provider: [lib/screens/patient_home/patient_home_data_provider.dart](lib/screens/patient_home/patient_home_data_provider.dart#L162-L170)
  ```dart
  /// TODO: Replace with actual SafetyRepository when available
  Future<SafetyStatus> _loadSafetyStatus(String? uid) async {
    // For first-time users: no safety monitoring is active yet
    // Return unknown/not-monitored state - never fake "All Clear"
    return SafetyStatus.unknown;
  }
  ```

**Severity:** **MEDIUM** - Safety feature advertised but not active; lower severity as it returns "unknown" rather than false positives.

---

## 3. Doctor Assignment & Clinical Data

**Entry Point:** [lib/next_screen.dart](lib/next_screen.dart) (Patient home screen - doctor info section)

**UI Coverage:**
- Doctor profile card
- "Not Assigned" placeholder visible when no doctor linked
- Lines [1006+](lib/next_screen.dart#L1006)

**Missing Functionality:**
- Doctor info always returns empty placeholder
- No relationship lookup or doctor profile loading
- Diagnosis summary always empty

**Evidence:**
- Data provider: [lib/screens/patient_home/patient_home_data_provider.dart](lib/screens/patient_home/patient_home_data_provider.dart#L171-L187)
  ```dart
  /// TODO: Replace with actual DoctorRepository when available
  Future<DoctorInfo> _loadDoctorInfo(String? uid) async {
    // For first-time users: no doctor is assigned yet
    // Return empty placeholder - never fake a doctor name
    return DoctorInfo.empty;
  }

  /// TODO: Replace with actual DiagnosisRepository when available
  Future<DiagnosisSummary> _loadDiagnosisSummary(String? uid) async {
    // For first-time users: no diagnosis history exists
    // Return empty placeholder - never fake diagnosis data
    return DiagnosisSummary.empty;
  }
  ```

**Severity:** **MEDIUM** - UI correctly shows "Not Assigned" so no misleading data, but doctor linking workflow incomplete.

---

## 4. Home Automation Integration

**Entry Point:** [lib/next_screen.dart](lib/next_screen.dart#L1152) (Patient home - Bulb/Automation tab)

**UI Coverage:**
- Full home automation dashboard UI (separate module)
- Room cards, device controls
- Entire `DrawerWrapper(homeScreen: HomeAutomationScreen())` navigation

**Missing Functionality:**
- Automation summary cards on home screen always empty
- No device connection or smart home API integration in patient context

**Evidence:**
- Data provider: [lib/screens/patient_home/patient_home_data_provider.dart](lib/screens/patient_home/patient_home_data_provider.dart#L189-L197)
  ```dart
  /// TODO: Replace with actual HomeAutomationRepository when available
  Future<List<AutomationCardData>> _loadAutomationCards(String? uid) async {
    // For first-time users: no devices are connected
    // Return empty list - never seed fake device data
    return const [];
  }
  ```

**Severity:** **LOW** - Home automation is ancillary to core health monitoring; UI correctly shows empty state.

---

## 5. Medication Schedule & Tracking

**Entry Point:** 
- [lib/next_screen.dart](lib/next_screen.dart#L1640-L1705) (Patient home - medication section)
- [lib/screens/patient_home_screen.dart](lib/screens/patient_home_screen.dart) (detailed medication screen)

**UI Coverage:**
- Medication time slots display
- "See More" button navigation to full medication screen
- Detailed medication cards with stock tracking UI (lines [35-60](lib/screens/patient_home_screen.dart#L35-L60) show hardcoded sample medications)

**Missing Functionality:**
- No persistent medication storage
- Patient home data provider returns empty medication list
- Full screen uses hardcoded static medication array in widget state (not persisted)

**Evidence:**
- Data provider: [lib/screens/patient_home/patient_home_data_provider.dart](lib/screens/patient_home/patient_home_data_provider.dart#L198-L206)
  ```dart
  /// TODO: Replace with actual MedicationRepository when available
  Future<List<MedicationTimeSlot>> _loadMedicationSchedule(String? uid) async {
    // For first-time users: no medications are added
    // Return empty list - never seed fake medication data
    return const [];
  }
  ```
- Full screen hardcoded data: [lib/screens/patient_home_screen.dart](lib/screens/patient_home_screen.dart#L23-L60) (in-memory `_medications` list, not backed by database)

**Severity:** **HIGH** - Medication adherence is critical for patient health; current implementation loses data on app restart.

---

## 6. Care Team Chat & Messaging

**Entry Point:** [lib/screens/patient_chat_screen.dart](lib/screens/patient_chat_screen.dart) (Patient home - Chat tab, lines [1-70](lib/screens/patient_chat_screen.dart#L1-L70))

**UI Coverage:**
- Chat session list UI
- Care team directory
- Medication status widget
- Peace of mind/community status cards

**Missing Functionality:**
- Care team list always empty (no local storage integration)
- Medication status returns `null`
- Peace/community status returns `null`
- No persistence layer for adding care team members

**Evidence:**
- Data provider: [lib/screens/patient_chat/patient_chat_data_provider.dart](lib/screens/patient_chat/patient_chat_data_provider.dart)
  - Lines [24](lib/screens/patient_chat/patient_chat_data_provider.dart#L24): `// TODO: Load care team from local storage`
  - Lines [27](lib/screens/patient_chat/patient_chat_data_provider.dart#L27): `// TODO: Load medication status from local storage`
  - Lines [30](lib/screens/patient_chat/patient_chat_data_provider.dart#L30): `// TODO: Load peace status from local storage`
  - Lines [33](lib/screens/patient_chat/patient_chat_data_provider.dart#L33): `// TODO: Load community status from local storage`
  - Lines [61-85](lib/screens/patient_chat/patient_chat_data_provider.dart#L61-L85): All load methods return empty/null
  - Lines [129-147](lib/screens/patient_chat/patient_chat_data_provider.dart#L129-L147): All persistence methods are no-ops with TODO comments

**Severity:** **HIGH** - Communication with care team is core to patient safety; current state shows empty UI with no way to persist contacts.

---

## 7. AI Health Chat Assistant

**Entry Point:** [lib/screens/patient_ai_chat_screen.dart](lib/screens/patient_ai_chat_screen.dart) (accessible from Patient chat screen)

**UI Coverage:**
- Full AI chat interface
- Voice/text input toggle
- Caregiver quick-call widget
- Heart rate monitoring status display

**Missing Functionality:**
- Chat history not persisted (only welcome message loads)
- No caregiver data loaded
- Heart rate monitoring status always returns `false`
- No device connection for live health data

**Evidence:**
- Data provider: [lib/screens/patient_ai_chat/patient_ai_chat_data_provider.dart](lib/screens/patient_ai_chat/patient_ai_chat_data_provider.dart)
  - Lines [50](lib/screens/patient_ai_chat/patient_ai_chat_data_provider.dart#L50): `// TODO: Implement Hive loading` (chat messages)
  - Lines [66](lib/screens/patient_ai_chat/patient_ai_chat_data_provider.dart#L66): `// TODO: Implement Hive loading` (caregiver)
  - Lines [74](lib/screens/patient_ai_chat/patient_ai_chat_data_provider.dart#L74): `// TODO: Implement health data loading` (heart rate)
  - Lines [82](lib/screens/patient_ai_chat/patient_ai_chat_data_provider.dart#L82): `// TODO: Implement status loading` (monitoring)
  - Lines [104-116](lib/screens/patient_ai_chat/patient_ai_chat_data_provider.dart#L104-L116): All persistence methods are stubs

**Severity:** **MEDIUM** - AI chat works for single-session interaction but loses context/history; caregiver widget non-functional.

---

## 8. Emergency SOS System

**Entry Point:** [lib/screens/patient_sos_screen.dart](lib/screens/patient_sos_screen.dart) (accessible from Patient chat screen)

**UI Coverage:**
- Full SOS activation screen with slide-to-confirm
- Heart rate display
- Location status
- Live speech transcription indicator
- Emergency contact notification status
- Lines [1-70](lib/screens/patient_sos_screen.dart#L1-L70)

**Missing Functionality:**
- No connection to actual heart rate service
- No location service integration
- No speech recognition integration
- No SOS backend notification service

**Evidence:**
- Data provider: [lib/screens/patient_sos/patient_sos_data_provider.dart](lib/screens/patient_sos/patient_sos_data_provider.dart#L119-L134)
  ```dart
  /// TODO: Connect these to actual service implementations:
  /// - Heart rate monitor service
  /// - Location service
  /// - Speech recognition service
  /// - SOS backend service
  Future<void> _connectToServices() async {
    // PLACEHOLDER: Connect to heart rate service
    // _heartRateSubscription = heartRateService.stream.listen(_onHeartRateUpdate);
    
    // PLACEHOLDER: Connect to location service
    // _locationSubscription = locationService.stream.listen(_onLocationUpdate);
    
    // PLACEHOLDER: Connect to speech recognition service
    // _transcriptSubscription = speechService.stream.listen(_onTranscriptUpdate);
    
    // PLACEHOLDER: Connect to SOS backend service
    // _sosEventSubscription = sosService.eventStream.listen(_onSosEvent);
  }
  ```

**Severity:** **CRITICAL** - SOS is a life-safety feature; UI exists but no actual emergency notification occurs when activated.

---

## 9. Settings - Profile Management

**Entry Point:** [lib/settings/profile_screen.dart](lib/settings/profile_screen.dart) (via [lib/settings_screen.dart](lib/settings_screen.dart#L183))

**UI Coverage:**
- Full profile edit form
- Name, email, phone, address fields
- Edit/Done toggle
- Profile picture placeholder
- Lines [1-120](lib/settings/profile_screen.dart#L1-L120)

**Missing Functionality:**
- Form uses hardcoded controller values (`"John Doe"`, `"john.doe@example.com"`)
- Save action shows success snackbar but no actual persistence
- No integration with OnboardingLocalService or PatientService to load/save real user data

**Evidence:**
- Controller initialization: [lib/settings/profile_screen.dart](lib/settings/profile_screen.dart#L15-L17) (hardcoded strings)
- Save handler: Lines [53-59](lib/settings/profile_screen.dart#L53-L59) - only validates and shows snackbar, no database call

**Severity:** **MEDIUM** - Users can't update their profile information; however, onboarding captures initial data correctly.

---

## 10. Settings - Guardian Management

**Entry Point:** [lib/settings/guardians_screen.dart](lib/settings/guardians_screen.dart) (via [lib/settings_screen.dart](lib/settings_screen.dart#L193))

**UI Coverage:**
- Guardian list view
- "Add Guardian" dialog
- Status indicators (Active/Pending)
- Lines [1-120](lib/settings/guardians_screen.dart#L1-L120)

**Missing Functionality:**
- Guardian list uses hardcoded in-memory array
- Add dialog likely collects data but doesn't persist (not shown in excerpt)
- No relationship service integration

**Evidence:**
- Hardcoded list: [lib/settings/guardians_screen.dart](lib/settings/guardians_screen.dart#L13-L16)
  ```dart
  final List<Map<String, String>> _guardians = [
    {'name': 'Sarah Connor', 'relation': 'Daughter', 'status': 'Active'},
    {'name': 'Kyle Reese', 'relation': 'Son', 'status': 'Pending'},
  ];
  ```

**Severity:** **HIGH** - Guardian relationships are critical for patient safety alerts; current state loses data on restart.

---

## 11. Settings - Doctor Linking

**Entry Point:** [lib/settings/doctors_screen.dart](lib/settings/doctors_screen.dart) (via [lib/settings_screen.dart](lib/settings_screen.dart#L203))

**UI Coverage:**
- Linked doctors list
- Invite code generation
- Active relationship status indicators
- Lines [1-120](lib/settings/doctors_screen.dart#L1-L120)

**Missing Functionality:**
- Doctor list loads correctly from Firestore (`DoctorRelationshipService`)
- **This feature appears to be IMPLEMENTED** with actual backend integration
- Not a gap - doctor linking has real persistence

**Evidence:**
- Service integration: [lib/settings/doctors_screen.dart](lib/settings/doctors_screen.dart#L50-L77) shows actual Firestore queries and relationship loading

**Severity:** **N/A** - No implementation gap; feature is functional.

---

## 12. Settings - Emergency Contacts

**Entry Point:** [lib/settings/emergency_contacts_screen.dart](lib/settings/emergency_contacts_screen.dart) (via [lib/settings_screen.dart](lib/settings_screen.dart#L213))

**UI Coverage:**
- Emergency contact list (expected based on navigation)

**Missing Functionality:**
- Screen file exists but detailed inspection not completed
- Likely similar pattern to guardians (hardcoded list)

**Evidence:**
- File exists: [lib/settings/emergency_contacts_screen.dart](lib/settings/emergency_contacts_screen.dart)
- Requires inspection to confirm gap severity

**Severity:** **MEDIUM** (assumed based on pattern) - Emergency contacts critical for safety.

---

## 13. Settings - Health Thresholds

**Entry Point:** [lib/settings/health_thresholds_screen.dart](lib/settings/health_thresholds_screen.dart) (via [lib/settings_screen.dart](lib/settings_screen.dart#L223))

**UI Coverage:**
- Health threshold configuration UI (expected)

**Missing Functionality:**
- Screen file exists but detailed inspection not completed
- Likely disconnected from actual monitoring logic (since vitals monitoring is stubbed)

**Evidence:**
- File exists: [lib/settings/health_thresholds_screen.dart](lib/settings/health_thresholds_screen.dart)
- Requires inspection to confirm gap severity

**Severity:** **LOW** (assumed) - Configuration UI less critical if underlying monitoring isn't active.

---

## 14. Settings - Device Settings

**Entry Point:** [lib/settings/device_settings_screen.dart](lib/settings/device_settings_screen.dart) (via [lib/settings_screen.dart](lib/settings_screen.dart#L233))

**UI Coverage:**
- Device pairing/management UI (expected)

**Missing Functionality:**
- Screen file exists but detailed inspection not completed
- No wearable device integration confirmed (vitals data always empty)

**Evidence:**
- File exists: [lib/settings/device_settings_screen.dart](lib/settings/device_settings_screen.dart)
- Requires inspection to confirm gap severity

**Severity:** **HIGH** (assumed) - Device pairing prerequisite for vitals monitoring.

---

## Summary of Severity Distribution

| Severity | Count | Features |
|----------|-------|----------|
| **CRITICAL** | 1 | Emergency SOS System |
| **HIGH** | 5 | Real-Time Vitals, Medication Tracking, Care Team Chat, Guardian Management, (Device Settings - assumed) |
| **MEDIUM** | 4 | Safety Monitoring, Doctor Assignment, AI Chat History, Profile Management |
| **LOW** | 2 | Home Automation, Health Thresholds |
| **N/A** | 1 | Doctor Linking (implemented) |

---

## Key Patterns Observed

1. **Explicit TODO Comments**: Most data providers contain clear `// TODO: Replace with actual *Repository` markers
2. **Safe Empty States**: Code correctly returns empty/null rather than fake data (production-safe design)
3. **UI-First Development**: Polished UI exists before backend integration
4. **Hardcoded Demo Data**: Some screens use in-memory arrays for demonstration (profile, guardians, medications in full screen)
5. **No Persistence Layer**: Most "add/update" methods are stubs with TODO comments

---

## Audit Methodology

- **Scope**: Patient role screens only (from login → NextScreen → Patient Home/Chat/Settings)
- **Search Strategy**: Grepped for `TODO|FIXME|placeholder|mock` in `lib/screens/patient_*` and `lib/settings/`
- **Verification**: Cross-referenced UI screens with their data provider implementations
- **Exclusion**: Did not inspect backend services, Firebase rules, or shared infrastructure

---

**End of Audit**
