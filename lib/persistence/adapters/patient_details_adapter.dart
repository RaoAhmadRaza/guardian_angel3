import 'package:hive/hive.dart';
import '../../onboarding/models/patient_details_model.dart';
import '../type_ids.dart';

/// Hive adapter for PatientDetailsModel.
class PatientDetailsAdapter extends TypeAdapter<PatientDetailsModel> {
  @override
  final int typeId = TypeIds.patientDetails;

  @override
  PatientDetailsModel read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return PatientDetailsModel(
      uid: fields[0] as String? ?? '',
      gender: fields[1] as String? ?? '',
      name: fields[2] as String? ?? '',
      phoneNumber: fields[3] as String? ?? '',
      address: fields[4] as String? ?? '',
      medicalHistory: fields[5] as String? ?? '',
      isComplete: fields[6] as bool? ?? false,
      createdAt: _parse(fields[7] as String?),
      updatedAt: _parse(fields[8] as String?),
    );
  }

  @override
  void write(BinaryWriter writer, PatientDetailsModel obj) {
    writer
      ..writeByte(9) // number of fields
      ..writeByte(0)
      ..write(obj.uid)
      ..writeByte(1)
      ..write(obj.gender)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.phoneNumber)
      ..writeByte(4)
      ..write(obj.address)
      ..writeByte(5)
      ..write(obj.medicalHistory)
      ..writeByte(6)
      ..write(obj.isComplete)
      ..writeByte(7)
      ..write(obj.createdAt.toUtc().toIso8601String())
      ..writeByte(8)
      ..write(obj.updatedAt.toUtc().toIso8601String());
  }

  DateTime _parse(String? v) => 
      v != null ? (DateTime.tryParse(v)?.toUtc() ?? DateTime.now().toUtc()) : DateTime.now().toUtc();
}
