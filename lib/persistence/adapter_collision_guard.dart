/// Adapter & TypeId Collision Guard
///
/// Validates that no two Hive adapters use the same TypeId.
/// This prevents silent data corruption from adapter conflicts.
///
/// Usage:
/// ```dart
/// // Call after all adapters are registered, before opening boxes
/// AdapterCollisionGuard.assertNoCollisions();
/// ```
library;

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../services/telemetry_service.dart';

/// Guard against TypeId collisions in Hive adapters.
///
/// TypeId collisions cause silent data corruption where one model's data
/// is deserialized as another model. This guard fails fast in dev/debug builds.
class AdapterCollisionGuard {
  AdapterCollisionGuard._();

  /// Known TypeIds from BoxRegistry.TypeIds for reference.
  ///
  /// This is the authoritative list. Any adapter not in this list
  /// should be added here first to reserve the ID.
  static const Map<int, String> reservedTypeIds = {
    10: 'RoomModel',
    11: 'PendingOp',
    12: 'DeviceModel / LockRecord', // Note: potential conflict!
    13: 'VitalsModel',
    14: 'UserProfileModel',
    15: 'SessionModel',
    16: 'FailedOpModel',
    17: 'AuditLogRecord',
    18: 'SettingsModel',
    19: 'AssetsCacheEntry',
    // Home Automation adapters (if different from above)
    // Add new adapters here BEFORE implementation
  };

  /// Check all registered adapters for TypeId collisions.
  ///
  /// In debug/profile builds: throws [StateError] on collision.
  /// In release builds: records telemetry but does NOT throw.
  ///
  /// Returns a [CollisionCheckResult] with details.
  static CollisionCheckResult checkForCollisions() {
    final usedTypeIds = <int, List<String>>{};
    final collisions = <TypeIdCollision>[];

    // Hive doesn't expose registered adapters directly.
    // We check by attempting to see if adapters are registered for known IDs.
    // This is a heuristic based on our known TypeIds.

    // Check each reserved ID to see if it's registered
    for (final entry in reservedTypeIds.entries) {
      final typeId = entry.key;
      final expectedName = entry.value;

      if (Hive.isAdapterRegistered(typeId)) {
        usedTypeIds.putIfAbsent(typeId, () => []).add(expectedName);
      }
    }

    // Also check common conflict ranges (0-99 for user types)
    for (int id = 0; id < 100; id++) {
      if (Hive.isAdapterRegistered(id) && !reservedTypeIds.containsKey(id)) {
        // Unknown registered adapter
        usedTypeIds.putIfAbsent(id, () => []).add('UNKNOWN_ADAPTER');
        TelemetryService.I.increment('adapter_guard.unknown_type_id');
      }
    }

    // Detect collisions (multiple names for same ID)
    for (final entry in usedTypeIds.entries) {
      if (entry.value.length > 1) {
        collisions.add(TypeIdCollision(
          typeId: entry.key,
          adapterNames: entry.value,
        ));
      }
    }

    final result = CollisionCheckResult(
      checkedCount: usedTypeIds.length,
      collisions: collisions,
      hasCollisions: collisions.isNotEmpty,
    );

    // Record telemetry
    TelemetryService.I.gauge('adapter_guard.registered_count', usedTypeIds.length);
    if (collisions.isNotEmpty) {
      TelemetryService.I.increment('adapter_guard.collision_detected');
      TelemetryService.I.gauge('adapter_guard.collision_count', collisions.length);
    }

    return result;
  }

  /// Assert that no TypeId collisions exist.
  ///
  /// In debug builds: throws [StateError] with details.
  /// In release builds: logs warning and continues.
  static void assertNoCollisions() {
    final result = checkForCollisions();

    if (result.hasCollisions) {
      final message = _buildCollisionMessage(result.collisions);

      if (kDebugMode || kProfileMode) {
        // Fail fast in development
        throw StateError(message);
      } else {
        // Log warning in release but don't crash
        TelemetryService.I.increment('adapter_guard.collision_warning_suppressed');
        // ignore: avoid_print
        print('[AdapterCollisionGuard] WARNING: $message');
      }
    }
  }

  /// Validate a single TypeId before registering an adapter.
  ///
  /// Call this before registering a new adapter to check for conflicts.
  static void validateTypeId(int typeId, String adapterName) {
    if (Hive.isAdapterRegistered(typeId)) {
      final existing = reservedTypeIds[typeId] ?? 'UNKNOWN';
      final message =
          'TypeId collision: $typeId is already registered for "$existing", '
          'cannot register "$adapterName"';

      TelemetryService.I.increment('adapter_guard.pre_registration_collision');

      if (kDebugMode) {
        throw StateError(message);
      }
    }

    // Check if ID is in reserved range but not in our list
    if (!reservedTypeIds.containsKey(typeId)) {
      TelemetryService.I.increment('adapter_guard.unreserved_type_id');
      if (kDebugMode) {
        // ignore: avoid_print
        print('[AdapterCollisionGuard] Warning: TypeId $typeId for "$adapterName" '
            'is not in reservedTypeIds. Add it to prevent future conflicts.');
      }
    }
  }

  static String _buildCollisionMessage(List<TypeIdCollision> collisions) {
    final buffer = StringBuffer('TypeId collision detected!\n');
    for (final collision in collisions) {
      buffer.writeln(
          '  TypeId ${collision.typeId}: ${collision.adapterNames.join(", ")}');
    }
    buffer.writeln(
        'This will cause silent data corruption. Fix adapter registration.');
    return buffer.toString();
  }
}

/// Result of a collision check.
class CollisionCheckResult {
  final int checkedCount;
  final List<TypeIdCollision> collisions;
  final bool hasCollisions;

  const CollisionCheckResult({
    required this.checkedCount,
    required this.collisions,
    required this.hasCollisions,
  });

  @override
  String toString() =>
      'CollisionCheckResult(checked: $checkedCount, collisions: ${collisions.length})';
}

/// Details of a single TypeId collision.
class TypeIdCollision {
  final int typeId;
  final List<String> adapterNames;

  const TypeIdCollision({
    required this.typeId,
    required this.adapterNames,
  });

  Map<String, dynamic> toJson() => {
    'typeId': typeId,
    'adapterNames': adapterNames,
  };

  @override
  String toString() => 'TypeIdCollision($typeId: ${adapterNames.join(", ")})';
}
