/// Doctor Patients Provider - Provides real patient data from relationships.
///
/// Replaces mock data in DoctorMainScreen with actual patient relationships
/// from DoctorRelationshipService.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../relationships/models/doctor_relationship_model.dart';
import '../relationships/services/doctor_relationship_service.dart';
import '../chat/services/doctor_chat_service.dart';
import '../chat/models/chat_thread_model.dart';

/// Current doctor UID provider.
final currentDoctorUidProvider = Provider<String?>((ref) {
  return FirebaseAuth.instance.currentUser?.uid;
});

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
        
        // Build patient item
        // TODO: Enrich with actual patient profile data when available
        final displayEnd = relationship.patientId.length > 6 ? 6 : relationship.patientId.length;
        
        items.add(DoctorPatientItem(
          relationshipId: relationship.id,
          patientId: relationship.patientId,
          patientName: 'Patient ${relationship.patientId.substring(0, displayEnd)}',
          photo: null, // Would come from patient profile
          age: null, // Would come from patient profile
          conditions: [], // Would come from shared health data
          lastActivity: _formatLastActivity(relationship.updatedAt),
          isStable: true, // Would come from health monitoring
          caregiverName: null, // Would come from relationship data
          hasChatPermission: relationship.hasPermission('chat'),
          chatThread: chatThread,
          unreadMessages: unreadCount,
        ));
      }
      
      return items;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

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
