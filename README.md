# 👼 Guardian Angel

<p align="center">
  <img src="images/logo.png" alt="Guardian Angel Logo" width="200"/>
</p>

<p align="center">
  <strong>AI-Powered Elderly Care & Health Monitoring Platform</strong>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#installation">Installation</a> •
  <a href="#configuration">Configuration</a> •
  <a href="#usage">Usage</a> •
  <a href="#tech-stack">Tech Stack</a>
</p>

---

## 📋 Overview

**Guardian Angel** is a comprehensive Flutter-based mobile application designed to enhance the safety, health monitoring, and quality of life for elderly individuals. It connects patients with caregivers and healthcare providers through real-time monitoring, AI-powered health analysis, and emergency response systems.

### 🎯 Key Objectives

- **Safety First**: Automatic fall detection and SOS emergency alerts
- **Health Monitoring**: Real-time vitals tracking with AI-powered anomaly detection
- **Connected Care**: Seamless communication between patients, caregivers, and doctors
- **Independence**: Enable elderly to live independently while staying protected
- **Peace of Mind**: Give families confidence through continuous monitoring

---

## ✨ Features

### 🚨 Emergency Response System

| Feature | Description |
|---------|-------------|
| **Manual SOS** | One-tap emergency button with 60-second cancellation window |
| **Fall Detection** | AI-powered fall detection using phone accelerometer & gyroscope |
| **Auto-Escalation** | Automatic emergency services contact if no response |
| **Multi-Channel Alerts** | Push notifications, SMS, and automated calls to caregivers |
| **Location Sharing** | Real-time GPS location shared with emergency contacts |

### ❤️ Health Monitoring

| Feature | Description |
|---------|-------------|
| **Vitals Tracking** | Heart rate, blood pressure, oxygen saturation, temperature |
| **HealthKit/Health Connect** | Integration with Apple Health and Google Health Connect |
| **Arrhythmia Detection** | Rule-based + ML analysis of heart rhythm irregularities |
| **Smart Alerts** | AI-powered health anomaly detection with risk scoring |
| **Historical Trends** | Long-term health data visualization and analysis |

### 🤖 AI-Powered Features

| Feature | Description |
|---------|-------------|
| **Fall Detection ML** | 1D CNN model trained on SisFall dataset (400 samples @ 200Hz) |
| **Arrhythmia Analysis** | HRV-based analysis with cloud function inference |
| **Guardian AI Chat** | Gemini-powered health assistant for patients |
| **Peace of Mind AI** | Daily wellness check-ins and conversation companion |

### 👥 Multi-Role Support

| Role | Capabilities |
|------|-------------|
| **Patient** | Health tracking, SOS alerts, medication reminders, AI chat |
| **Caregiver** | Real-time monitoring, alerts dashboard, chat, location tracking |
| **Doctor** | Patient vitals review, medical chat, health reports |

### 📍 Geofencing & Safe Zones

- Define safe zones (home, hospital, park)
- Automatic alerts when patient leaves safe zone
- Customizable zone radius and alert settings
- Real-time location tracking for caregivers

### 💬 Communication

- **Real-time Chat**: Secure messaging between patients and care team
- **In-app Chat Alerts**: SOS messages automatically sent to all chat threads
- **Push Notifications**: Instant alerts for emergencies and messages
- **Voice Features**: Speech-to-text and text-to-speech accessibility

### 💊 Medication Management

- Medication schedules with reminders
- Dose tracking and adherence monitoring
- Caregiver visibility into medication compliance

### 🏠 Smart Home Integration

- MQTT-based home automation control
- Smart device integration for assisted living
- Voice-controlled home automation

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           Guardian Angel App                             │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │   Patient   │  │  Caregiver  │  │   Doctor    │  │    Admin    │    │
│  │   Portal    │  │   Portal    │  │   Portal    │  │   Portal    │    │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘    │
├─────────┴────────────────┴────────────────┴────────────────┴────────────┤
│                          State Management (Riverpod)                     │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐        │
│  │   Health   │  │    SOS     │  │    Chat    │  │  Geofence  │        │
│  │  Services  │  │  Services  │  │  Services  │  │  Services  │        │
│  └──────┬─────┘  └──────┬─────┘  └──────┬─────┘  └──────┬─────┘        │
├─────────┴────────────────┴────────────────┴────────────────┴────────────┤
│                          Local-First Storage (Hive)                      │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐        │
│  │  Firebase  │  │   Cloud    │  │   Twilio   │  │   Gemini   │        │
│  │ Firestore  │  │ Functions  │  │  SMS/Call  │  │     AI     │        │
│  └────────────┘  └────────────┘  └────────────┘  └────────────┘        │
└─────────────────────────────────────────────────────────────────────────┘
```

### Data Flow

```
Sensors → Preprocessing → ML Model → Risk Assessment → Alert Decision → Notification
   ↓            ↓             ↓             ↓               ↓              ↓
 Hive ←──── Firestore ←── Cloud Fn ←── Analytics ←── FCM/Twilio ←── Caregiver
```

### Key Design Principles

1. **Local-First**: All data stored in Hive first, then synced to Firestore
2. **Offline Capable**: Full functionality without internet connection
3. **Privacy-Centric**: Health data encrypted at rest
4. **Resilient**: Crash recovery and sync retry mechanisms
5. **Accessible**: Voice features and large UI elements for elderly users

---

## 📁 Project Structure

```
lib/
├── main.dart                 # App entry point
├── firebase_options.dart     # Firebase configuration
│
├── screens/                  # UI screens
│   ├── patient_home/         # Patient dashboard
│   ├── patient_sos/          # SOS emergency screen
│   ├── patient_chat/         # Patient chat
│   ├── patient_ai_chat/      # AI health assistant
│   ├── caregiver_portal/     # Caregiver dashboard & alerts
│   ├── medication/           # Medication management
│   ├── fall_detection/       # Fall detection UI
│   └── community/            # Community features
│
├── services/                 # Business logic
│   ├── sos_emergency_action_service.dart
│   ├── sos_alert_chat_service.dart
│   ├── health_threshold_service.dart
│   ├── fall_detection/
│   └── ...
│
├── ml/                       # Machine learning
│   ├── fall_detection/
│   │   ├── fall_model.dart   # TFLite model wrapper
│   │   └── preprocessing.dart # Signal preprocessing
│   └── models/               # ML model configs
│
├── health/                   # Health data management
│   ├── models/
│   ├── providers/
│   ├── repositories/
│   └── services/
│
├── chat/                     # Chat system
│   ├── models/
│   ├── providers/
│   ├── repositories/
│   ├── screens/
│   └── services/
│
├── geofencing/               # Location & safe zones
│   ├── models/
│   ├── providers/
│   ├── repositories/
│   └── services/
│
├── relationships/            # Patient-Caregiver links
├── persistence/              # Hive box registry
├── providers/                # Riverpod providers
├── repositories/             # Data access layer
├── sync/                     # Firestore sync
└── utils/                    # Utilities

functions/                    # Firebase Cloud Functions
├── index.js                  # All cloud functions
└── package.json

assets/
└── ml/                       # TFLite models
```

---

## 🛠️ Installation

### Prerequisites

- Flutter SDK 3.8.1+
- Dart SDK 3.8.1+
- Xcode 15+ (for iOS)
- Android Studio (for Android)
- Firebase CLI
- Node.js 18+ (for Cloud Functions)

### Setup Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/guardian_angel.git
   cd guardian_angel
   ```

2. **Install Flutter dependencies**
   ```bash
   flutter pub get
   ```

3. **Generate Hive adapters**
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **iOS Setup**
   ```bash
   cd ios
   pod install
   cd ..
   ```

5. **Configure Firebase**
   ```bash
   # Install FlutterFire CLI
   dart pub global activate flutterfire_cli
   
   # Configure Firebase
   flutterfire configure
   ```

6. **Deploy Cloud Functions**
   ```bash
   cd functions
   npm install
   firebase deploy --only functions
   cd ..
   ```

7. **Deploy Firestore Indexes**
   ```bash
   firebase deploy --only firestore:indexes
   ```

8. **Run the app**
   ```bash
   flutter run
   ```

---

## ⚙️ Configuration

### Firebase Setup

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable the following services:
   - Authentication (Email/Password, Google, Apple)
   - Cloud Firestore
   - Cloud Functions
   - Cloud Messaging (FCM)
   - Cloud Storage

### Twilio Setup (Optional - for SMS/Calls)

```bash
firebase functions:config:set \
  twilio.account_sid="ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" \
  twilio.auth_token="your_auth_token" \
  twilio.phone_number="+1234567890"
```

### Google Maps API

Add your API key to:
- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/AppDelegate.swift`

### Gemini AI (for AI Chat)

```bash
firebase functions:config:set gemini.api_key="your_gemini_api_key"
```

---

## 📱 Usage

### For Patients

1. **Sign Up**: Create account and complete health profile
2. **Connect**: Link with caregivers and doctors via invite codes
3. **Monitor**: View health dashboard and sync with wearables
4. **Emergency**: Use SOS button or let fall detection protect you
5. **Chat**: Communicate with care team or AI assistant

### For Caregivers

1. **Accept Invite**: Link with patients via relationship codes
2. **Dashboard**: Monitor all linked patients in one view
3. **Alerts**: Receive and respond to health/SOS alerts
4. **Location**: Track patient location and safe zones
5. **Chat**: Stay connected with real-time messaging

### For Doctors

1. **Patient List**: View all linked patients
2. **Health Data**: Review vitals, trends, and anomalies
3. **Consultations**: Provide guidance via secure chat
4. **Reports**: Generate health summary reports

---

## 🔧 Tech Stack

### Frontend
| Technology | Purpose |
|------------|---------|
| **Flutter 3.8** | Cross-platform UI framework |
| **Riverpod** | State management |
| **Hive** | Local-first NoSQL storage |
| **TFLite Flutter** | On-device ML inference |

### Backend
| Technology | Purpose |
|------------|---------|
| **Firebase Auth** | Authentication |
| **Cloud Firestore** | Real-time database |
| **Cloud Functions** | Serverless backend |
| **Cloud Messaging** | Push notifications |
| **Twilio** | SMS and voice calls |

### AI/ML
| Technology | Purpose |
|------------|---------|
| **TensorFlow Lite** | Fall detection (1D CNN) |
| **Google Gemini** | AI chat assistant |
| **Custom HRV Analysis** | Arrhythmia detection |

### Integrations
| Technology | Purpose |
|------------|---------|
| **Apple HealthKit** | iOS health data |
| **Health Connect** | Android health data |
| **Google Maps** | Location & geofencing |
| **MQTT** | Smart home automation |

---

## 🧪 Testing

```bash
# Run unit tests
flutter test

# Run integration tests
flutter test integration_test/

# Run with coverage
flutter test --coverage
```

---

## 📊 ML Models

### Fall Detection Model

| Specification | Value |
|---------------|-------|
| **Architecture** | 1D Convolutional Neural Network |
| **Input** | 400 samples × 8 channels |
| **Sampling Rate** | 200 Hz |
| **Channels** | ax, ay, az, accel_mag, gx, gy, gz, gyro_mag |
| **Training Data** | SisFall dataset |
| **Output** | Binary classification (fall/no-fall) |
| **Threshold** | 0.35 with 2-of-3 voting |

### Preprocessing Pipeline

1. **Unit Conversion**: Phone SI units → SisFall sensor counts
2. **High-Pass Filter**: Remove gravity component (α=0.98)
3. **Magnitude Calculation**: Compute acceleration and gyro magnitudes
4. **Z-Score Normalization**: Using frozen training statistics
5. **Clamping**: Limit to [-10, +10] for numerical stability

---

## 🔐 Security

- **Authentication**: Firebase Auth with MFA support
- **Data Encryption**: AES-256 for sensitive data at rest
- **Secure Storage**: Flutter Secure Storage for credentials
- **Biometric Auth**: Fingerprint/Face ID for app access
- **Audit Logging**: All sensitive actions logged
- **Secure Erase**: Military-grade data wiping on logout

---

## 🗺️ Roadmap

- [x] Phase 1: Core patient portal & health monitoring
- [x] Phase 2: Caregiver portal & real-time alerts
- [x] Phase 3: Fall detection ML & SOS system
- [x] Phase 4: AI chat & health insights
- [ ] Phase 5: Wearable device integration
- [ ] Phase 6: Telehealth video consultations
- [ ] Phase 7: Multi-language support

---

## 👥 Contributors

- **Muhammad Afzal** - Project Lead & Developer

---

## 📄 License

This project is proprietary software. All rights reserved.

---

## 🙏 Acknowledgments

- **SisFall Dataset** - For fall detection training data
- **Firebase** - Backend infrastructure
- **Flutter Team** - Amazing cross-platform framework
- **Google Health** - Health data integration

---

<p align="center">
  <strong>Built with ❤️ for elderly care</strong>
</p>

<p align="center">
  <a href="#">Documentation</a> •
  <a href="#">API Reference</a> •
  <a href="#">Support</a>
</p>
