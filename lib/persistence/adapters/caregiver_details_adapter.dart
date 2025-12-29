import 'package:hive/hive.dart';
import '../../onboarding/models/caregiver_details_model.dart';
import '../type_ids.dart';

/// Hive adapter for CaregiverDetailsModel.
class CaregiverDetailsAdapter extends TypeAdapter<CaregiverDetailsModel> {
  @override
  final int typeId = TypeIds.caregiverDetails;

  @override
  CaregiverDetailsModel read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return CaregiverDetailsModel(
      uid: fields[0] as String? ?? '',
      caregiverName: fields[1] as String? ?? '',
      phoneNumber: fields[2] as String? ?? '',
      emailAddress: fields[3] as String? ?? '',
      relationToPatient: fields[4] as String? ?? '',
      patientName: fields[5] as String? ?? '',
      isComplete: fields[6] as bool? ?? false,
      createdAt: _parse(fields[7] as String?),
      updatedAt: _parse(fields[8] as String?),
    );
  }

  @override
  void write(BinaryWriter writer, CaregiverDetailsModel obj) {
    writer
      ..writeByte(9) // number of fields
      ..writeByte(0)
      ..write(obj.uid)
      ..writeByte(1)
      ..write(obj.caregiverName)
      ..writeByte(2)
      ..write(obj.phoneNumber)
      ..writeByte(3)
      ..write(obj.emailAddress)
      ..writeByte(4)
      ..write(obj.relationToPatient)
      ..writeByte(5)
      ..write(obj.patientName)
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
