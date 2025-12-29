/// ChatService - High-level orchestrator for chat operations.
///
/// This is the PRIMARY entry point for all chat operations.
/// It enforces RELATIONSHIP VALIDATION before any chat action.
///
/// Architecture:
/// UI → ChatService → (validates relationship) → ChatRepositoryHive → Hive
///                                             → ChatFirestoreService → Firestore (mirror)
///
/// SECURITY GUARANTEES:
/// 1. NO chat without active relationship
/// 2. NO chat without 'chat' permission
/// 3. NO access to other users' threads
/// 4. Local-first: Hive is source of truth
/// 5. Firestore is non-blocking mirror
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_thread_model.dart';
import '../models/chat_message_model.dart';
import '../repositories/chat_repository.dart';
import '../repositories/chat_repository_hive.dart';
import '../../relationships/models/relationship_model.dart';
import '../../relationships/services/relationship_service.dart';
import '../../services/telemetry_service.dart';
import 'chat_firestore_service.dart';

/// Result of a chat access check.
class ChatAccessResult {
  final bool allowed;
  final String? errorCode;
  final String? errorMessage;
  final RelationshipModel? relationship;

  const ChatAccessResult._({
    required this.allowed,
    this.errorCode,
    this.errorMessage,
    this.relationship,
  });

  factory ChatAccessResult.allowed(RelationshipModel relationship) =>
      ChatAccessResult._(allowed: true, relationship: relationship);

  factory ChatAccessResult.denied(String code, String message) =>
      ChatAccessResult._(allowed: false, errorCode: code, errorMessage: message);
}

/// High-level chat service with relationship enforcement.
class ChatService {
  ChatService._();

  static final ChatService _instance = ChatService._();
  static ChatService get instance => _instance;

  final ChatRepository _repository = ChatRepositoryHive();
  final ChatFirestoreService _firestore = ChatFirestoreService.instance;
  final RelationshipService _relationshipService = RelationshipService.instance;
  final TelemetryService _telemetry = getSharedTelemetryInstance();
  final Uuid _uuid = const Uuid();

  // Retry configuration
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 5);

  // Active Firestore subscription for incoming messages
  final Map<String, StreamSubscription> _firestoreSubscriptions = {};

  // ═══════════════════════════════════════════════════════════════════════════
  // ACCESS VALIDATION (MANDATORY BEFORE ANY CHAT OPERATION)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Validates that a user has chat access.
  ///
  /// CHECKS:
  /// 1. User has an active relationship (as patient or caregiver)
  /// 2. Relationship status is ACTIVE
  /// 3. Relationship has 'chat' permission
  ///
  /// This MUST be called before any chat operation.
  Future<ChatAccessResult> validateChatAccess(String currentUid) async {
    debugPrint('[ChatService] Validating chat access for: $currentUid');
    _telemetry.increment('chat.access.validate.attempt');

    // Check 1: Get user's relationship
    final relationshipResult = await _relationshipService.getRelationshipsForUser(currentUid);
    
    if (!relationshipResult.success || relationshipResult.data == null) {
      _telemetry.increment('chat.access.validate.no_relationship');
      return ChatAccessResult.denied(
        ChatErrorCodes.noRelationship,
        'No relationship found. Link with a patient or caregiver first.',
      );
    }

    // Find an active relationship
    final activeRelationship = relationshipResult.data!.firstWhere(
      (r) => r.status == RelationshipStatus.active,
      orElse: () => relationshipResult.data!.first,
    );

    // Check 2: Verify relationship is active
    if (activeRelationship.status != RelationshipStatus.active) {
      _telemetry.increment('chat.access.validate.inactive');
      return ChatAccessResult.denied(
        ChatErrorCodes.relationshipInactive,
        'Relationship is not active. Status: ${activeRelationship.status.value}',
      );
    }

    // Check 3: Verify chat permission
    if (!activeRelationship.hasPermission('chat')) {
      _telemetry.increment('chat.access.validate.no_permission');
      return ChatAccessResult.denied(
        ChatErrorCodes.noPermission,
        'Chat permission not granted in this relationship.',
      );
    }

    debugPrint('[ChatService] Chat access granted for: $currentUid');
    _telemetry.increment('chat.access.validate.allowed');
    return ChatAccessResult.allowed(activeRelationship);
  }

  /// Validates access for a specific thread.
  Future<ChatAccessResult> validateThreadAccess({
    required String currentUid,
    required String threadId,
  }) async {
    // First validate general chat access
    final accessResult = await validateChatAccess(currentUid);
    if (!accessResult.allowed) return accessResult;

    // Then verify thread matches relationship
    if (accessResult.relationship!.id != threadId) {
      // Check if thread belongs to any of user's relationships
      final threadResult = await _repository.getThread(threadId);
      if (!threadResult.success || threadResult.data == null) {
        return ChatAccessResult.denied(
          ChatErrorCodes.threadNotFound,
          'Thread not found.',
        );
      }

      final thread = threadResult.data!;
      if (!thread.isParticipant(currentUid)) {
        _telemetry.increment('chat.access.validate.unauthorized_thread');
        return ChatAccessResult.denied(
          ChatErrorCodes.unauthorized,
          'You are not a participant in this thread.',
        );
      }
    }

    return accessResult;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // THREAD OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Gets or creates a chat thread for the current user's relationship.
  ///
  /// VALIDATES ACCESS FIRST.
  Future<ChatResult<ChatThreadModel>> getOrCreateThreadForUser(String currentUid) async {
    debugPrint('[ChatService] getOrCreateThreadForUser: $currentUid');

    // MANDATORY: Validate access
    final access = await validateChatAccess(currentUid);
    if (!access.allowed) {
      return ChatResult.failure(access.errorCode!, access.errorMessage!);
    }

    final relationship = access.relationship!;

    // Get or create thread (thread ID = relationship ID)
    final result = await _repository.getOrCreateThread(
      relationshipId: relationship.id,
      patientId: relationship.patientId,
      caregiverId: relationship.caregiverId!,
    );

    if (result.success && result.data != null) {
      // Mirror to Firestore (non-blocking)
      _firestore.mirrorThread(result.data!).catchError((e) {
        debugPrint('[ChatService] Thread mirror failed: $e');
      });
    }

    return result;
  }

  /// Gets all threads for a user (should be exactly 1 for patient-caregiver).
  Future<ChatResult<List<ChatThreadModel>>> getThreadsForUser(String currentUid) async {
    // MANDATORY: Validate access
    final access = await validateChatAccess(currentUid);
    if (!access.allowed) {
      return ChatResult.failure(access.errorCode!, access.errorMessage!);
    }

    return _repository.getThreadsForUser(currentUid);
  }

  /// Watches threads for a user with access validation.
  Stream<List<ChatThreadModel>> watchThreadsForUser(String currentUid) async* {
    // Initial access check
    final access = await validateChatAccess(currentUid);
    if (!access.allowed) {
      yield [];
      return;
    }

    yield* _repository.watchThreadsForUser(currentUid);
  }

  /// Marks a thread as read.
  Future<ChatResult<void>> markThreadAsRead({
    required String threadId,
    required String currentUid,
  }) async {
    // Validate access
    final access = await validateThreadAccess(currentUid: currentUid, threadId: threadId);
    if (!access.allowed) {
      return ChatResult.failure(access.errorCode!, access.errorMessage!);
    }

    return _repository.markThreadAsRead(threadId: threadId, readerUid: currentUid);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MESSAGE OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Sends a text message.
  ///
  /// FLOW:
  /// 1. Validate relationship access
  /// 2. Create message with pending status
  /// 3. Save to Hive (LOCAL FIRST)
  /// 4. Update thread metadata
  /// 5. Mirror to Firestore (NON-BLOCKING)
  /// 6. Mark as sent on success, failed on error
  Future<ChatResult<ChatMessageModel>> sendTextMessage({
    required String threadId,
    required String currentUid,
    required String content,
  }) async {
    debugPrint('[ChatService] sendTextMessage: thread=$threadId');
    _telemetry.increment('chat.message.send.attempt');

    // MANDATORY: Validate access
    final access = await validateThreadAccess(currentUid: currentUid, threadId: threadId);
    if (!access.allowed) {
      _telemetry.increment('chat.message.send.access_denied');
      return ChatResult.failure(access.errorCode!, access.errorMessage!);
    }

    // Get thread to determine receiver
    final threadResult = await _repository.getThread(threadId);
    if (!threadResult.success || threadResult.data == null) {
      return ChatResult.failure(ChatErrorCodes.threadNotFound, 'Thread not found');
    }

    final thread = threadResult.data!;
    final receiverId = thread.getOtherParticipantId(currentUid);

    // Create message with pending status
    final message = ChatMessageModel.createText(
      id: _uuid.v4(),
      threadId: threadId,
      senderId: currentUid,
      receiverId: receiverId,
      content: content,
    );

    // STEP 1: Save to Hive (LOCAL FIRST - BLOCKING)
    final saveResult = await _repository.saveMessage(message);
    if (!saveResult.success) {
      _telemetry.increment('chat.message.send.local_failed');
      return saveResult;
    }

    debugPrint('[ChatService] Message saved locally: ${message.id}');
    _telemetry.increment('chat.message.send.local_success');

    // STEP 2: Mirror to Firestore (NON-BLOCKING)
    _mirrorMessageWithRetry(message);

    return ChatResult.success(message);
  }

  /// Retries sending failed messages.
  Future<void> retryFailedMessages() async {
    debugPrint('[ChatService] Retrying failed messages');
    _telemetry.increment('chat.message.retry.attempt');

    final result = await _repository.getRetryableMessages();
    if (!result.success || result.data == null) return;

    for (final message in result.data!) {
      _mirrorMessageWithRetry(message);
    }
  }

  /// Gets messages for a thread with access validation.
  Future<ChatResult<List<ChatMessageModel>>> getMessagesForThread(
    String threadId,
    String currentUid, {
    int? limit,
  }) async {
    // Validate access
    final access = await validateThreadAccess(currentUid: currentUid, threadId: threadId);
    if (!access.allowed) {
      return ChatResult.failure(access.errorCode!, access.errorMessage!);
    }

    return _repository.getMessagesForThread(threadId, limit: limit);
  }

  /// Watches messages for a thread with access validation.
  Stream<List<ChatMessageModel>> watchMessagesForThread(
    String threadId,
    String currentUid,
  ) async* {
    // Initial access check
    final access = await validateThreadAccess(currentUid: currentUid, threadId: threadId);
    if (!access.allowed) {
      yield [];
      return;
    }

    yield* _repository.watchMessagesForThread(threadId);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INCOMING MESSAGE SYNC
  // ═══════════════════════════════════════════════════════════════════════════

  /// Starts listening for incoming messages from Firestore.
  ///
  /// Call this when opening a chat thread.
  void startListeningForIncomingMessages({
    required String threadId,
    required String currentUid,
  }) async {
    // Validate access first
    final access = await validateThreadAccess(currentUid: currentUid, threadId: threadId);
    if (!access.allowed) {
      debugPrint('[ChatService] Cannot listen: ${access.errorMessage}');
      return;
    }

    // Cancel existing subscription
    _firestoreSubscriptions[threadId]?.cancel();

    // Get latest local message timestamp
    final messagesResult = await _repository.getMessagesForThread(threadId, limit: 1);
    DateTime? since;
    if (messagesResult.success && messagesResult.data!.isNotEmpty) {
      since = messagesResult.data!.last.createdAt;
    }

    // Start listening
    final subscription = _firestore.watchMessagesForThread(threadId, since: since).listen(
      (messages) async {
        for (final message in messages) {
          // Skip our own messages
          if (message.senderId == currentUid) continue;

          // Save to local if not exists
          final existing = await _repository.getMessage(
            threadId: threadId,
            messageId: message.id,
          );
          if (existing.data == null) {
            await _repository.saveMessage(message.copyWith(
              localStatus: ChatMessageLocalStatus.sent,
            ));
            debugPrint('[ChatService] Received message: ${message.id}');

            // Update delivery status
            _firestore.updateDeliveryStatus(
              threadId: threadId,
              messageId: message.id,
              deliveredAt: DateTime.now().toUtc(),
            );
          }
        }
      },
      onError: (e) {
        debugPrint('[ChatService] Firestore listener error: $e');
      },
    );

    _firestoreSubscriptions[threadId] = subscription;
    debugPrint('[ChatService] Started listening for thread: $threadId');
  }

  /// Stops listening for incoming messages.
  void stopListeningForIncomingMessages(String threadId) {
    _firestoreSubscriptions[threadId]?.cancel();
    _firestoreSubscriptions.remove(threadId);
    debugPrint('[ChatService] Stopped listening for thread: $threadId');
  }

  /// Stops all Firestore listeners.
  void stopAllListeners() {
    for (final sub in _firestoreSubscriptions.values) {
      sub.cancel();
    }
    _firestoreSubscriptions.clear();
    debugPrint('[ChatService] Stopped all listeners');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RELATIONSHIP CHANGE HANDLING
  // ═══════════════════════════════════════════════════════════════════════════

  /// Checks if chat is still allowed (for real-time UI updates).
  ///
  /// Call this periodically or when relationship changes.
  Future<bool> isChatStillAllowed(String currentUid) async {
    final access = await validateChatAccess(currentUid);
    return access.allowed;
  }

  /// Watches relationship changes that affect chat access.
  ///
  /// Emits false when relationship is revoked or permission removed.
  Stream<bool> watchChatAccessForUser(String currentUid) async* {
    yield* _relationshipService.watchRelationshipsForUser(currentUid).asyncMap((relationships) async {
      if (relationships.isEmpty) return false;

      final active = relationships.firstWhere(
        (r) => r.status == RelationshipStatus.active,
        orElse: () => relationships.first,
      );

      return active.status == RelationshipStatus.active && active.hasPermission('chat');
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Mirrors a message to Firestore with retry logic.
  Future<void> _mirrorMessageWithRetry(ChatMessageModel message) async {
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final success = await _firestore.mirrorMessage(message);
        if (success) {
          // Mark as sent locally
          await _repository.markMessageSent(message.id);
          debugPrint('[ChatService] Message mirrored: ${message.id}');
          _telemetry.increment('chat.message.mirror.success');
          return;
        }
      } catch (e) {
        debugPrint('[ChatService] Mirror attempt ${attempt + 1} failed: $e');
      }

      // Wait before retry
      if (attempt < _maxRetries - 1) {
        await Future.delayed(_retryDelay);
      }
    }

    // All retries failed - mark as failed locally
    await _repository.markMessageFailed(
      messageId: message.id,
      error: 'Failed to send after $_maxRetries attempts',
    );
    _telemetry.increment('chat.message.mirror.failed');
    debugPrint('[ChatService] Message mirror failed permanently: ${message.id}');
  }
}
