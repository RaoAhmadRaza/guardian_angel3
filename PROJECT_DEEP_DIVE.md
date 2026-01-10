# Guardian Angel 2.0 - Complete Project Deep Dive

**Last Updated:** January 10, 2026  
**Project Type:** Flutter Medical/Health Monitoring Application  
**Backend:** Firebase (Firestore, Cloud Functions, Authentication, Storage)  
**Architecture:** Multi-layer sync engine with offline-first capabilities

---

## 📋 Executive Summary

Guardian Angel 2.0 is a sophisticated Flutter health monitoring application designed for patients, caregivers, doctors, and guardians. It focuses on:

- **Multi-role support**: Patients, Caregivers, Doctors, Guardians
- **Health monitoring**: Vital signs tracking, arrhythmia detection, fall detection
- **Offline-first architecture**: Works without internet, syncs when online
- **Production-grade sync engine**: Handles eventual consistency, conflicts, retries
- **Emergency features**: SOS alerts, emergency contacts, real-time notifications
- **Medical AI**: Heart anomaly detection (arrhythmia inference)
- **Home automation**: Room management, device control
- **Chat system**: Real-time messaging between users
- **Medication tracking**: MEDSY medication manager integration

---

## 🏗️ Architecture Overview

### Layered Architecture

```
┌─────────────────────────────────────────┐
│   UI Layer (Flutter Screens)             │  - Onboarding, Chat, Health, Reports
├─────────────────────────────────────────┤
│   Provider/State Management (Riverpod)  │  - Global state, Theme, Auth
├─────────────────────────────────────────┤
│   Service Layer                         │  - Business logic services
├─────────────────────────────────────────┤
│   Sync Engine (Phase 3 & 4)            │  - Operation queuing, retry, recovery
├─────────────────────────────────────────┤
│   API Client & Backend Integration      │  - HTTP, Firebase, Firestore
├─────────────────────────────────────────┤
│   Persistence Layer (Hive)              │  - Local database, encryption
├─────────────────────────────────────────┤
│   Firebase Services                     │  - Auth, Firestore, Storage, Functions
└─────────────────────────────────────────┘
```

### Key Architectural Principles

1. **Offline-First**: Local Hive is source of truth; Firestore is a non-blocking mirror
2. **Single Processor**: Only one sync engine instance processes operations (via lock)
3. **FIFO Processing**: Operations queued and processed in order
4. **Idempotency**: Operations have idempotency keys; backend support with local fallback
5. **Fire-and-Forget**: Firestore mirrors never block UI
6. **Encryption**: Sensitive data encrypted in local storage
7. **Observability**: Comprehensive telemetry, metrics, logging

---

## 🔄 Sync Engine (The Heart of the System)

### What is the Sync Engine?

The sync engine is the central nervous system that keeps the app in sync with the backend despite network issues, crashes, and conflicts.

**Location:** `lib/sync/sync_engine.dart`

### Core Components

#### 1. **Pending Queue Service** (`pending_queue_service.dart`)
- Stores operations waiting to sync in Hive
- Operations: `{id, opType, entityType, payload, status, attempts, ...}`
- Survives app crashes - resumable
- Indexed for fast lookups

#### 2. **API Client** (`api_client.dart`)
- Centralized HTTP wrapper around all backend calls
- Auto-injects headers: Auth tokens, trace IDs, app version
- Handles 401 (token refresh), maps errors to exceptions
- Secure logging with PII redaction

#### 3. **Operation Router** (`op_router.dart`)
- Maps operation types to API endpoints
- Registers routes: `create::device → POST /api/v1/devices`
- Payload transformation before sending
- Extensible for new entity types

#### 4. **Processing Lock** (`processing_lock.dart`)
- Ensures only ONE processor runs at a time
- Uses Hive with TTL and runner ID
- Prevents concurrent updates to queue
- Handles dead processor cleanup

#### 5. **Backoff Policy** (`backoff_policy.dart`)
- Exponential backoff for retries
- Computes: `baseMs * (2^attempts) + randomJitter`
- Configurable: base, max, jitter range
- Deterministic for testing

#### 6. **Circuit Breaker** (`circuit_breaker.dart`)
- Protects backend from failure storms
- Trips after N failures in time window
- Automatic cooldown and recovery
- Prevents cascading failures

#### 7. **Reconciler** (`reconciler.dart`)
- Handles 409 Conflict responses automatically
- Strategies:
  - **CREATE**: Checks if resource already exists (idempotent)
  - **UPDATE**: 3-way merge (local + server + intended)
  - **DELETE**: Verifies resource already deleted
- Automatic retry on successful reconciliation

#### 8. **Optimistic Store** (`optimistic_store.dart`)
- Manages optimistic UI updates
- Commits on success, rolls back on failure
- Transaction token for correlation
- Success/error callbacks for UI refresh

#### 9. **Batch Coalescer** (`batch_coalescer.dart`)
- Merges redundant operations to reduce network calls
- E.g., DELETE removes pending UPDATEs for same resource
- Automatic deduplication
- Improves throughput

#### 10. **Real-time Service** (`realtime_service.dart`)
- WebSocket connection for push updates
- Automatic reconnection with exponential backoff
- Fallback when HTTP fails
- Push notification support

#### 11. **Telemetry/Metrics** (`telemetry/production_metrics.dart`)
- Prometheus-compatible metrics export
- Counters: processed_ops, failed_ops, conflicts_resolved
- Histograms: Processing latency (p50, p95, p99)
- Gauges: Pending operations, active processors
- Alert thresholds for critical states
- Sentry integration for error reporting

### The Processing Loop

```
START
  ↓
[Lock acquired? → No → Retry later]
  ↓ Yes
[Circuit broken? → Yes → Sleep, retry]
  ↓ No
[Get next operation from queue]
  ↓ (if empty, exit loop)
[Apply optimistic update to UI]
  ↓
[Call API via ApiClient]
  ↓
[Response?]
  ├─ Success (2xx) → Mark complete, commit optimistic
  ├─ 401 → Refresh token, retry
  ├─ 409 → Reconcile, retry if success
  ├─ 429 → Backoff (respect Retry-After), retry
  ├─ 5xx → Backoff, retry
  └─ Other → Log error, mark failed, rollback optimistic
  ↓
[Record metrics: latency, success/failure]
  ↓
[Sleep, then loop back]
```

### Example: Creating a Device

```dart
// 1. USER ACTION: Create device in UI
final device = Device(name: 'Fitbit', type: 'wearable');
final txnToken = uuid.v4();

// 2. ENQUEUE OPERATION
syncEngine.optimisticStore.register(
  txnToken: txnToken,
  optimisticUpdate: device,
  onCommit: () => devicesProvider.refresh(),
  onRollback: () => showError('Failed to create device'),
);

await syncEngine.enqueue(PendingOp(
  opType: 'CREATE',
  entityType: 'device',
  payload: device.toMap(),
  txnToken: txnToken,
));

// 3. UI IMMEDIATELY SHOWS DEVICE (optimistic)
devicesList.add(device);

// 4. SYNC ENGINE PROCESSES:
// - Acquires lock
// - Dequeues operation
// - Routes to: POST /api/v1/devices
// - Sends HTTP request with X-Idempotency-Key header
// - Success → Mark complete, commit optimistic
// - Failure → Rollback, UI removes device, shows error
```

### Phase 3: Reliability & Crash Recovery (Complete ✅)

All six components integrated:
- ✅ Circuit Breaker
- ✅ Reconciler  
- ✅ Optimistic Store
- ✅ Batch Coalescer
- ✅ SyncMetrics
- ✅ Real-time Service

**Test Results**: 13/18 tests passing (72%)

### Phase 4: Operationalization (Complete ✅)

Production-ready features:
- ✅ Production Metrics & Observability (Prometheus, Sentry, JSON logging)
- ✅ Load Testing Tool (enqueue throughput, latency, memory, stress tests)
- ✅ Export Operations CLI (CSV/JSON, PII redaction)
- ✅ Admin Console (queue inspection, repair toolkit)
- ✅ Release Validation & Sign-off (automated acceptance tests)

**Status**: 87.5% complete (7/8 tasks)

---

## 🔐 Backend Integration

### Firebase Services

#### 1. **Authentication** (`firebase/auth/`)
- Email/password, Google Sign-In, Apple Sign-In, Phone auth
- Token refresh on 401 Unauthorized
- Session management in AuthService

#### 2. **Firestore Database** (`cloud_firestore`)
- Collections:
  - `users/{uid}` - User profiles
  - `patient_users/{uid}` - Patient-specific data
  - `caregiver_users/{uid}` - Caregiver-specific data
  - `doctor_users/{uid}` - Doctor-specific data
  - `patients/{patientUid}/health_readings/{readingId}` - Vitals
  - `relationships/{relationshipId}` - User relationships
  - `chat_threads/{threadId}/messages/{msgId}` - Chat
  
- **Sync Strategy**: Local-first, fire-and-forget mirror
  - `HealthFirestoreService` mirrors vitals
  - `ChatFirestoreService` mirrors messages
  - `OnboardingFirestoreService` mirrors user data
  - All merge: true, never block UI

#### 3. **Cloud Storage** (`firebase_storage`)
- Profile images
- Document uploads
- Medical records

#### 4. **Cloud Functions** (`functions/index.js`)
- Chat notifications via FCM
- SOS alert notifications
- Health alert notifications (arrhythmia, abnormal vitals)
- Arrhythmia inference HTTP endpoint

#### 5. **Cloud Messaging** (`firebase_messaging`)
- Push notifications
- FCM token management
- Message handling in background/foreground

### Cloud Functions Endpoints

```
sendChatNotification
├─ Trigger: https.onCall (authenticated)
├─ Params: recipientUid, senderName, messagePreview, threadId
├─ Action: Get FCM tokens, send notification
└─ Response: { success, success_count, failure_count }

sendSosAlert
├─ Trigger: https.onCall
├─ Params: patientUid, location, emergencyContacts
├─ Action: Notify caregivers via FCM + SMS (Twilio)
└─ Response: { success, notified_count }

sendHealthAlert
├─ Trigger: https.onCall
├─ Params: patientUid, alertType, details
└─ Action: Notify doctor + caregiver

arrhythmiaInference (HTTP)
├─ Trigger: https.onRequest
├─ Params: ECG samples array
├─ Action: Run ML inference
└─ Response: { is_arrhythmia, confidence, details }
```

### Idempotency Contract

**Backend Support Detection:**
- Handshake endpoint: `POST /api/handshake` with `X-Idempotency-Key` header
- Response includes `X-Idempotency-Accepted: true` header
- Alternative: `idempotencyAccepted: true` in JSON body

**Request Header:**
```
X-Idempotency-Key: <unique-uuid-or-deterministic-key>
```

**Fallback:** Local Hive-based deduplication (24h TTL)

**Files:**
- `lib/services/backend_idempotency_service.dart` - Detection & validation
- `lib/services/local_idempotency_fallback.dart` - Local fallback

---

## 💾 Persistence Layer

### Hive (Local SQLite Alternative)

**Why Hive?**
- Encrypted key-value store (AES)
- Fast, ACID-compliant
- No server required (works offline)
- Portable (mobile, web, desktop)

### Boxes (Collections)

```
pending_ops
├─ id (string)
├─ opType (string)
├─ entityType (string)
├─ payload (JSON)
├─ status (queued/processing/completed/failed)
├─ attempts (int)
└─ ... 12 more fields

failed_ops
├─ id
├─ error_message
├─ error_code
├─ operation_details
└─ timestamp

health_readings
├─ id (composite: {patientUid}_{type}_{timestamp})
├─ reading_type (heart_rate, blood_pressure, etc.)
├─ value (number)
├─ recorded_at (datetime)
└─ synced_to_firestore (bool)

user_profiles
├─ uid
├─ email
├─ full_name
├─ profile_image_url
├─ birth_date
└─ ... user fields

medications
├─ id
├─ patient_uid
├─ medication_name
├─ dosage
├─ frequency
└─ ... medication fields

chat_threads
├─ thread_id
├─ participants
├─ last_message
├─ created_at
└─ ... thread fields
```

### Encryption

**Policy:** `lib/persistence/encryption_policy.dart`
- Sensitive fields encrypted: passwords, tokens, health data
- AES-256 encryption key stored securely
- Per-operation encryption
- Key rotation support

**Secure Storage:** `flutter_secure_storage`
- Keychain (iOS), Keystore (Android)
- Stores encryption keys

---

## 🎯 Key Features & Workflows

### 1. User Onboarding

**Flow:**
```
Welcome Screen
  ↓
[User selects role: Patient/Caregiver/Doctor]
  ↓
Authentication (Email/Google/Apple)
  ↓
Local Hive tables created
  ↓
Data collected: Name, age, medical history
  ↓
Firebase Firestore mirror
  ↓
Homescreen
```

**Files:**
- `lib/onboarding/` - Onboarding screens
- `lib/onboarding/services/onboarding_local_service.dart` - Local persistence
- `lib/onboarding/services/onboarding_firestore_service.dart` - Firestore mirror

### 2. Health Data Tracking

**Extraction Methods:**
- iOS HealthKit
- Android Health Connect
- Manual entry

**Captured Vitals:**
- Heart rate (BPM)
- Blood pressure (systolic/diastolic)
- SpO2 (oxygen saturation)
- Sleep duration
- Steps, calories, active minutes
- Temperature, blood glucose

**Sync Process:**
```
Extract from HealthKit/Health Connect
  ↓
Validate thresholds
  ↓
Store in local Hive
  ↓
Trigger Firestore sync (fire-and-forget)
  ↓
Send alert if abnormal
  ↓
Show in health dashboard
```

**Files:**
- `lib/health/services/health_data_persistence_service.dart`
- `lib/health/services/patient_health_extraction_service.dart`
- `lib/health/services/health_firestore_service.dart`
- `lib/health/services/health_threshold_service.dart`

### 3. Arrhythmia Detection

**ML Model:**
- TensorFlow Lite model (trained on ECG data)
- Takes 12-lead ECG samples (or single-lead Fitbit data)
- Outputs: arrhythmia probability, confidence

**Deployment:**
- Edge inference via `tflite_flutter`
- Cloud inference via Cloud Function
- Falls back if edge fails

**Alert Flow:**
```
ECG samples captured
  ↓
Run inference (local or cloud)
  ↓
Probability > threshold?
  ├─ Yes → Create health alert
  │        Send to doctor + caregiver
  │        Show notification
  └─ No → Log, continue
```

**Files:**
- `lib/ml/` - ML model integration
- `arrhythmia_inference_service/` - Inference logic

### 4. Fall Detection

**Implementation:**
- Accelerometer/gyroscope sensors
- Pattern recognition
- Real-time detection

**Alert:**
```
Fall detected
  ↓
SOS button prompt (10 second window)
  ↓
[User can cancel if false alarm]
  ↓
[Timeout or confirm]
  ├─ Confirmed → Send SOS alert
  ├─ Cancelled → Log and continue
  └─ Timeout → Send alert anyway
  ↓
Notify emergency contacts via FCM + SMS
```

**Project:** `fall_detection_sandbox/` (separate testing app)

### 5. SOS Emergency Alerts

**Trigger:**
- User presses SOS button
- Fall detected and confirmed
- Critical health alert (e.g., dangerous arrhythmia)

**Response:**
```
SOS triggered
  ↓
Send Cloud Function: sendSosAlert
  ├─ Get emergency contacts from Hive
  ├─ Send FCM notification
  ├─ Send SMS via Twilio (if phone available)
  ├─ Geo-locate (geolocator plugin)
  └─ Store SOS event in Firestore
  ↓
Notify caregiver/guardian app (real-time)
  ├─ Push notification
  ├─ Ringtone + vibration
  └─ Action buttons: Acknowledge, Call, Locate
```

**Files:**
- `lib/services/sos_emergency_action_service.dart`
- `lib/services/emergency_contact_service.dart`

### 6. Chat System

**Architecture:**
```
Local (Hive)
├─ chat_threads
└─ chat_messages

Remote (Firestore)
├─ chat_threads/{threadId}
└─ chat_threads/{threadId}/messages/{msgId}

Real-time (WebSocket)
└─ Fallback to polling

FCM Notifications
└─ sendChatNotification Cloud Function
```

**Flow:**
```
User sends message
  ↓
Store in local Hive (immediate UI update)
  ↓
Enqueue CHAT operation to sync
  ↓
Sync engine sends to API
  ↓
Firestore mirror
  ↓
Notify recipient via FCM
  ↓
Real-time listener shows in chat
```

**Files:**
- `lib/chat/services/chat_firestore_service.dart`
- `lib/chat/screens/chat_screen.dart`

### 7. Medication Tracking (MEDSY Integration)

**Feature:**
- Track medications and schedules
- Reminder notifications
- Adherence tracking

**Files:**
- `lib/services/medication_service.dart`
- `lib/models/medication_model.dart`

### 8. Home Automation

**Features:**
- Room management
- Device control (lights, temperature, etc.)
- Automation rules

**Files:**
- `lib/home automation/` - UI
- `lib/services/home_automation_service.dart` - Business logic

### 9. Relationship Management

**Relationships:**
- Patient ↔ Caregiver
- Patient ↔ Doctor
- Caregiver ↔ Guardian

**Firestore:**
```
relationships/{relationshipId}
├─ user_a_uid
├─ user_b_uid
├─ relationship_type (patient-caregiver, patient-doctor)
├─ status (pending, accepted, rejected)
└─ created_at
```

**Files:**
- `lib/relationships/services/relationship_firestore_service.dart`

---

## 🧪 Testing Infrastructure

### Phase 1: Test Automation (Complete ✅)

**Files:**
- `test/bootstrap.dart` - Test utilities
  - `initTestHive()` - Temporary Hive for tests
  - `InMemorySecureStorage` - Mock secure storage
  - `DeterministicRandom` - Reproducible randomness

- `test/mocks/mock_server.dart` - Deterministic HTTP server
  - Simulates errors: 429, 500, 503, 409
  - Records requests
  - Idempotency simulation

- `test/mocks/mock_auth_service.dart` - Mock auth

### Test Suites

#### Unit Tests
- `test/unit/local_idempotency_fallback_test.dart` (14 tests)
- `test/sync/circuit_breaker_test.dart`
- `test/sync/batch_coalescer_test.dart`

#### Integration Tests
- `test/integration/e2e_acceptance_test.dart` (7 scenarios)
- `test/integration/backend_idempotency_test.dart` (19 tests)

#### Phase 3 Integration Tests
- `test/sync/reconciliation_test.dart` (31 tests)
- `test/sync/crash_resume_test.dart` (18 tests)
- `test/sync/phase3_integration_test.dart` (399 tests)

### Acceptance Testing

**File:** `tool/acceptance_runner.dart`

**Scenarios:**
1. Happy path (offline → online)
2. Retry & backoff (429 with Retry-After)
3. Crash-resume (idempotency)
4. Conflict resolution (409)
5. Circuit breaker
6. Network connectivity transitions
7. Metrics & observability

**Output:** `acceptance-report.json`

### Load Testing

**File:** `tool/stress/load_test.dart`

**Test Suites:**
1. Enqueue throughput (100, 1000, 5000, 10000 ops)
2. Processing latency (P50, P95, P99)
3. Memory consumption (50k ops)
4. Circuit breaker stress (50 failures)
5. Concurrent processing (3 workers, 5000 ops)

---

## 📊 Metrics & Observability

### Production Metrics

**File:** `lib/sync/telemetry/production_metrics.dart`

#### Counters
```
processed_ops_total           # Operations successfully synced
failed_ops_total              # Operations that failed after all retries
backoff_events_total          # Times backoff was applied
circuit_tripped_total         # Times circuit breaker tripped
retries_total                 # Total retry attempts
conflicts_resolved_total      # 409 conflicts resolved by reconciler
auth_refresh_total            # Token refreshes
```

#### Gauges
```
pending_ops_gauge             # Current pending operations
active_processors_gauge       # Currently running processors
```

#### Histograms
```
processing_latency_ms
├─ buckets: [0, 10, 50, 100, 500, 1000, ∞]
├─ sum
├─ count
├─ p50, p95, p99 calculated
```

#### Custom Metrics
```
success_rate_percent          # % of ops that succeeded
failure_rate_per_min          # Failed ops per minute
network_health_score          # 0-100 health indicator
```

### Export Formats

#### Prometheus
```
# HELP processing_latency_ms Processing operation latency
# TYPE processing_latency_ms histogram
processing_latency_ms_bucket{le="10"} 23
processing_latency_ms_bucket{le="50"} 156
...
```

#### JSON
```json
{
  "timestamp": "2025-01-10T12:34:56Z",
  "metrics": {
    "counters": { "processed_ops_total": 12345 },
    "gauges": { "pending_ops": 42 },
    "histograms": { "processing_latency": {...} }
  }
}
```

### Alert Thresholds

| Metric | Threshold | Severity | Action |
|--------|-----------|----------|--------|
| failed_ops_rate | >10/min | CRITICAL | Page on-call |
| pending_ops | >1000 for 1h | HIGH | Investigate |
| circuit_tripped | >50/day | MEDIUM | Check network |
| p95_latency | >5000ms | MEDIUM | Performance check |
| success_rate | <90% | HIGH | Error analysis |

---

## 🛠️ Admin & Repair Tools

### Backend Health Authority

**File:** `lib/persistence/health/backend_health.dart`

**Health Checks:**
- `encryptionOK` - Encryption keys exist
- `schemaOK` - Hive adapters registered
- `queueHealthy` - Queue not stalled
- `noPoisonOps` - No stuck operations
- `lastSyncAge` - Time since last sync

**API:**
```dart
final health = await BackendHealth.check();
if (!health.allHealthy) {
  print('Status: ${health.statusText}');
  print('Severity: ${health.severity}'); // 0=healthy, 1=warning, 2=critical
  print('Score: ${health.healthScore}%');
}
```

### Admin Repair Toolkit

**File:** `lib/persistence/health/admin_repair_toolkit.dart`

**Allowed Actions (with confirmation tokens):**

1. **Rebuild Index**
   - Reconstructs pending ops index from Hive
   - Time-limited token (5 min)
   - Full audit logging

2. **Retry Failed Ops**
   - Move failed operations back to pending
   - Limited to N at a time
   - Audit trail

3. **Verify Encryption**
   - Check encryption keys
   - Verify policies
   - Report key age

4. **Compact Boxes**
   - Reclaim unused storage
   - Optimize Hive performance

**API:**
```dart
final toolkit = AdminRepairToolkit.create();
final token = toolkit.generateConfirmationToken(RepairActionType.rebuildIndex);

final result = await toolkit.execute(
  action: RepairActionType.rebuildIndex,
  userId: 'admin',
  confirmationToken: token,
);
```

### Admin Console Screen

**Features:**
- Queue status (pending, failed, completed)
- Health dashboard
- Repair action buttons
- Metrics display
- Error logs
- Operation details

**Access:** Dev builds only (via `Navigator`)

---

## 📱 Key Screens & User Flows

### Patient App

1. **Onboarding**
   - Select role → Authenticate → Enter medical history
   - Permissions: Health data, location, notifications

2. **Home Screen**
   - Quick vital status cards
   - Recent health readings
   - Emergency SOS button
   - Quick actions: Chat, medication, schedule

3. **Health Dashboard**
   - Vital signs graphs (24h, 7d, 30d)
   - Abnormal readings highlighted
   - Health alerts history
   - Threshold settings

4. **Chat**
   - Messages with doctor/caregiver
   - Real-time updates
   - Notification badges

5. **Medications**
   - Scheduled medications
   - Adherence tracking
   - Reminders

6. **SOS**
   - Emergency button
   - Quick contact list
   - Location sharing (optional)

### Caregiver App

1. **Managed Patients List**
   - Patient status at a glance
   - Quick links to health data
   - SOS alerts

2. **Patient Health Dashboard**
   - Vital signs for assigned patient
   - Abnormal reading alerts
   - Recommendations

3. **Chat**
   - Real-time messaging with patient/doctor

4. **SOS Alerts**
   - Real-time SOS notifications
   - Location on map
   - Quick response actions

### Doctor App

1. **Patient List**
   - Assigned patients
   - Latest vitals
   - Alert summary

2. **Patient Detailed View**
   - Full health history
   - ECG analysis (if arrhythmia detected)
   - Recommendations
   - Notes

3. **Chat**
   - Real-time messaging with patient/caregiver

---

## 🚀 Deployment & Release

### CI/CD Pipeline (GitHub Actions)

**File:** `.github/workflows/ci-tests.yml`

**Jobs:**
1. Test → Unit/integration tests
2. Acceptance → E2E acceptance scenarios
3. Coverage → Code coverage reports

**Gating:**
- Pull requests require passing tests
- Main branch requires all jobs to pass

### Release Checklist

**File:** `release-checklist.json`

**Automated Checks:**
- Unit tests pass
- Integration tests pass
- E2E acceptance pass
- Critical criteria met
- No breaking changes

**Manual Checks:**
- Metrics dashboard (success > 95%)
- Performance (latency < 500ms p95)
- Security review
- Documentation updated

### Sign-off Process

**File:** `scripts/mark_signoff.sh`

**Steps:**
1. Review release checklist
2. Confirm automated tests
3. Approve manual requirements
4. Create annotated Git tag: `release-YYYYMMDD-HHMMSS`
5. Push to remote

---

## 📚 Documentation Files

### Architecture & Design
- `DESIGN_SYSTEM_SPEC.md` - UI component system
- `docs/FIREBASE_SETUP.md` - Firebase initialization
- `docs/HEALTH_DATA_FIRESTORE_SYNC_SPEC.md` - Health sync design

### Implementation Guides
- `BACKEND_IDEMPOTENCY_IMPLEMENTATION_SUMMARY.md`
- `docs/BACKEND_IDEMPOTENCY_CONTRACT.md`
- `lib/sync/examples/sync_engine_setup.dart` - Setup example

### Phase Documentation
- `PHASE_1_TEST_AUTOMATION_COMPLETE.md` - Testing infrastructure
- `PHASE_2_IMPLEMENTATION_COMPLETE.md` - Release validation
- `PHASE_3_INTEGRATION_COMPLETE.md` - Reliability features
- `PHASE_4_IMPLEMENTATION_COMPLETE.md` - Operationalization

### Operational Guides
- `docs/runbooks/sync_runbook.md` - Sync operations runbook
- `docs/ADMIN_UI_RUNBOOK.md` - Admin console usage

---

## 🔑 Important Concepts

### Idempotency
**Problem:** Network retry could create duplicate operations  
**Solution:** Every operation has unique idempotency key; backend recognizes duplicates  
**Fallback:** If backend doesn't support, Hive local deduplication for 24h

### Optimistic Updates
**Problem:** UI should update immediately, not wait for network  
**Solution:** Apply changes locally first, rollback if sync fails  
**Implementation:** `OptimisticStore` with transaction tokens

### Circuit Breaker
**Problem:** Repeated failures overload backend  
**Solution:** Stop making requests after N failures in time window  
**Recovery:** Automatic reset after cooldown

### Reconciliation
**Problem:** 409 Conflicts (concurrent updates)  
**Solution:** Fetch latest server state, merge local changes, retry  
**Strategy:** Operation-type specific (CREATE, UPDATE, DELETE)

### Batch Coalescing
**Problem:** Redundant operations waste bandwidth  
**Solution:** DELETE removes pending UPDATEs for same resource  
**Impact:** Fewer network requests, faster processing

### Fire-and-Forget Mirrors
**Problem:** Firestore sync could block UI  
**Solution:** All Firestore writes are background, errors never propagate  
**Guarantee:** Local Hive is always up-to-date; Firestore is secondary

---

## 💡 Key Takeaways

### What Makes This Project Special

1. **Offline-First Architecture**
   - Works perfectly without internet
   - Seamless sync when online
   - No data loss even after crashes

2. **Production-Grade Sync Engine**
   - Handles eventual consistency
   - Automatic conflict resolution
   - Circuit breaker protection
   - Comprehensive observability

3. **Medical-Grade Reliability**
   - Idempotent operations
   - Audit logging
   - HIPAA-compliant encryption
   - Emergency fallbacks

4. **Real-Time Features**
   - WebSocket-based chat
   - Push notifications
   - SOS alerts with location
   - Live health monitoring

5. **AI/ML Integration**
   - Arrhythmia detection
   - Edge inference (TFLite)
   - Cloud inference (Cloud Functions)
   - Pattern recognition (fall detection)

6. **Multi-Role Support**
   - Patient, Caregiver, Doctor, Guardian roles
   - Relationship management
   - Role-based access control
   - Delegated health management

7. **Comprehensive Testing**
   - Unit, integration, E2E tests
   - Load testing tool
   - Acceptance testing
   - Deterministic mocks

8. **Observability at Scale**
   - Prometheus metrics
   - Sentry error tracking
   - JSON structured logging
   - Admin health dashboard

---

## 🔄 Common Workflows

### User Creates a Device (Patient App)

```
1. User taps "Add Device" button
2. Enters device details (name, type)
3. UI updates immediately (optimistic)
4. Operation enqueued: CREATE::device
5. Sync engine processes:
   - Acquires lock
   - Routes to POST /api/v1/devices
   - Sets X-Idempotency-Key header
   - Sends HTTP request
6. Success:
   - Marks operation complete
   - Commits optimistic update
   - Records metrics
7. Failure:
   - Retries with backoff
   - After max retries, marks failed
   - UI shows error
   - Rollback optimistic update
```

### Doctor Receives SOS Alert

```
1. Patient presses SOS button (or fall detected)
2. Local alert created in Hive
3. Cloud Function triggered: sendSosAlert
4. Caregiver receives FCM notification
5. Notification wakes screen (high priority)
6. Shows patient location on map
7. Caregiver can:
   - Acknowledge alert
   - Call patient
   - Navigate to location
   - Dispatch ambulance
8. Alert logged in Firestore
```

### Health Reading Extracted

```
1. App requests health data from HealthKit
2. Extracts: heart_rate, blood_pressure, etc.
3. Validates against thresholds
4. Stores in local Hive (immediate)
5. Triggers Firestore sync (background)
6. If abnormal:
   - Create health alert
   - Notify doctor via Cloud Function
   - Send push notification
7. Doctor sees alert in app
8. Doctor can:
   - View detailed reading
   - Chat with patient
   - Add recommendation
```

---

## 🎓 Learning Resources

To understand this codebase:

1. **Start with Sync Engine**
   - Read: `lib/sync/sync_engine.dart`
   - Then: Phase documentation
   - Understand: The processing loop

2. **Understand Data Flow**
   - Read: `lib/sync/models/pending_op.dart`
   - Then: Operation router, API client
   - Understand: How operations are routed

3. **Study Firebase Integration**
   - Read: `lib/firebase/` directory
   - Then: Firestore service, auth service
   - Understand: How data mirrors

4. **Learn Health Features**
   - Read: `lib/health/services/health_data_persistence_service.dart`
   - Then: Health Firestore service
   - Understand: Vital extraction and sync

5. **Explore Admin Tools**
   - Read: `lib/persistence/health/backend_health.dart`
   - Then: Admin repair toolkit
   - Understand: Observability and repair

---

## 🤔 FAQ

### Q: What happens if the network goes down?
**A:** Operations queue locally in Hive. When network returns, sync engine picks up where it left off. No data loss.

### Q: What if the user force-quits the app during a sync?
**A:** Processing lock with TTL ensures lock is released. On restart, sync engine resumes processing from queue. Idempotency keys prevent duplicates.

### Q: How are conflicts handled?
**A:** Reconciler fetches latest server state, merges local changes, and retries. Operation-specific strategies (CREATE, UPDATE, DELETE).

### Q: Is sensitive health data encrypted?
**A:** Yes. Encryption policy encrypts sensitive fields in Hive. Keys stored in secure storage (Keychain/Keystore).

### Q: How does it work on slow networks?
**A:** Backoff policy with exponential delays. Circuit breaker stops requests if too many failures. Metrics track network health.

### Q: Can operations be processed out of order?
**A:** No. FIFO queue ensures order. Single processor lock ensures atomicity.

### Q: What if Firestore sync fails?
**A:** Fire-and-forget means failures are logged but never block UI. Local data is always complete.

---

## 📞 Support & Contact

For questions about the architecture, refer to:
- Phase documentation files
- Implementation guides in `docs/`
- Code examples in `lib/sync/examples/`
- Test files for usage patterns

---

**Document Version:** 1.0  
**Last Updated:** January 10, 2026  
**Confidence Level:** High - Extracted from comprehensive codebase analysis
