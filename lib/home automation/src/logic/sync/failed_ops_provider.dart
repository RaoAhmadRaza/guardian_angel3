import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../data/hive_adapters/pending_op_hive.dart';
import '../../data/local_hive_service.dart';

final failedOpsBoxProvider = Provider<Box<PendingOp>>((ref) => LocalHiveService.failedOpsBox());

/// Stream provider that emits the list of failed ops for UI display
final failedOpsListProvider = StreamProvider<List<PendingOp>>((ref) async* {
  final box = ref.watch(failedOpsBoxProvider);
  // initial
  List<PendingOp> snapshot() {
    final list = box.values.toList();
    list.sort((a, b) {
      final la = a.lastAttemptAt ?? a.queuedAt;
      final lb = b.lastAttemptAt ?? b.queuedAt;
      return lb.compareTo(la);
    });
    return list;
  }

  yield snapshot();
  yield* box.watch().map((_) => snapshot());
});

class FailedOpsController {
  final Ref ref;
  FailedOpsController(this.ref);

  /// Retry a failed op by moving it back to the pending queue and resetting attempts.
  Future<void> retry(String opId) async {
    final failed = ref.read(failedOpsBoxProvider);
    final pending = LocalHiveService.pendingOpsBox();
    final op = failed.get(opId);
    if (op == null) return;
    op.attempts = 0;
    op.lastAttemptAt = null;
    await failed.delete(opId);
    await pending.put(opId, op);
  }

  /// Remove a failed op permanently.
  Future<void> remove(String opId) async {
    final failed = ref.read(failedOpsBoxProvider);
    await failed.delete(opId);
  }
}

final failedOpsControllerProvider = Provider<FailedOpsController>((ref) => FailedOpsController(ref));
