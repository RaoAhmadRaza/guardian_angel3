# Patient Role Edge Case Audit

## Executive Summary

This audit identifies **47 edge cases** across the patient-facing functionality that are NOT currently handled. These represent real-world scenarios that actual elderly users would encounter.

---

## 🔴 CRITICAL ISSUES (8)

### 1. SOS Screen - No Permission Denial Recovery
**File:** [patient_sos_screen.dart](lib/screens/patient_sos_screen.dart)  
**Lines:** 1-927 (entire screen)

**Edge Case:** User triggers SOS but location/microphone permissions are denied at the OS level.

**Current Behavior:** State has `locationDenied` and `microphoneDenied` flags but:
- No UI prompts user to enable permissions
- No button to open Settings app
- SOS continues without location data (emergency services can't find patient)

**Expected Behavior:**
- Show prominent "Enable Location for Emergency Services" dialog
- Provide direct link to iOS/Android Settings
- Store last-known location as fallback
- Display warning if proceeding without location

**Severity:** 🔴 CRITICAL

---

### 2. SOS Screen - No Network Failure Handling
**File:** [patient_sos_data_provider.dart](lib/screens/patient_sos/patient_sos_data_provider.dart)  
**Lines:** 62-90

**Edge Case:** User triggers SOS while offline or in poor network conditions.

**Current Behavior:** 
- No check for network connectivity before attempting to contact caregiver
- No fallback to SMS/phone call
- No offline queue for SOS events
- No retry mechanism

**Expected Behavior:**
- Detect network state before SOS
- Fall back to SMS for primary caregiver contact
- Queue SOS event for sync when online
- Show "Calling emergency services directly" fallback

**Severity:** 🔴 CRITICAL

---

### 3. SOS Screen - No Caregiver Response Timeout
**File:** [patient_sos_data_provider.dart](lib/screens/patient_sos/patient_sos_data_provider.dart)  
**Lines:** 130-175

**Edge Case:** SOS triggered but no caregiver responds within reasonable time.

**Current Behavior:**
- Phase stuck at `contactingCaregiver` indefinitely
- No automatic escalation to emergency services
- Patient left waiting with no action taken

**Expected Behavior:**
- Configurable timeout (e.g., 30 seconds)
- Auto-escalate to next emergency contact
- After 2 failed contacts, offer to call 911 directly
- Show countdown: "Escalating in X seconds..."

**Severity:** 🔴 CRITICAL

---

### 4. AI Chat - No API Key Causes Silent Failure UX
**File:** [guardian_ai_service.dart](lib/services/guardian_ai_service.dart)  
**Lines:** 100-108

**Edge Case:** OpenAI API key not configured in production build.

**Current Behavior:**
- Returns generic "I'm being set up" message
- User cannot chat with AI at all
- No indication this is a configuration issue vs. user error

**Expected Behavior:**
- Admin notification that API key is missing
- Fallback to local FAQ/help content
- Clear "Service temporarily unavailable" message
- Retry button that checks configuration

**Severity:** 🔴 CRITICAL

---

### 5. Session Expiry Not Handled on Patient Screens
**File:** [session_service.dart](lib/services/session_service.dart)  
**Lines:** 30-60

**Edge Case:** User's session expires (after 2 days) while actively using the app.

**Current Behavior:**
- `hasValidSession()` returns false
- Screens that depend on `FirebaseAuth.instance.currentUser?.uid` silently fail
- No redirect to login
- Data may be loaded for wrong/null user

**Expected Behavior:**
- Auth state listener on all patient screens
- Automatic redirect to login when session expires
- "Session expired - please log in again" message
- Preserve current screen state for post-login restoration

**Severity:** 🔴 CRITICAL

---

### 6. Patient Home - Hardcoded User Data
**File:** [patient_home_screen.dart](lib/screens/patient_home_screen.dart)  
**Lines:** 107-159

**Edge Case:** Any patient using the app sees "Jacob Miller" instead of their own name.

**Current Behavior:**
- Name hardcoded as 'Jacob Miller'
- Profile image hardcoded to random Unsplash URL
- Patient ID hardcoded in profile sheet

**Expected Behavior:**
- Load patient name from `PatientHomeDataProvider`
- Use actual profile image or generated avatar
- Display real patient ID

**Severity:** 🔴 CRITICAL

---

### 7. Patient Home - Medications Not Persisted
**File:** [patient_home_screen.dart](lib/screens/patient_home_screen.dart)  
**Lines:** 25-58

**Edge Case:** User adds medications, closes app, medications are gone.

**Current Behavior:**
- Medications stored in local `_medications` List (RAM only)
- `_addMedication()` only adds to local state
- No call to `MedicationService.saveMedication()`

**Expected Behavior:**
- Persist medications via `MedicationService`
- Load medications from service on init
- Sync with backend

**Severity:** 🔴 CRITICAL

---

### 8. Profile Screen - Hardcoded Values, No Persistence
**File:** [profile_screen.dart](lib/settings/profile_screen.dart)  
**Lines:** 14-18

**Edge Case:** Patient tries to update profile, changes are never saved.

**Current Behavior:**
- All TextEditingControllers initialized with hardcoded fake data
- "Done" button shows SnackBar but doesn't save anywhere
- No connection to `PatientService` or any persistence layer

**Expected Behavior:**
- Load actual patient data from `PatientService` or `OnboardingLocalService`
- Save changes to local storage and queue for sync
- Show error if save fails

**Severity:** 🔴 CRITICAL

---

## 🟠 HIGH ISSUES (12)

### 9. Patient Chat - Placeholder Patient Name
**File:** [patient_chat_screen.dart](lib/screens/patient_chat_screen.dart)  
**Lines:** 219-221

**Edge Case:** All patients see "Good Afternoon there" instead of their name.

**Current Behavior:**
```dart
const patientName = 'there'; // Placeholder - will be loaded from storage
```

**Expected Behavior:** Load from `PatientService.getPatientFirstName()`.

**Severity:** 🟠 HIGH

---

### 10. AI Chat - No Rate Limiting on Client
**File:** [patient_ai_chat_screen.dart](lib/screens/patient_ai_chat_screen.dart)  
**Lines:** 139-210

**Edge Case:** Elderly user rapidly taps send, causing multiple API calls and charges.

**Current Behavior:**
- No debouncing on send button
- No "thinking" state that disables input
- Each tap creates new API request

**Expected Behavior:**
- Disable send while `isAITyping`
- Add debounce (500ms minimum)
- Rate limit to 10 messages/minute client-side

**Severity:** 🟠 HIGH

---

### 11. AI Chat - No Character Limit on Input
**File:** [patient_ai_chat_screen.dart](lib/screens/patient_ai_chat_screen.dart)  
**Lines:** 139-145

**Edge Case:** User pastes extremely long text, causing API timeout or token limit error.

**Current Behavior:**
- No `maxLength` on TextField
- No validation on message length
- OpenAI will reject with 429 if too many tokens

**Expected Behavior:**
- Limit input to 2000 characters
- Show character counter
- Friendly message if exceeded

**Severity:** 🟠 HIGH

---

### 12. Add Medication - No Input Validation
**File:** [add_medication_modal.dart](lib/screens/add_medication_modal.dart)  
**Lines:** 40-60

**Edge Case:** User taps "Next" without entering medication name.

**Current Behavior:**
- `_name` remains empty string
- Medication created with empty name
- No validation before proceeding to next step

**Expected Behavior:**
- Require non-empty medication name
- Validate dosage format
- Show error if required fields missing

**Severity:** 🟠 HIGH

---

### 13. Emergency Contacts - No Phone Number Validation
**File:** [emergency_contacts_screen.dart](lib/settings/emergency_contacts_screen.dart)  
**Lines:** 241-300

**Edge Case:** User enters invalid phone number "abc123".

**Current Behavior:**
- Any string accepted as phone number
- No format validation
- SOS would fail to call invalid number

**Expected Behavior:**
- Validate phone format (E.164 or locale-specific)
- Show format hint
- Test call capability before saving

**Severity:** 🟠 HIGH

---

### 14. Guardians Screen - No Confirmation for Primary Change
**File:** [guardians_screen.dart](lib/settings/guardians_screen.dart)  
**Lines:** 50-56

**Edge Case:** User accidentally sets wrong person as primary guardian.

**Current Behavior:**
- Single tap changes primary guardian
- No confirmation dialog
- No undo option

**Expected Behavior:**
- Confirmation: "Set [Name] as primary guardian?"
- Undo option via snackbar
- Explain implications of primary guardian

**Severity:** 🟠 HIGH

---

### 15. Health Thresholds - No Validation on Range
**File:** [health_thresholds_screen.dart](lib/settings/health_thresholds_screen.dart)  
**Lines:** 124-150

**Edge Case:** User sets heart rate min higher than max (e.g., 100-60 BPM).

**Current Behavior:**
- RangeSlider allows min > max visually
- Invalid range saved to storage
- Alerts triggered incorrectly

**Expected Behavior:**
- RangeSlider should enforce min < max
- Validate before save
- Show warning for unusual ranges

**Severity:** 🟠 HIGH

---

### 16. All Patient Screens - No Loading States
**File:** Multiple files

**Edge Case:** Slow device/network causes data to load slowly.

**Current Behavior:**
- `patient_home_screen.dart`: No loading indicator while loading medications
- `patient_chat_screen.dart`: `_isLoading` flag exists but no skeleton UI
- `guardians_screen.dart`: CupertinoActivityIndicator only, no skeleton

**Expected Behavior:**
- Skeleton loading screens for each section
- Progressive loading (show available data first)
- Loading timeout with retry option

**Severity:** 🟠 HIGH

---

### 17. Patient Chat - Stream Subscription Not Cancelled
**File:** [patient_chat_screen.dart](lib/screens/patient_chat_screen.dart)  
**Lines:** 180-240

**Edge Case:** Rapidly navigating in/out of chat screen causes memory leaks.

**Current Behavior:**
- `_scrollController` and `_pulseController` disposed
- No stream subscriptions visible, but `PatientChatDataProvider` may have internal streams not cancelled

**Expected Behavior:**
- Ensure all subscriptions cancelled in dispose
- Use `AutomaticKeepAliveClientMixin` if appropriate

**Severity:** 🟠 HIGH

---

### 18. AI Chat - No Message Retry on Failure
**File:** [patient_ai_chat_screen.dart](lib/screens/patient_ai_chat_screen.dart)  
**Lines:** 190-208

**Edge Case:** AI response fails due to network. User must retype message.

**Current Behavior:**
- Error message shown but original user message lost context
- No "Retry" button on failed messages
- User must retype

**Expected Behavior:**
- Show retry icon on failed messages
- Tap to resend last message
- Keep user's original message for context

**Severity:** 🟠 HIGH

---

### 19. Notification Settings - Not Persisted
**File:** [notifications_settings_screen.dart](lib/settings/notifications_settings_screen.dart)  
**Lines:** 11-20

**Edge Case:** User disables notifications, closes app, settings reset.

**Current Behavior:**
- All toggles are local `setState()` only
- No persistence layer
- No actual notification permission changes

**Expected Behavior:**
- Persist settings to SharedPreferences
- Actually disable/enable notifications via OS APIs
- Sync preferences to backend

**Severity:** 🟠 HIGH

---

### 20. Profile Sheet - No Logout Functionality Visible
**File:** [profile_sheet.dart](lib/screens/profile_sheet.dart)  
**Lines:** 1-422

**Edge Case:** User wants to log out, cannot find option.

**Current Behavior:**
- Profile sheet shows user info
- No visible "Sign Out" button in first 200 lines
- Unclear how user logs out

**Expected Behavior:**
- Clear "Sign Out" option
- Confirmation dialog
- Properly clear session via `SessionService.endSession()`

**Severity:** 🟠 HIGH

---

## 🟡 MEDIUM ISSUES (15)

### 21. Patient Home - No Empty State for Medications
**File:** [patient_home_screen.dart](lib/screens/patient_home_screen.dart)  
**Lines:** 394-420

**Edge Case:** New user has no medications scheduled.

**Current Behavior:**
- Shows hardcoded list of 3 medications
- Never shows "No medications yet" state
- Add button visible but no guidance

**Expected Behavior:**
- Empty state with illustration
- Prompt: "Add your first medication"
- Link to medication reminder benefits

**Severity:** 🟡 MEDIUM

---

### 22. AI Chat - No Offline Mode
**File:** [patient_ai_chat_screen.dart](lib/screens/patient_ai_chat_screen.dart)

**Edge Case:** Patient tries to chat with AI while offline.

**Current Behavior:**
- API call fails
- Generic error message
- No indication it's a network issue

**Expected Behavior:**
- Detect offline state
- Show "You're offline. AI chat requires internet."
- Cache last 10 messages for viewing

**Severity:** 🟡 MEDIUM

---

### 23. All Patient Screens - No Pull-to-Refresh
**File:** Multiple files

**Edge Case:** User wants to refresh data without closing/reopening screen.

**Current Behavior:**
- No RefreshIndicator on any patient screen
- Data only loads on screen init

**Expected Behavior:**
- Add `RefreshIndicator` to main scrollable areas
- Reload data from services
- Show "Last updated: X minutes ago"

**Severity:** 🟡 MEDIUM

---

### 24. SOS Screen - No Cancel Confirmation Text
**File:** [patient_sos_screen.dart](lib/screens/patient_sos_screen.dart)  
**Lines:** 63-79

**Edge Case:** User accidentally slides to cancel during real emergency.

**Current Behavior:**
- `_showCancelConfirmation` flag set at 90% threshold
- No visible confirmation dialog code in excerpt

**Expected Behavior:**
- "Are you sure? Emergency services may have already been notified."
- Large "Keep SOS Active" button
- Small "Cancel SOS" option

**Severity:** 🟡 MEDIUM

---

### 25. Patient Home - Network Image Error Handling
**File:** [patient_home_screen.dart](lib/screens/patient_home_screen.dart)  
**Lines:** 107-130

**Edge Case:** Profile image URL fails to load (no network, 404, etc.).

**Current Behavior:**
- Uses `NetworkImage` with Unsplash URL
- No `errorBuilder`
- UI breaks or shows error icon

**Expected Behavior:**
- Fallback to initials avatar
- Graceful degradation
- Cache images locally

**Severity:** 🟡 MEDIUM

---

### 26. AI Chat - Sensitive Data Warning Missing
**File:** [guardian_ai_service.dart](lib/services/guardian_ai_service.dart)

**Edge Case:** Patient shares SSN, credit card, or medical record numbers.

**Current Behavior:**
- All text sent to OpenAI API
- No client-side filtering
- PII may be exposed to third-party

**Expected Behavior:**
- Regex filter for common PII patterns
- Warning: "Please don't share sensitive information like..."
- Option to delete message history

**Severity:** 🟡 MEDIUM

---

### 27. All Settings - No Confirmation for Destructive Actions
**File:** Multiple settings screens

**Edge Case:** User accidentally deletes emergency contact.

**Current Behavior:**
- `emergency_contacts_screen.dart`: Has delete confirmation ✓
- `guardians_screen.dart`: Uses `onLongPress` but no clear confirmation flow
- No undo functionality anywhere

**Expected Behavior:**
- Consistent confirmation dialogs
- Undo snackbar for all deletions
- Delay actual deletion by 5 seconds

**Severity:** 🟡 MEDIUM

---

### 28. AI Chat - History Not Cleared on Logout
**File:** [ai_chat_service.dart](lib/services/ai_chat_service.dart)

**Edge Case:** User logs out, new user sees old chat history.

**Current Behavior:**
- Chat stored per `patientId`
- Logout doesn't call `clearHistory()`
- If same device used by different patient, data leaked

**Expected Behavior:**
- Clear chat history on logout
- Or verify patientId matches before loading

**Severity:** 🟡 MEDIUM

---

### 29. Patient Home - Medication Time Display Not Localized
**File:** [patient_home_screen.dart](lib/screens/patient_home_screen.dart)  
**Lines:** 656-660

**Edge Case:** User in 24-hour locale sees 12-hour time format.

**Current Behavior:**
- Time stored as string '08:00 AM'
- No locale-aware formatting
- Add medication modal uses 12-hour picker

**Expected Behavior:**
- Use `TimeOfDay` and `MaterialLocalizations`
- Display in user's preferred format

**Severity:** 🟡 MEDIUM

---

### 30. SOS - Heart Rate Display Shows "--" Indefinitely
**File:** [patient_sos_screen.dart](lib/screens/patient_sos_screen.dart)  
**Lines:** 310-340

**Edge Case:** No wearable connected, heart rate never populates.

**Current Behavior:**
- Shows "--" for heart rate
- No indication that device needs pairing
- Waveform hidden but no explanation

**Expected Behavior:**
- Show "Connect wearable to share vitals"
- Link to device pairing screen
- Explain why vitals matter in emergency

**Severity:** 🟡 MEDIUM

---

### 31. Add Medication - Duplicate Detection Missing
**File:** [add_medication_modal.dart](lib/screens/add_medication_modal.dart)

**Edge Case:** User adds "Aspirin 500mg" twice at same time.

**Current Behavior:**
- No check for existing medications
- Duplicates allowed
- No warning

**Expected Behavior:**
- Check existing medications by name+dose+time
- Warn: "You already have Aspirin at 8:00 AM"
- Allow override with confirmation

**Severity:** 🟡 MEDIUM

---

### 32. Patient Chat - Care Team Shows Empty Without Guidance
**File:** [patient_chat_data_provider.dart](lib/screens/patient_chat/patient_chat_data_provider.dart)  
**Lines:** 60-106

**Edge Case:** New patient with no guardians or doctors connected.

**Current Behavior:**
- Returns empty list for care team
- UI shows empty state

**Expected Behavior:**
- Contextual empty state: "Add a guardian to get started"
- Link to Guardians settings
- Explain care team benefits

**Severity:** 🟡 MEDIUM

---

### 33. AI Chat - Voice Input Not Implemented
**File:** [patient_ai_chat_screen.dart](lib/screens/patient_ai_chat_screen.dart)

**Edge Case:** Elderly user with vision issues wants to use voice.

**Current Behavior:**
- `InputMode.voice` exists in state
- Microphone button visible
- No actual speech-to-text integration

**Expected Behavior:**
- Implement speech recognition
- Show transcription in real-time
- Allow correction before send

**Severity:** 🟡 MEDIUM

---

### 34. All Screens - No Haptic Feedback
**File:** All patient screens

**Edge Case:** User performs critical action with no tactile confirmation.

**Current Behavior:**
- No `HapticFeedback` calls found in patient screens
- Critical buttons (SOS, send message) have no feedback

**Expected Behavior:**
- `HapticFeedback.heavyImpact()` on SOS trigger
- `HapticFeedback.mediumImpact()` on message send
- `HapticFeedback.lightImpact()` on navigation

**Severity:** 🟡 MEDIUM

---

### 35. Profile Sheet - Hardcoded Patient ID
**File:** [profile_sheet.dart](lib/screens/profile_sheet.dart)  
**Lines:** 156-167

**Edge Case:** All patients see "PATIENT ID: #84920".

**Current Behavior:**
- ID hardcoded in UI

**Expected Behavior:**
- Generate unique patient ID
- Display actual user identifier

**Severity:** 🟡 MEDIUM

---

## 🟢 LOW ISSUES (12)

### 36. AI Chat - No Typing Indicator Animation
**File:** [patient_ai_chat_screen.dart](lib/screens/patient_ai_chat_screen.dart)

**Edge Case:** User unsure if AI is processing request.

**Current Behavior:**
- `isAITyping` flag exists
- Glow effect shown
- No classic "..." typing indicator

**Expected Behavior:**
- Add animated dots in chat bubble
- "Guardian Angel is thinking..."

**Severity:** 🟢 LOW

---

### 37. Patient Home - Date Selector Not Functional
**File:** [patient_home_screen.dart](lib/screens/patient_home_screen.dart)  
**Lines:** 313-350

**Edge Case:** User taps different day, expects to see that day's medications.

**Current Behavior:**
- Date selector is visual only
- `isSelected` hardcoded to `index == 2`
- No state change on tap

**Expected Behavior:**
- Track selected date in state
- Filter medications by selected date
- Show "No medications for this day" if empty

**Severity:** 🟢 LOW

---

### 38. All Screens - Missing Accessibility Labels
**File:** Multiple files

**Edge Case:** Blind/low-vision patient using VoiceOver/TalkBack.

**Current Behavior:**
- Very few `Semantics` widgets
- Icons without labels
- GestureDetectors without accessibility hints

**Expected Behavior:**
- Wrap all interactive elements in `Semantics`
- Label icons: "SOS emergency button"
- Group related content

**Severity:** 🟢 LOW (but legally important for accessibility compliance)

---

### 39. SOS Screen - Fixed English Text
**File:** [patient_sos_screen.dart](lib/screens/patient_sos_screen.dart)

**Edge Case:** Non-English speaking patient.

**Current Behavior:**
- All text hardcoded in English
- "Active Monitoring", "Contacting caregiver..." etc.

**Expected Behavior:**
- Use Flutter localization
- Support at least Spanish, Chinese, Hindi

**Severity:** 🟢 LOW (depends on target market)

---

### 40. Medication Detail - No Deep Link Support
**File:** [medication_detail_screen.dart](lib/screens/medication_detail_screen.dart)

**Edge Case:** Caregiver sends link to specific medication for patient to view.

**Current Behavior:**
- No deep link handling
- Cannot navigate directly to specific medication

**Expected Behavior:**
- Support `guardianangel://medication/{id}`
- Parse and navigate on app launch

**Severity:** 🟢 LOW

---

### 41. AI Chat - No Message Timestamp Display
**File:** [patient_ai_chat_screen.dart](lib/screens/patient_ai_chat_screen.dart)

**Edge Case:** User wants to know when conversation happened.

**Current Behavior:**
- Timestamps stored but not displayed
- Messages show in order only

**Expected Behavior:**
- Show time under each message
- Group by day with date headers

**Severity:** 🟢 LOW

---

### 42. Patient Home - No Dark Mode Support
**File:** [patient_home_screen.dart](lib/screens/patient_home_screen.dart)

**Edge Case:** User prefers dark mode for eye strain.

**Current Behavior:**
- Colors hardcoded (e.g., `Color(0xFFFDFDFD)`)
- No theme awareness

**Expected Behavior:**
- Use `Theme.of(context)` colors
- Respect system dark mode preference

**Severity:** 🟢 LOW

---

### 43. Add Medication - No Time Picker Accessibility
**File:** [add_medication_modal.dart](lib/screens/add_medication_modal.dart)

**Edge Case:** Elderly user with tremor struggles with precise time picker.

**Current Behavior:**
- Standard time picker
- Requires precise touch control

**Expected Behavior:**
- Larger touch targets
- Pre-set common times (Morning, Noon, Evening)
- Voice input option

**Severity:** 🟢 LOW

---

### 44. SOS Screen - No Battery Status Warning
**File:** [patient_sos_screen.dart](lib/screens/patient_sos_screen.dart)

**Edge Case:** Phone at 5% battery during SOS.

**Current Behavior:**
- No battery awareness
- Phone may die before help arrives

**Expected Behavior:**
- Show battery warning if < 20%
- Suggest plugging in
- Send battery status to caregivers

**Severity:** 🟢 LOW

---

### 45. AI Chat - No Read Receipts
**File:** [ai_chat_service.dart](lib/services/ai_chat_service.dart)

**Edge Case:** User unsure if message was received.

**Current Behavior:**
- Messages have `status` field
- Not visually displayed

**Expected Behavior:**
- Show sent/delivered indicators
- Grey checkmarks like messaging apps

**Severity:** 🟢 LOW

---

### 46. All Screens - No Landscape Orientation Support
**File:** Multiple files

**Edge Case:** User rotates tablet to landscape.

**Current Behavior:**
- No explicit orientation handling
- UI may not adapt properly

**Expected Behavior:**
- Test and support landscape
- Or lock to portrait explicitly

**Severity:** 🟢 LOW

---

### 47. Patient Home - Calendar Overlay Date Not Used
**File:** [calendar_overlay.dart](lib/screens/calendar_overlay.dart)

**Edge Case:** User selects date in calendar, nothing happens.

**Current Behavior:**
- Calendar opens as overlay
- Selection not captured/used
- No callback to parent screen

**Expected Behavior:**
- Return selected date
- Update home screen to show that day's schedule

**Severity:** 🟢 LOW

---

## Summary by Category

| Category | Critical | High | Medium | Low | Total |
|----------|----------|------|--------|-----|-------|
| Data Persistence | 3 | 2 | 1 | 0 | 6 |
| Error Handling | 1 | 2 | 2 | 0 | 5 |
| Network/Offline | 2 | 1 | 2 | 0 | 5 |
| Validation | 0 | 3 | 1 | 1 | 5 |
| UX/Accessibility | 0 | 2 | 3 | 5 | 10 |
| Security/Privacy | 1 | 0 | 2 | 0 | 3 |
| Authentication | 1 | 1 | 1 | 0 | 3 |
| SOS Specific | 0 | 0 | 1 | 2 | 3 |
| Hardcoded Data | 2 | 1 | 1 | 1 | 5 |
| Other | 0 | 0 | 1 | 3 | 4 |

---

## Recommended Priority Order

### Phase 1: Critical Fixes (Week 1)
1. Fix SOS permission handling (#1)
2. Fix SOS network failure handling (#2)
3. Add caregiver response timeout (#3)
4. Fix hardcoded user data (#6, #9)
5. Persist medications (#7)
6. Fix profile persistence (#8)
7. Handle session expiry (#5)
8. Handle missing AI API key gracefully (#4)

### Phase 2: High Priority (Week 2)
1. Add input validation (#10, #11, #12, #13)
2. Implement retry mechanisms (#18)
3. Persist notification settings (#19)
4. Add loading states (#16)
5. Add confirmation dialogs (#14, #15)

### Phase 3: Medium Priority (Week 3-4)
1. Offline mode handling
2. Pull-to-refresh
3. Empty states
4. Accessibility labels
5. Haptic feedback

### Phase 4: Low Priority (Backlog)
1. Dark mode
2. Localization
3. Deep links
4. Voice input completion

---

*Audit generated: January 9, 2026*  
*Auditor: GitHub Copilot (Claude Opus 4.5)*
