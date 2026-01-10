/// GuardianService - Persistent guardian data service.
///
/// Uses SharedPreferences for simple JSON storage.
/// Matches the pattern of PatientService for consistency.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/guardian_model.dart';

/// Service for managing guardian persistence.
class GuardianService {
  static const String _keyGuardians = 'patient_guardians';

  static GuardianService? _instance;
  static GuardianService get instance => _instance ??= GuardianService._();
  GuardianService._();

  /// Get all guardians for a patient
  Future<List<GuardianModel>> getGuardians(String patientId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyGuardians);
      if (jsonStr == null || jsonStr.isEmpty) return [];

      final List<dynamic> jsonList = json.decode(jsonStr) as List<dynamic>;
      return jsonList
          .map((e) => GuardianModel.fromJson(e as Map<String, dynamic>))
          .where((g) => g.patientId == patientId)
          .toList()
        ..sort((a, b) {
          // Primary first, then by status (active before pending)
          if (a.isPrimary && !b.isPrimary) return -1;
          if (!a.isPrimary && b.isPrimary) return 1;
          return a.status.index.compareTo(b.status.index);
        });
    } catch (e) {
      debugPrint('[GuardianService] Error loading guardians: $e');
      return [];
    }
  }

  /// Get primary guardian for a patient
  Future<GuardianModel?> getPrimaryGuardian(String patientId) async {
    final guardians = await getGuardians(patientId);
    try {
      return guardians.firstWhere((g) => g.isPrimary);
    } catch (_) {
      // No primary guardian, return first active
      try {
        return guardians.firstWhere((g) => g.status == GuardianStatus.active);
      } catch (_) {
        return guardians.isNotEmpty ? guardians.first : null;
      }
    }
  }

  /// Save a guardian
  Future<bool> saveGuardian(GuardianModel guardian) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await _getAllGuardians();
      
      // If this guardian is marked as primary, unmark others
      if (guardian.isPrimary) {
        for (int i = 0; i < existing.length; i++) {
          if (existing[i].patientId == guardian.patientId && existing[i].isPrimary) {
            existing[i] = existing[i].copyWith(isPrimary: false);
          }
        }
      }
      
      // Remove existing if updating
      existing.removeWhere((g) => g.id == guardian.id);
      existing.add(guardian);

      final jsonStr = json.encode(existing.map((g) => g.toJson()).toList());
      await prefs.setString(_keyGuardians, jsonStr);
      debugPrint('[GuardianService] Saved guardian: ${guardian.name}');
      return true;
    } catch (e) {
      debugPrint('[GuardianService] Error saving guardian: $e');
      return false;
    }
  }

  /// Delete a guardian
  Future<bool> deleteGuardian(String guardianId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await _getAllGuardians();
      existing.removeWhere((g) => g.id == guardianId);

      final jsonStr = json.encode(existing.map((g) => g.toJson()).toList());
      await prefs.setString(_keyGuardians, jsonStr);
      debugPrint('[GuardianService] Deleted guardian: $guardianId');
      return true;
    } catch (e) {
      debugPrint('[GuardianService] Error deleting guardian: $e');
      return false;
    }
  }

  /// Update guardian status
  Future<bool> updateStatus(String guardianId, GuardianStatus status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await _getAllGuardians();
      
      final index = existing.indexWhere((g) => g.id == guardianId);
      if (index == -1) return false;

      existing[index] = existing[index].copyWith(status: status);
      
      final jsonStr = json.encode(existing.map((g) => g.toJson()).toList());
      await prefs.setString(_keyGuardians, jsonStr);
      debugPrint('[GuardianService] Updated guardian status: $guardianId -> $status');
      return true;
    } catch (e) {
      debugPrint('[GuardianService] Error updating status: $e');
      return false;
    }
  }

  /// Set a guardian as primary
  Future<bool> setPrimary(String patientId, String guardianId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await _getAllGuardians();
      
      // Unmark all others for this patient
      for (int i = 0; i < existing.length; i++) {
        if (existing[i].patientId == patientId) {
          existing[i] = existing[i].copyWith(
            isPrimary: existing[i].id == guardianId,
          );
        }
      }
      
      final jsonStr = json.encode(existing.map((g) => g.toJson()).toList());
      await prefs.setString(_keyGuardians, jsonStr);
      debugPrint('[GuardianService] Set primary guardian: $guardianId');
      return true;
    } catch (e) {
      debugPrint('[GuardianService] Error setting primary: $e');
      return false;
    }
  }

  /// Get all guardians (internal helper)
  Future<List<GuardianModel>> _getAllGuardians() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyGuardians);
      if (jsonStr == null || jsonStr.isEmpty) return [];

      final List<dynamic> jsonList = json.decode(jsonStr) as List<dynamic>;
      return jsonList
          .map((e) => GuardianModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[GuardianService] Error loading all guardians: $e');
      return [];
    }
  }
}
