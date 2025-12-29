import 'package:hive/hive.dart';
import '../../models/user_profile_model.dart';
import '../box_registry.dart';

class UserProfileModelAdapter extends TypeAdapter<UserProfileModel> {
  @override
  final int typeId = TypeIds.userProfile;

  @override
  UserProfileModel read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return UserProfileModel(
      id: fields[0] as String? ?? '',
      role: fields[1] as String? ?? 'patient',
      displayName: fields[2] as String? ?? '',
      email: fields[3] as String?,
      createdAt: _parse(fields[4] as String?),
      updatedAt: _parse(fields[5] as String?),
      age: fields[6] as int?,
      address: fields[7] as String?,
      medicalHistory: fields[8] as String?,
      gender: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, UserProfileModel obj) {
    writer
      ..writeByte(10) // Updated field count
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.role)
      ..writeByte(2)
      ..write(obj.displayName)
      ..writeByte(3)
      ..write(obj.email)
      ..writeByte(4)
      ..write(obj.createdAt.toUtc().toIso8601String())
      ..writeByte(5)
      ..write(obj.updatedAt.toUtc().toIso8601String())
      ..writeByte(6)
      ..write(obj.age)
      ..writeByte(7)
      ..write(obj.address)
      ..writeByte(8)
      ..write(obj.medicalHistory)
      ..writeByte(9)
      ..write(obj.gender);
  }

  DateTime _parse(String? v) => v != null ? (DateTime.tryParse(v)?.toUtc() ?? DateTime.now().toUtc()) : DateTime.now().toUtc();
}