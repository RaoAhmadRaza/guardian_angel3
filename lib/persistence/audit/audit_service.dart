import 'dart:convert';
import 'package:hive/hive.dart';
import '../box_registry.dart';

/// Append-only audit log service. Each record is a Map<String,dynamic> with
/// keys: type, actor, timestamp (UTC ISO8601), payload (Map), redacted (bool?)
class AuditService {
  final Box _box;

  AuditService._(this._box);

  static Future<AuditService> create() async {
    final box = Hive.box(BoxRegistry.auditLogsBox);
    return AuditService._(box);
  }

  Future<void> append({
    required String type,
    required String actor,
    Map<String, dynamic>? payload,
    bool redacted = false,
  }) async {
    final record = {
      'type': type,
      'actor': actor,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'payload': payload ?? <String, dynamic>{},
      'redacted': redacted,
    };
    // Use incremental integer key to maintain order.
    final key = _box.length;
    await _box.put(key, record);
  }

  /// Query last [limit] records (most recent first).
  List<Map<String, dynamic>> tail(int limit) {
    final start = _box.length - limit;
    final list = <Map<String, dynamic>>[];
    for (int i = start < 0 ? 0 : start; i < _box.length; i++) {
      final v = _box.get(i);
      if (v is Map) list.add(Map<String, dynamic>.from(v));
    }
    return list.reversed.toList();
  }

  /// Export all logs to JSON string. Optionally redact payloads.
  String export({bool redactPayloads = false}) {
    final out = <Map<String, dynamic>>[];
    for (int i = 0; i < _box.length; i++) {
      final v = _box.get(i);
      if (v is Map) {
        final copy = Map<String, dynamic>.from(v);
        if (redactPayloads) {
          copy['payload'] = {'redacted': true};
          copy['redacted'] = true;
        }
        out.add(copy);
      }
    }
    return jsonEncode(out);
  }
}