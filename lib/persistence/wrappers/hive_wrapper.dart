import 'package:hive/hive.dart';

class HiveWrapper {
  static Future<void> safePut<T>(Box<T> box, dynamic key, T value) async {
    try {
      await box.put(key, value);
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> transactionalWrite(Future<void> Function() cb) async {
    // No true transactions in Hive; rely on batching/ordering.
    await cb();
  }

  static Box<T> getBox<T>(String name) => Hive.box<T>(name);
}
