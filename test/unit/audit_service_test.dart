import 'package:flutter_test/flutter_test.dart';
import 'package:hive_test/hive_test.dart';
import 'package:guardian_angel_fyp/services/audit_service.dart';
import 'package:guardian_angel_fyp/services/models/audit_log_entry.dart';
import 'package:hive/hive.dart';

void main() {
  setUpAll(() {
    // Register adapters once
    try {
      Hive.registerAdapter(AuditLogEntryAdapter());
      Hive.registerAdapter(AuditLogArchiveAdapter());
    } catch (_) {
      // Adapters already registered in other tests
    }
  });

  setUp(() async {
    await setUpTestHive();
  });

  tearDown(() async {
    await tearDownTestHive();
  });

  group('AuditService', () {
    group('append()', () {
      test('successfully appends audit entry to box', () async {
        final box = await Hive.openBox<AuditLogEntry>('audit_logs_box');
        final service = AuditService(box);

        final entry = AuditLogEntry(
          entryId: 'audit_001',
          timestamp: DateTime(2024, 1, 15, 10, 30).toUtc(),
          userId: 'user_001',
          action: 'login',
          metadata: {'ipAddress': '192.168.1.100'},
          severity: 'info',
        );

        await service.append(entry);

        expect(box.length, 1);
        expect(box.get('audit_001'), isNotNull);
        expect(box.get('audit_001')!.userId, 'user_001');
        expect(box.get('audit_001')!.action, 'login');
      });

      test('appends multiple entries maintaining order', () async {
        final box = await Hive.openBox<AuditLogEntry>('audit_logs_box');
        final service = AuditService(box);

        final entry1 = AuditLogEntry(
          entryId: 'audit_001',
          timestamp: DateTime(2024, 1, 15, 10, 30).toUtc(),
          userId: 'user_001',
          action: 'login',
          metadata: {},
          severity: 'info',
        );

        final entry2 = AuditLogEntry(
          entryId: 'audit_002',
          timestamp: DateTime(2024, 1, 15, 10, 35).toUtc(),
          userId: 'user_001',
          action: 'device_control',
          entityType: 'device',
          entityId: 'dev_001',
          metadata: {'command': 'toggle'},
          severity: 'info',
        );

        await service.append(entry1);
        await service.append(entry2);

        expect(box.length, 2);
        expect(service.entryCount, 2);
      });

      test('appends entries with all optional fields', () async {
        final box = await Hive.openBox<AuditLogEntry>('audit_logs_box');
        final service = AuditService(box);

        final entry = AuditLogEntry(
          entryId: 'audit_full',
          timestamp: DateTime(2024, 1, 15, 10, 30).toUtc(),
          userId: 'user_001',
          action: 'data_access',
          entityType: 'vitals',
          entityId: 'vitals_001',
          metadata: {'query': 'last_24h', 'records': 48},
          severity: 'warning',
          ipAddress: '192.168.1.100',
          deviceInfo: 'iOS 17.0 - iPhone 14 Pro',
        );

        await service.append(entry);

        final retrieved = box.get('audit_full')!;
        expect(retrieved.entityType, 'vitals');
        expect(retrieved.entityId, 'vitals_001');
        expect(retrieved.ipAddress, '192.168.1.100');
        expect(retrieved.deviceInfo, 'iOS 17.0 - iPhone 14 Pro');
        expect(retrieved.metadata['records'], 48);
      });
    });

    group('tail()', () {
      test('retrieves last N entries in descending timestamp order', () async {
        final box = await Hive.openBox<AuditLogEntry>('audit_logs_box');
        final service = AuditService(box);

        // Add 5 entries with different timestamps
        for (int i = 1; i <= 5; i++) {
          await service.append(AuditLogEntry(
            entryId: 'audit_00$i',
            timestamp: DateTime(2024, 1, 15, 10, i).toUtc(),
            userId: 'user_001',
            action: 'action_$i',
            metadata: {},
            severity: 'info',
          ));
        }

        final last3 = await service.tail(3);

        expect(last3.length, 3);
        // Most recent first
        expect(last3[0].action, 'action_5');
        expect(last3[1].action, 'action_4');
        expect(last3[2].action, 'action_3');
      });

      test('returns all entries when N exceeds count', () async {
        final box = await Hive.openBox<AuditLogEntry>('audit_logs_box');
        final service = AuditService(box);

        await service.append(AuditLogEntry(
          entryId: 'audit_001',
          timestamp: DateTime(2024, 1, 15, 10, 30).toUtc(),
          userId: 'user_001',
          action: 'login',
          metadata: {},
          severity: 'info',
        ));

        await service.append(AuditLogEntry(
          entryId: 'audit_002',
          timestamp: DateTime(2024, 1, 15, 10, 35).toUtc(),
          userId: 'user_001',
          action: 'logout',
          metadata: {},
          severity: 'info',
        ));

        final allEntries = await service.tail(100);

        expect(allEntries.length, 2);
        expect(allEntries[0].action, 'logout'); // Most recent
        expect(allEntries[1].action, 'login');
      });

      test('returns empty list when box is empty', () async {
        final box = await Hive.openBox<AuditLogEntry>('audit_logs_box');
        final service = AuditService(box);

        final entries = await service.tail(10);

        expect(entries, isEmpty);
      });
    });

    group('exportRedacted()', () {
      test('exports entries since specified timestamp with full redaction', () async {
        final box = await Hive.openBox<AuditLogEntry>('audit_logs_box');
        final service = AuditService(box);

        final oldEntry = AuditLogEntry(
          entryId: 'audit_old',
          timestamp: DateTime(2024, 1, 10).toUtc(),
          userId: 'user_001',
          action: 'login',
          metadata: {},
          severity: 'info',
          ipAddress: '192.168.1.100',
        );

        final newEntry = AuditLogEntry(
          entryId: 'audit_new',
          timestamp: DateTime(2024, 1, 15).toUtc(),
          userId: 'user_12345678',
          action: 'data_access',
          metadata: {'password': 'secret123', 'query': 'last_24h'},
          severity: 'warning',
          ipAddress: '192.168.1.200',
        );

        await service.append(oldEntry);
        await service.append(newEntry);

        final since = DateTime(2024, 1, 14).toUtc();
        final exported = await service.exportRedacted(since: since);

        expect(exported.length, 1);
        
        final redacted = exported.first;
        // User ID masked (first 4 chars only)
        expect(redacted.userId, 'user*********'); // 'user_12345678' -> 4 chars + 9 asterisks
        
        // IP address masked (first octet only)
        expect(redacted.ipAddress, '192.xxx.xxx.xxx');
        
        // Timestamp reduced to day precision
        expect(redacted.timestamp.hour, 0);
        expect(redacted.timestamp.minute, 0);
        expect(redacted.timestamp.second, 0);
        
        // Sensitive metadata redacted
        expect(redacted.metadata['password'], '[REDACTED]');
        expect(redacted.metadata['query'], 'last_24h'); // Non-sensitive kept
      });

      test('exports entries in chronological order', () async {
        final box = await Hive.openBox<AuditLogEntry>('audit_logs_box');
        final service = AuditService(box);

        // Add entries out of order
        await service.append(AuditLogEntry(
          entryId: 'audit_003',
          timestamp: DateTime(2024, 1, 15, 12, 0).toUtc(),
          userId: 'user_001',
          action: 'action_3',
          metadata: {},
          severity: 'info',
        ));

        await service.append(AuditLogEntry(
          entryId: 'audit_001',
          timestamp: DateTime(2024, 1, 15, 10, 0).toUtc(),
          userId: 'user_001',
          action: 'action_1',
          metadata: {},
          severity: 'info',
        ));

        await service.append(AuditLogEntry(
          entryId: 'audit_002',
          timestamp: DateTime(2024, 1, 15, 11, 0).toUtc(),
          userId: 'user_001',
          action: 'action_2',
          metadata: {},
          severity: 'info',
        ));

        final since = DateTime(2024, 1, 15).toUtc();
        final exported = await service.exportRedacted(since: since);

        expect(exported.length, 3);
        // Chronological order for export
        expect(exported[0].action, 'action_1');
        expect(exported[1].action, 'action_2');
        expect(exported[2].action, 'action_3');
      });

      test('allows selective redaction control', () async {
        final box = await Hive.openBox<AuditLogEntry>('audit_logs_box');
        final service = AuditService(box);

        await service.append(AuditLogEntry(
          entryId: 'audit_001',
          timestamp: DateTime(2024, 1, 15, 10, 30).toUtc(),
          userId: 'user_12345',
          action: 'login',
          metadata: {'token': 'abc123'},
          severity: 'info',
          ipAddress: '192.168.1.100',
        ));

        final since = DateTime(2024, 1, 14).toUtc();
        
        // No redaction
        final unredacted = await service.exportRedacted(
          since: since,
          maskUserId: false,
          partialTimestamp: false,
          maskIpAddress: false,
          maskMetadata: false,
        );

        expect(unredacted.first.userId, 'user_12345');
        expect(unredacted.first.ipAddress, '192.168.1.100');
        expect(unredacted.first.timestamp.hour, 5); // 10:30 UTC -> hour 5 in timestamp
        expect(unredacted.first.metadata['token'], 'abc123');
      });
    });

    group('helper methods', () {
      test('entryCount returns correct count', () async {
        final box = await Hive.openBox<AuditLogEntry>('audit_logs_box');
        final service = AuditService(box);

        expect(service.entryCount, 0);

        await service.append(AuditLogEntry(
          entryId: 'audit_001',
          timestamp: DateTime.now().toUtc(),
          userId: 'user_001',
          action: 'login',
          metadata: {},
          severity: 'info',
        ));

        expect(service.entryCount, 1);
      });

      test('oldestEntryTimestamp returns null when empty', () async {
        final box = await Hive.openBox<AuditLogEntry>('audit_logs_box');
        final service = AuditService(box);

        expect(service.oldestEntryTimestamp, isNull);
      });

      test('oldestEntryTimestamp returns earliest timestamp', () async {
        final box = await Hive.openBox<AuditLogEntry>('audit_logs_box');
        final service = AuditService(box);

        final oldest = DateTime(2024, 1, 10).toUtc();
        final newest = DateTime(2024, 1, 15).toUtc();

        await service.append(AuditLogEntry(
          entryId: 'audit_new',
          timestamp: newest,
          userId: 'user_001',
          action: 'action_new',
          metadata: {},
          severity: 'info',
        ));

        await service.append(AuditLogEntry(
          entryId: 'audit_old',
          timestamp: oldest,
          userId: 'user_001',
          action: 'action_old',
          metadata: {},
          severity: 'info',
        ));

        expect(service.oldestEntryTimestamp, oldest);
      });

      test('newestEntryTimestamp returns latest timestamp', () async {
        final box = await Hive.openBox<AuditLogEntry>('audit_logs_box');
        final service = AuditService(box);

        final oldest = DateTime(2024, 1, 10).toUtc();
        final newest = DateTime(2024, 1, 15).toUtc();

        await service.append(AuditLogEntry(
          entryId: 'audit_old',
          timestamp: oldest,
          userId: 'user_001',
          action: 'action_old',
          metadata: {},
          severity: 'info',
        ));

        await service.append(AuditLogEntry(
          entryId: 'audit_new',
          timestamp: newest,
          userId: 'user_001',
          action: 'action_new',
          metadata: {},
          severity: 'info',
        ));

        expect(service.newestEntryTimestamp, newest);
      });
    });

    group('filtering methods', () {
      test('getEntriesBySeverity filters correctly', () async {
        final box = await Hive.openBox<AuditLogEntry>('audit_logs_box');
        final service = AuditService(box);

        await service.append(AuditLogEntry(
          entryId: 'audit_001',
          timestamp: DateTime(2024, 1, 15, 10, 0).toUtc(),
          userId: 'user_001',
          action: 'login',
          metadata: {},
          severity: 'info',
        ));

        await service.append(AuditLogEntry(
          entryId: 'audit_002',
          timestamp: DateTime(2024, 1, 15, 11, 0).toUtc(),
          userId: 'user_001',
          action: 'failed_login',
          metadata: {},
          severity: 'critical',
        ));

        await service.append(AuditLogEntry(
          entryId: 'audit_003',
          timestamp: DateTime(2024, 1, 15, 12, 0).toUtc(),
          userId: 'user_002',
          action: 'logout',
          metadata: {},
          severity: 'info',
        ));

        final criticalEntries = await service.getEntriesBySeverity('critical');
        expect(criticalEntries.length, 1);
        expect(criticalEntries.first.action, 'failed_login');

        final infoEntries = await service.getEntriesBySeverity('info');
        expect(infoEntries.length, 2);
      });

      test('getEntriesForUser filters correctly', () async {
        final box = await Hive.openBox<AuditLogEntry>('audit_logs_box');
        final service = AuditService(box);

        await service.append(AuditLogEntry(
          entryId: 'audit_001',
          timestamp: DateTime.now().toUtc(),
          userId: 'user_001',
          action: 'login',
          metadata: {},
          severity: 'info',
        ));

        await service.append(AuditLogEntry(
          entryId: 'audit_002',
          timestamp: DateTime.now().toUtc(),
          userId: 'user_002',
          action: 'login',
          metadata: {},
          severity: 'info',
        ));

        await service.append(AuditLogEntry(
          entryId: 'audit_003',
          timestamp: DateTime.now().toUtc(),
          userId: 'user_001',
          action: 'logout',
          metadata: {},
          severity: 'info',
        ));

        final user1Entries = await service.getEntriesForUser('user_001');
        expect(user1Entries.length, 2);
        expect(user1Entries.every((e) => e.userId == 'user_001'), isTrue);
      });

      test('getEntriesByAction filters correctly', () async {
        final box = await Hive.openBox<AuditLogEntry>('audit_logs_box');
        final service = AuditService(box);

        await service.append(AuditLogEntry(
          entryId: 'audit_001',
          timestamp: DateTime.now().toUtc(),
          userId: 'user_001',
          action: 'device_control',
          metadata: {},
          severity: 'info',
        ));

        await service.append(AuditLogEntry(
          entryId: 'audit_002',
          timestamp: DateTime.now().toUtc(),
          userId: 'user_002',
          action: 'login',
          metadata: {},
          severity: 'info',
        ));

        await service.append(AuditLogEntry(
          entryId: 'audit_003',
          timestamp: DateTime.now().toUtc(),
          userId: 'user_001',
          action: 'device_control',
          metadata: {},
          severity: 'info',
        ));

        final controlActions = await service.getEntriesByAction('device_control');
        expect(controlActions.length, 2);
        expect(controlActions.every((e) => e.action == 'device_control'), isTrue);
      });
    });

    group('archiveOldEntries()', () {
      test('removes entries older than max age', () async {
        final box = await Hive.openBox<AuditLogEntry>('audit_logs_box');
        final service = AuditService(box);

        final now = DateTime.now().toUtc();
        final old = now.subtract(Duration(days: 100));

        await service.append(AuditLogEntry(
          entryId: 'audit_old',
          timestamp: old,
          userId: 'user_001',
          action: 'old_action',
          metadata: {},
          severity: 'info',
        ));

        await service.append(AuditLogEntry(
          entryId: 'audit_recent',
          timestamp: now,
          userId: 'user_001',
          action: 'recent_action',
          metadata: {},
          severity: 'info',
        ));

        expect(service.entryCount, 2);

        final archivedCount = await service.archiveOldEntries(
          maxAge: Duration(days: 30),
        );

        expect(archivedCount, 1);
        expect(service.entryCount, 1);
        expect(box.get('audit_old'), isNull);
        expect(box.get('audit_recent'), isNotNull);
      });

      test('returns 0 when no entries need archiving', () async {
        final box = await Hive.openBox<AuditLogEntry>('audit_logs_box');
        final service = AuditService(box);

        await service.append(AuditLogEntry(
          entryId: 'audit_recent',
          timestamp: DateTime.now().toUtc(),
          userId: 'user_001',
          action: 'recent_action',
          metadata: {},
          severity: 'info',
        ));

        final archivedCount = await service.archiveOldEntries(
          maxAge: Duration(days: 30),
        );

        expect(archivedCount, 0);
        expect(service.entryCount, 1);
      });
    });

    group('clear()', () {
      test('removes all audit entries', () async {
        final box = await Hive.openBox<AuditLogEntry>('audit_logs_box');
        final service = AuditService(box);

        await service.append(AuditLogEntry(
          entryId: 'audit_001',
          timestamp: DateTime.now().toUtc(),
          userId: 'user_001',
          action: 'action_1',
          metadata: {},
          severity: 'info',
        ));

        await service.append(AuditLogEntry(
          entryId: 'audit_002',
          timestamp: DateTime.now().toUtc(),
          userId: 'user_002',
          action: 'action_2',
          metadata: {},
          severity: 'info',
        ));

        expect(service.entryCount, 2);

        await service.clear();

        expect(service.entryCount, 0);
        expect(box.isEmpty, isTrue);
      });
    });
  });
}
