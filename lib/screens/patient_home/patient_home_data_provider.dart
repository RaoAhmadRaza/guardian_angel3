/// PatientHomeDataProvider - Loads patient home screen data from local sources.
///
/// This service reads from:
/// - OnboardingLocalService (patient details)
/// - PatientService (SharedPreferences - legacy)
/// - Future: VitalsRepository, MedicationRepository, etc.
///
/// All reads are LOCAL ONLY. No network calls.
/// Supports Demo Mode for showcasing UI with sample data.
library;

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/patient_service.dart';
import '../../services/demo_mode_service.dart';
import '../../services/demo_data.dart';
import '../../onboarding/services/onboarding_local_service.dart';
import 'patient_home_state.dart';

/// Provider for loading patient home screen data.
class PatientHomeDataProvider {
  PatientHomeDataProvider._();
  
  static PatientHomeDataProvider? _instance;
  static PatientHomeDataProvider get instance => 
      _instance ??= PatientHomeDataProvider._();

  /// Load complete patient home state from local databases.
  /// Returns demo data if Demo Mode is enabled.
  /// 
  /// Returns a fully populated [PatientHomeState] with:
  /// - Patient profile info (required)
  /// - Vitals (optional - may be empty)
  /// - Doctor info (optional - may be placeholder)
  /// - Medications (optional - may be empty list)
  /// - Automation cards (optional - may be placeholders)
  Future<PatientHomeState> loadPatientHomeState() async {
    debugPrint('[PatientHomeDataProvider] Loading patient home state...');
    
    try {
      // Get current user UID
      final uid = FirebaseAuth.instance.currentUser?.uid;
      
      // Load patient profile first (needed for demo mode too)
      final profileData = await _loadPatientProfile(uid);
      final patientName = profileData['name'] ?? 'Patient';
      final gender = profileData['gender'] ?? 'male';
      
      // Check if demo mode is enabled
      await DemoModeService.instance.initialize();
      if (DemoModeService.instance.isEnabled) {
        debugPrint('[PatientHomeDataProvider] Demo mode enabled - returning demo data');
        return PatientHomeDemoData.state(
          patientName: patientName,
          gender: gender,
        );
      }
      
      // Load real data from local sources
      // Load vitals (currently placeholder - future: from health repository)
      final vitals = await _loadVitals(uid);
      
      // Load safety status (currently placeholder)
      final safetyStatus = await _loadSafetyStatus(uid);
      
      // Load doctor info (currently placeholder)
      final doctorInfo = await _loadDoctorInfo(uid);
      
      // Load diagnosis summary (currently placeholder)
      final diagnosisSummary = await _loadDiagnosisSummary(uid);
      
      // Load home automation data (currently placeholder)
      final automationCards = await _loadAutomationCards(uid);
      
      // Load medication schedule (currently placeholder)
      final medicationSchedule = await _loadMedicationSchedule(uid);
      
      final state = PatientHomeState(
        patientName: patientName,
        gender: gender,
        profileImageUrl: profileData['profileImageUrl'],
        vitals: vitals,
        safetyStatus: safetyStatus,
        doctorInfo: doctorInfo,
        diagnosisSummary: diagnosisSummary,
        automationCards: automationCards,
        medicationSchedule: medicationSchedule,
        loadingState: PatientHomeLoadingState.partial, // Will be recalculated
      );
      
      debugPrint('[PatientHomeDataProvider] State loaded: ${state.effectiveLoadingState}');
      return state;
    } catch (e) {
      debugPrint('[PatientHomeDataProvider] Error loading state: $e');
      // Return empty state on error
      return PatientHomeState(
        patientName: 'Patient',
        gender: 'male',
        loadingState: PatientHomeLoadingState.empty,
      );
    }
  }

  /// Load patient profile from local databases
  Future<Map<String, dynamic>> _loadPatientProfile(String? uid) async {
    // Try Hive (OnboardingLocalService) first
    if (uid != null && uid.isNotEmpty) {
      final patientDetails = OnboardingLocalService.instance.getPatientDetails(uid);
      if (patientDetails != null) {
        debugPrint('[PatientHomeDataProvider] Loaded profile from Hive');
        return {
          'name': patientDetails.name,
          'gender': patientDetails.gender,
          'phoneNumber': patientDetails.phoneNumber,
          'address': patientDetails.address,
          'medicalHistory': patientDetails.medicalHistory,
          'profileImageUrl': null, // Not stored in patient details
        };
      }
      
      // Try UserBase for profile image
      final userBase = OnboardingLocalService.instance.getUserBase(uid);
      if (userBase != null) {
        debugPrint('[PatientHomeDataProvider] Loaded user base from Hive');
        // Combine with PatientService data
        final patientData = await PatientService.instance.getPatientData();
        return {
          'name': userBase.fullName ?? patientData['fullName'] ?? 'Patient',
          'gender': patientData['gender'] ?? 'male',
          'phoneNumber': patientData['phoneNumber'] ?? '',
          'address': patientData['address'] ?? '',
          'medicalHistory': patientData['medicalHistory'] ?? '',
          'profileImageUrl': userBase.profileImageUrl,
        };
      }
    }
    
    // Fallback to SharedPreferences (PatientService)
    debugPrint('[PatientHomeDataProvider] Falling back to SharedPreferences');
    final patientData = await PatientService.instance.getPatientData();
    return {
      'name': patientData['fullName'] ?? 'Patient',
      'gender': patientData['gender'] ?? 'male',
      'phoneNumber': patientData['phoneNumber'] ?? '',
      'address': patientData['address'] ?? '',
      'medicalHistory': patientData['medicalHistory'] ?? '',
      'profileImageUrl': null,
    };
  }

  /// Load vitals data
  /// 
  /// TODO: Replace with actual VitalsRepository when available
  Future<VitalsData> _loadVitals(String? uid) async {
    // Currently no vitals repository - return simulated live data flag
    // The screen will handle live animation if no stored data
    return VitalsData.empty;
  }

  /// Load safety status
  /// 
  /// TODO: Replace with actual SafetyRepository when available
  Future<SafetyStatus> _loadSafetyStatus(String? uid) async {
    // For first-time users: no safety monitoring is active yet
    // Return unknown/not-monitored state - never fake "All Clear"
    return SafetyStatus.unknown;
  }

  /// Load assigned doctor info
  /// 
  /// TODO: Replace with actual DoctorRepository when available
  Future<DoctorInfo> _loadDoctorInfo(String? uid) async {
    // For first-time users: no doctor is assigned yet
    // Return empty placeholder - never fake a doctor name
    return DoctorInfo.empty;
  }

  /// Load diagnosis summary
  /// 
  /// TODO: Replace with actual DiagnosisRepository when available
  Future<DiagnosisSummary> _loadDiagnosisSummary(String? uid) async {
    // For first-time users: no diagnosis history exists
    // Return empty placeholder - never fake diagnosis data
    return DiagnosisSummary.empty;
  }

  /// Load home automation summary cards
  /// 
  /// TODO: Replace with actual HomeAutomationRepository when available
  Future<List<AutomationCardData>> _loadAutomationCards(String? uid) async {
    // For first-time users: no devices are connected
    // Return empty list - never seed fake device data
    return const [];
  }

  /// Load medication schedule
  /// 
  /// TODO: Replace with actual MedicationRepository when available
  Future<List<MedicationTimeSlot>> _loadMedicationSchedule(String? uid) async {
    // For first-time users: no medications are added
    // Return empty list - never seed fake medication data
    return const [];
  }
}
