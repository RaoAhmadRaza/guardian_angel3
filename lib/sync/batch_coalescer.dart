import 'package:hive/hive.dart';
import 'models/pending_op.dart';

/// Batch coalescer for merging redundant operations
/// 
/// Optimizes queue by:
/// - Coalescing multiple updates to same entity
/// - Batching compatible operations
/// - Removing superseded operations
class BatchCoalescer {
  final Box _pendingBox;
  final Box _indexBox;
  
  // Operation types that can be coalesced
  final Set<String> _coalescableOps = {'UPDATE', 'PATCH', 'TOGGLE'};
  
  BatchCoalescer(this._pendingBox, this._indexBox);

  /// Attempt to coalesce a new operation with existing queue
  /// 
  /// Returns:
  /// - null if operation should be added as-is
  /// - PendingOp if operation was coalesced with existing op
  Future<PendingOp?> tryCoalesce(PendingOp newOp) async {
    if (!_isCoalescable(newOp)) {
      return null;
    }

    // Find existing operations for same entity
    final existing = await _findExistingOpsForEntity(
      newOp.entityType,
      newOp.payload['id'] as String?,
    );

    if (existing.isEmpty) {
      return null;
    }

    // Find coalescable operation
    for (final existingOp in existing) {
      if (_canCoalesce(existingOp, newOp)) {
        // Merge operations
        final merged = await _merge(existingOp, newOp);
        
        // Update existing operation
        await _pendingBox.put(existingOp.id, merged.toMap());
        
        print('[BatchCoalescer] Coalesced ${newOp.opType}::${newOp.entityType} into ${existingOp.id}');
        return merged;
      }
    }

    return null;
  }

  /// Check if operation type can be coalesced
  bool _isCoalescable(PendingOp op) {
    return _coalescableOps.contains(op.opType.toUpperCase());
  }

  /// Check if two operations can be coalesced
  bool _canCoalesce(PendingOp existing, PendingOp newOp) {
    // Must be same operation type and entity type
    if (existing.opType != newOp.opType) return false;
    if (existing.entityType != newOp.entityType) return false;
    
    // Must target same entity instance
    final existingId = existing.payload['id'];
    final newId = newOp.payload['id'];
    
    if (existingId == null || newId == null) return false;
    if (existingId != newId) return false;
    
    // Must not be processing or failed
    if (existing.status != 'queued') return false;
    
    return true;
  }

  /// Merge two operations
  Future<PendingOp> _merge(PendingOp existing, PendingOp newOp) async {
    // Strategy: new operation's payload supersedes existing
    // But preserve metadata from existing operation
    
    final merged = PendingOp(
      id: existing.id, // Keep existing ID
      opType: existing.opType,
      entityType: existing.entityType,
      payload: _mergePayloads(existing.payload, newOp.payload),
      createdAt: existing.createdAt, // Keep original timestamp for FIFO
      idempotencyKey: existing.idempotencyKey, // Keep existing key
      attempts: existing.attempts,
      nextAttemptAt: existing.nextAttemptAt,
      txnToken: newOp.txnToken ?? existing.txnToken, // Use newer token if available
      status: existing.status,
      traceId: existing.traceId,
    );

    return merged;
  }

  /// Merge payloads (new values override existing)
  Map<String, dynamic> _mergePayloads(
    Map<String, dynamic> existing,
    Map<String, dynamic> newPayload,
  ) {
    final merged = Map<String, dynamic>.from(existing);
    
    // Apply new payload values
    for (final key in newPayload.keys) {
      merged[key] = newPayload[key];
    }
    
    return merged;
  }

  /// Find existing operations for same entity
  Future<List<PendingOp>> _findExistingOpsForEntity(
    String entityType,
    String? entityId,
  ) async {
    if (entityId == null) return [];

    final index = _indexBox.get('order', defaultValue: <dynamic>[]) as List;
    final ops = <PendingOp>[];

    for (final entry in index) {
      final opId = entry['id'] as String;
      final opMap = _pendingBox.get(opId) as Map<dynamic, dynamic>?;
      
      if (opMap == null) continue;
      
      final op = PendingOp.fromMap(opMap);
      
      // Check if same entity
      if (op.entityType == entityType && op.payload['id'] == entityId) {
        ops.add(op);
      }
    }

    return ops;
  }

  /// Remove superseded operations
  /// 
  /// Example: DELETE supersedes all pending UPDATEs for same entity
  Future<void> removeSuperseded(PendingOp op) async {
    if (op.opType.toUpperCase() != 'DELETE') return;

    final entityId = op.payload['id'] as String?;
    if (entityId == null) return;

    final existing = await _findExistingOpsForEntity(op.entityType, entityId);
    
    for (final existingOp in existing) {
      if (existingOp.id == op.id) continue; // Don't remove self
      
      if (['UPDATE', 'PATCH', 'CREATE'].contains(existingOp.opType.toUpperCase())) {
        // Remove superseded operation
        await _pendingBox.delete(existingOp.id);
        
        // Remove from index
        final index = _indexBox.get('order', defaultValue: <dynamic>[]) as List;
        index.removeWhere((entry) => entry['id'] == existingOp.id);
        await _indexBox.put('order', index);
        
        print('[BatchCoalescer] Removed superseded ${existingOp.opType}::${existingOp.entityType} (${existingOp.id})');
      }
    }
  }

  /// Create batch operation from multiple individual ops
  Future<PendingOp?> createBatch(List<PendingOp> ops) async {
    if (ops.isEmpty) return null;
    if (ops.length == 1) return ops.first;

    // All ops must be same type and entity type
    final opType = ops.first.opType;
    final entityType = ops.first.entityType;
    
    if (!ops.every((op) => op.opType == opType && op.entityType == entityType)) {
      return null;
    }

    // Create batch operation
    final batchOp = PendingOp(
      id: 'batch_${DateTime.now().millisecondsSinceEpoch}',
      opType: 'BATCH_$opType',
      entityType: entityType,
      payload: {
        'operations': ops.map((op) => op.payload).toList(),
        'batch_size': ops.length,
      },
      idempotencyKey: ops.first.idempotencyKey,
    );

    return batchOp;
  }
}
