// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audit_log_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AuditLogEntryAdapter extends TypeAdapter<AuditLogEntry> {
  @override
  final int typeId = 33;

  @override
  AuditLogEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AuditLogEntry(
      entryId: fields[0] as String,
      timestamp: fields[1] as DateTime,
      userId: fields[2] as String,
      action: fields[3] as String,
      entityType: fields[4] as String?,
      entityId: fields[5] as String?,
      metadata: (fields[6] as Map).cast<String, dynamic>(),
      severity: fields[7] as String,
      ipAddress: fields[8] as String?,
      deviceInfo: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AuditLogEntry obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.entryId)
      ..writeByte(1)
      ..write(obj.timestamp)
      ..writeByte(2)
      ..write(obj.userId)
      ..writeByte(3)
      ..write(obj.action)
      ..writeByte(4)
      ..write(obj.entityType)
      ..writeByte(5)
      ..write(obj.entityId)
      ..writeByte(6)
      ..write(obj.metadata)
      ..writeByte(7)
      ..write(obj.severity)
      ..writeByte(8)
      ..write(obj.ipAddress)
      ..writeByte(9)
      ..write(obj.deviceInfo);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuditLogEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AuditLogArchiveAdapter extends TypeAdapter<AuditLogArchive> {
  @override
  final int typeId = 34;

  @override
  AuditLogArchive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AuditLogArchive(
      archiveId: fields[0] as String,
      createdAt: fields[1] as DateTime,
      startDate: fields[2] as DateTime,
      endDate: fields[3] as DateTime,
      entryCount: fields[4] as int,
      filePath: fields[5] as String,
      fileSizeBytes: fields[6] as int,
      isEncrypted: fields[7] as bool,
      checksum: fields[8] as String,
    );
  }

  @override
  void write(BinaryWriter writer, AuditLogArchive obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.archiveId)
      ..writeByte(1)
      ..write(obj.createdAt)
      ..writeByte(2)
      ..write(obj.startDate)
      ..writeByte(3)
      ..write(obj.endDate)
      ..writeByte(4)
      ..write(obj.entryCount)
      ..writeByte(5)
      ..write(obj.filePath)
      ..writeByte(6)
      ..write(obj.fileSizeBytes)
      ..writeByte(7)
      ..write(obj.isEncrypted)
      ..writeByte(8)
      ..write(obj.checksum);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuditLogArchiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
