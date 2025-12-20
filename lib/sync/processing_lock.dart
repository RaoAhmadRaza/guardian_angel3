import 'package:hive/hive.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// SYNC ENGINE LOCK - NOT FOR QUEUE PROCESSING
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// This lock implementation is specifically for the SyncEngine and admin
/// console operations. DO NOT use this for PendingQueueService.
/// 
/// For queue processing, use:
///   lib/persistence/locking/processing_lock.dart (canonical authority)
/// 
/// Processing Lock - Ensures single active processor
/// 
/// Implements persistent lock mechanism with heartbeat for crash recovery.
/// Follows the lock protocol from specs/sync/
/// ═══════════════════════════════════════════════════════════════════════════
class ProcessingLock {
  final Box _lockBox;
  final Duration lockTimeout;
  final Duration heartbeatInterval;

  ProcessingLock(
    this._lockBox, {
    this.lockTimeout = const Duration(minutes: 5),
    this.heartbeatInterval = const Duration(seconds: 30),
  });

  /// Try to acquire the processing lock
  /// 
  /// Returns true if lock acquired, false if another processor holds it
  Future<bool> tryAcquire(String runnerId) async {
    final now = DateTime.now().toUtc();
    final existing = _lockBox.get('lock') as Map<dynamic, dynamic>?;

    if (existing == null) {
      // No lock exists, acquire it
      await _writeLock(runnerId, now);
      return true;
    }

    final existingRunner = existing['runner_id'] as String;
    final lastHeartbeat = DateTime.parse(existing['last_heartbeat'] as String);

    // Check if lock is stale (no heartbeat within timeout)
    if (now.difference(lastHeartbeat) > lockTimeout) {
      // Stale lock, take over
      await _writeLock(runnerId, now);
      return true;
    }

    // Check if this is the same runner (re-acquisition)
    if (existingRunner == runnerId) {
      await _writeLock(runnerId, now);
      return true;
    }

    // Another active processor holds the lock
    return false;
  }

  /// Update heartbeat to keep lock alive
  Future<void> updateHeartbeat(String runnerId) async {
    final existing = _lockBox.get('lock') as Map<dynamic, dynamic>?;
    if (existing == null) return;

    final existingRunner = existing['runner_id'] as String;
    if (existingRunner != runnerId) return;

    await _writeLock(runnerId, DateTime.now().toUtc());
  }

  /// Release the processing lock
  Future<void> release(String runnerId) async {
    final existing = _lockBox.get('lock') as Map<dynamic, dynamic>?;
    if (existing == null) return;

    final existingRunner = existing['runner_id'] as String;
    if (existingRunner == runnerId) {
      await _lockBox.delete('lock');
    }
  }

  /// Write lock to storage
  Future<void> _writeLock(String runnerId, DateTime heartbeat) async {
    await _lockBox.put('lock', {
      'runner_id': runnerId,
      'last_heartbeat': heartbeat.toIso8601String(),
      'acquired_at': heartbeat.toIso8601String(),
    });
  }

  /// Check if lock is currently held
  Future<bool> isLocked() async {
    final existing = _lockBox.get('lock') as Map<dynamic, dynamic>?;
    if (existing == null) return false;

    final lastHeartbeat =
        DateTime.parse(existing['last_heartbeat'] as String);
    final now = DateTime.now().toUtc();

    return now.difference(lastHeartbeat) <= lockTimeout;
  }

  /// Get current lock holder (if any)
  Future<String?> getLockHolder() async {
    final existing = _lockBox.get('lock') as Map<dynamic, dynamic>?;
    if (existing == null) return null;

    final lastHeartbeat =
        DateTime.parse(existing['last_heartbeat'] as String);
    final now = DateTime.now().toUtc();

    if (now.difference(lastHeartbeat) > lockTimeout) {
      return null; // Stale lock
    }

    return existing['runner_id'] as String;
  }
}
