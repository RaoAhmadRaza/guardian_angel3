/// Chat Provider - Riverpod providers for chat functionality.
///
/// Provides reactive access to chat data with relationship validation.
///
/// USAGE:
/// ```dart
/// // In a widget
/// final chatAccess = ref.watch(chatAccessProvider);
/// final threads = ref.watch(chatThreadsProvider);
/// ```
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import chat module exports (relative path from within chat folder)
import '../models/chat_thread_model.dart';
import '../models/chat_message_model.dart';
import '../repositories/chat_repository.dart';
import '../services/chat_service.dart' hide ChatAccessResult;

/// Provider for current user's UID.
final currentUserUidProvider = Provider<String?>((ref) {
  return FirebaseAuth.instance.currentUser?.uid;
});

/// Chat access status result for UI consumption.
class ChatAccessStatus {
  final bool hasAccess;
  final String? errorCode;
  final String? reason;

  const ChatAccessStatus._({
    required this.hasAccess,
    this.errorCode,
    this.reason,
  });

  factory ChatAccessStatus.granted() => const ChatAccessStatus._(hasAccess: true);

  factory ChatAccessStatus.denied(String errorCode, String reason) => ChatAccessStatus._(
    hasAccess: false,
    errorCode: errorCode,
    reason: reason,
  );
}

/// Provider for chat access validation.
final chatAccessProvider = FutureProvider<ChatAccessStatus>((ref) async {
  final uid = ref.watch(currentUserUidProvider);
  if (uid == null) {
    return ChatAccessStatus.denied(ChatErrorCodes.unauthorized, 'Not authenticated');
  }
  
  final result = await ChatService.instance.validateChatAccess(uid);
  if (result.allowed) {
    return ChatAccessStatus.granted();
  } else {
    return ChatAccessStatus.denied(result.errorCode ?? 'unknown', result.errorMessage ?? 'Unknown error');
  }
});

/// Provider for chat threads for current user.
final chatThreadsProvider = StreamProvider<List<ChatThreadModel>>((ref) {
  final uid = ref.watch(currentUserUidProvider);
  if (uid == null) return Stream.value([]);
  return ChatService.instance.watchThreadsForUser(uid);
});

/// Provider for authorized chat threads (filters based on access).
final authorizedChatThreadsProvider = StreamProvider<List<ChatThreadModel>>((ref) {
  final uid = ref.watch(currentUserUidProvider);
  if (uid == null) return Stream.value([]);
  return ChatService.instance.watchThreadsForUser(uid);
});

/// Provider for messages in a specific thread.
final chatMessagesProvider = StreamProvider.family<List<ChatMessageModel>, String>((ref, threadId) {
  final uid = ref.watch(currentUserUidProvider);
  if (uid == null) return Stream.value([]);
  return ChatService.instance.watchMessagesForThread(threadId, uid);
});

/// Provider for watching chat access changes.
final chatAccessStreamProvider = StreamProvider<bool>((ref) {
  final uid = ref.watch(currentUserUidProvider);
  if (uid == null) return Stream.value(false);
  return ChatService.instance.watchChatAccessForUser(uid);
});

/// Notifier for sending messages.
class ChatMessageNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  final String _threadId;

  ChatMessageNotifier(this._ref, this._threadId) : super(const AsyncValue.data(null));

  Future<ChatResult<ChatMessageModel>> sendMessage(String content) async {
    state = const AsyncValue.loading();

    final uid = _ref.read(currentUserUidProvider);
    if (uid == null) {
      state = const AsyncValue.data(null);
      return ChatResult.failure(ChatErrorCodes.unauthorized, 'Not authenticated');
    }

    final result = await ChatService.instance.sendTextMessage(
      threadId: _threadId,
      currentUid: uid,
      content: content,
    );

    state = const AsyncValue.data(null);
    return result;
  }
}

/// Provider family for message sending.
final chatMessageNotifierProvider = StateNotifierProvider.family<ChatMessageNotifier, AsyncValue<void>, String>(
  (ref, threadId) => ChatMessageNotifier(ref, threadId),
);

/// Model for chat list item (enriched with user details).
class ChatListItem {
  final ChatThreadModel thread;
  final String displayName;
  final String? avatarUrl;
  final String? mood;
  final String? vitals;
  final bool isPatient; // true if current user is patient, false if caregiver
  
  const ChatListItem({
    required this.thread,
    required this.displayName,
    this.avatarUrl,
    this.mood,
    this.vitals,
    required this.isPatient,
  });
}

/// Provider for enriched chat list items.
final chatListItemsProvider = FutureProvider<List<ChatListItem>>((ref) async {
  final uid = ref.watch(currentUserUidProvider);
  if (uid == null) return [];

  final threadsAsync = ref.watch(chatThreadsProvider);
  
  return threadsAsync.when(
    data: (threads) async {
      final items = <ChatListItem>[];
      
      for (final thread in threads) {
        final isPatient = thread.patientId == uid;
        final otherUid = isPatient ? thread.caregiverId : thread.patientId;
        
        // Get other user's details
        // For now, generate a simple display name from UID
        final safeOtherUid = otherUid ?? 'unknown';
        final displayEnd = safeOtherUid.length > 6 ? 6 : safeOtherUid.length;
        String displayName = 'User ${safeOtherUid.substring(0, displayEnd)}';
        String? mood;
        String? vitals;
        
        // TODO: Integrate with OnboardingLocalService when available
        // if (isPatient) {
        //   final caregiverDetails = OnboardingLocalService.instance.getCaregiverDetails(otherUid);
        //   displayName = caregiverDetails?.caregiverName ?? displayName;
        // } else {
        //   final patientDetails = OnboardingLocalService.instance.getPatientDetails(otherUid);
        //   displayName = patientDetails?.name ?? displayName;
        // }
        
        items.add(ChatListItem(
          thread: thread,
          displayName: displayName,
          mood: mood,
          vitals: vitals,
          isPatient: isPatient,
        ));
      }
      
      return items;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Provider for getting or creating thread for current user.
final getOrCreateThreadProvider = FutureProvider<ChatResult<ChatThreadModel>>((ref) async {
  final uid = ref.watch(currentUserUidProvider);
  if (uid == null) {
    return ChatResult.failure(ChatErrorCodes.unauthorized, 'Not authenticated');
  }
  return ChatService.instance.getOrCreateThreadForUser(uid);
});
