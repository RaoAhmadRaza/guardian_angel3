/// Automatic Compaction Scheduler
///
/// Runs periodic compaction (every 24 hours) with battery-awareness.
/// Part of FINAL 10% CLIMB Phase 2: Long-term survivability.
///
/// Features:
/// - 24-hour periodic compaction cycle
/// - Skips compaction when battery is low (<20%)
/// - Manual trigger support for testing
/// - Graceful stop on app shutdown
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../services/ttl_compaction_service.dart';
import '../../../services/audit_log_service.dart';

/// Battery level threshold below which compaction is skipped.
const int kBatteryLowThreshold = 20;

/// Default compaction interval (24 hours).
const Duration kCompactionInterval = Duration(hours: 24);

/// Battery status provider interface for testability.
abstract class BatteryStatusProvider {
  /// Returns current battery level (0-100) or null if unavailable.
  Future<int?> getBatteryLevel();
  
  /// Returns true if device is currently charging.
  Future<bool> isCharging();
}

/// Default battery provider that always allows compaction.
/// In production, this should be replaced with actual battery_plus integration.
class DefaultBatteryProvider implements BatteryStatusProvider {
  const DefaultBatteryProvider();
  
  @override
  Future<int?> getBatteryLevel() async => 100; // Always assume full
  
  @override
  Future<bool> isCharging() async => true; // Always assume charging
}

/// Result of a compaction attempt.
enum CompactionResult {
  /// Compaction completed successfully.
  success,
  
  /// Skipped due to low battery.
  skippedLowBattery,
  
  /// Skipped due to recent compaction.
  skippedRecent,
  
  /// Failed with error.
  failed,
  
  /// Scheduler not running.
  notRunning,
}

/// Automatic compaction scheduler with battery awareness.
///
/// Usage:
/// ```dart
/// final scheduler = AutoCompactionScheduler();
/// await scheduler.start();
/// // ... app runs ...
/// scheduler.stop();
/// ```
class AutoCompactionScheduler {
  /// Creates scheduler with optional custom dependencies.
  AutoCompactionScheduler({
    TtlCompactionService? compactionService,
    BatteryStatusProvider? batteryProvider,
    Duration? interval,
  })  : _compactionService = compactionService ?? TtlCompactionService(),
        _batteryProvider = batteryProvider ?? const DefaultBatteryProvider(),
        _interval = interval ?? kCompactionInterval;

  final TtlCompactionService _compactionService;
  final BatteryStatusProvider _batteryProvider;
  final Duration _interval;
  
  Timer? _timer;
  DateTime? _lastCompactionTime;
  bool _isRunning = false;
  int _totalRuns = 0;
  int _successfulRuns = 0;
  int _skippedRuns = 0;
  int _failedRuns = 0;

  /// Whether the scheduler is currently running.
  bool get isRunning => _isRunning;

  /// When the last compaction was performed.
  DateTime? get lastCompactionTime => _lastCompactionTime;

  /// Total number of compaction attempts.
  int get totalRuns => _totalRuns;

  /// Number of successful compactions.
  int get successfulRuns => _successfulRuns;

  /// Number of skipped compactions (battery, recent, etc.).
  int get skippedRuns => _skippedRuns;

  /// Number of failed compactions.
  int get failedRuns => _failedRuns;

  /// Starts the periodic compaction scheduler.
  ///
  /// Runs compaction immediately if [runImmediately] is true (default: false).
  Future<void> start({bool runImmediately = false}) async {
    if (_isRunning) {
      debugPrint('[AutoCompactionScheduler] Already running');
      return;
    }

    _isRunning = true;
    debugPrint('[AutoCompactionScheduler] Started with interval: $_interval');

    _timer = Timer.periodic(_interval, (_) => _runCompaction());

    if (runImmediately) {
      await _runCompaction();
    }

    AuditLogService.I.log(
      userId: 'system',
      action: 'auto_compaction_scheduler_started',
      metadata: {
        'interval_hours': _interval.inHours,
        'run_immediately': runImmediately,
      },
    );
  }

  /// Stops the scheduler.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    debugPrint('[AutoCompactionScheduler] Stopped');

    AuditLogService.I.log(
      userId: 'system',
      action: 'auto_compaction_scheduler_stopped',
      metadata: {
        'total_runs': _totalRuns,
        'successful_runs': _successfulRuns,
        'skipped_runs': _skippedRuns,
        'failed_runs': _failedRuns,
      },
    );
  }

  /// Manually triggers a compaction attempt.
  ///
  /// Respects battery check unless [forceBatteryOverride] is true.
  Future<CompactionResult> triggerManually({
    bool forceBatteryOverride = false,
  }) async {
    if (!_isRunning && !forceBatteryOverride) {
      return CompactionResult.notRunning;
    }
    return _runCompaction(forceBatteryOverride: forceBatteryOverride);
  }

  /// Internal compaction runner.
  Future<CompactionResult> _runCompaction({
    bool forceBatteryOverride = false,
  }) async {
    _totalRuns++;
    
    try {
      // Check battery unless override
      if (!forceBatteryOverride) {
        final shouldSkip = await _shouldSkipDueToBattery();
        if (shouldSkip) {
          _skippedRuns++;
          debugPrint('[AutoCompactionScheduler] Skipped: low battery');
          AuditLogService.I.log(
            userId: 'system',
            action: 'compaction_skipped_low_battery',
            metadata: {'run_number': _totalRuns},
          );
          return CompactionResult.skippedLowBattery;
        }
      }

      // Run compaction
      debugPrint('[AutoCompactionScheduler] Running compaction...');
      final result = await _compactionService.runMaintenance();
      
      _successfulRuns++;
      _lastCompactionTime = DateTime.now();
      
      AuditLogService.I.log(
        userId: 'system',
        action: 'compaction_completed',
        metadata: {
          'run_number': _totalRuns,
          'timestamp': _lastCompactionTime!.toIso8601String(),
          'purged': result['purged'],
          'compacted': result['compacted'],
        },
      );
      
      debugPrint('[AutoCompactionScheduler] Compaction completed');
      return CompactionResult.success;
      
    } catch (e, stackTrace) {
      _failedRuns++;
      debugPrint('[AutoCompactionScheduler] Compaction failed: $e');
      
      AuditLogService.I.log(
        userId: 'system',
        action: 'compaction_failed',
        metadata: {
          'run_number': _totalRuns,
          'error': e.toString(),
          'stack_trace': stackTrace.toString().split('\n').take(5).join('\n'),
        },
        severity: 'error',
      );
      
      return CompactionResult.failed;
    }
  }

  /// Checks if compaction should be skipped due to low battery.
  Future<bool> _shouldSkipDueToBattery() async {
    final isCharging = await _batteryProvider.isCharging();
    if (isCharging) {
      return false; // Don't skip if charging
    }

    final batteryLevel = await _batteryProvider.getBatteryLevel();
    if (batteryLevel == null) {
      return false; // Unknown battery, proceed with compaction
    }

    return batteryLevel < kBatteryLowThreshold;
  }

  /// Returns scheduler statistics.
  Map<String, dynamic> getStatistics() {
    return {
      'is_running': _isRunning,
      'interval_hours': _interval.inHours,
      'total_runs': _totalRuns,
      'successful_runs': _successfulRuns,
      'skipped_runs': _skippedRuns,
      'failed_runs': _failedRuns,
      'last_compaction_time': _lastCompactionTime?.toIso8601String(),
      'success_rate': _totalRuns > 0 
          ? (_successfulRuns / _totalRuns * 100).toStringAsFixed(1) 
          : 'N/A',
    };
  }
}

/// Global scheduler instance for app-wide access.
/// Initialized during bootstrap, stopped on app termination.
AutoCompactionScheduler? _globalScheduler;

/// Gets or creates the global auto-compaction scheduler.
AutoCompactionScheduler get globalAutoCompactionScheduler {
  _globalScheduler ??= AutoCompactionScheduler();
  return _globalScheduler!;
}

/// Sets a custom global scheduler (useful for testing).
void setGlobalAutoCompactionScheduler(AutoCompactionScheduler scheduler) {
  _globalScheduler?.stop();
  _globalScheduler = scheduler;
}

/// Disposes the global scheduler.
void disposeGlobalAutoCompactionScheduler() {
  _globalScheduler?.stop();
  _globalScheduler = null;
}
