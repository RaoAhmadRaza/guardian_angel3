import 'package:hive/hive.dart';
import '../../models/failed_op_model.dart';
import '../box_registry.dart';

class FailedOpModelAdapter extends TypeAdapter<FailedOpModel> {
  @override
  final int typeId = TypeIds.failedOp;

  @override
  FailedOpModel read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return FailedOpModel(
      id: fields[0] as String? ?? '',
      sourcePendingOpId: fields[1] as String?,
      opType: fields[2] as String? ?? 'unknown',
      payload: (fields[3] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
      errorCode: fields[4] as String?,
      errorMessage: fields[5] as String?,
      idempotencyKey: fields[10] as String?,
      attempts: (fields[6] as int?) ?? 0,
      archived: fields[7] as bool? ?? false,
      createdAt: _parse(fields[8] as String?),
      updatedAt: _parse(fields[9] as String?),
    );
  }

  @override
  void write(BinaryWriter writer, FailedOpModel obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.sourcePendingOpId)
      ..writeByte(2)
      ..write(obj.opType)
      ..writeByte(3)
      ..write(obj.payload)
      ..writeByte(4)
      ..write(obj.errorCode)
      ..writeByte(5)
      ..write(obj.errorMessage)
      ..writeByte(6)
      ..write(obj.attempts)
      ..writeByte(7)
      ..write(obj.archived)
      ..writeByte(8)
      ..write(obj.createdAt.toUtc().toIso8601String())
      ..writeByte(9)
      ..write(obj.updatedAt.toUtc().toIso8601String())
      ..writeByte(10)
      ..write(obj.idempotencyKey);
  }

  DateTime _parse(String? v) => v != null ? (DateTime.tryParse(v)?.toUtc() ?? DateTime.now().toUtc()) : DateTime.now().toUtc();
}