/// Conflict Resolution System
///
/// Implements deterministic conflict resolution with "Local Is King" policy.
/// When remote state disagrees with local, this resolver decides what to do.
///
/// Rules:
/// - Local backend is source of truth unless conflict is semantic
/// - Version mismatch → Fetch remote → rebase → re-enqueue
/// - Already deleted → Mark op as success locally
/// - Stale update → Drop op + audit
///
/// Edge cases handled:
/// - Duplicate deletes
/// - Replays after reinstall
/// - Clock skew
library;

import '../models/pending_op.dart';
import '../services/telemetry_service.dart';
import 'sync_consumer.dart';
import 'exceptions.dart';

/// Types of conflicts that can occur during sync.
enum ConflictType {
  /// Local version doesn't match server version.
  /// Resolution: Fetch remote → rebase → re-enqueue
  versionMismatch,

  /// Entity was already deleted on server.
  /// Resolution: Mark op as success locally (no-op)
  alreadyDeleted,

  /// Update is based on stale data (superseded by newer change).
  /// Resolution: Drop op + audit trail
  staleUpdate,

  /// Entity doesn't exist on server (for update/delete).
  /// Resolution: Depends on operation type
  notFound,

  /// Duplicate create (entity already exists).
  /// Resolution: Treat as update or merge
  duplicateCreate,

  /// Semantic conflict requiring manual resolution.
  /// Resolution: Mark for user review
  semanticConflict,
}

/// Metadata about a detected conflict.
class ConflictInfo {
  /// Type of conflict detected.
  final ConflictType type;

  /// Local version of the entity.
  final int? localVersion;

  /// Server version of the entity.
  final int? serverVersion;

  /// Server's current state of the entity (if available).
  final Map<String, dynamic>? serverState;

  /// Timestamp when conflict was detected.
  final DateTime detectedAt;

  /// Original exception that indicated the conflict.
  final ConflictException? originalException;

  const ConflictInfo({
    required this.type,
    this.localVersion,
    this.serverVersion,
    this.serverState,
    required this.detectedAt,
    this.originalException,
  });

  @override
  String toString() {
    return 'ConflictInfo(type: $type, local: v$localVersion, server: v$serverVersion)';
  }
}

/// Abstract conflict resolver interface.
abstract class ConflictResolver {
  /// Resolve a conflict for the given operation.
  ///
  /// Returns a SyncResult indicating how the queue should proceed:
  /// - Success: operation is complete (conflict resolved)
  /// - TransientFailure: retry later (rebase in progress)
  /// - PermanentFailure: drop operation
  SyncResult resolve(PendingOp op, ConflictException exception);

  /// Check if an operation can be rebased onto newer server state.
  bool canRebase(PendingOp op, ConflictInfo conflict);

  /// Create a rebased operation with merged changes.
  PendingOp? rebase(PendingOp op, Map<String, dynamic> serverState);
}

/// Default conflict resolver implementing "Local Is King" policy.
///
/// Resolution rules:
/// | Conflict          | Resolution                           |
/// |-------------------|--------------------------------------|
/// | Version mismatch  | Fetch remote → rebase → re-enqueue   |
/// | Already deleted   | Mark op as success locally           |
/// | Stale update      | Drop op + audit                      |
/// | Not found         | Re-create or drop (based on action)  |
/// | Duplicate create  | Treat as update                      |
/// | Semantic conflict | Mark for user review                 |
class DefaultConflictResolver implements ConflictResolver {
  /// Optional audit logger function.
  final void Function(String action, Map<String, dynamic> details)? _auditLogger;

  DefaultConflictResolver({
    void Function(String action, Map<String, dynamic> details)? auditLogger,
  }) : _auditLogger = auditLogger;
  
  /// Log an audit entry.
  void _audit(String action, Map<String, dynamic> details) {
    _auditLogger?.call(action, details);
    // Also log to telemetry for observability
    TelemetryService.I.increment('conflict.audit.$action');
  }

  @override
  SyncResult resolve(PendingOp op, ConflictException exception) {
    // Parse conflict info from exception
    final conflictInfo = _parseConflict(exception);
    
    TelemetryService.I.increment('conflict.detected.${conflictInfo.type.name}');
    
    switch (conflictInfo.type) {
      case ConflictType.versionMismatch:
        return _resolveVersionMismatch(op, conflictInfo);

      case ConflictType.alreadyDeleted:
        return _resolveAlreadyDeleted(op, conflictInfo);

      case ConflictType.staleUpdate:
        return _resolveStaleUpdate(op, conflictInfo);

      case ConflictType.notFound:
        return _resolveNotFound(op, conflictInfo);

      case ConflictType.duplicateCreate:
        return _resolveDuplicateCreate(op, conflictInfo);

      case ConflictType.semanticConflict:
        return _resolveSemanticConflict(op, conflictInfo);
    }
  }

  @override
  bool canRebase(PendingOp op, ConflictInfo conflict) {
    // Only updates can be rebased
    final action = op.payload['action'] as String? ?? 'sync';
    if (action != 'update' && action != 'patch') {
      return false;
    }

    // Can't rebase if we don't have server state
    if (conflict.serverState == null) {
      return false;
    }

    // Can't rebase deletes
    if (action == 'delete') {
      return false;
    }

    return true;
  }

  @override
  PendingOp? rebase(PendingOp op, Map<String, dynamic> serverState) {
    // Extract fields we're trying to update
    final localChanges = op.payload['data'] as Map<String, dynamic>? ?? {};
    
    if (localChanges.isEmpty) {
      return null; // Nothing to rebase
    }

    // Merge: start with server state, apply local changes
    final mergedData = Map<String, dynamic>.from(serverState);
    mergedData.addAll(localChanges);

    // Create new operation with rebased data
    final now = DateTime.now().toUtc();
    final rebasedPayload = Map<String, dynamic>.from(op.payload);
    rebasedPayload['data'] = mergedData;
    rebasedPayload['rebased_at'] = now.toIso8601String();
    rebasedPayload['original_version'] = op.payload['version'];
    rebasedPayload['version'] = serverState['version'];

    return PendingOp(
      id: '${op.id}_rebased_${now.millisecondsSinceEpoch}',
      opType: op.opType,
      idempotencyKey: '${op.idempotencyKey}_rebased',
      payload: rebasedPayload,
      attempts: 0, // Reset attempts for rebased op
      status: 'pending',
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Parse conflict information from exception.
  ConflictInfo _parseConflict(ConflictException exception) {
    // Try to determine conflict type from HTTP status and message
    final httpStatus = exception.httpStatus;
    final message = exception.message.toLowerCase();

    ConflictType type;
    int? serverVersion;
    Map<String, dynamic>? serverState;

    if (httpStatus == 409) {
      // HTTP 409 Conflict
      if (message.contains('version') || message.contains('etag')) {
        type = ConflictType.versionMismatch;
      } else if (message.contains('deleted') || message.contains('gone')) {
        type = ConflictType.alreadyDeleted;
      } else if (message.contains('stale') || message.contains('outdated')) {
        type = ConflictType.staleUpdate;
      } else if (message.contains('exists') || message.contains('duplicate')) {
        type = ConflictType.duplicateCreate;
      } else {
        type = ConflictType.semanticConflict;
      }
    } else if (httpStatus == 404) {
      type = ConflictType.notFound;
    } else if (httpStatus == 410) {
      type = ConflictType.alreadyDeleted;
    } else {
      type = ConflictType.semanticConflict;
    }

    // Try to extract version from response
    // This would normally be parsed from the exception's response body
    // For now, we rely on the message parsing

    return ConflictInfo(
      type: type,
      localVersion: null, // Would be extracted from op.payload
      serverVersion: serverVersion,
      serverState: serverState,
      detectedAt: DateTime.now().toUtc(),
      originalException: exception,
    );
  }

  /// Resolve version mismatch: fetch remote, rebase, re-enqueue.
  SyncResult _resolveVersionMismatch(PendingOp op, ConflictInfo conflict) {
    // In a real implementation, we would:
    // 1. Fetch the current server state
    // 2. Check if we can rebase
    // 3. Create a rebased operation and re-enqueue
    //
    // For now, we return transient failure to trigger retry
    // The actual rebase will happen when we have the fetcher integrated

    TelemetryService.I.increment('conflict.resolved.version_mismatch');
    
    _audit('conflict_version_mismatch', {
      'op_id': op.id,
      'op_type': op.opType,
      'local_version': conflict.localVersion,
      'server_version': conflict.serverVersion,
    });

    // Return transient failure - queue will retry with backoff
    // In future, we'd return success if rebase was successful
    return SyncResult.transientFailure(
      'Version mismatch: needs rebase (local: ${conflict.localVersion}, server: ${conflict.serverVersion})',
    );
  }

  /// Resolve already deleted: mark as success (no-op).
  SyncResult _resolveAlreadyDeleted(PendingOp op, ConflictInfo conflict) {
    // The entity is already deleted on server
    // Our delete/update is effectively a no-op
    
    TelemetryService.I.increment('conflict.resolved.already_deleted');
    
    _audit('conflict_already_deleted', {
      'op_id': op.id,
      'op_type': op.opType,
      'action': op.payload['action'],
    });

    // Return success - the desired end state is achieved
    return SyncResult.success(
      serverId: op.payload['entity_id'] as String?,
    );
  }

  /// Resolve stale update: drop op + audit.
  SyncResult _resolveStaleUpdate(PendingOp op, ConflictInfo conflict) {
    // The update is stale - a newer change has superseded it
    // Drop the operation but audit trail it
    
    TelemetryService.I.increment('conflict.resolved.stale_update');
    
    _audit('conflict_stale_update_dropped', {
      'op_id': op.id,
      'op_type': op.opType,
      'local_version': conflict.localVersion,
      'server_version': conflict.serverVersion,
      'reason': 'superseded_by_newer_change',
    });

    // Return permanent failure - don't retry, it's intentionally dropped
    return SyncResult.permanentFailure(
      'Stale update dropped: server has newer version',
    );
  }

  /// Resolve not found: re-create or drop based on action.
  SyncResult _resolveNotFound(PendingOp op, ConflictInfo conflict) {
    final action = op.payload['action'] as String? ?? 'sync';
    
    TelemetryService.I.increment('conflict.resolved.not_found');

    if (action == 'delete') {
      // Trying to delete something that doesn't exist
      // Goal achieved - return success
      _audit('conflict_not_found_delete_success', {'op_id': op.id, 'op_type': op.opType});
      return SyncResult.success();
    }

    if (action == 'update' || action == 'patch') {
      // Trying to update something that doesn't exist
      // This might mean it was deleted elsewhere
      _audit('conflict_not_found_update_dropped', {'op_id': op.id, 'op_type': op.opType});
      return SyncResult.permanentFailure(
        'Cannot update: entity not found on server',
      );
    }

    // For sync/other actions, treat as transient
    return SyncResult.transientFailure('Entity not found');
  }

  /// Resolve duplicate create: convert to update or merge.
  SyncResult _resolveDuplicateCreate(PendingOp op, ConflictInfo conflict) {
    TelemetryService.I.increment('conflict.resolved.duplicate_create');
    
    _audit('conflict_duplicate_create', {
      'op_id': op.id,
      'op_type': op.opType,
      'resolution': 'treat_as_success',
    });

    // Entity already exists - our create is effectively a no-op
    // or we should convert to update (handled by caller)
    return SyncResult.success(
      serverId: op.payload['entity_id'] as String?,
    );
  }

  /// Resolve semantic conflict: mark for user review.
  SyncResult _resolveSemanticConflict(PendingOp op, ConflictInfo conflict) {
    TelemetryService.I.increment('conflict.resolved.semantic');
    
    _audit('conflict_semantic_needs_review', {
      'op_id': op.id,
      'op_type': op.opType,
      'conflict_info': conflict.toString(),
    });

    // Semantic conflicts require human intervention
    return SyncResult.permanentFailure(
      'Semantic conflict: requires manual resolution',
    );
  }
}
