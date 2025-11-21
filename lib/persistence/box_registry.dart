import 'dart:io';
import 'package:hive/hive.dart';
import '../models/pending_op.dart';
import '../models/room_model.dart';
import '../models/vitals_model.dart';

class BoxRegistry {
  // Box names (authoritative)
  static const roomsBox = 'rooms_box';
  static const devicesBox = 'devices_box';
  static const vitalsBox = 'vitals_box';
  static const userProfileBox = 'user_profile_box';
  static const sessionsBox = 'sessions_box';
  static const pendingOpsBox = 'pending_ops_box';
  static const pendingIndexBox = 'pending_index_box';
  static const failedOpsBox = 'failed_ops_box';
  static const auditLogsBox = 'audit_logs_box';
  static const settingsBox = 'settings_box';
  static const assetsCacheBox = 'assets_cache_box';
  static const uiPreferencesBox = 'ui_preferences_box';
  static const metaBox = 'persistence_metadata_box';

  static const allBoxes = <String>[
    roomsBox,
    devicesBox,
    vitalsBox,
    userProfileBox,
    sessionsBox,
    pendingOpsBox,
    pendingIndexBox,
    failedOpsBox,
    auditLogsBox,
    settingsBox,
    assetsCacheBox,
    uiPreferencesBox,
    metaBox,
  ];

  Box<T> box<T>(String name) => Hive.box<T>(name);

  Box<PendingOp> pendingOps() => Hive.box<PendingOp>(pendingOpsBox);
  Box pendingIndex() => Hive.box(pendingIndexBox);
  Box<RoomModel> rooms() => Hive.box<RoomModel>(roomsBox);
  Box<VitalsModel> vitals() => Hive.box<VitalsModel>(vitalsBox);

  Future<Box> openTempBox(String name) async => Hive.openBox(name);

  Future<void> backupAllBoxes({required String suffix}) async {
    // Derive Hive directory path from any open box; if none, skip.
    String hiveDirPath = '';
    for (final name in allBoxes) {
      if (!Hive.isBoxOpen(name)) continue;
      try {
        final dynamic b = Hive.box(name);
        final String? p = (b as Box).path;
        if (p != null && p.contains('/$name')) {
          hiveDirPath = p.replaceAll('/$name', '');
          break;
        }
      } catch (_) {
        // Skip type-mismatch issues when accessing with dynamic
        continue;
      }
    }
    if (hiveDirPath.isEmpty) return;
    final hiveDir = Directory(hiveDirPath);
    if (!await hiveDir.exists()) return;
    final timestamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final backupDir = Directory('${hiveDir.path}/migration_backups');
    if (!await backupDir.exists()) await backupDir.create(recursive: true);
    for (final boxName in allBoxes) {
      final file = File('${hiveDir.path}/$boxName.hive');
      if (await file.exists()) {
        final copyTarget = File('${backupDir.path}/$boxName.$suffix.$timestamp.bak');
        await file.copy(copyTarget.path);
      }
    }
  }
}

// Stable type IDs for Hive Adapters (documented in specs)
class TypeIds {
  static const room = 10;
  static const pendingOp = 11;
  static const device = 12;
  static const vitals = 13;
  static const userProfile = 14;
  static const session = 15;
  static const failedOp = 16;
  static const auditLog = 17;
  static const settings = 18;
  static const assetsCache = 19;
  // reserve ranges for other models to avoid collisions
  // device=12, user=14, session=15, failedOp=16, auditLog=17, settings=18
}
