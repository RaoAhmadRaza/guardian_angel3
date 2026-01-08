/// RelationshipRepositoryHive - Local-first Hive implementation.
///
/// Implements RelationshipRepository using Hive for local storage.
/// Follows the project's offline-first architecture.
library;

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../persistence/wrappers/box_accessor.dart';
import '../../services/telemetry_service.dart';
import '../models/relationship_model.dart';
import 'relationship_repository.dart';

/// Hive-based implementation of RelationshipRepository.
class RelationshipRepositoryHive implements RelationshipRepository {
  final BoxAccessor _boxAccessor;
  final TelemetryService _telemetry;
  final Uuid _uuid = const Uuid();

  RelationshipRepositoryHive({
    BoxAccessor? boxAccessor,
    TelemetryService? telemetry,
  })  : _boxAccessor = boxAccessor ?? getSharedBoxAccessorInstance(),
        _telemetry = telemetry ?? getSharedTelemetryInstance();

  /// Access the relationships box.
  Box<RelationshipModel> get _box => _boxAccessor.relationships();

  /// Saves a relationship directly to local Hive storage.
  /// 
  /// Used for syncing relationships from Firestore to local storage.
  /// This bypasses normal validation since the data is already validated.
  Future<void> saveToLocal(RelationshipModel relationship) async {
    debugPrint('[RelationshipRepositoryHive] Saving to local: ${relationship.id}');
    await _box.put(relationship.id, relationship);
    debugPrint('[RelationshipRepositoryHive] Saved to local: ${relationship.id}');
  }

  @override
  Future<RelationshipResult<RelationshipModel>> createPatientInvite({
    required String patientId,
    List<String>? permissions,
  }) async {
    debugPrint('[RelationshipRepositoryHive] Creating invite for patient: $patientId');
    _telemetry.increment('relationship.create_invite.attempt');

    try {
      // Generate unique invite code
      final inviteCode = _generateInviteCode();
      
      // Check invite code uniqueness
      final existing = _findByInviteCodeSync(inviteCode);
      if (existing != null) {
        // Extremely unlikely collision - regenerate
        return createPatientInvite(patientId: patientId, permissions: permissions);
      }

      final now = DateTime.now().toUtc();
      final relationship = RelationshipModel(
        id: _uuid.v4(),
        patientId: patientId,
        caregiverId: null,
        status: RelationshipStatus.pending,
        permissions: permissions ?? ['chat', 'view_vitals', 'sos'],
        inviteCode: inviteCode,
        createdAt: now,
        updatedAt: now,
        createdBy: patientId,
      );

      // Validate before saving
      relationship.validate();

      // Save to Hive
      await _box.put(relationship.id, relationship);

      debugPrint('[RelationshipRepositoryHive] Invite created: ${relationship.inviteCode}');
      _telemetry.increment('relationship.create_invite.success');

      return RelationshipResult.success(relationship);
    } catch (e) {
      debugPrint('[RelationshipRepositoryHive] Create invite failed: $e');
      _telemetry.increment('relationship.create_invite.error');
      
      if (e is RelationshipValidationError) {
        return RelationshipResult.failure(
          RelationshipErrorCodes.validationError,
          e.message,
        );
      }
      return RelationshipResult.failure(
        RelationshipErrorCodes.storageError,
        'Failed to create invite: $e',
      );
    }
  }

  @override
  Future<RelationshipResult<RelationshipModel>> acceptInvite({
    required String inviteCode,
    required String caregiverId,
  }) async {
    debugPrint('[RelationshipRepositoryHive] Accepting invite: $inviteCode for caregiver: $caregiverId');
    _telemetry.increment('relationship.accept_invite.attempt');

    try {
      // Find relationship by invite code
      final relationship = _findByInviteCodeSync(inviteCode);
      
      if (relationship == null) {
        _telemetry.increment('relationship.accept_invite.invalid_code');
        return RelationshipResult.failure(
          RelationshipErrorCodes.invalidInviteCode,
          'Invite code not found',
        );
      }

      // Check if already revoked
      if (relationship.status == RelationshipStatus.revoked) {
        _telemetry.increment('relationship.accept_invite.revoked');
        return RelationshipResult.failure(
          RelationshipErrorCodes.relationshipRevoked,
          'This invite has been revoked',
        );
      }

      // Check if already accepted
      if (relationship.status == RelationshipStatus.active) {
        if (relationship.caregiverId == caregiverId) {
          // Same caregiver - idempotent success
          _telemetry.increment('relationship.accept_invite.duplicate');
          return RelationshipResult.success(relationship);
        }
        _telemetry.increment('relationship.accept_invite.already_used');
        return RelationshipResult.failure(
          RelationshipErrorCodes.inviteAlreadyUsed,
          'This invite has already been used',
        );
      }

      // Check if caregiver already has an active relationship
      final existingActive = _getActiveRelationshipForCaregiverSync(caregiverId);
      if (existingActive != null) {
        _telemetry.increment('relationship.accept_invite.caregiver_linked');
        return RelationshipResult.failure(
          RelationshipErrorCodes.caregiverAlreadyLinked,
          'You are already linked to another patient',
        );
      }

      // Update relationship
      final now = DateTime.now().toUtc();
      final updated = relationship.copyWith(
        caregiverId: caregiverId,
        status: RelationshipStatus.active,
        updatedAt: now,
      );

      // Validate before saving
      updated.validate();

      // Save to Hive
      await _box.put(updated.id, updated);

      debugPrint('[RelationshipRepositoryHive] Invite accepted: ${updated.id}');
      _telemetry.increment('relationship.accept_invite.success');

      return RelationshipResult.success(updated);
    } catch (e) {
      debugPrint('[RelationshipRepositoryHive] Accept invite failed: $e');
      _telemetry.increment('relationship.accept_invite.error');
      
      if (e is RelationshipValidationError) {
        return RelationshipResult.failure(
          RelationshipErrorCodes.validationError,
          e.message,
        );
      }
      return RelationshipResult.failure(
        RelationshipErrorCodes.storageError,
        'Failed to accept invite: $e',
      );
    }
  }

  @override
  Future<RelationshipResult<List<RelationshipModel>>> getRelationshipsForUser(String uid) async {
    try {
      final relationships = _box.values.where((r) => 
        r.patientId == uid || r.caregiverId == uid
      ).toList();

      return RelationshipResult.success(relationships);
    } catch (e) {
      debugPrint('[RelationshipRepositoryHive] Get relationships failed: $e');
      return RelationshipResult.failure(
        RelationshipErrorCodes.storageError,
        'Failed to get relationships: $e',
      );
    }
  }

  @override
  Future<RelationshipResult<RelationshipModel?>> getActiveRelationshipForCaregiver(String uid) async {
    try {
      final relationship = _getActiveRelationshipForCaregiverSync(uid);
      return RelationshipResult.success(relationship);
    } catch (e) {
      debugPrint('[RelationshipRepositoryHive] Get active relationship failed: $e');
      return RelationshipResult.failure(
        RelationshipErrorCodes.storageError,
        'Failed to get active relationship: $e',
      );
    }
  }

  @override
  Future<RelationshipResult<List<RelationshipModel>>> getActiveRelationshipsForPatient(String uid) async {
    try {
      final relationships = _box.values.where((r) => 
        r.patientId == uid && r.status == RelationshipStatus.active
      ).toList();

      return RelationshipResult.success(relationships);
    } catch (e) {
      debugPrint('[RelationshipRepositoryHive] Get active relationships for patient failed: $e');
      return RelationshipResult.failure(
        RelationshipErrorCodes.storageError,
        'Failed to get relationships: $e',
      );
    }
  }

  @override
  Future<RelationshipResult<void>> revokeRelationship({
    required String relationshipId,
    required String requesterId,
  }) async {
    debugPrint('[RelationshipRepositoryHive] Revoking relationship: $relationshipId by: $requesterId');
    _telemetry.increment('relationship.revoke.attempt');

    try {
      final relationship = _box.get(relationshipId);
      
      if (relationship == null) {
        _telemetry.increment('relationship.revoke.not_found');
        return RelationshipResult.failure(
          RelationshipErrorCodes.notFound,
          'Relationship not found',
        );
      }

      // Check authorization - only patient or caregiver can revoke
      if (relationship.patientId != requesterId && relationship.caregiverId != requesterId) {
        _telemetry.increment('relationship.revoke.unauthorized');
        return RelationshipResult.failure(
          RelationshipErrorCodes.unauthorized,
          'You are not authorized to revoke this relationship',
        );
      }

      // Already revoked - idempotent success
      if (relationship.status == RelationshipStatus.revoked) {
        return RelationshipResult.success(null);
      }

      // Update status
      final now = DateTime.now().toUtc();
      final updated = relationship.copyWith(
        status: RelationshipStatus.revoked,
        updatedAt: now,
      );

      await _box.put(updated.id, updated);

      debugPrint('[RelationshipRepositoryHive] Relationship revoked: $relationshipId');
      _telemetry.increment('relationship.revoke.success');

      return RelationshipResult.success(null);
    } catch (e) {
      debugPrint('[RelationshipRepositoryHive] Revoke failed: $e');
      _telemetry.increment('relationship.revoke.error');
      return RelationshipResult.failure(
        RelationshipErrorCodes.storageError,
        'Failed to revoke relationship: $e',
      );
    }
  }

  @override
  Future<RelationshipResult<RelationshipModel?>> findByInviteCode(String inviteCode) async {
    try {
      final relationship = _findByInviteCodeSync(inviteCode);
      return RelationshipResult.success(relationship);
    } catch (e) {
      debugPrint('[RelationshipRepositoryHive] Find by invite code failed: $e');
      return RelationshipResult.failure(
        RelationshipErrorCodes.storageError,
        'Failed to find relationship: $e',
      );
    }
  }

  @override
  Stream<List<RelationshipModel>> watchRelationshipsForUser(String uid) {
    return _box.watch().map((_) {
      return _box.values.where((r) => 
        r.patientId == uid || r.caregiverId == uid
      ).toList();
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Synchronously finds a relationship by invite code.
  /// Handles case-insensitive matching and different formats (with/without hyphen).
  RelationshipModel? _findByInviteCodeSync(String inviteCode) {
    // Normalize the input
    final normalized = inviteCode.trim().toUpperCase();
    final withoutHyphen = normalized.replaceAll('-', '');
    final withHyphen = withoutHyphen.length == 6 
        ? '${withoutHyphen.substring(0, 3)}-${withoutHyphen.substring(3)}'
        : normalized;
    
    debugPrint('[RelationshipRepositoryHive] Looking for invite code: "$inviteCode"');
    debugPrint('[RelationshipRepositoryHive] Normalized formats: "$normalized", "$withoutHyphen", "$withHyphen"');
    debugPrint('[RelationshipRepositoryHive] Total relationships in box: ${_box.length}');
    
    try {
      for (final r in _box.values) {
        final storedCode = r.inviteCode.trim().toUpperCase();
        final storedWithoutHyphen = storedCode.replaceAll('-', '');
        
        debugPrint('[RelationshipRepositoryHive] Checking stored code: "${r.inviteCode}" (normalized: "$storedCode")');
        
        // Match against various formats
        if (storedCode == normalized ||
            storedCode == withHyphen ||
            storedWithoutHyphen == withoutHyphen) {
          debugPrint('[RelationshipRepositoryHive] MATCH FOUND! id=${r.id}');
          return r;
        }
      }
      debugPrint('[RelationshipRepositoryHive] No match found in local storage');
      return null;
    } catch (e) {
      debugPrint('[RelationshipRepositoryHive] Error finding invite code: $e');
      return null;
    }
  }

  /// Synchronously gets the active relationship for a caregiver.
  RelationshipModel? _getActiveRelationshipForCaregiverSync(String uid) {
    try {
      return _box.values.firstWhere(
        (r) => r.caregiverId == uid && r.status == RelationshipStatus.active,
      );
    } catch (_) {
      return null;
    }
  }

  /// Generates a human-readable 6-character invite code.
  /// Format: ABC-123 (letters + digits)
  String _generateInviteCode() {
    const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ'; // Excluding I, O to avoid confusion
    const digits = '23456789'; // Excluding 0, 1 to avoid confusion
    final random = Random.secure();
    
    final letterPart = List.generate(3, (_) => letters[random.nextInt(letters.length)]).join();
    final digitPart = List.generate(3, (_) => digits[random.nextInt(digits.length)]).join();
    
    return '$letterPart-$digitPart';
  }
}
