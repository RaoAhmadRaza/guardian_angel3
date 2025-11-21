import 'dart:async';
import 'package:hive/hive.dart';
import '../../models/pending_op.dart';
import '../index/pending_index.dart';
import '../locking/processing_lock.dart';
import '../wrappers/hive_wrapper.dart';
import '../box_registry.dart';
import '../../services/telemetry_service.dart';

/// High-level queue service for pending operations providing atomic enqueue,
/// FIFO dequeue and processing under a persistent lock to prevent concurrent
/// runners. Intended for background sync.
class PendingQueueService {
  final PendingIndex _index;
  final Box<PendingOp> _pendingBox;
  final ProcessingLock _lock;

  PendingQueueService._(this._index, this._pendingBox, this._lock);

  static Future<PendingQueueService> create() async {
    final index = await PendingIndex.create();
    final lock = await ProcessingLock.create();
    final pendingBox = Hive.box<PendingOp>(BoxRegistry.pendingOpsBox);
    return PendingQueueService._(index, pendingBox, lock);
  }

  /// Enqueue a new operation with atomic index update.
  Future<void> enqueue(PendingOp op) async {
    await HiveWrapper.transactionalWrite(() async {
      await _pendingBox.put(op.id, op);
      await _index.enqueue(op.id, op.createdAt.toUtc());
    });
    TelemetryService.I.gauge('pending_ops.count', _pendingBox.length);
    TelemetryService.I.increment('enqueue.count');
  }

  /// Process up to [batchSize] oldest operations invoking [handler].
  /// Returns number processed.
  Future<int> process({required Future<void> Function(PendingOp op) handler, int batchSize = 10}) async {
    final pid = _generatePid();
    final acquired = await _lock.tryAcquire(pid);
    if (acquired == null) return 0; // another runner active
    int processed = 0;
    final sw = Stopwatch()..start();
    try {
      await _index.integrityCheckAndRebuild();
      final ops = await _index.getOldest(batchSize);
      for (final op in ops) {
        try {
          await handler(op);
          await HiveWrapper.transactionalWrite(() async {
            await _pendingBox.delete(op.id);
            await _index.remove(op.id);
          });
          processed++;
          TelemetryService.I.increment('processed_ops.count');
        } catch (e) {
          TelemetryService.I.increment('failed_ops.count');
          // leave op for retry; update attempts?
        }
      }
    } finally {
      await _lock.release(pid);
    }
    sw.stop();
    TelemetryService.I.gauge('pending_ops.count', _pendingBox.length);
    TelemetryService.I.time('process.duration_ms', () => sw.elapsed); // record duration
    return processed;
  }

  Future<void> rebuildIndex() => _index.rebuild();

  String _generatePid() => DateTime.now().microsecondsSinceEpoch.toString();
}