import 'package:hive/hive.dart';

part 'pending_op_hive.g.dart';

/// Box name for queued operations
const kPendingOpsBoxName = 'pending_ops_box';

@HiveType(typeId: 2)
class PendingOp {
  @HiveField(0)
  final String opId; // unique id for the operation

  @HiveField(1)
  final String entityId; // roomId or deviceId

  @HiveField(2)
  final String entityType; // 'room' | 'device'

  @HiveField(3)
  final String opType; // 'create' | 'update' | 'delete' | 'toggle'

  @HiveField(4)
  final Map<String, dynamic> payload; // serialized model or minimal changes

  @HiveField(5)
  final DateTime queuedAt;

  @HiveField(6)
  int attempts; // increment on retry

  @HiveField(7)
  DateTime? lastAttemptAt; // timestamp of last attempt for backoff/observability

  PendingOp({
    required this.opId,
    required this.entityId,
    required this.entityType,
    required this.opType,
    required this.payload,
    DateTime? queuedAt,
    this.attempts = 0,
    this.lastAttemptAt,
  }) : queuedAt = queuedAt ?? DateTime.now();
}
