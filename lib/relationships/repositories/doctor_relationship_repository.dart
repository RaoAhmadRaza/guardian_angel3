/// DoctorRelationshipRepository - Abstract interface for doctor-patient relationship operations.
///
/// Defines the contract for all doctor-patient relationship data operations.
/// Implementations: DoctorRelationshipRepositoryHive (local-first)
library;

import '../models/doctor_relationship_model.dart';

/// Result wrapper for repository operations.
class DoctorRelationshipResult<T> {
  final bool success;
  final T? data;
  final String? errorCode;
  final String? errorMessage;

  const DoctorRelationshipResult._({
    required this.success,
    this.data,
    this.errorCode,
    this.errorMessage,
  });

  factory DoctorRelationshipResult.success(T data) => DoctorRelationshipResult._(
    success: true,
    data: data,
  );

  factory DoctorRelationshipResult.failure(String errorCode, String message) => DoctorRelationshipResult._(
    success: false,
    errorCode: errorCode,
    errorMessage: message,
  );

  /// Returns true if this is an error result.
  bool get isError => !success;
}

/// Error codes for doctor relationship operations.
abstract class DoctorRelationshipErrorCodes {
  static const invalidInviteCode = 'INVALID_INVITE_CODE';
  static const inviteAlreadyUsed = 'INVITE_ALREADY_USED';
  static const relationshipRevoked = 'RELATIONSHIP_REVOKED';
  static const duplicateAccept = 'DUPLICATE_ACCEPT';
  static const notFound = 'NOT_FOUND';
  static const validationError = 'VALIDATION_ERROR';
  static const storageError = 'STORAGE_ERROR';
  static const unauthorized = 'UNAUTHORIZED';
}

/// Abstract repository interface for doctor-patient relationship operations.
abstract class DoctorRelationshipRepository {
  /// Creates a new pending doctor relationship with invite code.
  /// 
  /// Called by patient after onboarding.
  /// Returns the created relationship with invite code.
  Future<DoctorRelationshipResult<DoctorRelationshipModel>> createPatientDoctorInvite({
    required String patientId,
    List<String>? permissions,
  });

  /// Accepts an invite code and links the doctor.
  /// 
  /// Called by doctor during/after onboarding.
  /// Validates:
  /// - Invite code exists and is valid
  /// - Invite is still pending
  Future<DoctorRelationshipResult<DoctorRelationshipModel>> acceptDoctorInvite({
    required String inviteCode,
    required String doctorId,
  });

  /// Gets all relationships for a user (as patient or doctor).
  Future<DoctorRelationshipResult<List<DoctorRelationshipModel>>> getRelationshipsForUser(String uid);

  /// Gets all active relationships for a doctor.
  /// 
  /// A doctor can have multiple patients.
  Future<DoctorRelationshipResult<List<DoctorRelationshipModel>>> getActiveRelationshipsForDoctor(String uid);

  /// Gets all active relationships for a patient.
  /// 
  /// A patient can have multiple doctors.
  Future<DoctorRelationshipResult<List<DoctorRelationshipModel>>> getActiveRelationshipsForPatient(String uid);

  /// Revokes a relationship.
  /// 
  /// Can be called by either patient or doctor.
  Future<DoctorRelationshipResult<void>> revokeRelationship({
    required String relationshipId,
    required String requesterId,
  });

  /// Finds a relationship by invite code.
  /// 
  /// Used to validate invite codes before acceptance.
  Future<DoctorRelationshipResult<DoctorRelationshipModel?>> findByInviteCode(String inviteCode);

  /// Watches relationships for a user.
  /// 
  /// Returns a stream that emits whenever relationships change.
  Stream<List<DoctorRelationshipModel>> watchRelationshipsForUser(String uid);
}
