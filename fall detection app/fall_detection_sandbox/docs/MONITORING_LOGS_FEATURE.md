# Monitoring Logs Feature - Technical Documentation

## Overview

The Monitoring Logs feature provides comprehensive real-time logging, reporting, and export capabilities for the fall detection system. It is designed for clinical review, debugging, and audit trails.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           UI Layer                                       │
├─────────────────────────────────────────────────────────────────────────┤
│  HomeScreen → MonitoringActiveScreen → LiveLogsScreen                   │
│                    │                         │                          │
│                    │ (Logs button)           │ (Export button)          │
│                    ▼                         ▼                          │
│              Real-time stats           PDF/TXT Export                   │
└─────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         Service Layer                                    │
├─────────────────────────────────────────────────────────────────────────┤
│  MonitoringLoggingService          │    ReportExportService              │
│  ├── Ring Buffer (240 entries)     │    ├── PDF Generation              │
│  ├── Auto Report (2 min)           │    ├── TXT Export                  │
│  └── Session Management            │    └── File Storage                │
└─────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         Data Models                                      │
├─────────────────────────────────────────────────────────────────────────┤
│  InferenceLogEntry                 │    MonitoringReport                 │
│  ├── SensorStatistics              │    ├── Processing Stats             │
│  ├── InferenceResult               │    ├── Sensor Summary              │
│  └── SystemState                   │    └── Model Info                  │
└─────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      Integration Layer                                   │
├─────────────────────────────────────────────────────────────────────────┤
│  FallDetectionManager._logInference()                                   │
│  ├── Creates SensorStatistics from raw window                          │
│  ├── Creates InferenceResult with timing & decision                    │
│  └── Pushes to MonitoringLoggingService                                │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## File Structure

```
lib/
├── models/
│   ├── log_entry.dart              # InferenceLogEntry, SensorStatistics, etc.
│   └── monitoring_report.dart      # MonitoringReport, SensorSummary
├── services/
│   ├── monitoring_logging_service.dart  # Ring buffer, auto-reports
│   └── report_export_service.dart       # PDF/TXT generation
├── ui/
│   ├── home_screen.dart            # Updated with logging integration
│   ├── monitoring_active_screen.dart    # NEW: Active monitoring UI
│   ├── live_logs_screen.dart            # NEW: Real-time log viewer
│   └── ...
└── logic/
    └── fall_detection_manager.dart # Updated with _logInference()
```

---

## Data Structures

### InferenceLogEntry
```dart
class InferenceLogEntry {
  String id;                        // Unique identifier
  DateTime timestamp;               // When log was created
  int sequenceNumber;               // Sequential window number
  SensorStatistics sensorStats;     // Aggregated sensor data
  InferenceResult inferenceResult;  // Model output & decision
  SystemState systemState;          // Monitoring/refractory state
}
```

### SensorStatistics
```dart
class SensorStatistics {
  // Accelerometer (m/s²)
  double accelXMean, accelYMean, accelZMean;
  double accelXPeak, accelYPeak, accelZPeak;
  double accelMagnitude, accelMagnitudePeak;
  
  // Gyroscope (rad/s)
  double gyroXMean, gyroYMean, gyroZMean;
  double gyroXPeak, gyroYPeak, gyroZPeak;
  double gyroMagnitude, gyroMagnitudePeak;
  
  int sampleCount;
}
```

### InferenceResult
```dart
class InferenceResult {
  DateTime windowStartTime;
  DateTime windowEndTime;
  int windowSize;                   // 400 samples
  double fallProbability;           // 0.0 - 1.0
  double thresholdUsed;             // 0.35
  String temporalAggregationState;  // "1 of 3", "2 of 3"
  bool thresholdExceeded;
  FallDecision finalDecision;       // noFall, fall, suppressed
  Duration inferenceLatency;
}
```

### SystemState
```dart
class SystemState {
  MonitoringState monitoringState;  // active, paused, stopped
  RefractoryState refractoryState;  // idle, active
  Duration? refractoryTimeRemaining;
  AlertState alertState;            // allowed, suppressed, triggered
  int bufferFillLevel;              // 0-100%
}
```

### MonitoringReport
```dart
class MonitoringReport {
  String id;
  DateTime generatedAt;
  DateTime periodStart, periodEnd;
  
  // Processing stats
  int totalWindowsProcessed;
  double averageFallProbability;
  double maxFallProbability;
  double minFallProbability;
  int thresholdCrossings;
  int alertsTriggered;
  int alertsSuppressed;
  
  // Sensor summary
  SensorSummary sensorSummary;
  
  // Model info
  String modelVersion;
  double thresholdUsed;
}
```

---

## Ring Buffer Implementation

The `MonitoringLoggingService` uses a Dart `Queue<InferenceLogEntry>` as an efficient ring buffer:

```dart
// Configuration
static const int _maxLogEntries = 240;  // ~2 minutes at 2 Hz

// O(1) insert
_logBuffer.addLast(entry);

// O(1) remove when full
while (_logBuffer.length > _maxLogEntries) {
  _logBuffer.removeFirst();
}
```

**Why 240 entries?**
- Inference rate: ~2 windows/second (0.5s step size)
- 2 minutes × 60 seconds × 2 windows = 240 entries
- Memory footprint: ~500 KB max

---

## Automatic Report Generation

Reports are generated automatically every 2 minutes:

```dart
_reportTimer = Timer.periodic(_reportInterval, (_) => _generatePeriodicReport());
```

Each report aggregates:
1. All logs from the last 2 minutes
2. Probability statistics (avg, min, max)
3. Sensor magnitude summaries
4. Alert statistics

---

## Export Formats

### PDF Export
- Full-featured report with sections and tables
- Device & app metadata
- Formatted for clinical review
- Uses `pdf` package for generation

### TXT Export
- ASCII box-drawing for structure
- Universal compatibility
- Suitable for debugging

---

## UI Flow

```
HomeScreen
    │
    │ [Start Monitoring]
    ▼
MonitoringActiveScreen
    │
    │ • Shows live probability
    │ • Animated status indicator
    │ • Pause/Stop controls
    │
    │ [Logs button - top right]
    ▼
LiveLogsScreen
    │
    │ • Rolling log display
    │ • Auto-scroll toggle
    │ • Export button
    │
    │ [Export]
    ▼
Share Sheet → PDF/TXT file
```

---

## Dependencies Added

```yaml
# pubspec.yaml
dependencies:
  pdf: ^3.10.8              # PDF generation
  share_plus: ^7.2.2        # File sharing
  device_info_plus: ^9.1.2  # Device metadata
```

---

## Integration Points

### FallDetectionManager
```dart
// Set logging service
void setLoggingService(MonitoringLoggingService service) {
  _loggingService = service;
}

// Called after each inference
void _logInference({...}) {
  final sensorStats = SensorStatistics.fromRawWindow(rawWindow);
  final inferenceResult = InferenceResult(...);
  final systemState = SystemState(...);
  
  _loggingService!.addLogEntry(
    sensorStats: sensorStats,
    inferenceResult: inferenceResult,
    systemState: systemState,
  );
}
```

### HomeScreen
```dart
// Initialize logging service
_loggingService = MonitoringLoggingService();
_manager.setLoggingService(_loggingService);

// Navigate to monitoring screen with logging
void _startMonitoringWithLogs() {
  _manager.startMonitoring();
  Navigator.of(context).push(
    CupertinoPageRoute(
      builder: (context) => MonitoringActiveScreen(
        manager: _manager,
        loggingService: _loggingService,
      ),
    ),
  );
}
```

---

## Performance Considerations

1. **Non-blocking logging**: All log operations are O(1)
2. **Fixed memory**: Ring buffer limits memory usage
3. **Lazy aggregation**: Sensor stats computed per-window, not per-sample
4. **Background reports**: Timer-based, doesn't block inference
5. **Efficient export**: PDF generated on-demand, not continuously

---

## Testing Recommendations

1. **Memory profiling**: Monitor heap during extended sessions
2. **Latency testing**: Ensure logging doesn't add >5ms to inference
3. **Export validation**: Verify PDF renders correctly on various devices
4. **Edge cases**:
   - Empty log buffer
   - Rapid start/stop monitoring
   - Export during active monitoring
   - Report generation with <240 entries

---

## Future Enhancements

1. **Cloud sync**: Upload reports to backend
2. **CSV export**: For data analysis tools
3. **Log filtering**: By probability range, time, etc.
4. **Waveform visualization**: Plot sensor data
5. **Comparison views**: Compare multiple reports
