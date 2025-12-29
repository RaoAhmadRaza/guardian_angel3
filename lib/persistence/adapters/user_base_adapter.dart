import 'package:hive/hive.dart';
import '../../onboarding/models/user_base_model.dart';
import '../type_ids.dart';

/// Hive adapter for UserBaseModel.
class UserBaseAdapter extends TypeAdapter<UserBaseModel> {
  @override
  final int typeId = TypeIds.userBase;

  @override
  UserBaseModel read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return UserBaseModel(
      uid: fields[0] as String? ?? '',
      email: fields[1] as String?,
      fullName: fields[2] as String?,
      profileImageUrl: fields[3] as String?,
      createdAt: _parse(fields[4] as String?),
      updatedAt: _parse(fields[5] as String?),
    );
  }

  @override
  void write(BinaryWriter writer, UserBaseModel obj) {
    writer
      ..writeByte(6) // number of fields
      ..writeByte(0)
      ..write(obj.uid)
      ..writeByte(1)
      ..write(obj.email)
      ..writeByte(2)
      ..write(obj.fullName)
      ..writeByte(3)
      ..write(obj.profileImageUrl)
      ..writeByte(4)
      ..write(obj.createdAt.toUtc().toIso8601String())
      ..writeByte(5)
      ..write(obj.updatedAt.toUtc().toIso8601String());
  }

  DateTime _parse(String? v) => 
      v != null ? (DateTime.tryParse(v)?.toUtc() ?? DateTime.now().toUtc()) : DateTime.now().toUtc();
}
