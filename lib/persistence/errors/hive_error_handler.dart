/// Centralized Hive Error Handler
///
/// Catches and categorizes all HiveError types, providing:
/// - Telemetry on failure patterns
/// - User-friendly error messages
/// - Recovery strategies per error type
/// - Crash prevention through graceful degradation
///
/// PHASE 1 BLOCKER FIX: No HiveError handling existed before this.
library;

import 'dart:io';
import 'package:hive/hive.dart';
import '../../services/telemetry_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// HIVE ERROR CATEGORIES
// ═══════════════════════════════════════════════════════════════════════════

/// Base class for all persistence layer errors.
sealed class PersistenceError implements Exception {
  final String message;
  final String boxName;
  final Object? originalError;
  final StackTrace? stackTrace;

  const PersistenceError({
    required this.message,
    required this.boxName,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() => 'PersistenceError($boxName): $message';

  /// User-friendly message for UI display.
  String get userMessage;

  /// Whether this error is recoverable.
  bool get isRecoverable;

  /// Suggested recovery action.
  RecoveryAction get suggestedAction;
}

/// Box is corrupted and cannot be read.
class BoxCorruptionError extends PersistenceError {
  const BoxCorruptionError({
    required super.message,
    required super.boxName,
    super.originalError,
    super.stackTrace,
  });

  @override
  String get userMessage => 'Data storage was corrupted. Please restart the app.';

  @override
  bool get isRecoverable => true; // Can delete and recreate box

  @override
  RecoveryAction get suggestedAction => RecoveryAction.deleteAndRecreate;
}

/// Box is locked by another process/isolate.
class BoxLockError extends PersistenceError {
  const BoxLockError({
    required super.message,
    required super.boxName,
    super.originalError,
    super.stackTrace,
  });

  @override
  String get userMessage => 'Data is being used by another process. Please try again.';

  @override
  bool get isRecoverable => true; // Retry after delay

  @override
  RecoveryAction get suggestedAction => RecoveryAction.retryWithDelay;
}

/// Storage quota exceeded.
class StorageQuotaError extends PersistenceError {
  const StorageQuotaError({
    required super.message,
    required super.boxName,
    super.originalError,
    super.stackTrace,
  });

  @override
  String get userMessage => 'Storage is full. Please free up space on your device.';

  @override
  bool get isRecoverable => false; // User action required

  @override
  RecoveryAction get suggestedAction => RecoveryAction.userActionRequired;
}

/// Box not open when accessed.
class BoxNotOpenError extends PersistenceError {
  const BoxNotOpenError({
    required super.message,
    required super.boxName,
    super.originalError,
    super.stackTrace,
  });

  @override
  String get userMessage => 'App initialization incomplete. Please restart.';

  @override
  bool get isRecoverable => true; // Re-open box

  @override
  RecoveryAction get suggestedAction => RecoveryAction.reopenBox;
}

/// Type mismatch when reading from box.
class BoxTypeMismatchError extends PersistenceError {
  const BoxTypeMismatchError({
    required super.message,
    required super.boxName,
    super.originalError,
    super.stackTrace,
  });

  @override
  String get userMessage => 'Data format has changed. Please update the app.';

  @override
  bool get isRecoverable => false; // Migration needed

  @override
  RecoveryAction get suggestedAction => RecoveryAction.migrationRequired;
}

/// Encryption/decryption failed.
class BoxEncryptionError extends PersistenceError {
  const BoxEncryptionError({
    required super.message,
    required super.boxName,
    super.originalError,
    super.stackTrace,
  });

  @override
  String get userMessage => 'Could not access secure data. Please restart the app.';

  @override
  bool get isRecoverable => true; // Re-fetch encryption key

  @override
  RecoveryAction get suggestedAction => RecoveryAction.refetchEncryptionKey;
}

/// Generic Hive error not matching other categories.
class BoxUnknownError extends PersistenceError {
  const BoxUnknownError({
    required super.message,
    required super.boxName,
    super.originalError,
    super.stackTrace,
  });

  @override
  String get userMessage => 'An unexpected error occurred. Please try again.';

  @override
  bool get isRecoverable => true; // Retry

  @override
  RecoveryAction get suggestedAction => RecoveryAction.retry;
}

// ═══════════════════════════════════════════════════════════════════════════
// RECOVERY ACTIONS
// ═══════════════════════════════════════════════════════════════════════════

enum RecoveryAction {
  /// Retry the operation immediately.
  retry,

  /// Retry after a short delay (lock contention).
  retryWithDelay,

  /// Re-open the box.
  reopenBox,

  /// Delete corrupted box and recreate.
  deleteAndRecreate,

  /// Re-fetch encryption key from secure storage.
  refetchEncryptionKey,

  /// Migration is required before retry.
  migrationRequired,

  /// User must take action (e.g., free storage).
  userActionRequired,

  /// No recovery possible.
  none,
}

// ═══════════════════════════════════════════════════════════════════════════
// HIVE ERROR HANDLER
// ═══════════════════════════════════════════════════════════════════════════

/// Centralized handler for all Hive errors.
///
/// Usage:
/// ```dart
/// try {
///   await box.put(key, value);
/// } catch (e, st) {
///   final error = HiveErrorHandler.categorize(e, st, boxName: 'my_box');
///   HiveErrorHandler.record(error);
///   // Handle based on error.suggestedAction
/// }
/// ```
class HiveErrorHandler {
  static const _tag = 'HiveErrorHandler';

  /// Categorizes a raw exception into a typed PersistenceError.
  static PersistenceError categorize(
    Object error,
    StackTrace stackTrace, {
    required String boxName,
  }) {
    // Handle HiveError
    if (error is HiveError) {
      return _categorizeHiveError(error, stackTrace, boxName);
    }

    // Handle FileSystemException (often wrapped)
    if (error is FileSystemException) {
      return _categorizeFileSystemError(error, stackTrace, boxName);
    }

    // Handle StateError (box not open)
    if (error is StateError) {
      if (error.message.contains('not open') ||
          error.message.contains('Box not found')) {
        return BoxNotOpenError(
          message: error.message,
          boxName: boxName,
          originalError: error,
          stackTrace: stackTrace,
        );
      }
    }

    // Handle TypeError (type mismatch during read)
    if (error is TypeError) {
      return BoxTypeMismatchError(
        message: error.toString(),
        boxName: boxName,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Generic fallback
    return BoxUnknownError(
      message: error.toString(),
      boxName: boxName,
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  static PersistenceError _categorizeHiveError(
    HiveError error,
    StackTrace stackTrace,
    String boxName,
  ) {
    final rawMessage = error.message;
    final message = rawMessage?.toLowerCase() ?? '';

    // Corruption patterns
    if (message.contains('corrupt') ||
        message.contains('checksum') ||
        message.contains('invalid frame')) {
      return BoxCorruptionError(
        message: rawMessage ?? 'Box data is corrupted',
        boxName: boxName,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Lock patterns
    if (message.contains('lock') || message.contains('already opened')) {
      return BoxLockError(
        message: rawMessage ?? 'Box is locked',
        boxName: boxName,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Encryption patterns
    if (message.contains('decrypt') ||
        message.contains('encrypt') ||
        message.contains('cipher')) {
      return BoxEncryptionError(
        message: rawMessage ?? 'Encryption error',
        boxName: boxName,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Type adapter patterns
    if (message.contains('adapter') ||
        message.contains('type') ||
        message.contains('cast')) {
      return BoxTypeMismatchError(
        message: rawMessage ?? 'Type mismatch',
        boxName: boxName,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Default HiveError
    return BoxUnknownError(
      message: rawMessage ?? 'Unknown Hive error',
      boxName: boxName,
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  static PersistenceError _categorizeFileSystemError(
    FileSystemException error,
    StackTrace stackTrace,
    String boxName,
  ) {
    final message = error.message.toLowerCase();

    // Quota patterns
    if (message.contains('no space') ||
        message.contains('quota') ||
        message.contains('disk full') ||
        error.osError?.errorCode == 28 || // ENOSPC on Linux/macOS
        error.osError?.errorCode == 112) {
      // ERROR_DISK_FULL on Windows
      return StorageQuotaError(
        message: 'Storage quota exceeded: ${error.message}',
        boxName: boxName,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Lock patterns
    if (message.contains('lock') ||
        message.contains('permission denied') ||
        error.osError?.errorCode == 13) {
      // EACCES
      return BoxLockError(
        message: 'File access denied: ${error.message}',
        boxName: boxName,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Corruption patterns
    if (message.contains('corrupt') ||
        message.contains('read error') ||
        message.contains('i/o error')) {
      return BoxCorruptionError(
        message: 'File system error: ${error.message}',
        boxName: boxName,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    return BoxUnknownError(
      message: 'File system error: ${error.message}',
      boxName: boxName,
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  /// Records a persistence error to telemetry.
  static void record(PersistenceError error) {
    final category = switch (error) {
      BoxCorruptionError() => 'corruption',
      BoxLockError() => 'lock',
      StorageQuotaError() => 'quota',
      BoxNotOpenError() => 'not_open',
      BoxTypeMismatchError() => 'type_mismatch',
      BoxEncryptionError() => 'encryption',
      BoxUnknownError() => 'unknown',
    };

    TelemetryService.I.increment('hive.error.$category');
    TelemetryService.I.increment('hive.error.box.${error.boxName}');
    TelemetryService.I.increment('hive.error.total');

    // Log for debugging
    print('[$_tag] ${error.runtimeType} on ${error.boxName}: ${error.message}');
    if (error.stackTrace != null) {
      print('[$_tag] Stack: ${error.stackTrace}');
    }
  }

  /// Attempts automatic recovery based on error type.
  ///
  /// Returns true if recovery was successful.
  static Future<bool> attemptRecovery(
    PersistenceError error, {
    Future<void> Function()? onRetry,
    Future<void> Function()? onReopenBox,
    Future<void> Function()? onDeleteAndRecreate,
    Future<void> Function()? onRefetchKey,
  }) async {
    TelemetryService.I.increment(
      'hive.recovery.attempt.${error.suggestedAction.name}',
    );

    try {
      switch (error.suggestedAction) {
        case RecoveryAction.retry:
          if (onRetry != null) {
            await onRetry();
            TelemetryService.I.increment('hive.recovery.success.retry');
            return true;
          }
          return false;

        case RecoveryAction.retryWithDelay:
          await Future.delayed(const Duration(milliseconds: 500));
          if (onRetry != null) {
            await onRetry();
            TelemetryService.I.increment('hive.recovery.success.retry_delay');
            return true;
          }
          return false;

        case RecoveryAction.reopenBox:
          if (onReopenBox != null) {
            await onReopenBox();
            TelemetryService.I.increment('hive.recovery.success.reopen');
            return true;
          }
          return false;

        case RecoveryAction.deleteAndRecreate:
          if (onDeleteAndRecreate != null) {
            await onDeleteAndRecreate();
            TelemetryService.I.increment('hive.recovery.success.recreate');
            return true;
          }
          return false;

        case RecoveryAction.refetchEncryptionKey:
          if (onRefetchKey != null) {
            await onRefetchKey();
            TelemetryService.I.increment('hive.recovery.success.refetch_key');
            return true;
          }
          return false;

        case RecoveryAction.migrationRequired:
        case RecoveryAction.userActionRequired:
        case RecoveryAction.none:
          return false;
      }
    } catch (e) {
      TelemetryService.I.increment('hive.recovery.failed');
      return false;
    }
  }
}
