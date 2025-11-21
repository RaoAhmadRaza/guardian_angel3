import 'package:hive/hive.dart';

part 'sync_failure.g.dart';

/// Represents a sync failure that requires user attention
@HiveType(typeId: 24)
class SyncFailure {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String entityType;

  @HiveField(2)
  final String entityId;

  @HiveField(3)
  final String operation;

  @HiveField(4)
  final String reason;

  @HiveField(5)
  final String errorMessage;

  @HiveField(6)
  final DateTime firstFailedAt;

  @HiveField(7)
  final DateTime lastAttemptAt;

  @HiveField(8)
  final int retryCount;

  @HiveField(9)
  final SyncFailureStatus status;

  @HiveField(10)
  final Map<String, dynamic> metadata;

  @HiveField(11)
  final String? userId;

  @HiveField(12)
  final SyncFailureSeverity severity;

  @HiveField(13)
  final bool requiresUserAction;

  @HiveField(14)
  final String? suggestedAction;

  @HiveField(15)
  final DateTime? resolvedAt;

  @HiveField(16)
  final String? resolutionNote;

  SyncFailure({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.reason,
    required this.errorMessage,
    required this.firstFailedAt,
    required this.lastAttemptAt,
    this.retryCount = 0,
    this.status = SyncFailureStatus.pending,
    this.metadata = const {},
    this.userId,
    this.severity = SyncFailureSeverity.medium,
    this.requiresUserAction = false,
    this.suggestedAction,
    this.resolvedAt,
    this.resolutionNote,
  });

  /// Create a copy with updated fields
  SyncFailure copyWith({
    String? id,
    String? entityType,
    String? entityId,
    String? operation,
    String? reason,
    String? errorMessage,
    DateTime? firstFailedAt,
    DateTime? lastAttemptAt,
    int? retryCount,
    SyncFailureStatus? status,
    Map<String, dynamic>? metadata,
    String? userId,
    SyncFailureSeverity? severity,
    bool? requiresUserAction,
    String? suggestedAction,
    DateTime? resolvedAt,
    String? resolutionNote,
  }) {
    return SyncFailure(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      operation: operation ?? this.operation,
      reason: reason ?? this.reason,
      errorMessage: errorMessage ?? this.errorMessage,
      firstFailedAt: firstFailedAt ?? this.firstFailedAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      retryCount: retryCount ?? this.retryCount,
      status: status ?? this.status,
      metadata: metadata ?? this.metadata,
      userId: userId ?? this.userId,
      severity: severity ?? this.severity,
      requiresUserAction: requiresUserAction ?? this.requiresUserAction,
      suggestedAction: suggestedAction ?? this.suggestedAction,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolutionNote: resolutionNote ?? this.resolutionNote,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'entityType': entityType,
        'entityId': entityId,
        'operation': operation,
        'reason': reason,
        'errorMessage': errorMessage,
        'firstFailedAt': firstFailedAt.toIso8601String(),
        'lastAttemptAt': lastAttemptAt.toIso8601String(),
        'retryCount': retryCount,
        'status': status.toString(),
        'metadata': metadata,
        'userId': userId,
        'severity': severity.toString(),
        'requiresUserAction': requiresUserAction,
        'suggestedAction': suggestedAction,
        'resolvedAt': resolvedAt?.toIso8601String(),
        'resolutionNote': resolutionNote,
      };

  /// Create from JSON
  factory SyncFailure.fromJson(Map<String, dynamic> json) {
    return SyncFailure(
      id: json['id'] as String,
      entityType: json['entityType'] as String,
      entityId: json['entityId'] as String,
      operation: json['operation'] as String,
      reason: json['reason'] as String,
      errorMessage: json['errorMessage'] as String,
      firstFailedAt: DateTime.parse(json['firstFailedAt'] as String),
      lastAttemptAt: DateTime.parse(json['lastAttemptAt'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
      status: _parseStatus(json['status'] as String?),
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ?? {},
      userId: json['userId'] as String?,
      severity: _parseSeverity(json['severity'] as String?),
      requiresUserAction: json['requiresUserAction'] as bool? ?? false,
      suggestedAction: json['suggestedAction'] as String?,
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.parse(json['resolvedAt'] as String)
          : null,
      resolutionNote: json['resolutionNote'] as String?,
    );
  }

  static SyncFailureStatus _parseStatus(String? value) {
    switch (value) {
      case 'SyncFailureStatus.pending':
      case 'pending':
        return SyncFailureStatus.pending;
      case 'SyncFailureStatus.retrying':
      case 'retrying':
        return SyncFailureStatus.retrying;
      case 'SyncFailureStatus.failed':
      case 'failed':
        return SyncFailureStatus.failed;
      case 'SyncFailureStatus.resolved':
      case 'resolved':
        return SyncFailureStatus.resolved;
      case 'SyncFailureStatus.dismissed':
      case 'dismissed':
        return SyncFailureStatus.dismissed;
      default:
        return SyncFailureStatus.pending;
    }
  }

  static SyncFailureSeverity _parseSeverity(String? value) {
    switch (value) {
      case 'SyncFailureSeverity.low':
      case 'low':
        return SyncFailureSeverity.low;
      case 'SyncFailureSeverity.medium':
      case 'medium':
        return SyncFailureSeverity.medium;
      case 'SyncFailureSeverity.high':
      case 'high':
        return SyncFailureSeverity.high;
      case 'SyncFailureSeverity.critical':
      case 'critical':
        return SyncFailureSeverity.critical;
      default:
        return SyncFailureSeverity.medium;
    }
  }

  /// Check if this failure is stale (no retry in last 24 hours)
  bool get isStale {
    return DateTime.now().difference(lastAttemptAt) > const Duration(hours: 24);
  }

  /// Check if this failure has exceeded max retries
  bool hasExceededMaxRetries(int maxRetries) {
    return retryCount >= maxRetries;
  }

  /// Get human-readable age
  String get ageDescription {
    final diff = DateTime.now().difference(firstFailedAt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}

/// Status of a sync failure
@HiveType(typeId: 25)
enum SyncFailureStatus {
  @HiveField(0)
  pending, // Awaiting retry

  @HiveField(1)
  retrying, // Currently being retried

  @HiveField(2)
  failed, // Permanently failed (max retries exceeded)

  @HiveField(3)
  resolved, // Successfully resolved

  @HiveField(4)
  dismissed, // Dismissed by user
}

/// Severity level of sync failures
@HiveType(typeId: 26)
enum SyncFailureSeverity {
  @HiveField(0)
  low, // Minor inconvenience, can be ignored

  @HiveField(1)
  medium, // Should be addressed but not urgent

  @HiveField(2)
  high, // Important, requires attention soon

  @HiveField(3)
  critical, // Urgent, blocks critical functionality
}
