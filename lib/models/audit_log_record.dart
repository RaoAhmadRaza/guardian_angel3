class AuditLogRecord {
  final String type;
  final String actor;
  final Map<String, dynamic> payload;
  final DateTime timestamp;
  final bool redacted;

  const AuditLogRecord({
    required this.type,
    required this.actor,
    required this.payload,
    required this.timestamp,
    this.redacted = false,
  });

  factory AuditLogRecord.fromJson(Map<String, dynamic> json) => AuditLogRecord(
        type: json['type'] as String,
        actor: json['actor'] as String,
        payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
        timestamp: DateTime.parse(json['timestamp'] as String).toUtc(),
        redacted: json['redacted'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'actor': actor,
        'payload': payload,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'redacted': redacted,
      };
}