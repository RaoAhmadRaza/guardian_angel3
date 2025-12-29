import 'package:hive/hive.dart';
import '../../relationships/models/relationship_model.dart';
import '../type_ids.dart';

/// Hive adapter for RelationshipModel.
class RelationshipAdapter extends TypeAdapter<RelationshipModel> {
  @override
  final int typeId = TypeIds.relationship;

  @override
  RelationshipModel read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return RelationshipModel(
      id: fields[0] as String? ?? '',
      patientId: fields[1] as String? ?? '',
      caregiverId: fields[2] as String?,
      status: _parseStatus(fields[3] as String?),
      permissions: (fields[4] as List?)?.cast<String>() ?? const [],
      inviteCode: fields[5] as String? ?? '',
      createdAt: _parseDateTime(fields[6] as String?),
      updatedAt: _parseDateTime(fields[7] as String?),
      createdBy: fields[8] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, RelationshipModel obj) {
    writer
      ..writeByte(9) // number of fields
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.patientId)
      ..writeByte(2)
      ..write(obj.caregiverId)
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

  RelationshipStatus _parseStatus(String? v) {
    if (v == null) return RelationshipStatus.pending;
    return RelationshipStatusExtension.fromString(v);
  }

  DateTime _parseDateTime(String? v) => 
      v != null ? (DateTime.tryParse(v)?.toUtc() ?? DateTime.now().toUtc()) : DateTime.now().toUtc();
}

/// Hive adapter for RelationshipStatus enum.
class RelationshipStatusAdapter extends TypeAdapter<RelationshipStatus> {
  @override
  final int typeId = TypeIds.relationshipStatus;

  @override
  RelationshipStatus read(BinaryReader reader) {
    final value = reader.readString();
    return RelationshipStatusExtension.fromString(value);
  }

  @override
  void write(BinaryWriter writer, RelationshipStatus obj) {
    writer.writeString(obj.value);
  }
}
