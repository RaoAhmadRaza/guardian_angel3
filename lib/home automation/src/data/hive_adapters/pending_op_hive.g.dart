// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_op_hive.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PendingOpAdapter extends TypeAdapter<PendingOp> {
  @override
  final int typeId = 2;

  @override
  PendingOp read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PendingOp(
      opId: fields[0] as String,
      entityId: fields[1] as String,
      entityType: fields[2] as String,
      opType: fields[3] as String,
      payload: (fields[4] as Map).cast<String, dynamic>(),
      queuedAt: fields[5] as DateTime?,
      attempts: fields[6] as int,
      lastAttemptAt: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, PendingOp obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.opId)
      ..writeByte(1)
      ..write(obj.entityId)
      ..writeByte(2)
      ..write(obj.entityType)
      ..writeByte(3)
      ..write(obj.opType)
      ..writeByte(4)
      ..write(obj.payload)
      ..writeByte(5)
      ..write(obj.queuedAt)
      ..writeByte(6)
      ..write(obj.attempts)
      ..writeByte(7)
      ..write(obj.lastAttemptAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingOpAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
