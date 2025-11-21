import 'package:hive/hive.dart';
import '../../models/session_model.dart';
import '../box_registry.dart';

class SessionModelAdapter extends TypeAdapter<SessionModel> {
  @override
  final int typeId = TypeIds.session;

  @override
  SessionModel read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return SessionModel(
      id: fields[0] as String? ?? '',
      userId: fields[1] as String? ?? '',
      authToken: fields[2] as String? ?? '',
      issuedAt: _parse(fields[3] as String?),
      expiresAt: _parse(fields[4] as String?),
      createdAt: _parse(fields[5] as String?),
      updatedAt: _parse(fields[6] as String?),
    );
  }

  @override
  void write(BinaryWriter writer, SessionModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.authToken)
      ..writeByte(3)
      ..write(obj.issuedAt.toUtc().toIso8601String())
      ..writeByte(4)
      ..write(obj.expiresAt.toUtc().toIso8601String())
      ..writeByte(5)
      ..write(obj.createdAt.toUtc().toIso8601String())
      ..writeByte(6)
      ..write(obj.updatedAt.toUtc().toIso8601String());
  }

  DateTime _parse(String? v) => v != null ? (DateTime.tryParse(v)?.toUtc() ?? DateTime.now().toUtc()) : DateTime.now().toUtc();
}