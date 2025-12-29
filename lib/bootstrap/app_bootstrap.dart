/// App Bootstrap - Single Mandatory Startup Pipeline
///
/// This is the ONE AND ONLY entry point for app initialization.
/// All persistence, validation, and service initialization MUST go through
/// this function.
///
/// ❌ FORBIDDEN:
/// - Calling HiveService.init() directly from main.dart
/// - Calling ha_boot.mainCommon() without going through bootstrapApp()
/// - Initializing AuditLogService before bootstrapApp() completes
/// - Any persistence access before bootstrapApp() succeeds
///
/// ✅ REQUIRED ORDER:
/// 1. HiveService.init() - Core persistence
/// 2. SchemaValidator.verify() - Schema integrity
/// 3. AdapterCollisionGuard.assertNoCollisions() - TypeId safety
/// 4. LocalBackendBootstrap.initLocalBackend() - Full persistence stack
/// 5. AuditLogService.init() - Buffered audit flush
/// 6. Home Automation bridge (if needed)
///
/// On ANY failure: throws [FatalStartupError], app shows recovery UI.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../persistence/hive_service.dart';
import '../persistence/validation/schema_validator.dart';
import '../persistence/adapter_collision_guard.dart';
import '../persistence/guardrails/production_guardrails.dart';
import '../services/telemetry_service.dart';
import '../services/audit_log_service.dart';
import '../home automation/main.dart' as ha_boot;
import 'local_backend_bootstrap.dart';
import 'fatal_startup_error.dart';
import '../firebase/firebase_initializer.dart';

// ═══════════════════════════════════════════════════════════════════════════
// BOOTSTRAP STATE
// ═══════════════════════════════════════════════════════════════════════════

/// Tracks which phase of bootstrap we're in (for recovery/debugging).
enum BootstrapPhase {
  notStarted,
  hiveInit,
  schemaValidation,
  adapterGuard,
  localBackend,
  auditService,
  homeAutomation,
  firebase,
  completed,
  failed,
}

/// Current bootstrap state - exposed for debugging and recovery UI.
class BootstrapState {
  BootstrapPhase phase = BootstrapPhase.notStarted;
  DateTime? startedAt;
  DateTime? completedAt;
  FatalStartupError? error;
  final List<String> completedSteps = [];
  final List<String> bufferedAuditEvents = [];
  
  /// Total bootstrap duration in milliseconds.
  int? get durationMs => completedAt != null && startedAt != null
      ? completedAt!.difference(startedAt!).inMilliseconds
      : null;
  
  /// Whether bootstrap completed successfully.
  bool get isCompleted => phase == BootstrapPhase.completed;
  
  /// Whether bootstrap failed.
  bool get isFailed => phase == BootstrapPhase.failed;
  
  /// Human-readable status.
  String get statusMessage {
    switch (phase) {
      case BootstrapPhase.notStarted:
        return 'Not started';
      case BootstrapPhase.hiveInit:
        return 'Initializing database...';
      case BootstrapPhase.schemaValidation:
        return 'Validating schema...';
      case BootstrapPhase.adapterGuard:
        return 'Checking adapters...';
      case BootstrapPhase.localBackend:
        return 'Starting local backend...';
      case BootstrapPhase.auditService:
        return 'Initializing audit service...';
      case BootstrapPhase.homeAutomation:
        return 'Starting home automation...';
      case BootstrapPhase.firebase:
        return 'Initializing Firebase...';
      case BootstrapPhase.completed:
        return 'Ready (${durationMs}ms)';
      case BootstrapPhase.failed:
        return 'Failed: ${error?.message ?? "Unknown error"}';
    }
  }
  
  void reset() {
    phase = BootstrapPhase.notStarted;
    startedAt = null;
    completedAt = null;
    error = null;
    completedSteps.clear();
    bufferedAuditEvents.clear();
  }
}

/// Global bootstrap state - accessible for UI and debugging.
final bootstrapState = BootstrapState();

// ═══════════════════════════════════════════════════════════════════════════
// BOOTSTRAP FUNCTION
// ═══════════════════════════════════════════════════════════════════════════

/// The SINGLE MANDATORY ENTRY POINT for app initialization.
///
/// Call this ONCE from main() before runApp().
/// 
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await bootstrapApp();
///   runApp(const MyApp());
/// }
/// ```
///
/// On success: returns normally, app can proceed.
/// On failure: throws [FatalStartupError], app must show recovery UI.
Future<void> bootstrapApp({
  bool strict = true,
  bool skipHomeAutomation = false,
}) async {
  // Prevent double-initialization
  if (bootstrapState.isCompleted) {
    TelemetryService.I.increment('bootstrap.skipped_already_completed');
    return;
  }
  
  // Reset state if retrying after failure
  if (bootstrapState.isFailed) {
    bootstrapState.reset();
  }
  
  bootstrapState.startedAt = DateTime.now();
  final sw = Stopwatch()..start();
  
  try {
    // ═════════════════════════════════════════════════════════════════════
    // PHASE 1: Hive Core Initialization
    // ═════════════════════════════════════════════════════════════════════
    bootstrapState.phase = BootstrapPhase.hiveInit;
    _bufferAuditEvent('bootstrap.phase.hive_init.started');
    
    try {
      final hiveService = await HiveService.create();
      await hiveService.init();
      bootstrapState.completedSteps.add('HiveService.init()');
      _bufferAuditEvent('bootstrap.phase.hive_init.completed');
    } catch (e, stackTrace) {
      throw FatalStartupError.hiveInit(
        details: 'Failed to initialize Hive database',
        cause: e,
        causeStackTrace: stackTrace,
      );
    }
    
    // ═════════════════════════════════════════════════════════════════════
    // PHASE 2: Schema Validation (BLOCKING)
    // ═════════════════════════════════════════════════════════════════════
    bootstrapState.phase = BootstrapPhase.schemaValidation;
    _bufferAuditEvent('bootstrap.phase.schema_validation.started');
    
    try {
      final schemaResult = await SchemaValidator.verify(
        strict: strict,
        telemetry: TelemetryService.I,
      );
      
      if (!schemaResult.isValid) {
        throw FatalStartupError.schemaValidation(
          details: schemaResult.errors.join('; '),
        );
      }
      
      bootstrapState.completedSteps.add('SchemaValidator.verify()');
      _bufferAuditEvent('bootstrap.phase.schema_validation.completed');
      
      if (schemaResult.warnings.isNotEmpty && kDebugMode) {
        print('[Bootstrap] Schema warnings: ${schemaResult.warnings}');
      }
    } on SchemaValidationException catch (e) {
      throw FatalStartupError.schemaValidation(
        details: e.result.errors.join('; '),
        cause: e,
      );
    }
    
    // ═════════════════════════════════════════════════════════════════════
    // PHASE 3: Adapter Collision Guard (BLOCKING)
    // ═════════════════════════════════════════════════════════════════════
    bootstrapState.phase = BootstrapPhase.adapterGuard;
    _bufferAuditEvent('bootstrap.phase.adapter_guard.started');
    
    try {
      final collisionResult = AdapterCollisionGuard.checkForCollisions();
      
      if (collisionResult.hasCollisions) {
        final collidingNames = collisionResult.collisions
            .expand((c) => c.adapterNames)
            .toList();
        
        throw FatalStartupError.adapterCollision(
          details: 'Found ${collisionResult.collisions.length} TypeId collision(s)',
          collidingAdapters: collidingNames,
        );
      }
      
      // Also call assertNoCollisions for dev-mode asserts
      AdapterCollisionGuard.assertNoCollisions();
      
      bootstrapState.completedSteps.add('AdapterCollisionGuard.checkForCollisions()');
      _bufferAuditEvent('bootstrap.phase.adapter_guard.completed');
    } catch (e) {
      if (e is FatalStartupError) rethrow;
      throw FatalStartupError.adapterCollision(
        details: e.toString(),
        collidingAdapters: [],
      );
    }
    
    // ═════════════════════════════════════════════════════════════════════
    // PHASE 4: Local Backend Bootstrap (Full Stack)
    // ═════════════════════════════════════════════════════════════════════
    bootstrapState.phase = BootstrapPhase.localBackend;
    _bufferAuditEvent('bootstrap.phase.local_backend.started');
    
    try {
      await initLocalBackend();
      bootstrapState.completedSteps.add('initLocalBackend()');
      _bufferAuditEvent('bootstrap.phase.local_backend.completed');
    } catch (e, stackTrace) {
      if (e is FatalStartupError) rethrow;
      throw FatalStartupError.localBackendBootstrap(
        details: e.toString(),
        cause: e,
        causeStackTrace: stackTrace,
      );
    }
    
    // ═════════════════════════════════════════════════════════════════════
    // PHASE 5: Audit Service Initialization (with buffered events flush)
    // ═════════════════════════════════════════════════════════════════════
    bootstrapState.phase = BootstrapPhase.auditService;
    _bufferAuditEvent('bootstrap.phase.audit_service.started');
    
    try {
      await AuditLogService.I.init();
      bootstrapState.completedSteps.add('AuditLogService.init()');
      
      // Flush all buffered audit events now that service is ready
      await _flushBufferedAuditEvents();
      _bufferAuditEvent('bootstrap.phase.audit_service.completed');
    } catch (e, stackTrace) {
      // Audit service failure is non-fatal in release, fatal in debug
      if (kDebugMode) {
        print('[Bootstrap] WARNING: AuditLogService init failed: $e');
        print(stackTrace);
      }
      TelemetryService.I.increment('bootstrap.audit_service.init_failed');
      // Don't throw - audit is important but not critical to app function
      bootstrapState.completedSteps.add('AuditLogService.init() [FAILED - continuing]');
    }
    
    // ═════════════════════════════════════════════════════════════════════
    // PHASE 6: Home Automation (optional, but uses shared Hive)
    // ═════════════════════════════════════════════════════════════════════
    if (!skipHomeAutomation) {
      bootstrapState.phase = BootstrapPhase.homeAutomation;
      _bufferAuditEvent('bootstrap.phase.home_automation.started');
      
      try {
        await ha_boot.mainCommon();
        bootstrapState.completedSteps.add('ha_boot.mainCommon()');
        _bufferAuditEvent('bootstrap.phase.home_automation.completed');
      } catch (e, stackTrace) {
        // Home automation failure is non-fatal - core app can still work
        if (kDebugMode) {
          print('[Bootstrap] WARNING: Home Automation init failed: $e');
          print(stackTrace);
        }
        TelemetryService.I.increment('bootstrap.home_automation.init_failed');
        bootstrapState.completedSteps.add('ha_boot.mainCommon() [FAILED - continuing]');
      }
    }
    
    // ═════════════════════════════════════════════════════════════════════
    // PHASE 7: Firebase Initialization (Non-blocking)
    // ═════════════════════════════════════════════════════════════════════
    bootstrapState.phase = BootstrapPhase.firebase;
    _bufferAuditEvent('bootstrap.phase.firebase.started');
    
    try {
      await FirebaseInitializer.initialize();
      bootstrapState.completedSteps.add('FirebaseInitializer.initialize()');
      _bufferAuditEvent('bootstrap.phase.firebase.completed');
    } catch (e, stackTrace) {
      // Firebase failure is non-fatal - app can work offline/without Firebase
      if (kDebugMode) {
        print('[Bootstrap] WARNING: Firebase init failed: $e');
        print(stackTrace);
      }
      TelemetryService.I.increment('bootstrap.firebase.init_failed');
      bootstrapState.completedSteps.add('FirebaseInitializer.initialize() [FAILED - continuing]');
    }
    
    // ═════════════════════════════════════════════════════════════════════
    // PHASE 8: Production Guardrails Startup Check
    // ═════════════════════════════════════════════════════════════════════
    try {
      final guardrailResult = await ProductionGuardrails.I.runStartupCheck();
      if (!guardrailResult.allPassed) {
        if (kDebugMode) {
          print('[Bootstrap] WARNING: Guardrail violations: ${guardrailResult.violations}');
        }
        TelemetryService.I.increment('bootstrap.guardrails.violations');
        // Log but don't fail - guardrails are advisory at startup
      }
      bootstrapState.completedSteps.add('ProductionGuardrails.runStartupCheck()');
    } catch (e) {
      if (kDebugMode) {
        print('[Bootstrap] WARNING: Guardrail check failed: $e');
      }
      // Non-fatal
    }
    
    // ═════════════════════════════════════════════════════════════════════
    // COMPLETE
    // ═════════════════════════════════════════════════════════════════════
    sw.stop();
    bootstrapState.phase = BootstrapPhase.completed;
    bootstrapState.completedAt = DateTime.now();
    
    TelemetryService.I.increment('bootstrap.success');
    TelemetryService.I.gauge('bootstrap.duration_ms', sw.elapsedMilliseconds);
    
    // Log final audit event
    try {
      await AuditLogService.I.log(
        userId: 'system',
        action: 'app_bootstrap_complete',
        metadata: {
          'duration_ms': sw.elapsedMilliseconds,
          'steps': bootstrapState.completedSteps,
        },
      );
    } catch (_) {
      // Ignore audit logging errors
    }
    
    print('[Bootstrap] ✅ App bootstrap complete in ${sw.elapsedMilliseconds}ms');
    print('[Bootstrap] Steps: ${bootstrapState.completedSteps.join(' → ')}');
    
  } catch (e, stackTrace) {
    sw.stop();
    bootstrapState.phase = BootstrapPhase.failed;
    
    if (e is FatalStartupError) {
      bootstrapState.error = e;
      e.logError();
      TelemetryService.I.increment(e.telemetryKey);
    } else {
      bootstrapState.error = FatalStartupError(
        message: 'Unexpected bootstrap failure: $e',
        component: 'AppBootstrap',
        cause: e,
        causeStackTrace: stackTrace,
      );
      if (kDebugMode) {
        print('[Bootstrap] ❌ FATAL ERROR: $e');
        print(stackTrace);
      }
      TelemetryService.I.increment('bootstrap.unexpected_failure');
    }
    
    rethrow;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BUFFERED AUDIT LOGGING
// ═══════════════════════════════════════════════════════════════════════════

/// Buffer audit events before AuditLogService is ready.
void _bufferAuditEvent(String event) {
  bootstrapState.bufferedAuditEvents.add(event);
  TelemetryService.I.increment(event);
}

/// Flush all buffered audit events to the AuditLogService.
Future<void> _flushBufferedAuditEvents() async {
  if (bootstrapState.bufferedAuditEvents.isEmpty) return;
  
  try {
    for (final event in bootstrapState.bufferedAuditEvents) {
      await AuditLogService.I.log(
        userId: 'system',
        action: event,
        severity: 'info',
        metadata: {'buffered': true, 'bootstrap_phase': true},
      );
    }
    TelemetryService.I.gauge(
      'bootstrap.audit_events_flushed',
      bootstrapState.bufferedAuditEvents.length,
    );
  } catch (e) {
    if (kDebugMode) {
      print('[Bootstrap] Failed to flush buffered audit events: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// RECOVERY HELPERS
// ═══════════════════════════════════════════════════════════════════════════

/// Attempts to recover from a bootstrap failure.
///
/// This should be called from a recovery UI when the user requests recovery.
Future<FatalErrorRecoveryResult> attemptRecovery() async {
  if (!bootstrapState.isFailed) {
    return FatalErrorRecoveryResult.failed;
  }
  
  TelemetryService.I.increment('bootstrap.recovery_attempted');
  
  try {
    // Reset state
    bootstrapState.reset();
    
    // Try bootstrap again
    await bootstrapApp();
    
    TelemetryService.I.increment('bootstrap.recovery_succeeded');
    return FatalErrorRecoveryResult.recovered;
  } catch (e) {
    TelemetryService.I.increment('bootstrap.recovery_failed');
    return FatalErrorRecoveryResult.failed;
  }
}

/// Reset for testing only - clears all bootstrap state.
@visibleForTesting
void resetBootstrapForTesting() {
  bootstrapState.reset();
  resetLocalBackendForTesting();
}
