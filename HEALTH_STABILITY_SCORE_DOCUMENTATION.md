# Health Stability Score (HSS) Module Documentation

## Executive Summary

The Health Stability Score (HSS) is a comprehensive health monitoring system that aggregates multiple physiological and behavioral signals into a single, actionable 0-100 score. It provides real-time health status assessment for elderly patients, enabling proactive care interventions before health deterioration occurs.

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Scoring Model](#scoring-model)
4. [Subsystem Signals](#subsystem-signals)
5. [Adaptive Baseline System](#adaptive-baseline-system)
6. [Components Reference](#components-reference)
7. [UI Integration](#ui-integration)
8. [API Reference](#api-reference)
9. [Configuration](#configuration)
10. [Future Enhancements](#future-enhancements)

---

## Overview

### Purpose

The HSS module addresses the challenge of synthesizing multiple health data streams into a single, interpretable metric that:

- **Reduces cognitive load** for caregivers monitoring multiple vital signs
- **Enables early warning** before critical health events occur
- **Personalizes thresholds** based on individual patient baselines
- **Provides actionable insights** with color-coded severity levels

### Key Features

| Feature | Description |
|---------|-------------|
| **Multi-Signal Fusion** | Combines physical, cardiac, sleep, and cognitive signals |
| **Adaptive Weighting** | Adjusts subsystem weights based on data availability |
| **Personal Baselines** | Learns individual patient norms over time |
| **Real-Time Updates** | Auto-refreshes every 15 minutes |
| **Trend Analysis** | Tracks score trajectory (improving/declining/stable) |
| **Reliability Scoring** | Indicates confidence level of the score |

### Score Interpretation

| Score Range | Level | Color | Meaning |
|-------------|-------|-------|---------|
| **85-100** | Stable | 🟢 Green | Excellent health stability |
| **70-84** | Moderate | 🟡 Yellow | Minor deviations from baseline |
| **50-69** | Attention | 🟠 Orange | Notable changes requiring monitoring |
| **0-49** | Alert | 🔴 Red | Significant health concerns |

---

## Architecture

### System Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         UI Layer                                         │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────┐  │
│  │  HSSBadge       │  │ StabilityGauge  │  │ StabilityScoreCard      │  │
│  │  (Compact)      │  │ Widget          │  │ (Full Details)          │  │
│  └────────┬────────┘  └────────┬────────┘  └───────────┬─────────────┘  │
│           │                    │                       │                 │
│           └────────────────────┼───────────────────────┘                 │
│                                ▼                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐│
│  │                  StabilityScoreProvider (Singleton)                  ││
│  │   • Manages UI state                                                 ││
│  │   • Auto-refresh timer (15 min)                                      ││
│  │   • Notifies listeners on score change                               ││
│  └─────────────────────────────┬───────────────────────────────────────┘│
└────────────────────────────────┼────────────────────────────────────────┘
                                 │
┌────────────────────────────────┼────────────────────────────────────────┐
│                         Service Layer                                    │
│                                ▼                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐│
│  │                  StabilityScoreService (Fusion Engine)               ││
│  │   • Normalizes subsystem scores to 0-100                             ││
│  │   • Applies adaptive weighting                                       ││
│  │   • Computes composite score                                         ││
│  │   • Determines stability level                                       ││
│  └─────────────────────────────┬───────────────────────────────────────┘│
│                                │                                         │
│       ┌────────────┬───────────┼───────────┬────────────┐               │
│       ▼            ▼           ▼           ▼            ▼               │
│  ┌─────────┐ ┌──────────┐ ┌─────────┐ ┌──────────┐ ┌──────────────┐    │
│  │Physical │ │ Cardiac  │ │  Sleep  │ │Cognitive │ │  Baseline    │    │
│  │Signals  │ │ Signals  │ │ Signals │ │ Signals  │ │  Persistence │    │
│  └────┬────┘ └────┬─────┘ └────┬────┘ └────┬─────┘ └──────┬───────┘    │
│       │           │            │           │              │             │
└───────┼───────────┼────────────┼───────────┼──────────────┼─────────────┘
        │           │            │           │              │
┌───────┼───────────┼────────────┼───────────┼──────────────┼─────────────┐
│       ▼           ▼            ▼           ▼              ▼             │
│  ┌─────────┐ ┌──────────┐ ┌─────────┐ ┌──────────┐ ┌──────────────┐    │
│  │  Fall   │ │Arrhythmia│ │  Sleep  │ │Medication│ │SharedPrefs   │    │
│  │Detection│ │ Service  │ │ Analyzer│ │ Tracker  │ │              │    │
│  │ TFLite  │ │ XGBoost  │ │         │ │          │ │              │    │
│  └─────────┘ └──────────┘ └─────────┘ └──────────┘ └──────────────┘    │
│                         Data Sources                                     │
└─────────────────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **Collection**: Subsystem collectors gather raw signals from sensors/services
2. **Normalization**: Raw values converted to 0-100 stability scores
3. **Baseline Comparison**: Current values compared to personal baselines
4. **Fusion**: Weighted aggregation produces composite score
5. **Level Assignment**: Score mapped to stability level (Stable/Moderate/Attention/Alert)
6. **UI Update**: Provider notifies widgets to refresh display

---

## Scoring Model

### Fusion Algorithm

The HSS uses an **adaptive weighted average** with the following formula:

```
HSS = Σ(Wᵢ × Sᵢ) / Σ(Wᵢ)

Where:
  Wᵢ = Adaptive weight for subsystem i
  Sᵢ = Normalized score (0-100) for subsystem i
```

### Default Weights

| Subsystem | Default Weight | Rationale |
|-----------|----------------|-----------|
| **Physical (Mobility)** | 30% | Fall risk is critical for elderly |
| **Cardiac** | 30% | Heart health indicates overall status |
| **Sleep** | 25% | Sleep quality affects recovery |
| **Cognitive/Behavioral** | 15% | Medication adherence + mood |

### Adaptive Weight Adjustment

Weights are dynamically adjusted based on:

1. **Data Freshness**: Stale data (>24h) receives reduced weight
2. **Data Availability**: Missing subsystems have weight redistributed
3. **Confidence Level**: Low-confidence readings weighted less

```dart
double _computeAdaptiveWeight(SubsystemSignals signals, double baseWeight) {
  final freshnessMultiplier = signals.dataFreshness;  // 0.0 to 1.0
  final confidenceMultiplier = signals.confidence;     // 0.0 to 1.0
  
  return baseWeight * freshnessMultiplier * confidenceMultiplier;
}
```

---

## Subsystem Signals

### 1. Physical Signals (Mobility & Fall Detection)

**Source**: TensorFlow Lite CNN Model + Accelerometer/Gyroscope

| Metric | Range | Description |
|--------|-------|-------------|
| `fallRiskScore` | 0.0-1.0 | Current fall probability from ML model |
| `recentFallEvents` | 0-N | Falls in last 24 hours |
| `mobilityScore` | 0-100 | Activity level indicator |
| `gaitStability` | 0-100 | Walking pattern consistency |

**Stability Score Calculation**:
```dart
double computeStabilityScore() {
  // Base score from inverse of fall risk
  double score = (1 - fallRiskScore) * 100;
  
  // Penalty for recent falls: -20 points per fall
  score -= recentFallEvents * 20;
  
  // Incorporate gait stability if available
  if (gaitStability != null) {
    score = (score * 0.7) + (gaitStability * 0.3);
  }
  
  return score.clamp(0, 100);
}
```

### 2. Cardiac Signals

**Source**: XGBoost Model via FastAPI + Health Connect/HealthKit

| Metric | Range | Description |
|--------|-------|-------------|
| `arrhythmiaRisk` | 0.0-1.0 | Probability of arrhythmia |
| `heartRateVariability` | 0-200 ms | HRV (RMSSD) |
| `restingHeartRate` | 40-120 bpm | Resting HR |
| `heartRateDeviation` | 0-50+ bpm | Deviation from personal baseline |

**Stability Score Calculation**:
```dart
double computeStabilityScore() {
  // Start with inverse arrhythmia risk
  double score = (1 - arrhythmiaRisk) * 100;
  
  // HRV contribution (higher = better, normalize to 100ms baseline)
  final hrvFactor = (heartRateVariability / 100).clamp(0.0, 1.0);
  score = (score * 0.6) + (hrvFactor * 100 * 0.4);
  
  // Penalty for HR deviation from baseline
  if (heartRateDeviation != null && heartRateDeviation! > 15) {
    score -= (heartRateDeviation! - 15) * 2;
  }
  
  return score.clamp(0, 100);
}
```

### 3. Sleep Signals

**Source**: `NormalizedSleepSession` from Health Connect/HealthKit

| Metric | Range | Description |
|--------|-------|-------------|
| `sleepEfficiency` | 0-100% | Time asleep / Time in bed |
| `deepSleepRatio` | 0-100% | Deep sleep / Total sleep |
| `sleepConsistency` | 0-100 | Bedtime regularity score |
| `recentSleepHours` | 0-24 | Average sleep duration (7 days) |

**Stability Score Calculation**:
```dart
double computeStabilityScore() {
  double score = 0;
  
  // Sleep duration score (optimal: 7-8 hours)
  final durationScore = _scoreSleepDuration(recentSleepHours);
  score += durationScore * 0.3;
  
  // Efficiency score
  score += sleepEfficiency * 0.25;
  
  // Deep sleep score (optimal: 15-25% of total)
  final deepScore = _scoreDeepSleep(deepSleepRatio);
  score += deepScore * 0.25;
  
  // Consistency score
  score += sleepConsistency * 0.2;
  
  return score.clamp(0, 100);
}
```

### 4. Cognitive/Behavioral Signals

**Source**: App Usage Data + Medication Tracking

| Metric | Range | Description |
|--------|-------|-------------|
| `medicationAdherence` | 0-100% | Doses taken / Scheduled doses (7 days) |
| `moodScore` | 1-5 | Self-reported mood (recent check-in) |
| `appEngagement` | 0-100 | App interaction frequency |
| `responseLatency` | 0-N sec | Average time to confirm medications |

**Stability Score Calculation**:
```dart
double computeStabilityScore() {
  double score = 0;
  
  // Medication adherence (most important)
  score += medicationAdherence * 0.5;
  
  // Mood score (normalized to 0-100)
  final moodNormalized = ((moodScore - 1) / 4) * 100;
  score += moodNormalized * 0.3;
  
  // App engagement
  score += appEngagement * 0.2;
  
  return score.clamp(0, 100);
}
```

---

## Adaptive Baseline System

### Purpose

Personal baselines enable detection of **relative changes** rather than absolute thresholds. A heart rate of 80 bpm might be normal for one patient but elevated for another.

### Baseline Learning

Baselines are learned using **Exponential Moving Average (EMA)**:

```dart
void updateBaseline(double newValue) {
  if (_baseline == null) {
    _baseline = newValue;
  } else {
    // α = 0.1 for slow adaptation
    _baseline = (_alpha * newValue) + ((1 - _alpha) * _baseline!);
  }
}
```

### Baseline Structure

```dart
class PersonalBaseline {
  final SubsystemBaseline physical;   // Mobility patterns
  final SubsystemBaseline cardiac;    // Heart rate norms
  final SubsystemBaseline sleep;      // Sleep patterns
  final SubsystemBaseline cognitive;  // Behavioral patterns
  
  final DateTime establishedAt;
  final int dataPointsCount;
  final bool isReliable;  // Minimum 7 days of data
}

class SubsystemBaseline {
  final double mean;
  final double standardDeviation;
  final double minNormal;
  final double maxNormal;
  final Map<String, double> metricBaselines;
}
```

### Deviation Scoring

Current values are scored based on deviation from baseline:

```dart
double scoreDeviation(double current, SubsystemBaseline baseline) {
  final zScore = (current - baseline.mean) / baseline.standardDeviation;
  
  // Map z-score to stability score
  // z=0 → 100 (perfect match)
  // z=±1 → 85 (1 std dev)
  // z=±2 → 60 (2 std dev)
  // z=±3 → 30 (3 std dev)
  
  final absZ = zScore.abs();
  if (absZ <= 1) return 100 - (absZ * 15);
  if (absZ <= 2) return 85 - ((absZ - 1) * 25);
  if (absZ <= 3) return 60 - ((absZ - 2) * 30);
  return 30 - ((absZ - 3) * 10).clamp(0, 30);
}
```

---

## Components Reference

### Models

| File | Class | Purpose |
|------|-------|---------|
| `subsystem_signals.dart` | `PhysicalSignals` | Fall detection + mobility data |
| `subsystem_signals.dart` | `CardiacSignals` | Heart health data |
| `subsystem_signals.dart` | `SleepSignals` | Sleep quality data |
| `subsystem_signals.dart` | `CognitiveSignals` | Behavioral data |
| `personal_baseline.dart` | `PersonalBaseline` | Learned patient norms |
| `personal_baseline.dart` | `SubsystemBaseline` | Per-subsystem baselines |
| `stability_score_result.dart` | `StabilityScoreResult` | Final computed score |
| `stability_score_result.dart` | `StabilityLevel` | Enum: stable/moderate/attention/alert |
| `stability_score_result.dart` | `SubsystemContribution` | Per-subsystem breakdown |

### Services

| File | Class | Purpose |
|------|-------|---------|
| `stability_score_service.dart` | `StabilityScoreService` | Main fusion engine |
| `sleep_trend_analyzer.dart` | `SleepTrendAnalyzer` | Analyzes `NormalizedSleepSession` |
| `cognitive_signal_collector.dart` | `CognitiveSignalCollector` | Medication + mood data |
| `baseline_persistence_service.dart` | `BaselinePersistenceService` | SharedPreferences storage |

### Provider

| File | Class | Purpose |
|------|-------|---------|
| `stability_score_provider.dart` | `StabilityScoreProvider` | Singleton state management |

### Widgets

| File | Class | Purpose |
|------|-------|---------|
| `stability_gauge_widget.dart` | `StabilityGaugeWidget` | Circular gauge visualization |
| `stability_gauge_widget.dart` | `StabilityScoreCard` | Full detail card |
| `hss_badge.dart` | `HSSBadge` | Compact badge for avatars |
| `hss_badge.dart` | `HSSAvatarIndicator` | Avatar wrapper with badge |

---

## UI Integration

### Quick Start

```dart
import 'package:guardian_angel/stability_score/stability_score.dart';

// 1. Initialize (typically in main screen's initState)
await StabilityScoreProvider.instance.initialize();

// 2. Display compact badge under avatar
const HSSBadge(
  size: HSSBadgeSize.small,
  showLabel: true,
)

// 3. Display full gauge
StabilityGaugeWidget(
  score: StabilityScoreProvider.instance.currentScore,
  size: 200,
  showBreakdown: true,
)
```

### Integration Points

The HSS badge is displayed on:

| Screen | Location | Widget |
|--------|----------|--------|
| `next_screen.dart` | Below patient avatar in header | `HSSBadge(size: small)` |
| `home_automation_dashboard.dart` | Below pulsing avatar | `HSSBadge(size: small)` |
| `settings_screen.dart` | Below profile picture | `HSSBadge(size: medium)` |

### Listening to Score Changes

```dart
ListenableBuilder(
  listenable: StabilityScoreProvider.instance,
  builder: (context, _) {
    final score = StabilityScoreProvider.instance.currentScore;
    return Text('HSS: ${score?.score.round() ?? "--"}');
  },
)
```

---

## API Reference

### StabilityScoreProvider

```dart
class StabilityScoreProvider extends ChangeNotifier {
  // Singleton access
  static StabilityScoreProvider get instance;
  
  // Initialization (call once at app start)
  Future<void> initialize();
  
  // Current computed score
  StabilityScoreResult? get currentScore;
  
  // Loading state
  bool get isLoading;
  
  // Error state
  String? get error;
  
  // Force refresh
  Future<void> refreshScore();
  
  // Record user mood check-in
  Future<void> recordMoodCheckIn(int mood); // 1-5 scale
  
  // Cleanup
  void dispose();
}
```

### StabilityScoreResult

```dart
class StabilityScoreResult {
  final double score;                    // 0-100
  final StabilityLevel level;            // stable/moderate/attention/alert
  final List<SubsystemContribution> contributions;
  final ScoreTrend trend;                // improving/declining/stable
  final bool isReliable;                 // Sufficient data available
  final double confidence;               // 0.0-1.0
  final DateTime computedAt;
  final String? primaryConcern;          // Lowest-scoring subsystem
}
```

### StabilityLevel

```dart
enum StabilityLevel {
  stable,     // 85-100, Green
  moderate,   // 70-84, Yellow
  attention,  // 50-69, Orange
  alert,      // 0-49, Red
}

extension StabilityLevelExtension on StabilityLevel {
  Color get color;
  String get label;
  String get description;
  IconData get icon;
}
```

---

## Configuration

### Timing Constants

| Constant | Default | Description |
|----------|---------|-------------|
| `refreshInterval` | 15 minutes | Auto-refresh frequency |
| `dataStaleThreshold` | 24 hours | Data considered stale |
| `baselineMinDays` | 7 days | Minimum for reliable baseline |
| `baselineAlpha` | 0.1 | EMA learning rate |

### Weight Configuration

Weights can be adjusted in `StabilityScoreService`:

```dart
static const Map<String, double> defaultWeights = {
  'physical': 0.30,
  'cardiac': 0.30,
  'sleep': 0.25,
  'cognitive': 0.15,
};
```

### Threshold Configuration

Score-to-level thresholds:

```dart
StabilityLevel _determineLevel(double score) {
  if (score >= 85) return StabilityLevel.stable;
  if (score >= 70) return StabilityLevel.moderate;
  if (score >= 50) return StabilityLevel.attention;
  return StabilityLevel.alert;
}
```

---

## Future Enhancements

### Planned Features

1. **Machine Learning Score Prediction**
   - Use historical patterns to predict future score trajectory
   - Alert before expected decline

2. **Caregiver Alerts**
   - Push notifications when score drops below threshold
   - Configurable alert levels per patient

3. **Detailed Analytics Dashboard**
   - Historical score graphs
   - Subsystem trend analysis
   - Correlation insights

4. **Voice-Based Mood Check-ins**
   - Analyze speech patterns for mood detection
   - Reduce manual input burden

5. **Wearable Integration**
   - Apple Watch complications
   - Fitbit tile display

6. **Doctor Dashboard**
   - Multi-patient HSS overview
   - Batch monitoring capabilities

### API Versioning

Current version: **1.0.0**

Future API changes will maintain backward compatibility through versioned endpoints.

---

## Appendix

### File Structure

```
lib/stability_score/
├── stability_score.dart           # Barrel file (exports all)
├── models/
│   ├── subsystem_signals.dart     # Input signal models
│   ├── personal_baseline.dart     # Baseline models
│   └── stability_score_result.dart # Output result model
├── services/
│   ├── stability_score_service.dart    # Fusion engine
│   ├── sleep_trend_analyzer.dart       # Sleep analysis
│   ├── cognitive_signal_collector.dart # Behavioral collection
│   └── baseline_persistence_service.dart # Storage
├── providers/
│   └── stability_score_provider.dart   # UI state management
└── widgets/
    ├── stability_gauge_widget.dart     # Visual gauge
    └── hss_badge.dart                  # Compact badge
```

### Dependencies

- `flutter/foundation.dart` - ChangeNotifier
- `shared_preferences` - Baseline persistence
- `fall_detection/fall_detection.dart` - Physical signals
- `arrhythmia/arrhythmia.dart` - Cardiac signals
- `sleep/normalized_sleep_session.dart` - Sleep signals

---

*Document Version: 1.0*  
*Last Updated: January 2026*  
*Module: Health Stability Score (HSS)*
