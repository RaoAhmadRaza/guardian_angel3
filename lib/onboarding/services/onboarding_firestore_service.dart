/// OnboardingFirestoreService - Firestore mirror for completed onboarding.
///
/// This service ONLY writes to Firestore AFTER local onboarding is complete.
/// It mirrors the local data to Firestore collections:
/// - caregiver_users/{uid} for caregivers
/// - patient_users/{uid} for patients
///
/// Rules:
/// - NEVER writes until local onboarding is complete
/// - Uses merge: true to avoid overwriting
/// - Firestore failure does NOT affect local data
/// - Safe to re-run (idempotent)
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_base_model.dart';
import '../models/caregiver_user_model.dart';
import '../models/caregiver_details_model.dart';
import '../models/patient_user_model.dart';
import '../models/patient_details_model.dart';
import 'onboarding_local_service.dart';

/// Result of a Firestore mirror operation.
class FirestoreMirrorResult {
  final bool success;
  final String? errorMessage;
  final String? errorCode;

  const FirestoreMirrorResult._({
    required this.success,
    this.errorMessage,
    this.errorCode,
  });

  factory FirestoreMirrorResult.success() => const FirestoreMirrorResult._(success: true);

  factory FirestoreMirrorResult.failure({
    required String errorCode,
    required String errorMessage,
  }) => FirestoreMirrorResult._(
    success: false,
    errorCode: errorCode,
    errorMessage: errorMessage,
  );
}

/// Firestore mirror service for completed onboarding.
class OnboardingFirestoreService {
  OnboardingFirestoreService({
    FirebaseFirestore? firestore,
    OnboardingLocalService? localService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _localService = localService ?? OnboardingLocalService.instance;

  final FirebaseFirestore _firestore;
  final OnboardingLocalService _localService;

  static OnboardingFirestoreService? _instance;
  static OnboardingFirestoreService get instance => 
      _instance ??= OnboardingFirestoreService();

  /// Firestore collection names
  static const String _caregiverCollection = 'caregiver_users';
  static const String _patientCollection = 'patient_users';

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 5A: CAREGIVER FIRESTORE MIRROR
  // ═══════════════════════════════════════════════════════════════════════════

  /// Mirrors complete caregiver data to Firestore.
  /// 
  /// This is STEP 5A - only called when local caregiver tables are complete.
  /// Creates/updates caregiver_users/{uid} document.
  Future<FirestoreMirrorResult> mirrorCaregiverToFirestore(String uid) async {
    debugPrint('[OnboardingFirestoreService] STEP 5A: Mirroring caregiver to Firestore for uid: $uid');
    
    // GUARD: Ensure local onboarding is complete
    if (!_localService.isCaregiverOnboardingComplete(uid)) {
      debugPrint('[OnboardingFirestoreService] ERROR: Caregiver onboarding not complete - aborting Firestore write');
      return FirestoreMirrorResult.failure(
        errorCode: 'incomplete_onboarding',
        errorMessage: 'Cannot mirror to Firestore: local caregiver onboarding is not complete',
      );
    }

    try {
      // Get all local data
      final userBase = _localService.getUserBase(uid);
      final caregiverUser = _localService.getCaregiverUser(uid);
      final caregiverDetails = _localService.getCaregiverDetails(uid);

      if (userBase == null || caregiverUser == null || caregiverDetails == null) {
        return FirestoreMirrorResult.failure(
          errorCode: 'missing_data',
          errorMessage: 'Missing local data for Firestore mirror',
        );
      }

      // Build Firestore document
      final docData = _buildCaregiverDocument(userBase, caregiverUser, caregiverDetails);

      // Write to Firestore with merge
      await _firestore
          .collection(_caregiverCollection)
          .doc(uid)
          .set(docData, SetOptions(merge: true));

      debugPrint('[OnboardingFirestoreService] Caregiver mirrored to Firestore successfully');
      return FirestoreMirrorResult.success();
    } on FirebaseException catch (e) {
      debugPrint('[OnboardingFirestoreService] Firestore error: ${e.code} - ${e.message}');
      return FirestoreMirrorResult.failure(
        errorCode: e.code,
        errorMessage: e.message ?? 'Unknown Firestore error',
      );
    } catch (e) {
      debugPrint('[OnboardingFirestoreService] Unexpected error: $e');
      return FirestoreMirrorResult.failure(
        errorCode: 'unknown',
        errorMessage: e.toString(),
      );
    }
  }

  /// Builds caregiver Firestore document from local data.
  Map<String, dynamic> _buildCaregiverDocument(
    UserBaseModel userBase,
    CaregiverUserModel caregiverUser,
    CaregiverDetailsModel caregiverDetails,
  ) {
    return {
      // From User Base Table
      'uid': userBase.uid,
      'email': userBase.email,
      'full_name': userBase.fullName,
      'profile_image_url': userBase.profileImageUrl,
      
      // From Caregiver User Table
      'role': caregiverUser.role,
      
      // From Caregiver Details Table
      'caregiver_name': caregiverDetails.caregiverName,
      'phone_number': caregiverDetails.phoneNumber,
      'email_address': caregiverDetails.emailAddress,
      'relation_to_patient': caregiverDetails.relationToPatient,
      'patient_name': caregiverDetails.patientName,
      
      // Metadata
      'is_complete': true,
      'created_at': userBase.createdAt.toIso8601String(),
      'updated_at': FieldValue.serverTimestamp(),
      'synced_at': FieldValue.serverTimestamp(),
    }..removeWhere((k, v) => v == null);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 6B: PATIENT FIRESTORE MIRROR
  // ═══════════════════════════════════════════════════════════════════════════

  /// Mirrors complete patient data to Firestore.
  /// 
  /// This is STEP 6B - only called when local patient tables are complete.
  /// Creates/updates patient_users/{uid} document.
  Future<FirestoreMirrorResult> mirrorPatientToFirestore(String uid) async {
    debugPrint('[OnboardingFirestoreService] STEP 6B: Mirroring patient to Firestore for uid: $uid');
    
    // GUARD: Ensure local onboarding is complete
    if (!_localService.isPatientOnboardingComplete(uid)) {
      debugPrint('[OnboardingFirestoreService] ERROR: Patient onboarding not complete - aborting Firestore write');
      return FirestoreMirrorResult.failure(
        errorCode: 'incomplete_onboarding',
        errorMessage: 'Cannot mirror to Firestore: local patient onboarding is not complete',
      );
    }

    try {
      // Get all local data
      final userBase = _localService.getUserBase(uid);
      final patientUser = _localService.getPatientUser(uid);
      final patientDetails = _localService.getPatientDetails(uid);

      if (userBase == null || patientUser == null || patientDetails == null) {
        return FirestoreMirrorResult.failure(
          errorCode: 'missing_data',
          errorMessage: 'Missing local data for Firestore mirror',
        );
      }

      // Build Firestore document
      final docData = _buildPatientDocument(userBase, patientUser, patientDetails);

      // Write to Firestore with merge
      await _firestore
          .collection(_patientCollection)
          .doc(uid)
          .set(docData, SetOptions(merge: true));

      debugPrint('[OnboardingFirestoreService] Patient mirrored to Firestore successfully');
      return FirestoreMirrorResult.success();
    } on FirebaseException catch (e) {
      debugPrint('[OnboardingFirestoreService] Firestore error: ${e.code} - ${e.message}');
      return FirestoreMirrorResult.failure(
        errorCode: e.code,
        errorMessage: e.message ?? 'Unknown Firestore error',
      );
    } catch (e) {
      debugPrint('[OnboardingFirestoreService] Unexpected error: $e');
      return FirestoreMirrorResult.failure(
        errorCode: 'unknown',
        errorMessage: e.toString(),
      );
    }
  }

  /// Builds patient Firestore document from local data.
  Map<String, dynamic> _buildPatientDocument(
    UserBaseModel userBase,
    PatientUserModel patientUser,
    PatientDetailsModel patientDetails,
  ) {
    return {
      // From User Base Table
      'uid': userBase.uid,
      'email': userBase.email,
      'full_name': userBase.fullName,
      'profile_image_url': userBase.profileImageUrl,
      
      // From Patient User Table
      'role': patientUser.role,
      'age': patientUser.age,
      
      // From Patient Details Table
      'gender': patientDetails.gender,
      'name': patientDetails.name,
      'phone_number': patientDetails.phoneNumber,
      'address': patientDetails.address,
      'medical_history': patientDetails.medicalHistory,
      
      // Metadata
      'is_complete': true,
      'created_at': userBase.createdAt.toIso8601String(),
      'updated_at': FieldValue.serverTimestamp(),
      'synced_at': FieldValue.serverTimestamp(),
    }..removeWhere((k, v) => v == null);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RETRY / SYNC UTILITIES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Attempts to mirror completed onboarding to Firestore.
  /// 
  /// Automatically determines caregiver vs patient and mirrors accordingly.
  /// Returns success only if local is complete AND Firestore write succeeds.
  Future<FirestoreMirrorResult> mirrorIfComplete(String uid) async {
    final state = _localService.getOnboardingState(uid);
    
    if (state == OnboardingState.caregiverComplete) {
      return mirrorCaregiverToFirestore(uid);
    }
    
    if (state == OnboardingState.patientComplete) {
      return mirrorPatientToFirestore(uid);
    }
    
    debugPrint('[OnboardingFirestoreService] Onboarding not complete, skipping Firestore mirror');
    return FirestoreMirrorResult.failure(
      errorCode: 'incomplete',
      errorMessage: 'Onboarding is not complete. Current state: $state',
    );
  }
}
