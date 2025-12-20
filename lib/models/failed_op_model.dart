import 'package:uuid/uuid.dart';
import 'pending_op.dart';

class FailedOpModel {
  final String id;
  final String? sourcePendingOpId;
  final String opType;
  final Map<String, dynamic> payload;
  final String? errorCode;
  final String? errorMessage;
  final String? idempotencyKey; // preserved for re-enqueue
  final int attempts;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FailedOpModel({
    required this.id,
    this.sourcePendingOpId,
    required this.opType,
    required this.payload,
    this.errorCode,
    this.errorMessage,
    this.idempotencyKey,
    required this.attempts,
    required this.archived,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a FailedOpModel from a PendingOp that exceeded max attempts.
  ///
  /// This preserves the original op's data for debugging and potential
  /// manual re-enqueue.
  factory FailedOpModel.fromPendingOp(
    PendingOp op, {
    String? errorCode,
    String? errorMessage,
  }) {
    final now = DateTime.now().toUtc();
    return FailedOpModel(
      id: const Uuid().v4(),
      sourcePendingOpId: op.id,
      opType: op.opType,
      payload: op.payload,
      errorCode: errorCode,
      errorMessage: errorMessage ?? op.lastError,
      idempotencyKey: op.idempotencyKey,
      attempts: op.attempts,
      archived: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory FailedOpModel.fromJson(Map<String, dynamic> json) => FailedOpModel(
        id: json['id'] as String,
        sourcePendingOpId: json['source_pending_op_id'] as String?,
        opType: json['op_type'] as String,
        payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
        errorCode: json['error_code'] as String?,
        errorMessage: json['error_message'] as String?,
        idempotencyKey: json['idempotency_key'] as String?,
        attempts: (json['attempts'] as num).toInt(),
        archived: json['archived'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
        updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'source_pending_op_id': sourcePendingOpId,
        'op_type': opType,
        'payload': payload,
        'error_code': errorCode,
        'error_message': errorMessage,
        'idempotency_key': idempotencyKey,
        'attempts': attempts,
        'archived': archived,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      }..removeWhere((k, v) => v == null);
}