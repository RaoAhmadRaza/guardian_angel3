import 'dart:convert';

class PendingOp {
  final String id;
  final String opType;
  final String idempotencyKey;
  final Map<String, dynamic> payload;
  final int attempts;
  final String status; // pending, in_progress, retry, failed, completed
  final String? lastError;
  final int schemaVersion;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PendingOp({
    required this.id,
    required this.opType,
    required this.idempotencyKey,
    required this.payload,
    this.attempts = 0,
    this.status = 'pending',
    this.lastError,
    this.schemaVersion = 1,
    required this.createdAt,
    required this.updatedAt,
  });

  PendingOp copyWith({
    int? attempts,
    String? status,
    String? lastError,
    DateTime? updatedAt,
  }) => PendingOp(
        id: id,
        opType: opType,
        idempotencyKey: idempotencyKey,
        payload: payload,
        attempts: attempts ?? this.attempts,
        status: status ?? this.status,
        lastError: lastError ?? this.lastError,
        schemaVersion: schemaVersion,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory PendingOp.fromJson(Map<String, dynamic> json) => PendingOp(
        id: json['id'] as String,
        opType: json['op_type'] as String,
        idempotencyKey: json['idempotency_key'] as String,
        payload: (json['payload'] as Map).cast<String, dynamic>(),
        attempts: (json['attempts'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? 'pending',
        lastError: json['last_error'] as String?,
        schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 1,
        createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
        updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'schema_version': schemaVersion,
        'op_type': opType,
        'idempotency_key': idempotencyKey,
        'payload': payload,
        'attempts': attempts,
        'status': status,
        'last_error': lastError,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      }..removeWhere((k, v) => v == null);

  @override
  String toString() => jsonEncode(toJson());
}
