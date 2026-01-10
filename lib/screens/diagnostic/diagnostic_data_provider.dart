/// DiagnosticDataProvider - Loads diagnostic data from local sources.
///
/// This service reads from:
/// - Device connection status (Bluetooth/wearable)
/// - Local Hive storage for cached diagnostic data (from Apple Health)
/// - Arrhythmia analysis results
///
/// All reads are LOCAL ONLY. No network calls.
/// Supports Demo Mode for showcasing UI with sample data.
/// NO simulated data when demo mode is off. NO timers. NO random values.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../services/demo_mode_service.dart';
import '../../services/demo_data.dart';
import '../../health/repositories/health_data_repository_hive.dart';
import '../../ml/services/arrhythmia_analysis_service.dart';
import '../../ml/models/arrhythmia_risk_level.dart';
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

  late final HealthDataRepositoryHive _healthRepo = HealthDataRepositoryHive();
  final ArrhythmiaAnalysisService _arrhythmiaService = ArrhythmiaAnalysisService();

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
      
      // Get current user UID
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        debugPrint('[DiagnosticDataProvider] No user logged in - returning empty state');
        return DiagnosticState.initial();
      }

      // Load real data from health repository
      return await _loadRealDiagnosticData(uid);
      
    } catch (e) {
      debugPrint('[DiagnosticDataProvider] Error loading state: $e');
      return DiagnosticState.initial();
    }
  }

  /// Load real diagnostic data from HealthDataRepositoryHive
  Future<DiagnosticState> _loadRealDiagnosticData(String patientUid) async {
    debugPrint('[DiagnosticDataProvider] Loading real data for $patientUid...');
    
    try {
      // Get latest vitals snapshot from health repository
      final snapshot = await _healthRepo.getLatestVitals(patientUid);
      
      // Extract heart rate using convenience getter
      final heartRate = snapshot.heartRateBpm;
      
      // Extract oxygen saturation using convenience getter
      OxygenSaturationData? oxygenSaturation;
      final oxygenPercent = snapshot.oxygenPercentage;
      if (oxygenPercent != null && snapshot.latestOxygen != null) {
        oxygenSaturation = OxygenSaturationData(
          percent: oxygenPercent,
          measurementTime: snapshot.latestOxygen!.recordedAt,
          status: _getOxygenStatus(oxygenPercent),
        );
      }
      
      // Extract HRV and RR intervals from data map
      List<int>? rrIntervals;
      if (snapshot.latestHRV != null) {
        final rrData = snapshot.latestHRV!.data['rrIntervals'];
        if (rrData is List) {
          rrIntervals = rrData.cast<int>().toList();
        }
      }
      
      // Extract sleep data from data map
      SleepQualityData? sleepData;
      if (snapshot.latestSleep != null) {
        final sleepStart = snapshot.latestSleep!.data['sleepStart'];
        final sleepEnd = snapshot.latestSleep!.data['sleepEnd'];
        if (sleepStart != null && sleepEnd != null) {
          final start = DateTime.parse(sleepStart as String);
          final end = DateTime.parse(sleepEnd as String);
          final hours = end.difference(start).inMinutes / 60.0;
          sleepData = SleepQualityData(
            qualityScore: (hours >= 7 ? 80 : hours >= 5 ? 60 : 40).toInt(),
            hoursSlept: hours,
            date: start,
            quality: hours >= 7 ? 'Good' : hours >= 5 ? 'Fair' : 'Poor',
          );
        }
      }
      
      // Get heart rhythm from arrhythmia analysis (cached result)
      String? heartRhythm;
      double? aiConfidence;
      final cachedAnalysis = _arrhythmiaService.cachedAnalysis;
      if (cachedAnalysis != null) {
        heartRhythm = cachedAnalysis.analysis.heartRhythmDescription;
        // Convert enum confidence to numeric value (0.0 - 1.0)
        aiConfidence = switch (cachedAnalysis.analysis.confidence) {
          ArrhythmiaConfidence.high => 0.95,
          ArrhythmiaConfidence.medium => 0.75,
          ArrhythmiaConfidence.low => 0.50,
        };
      }
      
      // Determine if we have any data
      final hasAnyData = heartRate != null || 
          oxygenSaturation != null || 
          sleepData != null ||
          rrIntervals != null;
      
      debugPrint('[DiagnosticDataProvider] Loaded: HR=$heartRate, O2=${oxygenSaturation?.percent}, Sleep=${sleepData?.hoursSlept}');
      
      return DiagnosticState(
        hasDeviceConnected: hasAnyData, // If we have data, health app is "connected"
        hasAnyDiagnosticData: hasAnyData,
        heartRate: heartRate,
        rrIntervals: rrIntervals,
        heartRhythm: heartRhythm,
        aiConfidence: aiConfidence,
        oxygenSaturation: oxygenSaturation,
        sleep: sleepData,
        hasDiagnosticHistory: hasAnyData,
      );
      
    } catch (e) {
      debugPrint('[DiagnosticDataProvider] Error loading real data: $e');
      return DiagnosticState.initial();
    }
  }

  /// Get oxygen status based on percentage
  String _getOxygenStatus(int percent) {
    if (percent >= 95) return 'Normal';
    if (percent >= 90) return 'Low';
    return 'Critical';
  }

  /// Load complete diagnostic data when device is connected
  /// 
  /// This is called when we know a device is connected and want
  /// to fetch all available data.
  Future<DiagnosticState> loadFullDiagnosticData() async {
    debugPrint('[DiagnosticDataProvider] Loading full diagnostic data...');
    
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return DiagnosticState.initial();
    }
    
    return _loadRealDiagnosticData(uid);
  }
}
