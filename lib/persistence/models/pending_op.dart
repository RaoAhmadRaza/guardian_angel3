/// Canonical PendingOp Model
///
/// THIS IS THE SINGLE SOURCE OF TRUTH FOR PENDING OPERATIONS.
/// 
/// ❌ DO NOT create alternative PendingOp models elsewhere.
/// ❌ DO NOT use the deprecated home automation pending_op_hive.dart.
/// 
/// All subsystems (home automation, sync, queue) MUST use this model.
/// TypeId: 11 (reserved in BoxRegistry.TypeIds.pendingOp)
/// Box: BoxRegistry.pendingOpsBox ('pending_ops_box')
///
/// Migration Note:
/// Home automation previously used a separate PendingOp with TypeId 2.
/// That model is now DEPRECATED. Use the compatibility factory methods
/// provided here for migration.
library;

import 'dart:convert';
import '../queue/op_priority.dart';

export '../queue/op_priority.dart' show OpPriority;

/// Delivery state for pending operations.
///
/// Tracks whether the operation has been acknowledged by the server.
/// Local backend only deletes ops on 'acknowledged' state.
enum DeliveryState {
  /// Operation is queued but not yet sent.
  pending,
  
  /// Operation has been sent to server but not acknowledged.
  sent,
  
  /// Server has acknowledged receipt with idempotency key confirmation.
  acknowledged,
}

/// Canonical pending operation model.
///
/// All pending operations across the entire app MUST use this class.
/// This ensures consistent TypeId, serialization, and queue behavior.
class PendingOp {
  /// Unique identifier for this operation.
  final String id;
  
  /// Type of operation (e.g., 'create', 'update', 'delete', 'toggle').
  final String opType;
  
  /// Idempotency key for server-side deduplication.
  final String idempotencyKey;
  
  /// Operation payload data.
  final Map<String, dynamic> payload;
  
  /// Number of processing attempts.
  final int attempts;
  
  /// Current status: 'pending', 'in_progress', 'retry', 'failed', 'completed'.
  final String status;
  
  /// Last error message if failed.
  final String? lastError;
  
  /// Timestamp of last processing attempt.
  final DateTime? lastTriedAt;
  
  /// Earliest time this op can be retried (for backoff).
  final DateTime? nextEligibleAt;
  
  /// Schema version for forward compatibility.
  final int schemaVersion;
  
  /// When this operation was created.
  final DateTime createdAt;
  
  /// When this operation was last updated.
  final DateTime updatedAt;
  
  /// Entity key for ordering guarantees.
  /// Format: "entity_type:entity_id" (e.g., "device:123", "room:abc")
  /// Operations on the same entity are processed in order.
  final String? entityKey;
  
  /// Priority level for this operation.
  /// Emergency ops bypass backoff and use fast lane.
  final OpPriority priority;
  
  /// Delivery state tracking.
  /// Ops only deleted when server acknowledges with idempotency key.
  final DeliveryState deliveryState;

  const PendingOp({
    required this.id,
    required this.opType,
    required this.idempotencyKey,
    required this.payload,
    this.attempts = 0,
    this.status = 'pending',
    this.lastError,
    this.lastTriedAt,
    this.nextEligibleAt,
    this.schemaVersion = 1,
    required this.createdAt,
    required this.updatedAt,
    this.entityKey,
    this.priority = OpPriority.normal,
    this.deliveryState = DeliveryState.pending,
  });

  PendingOp copyWith({
    int? attempts,
    String? status,
    String? lastError,
    DateTime? lastTriedAt,
    DateTime? nextEligibleAt,
    DateTime? updatedAt,
    String? entityKey,
    OpPriority? priority,
    DeliveryState? deliveryState,
  }) => PendingOp(
        id: id,
        opType: opType,
        idempotencyKey: idempotencyKey,
        payload: payload,
        attempts: attempts ?? this.attempts,
        status: status ?? this.status,
        lastError: lastError ?? this.lastError,
        lastTriedAt: lastTriedAt ?? this.lastTriedAt,
        nextEligibleAt: nextEligibleAt ?? this.nextEligibleAt,
        schemaVersion: schemaVersion,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        entityKey: entityKey ?? this.entityKey,
        priority: priority ?? this.priority,
        deliveryState: deliveryState ?? this.deliveryState,
      );

  /// Check if this op is eligible for processing now.
  /// Emergency ops bypass backoff entirely.
  bool get isEligibleNow {
    // Emergency ops always eligible (bypass backoff)
    if (priority == OpPriority.emergency) return true;
    
    if (nextEligibleAt == null) return true;
    return DateTime.now().toUtc().isAfter(nextEligibleAt!);
  }
  
  /// Derive entity key from payload if not explicitly set.
  /// Returns entityKey if set, otherwise constructs from payload.
  String? get effectiveEntityKey {
    if (entityKey != null) return entityKey;
    
    // Try to derive from payload
    final entityType = payload['entity_type'] as String?;
    final entityId = payload['entity_id'] as String?;
    
    if (entityType != null && entityId != null) {
      return '$entityType:$entityId';
    }
    
    return null;
  }

  factory PendingOp.fromJson(Map<String, dynamic> json) => PendingOp(
        id: json['id'] as String,
        opType: json['op_type'] as String,
        idempotencyKey: json['idempotency_key'] as String,
        payload: (json['payload'] as Map).cast<String, dynamic>(),
        attempts: (json['attempts'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? 'pending',
        lastError: json['last_error'] as String?,
        lastTriedAt: json['last_tried_at'] != null
            ? DateTime.parse(json['last_tried_at'] as String).toUtc()
            : null,
        nextEligibleAt: json['next_eligible_at'] != null
            ? DateTime.parse(json['next_eligible_at'] as String).toUtc()
            : null,
        schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 1,
        createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
        updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
        entityKey: json['entity_key'] as String?,
        priority: OpPriority.fromString(json['priority'] as String? ?? 'normal'),
        deliveryState: _parseDeliveryState(json['delivery_state'] as String?),
      );
  
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

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'schema_version': schemaVersion,
        'op_type': opType,
        'idempotency_key': idempotencyKey,
        'payload': payload,
        'attempts': attempts,
        'status': status,
        'last_error': lastError,
        'last_tried_at': lastTriedAt?.toUtc().toIso8601String(),
        'next_eligible_at': nextEligibleAt?.toUtc().toIso8601String(),
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'entity_key': entityKey,
        'priority': priority.name,
        'delivery_state': deliveryState.name,
      }..removeWhere((k, v) => v == null);

  @override
  String toString() => jsonEncode(toJson());
  
  // ═══════════════════════════════════════════════════════════════════════════
  // HOME AUTOMATION COMPATIBILITY
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Creates a PendingOp from the legacy home automation format.
  ///
  /// This factory method provides backward compatibility for code
  /// that was using the deprecated pending_op_hive.dart model.
  ///
  /// @deprecated Use standard constructor for new code.
  factory PendingOp.forHomeAutomation({
    required String opId,
    required String entityId,
    required String entityType,
    required String opType,
    required Map<String, dynamic> payload,
    DateTime? queuedAt,
    int attempts = 0,
    DateTime? lastAttemptAt,
  }) {
    final now = DateTime.now().toUtc();
    final created = queuedAt?.toUtc() ?? now;
    
    return PendingOp(
      id: opId,
      opType: opType,
      idempotencyKey: opId, // Use opId as idempotency key
      payload: {
        ...payload,
        'entity_type': entityType,
        'entity_id': entityId,
      },
      attempts: attempts,
      status: 'pending',
      lastTriedAt: lastAttemptAt?.toUtc(),
      createdAt: created,
      updatedAt: lastAttemptAt?.toUtc() ?? now,
      entityKey: '$entityType:$entityId',
      priority: OpPriority.normal,
      deliveryState: DeliveryState.pending,
    );
  }
  
  /// Gets the entity ID from a home automation operation.
  /// For backward compatibility with code expecting entityId.
  String? get entityId => payload['entity_id'] as String?;
  
  /// Gets the entity type from a home automation operation.
  /// For backward compatibility with code expecting entityType.
  String? get entityType => payload['entity_type'] as String?;
  
  /// Gets the queued timestamp (alias for createdAt).
  /// For backward compatibility with code expecting queuedAt.
  DateTime get queuedAt => createdAt;
  
  /// Gets the last attempt timestamp (alias for lastTriedAt).
  /// For backward compatibility with code expecting lastAttemptAt.
  DateTime? get lastAttemptAt => lastTriedAt;
  
  /// Gets the operation ID (alias for id).
  /// For backward compatibility with code expecting opId.
  String get opId => id;
}
