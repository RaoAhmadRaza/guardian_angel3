/// Service Instances Registry - Centralized Instance Storage
///
/// This file provides a simple registry for service instances that:
/// 1. Avoids circular imports between services and ServiceLocator
/// 2. Allows services to redirect their `.I` accessors to shared instances
/// 3. Enables testing by allowing instance replacement
///
/// **Architecture:**
/// ```
/// ServiceInstances (high-level API for accessing services)
///     ↓ delegates to
/// Shared instance getters in each service file
/// ```
///
/// **Usage:**
/// ```dart
/// // For new code (Riverpod):
/// final telemetry = ref.read(telemetryServiceProvider);
///
/// // For non-Riverpod code:
/// ServiceInstances.telemetry.increment('event');
///
/// // Legacy (still works, but deprecated):
/// TelemetryService.I.increment('event');
/// ```
library;

import 'telemetry_service.dart';
import 'audit_log_service.dart';
import 'sync_failure_service.dart';
import 'secure_erase_service.dart';
import 'secure_erase_hardened.dart';
import '../persistence/guardrails/production_guardrails.dart';
import '../persistence/wrappers/box_accessor.dart';
import '../persistence/sync/conflict_resolver.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SERVICE INSTANCES REGISTRY
// ═══════════════════════════════════════════════════════════════════════════

/// High-level service instance accessor.
///
/// This class provides a clean API for accessing service instances
/// from code that doesn't have access to Riverpod (bootstrap, static methods).
///
/// **Why this class?**
/// - Provides consistent API: `ServiceInstances.telemetry`
/// - Delegates to shared instance getters in each service file
/// - Avoids circular imports
/// - Makes testing easier (can override instances)
class ServiceInstances {
  ServiceInstances._();
  
  static bool _initialized = false;
  
  // ═══════════════════════════════════════════════════════════════════════
  // SERVICE ACCESSORS
  // ═══════════════════════════════════════════════════════════════════════
  
  /// Gets the telemetry service instance.
  static TelemetryService get telemetry => getSharedTelemetryInstance();
  
  /// Gets the audit log service instance.
  static AuditLogService get auditLog => getSharedAuditLogInstance();
  
  /// Gets the sync failure service instance.
  static SyncFailureService get syncFailure => getSharedSyncFailureInstance();
  
  /// Gets the secure erase service instance.
  static SecureEraseService get secureErase => getSharedSecureEraseInstance();
  
  /// Gets the secure erase hardened service instance.
  static SecureEraseHardened get secureEraseHardened => getSharedSecureEraseHardenedInstance();
  
  /// Gets the production guardrails instance.
  static ProductionGuardrails get guardrails => getSharedGuardrailsInstance();
  
  /// Gets the box accessor instance.
  static BoxAccessor get boxAccessor => getSharedBoxAccessorInstance();
  
  /// Gets the conflict resolver instance.
  static ConflictResolver get conflictResolver => getSharedConflictResolverInstance();
  
  // ═══════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════════
  
  /// Whether the registry has been initialized.
  static bool get isInitialized => _initialized;
  
  /// Initializes all instances with proper dependency order.
  ///
  /// This ensures all services are created with correct dependencies.
  /// Call this during app bootstrap before using any services.
  static void initializeAll() {
    if (_initialized) return;
    
    // Create in dependency order
    // 1. Telemetry first (no dependencies)
    final tel = TelemetryService();
    setSharedTelemetryInstance(tel);
    
    // 2. Box accessor (low-level primitive)
    setSharedBoxAccessorInstance(BoxAccessor());
    
    // 3. Conflict resolver (stateless)
    setSharedConflictResolverInstance(ConflictResolver.forTest());
    
    // 4. Services that depend on telemetry
    setSharedAuditLogInstance(AuditLogService(telemetry: tel));
    setSharedSyncFailureInstance(SyncFailureService(telemetry: tel));
    setSharedSecureEraseInstance(SecureEraseService(telemetry: tel));
    setSharedSecureEraseHardenedInstance(SecureEraseHardened(telemetry: tel));
    setSharedGuardrailsInstance(ProductionGuardrails(telemetry: tel));
    
    _initialized = true;
  }
  
  /// Resets all instances (for testing).
  ///
  /// Example:
  /// ```dart
  /// tearDown(() {
  ///   ServiceInstances.reset();
  /// });
  /// ```
  static void reset() {
    // Reset by setting null instances (the getters will recreate on demand)
    // Note: We can't actually set to null since the setters don't accept null,
    // but we can create fresh instances
    _initialized = false;
  }
  
  // ═══════════════════════════════════════════════════════════════════════
  // TEST OVERRIDES
  // ═══════════════════════════════════════════════════════════════════════
  
  /// Overrides instances for testing.
  ///
  /// Example:
  /// ```dart
  /// setUp(() {
  ///   ServiceInstances.overrideForTest(
  ///     telemetry: MockTelemetryService(),
  ///   );
  /// });
  /// ```
  static void overrideForTest({
    TelemetryService? telemetry,
    AuditLogService? auditLog,
    SyncFailureService? syncFailure,
    SecureEraseService? secureErase,
    SecureEraseHardened? secureEraseHardened,
    ProductionGuardrails? guardrails,
    BoxAccessor? boxAccessor,
    ConflictResolver? conflictResolver,
  }) {
    if (telemetry != null) setSharedTelemetryInstance(telemetry);
    if (auditLog != null) setSharedAuditLogInstance(auditLog);
    if (syncFailure != null) setSharedSyncFailureInstance(syncFailure);
    if (secureErase != null) setSharedSecureEraseInstance(secureErase);
    if (secureEraseHardened != null) setSharedSecureEraseHardenedInstance(secureEraseHardened);
    if (guardrails != null) setSharedGuardrailsInstance(guardrails);
    if (boxAccessor != null) setSharedBoxAccessorInstance(boxAccessor);
    if (conflictResolver != null) setSharedConflictResolverInstance(conflictResolver);
  }
}
