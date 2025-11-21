import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:guardian_angel_fyp/persistence/box_registry.dart';
import 'package:guardian_angel_fyp/services/models/transaction_record.dart';
import 'package:guardian_angel_fyp/services/models/lock_record.dart';
import 'package:guardian_angel_fyp/services/models/audit_log_entry.dart';
import 'package:guardian_angel_fyp/models/room_model.dart';
import 'package:guardian_angel_fyp/models/device_model.dart';
import 'package:guardian_angel_fyp/models/vitals_model.dart';
import 'package:guardian_angel_fyp/models/pending_op.dart';
import 'package:guardian_angel_fyp/models/failed_op_model.dart';
import 'package:guardian_angel_fyp/models/settings_model.dart';
import 'package:guardian_angel_fyp/models/session_model.dart';
import 'package:guardian_angel_fyp/models/user_profile_model.dart';
import 'package:guardian_angel_fyp/models/assets_cache_entry.dart';
import 'package:guardian_angel_fyp/models/sync_failure.dart';
import 'package:guardian_angel_fyp/persistence/adapters/room_adapter.dart';
import 'package:guardian_angel_fyp/persistence/adapters/device_adapter.dart';
import 'package:guardian_angel_fyp/persistence/adapters/vitals_adapter.dart';
import 'package:guardian_angel_fyp/persistence/adapters/pending_op_adapter.dart';
import 'package:guardian_angel_fyp/persistence/adapters/failed_op_adapter.dart';
import 'package:guardian_angel_fyp/persistence/adapters/settings_adapter.dart';
import 'package:guardian_angel_fyp/persistence/adapters/session_adapter.dart';
import 'package:guardian_angel_fyp/persistence/adapters/user_profile_adapter.dart';
import 'package:guardian_angel_fyp/persistence/adapters/assets_cache_adapter.dart';

/// Comprehensive round-trip tests for all TypeAdapters.
/// Validates that serialization→deserialization preserves object equality.
void main() {
  // Register adapters once before all tests (skip if already registered)
  setUpAll(() {
    try { Hive.registerAdapter(TransactionRecordAdapter()); } catch (_) {}
    try { Hive.registerAdapter(TransactionStateAdapter()); } catch (_) {}
    try { Hive.registerAdapter(LockRecordAdapter()); } catch (_) {}
    try { Hive.registerAdapter(AuditLogEntryAdapter()); } catch (_) {}
    try { Hive.registerAdapter(AuditLogArchiveAdapter()); } catch (_) {}
    try { Hive.registerAdapter(RoomAdapter()); } catch (_) {}
    try { Hive.registerAdapter(DeviceModelAdapter()); } catch (_) {}
    try { Hive.registerAdapter(VitalsAdapter()); } catch (_) {}
    try { Hive.registerAdapter(PendingOpAdapter()); } catch (_) {}
    try { Hive.registerAdapter(FailedOpModelAdapter()); } catch (_) {}
    try { Hive.registerAdapter(SettingsModelAdapter()); } catch (_) {}
    try { Hive.registerAdapter(SessionModelAdapter()); } catch (_) {}
    try { Hive.registerAdapter(UserProfileModelAdapter()); } catch (_) {}
    try { Hive.registerAdapter(AssetsCacheEntryAdapter()); } catch (_) {}
    try { Hive.registerAdapter(SyncFailureAdapter()); } catch (_) {}
    try { Hive.registerAdapter(SyncFailureStatusAdapter()); } catch (_) {}
    try { Hive.registerAdapter(SyncFailureSeverityAdapter()); } catch (_) {}
  });

  setUp(() async {
    await setUpTestHive();
  });

  tearDown(() async {
    await tearDownTestHive();
  });

  group('Adapter Round-Trip Tests', () {
    test('TransactionRecord serialization round-trip', () async {
      final box = await Hive.openBox<TransactionRecord>('test_tx');
      
      final original = TransactionRecord(
        transactionId: 'tx-001',
        createdAt: DateTime(2024, 1, 15, 10, 30).toUtc(),
        state: TransactionState.committed,
        committedAt: DateTime(2024, 1, 15, 10, 30, 5).toUtc(),
        appliedAt: null,
        modelChanges: {
          'devices_v1': {'d1': {'id': 'd1', 'name': 'Device 1'}},
        },
        pendingOp: {'op_type': 'create', 'entity': 'device'},
        indexEntries: {'pending_ops_index': ['op1', 'op2']},
        errorMessage: null,
      );
      
      await box.put('key1', original);
      final retrieved = box.get('key1');
      
      expect(retrieved, isNotNull);
      expect(retrieved!.transactionId, original.transactionId);
      expect(retrieved.state, original.state);
      expect(retrieved.createdAt, original.createdAt);
      expect(retrieved.committedAt, original.committedAt);
      expect(retrieved.modelChanges, original.modelChanges);
      expect(retrieved.pendingOp, original.pendingOp);
      expect(retrieved.indexEntries, original.indexEntries);
      
      await box.close();
    });

    test('TransactionState enum round-trip', () async {
      final box = await Hive.openBox<TransactionState>('test_tx_state');
      
      for (final state in TransactionState.values) {
        await box.put(state.name, state);
        final retrieved = box.get(state.name);
        expect(retrieved, state);
      }
      
      await box.close();
    });

    test('LockRecord serialization round-trip', () async {
      final box = await Hive.openBox<LockRecord>('test_locks');
      
      final original = LockRecord(
        lockName: 'sync_service',
        runnerId: 'runner-123',
        acquiredAt: DateTime(2024, 1, 15, 10, 0).toUtc(),
        lastHeartbeat: DateTime(2024, 1, 15, 10, 5).toUtc(),
        metadata: {'device_id': 'dev-001', 'process_id': '12345'},
        renewalCount: 5,
      );
      
      await box.put('lock1', original);
      final retrieved = box.get('lock1');
      
      expect(retrieved, isNotNull);
      expect(retrieved!.lockName, original.lockName);
      expect(retrieved.runnerId, original.runnerId);
      expect(retrieved.acquiredAt, original.acquiredAt);
      expect(retrieved.lastHeartbeat, original.lastHeartbeat);
      expect(retrieved.metadata, original.metadata);
      expect(retrieved.renewalCount, original.renewalCount);
      
      await box.close();
    });

    test('AuditLogEntry serialization round-trip', () async {
      final box = await Hive.openBox<AuditLogEntry>('test_audit');
      
      final original = AuditLogEntry(
        entryId: 'audit-001',
        timestamp: DateTime(2024, 1, 15, 10, 0).toUtc(),
        userId: 'user-123',
        action: 'login',
        entityType: 'user',
        entityId: 'user-123',
        metadata: {'ip': '192.168.1.1', 'success': true},
        severity: 'info',
        ipAddress: '192.168.1.1',
        deviceInfo: 'iOS 17.0',
      );
      
      await box.put('audit1', original);
      final retrieved = box.get('audit1');
      
      expect(retrieved, isNotNull);
      expect(retrieved!.entryId, original.entryId);
      expect(retrieved.timestamp, original.timestamp);
      expect(retrieved.userId, original.userId);
      expect(retrieved.action, original.action);
      expect(retrieved.entityType, original.entityType);
      expect(retrieved.entityId, original.entityId);
      expect(retrieved.metadata, original.metadata);
      expect(retrieved.severity, original.severity);
      expect(retrieved.ipAddress, original.ipAddress);
      expect(retrieved.deviceInfo, original.deviceInfo);
      
      await box.close();
    });

    test('AuditLogArchive serialization round-trip', () async {
      final box = await Hive.openBox<AuditLogArchive>('test_audit_archive');
      
      final original = AuditLogArchive(
        archiveId: 'archive-001',
        createdAt: DateTime(2024, 2, 1).toUtc(),
        startDate: DateTime(2024, 1, 1).toUtc(),
        endDate: DateTime(2024, 1, 31).toUtc(),
        entryCount: 150,
        filePath: '/path/to/archive.enc',
        fileSizeBytes: 524288,
        isEncrypted: true,
        checksum: 'abc123def456',
      );
      
      await box.put('archive1', original);
      final retrieved = box.get('archive1');
      
      expect(retrieved, isNotNull);
      expect(retrieved!.archiveId, original.archiveId);
      expect(retrieved.startDate, original.startDate);
      expect(retrieved.endDate, original.endDate);
      expect(retrieved.entryCount, original.entryCount);
      expect(retrieved.filePath, original.filePath);
      expect(retrieved.createdAt, original.createdAt);
      
      await box.close();
    });

    test('RoomModel serialization round-trip', () async {
      final box = await Hive.openBox<RoomModel>('test_rooms');
      
      final original = RoomModel(
        id: 'room-001',
        name: 'Living Room',
        icon: 'home',
        color: '#FF5733',
        deviceIds: ['dev-1', 'dev-2', 'dev-3'],
        meta: {'floor': '1', 'area_sqft': '200'},
        schemaVersion: 1,
        createdAt: DateTime(2024, 1, 15).toUtc(),
        updatedAt: DateTime(2024, 1, 20).toUtc(),
      );
      
      await box.put('room1', original);
      final retrieved = box.get('room1');
      
      expect(retrieved, isNotNull);
      expect(retrieved!.id, original.id);
      expect(retrieved.name, original.name);
      expect(retrieved.icon, original.icon);
      expect(retrieved.color, original.color);
      expect(retrieved.deviceIds, original.deviceIds);
      expect(retrieved.meta, original.meta);
      expect(retrieved.schemaVersion, original.schemaVersion);
      expect(retrieved.createdAt, original.createdAt);
      expect(retrieved.updatedAt, original.updatedAt);
      
      await box.close();
    });

    test('DeviceModel serialization round-trip', () async {
      final box = await Hive.openBox<DeviceModel>('test_devices');
      
      final original = DeviceModel(
        id: 'dev-001',
        roomId: 'room-001',
        type: 'sensor',
        status: 'active',
        properties: {'temperature': 22.5, 'humidity': 45, 'battery': 85},
        createdAt: DateTime(2024, 1, 15).toUtc(),
        updatedAt: DateTime(2024, 1, 20).toUtc(),
      );
      
      await box.put('dev1', original);
      final retrieved = box.get('dev1');
      
      expect(retrieved, isNotNull);
      expect(retrieved!.id, original.id);
      expect(retrieved.roomId, original.roomId);
      expect(retrieved.type, original.type);
      expect(retrieved.status, original.status);
      expect(retrieved.properties, original.properties);
      expect(retrieved.createdAt, original.createdAt);
      expect(retrieved.updatedAt, original.updatedAt);
      
      await box.close();
    });

    test('VitalsModel serialization round-trip with all fields', () async {
      final box = await Hive.openBox<VitalsModel>('test_vitals');
      
      final original = VitalsModel(
        id: 'vital-001',
        userId: 'user-123',
        heartRate: 72,
        systolicBp: 120,
        diastolicBp: 80,
        temperatureC: 36.8,
        oxygenPercent: 98,
        stressIndex: 3.2,
        recordedAt: DateTime(2024, 1, 15, 10, 30).toUtc(),
        schemaVersion: 1,
        createdAt: DateTime(2024, 1, 15, 10, 30).toUtc(),
        updatedAt: DateTime(2024, 1, 15, 10, 30).toUtc(),
        modelVersion: 2,
      );
      
      await box.put('vital1', original);
      final retrieved = box.get('vital1');
      
      expect(retrieved, isNotNull);
      expect(retrieved!.id, original.id);
      expect(retrieved.userId, original.userId);
      expect(retrieved.heartRate, original.heartRate);
      expect(retrieved.systolicBp, original.systolicBp);
      expect(retrieved.diastolicBp, original.diastolicBp);
      expect(retrieved.temperatureC, original.temperatureC);
      expect(retrieved.oxygenPercent, original.oxygenPercent);
      expect(retrieved.stressIndex, original.stressIndex);
      expect(retrieved.recordedAt, original.recordedAt);
      expect(retrieved.schemaVersion, original.schemaVersion);
      expect(retrieved.createdAt, original.createdAt);
      expect(retrieved.updatedAt, original.updatedAt);
      expect(retrieved.modelVersion, original.modelVersion);
      
      await box.close();
    });

    test('VitalsModel serialization round-trip with minimal fields', () async {
      final box = await Hive.openBox<VitalsModel>('test_vitals_min');
      
      final original = VitalsModel(
        id: 'vital-002',
        userId: 'user-456',
        heartRate: 65,
        systolicBp: 118,
        diastolicBp: 78,
        recordedAt: DateTime(2024, 1, 16).toUtc(),
        createdAt: DateTime(2024, 1, 16).toUtc(),
        updatedAt: DateTime(2024, 1, 16).toUtc(),
      );
      
      await box.put('vital2', original);
      final retrieved = box.get('vital2');
      
      expect(retrieved, isNotNull);
      expect(retrieved!.id, original.id);
      expect(retrieved.userId, original.userId);
      expect(retrieved.heartRate, original.heartRate);
      expect(retrieved.temperatureC, isNull);
      expect(retrieved.oxygenPercent, isNull);
      expect(retrieved.stressIndex, isNull);
      
      await box.close();
    });

    test('PendingOp serialization round-trip', () async {
      final box = await Hive.openBox<PendingOp>('test_pending');
      
      final original = PendingOp(
        id: 'op-001',
        opType: 'create_device',
        idempotencyKey: 'idem-key-001',
        payload: {'device_id': 'dev-001', 'room_id': 'room-001'},
        attempts: 2,
        status: 'pending',
        lastError: 'Network timeout',
        schemaVersion: 1,
        createdAt: DateTime(2024, 1, 15).toUtc(),
        updatedAt: DateTime(2024, 1, 15, 10, 30).toUtc(),
      );
      
      await box.put('op1', original);
      final retrieved = box.get('op1');
      
      expect(retrieved, isNotNull);
      expect(retrieved!.id, original.id);
      expect(retrieved.opType, original.opType);
      expect(retrieved.idempotencyKey, original.idempotencyKey);
      expect(retrieved.payload, original.payload);
      expect(retrieved.attempts, original.attempts);
      expect(retrieved.status, original.status);
      expect(retrieved.lastError, original.lastError);
      expect(retrieved.schemaVersion, original.schemaVersion);
      expect(retrieved.createdAt, original.createdAt);
      expect(retrieved.updatedAt, original.updatedAt);
      
      await box.close();
    });

    test('FailedOpModel serialization round-trip', () async {
      final box = await Hive.openBox<FailedOpModel>('test_failed');
      
      final original = FailedOpModel(
        id: 'failed-001',
        sourcePendingOpId: 'op-001',
        opType: 'create_device',
        payload: {'device_id': 'dev-001'},
        errorCode: 'NETWORK_ERROR',
        errorMessage: 'Connection timeout',
        idempotencyKey: 'idem-key-001',
        attempts: 5,
        archived: false,
        createdAt: DateTime(2024, 1, 15).toUtc(),
        updatedAt: DateTime(2024, 1, 20).toUtc(),
      );
      
      await box.put('failed1', original);
      final retrieved = box.get('failed1');
      
      expect(retrieved, isNotNull);
      expect(retrieved!.id, original.id);
      expect(retrieved.sourcePendingOpId, original.sourcePendingOpId);
      expect(retrieved.opType, original.opType);
      expect(retrieved.payload, original.payload);
      expect(retrieved.errorCode, original.errorCode);
      expect(retrieved.errorMessage, original.errorMessage);
      expect(retrieved.idempotencyKey, original.idempotencyKey);
      expect(retrieved.attempts, original.attempts);
      expect(retrieved.archived, original.archived);
      expect(retrieved.createdAt, original.createdAt);
      expect(retrieved.updatedAt, original.updatedAt);
      
      await box.close();
    });

    test('SettingsModel serialization round-trip', () async {
      final box = await Hive.openBox<SettingsModel>('test_settings');
      
      final original = SettingsModel(
        notificationsEnabled: true,
        vitalsRetentionDays: 30,
        updatedAt: DateTime(2024, 1, 20).toUtc(),
        devToolsEnabled: false,
        userRole: 'patient',
      );
      
      await box.put('settings1', original);
      final retrieved = box.get('settings1');
      
      expect(retrieved, isNotNull);
      expect(retrieved!.notificationsEnabled, original.notificationsEnabled);
      expect(retrieved.vitalsRetentionDays, original.vitalsRetentionDays);
      expect(retrieved.updatedAt, original.updatedAt);
      expect(retrieved.devToolsEnabled, original.devToolsEnabled);
      expect(retrieved.userRole, original.userRole);
      
      await box.close();
    });

    test('SessionModel serialization round-trip', () async {
      final box = await Hive.openBox<SessionModel>('test_sessions');
      
      final original = SessionModel(
        id: 'session-001',
        userId: 'user-123',
        authToken: 'jwt-token-xyz',
        issuedAt: DateTime(2024, 1, 15).toUtc(),
        expiresAt: DateTime(2024, 2, 15).toUtc(),
        createdAt: DateTime(2024, 1, 15).toUtc(),
        updatedAt: DateTime(2024, 1, 15).toUtc(),
      );
      
      await box.put('session1', original);
      final retrieved = box.get('session1');
      
      expect(retrieved, isNotNull);
      expect(retrieved!.id, original.id);
      expect(retrieved.userId, original.userId);
      expect(retrieved.authToken, original.authToken);
      expect(retrieved.issuedAt, original.issuedAt);
      expect(retrieved.expiresAt, original.expiresAt);
      expect(retrieved.createdAt, original.createdAt);
      expect(retrieved.updatedAt, original.updatedAt);
      
      await box.close();
    });

    test('UserProfileModel serialization round-trip', () async {
      final box = await Hive.openBox<UserProfileModel>('test_profiles');
      
      final original = UserProfileModel(
        id: 'user-123',
        role: 'patient',
        displayName: 'John Doe',
        email: 'john@example.com',
        createdAt: DateTime(2024, 1, 15).toUtc(),
        updatedAt: DateTime(2024, 1, 20).toUtc(),
      );
      
      await box.put('profile1', original);
      final retrieved = box.get('profile1');
      
      expect(retrieved, isNotNull);
      expect(retrieved!.id, original.id);
      expect(retrieved.role, original.role);
      expect(retrieved.displayName, original.displayName);
      expect(retrieved.email, original.email);
      expect(retrieved.createdAt, original.createdAt);
      expect(retrieved.updatedAt, original.updatedAt);
      
      await box.close();
    });

    test('AssetsCacheEntry serialization round-trip', () async {
      final box = await Hive.openBox<AssetsCacheEntry>('test_cache');
      
      final original = AssetsCacheEntry(
        key: 'user_avatar_123',
        checksum: 'abc123xyz',
        fetchedAt: DateTime(2024, 1, 15).toUtc(),
        sizeBytes: 102400,
      );
      
      await box.put('cache1', original);
      final retrieved = box.get('cache1');
      
      expect(retrieved, isNotNull);
      expect(retrieved!.key, original.key);
      expect(retrieved.checksum, original.checksum);
      expect(retrieved.fetchedAt, original.fetchedAt);
      expect(retrieved.sizeBytes, original.sizeBytes);
      
      await box.close();
    });

    test('SyncFailure serialization round-trip with all fields', () async {
      final box = await Hive.openBox<SyncFailure>('test_sync_failures');
      
      final original = SyncFailure(
        id: 'sync-fail-001',
        entityType: 'device',
        entityId: 'dev-001',
        operation: 'sync',
        reason: 'CONFLICT',
        errorMessage: 'Device state conflict detected',
        firstFailedAt: DateTime(2024, 1, 15, 10, 0).toUtc(),
        lastAttemptAt: DateTime(2024, 1, 15, 10, 30).toUtc(),
        retryCount: 3,
        status: SyncFailureStatus.pending,
        metadata: {'device_id': 'dev-001', 'conflict_field': 'status'},
        userId: 'user-123',
        severity: SyncFailureSeverity.high,
        requiresUserAction: true,
        suggestedAction: 'Please review conflicting changes',
        resolvedAt: null,
        resolutionNote: null,
      );
      
      await box.put('sync1', original);
      final retrieved = box.get('sync1');
      
      expect(retrieved, isNotNull);
      expect(retrieved!.id, original.id);
      expect(retrieved.entityType, original.entityType);
      expect(retrieved.entityId, original.entityId);
      expect(retrieved.operation, original.operation);
      expect(retrieved.reason, original.reason);
      expect(retrieved.errorMessage, original.errorMessage);
      expect(retrieved.firstFailedAt, original.firstFailedAt);
      expect(retrieved.lastAttemptAt, original.lastAttemptAt);
      expect(retrieved.retryCount, original.retryCount);
      expect(retrieved.status, original.status);
      expect(retrieved.metadata, original.metadata);
      expect(retrieved.userId, original.userId);
      expect(retrieved.severity, original.severity);
      expect(retrieved.requiresUserAction, original.requiresUserAction);
      expect(retrieved.suggestedAction, original.suggestedAction);
      expect(retrieved.resolvedAt, original.resolvedAt);
      expect(retrieved.resolutionNote, original.resolutionNote);
      
      await box.close();
    });

    test('SyncFailureStatus enum round-trip', () async {
      final box = await Hive.openBox<SyncFailureStatus>('test_sync_status');
      
      for (final status in SyncFailureStatus.values) {
        await box.put(status.name, status);
        final retrieved = box.get(status.name);
        expect(retrieved, status);
      }
      
      await box.close();
    });

    test('SyncFailureSeverity enum round-trip', () async {
      final box = await Hive.openBox<SyncFailureSeverity>('test_sync_severity');
      
      for (final severity in SyncFailureSeverity.values) {
        await box.put(severity.name, severity);
        final retrieved = box.get(severity.name);
        expect(retrieved, severity);
      }
      
      await box.close();
    });

    test('Multiple adapters in same test - mixed box operations', () async {
      final roomBox = await Hive.openBox<RoomModel>('multi_rooms');
      final deviceBox = await Hive.openBox<DeviceModel>('multi_devices');
      final vitalsBox = await Hive.openBox<VitalsModel>('multi_vitals');
      
      final room = RoomModel(
        id: 'room-m1',
        name: 'Bedroom',
        deviceIds: ['dev-m1'],
        createdAt: DateTime(2024, 1, 15).toUtc(),
        updatedAt: DateTime(2024, 1, 15).toUtc(),
      );
      
      final device = DeviceModel(
        id: 'dev-m1',
        roomId: 'room-m1',
        type: 'sensor',
        status: 'active',
        properties: {},
        createdAt: DateTime(2024, 1, 15).toUtc(),
        updatedAt: DateTime(2024, 1, 15).toUtc(),
      );
      
      final vitals = VitalsModel(
        id: 'vital-m1',
        userId: 'user-m1',
        heartRate: 70,
        systolicBp: 115,
        diastolicBp: 75,
        recordedAt: DateTime(2024, 1, 15).toUtc(),
        createdAt: DateTime(2024, 1, 15).toUtc(),
        updatedAt: DateTime(2024, 1, 15).toUtc(),
      );
      
      await roomBox.put('r1', room);
      await deviceBox.put('d1', device);
      await vitalsBox.put('v1', vitals);
      
      expect(roomBox.get('r1')!.id, 'room-m1');
      expect(deviceBox.get('d1')!.id, 'dev-m1');
      expect(vitalsBox.get('v1')!.id, 'vital-m1');
      
      await roomBox.close();
      await deviceBox.close();
      await vitalsBox.close();
    });

    test('Adapter handles null and empty values correctly', () async {
      final roomBox = await Hive.openBox<RoomModel>('null_test_rooms');
      
      final roomWithNulls = RoomModel(
        id: 'room-null',
        name: 'Empty Room',
        icon: null,
        color: null,
        deviceIds: [],
        meta: null,
        createdAt: DateTime(2024, 1, 15).toUtc(),
        updatedAt: DateTime(2024, 1, 15).toUtc(),
      );
      
      await roomBox.put('null_room', roomWithNulls);
      final retrieved = roomBox.get('null_room');
      
      expect(retrieved, isNotNull);
      expect(retrieved!.icon, isNull);
      expect(retrieved.color, isNull);
      expect(retrieved.deviceIds, isEmpty);
      expect(retrieved.meta, isNull);
      
      await roomBox.close();
    });

    test('Adapter handles large datasets correctly', () async {
      final deviceBox = await Hive.openBox<DeviceModel>('large_devices');
      
      // Create 100 devices
      for (int i = 0; i < 100; i++) {
        final device = DeviceModel(
          id: 'dev-$i',
          roomId: 'room-${i % 10}',
          type: 'sensor',
          status: i % 2 == 0 ? 'active' : 'inactive',
          properties: {'index': i, 'group': i % 5},
          createdAt: DateTime(2024, 1, 15).toUtc(),
          updatedAt: DateTime(2024, 1, 15).toUtc(),
        );
        await deviceBox.put('dev-$i', device);
      }
      
      expect(deviceBox.length, 100);
      
      // Verify random samples
      final dev0 = deviceBox.get('dev-0');
      final dev50 = deviceBox.get('dev-50');
      final dev99 = deviceBox.get('dev-99');
      
      expect(dev0!.id, 'dev-0');
      expect(dev50!.id, 'dev-50');
      expect(dev99!.id, 'dev-99');
      
      await deviceBox.close();
    });
  });
}
