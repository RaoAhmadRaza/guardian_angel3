/// ChatMessageModel - Individual message in a Patient ↔ Caregiver conversation.
///
/// Messages follow a strict state machine:
/// draft → pending → sent → delivered → read
///            ↘ failed (retryable)
///
/// Local-first: Messages are written to Hive FIRST, then mirrored to Firestore.
/// Firestore Mirror: chat_threads/{threadId}/messages/{messageId}
library;

/// Message types supported in chat.
enum ChatMessageType {
  /// Plain text message
  text,

  /// Image attachment (URL or local path)
  image,

  /// Voice message (audio file)
  voice,

  /// System message (e.g., "Caregiver joined")
  system,
}

/// Extension for ChatMessageType serialization.
extension ChatMessageTypeExtension on ChatMessageType {
  String get value {
    switch (this) {
      case ChatMessageType.text:
        return 'text';
      case ChatMessageType.image:
        return 'image';
      case ChatMessageType.voice:
        return 'voice';
      case ChatMessageType.system:
        return 'system';
    }
  }

  static ChatMessageType fromString(String value) {
    switch (value) {
      case 'text':
        return ChatMessageType.text;
      case 'image':
        return ChatMessageType.image;
      case 'voice':
        return ChatMessageType.voice;
      case 'system':
        return ChatMessageType.system;
      default:
        throw ArgumentError('Invalid ChatMessageType: $value');
    }
  }
}

/// Local status of a message (for offline-first tracking).
enum ChatMessageLocalStatus {
  /// Message created but not yet queued for send
  draft,

  /// Message queued for send, awaiting confirmation
  pending,

  /// Message successfully sent to Firestore
  sent,

  /// Send failed (will retry)
  failed,
}

/// Extension for ChatMessageLocalStatus serialization.
extension ChatMessageLocalStatusExtension on ChatMessageLocalStatus {
  String get value {
    switch (this) {
      case ChatMessageLocalStatus.draft:
        return 'draft';
      case ChatMessageLocalStatus.pending:
        return 'pending';
      case ChatMessageLocalStatus.sent:
        return 'sent';
      case ChatMessageLocalStatus.failed:
        return 'failed';
    }
  }

  static ChatMessageLocalStatus fromString(String value) {
    switch (value) {
      case 'draft':
        return ChatMessageLocalStatus.draft;
      case 'pending':
        return ChatMessageLocalStatus.pending;
      case 'sent':
        return ChatMessageLocalStatus.sent;
      case 'failed':
        return ChatMessageLocalStatus.failed;
      default:
        return ChatMessageLocalStatus.draft;
    }
  }
}

/// Individual chat message.
class ChatMessageModel {
  /// Unique identifier (UUID)
  final String id;

  /// Thread this message belongs to
  final String threadId;

  /// Firebase UID of the sender
  final String senderId;

  /// Firebase UID of the receiver
  final String receiverId;

  /// Type of message content
  final ChatMessageType messageType;

  /// Message content (text, URL, or path depending on type)
  final String content;

  /// Local status for offline-first tracking
  final ChatMessageLocalStatus localStatus;

  /// Number of retry attempts (for failed messages)
  final int retryCount;

  /// Error message if send failed
  final String? errorMessage;

  /// When this message was created locally
  final DateTime createdAt;

  /// When this message was sent to server (null if not yet sent)
  final DateTime? sentAt;

  /// When this message was delivered to recipient device (null if not yet)
  final DateTime? deliveredAt;

  /// When this message was read by recipient (null if not yet)
  final DateTime? readAt;

  /// Optional metadata (e.g., image dimensions, audio duration)
  final Map<String, dynamic>? metadata;

  /// Whether this message is deleted (soft delete)
  final bool isDeleted;

  const ChatMessageModel({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.receiverId,
    required this.messageType,
    required this.content,
    required this.localStatus,
    this.retryCount = 0,
    this.errorMessage,
    required this.createdAt,
    this.sentAt,
    this.deliveredAt,
    this.readAt,
    this.metadata,
    this.isDeleted = false,
  });

  /// Creates a new text message in draft state.
  factory ChatMessageModel.createText({
    required String id,
    required String threadId,
    required String senderId,
    required String receiverId,
    required String content,
  }) {
    return ChatMessageModel(
      id: id,
      threadId: threadId,
      senderId: senderId,
      receiverId: receiverId,
      messageType: ChatMessageType.text,
      content: content,
      localStatus: ChatMessageLocalStatus.pending,
      createdAt: DateTime.now().toUtc(),
    );
  }

  /// Creates a system message.
  factory ChatMessageModel.createSystem({
    required String id,
    required String threadId,
    required String content,
  }) {
    return ChatMessageModel(
      id: id,
      threadId: threadId,
      senderId: 'system',
      receiverId: 'system',
      messageType: ChatMessageType.system,
      content: content,
      localStatus: ChatMessageLocalStatus.sent,
      createdAt: DateTime.now().toUtc(),
      sentAt: DateTime.now().toUtc(),
    );
  }

  /// Whether this message is from the current user.
  bool isFromUser(String currentUid) => senderId == currentUid;

  /// Whether this message can be retried.
  bool get canRetry => localStatus == ChatMessageLocalStatus.failed && retryCount < 3;

  /// Whether this message is pending send.
  bool get isPending => localStatus == ChatMessageLocalStatus.pending;

  /// Whether this message has been sent.
  bool get isSent => localStatus == ChatMessageLocalStatus.sent;

  /// Whether this message has been delivered.
  bool get isDelivered => deliveredAt != null;

  /// Whether this message has been read.
  bool get isRead => readAt != null;

  /// Creates a copy with updated fields.
  ChatMessageModel copyWith({
    String? id,
    String? threadId,
    String? senderId,
    String? receiverId,
    ChatMessageType? messageType,
    String? content,
    ChatMessageLocalStatus? localStatus,
    int? retryCount,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? sentAt,
    DateTime? deliveredAt,
    DateTime? readAt,
    Map<String, dynamic>? metadata,
    bool? isDeleted,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      threadId: threadId ?? this.threadId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      messageType: messageType ?? this.messageType,
      content: content ?? this.content,
      localStatus: localStatus ?? this.localStatus,
      retryCount: retryCount ?? this.retryCount,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      sentAt: sentAt ?? this.sentAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      metadata: metadata ?? this.metadata,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  /// Marks message as pending (about to send).
  ChatMessageModel markPending() => copyWith(
        localStatus: ChatMessageLocalStatus.pending,
      );

  /// Marks message as sent with timestamp.
  ChatMessageModel markSent() => copyWith(
        localStatus: ChatMessageLocalStatus.sent,
        sentAt: DateTime.now().toUtc(),
      );

  /// Marks message as failed with error.
  ChatMessageModel markFailed(String error) => copyWith(
        localStatus: ChatMessageLocalStatus.failed,
        retryCount: retryCount + 1,
        errorMessage: error,
      );

  /// Marks message as delivered.
  ChatMessageModel markDelivered() => copyWith(
        deliveredAt: DateTime.now().toUtc(),
      );

  /// Marks message as read.
  ChatMessageModel markRead() => copyWith(
        readAt: DateTime.now().toUtc(),
      );

  /// Converts to JSON for Firestore.
  Map<String, dynamic> toJson() => {
        'id': id,
        'thread_id': threadId,
        'sender_id': senderId,
        'receiver_id': receiverId,
        'message_type': messageType.value,
        'content': content,
        'local_status': localStatus.value,
        'retry_count': retryCount,
        'error_message': errorMessage,
        'created_at': createdAt.toUtc().toIso8601String(),
        'sent_at': sentAt?.toUtc().toIso8601String(),
        'delivered_at': deliveredAt?.toUtc().toIso8601String(),
        'read_at': readAt?.toUtc().toIso8601String(),
        'metadata': metadata,
        'is_deleted': isDeleted,
      }..removeWhere((k, v) => v == null);

  /// Creates from JSON (Firestore).
  factory ChatMessageModel.fromJson(Map<String, dynamic> json) => ChatMessageModel(
        id: json['id'] as String,
        threadId: json['thread_id'] as String,
        senderId: json['sender_id'] as String,
        receiverId: json['receiver_id'] as String,
        messageType: ChatMessageTypeExtension.fromString(json['message_type'] as String),
        content: json['content'] as String,
        localStatus: ChatMessageLocalStatusExtension.fromString(
            json['local_status'] as String? ?? 'sent'),
        retryCount: json['retry_count'] as int? ?? 0,
        errorMessage: json['error_message'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
        sentAt: json['sent_at'] != null
            ? DateTime.parse(json['sent_at'] as String).toUtc()
            : null,
        deliveredAt: json['delivered_at'] != null
            ? DateTime.parse(json['delivered_at'] as String).toUtc()
            : null,
        readAt: json['read_at'] != null
            ? DateTime.parse(json['read_at'] as String).toUtc()
            : null,
        metadata: json['metadata'] as Map<String, dynamic>?,
        isDeleted: json['is_deleted'] as bool? ?? false,
      );

  @override
  String toString() =>
      'ChatMessageModel(id: $id, thread: $threadId, sender: $senderId, status: ${localStatus.value})';
}
