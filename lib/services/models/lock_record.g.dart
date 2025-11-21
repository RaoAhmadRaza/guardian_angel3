// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lock_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LockRecordAdapter extends TypeAdapter<LockRecord> {
  @override
  final int typeId = 32;

  @override
  LockRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LockRecord(
      lockName: fields[0] as String,
      runnerId: fields[1] as String,
      acquiredAt: fields[2] as DateTime,
      lastHeartbeat: fields[3] as DateTime,
      metadata: (fields[4] as Map?)?.cast<String, dynamic>(),
      renewalCount: fields[5] as int,
    );
  }

  @override
  void write(BinaryWriter writer, LockRecord obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.lockName)
      ..writeByte(1)
      ..write(obj.runnerId)
      ..writeByte(2)
      ..write(obj.acquiredAt)
      ..writeByte(3)
      ..write(obj.lastHeartbeat)
      ..writeByte(4)
      ..write(obj.metadata)
      ..writeByte(5)
      ..write(obj.renewalCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LockRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
