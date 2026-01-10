/// EmergencyContactService - Persistent emergency contact data service.
///
/// Uses SharedPreferences for simple JSON storage.
/// Matches the pattern of PatientService for consistency.
library;

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/emergency_contact_model.dart';

/// Service for managing emergency contact persistence.
class EmergencyContactService {
  static const String _keyEmergencyContacts = 'patient_emergency_contacts';

  static EmergencyContactService? _instance;
  static EmergencyContactService get instance => _instance ??= EmergencyContactService._();
  EmergencyContactService._();

  /// Get all emergency contacts for a patient (sorted by priority)
  Future<List<EmergencyContactModel>> getContacts(String patientId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyEmergencyContacts);
      if (jsonStr == null || jsonStr.isEmpty) return [];

      final List<dynamic> jsonList = json.decode(jsonStr) as List<dynamic>;
      return jsonList
          .map((e) => EmergencyContactModel.fromJson(e as Map<String, dynamic>))
          .where((c) => c.patientId == patientId && c.isEnabled)
          .toList()
        ..sort((a, b) => a.priority.compareTo(b.priority));
    } catch (e) {
      debugPrint('[EmergencyContactService] Error loading contacts: $e');
      return [];
    }
  }

  /// Get contacts that should be notified during SOS
  Future<List<EmergencyContactModel>> getSOSContacts(String patientId) async {
    final contacts = await getContacts(patientId);
    return contacts.where((c) => c.isEnabled).toList();
  }

  /// Save an emergency contact
  Future<bool> saveContact(EmergencyContactModel contact) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await _getAllContacts();
      
      // Remove existing if updating
      existing.removeWhere((c) => c.id == contact.id);
      existing.add(contact);

      final jsonStr = json.encode(existing.map((c) => c.toJson()).toList());
      await prefs.setString(_keyEmergencyContacts, jsonStr);
      debugPrint('[EmergencyContactService] Saved contact: ${contact.name}');
      return true;
    } catch (e) {
      debugPrint('[EmergencyContactService] Error saving contact: $e');
      return false;
    }
  }

  /// Delete an emergency contact
  Future<bool> deleteContact(String contactId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await _getAllContacts();
      existing.removeWhere((c) => c.id == contactId);

      final jsonStr = json.encode(existing.map((c) => c.toJson()).toList());
      await prefs.setString(_keyEmergencyContacts, jsonStr);
      debugPrint('[EmergencyContactService] Deleted contact: $contactId');
      return true;
    } catch (e) {
      debugPrint('[EmergencyContactService] Error deleting contact: $e');
      return false;
    }
  }

  /// Update contact priority
  Future<bool> updatePriority(String contactId, int newPriority) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await _getAllContacts();
      
      final index = existing.indexWhere((c) => c.id == contactId);
      if (index == -1) return false;

      existing[index] = existing[index].copyWith(priority: newPriority);
      
      final jsonStr = json.encode(existing.map((c) => c.toJson()).toList());
      await prefs.setString(_keyEmergencyContacts, jsonStr);
      debugPrint('[EmergencyContactService] Updated priority: $contactId -> $newPriority');
      return true;
    } catch (e) {
      debugPrint('[EmergencyContactService] Error updating priority: $e');
      return false;
    }
  }

  /// Reorder contacts (update priorities based on list order)
  Future<bool> reorderContacts(String patientId, List<String> orderedIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await _getAllContacts();
      
      for (int i = 0; i < orderedIds.length; i++) {
        final index = existing.indexWhere((c) => c.id == orderedIds[i]);
        if (index != -1) {
          existing[index] = existing[index].copyWith(priority: i);
        }
      }
      
      final jsonStr = json.encode(existing.map((c) => c.toJson()).toList());
      await prefs.setString(_keyEmergencyContacts, jsonStr);
      debugPrint('[EmergencyContactService] Reordered ${orderedIds.length} contacts');
      return true;
    } catch (e) {
      debugPrint('[EmergencyContactService] Error reordering: $e');
      return false;
    }
  }

  /// Toggle contact enabled/disabled
  Future<bool> toggleEnabled(String contactId, bool isEnabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await _getAllContacts();
      
      final index = existing.indexWhere((c) => c.id == contactId);
      if (index == -1) return false;

      existing[index] = existing[index].copyWith(isEnabled: isEnabled);
      
      final jsonStr = json.encode(existing.map((c) => c.toJson()).toList());
      await prefs.setString(_keyEmergencyContacts, jsonStr);
      debugPrint('[EmergencyContactService] Toggled enabled: $contactId -> $isEnabled');
      return true;
    } catch (e) {
      debugPrint('[EmergencyContactService] Error toggling enabled: $e');
      return false;
    }
  }

  /// Get all contacts (internal helper)
  Future<List<EmergencyContactModel>> _getAllContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyEmergencyContacts);
      if (jsonStr == null || jsonStr.isEmpty) return [];

      final List<dynamic> jsonList = json.decode(jsonStr) as List<dynamic>;
      return jsonList
          .map((e) => EmergencyContactModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[EmergencyContactService] Error loading all contacts: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AUTO-ADD LINKED CAREGIVER/DOCTOR AS EMERGENCY CONTACT
  // ═══════════════════════════════════════════════════════════════════════════

  /// Adds a linked caregiver as an emergency contact for the patient.
  /// 
  /// Called automatically when a caregiver accepts a patient's invite.
  /// Fetches the caregiver's phone number from Firestore and creates
  /// an emergency contact entry.
  /// 
  /// Returns true if successful, false if failed or already exists.
  Future<bool> addLinkedCaregiverAsEmergencyContact({
    required String patientId,
    required String caregiverId,
  }) async {
    debugPrint('[EmergencyContactService] Adding linked caregiver $caregiverId as emergency contact for patient $patientId');
    
    try {
      // Fetch caregiver details from Firestore
      final caregiverDoc = await FirebaseFirestore.instance
          .collection('caregiver_users')
          .doc(caregiverId)
          .get();
      
      if (!caregiverDoc.exists) {
        debugPrint('[EmergencyContactService] Caregiver document not found: $caregiverId');
        return false;
      }
      
      final data = caregiverDoc.data()!;
      final phoneNumber = data['phone_number'] as String? ?? '';
      final caregiverName = data['caregiver_name'] as String? ?? 
                           data['full_name'] as String? ?? 
                           'Caregiver';
      final relation = data['relation_to_patient'] as String? ?? 'Caregiver';
      
      if (phoneNumber.isEmpty) {
        debugPrint('[EmergencyContactService] Caregiver has no phone number');
        return false;
      }
      
      // Get existing contacts to check for duplicates and determine priority
      final existing = await getContacts(patientId);
      
      // Check if this phone number already exists
      final phoneExists = existing.any((c) => c.phoneNumber == phoneNumber);
      if (phoneExists) {
        debugPrint('[EmergencyContactService] Phone number already in emergency contacts');
        return true; // Already exists, consider it success
      }
      
      // Create emergency contact
      final contact = EmergencyContactModel.create(
        patientId: patientId,
        name: '$caregiverName ($relation)',
        phoneNumber: phoneNumber,
        type: EmergencyContactType.family,
        priority: existing.isEmpty ? 0 : existing.length, // Add at end
      );
      
      final saved = await saveContact(contact);
      debugPrint('[EmergencyContactService] Caregiver added as emergency contact: $saved');
      return saved;
    } catch (e) {
      debugPrint('[EmergencyContactService] Failed to add caregiver as emergency contact: $e');
      return false;
    }
  }

  /// Adds a linked doctor as an emergency contact for the patient.
  /// 
  /// Called automatically when a doctor accepts a patient's invite.
  /// Fetches the doctor's phone number from Firestore and creates
  /// an emergency contact entry.
  /// 
  /// Returns true if successful, false if failed or already exists.
  Future<bool> addLinkedDoctorAsEmergencyContact({
    required String patientId,
    required String doctorId,
  }) async {
    debugPrint('[EmergencyContactService] Adding linked doctor $doctorId as emergency contact for patient $patientId');
    
    try {
      // Fetch doctor details from Firestore
      final doctorDoc = await FirebaseFirestore.instance
          .collection('doctor_users')
          .doc(doctorId)
          .get();
      
      if (!doctorDoc.exists) {
        debugPrint('[EmergencyContactService] Doctor document not found: $doctorId');
        return false;
      }
      
      final data = doctorDoc.data()!;
      final phoneNumber = data['phone_number'] as String? ?? '';
      final doctorName = data['doctor_name'] as String? ?? 
                        data['full_name'] as String? ?? 
                        'Doctor';
      final specialty = data['specialty'] as String? ?? 'Doctor';
      
      if (phoneNumber.isEmpty) {
        debugPrint('[EmergencyContactService] Doctor has no phone number');
        return false;
      }
      
      // Check if this phone number already exists
      final existing = await getContacts(patientId);
      final phoneExists = existing.any((c) => c.phoneNumber == phoneNumber);
      if (phoneExists) {
        debugPrint('[EmergencyContactService] Phone number already in emergency contacts');
        return true; // Already exists, consider it success
      }
      
      // Create emergency contact with doctor type
      final contact = EmergencyContactModel.create(
        patientId: patientId,
        name: 'Dr. $doctorName ($specialty)',
        phoneNumber: phoneNumber,
        type: EmergencyContactType.doctor,
        priority: existing.isEmpty ? 0 : existing.length, // Add at end
      );
      
      final saved = await saveContact(contact);
      debugPrint('[EmergencyContactService] Doctor added as emergency contact: $saved');
      return saved;
    } catch (e) {
      debugPrint('[EmergencyContactService] Failed to add doctor as emergency contact: $e');
      return false;
    }
  }
}
