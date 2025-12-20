/// DataExportService - Minimal Data Export/Import
///
/// Part of FINAL CLIMB: Audit closure items.
///
/// Provides simple data export and import functionality:
/// - exportAllData() - Export all box data to a single JSON file
/// - importData(File) - Import data from a backup file
///
/// USAGE:
/// ```dart
/// // Export
/// final exportFile = await DataExportService.exportAllData();
/// 
/// // Import
/// await DataExportService.importData(backupFile);
/// ```
library;

import 'dart:io';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../box_registry.dart';
import '../../services/telemetry_service.dart';
import '../wrappers/box_accessor.dart';

/// Riverpod provider for DataExportService
final dataExportServiceProvider = Provider<DataExportService>((ref) {
  return DataExportService();
});

/// Result of an export operation
class ExportResult {
  final File file;
  final int boxCount;
  final int totalRecords;
  final DateTime exportedAt;
  final int sizeBytes;

  ExportResult({
    required this.file,
    required this.boxCount,
    required this.totalRecords,
    required this.exportedAt,
    required this.sizeBytes,
  });

  Map<String, dynamic> toJson() => {
        'path': file.path,
        'box_count': boxCount,
        'total_records': totalRecords,
        'exported_at': exportedAt.toIso8601String(),
        'size_bytes': sizeBytes,
      };
}

/// Result of an import operation
class ImportResult {
  final int boxCount;
  final int totalRecords;
  final List<String> importedBoxes;
  final List<String> skippedBoxes;
  final DateTime importedAt;

  ImportResult({
    required this.boxCount,
    required this.totalRecords,
    required this.importedBoxes,
    required this.skippedBoxes,
    required this.importedAt,
  });

  bool get hasSkipped => skippedBoxes.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'box_count': boxCount,
        'total_records': totalRecords,
        'imported_boxes': importedBoxes,
        'skipped_boxes': skippedBoxes,
        'imported_at': importedAt.toIso8601String(),
      };
}

/// Simple data export/import service.
///
/// Hooks into BoxRegistry to export/import all application data.
class DataExportService {
  /// Creates a new DataExportService instance.
  const DataExportService();

  // ═══════════════════════════════════════════════════════════════════════
  // EXPORT
  // ═══════════════════════════════════════════════════════════════════════

  /// Export all data from all boxes to a JSON file.
  ///
  /// Returns the exported file with metadata.
  ///
  /// ```dart
  /// final result = await DataExportService.exportAllData();
  /// print('Exported ${result.totalRecords} records to ${result.file.path}');
  /// ```
  static Future<ExportResult> exportAllData({
    String? customPath,
  }) async {
    final sw = Stopwatch()..start();
    
    // Collect all box data
    final exportData = <String, dynamic>{
      'version': 1,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'app': 'guardian_angel',
      'boxes': <String, dynamic>{},
    };

    int totalRecords = 0;
    int boxCount = 0;

    for (final boxName in BoxRegistry.allBoxes) {
      if (!Hive.isBoxOpen(boxName)) continue;

      try {
        final box = BoxAccess.I.boxUntyped(boxName);
        final records = <Map<String, dynamic>>[];

        for (final key in box.keys) {
          final value = box.get(key);
          records.add({
            'key': key.toString(),
            'value': _serializeValue(value),
          });
        }

        if (records.isNotEmpty) {
          exportData['boxes'][boxName] = records;
          totalRecords += records.length;
          boxCount++;
        }
      } catch (e) {
        // Skip boxes that can't be read
        print('[DataExportService] Skipping box $boxName: $e');
      }
    }

    // Generate file path
    final timestamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final fileName = 'guardian_angel_backup_$timestamp.json';
    
    String filePath;
    if (customPath != null) {
      filePath = customPath;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${dir.path}/backups');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      filePath = '${backupDir.path}/$fileName';
    }

    // Write to file
    final file = File(filePath);
    final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
    await file.writeAsString(jsonString, flush: true);

    sw.stop();
    
    TelemetryService.I.increment('data_export.success');
    TelemetryService.I.gauge('data_export.boxes', boxCount);
    TelemetryService.I.gauge('data_export.records', totalRecords);
    TelemetryService.I.time('data_export.duration_ms', () => sw.elapsed);

    print('[DataExportService] Exported $totalRecords records from $boxCount boxes to $filePath');

    return ExportResult(
      file: file,
      boxCount: boxCount,
      totalRecords: totalRecords,
      exportedAt: DateTime.now().toUtc(),
      sizeBytes: await file.length(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // IMPORT
  // ═══════════════════════════════════════════════════════════════════════

  /// Import data from a backup file.
  ///
  /// ```dart
  /// final result = await DataExportService.importData(backupFile);
  /// print('Imported ${result.totalRecords} records');
  /// ```
  static Future<ImportResult> importData(
    File backup, {
    bool overwriteExisting = false,
  }) async {
    final sw = Stopwatch()..start();

    if (!await backup.exists()) {
      throw StateError('Backup file not found: ${backup.path}');
    }

    final content = await backup.readAsString();
    final data = jsonDecode(content) as Map<String, dynamic>;

    // Validate format
    if (data['version'] != 1) {
      throw StateError('Unsupported backup version: ${data['version']}');
    }

    final boxes = data['boxes'] as Map<String, dynamic>? ?? {};
    
    int totalRecords = 0;
    final importedBoxes = <String>[];
    final skippedBoxes = <String>[];

    for (final entry in boxes.entries) {
      final boxName = entry.key;
      final records = entry.value as List<dynamic>;

      if (!Hive.isBoxOpen(boxName)) {
        // Try to open the box
        try {
          await Hive.openBox(boxName);
        } catch (e) {
          print('[DataExportService] Cannot open box $boxName: $e');
          skippedBoxes.add(boxName);
          continue;
        }
      }

      final box = BoxAccess.I.boxUntyped(boxName);

      // Skip non-empty boxes unless overwrite is enabled
      if (!overwriteExisting && box.isNotEmpty) {
        skippedBoxes.add(boxName);
        continue;
      }

      // Import records
      for (final record in records) {
        final map = record as Map<String, dynamic>;
        final key = map['key'];
        final value = map['value'];
        
        try {
          await box.put(key, value);
          totalRecords++;
        } catch (e) {
          print('[DataExportService] Failed to import $boxName/$key: $e');
        }
      }

      importedBoxes.add(boxName);
    }

    sw.stop();

    TelemetryService.I.increment('data_import.success');
    TelemetryService.I.gauge('data_import.boxes', importedBoxes.length);
    TelemetryService.I.gauge('data_import.records', totalRecords);
    TelemetryService.I.time('data_import.duration_ms', () => sw.elapsed);

    print('[DataExportService] Imported $totalRecords records into ${importedBoxes.length} boxes');

    return ImportResult(
      boxCount: importedBoxes.length,
      totalRecords: totalRecords,
      importedBoxes: importedBoxes,
      skippedBoxes: skippedBoxes,
      importedAt: DateTime.now().toUtc(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ═══════════════════════════════════════════════════════════════════════

  /// List available backup files.
  static Future<List<File>> listBackups() async {
    final dir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${dir.path}/backups');
    
    if (!await backupDir.exists()) {
      return [];
    }

    final files = await backupDir.list().toList();
    return files
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path)); // Newest first
  }

  /// Delete a backup file.
  static Future<void> deleteBackup(File backup) async {
    if (await backup.exists()) {
      await backup.delete();
      TelemetryService.I.increment('data_export.backup_deleted');
    }
  }

  /// Preview a backup without importing.
  static Future<Map<String, dynamic>> previewBackup(File backup) async {
    if (!await backup.exists()) {
      throw StateError('Backup file not found: ${backup.path}');
    }

    final content = await backup.readAsString();
    final data = jsonDecode(content) as Map<String, dynamic>;

    final boxes = data['boxes'] as Map<String, dynamic>? ?? {};
    final counts = <String, int>{};
    int total = 0;

    for (final entry in boxes.entries) {
      final records = entry.value as List<dynamic>;
      counts[entry.key] = records.length;
      total += records.length;
    }

    return {
      'version': data['version'],
      'exported_at': data['exported_at'],
      'box_count': boxes.length,
      'total_records': total,
      'record_counts': counts,
    };
  }

  /// Serialize a value for JSON export.
  static dynamic _serializeValue(dynamic value) {
    if (value == null) return null;
    if (value is String || value is num || value is bool) return value;
    if (value is DateTime) return value.toIso8601String();
    if (value is List) return value.map(_serializeValue).toList();
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _serializeValue(v)));
    }
    
    // Try toJson for model objects
    try {
      final dynamic obj = value;
      if (obj.toJson != null) {
        return obj.toJson();
      }
    } catch (_) {}

    // Fallback to toString
    return value.toString();
  }
}
