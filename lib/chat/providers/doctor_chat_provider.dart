/// Doctor Chat Provider - Riverpod providers for doctor chat functionality.
///
/// Mirrors chat_provider.dart but uses DoctorChatService for doctor relationships.
///
/// USAGE:
/// ```dart
/// // In a widget
/// final doctorChatAccess = ref.watch(doctorChatAccessProvider);
/// final doctorThreads = ref.watch(doctorChatThreadsProvider);
/// final messages = ref.watch(doctorChatMessagesProvider(threadId));
/// ```
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/chat_thread_model.dart';
import '../models/chat_message_model.dart';
import '../repositories/chat_repository.dart';
import '../services/doctor_chat_service.dart';

/// Provider for current user's UID (reused from chat_provider if available).
final doctorChatCurrentUserUidProvider = Provider<String?>((ref) {
  return FirebaseAuth.instance.currentUser?.uid;
});

/// Doctor chat access status result for UI consumption.
class DoctorChatAccessStatus {
  final bool hasAccess;
  final String? errorCode;
  final String? reason;
  final String? doctorId;

  const DoctorChatAccessStatus._({
    required this.hasAccess,
    this.errorCode,
    this.reason,
    this.doctorId,
  });

  factory DoctorChatAccessStatus.granted({String? doctorId}) => DoctorChatAccessStatus._(
    hasAccess: true,
    doctorId: doctorId,
  );

  factory DoctorChatAccessStatus.denied(String errorCode, String reason) => DoctorChatAccessStatus._(
    hasAccess: false,
    errorCode: errorCode,
    reason: reason,
  );
}

/// Provider for doctor chat access validation.
///
/// Validates that the current user has an active doctor relationship with chat permission.
final doctorChatAccessProvider = FutureProvider<DoctorChatAccessStatus>((ref) async {
  final uid = ref.watch(doctorChatCurrentUserUidProvider);
  if (uid == null) {
    return DoctorChatAccessStatus.denied(DoctorChatErrorCodes.unauthorized, 'Not authenticated');
  }
  
  final result = await DoctorChatService.instance.validateDoctorChatAccess(uid);
  if (result.allowed) {
    return DoctorChatAccessStatus.granted(
      doctorId: result.relationship?.doctorId,
    );
  } else {
    return DoctorChatAccessStatus.denied(
      result.errorCode ?? 'unknown',
      result.errorMessage ?? 'Unknown error',
    );
  }
});

/// Provider for doctor chat threads for current user.
///
/// Returns all doctor chat threads (may have multiple if multiple doctor relationships).
final doctorChatThreadsProvider = StreamProvider<List<ChatThreadModel>>((ref) {
  final uid = ref.watch(doctorChatCurrentUserUidProvider);
  if (uid == null) return Stream.value([]);
  return DoctorChatService.instance.watchDoctorThreadsForUser(uid);
});

/// Provider for messages in a specific doctor thread.
final doctorChatMessagesProvider = StreamProvider.family<List<ChatMessageModel>, String>((ref, threadId) {
  final uid = ref.watch(doctorChatCurrentUserUidProvider);
  if (uid == null) return Stream.value([]);
  return DoctorChatService.instance.watchDoctorMessagesForThread(threadId, uid);
});

/// Provider for watching doctor chat access changes.
///
/// Emits false when doctor relationship is revoked or chat permission removed.
final doctorChatAccessStreamProvider = StreamProvider<bool>((ref) {
  final uid = ref.watch(doctorChatCurrentUserUidProvider);
  if (uid == null) return Stream.value(false);
  return DoctorChatService.instance.watchDoctorChatAccessForUser(uid);
});

/// Notifier for sending doctor chat messages.
class DoctorChatMessageNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  final String _threadId;

  DoctorChatMessageNotifier(this._ref, this._threadId) : super(const AsyncValue.data(null));

  Future<ChatResult<ChatMessageModel>> sendMessage(String content) async {
    state = const AsyncValue.loading();

    final uid = _ref.read(doctorChatCurrentUserUidProvider);
    if (uid == null) {
      state = const AsyncValue.data(null);
      return ChatResult.failure(DoctorChatErrorCodes.unauthorized, 'Not authenticated');
    }

    final result = await DoctorChatService.instance.sendDoctorTextMessage(
      threadId: _threadId,
      currentUid: uid,
      content: content,
    );

    state = const AsyncValue.data(null);
    return result;
  }
}

/// Provider family for doctor message sending.
final doctorChatMessageNotifierProvider = StateNotifierProvider.family<DoctorChatMessageNotifier, AsyncValue<void>, String>(
  (ref, threadId) => DoctorChatMessageNotifier(ref, threadId),
);

/// Model for doctor chat list item (enriched with doctor/patient details).
class DoctorChatListItem {
  final ChatThreadModel thread;
  final String displayName;
  final String? avatarUrl;
  final String? specialty;
  final String? organization;
  final bool isPatient; // true if current user is patient, false if doctor
  
  const DoctorChatListItem({
    required this.thread,
    required this.displayName,
    this.avatarUrl,
    this.specialty,
    this.organization,
    required this.isPatient,
  });
}

/// Provider for enriched doctor chat list items.
final doctorChatListItemsProvider = FutureProvider<List<DoctorChatListItem>>((ref) async {
  final uid = ref.watch(doctorChatCurrentUserUidProvider);
  if (uid == null) return [];

  final threadsAsync = ref.watch(doctorChatThreadsProvider);
  
  return threadsAsync.when(
    data: (threads) async {
      final items = <DoctorChatListItem>[];
      
      for (final thread in threads) {
        final isPatient = thread.patientId == uid;
        final otherUid = thread.getOtherParticipantId(uid);
        
        // Get other user's details
        // For now, generate a simple display name from UID
        final displayEnd = otherUid.length > 6 ? 6 : otherUid.length;
        String displayName = isPatient ? 'Dr. ${otherUid.substring(0, displayEnd)}' : 'Patient ${otherUid.substring(0, displayEnd)}';
        String? specialty;
        String? organization;
        
        // TODO: Integrate with DoctorRelationshipService when display names available
        // final relationship = await DoctorRelationshipService.instance.getRelationship(thread.relationshipId);
        // if (relationship != null) {
        //   if (isPatient) {
        //     displayName = relationship.doctorName ?? displayName;
        //     specialty = relationship.doctorSpecialty;
        //     organization = relationship.doctorOrganization;
        //   }
        // }
        
        items.add(DoctorChatListItem(
          thread: thread,
          displayName: displayName,
          specialty: specialty,
          organization: organization,
          isPatient: isPatient,
        ));
      }
      
      return items;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Provider for getting or creating doctor thread for current user.
///
/// Uses the user's active doctor relationship to create/get the thread.
final getOrCreateDoctorThreadProvider = FutureProvider<ChatResult<ChatThreadModel>>((ref) async {
  final uid = ref.watch(doctorChatCurrentUserUidProvider);
  if (uid == null) {
    return ChatResult.failure(DoctorChatErrorCodes.unauthorized, 'Not authenticated');
  }
  return DoctorChatService.instance.getOrCreateDoctorThreadForUser(uid);
});

/// Provider to mark doctor thread as read.
final markDoctorThreadReadProvider = FutureProvider.family<void, String>((ref, threadId) async {
  final uid = ref.watch(doctorChatCurrentUserUidProvider);
  if (uid == null) return;
  await DoctorChatService.instance.markDoctorThreadAsRead(
    threadId: threadId,
    currentUid: uid,
  );
});

/// Provider for starting/stopping incoming message listeners.
///
/// Use this when entering/leaving a doctor chat screen.
class DoctorChatListenerNotifier extends StateNotifier<Set<String>> {
  final Ref _ref;

  DoctorChatListenerNotifier(this._ref) : super({});

  void startListening(String threadId) {
    final uid = _ref.read(doctorChatCurrentUserUidProvider);
    if (uid == null) return;
    
    if (!state.contains(threadId)) {
      DoctorChatService.instance.startListeningForIncomingDoctorMessages(
        threadId: threadId,
        currentUid: uid,
      );
      state = {...state, threadId};
    }
  }

  void stopListening(String threadId) {
    DoctorChatService.instance.stopListeningForIncomingDoctorMessages(threadId);
    state = state.where((id) => id != threadId).toSet();
  }

  void stopAll() {
    DoctorChatService.instance.stopAllDoctorListeners();
    state = {};
  }
}

final doctorChatListenerProvider = StateNotifierProvider<DoctorChatListenerNotifier, Set<String>>(
  (ref) => DoctorChatListenerNotifier(ref),
);
