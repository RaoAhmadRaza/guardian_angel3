import 'package:hive/hive.dart';

part 'lock_record.g.dart';

/// Record representing a distributed lock with heartbeat monitoring.
/// Stored in Hive to survive app restarts and enable multi-instance coordination.
@HiveType(typeId: 32)
class LockRecord {
  /// Unique name of the lock (e.g., 'sync_service', 'automation_sync')
  @HiveField(0)
  final String lockName;

  /// Unique runner ID that currently holds the lock
  @HiveField(1)
  final String runnerId;

  /// When the lock was initially acquired
  @HiveField(2)
  final DateTime acquiredAt;

  /// Last time the heartbeat was updated (proves runner is alive)
  @HiveField(3)
  DateTime lastHeartbeat;

  /// Optional metadata for debugging (device ID, process ID, etc.)
  @HiveField(4)
  final Map<String, dynamic>? metadata;

  /// Number of times this lock has been renewed
  @HiveField(5)
  int renewalCount;

  LockRecord({
    required this.lockName,
    required this.runnerId,
    required this.acquiredAt,
    required this.lastHeartbeat,
    this.metadata,
    this.renewalCount = 0,
  });

  /// Create a new lock record for a runner
  factory LockRecord.acquire({
    required String lockName,
    required String runnerId,
    Map<String, dynamic>? metadata,
  }) {
    final now = DateTime.now();
    return LockRecord(
      lockName: lockName,
      runnerId: runnerId,
      acquiredAt: now,
      lastHeartbeat: now,
      metadata: metadata,
      renewalCount: 0,
    );
  }

  /// Renew the heartbeat (call periodically while holding lock)
  void renewHeartbeat() {
    lastHeartbeat = DateTime.now();
    renewalCount++;
  }

  /// Check if this lock is stale (heartbeat expired)
  bool isStale(Duration stalenessThreshold) {
    final age = DateTime.now().difference(lastHeartbeat);
    return age > stalenessThreshold;
  }

  /// Check if this lock belongs to a specific runner
  bool isOwnedBy(String runnerId) {
    return this.runnerId == runnerId;
  }

  /// Get lock age (how long it's been held)
  Duration get age => DateTime.now().difference(acquiredAt);

  /// Get time since last heartbeat
  Duration get timeSinceHeartbeat => DateTime.now().difference(lastHeartbeat);

  @override
  String toString() {
    return 'LockRecord(name: $lockName, runner: $runnerId, '
        'age: ${age.inSeconds}s, lastHeartbeat: ${timeSinceHeartbeat.inSeconds}s ago, '
        'renewals: $renewalCount)';
  }

  /// Create a copy with updated fields
  LockRecord copyWith({
    String? lockName,
    String? runnerId,
    DateTime? acquiredAt,
    DateTime? lastHeartbeat,
    Map<String, dynamic>? metadata,
    int? renewalCount,
  }) {
    return LockRecord(
      lockName: lockName ?? this.lockName,
      runnerId: runnerId ?? this.runnerId,
      acquiredAt: acquiredAt ?? this.acquiredAt,
      lastHeartbeat: lastHeartbeat ?? this.lastHeartbeat,
      metadata: metadata ?? this.metadata,
      renewalCount: renewalCount ?? this.renewalCount,
    );
  }
}
