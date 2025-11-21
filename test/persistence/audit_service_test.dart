import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'dart:io';
import 'package:guardian_angel_fyp/persistence/audit/audit_service.dart';
import 'package:guardian_angel_fyp/persistence/box_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync();
    Hive.init(dir.path);
    await Hive.openBox(BoxRegistry.auditLogsBox);
  });

  test('append and tail returns recent logs', () async {
    final audit = await AuditService.create();
    await audit.append(type: 'eventA', actor: 'user1');
    await audit.append(type: 'eventB', actor: 'user2');
    final tail = audit.tail(2);
    expect(tail.length, 2);
    expect(tail.first['type'], 'eventB');
    expect(tail.last['type'], 'eventA');
  });

  test('export redacts payloads when requested', () async {
    final audit = await AuditService.create();
    await audit.append(type: 'pii_event', actor: 'user1', payload: {'secret': '123'});
    final json = audit.export(redactPayloads: true);
    expect(json.contains('redacted'), isTrue);
    expect(json.contains('123'), isFalse);
  });
}