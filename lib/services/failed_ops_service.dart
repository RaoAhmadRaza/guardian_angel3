import 'dart:convert';
import 'dart:math';
import 'package:hive/hive.dart';
import '../persistence/box_registry.dart';
import '../models/failed_op_model.dart';
import '../models/pending_op.dart';
import '../persistence/index/pending_index.dart';

class FailedOpsService {
  final BoxRegistry registry;
  final PendingIndex index;
  final int maxAttempts;
  final int maxBackoffSeconds;
  final int retentionDays;
  final Random _rng = Random();

  FailedOpsService({
    required this.registry,
    required this.index,
    this.maxAttempts = 5,
    this.maxBackoffSeconds = 300,
    this.retentionDays = 30,
  });

  Box<FailedOpModel> _failedBox() => Hive.box<FailedOpModel>(BoxRegistry.failedOpsBox);
  Box<PendingOp> _pendingBox() => Hive.box<PendingOp>(BoxRegistry.pendingOpsBox);

  Duration _computeBackoff(int attempts) {
    final base = min(pow(2, attempts).toInt(), maxBackoffSeconds);
    final jitterSpan = (base * 0.2).round();
    final jitter = _rng.nextInt(jitterSpan * 2 + 1) - jitterSpan; // +/- 20%
    return Duration(seconds: max(0, base + jitter));
  }

  Future<PendingOp> retryOp(String failedId) async {
    final box = _failedBox();
    final failed = box.get(failedId);
    if (failed == null) {
      throw ArgumentError('Failed op not found: $failedId');
    }
    if (failed.attempts >= maxAttempts) {
      throw StateError('Max attempts reached for $failedId');
    }
    // Backoff computed (could be used for scheduling); currently immediate re-enqueue.
    _computeBackoff(failed.attempts);
    return await _reenqueueInternal(failed, incrementAttempts: true);
  }

  Future<PendingOp> reenqueueOp(String failedId) async {
    final failed = _failedBox().get(failedId);
    if (failed == null) throw ArgumentError('Failed op not found: $failedId');
    return _reenqueueInternal(failed, incrementAttempts: false);
  }

  Future<PendingOp> _reenqueueInternal(FailedOpModel failed, {required bool incrementAttempts}) async {
    final now = DateTime.now().toUtc();
    // Determine idempotency key: prefer stored, else fallback from source pending op if present.
    String idem = failed.idempotencyKey ?? '';
    if (idem.isEmpty && failed.sourcePendingOpId != null && _pendingBox().containsKey(failed.sourcePendingOpId)) {
      final original = _pendingBox().get(failed.sourcePendingOpId!)!;
      idem = original.idempotencyKey;
    }
    if (idem.isEmpty) {
      idem = 'failed-${failed.id}';
    }
    final newId = 'retry_${failed.id}_${now.microsecondsSinceEpoch}';
    final pending = PendingOp(
      id: newId,
      opType: failed.opType,
      idempotencyKey: idem,
      payload: failed.payload,
      attempts: 0,
      status: 'pending',
      lastError: null,
      createdAt: now,
      updatedAt: now,
    );
    final pBox = _pendingBox();
    await pBox.put(pending.id, pending);
    await index.enqueue(pending.id, pending.createdAt); // maintain ordering
    if (incrementAttempts) {
      final updatedFailed = FailedOpModel(
        id: failed.id,
        sourcePendingOpId: failed.sourcePendingOpId,
        opType: failed.opType,
        payload: failed.payload,
        errorCode: failed.errorCode,
        errorMessage: failed.errorMessage,
        idempotencyKey: idem,
        attempts: failed.attempts + 1,
        archived: failed.archived,
        createdAt: failed.createdAt,
        updatedAt: now,
      );
      await _failedBox().put(failed.id, updatedFailed);
    }
    return pending;
  }

  Future<void> archiveOp(String failedId) async {
    final box = _failedBox();
    final failed = box.get(failedId);
    if (failed == null) return;
    if (failed.archived) return;
    final now = DateTime.now().toUtc();
    final updated = FailedOpModel(
      id: failed.id,
      sourcePendingOpId: failed.sourcePendingOpId,
      opType: failed.opType,
      payload: failed.payload,
      errorCode: failed.errorCode,
      errorMessage: failed.errorMessage,
      idempotencyKey: failed.idempotencyKey,
      attempts: failed.attempts,
      archived: true,
      createdAt: failed.createdAt,
      updatedAt: now,
    );
    await box.put(failed.id, updated);
  }

  /// Archive all failed ops older than the specified age (default: 30 days).
  /// Returns the count of archived operations.
  Future<int> archive({int? ageDays}) async {
    final box = _failedBox();
    final age = ageDays ?? retentionDays;
    final cutoff = DateTime.now().toUtc().subtract(Duration(days: age));
    int archived = 0;
    
    for (final f in box.values) {
      if (!f.archived && f.createdAt.isBefore(cutoff)) {
        await archiveOp(f.id);
        archived++;
      }
    }
    
    return archived;
  }

  Future<void> deleteOp(String failedId) async {
    final box = _failedBox();
    final failed = box.get(failedId);
    if (failed == null) return;
    if (!failed.archived) {
      await archiveOp(failedId);
    }
    await box.delete(failedId);
  }

  Future<String> exportFailedOps({bool? archived, String? errorCodeContains}) async {
    final box = _failedBox();
    final buffer = StringBuffer();
    for (final f in box.values) {
      if (archived != null && f.archived != archived) continue;
      if (errorCodeContains != null && (f.errorCode == null || !f.errorCode!.contains(errorCodeContains))) continue;
      buffer.writeln(jsonEncode(f.toJson()));
    }
    return buffer.toString();
  }

  Future<int> purgeExpired({int? retentionOverrideDays}) async {
    final box = _failedBox();
    final retention = retentionOverrideDays ?? retentionDays;
    final cutoff = DateTime.now().toUtc().subtract(Duration(days: retention));
    int purged = 0;
    final toDelete = <String>[];
    for (final f in box.values) {
      if (f.createdAt.isBefore(cutoff)) {
        // Archive first if not archived
        if (!f.archived) {
          await archiveOp(f.id);
        }
        toDelete.add(f.id);
      }
    }
    for (final id in toDelete) {
      await box.delete(id);
      purged++;
    }
    return purged;
  }
}