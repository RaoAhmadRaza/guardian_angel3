/// ChatFirestoreService - Mirrors chat data to Firestore.
///
/// This service handles Firestore mirroring for chat threads and messages.
/// NEVER blocks UI - all operations are fire-and-forget with retry.
///
/// Firestore Structure:
/// - chat_threads/{threadId} - Thread metadata
/// - chat_threads/{threadId}/messages/{messageId} - Individual messages
///
/// CRITICAL: This is a MIRROR only. Hive is the source of truth.
/// Errors here MUST NOT affect local operations.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_thread_model.dart';
import '../models/chat_message_model.dart';
import '../../services/telemetry_service.dart';

/// Firestore mirror service for chat.
class ChatFirestoreService {
  ChatFirestoreService._();

  static final ChatFirestoreService _instance = ChatFirestoreService._();
  static ChatFirestoreService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TelemetryService _telemetry = getSharedTelemetryInstance();

  /// Collection reference for chat threads.
  CollectionReference<Map<String, dynamic>> get _threadsCollection =>
      _firestore.collection('chat_threads');

  /// Gets messages subcollection for a thread.
  CollectionReference<Map<String, dynamic>> _messagesCollection(String threadId) =>
      _threadsCollection.doc(threadId).collection('messages');

  // ═══════════════════════════════════════════════════════════════════════════
  // THREAD MIRRORING
  // ═══════════════════════════════════════════════════════════════════════════

  /// Mirrors a thread to Firestore.
  ///
  /// NON-BLOCKING. Errors are logged but do not propagate.
  /// Uses set with merge to handle both create and update.
  Future<void> mirrorThread(ChatThreadModel thread) async {
    debugPrint('[ChatFirestoreService] Mirroring thread: ${thread.id}');
    _telemetry.increment('chat.firestore.thread.mirror.attempt');

    try {
      await _threadsCollection.doc(thread.id).set(
        {
          ...thread.toJson(),
          'server_updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      debugPrint('[ChatFirestoreService] Thread mirror success: ${thread.id}');
      _telemetry.increment('chat.firestore.thread.mirror.success');
    } catch (e) {
      debugPrint('[ChatFirestoreService] Thread mirror failed: $e');
      _telemetry.increment('chat.firestore.thread.mirror.error');
      // Do NOT rethrow - Firestore failures should not block UI
    }
  }

  /// Fetches a thread from Firestore by ID.
  ///
  /// Used for sync/recovery scenarios.
  Future<ChatThreadModel?> fetchThread(String threadId) async {
    try {
      final doc = await _threadsCollection.doc(threadId).get();
      if (!doc.exists || doc.data() == null) return null;

      return ChatThreadModel.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('[ChatFirestoreService] Fetch thread failed: $e');
      _telemetry.increment('chat.firestore.thread.fetch.error');
      return null;
    }
  }

  /// Fetches all threads for a user from Firestore.
  ///
  /// Queries both patient_id and caregiver_id fields.
  Future<List<ChatThreadModel>> fetchThreadsForUser(String uid) async {
    try {
      // Query as patient
      final patientQuery = await _threadsCollection
          .where('patient_id', isEqualTo: uid)
          .get();

      // Query as caregiver
      final caregiverQuery = await _threadsCollection
          .where('caregiver_id', isEqualTo: uid)
          .get();

      // Combine results, avoiding duplicates
      final Map<String, ChatThreadModel> results = {};

      for (final doc in patientQuery.docs) {
        if (doc.data().isNotEmpty) {
          final thread = ChatThreadModel.fromJson(doc.data());
          results[thread.id] = thread;
        }
      }

      for (final doc in caregiverQuery.docs) {
        if (doc.data().isNotEmpty) {
          final thread = ChatThreadModel.fromJson(doc.data());
          results[thread.id] = thread;
        }
      }

      return results.values.toList();
    } catch (e) {
      debugPrint('[ChatFirestoreService] Fetch threads for user failed: $e');
      _telemetry.increment('chat.firestore.thread.fetch_user.error');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MESSAGE MIRRORING
  // ═══════════════════════════════════════════════════════════════════════════

  /// Mirrors a message to Firestore.
  ///
  /// NON-BLOCKING. Errors are logged but do not propagate.
  /// Uses set with merge to handle both create and update.
  Future<bool> mirrorMessage(ChatMessageModel message) async {
    debugPrint('[ChatFirestoreService] Mirroring message: ${message.id}');
    _telemetry.increment('chat.firestore.message.mirror.attempt');

    try {
      await _messagesCollection(message.threadId).doc(message.id).set(
        {
          ...message.toJson(),
          'server_created_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      debugPrint('[ChatFirestoreService] Message mirror success: ${message.id}');
      _telemetry.increment('chat.firestore.message.mirror.success');
      return true;
    } catch (e) {
      debugPrint('[ChatFirestoreService] Message mirror failed: $e');
      _telemetry.increment('chat.firestore.message.mirror.error');
      // Do NOT rethrow - Firestore failures should not block UI
      return false;
    }
  }

  /// Fetches a message from Firestore.
  Future<ChatMessageModel?> fetchMessage({
    required String threadId,
    required String messageId,
  }) async {
    try {
      final doc = await _messagesCollection(threadId).doc(messageId).get();
      if (!doc.exists || doc.data() == null) return null;

      return ChatMessageModel.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('[ChatFirestoreService] Fetch message failed: $e');
      _telemetry.increment('chat.firestore.message.fetch.error');
      return null;
    }
  }

  /// Fetches messages for a thread from Firestore.
  ///
  /// Used for initial sync or recovery.
  Future<List<ChatMessageModel>> fetchMessagesForThread(
    String threadId, {
    int? limit,
    DateTime? since,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _messagesCollection(threadId)
          .orderBy('created_at', descending: true);

      if (since != null) {
        query = query.where('created_at', isGreaterThan: since.toIso8601String());
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => ChatMessageModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('[ChatFirestoreService] Fetch messages failed: $e');
      _telemetry.increment('chat.firestore.message.fetch_thread.error');
      return [];
    }
  }

  /// Updates delivery status in Firestore.
  Future<void> updateDeliveryStatus({
    required String threadId,
    required String messageId,
    required DateTime deliveredAt,
  }) async {
    try {
      await _messagesCollection(threadId).doc(messageId).update({
        'delivered_at': deliveredAt.toIso8601String(),
      });
    } catch (e) {
      debugPrint('[ChatFirestoreService] Update delivery status failed: $e');
      // Non-blocking
    }
  }

  /// Updates read status in Firestore.
  Future<void> updateReadStatus({
    required String threadId,
    required String messageId,
    required DateTime readAt,
  }) async {
    try {
      await _messagesCollection(threadId).doc(messageId).update({
        'read_at': readAt.toIso8601String(),
      });
    } catch (e) {
      debugPrint('[ChatFirestoreService] Update read status failed: $e');
      // Non-blocking
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REAL-TIME LISTENERS (for incoming messages)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Watches for new messages in a thread.
  ///
  /// Returns a stream that emits when new messages arrive.
  /// Used to sync incoming messages from the other participant.
  Stream<List<ChatMessageModel>> watchMessagesForThread(
    String threadId, {
    DateTime? since,
  }) {
    Query<Map<String, dynamic>> query = _messagesCollection(threadId)
        .orderBy('created_at', descending: false);

    if (since != null) {
      query = query.where('created_at', isGreaterThan: since.toIso8601String());
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ChatMessageModel.fromJson(doc.data()))
          .toList();
    });
  }

  /// Watches thread metadata for changes.
  Stream<ChatThreadModel?> watchThread(String threadId) {
    return _threadsCollection.doc(threadId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return ChatThreadModel.fromJson(snapshot.data()!);
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BATCH OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Mirrors multiple messages in a batch.
  ///
  /// More efficient than individual writes for bulk sync.
  Future<int> mirrorMessagesBatch(List<ChatMessageModel> messages) async {
    if (messages.isEmpty) return 0;

    debugPrint('[ChatFirestoreService] Batch mirroring ${messages.length} messages');
    _telemetry.increment('chat.firestore.message.batch.attempt');

    int successCount = 0;
    final batch = _firestore.batch();

    try {
      for (final message in messages) {
        final ref = _messagesCollection(message.threadId).doc(message.id);
        batch.set(
          ref,
          {
            ...message.toJson(),
            'server_created_at': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
      successCount = messages.length;

      debugPrint('[ChatFirestoreService] Batch mirror success: $successCount messages');
      _telemetry.increment('chat.firestore.message.batch.success');
    } catch (e) {
      debugPrint('[ChatFirestoreService] Batch mirror failed: $e');
      _telemetry.increment('chat.firestore.message.batch.error');
      // Non-blocking - return 0 to indicate failure
    }

    return successCount;
  }

  /// Deletes a message from Firestore (soft delete).
  Future<void> deleteMessage({
    required String threadId,
    required String messageId,
  }) async {
    try {
      await _messagesCollection(threadId).doc(messageId).update({
        'is_deleted': true,
      });
    } catch (e) {
      debugPrint('[ChatFirestoreService] Delete message failed: $e');
      // Non-blocking
    }
  }
}
