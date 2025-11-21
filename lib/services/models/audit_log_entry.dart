import 'package:hive/hive.dart';

part 'audit_log_entry.g.dart';

/// Audit log entry for tracking security-sensitive operations
@HiveType(typeId: 33)
class AuditLogEntry {
  @HiveField(0)
  final String entryId;

  @HiveField(1)
  final DateTime timestamp;

  @HiveField(2)
  final String userId;

  @HiveField(3)
  final String action; // e.g., 'login', 'logout', 'data_access', 'permission_change'

  @HiveField(4)
  final String? entityType; // Optional: 'room', 'device', 'user', etc.

  @HiveField(5)
  final String? entityId; // Optional: specific entity ID

  @HiveField(6)
  final Map<String, dynamic> metadata; // Additional context

  @HiveField(7)
  final String severity; // 'info', 'warning', 'critical'

  @HiveField(8)
  final String? ipAddress;

  @HiveField(9)
  final String? deviceInfo;

  AuditLogEntry({
    required this.entryId,
    required this.timestamp,
    required this.userId,
    required this.action,
    this.entityType,
    this.entityId,
    required this.metadata,
    required this.severity,
    this.ipAddress,
    this.deviceInfo,
  });

  /// Create a redacted copy with PII masked
  AuditLogEntry redact({
    bool maskUserId = true,
    bool partialTimestamp = true,
    bool maskIpAddress = true,
    bool maskMetadata = true,
  }) {
    return AuditLogEntry(
      entryId: entryId,
      timestamp: partialTimestamp 
          ? DateTime(timestamp.year, timestamp.month, timestamp.day) 
          : timestamp,
      userId: maskUserId ? _maskUserId(userId) : userId,
      action: action,
      entityType: entityType,
      entityId: entityId,
      metadata: maskMetadata ? _redactMetadata(metadata) : metadata,
      severity: severity,
      ipAddress: maskIpAddress ? _maskIpAddress(ipAddress) : ipAddress,
      deviceInfo: deviceInfo, // Keep device info for analytics
    );
  }

  /// Mask user ID (show only first 4 chars)
  String _maskUserId(String userId) {
    if (userId.length <= 4) return '****';
    return '${userId.substring(0, 4)}${'*' * (userId.length - 4)}';
  }

  /// Mask IP address (keep first octet only)
  String? _maskIpAddress(String? ip) {
    if (ip == null) return null;
    final parts = ip.split('.');
    if (parts.length == 4) {
      return '${parts[0]}.xxx.xxx.xxx';
    }
    // IPv6 or other format - mask completely
    return 'xxx.xxx.xxx.xxx';
  }

  /// Redact sensitive metadata fields
  Map<String, dynamic> _redactMetadata(Map<String, dynamic> meta) {
    final redacted = <String, dynamic>{};
    final sensitiveKeys = {'password', 'token', 'secret', 'apiKey', 'email', 'phone'};
    
    for (final entry in meta.entries) {
      final key = entry.key.toLowerCase();
      if (sensitiveKeys.any((sensitive) => key.contains(sensitive))) {
        redacted[entry.key] = '[REDACTED]';
      } else {
        redacted[entry.key] = entry.value;
      }
    }
    
    return redacted;
  }

  /// Convert to JSON for export
  Map<String, dynamic> toJson() {
    return {
      'entryId': entryId,
      'timestamp': timestamp.toIso8601String(),
      'userId': userId,
      'action': action,
      'entityType': entityType,
      'entityId': entityId,
      'metadata': metadata,
      'severity': severity,
      'ipAddress': ipAddress,
      'deviceInfo': deviceInfo,
    };
  }

  /// Create from JSON
  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    return AuditLogEntry(
      entryId: json['entryId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      userId: json['userId'] as String,
      action: json['action'] as String,
      entityType: json['entityType'] as String?,
      entityId: json['entityId'] as String?,
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ?? {},
      severity: json['severity'] as String,
      ipAddress: json['ipAddress'] as String?,
      deviceInfo: json['deviceInfo'] as String?,
    );
  }
}

/// Archive metadata for tracking rotated log files
@HiveType(typeId: 34)
class AuditLogArchive {
  @HiveField(0)
  final String archiveId;

  @HiveField(1)
  final DateTime createdAt;

  @HiveField(2)
  final DateTime startDate; // First log entry date

  @HiveField(3)
  final DateTime endDate; // Last log entry date

  @HiveField(4)
  final int entryCount;

  @HiveField(5)
  final String filePath; // Path to encrypted archive file

  @HiveField(6)
  final int fileSizeBytes;

  @HiveField(7)
  final bool isEncrypted;

  @HiveField(8)
  final String checksum; // For integrity verification

  AuditLogArchive({
    required this.archiveId,
    required this.createdAt,
    required this.startDate,
    required this.endDate,
    required this.entryCount,
    required this.filePath,
    required this.fileSizeBytes,
    required this.isEncrypted,
    required this.checksum,
  });

  /// Check if archive is expired based on retention policy
  bool isExpired(Duration retentionPeriod) {
    final expiryDate = createdAt.add(retentionPeriod);
    return DateTime.now().isAfter(expiryDate);
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'archiveId': archiveId,
      'createdAt': createdAt.toIso8601String(),
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'entryCount': entryCount,
      'filePath': filePath,
      'fileSizeBytes': fileSizeBytes,
      'isEncrypted': isEncrypted,
      'checksum': checksum,
    };
  }

  /// Create from JSON
  factory AuditLogArchive.fromJson(Map<String, dynamic> json) {
    return AuditLogArchive(
      archiveId: json['archiveId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      entryCount: json['entryCount'] as int,
      filePath: json['filePath'] as String,
      fileSizeBytes: json['fileSizeBytes'] as int,
      isEncrypted: json['isEncrypted'] as bool,
      checksum: json['checksum'] as String,
    );
  }
}

/// Retention policy configuration
class RetentionPolicy {
  final Duration activePeriod; // How long to keep in active log
  final Duration archivePeriod; // How long to keep archived logs
  final int maxActiveEntries; // Max entries before forcing rotation
  final int maxArchiveFileSizeMB; // Max size per archive file

  const RetentionPolicy({
    required this.activePeriod,
    required this.archivePeriod,
    required this.maxActiveEntries,
    required this.maxArchiveFileSizeMB,
  });

  /// Default policy: 7 days active, 90 days archive
  static const RetentionPolicy standard = RetentionPolicy(
    activePeriod: Duration(days: 7),
    archivePeriod: Duration(days: 90),
    maxActiveEntries: 10000,
    maxArchiveFileSizeMB: 10,
  );

  /// Strict policy for sensitive data: 1 day active, 30 days archive
  static const RetentionPolicy strict = RetentionPolicy(
    activePeriod: Duration(days: 1),
    archivePeriod: Duration(days: 30),
    maxActiveEntries: 1000,
    maxArchiveFileSizeMB: 5,
  );

  /// Extended policy for compliance: 30 days active, 2 years archive
  static const RetentionPolicy compliance = RetentionPolicy(
    activePeriod: Duration(days: 30),
    archivePeriod: Duration(days: 730), // 2 years
    maxActiveEntries: 50000,
    maxArchiveFileSizeMB: 50,
  );
}

/// Redaction configuration
class RedactionConfig {
  final bool maskUserId;
  final bool partialTimestamp;
  final bool maskIpAddress;
  final bool maskMetadata;
  final Set<String> additionalSensitiveFields;

  const RedactionConfig({
    this.maskUserId = true,
    this.partialTimestamp = true,
    this.maskIpAddress = true,
    this.maskMetadata = true,
    this.additionalSensitiveFields = const {},
  });

  /// Standard redaction (mask most PII)
  static const RedactionConfig standard = RedactionConfig();

  /// No redaction (full export for legal review)
  static const RedactionConfig none = RedactionConfig(
    maskUserId: false,
    partialTimestamp: false,
    maskIpAddress: false,
    maskMetadata: false,
  );

  /// Minimal redaction (keep userId but mask IPs)
  static const RedactionConfig minimal = RedactionConfig(
    maskUserId: false,
    partialTimestamp: false,
    maskIpAddress: true,
    maskMetadata: true,
  );
}
