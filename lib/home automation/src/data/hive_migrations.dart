import 'package:hive/hive.dart';
import 'hive_adapters/room_model_hive.dart';
import 'hive_adapters/device_model_hive.dart';

/// Migration helpers for Hive schema evolution using new box names.
///
/// Pattern:
/// - When changing binary layout or making breaking field changes, write to a new box name (e.g., rooms_v2)
/// - Migrate records from old -> new at startup, optionally deleting the old box files
/// - Keep adapters stable (same typeIds), but set defaults for new fields when mapping
///
/// NOTE: These functions do not change which boxes the app uses at runtime.
/// Update your box name usage (e.g., in LocalHiveService) when you actually flip to the new schema.
class HiveMigrations {
  static const _roomsV1 = 'rooms_v1';
  static const _roomsV2 = 'rooms_v2';

  static const _devicesV1 = 'devices_v1';
  static const _devicesV2 = 'devices_v2';

  /// Example migration: rooms_v1 -> rooms_v2
  /// Adds default values for newly introduced fields (e.g., iconPath).
  static Future<void> migrateRoomsV1toV2({bool deleteOld = false}) async {
    final existsOld = await Hive.boxExists(_roomsV1);
    final existsNew = await Hive.boxExists(_roomsV2);
    if (!existsOld || existsNew) return; // nothing to do or already migrated

    final old = await Hive.openBox<RoomModelHive>(_roomsV1);
    final newBox = await Hive.openBox<RoomModelHive>(_roomsV2);

    for (final r in old.values) {
      final migrated = RoomModelHive(
        id: r.id,
        name: r.name,
        iconId: r.iconId,
        color: r.color,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
        version: r.version,
        // Set defaults for new fields introduced in v2
        iconPath: r.iconPath ?? '',
      );
      await newBox.put(migrated.id, migrated);
    }

    await old.compact();
    if (deleteOld) {
      await old.deleteFromDisk();
    } else {
      await old.close();
    }
    await newBox.flush();
  }

  /// Example migration: devices_v1 -> devices_v2
  static Future<void> migrateDevicesV1toV2({bool deleteOld = false}) async {
    final existsOld = await Hive.boxExists(_devicesV1);
    final existsNew = await Hive.boxExists(_devicesV2);
    if (!existsOld || existsNew) return;

    final old = await Hive.openBox<DeviceModelHive>(_devicesV1);
    final newBox = await Hive.openBox<DeviceModelHive>(_devicesV2);

    for (final d in old.values) {
      final migrated = DeviceModelHive(
        id: d.id,
        roomId: d.roomId,
        type: d.type,
        name: d.name,
        isOn: d.isOn,
        state: Map<String, dynamic>.from(d.state),
        lastSeen: d.lastSeen,
        updatedAt: d.updatedAt,
        version: d.version,
      );
      await newBox.put(migrated.id, migrated);
    }

    await old.compact();
    if (deleteOld) {
      await old.deleteFromDisk();
    } else {
      await old.close();
    }
    await newBox.flush();
  }
}
