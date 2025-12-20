import 'package:hive/hive.dart';
import 'hive_adapters/room_model_hive.dart';
import 'hive_adapters/device_model_hive.dart';
import 'package:guardian_angel_fyp/persistence/models/pending_op.dart';
import 'package:guardian_angel_fyp/persistence/box_registry.dart';
import 'package:guardian_angel_fyp/models/failed_op_model.dart';
import 'encryption/secure_key_storage.dart';

/// Home Automation Local Hive Service
/// 
/// PHASE 1 BLOCKER FIX: Unified box naming via BoxRegistry.
/// All box names now come from BoxRegistry as the single source of truth.
class LocalHiveService {
  // ═══════════════════════════════════════════════════════════════════════
  // BOX NAMES - All from BoxRegistry (single source of truth)
  // ═══════════════════════════════════════════════════════════════════════
  
  /// Room box name - uses BoxRegistry canonical name
  /// Currently uses legacy name for backward compatibility.
  /// TODO: Migrate to BoxRegistry.homeAutomationRoomsBox after migration runs.
  static const String roomBoxName = BoxRegistry.homeAutomationRoomsBoxLegacy;
  
  /// Device box name - uses BoxRegistry canonical name
  /// Currently uses legacy name for backward compatibility.
  /// TODO: Migrate to BoxRegistry.homeAutomationDevicesBox after migration runs.
  static const String deviceBoxName = BoxRegistry.homeAutomationDevicesBoxLegacy;
  
  /// CANONICAL box name - must match BoxRegistry.pendingOpsBox
  static const String pendingOpsBoxName = BoxRegistry.pendingOpsBox;
  static const String failedOpsBoxName = BoxRegistry.homeAutomationFailedOpsBox;

  static Future<void> openAllBoxes() async {
    await Hive.openBox<RoomModelHive>(roomBoxName);
    await Hive.openBox<DeviceModelHive>(deviceBoxName);
    await Hive.openBox<PendingOp>(pendingOpsBoxName);
    await Hive.openBox<PendingOp>(failedOpsBoxName);
  }

  static Box<RoomModelHive> roomBox() => Hive.box<RoomModelHive>(roomBoxName);
  static Box<DeviceModelHive> deviceBox() => Hive.box<DeviceModelHive>(deviceBoxName);
  static Box<PendingOp> pendingOpsBox() => Hive.box<PendingOp>(pendingOpsBoxName);
  static Box<PendingOp> failedOpsBox() => Hive.box<PendingOp>(failedOpsBoxName);

  /// Open an encrypted box using a secure key stored in Keychain/Keystore.
  /// Use this for sensitive data (tokens, credentials), not necessarily for all boxes.
  static Future<Box<T>> openEncryptedBox<T>(String name, {required String keyName}) async {
    final cipher = await SecureKeyStorage.getCipher(keyName);
    return Hive.openBox<T>(name, encryptionCipher: cipher);
  }
}
