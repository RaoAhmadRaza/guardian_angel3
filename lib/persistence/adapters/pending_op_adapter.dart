import 'package:hive/hive.dart';
import '../models/pending_op.dart';
import '../box_registry.dart';
import '../queue/op_priority.dart';

class PendingOpAdapter extends TypeAdapter<PendingOp> {
  @override
  final int typeId = TypeIds.pendingOp;

  @override
  PendingOp read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    try {
      final id = fields[0] as String? ?? '';
      final opType = fields[1] as String? ?? 'unknown';
      final idempotencyKey = fields[2] as String? ?? '';
      final payload = (fields[3] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
      final attempts = (fields[4] as int?) ?? 0;
      final status = fields[5] as String? ?? 'pending';
      final lastError = fields[6] as String?;
      final schemaVersion = (fields[7] as int?) ?? 1;
      final createdAtStr = fields[8] as String?;
      final updatedAtStr = fields[9] as String?;
      final lastTriedAtStr = fields[10] as String?; // Field 10: lastTriedAt
      final nextEligibleAtStr = fields[11] as String?; // Field 11: nextEligibleAt
      final entityKey = fields[12] as String?; // Field 12: entityKey
      final priorityStr = fields[13] as String?; // Field 13: priority
      final deliveryStateStr = fields[14] as String?; // Field 14: deliveryState

      return PendingOp(
        id: id,
        opType: opType,
        idempotencyKey: idempotencyKey,
        payload: payload,
        attempts: attempts,
        status: status,
        lastError: lastError,
        lastTriedAt: lastTriedAtStr != null
            ? DateTime.tryParse(lastTriedAtStr)?.toUtc()
            : null,
        nextEligibleAt: nextEligibleAtStr != null
            ? DateTime.tryParse(nextEligibleAtStr)?.toUtc()
            : null,
        schemaVersion: schemaVersion,
        createdAt: createdAtStr != null
            ? DateTime.tryParse(createdAtStr)?.toUtc() ?? DateTime.now().toUtc()
            : DateTime.now().toUtc(),
        updatedAt: updatedAtStr != null
            ? DateTime.tryParse(updatedAtStr)?.toUtc() ?? DateTime.now().toUtc()
            : DateTime.now().toUtc(),
        entityKey: entityKey,
        priority: OpPriority.fromString(priorityStr ?? 'normal'),
        deliveryState: _parseDeliveryState(deliveryStateStr),
      );
    } catch (_) {
      return PendingOp(
        id: '',
        opType: 'unknown',
        idempotencyKey: '',
        payload: const <String, dynamic>{},
        attempts: 0,
        status: 'pending',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
    }
  }
  
  static DeliveryState _parseDeliveryState(String? value) {
    switch (value?.toLowerCase()) {
      case 'sent':
        return DeliveryState.sent;
      case 'acknowledged':
        return DeliveryState.acknowledged;
      default:
        return DeliveryState.pending;
    }
  }

  @override
  void write(BinaryWriter writer, PendingOp obj) {
    writer
      ..writeByte(15) // 15 fields now (added priority and deliveryState)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.opType)
      ..writeByte(2)
      ..write(obj.idempotencyKey)
      ..writeByte(3)
      ..write(obj.payload)
      ..writeByte(4)
      ..write(obj.attempts)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.lastError)
      ..writeByte(7)
      ..write(obj.schemaVersion)
      ..writeByte(8)
      ..write(obj.createdAt.toUtc().toIso8601String())
      ..writeByte(9)
      ..write(obj.updatedAt.toUtc().toIso8601String())
      ..writeByte(10)
      ..write(obj.lastTriedAt?.toUtc().toIso8601String())
      ..writeByte(11)
      ..write(obj.nextEligibleAt?.toUtc().toIso8601String())
      ..writeByte(12)
      ..write(obj.entityKey)
      ..writeByte(13)
      ..write(obj.priority.name)
      ..writeByte(14)
      ..write(obj.deliveryState.name);
  }
}
