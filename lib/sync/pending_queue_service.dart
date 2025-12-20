import 'package:hive/hive.dart';
import 'models/pending_op.dart';
import 'models/failed_op.dart';

/// Pending Queue Service - Manages FIFO operation queue
/// 
/// Provides atomic operations for enqueueing, processing, and failing operations.
/// Maintains a sorted index for FIFO ordering.
class PendingQueueService {
  final Box _pendingBox; // Stores PendingOp data
  final Box _indexBox; // Stores ordered index
  final Box _failedBox; // Stores FailedOp data

  PendingQueueService(this._pendingBox, this._indexBox, this._failedBox);

  /// Enqueue a new operation (atomic: op + index)
  Future<void> enqueue(PendingOp op) async {
    // Write operation to storage
    await _pendingBox.put(op.id, op.toMap());

    // Update index atomically
    final idx = await _getIndex();
    idx.add({
      'id': op.id,
      'created_at': op.createdAt.toUtc().toIso8601String(),
    });
    idx.sort((a, b) => a['created_at'].compareTo(b['created_at']));
    await _indexBox.put('order', idx);
  }

  /// Get the oldest pending operation (FIFO)
  Future<PendingOp?> getOldest() async {
    final idx = await _getIndex();
    if (idx.isEmpty) return null;

    final first = idx.first;
    final id = first['id'] as String;
    final raw = _pendingBox.get(id) as Map<dynamic, dynamic>?;

    if (raw == null) {
      // Inconsistent state: rebuild index
      await rebuildIndex();
      return getOldest();
    }

    return PendingOp.fromMap(raw);
  }

  /// Get pending operation by ID
  Future<PendingOp?> getById(String id) async {
    final raw = _pendingBox.get(id) as Map<dynamic, dynamic>?;
    if (raw == null) return null;
    return PendingOp.fromMap(raw);
  }

  /// Update existing operation (e.g., after retry)
  Future<void> update(PendingOp op) async {
    await _pendingBox.put(op.id, op.toMap());
  }

  /// Mark operation as successfully processed
  /// 
  /// Removes from pending queue and index
  Future<void> markProcessed(String id) async {
    await _pendingBox.delete(id);

    final idx = await _getIndex();
    idx.removeWhere((m) => m['id'] == id);
    await _indexBox.put('order', idx);
  }

  /// Mark operation as failed
  /// 
  /// Moves to failed_ops queue and removes from pending
  Future<void> markFailed(
    String id,
    Map<String, dynamic> errorPayload, {
    int attempts = 0,
  }) async {
    final raw = _pendingBox.get(id) as Map<dynamic, dynamic>?;
    if (raw == null) return;

    final failed = FailedOp(
      id: id,
      operation: Map<String, dynamic>.from(raw),
      error: errorPayload,
      attempts: attempts,
    );

    await _failedBox.put(id, failed.toMap());
    await markProcessed(id);
  }

  /// Get all pending operations (for debugging)
  Future<List<PendingOp>> getAll() async {
    final idx = await _getIndex();
    final ops = <PendingOp>[];

    for (final entry in idx) {
      final id = entry['id'] as String;
      final raw = _pendingBox.get(id) as Map<dynamic, dynamic>?;
      if (raw != null) {
        ops.add(PendingOp.fromMap(raw));
      }
    }

    return ops;
  }

  /// Get count of pending operations
  Future<int> count() async {
    final idx = await _getIndex();
    return idx.length;
  }

  /// Rebuild index from scratch (recovery)
  Future<void> rebuildIndex() async {
    final keys = _pendingBox.keys;
    final list = <Map<String, dynamic>>[];

    for (final k in keys) {
      final raw = _pendingBox.get(k) as Map<dynamic, dynamic>?;
      if (raw == null) continue;

      final created = raw['created_at'] as String;
      list.add({'id': k, 'created_at': created});
    }

    list.sort((a, b) => a['created_at'].compareTo(b['created_at']));
    await _indexBox.put('order', list);
  }

  /// Get index (private helper)
  Future<List<Map<String, dynamic>>> _getIndex() async {
    final raw = _indexBox.get('order') as List<dynamic>?;
    if (raw == null) return [];

    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Clear all pending operations (for testing)
  Future<void> clearAll() async {
    await _pendingBox.clear();
    await _indexBox.clear();
  }
}
