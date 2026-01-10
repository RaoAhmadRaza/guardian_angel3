/// PatientHomeDataProvider - Loads patient home screen data from local sources.
///
/// This service reads from:
/// - OnboardingLocalService (patient details)
/// - PatientService (SharedPreferences - legacy)
/// - VitalsRepository (Hive - real vitals data)
/// - MedicationService (SharedPreferences - medication tracking)
/// - DoctorRelationshipService (Firestore - doctor relationships)
///
/// All reads are LOCAL ONLY. No network calls (except doctor relationships).
/// Supports Demo Mode for showcasing UI with sample data.
library;

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/patient_service.dart';
import '../../services/demo_mode_service.dart';
import '../../services/demo_data.dart';
import '../../services/medication_service.dart';
import '../../onboarding/services/onboarding_local_service.dart';
import '../../relationships/services/doctor_relationship_service.dart';
import '../../relationships/models/doctor_relationship_model.dart';
import '../../repositories/vitals_repository.dart';
import '../../repositories/impl/vitals_repository_hive.dart';
import '../../persistence/wrappers/box_accessor.dart';
import 'patient_home_state.dart';

/// Provider for loading patient home screen data.
class PatientHomeDataProvider {
  PatientHomeDataProvider._();
  
  static PatientHomeDataProvider? _instance;
  static PatientHomeDataProvider get instance => 
      _instance ??= PatientHomeDataProvider._();

  // Lazy-loaded vitals repository
  VitalsRepository? _vitalsRepository;
  VitalsRepository get _vitalsRepo {
    _vitalsRepository ??= VitalsRepositoryHive(boxAccessor: BoxAccessor());
    return _vitalsRepository!;
  }

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

  /// Load vitals data from VitalsRepository
  Future<VitalsData> _loadVitals(String? uid) async {
    if (uid == null || uid.isEmpty) return VitalsData.empty;
    
    try {
      final latestVital = await _vitalsRepo.getLatestForUser(uid);
      if (latestVital != null) {
        debugPrint('[PatientHomeDataProvider] Loaded vitals from repository');
        return VitalsData(
          systolicBP: latestVital.systolicBp,
          diastolicBP: latestVital.diastolicBp,
          heartRate: latestVital.heartRate,
          oxygenPercent: latestVital.oxygenPercent,
          lastUpdated: latestVital.recordedAt,
        );
      }
    } catch (e) {
      debugPrint('[PatientHomeDataProvider] Error loading vitals: $e');
    }
    
    // No vitals data available yet
    return VitalsData.empty;
  }

  /// Load safety status based on location and thresholds
  Future<SafetyStatus> _loadSafetyStatus(String? uid) async {
    // For now, return "All Clear" if user exists, otherwise unknown
    // Future: integrate with location service and safe zones
    if (uid == null || uid.isEmpty) return SafetyStatus.unknown;
    
    // Check if user has set up monitoring (has any vitals data)
    try {
      final vitals = await _vitalsRepo.getForUser(uid);
      if (vitals.isNotEmpty) {
        return SafetyStatus.allClear;
      }
    } catch (_) {}
    
    return SafetyStatus.unknown;
  }

  /// Load assigned doctor info from relationships
  Future<DoctorInfo> _loadDoctorInfo(String? uid) async {
    if (uid == null || uid.isEmpty) return DoctorInfo.empty;
    
    try {
      final result = await DoctorRelationshipService.instance.getRelationshipsForUser(uid);
      if (result.success && result.data != null) {
        // Find active doctor relationship where user is the patient
        DoctorRelationshipModel? activeRelationship;
        for (final r in result.data!) {
          if (r.patientId == uid && r.status == DoctorRelationshipStatus.active && r.doctorId != null) {
            activeRelationship = r;
            break;
          }
        }
        
        if (activeRelationship?.doctorId != null) {
          // Fetch doctor info from Firestore
          final doc = await FirebaseFirestore.instance
              .collection('doctors')
              .doc(activeRelationship!.doctorId)
              .get();
          
          if (doc.exists && doc.data() != null) {
            final data = doc.data()!;
            return DoctorInfo(
              name: data['full_name'] as String? ?? data['name'] as String? ?? 'Doctor',
              specialty: data['specialization'] as String? ?? 'General Practitioner',
              phoneNumber: data['phone_number'] as String?,
              imageUrl: data['profile_image'] as String?,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[PatientHomeDataProvider] Error loading doctor info: $e');
    }
    
    return DoctorInfo.empty;
  }

  /// Load diagnosis summary (from vitals history)
  Future<DiagnosisSummary> _loadDiagnosisSummary(String? uid) async {
    if (uid == null || uid.isEmpty) return DiagnosisSummary.empty;
    
    try {
      final vitals = await _vitalsRepo.getForUser(uid);
      if (vitals.isNotEmpty) {
        final latest = vitals.first;
        return DiagnosisSummary(
          title: 'Heart Health',
          subtitle: 'Vitals tracking active',
          lastDiagnosisDate: latest.recordedAt,
        );
      }
    } catch (e) {
      debugPrint('[PatientHomeDataProvider] Error loading diagnosis: $e');
    }
    
    return DiagnosisSummary.empty;
  }

  /// Load home automation summary cards
  Future<List<AutomationCardData>> _loadAutomationCards(String? uid) async {
    // Home automation is handled by the separate HomeAutomationRepository
    // For the summary on home screen, we return empty (user navigates to full screen)
    return const [];
  }

  /// Load medication schedule from MedicationService
  Future<List<MedicationTimeSlot>> _loadMedicationSchedule(String? uid) async {
    if (uid == null || uid.isEmpty) return [];
    
    try {
      final medications = await MedicationService.instance.getMedications(uid);
      if (medications.isEmpty) return [];
      
      // Group medications by time
      final Map<String, List<MedicationEntry>> byTime = {};
      for (final med in medications) {
        final entries = byTime[med.time] ?? [];
        entries.add(MedicationEntry(
          name: med.name,
          dose: med.dose,
          type: med.type,
        ));
        byTime[med.time] = entries;
      }
      
      // Convert to time slots, sorted by time
      final slots = byTime.entries
          .map((e) => MedicationTimeSlot(time: e.key, medications: e.value))
          .toList()
        ..sort((a, b) => a.time.compareTo(b.time));
      
      debugPrint('[PatientHomeDataProvider] Loaded ${slots.length} medication slots');
      return slots;
    } catch (e) {
      debugPrint('[PatientHomeDataProvider] Error loading medications: $e');
      return [];
    }
  }
}
