import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'dart:math';
import 'package:guardian_angel_fyp/persistence/adapters/room_adapter.dart';
import 'package:guardian_angel_fyp/persistence/adapters/pending_op_adapter.dart';
import 'package:guardian_angel_fyp/persistence/adapters/vitals_adapter.dart';
import 'package:guardian_angel_fyp/persistence/adapters/device_adapter.dart';
import 'package:guardian_angel_fyp/persistence/adapters/session_adapter.dart';
import 'package:guardian_angel_fyp/persistence/adapters/user_profile_adapter.dart';
import 'package:guardian_angel_fyp/persistence/adapters/failed_op_adapter.dart';
import 'package:guardian_angel_fyp/persistence/adapters/audit_log_adapter.dart';
import 'package:guardian_angel_fyp/persistence/adapters/settings_adapter.dart';
import 'package:guardian_angel_fyp/persistence/adapters/assets_cache_adapter.dart';
import 'package:guardian_angel_fyp/models/room_model.dart';
import 'package:guardian_angel_fyp/models/pending_op.dart';
import 'package:guardian_angel_fyp/models/vitals_model.dart';
import 'package:guardian_angel_fyp/models/device_model.dart';
import 'package:guardian_angel_fyp/models/session_model.dart';
import 'package:guardian_angel_fyp/models/user_profile_model.dart';
import 'package:guardian_angel_fyp/models/failed_op_model.dart';
import 'package:guardian_angel_fyp/models/audit_log_record.dart';
import 'package:guardian_angel_fyp/models/settings_model.dart';
import 'package:guardian_angel_fyp/models/assets_cache_entry.dart';

int _boxCounter = 0;

Future<T> _roundTrip<T>(T value) async {
  final boxName = 'rt_${T.toString()}_${_boxCounter++}';
  final box = await Hive.openBox<T>(boxName);
  await box.put('k', value);
  final back = box.get('k');
  expect(back, isNotNull);
  await box.deleteFromDisk();
  return back as T;
}

void main() {
  group('TypeAdapter round-trip', () {
    setUp(() async {
      await setUpTestHive();
      // Register adapters (guard to avoid duplicate registration errors)
      if (!Hive.isAdapterRegistered(RoomAdapter().typeId)) {
        Hive
          ..registerAdapter(RoomAdapter())
          ..registerAdapter(PendingOpAdapter())
          ..registerAdapter(VitalsAdapter())
          ..registerAdapter(DeviceModelAdapter())
          ..registerAdapter(SessionModelAdapter())
          ..registerAdapter(UserProfileModelAdapter())
          ..registerAdapter(FailedOpModelAdapter())
          ..registerAdapter(AuditLogRecordAdapter())
          ..registerAdapter(SettingsModelAdapter())
          ..registerAdapter(AssetsCacheEntryAdapter());
      }
    });

    tearDown(() async {
      await tearDownTestHive();
    });

    test('RoomModel', () async {
      final model = RoomModel(
        id: 'room1',
        name: 'ICU',
        icon: 'bed',
        color: '#FFFFFF',
        deviceIds: const ['dev1', 'dev2'],
        meta: const {'floor': 3},
        createdAt: DateTime.utc(2024, 1, 1),
        updatedAt: DateTime.utc(2024, 1, 2),
      );
      final back = await _roundTrip(model);
      expect(back.toJson(), equals(model.toJson()));
    });

    test('PendingOp', () async {
      final model = PendingOp(
        id: 'op1',
        opType: 'device_toggle',
        idempotencyKey: 'idem-12345678',
        payload: const {'device_id': 'dev1', 'state': 'on'},
        attempts: 2,
        status: 'retry',
        lastError: 'timeout',
        createdAt: DateTime.utc(2024, 1, 1, 12),
        updatedAt: DateTime.utc(2024, 1, 1, 13),
      );
      final back = await _roundTrip(model);
      expect(back.toJson(), equals(model.toJson()));
    });

    test('VitalsModel', () async {
      final model = VitalsModel(
        id: 'v1',
        userId: 'u1',
        heartRate: 72,
        systolicBp: 120,
        diastolicBp: 80,
        temperatureC: 36.6,
        oxygenPercent: 98,
        stressIndex: 0.4,
        recordedAt: DateTime.utc(2024, 1, 1, 10),
        createdAt: DateTime.utc(2024, 1, 1, 10),
        updatedAt: DateTime.utc(2024, 1, 1, 11),
        modelVersion: 2,
      );
      final back = await _roundTrip(model);
      expect(back.toJson(), equals(model.toJson()));
    });

    test('DeviceModel', () async {
      final model = DeviceModel(
        id: 'dev1',
        roomId: 'room1',
        type: 'sensor',
        status: 'active',
        properties: const {'battery': 0.87},
        createdAt: DateTime.utc(2024, 1, 1),
        updatedAt: DateTime.utc(2024, 1, 2),
      );
      final back = await _roundTrip(model);
      expect(back.toJson(), equals(model.toJson()));
    });

    test('SessionModel', () async {
      final now = DateTime.utc(2024, 1, 1, 12);
      final model = SessionModel(
        id: 'sess1',
        userId: 'u1',
        authToken: 'token-abc',
        issuedAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
        createdAt: now,
        updatedAt: now.add(const Duration(minutes: 5)),
      );
      final back = await _roundTrip(model);
      expect(back.toJson(), equals(model.toJson()));
    });

    test('UserProfileModel', () async {
      final model = UserProfileModel(
        id: 'user1',
        role: 'patient',
        displayName: 'Alice',
        email: 'alice@example.com',
        createdAt: DateTime.utc(2024, 1, 1),
        updatedAt: DateTime.utc(2024, 1, 2),
      );
      final back = await _roundTrip(model);
      expect(back.toJson(), equals(model.toJson()));
    });

    test('FailedOpModel', () async {
      final model = FailedOpModel(
        id: 'f1',
        sourcePendingOpId: 'op1',
        opType: 'device_toggle',
        payload: const {'device_id': 'dev1'},
        errorCode: 'TIMEOUT',
        errorMessage: 'Request timed out',
        idempotencyKey: 'idem-op1-xyz',
        attempts: 3,
        archived: false,
        createdAt: DateTime.utc(2024, 1, 1),
        updatedAt: DateTime.utc(2024, 1, 2),
      );
      final back = await _roundTrip(model);
      expect(back.toJson(), equals(model.toJson()));
    });

    test('AuditLogRecord', () async {
      final model = AuditLogRecord(
        type: 'SOS',
        actor: 'user1',
        payload: const {'severity': 'high'},
        timestamp: DateTime.utc(2024, 1, 1, 12, 30),
        redacted: false,
      );
      final back = await _roundTrip(model);
      expect(back.toJson(), equals(model.toJson()));
    });

    test('SettingsModel', () async {
      final model = SettingsModel(
        notificationsEnabled: true,
        vitalsRetentionDays: 45,
        updatedAt: DateTime.utc(2024, 1, 2),
      );
      final back = await _roundTrip(model);
      expect(back.toJson(), equals(model.toJson()));
    });

    test('AssetsCacheEntry', () async {
      final model = AssetsCacheEntry(
        key: 'img/logo@2x',
        checksum: 'sha256:${Random().nextInt(1 << 32)}',
        fetchedAt: DateTime.utc(2024, 1, 1, 9),
        sizeBytes: 2048,
      );
      final back = await _roundTrip(model);
      expect(back.toJson(), equals(model.toJson()));
    });
  });
}