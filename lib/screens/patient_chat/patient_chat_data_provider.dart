/// Patient Chat Data Provider
/// 
/// Production-safe data loading service for patient chat screen.
/// Returns empty state for first-time users.
/// Integrates with: GuardianService, MedicationService, DoctorRelationshipService
/// 
/// NO FAKE DATA - Loads real data only.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:guardian_angel_fyp/screens/patient_chat/patient_chat_state.dart';
import 'package:guardian_angel_fyp/screens/patient_chat_screen.dart';
import 'package:guardian_angel_fyp/services/guardian_service.dart';
import 'package:guardian_angel_fyp/services/medication_service.dart';
import 'package:guardian_angel_fyp/relationships/services/doctor_relationship_service.dart';
import 'package:guardian_angel_fyp/relationships/services/relationship_service.dart';
import 'package:guardian_angel_fyp/models/guardian_model.dart';

/// Singleton data provider for patient chat screen
class PatientChatDataProvider {
  // Singleton instance
  static final PatientChatDataProvider _instance = PatientChatDataProvider._internal();
  factory PatientChatDataProvider() => _instance;
  PatientChatDataProvider._internal();
  
  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;
  
  /// Load initial state for patient chat screen
  /// 
  /// For first-time users, returns empty state with no fake data.
  Future<PatientChatState> loadInitialState({required String patientName}) async {
    // Load care team from local storage and Firebase
    final careTeam = await _loadCareTeam();
    
    // Load medication status from MedicationService
    final medicationStatus = await _loadMedicationStatus();
    
    // Load peace status from local storage
    final peaceStatus = await _loadPeaceStatus();
    
    // Load community status from local storage
    final communityStatus = await _loadCommunityStatus();
    
    // Calculate total unread messages
    final totalUnread = careTeam.fold<int>(0, (sum, s) => sum + s.unreadCount);
    
    // Determine dynamic island subtitle based on state
    final subtitle = _getDynamicIslandSubtitle(
      careTeam: careTeam,
      medicationStatus: medicationStatus,
      totalUnread: totalUnread,
    );
    
    return PatientChatState(
      patientName: patientName,
      today: DateTime.now(),
      careTeam: careTeam,
      totalUnreadMessages: totalUnread,
      medicationStatus: medicationStatus,
      peaceStatus: peaceStatus,
      communityStatus: communityStatus,
      dynamicIslandSubtitle: subtitle,
    );
  }
  
  /// Load care team members from RelationshipService, GuardianService and DoctorRelationshipService
  Future<List<ChatSession>> _loadCareTeam() async {
    final uid = _currentUid;
    if (uid == null) return const [];
    
    final List<ChatSession> team = [];
    
    try {
      // Step 1: Sync relationships from Firestore to local Hive
      // This ensures we have the latest caregiver acceptances
      debugPrint('[PatientChatDataProvider] Syncing relationships from Firestore...');
      await RelationshipService.instance.syncFromFirestore(uid);
      
      // Step 2: Load active relationships (caregivers) from RelationshipService
      final relResult = await RelationshipService.instance.getActiveRelationshipsForPatient(uid);
      if (relResult.success && relResult.data != null) {
        for (final rel in relResult.data!) {
          if (rel.caregiverId != null && rel.caregiverId!.isNotEmpty) {
            // Fetch caregiver info from Firestore
            try {
              final caregiverDoc = await FirebaseFirestore.instance
                  .collection('caregiver_users')
                  .doc(rel.caregiverId)
                  .get();
              
              String caregiverName = 'Caregiver';
              String relation = 'Caregiver';
              
              if (caregiverDoc.exists && caregiverDoc.data() != null) {
                final data = caregiverDoc.data()!;
                caregiverName = data['caregiver_name'] as String? ?? 
                               data['name'] as String? ?? 
                               data['display_name'] as String? ??
                               'Caregiver';
                relation = data['relation'] as String? ?? 
                          data['relationship'] as String? ?? 
                          'Caregiver';
              }
              
              team.add(ChatSession(
                id: rel.caregiverId!,
                type: ViewType.CAREGIVER,
                name: caregiverName,
                subtitle: relation,
                unreadCount: 0,
                isOnline: false,
              ));
              debugPrint('[PatientChatDataProvider] Added caregiver: $caregiverName');
            } catch (e) {
              debugPrint('[PatientChatDataProvider] Error fetching caregiver info: $e');
              // Still add the caregiver with default info
              team.add(ChatSession(
                id: rel.caregiverId!,
                type: ViewType.CAREGIVER,
                name: 'Caregiver',
                subtitle: 'Caregiver',
                unreadCount: 0,
                isOnline: false,
              ));
            }
          }
        }
      }
      
      // Step 3: Also load from legacy GuardianService for backward compatibility
      final guardians = await GuardianService.instance.getGuardians(uid);
      for (final guardian in guardians.where((g) => g.status.name == 'active')) {
        // Skip if already added from RelationshipService
        if (team.any((t) => t.id == guardian.id)) continue;
        
        team.add(ChatSession(
          id: guardian.id,
          type: ViewType.CAREGIVER,
          name: guardian.name,
          subtitle: guardian.relation,
          unreadCount: 0,
          isOnline: false,
        ));
      }
      
      // Step 4: Load doctor relationships
      final docResult = await DoctorRelationshipService.instance.getRelationshipsForUser(uid);
      if (docResult.success && docResult.data != null) {
        for (final rel in docResult.data!.where((r) => r.status.name == 'active' && r.doctorId != null)) {
          // Fetch doctor info
          try {
            final doc = await FirebaseFirestore.instance
                .collection('doctors')
                .doc(rel.doctorId)
                .get();
            
            if (doc.exists && doc.data() != null) {
              final data = doc.data()!;
              team.add(ChatSession(
                id: rel.doctorId!,
                type: ViewType.DOCTOR,
                name: data['full_name'] as String? ?? data['name'] as String? ?? 'Doctor',
                subtitle: data['specialization'] as String? ?? 'Doctor',
                unreadCount: 0,
                isOnline: false,
              ));
            }
          } catch (e) {
            debugPrint('[PatientChatDataProvider] Error fetching doctor: $e');
          }
        }
      }
      
      debugPrint('[PatientChatDataProvider] Loaded ${team.length} care team members');
    } catch (e) {
      debugPrint('[PatientChatDataProvider] Error loading care team: $e');
    }
    
    return team;
  }
  
  /// Load medication tracking status from MedicationService
  Future<MedicationStatus?> _loadMedicationStatus() async {
    final uid = _currentUid;
    if (uid == null) return null;
    
    try {
      final medications = await MedicationService.instance.getMedications(uid);
      if (medications.isEmpty) return null;
      
      // Calculate today's progress based on isTaken status
      final takenMeds = medications.where((m) => m.isTaken).toList();
      
      final taken = takenMeds.length;
      final total = medications.length;
      final progressPercent = total > 0 ? ((taken / total) * 100).round() : 0;
      
      if (taken >= total) {
        return const MedicationStatus(
          status: 'All medications taken',
          progressPercent: 100,
        );
      }
      
      return MedicationStatus(
        status: '$taken of $total taken today',
        progressPercent: progressPercent,
      );
    } catch (e) {
      debugPrint('[PatientChatDataProvider] Error loading medication status: $e');
      return null;
    }
  }
  
  /// Load peace of mind / mindfulness status
  /// Returns null for first-time users (not started)
  Future<PeaceStatus?> _loadPeaceStatus() async {
    // Peace/mindfulness features are not yet implemented with storage
    // TODO: Implement when mindfulness tracking is added
    return null;
  }
  
  /// Load community engagement status
  /// Returns null for first-time users (not joined)
  Future<CommunityStatus?> _loadCommunityStatus() async {
    // Community features are not yet implemented with storage
    // TODO: Implement when community features are added
    return null;
  }
  
  /// Determine appropriate dynamic island subtitle based on state
  String _getDynamicIslandSubtitle({
    required List<ChatSession> careTeam,
    required MedicationStatus? medicationStatus,
    required int totalUnread,
  }) {
    // First-time user - no care team, no setup
    if (careTeam.isEmpty && medicationStatus == null) {
      return 'Ready when you need help';
    }
    
    // Has unread messages
    if (totalUnread > 0) {
      return '$totalUnread unread message${totalUnread > 1 ? 's' : ''}';
    }
    
    // Has care team but no messages
    if (careTeam.isNotEmpty) {
      return 'Your care team is here';
    }
    
    // Has medication setup
    if (medicationStatus != null) {
      return medicationStatus.status;
    }
    
    // Default
    return 'Ready when you need help';
  }
  
  /// Refresh state with updated data
  /// Call this after adding care team members, medications, etc.
  Future<PatientChatState> refreshState(PatientChatState currentState) async {
    return loadInitialState(patientName: currentState.patientName);
  }
  
  /// Add a care team member (guardian)
  Future<void> addCareTeamMember(ChatSession session) async {
    final uid = _currentUid;
    if (uid == null) return;
    
    // Create guardian from session data using factory
    final guardian = GuardianModel.create(
      patientId: uid,
      name: session.name,
      relation: session.subtitle ?? 'Guardian',
      phoneNumber: '',
    );
    await GuardianService.instance.saveGuardian(guardian);
  }
  
  /// Update medication status - refreshes from service on next load
  Future<void> updateMedicationStatus(MedicationStatus status) async {
    // Medication status is computed from MedicationService
    // This method exists for interface compatibility
  }
  
  /// Update peace status
  Future<void> updatePeaceStatus(PeaceStatus status) async {
    // TODO: Implement when mindfulness tracking is added
  }
  
  /// Update community status
  Future<void> updateCommunityStatus(CommunityStatus status) async {
    // TODO: Implement when community features are added
  }
}
