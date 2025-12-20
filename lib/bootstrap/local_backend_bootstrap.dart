/// Local Backend Bootstrap
///
/// Single source of truth for initializing the entire local persistence layer.
/// This ensures:
/// - Hive is initialized exactly once
/// - All adapters are registered before any box is opened
/// - Encryption keys are loaded/created before encrypted boxes open
/// - Home Automation boxes use the same Hive instance and encryption
/// - TypeId collisions are detected at startup (Phase 2)
/// - Encryption policies are validated (Phase 2)
/// - Queue integrity is verified (Phase 2)
/// - Lock authority is validated (no dual-lock scenarios)
/// - Migrations run automatically on startup (Phase 3)
/// - TTL compaction runs on startup (Phase 3)
/// - Transaction journal replays incomplete transactions (Phase 3)
/// - Storage quota is checked and enforced (CLIMB #2)
/// - Lifecycle observer registered for storage monitoring (Phase 3)
/// - Cache invalidator initialized (Phase 3)
///
/// Usage in main.dart:
/// ```dart
/// await initLocalBackend();
/// ```
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../persistence/hive_service.dart';
import '../persistence/adapter_collision_guard.dart';
import '../persistence/encryption_policy.dart';
import '../persistence/index/pending_index.dart';
import '../persistence/locking/processing_lock.dart';
import '../persistence/migrations/migration_runner.dart';
import '../persistence/transactions/transaction_journal.dart';
import '../persistence/monitoring/storage_monitor.dart';
import '../persistence/cache/cache_invalidator.dart';
import '../home automation/src/data/home_automation_hive_bridge.dart';
import '../services/telemetry_service.dart';
import '../services/ttl_compaction_service.dart';
import 'app_lifecycle_observer.dart';

/// Global flag to prevent double-initialization
bool _localBackendInitialized = false;

/// Whether the local backend has been initialized
bool get isLocalBackendInitialized => _localBackendInitialized;

/// Initializes the entire local backend in the correct order.
///
/// This function is idempotent - calling it multiple times is safe.
///
/// Order of operations:
/// 1. HiveService.init() - Hive.initFlutter(), adapter registration, encryption key, core boxes
/// 2. AdapterCollisionGuard.assertNoCollisions() - Fail fast on TypeId conflicts
/// 3. HomeAutomationHiveBridge.open() - opens automation boxes using same Hive instance
/// 4. BoxPolicyRegistry.checkAllPolicies() - Validate encryption policies
/// 5. PendingIndex.integrityCheckAndRebuild() - Queue integrity auto-check
///
/// Edge cases handled:
/// - App resume after crash: boxes may already be open, we skip re-opening
/// - Secure erase already called: re-initializes cleanly
/// - Partial adapter registration: HiveService guards against double-registration
/// - Key rotation mid-session: handled by HiveService.resumeInterruptedRotation()
/// - TypeId collisions: detected and fail fast in dev builds (Phase 2)
/// - Encryption policy violations: logged to telemetry (Phase 2)
/// - Queue corruption: auto-healed on startup (Phase 2)
Future<void> initLocalBackend() async {
  if (_localBackendInitialized) {
    TelemetryService.I.increment('local_backend.init.skipped_already_initialized');
    return;
  }

  final sw = Stopwatch()..start();
  try {
    // Step 1: Initialize core persistence (Hive.initFlutter, adapters, encryption, core boxes)
    final hiveService = await HiveService.create();
    await hiveService.init();
    
    // Step 1b: Check for interrupted key rotation and resume if needed
    try {
      await hiveService.resumeInterruptedRotation();
    } catch (e) {
      // Log but don't fail init - rotation can be retried later
      TelemetryService.I.increment('local_backend.rotation_resume_failed');
      print('[LocalBackendBootstrap] Warning: rotation resume failed: $e');
    }

    // Step 2: Validate TypeId collisions (Phase 2 - fails fast in debug)
    AdapterCollisionGuard.assertNoCollisions();
    TelemetryService.I.increment('local_backend.adapter_check.passed');

    // Step 3: Open Home Automation boxes using the same Hive instance
    await HomeAutomationHiveBridge.open();

    // Step 4: Validate encryption policies (Phase 2 - soft enforcement)
    final policySummary = BoxPolicyRegistry.getSummary();
    if (!policySummary.isHealthy) {
      TelemetryService.I.increment('local_backend.encryption_policy.violations');
      TelemetryService.I.gauge(
          'local_backend.encryption_policy.violation_count', policySummary.violationCount);
      print('[LocalBackendBootstrap] Warning: Encryption policy violations detected: '
          '${policySummary.violatedBoxes}');
    } else {
      TelemetryService.I.increment('local_backend.encryption_policy.healthy');
    }

    // Step 5: Queue integrity auto-check (Phase 2)
    try {
      final pendingIndex = await PendingIndex.create();
      await pendingIndex.integrityCheckAndRebuild();
      TelemetryService.I.increment('local_backend.queue_integrity.checked');
    } catch (e) {
      // Log but don't fail init - queue can be rebuilt later
      TelemetryService.I.increment('local_backend.queue_integrity.failed');
      print('[LocalBackendBootstrap] Warning: Queue integrity check failed: $e');
    }

    // Step 6: Lock authority validation (fails fast in debug if dual-lock detected)
    // ProcessingLock is the ONLY lock for queue/sync operations.
    // This assertion detects if LockService is incorrectly being used for queue ops.
    if (kDebugMode) {
      try {
        await ProcessingLock.assertNoDualLockActive();
        TelemetryService.I.increment('local_backend.lock_authority.validated');
      } catch (e) {
        TelemetryService.I.increment('local_backend.lock_authority.dual_lock_detected');
        print('[LocalBackendBootstrap] ERROR: $e');
        rethrow; // Fail fast in debug mode
      }
    }

    // ═════════════════════════════════════════════════════════════════════
    // Step 7: Run pending migrations (auto-upgrade schema)
    // ═════════════════════════════════════════════════════════════════════
    try {
      final migrationsApplied = await MigrationRunner.runAllPending();
      if (migrationsApplied > 0) {
        TelemetryService.I.increment('local_backend.migrations.ran');
      }
    } catch (e) {
      TelemetryService.I.increment('local_backend.migrations.failed');
      print('[LocalBackendBootstrap] Warning: Migration failed: $e');
      // Non-fatal - app may still work with older schema
    }

    // ═════════════════════════════════════════════════════════════════════
    // Step 8: Initialize TransactionJournal and replay incomplete transactions
    // ═════════════════════════════════════════════════════════════════════
    try {
      await TransactionJournal.I.init();
      final rolledBack = await TransactionJournal.I.replayPendingJournals();
      if (rolledBack > 0) {
        TelemetryService.I.increment('local_backend.transaction_journal.replayed');
      }
    } catch (e) {
      TelemetryService.I.increment('local_backend.transaction_journal.failed');
      print('[LocalBackendBootstrap] Warning: TransactionJournal init/replay failed: $e');
      // Non-fatal - transactions will be handled manually
    }

    // ═════════════════════════════════════════════════════════════════════
    // Step 9: TTL compaction - purge old vitals and compact if needed
    // ═════════════════════════════════════════════════════════════════════
    try {
      await TtlCompactionService.runIfNeeded();
      TelemetryService.I.increment('local_backend.ttl_compaction.ran');
    } catch (e) {
      TelemetryService.I.increment('local_backend.ttl_compaction.failed');
      print('[LocalBackendBootstrap] Warning: TTL compaction failed: $e');
      // Non-fatal - will run again next startup
    }

    // ═════════════════════════════════════════════════════════════════════
    // Step 10: Storage quota check - enforce storage limits
    // ═════════════════════════════════════════════════════════════════════
    try {
      final storageResult = await StorageMonitor.runStartupCheck();
      if (storageResult.needsAttention) {
        TelemetryService.I.increment('local_backend.storage.${storageResult.pressure.name}');
      }
    } catch (e) {
      TelemetryService.I.increment('local_backend.storage.check_failed');
      print('[LocalBackendBootstrap] Warning: Storage check failed: $e');
      // Non-fatal - will run again on resume
    }

    // ═════════════════════════════════════════════════════════════════════
    // Step 11: Register lifecycle observer for app resume/terminate
    // PHASE 3 STEP 3.2 & 3.3: Force-exercise safety paths and enforce box lifecycle
    // ═════════════════════════════════════════════════════════════════════
    try {
      AppLifecycleObserver.I.register();
      TelemetryService.I.increment('local_backend.lifecycle_observer.registered');
    } catch (e) {
      TelemetryService.I.increment('local_backend.lifecycle_observer.failed');
      print('[LocalBackendBootstrap] Warning: Lifecycle observer registration failed: $e');
      // Non-fatal
    }

    // ═════════════════════════════════════════════════════════════════════
    // Step 12: Initialize cache invalidator (touch to prove it exists)
    // PHASE 3 STEP 3.1: Ensure CacheInvalidator is exercised
    // ═════════════════════════════════════════════════════════════════════
    try {
      final invalidator = CacheInvalidator();
      // Initialize with a startup event to prove it runs
      invalidator.invalidateAll();
      TelemetryService.I.increment('local_backend.cache_invalidator.initialized');
    } catch (e) {
      TelemetryService.I.increment('local_backend.cache_invalidator.failed');
      print('[LocalBackendBootstrap] Warning: Cache invalidator init failed: $e');
      // Non-fatal
    }

    _localBackendInitialized = true;
    sw.stop();
    TelemetryService.I.gauge('local_backend.init.duration_ms', sw.elapsedMilliseconds);
    TelemetryService.I.increment('local_backend.init.success');
    print('[LocalBackendBootstrap] Local backend initialized in ${sw.elapsedMilliseconds}ms');
  } catch (e, stackTrace) {
    sw.stop();
    TelemetryService.I.increment('local_backend.init.failed');
    print('[LocalBackendBootstrap] FATAL: Local backend init failed: $e');
    print(stackTrace);
    // PHASE 3 STEP 3.3: Close Hive on fatal startup error
    await AppLifecycleObserver.onFatalStartupError();
    rethrow;
  }
}

/// Resets the initialization flag (for testing only).
///
/// WARNING: This does NOT close boxes or clean up state.
/// Use only in test teardown after closing Hive.
void resetLocalBackendForTesting() {
  _localBackendInitialized = false;
}
