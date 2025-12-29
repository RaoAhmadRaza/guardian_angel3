/// ChatRepository - Abstract interface for chat operations.
///
/// Defines the contract for all chat data operations.
/// Implementations: ChatRepositoryHive (local-first)
///
/// RELATIONSHIP ENFORCEMENT:
/// All chat operations REQUIRE a valid relationshipId.
/// The service layer validates relationships BEFORE calling these methods.
library;

import '../models/chat_thread_model.dart';
import '../models/chat_message_model.dart';

/// Result wrapper for chat operations.
class ChatResult<T> {
  final bool success;
  final T? data;
  final String? errorCode;
  final String? errorMessage;

  const ChatResult._({
    required this.success,
    this.data,
    this.errorCode,
    this.errorMessage,
  });

  factory ChatResult.success(T data) => ChatResult._(
        success: true,
        data: data,
      );

  factory ChatResult.failure(String errorCode, String message) => ChatResult._(
        success: false,
        errorCode: errorCode,
        errorMessage: message,
      );

  /// Returns true if this is an error result.
  bool get isError => !success;
}

/// Error codes for chat operations.
abstract class ChatErrorCodes {
  static const threadNotFound = 'THREAD_NOT_FOUND';
  static const messageNotFound = 'MESSAGE_NOT_FOUND';
  static const noRelationship = 'NO_RELATIONSHIP';
  static const relationshipInactive = 'RELATIONSHIP_INACTIVE';
  static const noPermission = 'NO_CHAT_PERMISSION';
  static const validationError = 'VALIDATION_ERROR';
  static const storageError = 'STORAGE_ERROR';
  static const duplicateMessage = 'DUPLICATE_MESSAGE';
  static const unauthorized = 'UNAUTHORIZED';
  static const sendFailed = 'SEND_FAILED';
}

/// Abstract repository interface for chat operations.
abstract class ChatRepository {
  // ═══════════════════════════════════════════════════════════════════════════
  // THREAD OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Creates or gets an existing thread for a relationship.
  ///
  /// IDEMPOTENT: If thread exists, returns existing thread.
  /// Thread ID = Relationship ID (1:1 mapping).
  Future<ChatResult<ChatThreadModel>> getOrCreateThread({
    required String relationshipId,
    required String patientId,
    required String caregiverId,
  });

  /// Gets a thread by ID.
  Future<ChatResult<ChatThreadModel?>> getThread(String threadId);

  /// Gets all threads for a user.
  ///
  /// Returns threads where user is either patient or caregiver.
  Future<ChatResult<List<ChatThreadModel>>> getThreadsForUser(String uid);

  /// Updates thread metadata (last message, unread count, etc.).
  Future<ChatResult<ChatThreadModel>> updateThread(ChatThreadModel thread);

  /// Archives a thread (soft delete).
  Future<ChatResult<void>> archiveThread(String threadId);

  /// Marks all messages in a thread as read.
  Future<ChatResult<void>> markThreadAsRead({
    required String threadId,
    required String readerUid,
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // MESSAGE OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Saves a message locally.
  ///
  /// Called BEFORE Firestore mirror. Sets localStatus = pending.
  Future<ChatResult<ChatMessageModel>> saveMessage(ChatMessageModel message);

  /// Gets a message by ID.
  Future<ChatResult<ChatMessageModel?>> getMessage({
    required String threadId,
    required String messageId,
  });

  /// Gets all messages for a thread.
  ///
  /// Sorted by createdAt descending (newest first).
  Future<ChatResult<List<ChatMessageModel>>> getMessagesForThread(
    String threadId, {
    int? limit,
    DateTime? before,
  });

  /// Updates a message (status changes, delivery/read receipts).
  Future<ChatResult<ChatMessageModel>> updateMessage(ChatMessageModel message);

  /// Marks a message as sent.
  Future<ChatResult<ChatMessageModel>> markMessageSent(String messageId);

  /// Marks a message as failed.
  Future<ChatResult<ChatMessageModel>> markMessageFailed({
    required String messageId,
    required String error,
  });

  /// Marks a message as delivered.
  Future<ChatResult<void>> markMessageDelivered(String messageId);

  /// Marks a message as read.
  Future<ChatResult<void>> markMessageRead(String messageId);

  /// Gets pending messages that need to be sent/retried.
  Future<ChatResult<List<ChatMessageModel>>> getPendingMessages();

  /// Gets failed messages that can be retried.
  Future<ChatResult<List<ChatMessageModel>>> getRetryableMessages();

  /// Deletes a message (soft delete).
  Future<ChatResult<void>> deleteMessage({
    required String threadId,
    required String messageId,
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // STREAMS (for reactive UI)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Watches threads for a user.
  Stream<List<ChatThreadModel>> watchThreadsForUser(String uid);

  /// Watches messages for a thread.
  Stream<List<ChatMessageModel>> watchMessagesForThread(String threadId);

  /// Watches a single thread for changes.
  Stream<ChatThreadModel?> watchThread(String threadId);
}
