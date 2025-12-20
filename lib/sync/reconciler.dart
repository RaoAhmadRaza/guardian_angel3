import 'api_client.dart';
import 'models/pending_op.dart';
import 'exceptions.dart';

/// Reconciler for handling conflict resolution (409)
/// 
/// Implements reconciliation strategies for merge conflicts:
/// - Fetch latest server state
/// - Merge local changes
/// - Re-queue operation or update local state
class Reconciler {
  final ApiClient api;

  Reconciler(this.api);

  /// Reconcile a conflict for a pending operation
  /// 
  /// Returns:
  /// - true if conflict resolved and operation can be retried
  /// - false if conflict cannot be resolved (operation should fail)
  Future<bool> reconcileConflict(PendingOp op, ConflictException conflict) async {
    print('[Reconciler] Attempting to reconcile conflict for ${op.opType}::${op.entityType}');
    
    try {
      // Strategy depends on operation type
      switch (op.opType.toUpperCase()) {
        case 'CREATE':
          return await _reconcileCreate(op, conflict);
        
        case 'UPDATE':
        case 'PATCH':
          return await _reconcileUpdate(op, conflict);
        
        case 'DELETE':
          return await _reconcileDelete(op, conflict);
        
        default:
          print('[Reconciler] Unknown operation type: ${op.opType}');
          return false;
      }
    } catch (e) {
      print('[Reconciler] Reconciliation failed: $e');
      return false;
    }
  }

  /// Reconcile CREATE conflict (likely duplicate)
  Future<bool> _reconcileCreate(PendingOp op, ConflictException conflict) async {
    // For CREATE conflicts, typically the resource already exists
    // Strategy: Check if server version matches intent, if so treat as success
    
    final id = op.payload['id'];
    if (id == null) {
      print('[Reconciler] CREATE conflict but no ID in payload');
      return false;
    }

    try {
      // Fetch existing resource
      final path = _buildResourcePath(op.entityType, id);
      final serverState = await api.request(method: 'GET', path: path);
      
      // Compare key fields to see if they match intent
      if (_resourceMatchesIntent(serverState, op.payload)) {
        print('[Reconciler] CREATE conflict resolved: resource already exists with matching state');
        return true; // Treat as success (idempotent create)
      }
      
      print('[Reconciler] CREATE conflict: resource exists but differs');
      return false;
    } on ResourceNotFoundException {
      // Resource doesn't exist anymore, can retry create
      print('[Reconciler] CREATE conflict resolved: resource no longer exists, retrying');
      return true;
    }
  }

  /// Reconcile UPDATE conflict (version mismatch)
  Future<bool> _reconcileUpdate(PendingOp op, ConflictException conflict) async {
    // For UPDATE conflicts, fetch latest version and merge changes
    
    final id = op.payload['id'];
    if (id == null) {
      print('[Reconciler] UPDATE conflict but no ID in payload');
      return false;
    }

    try {
      // Fetch latest server state
      final path = _buildResourcePath(op.entityType, id);
      final serverState = await api.request(method: 'GET', path: path);
      
      // Merge local changes onto server state
      final mergedPayload = _mergePayloads(serverState, op.payload);
      
      // Update operation payload with merged version
      op.payload = mergedPayload;
      op.payload['version'] = serverState['version']; // Update version
      
      print('[Reconciler] UPDATE conflict resolved: merged changes with server state');
      return true; // Can retry with merged payload
    } on ResourceNotFoundException {
      // Resource was deleted, UPDATE cannot proceed
      print('[Reconciler] UPDATE conflict: resource no longer exists');
      return false;
    }
  }

  /// Reconcile DELETE conflict
  Future<bool> _reconcileDelete(PendingOp op, ConflictException conflict) async {
    // For DELETE conflicts, check if resource still exists
    
    final id = op.payload['id'];
    if (id == null) {
      print('[Reconciler] DELETE conflict but no ID in payload');
      return false;
    }

    try {
      // Try to fetch the resource
      final path = _buildResourcePath(op.entityType, id);
      await api.request(method: 'GET', path: path);
      
      // Resource still exists, can retry delete
      print('[Reconciler] DELETE conflict resolved: resource still exists, retrying');
      return true;
    } on ResourceNotFoundException {
      // Resource already deleted, treat as success
      print('[Reconciler] DELETE conflict resolved: resource already deleted');
      return true; // Idempotent delete succeeded
    }
  }

  /// Build resource path from entity type and ID
  String _buildResourcePath(String entityType, String id) {
    final pluralType = _pluralize(entityType);
    return '/api/v1/$pluralType/$id';
  }

  /// Simple pluralization (extend as needed)
  String _pluralize(String entityType) {
    final lower = entityType.toLowerCase();
    if (lower.endsWith('y')) {
      return '${lower.substring(0, lower.length - 1)}ies';
    }
    return '${lower}s';
  }

  /// Check if server resource matches local intent
  bool _resourceMatchesIntent(Map<String, dynamic> serverState, Map<String, dynamic> localPayload) {
    // Compare key fields (app-specific logic)
    // For now, simple field-by-field comparison
    
    final keysToCheck = ['name', 'status', 'value', 'state'];
    
    for (final key in keysToCheck) {
      if (localPayload.containsKey(key) && serverState.containsKey(key)) {
        if (localPayload[key] != serverState[key]) {
          return false;
        }
      }
    }
    
    return true;
  }

  /// Merge local changes onto server state (3-way merge strategy)
  Map<String, dynamic> _mergePayloads(Map<String, dynamic> serverState, Map<String, dynamic> localPayload) {
    final merged = Map<String, dynamic>.from(serverState);
    
    // Apply local changes (local wins for conflicting fields)
    for (final key in localPayload.keys) {
      if (key != 'version' && key != 'updated_at' && key != 'created_at') {
        merged[key] = localPayload[key];
      }
    }
    
    return merged;
  }

  /// Get reconciliation strategy for conflict type
  String getStrategyForConflict(ConflictException conflict) {
    switch (conflict.conflictType) {
      case 'version_mismatch':
        return 'merge_and_retry';
      case 'duplicate':
        return 'check_and_treat_as_success';
      case 'constraint_violation':
        return 'fail_permanent';
      default:
        return 'unknown';
    }
  }
}
