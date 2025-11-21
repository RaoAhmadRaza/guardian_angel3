import 'package:hive/hive.dart';

/// Local fallback deduplication when backend doesn't support idempotency.
/// Tracks recently processed idempotency keys to prevent duplicate operations.
class LocalIdempotencyFallback {
  static const String _boxName = 'local_idempotency_fallback';
  static const Duration defaultTtl = Duration(hours: 24);
  
  Box? _box;
  
  /// Initialize the fallback store.
  Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox(_boxName);
    } else {
      _box = Hive.box(_boxName);
    }
  }

  /// Check if an idempotency key was recently processed.
  /// Returns true if the key exists (duplicate), false if new.
  Future<bool> isDuplicate(String idempotencyKey) async {
    if (_box == null) await init();
    final existingTimestamp = _box!.get(idempotencyKey) as int?;
    if (existingTimestamp == null) return false;
    
    // Check if entry is still within TTL
    final processedAt = DateTime.fromMillisecondsSinceEpoch(existingTimestamp);
    final age = DateTime.now().toUtc().difference(processedAt);
    if (age > defaultTtl) {
      // Expired - treat as new
      await _box!.delete(idempotencyKey);
      return false;
    }
    
    return true;
  }

  /// Mark an idempotency key as processed.
  Future<void> markProcessed(String idempotencyKey) async {
    if (_box == null) await init();
    await _box!.put(idempotencyKey, DateTime.now().toUtc().millisecondsSinceEpoch);
  }

  /// Remove expired entries (older than [customTtl] or [defaultTtl]).
  Future<int> purgeExpired({Duration? customTtl}) async {
    if (_box == null) await init();
    final ttl = customTtl ?? defaultTtl;
    final cutoff = DateTime.now().toUtc().subtract(ttl).millisecondsSinceEpoch;
    final expired = <String>[];
    
    for (final key in _box!.keys) {
      final timestamp = _box!.get(key) as int?;
      if (timestamp != null && timestamp < cutoff) {
        expired.add(key.toString());
      }
    }
    
    for (final key in expired) {
      await _box!.delete(key);
    }
    
    return expired.length;
  }

  /// Get count of tracked keys.
  int get count => _box?.length ?? 0;

  /// Clear all tracked keys (for testing).
  Future<void> clear() async {
    if (_box == null) await init();
    await _box!.clear();
  }
}
