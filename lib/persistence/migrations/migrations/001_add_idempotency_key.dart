import 'package:hive/hive.dart';
import '../../../models/pending_op.dart';
import '../../box_registry.dart';

/// Example migration: ensure idempotencyKey exists for all pending ops
Future<void> migration001EnsureIdempotencyKey() async {
  final box = Hive.box<PendingOp>(BoxRegistry.pendingOpsBox);
  final entries = box.values.toList();
  for (final op in entries) {
    if (op.idempotencyKey.isEmpty) {
      final updated = PendingOp(
        id: op.id,
        opType: op.opType,
        idempotencyKey: op.id.isNotEmpty ? op.id : '${op.opType}-${op.createdAt.millisecondsSinceEpoch}',
        payload: op.payload,
        attempts: op.attempts,
        status: op.status,
        lastError: op.lastError,
        schemaVersion: op.schemaVersion,
        createdAt: op.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );
      await box.put(op.id, updated);
    }
  }
}
