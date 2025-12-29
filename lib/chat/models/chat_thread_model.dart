/// ChatThreadModel - Represents a conversation thread between Patient and Caregiver.
///
/// Each thread is STRICTLY tied to a RelationshipModel.
/// If relationship becomes inactive/revoked, the thread is read-only.
///
/// Hive Storage: chat_threads_box
/// Firestore Mirror: chat_threads/{threadId}
library;

/// Chat thread linking Patient ↔ Caregiver conversation.
class ChatThreadModel {
  /// Unique identifier (UUID) - same as relationship.id for 1:1 mapping
  final String id;

  /// The relationship this thread belongs to (MANDATORY).
  /// If null or invalid, thread cannot be accessed.
  final String relationshipId;

  /// Firebase UID of the patient in this conversation.
  final String patientId;

  /// Firebase UID of the caregiver in this conversation.
  final String caregiverId;

  /// When this thread was created.
  final DateTime createdAt;

  /// When the last message was sent/received.
  final DateTime lastMessageAt;

  /// Preview of the last message (truncated).
  final String? lastMessagePreview;

  /// UID of the last message sender.
  final String? lastMessageSenderId;

  /// Count of unread messages for the current user.
  final int unreadCount;

  /// Whether this thread is archived by the user.
  final bool isArchived;

  /// Whether this thread is muted (no notifications).
  final bool isMuted;

  const ChatThreadModel({
    required this.id,
    required this.relationshipId,
    required this.patientId,
    required this.caregiverId,
    required this.createdAt,
    required this.lastMessageAt,
    this.lastMessagePreview,
    this.lastMessageSenderId,
    this.unreadCount = 0,
    this.isArchived = false,
    this.isMuted = false,
  });

  /// Validates this model.
  /// Throws [ChatValidationError] if invalid.
  ChatThreadModel validate() {
    if (id.isEmpty) {
      throw ChatValidationError('id cannot be empty');
    }
    if (relationshipId.isEmpty) {
      throw ChatValidationError('relationshipId cannot be empty');
    }
    if (patientId.isEmpty) {
      throw ChatValidationError('patientId cannot be empty');
    }
    if (caregiverId.isEmpty) {
      throw ChatValidationError('caregiverId cannot be empty');
    }
    if (lastMessageAt.isBefore(createdAt)) {
      throw ChatValidationError('lastMessageAt cannot be before createdAt');
    }
    return this;
  }

  /// Returns the other participant's UID given the current user's UID.
  String getOtherParticipantId(String currentUid) {
    if (currentUid == patientId) return caregiverId;
    if (currentUid == caregiverId) return patientId;
    throw ChatValidationError('User $currentUid is not a participant in this thread');
  }

  /// Checks if a user is a participant in this thread.
  bool isParticipant(String uid) => uid == patientId || uid == caregiverId;

  /// Creates a copy with updated fields.
  ChatThreadModel copyWith({
    String? id,
    String? relationshipId,
    String? patientId,
    String? caregiverId,
    DateTime? createdAt,
    DateTime? lastMessageAt,
    String? lastMessagePreview,
    String? lastMessageSenderId,
    int? unreadCount,
    bool? isArchived,
    bool? isMuted,
  }) {
    return ChatThreadModel(
      id: id ?? this.id,
      relationshipId: relationshipId ?? this.relationshipId,
      patientId: patientId ?? this.patientId,
      caregiverId: caregiverId ?? this.caregiverId,
      createdAt: createdAt ?? this.createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      unreadCount: unreadCount ?? this.unreadCount,
      isArchived: isArchived ?? this.isArchived,
      isMuted: isMuted ?? this.isMuted,
    );
  }

  /// Converts to JSON for Firestore.
  Map<String, dynamic> toJson() => {
        'id': id,
        'relationship_id': relationshipId,
        'patient_id': patientId,
        'caregiver_id': caregiverId,
        'created_at': createdAt.toUtc().toIso8601String(),
        'last_message_at': lastMessageAt.toUtc().toIso8601String(),
        'last_message_preview': lastMessagePreview,
        'last_message_sender_id': lastMessageSenderId,
        'unread_count': unreadCount,
        'is_archived': isArchived,
        'is_muted': isMuted,
      }..removeWhere((k, v) => v == null);

  /// Creates from JSON (Firestore).
  factory ChatThreadModel.fromJson(Map<String, dynamic> json) => ChatThreadModel(
        id: json['id'] as String,
        relationshipId: json['relationship_id'] as String,
        patientId: json['patient_id'] as String,
        caregiverId: json['caregiver_id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
        lastMessageAt: DateTime.parse(json['last_message_at'] as String).toUtc(),
        lastMessagePreview: json['last_message_preview'] as String?,
        lastMessageSenderId: json['last_message_sender_id'] as String?,
        unreadCount: json['unread_count'] as int? ?? 0,
        isArchived: json['is_archived'] as bool? ?? false,
        isMuted: json['is_muted'] as bool? ?? false,
      );

  @override
  String toString() =>
      'ChatThreadModel(id: $id, relationship: $relationshipId, patient: $patientId, caregiver: $caregiverId)';
}

/// Validation error for chat data integrity.
class ChatValidationError implements Exception {
  final String message;
  ChatValidationError(this.message);
  @override
  String toString() => 'ChatValidationError: $message';
}
