import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:guardian_angel_fyp/persistence/backups/data_export_service.dart';

/// Unit tests for DataExportService
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('data_export_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('DataExportService', () {
    test('ExportResult toJson contains expected fields', () {
      final result = ExportResult(
        file: File('/tmp/test.json'),
        boxCount: 3,
        totalRecords: 100,
        exportedAt: DateTime.utc(2025, 1, 15, 10, 30),
        sizeBytes: 5000,
      );

      final json = result.toJson();

      expect(json['path'], equals('/tmp/test.json'));
      expect(json['box_count'], equals(3));
      expect(json['total_records'], equals(100));
      expect(json['size_bytes'], equals(5000));
      expect(json['exported_at'], contains('2025'));
    });

    test('ImportResult toJson contains expected fields', () {
      final result = ImportResult(
        boxCount: 2,
        totalRecords: 50,
        importedBoxes: ['rooms_box', 'vitals_box'],
        skippedBoxes: ['settings_box'],
        importedAt: DateTime.utc(2025, 1, 15, 10, 30),
      );

      final json = result.toJson();

      expect(json['box_count'], equals(2));
      expect(json['total_records'], equals(50));
      expect(json['imported_boxes'], contains('rooms_box'));
      expect(json['skipped_boxes'], contains('settings_box'));
    });

    test('ImportResult hasSkipped returns true when boxes skipped', () {
      final result = ImportResult(
        boxCount: 1,
        totalRecords: 10,
        importedBoxes: ['rooms_box'],
        skippedBoxes: ['settings_box'],
        importedAt: DateTime.now(),
      );

      expect(result.hasSkipped, isTrue);
    });

    test('ImportResult hasSkipped returns false when no boxes skipped', () {
      final result = ImportResult(
        boxCount: 1,
        totalRecords: 10,
        importedBoxes: ['rooms_box'],
        skippedBoxes: [],
        importedAt: DateTime.now(),
      );

      expect(result.hasSkipped, isFalse);
    });

    test('exportAllData creates valid JSON file', () async {
      // Create a test box with data
      final box = await Hive.openBox('test_export_box');
      await box.put('key1', 'value1');
      await box.put('key2', {'nested': 'data'});

      final exportPath = '${tempDir.path}/export_test.json';
      final result = await DataExportService.exportAllData(
        customPath: exportPath,
      );

      expect(result.file.existsSync(), isTrue);
      
      // Verify JSON is valid
      final content = await result.file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      
      expect(data['version'], equals(1));
      expect(data['app'], equals('guardian_angel'));
      expect(data['boxes'], isA<Map>());
    });

    test('previewBackup returns correct counts', () async {
      // Create a backup file manually
      final backupData = {
        'version': 1,
        'exported_at': DateTime.now().toIso8601String(),
        'boxes': {
          'box1': [
            {'key': 'a', 'value': 1},
            {'key': 'b', 'value': 2},
          ],
          'box2': [
            {'key': 'c', 'value': 3},
          ],
        },
      };

      final backupFile = File('${tempDir.path}/preview_test.json');
      await backupFile.writeAsString(jsonEncode(backupData));

      final preview = await DataExportService.previewBackup(backupFile);

      expect(preview['version'], equals(1));
      expect(preview['box_count'], equals(2));
      expect(preview['total_records'], equals(3));
      expect((preview['record_counts'] as Map)['box1'], equals(2));
      expect((preview['record_counts'] as Map)['box2'], equals(1));
    });

    test('importData throws on missing file', () async {
      final missingFile = File('${tempDir.path}/missing.json');

      expect(
        () => DataExportService.importData(missingFile),
        throwsStateError,
      );
    });

    test('importData throws on invalid version', () async {
      final invalidBackup = {
        'version': 999,
        'boxes': {},
      };

      final backupFile = File('${tempDir.path}/invalid_version.json');
      await backupFile.writeAsString(jsonEncode(invalidBackup));

      expect(
        () => DataExportService.importData(backupFile),
        throwsStateError,
      );
    });
  });
}
