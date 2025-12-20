/// Home Automation Box Migration
///
/// Migrates data from legacy box names to canonical box names.
/// 
/// Legacy → Canonical:
/// - 'rooms_v1' → 'ha_rooms_box' (BoxRegistry.homeAutomationRoomsBox)
/// - 'devices_v1' → 'ha_devices_box' (BoxRegistry.homeAutomationDevicesBox)
///
/// This migration is OPTIONAL and can be run when ready to switch to new names.
/// Until run, LocalHiveService continues using legacy names.
///
/// PHASE 1 BLOCKER FIX: Dual room box issue resolution.
library;

import 'package:hive/hive.dart';
import 'package:guardian_angel_fyp/persistence/box_registry.dart';
import 'package:guardian_angel_fyp/services/telemetry_service.dart';
import '../hive_adapters/room_model_hive.dart';
import '../hive_adapters/device_model_hive.dart';

/// Result of a box migration.
class BoxMigrationResult {
  final String fromBox;
  final String toBox;
  final int recordsMigrated;
  final bool success;
  final String? error;

  const BoxMigrationResult({
    required this.fromBox,
    required this.toBox,
    required this.recordsMigrated,
    required this.success,
    this.error,
  });

  @override
  String toString() =>
      'BoxMigrationResult(from: $fromBox, to: $toBox, records: $recordsMigrated, success: $success${error != null ? ', error: $error' : ''})';
}

/// Migrates home automation boxes from legacy names to canonical names.
class HomeAutomationBoxMigration {
  static const _tag = 'HomeAutomationBoxMigration';

  /// Checks if migration is needed (legacy boxes have data, canonical boxes are empty or don't exist).
  static Future<bool> isMigrationNeeded() async {
    final legacyRoomsExists = await Hive.boxExists(BoxRegistry.homeAutomationRoomsBoxLegacy);
    final canonicalRoomsExists = await Hive.boxExists(BoxRegistry.homeAutomationRoomsBox);
    
    final legacyDevicesExists = await Hive.boxExists(BoxRegistry.homeAutomationDevicesBoxLegacy);
    final canonicalDevicesExists = await Hive.boxExists(BoxRegistry.homeAutomationDevicesBox);

    // Migration needed if legacy exists and canonical doesn't
    final roomsMigrationNeeded = legacyRoomsExists && !canonicalRoomsExists;
    final devicesMigrationNeeded = legacyDevicesExists && !canonicalDevicesExists;

    return roomsMigrationNeeded || devicesMigrationNeeded;
  }

  /// Runs full migration from legacy to canonical box names.
  ///
  /// Returns list of migration results.
  ///
  /// If [deleteOldBoxes] is true, legacy boxes will be deleted after successful migration.
  static Future<List<BoxMigrationResult>> runMigration({
    bool deleteOldBoxes = false,
  }) async {
    final results = <BoxMigrationResult>[];

    print('[$_tag] Starting home automation box migration...');
    TelemetryService.I.increment('ha_box_migration.started');

    // Migrate rooms
    final roomsResult = await _migrateRooms(deleteOld: deleteOldBoxes);
    results.add(roomsResult);
    
    // Migrate devices
    final devicesResult = await _migrateDevices(deleteOld: deleteOldBoxes);
    results.add(devicesResult);

    final allSuccessful = results.every((r) => r.success);
    if (allSuccessful) {
      TelemetryService.I.increment('ha_box_migration.completed.success');
      print('[$_tag] Migration completed successfully');
    } else {
      TelemetryService.I.increment('ha_box_migration.completed.partial_failure');
      print('[$_tag] Migration completed with errors');
    }

    return results;
  }

  static Future<BoxMigrationResult> _migrateRooms({bool deleteOld = false}) async {
    const fromBox = BoxRegistry.homeAutomationRoomsBoxLegacy;
    const toBox = BoxRegistry.homeAutomationRoomsBox;

    try {
      final legacyExists = await Hive.boxExists(fromBox);
      if (!legacyExists) {
        print('[$_tag] No legacy rooms box found, skipping rooms migration');
        return BoxMigrationResult(
          fromBox: fromBox,
          toBox: toBox,
          recordsMigrated: 0,
          success: true,
        );
      }

      final canonicalExists = await Hive.boxExists(toBox);
      if (canonicalExists) {
        print('[$_tag] Canonical rooms box already exists, skipping rooms migration');
        return BoxMigrationResult(
          fromBox: fromBox,
          toBox: toBox,
          recordsMigrated: 0,
          success: true,
        );
      }

      // Open legacy box
      final legacy = await Hive.openBox<RoomModelHive>(fromBox);
      final recordCount = legacy.length;

      if (recordCount == 0) {
        await legacy.close();
        print('[$_tag] Legacy rooms box is empty, skipping migration');
        return BoxMigrationResult(
          fromBox: fromBox,
          toBox: toBox,
          recordsMigrated: 0,
          success: true,
        );
      }

      // Open canonical box
      final canonical = await Hive.openBox<RoomModelHive>(toBox);

      // Copy all records
      for (final entry in legacy.toMap().entries) {
        await canonical.put(entry.key, entry.value);
      }
      await canonical.flush();

      print('[$_tag] Migrated $recordCount rooms from $fromBox to $toBox');
      TelemetryService.I.increment('ha_box_migration.rooms.migrated');

      // Optionally delete old box
      if (deleteOld) {
        await legacy.deleteFromDisk();
        print('[$_tag] Deleted legacy rooms box');
      } else {
        await legacy.close();
      }

      return BoxMigrationResult(
        fromBox: fromBox,
        toBox: toBox,
        recordsMigrated: recordCount,
        success: true,
      );
    } catch (e) {
      TelemetryService.I.increment('ha_box_migration.rooms.failed');
      print('[$_tag] Rooms migration failed: $e');
      return BoxMigrationResult(
        fromBox: fromBox,
        toBox: toBox,
        recordsMigrated: 0,
        success: false,
        error: e.toString(),
      );
    }
  }

  static Future<BoxMigrationResult> _migrateDevices({bool deleteOld = false}) async {
    const fromBox = BoxRegistry.homeAutomationDevicesBoxLegacy;
    const toBox = BoxRegistry.homeAutomationDevicesBox;

    try {
      final legacyExists = await Hive.boxExists(fromBox);
      if (!legacyExists) {
        print('[$_tag] No legacy devices box found, skipping devices migration');
        return BoxMigrationResult(
          fromBox: fromBox,
          toBox: toBox,
          recordsMigrated: 0,
          success: true,
        );
      }

      final canonicalExists = await Hive.boxExists(toBox);
      if (canonicalExists) {
        print('[$_tag] Canonical devices box already exists, skipping devices migration');
        return BoxMigrationResult(
          fromBox: fromBox,
          toBox: toBox,
          recordsMigrated: 0,
          success: true,
        );
      }

      // Open legacy box
      final legacy = await Hive.openBox<DeviceModelHive>(fromBox);
      final recordCount = legacy.length;

      if (recordCount == 0) {
        await legacy.close();
        print('[$_tag] Legacy devices box is empty, skipping migration');
        return BoxMigrationResult(
          fromBox: fromBox,
          toBox: toBox,
          recordsMigrated: 0,
          success: true,
        );
      }

      // Open canonical box
      final canonical = await Hive.openBox<DeviceModelHive>(toBox);

      // Copy all records
      for (final entry in legacy.toMap().entries) {
        await canonical.put(entry.key, entry.value);
      }
      await canonical.flush();

      print('[$_tag] Migrated $recordCount devices from $fromBox to $toBox');
      TelemetryService.I.increment('ha_box_migration.devices.migrated');

      // Optionally delete old box
      if (deleteOld) {
        await legacy.deleteFromDisk();
        print('[$_tag] Deleted legacy devices box');
      } else {
        await legacy.close();
      }

      return BoxMigrationResult(
        fromBox: fromBox,
        toBox: toBox,
        recordsMigrated: recordCount,
        success: true,
      );
    } catch (e) {
      TelemetryService.I.increment('ha_box_migration.devices.failed');
      print('[$_tag] Devices migration failed: $e');
      return BoxMigrationResult(
        fromBox: fromBox,
        toBox: toBox,
        recordsMigrated: 0,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Gets the current status of box naming.
  static Future<Map<String, dynamic>> getStatus() async {
    return {
      'legacyRoomsExists': await Hive.boxExists(BoxRegistry.homeAutomationRoomsBoxLegacy),
      'canonicalRoomsExists': await Hive.boxExists(BoxRegistry.homeAutomationRoomsBox),
      'legacyDevicesExists': await Hive.boxExists(BoxRegistry.homeAutomationDevicesBoxLegacy),
      'canonicalDevicesExists': await Hive.boxExists(BoxRegistry.homeAutomationDevicesBox),
      'migrationNeeded': await isMigrationNeeded(),
      'currentRoomBoxName': BoxRegistry.homeAutomationRoomsBoxLegacy,
      'targetRoomBoxName': BoxRegistry.homeAutomationRoomsBox,
      'currentDeviceBoxName': BoxRegistry.homeAutomationDevicesBoxLegacy,
      'targetDeviceBoxName': BoxRegistry.homeAutomationDevicesBox,
    };
  }
}
