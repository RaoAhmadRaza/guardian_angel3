import 'package:hive/hive.dart';
import 'hive_adapters/room_model_hive.dart';
import 'hive_adapters/device_model_hive.dart';
import 'hive_adapters/pending_op_hive.dart';
import 'encryption/secure_key_storage.dart';

class LocalHiveService {
  static const String roomBoxName = 'rooms_v1';
  static const String deviceBoxName = 'devices_v1';
  static const String pendingOpsBoxName = 'pending_ops_v1';
  static const String failedOpsBoxName = 'failed_ops_v1';

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
