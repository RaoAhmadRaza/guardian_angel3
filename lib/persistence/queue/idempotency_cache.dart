/// Idempotency Cache
///
/// Lightweight cache to prevent duplicate operation enqueue.
/// Stores recent idempotency keys with timestamps for TTL-based cleanup.
library;

import 'package:hive/hive.dart';
import '../../services/telemetry_service.dart';

/// Box name for the idempotency cache.
const String idempotencyCacheBoxName = 'idempotency_cache';

/// Default TTL for idempotency keys (24 hours).
const Duration defaultIdempotencyTtl = Duration(hours: 24);

/// Idempotency cache to prevent duplicate operation enqueue.
///
/// Stores idempotency keys with timestamps. Keys older than TTL
/// are cleaned up periodically.
class IdempotencyCache {
  final Box<String> _cacheBox;
  final Duration ttl;

  IdempotencyCache._(this._cacheBox, {this.ttl = defaultIdempotencyTtl});

  /// Create or get the idempotency cache.
  static Future<IdempotencyCache> create({
    Duration ttl = defaultIdempotencyTtl,
  }) async {
    Box<String> box;
    if (Hive.isBoxOpen(idempotencyCacheBoxName)) {
      box = Hive.box<String>(idempotencyCacheBoxName);
    } else {
      box = await Hive.openBox<String>(idempotencyCacheBoxName);
    }
    return IdempotencyCache._(box, ttl: ttl);
  }

  /// Check if an idempotency key has been seen recently.
  ///
  /// Returns `true` if the key exists and is not expired.
  bool contains(String idempotencyKey) {
    final timestampStr = _cacheBox.get(idempotencyKey);
    if (timestampStr == null) return false;

    final timestamp = DateTime.tryParse(timestampStr);
    if (timestamp == null) {
      // Corrupt entry - remove it
      _cacheBox.delete(idempotencyKey);
      return false;
    }

    // Check if expired
    if (DateTime.now().toUtc().difference(timestamp) > ttl) {
      _cacheBox.delete(idempotencyKey);
      return false;
    }

    return true;
  }

  /// Record an idempotency key.
  ///
  /// Returns `true` if the key was new (not seen before).
  /// Returns `false` if the key already existed (duplicate).
  Future<bool> record(String idempotencyKey) async {
    if (contains(idempotencyKey)) {
      TelemetryService.I.increment('idempotency.duplicate_blocked');
      return false;
    }

    await _cacheBox.put(idempotencyKey, DateTime.now().toUtc().toIso8601String());
    TelemetryService.I.increment('idempotency.key_recorded');
    return true;
  }

  /// Check and record an idempotency key atomically.
  ///
  /// Returns `true` if the operation should proceed (key is new).
  /// Returns `false` if the operation should be skipped (duplicate).
  Future<bool> checkAndRecord(String idempotencyKey) async {
    return record(idempotencyKey);
  }

  /// Remove an idempotency key (e.g., if operation failed and should be retried).
  Future<void> remove(String idempotencyKey) async {
    await _cacheBox.delete(idempotencyKey);
  }

  /// Clean up expired entries.
  ///
  /// Call this periodically (e.g., on app start, every hour).
  Future<int> cleanup() async {
    final now = DateTime.now().toUtc();
    final keysToRemove = <String>[];

    for (final key in _cacheBox.keys.cast<String>()) {
      final timestampStr = _cacheBox.get(key);
      if (timestampStr == null) {
        keysToRemove.add(key);
        continue;
      }

      final timestamp = DateTime.tryParse(timestampStr);
      if (timestamp == null || now.difference(timestamp) > ttl) {
        keysToRemove.add(key);
      }
    }

    for (final key in keysToRemove) {
      await _cacheBox.delete(key);
    }

    if (keysToRemove.isNotEmpty) {
      TelemetryService.I.increment('idempotency.cleanup_count', keysToRemove.length);
    }

    return keysToRemove.length;
  }

  /// Get the number of cached keys.
  int get size => _cacheBox.length;

  /// Get all cached keys (for debugging).
  Iterable<String> get keys => _cacheBox.keys.cast<String>();

  /// Clear all cached keys.
  Future<void> clear() async {
    await _cacheBox.clear();
    TelemetryService.I.increment('idempotency.cache_cleared');
  }
}
