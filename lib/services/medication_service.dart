/// MedicationService - Persistent medication data service.
///
/// Uses SharedPreferences for simple JSON storage.
/// Matches the pattern of PatientService for consistency.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/medication_model.dart';

/// Service for managing medication persistence.
class MedicationService {
  static const String _keyMedications = 'patient_medications';

  static MedicationService? _instance;
  static MedicationService get instance => _instance ??= MedicationService._();
  MedicationService._();

  /// Get all medications for a patient (excludes soft-deleted)
  Future<List<MedicationModel>> getMedications(String patientId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyMedications);
      if (jsonStr == null || jsonStr.isEmpty) return [];

      final List<dynamic> jsonList = json.decode(jsonStr) as List<dynamic>;
      return jsonList
          .map((e) => MedicationModel.fromJson(e as Map<String, dynamic>))
          .where((m) => m.patientId == patientId && !m.isDeleted) // Critical Issue #10: Exclude soft-deleted
          .toList()
        ..sort((a, b) => a.time.compareTo(b.time));
    } catch (e) {
      debugPrint('[MedicationService] Error loading medications: $e');
      return [];
    }
  }

  /// Save a medication
  Future<bool> saveMedication(MedicationModel medication) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await _getAllMedications();
      
      // Remove existing if updating
      existing.removeWhere((m) => m.id == medication.id);
      existing.add(medication);

      final jsonStr = json.encode(existing.map((m) => m.toJson()).toList());
      await prefs.setString(_keyMedications, jsonStr);
      debugPrint('[MedicationService] Saved medication: ${medication.name}');
      return true;
    } catch (e) {
      debugPrint('[MedicationService] Error saving medication: $e');
      return false;
    }
  }

  /// Soft delete a medication (Critical Issue #10: Enable undo)
  Future<bool> deleteMedication(String medicationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await _getAllMedications();
      
      final index = existing.indexWhere((m) => m.id == medicationId);
      if (index == -1) return false;
      
      // Soft delete instead of hard delete
      existing[index] = existing[index].copyWith(
        isDeleted: true,
        deletedAt: DateTime.now().toUtc(),
      );

      final jsonStr = json.encode(existing.map((m) => m.toJson()).toList());
      await prefs.setString(_keyMedications, jsonStr);
      debugPrint('[MedicationService] Soft deleted medication: $medicationId');
      return true;
    } catch (e) {
      debugPrint('[MedicationService] Error deleting medication: $e');
      return false;
    }
  }
  
  /// Restore a soft-deleted medication (Critical Issue #10: Undo support)
  Future<bool> restoreMedication(String medicationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await _getAllMedications();
      
      final index = existing.indexWhere((m) => m.id == medicationId);
      if (index == -1) return false;
      
      existing[index] = existing[index].copyWith(
        isDeleted: false,
        deletedAt: null,
      );

      final jsonStr = json.encode(existing.map((m) => m.toJson()).toList());
      await prefs.setString(_keyMedications, jsonStr);
      debugPrint('[MedicationService] Restored medication: $medicationId');
      return true;
    } catch (e) {
      debugPrint('[MedicationService] Error restoring medication: $e');
      return false;
    }
  }
  
  /// Permanently delete a medication (hard delete)
  Future<bool> permanentlyDeleteMedication(String medicationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await _getAllMedications();
      existing.removeWhere((m) => m.id == medicationId);

      final jsonStr = json.encode(existing.map((m) => m.toJson()).toList());
      await prefs.setString(_keyMedications, jsonStr);
      debugPrint('[MedicationService] Permanently deleted medication: $medicationId');
      return true;
    } catch (e) {
      debugPrint('[MedicationService] Error permanently deleting medication: $e');
      return false;
    }
  }
  
  /// Get recently deleted medications (for undo feature)
  Future<List<MedicationModel>> getDeletedMedications(String patientId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyMedications);
      if (jsonStr == null || jsonStr.isEmpty) return [];

      final List<dynamic> jsonList = json.decode(jsonStr) as List<dynamic>;
      final now = DateTime.now().toUtc();
      
      return jsonList
          .map((e) => MedicationModel.fromJson(e as Map<String, dynamic>))
          .where((m) => 
              m.patientId == patientId && 
              m.isDeleted && 
              m.deletedAt != null &&
              now.difference(m.deletedAt!).inDays < 30) // Keep deleted for 30 days
          .toList();
    } catch (e) {
      debugPrint('[MedicationService] Error loading deleted medications: $e');
      return [];
    }
  }
  
  /// Clean up old soft-deleted medications (older than 30 days)
  Future<void> cleanupDeletedMedications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await _getAllMedications();
      final now = DateTime.now().toUtc();
      
      existing.removeWhere((m) => 
          m.isDeleted && 
          m.deletedAt != null && 
          now.difference(m.deletedAt!).inDays >= 30);

      final jsonStr = json.encode(existing.map((m) => m.toJson()).toList());
      await prefs.setString(_keyMedications, jsonStr);
      debugPrint('[MedicationService] Cleaned up old deleted medications');
    } catch (e) {
      debugPrint('[MedicationService] Error cleaning up medications: $e');
    }
  }

  /// Mark medication as taken/not taken
  Future<bool> toggleMedicationTaken(String medicationId, bool isTaken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await _getAllMedications();
      
      final index = existing.indexWhere((m) => m.id == medicationId);
      if (index == -1) return false;

      existing[index] = existing[index].copyWith(isTaken: isTaken);
      
      final jsonStr = json.encode(existing.map((m) => m.toJson()).toList());
      await prefs.setString(_keyMedications, jsonStr);
      debugPrint('[MedicationService] Toggled medication taken: $medicationId -> $isTaken');
      return true;
    } catch (e) {
      debugPrint('[MedicationService] Error toggling medication: $e');
      return false;
    }
  }

  /// Update medication stock
  Future<bool> updateStock(String medicationId, int newStock) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await _getAllMedications();
      
      final index = existing.indexWhere((m) => m.id == medicationId);
      if (index == -1) return false;

      existing[index] = existing[index].copyWith(currentStock: newStock);
      
      final jsonStr = json.encode(existing.map((m) => m.toJson()).toList());
      await prefs.setString(_keyMedications, jsonStr);
      debugPrint('[MedicationService] Updated stock: $medicationId -> $newStock');
      return true;
    } catch (e) {
      debugPrint('[MedicationService] Error updating stock: $e');
      return false;
    }
  }

  /// Get all medications (internal helper)
  Future<List<MedicationModel>> _getAllMedications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyMedications);
      if (jsonStr == null || jsonStr.isEmpty) return [];

      final List<dynamic> jsonList = json.decode(jsonStr) as List<dynamic>;
      return jsonList
          .map((e) => MedicationModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[MedicationService] Error loading all medications: $e');
      return [];
    }
  }

  /// Clear all medications for a patient
  Future<bool> clearMedications(String patientId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await _getAllMedications();
      existing.removeWhere((m) => m.patientId == patientId);

      final jsonStr = json.encode(existing.map((m) => m.toJson()).toList());
      await prefs.setString(_keyMedications, jsonStr);
      debugPrint('[MedicationService] Cleared medications for: $patientId');
      return true;
    } catch (e) {
      debugPrint('[MedicationService] Error clearing medications: $e');
      return false;
    }
  }
}
