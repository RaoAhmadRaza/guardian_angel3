import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';

/// Sets up Hive for in-memory testing.
Future<void> setUpInMemoryHive() async {
  await setUpTestHive();
}

/// Tears down the in-memory Hive instance.
Future<void> tearDownInMemoryHive() async {
  await tearDownTestHive();
}

/// Opens a typed box for tests. The box is created in-memory.
Future<Box<T>> openTestBox<T>(String name) async {
  return Hive.openBox<T>(name);
}
