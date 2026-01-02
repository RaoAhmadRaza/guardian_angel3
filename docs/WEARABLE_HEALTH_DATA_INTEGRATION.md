# Wearable Health Data Integration — Implementation Guide

## Executive Summary

This document provides concrete implementation steps for extracting **heart rate**, **raw heart sensor signals (PPG/ECG)**, **SpO₂**, and **sleep data** from **Apple Watch**, **Samsung Galaxy Watch**, and **Xiaomi wearables** into Guardian Angel's patient screens.

**Current State Analysis:**
- ✅ `VitalsModel` already supports: `heartRate`, `oxygenPercent`, `temperatureC`, `stressIndex`
- ✅ `DiagnosticState` supports: `heartRate`, `rrIntervals`, `ecgSamples`, `SleepQualityData`
- ✅ `VitalsRepository` exists with Hive persistence
- ✅ `flutter_blue_plus: ^1.4.0` already in `pubspec.yaml`
- ⚠️ No health platform SDK integration exists
- ⚠️ No wearable service layer implemented

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           WEARABLE ECOSYSTEMS                           │
├───────────────────┬───────────────────────┬─────────────────────────────┤
│   Apple Watch     │   Samsung Galaxy      │   Xiaomi Band/Watch         │
│   (watchOS)       │   Watch (Wear OS)     │   (Proprietary + BLE)       │
└─────────┬─────────┴───────────┬───────────┴──────────────┬──────────────┘
          │                     │                          │
          ▼                     ▼                          ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        PLATFORM HEALTH APIS                             │
├───────────────────┬───────────────────────┬─────────────────────────────┤
│   Apple HealthKit │   Health Connect      │   Xiaomi Health (Mi Fit)    │
│   (iOS only)      │   (Android 14+)       │   + Direct BLE              │
└─────────┬─────────┴───────────┬───────────┴──────────────┬──────────────┘
          │                     │                          │
          ▼                     ▼                          ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    FLUTTER INTEGRATION LAYER                            │
├─────────────────────────────────────────────────────────────────────────┤
│  health: ^10.0.0  │  health_connect: ^2.0 │  flutter_blue_plus: ^1.4.0  │
│  (HealthKit +     │  (Health Connect      │  (Direct BLE for Xiaomi     │
│   Health Connect) │   Android-native)     │   PPG streaming)            │
└─────────┬─────────┴───────────┬───────────┴──────────────┬──────────────┘
          │                     │                          │
          └─────────────────────┼──────────────────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│               lib/health/services/wearable_health_service.dart          │
│                     (Unified abstraction layer)                         │
└─────────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│              lib/repositories/vitals_repository_hive.dart               │
│              lib/persistence/box_registry.dart (vitals_box)             │
└─────────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         UI CONSUMERS                                    │
├───────────────────┬───────────────────────┬─────────────────────────────┤
│   next_screen.dart│diagnostic_screen.dart │patient_sos_screen.dart      │
│   (Home vitals)   │(ECG/HRV analysis)     │(Real-time HR during SOS)    │
└───────────────────┴───────────────────────┴─────────────────────────────┘
```

---

## Implementation Plan

### Phase 1: Add Dependencies & Models

#### Step 1.1: Update pubspec.yaml

```yaml
dependencies:
  # Add health package (supports HealthKit + Health Connect)
  health: ^10.2.0
  
  # flutter_blue_plus already exists for direct BLE
  # flutter_blue_plus: ^1.4.0  # Already present
  
  # Permission handling
  permission_handler: ^11.0.0
```

#### Step 1.2: Extend VitalsModel

**File:** `lib/models/vitals_model.dart`

Add new fields to support richer health data:

```dart
class VitalsModel {
  // Existing fields...
  final String id;
  final String userId;
  final int heartRate;
  final int systolicBp;
  final int diastolicBp;
  final double? temperatureC;
  final int? oxygenPercent;      // SpO2 already supported
  final double? stressIndex;
  
  // NEW: Extended health data
  final List<int>? rrIntervals;          // R-R intervals in ms (HRV)
  final List<double>? ppgWaveform;       // Raw PPG signal samples
  final String? dataSource;              // 'apple_watch', 'samsung', 'xiaomi', 'manual'
  final String? deviceId;                // Specific device identifier
  final double? respiratoryRate;         // Breaths per minute
  final int? restingHeartRate;           // Resting HR if available
  final double? hrvSdnn;                 // HRV SDNN metric
  final DateTime recordedAt;
  // ...existing fields
}
```

#### Step 1.3: Create Sleep Data Model

**File:** `lib/models/sleep_model.dart`

```dart
/// Sleep data model for wearable sleep tracking.
///
/// Supports sleep stage classification from Apple Watch, Samsung, and Xiaomi.
library;

/// Sleep stage classification
enum SleepStage {
  awake,
  light,
  deep,
  rem,
  unknown,
}

/// Individual sleep segment
class SleepSegment {
  final DateTime startTime;
  final DateTime endTime;
  final SleepStage stage;
  
  const SleepSegment({
    required this.startTime,
    required this.endTime,
    required this.stage,
  });
  
  Duration get duration => endTime.difference(startTime);
}

/// Complete sleep session data
class SleepModel {
  final String id;
  final String userId;
  final DateTime sleepStart;
  final DateTime sleepEnd;
  final List<SleepSegment> segments;
  final int? sleepScore;           // 0-100 quality score
  final String dataSource;         // 'apple_watch', 'samsung', 'xiaomi'
  final DateTime createdAt;
  
  const SleepModel({
    required this.id,
    required this.userId,
    required this.sleepStart,
    required this.sleepEnd,
    required this.segments,
    this.sleepScore,
    required this.dataSource,
    required this.createdAt,
  });
  
  /// Total sleep duration
  Duration get totalDuration => sleepEnd.difference(sleepStart);
  
  /// Duration in specific stage
  Duration durationInStage(SleepStage stage) {
    return segments
        .where((s) => s.stage == stage)
        .fold(Duration.zero, (total, s) => total + s.duration);
  }
  
  /// Percentage of time in each stage
  Map<SleepStage, double> get stagePercentages {
    final total = totalDuration.inMinutes;
    if (total == 0) return {};
    
    return {
      for (final stage in SleepStage.values)
        stage: (durationInStage(stage).inMinutes / total) * 100,
    };
  }
}
```

---

### Phase 2: Platform-Specific Health Service

#### Step 2.1: Create Unified Health Service

**File:** `lib/health/services/wearable_health_service.dart`

```dart
/// WearableHealthService - Unified abstraction for wearable health data.
///
/// Supports:
/// - Apple Watch via HealthKit (iOS)
/// - Samsung Galaxy Watch via Health Connect (Android 14+)
/// - Xiaomi via Health Connect + direct BLE fallback
///
/// Pattern: Local-first
/// 1. Request data from platform API
/// 2. Store in Hive (VitalsModel, SleepModel)
/// 3. Notify UI via streams
library;

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import '../../models/vitals_model.dart';
import '../../models/sleep_model.dart';
import '../../repositories/vitals_repository.dart';
import '../repositories/sleep_repository.dart';

/// Supported wearable platforms
enum WearablePlatform {
  appleWatch,
  samsungGalaxy,
  xiaomi,
  unknown,
}

/// Health data availability result
class HealthDataAvailability {
  final bool heartRate;
  final bool heartRateVariability;
  final bool oxygenSaturation;
  final bool sleepAnalysis;
  final bool bloodPressure;
  final bool ecgAvailable;
  final WearablePlatform platform;
  
  const HealthDataAvailability({
    required this.heartRate,
    required this.heartRateVariability,
    required this.oxygenSaturation,
    required this.sleepAnalysis,
    required this.bloodPressure,
    required this.ecgAvailable,
    required this.platform,
  });
  
  static const none = HealthDataAvailability(
    heartRate: false,
    heartRateVariability: false,
    oxygenSaturation: false,
    sleepAnalysis: false,
    bloodPressure: false,
    ecgAvailable: false,
    platform: WearablePlatform.unknown,
  );
}

/// Unified wearable health service
class WearableHealthService {
  WearableHealthService._();
  
  static final WearableHealthService _instance = WearableHealthService._();
  static WearableHealthService get instance => _instance;
  
  final Health _health = Health();
  
  // Stream controllers for real-time data
  final _heartRateController = StreamController<int>.broadcast();
  final _oxygenController = StreamController<int>.broadcast();
  final _sleepController = StreamController<SleepModel>.broadcast();
  
  /// Stream of real-time heart rate updates
  Stream<int> get heartRateStream => _heartRateController.stream;
  
  /// Stream of SpO2 updates
  Stream<int> get oxygenStream => _oxygenController.stream;
  
  /// Stream of sleep data updates
  Stream<SleepModel> get sleepStream => _sleepController.stream;
  
  bool _isInitialized = false;
  HealthDataAvailability _availability = HealthDataAvailability.none;
  
  /// Check what health data is available on this device
  Future<HealthDataAvailability> checkAvailability() async {
    if (Platform.isIOS) {
      return _checkAppleHealthAvailability();
    } else if (Platform.isAndroid) {
      return _checkAndroidHealthAvailability();
    }
    return HealthDataAvailability.none;
  }
  
  /// Request permissions for health data access
  Future<bool> requestPermissions() async {
    debugPrint('[WearableHealthService] Requesting health permissions...');
    
    final types = <HealthDataType>[
      HealthDataType.HEART_RATE,
      HealthDataType.BLOOD_OXYGEN,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_AWAKE,
      HealthDataType.SLEEP_DEEP,
      HealthDataType.SLEEP_LIGHT,
      HealthDataType.SLEEP_REM,
      HealthDataType.HEART_RATE_VARIABILITY_SDNN,
      HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
      HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    ];
    
    // Add iOS-specific types
    if (Platform.isIOS) {
      types.addAll([
        HealthDataType.ELECTROCARDIOGRAM,
        HealthDataType.RESPIRATORY_RATE,
        HealthDataType.RESTING_HEART_RATE,
      ]);
    }
    
    try {
      final granted = await _health.requestAuthorization(types);
      debugPrint('[WearableHealthService] Permissions granted: $granted');
      _isInitialized = granted;
      return granted;
    } catch (e) {
      debugPrint('[WearableHealthService] Permission request failed: $e');
      return false;
    }
  }
  
  /// Fetch heart rate data for a time range
  Future<List<HealthDataPoint>> fetchHeartRateData({
    required DateTime start,
    required DateTime end,
  }) async {
    if (!_isInitialized) {
      debugPrint('[WearableHealthService] Not initialized, requesting permissions...');
      await requestPermissions();
    }
    
    try {
      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: start,
        endTime: end,
      );
      
      debugPrint('[WearableHealthService] Fetched ${data.length} heart rate points');
      return data;
    } catch (e) {
      debugPrint('[WearableHealthService] Failed to fetch heart rate: $e');
      return [];
    }
  }
  
  /// Fetch SpO2 data for a time range
  Future<List<HealthDataPoint>> fetchOxygenData({
    required DateTime start,
    required DateTime end,
  }) async {
    if (!_isInitialized) await requestPermissions();
    
    try {
      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.BLOOD_OXYGEN],
        startTime: start,
        endTime: end,
      );
      
      debugPrint('[WearableHealthService] Fetched ${data.length} SpO2 points');
      return data;
    } catch (e) {
      debugPrint('[WearableHealthService] Failed to fetch SpO2: $e');
      return [];
    }
  }
  
  /// Fetch sleep data for last night
  Future<SleepModel?> fetchLastNightSleep(String userId) async {
    if (!_isInitialized) await requestPermissions();
    
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(hours: 24));
    
    try {
      final sleepTypes = [
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_AWAKE,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_REM,
      ];
      
      final data = await _health.getHealthDataFromTypes(
        types: sleepTypes,
        startTime: yesterday,
        endTime: now,
      );
      
      if (data.isEmpty) return null;
      
      // Convert to SleepModel
      return _convertToSleepModel(userId, data);
    } catch (e) {
      debugPrint('[WearableHealthService] Failed to fetch sleep: $e');
      return null;
    }
  }
  
  /// Fetch HRV (Heart Rate Variability) data
  Future<List<double>> fetchHRVData({
    required DateTime start,
    required DateTime end,
  }) async {
    if (!_isInitialized) await requestPermissions();
    
    try {
      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE_VARIABILITY_SDNN],
        startTime: start,
        endTime: end,
      );
      
      return data.map((p) => (p.value as NumericHealthValue).numericValue.toDouble()).toList();
    } catch (e) {
      debugPrint('[WearableHealthService] Failed to fetch HRV: $e');
      return [];
    }
  }
  
  /// Convert and store vitals from health data points
  Future<void> syncVitalsToLocal({
    required String userId,
    required VitalsRepository repository,
  }) async {
    final now = DateTime.now();
    final oneHourAgo = now.subtract(const Duration(hours: 1));
    
    // Fetch recent data
    final heartRateData = await fetchHeartRateData(start: oneHourAgo, end: now);
    final oxygenData = await fetchOxygenData(start: oneHourAgo, end: now);
    
    if (heartRateData.isEmpty && oxygenData.isEmpty) {
      debugPrint('[WearableHealthService] No new health data to sync');
      return;
    }
    
    // Get latest values
    final latestHR = heartRateData.isNotEmpty
        ? (heartRateData.last.value as NumericHealthValue).numericValue.toInt()
        : null;
    final latestO2 = oxygenData.isNotEmpty
        ? (oxygenData.last.value as NumericHealthValue).numericValue.toInt()
        : null;
    
    if (latestHR != null || latestO2 != null) {
      final vital = VitalsModel(
        id: 'v_${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        heartRate: latestHR ?? 0,
        systolicBp: 0,  // Separate fetch needed
        diastolicBp: 0,
        oxygenPercent: latestO2,
        dataSource: _detectPlatformSource(),
        recordedAt: now,
        createdAt: now,
        updatedAt: now,
      );
      
      await repository.save(vital);
      debugPrint('[WearableHealthService] Synced vitals: HR=$latestHR, O2=$latestO2');
      
      // Emit to streams
      if (latestHR != null) _heartRateController.add(latestHR);
      if (latestO2 != null) _oxygenController.add(latestO2);
    }
  }
  
  // ══════════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ══════════════════════════════════════════════════════════════════════
  
  Future<HealthDataAvailability> _checkAppleHealthAvailability() async {
    // Apple Watch provides all data via HealthKit
    return const HealthDataAvailability(
      heartRate: true,
      heartRateVariability: true,
      oxygenSaturation: true,
      sleepAnalysis: true,
      bloodPressure: true,  // Manual entry supported
      ecgAvailable: true,   // Apple Watch Series 4+
      platform: WearablePlatform.appleWatch,
    );
  }
  
  Future<HealthDataAvailability> _checkAndroidHealthAvailability() async {
    // Check if Health Connect is available (Android 14+)
    final hasHealthConnect = await _health.hasPermissions(
      [HealthDataType.HEART_RATE],
    );
    
    return HealthDataAvailability(
      heartRate: hasHealthConnect ?? false,
      heartRateVariability: hasHealthConnect ?? false,
      oxygenSaturation: hasHealthConnect ?? false,
      sleepAnalysis: hasHealthConnect ?? false,
      bloodPressure: hasHealthConnect ?? false,
      ecgAvailable: false,  // ECG not standard on Android
      platform: WearablePlatform.samsungGalaxy,
    );
  }
  
  String _detectPlatformSource() {
    if (Platform.isIOS) return 'apple_watch';
    return 'health_connect';  // Samsung/Xiaomi via Health Connect
  }
  
  SleepModel? _convertToSleepModel(String userId, List<HealthDataPoint> data) {
    if (data.isEmpty) return null;
    
    // Sort by time
    data.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
    
    final segments = <SleepSegment>[];
    
    for (final point in data) {
      final stage = _healthTypeToSleepStage(point.type);
      segments.add(SleepSegment(
        startTime: point.dateFrom,
        endTime: point.dateTo,
        stage: stage,
      ));
    }
    
    return SleepModel(
      id: 'sleep_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      sleepStart: data.first.dateFrom,
      sleepEnd: data.last.dateTo,
      segments: segments,
      dataSource: _detectPlatformSource(),
      createdAt: DateTime.now(),
    );
  }
  
  SleepStage _healthTypeToSleepStage(HealthDataType type) {
    switch (type) {
      case HealthDataType.SLEEP_AWAKE:
        return SleepStage.awake;
      case HealthDataType.SLEEP_LIGHT:
        return SleepStage.light;
      case HealthDataType.SLEEP_DEEP:
        return SleepStage.deep;
      case HealthDataType.SLEEP_REM:
        return SleepStage.rem;
      default:
        return SleepStage.unknown;
    }
  }
  
  void dispose() {
    _heartRateController.close();
    _oxygenController.close();
    _sleepController.close();
  }
}
```

---

### Phase 3: Xiaomi Direct BLE Integration

Xiaomi devices (Mi Band, Amazfit) have limited Health Connect support. For real-time heart rate streaming, direct BLE is required.

#### Step 3.1: Xiaomi BLE Service

**File:** `lib/health/services/xiaomi_ble_service.dart`

```dart
/// XiaomiBLEService - Direct Bluetooth LE communication with Xiaomi wearables.
///
/// Supports real-time PPG (heart rate) streaming from:
/// - Mi Band 4/5/6/7/8
/// - Amazfit Bip/GTS/GTR series
///
/// Note: Requires device pairing via Mi Fitness app first.
library;

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Xiaomi BLE service UUIDs (reverse-engineered)
class XiaomiUUIDs {
  // Heart rate service (standard BLE HR profile)
  static const heartRateService = '0000180d-0000-1000-8000-00805f9b34fb';
  static const heartRateMeasurement = '00002a37-0000-1000-8000-00805f9b34fb';
  
  // Xiaomi proprietary service (for raw PPG on some devices)
  static const xiaomiService = '0000fee0-0000-1000-8000-00805f9b34fb';
  static const xiaomiNotify = '0000ff01-0000-1000-8000-00805f9b34fb';
  
  // Device info
  static const deviceInfoService = '0000180a-0000-1000-8000-00805f9b34fb';
}

/// Real-time heart rate data from Xiaomi device
class XiaomiHeartRateData {
  final int heartRate;
  final DateTime timestamp;
  final bool isContactDetected;
  final List<int>? rrIntervals;  // R-R intervals if available
  
  const XiaomiHeartRateData({
    required this.heartRate,
    required this.timestamp,
    this.isContactDetected = true,
    this.rrIntervals,
  });
}

/// Xiaomi BLE connection state
enum XiaomiConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  streaming,
  error,
}

/// Direct BLE service for Xiaomi wearables
class XiaomiBLEService {
  XiaomiBLEService._();
  
  static final XiaomiBLEService _instance = XiaomiBLEService._();
  static XiaomiBLEService get instance => _instance;
  
  BluetoothDevice? _connectedDevice;
  StreamSubscription<List<int>>? _heartRateSubscription;
  
  final _heartRateController = StreamController<XiaomiHeartRateData>.broadcast();
  final _stateController = StreamController<XiaomiConnectionState>.broadcast();
  
  /// Stream of real-time heart rate data
  Stream<XiaomiHeartRateData> get heartRateStream => _heartRateController.stream;
  
  /// Stream of connection state changes
  Stream<XiaomiConnectionState> get stateStream => _stateController.stream;
  
  XiaomiConnectionState _state = XiaomiConnectionState.disconnected;
  XiaomiConnectionState get state => _state;
  
  /// Scan for nearby Xiaomi devices
  Future<List<ScanResult>> scanForDevices({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    _setState(XiaomiConnectionState.scanning);
    
    final results = <ScanResult>[];
    
    try {
      await FlutterBluePlus.startScan(timeout: timeout);
      
      await for (final scanResults in FlutterBluePlus.scanResults) {
        for (final result in scanResults) {
          final name = result.device.platformName.toLowerCase();
          // Filter for Xiaomi/Amazfit devices
          if (name.contains('mi band') ||
              name.contains('amazfit') ||
              name.contains('xiaomi')) {
            if (!results.any((r) => r.device.remoteId == result.device.remoteId)) {
              results.add(result);
              debugPrint('[XiaomiBLE] Found device: ${result.device.platformName}');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[XiaomiBLE] Scan error: $e');
      _setState(XiaomiConnectionState.error);
    }
    
    await FlutterBluePlus.stopScan();
    _setState(XiaomiConnectionState.disconnected);
    
    return results;
  }
  
  /// Connect to a Xiaomi device and start heart rate streaming
  Future<bool> connectAndStream(BluetoothDevice device) async {
    _setState(XiaomiConnectionState.connecting);
    
    try {
      await device.connect(timeout: const Duration(seconds: 15));
      _connectedDevice = device;
      
      debugPrint('[XiaomiBLE] Connected to ${device.platformName}');
      _setState(XiaomiConnectionState.connected);
      
      // Discover services
      final services = await device.discoverServices();
      
      // Find heart rate service
      BluetoothService? hrService;
      for (final service in services) {
        if (service.uuid.toString().toLowerCase() == XiaomiUUIDs.heartRateService) {
          hrService = service;
          break;
        }
      }
      
      if (hrService == null) {
        debugPrint('[XiaomiBLE] Heart rate service not found');
        _setState(XiaomiConnectionState.error);
        return false;
      }
      
      // Find heart rate measurement characteristic
      BluetoothCharacteristic? hrChar;
      for (final char in hrService.characteristics) {
        if (char.uuid.toString().toLowerCase() == XiaomiUUIDs.heartRateMeasurement) {
          hrChar = char;
          break;
        }
      }
      
      if (hrChar == null) {
        debugPrint('[XiaomiBLE] Heart rate characteristic not found');
        _setState(XiaomiConnectionState.error);
        return false;
      }
      
      // Enable notifications
      await hrChar.setNotifyValue(true);
      
      // Subscribe to heart rate updates
      _heartRateSubscription = hrChar.onValueReceived.listen((value) {
        final data = _parseHeartRateData(value);
        if (data != null) {
          _heartRateController.add(data);
          debugPrint('[XiaomiBLE] HR: ${data.heartRate} BPM');
        }
      });
      
      _setState(XiaomiConnectionState.streaming);
      return true;
      
    } catch (e) {
      debugPrint('[XiaomiBLE] Connection error: $e');
      _setState(XiaomiConnectionState.error);
      return false;
    }
  }
  
  /// Disconnect from device
  Future<void> disconnect() async {
    await _heartRateSubscription?.cancel();
    _heartRateSubscription = null;
    
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
    }
    
    _setState(XiaomiConnectionState.disconnected);
  }
  
  /// Parse BLE heart rate measurement data per Bluetooth SIG spec
  XiaomiHeartRateData? _parseHeartRateData(List<int> data) {
    if (data.isEmpty) return null;
    
    final flags = data[0];
    final is16Bit = (flags & 0x01) != 0;
    final hasContact = (flags & 0x04) != 0;
    final hasRR = (flags & 0x10) != 0;
    
    int heartRate;
    int offset = 1;
    
    if (is16Bit) {
      if (data.length < 3) return null;
      heartRate = data[1] | (data[2] << 8);
      offset = 3;
    } else {
      heartRate = data[1];
      offset = 2;
    }
    
    // Parse R-R intervals if present
    List<int>? rrIntervals;
    if (hasRR && offset < data.length) {
      rrIntervals = [];
      while (offset + 1 < data.length) {
        final rr = data[offset] | (data[offset + 1] << 8);
        rrIntervals.add(rr);
        offset += 2;
      }
    }
    
    return XiaomiHeartRateData(
      heartRate: heartRate,
      timestamp: DateTime.now(),
      isContactDetected: !hasContact || (flags & 0x02) != 0,
      rrIntervals: rrIntervals,
    );
  }
  
  void _setState(XiaomiConnectionState newState) {
    _state = newState;
    _stateController.add(newState);
  }
  
  void dispose() {
    disconnect();
    _heartRateController.close();
    _stateController.close();
  }
}
```

---

### Phase 4: Platform Configuration

#### iOS Configuration (Info.plist)

```xml
<!-- Health data access -->
<key>NSHealthShareUsageDescription</key>
<string>Guardian Angel needs access to your health data to monitor your vitals and provide health insights.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>Guardian Angel may save health data to track your progress.</string>

<!-- Bluetooth (for Xiaomi BLE) -->
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Guardian Angel uses Bluetooth to connect to your wearable device for real-time health monitoring.</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>Guardian Angel needs Bluetooth to connect to your health devices.</string>

<!-- Background modes -->
<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
    <string>processing</string>
</array>

<!-- HealthKit capability -->
<key>com.apple.developer.healthkit</key>
<true/>
<key>com.apple.developer.healthkit.access</key>
<array>
    <string>health-records</string>
</array>
```

#### Android Configuration

**android/app/src/main/AndroidManifest.xml:**

```xml
<!-- Health Connect permissions -->
<uses-permission android:name="android.permission.health.READ_HEART_RATE"/>
<uses-permission android:name="android.permission.health.READ_BLOOD_OXYGEN"/>
<uses-permission android:name="android.permission.health.READ_SLEEP"/>
<uses-permission android:name="android.permission.health.READ_HEART_RATE_VARIABILITY"/>
<uses-permission android:name="android.permission.health.READ_BLOOD_PRESSURE"/>

<!-- Bluetooth permissions -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>

<!-- Health Connect activity -->
<activity
    android:name="androidx.health.connect.client.permission.HealthDataRequestPermissionsActivity"
    android:exported="true">
    <intent-filter>
        <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE"/>
    </intent-filter>
</activity>

<queries>
    <package android:name="com.google.android.apps.healthdata"/>
</queries>
```

---

### Phase 5: Wire to UI

#### Step 5.1: Create Health Provider

**File:** `lib/health/providers/wearable_health_provider.dart`

```dart
/// Riverpod providers for wearable health data.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/wearable_health_service.dart';
import '../services/xiaomi_ble_service.dart';

/// Provider for WearableHealthService singleton
final wearableHealthServiceProvider = Provider<WearableHealthService>((ref) {
  return WearableHealthService.instance;
});

/// Provider for XiaomiBLEService singleton
final xiaomiBleServiceProvider = Provider<XiaomiBLEService>((ref) {
  return XiaomiBLEService.instance;
});

/// Stream provider for real-time heart rate from platform APIs
final platformHeartRateStreamProvider = StreamProvider<int>((ref) {
  return ref.watch(wearableHealthServiceProvider).heartRateStream;
});

/// Stream provider for real-time heart rate from Xiaomi BLE
final xiaomiHeartRateStreamProvider = StreamProvider<XiaomiHeartRateData>((ref) {
  return ref.watch(xiaomiBleServiceProvider).heartRateStream;
});

/// Stream provider for Xiaomi connection state
final xiaomiConnectionStateProvider = StreamProvider<XiaomiConnectionState>((ref) {
  return ref.watch(xiaomiBleServiceProvider).stateStream;
});

/// Provider for health data availability check
final healthAvailabilityProvider = FutureProvider<HealthDataAvailability>((ref) {
  return ref.watch(wearableHealthServiceProvider).checkAvailability();
});
```

#### Step 5.2: Update Patient SOS Screen

**File:** `lib/screens/patient_sos/patient_sos_data_provider.dart`

Add connection to real heart rate service:

```dart
/// Connect to real services
Future<void> _connectToServices() async {
  // Connect to wearable health service
  final healthService = WearableHealthService.instance;
  
  // Try platform health API first (Apple/Samsung)
  _heartRateSubscription = healthService.heartRateStream.listen((hr) {
    onHeartRateUpdate(hr);
  });
  
  // Fallback to Xiaomi BLE if needed
  if (await healthService.checkAvailability() == HealthDataAvailability.none) {
    final xiaomiService = XiaomiBLEService.instance;
    if (xiaomiService.state == XiaomiConnectionState.streaming) {
      _heartRateSubscription = xiaomiService.heartRateStream.listen((data) {
        onHeartRateUpdate(data.heartRate);
      });
    }
  }
}
```

#### Step 5.3: Update Diagnostic Screen

**File:** `lib/screens/diagnostic/diagnostic_data_provider.dart`

```dart
/// Check if a wearable/ECG device is connected
Future<bool> _checkDeviceConnection() async {
  // Check platform health APIs
  final availability = await WearableHealthService.instance.checkAvailability();
  if (availability.heartRate) return true;
  
  // Check Xiaomi BLE
  if (XiaomiBLEService.instance.state == XiaomiConnectionState.streaming) {
    return true;
  }
  
  return false;
}

/// Load cached heart rate data from health service
Future<int?> _loadCachedHeartRate() async {
  final healthService = WearableHealthService.instance;
  final now = DateTime.now();
  final data = await healthService.fetchHeartRateData(
    start: now.subtract(const Duration(minutes: 5)),
    end: now,
  );
  
  if (data.isNotEmpty) {
    return (data.last.value as NumericHealthValue).numericValue.toInt();
  }
  return null;
}

/// Load sleep data from health service
Future<SleepQualityData?> _loadCachedSleepData() async {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  if (userId == null) return null;
  
  final sleep = await WearableHealthService.instance.fetchLastNightSleep(userId);
  if (sleep == null) return null;
  
  return SleepQualityData(
    qualityScore: sleep.sleepScore ?? 0,
    hoursSlept: sleep.totalDuration.inMinutes / 60,
    date: sleep.sleepStart,
    quality: _scoreToQuality(sleep.sleepScore),
  );
}

String? _scoreToQuality(int? score) {
  if (score == null) return null;
  if (score >= 80) return 'Good';
  if (score >= 60) return 'Fair';
  return 'Poor';
}
```

---

## Data Type Matrix

| Data Type | Apple Watch | Samsung Galaxy | Xiaomi | Storage |
|-----------|-------------|----------------|--------|---------|
| Heart Rate | HealthKit | Health Connect | BLE + Health Connect | `VitalsModel.heartRate` |
| SpO₂ | HealthKit | Health Connect | Health Connect | `VitalsModel.oxygenPercent` |
| R-R Intervals | HealthKit HRV | Health Connect HRV | BLE (some models) | `VitalsModel.rrIntervals` |
| Raw PPG | ❌ (not exposed) | ❌ (not exposed) | BLE (limited) | Custom model needed |
| ECG | HealthKit ECG | ❌ | ❌ | `DiagnosticState.ecgSamples` |
| Sleep Stages | HealthKit Sleep | Health Connect Sleep | Health Connect | `SleepModel` |
| Respiratory Rate | HealthKit | ❌ | ❌ | `VitalsModel.respiratoryRate` |

---

## Security Considerations

1. **Permission Scoping**: Request only the health data types actually needed
2. **Data Encryption**: All health data stored in Hive uses existing encryption layer
3. **User Consent**: Always show clear permission dialogs explaining data usage
4. **Data Retention**: Apply TTL compaction from `TtlCompactionService` to health data
5. **Audit Logging**: Log all health data access via existing `AuditLogService`

---

## Testing Strategy

1. **Unit Tests**: Mock health package responses
2. **Integration Tests**: Real device tests on iOS/Android
3. **BLE Tests**: Xiaomi device connection scenarios
4. **Offline Tests**: Verify Hive persistence when network unavailable

---

## Next Steps

1. [ ] Add `health: ^10.2.0` and `permission_handler: ^11.0.0` to pubspec.yaml
2. [ ] Create `lib/health/services/wearable_health_service.dart`
3. [ ] Create `lib/health/services/xiaomi_ble_service.dart`
4. [ ] Create `lib/models/sleep_model.dart`
5. [ ] Add Hive adapter for SleepModel
6. [ ] Update platform configurations (Info.plist, AndroidManifest.xml)
7. [ ] Wire providers to existing UI screens
8. [ ] Implement device pairing flow in Settings
9. [ ] Add background sync for periodic health data fetch

---

## References

- [health package](https://pub.dev/packages/health)
- [Health Connect API](https://developer.android.com/health-and-fitness/guides/health-connect)
- [Apple HealthKit](https://developer.apple.com/documentation/healthkit)
- [flutter_blue_plus](https://pub.dev/packages/flutter_blue_plus)
- [BLE Heart Rate Service Spec](https://www.bluetooth.com/specifications/specs/heart-rate-service-1-0/)
