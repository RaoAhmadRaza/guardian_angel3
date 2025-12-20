/// Audit Event Types
///
/// Canonical audit event types for the local backend.
/// All security-sensitive operations MUST use these types.
///
/// See also: docs/AUDIT_LOG_SYSTEM.md
library;

// ═══════════════════════════════════════════════════════════════════════════
// AUDIT TYPE ENUM
// ═══════════════════════════════════════════════════════════════════════════

/// Canonical audit event types.
///
/// Use these types for all audit logging to ensure consistency
/// and enable reliable searching/filtering.
enum AuditType {
  // ─────────────────────────────────────────────────────────────────────────
  // EMERGENCY & SAFETY
  // ─────────────────────────────────────────────────────────────────────────
  
  /// SOS triggered by user.
  sosTrigger,
  
  /// SOS cancelled by user.
  sosCancel,
  
  /// SOS delivered to cloud.
  sosDelivered,
  
  /// SOS escalated (cloud unreachable, local alert triggered).
  sosEscalated,
  
  /// Emergency operation enqueued.
  emergencyEnqueued,
  
  /// Emergency operation processed successfully.
  emergencyProcessed,
  
  /// Emergency operation escalated after max retries.
  emergencyEscalated,
  
  /// Safety fallback mode activated (network blackout).
  safetyFallbackActivated,
  
  /// Safety fallback mode deactivated.
  safetyFallbackDeactivated,
  
  /// Local alert triggered (fallback notification).
  localAlertTriggered,
  
  // ─────────────────────────────────────────────────────────────────────────
  // QUEUE OPERATIONS
  // ─────────────────────────────────────────────────────────────────────────
  
  /// Operation enqueued to pending queue.
  opEnqueued,
  
  /// Operation processed successfully.
  opProcessed,
  
  /// Operation failed and will be retried.
  opFailed,
  
  /// Operation became poison (exceeded max attempts).
  opPoisoned,
  
  /// Queue stall detected.
  queueStallDetected,
  
  /// Queue stall auto-recovered.
  queueStallRecovered,
  
  /// Queue paused (e.g., for auth).
  queuePaused,
  
  /// Queue resumed.
  queueResumed,
  
  // ─────────────────────────────────────────────────────────────────────────
  // REPAIR & ADMIN ACTIONS
  // ─────────────────────────────────────────────────────────────────────────
  
  /// Repair action started.
  repairStarted,
  
  /// Repair action completed.
  repairCompleted,
  
  /// Repair action failed.
  repairFailed,
  
  /// Index rebuilt.
  indexRebuilt,
  
  /// Stale lock released.
  staleLockReleased,
  
  /// Poison ops purged.
  poisonOpsPurged,
  
  // ─────────────────────────────────────────────────────────────────────────
  // SECURITY & ENCRYPTION
  // ─────────────────────────────────────────────────────────────────────────
  
  /// Secure erase initiated.
  secureEraseStarted,
  
  /// Secure erase completed.
  secureEraseCompleted,
  
  /// Encryption key rotated.
  encryptionKeyRotated,
  
  /// Encryption verification passed.
  encryptionVerified,
  
  /// Encryption verification failed.
  encryptionFailed,
  
  /// Data export initiated.
  dataExportStarted,
  
  /// Data export completed.
  dataExportCompleted,
  
  // ─────────────────────────────────────────────────────────────────────────
  // SYNC & CONFLICT
  // ─────────────────────────────────────────────────────────────────────────
  
  /// Sync started.
  syncStarted,
  
  /// Sync completed successfully.
  syncCompleted,
  
  /// Sync failed.
  syncFailed,
  
  /// Conflict detected.
  conflictDetected,
  
  /// Conflict resolved.
  conflictResolved,
  
  // ─────────────────────────────────────────────────────────────────────────
  // SESSION & AUTH
  // ─────────────────────────────────────────────────────────────────────────
  
  /// User session started.
  sessionStarted,
  
  /// User session ended.
  sessionEnded,
  
  /// Authentication succeeded.
  authSuccess,
  
  /// Authentication failed.
  authFailed,
  
  /// Token refreshed.
  tokenRefreshed,
}

extension AuditTypeExtension on AuditType {
  /// Get the action string for logging.
  String get action => name;
  
  /// Get the severity level (info, warning, critical).
  String get severity {
    switch (this) {
      // Critical - immediate attention required
      case AuditType.sosTrigger:
      case AuditType.sosEscalated:
      case AuditType.emergencyEscalated:
      case AuditType.localAlertTriggered:
      case AuditType.secureEraseStarted:
      case AuditType.secureEraseCompleted:
      case AuditType.encryptionFailed:
      case AuditType.repairFailed:
      case AuditType.authFailed:
        return 'critical';
      
      // Warning - should be monitored
      case AuditType.emergencyEnqueued:
      case AuditType.safetyFallbackActivated:
      case AuditType.opFailed:
      case AuditType.opPoisoned:
      case AuditType.queueStallDetected:
      case AuditType.queuePaused:
      case AuditType.repairStarted:
      case AuditType.staleLockReleased:
      case AuditType.poisonOpsPurged:
      case AuditType.conflictDetected:
      case AuditType.syncFailed:
        return 'warning';
      
      // Info - normal operations
      default:
        return 'info';
    }
  }
  
  /// Whether this event should always be logged (never filtered).
  bool get isMandatory {
    switch (this) {
      case AuditType.sosTrigger:
      case AuditType.sosCancel:
      case AuditType.sosDelivered:
      case AuditType.sosEscalated:
      case AuditType.emergencyEscalated:
      case AuditType.secureEraseStarted:
      case AuditType.secureEraseCompleted:
      case AuditType.repairStarted:
      case AuditType.repairCompleted:
      case AuditType.repairFailed:
      case AuditType.encryptionKeyRotated:
      case AuditType.authFailed:
        return true;
      default:
        return false;
    }
  }
  
  /// Get the entity type for this audit event.
  String get defaultEntityType {
    switch (this) {
      case AuditType.sosTrigger:
      case AuditType.sosCancel:
      case AuditType.sosDelivered:
      case AuditType.sosEscalated:
        return 'sos';
      
      case AuditType.emergencyEnqueued:
      case AuditType.emergencyProcessed:
      case AuditType.emergencyEscalated:
        return 'emergency_op';
      
      case AuditType.safetyFallbackActivated:
      case AuditType.safetyFallbackDeactivated:
      case AuditType.localAlertTriggered:
        return 'safety_fallback';
      
      case AuditType.opEnqueued:
      case AuditType.opProcessed:
      case AuditType.opFailed:
      case AuditType.opPoisoned:
        return 'pending_op';
      
      case AuditType.queueStallDetected:
      case AuditType.queueStallRecovered:
      case AuditType.queuePaused:
      case AuditType.queueResumed:
        return 'queue';
      
      case AuditType.repairStarted:
      case AuditType.repairCompleted:
      case AuditType.repairFailed:
      case AuditType.indexRebuilt:
      case AuditType.staleLockReleased:
      case AuditType.poisonOpsPurged:
        return 'repair_action';
      
      case AuditType.secureEraseStarted:
      case AuditType.secureEraseCompleted:
      case AuditType.encryptionKeyRotated:
      case AuditType.encryptionVerified:
      case AuditType.encryptionFailed:
        return 'security';
      
      case AuditType.dataExportStarted:
      case AuditType.dataExportCompleted:
        return 'data_export';
      
      case AuditType.syncStarted:
      case AuditType.syncCompleted:
      case AuditType.syncFailed:
        return 'sync';
      
      case AuditType.conflictDetected:
      case AuditType.conflictResolved:
        return 'conflict';
      
      case AuditType.sessionStarted:
      case AuditType.sessionEnded:
      case AuditType.authSuccess:
      case AuditType.authFailed:
      case AuditType.tokenRefreshed:
        return 'session';
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// AUDIT EVENT
// ═══════════════════════════════════════════════════════════════════════════

/// Structured audit event for logging.
///
/// Use this class to create standardized audit events.
class AuditEvent {
  /// The type of audit event.
  final AuditType type;
  
  /// User ID (required for traceability).
  final String userId;
  
  /// Entity ID (specific item affected).
  final String? entityId;
  
  /// Additional metadata.
  final Map<String, dynamic> metadata;
  
  /// Device information.
  final String? deviceInfo;
  
  /// IP address (for network operations).
  final String? ipAddress;
  
  const AuditEvent({
    required this.type,
    required this.userId,
    this.entityId,
    this.metadata = const {},
    this.deviceInfo,
    this.ipAddress,
  });
  
  /// Get the action string for this event.
  String get action => type.action;
  
  /// Get the severity for this event.
  String get severity => type.severity;
  
  /// Get the entity type for this event.
  String get entityType => type.defaultEntityType;
  
  /// Whether this event must always be logged.
  bool get isMandatory => type.isMandatory;
  
  // ─────────────────────────────────────────────────────────────────────────
  // FACTORY METHODS FOR COMMON EVENTS
  // ─────────────────────────────────────────────────────────────────────────
  
  /// Create an SOS trigger event.
  factory AuditEvent.sosTrigger({
    required String userId,
    required String sosId,
    String? location,
    String? deviceInfo,
  }) {
    return AuditEvent(
      type: AuditType.sosTrigger,
      userId: userId,
      entityId: sosId,
      metadata: {
        if (location != null) 'location': location,
        'triggered_at': DateTime.now().toUtc().toIso8601String(),
      },
      deviceInfo: deviceInfo,
    );
  }
  
  /// Create an emergency operation event.
  factory AuditEvent.emergency({
    required AuditType type,
    required String userId,
    required String opId,
    String? opType,
    String? error,
    int? attempts,
  }) {
    return AuditEvent(
      type: type,
      userId: userId,
      entityId: opId,
      metadata: {
        if (opType != null) 'op_type': opType,
        if (error != null) 'error': error,
        if (attempts != null) 'attempts': attempts,
      },
    );
  }
  
  /// Create a queue stall event.
  factory AuditEvent.queueStall({
    required AuditType type,
    required String userId,
    Duration? stallDuration,
    String? oldestOpId,
    int? pendingCount,
    bool? autoRecovered,
  }) {
    return AuditEvent(
      type: type,
      userId: userId,
      metadata: {
        if (stallDuration != null) 'stall_duration_seconds': stallDuration.inSeconds,
        if (oldestOpId != null) 'oldest_op_id': oldestOpId,
        if (pendingCount != null) 'pending_count': pendingCount,
        if (autoRecovered != null) 'auto_recovered': autoRecovered,
      },
    );
  }
  
  /// Create a repair action event.
  factory AuditEvent.repair({
    required AuditType type,
    required String userId,
    required String action,
    String? confirmationToken,
    int? affectedCount,
    String? error,
    Duration? duration,
  }) {
    return AuditEvent(
      type: type,
      userId: userId,
      entityId: confirmationToken,
      metadata: {
        'action': action,
        if (affectedCount != null) 'affected_count': affectedCount,
        if (error != null) 'error': error,
        if (duration != null) 'duration_ms': duration.inMilliseconds,
      },
    );
  }
  
  /// Create a secure erase event.
  factory AuditEvent.secureErase({
    required AuditType type,
    required String userId,
    required String reason,
    List<String>? boxesAffected,
    int? itemsErased,
  }) {
    return AuditEvent(
      type: type,
      userId: userId,
      metadata: {
        'reason': reason,
        if (boxesAffected != null) 'boxes_affected': boxesAffected,
        if (itemsErased != null) 'items_erased': itemsErased,
      },
    );
  }
}
