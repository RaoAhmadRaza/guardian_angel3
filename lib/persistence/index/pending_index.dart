import 'package:hive/hive.dart';
import '../../models/pending_op.dart';
import '../box_registry.dart';
import '../wrappers/box_accessor.dart';
import '../../services/telemetry_service.dart';

/// FIFO index for pending operations backed by a lightweight index box that
/// stores an ordered list of maps {id, createdAt}. Maintains monotonic UTC
/// timestamps for deterministic processing order.
/// 
/// Note: Single-box writes are already atomic in Hive. This class only
/// manages the index box - callers coordinate multi-box atomicity via
/// [AtomicTransaction].
class PendingIndex {
  final Box _indexBox; // stores key 'order' -> List<Map>
  final Box<PendingOp> _pendingBox;

  PendingIndex._(this._indexBox, this._pendingBox);

  static Future<PendingIndex> create() async {
    final index = BoxAccess.I.boxUntyped(BoxRegistry.pendingIndexBox);
    final pending = BoxAccess.I.pendingOps();
    return PendingIndex._(index, pending);
  }

  List<Map<String, dynamic>> _currentIndex() {
    final raw = _indexBox.get('order', defaultValue: <Map<String, dynamic>>[]) as List;
    // Defensive copy
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Add an operation ID to the index.
  /// Note: Single-box write is atomic. Caller coordinates multi-box atomicity.
  Future<void> enqueue(String opId, DateTime createdAtUtc) async {
    final idx = _currentIndex();
    idx.add({'id': opId, 'createdAt': createdAtUtc.toUtc().toIso8601String()});
    idx.sort((a, b) => (a['createdAt'] as String).compareTo(b['createdAt'] as String));
    await _indexBox.put('order', idx);
  }

  /// Remove an operation ID from the index.
  /// Note: Single-box write is atomic. Caller coordinates multi-box atomicity.
  Future<void> remove(String opId) async {
    final idx = _currentIndex();
    idx.removeWhere((e) => e['id'] == opId);
    await _indexBox.put('order', idx);
  }

  /// Returns oldest N pending op IDs in FIFO order.
  Future<List<String>> getOldestIds(int limit) async {
    final idx = _currentIndex();
    return idx.take(limit).map((e) => e['id'] as String).toList();
  }

  /// Convenience: fetch PendingOp objects for oldest N.
  Future<List<PendingOp>> getOldest(int limit) async {
    final ids = await getOldestIds(limit);
    final list = <PendingOp>[];
    for (final id in ids) {
      final op = _pendingBox.get(id);
      if (op != null) list.add(op);
    }
    return list;
  }

  /// Integrity check ensures index matches actual box keys; rebuild if mismatch.
  Future<void> integrityCheckAndRebuild() async {
    final idx = _currentIndex();
    final keySet = _pendingBox.keys.map((e) => e.toString()).toSet();
    final idxSet = idx.map((e) => e['id'] as String).toSet();
    if (idxSet.length != keySet.length || !idxSet.containsAll(keySet)) {
      await rebuild();
    }
  }

  Future<void> rebuild() async {
    final sw = Stopwatch()..start();
    final list = <Map<String, dynamic>>[];
    for (final k in _pendingBox.keys) {
      final v = _pendingBox.get(k);
      if (v == null) continue;
      list.add({
        'id': k.toString(),
        'createdAt': v.createdAt.toUtc().toIso8601String(),
      });
    }
    list.sort((a, b) => (a['createdAt'] as String).compareTo(b['createdAt'] as String));
    await _indexBox.put('order', list);
    sw.stop();
    TelemetryService.I.time('index.rebuild.duration_ms', () => sw.elapsed);
  }
}
