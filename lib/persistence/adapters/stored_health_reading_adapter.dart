/// Hive Adapters for Health Data Persistence
///
/// TypeIds:
/// - 55: StoredHealthReading
/// - 56: StoredHealthReadingType (enum)
///
/// DESIGN NOTES:
/// - Manual adapter (not generated) for full control
/// - JSON encoding for payload flexibility
/// - Backward-compatible field handling
/// - UTC timestamps throughout
library;

import 'dart:convert';

import 'package:hive/hive.dart';

import '../../health/models/stored_health_reading.dart';
import '../type_ids.dart';

/// Hive adapter for StoredHealthReadingType enum.
///
/// Field: enum index (int)
class StoredHealthReadingTypeAdapter extends TypeAdapter<StoredHealthReadingType> {
  @override
  final int typeId = TypeIds.storedHealthReadingType;

  @override
  StoredHealthReadingType read(BinaryReader reader) {
    final index = reader.readByte();
    if (index >= 0 && index < StoredHealthReadingType.values.length) {
      return StoredHealthReadingType.values[index];
    }
    // Default to heartRate for unknown values
    return StoredHealthReadingType.heartRate;
  }

  @override
  void write(BinaryWriter writer, StoredHealthReadingType obj) {
    writer.writeByte(obj.index);
  }
}

/// Hive adapter for StoredHealthReading.
///
/// Field mapping:
/// 0: id (String) - composite key
/// 1: patientUid (String)
/// 2: readingType (int - enum index)
/// 3: recordedAt (String - ISO8601)
/// 4: persistedAt (String - ISO8601)
/// 5: dataSource (String)
/// 6: deviceType (String)
/// 7: reliability (String)
/// 8: data (String - JSON)
/// 9: schemaVersion (int)
class StoredHealthReadingAdapter extends TypeAdapter<StoredHealthReading> {
  @override
  final int typeId = TypeIds.storedHealthReading;

  @override
  StoredHealthReading read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numFields; i++) {
      fields[reader.readByte()] = reader.read();
    }

    return StoredHealthReading(
      id: fields[0] as String? ?? '',
      patientUid: fields[1] as String? ?? '',
      readingType: _readingTypeFromIndex(fields[2] as int? ?? 0),
      recordedAt: _parseDateTime(fields[3] as String?),
      persistedAt: _parseDateTime(fields[4] as String?),
      dataSource: fields[5] as String? ?? 'unknown',
      deviceType: fields[6] as String? ?? 'unknown',
      reliability: fields[7] as String? ?? 'medium',
      data: _parseJson(fields[8] as String?),
      schemaVersion: fields[9] as int? ?? 1,
    );
  }

  @override
  void write(BinaryWriter writer, StoredHealthReading obj) {
    writer
      ..writeByte(10) // field count
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.patientUid)
      ..writeByte(2)
      ..write(obj.readingType.index)
      ..writeByte(3)
      ..write(obj.recordedAt.toUtc().toIso8601String())
      ..writeByte(4)
      ..write(obj.persistedAt.toUtc().toIso8601String())
      ..writeByte(5)
      ..write(obj.dataSource)
      ..writeByte(6)
      ..write(obj.deviceType)
      ..writeByte(7)
      ..write(obj.reliability)
      ..writeByte(8)
      ..write(_encodeJson(obj.data))
      ..writeByte(9)
      ..write(obj.schemaVersion);
  }

  /// Parse DateTime from ISO8601 string with fallback.
  DateTime _parseDateTime(String? v) {
    if (v == null || v.isEmpty) return DateTime.now().toUtc();
    return DateTime.tryParse(v)?.toUtc() ?? DateTime.now().toUtc();
  }

  /// Parse JSON map from string with fallback.
  Map<String, dynamic> _parseJson(String? v) {
    if (v == null || v.isEmpty) return {};
    try {
      final decoded = jsonDecode(v);
      if (decoded is Map<String, dynamic>) return decoded;
      return {};
    } catch (_) {
      // Corrupted JSON - return empty map
      return {};
    }
  }

  /// Encode map to JSON string.
  String _encodeJson(Map<String, dynamic> data) {
    try {
      return jsonEncode(data);
    } catch (_) {
      // Encoding failure - return empty object
      return '{}';
    }
  }

  /// Convert index to enum with bounds checking.
  StoredHealthReadingType _readingTypeFromIndex(int index) {
    if (index >= 0 && index < StoredHealthReadingType.values.length) {
      return StoredHealthReadingType.values[index];
    }
    return StoredHealthReadingType.heartRate;
  }
}
