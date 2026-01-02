# Health Data Extraction Layer — Implementation Complete

## Summary

This document describes the **read-only health data extraction layer** implemented for Guardian Angel's patient screens.

**Scope:** Data extraction only. NO persistence, NO sync, NO BLE.

---

## Files Created

```
lib/health/
├── health.dart                              # Public API barrel export
├── models/
│   ├── normalized_health_data.dart          # Platform-agnostic output models
│   └── health_extraction_result.dart        # Result wrappers & error codes
├── providers/
│   └── health_extraction_provider.dart      # Riverpod DI providers
└── services/
    └── patient_health_extraction_service.dart   # Core extraction logic
```

---

## Dependency Added

```yaml
# pubspec.yaml
health: ^10.2.0
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      UI LAYER                               │
│  (next_screen.dart, diagnostic_screen.dart, etc.)          │
└─────────────────────────────┬───────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│               RIVERPOD PROVIDERS                            │
│  healthExtractionServiceProvider                            │
│  healthAvailabilityProvider                                 │
│  healthPermissionProvider                                   │
│  recentVitalsProvider(params)                               │
│  sleepSessionsProvider(params)                              │
│  hrvDataProvider(params)                                    │
└─────────────────────────────┬───────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│        PatientHealthExtractionService (Singleton)          │
│                                                             │
│  Public API:                                                │
│  • checkAvailability()                                      │
│  • requestPermissions()                                     │
│  • fetchRecentVitals(patientUid, windowMinutes)            │
│  • fetchSleepSessions(patientUid, start?, end?)            │
│  • fetchHRVData(patientUid, windowMinutes)                 │
└─────────────────────────────┬───────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    health package                           │
│        (HealthKit on iOS, Health Connect on Android)        │
└─────────────────────────────────────────────────────────────┘
```

---

## Data Types Extracted

| Data Type | Model Class | iOS Source | Android Source |
|-----------|-------------|------------|----------------|
| Heart Rate | `NormalizedHeartRateReading` | HealthKit | Health Connect |
| Blood Oxygen (SpO₂) | `NormalizedOxygenReading` | HealthKit | Health Connect |
| Sleep Sessions | `NormalizedSleepSession` | HealthKit | Health Connect |
| Sleep Stages | `NormalizedSleepSegment` | HealthKit | Health Connect |
| HRV (SDNN) | `NormalizedHRVReading` | HealthKit | Health Connect |

---

## Normalized Output Models

### NormalizedHeartRateReading
```dart
class NormalizedHeartRateReading {
  final String patientUid;
  final DateTime timestamp;
  final int bpm;
  final HealthDataSource dataSource;
  final DetectedDeviceType deviceType;
  final DataReliability reliability;
  final bool isResting;
}
```

### NormalizedOxygenReading
```dart
class NormalizedOxygenReading {
  final String patientUid;
  final DateTime timestamp;
  final int percentage;  // 0-100
  final HealthDataSource dataSource;
  final DetectedDeviceType deviceType;
  final DataReliability reliability;
}
```

### NormalizedSleepSession
```dart
class NormalizedSleepSession {
  final String patientUid;
  final DateTime sleepStart;
  final DateTime sleepEnd;
  final List<NormalizedSleepSegment> segments;
  final HealthDataSource dataSource;
  final DetectedDeviceType deviceType;
  final DataReliability reliability;
  final bool hasStageData;
}
```

### NormalizedHRVReading
```dart
class NormalizedHRVReading {
  final String patientUid;
  final DateTime timestamp;
  final double sdnnMs;
  final HealthDataSource dataSource;
  final DetectedDeviceType deviceType;
  final DataReliability reliability;
  final List<int>? rrIntervals;
}
```

---

## Result Wrapper

All extraction methods return `HealthExtractionResult<T>`:

```dart
final result = await service.fetchRecentVitals(patientUid: 'abc123');

if (result.success) {
  if (result.hasData) {
    final vitals = result.data!;
    print('HR: ${vitals.latestHeartRate?.bpm}');
  } else {
    print('No data available');
  }
} else {
  print('Error: ${result.errorCode} - ${result.errorMessage}');
}
```

### Error Codes
- `none` — Success
- `platformUnsupported` — Not iOS/Android
- `healthServiceUnavailable` — Health Connect not installed
- `permissionDenied` — User denied permissions
- `permissionRevoked` — Permissions revoked after grant
- `noDevicePaired` — No wearable connected
- `noDataAvailable` — No data in time range
- `dataStale` — Data too old
- `timeout` — Request timed out
- `platformError` — OS error
- `invalidTimeRange` — Bad time range
- `rateLimited` — Too many requests

---

## Permission Handling

### Permission Status
```dart
enum HealthPermissionStatus {
  granted,
  partiallyGranted,
  denied,
  notDetermined,
  platformUnsupported,
  healthServiceUnavailable,
  revoked,
}
```

### Usage
```dart
// Check availability first
final availability = await service.checkAvailability();
if (!availability.platformSupported) {
  // Show "not supported" message
  return;
}

// Request permissions
final permissions = await service.requestPermissions();
if (permissions.hasAnyPermission) {
  // Can fetch data
} else {
  // Show permission required message
}
```

---

## Edge Cases Handled

| Edge Case | Behavior |
|-----------|----------|
| Platform not iOS/Android | Returns `platformUnsupported` error |
| Health Connect not installed | Returns `healthServiceUnavailable` error |
| Permissions denied | Returns `permissionDenied` error |
| Permissions revoked mid-session | Returns `permissionRevoked` error |
| No wearable paired | Returns empty result with warning |
| No data in time range | Returns empty result (success, no data) |
| Xiaomi data delayed | Accepts stale data with `low` reliability |
| Duplicate data points | Deduplicated by timestamp |
| Overlapping sleep segments | Merged into sessions |
| Invalid data values | Filtered out by `isValid` checks |

---

## Logging

All operations log with `[HealthExtract]` prefix:

```
[HealthExtract] CheckingAvailability
[HealthExtract] AvailabilityCheckComplete: Platform: ios, service installed
[HealthExtract] RequestingPermissions
[HealthExtract] PermissionsGranted
[HealthExtract] FetchingRecentVitals: window: 60min
[HealthExtract] VitalsFetchComplete: HR: 72, O2: 98
[HealthExtract] NoDataAvailable: No vitals found in 60min window
```

---

## Usage Examples

### Basic Vitals Fetch
```dart
import 'package:guardian_angel_fyp/health/health.dart';

final service = PatientHealthExtractionService.instance;

// 1. Check availability
final availability = await service.checkAvailability();
print('Available: ${availability.hasAnyDataType}');

// 2. Request permissions
final permissions = await service.requestPermissions();
if (!permissions.hasAnyPermission) {
  print('No permissions granted');
  return;
}

// 3. Fetch vitals
final result = await service.fetchRecentVitals(
  patientUid: 'patient_123',
  windowMinutes: 60,
);

if (result.success && result.hasData) {
  final snapshot = result.data!;
  print('Heart Rate: ${snapshot.latestHeartRate?.bpm} bpm');
  print('SpO2: ${snapshot.latestOxygen?.percentage}%');
}
```

### With Riverpod
```dart
// In a ConsumerWidget
Widget build(BuildContext context, WidgetRef ref) {
  final availability = ref.watch(healthAvailabilityProvider);
  
  return availability.when(
    data: (avail) {
      if (!avail.platformSupported) {
        return Text('Health data not supported');
      }
      
      // Show permission request button
      return ElevatedButton(
        onPressed: () {
          ref.read(healthPermissionProvider.notifier).requestPermissions();
        },
        child: Text('Grant Health Permissions'),
      );
    },
    loading: () => CircularProgressIndicator(),
    error: (e, _) => Text('Error: $e'),
  );
}
```

### Sleep Data
```dart
final result = await service.fetchSleepSessions(
  patientUid: 'patient_123',
);

if (result.success && result.hasData) {
  for (final session in result.data!) {
    print('Sleep: ${session.totalHours.toStringAsFixed(1)}h');
    print('Stages: ${session.stagePercentages}');
  }
}
```

---

## Platform Configuration Required

### iOS (Info.plist)
```xml
<key>NSHealthShareUsageDescription</key>
<string>Guardian Angel needs access to your health data to monitor your vitals.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>Guardian Angel may save health data to track your progress.</string>
```

### Android (AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.health.READ_HEART_RATE"/>
<uses-permission android:name="android.permission.health.READ_BLOOD_OXYGEN"/>
<uses-permission android:name="android.permission.health.READ_SLEEP"/>
<uses-permission android:name="android.permission.health.READ_HEART_RATE_VARIABILITY"/>
```

---

## NOT Included (Future Steps)

| Feature | Why Not Included |
|---------|-----------------|
| Hive persistence | Out of scope — extraction only |
| Firestore sync | Out of scope — extraction only |
| BLE direct connection | Unnecessary — platform APIs sufficient |
| Raw ECG waveforms | Not exposed by platform APIs |
| Raw PPG waveforms | Not exposed by platform APIs |
| Background sync | Out of scope — separate module |
| Real-time streaming | Platform APIs don't guarantee this |
| ML analysis | Out of scope — separate module |
| Alerts/notifications | Out of scope — separate module |

---

## Next Steps

1. **Step 2: Persistence Layer** — Wire extraction output to Hive
2. **Step 3: Sync Layer** — Mirror vitals to Firestore
3. **Step 4: UI Integration** — Update patient screens to use providers
4. **Step 5: Background Sync** — Periodic health data refresh

---

## Testing

Run analyzer:
```bash
dart analyze lib/health/
```

All issues resolved: `No issues found!`
