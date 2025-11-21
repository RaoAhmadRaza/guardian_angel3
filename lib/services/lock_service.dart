import 'dart:async';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'models/lock_record.dart';
import 'telemetry_service.dart';

/// LockService provides distributed locking with heartbeat monitoring.
/// 
/// Features:
/// - Unique runner IDs for multi-instance detection
/// - Heartbeat mechanism to detect stale locks
/// - Automatic takeover of expired locks
/// - Telemetry for lock contention and health
/// 
/// Usage:
/// ```dart
/// final lockService = LockService();
/// await lockService.init();
/// 
/// final acquired = await lockService.acquireLock('sync_service');
/// if (acquired) {
///   try {
///     // Start heartbeat monitoring
///     lockService.startHeartbeat('sync_service');
///     
///     // Do work...
///     
///   } finally {
///     lockService.stopHeartbeat('sync_service');
///     await lockService.releaseLock('sync_service');
///   }
/// }
/// ```
class LockService {
  static const String _boxName = 'distributed_locks';
  static const String _runnerIdBoxName = 'runner_metadata';
  
  /// How often to renew heartbeat while holding lock
  static const Duration heartbeatInterval = Duration(seconds: 1);
  
  /// How long before considering a lock stale (no heartbeat)
  static const Duration stalenessThreshold = Duration(seconds: 5);
  
  static final _uuid = Uuid();
  
  Box<LockRecord>? _lockBox;
  Box? _runnerBox;
  String? _runnerId;
  
  /// Active heartbeat timers per lock name
  final Map<String, Timer> _heartbeatTimers = {};

  /// Initialize lock service and generate/load runner ID
  Future<void> init() async {
    // Register adapter if not already registered
    if (!Hive.isAdapterRegistered(12)) {
      Hive.registerAdapter(LockRecordAdapter());
    }

    // Open boxes
    if (!Hive.isBoxOpen(_boxName)) {
      _lockBox = await Hive.openBox<LockRecord>(_boxName);
    } else {
      _lockBox = Hive.box<LockRecord>(_boxName);
    }

    if (!Hive.isBoxOpen(_runnerIdBoxName)) {
      _runnerBox = await Hive.openBox(_runnerIdBoxName);
    } else {
      _runnerBox = Hive.box(_runnerIdBoxName);
    }

    // Generate or load runner ID
    _runnerId = _runnerBox!.get('runnerId') as String?;
    if (_runnerId == null) {
      _runnerId = _generateRunnerId();
      await _runnerBox!.put('runnerId', _runnerId);
      await _runnerBox!.put('createdAt', DateTime.now().toIso8601String());
    }

    print('[LockService] Initialized with runner ID: $_runnerId');
  }

  /// Generate a unique runner ID with metadata
  String _generateRunnerId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final uuid = _uuid.v4().substring(0, 8);
    final processId = pid;
    return 'runner_${timestamp}_${uuid}_$processId';
  }

  /// Get current runner ID
  String get runnerId {
    if (_runnerId == null) {
      throw StateError('LockService not initialized');
    }
    return _runnerId!;
  }

  /// Attempt to acquire a lock. Returns true if acquired, false if held by another runner.
  Future<bool> acquireLock(String lockName, {Map<String, dynamic>? metadata}) async {
    if (_lockBox == null) await init();

    final existingLock = _lockBox!.get(lockName);

    // Case 1: No existing lock - acquire immediately
    if (existingLock == null) {
      final lock = LockRecord.acquire(
        lockName: lockName,
        runnerId: runnerId,
        metadata: metadata ?? _getDefaultMetadata(),
      );
      await _lockBox!.put(lockName, lock);

      TelemetryService.I.increment('lock.acquired');
      TelemetryService.I.gauge('lock.${lockName}.holder', runnerId.hashCode);
      
      print('[LockService] Acquired lock: $lockName');
      return true;
    }

    // Case 2: Lock held by current runner - already acquired
    if (existingLock.isOwnedBy(runnerId)) {
      print('[LockService] Lock $lockName already held by current runner');
      return true;
    }

    // Case 3: Lock held by another runner - check if stale
    if (existingLock.isStale(stalenessThreshold)) {
      // Stale lock detected - takeover
      final lock = LockRecord.acquire(
        lockName: lockName,
        runnerId: runnerId,
        metadata: metadata ?? _getDefaultMetadata(),
      );
      await _lockBox!.put(lockName, lock);

      TelemetryService.I.increment('lock.takeover_detected');
      TelemetryService.I.increment('lock.stale_detected');
      TelemetryService.I.gauge('lock.${lockName}.holder', runnerId.hashCode);

      print('[LockService] Took over stale lock: $lockName (previous: ${existingLock.runnerId}, stale for ${existingLock.timeSinceHeartbeat.inSeconds}s)');
      return true;
    }

    // Case 4: Lock held by active runner - cannot acquire
    TelemetryService.I.increment('lock.contention');
    print('[LockService] Lock $lockName held by ${existingLock.runnerId} (heartbeat ${existingLock.timeSinceHeartbeat.inSeconds}s ago)');
    return false;
  }

  /// Release a lock held by current runner
  Future<void> releaseLock(String lockName) async {
    if (_lockBox == null) await init();

    final existingLock = _lockBox!.get(lockName);

    if (existingLock == null) {
      print('[LockService] Lock $lockName already released');
      return;
    }

    if (!existingLock.isOwnedBy(runnerId)) {
      print('[LockService] Warning: Attempting to release lock $lockName not owned by current runner');
      TelemetryService.I.increment('lock.release_mismatch');
      return;
    }

    await _lockBox!.delete(lockName);
    TelemetryService.I.increment('lock.released');
    TelemetryService.I.gauge('lock.${lockName}.hold_duration_ms', existingLock.age.inMilliseconds);

    print('[LockService] Released lock: $lockName (held for ${existingLock.age.inSeconds}s, ${existingLock.renewalCount} renewals)');
  }

  /// Renew heartbeat for a lock (call periodically while holding lock)
  Future<bool> renewHeartbeat(String lockName) async {
    if (_lockBox == null) await init();

    final existingLock = _lockBox!.get(lockName);

    if (existingLock == null) {
      print('[LockService] Warning: Cannot renew heartbeat for non-existent lock: $lockName');
      return false;
    }

    if (!existingLock.isOwnedBy(runnerId)) {
      print('[LockService] Warning: Cannot renew heartbeat for lock $lockName not owned by current runner');
      return false;
    }

    existingLock.renewHeartbeat();
    await _lockBox!.put(lockName, existingLock);

    TelemetryService.I.increment('lock.heartbeat_renewed');

    return true;
  }

  /// Start automatic heartbeat renewal for a lock (call after acquiring)
  void startHeartbeat(String lockName) {
    // Stop any existing timer for this lock
    stopHeartbeat(lockName);

    _heartbeatTimers[lockName] = Timer.periodic(heartbeatInterval, (_) async {
      final success = await renewHeartbeat(lockName);
      if (!success) {
        // Heartbeat renewal failed - stop timer
        print('[LockService] Heartbeat renewal failed for $lockName, stopping heartbeat');
        stopHeartbeat(lockName);
        TelemetryService.I.increment('lock.heartbeat_failure');
      }
    });

    print('[LockService] Started heartbeat for lock: $lockName (interval: ${heartbeatInterval.inSeconds}s)');
  }

  /// Stop automatic heartbeat renewal for a lock
  void stopHeartbeat(String lockName) {
    final timer = _heartbeatTimers.remove(lockName);
    timer?.cancel();
  }

  /// Check if a lock is currently held by any runner
  bool isLockHeld(String lockName) {
    final lock = _lockBox?.get(lockName);
    if (lock == null) return false;
    return !lock.isStale(stalenessThreshold);
  }

  /// Check if a lock is held by the current runner
  bool isLockHeldByMe(String lockName) {
    final lock = _lockBox?.get(lockName);
    if (lock == null) return false;
    return lock.isOwnedBy(runnerId) && !lock.isStale(stalenessThreshold);
  }

  /// Get lock information for debugging
  LockRecord? getLockInfo(String lockName) {
    return _lockBox?.get(lockName);
  }

  /// List all active locks
  List<LockRecord> getAllLocks() {
    return _lockBox?.values.toList() ?? [];
  }

  /// Force release all locks held by current runner (use with caution)
  Future<void> releaseAllMyLocks() async {
    if (_lockBox == null) await init();

    final myLocks = _lockBox!.values.where((lock) => lock.isOwnedBy(runnerId)).toList();

    for (final lock in myLocks) {
      await releaseLock(lock.lockName);
      stopHeartbeat(lock.lockName);
    }

    print('[LockService] Released all ${myLocks.length} locks held by current runner');
  }

  /// Cleanup stale locks (manual trigger for maintenance)
  Future<int> cleanupStaleLocks() async {
    if (_lockBox == null) await init();

    int cleaned = 0;
    final locks = _lockBox!.values.toList();

    for (final lock in locks) {
      if (lock.isStale(stalenessThreshold)) {
        await _lockBox!.delete(lock.lockName);
        cleaned++;
        TelemetryService.I.increment('lock.stale_cleaned');
        print('[LockService] Cleaned stale lock: ${lock.lockName} (runner: ${lock.runnerId}, stale for ${lock.timeSinceHeartbeat.inSeconds}s)');
      }
    }

    if (cleaned > 0) {
      TelemetryService.I.gauge('lock.cleanup_count', cleaned);
    }

    return cleaned;
  }

  /// Get default metadata for this runner
  Map<String, dynamic> _getDefaultMetadata() {
    return {
      'pid': pid,
      'hostname': Platform.localHostname,
      'platform': Platform.operatingSystem,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Get lock statistics for monitoring
  Map<String, dynamic> getStats() {
    final locks = getAllLocks();
    final myLocks = locks.where((lock) => lock.isOwnedBy(runnerId)).toList();
    final staleLocks = locks.where((lock) => lock.isStale(stalenessThreshold)).toList();
    final activeLocks = locks.where((lock) => !lock.isStale(stalenessThreshold)).toList();

    return {
      'runnerId': runnerId,
      'totalLocks': locks.length,
      'myLocks': myLocks.length,
      'activeLocks': activeLocks.length,
      'staleLocks': staleLocks.length,
      'activeHeartbeats': _heartbeatTimers.length,
      'locks': locks.map((l) => {
        'name': l.lockName,
        'runner': l.runnerId,
        'age': l.age.inSeconds,
        'heartbeat': l.timeSinceHeartbeat.inSeconds,
        'renewals': l.renewalCount,
        'stale': l.isStale(stalenessThreshold),
      }).toList(),
    };
  }

  /// Dispose of lock service (stop all heartbeats)
  void dispose() {
    for (final timer in _heartbeatTimers.values) {
      timer.cancel();
    }
    _heartbeatTimers.clear();
  }
}
