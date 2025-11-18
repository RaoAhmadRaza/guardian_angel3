// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_model_hive.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DeviceModelHiveAdapter extends TypeAdapter<DeviceModelHive> {
  @override
  final int typeId = 1;

  @override
  DeviceModelHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DeviceModelHive(
      id: fields[0] as String,
      roomId: fields[1] as String,
      type: fields[2] as String,
      name: fields[3] as String,
      isOn: fields[4] as bool,
      state: (fields[5] as Map?)?.cast<String, dynamic>(),
      lastSeen: fields[6] as DateTime?,
      updatedAt: fields[7] as DateTime?,
      version: fields[8] as int,
    );
  }

  @override
  void write(BinaryWriter writer, DeviceModelHive obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.roomId)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.name)
      ..writeByte(4)
      ..write(obj.isOn)
      ..writeByte(5)
      ..write(obj.state)
      ..writeByte(6)
      ..write(obj.lastSeen)
      ..writeByte(7)
      ..write(obj.updatedAt)
      ..writeByte(8)
      ..write(obj.version);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceModelHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
