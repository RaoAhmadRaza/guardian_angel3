/// HealthThresholdService - Persistent health threshold settings service.
///
/// Uses SharedPreferences for simple JSON storage.
/// Matches the pattern of PatientService for consistency.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/health_threshold_model.dart';

/// Service for managing health threshold persistence.
class HealthThresholdService {
  static const String _keyThresholds = 'patient_health_thresholds';

  static HealthThresholdService? _instance;
  static HealthThresholdService get instance => _instance ??= HealthThresholdService._();
  HealthThresholdService._();

  /// Get thresholds for a patient (returns defaults if not set)
  Future<HealthThresholdModel> getThresholds(String patientId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyThresholds);
      if (jsonStr == null || jsonStr.isEmpty) {
        return HealthThresholdModel.defaults(patientId);
      }

      final List<dynamic> jsonList = json.decode(jsonStr) as List<dynamic>;
      final thresholds = jsonList
          .map((e) => HealthThresholdModel.fromJson(e as Map<String, dynamic>))
          .where((t) => t.patientId == patientId)
          .toList();

      if (thresholds.isEmpty) {
        return HealthThresholdModel.defaults(patientId);
      }
      return thresholds.first;
    } catch (e) {
      debugPrint('[HealthThresholdService] Error loading thresholds: $e');
      return HealthThresholdModel.defaults(patientId);
    }
  }

  /// Save thresholds
  Future<bool> saveThresholds(HealthThresholdModel thresholds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await _getAllThresholds();
      
      // Remove existing for this patient
      existing.removeWhere((t) => t.patientId == thresholds.patientId);
      existing.add(thresholds);

      final jsonStr = json.encode(existing.map((t) => t.toJson()).toList());
      await prefs.setString(_keyThresholds, jsonStr);
      debugPrint('[HealthThresholdService] Saved thresholds for: ${thresholds.patientId}');
      return true;
    } catch (e) {
      debugPrint('[HealthThresholdService] Error saving thresholds: $e');
      return false;
    }
  }

  /// Update heart rate range
  Future<bool> updateHeartRateRange(String patientId, int min, int max) async {
    final current = await getThresholds(patientId);
    final updated = current.copyWith(heartRateMin: min, heartRateMax: max);
    return saveThresholds(updated);
  }

  /// Toggle fall detection
  Future<bool> toggleFallDetection(String patientId, bool enabled) async {
    final current = await getThresholds(patientId);
    final updated = current.copyWith(fallDetectionEnabled: enabled);
    return saveThresholds(updated);
  }

  /// Toggle inactivity alert
  Future<bool> toggleInactivityAlert(String patientId, bool enabled) async {
    final current = await getThresholds(patientId);
    final updated = current.copyWith(inactivityAlertEnabled: enabled);
    return saveThresholds(updated);
  }

  /// Update inactivity hours
  Future<bool> updateInactivityHours(String patientId, double hours) async {
    final current = await getThresholds(patientId);
    final updated = current.copyWith(inactivityHours: hours);
    return saveThresholds(updated);
  }

  /// Get all thresholds (internal helper)
  Future<List<HealthThresholdModel>> _getAllThresholds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyThresholds);
      if (jsonStr == null || jsonStr.isEmpty) return [];

      final List<dynamic> jsonList = json.decode(jsonStr) as List<dynamic>;
      return jsonList
          .map((e) => HealthThresholdModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[HealthThresholdService] Error loading all thresholds: $e');
      return [];
    }
  }

  /// Check if heart rate is within safe range
  bool isHeartRateSafe(HealthThresholdModel thresholds, int heartRate) {
    return heartRate >= thresholds.heartRateMin && heartRate <= thresholds.heartRateMax;
  }

  /// Check if blood pressure is within safe range
  bool isBloodPressureSafe(HealthThresholdModel thresholds, int systolic, int diastolic) {
    return systolic <= thresholds.systolicBpMax && diastolic <= thresholds.diastolicBpMax;
  }

  /// Check if oxygen level is safe
  bool isOxygenSafe(HealthThresholdModel thresholds, int oxygenPercent) {
    return oxygenPercent >= thresholds.oxygenMin;
  }
}
