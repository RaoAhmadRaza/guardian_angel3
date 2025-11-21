import 'package:hive/hive.dart';
import '../box_registry.dart';

/// Persistent processing lock backed by meta box to ensure only a single
/// queue processor instance runs. Detects stale lock after [staleThreshold].
class ProcessingLock {
  final Box _metaBox;
  final Duration staleThreshold;

  ProcessingLock._(this._metaBox, this.staleThreshold);

  static Future<ProcessingLock> create({Duration staleThreshold = const Duration(minutes: 2)}) async {
    final box = Hive.box(BoxRegistry.metaBox);
    return ProcessingLock._(box, staleThreshold);
  }

  Future<String?> tryAcquire(String pid) async {
    final current = _metaBox.get('processing_lock') as Map?;
    final now = DateTime.now().toUtc();
    if (current == null) {
      await _metaBox.put('processing_lock', {
        'processing': true,
        'startedAt': now.toIso8601String(),
        'pid': pid,
      });
      return pid;
    } else {
      final started = DateTime.tryParse(current['startedAt'] as String? ?? '') ?? now;
      if (now.difference(started) > staleThreshold) {
        await _metaBox.put('processing_lock', {
          'processing': true,
          'startedAt': now.toIso8601String(),
          'pid': pid,
          'previousPid': current['pid'],
          'staleRecovered': true,
        });
        return pid;
      } else {
        return null; // active
      }
    }
  }

  Future<void> release(String pid) async {
    final current = _metaBox.get('processing_lock') as Map?;
    if (current != null && current['pid'] == pid) {
      await _metaBox.delete('processing_lock');
    }
  }

  Future<bool> isLocked() async => _metaBox.get('processing_lock') != null;
}
