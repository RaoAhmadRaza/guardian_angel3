import 'package:hive/hive.dart';
import '../../relationships/models/doctor_relationship_model.dart';
import '../type_ids.dart';

/// Hive adapter for DoctorRelationshipModel.
class DoctorRelationshipAdapter extends TypeAdapter<DoctorRelationshipModel> {
  @override
  final int typeId = TypeIds.doctorRelationship;

  @override
  DoctorRelationshipModel read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return DoctorRelationshipModel(
      id: fields[0] as String? ?? '',
      patientId: fields[1] as String? ?? '',
      doctorId: fields[2] as String?,
      status: _parseStatus(fields[3] as String?),
      permissions: (fields[4] as List?)?.cast<String>() ?? const [],
      inviteCode: fields[5] as String? ?? '',
      createdAt: _parseDateTime(fields[6] as String?),
      updatedAt: _parseDateTime(fields[7] as String?),
      createdBy: fields[8] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, DoctorRelationshipModel obj) {
    writer
      ..writeByte(9) // number of fields
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.patientId)
      ..writeByte(2)
      ..write(obj.doctorId)
      ..writeByte(3)
      ..write(obj.status.value)
      ..writeByte(4)
      ..write(obj.permissions)
      ..writeByte(5)
      ..write(obj.inviteCode)
      ..writeByte(6)
      ..write(obj.createdAt.toUtc().toIso8601String())
      ..writeByte(7)
      ..write(obj.updatedAt.toUtc().toIso8601String())
      ..writeByte(8)
      ..write(obj.createdBy);
  }

  DoctorRelationshipStatus _parseStatus(String? v) {
    if (v == null) return DoctorRelationshipStatus.pending;
    return DoctorRelationshipStatusExtension.fromString(v);
  }

  DateTime _parseDateTime(String? v) => 
      v != null ? (DateTime.tryParse(v)?.toUtc() ?? DateTime.now().toUtc()) : DateTime.now().toUtc();
}

/// Hive adapter for DoctorRelationshipStatus enum.
class DoctorRelationshipStatusAdapter extends TypeAdapter<DoctorRelationshipStatus> {
  @override
  final int typeId = TypeIds.doctorRelationshipStatus;

  @override
  DoctorRelationshipStatus read(BinaryReader reader) {
    final value = reader.readString();
    return DoctorRelationshipStatusExtension.fromString(value);
  }

  @override
  void write(BinaryWriter writer, DoctorRelationshipStatus obj) {
    writer.writeString(obj.value);
  }
}
