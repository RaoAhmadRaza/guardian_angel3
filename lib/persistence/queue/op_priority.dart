/// Operation Priority Levels
///
/// Defines priority levels for pending operations.
/// Guardian Angel uses priority to ensure safety-critical operations
/// (SOS, fall detection) are processed before routine operations.
///
/// Processing order: emergency → high → normal → low
///
/// Emergency operations:
/// - Bypass normal backoff
/// - Use separate emergency queue
/// - Trigger immediate processing
library;

/// Priority levels for pending operations.
///
/// Order matters: lower index = higher priority.
enum OpPriority {
  /// Life-threatening situations requiring immediate attention.
  /// Examples: SOS triggered, fall detected, vital signs critical.
  /// 
  /// Special handling:
  /// - Ignores backoff completely
  /// - Uses emergency fast lane
  /// - Aggressive retry (short backoff)
  /// - Escalates to local alert if network unavailable
  emergency(0),

  /// Important but not immediately life-threatening.
  /// Examples: Medication confirmation, caregiver check-in due.
  ///
  /// Special handling:
  /// - Processed before normal ops
  /// - Standard backoff applies
  high(1),

  /// Standard operations.
  /// Examples: Room updates, device configuration changes.
  ///
  /// Standard queue processing with full backoff.
  normal(2),

  /// Low priority, can be delayed.
  /// Examples: Analytics, preference syncing, room rename.
  ///
  /// Processed only when no higher priority ops pending.
  low(3);

  /// Numeric value for sorting (lower = higher priority).
  final int value;

  const OpPriority(this.value);

  /// Compare priorities for sorting.
  /// Returns negative if this is higher priority than other.
  int compareTo(OpPriority other) => value.compareTo(other.value);

  /// Whether this priority level bypasses normal backoff.
  bool get bypassesBackoff => this == OpPriority.emergency;

  /// Whether this is a safety-critical priority level.
  bool get isSafetyCritical => this == OpPriority.emergency;

  /// Get human-readable display name.
  String get displayName {
    switch (this) {
      case OpPriority.emergency:
        return 'Emergency';
      case OpPriority.high:
        return 'High';
      case OpPriority.normal:
        return 'Normal';
      case OpPriority.low:
        return 'Low';
    }
  }

  /// Parse from string (case-insensitive).
  static OpPriority fromString(String value) {
    switch (value.toLowerCase()) {
      case 'emergency':
        return OpPriority.emergency;
      case 'high':
        return OpPriority.high;
      case 'normal':
        return OpPriority.normal;
      case 'low':
        return OpPriority.low;
      default:
        return OpPriority.normal;
    }
  }

  /// Convert to string for serialization.
  @override
  String toString() => name;
}

/// Extension methods for determining operation priority.
extension OpTypeToOpPriority on String {
  /// Determine priority from operation type.
  ///
  /// Maps known op types to appropriate priority levels.
  /// Unknown types default to normal priority.
  OpPriority get defaultOpPriority {
    switch (toLowerCase()) {
      // Emergency operations
      case 'sos':
      case 'sos_triggered':
      case 'fall_detected':
      case 'vital_critical':
      case 'emergency_alert':
      case 'panic_button':
        return OpPriority.emergency;

      // High priority operations
      case 'medication_confirm':
      case 'medication_missed':
      case 'caregiver_checkin':
      case 'vital_warning':
      case 'device_offline':
      case 'schedule_reminder':
        return OpPriority.high;

      // Low priority operations
      case 'room_rename':
      case 'preference_update':
      case 'analytics':
      case 'theme_change':
      case 'notification_settings':
        return OpPriority.low;

      // Default to normal
      default:
        return OpPriority.normal;
    }
  }
}
