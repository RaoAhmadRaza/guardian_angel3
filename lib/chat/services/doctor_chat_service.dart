/// DoctorChatService - Chat service for Patient ↔ Doctor communication.
///
/// This service mirrors ChatService exactly but uses DoctorRelationshipModel
/// for access validation instead of RelationshipModel.
///
/// Architecture:
/// UI → DoctorChatService → (validates doctor relationship) → ChatRepositoryHive → Hive
///                                                          → ChatFirestoreService → Firestore (mirror)
///
/// SECURITY GUARANTEES:
/// 1. NO chat without active DoctorRelationshipModel
/// 2. NO chat without 'chat' permission in DoctorRelationshipModel
/// 3. NO access to other users' threads
/// 4. Local-first: Hive is source of truth
/// 5. Firestore is non-blocking mirror
///
/// This is the SINGLE ENTRY POINT for all doctor chat operations.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_thread_model.dart';
import '../models/chat_message_model.dart';
import '../repositories/chat_repository.dart';
import '../repositories/chat_repository_hive.dart';
import '../../relationships/models/doctor_relationship_model.dart';
import '../../relationships/services/doctor_relationship_service.dart';
import '../../services/telemetry_service.dart';
import 'chat_firestore_service.dart';

/// Result of a doctor chat access check.
class DoctorChatAccessResult {
  final bool allowed;
  final String? errorCode;
  final String? errorMessage;
  final DoctorRelationshipModel? relationship;

  const DoctorChatAccessResult._({
    required this.allowed,
    this.errorCode,
    this.errorMessage,
    this.relationship,
  });

  factory DoctorChatAccessResult.allowed(DoctorRelationshipModel relationship) =>
      DoctorChatAccessResult._(allowed: true, relationship: relationship);

  factory DoctorChatAccessResult.denied(String code, String message) =>
      DoctorChatAccessResult._(allowed: false, errorCode: code, errorMessage: message);
}

/// Error codes for doctor chat operations.
abstract class DoctorChatErrorCodes {
  static const threadNotFound = 'THREAD_NOT_FOUND';
  static const messageNotFound = 'MESSAGE_NOT_FOUND';
  static const noRelationship = 'NO_DOCTOR_RELATIONSHIP';
  static const relationshipInactive = 'RELATIONSHIP_INACTIVE';
  static const noPermission = 'NO_CHAT_PERMISSION';
  static const validationError = 'VALIDATION_ERROR';
  static const storageError = 'STORAGE_ERROR';
  static const unauthorized = 'UNAUTHORIZED';
  static const sendFailed = 'SEND_FAILED';
}

/// High-level doctor chat service with relationship enforcement.
///
/// MANDATORY: Every public method validates relationship access FIRST.
class DoctorChatService {
  DoctorChatService._();

  static final DoctorChatService _instance = DoctorChatService._();
  static DoctorChatService get instance => _instance;

  final ChatRepositoryHive _repository = ChatRepositoryHive();
  final ChatFirestoreService _firestore = ChatFirestoreService.instance;
  final DoctorRelationshipService _relationshipService = DoctorRelationshipService.instance;
  final TelemetryService _telemetry = getSharedTelemetryInstance();
  final Uuid _uuid = const Uuid();

  // Retry configuration
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 5);

  // Active Firestore subscription for incoming messages
  final Map<String, StreamSubscription> _firestoreSubscriptions = {};

  // ═══════════════════════════════════════════════════════════════════════════
  // ACCESS VALIDATION (MANDATORY BEFORE ANY DOCTOR CHAT OPERATION)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Validates that a user has doctor chat access.
  ///
  /// CHECKS:
  /// 1. User has an active doctor relationship (as patient or doctor)
  /// 2. DoctorRelationshipModel.status == active
  /// 3. DoctorRelationshipModel.doctorId != null
  /// 4. DoctorRelationshipModel.hasPermission('chat') == true
  ///
  /// This MUST be called before any doctor chat operation.
  Future<DoctorChatAccessResult> validateDoctorChatAccess(String currentUid) async {
    debugPrint('[DoctorChatService] Validating doctor chat access for: $currentUid');
    _telemetry.increment('doctor_chat.access.validate.attempt');

    // Check 1: Get user's doctor relationships
    final relationshipResult = await _relationshipService.getRelationshipsForUser(currentUid);
    
    if (!relationshipResult.success || relationshipResult.data == null || relationshipResult.data!.isEmpty) {
      _telemetry.increment('doctor_chat.access.validate.no_relationship');
      return DoctorChatAccessResult.denied(
        DoctorChatErrorCodes.noRelationship,
        'No doctor relationship found. Link with a patient or doctor first.',
      );
    }

    // Find an active relationship
    DoctorRelationshipModel? activeRelationship;
    for (final r in relationshipResult.data!) {
      if (r.status == DoctorRelationshipStatus.active && r.doctorId != null) {
        activeRelationship = r;
        break;
      }
    }

    if (activeRelationship == null) {
      _telemetry.increment('doctor_chat.access.validate.no_active');
      // Check if there's a pending relationship
      final pending = relationshipResult.data!.firstWhere(
        (r) => r.status == DoctorRelationshipStatus.pending,
        orElse: () => relationshipResult.data!.first,
      );
      
      if (pending.status == DoctorRelationshipStatus.pending) {
        return DoctorChatAccessResult.denied(
          DoctorChatErrorCodes.relationshipInactive,
          'Doctor relationship is pending. Waiting for doctor to accept invite.',
        );
      }
      
      return DoctorChatAccessResult.denied(
        DoctorChatErrorCodes.relationshipInactive,
        'Doctor relationship is not active. Status: ${pending.status.value}',
      );
    }

    // Check 2: Verify relationship is active (redundant but explicit)
    if (activeRelationship.status != DoctorRelationshipStatus.active) {
      _telemetry.increment('doctor_chat.access.validate.inactive');
      return DoctorChatAccessResult.denied(
        DoctorChatErrorCodes.relationshipInactive,
        'Doctor relationship is not active. Status: ${activeRelationship.status.value}',
      );
    }

    // Check 3: Verify doctorId is set
    if (activeRelationship.doctorId == null || activeRelationship.doctorId!.isEmpty) {
      _telemetry.increment('doctor_chat.access.validate.no_doctor');
      return DoctorChatAccessResult.denied(
        DoctorChatErrorCodes.relationshipInactive,
        'Doctor relationship does not have a linked doctor yet.',
      );
    }

    // Check 4: Verify chat permission
    if (!activeRelationship.hasPermission('chat')) {
      _telemetry.increment('doctor_chat.access.validate.no_permission');
      return DoctorChatAccessResult.denied(
        DoctorChatErrorCodes.noPermission,
        'Chat permission not granted in this doctor relationship.',
      );
    }

    // Check 5: Verify current user is a participant
    if (currentUid != activeRelationship.patientId && currentUid != activeRelationship.doctorId) {
      _telemetry.increment('doctor_chat.access.validate.not_participant');
      return DoctorChatAccessResult.denied(
        DoctorChatErrorCodes.unauthorized,
        'You are not a participant in this doctor relationship.',
      );
    }

    debugPrint('[DoctorChatService] Doctor chat access granted for: $currentUid');
    _telemetry.increment('doctor_chat.access.validate.allowed');
    return DoctorChatAccessResult.allowed(activeRelationship);
  }

  /// Validates access for a specific doctor thread.
  Future<DoctorChatAccessResult> validateDoctorThreadAccess({
    required String currentUid,
    required String threadId,
  }) async {
    // First validate general doctor chat access
    final accessResult = await validateDoctorChatAccess(currentUid);
    if (!accessResult.allowed) return accessResult;

    // Then verify thread matches relationship
    if (accessResult.relationship!.id != threadId) {
      // Check if thread belongs to any of user's doctor relationships
      final threadResult = await _repository.getThread(threadId);
      if (!threadResult.success || threadResult.data == null) {
        return DoctorChatAccessResult.denied(
          DoctorChatErrorCodes.threadNotFound,
          'Doctor thread not found.',
        );
      }

      final thread = threadResult.data!;
      
      // Verify it's a doctor thread
      if (thread.threadType != ChatThreadType.doctor) {
        return DoctorChatAccessResult.denied(
          DoctorChatErrorCodes.unauthorized,
          'This is not a doctor chat thread.',
        );
      }
      
      if (!thread.isParticipant(currentUid)) {
        _telemetry.increment('doctor_chat.access.validate.unauthorized_thread');
        return DoctorChatAccessResult.denied(
          DoctorChatErrorCodes.unauthorized,
          'You are not a participant in this doctor thread.',
        );
      }
    }

    return accessResult;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // THREAD OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Gets or creates a doctor chat thread for the current user's relationship.
  ///
  /// VALIDATES ACCESS FIRST.
  /// Thread ID = DoctorRelationship ID (1:1 mapping enforced).
  Future<ChatResult<ChatThreadModel>> getOrCreateDoctorThreadForUser(String currentUid) async {
    debugPrint('[DoctorChatService] getOrCreateDoctorThreadForUser: $currentUid');

    // MANDATORY: Validate access
    final access = await validateDoctorChatAccess(currentUid);
    if (!access.allowed) {
      return ChatResult.failure(access.errorCode!, access.errorMessage!);
    }

    final relationship = access.relationship!;

    // Get or create thread using repository
    final result = await _repository.getOrCreateDoctorThread(
      relationshipId: relationship.id,
      patientId: relationship.patientId,
      doctorId: relationship.doctorId!,
    );

    if (result.success && result.data != null) {
      // Mirror to Firestore (non-blocking)
      _firestore.mirrorThread(result.data!).catchError((e) {
        debugPrint('[DoctorChatService] Thread mirror failed: $e');
      });
    }

    return result;
  }

  /// Gets all doctor threads for a user (may have multiple doctor relationships).
  Future<ChatResult<List<ChatThreadModel>>> getDoctorThreadsForUser(String currentUid) async {
    // MANDATORY: Validate access
    final access = await validateDoctorChatAccess(currentUid);
    if (!access.allowed) {
      return ChatResult.failure(access.errorCode!, access.errorMessage!);
    }

    return _repository.getDoctorThreadsForUser(currentUid);
  }

  /// Watches doctor threads for a user with access validation.
  Stream<List<ChatThreadModel>> watchDoctorThreadsForUser(String currentUid) async* {
    // Initial access check
    final access = await validateDoctorChatAccess(currentUid);
    if (!access.allowed) {
      yield [];
      return;
    }

    yield* _repository.watchDoctorThreadsForUser(currentUid);
  }

  /// Marks a doctor thread as read.
  Future<ChatResult<void>> markDoctorThreadAsRead({
    required String threadId,
    required String currentUid,
  }) async {
    // Validate access
    final access = await validateDoctorThreadAccess(currentUid: currentUid, threadId: threadId);
    if (!access.allowed) {
      return ChatResult.failure(access.errorCode!, access.errorMessage!);
    }

    return _repository.markThreadAsRead(threadId: threadId, readerUid: currentUid);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MESSAGE OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Sends a text message in a doctor chat.
  ///
  /// FLOW:
  /// 1. Validate doctor relationship access
  /// 2. Create message with pending status
  /// 3. Save to Hive (LOCAL FIRST)
  /// 4. Update thread metadata
  /// 5. Mirror to Firestore (NON-BLOCKING)
  /// 6. Mark as sent on success, failed on error
  Future<ChatResult<ChatMessageModel>> sendDoctorTextMessage({
    required String threadId,
    required String currentUid,
    required String content,
  }) async {
    debugPrint('[DoctorChatService] sendDoctorTextMessage: thread=$threadId');
    _telemetry.increment('doctor_chat.message.send.attempt');

    // MANDATORY: Validate access
    final access = await validateDoctorThreadAccess(currentUid: currentUid, threadId: threadId);
    if (!access.allowed) {
      _telemetry.increment('doctor_chat.message.send.access_denied');
      return ChatResult.failure(access.errorCode!, access.errorMessage!);
    }

    // Get thread to determine receiver
    final threadResult = await _repository.getThread(threadId);
    if (!threadResult.success || threadResult.data == null) {
      return ChatResult.failure(DoctorChatErrorCodes.threadNotFound, 'Doctor thread not found');
    }

    final thread = threadResult.data!;
    
    // Verify it's a doctor thread
    if (thread.threadType != ChatThreadType.doctor) {
      return ChatResult.failure(DoctorChatErrorCodes.validationError, 'This is not a doctor chat thread');
    }
    
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
      _telemetry.increment('doctor_chat.message.send.local_failed');
      return saveResult;
    }

    debugPrint('[DoctorChatService] Doctor message saved locally: ${message.id}');
    _telemetry.increment('doctor_chat.message.send.local_success');

    // STEP 2: Mirror to Firestore (NON-BLOCKING)
    _mirrorMessageWithRetry(message);

    return ChatResult.success(message);
  }

  /// Retries sending failed doctor messages.
  Future<void> retryFailedDoctorMessages() async {
    debugPrint('[DoctorChatService] Retrying failed doctor messages');
    _telemetry.increment('doctor_chat.message.retry.attempt');

    final result = await _repository.getRetryableMessages();
    if (!result.success || result.data == null) return;

    for (final message in result.data!) {
      // Only retry messages from doctor threads
      final threadResult = await _repository.getThread(message.threadId);
      if (threadResult.success && 
          threadResult.data != null && 
          threadResult.data!.threadType == ChatThreadType.doctor) {
        _mirrorMessageWithRetry(message);
      }
    }
  }

  /// Gets messages for a doctor thread with access validation.
  Future<ChatResult<List<ChatMessageModel>>> getDoctorMessagesForThread(
    String threadId,
    String currentUid, {
    int? limit,
  }) async {
    // Validate access
    final access = await validateDoctorThreadAccess(currentUid: currentUid, threadId: threadId);
    if (!access.allowed) {
      return ChatResult.failure(access.errorCode!, access.errorMessage!);
    }

    return _repository.getMessagesForThread(threadId, limit: limit);
  }

  /// Watches messages for a doctor thread with access validation.
  Stream<List<ChatMessageModel>> watchDoctorMessagesForThread(
    String threadId,
    String currentUid,
  ) async* {
    // Initial access check
    final access = await validateDoctorThreadAccess(currentUid: currentUid, threadId: threadId);
    if (!access.allowed) {
      yield [];
      return;
    }

    yield* _repository.watchMessagesForThread(threadId);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INCOMING MESSAGE SYNC
  // ═══════════════════════════════════════════════════════════════════════════

  /// Starts listening for incoming doctor messages from Firestore.
  ///
  /// Call this when opening a doctor chat thread.
  void startListeningForIncomingDoctorMessages({
    required String threadId,
    required String currentUid,
  }) async {
    // Validate access first
    final access = await validateDoctorThreadAccess(currentUid: currentUid, threadId: threadId);
    if (!access.allowed) {
      debugPrint('[DoctorChatService] Cannot listen: ${access.errorMessage}');
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
            debugPrint('[DoctorChatService] Received doctor message: ${message.id}');

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
        debugPrint('[DoctorChatService] Firestore listener error: $e');
      },
    );

    _firestoreSubscriptions[threadId] = subscription;
    debugPrint('[DoctorChatService] Started listening for doctor thread: $threadId');
  }

  /// Stops listening for incoming doctor messages.
  void stopListeningForIncomingDoctorMessages(String threadId) {
    _firestoreSubscriptions[threadId]?.cancel();
    _firestoreSubscriptions.remove(threadId);
    debugPrint('[DoctorChatService] Stopped listening for doctor thread: $threadId');
  }

  /// Stops all Firestore listeners.
  void stopAllDoctorListeners() {
    for (final sub in _firestoreSubscriptions.values) {
      sub.cancel();
    }
    _firestoreSubscriptions.clear();
    debugPrint('[DoctorChatService] Stopped all doctor chat listeners');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RELATIONSHIP CHANGE HANDLING
  // ═══════════════════════════════════════════════════════════════════════════

  /// Checks if doctor chat is still allowed (for real-time UI updates).
  ///
  /// Call this periodically or when relationship changes.
  Future<bool> isDoctorChatStillAllowed(String currentUid) async {
    final access = await validateDoctorChatAccess(currentUid);
    return access.allowed;
  }

  /// Watches doctor relationship changes that affect chat access.
  ///
  /// Emits false when relationship is revoked or permission removed.
  Stream<bool> watchDoctorChatAccessForUser(String currentUid) async* {
    yield* _relationshipService.watchRelationshipsForUser(currentUid).asyncMap((relationships) async {
      if (relationships.isEmpty) return false;

      // Find any active relationship with chat permission
      for (final r in relationships) {
        if (r.status == DoctorRelationshipStatus.active && 
            r.doctorId != null &&
            r.hasPermission('chat')) {
          return true;
        }
      }
      
      return false;
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
          debugPrint('[DoctorChatService] Doctor message mirrored: ${message.id}');
          _telemetry.increment('doctor_chat.message.mirror.success');
          return;
        }
      } catch (e) {
        debugPrint('[DoctorChatService] Mirror attempt ${attempt + 1} failed: $e');
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
    _telemetry.increment('doctor_chat.message.mirror.failed');
    debugPrint('[DoctorChatService] Doctor message mirror failed permanently: ${message.id}');
  }
}
