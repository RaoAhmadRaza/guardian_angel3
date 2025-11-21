import 'package:hive/hive.dart';
import '../../models/settings_model.dart';
import '../box_registry.dart';

class SettingsModelAdapter extends TypeAdapter<SettingsModel> {
  @override
  final int typeId = TypeIds.settings;

  @override
  SettingsModel read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return SettingsModel(
      notificationsEnabled: fields[0] as bool? ?? true,
      vitalsRetentionDays: (fields[1] as int?) ?? 30,
      updatedAt: _parse(fields[2] as String?),
      devToolsEnabled: fields[3] as bool? ?? false,
      userRole: fields[4] as String? ?? 'patient',
    );
  }

  @override
  void write(BinaryWriter writer, SettingsModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.notificationsEnabled)
      ..writeByte(1)
      ..write(obj.vitalsRetentionDays)
      ..writeByte(2)
      ..write(obj.updatedAt.toUtc().toIso8601String())
      ..writeByte(3)
      ..write(obj.devToolsEnabled)
      ..writeByte(4)
      ..write(obj.userRole);
  }

  DateTime _parse(String? v) => v != null ? (DateTime.tryParse(v)?.toUtc() ?? DateTime.now().toUtc()) : DateTime.now().toUtc();
}