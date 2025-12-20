/// Canonical PendingOp Payload Contract
///
/// Single source of truth for pending operation payloads.
/// All modules MUST use this schema when enqueuing operations.
///
/// This ensures:
/// - Consistent structure across domains (automation, chat, vitals)
/// - Enforced validation at enqueue time
/// - Clear idempotency semantics
/// - Future sync compatibility
library;

import 'package:uuid/uuid.dart';

/// Domain categories for pending operations.
///
/// Each domain represents a logical subsystem of the app.
enum OpDomain {
  /// Home automation operations (rooms, devices, scenes)
  automation,

  /// Chat/messaging operations
  chat,

  /// Health vitals operations
  vitals,

  /// User profile operations
  profile,

  /// Settings operations
  settings,

  /// General/uncategorized operations
  general,
}

/// Action types for pending operations.
enum OpAction {
  /// Create a new resource
  create,

  /// Update an existing resource
  update,

  /// Delete a resource
  delete,

  /// Sync state (pull/push)
  sync,

  /// Custom action (requires action_name in data)
  custom,
}

/// Canonical payload structure for pending operations.
///
/// All operations MUST be enqueued using this structure to ensure
/// consistency and future sync compatibility.
class PendingOpPayload {
  /// Domain this operation belongs to.
  final OpDomain domain;

  /// Action type being performed.
  final OpAction action;

  /// Domain-specific data. Structure depends on domain + action.
  final Map<String, dynamic> data;

  /// Unique idempotency key to prevent duplicate processing.
  /// 
  /// MUST be non-empty. Should be generated using [generateIdempotencyKey].
  final String idempotencyKey;

  /// Optional resource ID being operated on.
  final String? resourceId;

  /// Optional resource type (e.g., 'room', 'device', 'vital').
  final String? resourceType;

  /// Timestamp when this payload was created.
  final DateTime createdAt;

  /// Client-side schema version for forward compatibility.
  final int schemaVersion;

  const PendingOpPayload({
    required this.domain,
    required this.action,
    required this.data,
    required this.idempotencyKey,
    this.resourceId,
    this.resourceType,
    required this.createdAt,
    this.schemaVersion = 1,
  });

  /// Create a new payload with a generated idempotency key.
  factory PendingOpPayload.create({
    required OpDomain domain,
    required OpAction action,
    required Map<String, dynamic> data,
    String? resourceId,
    String? resourceType,
  }) {
    return PendingOpPayload(
      domain: domain,
      action: action,
      data: data,
      idempotencyKey: generateIdempotencyKey(domain, action, resourceId),
      resourceId: resourceId,
      resourceType: resourceType,
      createdAt: DateTime.now().toUtc(),
    );
  }

  /// Validate this payload. Throws [ArgumentError] if invalid.
  void validate() {
    if (idempotencyKey.isEmpty) {
      throw ArgumentError('idempotencyKey cannot be empty');
    }
    if (idempotencyKey.length < 8) {
      throw ArgumentError('idempotencyKey must be at least 8 characters');
    }
    if (action == OpAction.custom && !data.containsKey('action_name')) {
      throw ArgumentError('Custom actions must include action_name in data');
    }
    if (action == OpAction.update && resourceId == null) {
      throw ArgumentError('Update actions must include resourceId');
    }
    if (action == OpAction.delete && resourceId == null) {
      throw ArgumentError('Delete actions must include resourceId');
    }
  }

  /// Check if this payload is valid without throwing.
  bool get isValid {
    try {
      validate();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Convert to the legacy payload format for PendingOp.
  Map<String, dynamic> toPayloadMap() => {
        'domain': domain.name,
        'action': action.name,
        'data': data,
        'idempotency_key': idempotencyKey,
        'resource_id': resourceId,
        'resource_type': resourceType,
        'created_at': createdAt.toUtc().toIso8601String(),
        'schema_version': schemaVersion,
      }..removeWhere((_, v) => v == null);

  /// Create from legacy payload map.
  factory PendingOpPayload.fromPayloadMap(Map<String, dynamic> map) {
    return PendingOpPayload(
      domain: OpDomain.values.firstWhere(
        (d) => d.name == map['domain'],
        orElse: () => OpDomain.general,
      ),
      action: OpAction.values.firstWhere(
        (a) => a.name == map['action'],
        orElse: () => OpAction.custom,
      ),
      data: (map['data'] as Map?)?.cast<String, dynamic>() ?? {},
      idempotencyKey: map['idempotency_key'] as String? ?? '',
      resourceId: map['resource_id'] as String?,
      resourceType: map['resource_type'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String).toUtc()
          : DateTime.now().toUtc(),
      schemaVersion: (map['schema_version'] as num?)?.toInt() ?? 1,
    );
  }

  /// Generate an opType string for PendingOp compatibility.
  String get opType => '${domain.name}.${action.name}';

  @override
  String toString() =>
      'PendingOpPayload($opType, key: ${idempotencyKey.substring(0, 8)}...)';
}

/// Generate a unique idempotency key.
///
/// Format: `{domain}_{action}_{resourceId?}_{uuid}`
String generateIdempotencyKey(
  OpDomain domain,
  OpAction action, [
  String? resourceId,
]) {
  final uuid = const Uuid().v4();
  final parts = [domain.name, action.name];
  if (resourceId != null) parts.add(resourceId);
  parts.add(uuid);
  return parts.join('_');
}

/// Extension methods for OpDomain.
extension OpDomainExtension on OpDomain {
  /// Human-readable display name.
  String get displayName {
    switch (this) {
      case OpDomain.automation:
        return 'Home Automation';
      case OpDomain.chat:
        return 'Chat';
      case OpDomain.vitals:
        return 'Vitals';
      case OpDomain.profile:
        return 'Profile';
      case OpDomain.settings:
        return 'Settings';
      case OpDomain.general:
        return 'General';
    }
  }
}
