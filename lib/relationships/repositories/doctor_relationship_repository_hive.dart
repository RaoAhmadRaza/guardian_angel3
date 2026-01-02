/// DoctorRelationshipRepositoryHive - Local-first Hive implementation.
///
/// Implements DoctorRelationshipRepository using Hive for local storage.
/// Follows the project's offline-first architecture.
library;

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../persistence/wrappers/box_accessor.dart';
import '../../services/telemetry_service.dart';
import '../models/doctor_relationship_model.dart';
import 'doctor_relationship_repository.dart';

/// Hive-based implementation of DoctorRelationshipRepository.
class DoctorRelationshipRepositoryHive implements DoctorRelationshipRepository {
  final BoxAccessor _boxAccessor;
  final TelemetryService _telemetry;
  final Uuid _uuid = const Uuid();

  DoctorRelationshipRepositoryHive({
    BoxAccessor? boxAccessor,
    TelemetryService? telemetry,
  })  : _boxAccessor = boxAccessor ?? getSharedBoxAccessorInstance(),
        _telemetry = telemetry ?? getSharedTelemetryInstance();

  /// Access the doctor relationships box.
  Box<DoctorRelationshipModel> get _box => _boxAccessor.doctorRelationships();

  @override
  Future<DoctorRelationshipResult<DoctorRelationshipModel>> createPatientDoctorInvite({
    required String patientId,
    List<String>? permissions,
  }) async {
    debugPrint('[DoctorRelationshipRepositoryHive] Creating doctor invite for patient: $patientId');
    _telemetry.increment('doctor_relationship.create_invite.attempt');

    try {
      // Generate unique invite code
      final inviteCode = _generateInviteCode();
      
      // Check invite code uniqueness
      final existing = _findByInviteCodeSync(inviteCode);
      if (existing != null) {
        // Extremely unlikely collision - regenerate
        return createPatientDoctorInvite(patientId: patientId, permissions: permissions);
      }

      final now = DateTime.now().toUtc();
      final relationship = DoctorRelationshipModel(
        id: _uuid.v4(),
        patientId: patientId,
        doctorId: null,
        status: DoctorRelationshipStatus.pending,
        permissions: permissions ?? ['chat', 'view_records', 'view_vitals', 'notes'],
        inviteCode: inviteCode,
        createdAt: now,
        updatedAt: now,
        createdBy: patientId,
      );

      // Validate before saving
      relationship.validate();

      // Save to Hive
      await _box.put(relationship.id, relationship);

      debugPrint('[DoctorRelationshipRepositoryHive] Doctor invite created: ${relationship.inviteCode}');
      _telemetry.increment('doctor_relationship.create_invite.success');

      return DoctorRelationshipResult.success(relationship);
    } catch (e) {
      debugPrint('[DoctorRelationshipRepositoryHive] Create doctor invite failed: $e');
      _telemetry.increment('doctor_relationship.create_invite.error');
      
      if (e is DoctorRelationshipValidationError) {
        return DoctorRelationshipResult.failure(
          DoctorRelationshipErrorCodes.validationError,
          e.message,
        );
      }
      return DoctorRelationshipResult.failure(
        DoctorRelationshipErrorCodes.storageError,
        'Failed to create doctor invite: $e',
      );
    }
  }

  @override
  Future<DoctorRelationshipResult<DoctorRelationshipModel>> acceptDoctorInvite({
    required String inviteCode,
    required String doctorId,
  }) async {
    debugPrint('[DoctorRelationshipRepositoryHive] Accepting doctor invite: $inviteCode for doctor: $doctorId');
    _telemetry.increment('doctor_relationship.accept_invite.attempt');

    try {
      // Find relationship by invite code
      final relationship = _findByInviteCodeSync(inviteCode);
      
      if (relationship == null) {
        _telemetry.increment('doctor_relationship.accept_invite.invalid_code');
        return DoctorRelationshipResult.failure(
          DoctorRelationshipErrorCodes.invalidInviteCode,
          'Invite code not found',
        );
      }

      // Check if already revoked
      if (relationship.status == DoctorRelationshipStatus.revoked) {
        _telemetry.increment('doctor_relationship.accept_invite.revoked');
        return DoctorRelationshipResult.failure(
          DoctorRelationshipErrorCodes.relationshipRevoked,
          'This invite has been revoked',
        );
      }

      // Check if already accepted
      if (relationship.status == DoctorRelationshipStatus.active) {
        if (relationship.doctorId == doctorId) {
          // Same doctor - idempotent success
          _telemetry.increment('doctor_relationship.accept_invite.duplicate');
          return DoctorRelationshipResult.success(relationship);
        }
        _telemetry.increment('doctor_relationship.accept_invite.already_used');
        return DoctorRelationshipResult.failure(
          DoctorRelationshipErrorCodes.inviteAlreadyUsed,
          'This invite has already been used',
        );
      }

      // Update relationship - NOTE: Unlike caregiver, a doctor can have multiple patients
      // No check for existing active relationship
      final now = DateTime.now().toUtc();
      final updated = relationship.copyWith(
        doctorId: doctorId,
        status: DoctorRelationshipStatus.active,
        updatedAt: now,
      );

      // Validate before saving
      updated.validate();

      // Save to Hive
      await _box.put(updated.id, updated);

      debugPrint('[DoctorRelationshipRepositoryHive] Doctor invite accepted: ${updated.id}');
      _telemetry.increment('doctor_relationship.accept_invite.success');

      return DoctorRelationshipResult.success(updated);
    } catch (e) {
      debugPrint('[DoctorRelationshipRepositoryHive] Accept doctor invite failed: $e');
      _telemetry.increment('doctor_relationship.accept_invite.error');
      
      if (e is DoctorRelationshipValidationError) {
        return DoctorRelationshipResult.failure(
          DoctorRelationshipErrorCodes.validationError,
          e.message,
        );
      }
      return DoctorRelationshipResult.failure(
        DoctorRelationshipErrorCodes.storageError,
        'Failed to accept invite: $e',
      );
    }
  }

  @override
  Future<DoctorRelationshipResult<List<DoctorRelationshipModel>>> getRelationshipsForUser(String uid) async {
    try {
      final relationships = _box.values.where((r) => 
        r.patientId == uid || r.doctorId == uid
      ).toList();

      return DoctorRelationshipResult.success(relationships);
    } catch (e) {
      debugPrint('[DoctorRelationshipRepositoryHive] Get relationships failed: $e');
      return DoctorRelationshipResult.failure(
        DoctorRelationshipErrorCodes.storageError,
        'Failed to get relationships: $e',
      );
    }
  }

  @override
  Future<DoctorRelationshipResult<List<DoctorRelationshipModel>>> getActiveRelationshipsForDoctor(String uid) async {
    try {
      final relationships = _box.values.where((r) => 
        r.doctorId == uid && r.status == DoctorRelationshipStatus.active
      ).toList();

      return DoctorRelationshipResult.success(relationships);
    } catch (e) {
      debugPrint('[DoctorRelationshipRepositoryHive] Get active relationships for doctor failed: $e');
      return DoctorRelationshipResult.failure(
        DoctorRelationshipErrorCodes.storageError,
        'Failed to get relationships: $e',
      );
    }
  }

  @override
  Future<DoctorRelationshipResult<List<DoctorRelationshipModel>>> getActiveRelationshipsForPatient(String uid) async {
    try {
      final relationships = _box.values.where((r) => 
        r.patientId == uid && r.status == DoctorRelationshipStatus.active
      ).toList();

      return DoctorRelationshipResult.success(relationships);
    } catch (e) {
      debugPrint('[DoctorRelationshipRepositoryHive] Get active relationships for patient failed: $e');
      return DoctorRelationshipResult.failure(
        DoctorRelationshipErrorCodes.storageError,
        'Failed to get relationships: $e',
      );
    }
  }

  @override
  Future<DoctorRelationshipResult<void>> revokeRelationship({
    required String relationshipId,
    required String requesterId,
  }) async {
    debugPrint('[DoctorRelationshipRepositoryHive] Revoking relationship: $relationshipId by: $requesterId');
    _telemetry.increment('doctor_relationship.revoke.attempt');

    try {
      final relationship = _box.get(relationshipId);
      
      if (relationship == null) {
        _telemetry.increment('doctor_relationship.revoke.not_found');
        return DoctorRelationshipResult.failure(
          DoctorRelationshipErrorCodes.notFound,
          'Relationship not found',
        );
      }

      // Check authorization - only patient or doctor can revoke
      if (relationship.patientId != requesterId && relationship.doctorId != requesterId) {
        _telemetry.increment('doctor_relationship.revoke.unauthorized');
        return DoctorRelationshipResult.failure(
          DoctorRelationshipErrorCodes.unauthorized,
          'You are not authorized to revoke this relationship',
        );
      }

      // Already revoked - idempotent success
      if (relationship.status == DoctorRelationshipStatus.revoked) {
        return DoctorRelationshipResult.success(null);
      }

      // Update status
      final now = DateTime.now().toUtc();
      final updated = relationship.copyWith(
        status: DoctorRelationshipStatus.revoked,
        updatedAt: now,
      );

      await _box.put(updated.id, updated);

      debugPrint('[DoctorRelationshipRepositoryHive] Relationship revoked: $relationshipId');
      _telemetry.increment('doctor_relationship.revoke.success');

      return DoctorRelationshipResult.success(null);
    } catch (e) {
      debugPrint('[DoctorRelationshipRepositoryHive] Revoke failed: $e');
      _telemetry.increment('doctor_relationship.revoke.error');
      return DoctorRelationshipResult.failure(
        DoctorRelationshipErrorCodes.storageError,
        'Failed to revoke relationship: $e',
      );
    }
  }

  @override
  Future<DoctorRelationshipResult<DoctorRelationshipModel?>> findByInviteCode(String inviteCode) async {
    try {
      final relationship = _findByInviteCodeSync(inviteCode);
      return DoctorRelationshipResult.success(relationship);
    } catch (e) {
      debugPrint('[DoctorRelationshipRepositoryHive] Find by invite code failed: $e');
      return DoctorRelationshipResult.failure(
        DoctorRelationshipErrorCodes.storageError,
        'Failed to find relationship: $e',
      );
    }
  }

  @override
  Stream<List<DoctorRelationshipModel>> watchRelationshipsForUser(String uid) {
    return _box.watch().map((_) {
      return _box.values.where((r) => 
        r.patientId == uid || r.doctorId == uid
      ).toList();
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ADDITIONAL HELPERS FOR UI INTEGRATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Gets pending doctor invites for a patient.
  /// 
  /// Used to display pending invites on patient settings/home screen.
  Future<DoctorRelationshipResult<List<DoctorRelationshipModel>>> getPendingInvitesForPatient(String uid) async {
    try {
      final relationships = _box.values.where((r) => 
        r.patientId == uid && r.status == DoctorRelationshipStatus.pending
      ).toList();

      return DoctorRelationshipResult.success(relationships);
    } catch (e) {
      debugPrint('[DoctorRelationshipRepositoryHive] Get pending invites failed: $e');
      return DoctorRelationshipResult.failure(
        DoctorRelationshipErrorCodes.storageError,
        'Failed to get pending invites: $e',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Synchronously finds a relationship by invite code.
  DoctorRelationshipModel? _findByInviteCodeSync(String inviteCode) {
    try {
      return _box.values.firstWhere(
        (r) => r.inviteCode == inviteCode,
      );
    } catch (_) {
      return null;
    }
  }

  /// Generates a human-readable 6-character invite code.
  /// Format: DOC-ABC123 (prefix + letters + digits)
  String _generateInviteCode() {
    const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ'; // Excluding I, O to avoid confusion
    const digits = '23456789'; // Excluding 0, 1 to avoid confusion
    final random = Random.secure();
    
    final letterPart = List.generate(3, (_) => letters[random.nextInt(letters.length)]).join();
    final digitPart = List.generate(3, (_) => digits[random.nextInt(digits.length)]).join();
    
    return 'DOC-$letterPart$digitPart';
  }
}
