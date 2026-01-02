/// OnboardingLocalService - Local-first onboarding persistence.
///
/// This is the CORE service for strict offline-first onboarding.
/// It handles all local tables in the correct sequence:
/// 
/// 1. UserBaseTable - Auth basics (Step 1)
/// 2. CaregiverUserTable / PatientUserTable / DoctorUserTable - Role assignment (Step 3)
/// 3. CaregiverDetailsTable / PatientDetailsTable / DoctorDetailsTable - Full details (Step 4/5)
///
/// Rules:
/// - Local writes ALWAYS happen first
/// - Firestore writes NEVER happen until onboarding is complete
/// - Each table is separate (no merging)
/// - Idempotent - safe to re-run
library;

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../../persistence/box_registry.dart';
import '../models/user_base_model.dart';
import '../models/caregiver_user_model.dart';
import '../models/caregiver_details_model.dart';
import '../models/patient_user_model.dart';
import '../models/patient_details_model.dart';
import '../models/doctor_user_model.dart';
import '../models/doctor_details_model.dart';

/// Result of a local save operation.
class LocalSaveResult<T> {
  final bool success;
  final T? data;
  final String? errorMessage;

  const LocalSaveResult._({
    required this.success,
    this.data,
    this.errorMessage,
  });

  factory LocalSaveResult.success(T data) => LocalSaveResult._(
    success: true,
    data: data,
  );

  factory LocalSaveResult.failure(String message) => LocalSaveResult._(
    success: false,
    errorMessage: message,
  );
}

/// Local-first onboarding persistence service.
class OnboardingLocalService {
  OnboardingLocalService._();
  
  static OnboardingLocalService? _instance;
  static OnboardingLocalService get instance => _instance ??= OnboardingLocalService._();

  // ═══════════════════════════════════════════════════════════════════════════
  // BOX ACCESSORS
  // ═══════════════════════════════════════════════════════════════════════════

  Box<UserBaseModel> get _userBaseBox => 
      Hive.box<UserBaseModel>(BoxRegistry.userBaseBox);

  Box<CaregiverUserModel> get _caregiverUserBox => 
      Hive.box<CaregiverUserModel>(BoxRegistry.caregiverUserBox);

  Box<CaregiverDetailsModel> get _caregiverDetailsBox => 
      Hive.box<CaregiverDetailsModel>(BoxRegistry.caregiverDetailsBox);

  Box<PatientUserModel> get _patientUserBox => 
      Hive.box<PatientUserModel>(BoxRegistry.patientUserBox);

  Box<PatientDetailsModel> get _patientDetailsBox => 
      Hive.box<PatientDetailsModel>(BoxRegistry.patientDetailsBox);

  Box<DoctorUserModel> get _doctorUserBox => 
      Hive.box<DoctorUserModel>(BoxRegistry.doctorUserBox);

  Box<DoctorDetailsModel> get _doctorDetailsBox => 
      Hive.box<DoctorDetailsModel>(BoxRegistry.doctorDetailsBox);

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 1: USER BASE TABLE (Auth basics)
  // ═══════════════════════════════════════════════════════════════════════════
  /// Saves auth basics to User Base Table immediately after authentication.
  /// 
  /// This is STEP 1 - runs exactly once per auth session.
  /// Does NOT ask for role. Does NOT write to Firestore.
  Future<LocalSaveResult<UserBaseModel>> saveUserBase({
    required String uid,
    String? email,
    String? fullName,
    String? profileImageUrl,
  }) async {
    debugPrint('[OnboardingLocalService] STEP 1: Saving user base for uid: $uid');
    
    try {
      final now = DateTime.now().toUtc();
      
      // Check if already exists
      final existing = _userBaseBox.get(uid);
      
      final model = UserBaseModel(
        uid: uid,
        email: email,
        fullName: fullName,
        profileImageUrl: profileImageUrl,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );
      
      model.validate();
      await _userBaseBox.put(uid, model);
      
      debugPrint('[OnboardingLocalService] User base saved successfully');
      return LocalSaveResult.success(model);
    } catch (e) {
      debugPrint('[OnboardingLocalService] STEP 1 FAILED: $e');
      return LocalSaveResult.failure('Failed to save user base: $e');
    }
  }

  /// Gets the current user base data.
  UserBaseModel? getUserBase(String uid) => _userBaseBox.get(uid);

  /// Checks if user base exists for uid.
  bool hasUserBase(String uid) => _userBaseBox.containsKey(uid);

  /// Gets the most recently saved user's UID from local storage.
  /// 
  /// This is useful for simulator mode where FirebaseAuth.instance.currentUser
  /// is null but we still have a locally saved user from the mock auth flow.
  /// Returns null if no users exist in local storage.
  String? getLastSavedUid() {
    try {
      if (_userBaseBox.isEmpty) return null;
      
      // Get all users and find the one with the most recent updatedAt
      final users = _userBaseBox.values.toList();
      if (users.isEmpty) return null;
      
      users.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final lastUser = users.first;
      debugPrint('[OnboardingLocalService] getLastSavedUid: ${lastUser.uid}');
      return lastUser.uid;
    } catch (e) {
      debugPrint('[OnboardingLocalService] getLastSavedUid FAILED: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 3A: CAREGIVER USER TABLE (Role assignment)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Saves caregiver role to Caregiver User Table.
  /// 
  /// This is STEP 3A - only if user selects "Caregiver".
  /// Does NOT write to Firestore.
  Future<LocalSaveResult<CaregiverUserModel>> saveCaregiverRole({
    required String uid,
  }) async {
    debugPrint('[OnboardingLocalService] STEP 3A: Saving caregiver role for uid: $uid');
    
    try {
      final now = DateTime.now().toUtc();
      
      final existing = _caregiverUserBox.get(uid);
      
      final model = CaregiverUserModel(
        uid: uid,
        role: 'caregiver',
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );
      
      model.validate();
      await _caregiverUserBox.put(uid, model);
      
      debugPrint('[OnboardingLocalService] Caregiver role saved successfully');
      return LocalSaveResult.success(model);
    } catch (e) {
      debugPrint('[OnboardingLocalService] STEP 3A FAILED: $e');
      return LocalSaveResult.failure('Failed to save caregiver role: $e');
    }
  }

  /// Gets the caregiver user record.
  CaregiverUserModel? getCaregiverUser(String uid) => _caregiverUserBox.get(uid);

  /// Checks if caregiver role is assigned.
  bool isCaregiverRole(String uid) => _caregiverUserBox.containsKey(uid);

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 4A: CAREGIVER DETAILS TABLE (Full details)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Saves caregiver details to Caregiver Details Table.
  /// 
  /// This is STEP 4A - from Caregiver Details Screen.
  /// Does NOT write to Firestore yet.
  Future<LocalSaveResult<CaregiverDetailsModel>> saveCaregiverDetails({
    required String uid,
    required String caregiverName,
    required String phoneNumber,
    required String emailAddress,
    required String relationToPatient,
    required String patientName,
  }) async {
    debugPrint('[OnboardingLocalService] STEP 4A: Saving caregiver details for uid: $uid');
    
    try {
      final now = DateTime.now().toUtc();
      
      final existing = _caregiverDetailsBox.get(uid);
      
      final model = CaregiverDetailsModel(
        uid: uid,
        caregiverName: caregiverName,
        phoneNumber: phoneNumber,
        emailAddress: emailAddress,
        relationToPatient: relationToPatient,
        patientName: patientName,
        isComplete: true, // Mark as complete since all fields provided
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );
      
      model.validate();
      await _caregiverDetailsBox.put(uid, model);
      
      debugPrint('[OnboardingLocalService] Caregiver details saved successfully (isComplete: true)');
      return LocalSaveResult.success(model);
    } catch (e) {
      debugPrint('[OnboardingLocalService] STEP 4A FAILED: $e');
      return LocalSaveResult.failure('Failed to save caregiver details: $e');
    }
  }

  /// Gets caregiver details.
  CaregiverDetailsModel? getCaregiverDetails(String uid) => _caregiverDetailsBox.get(uid);

  /// Checks if caregiver details are complete.
  bool isCaregiverOnboardingComplete(String uid) {
    final details = _caregiverDetailsBox.get(uid);
    return details?.isComplete ?? false;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 3B: PATIENT USER TABLE (Role assignment + Age)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Saves patient role and age to Patient User Table.
  /// 
  /// This is STEP 3B + STEP 4B combined - role + age from Age Selection Screen.
  /// Age must be >= 60. Does NOT write to Firestore.
  Future<LocalSaveResult<PatientUserModel>> savePatientRole({
    required String uid,
    required int age,
  }) async {
    debugPrint('[OnboardingLocalService] STEP 3B/4B: Saving patient role (age: $age) for uid: $uid');
    
    // Age validation
    if (age < 60) {
      return LocalSaveResult.failure('Age must be at least 60 years');
    }
    
    try {
      final now = DateTime.now().toUtc();
      
      final existing = _patientUserBox.get(uid);
      
      final model = PatientUserModel(
        uid: uid,
        role: 'patient',
        age: age,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );
      
      model.validate();
      await _patientUserBox.put(uid, model);
      
      debugPrint('[OnboardingLocalService] Patient role saved successfully');
      return LocalSaveResult.success(model);
    } catch (e) {
      debugPrint('[OnboardingLocalService] STEP 3B/4B FAILED: $e');
      return LocalSaveResult.failure('Failed to save patient role: $e');
    }
  }

  /// Gets the patient user record.
  PatientUserModel? getPatientUser(String uid) => _patientUserBox.get(uid);

  /// Checks if patient role is assigned.
  bool isPatientRole(String uid) => _patientUserBox.containsKey(uid);

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 5B: PATIENT DETAILS TABLE (Full details)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Saves patient details to Patient Details Table.
  /// 
  /// This is STEP 5B - from Patient Details Screen.
  /// Does NOT write to Firestore yet.
  Future<LocalSaveResult<PatientDetailsModel>> savePatientDetails({
    required String uid,
    required String gender,
    required String name,
    required String phoneNumber,
    required String address,
    required String medicalHistory,
  }) async {
    debugPrint('[OnboardingLocalService] STEP 5B: Saving patient details for uid: $uid');
    
    try {
      final now = DateTime.now().toUtc();
      
      final existing = _patientDetailsBox.get(uid);
      
      final model = PatientDetailsModel(
        uid: uid,
        gender: gender.toLowerCase(),
        name: name,
        phoneNumber: phoneNumber,
        address: address,
        medicalHistory: medicalHistory,
        isComplete: true, // Mark as complete since all required fields provided
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );
      
      model.validate();
      await _patientDetailsBox.put(uid, model);
      
      debugPrint('[OnboardingLocalService] Patient details saved successfully (isComplete: true)');
      return LocalSaveResult.success(model);
    } catch (e) {
      debugPrint('[OnboardingLocalService] STEP 5B FAILED: $e');
      return LocalSaveResult.failure('Failed to save patient details: $e');
    }
  }

  /// Gets patient details.
  PatientDetailsModel? getPatientDetails(String uid) => _patientDetailsBox.get(uid);

  /// Checks if patient details are complete.
  bool isPatientOnboardingComplete(String uid) {
    final details = _patientDetailsBox.get(uid);
    return details?.isComplete ?? false;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 3C: DOCTOR USER TABLE (Role assignment)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Saves doctor role to Doctor User Table.
  /// 
  /// This is STEP 3C - only if user selects "Doctor".
  /// Does NOT write to Firestore.
  Future<LocalSaveResult<DoctorUserModel>> saveDoctorRole({
    required String uid,
  }) async {
    debugPrint('[OnboardingLocalService] STEP 3C: Saving doctor role for uid: $uid');
    
    try {
      final now = DateTime.now().toUtc();
      
      final existing = _doctorUserBox.get(uid);
      
      final model = DoctorUserModel(
        uid: uid,
        role: 'doctor',
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );
      
      model.validate();
      await _doctorUserBox.put(uid, model);
      
      debugPrint('[OnboardingLocalService] Doctor role saved successfully');
      return LocalSaveResult.success(model);
    } catch (e) {
      debugPrint('[OnboardingLocalService] STEP 3C FAILED: $e');
      return LocalSaveResult.failure('Failed to save doctor role: $e');
    }
  }

  /// Gets the doctor user record.
  DoctorUserModel? getDoctorUser(String uid) => _doctorUserBox.get(uid);

  /// Checks if doctor role is assigned.
  bool isDoctorRole(String uid) => _doctorUserBox.containsKey(uid);

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 4C: DOCTOR DETAILS TABLE (Full details)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Saves doctor details to Doctor Details Table.
  /// 
  /// This is STEP 4C - from Doctor Details Screen.
  /// Does NOT write to Firestore yet.
  Future<LocalSaveResult<DoctorDetailsModel>> saveDoctorDetails({
    required String uid,
    required String fullName,
    required String email,
    required String phoneNumber,
    required String specialization,
    required String licenseNumber,
    required int yearsOfExperience,
    required String clinicOrHospitalName,
    required String address,
  }) async {
    debugPrint('[OnboardingLocalService] STEP 4C: Saving doctor details for uid: $uid');
    
    try {
      final now = DateTime.now().toUtc();
      
      final existing = _doctorDetailsBox.get(uid);
      
      final model = DoctorDetailsModel(
        uid: uid,
        fullName: fullName,
        email: email,
        phoneNumber: phoneNumber,
        specialization: specialization,
        licenseNumber: licenseNumber,
        yearsOfExperience: yearsOfExperience,
        clinicOrHospitalName: clinicOrHospitalName,
        address: address,
        isVerified: false, // Default to unverified
        isComplete: true, // Mark as complete since all required fields provided
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );
      
      model.validate();
      await _doctorDetailsBox.put(uid, model);
      
      debugPrint('[OnboardingLocalService] Doctor details saved successfully (isComplete: true)');
      return LocalSaveResult.success(model);
    } catch (e) {
      debugPrint('[OnboardingLocalService] STEP 4C FAILED: $e');
      return LocalSaveResult.failure('Failed to save doctor details: $e');
    }
  }

  /// Gets doctor details.
  DoctorDetailsModel? getDoctorDetails(String uid) => _doctorDetailsBox.get(uid);

  /// Checks if doctor details are complete.
  bool isDoctorOnboardingComplete(String uid) {
    final details = _doctorDetailsBox.get(uid);
    return details?.isComplete ?? false;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ONBOARDING STATUS CHECKS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Gets the current onboarding state for a user.
  OnboardingState getOnboardingState(String uid) {
    // Check Step 1: User Base
    if (!hasUserBase(uid)) {
      return OnboardingState.notStarted;
    }

    // Check if role is assigned
    final isCaregiver = isCaregiverRole(uid);
    final isPatient = isPatientRole(uid);
    final isDoctor = isDoctorRole(uid);

    if (!isCaregiver && !isPatient && !isDoctor) {
      return OnboardingState.awaitingRoleSelection;
    }

    // Caregiver flow
    if (isCaregiver) {
      if (isCaregiverOnboardingComplete(uid)) {
        return OnboardingState.caregiverComplete;
      }
      return OnboardingState.caregiverAwaitingDetails;
    }

    // Patient flow
    if (isPatient) {
      if (isPatientOnboardingComplete(uid)) {
        return OnboardingState.patientComplete;
      }
      return OnboardingState.patientAwaitingDetails;
    }

    // Doctor flow
    if (isDoctor) {
      if (isDoctorOnboardingComplete(uid)) {
        return OnboardingState.doctorComplete;
      }
      return OnboardingState.doctorAwaitingDetails;
    }

    return OnboardingState.notStarted;
  }

  /// Checks if onboarding is fully complete (ready for Firestore mirror).
  bool isOnboardingComplete(String uid) {
    final state = getOnboardingState(uid);
    return state == OnboardingState.caregiverComplete || 
           state == OnboardingState.patientComplete ||
           state == OnboardingState.doctorComplete;
  }
}

/// Represents the current state of onboarding.
enum OnboardingState {
  /// No data saved yet
  notStarted,
  
  /// User Base saved, waiting for role selection
  awaitingRoleSelection,
  
  /// Caregiver role assigned, waiting for details
  caregiverAwaitingDetails,
  
  /// Caregiver details complete, ready for Firestore mirror
  caregiverComplete,
  
  /// Patient role assigned with age, waiting for details
  patientAwaitingDetails,
  
  /// Patient details complete, ready for Firestore mirror
  patientComplete,
  
  /// Doctor role assigned, waiting for details
  doctorAwaitingDetails,
  
  /// Doctor details complete, ready for Firestore mirror
  doctorComplete,
}
