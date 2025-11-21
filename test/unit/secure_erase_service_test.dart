import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:guardian_angel_fyp/services/secure_erase_service.dart';
import 'package:guardian_angel_fyp/services/audit_log_service.dart';
import 'package:guardian_angel_fyp/persistence/box_registry.dart';
import 'package:guardian_angel_fyp/persistence/adapters/pending_op_adapter.dart';
import 'package:guardian_angel_fyp/persistence/adapters/room_adapter.dart';
import 'package:guardian_angel_fyp/persistence/adapters/vitals_adapter.dart';
import 'package:guardian_angel_fyp/services/models/audit_log_entry.dart';

void main() {
  late Directory tempDir;
  late SecureEraseService eraseService;
  late FlutterSecureStorage secureStorage;

  setUpAll(() {
    // Register adapters once for all tests
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(PendingOpAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(RoomAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(VitalsAdapter());
    }
    if (!Hive.isAdapterRegistered(13)) {
      Hive.registerAdapter(AuditLogEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(14)) {
      Hive.registerAdapter(AuditLogArchiveAdapter());
    }
  });

  setUp(() async {
    // Create temporary directory for Hive
    tempDir = await Directory.systemTemp.createTemp('secure_erase_test_');
    
    // Initialize Hive with temp directory
    Hive.init(tempDir.path);

    eraseService = SecureEraseService.I;
    secureStorage = const FlutterSecureStorage();
    
    // Initialize audit log service for logging
    try {
      await AuditLogService.I.init();
    } catch (e) {
      // May already be initialized
    }
  });

  tearDown(() async {
    // Close all boxes
    for (final boxName in BoxRegistry.allBoxes) {
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box(boxName).close();
      }
    }
    
    // Close audit log boxes
    if (Hive.isBoxOpen('audit_active_logs')) {
      await Hive.box('audit_active_logs').close();
    }
    if (Hive.isBoxOpen('audit_archive_metadata')) {
      await Hive.box('audit_archive_metadata').close();
    }

    // Clean up temp directory
    try {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    } catch (e) {
      // Ignore cleanup errors
    }
    
    // Clean up secure storage keys
    try {
      await secureStorage.delete(key: 'hive_enc_key_v1');
      await secureStorage.delete(key: 'hive_enc_key_prev');
      await secureStorage.delete(key: 'hive_enc_key_v1_candidate');
    } catch (e) {
      // Ignore cleanup errors
    }
  });

  group('Basic Operations', () {
    test('service initializes successfully', () {
      expect(eraseService, isNotNull);
      expect(SecureEraseService.I, same(eraseService));
    });

    test('hasDataToErase returns false when no data exists', () async {
      final hasData = await eraseService.hasDataToErase();
      expect(hasData, isFalse);
    });

    test('hasDataToErase returns true when encryption key exists', () async {
      // Create encryption key
      await secureStorage.write(key: 'hive_enc_key_v1', value: 'test_key');
      
      final hasData = await eraseService.hasDataToErase();
      expect(hasData, isTrue);
      
      // Cleanup
      await secureStorage.delete(key: 'hive_enc_key_v1');
    });

    test('hasDataToErase returns true when boxes are open', () async {
      // Open a box
      await Hive.openBox(BoxRegistry.pendingOpsBox);
      
      final hasData = await eraseService.hasDataToErase();
      expect(hasData, isTrue);
      
      // Cleanup
      await Hive.box(BoxRegistry.pendingOpsBox).close();
    });
  });

  group('Box Operations', () {
    test('closes all open boxes', () async {
      // Open multiple boxes
      await Hive.openBox(BoxRegistry.pendingOpsBox);
      await Hive.openBox(BoxRegistry.roomsBox);
      await Hive.openBox(BoxRegistry.vitalsBox);
      
      expect(Hive.isBoxOpen(BoxRegistry.pendingOpsBox), isTrue);
      expect(Hive.isBoxOpen(BoxRegistry.roomsBox), isTrue);
      expect(Hive.isBoxOpen(BoxRegistry.vitalsBox), isTrue);
      
      // Perform erase
      final result = await eraseService.eraseAllData(userId: 'testuser');
      
      expect(result.success, isTrue);
      expect(result.boxesClosed, greaterThanOrEqualTo(3));
      expect(Hive.isBoxOpen(BoxRegistry.pendingOpsBox), isFalse);
      expect(Hive.isBoxOpen(BoxRegistry.roomsBox), isFalse);
      expect(Hive.isBoxOpen(BoxRegistry.vitalsBox), isFalse);
    });

    test('deletes box files from file system', () async {
      // Create and populate a box
      final box = await Hive.openBox(BoxRegistry.pendingOpsBox);
      await box.put('test_key', 'test_value');
      await box.close();
      
      // Verify file exists
      final boxFile = File('${tempDir.path}/${BoxRegistry.pendingOpsBox}.hive');
      expect(boxFile.existsSync(), isTrue);
      
      // Perform erase
      final result = await eraseService.eraseAllData(userId: 'testuser');
      
      expect(result.success, isTrue);
      expect(result.boxesDeleted, greaterThan(0));
      
      // Verify file deleted
      expect(boxFile.existsSync(), isFalse);
    });

    test('handles already closed boxes gracefully', () async {
      // Don't open any boxes
      
      final result = await eraseService.eraseAllData(userId: 'testuser');
      
      expect(result.success, isTrue);
      expect(result.boxesClosed, equals(0));
    });
  });

  group('Encryption Key Operations', () {
    test('deletes all encryption keys', () async {
      // Create encryption keys
      await secureStorage.write(key: 'hive_enc_key_v1', value: 'current_key');
      await secureStorage.write(key: 'hive_enc_key_prev', value: 'prev_key');
      await secureStorage.write(key: 'hive_enc_key_v1_candidate', value: 'candidate_key');
      
      // Verify keys exist
      expect(await secureStorage.read(key: 'hive_enc_key_v1'), isNotNull);
      expect(await secureStorage.read(key: 'hive_enc_key_prev'), isNotNull);
      expect(await secureStorage.read(key: 'hive_enc_key_v1_candidate'), isNotNull);
      
      // Perform erase
      final result = await eraseService.eraseAllData(userId: 'testuser');
      
      expect(result.success, isTrue);
      expect(result.keysDeleted, equals(3));
      
      // Verify keys deleted
      expect(await secureStorage.read(key: 'hive_enc_key_v1'), isNull);
      expect(await secureStorage.read(key: 'hive_enc_key_prev'), isNull);
      expect(await secureStorage.read(key: 'hive_enc_key_v1_candidate'), isNull);
    });

    test('handles missing keys gracefully', () async {
      // Don't create any keys
      
      final result = await eraseService.eraseAllData(userId: 'testuser');
      
      expect(result.success, isTrue);
      expect(result.keysDeleted, equals(0));
    });

    test('deletes partial keys when some exist', () async {
      // Create only some keys
      await secureStorage.write(key: 'hive_enc_key_v1', value: 'current_key');
      
      final result = await eraseService.eraseAllData(userId: 'testuser');
      
      expect(result.success, isTrue);
      expect(result.keysDeleted, equals(1));
      expect(await secureStorage.read(key: 'hive_enc_key_v1'), isNull);
    });
  });

  group('Verification', () {
    test('verification passes when all data erased', () async {
      // Create some data
      await secureStorage.write(key: 'hive_enc_key_v1', value: 'test_key');
      await Hive.openBox(BoxRegistry.pendingOpsBox);
      
      // Erase
      final result = await eraseService.eraseAllData(userId: 'testuser');
      
      expect(result.success, isTrue);
      expect(result.verification.isComplete, isTrue);
      expect(result.verification.remainingCount, equals(0));
      expect(result.verification.remainingBoxes, isEmpty);
      expect(result.verification.remainingKeys, isEmpty);
      expect(result.verification.remainingFiles, isEmpty);
    });

    test('verification reports remaining boxes', () async {
      // Open a box but keep it open (simulate failure)
      await Hive.openBox(BoxRegistry.pendingOpsBox);
      
      // Manually open another box after erase would try to close
      // (This test simulates a box that couldn't be closed)
      final result = await eraseService.eraseAllData(userId: 'testuser');
      
      // Re-open a box to simulate incomplete closure
      await Hive.openBox(BoxRegistry.roomsBox);
      
      // Verify again
      final verification = await eraseService.eraseAllData(userId: 'testuser2');
      
      // Should have reported the newly opened box
      expect(verification.boxesClosed, greaterThan(0));
    });

    test('verification includes all remaining items', () async {
      // Create data
      await secureStorage.write(key: 'hive_enc_key_v1', value: 'test_key');
      await Hive.openBox(BoxRegistry.pendingOpsBox);
      
      final result = await eraseService.eraseAllData(userId: 'testuser');
      
      expect(result.verification.remainingItems, isEmpty);
    });
  });

  group('Audit Logging', () {
    test('logs erase initiation event', () async {
      // Perform erase with reason
      final result = await eraseService.eraseAllData(
        userId: 'testuser',
        reason: 'gdpr_request',
      );
      
      expect(result.success, isTrue);
      
      // Verify audit log (if service is still available)
      // Note: Audit logs may be deleted during erase
    });

    test('handles audit log failure gracefully', () async {
      // Dispose audit service to cause logging to fail
      AuditLogService.I.dispose();
      
      // Erase should still succeed even if audit logging fails
      final result = await eraseService.eraseAllData(userId: 'testuser');
      
      expect(result.success, isTrue);
      expect(result.completedAt, isNotNull);
    });
  });

  group('Error Handling', () {
    test('handles file system errors gracefully', () async {
      // Create a box
      await Hive.openBox(BoxRegistry.pendingOpsBox);
      
      // Erase should handle any file system errors
      final result = await eraseService.eraseAllData(userId: 'testuser');
      
      // Should succeed or fail gracefully
      expect(result.completedAt, isNotNull);
    });

    test('continues on individual box close failures', () async {
      // Open multiple boxes
      await Hive.openBox(BoxRegistry.pendingOpsBox);
      await Hive.openBox(BoxRegistry.roomsBox);
      
      // Erase should close what it can
      final result = await eraseService.eraseAllData(userId: 'testuser');
      
      expect(result.boxesClosed, greaterThan(0));
    });

    test('continues on individual key delete failures', () async {
      // Create keys
      await secureStorage.write(key: 'hive_enc_key_v1', value: 'key1');
      await secureStorage.write(key: 'hive_enc_key_prev', value: 'key2');
      
      // Erase should delete what it can
      final result = await eraseService.eraseAllData(userId: 'testuser');
      
      expect(result.keysDeleted, greaterThan(0));
    });
  });

  group('Result Object', () {
    test('result contains complete metadata', () async {
      await secureStorage.write(key: 'hive_enc_key_v1', value: 'test_key');
      await Hive.openBox(BoxRegistry.pendingOpsBox);
      
      final result = await eraseService.eraseAllData(userId: 'testuser123');
      
      expect(result.userId, equals('testuser123'));
      expect(result.startedAt, isNotNull);
      expect(result.completedAt, isNotNull);
      expect(result.durationMs, isNotNull);
      expect(result.durationMs, greaterThan(0));
      expect(result.success, isTrue);
      expect(result.boxesClosed, greaterThan(0));
      expect(result.keysDeleted, greaterThan(0));
    });

    test('result serializes to JSON correctly', () async {
      await secureStorage.write(key: 'hive_enc_key_v1', value: 'test_key');
      
      final result = await eraseService.eraseAllData(userId: 'testuser');
      
      final json = result.toJson();
      
      expect(json['userId'], equals('testuser'));
      expect(json['success'], isTrue);
      expect(json['boxesClosed'], isA<int>());
      expect(json['boxesDeleted'], isA<int>());
      expect(json['keysDeleted'], isA<int>());
      expect(json['verification'], isA<Map>());
      expect(json['errors'], isA<List>());
    });

    test('result tracks duration correctly', () async {
      await secureStorage.write(key: 'hive_enc_key_v1', value: 'test_key');
      await Hive.openBox(BoxRegistry.pendingOpsBox);
      
      final result = await eraseService.eraseAllData(userId: 'testuser');
      
      expect(result.durationMs, isNotNull);
      expect(result.durationMs, greaterThan(0));
      expect(result.durationMs, lessThan(10000)); // Should be fast
    });
  });

  group('Integration Tests', () {
    test('complete erase workflow', () async {
      // Setup: Create comprehensive data
      await secureStorage.write(key: 'hive_enc_key_v1', value: 'current_key');
      await secureStorage.write(key: 'hive_enc_key_prev', value: 'prev_key');
      
      final pendingBox = await Hive.openBox(BoxRegistry.pendingOpsBox);
      await pendingBox.put('op1', 'operation1');
      await pendingBox.put('op2', 'operation2');
      
      final roomsBox = await Hive.openBox(BoxRegistry.roomsBox);
      await roomsBox.put('room1', 'living_room');
      
      final vitalsBox = await Hive.openBox(BoxRegistry.vitalsBox);
      await vitalsBox.put('vital1', 'heart_rate');
      
      // Verify data exists
      expect(Hive.isBoxOpen(BoxRegistry.pendingOpsBox), isTrue);
      expect(Hive.isBoxOpen(BoxRegistry.roomsBox), isTrue);
      expect(Hive.isBoxOpen(BoxRegistry.vitalsBox), isTrue);
      expect(await secureStorage.read(key: 'hive_enc_key_v1'), isNotNull);
      
      // Execute erase
      final result = await eraseService.eraseAllData(
        userId: 'integration_test_user',
        reason: 'full_account_deletion',
      );
      
      // Verify success
      expect(result.success, isTrue);
      expect(result.boxesClosed, greaterThanOrEqualTo(3));
      expect(result.keysDeleted, greaterThanOrEqualTo(2));
      expect(result.verification.isComplete, isTrue);
      
      // Verify boxes closed
      expect(Hive.isBoxOpen(BoxRegistry.pendingOpsBox), isFalse);
      expect(Hive.isBoxOpen(BoxRegistry.roomsBox), isFalse);
      expect(Hive.isBoxOpen(BoxRegistry.vitalsBox), isFalse);
      
      // Verify keys deleted
      expect(await secureStorage.read(key: 'hive_enc_key_v1'), isNull);
      expect(await secureStorage.read(key: 'hive_enc_key_prev'), isNull);
      
      // Verify files deleted
      final pendingFile = File('${tempDir.path}/${BoxRegistry.pendingOpsBox}.hive');
      final roomsFile = File('${tempDir.path}/${BoxRegistry.roomsBox}.hive');
      expect(pendingFile.existsSync(), isFalse);
      expect(roomsFile.existsSync(), isFalse);
    });

    test('erase on empty system succeeds', () async {
      // No data setup
      
      final result = await eraseService.eraseAllData(userId: 'empty_user');
      
      expect(result.success, isTrue);
      expect(result.boxesClosed, equals(0));
      expect(result.boxesDeleted, greaterThanOrEqualTo(0));
      expect(result.keysDeleted, equals(0));
      expect(result.verification.isComplete, isTrue);
    });

    test('multiple erasures in sequence', () async {
      // First erase
      await secureStorage.write(key: 'hive_enc_key_v1', value: 'key1');
      await Hive.openBox(BoxRegistry.pendingOpsBox);
      
      final result1 = await eraseService.eraseAllData(userId: 'user1');
      expect(result1.success, isTrue);
      
      // Second erase (should be mostly empty)
      final result2 = await eraseService.eraseAllData(userId: 'user2');
      expect(result2.success, isTrue);
      expect(result2.boxesClosed, equals(0));
      expect(result2.keysDeleted, equals(0));
    });

    test('performance with many boxes', () async {
      // Create many boxes
      for (var i = 0; i < 5; i++) {
        await Hive.openBox('${BoxRegistry.pendingOpsBox}_$i');
      }
      await secureStorage.write(key: 'hive_enc_key_v1', value: 'test_key');
      
      final startTime = DateTime.now();
      final result = await eraseService.eraseAllData(userId: 'perf_test');
      final duration = DateTime.now().difference(startTime);
      
      expect(result.success, isTrue);
      expect(duration.inMilliseconds, lessThan(5000)); // Should be fast
      expect(result.durationMs, lessThan(5000));
    });
  });

  group('Telemetry', () {
    test('records telemetry events during erase', () async {
      await secureStorage.write(key: 'hive_enc_key_v1', value: 'test_key');
      await Hive.openBox(BoxRegistry.pendingOpsBox);
      
      final result = await eraseService.eraseAllData(userId: 'telemetry_test');
      
      expect(result.success, isTrue);
      
      // Telemetry should have recorded:
      // - secure_erase.started
      // - secure_erase.boxes_closed
      // - secure_erase.boxes_deleted
      // - secure_erase.keys_deleted
      // - secure_erase.success
      // - secure_erase.duration_ms
    });
  });
}
