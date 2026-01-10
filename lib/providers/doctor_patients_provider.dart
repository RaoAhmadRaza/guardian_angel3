/// Doctor Patients Provider - Provides real patient data from relationships.
///
/// Replaces mock data in DoctorMainScreen with actual patient relationships
/// from DoctorRelationshipService.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../relationships/models/doctor_relationship_model.dart';
import '../relationships/services/doctor_relationship_service.dart';
import '../chat/services/doctor_chat_service.dart';
import '../chat/models/chat_thread_model.dart';

/// Current doctor UID provider.
final currentDoctorUidProvider = Provider<String?>((ref) {
  return FirebaseAuth.instance.currentUser?.uid;
});

/// Real-time patient vitals data model.
class PatientVitalsData {
  final int? heartRate;
  final int? bloodOxygen;
  final double? sleepHours;
  final DateTime? lastUpdated;
  final bool hasRecentData; // Data within last 24 hours

  const PatientVitalsData({
    this.heartRate,
    this.bloodOxygen,
    this.sleepHours,
    this.lastUpdated,
    this.hasRecentData = false,
  });

  /// Vitals are stable if heart rate is 50-120 and oxygen >= 90
  bool get isStable {
    if (heartRate == null && bloodOxygen == null) return true; // No data = assume stable
    final hrOk = heartRate == null || (heartRate! >= 50 && heartRate! <= 120);
    final o2Ok = bloodOxygen == null || bloodOxygen! >= 90;
    return hrOk && o2Ok;
  }
}

/// Model for a patient in the doctor's list (enriched from relationship).
class DoctorPatientItem {
  final String relationshipId;
  final String patientId;
  final String patientName;
  final String? photo;
  final int? age;
  final List<String> conditions;
  final String? lastActivity;
  final bool isStable;
  final String? caregiverName;
  final bool hasChatPermission;
  final ChatThreadModel? chatThread;
  final int unreadMessages;
  final PatientVitalsData? vitals;

  const DoctorPatientItem({
    required this.relationshipId,
    required this.patientId,
    required this.patientName,
    this.photo,
    this.age,
    this.conditions = const [],
    this.lastActivity,
    this.isStable = true,
    this.caregiverName,
    this.hasChatPermission = false,
    this.chatThread,
    this.unreadMessages = 0,
    this.vitals,
  });
}

/// Provider for doctor's patient relationships.
final doctorPatientsRelationshipsProvider = StreamProvider<List<DoctorRelationshipModel>>((ref) {
  final uid = ref.watch(currentDoctorUidProvider);
  if (uid == null) return Stream.value([]);
  
  return DoctorRelationshipService.instance.watchRelationshipsForUser(uid).map((relationships) {
    // Filter to only show active relationships where current user is the doctor
    return relationships.where((r) => 
      r.doctorId == uid && 
      r.status == DoctorRelationshipStatus.active
    ).toList();
  });
});

/// Provider for enriched patient list for doctor dashboard.
final doctorPatientListProvider = FutureProvider<List<DoctorPatientItem>>((ref) async {
  final uid = ref.watch(currentDoctorUidProvider);
  if (uid == null) return [];

  final relationshipsAsync = ref.watch(doctorPatientsRelationshipsProvider);
  
  return relationshipsAsync.when(
    data: (relationships) async {
      final items = <DoctorPatientItem>[];
      
      for (final relationship in relationships) {
        // Get chat thread if exists
        ChatThreadModel? chatThread;
        int unreadCount = 0;
        
        if (relationship.hasPermission('chat')) {
          final threadResult = await DoctorChatService.instance.getDoctorThreadsForUser(uid);
          if (threadResult.success && threadResult.data != null) {
            final threads = threadResult.data!;
            final matchingThread = threads.where((t) => t.relationshipId == relationship.id).toList();
            if (matchingThread.isNotEmpty) {
              chatThread = matchingThread.first;
              unreadCount = chatThread.unreadCount;
            }
          }
        }
        
        // Fetch real patient profile data from Firestore
        final patientInfo = await _fetchPatientInfo(relationship.patientId);
        
        // Fetch real-time vitals from Firestore
        final vitals = await _fetchPatientVitals(relationship.patientId);
        
        items.add(DoctorPatientItem(
          relationshipId: relationship.id,
          patientId: relationship.patientId,
          patientName: patientInfo.name,
          photo: patientInfo.photo,
          age: patientInfo.age,
          conditions: patientInfo.conditions,
          lastActivity: _formatLastActivity(relationship.updatedAt),
          isStable: vitals.isStable, // Real vitals-based stability
          caregiverName: patientInfo.caregiverName,
          hasChatPermission: relationship.hasPermission('chat'),
          chatThread: chatThread,
          unreadMessages: unreadCount,
          vitals: vitals,
        ));
      }
      
      return items;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Helper class for patient info fetched from Firestore.
class _PatientInfo {
  final String name;
  final String? photo;
  final int? age;
  final List<String> conditions;
  final String? caregiverName;
  
  const _PatientInfo({
    required this.name,
    this.photo,
    this.age,
    this.conditions = const [],
    this.caregiverName,
  });
}

/// Fetches patient profile information from Firestore.
/// 
/// Tries patient_users collection first (where patient onboarding data lives),
/// then falls back to users collection.
Future<_PatientInfo> _fetchPatientInfo(String patientId) async {
  final firestore = FirebaseFirestore.instance;
  
  try {
    // Try patient_users collection first (onboarding data)
    final patientDoc = await firestore
        .collection('patient_users')
        .doc(patientId)
        .get();
    
    if (patientDoc.exists && patientDoc.data() != null) {
      final data = patientDoc.data()!;
      return _PatientInfo(
        name: data['full_name'] as String? ?? 
              data['name'] as String? ?? 
              'Patient ${patientId.substring(0, patientId.length > 6 ? 6 : patientId.length)}',
        photo: data['photo_url'] as String?,
        age: data['age'] as int?,
        conditions: _parseConditions(data['medical_history']),
        caregiverName: null, // Would need separate lookup
      );
    }
    
    // Fall back to users collection
    final userDoc = await firestore
        .collection('users')
        .doc(patientId)
        .get();
    
    if (userDoc.exists && userDoc.data() != null) {
      final data = userDoc.data()!;
      return _PatientInfo(
        name: data['display_name'] as String? ?? 
              data['full_name'] as String? ?? 
              data['name'] as String? ?? 
              'Patient ${patientId.substring(0, patientId.length > 6 ? 6 : patientId.length)}',
        photo: data['photo_url'] as String?,
        age: data['age'] as int?,
        conditions: [],
        caregiverName: null,
      );
    }
  } catch (e) {
    // Silent fail - return default
  }
  
  // Return default if nothing found
  return _PatientInfo(
    name: 'Patient ${patientId.substring(0, patientId.length > 6 ? 6 : patientId.length)}',
  );
}

/// Parses medical conditions from medical_history field.
List<String> _parseConditions(dynamic medicalHistory) {
  if (medicalHistory == null) return [];
  
  if (medicalHistory is List) {
    return medicalHistory.map((e) => e.toString()).take(3).toList();
  }
  
  if (medicalHistory is String && medicalHistory.isNotEmpty) {
    // Parse comma-separated or JSON-like string
    if (medicalHistory.contains(',')) {
      return medicalHistory.split(',').map((s) => s.trim()).take(3).toList();
    }
    return [medicalHistory];
  }
  
  return [];
}

/// Fetches latest vitals from Firestore health_readings collection.
/// 
/// Queries for heart_rate, blood_oxygen, and sleep_session readings.
Future<PatientVitalsData> _fetchPatientVitals(String patientId) async {
  final firestore = FirebaseFirestore.instance;
  final now = DateTime.now();
  final yesterday = now.subtract(const Duration(hours: 24));
  
  int? heartRate;
  int? bloodOxygen;
  double? sleepHours;
  DateTime? lastUpdated;
  
  try {
    final healthReadingsRef = firestore
        .collection('patients')
        .doc(patientId)
        .collection('health_readings');
    
    // Query latest heart rate
    final hrQuery = await healthReadingsRef
        .where('reading_type', isEqualTo: 'heart_rate')
        .orderBy('recorded_at', descending: true)
        .limit(1)
        .get();
    
    if (hrQuery.docs.isNotEmpty) {
      final hrData = hrQuery.docs.first.data();
      heartRate = hrData['value'] as int?;
      final recordedAt = hrData['recorded_at'];
      if (recordedAt is Timestamp) {
        lastUpdated = recordedAt.toDate();
      } else if (recordedAt is String) {
        lastUpdated = DateTime.tryParse(recordedAt);
      }
    }
    
    // Query latest blood oxygen
    final o2Query = await healthReadingsRef
        .where('reading_type', isEqualTo: 'blood_oxygen')
        .orderBy('recorded_at', descending: true)
        .limit(1)
        .get();
    
    if (o2Query.docs.isNotEmpty) {
      final o2Data = o2Query.docs.first.data();
      bloodOxygen = o2Data['value'] as int?;
      final recordedAt = o2Data['recorded_at'];
      DateTime? o2Time;
      if (recordedAt is Timestamp) {
        o2Time = recordedAt.toDate();
      } else if (recordedAt is String) {
        o2Time = DateTime.tryParse(recordedAt);
      }
      if (o2Time != null && (lastUpdated == null || o2Time.isAfter(lastUpdated))) {
        lastUpdated = o2Time;
      }
    }
    
    // Query latest sleep session
    final sleepQuery = await healthReadingsRef
        .where('reading_type', isEqualTo: 'sleep_session')
        .orderBy('recorded_at', descending: true)
        .limit(1)
        .get();
    
    if (sleepQuery.docs.isNotEmpty) {
      final sleepData = sleepQuery.docs.first.data();
      // Sleep duration might be stored as minutes or hours
      final duration = sleepData['duration_minutes'] ?? sleepData['value'];
      if (duration is num) {
        sleepHours = duration / 60.0; // Convert minutes to hours
      }
    }
    
    // Determine if data is recent (within 24 hours)
    final hasRecentData = lastUpdated != null && lastUpdated.isAfter(yesterday);
    
    return PatientVitalsData(
      heartRate: heartRate,
      bloodOxygen: bloodOxygen,
      sleepHours: sleepHours,
      lastUpdated: lastUpdated,
      hasRecentData: hasRecentData,
    );
  } catch (e) {
    // Silent fail - return empty vitals
    return const PatientVitalsData();
  }
}

/// Provider for pending invites (patients waiting for doctor to accept).
final pendingDoctorInvitesProvider = FutureProvider<List<DoctorRelationshipModel>>((ref) async {
  final uid = ref.watch(currentDoctorUidProvider);
  if (uid == null) return [];
  
  final result = await DoctorRelationshipService.instance.getRelationshipsForUser(uid);
  if (!result.success || result.data == null) return [];
  
  // Return only pending invites where user could become the doctor
  // Note: In the current flow, patient creates invite and shares code with doctor
  // Doctor doesn't see pending until they enter the code
  return result.data!.where((r) => 
    r.status == DoctorRelationshipStatus.pending
  ).toList();
});

/// Provider for total unread doctor chat messages.
final totalDoctorUnreadProvider = FutureProvider<int>((ref) async {
  final patientsAsync = ref.watch(doctorPatientListProvider);
  
  return patientsAsync.when(
    data: (patients) {
      return patients.fold<int>(0, (sum, p) => sum + p.unreadMessages);
    },
    loading: () => 0,
    error: (_, __) => 0,
  );
});

String _formatLastActivity(DateTime? dt) {
  if (dt == null) return 'No activity';
  
  final now = DateTime.now();
  final diff = now.difference(dt);
  
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  
  return '${dt.day}/${dt.month}/${dt.year}';
}
