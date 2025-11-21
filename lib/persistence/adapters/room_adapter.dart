import 'package:hive/hive.dart';
import '../../models/room_model.dart';
import '../box_registry.dart';

class RoomAdapter extends TypeAdapter<RoomModel> {
  @override
  final int typeId = TypeIds.room;

  @override
  RoomModel read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    try {
      final id = fields[0] as String? ?? '';
      final name = fields[1] as String? ?? 'Unnamed Room';
      final icon = fields[2] as String?;
      final color = fields[3] as String?;
      final deviceIds = (fields[4] as List?)?.cast<String>() ?? <String>[];
      final meta = (fields[5] as Map?)?.cast<String, dynamic>();
      final schemaVersion = (fields[6] as int?) ?? 1;
      final createdAtStr = fields[7] as String?;
      final updatedAtStr = fields[8] as String?;

      return RoomModel(
        id: id,
        name: name,
        icon: icon,
        color: color,
        deviceIds: deviceIds,
        meta: meta,
        schemaVersion: schemaVersion,
        createdAt: createdAtStr != null
            ? DateTime.tryParse(createdAtStr)?.toUtc() ?? DateTime.now().toUtc()
            : DateTime.now().toUtc(),
        updatedAt: updatedAtStr != null
            ? DateTime.tryParse(updatedAtStr)?.toUtc() ?? DateTime.now().toUtc()
            : DateTime.now().toUtc(),
      );
    } catch (_) {
      // Fallback with minimal defaults
      return RoomModel(
        id: '',
        name: 'Unnamed Room',
        deviceIds: const <String>[],
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
    }
  }

  @override
  void write(BinaryWriter writer, RoomModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.icon)
      ..writeByte(3)
      ..write(obj.color)
      ..writeByte(4)
      ..write(obj.deviceIds)
      ..writeByte(5)
      ..write(obj.meta)
      ..writeByte(6)
      ..write(obj.schemaVersion)
      ..writeByte(7)
      ..write(obj.createdAt.toUtc().toIso8601String())
      ..writeByte(8)
      ..write(obj.updatedAt.toUtc().toIso8601String());
  }
}
