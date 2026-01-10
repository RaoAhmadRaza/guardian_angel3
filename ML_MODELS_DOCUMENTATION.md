# Machine Learning Models Documentation

**Project:** Guardian Angel Health Monitoring App  
**Version:** 1.0.0  
**Last Updated:** January 2025  
**Status:** Production Ready

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Fall Detection Model (1D CNN)](#2-fall-detection-model-1d-cnn)
3. [Arrhythmia Detection Model (Rule-Based HRV)](#3-arrhythmia-detection-model-rule-based-hrv)
4. [Integration with Guardian Angel](#4-integration-with-guardian-angel)
5. [API Reference](#5-api-reference)
6. [Configuration Reference](#6-configuration-reference)
7. [Troubleshooting](#7-troubleshooting)

---

## 1. Executive Summary

Guardian Angel employs two distinct machine learning approaches for health monitoring:

| Model | Purpose | Technology | Inference Location |
|-------|---------|------------|-------------------|
| **Fall Detection** | Real-time fall event detection | 1D CNN (TensorFlow Lite) | On-device |
| **Arrhythmia Detection** | Heart rhythm abnormality detection | Rule-based HRV Analysis | Cloud (Firebase Functions) |

### Why These Architectures?

#### Fall Detection: 1D CNN
- **Real-time requirement**: ~10-20ms inference time
- **Sequential sensor data**: Natural fit for convolutional operations
- **On-device privacy**: No network latency, works offline
- **Battery efficiency**: TFLite optimized for mobile
- **Temporal patterns**: CNN excels at learning fall motion signatures

#### Arrhythmia Detection: Rule-Based HRV
- **Tabular HRV features**: SDNN, RMSSD, pNN50 are computed statistics
- **Medical interpretability**: Rule thresholds based on clinical literature
- **Small training data**: Medical data is scarce; rules don't need training
- **Cloud scalability**: Can upgrade to XGBoost/ML without app update

---

## 2. Fall Detection Model (1D CNN)

### 2.1 Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────────┐
│                      FALL DETECTION PIPELINE v1.0                         │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────┐   ┌──────────────┐   ┌──────────┐   ┌──────────────────┐  │
│  │  Phone   │──▶│ Preprocessing│──▶│   CNN    │──▶│ Temporal Voting  │  │
│  │   IMU    │   │   Pipeline   │   │  Model   │   │ + Stillness Gate │  │
│  │ Sensors  │   │              │   │ (TFLite) │   │                  │  │
│  └──────────┘   └──────────────┘   └──────────┘   └──────────────────┘  │
│       │               │                 │                   │            │
│       ▼               ▼                 ▼                   ▼            │
│   6 channels      8 channels       Probability          Fall/No-Fall    │
│   @ 200 Hz        normalized       [0.0 - 1.0]          Decision        │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Model Specification

| Parameter | Value |
|-----------|-------|
| **Architecture** | 1D Convolutional Neural Network |
| **Framework** | TensorFlow → TensorFlow Lite |
| **Model File** | `assets/ml/best_fall_model_v2.tflite` |
| **File Size** | ~500 KB |
| **Input Shape** | `[1, 400, 8]` (batch, timesteps, channels) |
| **Output Shape** | `[1, 1]` (single sigmoid probability) |
| **Inference Time** | <10ms on mobile devices |
| **Quantization** | Float32 (Float16/INT8 planned) |

### 2.3 Training Data

| Parameter | Value |
|-----------|-------|
| **Dataset** | SisFall (Universidad de Antioquia) |
| **Total Recordings** | 4,505 files |
| **Total Windows** | 74,409 |
| **Fall Windows** | 25,050 (33.7%) |
| **ADL Windows** | 49,359 (66.3%) |
| **Held-out Subjects** | SA21, SA22, SA23 |
| **Sampling Rate** | 200 Hz |
| **Window Duration** | 2 seconds (400 samples) |

#### Fall Types Covered (15 types)

| Code | Description |
|------|-------------|
| F01 | Fall forward from standing (slipping) |
| F02 | Fall backward from standing (slipping) |
| F03 | Lateral fall from standing (slipping) |
| F04 | Fall forward while walking (tripping) |
| F05 | Fall forward while jogging (tripping) |
| F06 | Vertical fall (fainting) |
| F07 | Fall while walking, hands on table |
| F08 | Fall forward getting up from chair |
| F09 | Lateral fall getting up from chair |
| F10 | Fall forward sitting down |
| F11 | Fall backward sitting down |
| F12 | Lateral fall sitting down |
| F13 | Fall forward while seated |
| F14 | Fall backward while seated |
| F15 | Lateral fall while seated |

#### Activities of Daily Living (19 types)

| Code | Description |
|------|-------------|
| D01-D04 | Walking/jogging at various speeds |
| D05-D06 | Walking up/down stairs |
| D07-D10 | Sitting down/standing up |
| D11 | Collapsing into chair |
| D12-D13 | Lying down/getting up |
| D14-D19 | Various other daily activities |

### 2.4 Preprocessing Pipeline

#### Input Contract

```
INPUT REQUIREMENTS:
─────────────────────────────────────────
• Window Size: 400 samples (exactly)
• Sampling Rate: 200 Hz (2 seconds)
• Channels: 6 raw values per sample
• Channel Order: [ax, ay, az, gx, gy, gz]
• Accelerometer Units: m/s² (SI)
• Gyroscope Units: rad/s (SI)
• Data Type: Float64
```

#### Processing Steps

**Step 1: Unit Conversion (SI → SisFall Counts)**

```dart
// Phone sensors → SisFall sensor scale
static const double accelScale = 104.4189;  // counts per m/s²
static const double gyroScale = 823.6271;   // counts per rad/s
```

**Step 2: High-Pass Filter (Gravity Removal)**

```dart
// Exponential high-pass filter
static const double hpAlpha = 0.98;

// Formula: hp_out = alpha * (hp_prev + raw - raw_prev)
```

**Step 3: Magnitude Computation**

```dart
accel_mag = sqrt(ax² + ay² + az²)
gyro_mag = sqrt(gx² + gy² + gz²)
```

**Step 4: Z-Score Normalization**

```dart
normalized = (value - mean) / std
```

| Channel | Mean | Std Dev |
|---------|------|---------|
| ax | -0.108100 | 212.180482 |
| ay | -0.181585 | 415.224954 |
| az | -0.108891 | 234.732531 |
| accel_mag | -0.242277 | 574.561888 |
| gx | 0.113382 | 406.914084 |
| gy | 0.156914 | 381.328314 |
| gz | 253.465736 | 456.384550 |
| gyro_mag | 417.484682 | 683.241066 |

**Step 5: Safety Clamping**

```dart
// Prevent numerical instability
normalized = clamp(normalized, -10.0, +10.0)
```

#### Output Contract

```
OUTPUT SPECIFICATION:
─────────────────────────────────────────
• Window Size: 400 samples
• Channels: 8 normalized values per sample
• Channel Order: [ax, ay, az, accel_mag, gx, gy, gz, gyro_mag]
• Value Range: [-10.0, +10.0] (clamped)
• Data Type: Float32 (for TFLite)
```

### 2.5 Temporal Aggregation

Single-window predictions are noisy. We use temporal voting to improve reliability.

#### Configuration (FROZEN)

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| **Threshold** | 0.35 (35%) | Balances sensitivity vs. false positives |
| **Voting Rule** | 2-of-3 | Requires sustained high probability |
| **Window Step** | 100 samples (0.5s) | Sliding window overlap |
| **Refractory Period** | 15 seconds | Prevents alert spam |

#### Decision Flow

```
New Probability → Add to Buffer (size=3)
        │
        ▼
Buffer Full? ──No──→ Wait
        │
       Yes
        │
        ▼
In Refractory? ──Yes──→ Suppress
        │
        No
        │
        ▼
Count ≥2 above 35%?
        │
   ┌────┴────┐
  Yes        No
   │          │
   ▼          ▼
🚨 ALERT!   Continue
(Start 15s   Monitoring
refractory)
```

### 2.6 Stillness Gating (Optional Enhancement)

**Purpose:** Reduce "drop & catch" false positives

**Logic:**
1. After probability spike, wait for acceleration to stabilize
2. Stabilized = magnitude ≈ 9.8 m/s² (gravity) ± 2 m/s²
3. Must be stable for ≥150 samples (~0.75s at 200Hz)
4. Real falls end with stillness; catches do not

```dart
// Configuration
static const double gravityMagnitude = 9.80665;  // m/s²
static const double stabilityTolerance = 2.0;    // ±2 m/s²
static const int requiredStillSamples = 150;     // ~0.75s at 200Hz
```

### 2.7 Key Source Files

| File | Purpose |
|------|---------|
| `lib/ml/fall_detection/fall_model.dart` | TFLite model wrapper |
| `lib/ml/fall_detection/preprocessing.dart` | Preprocessing + normalization |
| `lib/services/fall_detection/fall_detection_manager.dart` | Pipeline orchestration |

---

## 3. Arrhythmia Detection Model (Rule-Based HRV)

### 3.1 Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────────┐
│                    ARRHYTHMIA DETECTION PIPELINE v1.0                     │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────┐   ┌──────────────┐   ┌──────────┐   ┌──────────────────┐  │
│  │ Wearable │──▶│ RR Interval  │──▶│   HRV    │──▶│ Rule-Based       │  │
│  │ Device   │   │  Extraction  │   │ Features │   │ Classification   │  │
│  │ (BLE)    │   │              │   │          │   │                  │  │
│  └──────────┘   └──────────────┘   └──────────┘   └──────────────────┘  │
│       │               │                 │                   │            │
│       ▼               ▼                 ▼                   ▼            │
│   Heart rate      RR intervals     SDNN, RMSSD,         Risk Level     │
│   sensor          in ms            pNN50, HR BPM        + Flags        │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

### 3.2 System Specification

| Parameter | Value |
|-----------|-------|
| **Model Type** | Rule-based HRV analysis |
| **Inference Location** | Firebase Cloud Function |
| **Endpoint** | `POST /analyzeArrhythmia` |
| **Min RR Intervals** | 10 (API), 40 (recommended) |
| **Max RR Intervals** | 200 |
| **Analysis Window** | 60 seconds |
| **Request Timeout** | 10 seconds |
| **Retry Count** | 3 (with 2s delay) |

### 3.3 HRV Feature Extraction

The system calculates standard Heart Rate Variability metrics from RR intervals:

#### Input: RR Intervals

```javascript
// RR intervals in milliseconds
// Example: [800, 850, 780, 920, 870, ...]
```

#### Feature Calculations

**Mean RR (Average beat-to-beat interval)**
```javascript
meanRR = sum(rrIntervals) / n
```

**SDNN (Standard Deviation of NN intervals)**
```javascript
squaredDiffs = rrIntervals.map(rr => (rr - meanRR)²)
sdnn = sqrt(sum(squaredDiffs) / n)
```

**RMSSD (Root Mean Square of Successive Differences)**
```javascript
successiveDiffs = [rr[1]-rr[0], rr[2]-rr[1], ...]
squaredSuccDiffs = successiveDiffs.map(d => d²)
rmssd = sqrt(sum(squaredSuccDiffs) / (n-1))
```

**pNN50 (Percentage of successive differences > 50ms)**
```javascript
nn50Count = count(|diff| > 50)
pNN50 = (nn50Count / totalDiffs) * 100
```

**Heart Rate (BPM)**
```javascript
heartRateBpm = 60000 / meanRR
```

### 3.4 Risk Scoring Algorithm

The rule-based classifier evaluates multiple criteria:

| Condition | Risk Score Added | Flag |
|-----------|-----------------|------|
| SDNN > 200 ms | +0.30 | `high_variability` |
| SDNN < 20 ms | +0.20 | `low_variability` |
| RMSSD > 150 ms | +0.25 | `high_rmssd` |
| pNN50 > 50% OR < 3% | +0.15 | `abnormal_pnn50` |
| Heart Rate > 150 OR < 40 BPM | +0.30 | `extreme_heart_rate` |

**Risk Score Capped at 1.0**

#### Risk Level Classification

| Risk Score | Risk Level | Classification |
|------------|------------|----------------|
| ≥ 0.70 | **High** | "Potential Arrhythmia" |
| 0.40 - 0.69 | **Moderate** | "Irregular Pattern" |
| < 0.40 | **Low** | "Normal Sinus Rhythm" |

#### Confidence Calculation

```javascript
confidence = 0.75 + (0.25 * (1 - riskScore))
// Higher confidence for normal readings
// Range: 0.75 (high risk) to 1.00 (normal)
```

### 3.5 API Request/Response

#### Request

```http
POST https://us-central1-guardian-angel-app.cloudfunctions.net/analyzeArrhythmia
Content-Type: application/json

{
  "rr_intervals_ms": [800, 850, 780, 920, 870, ...],
  "request_id": "uuid-v4-string"
}
```

#### Response (Success)

```json
{
  "request_id": "uuid-v4-string",
  "risk_score": 0.25,
  "risk_level": "low",
  "classification": "Normal Sinus Rhythm",
  "confidence": 0.9375,
  "features": {
    "mean_rr": 845.5,
    "sdnn": 65.2,
    "rmssd": 48.7,
    "pnn50": 18.5,
    "heart_rate_bpm": 71.0
  },
  "analyzed_at": "2025-01-15T10:30:00.000Z",
  "model_version": "1.0.0-cloud"
}
```

### 3.6 Risk Level Thresholds (Dart Models)

```dart
enum ArrhythmiaRiskLevel {
  low,       // probability < 0.30
  moderate,  // probability 0.30 - 0.50
  elevated,  // probability 0.50 - 0.70
  high;      // probability > 0.70
}
```

### 3.7 Key Source Files

| File | Purpose |
|------|---------|
| `lib/ml/services/arrhythmia_analysis_service.dart` | Client orchestration |
| `lib/ml/services/arrhythmia_inference_client.dart` | HTTP client |
| `lib/ml/config/arrhythmia_config.dart` | Configuration constants |
| `lib/ml/models/arrhythmia_response.dart` | Response parsing |
| `lib/ml/models/arrhythmia_risk_level.dart` | Risk level enum |
| `functions/index.js` | Cloud Function implementation |

---

## 4. Integration with Guardian Angel

### 4.1 Fall Detection → SOS Flow

```
Fall Detected (2-of-3 voting)
        │
        ▼
Show Countdown Screen (30s)
        │
        ├── User taps "I'm OK" → Cancel alert
        │
        └── Timeout (30s) → Trigger SOS
                │
                ▼
        ┌───────────────────────────────────────┐
        │           SOS ESCALATION              │
        ├───────────────────────────────────────┤
        │ 0s:    Push notification sent         │
        │ 5-10s: Twilio SMS sent                │
        │ 60s:   Auto-escalation (if no response)│
        │        Twilio voice call initiated    │
        └───────────────────────────────────────┘
```

### 4.2 Arrhythmia Detection → Health Alert Flow

```
Wearable Heart Data (BLE)
        │
        ▼
RR Interval Extraction
        │
        ▼
ArrhythmiaAnalysisService.analyze()
        │
        ├── Cache hit (< 15 min) → Return cached
        │
        └── Cache miss → HTTP request to Cloud Function
                │
                ▼
        Rule-based HRV analysis
                │
                ▼
        Return ArrhythmiaAnalysisResponse
                │
                ├── Low risk → Log only
                │
                ├── Moderate risk → In-app notification
                │
                └── High risk → sendHealthAlert()
                        │
                        ▼
                Push notification to caregivers
```

### 4.3 Cloud Functions Overview

| Function | Type | Purpose |
|----------|------|---------|
| `analyzeArrhythmia` | HTTP (onRequest) | HRV analysis endpoint |
| `sendHealthAlert` | onCall | Push notification for health alerts |
| `sendSosAlert` | onCall | Push notification for SOS |
| `sendSosResponse` | onCall | Push notification for SOS response |
| `sendSosSms` | onCall | Twilio SMS for SOS |
| `sendSosCall` | onCall | Twilio voice call for SOS |
| `sendChatNotification` | onCall | Chat message notifications |

---

## 5. API Reference

### 5.1 Fall Detection API (Internal)

**FallModel Class**

```dart
class FallModel {
  static const int windowSize = 400;
  static const int numFeatures = 8;
  
  Future<void> loadModel();
  double predict(List<List<double>> inputWindow);
  void dispose();
}
```

**Preprocessor Class**

```dart
class Preprocessor {
  static const int requiredWindowSize = 400;
  static const int requiredRawChannels = 6;
  static const int outputChannels = 8;
  
  static void resetFilter();
  static List<double>? preprocessSample(List<double> rawSample);
  static List<List<double>>? preprocessWindow(List<List<double>> rawWindow);
}
```

**TemporalAggregator Class**

```dart
class TemporalAggregator {
  final int bufferSize;        // Default: 3
  final int requiredPositives; // Default: 2
  final Duration refractoryPeriod; // Default: 15 seconds
  final double threshold;      // Default: 0.35
  
  bool addProbabilityAndCheck(double probability);
  void reset();
}
```

### 5.2 Arrhythmia Detection API (Cloud)

**Endpoint**

```
POST /analyzeArrhythmia
```

**Request Schema**

```typescript
{
  rr_intervals_ms: number[];  // Required, min 10 values
  request_id?: string;        // Optional UUID
}
```

**Response Schema**

```typescript
{
  request_id: string;
  risk_score: number;         // 0.0 - 1.0
  risk_level: "low" | "moderate" | "high";
  classification: string;
  confidence: number;         // 0.75 - 1.0
  features: {
    mean_rr: number;
    sdnn: number;
    rmssd: number;
    pnn50: number;
    heart_rate_bpm: number;
  };
  analyzed_at: string;        // ISO 8601
  model_version: string;
}
```

---

## 6. Configuration Reference

### 6.1 Fall Detection Configuration

```dart
// fall_detection_manager.dart
static const int _windowSize = 400;    // 2 seconds @ 200Hz
static const int _stepSize = 100;      // 0.5 second sliding step

// Temporal aggregation
TemporalAggregator(
  bufferSize: 3,
  requiredPositives: 2,
  threshold: 0.35,
  refractoryPeriod: Duration(seconds: 15),
);
```

### 6.2 Arrhythmia Configuration

```dart
// arrhythmia_config.dart
class ArrhythmiaConfig {
  static String inferenceServiceUrl = 
    'https://us-central1-guardian-angel-app.cloudfunctions.net';
  static const String inferenceEndpoint = '/analyzeArrhythmia';
  
  static const Duration requestTimeout = Duration(seconds: 10);
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  
  static const int minRRIntervalsRequired = 40;
  static const int maxRRIntervals = 200;
  static const Duration analysisWindowDuration = Duration(seconds: 60);
  static const Duration staleAnalysisThreshold = Duration(minutes: 15);
  
  // Valid RR interval range (ms)
  static const int minRRValueMs = 200;   // Max 300 BPM
  static const int maxRRValueMs = 2000;  // Min 30 BPM
}
```

### 6.3 Environment Variables

```bash
# Cloud Function URL (set via dart-define or .env)
ARRHYTHMIA_SERVICE_URL=https://us-central1-guardian-angel-app.cloudfunctions.net

# Twilio (set via Firebase Functions config)
firebase functions:config:set \
  twilio.account_sid="ACXXX" \
  twilio.auth_token="XXX" \
  twilio.phone_number="+1234567890"
```

---

## 7. Troubleshooting

### 7.1 Fall Detection Issues

| Issue | Possible Cause | Solution |
|-------|----------------|----------|
| No alerts triggering | Threshold too high | Lower from 0.35 |
| Too many false alerts | Threshold too low | Raise above 0.35 |
| Alerts on phone drops | Expected behavior | Enable stillness gating |
| 0% probability always | Preprocessing mismatch | Check unit conversion |
| Model fails to load | Asset path incorrect | Verify `pubspec.yaml` |

### 7.2 Arrhythmia Detection Issues

| Issue | Possible Cause | Solution |
|-------|----------------|----------|
| Request timeout | Network/server issue | Check Firebase status |
| "Insufficient data" | Too few RR intervals | Ensure ≥40 intervals |
| Always "low risk" | Normal rhythm | Expected behavior |
| CORS error | Cross-origin blocked | Check Cloud Function CORS headers |
| 500 server error | Cloud Function crash | Check Firebase logs |

### 7.3 Logs & Debugging

**Fall Detection Logs**
```dart
// Enable via Developer Mode in app
log('[FallModel] Inference result: $fallProbability');
log('[FallDetectionManager] Threshold crossing: $probability');
log('[TemporalAggregator] Alert triggered');
```

**Arrhythmia Logs**
```javascript
// Firebase Functions console
console.log('Arrhythmia analysis:', { features, riskScore, classification });
console.error('Arrhythmia analysis error:', error);
```

---

## Appendix A: Quick Reference Constants

### Fall Detection

```dart
const int windowSize = 400;            // samples
const double samplingRate = 200.0;     // Hz
const double threshold = 0.35;         // 35%
const int votingWindow = 3;            // samples
const int requiredPositives = 2;       // 2-of-3
const Duration refractoryPeriod = Duration(seconds: 15);
```

### Arrhythmia Detection

```javascript
// Risk thresholds (Cloud Function)
const SDNN_HIGH = 200;    // ms
const SDNN_LOW = 20;      // ms
const RMSSD_HIGH = 150;   // ms
const PNN50_HIGH = 50;    // %
const PNN50_LOW = 3;      // %
const HR_HIGH = 150;      // BPM
const HR_LOW = 40;        // BPM
```

---

## Appendix B: Model Files

| File | Location | Size | Format |
|------|----------|------|--------|
| Fall Detection | `assets/ml/best_fall_model_v2.tflite` | ~500 KB | TFLite Float32 |
| Arrhythmia | Cloud Function (no model file) | N/A | Rule-based |

---

## Appendix C: Future Roadmap

### Fall Detection
- [ ] INT8 quantization (smaller model, faster inference)
- [ ] Multi-position training (wrist, pocket, bag)
- [ ] On-device model updates
- [ ] Fall severity classification

### Arrhythmia Detection
- [ ] Upgrade to XGBoost ML model
- [ ] Local TFLite inference option
- [ ] Additional arrhythmia types (AFib, bradycardia)
- [ ] Continuous monitoring mode

---

**Document Version:** 1.0.0  
**Last Updated:** January 2025  
**Authors:** Guardian Angel Development Team
