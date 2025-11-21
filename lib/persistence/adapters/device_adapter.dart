import 'package:hive/hive.dart';
import '../../models/device_model.dart';
import '../box_registry.dart';

class DeviceModelAdapter extends TypeAdapter<DeviceModel> {
  @override
  final int typeId = TypeIds.device;

  @override
  DeviceModel read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return DeviceModel(
      id: fields[0] as String? ?? '',
      roomId: fields[1] as String? ?? '',
      type: fields[2] as String? ?? 'unknown',
      status: fields[3] as String? ?? 'active',
      properties: (fields[4] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
      createdAt: _parse(fields[5] as String?),
      updatedAt: _parse(fields[6] as String?),
    );
  }

  @override
  void write(BinaryWriter writer, DeviceModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.roomId)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.properties)
      ..writeByte(5)
      ..write(obj.createdAt.toUtc().toIso8601String())
      ..writeByte(6)
      ..write(obj.updatedAt.toUtc().toIso8601String());
  }

  DateTime _parse(String? v) => v != null ? (DateTime.tryParse(v)?.toUtc() ?? DateTime.now().toUtc()) : DateTime.now().toUtc();
}