/// Community Chat Message Model
/// 
/// Represents a message in the community chat room.
/// Uses Firestore real-time streams for instant updates.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Type of chat message
enum ChatMessageType {
  /// Regular text message
  text,
  
  /// Image message
  image,
  
  /// System message (user joined, etc.)
  system,
  
  /// Shared post from feed
  sharedPost,
}

/// Chat message in community room
class ChatMessage {
  /// Unique message ID (Firestore document ID)
  final String id;
  
  /// Sender's Firebase UID
  final String senderUid;
  
  /// Sender's display name
  final String senderName;
  
  /// Sender's avatar URL
  final String? senderAvatar;
  
  /// Message text content
  final String text;
  
  /// Optional image URL
  final String? imageUrl;
  
  /// Message type
  final ChatMessageType type;
  
  /// When the message was sent
  final DateTime createdAt;
  
  /// Whether message has been read
  final bool isRead;
  
  /// ID of replied message (if this is a reply)
  final String? replyToId;
  
  /// Preview of replied message text
  final String? replyToText;
  
  const ChatMessage({
    required this.id,
    required this.senderUid,
    required this.senderName,
    this.senderAvatar,
    required this.text,
    this.imageUrl,
    this.type = ChatMessageType.text,
    required this.createdAt,
    this.isRead = false,
    this.replyToId,
    this.replyToText,
  });
  
  /// Create from Firestore document
  factory ChatMessage.fromFirestore(Map<String, dynamic> data, String docId) {
    return ChatMessage(
      id: docId,
      senderUid: data['senderUid'] as String? ?? '',
      senderName: data['senderName'] as String? ?? 'Anonymous',
      senderAvatar: data['senderAvatar'] as String?,
      text: data['text'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      type: ChatMessageType.values.firstWhere(
        (t) => t.name == (data['type'] as String?),
        orElse: () => ChatMessageType.text,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] as bool? ?? false,
      replyToId: data['replyToId'] as String?,
      replyToText: data['replyToText'] as String?,
    );
  }
  
  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'senderUid': senderUid,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'text': text,
      'imageUrl': imageUrl,
      'type': type.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      'replyToId': replyToId,
      'replyToText': replyToText,
    };
  }
  
  /// Check if message is from current user
  bool isFromUser(String currentUid) => senderUid == currentUid;
  
  /// Alias for senderAvatar for API consistency
  String? get senderAvatarUrl => senderAvatar;
  
  /// Check if this is a system message
  bool get isSystem => type == ChatMessageType.system;
  
  /// Get formatted time (e.g., "10:30 AM")
  String get formattedTime {
    final hour = createdAt.hour;
    final minute = createdAt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
  
  /// Create a system message
  factory ChatMessage.system({
    required String text,
    String? id,
  }) {
    return ChatMessage(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      senderUid: 'system',
      senderName: 'System',
      text: text,
      type: ChatMessageType.system,
      createdAt: DateTime.now(),
    );
  }
  
  @override
  String toString() => 'ChatMessage($id from $senderName)';
}

/// Chat room metadata
class ChatRoom {
  /// Room ID (typically based on geohash or community ID)
  final String id;
  
  /// Room name
  final String name;
  
  /// Room description
  final String? description;
  
  /// Number of active participants
  final int participantCount;
  
  /// Last message preview
  final String? lastMessage;
  
  /// Time of last message
  final DateTime? lastMessageAt;
  
  /// Room cover image
  final String? coverImage;
  
  /// Whether room is active
  final bool isActive;
  
  const ChatRoom({
    required this.id,
    required this.name,
    this.description,
    this.participantCount = 0,
    this.lastMessage,
    this.lastMessageAt,
    this.coverImage,
    this.isActive = true,
  });
  
  /// Create from Firestore document
  factory ChatRoom.fromFirestore(Map<String, dynamic> data, String docId) {
    return ChatRoom(
      id: docId,
      name: data['name'] as String? ?? 'Chat Room',
      description: data['description'] as String?,
      participantCount: data['participantCount'] as int? ?? 0,
      lastMessage: data['lastMessage'] as String?,
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      coverImage: data['coverImage'] as String?,
      isActive: data['isActive'] as bool? ?? true,
    );
  }
  
  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'participantCount': participantCount,
      'lastMessage': lastMessage,
      'lastMessageAt': lastMessageAt != null 
          ? Timestamp.fromDate(lastMessageAt!) 
          : null,
      'coverImage': coverImage,
      'isActive': isActive,
    };
  }
}
