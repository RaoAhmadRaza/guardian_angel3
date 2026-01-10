# Backend Architecture & Cloud Infrastructure

**Document:** Detailed backend and Firebase setup  
**Date:** January 10, 2026

---

## 🏢 Backend Infrastructure Overview

### Cloud Provider: Firebase/Google Cloud

**Project ID:** `guardian-angel-e5ad0`  
**Region:** Default (auto-scaled globally)

### Services Used

```
Firebase Authentication
├─ Email/Password
├─ Google Sign-In
├─ Apple Sign-In
└─ Phone Authentication

Cloud Firestore (NoSQL Database)
├─ Collections for users, health data, relationships
├─ Real-time listeners
├─ Security rules
└─ Offline persistence

Cloud Storage
├─ Profile images
├─ Medical documents
└─ User uploads

Cloud Functions (Serverless Backend)
├─ Chat notifications
├─ SOS alerts
├─ Health alerts
├─ Arrhythmia inference
└─ Triggered by HTTP, Firestore events, messaging

Cloud Messaging (Push Notifications)
├─ FCM token management
├─ Android notifications
├─ iOS APNs integration
└─ Web push

Google Cloud Logging
├─ Structured logs
├─ Error tracking
└─ Performance monitoring
```

---

## 🔑 Firebase Authentication

### Configuration

**File:** `lib/firebase/firebase_options.dart`

**Credentials per Platform:**

#### Web
```dart
apiKey: 'AIzaSyD9J5Ba_hDesTusIzs798qrrv6T9eGYbWc'
appId: '1:949637696820:web:b6dc4434b12e7852436961'
projectId: 'guardian-angel-e5ad0'
authDomain: 'guardian-angel-e5ad0.firebaseapp.com'
storageBucket: 'guardian-angel-e5ad0.firebasestorage.app'
```

#### Android
```dart
apiKey: 'AIzaSyB3vQg219902F3ZV6b8KRuQ0m9FUJ6uiyQ'
appId: '1:949637696820:android:cf7eefbd933b6c48436961'
projectId: 'guardian-angel-e5ad0'
storageBucket: 'guardian-angel-e5ad0.firebasestorage.app'
```

#### iOS / macOS
```dart
apiKey: 'AIzaSyBA9-fAD_xzTV8PhzY7mV8o5OLBCYoDi_Q'
appId: '1:949637696820:ios:0f5e2e338bf27ddd436961'
projectId: 'guardian-angel-e5ad0'
storageBucket: 'guardian-angel-e5ad0.firebasestorage.app'
iosClientId: 'PLACEHOLDER-IOS-CLIENT-ID'
iosBundleId: 'com.guardianangel.guardianAngelFyp'
```

### Auth Providers

**File:** `lib/firebase/auth/`

#### Google Sign-In
```dart
GoogleAuthProvider
├─ Web OAuth 2.0 credentials
├─ Android OAuth credentials
├─ iOS OAuth credentials
└─ Scopes: profile, email
```

#### Apple Sign-In
```dart
AppleAuthProvider
├─ Requires Apple Developer account
├─ Team ID configuration
├─ Key ID from Apple
└─ Private key for token validation
```

#### Email/Password
```dart
Email/PasswordProvider
├─ Built-in Firebase auth
├─ Password reset via email
├─ Email verification
└─ Custom claims for roles
```

### Token Management

**File:** `lib/sync/auth_service.dart`

```dart
class AuthService {
  // Get valid access token (refresh if needed)
  Future<String?> getAccessToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    
    try {
      final tokenResult = await user.getIdTokenResult(true);
      return tokenResult.token;
    } catch (e) {
      return null; // Return null instead of throwing
    }
  }
  
  // Refresh token (called on 401)
  Future<void> refreshToken() async {
    try {
      await FirebaseAuth.instance.currentUser?.getIdTokenResult(true);
    } catch (e) {
      // Re-throw to signal failed refresh
      rethrow;
    }
  }
}
```

---

## 📊 Firestore Database Structure

### Collections & Schema

#### 1. `users/{uid}` - Universal user data

```json
{
  "uid": "user123",
  "email": "patient@example.com",
  "full_name": "John Doe",
  "role": "patient",  // or caregiver, doctor
  "profile_image_url": "gs://...",
  "birth_date": "1990-01-15",
  "created_at": Timestamp,
  "updated_at": Timestamp,
  "phone_number": "+1234567890",
  "address": "123 Main St",
  "emergency_contacts": ["contact1_uid", "contact2_uid"]
}
```

#### 2. `patient_users/{uid}` - Patient-specific data

```json
{
  "uid": "patient123",
  "medical_history": ["diabetes", "hypertension"],
  "allergies": ["penicillin"],
  "current_medications": ["metformin", "lisinopril"],
  "blood_type": "O+",
  "assigned_doctor": "doctor123",
  "assigned_caregivers": ["caregiver1", "caregiver2"],
  "health_thresholds": {
    "heart_rate_high": 120,
    "heart_rate_low": 40,
    "blood_pressure_high": "180/110",
    "blood_pressure_low": "90/60"
  }
}
```

#### 3. `caregiver_users/{uid}` - Caregiver data

```json
{
  "uid": "caregiver123",
  "organization": "Home Care Plus",
  "license_number": "LIC123456",
  "assigned_patients": ["patient1", "patient2"],
  "contact_number": "+1234567890",
  "availability": "24/7"
}
```

#### 4. `doctor_users/{uid}` - Doctor data

```json
{
  "uid": "doctor123",
  "medical_license": "MD123456",
  "specialization": "Cardiology",
  "clinic_name": "Heart Health Clinic",
  "assigned_patients": ["patient1", "patient2"],
  "availability": {
    "monday": ["09:00-17:00"],
    "tuesday": ["09:00-17:00"]
  }
}
```

#### 5. `patients/{patientUid}/health_readings/{readingId}` - Vitals

```json
{
  "id": "patient123_heart_rate_2025-01-10T10:30:00Z",
  "patient_uid": "patient123",
  "reading_type": "heart_rate",  // or blood_pressure, spo2, sleep, etc.
  "value": 85,
  "unit": "BPM",
  "recorded_at": Timestamp,
  "source": "apple_health",  // or health_connect, manual, wearable
  "is_abnormal": false,
  "abnormality_details": null,
  "synced_at": Timestamp
}
```

**Composite ID Logic:**
```dart
// Format: {patientUid}_{readingType}_{ISO8601TimestampUTC}
final id = "${patientUid}_${type.name}_${timestamp.toIso8601String()}";
```

#### 6. `relationships/{relationshipId}` - User relationships

```json
{
  "id": "rel123",
  "user_a_uid": "patient123",
  "user_b_uid": "caregiver456",
  "relationship_type": "patient-caregiver",  // or patient-doctor
  "status": "accepted",  // or pending, rejected
  "created_at": Timestamp,
  "accepted_at": Timestamp,
  "permissions": ["view_health", "contact"]
}
```

#### 7. `chat_threads/{threadId}` - Chat metadata

```json
{
  "id": "thread123",
  "participants": ["patient123", "doctor456"],
  "created_at": Timestamp,
  "last_message_at": Timestamp,
  "last_message_preview": "How are you feeling?",
  "unread_count": {
    "patient123": 0,
    "doctor456": 1
  }
}
```

#### 8. `chat_threads/{threadId}/messages/{messageId}` - Chat messages

```json
{
  "id": "msg123",
  "thread_id": "thread123",
  "sender_uid": "doctor456",
  "content": "How are you feeling today?",
  "timestamp": Timestamp,
  "read": false,
  "read_at": null,
  "attachments": []  // URLs to images, files
}
```

#### 9. `health_alerts/{alertId}` - Health alert history

```json
{
  "id": "alert123",
  "patient_uid": "patient123",
  "alert_type": "arrhythmia",  // or abnormal_vitals, fall_detected
  "severity": "critical",  // or high, medium, low
  "message": "Possible arrhythmia detected",
  "reading_id": "patient123_ecg_2025-01-10T10:30:00Z",
  "created_at": Timestamp,
  "notified_doctor": true,
  "notified_caregiver": true,
  "acknowledged": false,
  "acknowledged_by": null,
  "acknowledged_at": null
}
```

#### 10. `sos_alerts/{sosId}` - SOS event log

```json
{
  "id": "sos123",
  "patient_uid": "patient123",
  "triggered_at": Timestamp,
  "trigger_reason": "manual",  // or fall_detected
  "location": {
    "latitude": 40.7128,
    "longitude": -74.0060,
    "address": "123 Main St, New York"
  },
  "notified_contacts": ["contact1", "contact2"],
  "response_status": "acknowledged",  // or pending, responded
  "acknowledged_by": "caregiver456",
  "acknowledged_at": Timestamp
}
```

---

## 🔐 Firestore Security Rules

### Location: Firebase Console → Firestore → Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ════════════════════════════════════════════════════════════════════════
    // AUTHENTICATION HELPERS
    // ════════════════════════════════════════════════════════════════════════
    
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isOwner(uid) {
      return request.auth.uid == uid;
    }
    
    function hasRole(role) {
      return get(/databases/$(database)/documents/users/$(request.auth.uid))
        .data.role == role;
    }
    
    // ════════════════════════════════════════════════════════════════════════
    // USERS COLLECTION
    // ════════════════════════════════════════════════════════════════════════
    
    match /users/{uid} {
      // Own profile: read/write
      allow read, write: if isOwner(uid);
      
      // Doctor/caregiver can read patient profile if relationship exists
      allow read: if exists(/databases/$(database)/documents/relationships/{relationshipId}
        where relationshipId != uid
        && (resource.data.user_a_uid == request.auth.uid || 
            resource.data.user_b_uid == request.auth.uid));
      
      match /health_readings/{readingId} {
        // Patient: own readings
        allow read, write: if isOwner(uid);
        
        // Doctor/caregiver: read if relationship exists
        allow read: if exists(/databases/$(database)/documents/relationships/{relationshipId}
          where (resource.data.user_a_uid == uid && 
                 resource.data.user_b_uid == request.auth.uid) ||
                (resource.data.user_b_uid == uid && 
                 resource.data.user_a_uid == request.auth.uid));
      }
    }
    
    // ════════════════════════════════════════════════════════════════════════
    // CHAT THREADS
    // ════════════════════════════════════════════════════════════════════════
    
    match /chat_threads/{threadId} {
      // Participant can read/write
      allow read, write: if request.auth.uid in resource.data.participants;
      
      match /messages/{messageId} {
        // Participant can read/write
        allow read, write: if request.auth.uid in 
          get(/databases/$(database)/documents/chat_threads/$(threadId))
            .data.participants;
      }
    }
    
    // ════════════════════════════════════════════════════════════════════════
    // RELATIONSHIPS
    // ════════════════════════════════════════════════════════════════════════
    
    match /relationships/{relationshipId} {
      // Either party can read
      allow read: if request.auth.uid == resource.data.user_a_uid ||
                     request.auth.uid == resource.data.user_b_uid;
      
      // Can only write if one party is self
      allow create: if request.auth.uid == request.resource.data.user_a_uid ||
                       request.auth.uid == request.resource.data.user_b_uid;
      
      // Can only update if one party is self
      allow update: if request.auth.uid == resource.data.user_a_uid ||
                       request.auth.uid == resource.data.user_b_uid;
    }
    
    // ════════════════════════════════════════════════════════════════════════
    // HEALTH ALERTS
    // ════════════════════════════════════════════════════════════════════════
    
    match /health_alerts/{alertId} {
      // Patient: read own alerts
      allow read: if request.auth.uid == resource.data.patient_uid;
      
      // Doctor/caregiver: read if relationship exists with patient
      allow read: if exists(/databases/$(database)/documents/relationships/{relationshipId}
        where (resource.data.user_a_uid == resource.data.patient_uid &&
               resource.data.user_b_uid == request.auth.uid) ||
              (resource.data.user_b_uid == resource.data.patient_uid &&
               resource.data.user_a_uid == request.auth.uid));
      
      // Only system/cloud functions can create
      allow create: if false;
    }
    
    // ════════════════════════════════════════════════════════════════════════
    // SOS ALERTS
    // ════════════════════════════════════════════════════════════════════════
    
    match /sos_alerts/{sosId} {
      // Patient: read/write own
      allow read, write: if request.auth.uid == resource.data.patient_uid;
      
      // Caregiver/doctor: read if relationship
      allow read: if exists(/databases/$(database)/documents/relationships/{relationshipId}
        where (resource.data.user_a_uid == resource.data.patient_uid &&
               resource.data.user_b_uid == request.auth.uid));
    }
    
    // ════════════════════════════════════════════════════════════════════════
    // DEFAULT DENY
    // ════════════════════════════════════════════════════════════════════════
    
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

---

## ☁️ Cloud Functions

### Location: `functions/index.js`

### Setup

```bash
cd functions
npm install
firebase deploy --only functions
```

### Functions Implemented

#### 1. sendChatNotification

```javascript
exports.sendChatNotification = functions.https.onCall(async (data, context) => {
  // Requires authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', '...');
  }

  const {
    recipient_uid,           // UID of notification recipient
    sender_name,             // Name to display
    message_preview,         // Message text (max 100 chars)
    thread_id,              // For deep linking
    message_id              // Message document ID
  } = data;

  try {
    // Get recipient's FCM tokens
    const tokens = await getTokensForUser(recipient_uid);
    
    // Send notification
    const payload = {
      notification: {
        title: sender_name,
        body: messagePreview || "Sent you a message"
      },
      data: {
        type: "chat",
        sender_id: context.auth.uid,
        thread_id: threadId,
        message_id: messageId,
        click_action: "FLUTTER_NOTIFICATION_CLICK"
      }
    };

    // Send to all tokens
    const result = await sendToTokens(tokens, payload);
    return { success: true, success_count: result.success };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

// Helper: Get all FCM tokens for a user
async function getTokensForUser(uid) {
  const doc = await db.collection('users').doc(uid).get();
  return doc.data()?.fcm_tokens || [];
}

// Helper: Send notification to multiple tokens
async function sendToTokens(tokens, payload) {
  const response = await messaging.sendMulticast({
    tokens,
    ...payload
  });
  return {
    success: response.successCount,
    failure: response.failureCount
  };
}
```

#### 2. sendSosAlert

```javascript
exports.sendSosAlert = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', '...');
  }

  const {
    patient_uid,           // Patient triggering SOS
    location,             // { latitude, longitude, address }
    emergency_contacts    // Array of contact UIDs
  } = data;

  try {
    // Get emergency contacts' phone numbers
    const contactPhones = await getContactPhones(emergency_contacts);
    
    // Send FCM notifications
    for (const contactUid of emergency_contacts) {
      const tokens = await getTokensForUser(contactUid);
      await messaging.sendMulticast({
        tokens,
        notification: {
          title: "SOS ALERT",
          body: "Patient needs emergency assistance"
        },
        data: {
          type: "sos",
          patient_uid,
          location: JSON.stringify(location),
          click_action: "FLUTTER_NOTIFICATION_CLICK"
        }
      });
    }
    
    // Send SMS via Twilio
    const twilioClient = twilio(
      process.env.TWILIO_ACCOUNT_SID,
      process.env.TWILIO_AUTH_TOKEN
    );
    
    for (const phone of contactPhones) {
      await twilioClient.messages.create({
        body: `SOS ALERT: Patient needs help. Location: ${location.address}`,
        from: process.env.TWILIO_PHONE,
        to: phone
      });
    }
    
    // Log SOS event to Firestore
    await db.collection('sos_alerts').add({
      patient_uid,
      triggered_at: admin.firestore.FieldValue.serverTimestamp(),
      location,
      notified_contacts: emergency_contacts,
      response_status: 'pending'
    });
    
    return { success: true, notified: emergency_contacts.length };
  } catch (error) {
    console.error('SOS alert failed:', error);
    return { success: false, error: error.message };
  }
});

async function getContactPhones(contactUids) {
  const phones = [];
  for (const uid of contactUids) {
    const doc = await db.collection('users').doc(uid).get();
    if (doc.data()?.phone_number) {
      phones.push(doc.data().phone_number);
    }
  }
  return phones;
}
```

#### 3. sendHealthAlert

```javascript
exports.sendHealthAlert = functions.https.onCall(async (data, context) => {
  const {
    patient_uid,
    alert_type,      // 'arrhythmia', 'abnormal_vitals', etc.
    severity,        // 'critical', 'high', 'medium', 'low'
    reading_id,
    message
  } = data;

  try {
    // Get patient's assigned doctor and caregivers
    const relationships = await db.collectionGroup('relationships')
      .where('user_a_uid', '==', patient_uid)
      .get();
    
    const notifyUids = relationships.docs
      .map(doc => doc.data().user_b_uid);
    
    // Send notifications
    for (const uid of notifyUids) {
      const tokens = await getTokensForUser(uid);
      const priority = severity === 'critical' ? 'high' : 'normal';
      
      await messaging.sendMulticast({
        tokens,
        notification: {
          title: `Health Alert: ${alert_type}`,
          body: message
        },
        data: {
          type: 'health_alert',
          patient_uid,
          alert_type,
          severity,
          reading_id
        },
        android: { priority },
        apns: {
          payload: { aps: { sound: 'default' } }
        }
      });
    }
    
    // Log alert
    await db.collection('health_alerts').add({
      patient_uid,
      alert_type,
      severity,
      reading_id,
      message,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      notified_doctor: true,
      notified_caregiver: true,
      acknowledged: false
    });
    
    return { success: true };
  } catch (error) {
    return { success: false, error: error.message };
  }
});
```

#### 4. arrhythmiaInference (HTTP endpoint)

```javascript
exports.arrhythmiaInference = functions.https.onRequest(async (req, res) => {
  // Validate request
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { samples, sampling_rate } = req.body;
  
  if (!Array.isArray(samples) || samples.length === 0) {
    return res.status(400).json({ error: 'Invalid samples' });
  }

  try {
    // Load TensorFlow model from Cloud Storage
    const modelUrl = 'gs://guardian-angel-e5ad0/models/arrhythmia_model';
    const model = await tf.loadLayersModel(modelUrl);
    
    // Preprocess: normalize samples to [-1, 1]
    const tensor = tf.tensor2d([samples]);
    const mean = tensor.mean();
    const std = tensor.sub(mean).pow(2).mean().sqrt();
    const normalized = tensor.sub(mean).div(std);
    
    // Inference
    const prediction = model.predict(normalized);
    const [probability] = await prediction.data();
    
    const isArrhythmia = probability > 0.5;
    const confidence = isArrhythmia ? probability : 1 - probability;
    
    return res.json({
      is_arrhythmia: isArrhythmia,
      confidence: parseFloat(confidence.toFixed(4)),
      probability: parseFloat(probability.toFixed(4)),
      threshold: 0.5,
      sampling_rate,
      sample_count: samples.length
    });
  } catch (error) {
    console.error('Inference failed:', error);
    return res.status(500).json({ error: 'Inference failed' });
  }
});
```

#### 5. onHealthReadingCreated (Firestore trigger)

```javascript
exports.onHealthReadingCreated = functions.firestore
  .document('users/{uid}/health_readings/{readingId}')
  .onCreate(async (snap, context) => {
    const reading = snap.data();
    const { uid } = context.params;

    try {
      // Check if reading is abnormal
      const thresholds = await getThresholds(uid);
      
      if (!isWithinThresholds(reading, thresholds)) {
        // Send alert
        await sendHealthAlert({
          patient_uid: uid,
          alert_type: 'abnormal_vitals',
          severity: determineSeverity(reading),
          reading_id: context.params.readingId,
          message: `Abnormal ${reading.reading_type}: ${reading.value} ${reading.unit}`
        });
      }
      
      // If arrhythmia detected via ECG
      if (reading.reading_type === 'ecg' && reading.is_abnormal) {
        await sendHealthAlert({
          patient_uid: uid,
          alert_type: 'arrhythmia',
          severity: 'critical',
          reading_id: context.params.readingId,
          message: 'Possible arrhythmia detected in ECG'
        });
      }
    } catch (error) {
      console.error('Health reading processing failed:', error);
      // Don't throw - this would fail the write
    }
  });

function isWithinThresholds(reading, thresholds) {
  const { value, reading_type } = reading;
  const threshold = thresholds[reading_type];
  
  if (!threshold) return true; // No threshold set
  
  return value >= threshold.min && value <= threshold.max;
}

function determineSeverity(reading) {
  // Return 'critical', 'high', 'medium', or 'low'
  // Based on how far the reading is from normal range
  // ... implementation ...
}
```

---

## 📲 Firebase Messaging (FCM)

### FCM Token Management

**File:** `lib/services/fcm_service.dart`

```dart
class FCMService {
  // Get device's FCM token
  Future<String?> getToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      return token;
    } catch (e) {
      return null;
    }
  }

  // Listen for token refreshes
  void startTokenRefreshListener() {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      // Update in Firestore
      FirebaseFirestore.instance
        .collection('users')
        .doc(auth.currentUser!.uid)
        .update({
          'fcm_tokens': FieldValue.arrayUnion([newToken])
        });
    });
  }

  // Handle notifications in foreground
  void startForegroundMessageListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final data = message.data;
      
      switch (data['type']) {
        case 'chat':
          showChatNotification(message);
          break;
        case 'sos':
          showSOSNotification(message);
          break;
        case 'health_alert':
          showHealthAlertNotification(message);
          break;
      }
    });
  }

  // Handle notification taps
  void startNotificationTapListener() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final data = message.data;
      
      switch (data['type']) {
        case 'chat':
          navigateToChatThread(data['thread_id']);
          break;
        case 'sos':
          navigateToSOSDetail(data['sos_id']);
          break;
        case 'health_alert':
          navigateToHealthAlert(data['alert_id']);
          break;
      }
    });
  }
}
```

---

## 🔒 API Security

### Authentication Flow

```
1. User signs in via Firebase Auth
2. Firebase generates ID token (1 hour validity)
3. Client obtains token via getIdToken()
4. Token sent in Authorization header: "Bearer {token}"
5. Backend verifies token via Firebase Admin SDK
6. On 401: Client calls refreshToken(), retries
7. After sign-out: Token immediately invalid
```

### CORS & API Configuration

All Cloud Functions have CORS enabled:

```javascript
res.set('Access-Control-Allow-Origin', '*');
res.set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
```

### Rate Limiting

Implemented via:
- Circuit breaker (local client-side)
- Cloud Function quotas (backend)
- Firestore rules (write limits per user)

---

## 📈 Backend Monitoring

### Cloud Logging

**Structured Log Format:**

```json
{
  "timestamp": "2025-01-10T12:34:56Z",
  "severity": "INFO",
  "message": "Chat notification sent",
  "labels": {
    "function": "sendChatNotification",
    "status": "success"
  },
  "jsonPayload": {
    "recipient_uid": "user123",
    "sender_uid": "user456",
    "thread_id": "thread789",
    "duration_ms": 145
  }
}
```

### Performance Monitoring

**Metrics Tracked:**
- Function execution time
- Memory usage
- Error rates
- Latency p50, p95, p99

### Error Handling

**In Cloud Functions:**
- All errors logged to Cloud Logging
- Structured error objects with context
- PII redaction in logs
- Retry-safe operations (idempotent)

---

## 🔄 Sync Integration with Firebase

### Data Flow

```
Client (Hive)
  ↓ (enqueue operation)
Sync Engine
  ↓ (send HTTP request)
API Client
  ↓ (route to endpoint)
Cloud Function (REST API)
  ↓ (authenticate, authorize)
Business Logic
  ↓ (update database)
Firestore
  ↓ (trigger on write)
Trigger Function (optional)
  ↓ (send notification)
Cloud Messaging (FCM)
  ↓
Device (Notification)
  ↓
App (foreground/background handler)
  ↓
Update Hive (listener)
  ↓
UI refresh
```

### Example: Chat Message Flow

```
1. User types message in Flutter app
2. Message enqueued as CHAT::message operation
3. Optimistic update: message appears in UI immediately
4. Sync engine routes to: POST /api/v1/chat/messages
5. Cloud Function receives call
6. Validates user authenticated
7. Stores in Firestore: chat_threads/{threadId}/messages/{msgId}
8. Firestore trigger runs: onChatMessageCreated
9. Gets recipient FCM tokens
10. Cloud Messaging sends notification
11. Recipient device receives FCM message
12. App's foreground listener shows notification
13. If app open: listener updates local Hive
14. UI rebuilds with new message (via Riverpod)
15. If app closed: notification tapped
16. App navigates to chat thread
17. Loads messages from Firestore listener
```

---

## 🚀 Deployment

### Prerequisites

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Authenticate
firebase login

# Select project
firebase use guardian-angel-e5ad0
```

### Deploy Functions

```bash
# Deploy all functions
firebase deploy --only functions

# Deploy specific function
firebase deploy --only functions:sendChatNotification

# View logs
firebase functions:log

# View errors
firebase functions:log --limit 50 --severity ERROR
```

### Monitor in Console

1. Go to: `console.firebase.google.com`
2. Select project: `guardian-angel-e5ad0`
3. Navigate to:
   - **Cloud Functions** → View logs, metrics
   - **Cloud Firestore** → View database, usage
   - **Authentication** → View users
   - **Realtime Database** → View data
   - **Cloud Storage** → View files
   - **Cloud Messaging** → View statistics

---

## ⚠️ Common Issues & Solutions

### Issue: 401 Unauthorized

**Cause:** Token expired or invalid  
**Solution:** Sync engine auto-refreshes token on 401 and retries

### Issue: 403 Forbidden

**Cause:** Security rules deny access  
**Solution:** Check Firestore rules, verify user permissions, check relationship

### Issue: FCM Notifications Not Arriving

**Cause:** FCM tokens not registered  
**Solution:** Call `getToken()` and store in Firestore under `fcm_tokens`

### Issue: Cloud Function Timeout

**Cause:** Long-running operation  
**Solution:** Increase timeout in `firebase.json`, optimize async operations

### Issue: Quota Exceeded

**Cause:** Too many function calls  
**Solution:** Check billing plan, implement client-side rate limiting

---

**Document Version:** 1.0  
**Last Updated:** January 10, 2026
