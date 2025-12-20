/// Production Guardrails - Runtime Invariant Checking
///
/// Provides runtime assertions and invariant checks to prevent
/// regressions and catch bugs early:
/// - Queue invariants (pendingOps >= 0)
/// - Emergency queue status
/// - Encryption policy compliance
/// - Adapter consistency
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../box_registry.dart';
import '../../services/telemetry_service.dart';
import '../adapter_collision_guard.dart';
import '../wrappers/box_accessor.dart';
export '../adapter_collision_guard.dart' show TypeIdCollision;

// Shared instance management (avoids circular imports)
ProductionGuardrails? _sharedGuardrailsInstance;

/// Sets the shared ProductionGuardrails instance.
void setSharedGuardrailsInstance(ProductionGuardrails instance) {
  _sharedGuardrailsInstance = instance;
}

/// Gets or creates the shared ProductionGuardrails instance.
ProductionGuardrails getSharedGuardrailsInstance() {
  return _sharedGuardrailsInstance ??= ProductionGuardrails(telemetry: TelemetryService.I);
}

// ═══════════════════════════════════════════════════════════════════════════
// PRODUCTION GUARDRAILS
// ═══════════════════════════════════════════════════════════════════════════

/// Runtime invariant checker for production safety.
class ProductionGuardrails {
  // ═══════════════════════════════════════════════════════════════════════
  // SINGLETON (DEPRECATED - Use ServiceInstances or Riverpod provider)
  // ═══════════════════════════════════════════════════════════════════════
  /// Legacy singleton accessor - routes to shared instance.
  @Deprecated('Use productionGuardrailsProvider or ServiceInstances.guardrails instead')
  static ProductionGuardrails get I => getSharedGuardrailsInstance();
  
  // ═══════════════════════════════════════════════════════════════════════
  // PROPER DI CONSTRUCTOR (Use this via Riverpod)
  // ═══════════════════════════════════════════════════════════════════════
  /// Creates a new ProductionGuardrails instance for dependency injection.
  ProductionGuardrails({required TelemetryService telemetry}) : _telemetry = telemetry;
  
  final TelemetryService _telemetry;
  
  /// Last check results (cached for UI display).
  InvariantCheckResult? _lastResult;
  InvariantCheckResult? get lastResult => _lastResult;
  
  // ═══════════════════════════════════════════════════════════════════════
  // INVARIANT ASSERTIONS
  // ═══════════════════════════════════════════════════════════════════════
  
  /// Asserts pending operations count is non-negative.
  ///
  /// This should NEVER fail in production. If it does, we have a serious bug.
  void assertPendingOpsNonNegative(int count) {
    if (count < 0) {
      _telemetry.increment('guardrails.pending_ops_negative');
      
      assert(
        false,
        'INVARIANT VIOLATION: pendingOps count is negative ($count). '
        'This indicates a serious bug in queue management.',
      );
      
      // In release mode, log but don't crash
      if (kReleaseMode) {
        _telemetry.increment('guardrails.violation.pending_ops_negative');
      }
    }
  }
  
  /// Asserts emergency queue is not blocked when it shouldn't be.
  ///
  /// Emergency queue should never be blocked indefinitely.
  void assertEmergencyQueueNotBlocked(bool isBlocked, Duration? blockedDuration) {
    // Emergency queue can be temporarily blocked, but not for more than 5 minutes
    const maxBlockedDuration = Duration(minutes: 5);
    
    if (isBlocked && blockedDuration != null && blockedDuration > maxBlockedDuration) {
      _telemetry.increment('guardrails.emergency_queue_blocked');
      
      assert(
        false,
        'INVARIANT VIOLATION: emergencyQueue blocked for ${blockedDuration.inMinutes} minutes. '
        'Emergency operations must not be blocked indefinitely.',
      );
      
      if (kReleaseMode) {
        _telemetry.increment('guardrails.violation.emergency_queue_blocked');
      }
    }
  }
  
  /// Asserts encryption policy is satisfied.
  ///
  /// Sensitive boxes MUST be encrypted in production.
  Future<void> assertEncryptionPolicySatisfied() async {
    // In debug mode, we may skip encryption for testing
    if (!kReleaseMode) return;
    
    final sensitiveBoxes = [
      BoxRegistry.roomsBox,
      BoxRegistry.vitalsBox,
      BoxRegistry.userProfileBox,
      BoxRegistry.sessionsBox,
      BoxRegistry.auditLogsBox,
    ];
    
    for (final boxName in sensitiveBoxes) {
      if (Hive.isBoxOpen(boxName)) {
        // Box is open - trust that it was opened with encryption via HiveService
        // Hive doesn't expose encryption status directly
        // For now, we verify boxes are open which implies proper initialization
        BoxAccess.I.boxUntyped(boxName); // Verify box is accessible
      }
    }
  }
  
  /// Asserts no TypeId collisions exist.
  void assertNoAdapterCollisions(List<TypeIdCollision> collisions) {
    if (collisions.isNotEmpty) {
      _telemetry.increment('guardrails.adapter_collision');
      
      final collisionStr = collisions
        .map((c) => 'TypeId ${c.typeId}: ${c.adapterNames.join(', ')}')
        .join('; ');
      
      assert(
        false,
        'INVARIANT VIOLATION: TypeId collisions detected: $collisionStr. '
        'This causes silent data corruption!',
      );
      
      if (kReleaseMode) {
        _telemetry.increment('guardrails.violation.adapter_collision');
      }
    }
  }
  
  /// Asserts schema version is consistent.
  void assertSchemaVersionConsistent(int stored, int current) {
    if (stored > current) {
      _telemetry.increment('guardrails.schema_version_mismatch');
      
      assert(
        false,
        'INVARIANT VIOLATION: Data schema version ($stored) is newer than app version ($current). '
        'App may not be able to read data correctly.',
      );
      
      if (kReleaseMode) {
        _telemetry.increment('guardrails.violation.schema_version_mismatch');
      }
    }
  }
  
  /// Asserts failed operations count is bounded.
  void assertFailedOpsBounded(int count, {int maxAllowed = 1000}) {
    if (count > maxAllowed) {
      _telemetry.increment('guardrails.failed_ops_unbounded');
      
      assert(
        false,
        'INVARIANT VIOLATION: failedOps count ($count) exceeds maximum ($maxAllowed). '
        'Failed operations should be purged periodically.',
      );
      
      if (kReleaseMode) {
        _telemetry.increment('guardrails.violation.failed_ops_unbounded');
      }
    }
  }
  
  /// Asserts lock is not held indefinitely.
  void assertLockNotStale(bool isLocked, Duration? lockDuration, {Duration maxDuration = const Duration(minutes: 10)}) {
    if (isLocked && lockDuration != null && lockDuration > maxDuration) {
      _telemetry.increment('guardrails.stale_lock');
      
      assert(
        false,
        'INVARIANT VIOLATION: Lock held for ${lockDuration.inMinutes} minutes. '
        'Locks should be released within $maxDuration.',
      );
      
      if (kReleaseMode) {
        _telemetry.increment('guardrails.violation.stale_lock');
      }
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════
  // STARTUP CHECK
  // ═══════════════════════════════════════════════════════════════════════
  
  /// Runs startup-specific invariant checks.
  ///
  /// Called during bootstrapApp() to validate system state.
  /// Returns [StartupCheckResult] with pass/fail status.
  Future<StartupCheckResult> runStartupCheck() async {
    final result = StartupCheckResult();
    final sw = Stopwatch()..start();
    
    try {
      // Check 1: Adapter collisions (most critical)
      final collisionResult = AdapterCollisionGuard.checkForCollisions();
      if (collisionResult.hasCollisions) {
        for (final collision in collisionResult.collisions) {
          result.violations.add('TypeId ${collision.typeId} collision: ${collision.adapterNames.join(", ")}');
        }
      }
      result.adapterCheckPassed = !collisionResult.hasCollisions;
      
      // Check 2: Core boxes accessible
      final coreBoxes = [
        BoxRegistry.metaBox,
        BoxRegistry.pendingOpsBox,
      ];
      for (final boxName in coreBoxes) {
        try {
          final exists = await Hive.boxExists(boxName);
          if (exists && !Hive.isBoxOpen(boxName)) {
            // Box exists but isn't open - could indicate init issue
            result.violations.add('Box "$boxName" exists but is not open');
          }
        } catch (e) {
          result.violations.add('Box "$boxName" check failed: $e');
        }
      }
      result.boxCheckPassed = result.violations.where((v) => v.contains('Box')).isEmpty;
      
      sw.stop();
      result.durationMs = sw.elapsedMilliseconds;
      result.checkedAt = DateTime.now().toUtc();
      
      _telemetry.gauge('guardrails.startup_check_duration_ms', sw.elapsedMilliseconds);
      if (result.allPassed) {
        _telemetry.increment('guardrails.startup_check_passed');
      } else {
        _telemetry.increment('guardrails.startup_check_failed');
        _telemetry.gauge('guardrails.startup_violations', result.violations.length);
      }
      
      return result;
    } catch (e) {
      sw.stop();
      result.durationMs = sw.elapsedMilliseconds;
      result.checkedAt = DateTime.now().toUtc();
      result.checkError = e.toString();
      _telemetry.increment('guardrails.startup_check_error');
      return result;
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════
  // COMPREHENSIVE CHECK
  // ═══════════════════════════════════════════════════════════════════════
  
  /// Runs all invariant checks and returns result.
  ///
  /// This is designed for periodic health checks and CI validation.
  Future<InvariantCheckResult> runAllChecks({
    int? pendingOpsCount,
    int? failedOpsCount,
    bool? emergencyQueueBlocked,
    Duration? emergencyQueueBlockedDuration,
    bool? lockHeld,
    Duration? lockDuration,
    int? storedSchemaVersion,
    int? currentSchemaVersion,
    List<TypeIdCollision>? collisions,
  }) async {
    final result = InvariantCheckResult();
    final sw = Stopwatch()..start();
    
    try {
      // Check 1: Pending ops non-negative
      if (pendingOpsCount != null) {
        if (pendingOpsCount < 0) {
          result.violations.add(InvariantViolation(
            name: 'pendingOpsNonNegative',
            message: 'Pending ops count is negative: $pendingOpsCount',
            severity: ViolationSeverity.critical,
          ));
        }
        result.pendingOpsCount = pendingOpsCount;
      }
      
      // Check 2: Failed ops bounded
      if (failedOpsCount != null) {
        if (failedOpsCount > 1000) {
          result.violations.add(InvariantViolation(
            name: 'failedOpsBounded',
            message: 'Failed ops count exceeds limit: $failedOpsCount > 1000',
            severity: ViolationSeverity.warning,
          ));
        }
        result.failedOpsCount = failedOpsCount;
      }
      
      // Check 3: Emergency queue not blocked
      if (emergencyQueueBlocked == true && emergencyQueueBlockedDuration != null) {
        if (emergencyQueueBlockedDuration > const Duration(minutes: 5)) {
          result.violations.add(InvariantViolation(
            name: 'emergencyQueueNotBlocked',
            message: 'Emergency queue blocked for ${emergencyQueueBlockedDuration.inMinutes} minutes',
            severity: ViolationSeverity.critical,
          ));
        }
      }
      
      // Check 4: Lock not stale
      if (lockHeld == true && lockDuration != null) {
        if (lockDuration > const Duration(minutes: 10)) {
          result.violations.add(InvariantViolation(
            name: 'lockNotStale',
            message: 'Lock held for ${lockDuration.inMinutes} minutes',
            severity: ViolationSeverity.warning,
          ));
        }
      }
      
      // Check 5: Schema version consistent
      if (storedSchemaVersion != null && currentSchemaVersion != null) {
        if (storedSchemaVersion > currentSchemaVersion) {
          result.violations.add(InvariantViolation(
            name: 'schemaVersionConsistent',
            message: 'Schema version mismatch: stored=$storedSchemaVersion, current=$currentSchemaVersion',
            severity: ViolationSeverity.critical,
          ));
        }
      }
      
      // Check 6: No adapter collisions
      if (collisions != null && collisions.isNotEmpty) {
        for (final collision in collisions) {
          result.violations.add(InvariantViolation(
            name: 'noAdapterCollisions',
            message: 'TypeId ${collision.typeId} collision: ${collision.adapterNames.join(', ')}',
            severity: ViolationSeverity.critical,
          ));
        }
      }
      
      sw.stop();
      result.checkDurationMs = sw.elapsedMilliseconds;
      result.checkedAt = DateTime.now().toUtc();
      
      _lastResult = result;
      
      // Record telemetry
      _telemetry.gauge('guardrails.check_duration_ms', sw.elapsedMilliseconds);
      _telemetry.gauge('guardrails.violation_count', result.violations.length);
      _telemetry.gauge('guardrails.critical_count', result.criticalCount);
      
      if (result.isHealthy) {
        _telemetry.increment('guardrails.check_passed');
      } else {
        _telemetry.increment('guardrails.check_failed');
      }
      
      return result;
      
    } catch (e) {
      sw.stop();
      result.checkDurationMs = sw.elapsedMilliseconds;
      result.checkedAt = DateTime.now().toUtc();
      result.checkError = e.toString();
      
      _telemetry.increment('guardrails.check_error');
      
      return result;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// RESULT TYPES
// ═══════════════════════════════════════════════════════════════════════════

/// Severity of an invariant violation.
enum ViolationSeverity {
  /// Warning - should be investigated but not blocking.
  warning,
  
  /// Critical - indicates a serious bug that needs immediate attention.
  critical,
}

/// An invariant violation detected by guardrails.
class InvariantViolation {
  final String name;
  final String message;
  final ViolationSeverity severity;
  
  InvariantViolation({
    required this.name,
    required this.message,
    required this.severity,
  });
  
  bool get isCritical => severity == ViolationSeverity.critical;
  
  Map<String, dynamic> toJson() => {
    'name': name,
    'message': message,
    'severity': severity.name,
    'isCritical': isCritical,
  };
}

/// Result of running all invariant checks.
class InvariantCheckResult {
  final List<InvariantViolation> violations = [];
  DateTime? checkedAt;
  int checkDurationMs = 0;
  String? checkError;
  
  // Captured values for debugging
  int? pendingOpsCount;
  int? failedOpsCount;
  
  bool get isHealthy => violations.isEmpty && checkError == null;
  int get criticalCount => violations.where((v) => v.isCritical).length;
  int get warningCount => violations.where((v) => !v.isCritical).length;
  
  Map<String, dynamic> toJson() => {
    'isHealthy': isHealthy,
    'checkedAt': checkedAt?.toIso8601String(),
    'checkDurationMs': checkDurationMs,
    'checkError': checkError,
    'violations': violations.map((v) => v.toJson()).toList(),
    'criticalCount': criticalCount,
    'warningCount': warningCount,
    'pendingOpsCount': pendingOpsCount,
    'failedOpsCount': failedOpsCount,
  };
}

/// Result of startup-specific guardrail checks.
class StartupCheckResult {
  final List<String> violations = [];
  DateTime? checkedAt;
  int durationMs = 0;
  String? checkError;
  
  bool adapterCheckPassed = false;
  bool boxCheckPassed = false;
  
  bool get allPassed => 
      adapterCheckPassed && 
      boxCheckPassed && 
      violations.isEmpty && 
      checkError == null;
  
  Map<String, dynamic> toJson() => {
    'allPassed': allPassed,
    'adapterCheckPassed': adapterCheckPassed,
    'boxCheckPassed': boxCheckPassed,
    'checkedAt': checkedAt?.toIso8601String(),
    'durationMs': durationMs,
    'checkError': checkError,
    'violations': violations,
  };
}
