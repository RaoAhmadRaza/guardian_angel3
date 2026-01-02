/// ChatRepositoryHive - Local-first Hive implementation.
///
/// Implements ChatRepository using Hive for local storage.
/// Follows the project's offline-first architecture.
///
/// BOX STRATEGY:
/// - chat_threads_box: keyed by threadId (= relationshipId)
/// - chat_messages_box: keyed by "threadId:messageId" (composite key)
///
/// This single-box approach (vs per-thread boxes) was chosen for:
/// 1. Simpler lifecycle management
/// 2. Easier backup/restore
/// 3. Consistent patterns with existing codebase
/// 4. Efficient prefix-based filtering for thread messages
library;

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../persistence/wrappers/box_accessor.dart';
import '../../services/telemetry_service.dart';
import '../models/chat_thread_model.dart';
import '../models/chat_message_model.dart';
import 'chat_repository.dart';

/// Hive-based implementation of ChatRepository.
class ChatRepositoryHive implements ChatRepository {
  final BoxAccessor _boxAccessor;
  final TelemetryService _telemetry;

  ChatRepositoryHive({
    BoxAccessor? boxAccessor,
    TelemetryService? telemetry,
  })  : _boxAccessor = boxAccessor ?? getSharedBoxAccessorInstance(),
        _telemetry = telemetry ?? getSharedTelemetryInstance();

  /// Access the chat threads box.
  Box<ChatThreadModel> get _threadsBox => _boxAccessor.chatThreads();

  /// Access the chat messages box.
  Box<ChatMessageModel> get _messagesBox => _boxAccessor.chatMessages();

  /// Generates a composite key for messages.
  /// Format: "threadId:messageId"
  String _messageKey(String threadId, String messageId) => '$threadId:$messageId';

  // ═══════════════════════════════════════════════════════════════════════════
  // THREAD OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<ChatResult<ChatThreadModel>> getOrCreateThread({
    required String relationshipId,
    required String patientId,
    required String caregiverId,
  }) async {
    debugPrint('[ChatRepositoryHive] getOrCreateThread for relationship: $relationshipId');
    _telemetry.increment('chat.thread.get_or_create.attempt');

    try {
      // Thread ID = Relationship ID (1:1 mapping)
      final threadId = relationshipId;
      
      // Check if thread exists
      final existing = _threadsBox.get(threadId);
      if (existing != null) {
        debugPrint('[ChatRepositoryHive] Thread exists: $threadId');
        _telemetry.increment('chat.thread.get_or_create.existing');
        return ChatResult.success(existing);
      }

      // Create new thread
      final now = DateTime.now().toUtc();
      final thread = ChatThreadModel(
        id: threadId,
        relationshipId: relationshipId,
        patientId: patientId,
        caregiverId: caregiverId,
        createdAt: now,
        lastMessageAt: now,
      );

      // Validate before saving
      thread.validate();

      // Save to Hive
      await _threadsBox.put(threadId, thread);

      debugPrint('[ChatRepositoryHive] Thread created: $threadId');
      _telemetry.increment('chat.thread.get_or_create.created');

      return ChatResult.success(thread);
    } catch (e) {
      debugPrint('[ChatRepositoryHive] getOrCreateThread failed: $e');
      _telemetry.increment('chat.thread.get_or_create.error');
      
      if (e is ChatValidationError) {
        return ChatResult.failure(ChatErrorCodes.validationError, e.message);
      }
      return ChatResult.failure(ChatErrorCodes.storageError, 'Failed to create thread: $e');
    }
  }

  @override
  Future<ChatResult<ChatThreadModel?>> getThread(String threadId) async {
    try {
      final thread = _threadsBox.get(threadId);
      return ChatResult.success(thread);
    } catch (e) {
      debugPrint('[ChatRepositoryHive] getThread failed: $e');
      return ChatResult.failure(ChatErrorCodes.storageError, 'Failed to get thread: $e');
    }
  }

  @override
  Future<ChatResult<List<ChatThreadModel>>> getThreadsForUser(String uid) async {
    try {
      final threads = _threadsBox.values
          .where((t) => t.patientId == uid || t.caregiverId == uid)
          .where((t) => !t.isArchived)
          .toList();

      // Sort by lastMessageAt descending
      threads.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

      return ChatResult.success(threads);
    } catch (e) {
      debugPrint('[ChatRepositoryHive] getThreadsForUser failed: $e');
      return ChatResult.failure(ChatErrorCodes.storageError, 'Failed to get threads: $e');
    }
  }

  @override
  Future<ChatResult<ChatThreadModel>> updateThread(ChatThreadModel thread) async {
    try {
      thread.validate();
      await _threadsBox.put(thread.id, thread);
      return ChatResult.success(thread);
    } catch (e) {
      debugPrint('[ChatRepositoryHive] updateThread failed: $e');
      if (e is ChatValidationError) {
        return ChatResult.failure(ChatErrorCodes.validationError, e.message);
      }
      return ChatResult.failure(ChatErrorCodes.storageError, 'Failed to update thread: $e');
    }
  }

  @override
  Future<ChatResult<void>> archiveThread(String threadId) async {
    try {
      final thread = _threadsBox.get(threadId);
      if (thread == null) {
        return ChatResult.failure(ChatErrorCodes.threadNotFound, 'Thread not found');
      }
      
      final archived = thread.copyWith(isArchived: true);
      await _threadsBox.put(threadId, archived);
      
      return ChatResult.success(null);
    } catch (e) {
      debugPrint('[ChatRepositoryHive] archiveThread failed: $e');
      return ChatResult.failure(ChatErrorCodes.storageError, 'Failed to archive thread: $e');
    }
  }

  @override
  Future<ChatResult<void>> markThreadAsRead({
    required String threadId,
    required String readerUid,
  }) async {
    try {
      final thread = _threadsBox.get(threadId);
      if (thread == null) {
        return ChatResult.failure(ChatErrorCodes.threadNotFound, 'Thread not found');
      }

      // Reset unread count
      final updated = thread.copyWith(unreadCount: 0);
      await _threadsBox.put(threadId, updated);

      // Mark all unread messages as read
      final messages = _getMessagesForThreadSync(threadId);
      for (final msg in messages) {
        if (msg.receiverId == readerUid && msg.readAt == null) {
          final readMsg = msg.markRead();
          await _messagesBox.put(_messageKey(threadId, msg.id), readMsg);
        }
      }

      _telemetry.increment('chat.thread.mark_read');
      return ChatResult.success(null);
    } catch (e) {
      debugPrint('[ChatRepositoryHive] markThreadAsRead failed: $e');
      return ChatResult.failure(ChatErrorCodes.storageError, 'Failed to mark thread as read: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MESSAGE OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<ChatResult<ChatMessageModel>> saveMessage(ChatMessageModel message) async {
    debugPrint('[ChatRepositoryHive] saveMessage: ${message.id}');
    _telemetry.increment('chat.message.save.attempt');

    try {
      // Check for duplicate (idempotency)
      final key = _messageKey(message.threadId, message.id);
      final existing = _messagesBox.get(key);
      if (existing != null) {
        debugPrint('[ChatRepositoryHive] Duplicate message, returning existing');
        _telemetry.increment('chat.message.save.duplicate');
        return ChatResult.success(existing);
      }

      // Save message
      await _messagesBox.put(key, message);

      // Update thread metadata
      await _updateThreadAfterMessage(message);

      debugPrint('[ChatRepositoryHive] Message saved: ${message.id}');
      _telemetry.increment('chat.message.save.success');

      return ChatResult.success(message);
    } catch (e) {
      debugPrint('[ChatRepositoryHive] saveMessage failed: $e');
      _telemetry.increment('chat.message.save.error');
      return ChatResult.failure(ChatErrorCodes.storageError, 'Failed to save message: $e');
    }
  }

  @override
  Future<ChatResult<ChatMessageModel?>> getMessage({
    required String threadId,
    required String messageId,
  }) async {
    try {
      final key = _messageKey(threadId, messageId);
      final message = _messagesBox.get(key);
      return ChatResult.success(message);
    } catch (e) {
      debugPrint('[ChatRepositoryHive] getMessage failed: $e');
      return ChatResult.failure(ChatErrorCodes.storageError, 'Failed to get message: $e');
    }
  }

  @override
  Future<ChatResult<List<ChatMessageModel>>> getMessagesForThread(
    String threadId, {
    int? limit,
    DateTime? before,
  }) async {
    try {
      var messages = _getMessagesForThreadSync(threadId);

      // Filter by time if specified
      if (before != null) {
        messages = messages.where((m) => m.createdAt.isBefore(before)).toList();
      }

      // Sort by createdAt ascending (oldest first for display)
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // Apply limit
      if (limit != null && messages.length > limit) {
        messages = messages.sublist(messages.length - limit);
      }

      return ChatResult.success(messages);
    } catch (e) {
      debugPrint('[ChatRepositoryHive] getMessagesForThread failed: $e');
      return ChatResult.failure(ChatErrorCodes.storageError, 'Failed to get messages: $e');
    }
  }

  @override
  Future<ChatResult<ChatMessageModel>> updateMessage(ChatMessageModel message) async {
    try {
      final key = _messageKey(message.threadId, message.id);
      await _messagesBox.put(key, message);
      return ChatResult.success(message);
    } catch (e) {
      debugPrint('[ChatRepositoryHive] updateMessage failed: $e');
      return ChatResult.failure(ChatErrorCodes.storageError, 'Failed to update message: $e');
    }
  }

  @override
  Future<ChatResult<ChatMessageModel>> markMessageSent(String messageId) async {
    debugPrint('[ChatRepositoryHive] markMessageSent: $messageId');
    _telemetry.increment('chat.message.mark_sent.attempt');

    try {
      // Find message by ID (need to scan since we don't have threadId)
      ChatMessageModel? found;
      String? foundKey;
      
      for (final key in _messagesBox.keys) {
        if (key.toString().endsWith(':$messageId')) {
          found = _messagesBox.get(key);
          foundKey = key.toString();
          break;
        }
      }

      if (found == null || foundKey == null) {
        return ChatResult.failure(ChatErrorCodes.messageNotFound, 'Message not found');
      }

      final updated = found.markSent();
      await _messagesBox.put(foundKey, updated);

      _telemetry.increment('chat.message.mark_sent.success');
      return ChatResult.success(updated);
    } catch (e) {
      debugPrint('[ChatRepositoryHive] markMessageSent failed: $e');
      _telemetry.increment('chat.message.mark_sent.error');
      return ChatResult.failure(ChatErrorCodes.storageError, 'Failed to mark message sent: $e');
    }
  }

  @override
  Future<ChatResult<ChatMessageModel>> markMessageFailed({
    required String messageId,
    required String error,
  }) async {
    debugPrint('[ChatRepositoryHive] markMessageFailed: $messageId');
    _telemetry.increment('chat.message.mark_failed');

    try {
      ChatMessageModel? found;
      String? foundKey;
      
      for (final key in _messagesBox.keys) {
        if (key.toString().endsWith(':$messageId')) {
          found = _messagesBox.get(key);
          foundKey = key.toString();
          break;
        }
      }

      if (found == null || foundKey == null) {
        return ChatResult.failure(ChatErrorCodes.messageNotFound, 'Message not found');
      }

      final updated = found.markFailed(error);
      await _messagesBox.put(foundKey, updated);

      return ChatResult.success(updated);
    } catch (e) {
      debugPrint('[ChatRepositoryHive] markMessageFailed failed: $e');
      return ChatResult.failure(ChatErrorCodes.storageError, 'Failed to mark message failed: $e');
    }
  }

  @override
  Future<ChatResult<void>> markMessageDelivered(String messageId) async {
    try {
      ChatMessageModel? found;
      String? foundKey;
      
      for (final key in _messagesBox.keys) {
        if (key.toString().endsWith(':$messageId')) {
          found = _messagesBox.get(key);
          foundKey = key.toString();
          break;
        }
      }

      if (found == null || foundKey == null) {
        return ChatResult.failure(ChatErrorCodes.messageNotFound, 'Message not found');
      }

      final updated = found.markDelivered();
      await _messagesBox.put(foundKey, updated);

      return ChatResult.success(null);
    } catch (e) {
      debugPrint('[ChatRepositoryHive] markMessageDelivered failed: $e');
      return ChatResult.failure(ChatErrorCodes.storageError, 'Failed to mark delivered: $e');
    }
  }

  @override
  Future<ChatResult<void>> markMessageRead(String messageId) async {
    try {
      ChatMessageModel? found;
      String? foundKey;
      
      for (final key in _messagesBox.keys) {
        if (key.toString().endsWith(':$messageId')) {
          found = _messagesBox.get(key);
          foundKey = key.toString();
          break;
        }
      }

      if (found == null || foundKey == null) {
        return ChatResult.failure(ChatErrorCodes.messageNotFound, 'Message not found');
      }

      final updated = found.markRead();
      await _messagesBox.put(foundKey, updated);

      return ChatResult.success(null);
    } catch (e) {
      debugPrint('[ChatRepositoryHive] markMessageRead failed: $e');
      return ChatResult.failure(ChatErrorCodes.storageError, 'Failed to mark read: $e');
    }
  }

  @override
  Future<ChatResult<List<ChatMessageModel>>> getPendingMessages() async {
    try {
      final pending = _messagesBox.values
          .where((m) => m.localStatus == ChatMessageLocalStatus.pending)
          .toList();

      // Sort by createdAt ascending (oldest first for retry order)
      pending.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      return ChatResult.success(pending);
    } catch (e) {
      debugPrint('[ChatRepositoryHive] getPendingMessages failed: $e');
      return ChatResult.failure(ChatErrorCodes.storageError, 'Failed to get pending: $e');
    }
  }

  @override
  Future<ChatResult<List<ChatMessageModel>>> getRetryableMessages() async {
    try {
      final retryable = _messagesBox.values
          .where((m) => m.canRetry)
          .toList();

      // Sort by createdAt ascending
      retryable.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      return ChatResult.success(retryable);
    } catch (e) {
      debugPrint('[ChatRepositoryHive] getRetryableMessages failed: $e');
      return ChatResult.failure(ChatErrorCodes.storageError, 'Failed to get retryable: $e');
    }
  }

  @override
  Future<ChatResult<void>> deleteMessage({
    required String threadId,
    required String messageId,
  }) async {
    try {
      final key = _messageKey(threadId, messageId);
      final message = _messagesBox.get(key);
      
      if (message == null) {
        return ChatResult.failure(ChatErrorCodes.messageNotFound, 'Message not found');
      }

      // Soft delete
      final deleted = message.copyWith(isDeleted: true);
      await _messagesBox.put(key, deleted);

      return ChatResult.success(null);
    } catch (e) {
      debugPrint('[ChatRepositoryHive] deleteMessage failed: $e');
      return ChatResult.failure(ChatErrorCodes.storageError, 'Failed to delete message: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STREAMS
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Stream<List<ChatThreadModel>> watchThreadsForUser(String uid) {
    return _threadsBox.watch().map((_) {
      return _threadsBox.values
          .where((t) => t.patientId == uid || t.caregiverId == uid)
          .where((t) => !t.isArchived)
          .toList()
        ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    });
  }

  @override
  Stream<List<ChatMessageModel>> watchMessagesForThread(String threadId) {
    return _messagesBox.watch().map((_) {
      return _getMessagesForThreadSync(threadId)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    });
  }

  @override
  Stream<ChatThreadModel?> watchThread(String threadId) {
    return _threadsBox.watch(key: threadId).map((_) => _threadsBox.get(threadId));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Synchronously gets messages for a thread.
  List<ChatMessageModel> _getMessagesForThreadSync(String threadId) {
    final prefix = '$threadId:';
    return _messagesBox.keys
        .where((k) => k.toString().startsWith(prefix))
        .map((k) => _messagesBox.get(k))
        .whereType<ChatMessageModel>()
        .where((m) => !m.isDeleted)
        .toList();
  }

  /// Updates thread metadata after a new message.
  Future<void> _updateThreadAfterMessage(ChatMessageModel message) async {
    final thread = _threadsBox.get(message.threadId);
    if (thread == null) return;

    // Determine if we need to increment unread
    // Unread is incremented if the receiver hasn't read yet
    final newUnreadCount = thread.unreadCount + 1;

    final updated = thread.copyWith(
      lastMessageAt: message.createdAt,
      lastMessagePreview: _truncateMessage(message.content),
      lastMessageSenderId: message.senderId,
      unreadCount: newUnreadCount,
    );

    await _threadsBox.put(thread.id, updated);
  }

  /// Truncates message content for preview.
  String _truncateMessage(String content, {int maxLength = 50}) {
    if (content.length <= maxLength) return content;
    return '${content.substring(0, maxLength)}...';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DOCTOR THREAD OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Gets or creates a DOCTOR chat thread.
  ///
  /// Thread ID = DoctorRelationship ID (1:1 mapping).
  /// Uses ChatThreadType.doctor to distinguish from caregiver threads.
  Future<ChatResult<ChatThreadModel>> getOrCreateDoctorThread({
    required String relationshipId,
    required String patientId,
    required String doctorId,
  }) async {
    debugPrint('[ChatRepositoryHive] getOrCreateDoctorThread for relationship: $relationshipId');
    _telemetry.increment('chat.doctor_thread.get_or_create.attempt');

    try {
      // Thread ID = DoctorRelationship ID (1:1 mapping)
      final threadId = relationshipId;

      // Check if thread exists
      final existing = _threadsBox.get(threadId);
      if (existing != null) {
        // Verify it's a doctor thread (safety check)
        if (existing.threadType != ChatThreadType.doctor) {
          debugPrint('[ChatRepositoryHive] Thread exists but is not a doctor thread!');
          return ChatResult.failure(
            ChatErrorCodes.validationError,
            'Thread exists but is not a doctor thread. ID collision detected.',
          );
        }
        debugPrint('[ChatRepositoryHive] Doctor thread exists: $threadId');
        _telemetry.increment('chat.doctor_thread.get_or_create.existing');
        return ChatResult.success(existing);
      }

      // Create new doctor thread using named constructor
      final now = DateTime.now().toUtc();
      final thread = ChatThreadModel.doctor(
        id: threadId,
        relationshipId: relationshipId,
        patientId: patientId,
        doctorId: doctorId,
        createdAt: now,
        lastMessageAt: now,
      );

      // Validate before saving
      thread.validate();

      // Save to Hive
      await _threadsBox.put(threadId, thread);

      debugPrint('[ChatRepositoryHive] Doctor thread created: $threadId');
      _telemetry.increment('chat.doctor_thread.get_or_create.created');

      return ChatResult.success(thread);
    } catch (e) {
      debugPrint('[ChatRepositoryHive] getOrCreateDoctorThread failed: $e');
      _telemetry.increment('chat.doctor_thread.get_or_create.error');

      if (e is ChatValidationError) {
        return ChatResult.failure(ChatErrorCodes.validationError, e.message);
      }
      return ChatResult.failure(ChatErrorCodes.storageError, 'Failed to create doctor thread: $e');
    }
  }

  /// Gets all DOCTOR threads for a user.
  ///
  /// Filters threads by ChatThreadType.doctor and participant.
  Future<ChatResult<List<ChatThreadModel>>> getDoctorThreadsForUser(String uid) async {
    debugPrint('[ChatRepositoryHive] getDoctorThreadsForUser: $uid');

    try {
      final threads = _threadsBox.values
          .where((t) => t.threadType == ChatThreadType.doctor)
          .where((t) => t.patientId == uid || t.doctorId == uid)
          .where((t) => !t.isArchived)
          .toList();

      // Sort by lastMessageAt descending
      threads.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

      debugPrint('[ChatRepositoryHive] Found ${threads.length} doctor threads for $uid');
      return ChatResult.success(threads);
    } catch (e) {
      debugPrint('[ChatRepositoryHive] getDoctorThreadsForUser failed: $e');
      return ChatResult.failure(ChatErrorCodes.storageError, 'Failed to get doctor threads: $e');
    }
  }

  /// Watches DOCTOR threads for a user.
  ///
  /// Streams updates when doctor threads change.
  Stream<List<ChatThreadModel>> watchDoctorThreadsForUser(String uid) {
    return _threadsBox.watch().map((_) {
      return _threadsBox.values
          .where((t) => t.threadType == ChatThreadType.doctor)
          .where((t) => t.patientId == uid || t.doctorId == uid)
          .where((t) => !t.isArchived)
          .toList()
        ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    });
  }

  /// Gets all CAREGIVER threads for a user (backward compatible).
  ///
  /// Filters threads by ChatThreadType.caregiver and participant.
  Future<ChatResult<List<ChatThreadModel>>> getCaregiverThreadsForUser(String uid) async {
    try {
      final threads = _threadsBox.values
          .where((t) => t.threadType == ChatThreadType.caregiver)
          .where((t) => t.patientId == uid || t.caregiverId == uid)
          .where((t) => !t.isArchived)
          .toList();

      // Sort by lastMessageAt descending
      threads.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

      return ChatResult.success(threads);
    } catch (e) {
      debugPrint('[ChatRepositoryHive] getCaregiverThreadsForUser failed: $e');
      return ChatResult.failure(ChatErrorCodes.storageError, 'Failed to get caregiver threads: $e');
    }
  }

  /// Watches CAREGIVER threads for a user.
  Stream<List<ChatThreadModel>> watchCaregiverThreadsForUser(String uid) {
    return _threadsBox.watch().map((_) {
      return _threadsBox.values
          .where((t) => t.threadType == ChatThreadType.caregiver)
          .where((t) => t.patientId == uid || t.caregiverId == uid)
          .where((t) => !t.isArchived)
          .toList()
        ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    });
  }
}
