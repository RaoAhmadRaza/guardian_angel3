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
import '../../chat/services/chat_service.dart';
import '../../services/emergency_contact_service.dart';

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
  /// 1. Try to find and accept in Hive (local)
  /// 2. If not found locally, check Firestore
  /// 3. If found in Firestore, sync to local and accept
  /// 4. Mirror updated relationship to Firestore (non-blocking)
  /// 
  /// Returns the updated relationship.
  Future<RelationshipResult<RelationshipModel>> acceptInvite({
    required String inviteCode,
    required String caregiverId,
  }) async {
    debugPrint('[RelationshipService] ========================================');
    debugPrint('[RelationshipService] Accepting invite code: "$inviteCode"');
    debugPrint('[RelationshipService] Caregiver ID: $caregiverId');
    debugPrint('[RelationshipService] ========================================');

    // Step 1: Try to accept locally first
    debugPrint('[RelationshipService] Step 1: Trying local Hive lookup...');
    var result = await _repository.acceptInvite(
      inviteCode: inviteCode,
      caregiverId: caregiverId,
    );
    debugPrint('[RelationshipService] Local result: success=${result.success}, error=${result.errorCode}');

    // Step 2: If local lookup fails, try Firestore as fallback
    if (!result.success && result.errorCode == RelationshipErrorCodes.invalidInviteCode) {
      debugPrint('[RelationshipService] Step 2: Local lookup failed, trying Firestore...');
      
      final firestoreRelationship = await _firestore.findByInviteCode(inviteCode);
      
      if (firestoreRelationship != null) {
        debugPrint('[RelationshipService] Found in Firestore: ${firestoreRelationship.id}');
        debugPrint('[RelationshipService] Firestore invite_code: ${firestoreRelationship.inviteCode}');
        debugPrint('[RelationshipService] Firestore status: ${firestoreRelationship.status}');
        
        // Check if already revoked
        if (firestoreRelationship.status == RelationshipStatus.revoked) {
          return RelationshipResult.failure(
            RelationshipErrorCodes.relationshipRevoked,
            'This invite has been revoked',
          );
        }

        // Check if already accepted by another caregiver
        if (firestoreRelationship.status == RelationshipStatus.active) {
          if (firestoreRelationship.caregiverId == caregiverId) {
            // Same caregiver - idempotent success, sync locally
            await _syncRelationshipToLocal(firestoreRelationship);
            return RelationshipResult.success(firestoreRelationship);
          }
          return RelationshipResult.failure(
            RelationshipErrorCodes.inviteAlreadyUsed,
            'This invite has already been used',
          );
        }

        // Check if caregiver already has an active relationship
        final existingActive = await _repository.getActiveRelationshipForCaregiver(caregiverId);
        if (existingActive.success && existingActive.data != null) {
          return RelationshipResult.failure(
            RelationshipErrorCodes.caregiverAlreadyLinked,
            'You are already linked to another patient',
          );
        }

        // Update the relationship
        final now = DateTime.now().toUtc();
        final updated = firestoreRelationship.copyWith(
          caregiverId: caregiverId,
          status: RelationshipStatus.active,
          updatedAt: now,
        );

        // Save to local storage
        await _syncRelationshipToLocal(updated);
        
        // Mirror to Firestore (non-blocking)
        _firestore.mirrorRelationship(updated).then((_) {
          debugPrint('[RelationshipService] Firestore mirror complete');
        }).catchError((e) {
          debugPrint('[RelationshipService] Firestore mirror failed (will retry): $e');
        });
        
        // Auto-create chat thread for the new relationship (non-blocking)
        _createChatThreadForRelationship(updated);
        
        // Auto-add caregiver as emergency contact for SMS alerts (non-blocking)
        _addCaregiverAsEmergencyContact(updated);

        return RelationshipResult.success(updated);
      }
      
      // Not found in Firestore either
      debugPrint('[RelationshipService] Invite code not found in Firestore');
      return result;
    }

    if (!result.success || result.data == null) {
      debugPrint('[RelationshipService] Accept failed: ${result.errorMessage}');
      return result;
    }

    // Step 3: Mirror to Firestore (non-blocking)
    _firestore.mirrorRelationship(result.data!).then((_) {
      debugPrint('[RelationshipService] Firestore mirror complete');
    }).catchError((e) {
      debugPrint('[RelationshipService] Firestore mirror failed (will retry): $e');
    });
    
    // Auto-create chat thread for the new relationship (non-blocking)
    _createChatThreadForRelationship(result.data!);
    
    // Auto-add caregiver as emergency contact for SMS alerts (non-blocking)
    _addCaregiverAsEmergencyContact(result.data!);

    return result;
  }

  /// Syncs a relationship from Firestore to local Hive storage.
  Future<void> _syncRelationshipToLocal(RelationshipModel relationship) async {
    debugPrint('[RelationshipService] Syncing relationship to local: ${relationship.id}');
    try {
      // Use the repository's internal save method by casting
      final hiveRepo = _repository as RelationshipRepositoryHive;
      await hiveRepo.saveToLocal(relationship);
      debugPrint('[RelationshipService] Local sync complete');
    } catch (e) {
      debugPrint('[RelationshipService] Local sync failed: $e');
      // Don't fail the operation - Firestore is the source for this invite
    }
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

  /// Syncs relationships from Firestore to local Hive storage.
  /// 
  /// This should be called when:
  /// - Patient opens the app (to pull caregiver acceptances)
  /// - Caregiver opens the app (to pull patient invites)
  /// 
  /// Flow:
  /// 1. Fetch all relationships from Firestore for this user
  /// 2. Merge with local data (Firestore wins for status changes)
  /// 3. Save to local Hive
  Future<void> syncFromFirestore(String uid) async {
    debugPrint('[RelationshipService] Syncing from Firestore for user: $uid');
    
    try {
      // Fetch from Firestore
      final firestoreRelationships = await _firestore.fetchRelationshipsForUser(uid);
      debugPrint('[RelationshipService] Fetched ${firestoreRelationships.length} relationships from Firestore');
      
      if (firestoreRelationships.isEmpty) {
        debugPrint('[RelationshipService] No relationships in Firestore to sync');
        return;
      }
      
      // Sync each relationship to local storage
      final hiveRepo = _repository as RelationshipRepositoryHive;
      for (final relationship in firestoreRelationships) {
        try {
          await hiveRepo.saveToLocal(relationship);
          debugPrint('[RelationshipService] Synced relationship: ${relationship.id} (status: ${relationship.status})');
        } catch (e) {
          debugPrint('[RelationshipService] Failed to sync relationship ${relationship.id}: $e');
        }
      }
      
      debugPrint('[RelationshipService] Firestore sync complete');
    } catch (e) {
      debugPrint('[RelationshipService] Firestore sync failed: $e');
      // Don't throw - sync failures should not break the app
    }
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
  
  /// Creates a chat thread automatically when relationship is accepted.
  /// 
  /// This ensures caregiver and patient can immediately start chatting
  /// without needing to navigate to chat first.
  void _createChatThreadForRelationship(RelationshipModel relationship) {
    debugPrint('[RelationshipService] Auto-creating chat thread for relationship: ${relationship.id}');
    
    // Validate we have both parties
    if (relationship.patientId.isEmpty || 
        relationship.caregiverId == null || 
        relationship.caregiverId!.isEmpty) {
      debugPrint('[RelationshipService] Cannot create chat - missing patient or caregiver ID');
      return;
    }
    
    // Check if chat permission is granted
    if (!relationship.permissions.contains('chat')) {
      debugPrint('[RelationshipService] Chat permission not granted, skipping thread creation');
      return;
    }
    
    // Use ChatService to create thread (non-blocking)
    ChatService.instance.getOrCreateThreadForRelationship(
      relationshipId: relationship.id,
      patientId: relationship.patientId,
      caregiverId: relationship.caregiverId!,
    ).then((result) {
      if (result.success) {
        debugPrint('[RelationshipService] Chat thread created successfully: ${result.data?.id}');
      } else {
        debugPrint('[RelationshipService] Failed to create chat thread: ${result.errorMessage}');
      }
    }).catchError((e) {
      debugPrint('[RelationshipService] Chat thread creation error: $e');
    });
  }
  
  /// Adds caregiver as emergency contact automatically when relationship is accepted.
  /// 
  /// This ensures the caregiver receives SMS alerts during SOS emergencies.
  /// Fetches the caregiver's phone number from Firestore and adds it to the
  /// patient's emergency contacts.
  void _addCaregiverAsEmergencyContact(RelationshipModel relationship) {
    debugPrint('[RelationshipService] Auto-adding caregiver as emergency contact for relationship: ${relationship.id}');
    
    // Validate we have both parties
    if (relationship.patientId.isEmpty || 
        relationship.caregiverId == null || 
        relationship.caregiverId!.isEmpty) {
      debugPrint('[RelationshipService] Cannot add emergency contact - missing patient or caregiver ID');
      return;
    }
    
    // Use EmergencyContactService to add caregiver (non-blocking)
    EmergencyContactService.instance.addLinkedCaregiverAsEmergencyContact(
      patientId: relationship.patientId,
      caregiverId: relationship.caregiverId!,
    ).then((success) {
      if (success) {
        debugPrint('[RelationshipService] Caregiver added as emergency contact successfully');
      } else {
        debugPrint('[RelationshipService] Failed to add caregiver as emergency contact');
      }
    }).catchError((e) {
      debugPrint('[RelationshipService] Emergency contact addition error: $e');
    });
  }
}
