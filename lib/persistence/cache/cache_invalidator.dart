/// CacheInvalidator - Explicit Cache Invalidation Strategy
///
/// Part of 10% CLIMB #2: Operational safety & consistency.
///
/// Provides a clear, explicit strategy for handling stale data:
/// - invalidateOnWrite(): Remove cached entity when it's written
/// - invalidateOnSync(): Clear cache for synced entities
/// - invalidateAll(): Full cache flush
///
/// USAGE:
/// ```dart
/// // Via provider (recommended)
/// final cache = ref.read(cacheInvalidatorProvider);
///
/// // On write
/// await vitalsBox.put(vitalId, newVital);
/// cache.invalidateOnWrite('vitals', vitalId);
///
/// // On sync complete
/// cache.invalidateOnSync('rooms', syncedRoomIds);
///
/// // On user logout
/// cache.invalidateAll();
/// ```
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/telemetry_service.dart';

/// Riverpod provider for CacheInvalidator
final cacheInvalidatorProvider = Provider<CacheInvalidator>((ref) {
  return CacheInvalidator();
});

/// Cache invalidation event for subscribers
class CacheInvalidationEvent {
  final String entityType;
  final String? entityId;
  final CacheInvalidationReason reason;
  final DateTime timestamp;

  CacheInvalidationEvent({
    required this.entityType,
    this.entityId,
    required this.reason,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().toUtc();

  bool get isFullInvalidation => entityId == null;

  Map<String, dynamic> toJson() => {
        'entity_type': entityType,
        'entity_id': entityId,
        'reason': reason.name,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Reason for cache invalidation
enum CacheInvalidationReason {
  /// Local write operation
  write,
  /// Sync from server
  sync,
  /// User-initiated refresh
  refresh,
  /// TTL expiration
  ttl,
  /// Full cache clear
  clear,
  /// Entity deletion
  delete,
}

/// Explicit cache invalidation strategy.
///
/// This class provides a centralized, explicit approach to cache invalidation.
/// All cache updates MUST go through this class to ensure consistency.
class CacheInvalidator {
  final TelemetryService? _telemetry;
  
  /// In-memory cache storage (entity type -> entity id -> cached value)
  final Map<String, Map<String, dynamic>> _cache = {};
  
  /// Stream controller for invalidation events
  final StreamController<CacheInvalidationEvent> _events = 
      StreamController<CacheInvalidationEvent>.broadcast();

  /// Invalidation event stream for UI/widget subscribers
  Stream<CacheInvalidationEvent> get events => _events.stream;

  CacheInvalidator({TelemetryService? telemetry}) : _telemetry = telemetry;

  // ═══════════════════════════════════════════════════════════════════════
  // CACHE OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════

  /// Get a cached value.
  T? get<T>(String entityType, String entityId) {
    final typeCache = _cache[entityType];
    if (typeCache == null) return null;
    
    final value = typeCache[entityId];
    if (value is T) {
      _telemetry?.increment('cache.hit.$entityType');
      return value;
    }
    
    _telemetry?.increment('cache.miss.$entityType');
    return null;
  }

  /// Put a value in cache.
  void put<T>(String entityType, String entityId, T value) {
    _cache.putIfAbsent(entityType, () => {});
    _cache[entityType]![entityId] = value;
    _telemetry?.increment('cache.put.$entityType');
  }

  /// Check if an entity is cached.
  bool has(String entityType, String entityId) {
    return _cache[entityType]?.containsKey(entityId) ?? false;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // INVALIDATION STRATEGIES
  // ═══════════════════════════════════════════════════════════════════════

  /// Invalidate a single entity when it's written.
  ///
  /// Call this AFTER writing to persistent storage to ensure
  /// the cache doesn't serve stale data.
  ///
  /// ```dart
  /// await vitalsBox.put(vitalId, newVital);
  /// cacheInvalidator.invalidateOnWrite('vitals', vitalId);
  /// ```
  void invalidateOnWrite(String entityType, String entityId) {
    _remove(entityType, entityId);
    _emitEvent(entityType, entityId, CacheInvalidationReason.write);
    _telemetry?.increment('cache.invalidate.write.$entityType');
  }

  /// Invalidate multiple entities after sync.
  ///
  /// Call this after a successful sync operation to invalidate
  /// all entities that were updated from the server.
  ///
  /// ```dart
  /// await syncService.syncRooms();
  /// cacheInvalidator.invalidateOnSync('rooms', syncedRoomIds);
  /// ```
  void invalidateOnSync(String entityType, List<String> entityIds) {
    for (final id in entityIds) {
      _remove(entityType, id);
      _emitEvent(entityType, id, CacheInvalidationReason.sync);
    }
    _telemetry?.increment('cache.invalidate.sync.$entityType', entityIds.length);
  }

  /// Invalidate an entity on deletion.
  ///
  /// ```dart
  /// await roomsBox.delete(roomId);
  /// cacheInvalidator.invalidateOnDelete('rooms', roomId);
  /// ```
  void invalidateOnDelete(String entityType, String entityId) {
    _remove(entityType, entityId);
    _emitEvent(entityType, entityId, CacheInvalidationReason.delete);
    _telemetry?.increment('cache.invalidate.delete.$entityType');
  }

  /// Invalidate all entities of a type.
  ///
  /// Call this when the entire collection may be stale.
  ///
  /// ```dart
  /// await fullSyncRooms();
  /// cacheInvalidator.invalidateType('rooms');
  /// ```
  void invalidateType(String entityType) {
    final removed = _cache[entityType]?.length ?? 0;
    _cache.remove(entityType);
    _emitEvent(entityType, null, CacheInvalidationReason.clear);
    _telemetry?.increment('cache.invalidate.type.$entityType', removed);
  }

  /// Invalidate ALL cached data.
  ///
  /// Call this on user logout or after major data changes.
  ///
  /// ```dart
  /// await authService.logout();
  /// cacheInvalidator.invalidateAll();
  /// ```
  void invalidateAll() {
    final totalRemoved = _cache.values.fold<int>(0, (sum, m) => sum + m.length);
    _cache.clear();
    _emitEvent('*', null, CacheInvalidationReason.clear);
    _telemetry?.increment('cache.invalidate.all', totalRemoved);
    print('[CacheInvalidator] Cleared all cache ($totalRemoved entries)');
  }

  /// User-initiated refresh invalidation.
  ///
  /// ```dart
  /// onPullToRefresh: () {
  ///   cacheInvalidator.invalidateOnRefresh('vitals');
  ///   await loadVitals();
  /// }
  /// ```
  void invalidateOnRefresh(String entityType) {
    final removed = _cache[entityType]?.length ?? 0;
    _cache.remove(entityType);
    _emitEvent(entityType, null, CacheInvalidationReason.refresh);
    _telemetry?.increment('cache.invalidate.refresh.$entityType', removed);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STATS & DEBUGGING
  // ═══════════════════════════════════════════════════════════════════════

  /// Get cache statistics.
  Map<String, dynamic> getStats() {
    final stats = <String, int>{};
    int total = 0;
    
    for (final entry in _cache.entries) {
      stats[entry.key] = entry.value.length;
      total += entry.value.length;
    }
    
    return {
      'total_entries': total,
      'entity_types': stats.length,
      'entries_by_type': stats,
    };
  }

  /// Get cache size estimate in bytes (rough approximation).
  int estimatedSizeBytes() {
    int size = 0;
    for (final typeCache in _cache.values) {
      for (final value in typeCache.values) {
        // Rough estimate: 100 bytes per entry average
        size += 100;
        if (value is String) {
          size += value.length * 2;
        } else if (value is Map) {
          size += value.length * 50;
        }
      }
    }
    return size;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // INTERNAL HELPERS
  // ═══════════════════════════════════════════════════════════════════════

  void _remove(String entityType, String entityId) {
    _cache[entityType]?.remove(entityId);
  }

  void _emitEvent(String entityType, String? entityId, CacheInvalidationReason reason) {
    _events.add(CacheInvalidationEvent(
      entityType: entityType,
      entityId: entityId,
      reason: reason,
    ));
  }

  /// Dispose the cache invalidator.
  void dispose() {
    _events.close();
    _cache.clear();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CACHE-AWARE REPOSITORY MIXIN
// ═══════════════════════════════════════════════════════════════════════════

/// Mixin for repositories that use caching.
///
/// Provides automatic cache invalidation on writes.
///
/// ```dart
/// class RoomRepository with CacheAwareRepository {
///   @override
///   CacheInvalidator get cacheInvalidator => _cacheInvalidator;
///   
///   @override
///   String get entityType => 'rooms';
///
///   Future<void> save(Room room) async {
///     await box.put(room.id, room.toModel());
///     invalidateCacheForEntity(room.id);
///   }
/// }
/// ```
mixin CacheAwareRepository {
  CacheInvalidator get cacheInvalidator;
  String get entityType;

  /// Call after any write operation.
  void invalidateCacheForEntity(String entityId) {
    cacheInvalidator.invalidateOnWrite(entityType, entityId);
  }

  /// Call after delete operation.
  void invalidateCacheForDelete(String entityId) {
    cacheInvalidator.invalidateOnDelete(entityType, entityId);
  }

  /// Call after sync operation.
  void invalidateCacheForSync(List<String> entityIds) {
    cacheInvalidator.invalidateOnSync(entityType, entityIds);
  }

  /// Get cached value or null.
  T? getCached<T>(String entityId) {
    return cacheInvalidator.get<T>(entityType, entityId);
  }

  /// Put value in cache.
  void putInCache<T>(String entityId, T value) {
    cacheInvalidator.put<T>(entityType, entityId, value);
  }
}
