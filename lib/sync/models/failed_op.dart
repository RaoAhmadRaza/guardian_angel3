/// Represents a failed operation that couldn't be processed
/// 
/// Failed operations are moved from pending_ops to failed_ops queue
/// for manual review or automatic retry after reconciliation.
class FailedOp {
  /// Unique identifier (same as original PendingOp.id)
  final String id;

  /// Original operation data
  final Map<String, dynamic> operation;

  /// Error information
  final Map<String, dynamic> error;

  /// Number of attempts before failure
  final int attempts;

  /// When the operation failed (UTC)
  final DateTime failedAt;

  /// Optional: when to retry (for transient failures)
  final DateTime? retryAt;

  FailedOp({
    required this.id,
    required this.operation,
    required this.error,
    required this.attempts,
    DateTime? failedAt,
    this.retryAt,
  }) : failedAt = failedAt ?? DateTime.now().toUtc();

  /// Create FailedOp from stored map
  factory FailedOp.fromMap(Map<dynamic, dynamic> m) {
    return FailedOp(
      id: m['id'] as String,
      operation: Map<String, dynamic>.from(m['op'] as Map),
      error: Map<String, dynamic>.from(m['error'] as Map),
      attempts: m['attempts'] as int? ?? 0,
      failedAt: DateTime.parse(m['failed_at'] as String),
      retryAt: m['retry_at'] == null
          ? null
          : DateTime.parse(m['retry_at'] as String),
    );
  }

  /// Convert to map for Hive storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'op': operation,
      'error': error,
      'attempts': attempts,
      'failed_at': failedAt.toUtc().toIso8601String(),
      'retry_at': retryAt?.toUtc().toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'FailedOp(id: $id, attempts: $attempts, failedAt: $failedAt)';
  }
}
