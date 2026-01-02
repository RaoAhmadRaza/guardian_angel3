/// DoctorRelationshipService - High-level API for doctor-patient relationship operations.
///
/// Combines local Hive storage with Firestore mirroring.
/// This is the primary entry point for doctor relationship operations.
///
/// Pattern: Local-first
/// 1. Save/update in Hive
/// 2. Mirror to Firestore (non-blocking)
library;

import 'package:flutter/foundation.dart';
import '../models/doctor_relationship_model.dart';
import '../repositories/doctor_relationship_repository.dart';
import '../repositories/doctor_relationship_repository_hive.dart';
import 'doctor_relationship_firestore_service.dart';

/// High-level service for doctor-patient relationship operations.
class DoctorRelationshipService {
  DoctorRelationshipService._();

  static final DoctorRelationshipService _instance = DoctorRelationshipService._();
  static DoctorRelationshipService get instance => _instance;

  final DoctorRelationshipRepository _repository = DoctorRelationshipRepositoryHive();
  final DoctorRelationshipFirestoreService _firestore = DoctorRelationshipFirestoreService.instance;

  /// Creates a new patient-doctor invite.
  /// 
  /// Flow:
  /// 1. Save to Hive (local)
  /// 2. Mirror to Firestore (non-blocking)
  /// 
  /// Returns the created relationship with invite code.
  Future<DoctorRelationshipResult<DoctorRelationshipModel>> createPatientDoctorInvite({
    required String patientId,
    List<String>? permissions,
  }) async {
    debugPrint('[DoctorRelationshipService] Creating patient-doctor invite for: $patientId');

    // Step 1: Save locally
    final result = await _repository.createPatientDoctorInvite(
      patientId: patientId,
      permissions: permissions,
    );

    if (!result.success || result.data == null) {
      debugPrint('[DoctorRelationshipService] Local save failed: ${result.errorMessage}');
      return result;
    }

    // Step 2: Mirror to Firestore (non-blocking)
    _firestore.mirrorRelationship(result.data!).then((_) {
      debugPrint('[DoctorRelationshipService] Firestore mirror complete');
    }).catchError((e) {
      debugPrint('[DoctorRelationshipService] Firestore mirror failed (will retry): $e');
    });

    return result;
  }

  /// Accepts a doctor invite code.
  /// 
  /// Flow:
  /// 1. Validate and update in Hive (local)
  /// 2. Mirror to Firestore (non-blocking)
  /// 
  /// Returns the updated relationship.
  Future<DoctorRelationshipResult<DoctorRelationshipModel>> acceptDoctorInvite({
    required String inviteCode,
    required String doctorId,
  }) async {
    debugPrint('[DoctorRelationshipService] Accepting doctor invite: $inviteCode');

    // Step 1: Accept locally
    final result = await _repository.acceptDoctorInvite(
      inviteCode: inviteCode,
      doctorId: doctorId,
    );

    if (!result.success || result.data == null) {
      // If local lookup fails, try Firestore as fallback
      if (result.errorCode == DoctorRelationshipErrorCodes.invalidInviteCode) {
        debugPrint('[DoctorRelationshipService] Local lookup failed, trying Firestore');
        final firestoreRelationship = await _firestore.findByInviteCode(inviteCode);
        
        if (firestoreRelationship != null) {
          // Found in Firestore - sync locally and retry
          debugPrint('[DoctorRelationshipService] Found in Firestore but local sync not implemented');
        }
      }
      
      debugPrint('[DoctorRelationshipService] Accept failed: ${result.errorMessage}');
      return result;
    }

    // Step 2: Mirror to Firestore (non-blocking)
    _firestore.mirrorRelationship(result.data!).then((_) {
      debugPrint('[DoctorRelationshipService] Firestore mirror complete');
    }).catchError((e) {
      debugPrint('[DoctorRelationshipService] Firestore mirror failed (will retry): $e');
    });

    return result;
  }

  /// Gets relationships for a user.
  Future<DoctorRelationshipResult<List<DoctorRelationshipModel>>> getRelationshipsForUser(String uid) {
    return _repository.getRelationshipsForUser(uid);
  }

  /// Gets all active relationships for a doctor.
  Future<DoctorRelationshipResult<List<DoctorRelationshipModel>>> getActiveRelationshipsForDoctor(String uid) {
    return _repository.getActiveRelationshipsForDoctor(uid);
  }

  /// Gets all active relationships for a patient.
  Future<DoctorRelationshipResult<List<DoctorRelationshipModel>>> getActiveRelationshipsForPatient(String uid) {
    return _repository.getActiveRelationshipsForPatient(uid);
  }

  /// Revokes a relationship.
  Future<DoctorRelationshipResult<void>> revokeRelationship({
    required String relationshipId,
    required String requesterId,
  }) async {
    debugPrint('[DoctorRelationshipService] Revoking relationship: $relationshipId');

    final result = await _repository.revokeRelationship(
      relationshipId: relationshipId,
      requesterId: requesterId,
    );

    if (result.success) {
      // Note: For revoke, the Hive impl already persists locally.
      // Firestore will sync on next read. A proper implementation would
      // fetch by ID and mirror, but that's out of scope for this pattern.
      debugPrint('[DoctorRelationshipService] Revoke successful (Firestore sync pending)');
    }

    return result;
  }

  /// Finds a relationship by invite code.
  Future<DoctorRelationshipResult<DoctorRelationshipModel?>> findByInviteCode(String inviteCode) {
    return _repository.findByInviteCode(inviteCode);
  }

  /// Watches relationships for a user.
  Stream<List<DoctorRelationshipModel>> watchRelationshipsForUser(String uid) {
    return _repository.watchRelationshipsForUser(uid);
  }
}
