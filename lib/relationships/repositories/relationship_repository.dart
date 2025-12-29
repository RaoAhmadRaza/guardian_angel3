/// RelationshipRepository - Abstract interface for relationship operations.
///
/// Defines the contract for all relationship data operations.
/// Implementations: RelationshipRepositoryHive (local-first)
library;

import '../models/relationship_model.dart';

/// Result wrapper for repository operations.
class RelationshipResult<T> {
  final bool success;
  final T? data;
  final String? errorCode;
  final String? errorMessage;

  const RelationshipResult._({
    required this.success,
    this.data,
    this.errorCode,
    this.errorMessage,
  });

  factory RelationshipResult.success(T data) => RelationshipResult._(
    success: true,
    data: data,
  );

  factory RelationshipResult.failure(String errorCode, String message) => RelationshipResult._(
    success: false,
    errorCode: errorCode,
    errorMessage: message,
  );

  /// Returns true if this is an error result.
  bool get isError => !success;
}

/// Error codes for relationship operations.
abstract class RelationshipErrorCodes {
  static const invalidInviteCode = 'INVALID_INVITE_CODE';
  static const inviteAlreadyUsed = 'INVITE_ALREADY_USED';
  static const caregiverAlreadyLinked = 'CAREGIVER_ALREADY_LINKED';
  static const relationshipRevoked = 'RELATIONSHIP_REVOKED';
  static const duplicateAccept = 'DUPLICATE_ACCEPT';
  static const notFound = 'NOT_FOUND';
  static const validationError = 'VALIDATION_ERROR';
  static const storageError = 'STORAGE_ERROR';
  static const unauthorized = 'UNAUTHORIZED';
}

/// Abstract repository interface for relationship operations.
abstract class RelationshipRepository {
  /// Creates a new pending relationship with invite code.
  /// 
  /// Called by patient after onboarding.
  /// Returns the created relationship with invite code.
  Future<RelationshipResult<RelationshipModel>> createPatientInvite({
    required String patientId,
    List<String>? permissions,
  });

  /// Accepts an invite code and links the caregiver.
  /// 
  /// Called by caregiver during onboarding.
  /// Validates:
  /// - Invite code exists and is valid
  /// - Invite is still pending
  /// - Caregiver is not already linked elsewhere
  Future<RelationshipResult<RelationshipModel>> acceptInvite({
    required String inviteCode,
    required String caregiverId,
  });

  /// Gets all relationships for a user (as patient or caregiver).
  Future<RelationshipResult<List<RelationshipModel>>> getRelationshipsForUser(String uid);

  /// Gets the active relationship for a caregiver.
  /// 
  /// Returns null if caregiver has no active relationship.
  Future<RelationshipResult<RelationshipModel?>> getActiveRelationshipForCaregiver(String uid);

  /// Gets all active relationships for a patient.
  /// 
  /// A patient can have multiple caregivers.
  Future<RelationshipResult<List<RelationshipModel>>> getActiveRelationshipsForPatient(String uid);

  /// Revokes a relationship.
  /// 
  /// Can be called by either patient or caregiver.
  Future<RelationshipResult<void>> revokeRelationship({
    required String relationshipId,
    required String requesterId,
  });

  /// Finds a relationship by invite code.
  /// 
  /// Used to validate invite codes before acceptance.
  Future<RelationshipResult<RelationshipModel?>> findByInviteCode(String inviteCode);

  /// Watches relationships for a user.
  /// 
  /// Returns a stream that emits whenever relationships change.
  Stream<List<RelationshipModel>> watchRelationshipsForUser(String uid);
}
