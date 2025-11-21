import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:guardian_angel_fyp/services/audit_log_service.dart';
import 'package:guardian_angel_fyp/services/models/audit_log_entry.dart';
import 'package:guardian_angel_fyp/services/telemetry_service.dart';

void main() {
  late Directory tempDir;
  late Directory archiveDir;
  late AuditLogService auditService;
  late TelemetryService telemetry;

  setUpAll(() async {
    // Register Hive adapters
    Hive.registerAdapter(AuditLogEntryAdapter());
    Hive.registerAdapter(AuditLogArchiveAdapter());
  });

  setUp(() async {
    // Create temporary directories
    tempDir = await Directory.systemTemp.createTemp('audit_test_');
    archiveDir = Directory('${tempDir.path}/archives');
    await archiveDir.create();
    
    Hive.init(tempDir.path);
    
    telemetry = TelemetryService.I;
    
    auditService = AuditLogService(
      telemetry: telemetry,
      archiveDirectory: archiveDir.path,
    );
    await auditService.init();
  });

  tearDown(() async {
    auditService.dispose();
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  group('Audit Log Basic Operations', () {
    test('init initializes service correctly', () async {
      final stats = await auditService.getStats();
      
      expect(stats.activeEntryCount, equals(0));
      expect(stats.archiveCount, equals(0));
    });

    test('log creates audit entry', () async {
      await auditService.log(
        userId: 'user123',
        action: 'login',
        severity: 'info',
        metadata: {'source': 'mobile'},
      );

      final stats = await auditService.getStats();
      expect(stats.activeEntryCount, equals(1));
    });

    test('log captures all fields correctly', () async {
      await auditService.log(
        userId: 'user456',
        action: 'data_access',
        entityType: 'device',
        entityId: 'device_789',
        severity: 'warning',
        ipAddress: '192.168.1.100',
        deviceInfo: 'iOS 15.0',
        metadata: {'action': 'read', 'count': 5},
      );

      final entries = await auditService.exportLogs(
        redactionConfig: RedactionConfig.none,
        includeArchives: false,
      );

      expect(entries.length, equals(1));
      final entry = entries.first;
      
      expect(entry.userId, equals('user456'));
      expect(entry.action, equals('data_access'));
      expect(entry.entityType, equals('device'));
      expect(entry.entityId, equals('device_789'));
      expect(entry.severity, equals('warning'));
      expect(entry.ipAddress, equals('192.168.1.100'));
      expect(entry.deviceInfo, equals('iOS 15.0'));
      expect(entry.metadata['action'], equals('read'));
    });

    test('multiple log entries maintain order', () async {
      for (int i = 0; i < 10; i++) {
        await auditService.log(
          userId: 'user$i',
          action: 'action$i',
          severity: 'info',
        );
        await Future.delayed(const Duration(milliseconds: 10));
      }

      final entries = await auditService.exportLogs(
        redactionConfig: RedactionConfig.none,
        includeArchives: false,
      );

      expect(entries.length, equals(10));
      
      // Verify chronological order
      for (int i = 1; i < entries.length; i++) {
        expect(entries[i].timestamp.isAfter(entries[i - 1].timestamp), isTrue);
      }
    });
  });

  group('Redaction', () {
    test('standard redaction masks userId', () async {
      await auditService.log(
        userId: 'user123456789',
        action: 'test',
        severity: 'info',
      );

      final entries = await auditService.exportLogs(
        redactionConfig: RedactionConfig.standard,
        includeArchives: false,
      );

      expect(entries.first.userId, equals('user*********')); // 9 asterisks for remaining chars
    });

    test('standard redaction masks IP address', () async {
      await auditService.log(
        userId: 'user123',
        action: 'test',
        severity: 'info',
        ipAddress: '192.168.1.100',
      );

      final entries = await auditService.exportLogs(
        redactionConfig: RedactionConfig.standard,
        includeArchives: false,
      );

      expect(entries.first.ipAddress, equals('192.xxx.xxx.xxx'));
    });

    test('standard redaction uses partial timestamps', () async {
      await auditService.log(
        userId: 'user123',
        action: 'test',
        severity: 'info',
      );

      final entries = await auditService.exportLogs(
        redactionConfig: RedactionConfig.standard,
        includeArchives: false,
      );

      final entry = entries.first;
      // Should have hour/minute/second zeroed out
      expect(entry.timestamp.hour, equals(0));
      expect(entry.timestamp.minute, equals(0));
      expect(entry.timestamp.second, equals(0));
    });

    test('standard redaction masks sensitive metadata', () async {
      await auditService.log(
        userId: 'user123',
        action: 'test',
        severity: 'info',
        metadata: {
          'password': 'secret123',
          'token': 'abc-xyz',
          'email': 'user@example.com',
          'normalField': 'keepThis',
        },
      );

      final entries = await auditService.exportLogs(
        redactionConfig: RedactionConfig.standard,
        includeArchives: false,
      );

      final metadata = entries.first.metadata;
      expect(metadata['password'], equals('[REDACTED]'));
      expect(metadata['token'], equals('[REDACTED]'));
      expect(metadata['email'], equals('[REDACTED]'));
      expect(metadata['normalField'], equals('keepThis'));
    });

    test('none redaction preserves all data', () async {
      await auditService.log(
        userId: 'user123456789',
        action: 'test',
        severity: 'info',
        ipAddress: '192.168.1.100',
        metadata: {'password': 'secret'},
      );

      final entries = await auditService.exportLogs(
        redactionConfig: RedactionConfig.none,
        includeArchives: false,
      );

      final entry = entries.first;
      expect(entry.userId, equals('user123456789'));
      expect(entry.ipAddress, equals('192.168.1.100'));
      expect(entry.metadata['password'], equals('secret'));
      expect(entry.timestamp.hour, isNot(equals(0))); // Full timestamp
    });

    test('minimal redaction keeps userId but masks IP', () async {
      await auditService.log(
        userId: 'user123',
        action: 'test',
        severity: 'info',
        ipAddress: '192.168.1.100',
      );

      final entries = await auditService.exportLogs(
        redactionConfig: RedactionConfig.minimal,
        includeArchives: false,
      );

      expect(entries.first.userId, equals('user123'));
      expect(entries.first.ipAddress, equals('192.xxx.xxx.xxx'));
    });
  });

  group('Log Rotation', () {
    test('manual rotation creates archive', () async {
      // Add entries
      for (int i = 0; i < 5; i++) {
        await auditService.log(
          userId: 'user$i',
          action: 'action$i',
          severity: 'info',
        );
      }

      var stats = await auditService.getStats();
      expect(stats.activeEntryCount, equals(5));
      expect(stats.archiveCount, equals(0));

      // Rotate
      await auditService.rotateNow();

      stats = await auditService.getStats();
      expect(stats.activeEntryCount, equals(0));
      expect(stats.archiveCount, equals(1));
      expect(stats.totalArchivedEntries, equals(5));
    });

    test('rotation creates encrypted archive file', () async {
      await auditService.log(
        userId: 'user123',
        action: 'test',
        severity: 'info',
      );

      await auditService.rotateNow();

      // Check archive file exists
      final files = await archiveDir.list().toList();
      expect(files.length, equals(1));
      expect(files.first.path.endsWith('.alog'), isTrue);
    });

    test('automatic rotation triggers at max entries', () async {
      // Create service with low max entries
      auditService.dispose();
      
      final customPolicy = RetentionPolicy(
        activePeriod: const Duration(days: 1),
        archivePeriod: const Duration(days: 7),
        maxActiveEntries: 10,
        maxArchiveFileSizeMB: 5,
      );
      
      auditService = AuditLogService(
        telemetry: telemetry,
        retentionPolicy: customPolicy,
        archiveDirectory: archiveDir.path,
      );
      await auditService.init();

      // Add entries up to threshold
      for (int i = 0; i < 11; i++) {
        await auditService.log(
          userId: 'user$i',
          action: 'action$i',
          severity: 'info',
        );
      }

      // Last log should trigger rotation
      final stats = await auditService.getStats();
      expect(stats.archiveCount, greaterThan(0));
    });

    test('export includes archived entries', () async {
      // Add and rotate first batch
      for (int i = 0; i < 3; i++) {
        await auditService.log(
          userId: 'batch1_user$i',
          action: 'batch1_action',
          severity: 'info',
        );
      }
      await auditService.rotateNow();

      // Add second batch
      for (int i = 0; i < 2; i++) {
        await auditService.log(
          userId: 'batch2_user$i',
          action: 'batch2_action',
          severity: 'info',
        );
      }

      final entries = await auditService.exportLogs(
        redactionConfig: RedactionConfig.none,
        includeArchives: true,
      );

      expect(entries.length, equals(5));
      expect(entries.where((e) => e.action == 'batch1_action').length, equals(3));
      expect(entries.where((e) => e.action == 'batch2_action').length, equals(2));
    });

    test('export excludes archives when specified', () async {
      await auditService.log(userId: 'user1', action: 'action1', severity: 'info');
      await auditService.rotateNow();
      await auditService.log(userId: 'user2', action: 'action2', severity: 'info');

      final entries = await auditService.exportLogs(
        redactionConfig: RedactionConfig.none,
        includeArchives: false,
      );

      expect(entries.length, equals(1));
      expect(entries.first.action, equals('action2'));
    });
  });

  group('Auto-Purge', () {
    test('purgeExpiredArchives removes old archives', () async {
      // Create service with short retention
      auditService.dispose();
      
      final shortPolicy = RetentionPolicy(
        activePeriod: const Duration(seconds: 1),
        archivePeriod: const Duration(seconds: 1),
        maxActiveEntries: 5,
        maxArchiveFileSizeMB: 5,
      );
      
      auditService = AuditLogService(
        telemetry: telemetry,
        retentionPolicy: shortPolicy,
        archiveDirectory: archiveDir.path,
      );
      await auditService.init();

      // Create and rotate entries
      await auditService.log(userId: 'user1', action: 'test', severity: 'info');
      await auditService.rotateNow();

      var stats = await auditService.getStats();
      expect(stats.archiveCount, equals(1));

      // Wait for expiry
      await Future.delayed(const Duration(seconds: 2));

      // Purge
      final purgedCount = await auditService.purgeExpiredArchives();
      expect(purgedCount, equals(1));

      stats = await auditService.getStats();
      expect(stats.archiveCount, equals(0));
    });

    test('purgeExpiredArchives deletes archive files', () async {
      auditService.dispose();
      
      final shortPolicy = RetentionPolicy(
        activePeriod: const Duration(seconds: 1),
        archivePeriod: const Duration(seconds: 1),
        maxActiveEntries: 5,
        maxArchiveFileSizeMB: 5,
      );
      
      auditService = AuditLogService(
        telemetry: telemetry,
        retentionPolicy: shortPolicy,
        archiveDirectory: archiveDir.path,
      );
      await auditService.init();

      await auditService.log(userId: 'user1', action: 'test', severity: 'info');
      await auditService.rotateNow();

      var files = await archiveDir.list().toList();
      expect(files.length, equals(1));

      await Future.delayed(const Duration(seconds: 2));
      await auditService.purgeExpiredArchives();

      files = await archiveDir.list().toList();
      expect(files.length, equals(0));
    });

    test('purgeExpiredArchives preserves recent archives', () async {
      await auditService.log(userId: 'user1', action: 'test', severity: 'info');
      await auditService.rotateNow();

      final purgedCount = await auditService.purgeExpiredArchives();
      expect(purgedCount, equals(0));

      final stats = await auditService.getStats();
      expect(stats.archiveCount, equals(1));
    });
  });

  group('Date Range Export', () {
    test('export filters by start date', () async {
      await auditService.log(userId: 'user1', action: 'old', severity: 'info');
      await Future.delayed(const Duration(milliseconds: 100));
      
      final cutoff = DateTime.now();
      await Future.delayed(const Duration(milliseconds: 100));
      
      await auditService.log(userId: 'user2', action: 'new', severity: 'info');

      final entries = await auditService.exportLogs(
        startDate: cutoff,
        redactionConfig: RedactionConfig.none,
        includeArchives: false,
      );

      expect(entries.length, equals(1));
      expect(entries.first.action, equals('new'));
    });

    test('export filters by end date', () async {
      await auditService.log(userId: 'user1', action: 'old', severity: 'info');
      await Future.delayed(const Duration(milliseconds: 100));
      
      final cutoff = DateTime.now();
      await Future.delayed(const Duration(milliseconds: 100));
      
      await auditService.log(userId: 'user2', action: 'new', severity: 'info');

      final entries = await auditService.exportLogs(
        endDate: cutoff,
        redactionConfig: RedactionConfig.none,
        includeArchives: false,
      );

      expect(entries.length, equals(1));
      expect(entries.first.action, equals('old'));
    });

    test('export filters by date range', () async {
      await auditService.log(userId: 'user1', action: 'before', severity: 'info');
      await Future.delayed(const Duration(milliseconds: 100));
      
      final start = DateTime.now();
      await Future.delayed(const Duration(milliseconds: 100));
      
      await auditService.log(userId: 'user2', action: 'during', severity: 'info');
      await Future.delayed(const Duration(milliseconds: 100));
      
      final end = DateTime.now();
      await Future.delayed(const Duration(milliseconds: 100));
      
      await auditService.log(userId: 'user3', action: 'after', severity: 'info');

      final entries = await auditService.exportLogs(
        startDate: start,
        endDate: end,
        redactionConfig: RedactionConfig.none,
        includeArchives: false,
      );

      expect(entries.length, equals(1));
      expect(entries.first.action, equals('during'));
    });
  });

  group('Export to File', () {
    test('exportToFile creates JSON file', () async {
      await auditService.log(userId: 'user123', action: 'test', severity: 'info');

      final exportPath = '${tempDir.path}/export.json';
      await auditService.exportToFile(
        filePath: exportPath,
        redactionConfig: RedactionConfig.none,
      );

      final file = File(exportPath);
      expect(await file.exists(), isTrue);
    });

    test('exportToFile includes metadata', () async {
      await auditService.log(userId: 'user123', action: 'test', severity: 'info');

      final exportPath = '${tempDir.path}/export.json';
      await auditService.exportToFile(
        filePath: exportPath,
        redactionConfig: RedactionConfig.standard,
      );

      final file = File(exportPath);
      final content = await file.readAsString();
      
      expect(content.contains('exportDate'), isTrue);
      expect(content.contains('redactionApplied'), isTrue);
      expect(content.contains('entryCount'), isTrue);
    });
  });

  group('Statistics', () {
    test('getStats returns accurate counts', () async {
      for (int i = 0; i < 5; i++) {
        await auditService.log(userId: 'user$i', action: 'test', severity: 'info');
      }
      await auditService.rotateNow();
      
      for (int i = 0; i < 3; i++) {
        await auditService.log(userId: 'user$i', action: 'test', severity: 'info');
      }

      final stats = await auditService.getStats();
      
      expect(stats.activeEntryCount, equals(3));
      expect(stats.archiveCount, equals(1));
      expect(stats.totalArchivedEntries, equals(5));
      expect(stats.totalEntries, equals(8));
    });

    test('getStats tracks oldest and newest active entries', () async {
      await auditService.log(userId: 'user1', action: 'first', severity: 'info');
      await Future.delayed(const Duration(milliseconds: 100));
      await auditService.log(userId: 'user2', action: 'second', severity: 'info');
      await Future.delayed(const Duration(milliseconds: 100));
      await auditService.log(userId: 'user3', action: 'third', severity: 'info');

      final stats = await auditService.getStats();
      
      expect(stats.oldestActiveEntry, isNotNull);
      expect(stats.newestActiveEntry, isNotNull);
      expect(stats.newestActiveEntry!.isAfter(stats.oldestActiveEntry!), isTrue);
    });

    test('getStats calculates archive size', () async {
      for (int i = 0; i < 10; i++) {
        await auditService.log(
          userId: 'user$i',
          action: 'test',
          severity: 'info',
          metadata: {'data': 'x' * 100}, // Add some data
        );
      }
      await auditService.rotateNow();

      final stats = await auditService.getStats();
      
      expect(stats.totalArchiveSizeBytes, greaterThan(0));
      expect(stats.totalArchiveSizeMB, greaterThan(0));
    });
  });

  group('Error Handling', () {
    test('throws error if not initialized', () async {
      final uninitService = AuditLogService(
        telemetry: telemetry,
      );

      expect(
        () => uninitService.log(userId: 'user1', action: 'test', severity: 'info'),
        throwsStateError,
      );
    });

    test('handles missing archive file gracefully', () async {
      await auditService.log(userId: 'user1', action: 'test', severity: 'info');
      await auditService.rotateNow();

      // Delete archive file manually
      final files = await archiveDir.list().toList();
      await (files.first as File).delete();

      // Export should still work (returns empty for missing archive)
      final entries = await auditService.exportLogs(
        redactionConfig: RedactionConfig.none,
        includeArchives: true,
      );

      expect(entries, isNotNull);
    });
  });

  group('Integration Tests', () {
    test('complete workflow: log, rotate, export, purge', () async {
      // Phase 1: Log entries
      for (int i = 0; i < 5; i++) {
        await auditService.log(
          userId: 'user$i',
          action: 'phase1_action',
          severity: 'info',
          metadata: {'phase': 1},
        );
      }

      // Phase 2: Rotate to archive
      await auditService.rotateNow();
      
      var stats = await auditService.getStats();
      expect(stats.activeEntryCount, equals(0));
      expect(stats.archiveCount, equals(1));

      // Phase 3: Log more entries
      for (int i = 0; i < 3; i++) {
        await auditService.log(
          userId: 'user$i',
          action: 'phase2_action',
          severity: 'warning',
          metadata: {'phase': 2},
        );
      }

      // Phase 4: Export with redaction
      var entries = await auditService.exportLogs(
        redactionConfig: RedactionConfig.standard,
        includeArchives: true,
      );

      expect(entries.length, equals(8));
      expect(entries.first.userId, contains('*')); // Redacted

      // Phase 5: Export without redaction (legal review)
      entries = await auditService.exportLogs(
        redactionConfig: RedactionConfig.none,
        includeArchives: true,
      );

      expect(entries.length, equals(8));
      expect(entries.first.userId, isNot(contains('*'))); // Not redacted

      // Phase 6: Verify no purge for recent data
      final purgedCount = await auditService.purgeExpiredArchives();
      expect(purgedCount, equals(0));

      stats = await auditService.getStats();
      expect(stats.archiveCount, equals(1));
    });

    test('high volume logging performance', () async {
      final stopwatch = Stopwatch()..start();
      
      // Log 1000 entries
      for (int i = 0; i < 1000; i++) {
        await auditService.log(
          userId: 'user${i % 100}',
          action: 'action_$i',
          severity: i % 3 == 0 ? 'critical' : 'info',
          metadata: {'index': i, 'batch': i ~/ 100},
        );
      }

      stopwatch.stop();
      final logTime = stopwatch.elapsedMilliseconds;
      
      print('Logged 1000 entries in ${logTime}ms');
      expect(logTime, lessThan(5000), reason: '1000 entries should log in < 5s');

      // Rotate
      stopwatch.reset();
      stopwatch.start();
      await auditService.rotateNow();
      stopwatch.stop();
      final rotateTime = stopwatch.elapsedMilliseconds;
      
      print('Rotated 1000 entries in ${rotateTime}ms');
      expect(rotateTime, lessThan(2000), reason: 'Rotation should complete in < 2s');

      final stats = await auditService.getStats();
      expect(stats.totalArchivedEntries, equals(1000));
    });
  });
}
