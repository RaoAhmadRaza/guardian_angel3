import 'package:hive/hive.dart';
import '../../models/vitals_model.dart';
import '../box_registry.dart';

class VitalsAdapter extends TypeAdapter<VitalsModel> {
  @override
  final int typeId = TypeIds.vitals;

  @override
  VitalsModel read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    try {
      final id = fields[0] as String? ?? '';
      final userId = fields[1] as String? ?? '';
      final heartRate = (fields[2] as int?) ?? 0;
      final systolic = (fields[3] as int?) ?? 0;
      final diastolic = (fields[4] as int?) ?? 0;
      final temperatureC = (fields[5] as double?);
      final oxygenPercent = (fields[6] as int?);
      final stressIndex = (fields[7] as double?); // added in modelVersion >=2
      final recordedAtStr = fields[8] as String?;
      final schemaVersion = (fields[9] as int?) ?? 1;
      final createdAtStr = fields[10] as String?;
      final updatedAtStr = fields[11] as String?;
      final modelVersion = (fields[12] as int?) ?? (stressIndex != null ? 2 : 1);

      DateTime _parse(String? v) => v != null ? (DateTime.tryParse(v)?.toUtc() ?? DateTime.now().toUtc()) : DateTime.now().toUtc();

      return VitalsModel(
        id: id,
        userId: userId,
        heartRate: heartRate,
        systolicBp: systolic,
        diastolicBp: diastolic,
        temperatureC: temperatureC,
        oxygenPercent: oxygenPercent,
        stressIndex: stressIndex,
        recordedAt: _parse(recordedAtStr),
        schemaVersion: schemaVersion,
        createdAt: _parse(createdAtStr),
        updatedAt: _parse(updatedAtStr),
        modelVersion: modelVersion,
      );
    } catch (_) {
      return VitalsModel(
        id: '',
        userId: '',
        heartRate: 0,
        systolicBp: 0,
        diastolicBp: 0,
        recordedAt: DateTime.now().toUtc(),
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
    }
  }

  @override
  void write(BinaryWriter writer, VitalsModel obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.heartRate)
      ..writeByte(3)
      ..write(obj.systolicBp)
      ..writeByte(4)
      ..write(obj.diastolicBp)
      ..writeByte(5)
      ..write(obj.temperatureC)
      ..writeByte(6)
      ..write(obj.oxygenPercent)
      ..writeByte(7)
      ..write(obj.stressIndex)
      ..writeByte(8)
      ..write(obj.recordedAt.toUtc().toIso8601String())
      ..writeByte(9)
      ..write(obj.schemaVersion)
      ..writeByte(10)
      ..write(obj.createdAt.toUtc().toIso8601String())
      ..writeByte(11)
      ..write(obj.updatedAt.toUtc().toIso8601String())
      ..writeByte(12)
      ..write(obj.modelVersion);
  }
}
