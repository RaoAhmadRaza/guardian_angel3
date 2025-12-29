/// Hive adapters for Chat models.
///
/// TypeIds:
/// - 47: ChatThreadModel
/// - 48: ChatMessageModel  
/// - 49: ChatMessageType
/// - 50: ChatMessageLocalStatus
library;

import 'package:hive/hive.dart';
import '../../chat/models/chat_thread_model.dart';
import '../../chat/models/chat_message_model.dart';
import '../type_ids.dart';

/// Hive adapter for ChatThreadModel.
class ChatThreadAdapter extends TypeAdapter<ChatThreadModel> {
  @override
  final int typeId = TypeIds.chatThread;

  @override
  ChatThreadModel read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return ChatThreadModel(
      id: fields[0] as String? ?? '',
      relationshipId: fields[1] as String? ?? '',
      patientId: fields[2] as String? ?? '',
      caregiverId: fields[3] as String? ?? '',
      createdAt: _parseDateTime(fields[4] as String?),
      lastMessageAt: _parseDateTime(fields[5] as String?),
      lastMessagePreview: fields[6] as String?,
      lastMessageSenderId: fields[7] as String?,
      unreadCount: fields[8] as int? ?? 0,
      isArchived: fields[9] as bool? ?? false,
      isMuted: fields[10] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, ChatThreadModel obj) {
    writer
      ..writeByte(11) // number of fields
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.relationshipId)
      ..writeByte(2)
      ..write(obj.patientId)
      ..writeByte(3)
      ..write(obj.caregiverId)
      ..writeByte(4)
      ..write(obj.createdAt.toUtc().toIso8601String())
      ..writeByte(5)
      ..write(obj.lastMessageAt.toUtc().toIso8601String())
      ..writeByte(6)
      ..write(obj.lastMessagePreview)
      ..writeByte(7)
      ..write(obj.lastMessageSenderId)
      ..writeByte(8)
      ..write(obj.unreadCount)
      ..writeByte(9)
      ..write(obj.isArchived)
      ..writeByte(10)
      ..write(obj.isMuted);
  }

  DateTime _parseDateTime(String? v) =>
      v != null ? (DateTime.tryParse(v)?.toUtc() ?? DateTime.now().toUtc()) : DateTime.now().toUtc();
}

/// Hive adapter for ChatMessageModel.
class ChatMessageAdapter extends TypeAdapter<ChatMessageModel> {
  @override
  final int typeId = TypeIds.chatMessage;

  @override
  ChatMessageModel read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return ChatMessageModel(
      id: fields[0] as String? ?? '',
      threadId: fields[1] as String? ?? '',
      senderId: fields[2] as String? ?? '',
      receiverId: fields[3] as String? ?? '',
      messageType: _parseMessageType(fields[4] as String?),
      content: fields[5] as String? ?? '',
      localStatus: _parseLocalStatus(fields[6] as String?),
      retryCount: fields[7] as int? ?? 0,
      errorMessage: fields[8] as String?,
      createdAt: _parseDateTime(fields[9] as String?),
      sentAt: fields[10] != null ? _parseDateTime(fields[10] as String?) : null,
      deliveredAt: fields[11] != null ? _parseDateTime(fields[11] as String?) : null,
      readAt: fields[12] != null ? _parseDateTime(fields[12] as String?) : null,
      metadata: _parseMetadata(fields[13]),
      isDeleted: fields[14] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, ChatMessageModel obj) {
    writer
      ..writeByte(15) // number of fields
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.threadId)
      ..writeByte(2)
      ..write(obj.senderId)
      ..writeByte(3)
      ..write(obj.receiverId)
      ..writeByte(4)
      ..write(obj.messageType.value)
      ..writeByte(5)
      ..write(obj.content)
      ..writeByte(6)
      ..write(obj.localStatus.value)
      ..writeByte(7)
      ..write(obj.retryCount)
      ..writeByte(8)
      ..write(obj.errorMessage)
      ..writeByte(9)
      ..write(obj.createdAt.toUtc().toIso8601String())
      ..writeByte(10)
      ..write(obj.sentAt?.toUtc().toIso8601String())
      ..writeByte(11)
      ..write(obj.deliveredAt?.toUtc().toIso8601String())
      ..writeByte(12)
      ..write(obj.readAt?.toUtc().toIso8601String())
      ..writeByte(13)
      ..write(obj.metadata)
      ..writeByte(14)
      ..write(obj.isDeleted);
  }

  ChatMessageType _parseMessageType(String? v) {
    if (v == null) return ChatMessageType.text;
    return ChatMessageTypeExtension.fromString(v);
  }

  ChatMessageLocalStatus _parseLocalStatus(String? v) {
    if (v == null) return ChatMessageLocalStatus.pending;
    return ChatMessageLocalStatusExtension.fromString(v);
  }

  DateTime _parseDateTime(String? v) =>
      v != null ? (DateTime.tryParse(v)?.toUtc() ?? DateTime.now().toUtc()) : DateTime.now().toUtc();

  Map<String, dynamic>? _parseMetadata(dynamic v) {
    if (v == null) return null;
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }
}

/// Hive adapter for ChatMessageType enum.
class ChatMessageTypeAdapter extends TypeAdapter<ChatMessageType> {
  @override
  final int typeId = TypeIds.chatMessageType;

  @override
  ChatMessageType read(BinaryReader reader) {
    final value = reader.readString();
    return ChatMessageTypeExtension.fromString(value);
  }

  @override
  void write(BinaryWriter writer, ChatMessageType obj) {
    writer.writeString(obj.value);
  }
}

/// Hive adapter for ChatMessageLocalStatus enum.
class ChatMessageLocalStatusAdapter extends TypeAdapter<ChatMessageLocalStatus> {
  @override
  final int typeId = TypeIds.chatMessageLocalStatus;

  @override
  ChatMessageLocalStatus read(BinaryReader reader) {
    final value = reader.readString();
    return ChatMessageLocalStatusExtension.fromString(value);
  }

  @override
  void write(BinaryWriter writer, ChatMessageLocalStatus obj) {
    writer.writeString(obj.value);
  }
}
