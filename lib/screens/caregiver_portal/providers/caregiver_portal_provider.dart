/// Caregiver Portal State Management
/// 
/// Provides real-time data for the caregiver portal screens.
/// Integrates with RelationshipService, ChatService, and Health data.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../relationships/models/relationship_model.dart';
import '../../../relationships/services/relationship_service.dart';
import '../../../chat/services/chat_service.dart';
import '../../../chat/models/chat_thread_model.dart';
import '../../../chat/models/chat_message_model.dart';
import '../../../health/repositories/health_data_repository_hive.dart';
import '../../../services/session_service.dart';
import '../../../profile/user_profile_remote_service.dart';

// ============================================================
// CAREGIVER STATE MODEL
// ============================================================


/// Linked patient data container (for multi-patient support)
class LinkedPatientData {
  final RelationshipModel relationship;
  final PatientInfo patient;
  final PatientVitals? vitals;
  final ChatThreadModel? chatThread;
  final List<ChatMessageModel> recentMessages;
  final int unreadMessageCount;
  final List<CaregiverAlert> alerts;
  final Set<String> permissions;
  
  const LinkedPatientData({
    required this.relationship,
    required this.patient,
    this.vitals,
    this.chatThread,
    this.recentMessages = const [],
    this.unreadMessageCount = 0,
    this.alerts = const [],
    this.permissions = const {},
  });
  
  /// Check if caregiver has a specific permission for this patient
  bool hasPermission(String permission) => permissions.contains(permission);
}

/// Complete state for the caregiver portal
class CaregiverPortalState {
  final CaregiverLoadingStatus loadingStatus;
  final String? errorMessage;
  
  // Caregiver info
  final String? caregiverUid;
  final String? caregiverName;
  
  // ALL linked patients (multi-patient support)
  final List<LinkedPatientData> linkedPatients;
  
  // Currently selected patient index
  final int selectedPatientIndex;
  
  // Linked patient info (from relationship) - for backward compatibility
  final RelationshipModel? activeRelationship;
  final PatientInfo? linkedPatient;
  
  // Patient vitals (if permitted)
  final PatientVitals? patientVitals;
  
  // Chat data
  final ChatThreadModel? chatThread;
  final List<ChatMessageModel> recentMessages;
  final int unreadMessageCount;
  
  // Alerts
  final List<CaregiverAlert> alerts;
  final int activeAlertCount;
  
  // Permissions
  final Set<String> permissions;
  
  const CaregiverPortalState({
    this.loadingStatus = CaregiverLoadingStatus.loading,
    this.errorMessage,
    this.caregiverUid,
    this.caregiverName,
    this.linkedPatients = const [],
    this.selectedPatientIndex = 0,
    this.activeRelationship,
    this.linkedPatient,
    this.patientVitals,
    this.chatThread,
    this.recentMessages = const [],
    this.unreadMessageCount = 0,
    this.alerts = const [],
    this.activeAlertCount = 0,
    this.permissions = const {},
  });
  
  /// Check if caregiver has a specific permission
  bool hasPermission(String permission) => permissions.contains(permission);
  
  /// Check if there's a valid, active relationship
  bool get hasActiveRelationship => 
      activeRelationship != null && 
      activeRelationship!.status == RelationshipStatus.active;
  
  /// Check if patient data is available
  bool get hasPatientData => linkedPatient != null;
  
  /// Check if vitals access is permitted and data is available
  bool get canViewVitals => hasPermission('view_vitals') && patientVitals != null;
  
  /// Check if chat is permitted
  bool get canChat => hasPermission('chat');
  
  /// Check if location viewing is permitted
  bool get canViewLocation => hasPermission('view_location');
  
  /// Check if medication viewing is permitted
  bool get canViewMedications => hasPermission('view_medications');
  
  /// Check if SOS features are permitted
  bool get canUseSOS => hasPermission('sos');
  
  /// Multi-patient support: Get number of linked patients
  int get patientCount => linkedPatients.length;
  
  /// Multi-patient support: Check if multiple patients are linked
  bool get hasMultiplePatients => linkedPatients.length > 1;
  
  /// Multi-patient support: Get currently selected patient data
  LinkedPatientData? get selectedPatient {
    if (linkedPatients.isEmpty) return null;
    if (selectedPatientIndex >= linkedPatients.length) return linkedPatients.first;
    return linkedPatients[selectedPatientIndex];
  }
  
  /// Multi-patient support: Total unread messages across all patients
  int get totalUnreadMessages {
    return linkedPatients.fold(0, (sum, p) => sum + p.unreadMessageCount);
  }
  
  /// Multi-patient support: Total active alerts across all patients
  int get totalActiveAlerts {
    return linkedPatients.fold(
      0, 
      (sum, p) => sum + p.alerts.where((a) => !a.isResolved).length
    );
  }
  
  CaregiverPortalState copyWith({
    CaregiverLoadingStatus? loadingStatus,
    String? errorMessage,
    String? caregiverUid,
    String? caregiverName,
    List<LinkedPatientData>? linkedPatients,
    int? selectedPatientIndex,
    RelationshipModel? activeRelationship,
    PatientInfo? linkedPatient,
    PatientVitals? patientVitals,
    ChatThreadModel? chatThread,
    List<ChatMessageModel>? recentMessages,
    int? unreadMessageCount,
    List<CaregiverAlert>? alerts,
    int? activeAlertCount,
    Set<String>? permissions,
  }) {
    return CaregiverPortalState(
      loadingStatus: loadingStatus ?? this.loadingStatus,
      errorMessage: errorMessage,
      caregiverUid: caregiverUid ?? this.caregiverUid,
      caregiverName: caregiverName ?? this.caregiverName,
      linkedPatients: linkedPatients ?? this.linkedPatients,
      selectedPatientIndex: selectedPatientIndex ?? this.selectedPatientIndex,
      activeRelationship: activeRelationship ?? this.activeRelationship,
      linkedPatient: linkedPatient ?? this.linkedPatient,
      patientVitals: patientVitals ?? this.patientVitals,
      chatThread: chatThread ?? this.chatThread,
      recentMessages: recentMessages ?? this.recentMessages,
      unreadMessageCount: unreadMessageCount ?? this.unreadMessageCount,
      alerts: alerts ?? this.alerts,
      activeAlertCount: activeAlertCount ?? this.activeAlertCount,
      permissions: permissions ?? this.permissions,
    );
  }
  
  /// Create initial loading state
  factory CaregiverPortalState.loading() => const CaregiverPortalState(
    loadingStatus: CaregiverLoadingStatus.loading,
  );
  
  /// Create error state
  factory CaregiverPortalState.error(String message) => CaregiverPortalState(
    loadingStatus: CaregiverLoadingStatus.error,
    errorMessage: message,
  );
  
  /// Create state when no relationship exists
  factory CaregiverPortalState.noRelationship(String caregiverUid) => CaregiverPortalState(
    loadingStatus: CaregiverLoadingStatus.noRelationship,
    caregiverUid: caregiverUid,
  );
}

/// Loading status enum
enum CaregiverLoadingStatus {
  loading,
  loaded,
  error,
  noRelationship,
  relationshipPending,
  relationshipRevoked,
  notAuthenticated,
}

/// Patient info extracted from relationship and profile
class PatientInfo {
  final String uid;
  final String name;
  final String? photoUrl;
  final int? age;
  final String? patientId; // e.g., "GA-8829"
  final bool isOnline;
  final DateTime? lastSeen;
  final String? currentLocation;
  
  const PatientInfo({
    required this.uid,
    required this.name,
    this.photoUrl,
    this.age,
    this.patientId,
    this.isOnline = false,
    this.lastSeen,
    this.currentLocation,
  });
  
  /// Get initials for avatar fallback
  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

/// Patient vitals snapshot
class PatientVitals {
  final int? heartRate;
  final String? heartRateTrend; // 'up', 'down', 'stable'
  final int? systolic;
  final int? diastolic;
  final int? oxygenLevel;
  final int? glucoseLevel;
  final double? temperature;
  final int? steps;
  final double? sleepHours;
  final DateTime? lastUpdated;
  
  const PatientVitals({
    this.heartRate,
    this.heartRateTrend,
    this.systolic,
    this.diastolic,
    this.oxygenLevel,
    this.glucoseLevel,
    this.temperature,
    this.steps,
    this.sleepHours,
    this.lastUpdated,
  });
  
  /// Get overall health status
  String get overallStatus {
    if (heartRate == null && oxygenLevel == null) return 'No Data';
    
    // Simple heuristics
    bool hasWarning = false;
    if (heartRate != null && (heartRate! < 50 || heartRate! > 120)) hasWarning = true;
    if (oxygenLevel != null && oxygenLevel! < 92) hasWarning = true;
    if (systolic != null && (systolic! > 140 || systolic! < 90)) hasWarning = true;
    
    return hasWarning ? 'Needs Attention' : 'Stable';
  }
  
  /// Get blood pressure as string
  String? get bloodPressure {
    if (systolic != null && diastolic != null) {
      return '$systolic/$diastolic';
    }
    return null;
  }
  
  /// Get time since last update
  String get lastUpdatedText {
    if (lastUpdated == null) return 'Never';
    final diff = DateTime.now().difference(lastUpdated!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

/// Alert model for caregiver
class CaregiverAlert {
  final String id;
  final CaregiverAlertType type;
  final String title;
  final String description;
  final DateTime timestamp;
  final bool isResolved;
  final CaregiverAlertSeverity severity;
  final String? patientId;
  
  const CaregiverAlert({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.timestamp,
    this.isResolved = false,
    this.severity = CaregiverAlertSeverity.medium,
    this.patientId,
  });
  
  /// Get time ago text
  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

enum CaregiverAlertType {
  sos,
  fall,
  geoFence,
  medication,
  vitals,
  system,
}

enum CaregiverAlertSeverity {
  low,
  medium,
  high,
  critical,
}

// ============================================================
// CAREGIVER PORTAL NOTIFIER
// ============================================================

/// State notifier that manages all caregiver portal data
class CaregiverPortalNotifier extends StateNotifier<CaregiverPortalState> {
  // ignore: unused_field - kept for future real-time subscription features
  final Ref _ref;
  
  // Subscriptions for real-time updates
  StreamSubscription? _relationshipSubscription;
  StreamSubscription? _chatSubscription;
  StreamSubscription? _vitalsSubscription;
  StreamSubscription? _authSubscription;
  
  // Track active Firestore listener thread ID for cleanup
  String? _activeListeningThreadId;
  
  CaregiverPortalNotifier(this._ref) : super(CaregiverPortalState.loading()) {
    _initialize();
  }
  
  /// Initialize the caregiver portal
  Future<void> _initialize() async {
    // First check if we have a valid session (from SessionService)
    // This proves the user went through proper auth flow
    final hasSession = await SessionService.instance.hasValidSession();
    
    if (!hasSession) {
      // No valid session - user shouldn't be here
      state = const CaregiverPortalState(
        loadingStatus: CaregiverLoadingStatus.notAuthenticated,
      );
      return;
    }
    
    // Wait a moment for Firebase Auth to restore state if needed
    User? user = FirebaseAuth.instance.currentUser;
    
    // If user is null, wait for auth state to settle (Firebase may still be initializing)
    if (user == null) {
      // Wait up to 3 seconds for Firebase Auth to restore the user
      for (int i = 0; i < 6; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        user = FirebaseAuth.instance.currentUser;
        if (user != null) break;
      }
    }
    
    // If still no user after waiting, but we have a session, proceed with session UID
    if (user != null) {
      await _loadCaregiverData(user.uid);
    } else {
      // Fallback: Try to get UID from auth state stream
      debugPrint('CaregiverPortal: Firebase Auth user null, waiting for auth state...');
      
      // Listen for auth state and load when user becomes available
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((authUser) {
        if (authUser != null) {
          _loadCaregiverData(authUser.uid);
        }
      });
      
      // Also try one more time after a delay
      await Future.delayed(const Duration(seconds: 1));
      user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _loadCaregiverData(user.uid);
      } else {
        // Still no user - show no relationship screen instead of blocking
        // User has a session so they're authenticated, just Firebase is slow
        state = const CaregiverPortalState(
          loadingStatus: CaregiverLoadingStatus.noRelationship,
        );
      }
    }
    
    // Set up listener for future auth changes
    _authSubscription ??= FirebaseAuth.instance.authStateChanges().listen((authUser) {
      if (authUser == null && state.loadingStatus == CaregiverLoadingStatus.loaded) {
        // User signed out
        state = const CaregiverPortalState(
          loadingStatus: CaregiverLoadingStatus.notAuthenticated,
        );
      } else if (authUser != null && state.loadingStatus != CaregiverLoadingStatus.loaded) {
        // User signed in, reload data
        _loadCaregiverData(authUser.uid);
      }
    });
  }
  
  /// Load all caregiver data - SUPPORTS MULTIPLE PATIENTS
  Future<void> _loadCaregiverData(String caregiverUid) async {
    try {
      // Get caregiver name from Firebase Auth
      final currentUser = FirebaseAuth.instance.currentUser;
      final caregiverName = currentUser?.displayName ?? currentUser?.email?.split('@').first;
      
      state = state.copyWith(
        loadingStatus: CaregiverLoadingStatus.loading,
        caregiverUid: caregiverUid,
        caregiverName: caregiverName,
      );
      
      // Step 1: Get ALL relationships for caregiver
      final allRelationshipsResult = await RelationshipService.instance
          .getRelationshipsForUser(caregiverUid);
      
      if (!allRelationshipsResult.success || allRelationshipsResult.data == null) {
        state = CaregiverPortalState.noRelationship(caregiverUid);
        return;
      }
      
      final allRelationships = allRelationshipsResult.data!;
      
      // Filter active relationships (where user is caregiver)
      final activeRelationships = allRelationships.where(
        (r) => r.caregiverId == caregiverUid && r.status == RelationshipStatus.active
      ).toList();
      
      // Check for pending relationships
      final pendingRelationships = allRelationships.where(
        (r) => r.status == RelationshipStatus.pending
      ).toList();
      
      if (activeRelationships.isEmpty) {
        if (pendingRelationships.isNotEmpty) {
          state = CaregiverPortalState(
            loadingStatus: CaregiverLoadingStatus.relationshipPending,
            caregiverUid: caregiverUid,
            activeRelationship: pendingRelationships.first,
          );
          return;
        }
        state = CaregiverPortalState.noRelationship(caregiverUid);
        return;
      }
      
      // Step 2: Load data for ALL linked patients
      final linkedPatientsList = <LinkedPatientData>[];
      
      for (final relationship in activeRelationships) {
        final permissions = relationship.permissions.toSet();
        
        // Load patient info
        final patientInfo = await _loadPatientInfo(relationship.patientId);
        
        // Load vitals if permitted
        PatientVitals? vitals;
        if (permissions.contains('view_vitals')) {
          vitals = await _loadPatientVitals(relationship.patientId);
        }
        
        // Load chat thread if permitted
        ChatThreadModel? chatThread;
        List<ChatMessageModel> messages = [];
        int unreadCount = 0;
        if (permissions.contains('chat')) {
          final chatResult = await _loadChatData(caregiverUid, relationship.id);
          chatThread = chatResult.$1;
          messages = chatResult.$2;
          unreadCount = chatResult.$3;
        }
        
        // Load alerts
        final alerts = await _loadAlerts(relationship.patientId);
        
        linkedPatientsList.add(LinkedPatientData(
          relationship: relationship,
          patient: patientInfo,
          vitals: vitals,
          chatThread: chatThread,
          recentMessages: messages,
          unreadMessageCount: unreadCount,
          alerts: alerts,
          permissions: permissions,
        ));
      }
      
      // Use first patient as the "active" one for backward compatibility
      final firstPatient = linkedPatientsList.isNotEmpty ? linkedPatientsList.first : null;
      
      // Update state with all loaded data
      state = CaregiverPortalState(
        loadingStatus: CaregiverLoadingStatus.loaded,
        caregiverUid: caregiverUid,
        caregiverName: caregiverName,
        linkedPatients: linkedPatientsList,
        selectedPatientIndex: 0,
        // Backward compatibility fields (from first patient)
        activeRelationship: firstPatient?.relationship,
        linkedPatient: firstPatient?.patient,
        patientVitals: firstPatient?.vitals,
        chatThread: firstPatient?.chatThread,
        recentMessages: firstPatient?.recentMessages ?? [],
        unreadMessageCount: firstPatient?.unreadMessageCount ?? 0,
        alerts: firstPatient?.alerts ?? [],
        activeAlertCount: (firstPatient?.alerts ?? []).where((a) => !a.isResolved).length,
        permissions: firstPatient?.permissions ?? {},
      );
      
      // Set up real-time subscriptions for first patient
      if (firstPatient != null) {
        _setupRealtimeSubscriptions(caregiverUid, firstPatient.relationship);
      }
      
    } catch (e) {
      debugPrint('CaregiverPortal Error: $e');
      state = CaregiverPortalState.error('Failed to load data: ${e.toString()}');
    }
  }
  
  /// Switch to a different patient (for multi-patient support)
  void selectPatient(int index) {
    if (index < 0 || index >= state.linkedPatients.length) return;
    
    final selectedPatient = state.linkedPatients[index];
    
    state = state.copyWith(
      selectedPatientIndex: index,
      // Update backward-compatibility fields
      activeRelationship: selectedPatient.relationship,
      linkedPatient: selectedPatient.patient,
      patientVitals: selectedPatient.vitals,
      chatThread: selectedPatient.chatThread,
      recentMessages: selectedPatient.recentMessages,
      unreadMessageCount: selectedPatient.unreadMessageCount,
      alerts: selectedPatient.alerts,
      activeAlertCount: selectedPatient.alerts.where((a) => !a.isResolved).length,
      permissions: selectedPatient.permissions,
    );
    
    // Update real-time subscriptions
    _relationshipSubscription?.cancel();
    _chatSubscription?.cancel();
    _vitalsSubscription?.cancel();
    _setupRealtimeSubscriptions(state.caregiverUid!, selectedPatient.relationship);
  }
  
  /// Load patient info from Firestore
  /// Checks patient_users collection first, then falls back to users collection
  Future<PatientInfo> _loadPatientInfo(String patientId) async {
    debugPrint('[CaregiverPortal] Loading patient info for: $patientId');
    final firestore = FirebaseFirestore.instance;
    
    try {
      // FIRST: Try patient_users collection (where patient onboarding data is stored)
      debugPrint('[CaregiverPortal] Checking patient_users collection...');
      final patientDoc = await firestore.collection('patient_users').doc(patientId).get();
      
      if (patientDoc.exists && patientDoc.data() != null) {
        final data = patientDoc.data()!;
        debugPrint('[CaregiverPortal] Found patient in patient_users: $data');
        
        // Extract name - try 'name' first, then 'full_name'
        final name = (data['name'] as String?) ?? 
                     (data['full_name'] as String?) ?? 
                     'Patient';
        final age = data['age'] as int?;
        
        debugPrint('[CaregiverPortal] Patient name: $name, age: $age');
        
        return PatientInfo(
          uid: patientId,
          name: name.isNotEmpty ? name : 'Patient',
          age: age,
          isOnline: true,
          lastSeen: DateTime.now(),
        );
      }
      
      debugPrint('[CaregiverPortal] Patient not found in patient_users, trying users collection...');
      
      // SECOND: Fall back to users collection
      final profileService = UserProfileRemoteService();
      final profile = await profileService.fetchProfile(patientId);
      
      if (profile != null) {
        debugPrint('[CaregiverPortal] Loaded patient from users collection: ${profile.displayName}, age: ${profile.age}');
        return PatientInfo(
          uid: patientId,
          name: profile.displayName.isNotEmpty ? profile.displayName : 'Patient',
          age: profile.age,
          isOnline: true,
          lastSeen: DateTime.now(),
        );
      }
      
      debugPrint('[CaregiverPortal] Patient not found in any Firestore collection');
    } catch (e) {
      debugPrint('[CaregiverPortal] Error loading patient info: $e');
    }
    
    // Fallback if all Firestore fetches fail
    return PatientInfo(
      uid: patientId,
      name: 'Patient',
      isOnline: true,
      lastSeen: DateTime.now(),
    );
  }
  
  /// Load patient vitals from FIRESTORE (not local Hive)
  /// This queries the patient's health_readings collection in Firestore
  Future<PatientVitals?> _loadPatientVitals(String patientId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final healthReadingsRef = firestore
          .collection('patients')
          .doc(patientId)
          .collection('health_readings');
      
      // Get latest heart rate
      final heartRateQuery = await healthReadingsRef
          .where('type', isEqualTo: 'heart_rate')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      
      // Get latest blood oxygen
      final oxygenQuery = await healthReadingsRef
          .where('type', isEqualTo: 'blood_oxygen')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      
      // Get latest sleep session
      final sleepQuery = await healthReadingsRef
          .where('type', isEqualTo: 'sleep_session')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      
      int? heartRate;
      int? oxygenLevel;
      double? sleepHours;
      DateTime? lastUpdated;
      
      if (heartRateQuery.docs.isNotEmpty) {
        final doc = heartRateQuery.docs.first;
        heartRate = doc.data()['bpm'] as int?;
        final timestamp = doc.data()['timestamp'];
        if (timestamp is Timestamp) {
          lastUpdated = timestamp.toDate();
        } else if (timestamp is String) {
          lastUpdated = DateTime.tryParse(timestamp);
        }
      }
      
      if (oxygenQuery.docs.isNotEmpty) {
        final doc = oxygenQuery.docs.first;
        oxygenLevel = doc.data()['percentage'] as int? ?? doc.data()['spo2'] as int?;
      }
      
      if (sleepQuery.docs.isNotEmpty) {
        final doc = sleepQuery.docs.first;
        final totalMinutes = doc.data()['total_minutes'] as num?;
        if (totalMinutes != null) {
          sleepHours = totalMinutes / 60;
        }
      }
      
      return PatientVitals(
        heartRate: heartRate,
        oxygenLevel: oxygenLevel,
        sleepHours: sleepHours,
        lastUpdated: lastUpdated,
      );
    } catch (e) {
      debugPrint('Failed to load vitals from Firestore: $e');
      return null;
    }
  }
  
  /// Load chat data
  Future<(ChatThreadModel?, List<ChatMessageModel>, int)> _loadChatData(
    String caregiverUid,
    String relationshipId,
  ) async {
    try {
      // Validate access first
      final accessResult = await ChatService.instance.validateChatAccess(caregiverUid);
      if (!accessResult.allowed) {
        return (null, <ChatMessageModel>[], 0);
      }
      
      // Get or create thread
      final threadResult = await ChatService.instance.getOrCreateThreadForUser(caregiverUid);
      if (!threadResult.success || threadResult.data == null) {
        return (null, <ChatMessageModel>[], 0);
      }
      
      final thread = threadResult.data!;
      
      // Get recent messages
      final messagesResult = await ChatService.instance.getMessagesForThread(
        thread.id,
        caregiverUid,
        limit: 50,
      );
      
      final messages = messagesResult.success ? (messagesResult.data ?? <ChatMessageModel>[]) : <ChatMessageModel>[];
      
      return (thread, messages, thread.unreadCount);
    } catch (e) {
      debugPrint('Failed to load chat: $e');
      return (null, <ChatMessageModel>[], 0);
    }
  }
  
  /// Load alerts for patient from Firestore
  Future<List<CaregiverAlert>> _loadAlerts(String patientId) async {
    final alerts = <CaregiverAlert>[];
    
    try {
      final firestore = FirebaseFirestore.instance;
      
      // Load health alerts from patients/{patientId}/health_alerts
      try {
        final healthAlertsSnapshot = await firestore
            .collection('patients')
            .doc(patientId)
            .collection('health_alerts')
            .orderBy('created_at', descending: true)
            .limit(20)
            .get();
        
        for (final doc in healthAlertsSnapshot.docs) {
          final data = doc.data();
          alerts.add(_parseHealthAlert(doc.id, data, patientId));
        }
        debugPrint('[CaregiverPortal] Loaded ${healthAlertsSnapshot.docs.length} health alerts for patient $patientId');
      } catch (healthError) {
        debugPrint('[CaregiverPortal] Failed to load health alerts: $healthError');
        // Continue to try loading SOS alerts even if health alerts fail
      }
      
      // Load SOS alerts from sos_sessions where patient_uid = patientId
      // Note: This compound query requires a composite index on (patient_uid, created_at)
      // Deploy with: firebase deploy --only firestore:indexes
      try {
        final sosSnapshot = await firestore
            .collection('sos_sessions')
            .where('patient_uid', isEqualTo: patientId)
            .orderBy('created_at', descending: true)
            .limit(10)
            .get();
        
        for (final doc in sosSnapshot.docs) {
          final data = doc.data();
          alerts.add(_parseSosAlert(doc.id, data, patientId));
        }
        debugPrint('[CaregiverPortal] Loaded ${sosSnapshot.docs.length} SOS alerts for patient $patientId');
      } catch (sosError) {
        // Check for missing index error
        final errorMessage = sosError.toString();
        if (errorMessage.contains('index') || errorMessage.contains('FAILED_PRECONDITION')) {
          debugPrint('[CaregiverPortal] MISSING FIRESTORE INDEX: The sos_sessions query requires a composite index.');
          debugPrint('[CaregiverPortal] Run: firebase deploy --only firestore:indexes');
        } else {
          debugPrint('[CaregiverPortal] Failed to load SOS alerts: $sosError');
        }
        // Continue with whatever alerts we have
      }
      
      // Sort by timestamp descending
      alerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      debugPrint('[CaregiverPortal] Total alerts loaded: ${alerts.length}');
      return alerts;
    } catch (e) {
      debugPrint('[CaregiverPortal] Failed to load alerts: $e');
      return [];
    }
  }
  
  /// Parse a health alert from Firestore data
  CaregiverAlert _parseHealthAlert(String id, Map<String, dynamic> data, String patientId) {
    final type = data['type'] as String? ?? 'vitals';
    final riskLevel = data['risk_level'] as String? ?? 'unknown';
    final recommendation = data['recommendation'] as String? ?? '';
    final acknowledged = data['acknowledged'] as bool? ?? false;
    final createdAt = data['created_at'];
    
    DateTime timestamp = DateTime.now();
    if (createdAt is Timestamp) {
      timestamp = createdAt.toDate();
    } else if (createdAt is String) {
      timestamp = DateTime.tryParse(createdAt) ?? DateTime.now();
    }
    
    // Map type to CaregiverAlertType
    CaregiverAlertType alertType;
    switch (type) {
      case 'arrhythmia':
      case 'heart_rate':
      case 'blood_oxygen':
        alertType = CaregiverAlertType.vitals;
        break;
      case 'fall':
        alertType = CaregiverAlertType.fall;
        break;
      case 'medication':
        alertType = CaregiverAlertType.medication;
        break;
      default:
        alertType = CaregiverAlertType.system;
    }
    
    // Map risk level to severity
    CaregiverAlertSeverity severity;
    switch (riskLevel) {
      case 'critical':
      case 'high':
        severity = CaregiverAlertSeverity.critical;
        break;
      case 'moderate':
        severity = CaregiverAlertSeverity.high;
        break;
      case 'low':
        severity = CaregiverAlertSeverity.medium;
        break;
      default:
        severity = CaregiverAlertSeverity.medium;
    }
    
    return CaregiverAlert(
      id: id,
      type: alertType,
      title: '${type.replaceAll('_', ' ').toUpperCase()} Alert',
      description: recommendation.isNotEmpty 
          ? recommendation 
          : 'Risk level: $riskLevel',
      timestamp: timestamp,
      isResolved: acknowledged,
      severity: severity,
      patientId: patientId,
    );
  }
  
  /// Parse an SOS alert from Firestore data
  CaregiverAlert _parseSosAlert(String id, Map<String, dynamic> data, String patientId) {
    final state = data['state'] as String? ?? 'unknown';
    final patientName = data['patient_name'] as String? ?? 'Patient';
    final createdAt = data['created_at'];
    
    DateTime timestamp = DateTime.now();
    if (createdAt is Timestamp) {
      timestamp = createdAt.toDate();
    } else if (createdAt is String) {
      timestamp = DateTime.tryParse(createdAt) ?? DateTime.now();
    }
    
    final isResolved = state == 'resolved' || state == 'cancelled' || state == 'false_alarm';
    
    CaregiverAlertSeverity severity;
    switch (state) {
      case 'active':
      case 'escalated':
        severity = CaregiverAlertSeverity.critical;
        break;
      default:
        severity = CaregiverAlertSeverity.high;
    }
    
    return CaregiverAlert(
      id: id,
      type: CaregiverAlertType.sos,
      title: 'SOS Emergency',
      description: '$patientName triggered an SOS alert',
      timestamp: timestamp,
      isResolved: isResolved,
      severity: severity,
      patientId: patientId,
    );
  }
  
  /// Set up real-time subscriptions
  void _setupRealtimeSubscriptions(String caregiverUid, RelationshipModel relationship) {
    // Watch relationship changes
    _relationshipSubscription?.cancel();
    _relationshipSubscription = RelationshipService.instance
        .watchRelationshipsForUser(caregiverUid)
        .listen((relationships) {
      final active = relationships.where(
        (r) => r.status == RelationshipStatus.active && r.id == relationship.id
      ).firstOrNull;
      
      if (active == null) {
        // Relationship was revoked or changed
        _loadCaregiverData(caregiverUid);
      } else if (active.permissions.toSet() != state.permissions) {
        // Permissions changed
        state = state.copyWith(
          activeRelationship: active,
          permissions: active.permissions.toSet(),
        );
      }
    });
    
    // Watch chat messages if permitted
    if (state.canChat && state.chatThread != null) {
      _chatSubscription?.cancel();
      
      // Stop previous Firestore listener if different thread
      if (_activeListeningThreadId != null && _activeListeningThreadId != state.chatThread!.id) {
        ChatService.instance.stopListeningForIncomingMessages(_activeListeningThreadId!);
      }
      
      // CRITICAL: Start listening for incoming messages from Firestore
      // This syncs messages sent by the patient to the caregiver's local Hive
      _activeListeningThreadId = state.chatThread!.id;
      ChatService.instance.startListeningForIncomingMessages(
        threadId: state.chatThread!.id,
        currentUid: caregiverUid,
      );
      
      _chatSubscription = ChatService.instance
          .watchMessagesForThread(state.chatThread!.id, caregiverUid)
          .listen((messages) {
        state = state.copyWith(
          recentMessages: messages,
          unreadMessageCount: messages.where((m) => 
            m.senderId != caregiverUid && m.readAt == null
          ).length,
        );
      });
    }
    
    // Watch vitals if permitted
    if (state.canViewVitals) {
      _vitalsSubscription?.cancel();
      try {
        final repo = HealthDataRepositoryHive();
        _vitalsSubscription = repo
            .watchLatestVitals(relationship.patientId)
            .listen((snapshot) {
          state = state.copyWith(
            patientVitals: PatientVitals(
              heartRate: snapshot.latestHeartRate?.data['bpm'] as int?,
              oxygenLevel: snapshot.latestOxygen?.data['spo2'] as int?,
              sleepHours: snapshot.latestSleep?.data['totalMinutes'] != null 
                  ? (snapshot.latestSleep!.data['totalMinutes'] as num) / 60 
                  : null,
              lastUpdated: snapshot.latestHeartRate?.recordedAt,
            ),
          );
        });
      } catch (e) {
        debugPrint('Failed to watch vitals: $e');
      }
    }
  }
  
  /// Refresh all data
  Future<void> refresh() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await _loadCaregiverData(uid);
    }
  }
  
  /// Send a chat message
  Future<bool> sendMessage(String content) async {
    if (!state.canChat || state.chatThread == null || state.caregiverUid == null) {
      return false;
    }
    
    try {
      final result = await ChatService.instance.sendTextMessage(
        threadId: state.chatThread!.id,
        currentUid: state.caregiverUid!,
        content: content,
      );
      return result.success;
    } catch (e) {
      debugPrint('Failed to send message: $e');
      return false;
    }
  }
  
  /// Mark a message as read
  Future<void> markMessagesAsRead() async {
    if (state.chatThread == null || state.caregiverUid == null) return;
    
    try {
      await ChatService.instance.markThreadAsRead(
        threadId: state.chatThread!.id,
        currentUid: state.caregiverUid!,
      );
    } catch (e) {
      debugPrint('Failed to mark as read: $e');
    }
  }
  
  /// Retry failed messages
  Future<void> retryFailedMessages() async {
    try {
      await ChatService.instance.retryFailedMessages();
    } catch (e) {
      debugPrint('Failed to retry messages: $e');
    }
  }
  
  /// Resolve an alert - updates both local state and Firestore
  Future<void> resolveAlert(String alertId) async {
    // Find the alert to get its type and patient ID
    final alertToResolve = state.alerts.where((a) => a.id == alertId).firstOrNull;
    if (alertToResolve == null) return;
    
    // Update Firestore based on alert type
    try {
      final firestore = FirebaseFirestore.instance;
      final caregiverUid = state.caregiverUid;
      final caregiverName = state.caregiverName ?? 'Caregiver';
      
      if (alertToResolve.type == CaregiverAlertType.sos) {
        // Update SOS session
        await firestore.collection('sos_sessions').doc(alertId).update({
          'state': 'resolved',
          'resolved_at': FieldValue.serverTimestamp(),
          'resolved_by': caregiverName,
          'resolved_by_uid': caregiverUid,
          'resolution_reason': 'Resolved by caregiver',
        });
        debugPrint('[CaregiverPortal] SOS alert resolved in Firestore: $alertId');
      } else {
        // Update health alert
        final patientId = alertToResolve.patientId ?? state.linkedPatient?.uid;
        if (patientId != null) {
          await firestore
              .collection('patients')
              .doc(patientId)
              .collection('health_alerts')
              .doc(alertId)
              .update({
            'acknowledged': true,
            'acknowledged_at': FieldValue.serverTimestamp(),
            'acknowledged_by': caregiverName,
            'acknowledged_by_uid': caregiverUid,
          });
          debugPrint('[CaregiverPortal] Health alert acknowledged in Firestore: $alertId');
        }
      }
    } catch (e) {
      debugPrint('[CaregiverPortal] Failed to persist alert resolution: $e');
      // Continue with local update even if Firestore fails
    }
    
    // Update local state
    final alerts = state.alerts.map((a) {
      if (a.id == alertId) {
        return CaregiverAlert(
          id: a.id,
          type: a.type,
          title: a.title,
          description: a.description,
          timestamp: a.timestamp,
          isResolved: true,
          severity: a.severity,
          patientId: a.patientId,
        );
      }
      return a;
    }).toList();
    
    state = state.copyWith(
      alerts: alerts,
      activeAlertCount: alerts.where((a) => !a.isResolved).length,
    );
  }
  
  @override
  void dispose() {
    _relationshipSubscription?.cancel();
    _chatSubscription?.cancel();
    _vitalsSubscription?.cancel();
    _authSubscription?.cancel();
    
    // Stop Firestore listener for incoming messages
    if (_activeListeningThreadId != null) {
      ChatService.instance.stopListeningForIncomingMessages(_activeListeningThreadId!);
      _activeListeningThreadId = null;
    }
    
    super.dispose();
  }
}

// ============================================================
// RIVERPOD PROVIDERS
// ============================================================

/// Main caregiver portal provider
final caregiverPortalProvider = StateNotifierProvider<CaregiverPortalNotifier, CaregiverPortalState>((ref) {
  return CaregiverPortalNotifier(ref);
});

/// Current caregiver UID provider
final caregiverUidProvider = Provider<String?>((ref) {
  return FirebaseAuth.instance.currentUser?.uid;
});

/// Patient info provider (derived from main state)
final linkedPatientProvider = Provider<PatientInfo?>((ref) {
  return ref.watch(caregiverPortalProvider).linkedPatient;
});

/// Patient vitals provider (derived from main state)
final patientVitalsProvider = Provider<PatientVitals?>((ref) {
  return ref.watch(caregiverPortalProvider).patientVitals;
});

/// Chat thread provider (derived from main state)
final caregiverChatThreadProvider = Provider<ChatThreadModel?>((ref) {
  return ref.watch(caregiverPortalProvider).chatThread;
});

/// Chat messages provider (derived from main state)
final caregiverChatMessagesProvider = Provider<List<ChatMessageModel>>((ref) {
  return ref.watch(caregiverPortalProvider).recentMessages;
});

/// Alerts provider (derived from main state)
final caregiverAlertsProvider = Provider<List<CaregiverAlert>>((ref) {
  return ref.watch(caregiverPortalProvider).alerts;
});

/// Unread count provider
final caregiverUnreadCountProvider = Provider<int>((ref) {
  return ref.watch(caregiverPortalProvider).unreadMessageCount;
});

/// Active alert count provider
final activeAlertCountProvider = Provider<int>((ref) {
  return ref.watch(caregiverPortalProvider).activeAlertCount;
});

/// Permission check providers
final canViewVitalsProvider = Provider<bool>((ref) {
  return ref.watch(caregiverPortalProvider).canViewVitals;
});

final canChatProvider = Provider<bool>((ref) {
  return ref.watch(caregiverPortalProvider).canChat;
});

final canViewLocationProvider = Provider<bool>((ref) {
  return ref.watch(caregiverPortalProvider).canViewLocation;
});

final canUseSosProvider = Provider<bool>((ref) {
  return ref.watch(caregiverPortalProvider).canUseSOS;
});
