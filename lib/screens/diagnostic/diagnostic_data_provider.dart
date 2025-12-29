/// DiagnosticDataProvider - Loads diagnostic data from local sources.
///
/// This service reads from:
/// - Device connection status (Bluetooth/wearable)
/// - Local Hive storage for cached diagnostic data
/// - Future: Real-time device data streams
///
/// All reads are LOCAL ONLY. No network calls.
/// Supports Demo Mode for showcasing UI with sample data.
/// NO simulated data when demo mode is off. NO timers. NO random values.
library;

import 'package:flutter/foundation.dart';
import '../../services/demo_mode_service.dart';
import '../../services/demo_data.dart';
import 'diagnostic_state.dart';

/// Provider for loading diagnostic screen data.
/// 
/// For first-time users with no connected devices,
/// this returns DiagnosticState.initial() with all null values.
/// When Demo Mode is enabled, returns sample data for showcasing UI.
class DiagnosticDataProvider {
  DiagnosticDataProvider._();
  
  static DiagnosticDataProvider? _instance;
  static DiagnosticDataProvider get instance => 
      _instance ??= DiagnosticDataProvider._();

  /// Load initial diagnostic state from local sources.
  /// Returns demo data if Demo Mode is enabled.
  /// 
  /// Returns [DiagnosticState] with:
  /// - Device connection status
  /// - Any cached diagnostic data
  /// - Diagnostic history availability
  /// 
  /// For first-time users: returns DiagnosticState.initial()
  Future<DiagnosticState> loadInitialState() async {
    debugPrint('[DiagnosticDataProvider] Loading initial state...');
    
    try {
      // Check if demo mode is enabled
      await DemoModeService.instance.initialize();
      if (DemoModeService.instance.isEnabled) {
        debugPrint('[DiagnosticDataProvider] Demo mode enabled - returning demo data');
        return DiagnosticDemoData.state;
      }
      
      // Load real data
      // Check if any device is connected
      final hasDevice = await _checkDeviceConnection();
      
      if (!hasDevice) {
        debugPrint('[DiagnosticDataProvider] No device connected - returning empty state');
        return DiagnosticState.initial();
      }
      
      // If device is connected, load any available data
      // For now, we don't have real device integration, so return empty
      debugPrint('[DiagnosticDataProvider] Device connected but no data yet');
      return const DiagnosticState(
        hasDeviceConnected: true,
        hasAnyDiagnosticData: false,
        hasDiagnosticHistory: false,
      );
      
    } catch (e) {
      debugPrint('[DiagnosticDataProvider] Error loading state: $e');
      return DiagnosticState.initial();
    }
  }

  /// Check if a wearable/ECG device is connected
  /// 
  /// TODO: Replace with actual device connection check when available
  Future<bool> _checkDeviceConnection() async {
    // For now, no device integration exists
    // Return false - no device connected
    return false;
  }

  /// Load cached heart rate data from local storage
  /// 
  /// TODO: Replace with actual Hive/local storage when available
  Future<int?> _loadCachedHeartRate() async {
    // No local storage for heart rate yet
    return null;
  }

  /// Load cached R-R intervals from local storage
  /// 
  /// TODO: Replace with actual Hive/local storage when available
  Future<List<int>?> _loadCachedRRIntervals() async {
    // No local storage for R-R intervals yet
    return null;
  }

  /// Load cached ECG samples from local storage
  /// 
  /// TODO: Replace with actual Hive/local storage when available
  Future<List<double>?> _loadCachedECGSamples() async {
    // No local storage for ECG samples yet
    return null;
  }

  /// Load cached blood pressure from local storage
  /// 
  /// TODO: Replace with actual Hive/local storage when available
  Future<BloodPressureData?> _loadCachedBloodPressure() async {
    // No local storage for blood pressure yet
    return null;
  }

  /// Load cached temperature from local storage
  /// 
  /// TODO: Replace with actual Hive/local storage when available
  Future<TemperatureData?> _loadCachedTemperature() async {
    // No local storage for temperature yet
    return null;
  }

  /// Load cached sleep data from local storage
  /// 
  /// TODO: Replace with actual Hive/local storage when available
  Future<SleepQualityData?> _loadCachedSleepData() async {
    // No local storage for sleep data yet
    return null;
  }

  /// Check if user has any diagnostic history
  /// 
  /// TODO: Replace with actual history check when available
  Future<bool> _checkDiagnosticHistory() async {
    // No diagnostic history system yet
    return false;
  }

  /// Load complete diagnostic data when device is connected
  /// 
  /// This is called when we know a device is connected and want
  /// to fetch all available data.
  Future<DiagnosticState> loadFullDiagnosticData() async {
    debugPrint('[DiagnosticDataProvider] Loading full diagnostic data...');
    
    final hasDevice = await _checkDeviceConnection();
    if (!hasDevice) {
      return DiagnosticState.initial();
    }

    // Load all cached data in parallel
    final results = await Future.wait([
      _loadCachedHeartRate(),
      _loadCachedRRIntervals(),
      _loadCachedECGSamples(),
      _loadCachedBloodPressure(),
      _loadCachedTemperature(),
      _loadCachedSleepData(),
      _checkDiagnosticHistory(),
    ]);

    final heartRate = results[0] as int?;
    final rrIntervals = results[1] as List<int>?;
    final ecgSamples = results[2] as List<double>?;
    final bloodPressure = results[3] as BloodPressureData?;
    final temperature = results[4] as TemperatureData?;
    final sleep = results[5] as SleepQualityData?;
    final hasHistory = results[6] as bool;

    // Determine if we have any diagnostic data
    final hasAnyData = heartRate != null ||
        (rrIntervals != null && rrIntervals.isNotEmpty) ||
        (ecgSamples != null && ecgSamples.isNotEmpty) ||
        bloodPressure != null ||
        temperature != null ||
        sleep != null;

    return DiagnosticState(
      hasDeviceConnected: true,
      hasAnyDiagnosticData: hasAnyData,
      heartRate: heartRate,
      rrIntervals: rrIntervals,
      ecgSamples: ecgSamples,
      bloodPressure: bloodPressure,
      temperature: temperature,
      sleep: sleep,
      hasDiagnosticHistory: hasHistory,
      // AI analysis fields remain null until real AI is integrated
    );
  }
}
