import 'package:hive/hive.dart';
import '../../models/audit_log_record.dart';
import '../box_registry.dart';

class AuditLogRecordAdapter extends TypeAdapter<AuditLogRecord> {
  @override
  final int typeId = TypeIds.auditLog;

  @override
  AuditLogRecord read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return AuditLogRecord(
      type: fields[0] as String? ?? 'unknown',
      actor: fields[1] as String? ?? '',
      payload: (fields[2] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
      timestamp: _parse(fields[3] as String?),
      redacted: fields[4] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, AuditLogRecord obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.type)
      ..writeByte(1)
      ..write(obj.actor)
      ..writeByte(2)
      ..write(obj.payload)
      ..writeByte(3)
      ..write(obj.timestamp.toUtc().toIso8601String())
      ..writeByte(4)
      ..write(obj.redacted);
  }

  DateTime _parse(String? v) => v != null ? (DateTime.tryParse(v)?.toUtc() ?? DateTime.now().toUtc()) : DateTime.now().toUtc();
}