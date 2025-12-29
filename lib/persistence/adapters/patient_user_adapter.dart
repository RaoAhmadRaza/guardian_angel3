import 'package:hive/hive.dart';
import '../../onboarding/models/patient_user_model.dart';
import '../type_ids.dart';

/// Hive adapter for PatientUserModel.
class PatientUserAdapter extends TypeAdapter<PatientUserModel> {
  @override
  final int typeId = TypeIds.patientUser;

  @override
  PatientUserModel read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return PatientUserModel(
      uid: fields[0] as String? ?? '',
      role: fields[1] as String? ?? 'patient',
      age: fields[2] as int? ?? 60,
      createdAt: _parse(fields[3] as String?),
      updatedAt: _parse(fields[4] as String?),
    );
  }

  @override
  void write(BinaryWriter writer, PatientUserModel obj) {
    writer
      ..writeByte(5) // number of fields
      ..writeByte(0)
      ..write(obj.uid)
      ..writeByte(1)
      ..write(obj.role)
      ..writeByte(2)
      ..write(obj.age)
      ..writeByte(3)
      ..write(obj.createdAt.toUtc().toIso8601String())
      ..writeByte(4)
      ..write(obj.updatedAt.toUtc().toIso8601String());
  }

  DateTime _parse(String? v) => 
      v != null ? (DateTime.tryParse(v)?.toUtc() ?? DateTime.now().toUtc()) : DateTime.now().toUtc();
}
