/// Sync-layer PendingOp model for the sync engine.
///
/// This model is used by the sync layer for queue processing.
/// It contains sync-specific fields like traceId, txnToken, entityType.
///
/// Note: The persistence layer uses a different canonical model at
/// `lib/persistence/models/pending_op.dart` with slightly different fields.
/// This is intentional - different layers have different concerns.
library;

/// Represents a pending operation waiting to be synced.
///
/// Used by SyncEngine, BatchCoalescer, PendingQueueService.
class PendingOp {
  /// Unique identifier for this operation.
  final String id;
  
  /// Type of operation: CREATE, UPDATE, DELETE, TOGGLE, etc.
  final String opType;
  
  /// Entity type being operated on: device, room, vitals, etc.
  final String entityType;
  
  /// Operation payload data (mutable for merge operations).
  Map<String, dynamic> payload;
  
  /// When this operation was created (UTC).
  final DateTime createdAt;
  
  /// When this operation was last updated (UTC).
  DateTime updatedAt;
  
  /// Number of processing attempts.
  int attempts;
  
  /// Current status: queued, processing, completed, failed.
  String status;
  
  /// Last error message if processing failed.
  String? lastError;
  
  /// When the operation was last attempted (UTC).
  DateTime? lastTriedAt;
  
  /// Earliest time this operation can be retried (for backoff).
  DateTime? nextAttemptAt;
  
  /// Idempotency key for server-side deduplication (mutable for generation).
  String idempotencyKey;
  
  /// Trace ID for distributed tracing/correlation.
  String? traceId;
  
  /// Transaction token for optimistic UI rollback.
  String? txnToken;

  PendingOp({
    required this.id,
    required this.opType,
    required this.entityType,
    required this.payload,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.attempts = 0,
    this.status = 'queued',
    this.lastError,
    this.lastTriedAt,
    this.nextAttemptAt,
    String? idempotencyKey,
    this.traceId,
    this.txnToken,
  })  : createdAt = createdAt ?? DateTime.now().toUtc(),
        updatedAt = updatedAt ?? DateTime.now().toUtc(),
        idempotencyKey = idempotencyKey ?? '${DateTime.now().millisecondsSinceEpoch}_$id';

  /// Create from stored map.
  factory PendingOp.fromMap(Map<dynamic, dynamic> m) {
    return PendingOp(
      id: m['id'] as String,
      opType: m['op_type'] as String,
      entityType: m['entity_type'] as String,
      payload: Map<String, dynamic>.from(m['payload'] as Map),
      createdAt: DateTime.parse(m['created_at'] as String),
      updatedAt: DateTime.parse(m['updated_at'] as String),
      attempts: m['attempts'] as int? ?? 0,
      status: m['status'] as String? ?? 'queued',
      lastError: m['last_error'] as String?,
      lastTriedAt: m['last_tried_at'] == null
          ? null
          : DateTime.parse(m['last_tried_at'] as String),
      nextAttemptAt: m['next_attempt_at'] == null
          ? null
          : DateTime.parse(m['next_attempt_at'] as String),
      idempotencyKey: m['idempotency_key'] as String,
      traceId: m['trace_id'] as String?,
      txnToken: m['txn_token'] as String?,
    );
  }

  /// Convert to map for Hive storage.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'op_type': opType,
      'entity_type': entityType,
      'payload': payload,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'attempts': attempts,
      'status': status,
      'last_error': lastError,
      'last_tried_at': lastTriedAt?.toUtc().toIso8601String(),
      'next_attempt_at': nextAttemptAt?.toUtc().toIso8601String(),
      'idempotency_key': idempotencyKey,
      'trace_id': traceId,
      'txn_token': txnToken,
    };
  }

  /// Create a copy with updated fields.
  PendingOp copyWith({
    int? attempts,
    String? status,
    String? lastError,
    DateTime? lastTriedAt,
    DateTime? nextAttemptAt,
    DateTime? updatedAt,
    String? traceId,
    String? txnToken,
    Map<String, dynamic>? payload,
    String? idempotencyKey,
  }) {
    return PendingOp(
      id: id,
      opType: opType,
      entityType: entityType,
      payload: payload ?? this.payload,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      attempts: attempts ?? this.attempts,
      status: status ?? this.status,
      lastError: lastError ?? this.lastError,
      lastTriedAt: lastTriedAt ?? this.lastTriedAt,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      traceId: traceId ?? this.traceId,
      txnToken: txnToken ?? this.txnToken,
    );
  }

  @override
  String toString() {
    return 'PendingOp(id: $id, opType: $opType, entityType: $entityType, status: $status)';
  }
}
