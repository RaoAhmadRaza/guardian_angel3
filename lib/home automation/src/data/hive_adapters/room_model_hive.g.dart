// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room_model_hive.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RoomModelHiveAdapter extends TypeAdapter<RoomModelHive> {
  @override
  final int typeId = 0;

  @override
  RoomModelHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RoomModelHive(
      id: fields[0] as String,
      name: fields[1] as String,
      iconId: fields[2] as String,
      color: fields[3] as int,
      createdAt: fields[4] as DateTime?,
      updatedAt: fields[5] as DateTime?,
      version: fields[6] as int,
      iconPath: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, RoomModelHive obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.iconId)
      ..writeByte(3)
      ..write(obj.color)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.updatedAt)
      ..writeByte(6)
      ..write(obj.version)
      ..writeByte(7)
      ..write(obj.iconPath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoomModelHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
