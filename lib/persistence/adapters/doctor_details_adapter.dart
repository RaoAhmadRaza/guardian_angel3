import 'package:hive/hive.dart';
import '../../onboarding/models/doctor_details_model.dart';
import '../type_ids.dart';

/// Hive adapter for DoctorDetailsModel.
class DoctorDetailsAdapter extends TypeAdapter<DoctorDetailsModel> {
  @override
  final int typeId = TypeIds.doctorDetails;

  @override
  DoctorDetailsModel read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return DoctorDetailsModel(
      uid: fields[0] as String? ?? '',
      fullName: fields[1] as String? ?? '',
      email: fields[2] as String? ?? '',
      phoneNumber: fields[3] as String? ?? '',
      specialization: fields[4] as String? ?? '',
      licenseNumber: fields[5] as String? ?? '',
      yearsOfExperience: fields[6] as int? ?? 0,
      clinicOrHospitalName: fields[7] as String? ?? '',
      address: fields[8] as String? ?? '',
      isVerified: fields[9] as bool? ?? false,
      isComplete: fields[10] as bool? ?? false,
      createdAt: _parse(fields[11] as String?),
      updatedAt: _parse(fields[12] as String?),
    );
  }

  @override
  void write(BinaryWriter writer, DoctorDetailsModel obj) {
    writer
      ..writeByte(13) // number of fields
      ..writeByte(0)
      ..write(obj.uid)
      ..writeByte(1)
      ..write(obj.fullName)
      ..writeByte(2)
      ..write(obj.email)
      ..writeByte(3)
      ..write(obj.phoneNumber)
      ..writeByte(4)
      ..write(obj.specialization)
      ..writeByte(5)
      ..write(obj.licenseNumber)
      ..writeByte(6)
      ..write(obj.yearsOfExperience)
      ..writeByte(7)
      ..write(obj.clinicOrHospitalName)
      ..writeByte(8)
      ..write(obj.address)
      ..writeByte(9)
      ..write(obj.isVerified)
      ..writeByte(10)
      ..write(obj.isComplete)
      ..writeByte(11)
      ..write(obj.createdAt.toUtc().toIso8601String())
      ..writeByte(12)
      ..write(obj.updatedAt.toUtc().toIso8601String());
  }

  DateTime _parse(String? v) => 
      v != null ? (DateTime.tryParse(v)?.toUtc() ?? DateTime.now().toUtc()) : DateTime.now().toUtc();
}
