import 'package:hive/hive.dart';
import '../../onboarding/models/doctor_user_model.dart';
import '../type_ids.dart';

/// Hive adapter for DoctorUserModel.
class DoctorUserAdapter extends TypeAdapter<DoctorUserModel> {
  @override
  final int typeId = TypeIds.doctorUser;

  @override
  DoctorUserModel read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return DoctorUserModel(
      uid: fields[0] as String? ?? '',
      role: fields[1] as String? ?? 'doctor',
      createdAt: _parse(fields[2] as String?),
      updatedAt: _parse(fields[3] as String?),
    );
  }

  @override
  void write(BinaryWriter writer, DoctorUserModel obj) {
    writer
      ..writeByte(4) // number of fields
      ..writeByte(0)
      ..write(obj.uid)
      ..writeByte(1)
      ..write(obj.role)
      ..writeByte(2)
      ..write(obj.createdAt.toUtc().toIso8601String())
      ..writeByte(3)
      ..write(obj.updatedAt.toUtc().toIso8601String());
  }

  DateTime _parse(String? v) => 
      v != null ? (DateTime.tryParse(v)?.toUtc() ?? DateTime.now().toUtc()) : DateTime.now().toUtc();
}
