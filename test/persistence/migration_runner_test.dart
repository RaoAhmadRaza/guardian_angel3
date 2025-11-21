/// Migration Runner Test Suite
/// 
/// This test suite validates the migration system using a stabilized approach
/// that follows best practices for Hive testing:
/// 
/// STABILIZATION CHECKLIST IMPLEMENTED:
/// ✅ 1. All TypeAdapters registered in setUpAll() before any tests run
/// ✅ 2. Adapters registered ONCE and remain available across all tests
/// ✅ 3. setUpTestHive() called in setUp() to create fresh temp directory per test
/// ✅ 4. Boxes opened using typed form: Hive.openBox<T>('boxName')
/// ✅ 5. tearDownTestHive() called in tearDown() to clean up and ensure test isolation
/// ✅ 6. MigrationRunner called with skipBackup: true to avoid filesystem operations
/// ✅ 7. Pre-populated data created programmatically using adapters, not binary files
/// 
/// This approach prevents:
/// - TypeId collisions between tests
/// - "Box already open" errors
/// - Adapter registration issues
/// - Test data pollution between test runs
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:guardian_angel_fyp/persistence/migrations/migration_runner.dart';
import 'package:guardian_angel_fyp/persistence/migrations/migration_registry.dart';
import 'package:guardian_angel_fyp/persistence/meta/meta_store.dart';
import 'package:guardian_angel_fyp/persistence/box_registry.dart';
import 'package:guardian_angel_fyp/persistence/adapters/pending_op_adapter.dart';
import 'package:guardian_angel_fyp/models/pending_op.dart';
import 'package:guardian_angel_fyp/persistence/adapters/vitals_adapter.dart';
import 'package:guardian_angel_fyp/models/vitals_model.dart';
import 'package:guardian_angel_fyp/persistence/adapters/room_adapter.dart';
import 'package:guardian_angel_fyp/persistence/adapters/device_adapter.dart';
import 'package:guardian_angel_fyp/persistence/adapters/user_profile_adapter.dart';
import 'package:guardian_angel_fyp/persistence/adapters/session_adapter.dart';
import 'package:guardian_angel_fyp/persistence/adapters/failed_op_adapter.dart';
import 'package:guardian_angel_fyp/persistence/adapters/audit_log_adapter.dart';
import 'package:guardian_angel_fyp/persistence/adapters/settings_adapter.dart';
import 'package:guardian_angel_fyp/persistence/adapters/assets_cache_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Step 2: Register ALL adapters ONCE before any tests run
  // This prevents TypeId collisions and ensures all boxes can be opened safely
  // Adapters remain registered across tests - this is intentional and correct
  setUpAll(() {
    Hive.registerAdapter(PendingOpAdapter());
    Hive.registerAdapter(VitalsAdapter());
    Hive.registerAdapter(RoomAdapter());
    Hive.registerAdapter(DeviceModelAdapter());
    Hive.registerAdapter(UserProfileModelAdapter());
    Hive.registerAdapter(SessionModelAdapter());
    Hive.registerAdapter(FailedOpModelAdapter());
    Hive.registerAdapter(AuditLogRecordAdapter());
    Hive.registerAdapter(SettingsModelAdapter());
    Hive.registerAdapter(AssetsCacheEntryAdapter());
  });

  setUp(() async {
    // Step 1: setUpTestHive creates fresh temporary directory for each test
    await setUpTestHive();
    
    // Step 3: Open boxes using typed form
    await Hive.openBox(BoxRegistry.metaBox);
    await Hive.openBox<PendingOp>(BoxRegistry.pendingOpsBox);
    await Hive.openBox<VitalsModel>(BoxRegistry.vitalsBox);
    
    // Step 4: Initialize meta store with schema version 0
    final meta = MetaStore(Hive.box(BoxRegistry.metaBox));
    await meta.setSchemaVersion('core', 0);
  });

  tearDown(() async {
    // Step 5: Ensure tearDownTestHive to clean up boxes and temp directory
    // This closes all boxes and removes the temp directory, ensuring test isolation
    await tearDownTestHive();
  });

  group('Migration Runner Tests', () {
    test('migration 001 sets idempotencyKey if missing', () async {
      final pending = Hive.box<PendingOp>(BoxRegistry.pendingOpsBox);
      
      // Create op with empty idempotencyKey (pre-migration state)
      final op = PendingOp(
        id: 'op1',
        opType: 'device_toggle',
        idempotencyKey: '',
        payload: const {},
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2024-01-01T00:00:00Z'),
      );
      await pending.put(op.id, op);

      final meta = MetaStore(Hive.box(BoxRegistry.metaBox));
      // Use skipBackup: true to avoid file system operations in tests
      final runner = MigrationRunner(
        meta: meta,
        migrations: buildMigrationRegistry(),
        registry: BoxRegistry(),
        skipBackup: true,
      );
      
      await runner.runAll();

      final updated = pending.get(op.id)!;
      expect(updated.idempotencyKey.isNotEmpty, isTrue);
      expect(updated.idempotencyKey, 'op1'); // Should use op.id
      expect(meta.getSchemaVersion('core'), 2); // Both migrations applied
    });

    test('migration 001 preserves existing idempotencyKey', () async {
      final pending = Hive.box<PendingOp>(BoxRegistry.pendingOpsBox);
      
      final op = PendingOp(
        id: 'op2',
        opType: 'room_create',
        idempotencyKey: 'existing-key-123',
        payload: const {'room_id': 'room-1'},
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2024-01-01T00:00:00Z'),
      );
      await pending.put(op.id, op);

      final meta = MetaStore(Hive.box(BoxRegistry.metaBox));
      final runner = MigrationRunner(
        meta: meta,
        migrations: buildMigrationRegistry(),
        registry: BoxRegistry(),
        skipBackup: true,
      );
      
      await runner.runAll();

      final updated = pending.get(op.id)!;
      expect(updated.idempotencyKey, 'existing-key-123'); // Unchanged
    });

    test('migration 002 adds stressIndex to vitals if missing', () async {
      final vitals = Hive.box<VitalsModel>(BoxRegistry.vitalsBox);
      
      // Create vitals without stressIndex (pre-migration state)
      final v = VitalsModel(
        id: 'v1',
        userId: 'user-123',
        heartRate: 72,
        systolicBp: 120,
        diastolicBp: 80,
        stressIndex: null, // Missing in old schema
        recordedAt: DateTime.parse('2024-01-01T10:00:00Z'),
        createdAt: DateTime.parse('2024-01-01T10:00:00Z'),
        updatedAt: DateTime.parse('2024-01-01T10:00:00Z'),
        modelVersion: 1,
      );
      await vitals.put(v.id, v);

      final meta = MetaStore(Hive.box(BoxRegistry.metaBox));
      final runner = MigrationRunner(
        meta: meta,
        migrations: buildMigrationRegistry(),
        registry: BoxRegistry(),
        skipBackup: true,
      );
      
      await runner.runAll();

      final updated = vitals.get(v.id)!;
      expect(updated.stressIndex, 0.0); // Default value added
      expect(updated.modelVersion, 2); // Version upgraded
    });

    test('migration 002 preserves existing stressIndex', () async {
      final vitals = Hive.box<VitalsModel>(BoxRegistry.vitalsBox);
      
      final v = VitalsModel(
        id: 'v2',
        userId: 'user-456',
        heartRate: 85,
        systolicBp: 130,
        diastolicBp: 85,
        stressIndex: 4.5, // Already present
        recordedAt: DateTime.parse('2024-01-01T11:00:00Z'),
        createdAt: DateTime.parse('2024-01-01T11:00:00Z'),
        updatedAt: DateTime.parse('2024-01-01T11:00:00Z'),
        modelVersion: 1,
      );
      await vitals.put(v.id, v);

      final meta = MetaStore(Hive.box(BoxRegistry.metaBox));
      final runner = MigrationRunner(
        meta: meta,
        migrations: buildMigrationRegistry(),
        registry: BoxRegistry(),
        skipBackup: true,
      );
      
      await runner.runAll();

      final updated = vitals.get(v.id)!;
      expect(updated.stressIndex, 4.5); // Preserved
      expect(updated.modelVersion, 2); // Version upgraded
    });

    test('runAll is idempotent - running twice does not double-migrate', () async {
      final pending = Hive.box<PendingOp>(BoxRegistry.pendingOpsBox);
      
      final op = PendingOp(
        id: 'op3',
        opType: 'device_update',
        idempotencyKey: '',
        payload: const {},
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2024-01-01T00:00:00Z'),
      );
      await pending.put(op.id, op);

      final meta = MetaStore(Hive.box(BoxRegistry.metaBox));
      final runner = MigrationRunner(
        meta: meta,
        migrations: buildMigrationRegistry(),
        registry: BoxRegistry(),
        skipBackup: true,
      );
      
      await runner.runAll();
      final firstVersion = meta.getSchemaVersion('core');
      final firstKey = pending.get(op.id)!.idempotencyKey;
      
      // Run again - should be no-op
      await runner.runAll();
      
      expect(meta.getSchemaVersion('core'), firstVersion);
      expect(pending.get(op.id)!.idempotencyKey, firstKey);
    });

    test('migrations handle empty boxes gracefully', () async {
      final meta = MetaStore(Hive.box(BoxRegistry.metaBox));
      final runner = MigrationRunner(
        meta: meta,
        migrations: buildMigrationRegistry(),
        registry: BoxRegistry(),
        skipBackup: true,
      );
      
      // Run migrations on empty boxes - should not throw
      await runner.runAll();
      
      expect(meta.getSchemaVersion('core'), 2);
    });

    test('migrations handle multiple records correctly', () async {
      final pending = Hive.box<PendingOp>(BoxRegistry.pendingOpsBox);
      
      // Create 10 ops with empty idempotencyKeys
      for (int i = 0; i < 10; i++) {
        final op = PendingOp(
          id: 'op-batch-$i',
          opType: 'batch_op',
          idempotencyKey: '',
          payload: const {},
          createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
          updatedAt: DateTime.parse('2024-01-01T00:00:00Z'),
        );
        await pending.put(op.id, op);
      }

      final meta = MetaStore(Hive.box(BoxRegistry.metaBox));
      final runner = MigrationRunner(
        meta: meta,
        migrations: buildMigrationRegistry(),
        registry: BoxRegistry(),
        skipBackup: true,
      );
      
      await runner.runAll();

      // Verify all ops have idempotencyKey
      for (int i = 0; i < 10; i++) {
        final updated = pending.get('op-batch-$i')!;
        expect(updated.idempotencyKey.isNotEmpty, isTrue);
      }
    });
  });
}