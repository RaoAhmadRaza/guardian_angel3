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
import '../../chat/services/doctor_chat_service.dart';
import '../../services/emergency_contact_service.dart';

/// High-level service for doctor-patient relationship operations.
class DoctorRelationshipService {
  DoctorRelationshipService._();

  static final DoctorRelationshipService _instance = DoctorRelationshipService._();
  static DoctorRelationshipService get instance => _instance;

  final DoctorRelationshipRepositoryHive _repository = DoctorRelationshipRepositoryHive();
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
  /// 2. If not found locally, check Firestore and sync
  /// 3. Mirror to Firestore (non-blocking)
  /// 
  /// Returns the updated relationship.
  Future<DoctorRelationshipResult<DoctorRelationshipModel>> acceptDoctorInvite({
    required String inviteCode,
    required String doctorId,
  }) async {
    debugPrint('[DoctorRelationshipService] Accepting doctor invite: $inviteCode');
    
    // Normalize the invite code for matching
    final normalizedCode = _normalizeInviteCode(inviteCode);
    debugPrint('[DoctorRelationshipService] Normalized code: $normalizedCode');

    // Step 1: Accept locally
    final result = await _repository.acceptDoctorInvite(
      inviteCode: normalizedCode,
      doctorId: doctorId,
    );

    if (!result.success || result.data == null) {
      // If local lookup fails, try Firestore as fallback
      if (result.errorCode == DoctorRelationshipErrorCodes.invalidInviteCode) {
        debugPrint('[DoctorRelationshipService] Local lookup failed, trying Firestore');
        
        // Try multiple formats in Firestore
        DoctorRelationshipModel? firestoreRelationship;
        final codesToTry = _getCodeVariants(inviteCode);
        
        for (final code in codesToTry) {
          firestoreRelationship = await _firestore.findByInviteCode(code);
          if (firestoreRelationship != null) {
            debugPrint('[DoctorRelationshipService] Found in Firestore with code: $code');
            break;
          }
        }
        
        if (firestoreRelationship != null) {
          debugPrint('[DoctorRelationshipService] Found in Firestore, syncing locally...');
          
          // Save to local storage first
          final syncResult = await _repository.saveLocally(firestoreRelationship);
          if (!syncResult.success) {
            debugPrint('[DoctorRelationshipService] Local sync failed: ${syncResult.errorMessage}');
            return DoctorRelationshipResult.failure(
              DoctorRelationshipErrorCodes.storageError,
              'Failed to sync relationship locally',
            );
          }
          
          // Now retry the accept with the correct invite code
          final retryResult = await _repository.acceptDoctorInvite(
            inviteCode: firestoreRelationship.inviteCode,
            doctorId: doctorId,
          );
          
          if (retryResult.success && retryResult.data != null) {
            // Mirror to Firestore
            _firestore.mirrorRelationship(retryResult.data!).then((_) {
              debugPrint('[DoctorRelationshipService] Firestore mirror complete (after sync)');
            }).catchError((e) {
              debugPrint('[DoctorRelationshipService] Firestore mirror failed: $e');
            });
            
            // Auto-create chat thread for the new relationship (non-blocking)
            _createChatThreadForRelationship(retryResult.data!);
            
            // Auto-add doctor as emergency contact for SMS alerts (non-blocking)
            _addDoctorAsEmergencyContact(retryResult.data!);
            
            return retryResult;
          }
          
          return retryResult;
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
    
    // Auto-create chat thread for the new relationship (non-blocking)
    _createChatThreadForRelationship(result.data!);
    
    // Auto-add doctor as emergency contact for SMS alerts (non-blocking)
    _addDoctorAsEmergencyContact(result.data!);

    return result;
  }
  
  /// Normalizes an invite code for consistent matching.
  String _normalizeInviteCode(String code) {
    return code.toUpperCase().trim();
  }
  
  /// Gets all variants of an invite code to try.
  List<String> _getCodeVariants(String code) {
    final normalized = _normalizeInviteCode(code);
    final variants = <String>{normalized};
    
    // Try without hyphen
    if (normalized.contains('-')) {
      variants.add(normalized.replaceAll('-', ''));
    }
    
    // Try with DOC- prefix if not present
    if (!normalized.startsWith('DOC-')) {
      variants.add('DOC-$normalized');
      variants.add('DOC-${normalized.replaceAll('-', '')}');
    }
    
    // Try without DOC- prefix
    if (normalized.startsWith('DOC-')) {
      variants.add(normalized.substring(4));
    }
    
    return variants.toList();
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
  
  /// Creates a chat thread automatically when doctor relationship is accepted.
  /// 
  /// This ensures doctor and patient can immediately start chatting
  /// without needing to navigate to chat first.
  void _createChatThreadForRelationship(DoctorRelationshipModel relationship) {
    debugPrint('[DoctorRelationshipService] Auto-creating chat thread for doctor relationship: ${relationship.id}');
    
    // Validate we have both parties
    if (relationship.patientId.isEmpty || 
        relationship.doctorId == null || 
        relationship.doctorId!.isEmpty) {
      debugPrint('[DoctorRelationshipService] Cannot create chat - missing patient or doctor ID');
      return;
    }
    
    // Check if chat permission is granted
    if (!relationship.hasPermission('chat')) {
      debugPrint('[DoctorRelationshipService] Chat permission not granted, skipping thread creation');
      return;
    }
    
    // Use DoctorChatService to create thread (non-blocking)
    DoctorChatService.instance.getOrCreateDoctorThreadForRelationship(
      relationshipId: relationship.id,
      patientId: relationship.patientId,
      doctorId: relationship.doctorId!,
    ).then((result) {
      if (result.success) {
        debugPrint('[DoctorRelationshipService] Doctor chat thread created successfully: ${result.data?.id}');
      } else {
        debugPrint('[DoctorRelationshipService] Failed to create doctor chat thread: ${result.errorMessage}');
      }
    }).catchError((e) {
      debugPrint('[DoctorRelationshipService] Doctor chat thread creation error: $e');
    });
  }
  
  /// Adds doctor as emergency contact automatically when relationship is accepted.
  /// 
  /// This ensures the doctor receives SMS alerts during SOS emergencies.
  /// Fetches the doctor's phone number from Firestore and adds it to the
  /// patient's emergency contacts.
  void _addDoctorAsEmergencyContact(DoctorRelationshipModel relationship) {
    debugPrint('[DoctorRelationshipService] Auto-adding doctor as emergency contact for relationship: ${relationship.id}');
    
    // Validate we have both parties
    if (relationship.patientId.isEmpty || 
        relationship.doctorId == null || 
        relationship.doctorId!.isEmpty) {
      debugPrint('[DoctorRelationshipService] Cannot add emergency contact - missing patient or doctor ID');
      return;
    }
    
    // Use EmergencyContactService to add doctor (non-blocking)
    EmergencyContactService.instance.addLinkedDoctorAsEmergencyContact(
      patientId: relationship.patientId,
      doctorId: relationship.doctorId!,
    ).then((success) {
      if (success) {
        debugPrint('[DoctorRelationshipService] Doctor added as emergency contact successfully');
      } else {
        debugPrint('[DoctorRelationshipService] Failed to add doctor as emergency contact');
      }
    }).catchError((e) {
      debugPrint('[DoctorRelationshipService] Emergency contact addition error: $e');
    });
  }
}
