/// ChatThreadModel - Represents a conversation thread between Patient and Caregiver/Doctor.
///
/// Each thread is STRICTLY tied to a RelationshipModel (caregiver) or DoctorRelationshipModel (doctor).
/// If relationship becomes inactive/revoked, the thread is read-only.
///
/// Thread Identity Rules:
/// - Thread ID = Relationship ID (1:1 mapping)
/// - threadType determines which relationship layer to validate against
/// - 1 relationship = 1 chat thread (enforced)
///
/// Hive Storage: chat_threads_box
/// Firestore Mirror: chat_threads/{threadId}
library;

/// Thread type discriminator for routing validation.
enum ChatThreadType {
  /// Thread between Patient and Caregiver (uses RelationshipModel)
  caregiver,
  
  /// Thread between Patient and Doctor (uses DoctorRelationshipModel)
  doctor,
}

/// Extension for ChatThreadType serialization.
extension ChatThreadTypeExtension on ChatThreadType {
  String get value {
    switch (this) {
      case ChatThreadType.caregiver:
        return 'caregiver';
      case ChatThreadType.doctor:
        return 'doctor';
    }
  }

  static ChatThreadType fromString(String value) {
    switch (value) {
      case 'doctor':
        return ChatThreadType.doctor;
      case 'caregiver':
      default:
        return ChatThreadType.caregiver;
    }
  }
}

/// Chat thread linking Patient ↔ Caregiver or Patient ↔ Doctor conversation.
class ChatThreadModel {
  /// Unique identifier (UUID) - same as relationship.id for 1:1 mapping
  final String id;

  /// The relationship this thread belongs to (MANDATORY).
  /// If null or invalid, thread cannot be accessed.
  final String relationshipId;

  /// Firebase UID of the patient in this conversation.
  final String patientId;

  /// Firebase UID of the caregiver in this conversation (for caregiver threads).
  /// Null for doctor threads.
  final String? caregiverId;
  
  /// Firebase UID of the doctor in this conversation (for doctor threads).
  /// Null for caregiver threads.
  final String? doctorId;
  
  /// Type of this thread - determines validation path.
  /// Default: caregiver (backward compatible)
  final ChatThreadType threadType;

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
    this.caregiverId,
    this.doctorId,
    this.threadType = ChatThreadType.caregiver,
    required this.createdAt,
    required this.lastMessageAt,
    this.lastMessagePreview,
    this.lastMessageSenderId,
    this.unreadCount = 0,
    this.isArchived = false,
    this.isMuted = false,
  });
  
  /// Named constructor for caregiver threads (backward compatible).
  const ChatThreadModel.caregiver({
    required this.id,
    required this.relationshipId,
    required this.patientId,
    required String caregiverId,
    required this.createdAt,
    required this.lastMessageAt,
    this.lastMessagePreview,
    this.lastMessageSenderId,
    this.unreadCount = 0,
    this.isArchived = false,
    this.isMuted = false,
  }) : caregiverId = caregiverId,
       doctorId = null,
       threadType = ChatThreadType.caregiver;
  
  /// Named constructor for doctor threads.
  const ChatThreadModel.doctor({
    required this.id,
    required this.relationshipId,
    required this.patientId,
    required String doctorId,
    required this.createdAt,
    required this.lastMessageAt,
    this.lastMessagePreview,
    this.lastMessageSenderId,
    this.unreadCount = 0,
    this.isArchived = false,
    this.isMuted = false,
  }) : doctorId = doctorId,
       caregiverId = null,
       threadType = ChatThreadType.doctor;

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
    // Validate based on thread type
    if (threadType == ChatThreadType.caregiver && (caregiverId == null || caregiverId!.isEmpty)) {
      throw ChatValidationError('caregiverId cannot be empty for caregiver thread');
    }
    if (threadType == ChatThreadType.doctor && (doctorId == null || doctorId!.isEmpty)) {
      throw ChatValidationError('doctorId cannot be empty for doctor thread');
    }
    if (lastMessageAt.isBefore(createdAt)) {
      throw ChatValidationError('lastMessageAt cannot be before createdAt');
    }
    return this;
  }

  /// Returns the other participant's UID given the current user's UID.
  String getOtherParticipantId(String currentUid) {
    if (currentUid == patientId) {
      // Current user is patient - return doctor or caregiver
      if (threadType == ChatThreadType.doctor) {
        if (doctorId == null) throw ChatValidationError('doctorId is null in doctor thread');
        return doctorId!;
      } else {
        if (caregiverId == null) throw ChatValidationError('caregiverId is null in caregiver thread');
        return caregiverId!;
      }
    }
    // Current user is caregiver or doctor - return patient
    if (threadType == ChatThreadType.doctor && currentUid == doctorId) {
      return patientId;
    }
    if (threadType == ChatThreadType.caregiver && currentUid == caregiverId) {
      return patientId;
    }
    throw ChatValidationError('User $currentUid is not a participant in this thread');
  }

  /// Checks if a user is a participant in this thread.
  bool isParticipant(String uid) {
    if (uid == patientId) return true;
    if (threadType == ChatThreadType.doctor && uid == doctorId) return true;
    if (threadType == ChatThreadType.caregiver && uid == caregiverId) return true;
    return false;
  }
  
  /// Returns true if this is a doctor thread.
  bool get isDoctorThread => threadType == ChatThreadType.doctor;
  
  /// Returns true if this is a caregiver thread.
  bool get isCaregiverThread => threadType == ChatThreadType.caregiver;

  /// Creates a copy with updated fields.
  ChatThreadModel copyWith({
    String? id,
    String? relationshipId,
    String? patientId,
    String? caregiverId,
    String? doctorId,
    ChatThreadType? threadType,
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
      doctorId: doctorId ?? this.doctorId,
      threadType: threadType ?? this.threadType,
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
        'doctor_id': doctorId,
        'thread_type': threadType.value,
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
        caregiverId: json['caregiver_id'] as String?,
        doctorId: json['doctor_id'] as String?,
        threadType: ChatThreadTypeExtension.fromString(json['thread_type'] as String? ?? 'caregiver'),
        createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
        lastMessageAt: DateTime.parse(json['last_message_at'] as String).toUtc(),
        lastMessagePreview: json['last_message_preview'] as String?,
        lastMessageSenderId: json['last_message_sender_id'] as String?,
        unreadCount: json['unread_count'] as int? ?? 0,
        isArchived: json['is_archived'] as bool? ?? false,
        isMuted: json['is_muted'] as bool? ?? false,
      );

  @override
  String toString() {
    if (threadType == ChatThreadType.doctor) {
      return 'ChatThreadModel(id: $id, relationship: $relationshipId, patient: $patientId, doctor: $doctorId, type: doctor)';
    }
    return 'ChatThreadModel(id: $id, relationship: $relationshipId, patient: $patientId, caregiver: $caregiverId, type: caregiver)';
  }
}

/// Validation error for chat data integrity.
class ChatValidationError implements Exception {
  final String message;
  ChatValidationError(this.message);
  @override
  String toString() => 'ChatValidationError: $message';
}
