/// Fatal Startup Error - Blocks App Launch
///
/// When thrown during bootstrap, the app MUST NOT continue.
/// Instead, it should display a recovery UI to the user.
///
/// This is the enforcement mechanism for startup truth:
/// - SchemaValidator failures
/// - AdapterCollisionGuard failures
/// - HiveService init failures
/// - ProductionGuardrails violations
library;

import 'package:flutter/foundation.dart';

/// Error thrown when bootstrap fails in a way that cannot be recovered
/// without user intervention.
///
/// The app MUST NOT continue when this error is thrown.
/// Instead, display a [FatalStartupErrorScreen] to the user.
class FatalStartupError extends Error {
  /// Human-readable description of what failed.
  final String message;
  
  /// The component that failed (e.g., 'SchemaValidator', 'HiveService').
  final String component;
  
  /// The underlying error that caused the failure.
  final Object? cause;
  
  /// Stack trace of the underlying error.
  final StackTrace? causeStackTrace;
  
  /// Recovery instructions for the user.
  final List<String> recoverySteps;
  
  /// Whether this error is recoverable by the user (e.g., by clearing data).
  final bool isUserRecoverable;
  
  /// Telemetry key for this error type.
  final String telemetryKey;
  
  FatalStartupError({
    required this.message,
    required this.component,
    this.cause,
    this.causeStackTrace,
    this.recoverySteps = const [],
    this.isUserRecoverable = true,
    String? telemetryKey,
  }) : telemetryKey = telemetryKey ?? 'fatal_startup.${component.toLowerCase()}';
  
  @override
  String toString() {
    final buffer = StringBuffer()
      ..writeln('═══════════════════════════════════════════════════════════════')
      ..writeln('FATAL STARTUP ERROR: $component')
      ..writeln('═══════════════════════════════════════════════════════════════')
      ..writeln()
      ..writeln('Message: $message')
      ..writeln();
    
    if (recoverySteps.isNotEmpty) {
      buffer.writeln('Recovery Steps:');
      for (var i = 0; i < recoverySteps.length; i++) {
        buffer.writeln('  ${i + 1}. ${recoverySteps[i]}');
      }
      buffer.writeln();
    }
    
    if (cause != null) {
      buffer.writeln('Underlying Error: $cause');
      if (causeStackTrace != null) {
        buffer.writeln('Stack Trace:');
        buffer.writeln(causeStackTrace);
      }
    }
    
    buffer.writeln('═══════════════════════════════════════════════════════════════');
    
    return buffer.toString();
  }
  
  /// Creates a FatalStartupError for schema validation failures.
  factory FatalStartupError.schemaValidation({
    required String details,
    Object? cause,
    StackTrace? causeStackTrace,
  }) {
    return FatalStartupError(
      message: 'Schema validation failed: $details',
      component: 'SchemaValidator',
      cause: cause,
      causeStackTrace: causeStackTrace,
      isUserRecoverable: true,
      recoverySteps: [
        'Close the app completely',
        'Clear app data from device settings',
        'Reinstall the app if the problem persists',
        'Contact support if you need to recover data',
      ],
    );
  }
  
  /// Creates a FatalStartupError for adapter collision.
  factory FatalStartupError.adapterCollision({
    required String details,
    required List<String> collidingAdapters,
  }) {
    return FatalStartupError(
      message: 'TypeId collision detected: $details',
      component: 'AdapterCollisionGuard',
      isUserRecoverable: false,
      recoverySteps: [
        'This is a bug in the app',
        'Please update to the latest version',
        'If updated, contact support with error details',
        'Colliding adapters: ${collidingAdapters.join(", ")}',
      ],
    );
  }
  
  /// Creates a FatalStartupError for Hive initialization failure.
  factory FatalStartupError.hiveInit({
    required String details,
    Object? cause,
    StackTrace? causeStackTrace,
  }) {
    return FatalStartupError(
      message: 'Database initialization failed: $details',
      component: 'HiveService',
      cause: cause,
      causeStackTrace: causeStackTrace,
      isUserRecoverable: true,
      recoverySteps: [
        'Ensure the device has sufficient storage',
        'Close the app and try again',
        'Clear app data from device settings',
        'Contact support if the problem persists',
      ],
    );
  }
  
  /// Creates a FatalStartupError for encryption key issues.
  factory FatalStartupError.encryptionKey({
    required String details,
    Object? cause,
    StackTrace? causeStackTrace,
  }) {
    return FatalStartupError(
      message: 'Encryption key error: $details',
      component: 'EncryptionService',
      cause: cause,
      causeStackTrace: causeStackTrace,
      isUserRecoverable: true,
      recoverySteps: [
        'The encryption key could not be accessed',
        'Clear app data to reset encryption',
        'You will need to log in again',
        'Synced data will be restored from the server',
      ],
    );
  }
  
  /// Creates a FatalStartupError for guardrail violations.
  factory FatalStartupError.guardrailViolation({
    required String invariant,
    required String details,
  }) {
    return FatalStartupError(
      message: 'Guardrail violation: $invariant - $details',
      component: 'ProductionGuardrails',
      isUserRecoverable: true,
      recoverySteps: [
        'The app detected an inconsistent state',
        'Clear app data to reset',
        'Contact support if this happens repeatedly',
      ],
    );
  }
  
  /// Creates a FatalStartupError for LocalBackendBootstrap failures.
  factory FatalStartupError.localBackendBootstrap({
    required String details,
    Object? cause,
    StackTrace? causeStackTrace,
  }) {
    return FatalStartupError(
      message: 'Local backend bootstrap failed: $details',
      component: 'LocalBackendBootstrap',
      cause: cause,
      causeStackTrace: causeStackTrace,
      isUserRecoverable: true,
      recoverySteps: [
        'The local database could not be initialized',
        'Ensure the device has sufficient storage',
        'Clear app data from device settings',
        'Contact support if the problem persists',
      ],
    );
  }
}

/// Result of attempting to recover from a fatal error.
enum FatalErrorRecoveryResult {
  /// Recovery succeeded, app can restart.
  recovered,
  
  /// Recovery failed, user must clear data manually.
  failed,
  
  /// Recovery in progress, wait for completion.
  inProgress,
}

/// Extension for logging fatal errors.
extension FatalStartupErrorLogging on FatalStartupError {
  /// Logs this error for debugging and telemetry.
  void logError() {
    // Always print to console for debugging
    if (kDebugMode) {
      print(toString());
    }
    
    // In release, print a condensed version
    if (kReleaseMode) {
      print('[FATAL] $component: $message');
    }
  }
}
