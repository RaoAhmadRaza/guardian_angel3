import 'package:hive/hive.dart';
import '../box_registry.dart';
import '../wrappers/box_accessor.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// CANONICAL LOCK AUTHORITY FOR QUEUE PROCESSING
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// This is the ONLY lock implementation to use for PendingQueueService and
/// related queue/sync operations in the persistence layer.
/// 
/// DO NOT USE:
/// - lib/sync/processing_lock.dart (sync engine only, different concern)
/// - lib/services/lock_service.dart (deprecated for queue use)
/// 
/// Persistent processing lock backed by meta box to ensure only a single
/// queue processor instance runs. Detects stale lock after [staleThreshold].
/// 
/// The lock is stored in [BoxRegistry.metaBox] under key 'processing_lock'.
/// Stale locks are automatically recovered after [staleThreshold].
/// 
/// See also: docs/LOCK_PROTOCOL.md
/// ═══════════════════════════════════════════════════════════════════════════
class ProcessingLock {
  final Box _metaBox;
  final Duration staleThreshold;

  ProcessingLock._(this._metaBox, this.staleThreshold);

  static Future<ProcessingLock> create({Duration staleThreshold = const Duration(minutes: 2)}) async {
    final box = BoxAccess.I.meta();
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

  /// Get the current lock holder's PID, or null if not locked.
  String? get currentHolder {
    final current = _metaBox.get('processing_lock') as Map?;
    return current?['pid'] as String?;
  }

  /// Check if lock was recovered from a stale state.
  bool get wasStaleRecovered {
    final current = _metaBox.get('processing_lock') as Map?;
    return current?['staleRecovered'] == true;
  }

  /// Runtime assertion to detect dual-lock scenarios.
  /// 
  /// Call this during development/testing to ensure no other lock service
  /// is interfering with queue processing.
  /// 
  /// Throws [StateError] if LockService's distributed_locks box exists
  /// and has a 'sync_service' or 'queue_processing' lock active.
  static Future<void> assertNoDualLockActive() async {
    // Check if LockService boxes are being used for queue-like operations
    if (Hive.isBoxOpen('distributed_locks')) {
      final distLockBox = BoxAccess.I.boxUntyped('distributed_locks');
      final suspiciousKeys = ['sync_service', 'queue_processing', 'pending_ops'];
      for (final key in suspiciousKeys) {
        if (distLockBox.containsKey(key)) {
          throw StateError(
            'DUAL-LOCK DETECTED: LockService holds "$key" lock while '
            'ProcessingLock is the canonical authority for queue operations. '
            'See lib/persistence/locking/processing_lock.dart for guidance.',
          );
        }
      }
    }
  }
}
