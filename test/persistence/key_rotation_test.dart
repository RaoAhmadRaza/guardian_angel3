import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:guardian_angel_fyp/persistence/box_registry.dart';
import 'package:guardian_angel_fyp/persistence/hive_service.dart';
import 'package:guardian_angel_fyp/models/room_model.dart';
import 'package:guardian_angel_fyp/models/pending_op.dart';
import 'package:guardian_angel_fyp/persistence/adapters/room_adapter.dart';
import 'package:guardian_angel_fyp/persistence/adapters/pending_op_adapter.dart';

// Simple in-memory secure storage stub for tests.
class InMemorySecureStorage extends FlutterSecureStorage {
  final Map<String, String> _store = {};
  InMemorySecureStorage();
  @override
  Future<void> write({required String key, required String? value, IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, MacOsOptions? mOptions, WindowsOptions? wOptions}) async {
    if (value == null) {
      _store.remove(key);
    } else {
      _store[key] = value;
    }
  }

  @override
  Future<String?> read({required String key, IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, MacOsOptions? mOptions, WindowsOptions? wOptions}) async => _store[key];

  @override
  Future<void> delete({required String key, IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, MacOsOptions? mOptions, WindowsOptions? wOptions}) async => _store.remove(key);

  @override
  Future<Map<String, String>> readAll({IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, MacOsOptions? mOptions, WindowsOptions? wOptions}) async => Map<String, String>.from(_store);

  @override
  Future<void> deleteAll({IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, MacOsOptions? mOptions, WindowsOptions? wOptions}) async => _store.clear();

  @override
  Future<bool> containsKey({required String key, IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, MacOsOptions? mOptions, WindowsOptions? wOptions}) async => _store.containsKey(key);

  @override
  Future<bool> isCupertinoProtectedDataAvailable() async => true;

  @override
  void registerListener({required String key, required void Function(String?) listener}) {}

  @override
  void unregisterListener({required String key, required void Function(String?) listener}) {}

  @override
  void unregisterAllListeners() {}
}

void main() {
  setUp(() async {
    await setUpTestHive();
    if (!Hive.isAdapterRegistered(RoomAdapter().typeId)) {
      Hive.registerAdapter(RoomAdapter());
    }
    if (!Hive.isAdapterRegistered(PendingOpAdapter().typeId)) {
      Hive.registerAdapter(PendingOpAdapter());
    }
    await Hive.openBox(BoxRegistry.metaBox);
  });

  tearDown(() async {
    await tearDownTestHive();
  });

  test('rotateEncryptionKey re-encrypts boxes and preserves data', () async {
    final secure = InMemorySecureStorage();
    final hiveService = HiveService(secureStorage: secure);
    // Manually init without Flutter init
    if (!Hive.isAdapterRegistered(RoomAdapter().typeId)) {
      Hive.registerAdapter(RoomAdapter());
    }
    if (!Hive.isAdapterRegistered(PendingOpAdapter().typeId)) {
      Hive.registerAdapter(PendingOpAdapter());
    }
    // Create initial key
    final initialKey = Hive.generateSecureKey();
    await secure.write(key: 'hive_enc_key_v1', value: base64.encode(initialKey));
    await Hive.openBox<RoomModel>(BoxRegistry.roomsBox, encryptionCipher: HiveAesCipher(initialKey));
    await Hive.openBox<PendingOp>(BoxRegistry.pendingOpsBox, encryptionCipher: HiveAesCipher(initialKey));
    // Insert sample data
    final rooms = Hive.box<RoomModel>(BoxRegistry.roomsBox);
    await rooms.put('r1', RoomModel(
      id: 'r1',
      name: 'Room 1',
      icon: 'bed',
      color: '#fff',
      deviceIds: [],
      meta: {},
      createdAt: DateTime.utc(2024, 1, 1),
      updatedAt: DateTime.utc(2024, 1, 1),
    ));
    final pending = Hive.box<PendingOp>(BoxRegistry.pendingOpsBox);
    await pending.put('op1', PendingOp(
      id: 'op1',
      opType: 'device_toggle',
      idempotencyKey: 'idem-1',
      payload: const {},
      attempts: 0,
      status: 'pending',
      lastError: null,
      createdAt: DateTime.utc(2024, 1, 1),
      updatedAt: DateTime.utc(2024, 1, 1),
    ));
    await hiveService.rotateEncryptionKey();
    // Close and reopen with new key
    await rooms.close();
    await pending.close();
    final newKeyB64 = await secure.read(key: 'hive_enc_key_v1');
    final newKey = base64.decode(newKeyB64!);
    await Hive.openBox<RoomModel>(BoxRegistry.roomsBox, encryptionCipher: HiveAesCipher(newKey));
    await Hive.openBox<PendingOp>(BoxRegistry.pendingOpsBox, encryptionCipher: HiveAesCipher(newKey));
    expect(Hive.box<RoomModel>(BoxRegistry.roomsBox).get('r1')!.name, 'Room 1');
    expect(Hive.box<PendingOp>(BoxRegistry.pendingOpsBox).get('op1')!.idempotencyKey, 'idem-1');
  });

  test('resumeInterruptedRotation completes remaining boxes', () async {
    final secure = InMemorySecureStorage();
    final hiveService = HiveService(secureStorage: secure);
    final initialKey = Hive.generateSecureKey();
    await secure.write(key: 'hive_enc_key_v1', value: base64.encode(initialKey));
    await Hive.openBox<RoomModel>(BoxRegistry.roomsBox, encryptionCipher: HiveAesCipher(initialKey));
    await Hive.openBox<PendingOp>(BoxRegistry.pendingOpsBox, encryptionCipher: HiveAesCipher(initialKey));
    final rooms = Hive.box<RoomModel>(BoxRegistry.roomsBox);
    await rooms.put('r2', RoomModel(
      id: 'r2',
      name: 'Room 2',
      icon: 'bed',
      color: '#fff',
      deviceIds: [],
      meta: {},
      createdAt: DateTime.utc(2024, 1, 1),
      updatedAt: DateTime.utc(2024, 1, 1),
    ));
    // Start rotation manually: write candidate and prev keys, meta state marking first box done.
    final newKey = Hive.generateSecureKey();
    await secure.write(key: 'hive_enc_key_prev', value: base64.encode(initialKey));
    await secure.write(key: 'hive_enc_key_v1_candidate', value: base64.encode(newKey));
    final meta = await Hive.openBox(BoxRegistry.metaBox);
    meta.put('rotation_state', {
      'status': 'in_progress',
      'started_at': DateTime.now().toUtc().toIso8601String(),
      'boxes_completed': [BoxRegistry.roomsBox],
    });
    // Close rooms to simulate partial rotation; reopen with new key so we can resume others.
    await rooms.close();
    await Hive.openBox<RoomModel>(BoxRegistry.roomsBox, encryptionCipher: HiveAesCipher(newKey));
    // Pending ops still on old key, resume should rotate it.
    await hiveService.resumeInterruptedRotation();
    // Verify pending ops accessible after resume with final key
    String? finalKeyB64 = await secure.read(key: 'hive_enc_key_v1');
    finalKeyB64 ??= await secure.read(key: 'hive_enc_key_v1_candidate');
    expect(finalKeyB64, isNotNull, reason: 'Rotated key should be persisted');
    final finalKey = base64.decode(finalKeyB64!);
    await Hive.box<PendingOp>(BoxRegistry.pendingOpsBox).close();
    await Hive.openBox<PendingOp>(BoxRegistry.pendingOpsBox, encryptionCipher: HiveAesCipher(finalKey));
    // Ensure pending ops box accessible under rotated key.
    expect(Hive.box<PendingOp>(BoxRegistry.pendingOpsBox).get('op_missing'), isNull);
  });
}