// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_failure.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SyncFailureAdapter extends TypeAdapter<SyncFailure> {
  @override
  final int typeId = 24;

  @override
  SyncFailure read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SyncFailure(
      id: fields[0] as String,
      entityType: fields[1] as String,
      entityId: fields[2] as String,
      operation: fields[3] as String,
      reason: fields[4] as String,
      errorMessage: fields[5] as String,
      firstFailedAt: fields[6] as DateTime,
      lastAttemptAt: fields[7] as DateTime,
      retryCount: fields[8] as int,
      status: fields[9] as SyncFailureStatus,
      metadata: (fields[10] as Map).cast<String, dynamic>(),
      userId: fields[11] as String?,
      severity: fields[12] as SyncFailureSeverity,
      requiresUserAction: fields[13] as bool,
      suggestedAction: fields[14] as String?,
      resolvedAt: fields[15] as DateTime?,
      resolutionNote: fields[16] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SyncFailure obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.entityType)
      ..writeByte(2)
      ..write(obj.entityId)
      ..writeByte(3)
      ..write(obj.operation)
      ..writeByte(4)
      ..write(obj.reason)
      ..writeByte(5)
      ..write(obj.errorMessage)
      ..writeByte(6)
      ..write(obj.firstFailedAt)
      ..writeByte(7)
      ..write(obj.lastAttemptAt)
      ..writeByte(8)
      ..write(obj.retryCount)
      ..writeByte(9)
      ..write(obj.status)
      ..writeByte(10)
      ..write(obj.metadata)
      ..writeByte(11)
      ..write(obj.userId)
      ..writeByte(12)
      ..write(obj.severity)
      ..writeByte(13)
      ..write(obj.requiresUserAction)
      ..writeByte(14)
      ..write(obj.suggestedAction)
      ..writeByte(15)
      ..write(obj.resolvedAt)
      ..writeByte(16)
      ..write(obj.resolutionNote);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncFailureAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SyncFailureStatusAdapter extends TypeAdapter<SyncFailureStatus> {
  @override
  final int typeId = 25;

  @override
  SyncFailureStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SyncFailureStatus.pending;
      case 1:
        return SyncFailureStatus.retrying;
      case 2:
        return SyncFailureStatus.failed;
      case 3:
        return SyncFailureStatus.resolved;
      case 4:
        return SyncFailureStatus.dismissed;
      default:
        return SyncFailureStatus.pending;
    }
  }

  @override
  void write(BinaryWriter writer, SyncFailureStatus obj) {
    switch (obj) {
      case SyncFailureStatus.pending:
        writer.writeByte(0);
        break;
      case SyncFailureStatus.retrying:
        writer.writeByte(1);
        break;
      case SyncFailureStatus.failed:
        writer.writeByte(2);
        break;
      case SyncFailureStatus.resolved:
        writer.writeByte(3);
        break;
      case SyncFailureStatus.dismissed:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncFailureStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SyncFailureSeverityAdapter extends TypeAdapter<SyncFailureSeverity> {
  @override
  final int typeId = 26;

  @override
  SyncFailureSeverity read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SyncFailureSeverity.low;
      case 1:
        return SyncFailureSeverity.medium;
      case 2:
        return SyncFailureSeverity.high;
      case 3:
        return SyncFailureSeverity.critical;
      default:
        return SyncFailureSeverity.low;
    }
  }

  @override
  void write(BinaryWriter writer, SyncFailureSeverity obj) {
    switch (obj) {
      case SyncFailureSeverity.low:
        writer.writeByte(0);
        break;
      case SyncFailureSeverity.medium:
        writer.writeByte(1);
        break;
      case SyncFailureSeverity.high:
        writer.writeByte(2);
        break;
      case SyncFailureSeverity.critical:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncFailureSeverityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
