/// DoctorRelationshipFirestoreService - Mirrors doctor relationship data to Firestore.
///
/// This service handles Firestore mirroring for doctor-patient relationships.
/// NEVER blocks UI - all operations are fire-and-forget with retry.
///
/// Collection: doctor_relationships/{relationshipId}
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/doctor_relationship_model.dart';
import '../../services/telemetry_service.dart';

/// Firestore mirror service for doctor relationships.
class DoctorRelationshipFirestoreService {
  DoctorRelationshipFirestoreService._();

  static final DoctorRelationshipFirestoreService _instance = DoctorRelationshipFirestoreService._();
  static DoctorRelationshipFirestoreService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TelemetryService _telemetry = getSharedTelemetryInstance();

  /// Collection reference for doctor relationships.
  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('doctor_relationships');

  /// Mirrors a doctor relationship to Firestore.
  /// 
  /// This is NON-BLOCKING. Errors are logged but do not propagate.
  /// Use set with merge to handle both create and update.
  Future<void> mirrorRelationship(DoctorRelationshipModel relationship) async {
    debugPrint('[DoctorRelationshipFirestoreService] Mirroring doctor relationship: ${relationship.id}');
    _telemetry.increment('doctor_relationship.firestore.mirror.attempt');

    try {
      await _collection.doc(relationship.id).set(
        relationship.toJson(),
        SetOptions(merge: true),
      );

      debugPrint('[DoctorRelationshipFirestoreService] Mirror success: ${relationship.id}');
      _telemetry.increment('doctor_relationship.firestore.mirror.success');
    } catch (e) {
      debugPrint('[DoctorRelationshipFirestoreService] Mirror failed: $e');
      _telemetry.increment('doctor_relationship.firestore.mirror.error');
      // Do NOT rethrow - Firestore failures should not block UI
    }
  }

  /// Fetches a doctor relationship from Firestore by ID.
  /// 
  /// Used for sync/recovery scenarios.
  Future<DoctorRelationshipModel?> fetchRelationship(String relationshipId) async {
    try {
      final doc = await _collection.doc(relationshipId).get();
      if (!doc.exists || doc.data() == null) return null;
      
      return DoctorRelationshipModel.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('[DoctorRelationshipFirestoreService] Fetch failed: $e');
      _telemetry.increment('doctor_relationship.firestore.fetch.error');
      return null;
    }
  }

  /// Fetches all doctor relationships for a user from Firestore.
  /// 
  /// Queries both patient_id and doctor_id fields.
  Future<List<DoctorRelationshipModel>> fetchRelationshipsForUser(String uid) async {
    try {
      // Query as patient
      final patientQuery = await _collection
          .where('patient_id', isEqualTo: uid)
          .get();

      // Query as doctor
      final doctorQuery = await _collection
          .where('doctor_id', isEqualTo: uid)
          .get();

      // Combine results, avoiding duplicates
      final Map<String, DoctorRelationshipModel> results = {};
      
      for (final doc in patientQuery.docs) {
        if (doc.data().isNotEmpty) {
          final relationship = DoctorRelationshipModel.fromJson(doc.data());
          results[relationship.id] = relationship;
        }
      }
      
      for (final doc in doctorQuery.docs) {
        if (doc.data().isNotEmpty) {
          final relationship = DoctorRelationshipModel.fromJson(doc.data());
          results[relationship.id] = relationship;
        }
      }

      return results.values.toList();
    } catch (e) {
      debugPrint('[DoctorRelationshipFirestoreService] Fetch for user failed: $e');
      _telemetry.increment('doctor_relationship.firestore.fetch_user.error');
      return [];
    }
  }

  /// Finds a doctor relationship by invite code in Firestore.
  /// 
  /// Used as fallback when local lookup fails.
  Future<DoctorRelationshipModel?> findByInviteCode(String inviteCode) async {
    try {
      final query = await _collection
          .where('invite_code', isEqualTo: inviteCode)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;
      
      final doc = query.docs.first;
      if (doc.data().isEmpty) return null;
      
      return DoctorRelationshipModel.fromJson(doc.data());
    } catch (e) {
      debugPrint('[DoctorRelationshipFirestoreService] Find by invite code failed: $e');
      _telemetry.increment('doctor_relationship.firestore.find_invite.error');
      return null;
    }
  }

  /// Fetches all active relationships for a doctor from Firestore.
  Future<List<DoctorRelationshipModel>> fetchActiveRelationshipsForDoctor(String doctorUid) async {
    try {
      final query = await _collection
          .where('doctor_id', isEqualTo: doctorUid)
          .where('status', isEqualTo: 'active')
          .get();

      return query.docs
          .where((doc) => doc.data().isNotEmpty)
          .map((doc) => DoctorRelationshipModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('[DoctorRelationshipFirestoreService] Fetch active for doctor failed: $e');
      _telemetry.increment('doctor_relationship.firestore.fetch_doctor.error');
      return [];
    }
  }

  /// Fetches all active relationships for a patient from Firestore.
  Future<List<DoctorRelationshipModel>> fetchActiveRelationshipsForPatient(String patientUid) async {
    try {
      final query = await _collection
          .where('patient_id', isEqualTo: patientUid)
          .where('status', isEqualTo: 'active')
          .get();

      return query.docs
          .where((doc) => doc.data().isNotEmpty)
          .map((doc) => DoctorRelationshipModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('[DoctorRelationshipFirestoreService] Fetch active for patient failed: $e');
      _telemetry.increment('doctor_relationship.firestore.fetch_patient.error');
      return [];
    }
  }

  /// Deletes a doctor relationship from Firestore.
  /// 
  /// Used when relationship is permanently deleted (rare).
  Future<void> deleteRelationship(String relationshipId) async {
    try {
      await _collection.doc(relationshipId).delete();
      debugPrint('[DoctorRelationshipFirestoreService] Deleted: $relationshipId');
      _telemetry.increment('doctor_relationship.firestore.delete.success');
    } catch (e) {
      debugPrint('[DoctorRelationshipFirestoreService] Delete failed: $e');
      _telemetry.increment('doctor_relationship.firestore.delete.error');
    }
  }

  /// Watches doctor relationships for a user in Firestore.
  /// 
  /// Returns a stream of relationship lists.
  /// Note: This creates TWO Firestore listeners (patient + doctor queries).
  Stream<List<DoctorRelationshipModel>> watchRelationshipsForUser(String uid) {
    // Watch as patient
    final patientStream = _collection
        .where('patient_id', isEqualTo: uid)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .where((doc) => doc.data().isNotEmpty)
            .map((doc) => DoctorRelationshipModel.fromJson(doc.data()))
            .toList());

    // Watch as doctor
    final doctorStream = _collection
        .where('doctor_id', isEqualTo: uid)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .where((doc) => doc.data().isNotEmpty)
            .map((doc) => DoctorRelationshipModel.fromJson(doc.data()))
            .toList());

    // Combine streams - merge and deduplicate
    return patientStream.asyncExpand((patientRelationships) {
      return doctorStream.map((doctorRelationships) {
        final Map<String, DoctorRelationshipModel> combined = {};
        for (final r in patientRelationships) {
          combined[r.id] = r;
        }
        for (final r in doctorRelationships) {
          combined[r.id] = r;
        }
        return combined.values.toList();
      });
    });
  }
}
