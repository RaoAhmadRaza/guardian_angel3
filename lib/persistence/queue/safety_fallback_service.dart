/// Safety-First Fallback Service
///
/// Handles scenarios where network is unavailable and emergency ops fail.
/// Triggers local alerts to caregivers without cloud dependency.
///
/// Fallback triggers:
/// - Emergency op fails N times
/// - Network unavailable for T minutes
/// - Total network blackout
/// - Backend outage
///
/// Actions:
/// - Local caregiver notification (push/alarm)
/// - Switch UI to "limited connectivity" safety mode
/// - Log escalation for audit
library;

import 'dart:async';
import 'package:hive/hive.dart';
import '../../models/pending_op.dart';
import '../../services/telemetry_service.dart';
import '../box_registry.dart';
import '../wrappers/box_accessor.dart';

/// Configuration for safety fallback thresholds.
class SafetyFallbackConfig {
  /// Max emergency op failures before local escalation.
  final int maxEmergencyFailures;
  
  /// Minutes of network unavailability before safety mode.
  final int networkUnavailableMinutes;
  
  /// Whether to use aggressive local notifications.
  final bool aggressiveAlerts;
  
  const SafetyFallbackConfig({
    this.maxEmergencyFailures = 3,
    this.networkUnavailableMinutes = 5,
    this.aggressiveAlerts = true,
  });
  
  static const defaultConfig = SafetyFallbackConfig();
}

/// Current safety state of the app.
enum SafetyMode {
  /// Normal operation - network available, all systems go.
  normal,
  
  /// Limited connectivity - some features degraded.
  limitedConnectivity,
  
  /// Emergency mode - critical features only, local alerts active.
  emergency,
  
  /// Offline safety mode - no network, local alerts triggered.
  offlineSafety,
}

/// Escalation type for audit logging.
enum EscalationType {
  emergencyOpFailed,
  networkUnavailable,
  manualTrigger,
  panicButton,
  vitalsCritical,
}

/// Record of an escalation event.
class EscalationRecord {
  final String id;
  final EscalationType type;
  final String? opId;
  final String? opType;
  final String reason;
  final DateTime timestamp;
  final bool acknowledged;
  
  const EscalationRecord({
    required this.id,
    required this.type,
    this.opId,
    this.opType,
    required this.reason,
    required this.timestamp,
    this.acknowledged = false,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'op_id': opId,
    'op_type': opType,
    'reason': reason,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'acknowledged': acknowledged,
  };
  
  factory EscalationRecord.fromJson(Map<String, dynamic> json) => EscalationRecord(
    id: json['id'] as String,
    type: EscalationType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => EscalationType.emergencyOpFailed,
    ),
    opId: json['op_id'] as String?,
    opType: json['op_type'] as String?,
    reason: json['reason'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String).toUtc(),
    acknowledged: json['acknowledged'] as bool? ?? false,
  );
}

/// Callback for local alert triggering.
typedef LocalAlertCallback = Future<void> Function(
  SafetyMode mode,
  String message,
  EscalationRecord? record,
);

/// Callback for UI mode changes.
typedef SafetyModeChangeCallback = void Function(SafetyMode newMode);

/// Safety-First Fallback Service.
///
/// Monitors network state and emergency op outcomes.
/// Triggers local escalation when cloud is unreachable.
class SafetyFallbackService {
  final SafetyFallbackConfig config;
  
  Box? _stateBox;
  bool _isInitialized = false;
  final TelemetryService _telemetry;
  
  /// Current safety mode.
  SafetyMode _currentMode = SafetyMode.normal;
  SafetyMode get currentMode => _currentMode;
  
  /// When network became unavailable.
  DateTime? _networkUnavailableSince;
  
  /// Emergency op failure count (since last success).
  int _emergencyFailureCount = 0;
  
  /// List of pending escalation records.
  final List<EscalationRecord> _escalationHistory = [];
  
  /// Callbacks for local alerts.
  LocalAlertCallback? onLocalAlert;
  
  /// Callback for UI mode changes.
  SafetyModeChangeCallback? onModeChange;
  
  /// Stream controller for safety mode changes.
  final _modeController = StreamController<SafetyMode>.broadcast();
  
  /// Stream of safety mode changes.
  Stream<SafetyMode> get modeStream => _modeController.stream;
  
  /// Timer for checking network timeout.
  Timer? _networkCheckTimer;
  
  SafetyFallbackService({
    this.config = SafetyFallbackConfig.defaultConfig,
    TelemetryService? telemetry,
  }) : _telemetry = telemetry ?? TelemetryService.I;

  /// Initialize the safety fallback service.
  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      if (!Hive.isBoxOpen(BoxRegistry.safetyStateBox)) {
        _stateBox = await Hive.openBox(BoxRegistry.safetyStateBox);
      } else {
        _stateBox = BoxAccess.I.safetyState();
      }
      
      // Restore state from persistence
      await _restoreState();
      
      // Start network timeout checker
      _startNetworkTimeoutChecker();
      
      _isInitialized = true;
      _telemetry.increment('safety_fallback.init');
    } catch (e) {
      _telemetry.increment('safety_fallback.init_error');
      rethrow;
    }
  }

  /// Restore state from Hive box.
  Future<void> _restoreState() async {
    final modeStr = _stateBox?.get('current_mode') as String?;
    if (modeStr != null) {
      _currentMode = SafetyMode.values.firstWhere(
        (m) => m.name == modeStr,
        orElse: () => SafetyMode.normal,
      );
    }
    
    final unavailableSinceStr = _stateBox?.get('network_unavailable_since') as String?;
    if (unavailableSinceStr != null) {
      _networkUnavailableSince = DateTime.tryParse(unavailableSinceStr)?.toUtc();
    }
    
    _emergencyFailureCount = _stateBox?.get('emergency_failure_count') as int? ?? 0;
    
    // Restore escalation history
    final historyJson = _stateBox?.get('escalation_history') as List?;
    if (historyJson != null) {
      _escalationHistory.clear();
      for (final item in historyJson) {
        try {
          _escalationHistory.add(EscalationRecord.fromJson(
            Map<String, dynamic>.from(item as Map),
          ));
        } catch (_) {
          // Skip invalid records
        }
      }
    }
  }

  /// Persist state to Hive box.
  Future<void> _persistState() async {
    await _stateBox?.put('current_mode', _currentMode.name);
    await _stateBox?.put(
      'network_unavailable_since', 
      _networkUnavailableSince?.toUtc().toIso8601String(),
    );
    await _stateBox?.put('emergency_failure_count', _emergencyFailureCount);
    await _stateBox?.put(
      'escalation_history',
      _escalationHistory.map((r) => r.toJson()).toList(),
    );
  }

  /// Report network availability state.
  Future<void> reportNetworkState({required bool isAvailable}) async {
    if (!_isInitialized) await init();
    
    if (isAvailable) {
      // Network restored
      _networkUnavailableSince = null;
      
      if (_currentMode == SafetyMode.limitedConnectivity ||
          _currentMode == SafetyMode.offlineSafety) {
        await _transitionMode(SafetyMode.normal);
      }
      
      _telemetry.increment('safety_fallback.network_restored');
    } else {
      // Network became unavailable
      _networkUnavailableSince ??= DateTime.now().toUtc();
      
      if (_currentMode == SafetyMode.normal) {
        await _transitionMode(SafetyMode.limitedConnectivity);
      }
      
      _telemetry.increment('safety_fallback.network_unavailable');
    }
    
    await _persistState();
  }

  /// Report emergency op processing result.
  Future<void> reportEmergencyOpResult(PendingOp op, {required bool success}) async {
    if (!_isInitialized) await init();
    
    if (success) {
      // Reset failure count on success
      _emergencyFailureCount = 0;
      
      if (_currentMode == SafetyMode.emergency) {
        await _transitionMode(SafetyMode.normal);
      }
      
      _telemetry.increment('safety_fallback.emergency_success');
    } else {
      // Increment failure count
      _emergencyFailureCount++;
      
      _telemetry.increment('safety_fallback.emergency_failure');
      _telemetry.gauge('safety_fallback.failure_count', _emergencyFailureCount);
      
      // Check if we need to escalate
      if (_emergencyFailureCount >= config.maxEmergencyFailures) {
        await _triggerEscalation(
          EscalationType.emergencyOpFailed,
          op: op,
          reason: 'Emergency operation failed ${_emergencyFailureCount} times',
        );
      }
    }
    
    await _persistState();
  }

  /// Start the network timeout checker.
  void _startNetworkTimeoutChecker() {
    _networkCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await _checkNetworkTimeout();
    });
  }

  /// Check if network has been unavailable too long.
  Future<void> _checkNetworkTimeout() async {
    if (_networkUnavailableSince == null) return;
    
    final duration = DateTime.now().toUtc().difference(_networkUnavailableSince!);
    final thresholdMinutes = config.networkUnavailableMinutes;
    
    if (duration.inMinutes >= thresholdMinutes) {
      if (_currentMode != SafetyMode.offlineSafety) {
        await _triggerEscalation(
          EscalationType.networkUnavailable,
          reason: 'Network unavailable for ${duration.inMinutes} minutes',
        );
      }
    }
  }

  /// Trigger an escalation event.
  Future<void> _triggerEscalation(
    EscalationType type, {
    PendingOp? op,
    required String reason,
  }) async {
    _telemetry.increment('safety_fallback.escalation.${type.name}');
    
    // Create escalation record
    final record = EscalationRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: type,
      opId: op?.id,
      opType: op?.opType,
      reason: reason,
      timestamp: DateTime.now().toUtc(),
    );
    
    _escalationHistory.add(record);
    
    // Keep history bounded
    while (_escalationHistory.length > 100) {
      _escalationHistory.removeAt(0);
    }
    
    // Determine new mode
    final newMode = type == EscalationType.networkUnavailable
        ? SafetyMode.offlineSafety
        : SafetyMode.emergency;
    
    await _transitionMode(newMode);
    
    // Trigger local alert
    await _triggerLocalAlert(
      _buildAlertMessage(type, op, reason),
      record,
    );
    
    await _persistState();
  }

  /// Build alert message for escalation.
  String _buildAlertMessage(EscalationType type, PendingOp? op, String reason) {
    switch (type) {
      case EscalationType.emergencyOpFailed:
        return 'EMERGENCY: ${op?.opType ?? 'Critical operation'} failed. $reason. '
            'Please check on the user immediately.';
      case EscalationType.networkUnavailable:
        return 'ALERT: Network unavailable. Device is in offline safety mode. '
            'Local monitoring is active but cloud sync is disabled.';
      case EscalationType.panicButton:
        return 'PANIC: User triggered panic button. Immediate assistance required.';
      case EscalationType.vitalsCritical:
        return 'CRITICAL: Vital signs are in critical range. '
            'Immediate medical attention may be required.';
      case EscalationType.manualTrigger:
        return 'ALERT: Safety mode manually triggered. $reason';
    }
  }

  /// Trigger local alert (notification, alarm, etc).
  Future<void> _triggerLocalAlert(String message, EscalationRecord record) async {
    // Log for audit
    // ignore: avoid_print
    print('[SafetyFallback] ALERT: $message');
    
    // Call callback if registered
    if (onLocalAlert != null) {
      try {
        await onLocalAlert!(_currentMode, message, record);
      } catch (e) {
        _telemetry.increment('safety_fallback.alert_callback_error');
      }
    }
  }

  /// Transition to a new safety mode.
  Future<void> _transitionMode(SafetyMode newMode) async {
    if (_currentMode == newMode) return;
    
    final oldMode = _currentMode;
    _currentMode = newMode;
    
    _telemetry.increment('safety_fallback.mode_change.${newMode.name}');
    
    _modeController.add(newMode);
    onModeChange?.call(newMode);
    
    // ignore: avoid_print
    print('[SafetyFallback] Mode changed: ${oldMode.name} → ${newMode.name}');
    
    await _persistState();
  }

  /// Manually trigger safety mode (for testing or user action).
  Future<void> triggerSafetyMode({required String reason}) async {
    await _triggerEscalation(
      EscalationType.manualTrigger,
      reason: reason,
    );
  }

  /// Acknowledge and reset safety mode.
  Future<void> acknowledgeSafetyMode() async {
    if (_currentMode != SafetyMode.normal) {
      _emergencyFailureCount = 0;
      await _transitionMode(SafetyMode.normal);
      
      _telemetry.increment('safety_fallback.acknowledged');
    }
  }

  /// Get escalation history.
  List<EscalationRecord> get escalationHistory => List.unmodifiable(_escalationHistory);

  /// Get unacknowledged escalations.
  List<EscalationRecord> get unacknowledgedEscalations =>
      _escalationHistory.where((r) => !r.acknowledged).toList();

  /// Check if currently in any safety mode.
  bool get isInSafetyMode => _currentMode != SafetyMode.normal;

  /// Get human-readable status message.
  String get statusMessage {
    switch (_currentMode) {
      case SafetyMode.normal:
        return 'All systems operational';
      case SafetyMode.limitedConnectivity:
        return 'Limited connectivity - some features may be delayed';
      case SafetyMode.emergency:
        return 'Emergency mode active - local alerts enabled';
      case SafetyMode.offlineSafety:
        return 'Offline safety mode - monitoring locally';
    }
  }

  /// Dispose resources.
  void dispose() {
    _networkCheckTimer?.cancel();
    _modeController.close();
  }
}
