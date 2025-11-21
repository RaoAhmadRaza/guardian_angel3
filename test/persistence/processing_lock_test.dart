import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'dart:io';
import 'package:guardian_angel_fyp/persistence/locking/processing_lock.dart';
import 'package:guardian_angel_fyp/persistence/box_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync();
    Hive.init(dir.path);
    await Hive.openBox(BoxRegistry.metaBox);
  });

  test('acquire and release persistent lock', () async {
    final lock = await ProcessingLock.create(staleThreshold: const Duration(seconds: 1));
    final pid1 = await lock.tryAcquire('pid1');
    expect(pid1, 'pid1');
    final pid2 = await lock.tryAcquire('pid2');
    expect(pid2, isNull); // still locked
    await Future.delayed(const Duration(seconds: 2));
    final pid3 = await lock.tryAcquire('pid3'); // stale takeover
    expect(pid3, 'pid3');
    await lock.release('pid3');
    final pid4 = await lock.tryAcquire('pid4');
    expect(pid4, 'pid4');
  });
}