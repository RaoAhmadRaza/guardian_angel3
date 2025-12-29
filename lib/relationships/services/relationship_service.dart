/// RelationshipService - High-level API for relationship operations.
///
/// Combines local Hive storage with Firestore mirroring.
/// This is the primary entry point for relationship operations.
///
/// Pattern: Local-first
/// 1. Save/update in Hive
/// 2. Mirror to Firestore (non-blocking)
library;

import 'package:flutter/foundation.dart';
import '../models/relationship_model.dart';
import '../repositories/relationship_repository.dart';
import '../repositories/relationship_repository_hive.dart';
import 'relationship_firestore_service.dart';

/// High-level service for relationship operations.
class RelationshipService {
  RelationshipService._();

  static final RelationshipService _instance = RelationshipService._();
  static RelationshipService get instance => _instance;

  final RelationshipRepository _repository = RelationshipRepositoryHive();
  final RelationshipFirestoreService _firestore = RelationshipFirestoreService.instance;

  /// Creates a new patient invite.
  /// 
  /// Flow:
  /// 1. Save to Hive (local)
  /// 2. Mirror to Firestore (non-blocking)
  /// 
  /// Returns the created relationship with invite code.
  Future<RelationshipResult<RelationshipModel>> createPatientInvite({
    required String patientId,
    List<String>? permissions,
  }) async {
    debugPrint('[RelationshipService] Creating patient invite for: $patientId');

    // Step 1: Save locally
    final result = await _repository.createPatientInvite(
      patientId: patientId,
      permissions: permissions,
    );

    if (!result.success || result.data == null) {
      debugPrint('[RelationshipService] Local save failed: ${result.errorMessage}');
      return result;
    }

    // Step 2: Mirror to Firestore (non-blocking)
    _firestore.mirrorRelationship(result.data!).then((_) {
      debugPrint('[RelationshipService] Firestore mirror complete');
    }).catchError((e) {
      debugPrint('[RelationshipService] Firestore mirror failed (will retry): $e');
    });

    return result;
  }

  /// Accepts an invite code.
  /// 
  /// Flow:
  /// 1. Validate and update in Hive (local)
  /// 2. Mirror to Firestore (non-blocking)
  /// 
  /// Returns the updated relationship.
  Future<RelationshipResult<RelationshipModel>> acceptInvite({
    required String inviteCode,
    required String caregiverId,
  }) async {
    debugPrint('[RelationshipService] Accepting invite: $inviteCode');

    // Step 1: Accept locally
    final result = await _repository.acceptInvite(
      inviteCode: inviteCode,
      caregiverId: caregiverId,
    );

    if (!result.success || result.data == null) {
      // If local lookup fails, try Firestore as fallback
      if (result.errorCode == RelationshipErrorCodes.invalidInviteCode) {
        debugPrint('[RelationshipService] Local lookup failed, trying Firestore');
        final firestoreRelationship = await _firestore.findByInviteCode(inviteCode);
        
        if (firestoreRelationship != null) {
          // Found in Firestore - sync locally and retry
          // For now, we'll return the error - full sync logic is out of scope
          debugPrint('[RelationshipService] Found in Firestore but local sync not implemented');
        }
      }
      
      debugPrint('[RelationshipService] Accept failed: ${result.errorMessage}');
      return result;
    }

    // Step 2: Mirror to Firestore (non-blocking)
    _firestore.mirrorRelationship(result.data!).then((_) {
      debugPrint('[RelationshipService] Firestore mirror complete');
    }).catchError((e) {
      debugPrint('[RelationshipService] Firestore mirror failed (will retry): $e');
    });

    return result;
  }

  /// Gets relationships for a user.
  Future<RelationshipResult<List<RelationshipModel>>> getRelationshipsForUser(String uid) {
    return _repository.getRelationshipsForUser(uid);
  }

  /// Gets the active relationship for a caregiver.
  Future<RelationshipResult<RelationshipModel?>> getActiveRelationshipForCaregiver(String uid) {
    return _repository.getActiveRelationshipForCaregiver(uid);
  }

  /// Gets all active relationships for a patient.
  Future<RelationshipResult<List<RelationshipModel>>> getActiveRelationshipsForPatient(String uid) {
    return _repository.getActiveRelationshipsForPatient(uid);
  }

  /// Revokes a relationship.
  /// 
  /// Flow:
  /// 1. Update status in Hive (local)
  /// 2. Mirror to Firestore (non-blocking)
  Future<RelationshipResult<void>> revokeRelationship({
    required String relationshipId,
    required String requesterId,
  }) async {
    debugPrint('[RelationshipService] Revoking relationship: $relationshipId');

    // Step 1: Revoke locally
    final result = await _repository.revokeRelationship(
      relationshipId: relationshipId,
      requesterId: requesterId,
    );

    if (!result.success) {
      debugPrint('[RelationshipService] Revoke failed: ${result.errorMessage}');
      return result;
    }

    // Step 2: Fetch updated relationship and mirror
    final fetchResult = await _repository.getRelationshipsForUser(requesterId);
    if (fetchResult.success && fetchResult.data != null) {
      final updated = fetchResult.data!.where((r) => r.id == relationshipId).firstOrNull;
      if (updated != null) {
        _firestore.mirrorRelationship(updated).catchError((e) {
          debugPrint('[RelationshipService] Firestore mirror failed: $e');
        });
      }
    }

    return result;
  }

  /// Finds a relationship by invite code.
  Future<RelationshipResult<RelationshipModel?>> findByInviteCode(String inviteCode) {
    return _repository.findByInviteCode(inviteCode);
  }

  /// Watches relationships for a user.
  Stream<List<RelationshipModel>> watchRelationshipsForUser(String uid) {
    return _repository.watchRelationshipsForUser(uid);
  }

  /// Gets the pending invite code for a patient (if any).
  /// 
  /// Returns the most recent pending invite code.
  Future<String?> getPendingInviteCodeForPatient(String patientId) async {
    final result = await _repository.getRelationshipsForUser(patientId);
    if (!result.success || result.data == null) return null;

    final pending = result.data!
        .where((r) => r.patientId == patientId && r.status == RelationshipStatus.pending)
        .toList();

    if (pending.isEmpty) return null;

    // Sort by creation date descending, return most recent
    pending.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return pending.first.inviteCode;
  }
}
