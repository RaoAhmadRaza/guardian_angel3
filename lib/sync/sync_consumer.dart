/// Sync Consumer Interface
///
/// This file defines the contract between the local queue processor and
/// future sync implementations. By defining the interface NOW, we ensure:
///
/// 1. Queue processor can be written against the interface
/// 2. Sync implementations can be swapped without touching queue code
/// 3. Testing is simplified with mock implementations
/// 4. Clear separation of concerns between queue management and sync logic
///
/// IMPORTANT: This is an interface-only file. No sync logic is implemented here.
/// The actual sync implementation will be added in a future phase.
///
/// Usage:
/// ```dart
/// // Future sync implementation
/// class HttpSyncConsumer implements SyncConsumer {
///   @override
///   Future<SyncResult> process(PendingOp op) async {
///     // Send to backend, return result
///   }
/// }
///
/// // Queue processor uses interface
/// final result = await syncConsumer.process(op);
/// if (result.isSuccess) {
///   await queue.remove(op);
/// }
/// ```
library sync_consumer;

import '../models/pending_op.dart';

/// Result of attempting to sync a pending operation.
///
/// Encapsulates success/failure state and metadata needed for
/// the queue processor to make decisions about retry, removal, or escalation.
class SyncResult {
  /// Whether the sync operation succeeded.
  final bool isSuccess;

  /// Classification of the failure (null if success).
  final FailureType? failureType;

  /// Human-readable error message (null if success).
  final String? errorMessage;

  /// Server-assigned ID if created (null if not applicable).
  final String? serverId;

  /// Server timestamp of the operation (null if not available).
  final DateTime? serverTimestamp;

  /// Whether this operation should be retried.
  ///
  /// Derived from failure type:
  /// - transient: retry
  /// - permanent: do not retry
  /// - auth: do not retry (escalate)
  /// - schema: do not retry (escalate)
  bool get shouldRetry =>
      !isSuccess && failureType == FailureType.transient;

  /// Whether this failure should trigger escalation (user notification, etc).
  ///
  /// Non-transient failures typically require human intervention.
  bool get shouldEscalate =>
      !isSuccess && failureType != FailureType.transient;

  const SyncResult._({
    required this.isSuccess,
    this.failureType,
    this.errorMessage,
    this.serverId,
    this.serverTimestamp,
  });

  /// Creates a successful sync result.
  ///
  /// [serverId] - Optional server-assigned ID for create operations.
  /// [serverTimestamp] - Optional server timestamp for the operation.
  factory SyncResult.success({
    String? serverId,
    DateTime? serverTimestamp,
  }) {
    return SyncResult._(
      isSuccess: true,
      serverId: serverId,
      serverTimestamp: serverTimestamp,
    );
  }

  /// Creates a transient failure result (network timeout, server 5xx, etc).
  ///
  /// Transient failures should be retried with backoff.
  factory SyncResult.transientFailure(String message) {
    return SyncResult._(
      isSuccess: false,
      failureType: FailureType.transient,
      errorMessage: message,
    );
  }

  /// Creates a permanent failure result (validation error, 400, 404, etc).
  ///
  /// Permanent failures should NOT be retried - they will never succeed.
  factory SyncResult.permanentFailure(String message) {
    return SyncResult._(
      isSuccess: false,
      failureType: FailureType.permanent,
      errorMessage: message,
    );
  }

  /// Creates an auth failure result (401, 403, token expired, etc).
  ///
  /// Auth failures require re-authentication before retry.
  factory SyncResult.authFailure(String message) {
    return SyncResult._(
      isSuccess: false,
      failureType: FailureType.auth,
      errorMessage: message,
    );
  }

  /// Creates a schema mismatch failure (API version incompatible, etc).
  ///
  /// Schema failures require app update before retry.
  factory SyncResult.schemaFailure(String message) {
    return SyncResult._(
      isSuccess: false,
      failureType: FailureType.schema,
      errorMessage: message,
    );
  }

  @override
  String toString() {
    if (isSuccess) {
      return 'SyncResult.success(serverId: $serverId)';
    }
    return 'SyncResult.${failureType?.name}Failure($errorMessage)';
  }
}

/// Classification of sync operation failures.
///
/// Used by queue processor to determine:
/// - Whether to retry the operation
/// - What backoff strategy to use
/// - Whether to escalate to user
/// - How to log/report the failure
enum FailureType {
  /// Temporary failure that may succeed on retry.
  ///
  /// Examples:
  /// - Network timeout
  /// - Connection refused
  /// - Server 500/502/503/504
  /// - Rate limit (429)
  ///
  /// Action: Retry with exponential backoff.
  transient,

  /// Permanent failure that will never succeed.
  ///
  /// Examples:
  /// - Validation error (400)
  /// - Resource not found (404)
  /// - Conflict (409)
  /// - Payload too large (413)
  ///
  /// Action: Move to failed_ops, notify user, do not retry.
  permanent,

  /// Authentication/authorization failure.
  ///
  /// Examples:
  /// - Token expired (401)
  /// - Permission denied (403)
  /// - Account suspended
  ///
  /// Action: Pause queue, prompt re-auth, then retry.
  auth,

  /// Schema/version mismatch.
  ///
  /// Examples:
  /// - API version unsupported
  /// - Required field missing
  /// - Field type changed
  ///
  /// Action: Pause queue, prompt app update, do not retry.
  schema,
}

/// Extension to map HTTP status codes to failure types.
extension HttpStatusToFailureType on int {
  /// Maps an HTTP status code to the appropriate failure type.
  ///
  /// Returns null for success codes (2xx).
  FailureType? toFailureType() {
    if (this >= 200 && this < 300) return null; // Success

    switch (this) {
      // Auth failures
      case 401:
      case 403:
        return FailureType.auth;

      // Transient failures (retry-able)
      case 408: // Request Timeout
      case 429: // Too Many Requests
      case 500: // Internal Server Error
      case 502: // Bad Gateway
      case 503: // Service Unavailable
      case 504: // Gateway Timeout
        return FailureType.transient;

      // Permanent failures (do not retry)
      case 400: // Bad Request
      case 404: // Not Found
      case 405: // Method Not Allowed
      case 409: // Conflict
      case 410: // Gone
      case 413: // Payload Too Large
      case 415: // Unsupported Media Type
      case 422: // Unprocessable Entity
        return FailureType.permanent;

      // Default to transient for unknown codes
      default:
        return this >= 500 ? FailureType.transient : FailureType.permanent;
    }
  }
}

/// Extension to map common exceptions to failure types.
extension ExceptionToFailureType on Exception {
  /// Maps an exception to the appropriate failure type.
  ///
  /// This is a best-effort mapping based on exception type name.
  /// Specific sync implementations should catch and classify their
  /// own exceptions more precisely.
  FailureType classifyFailure() {
    final typeName = runtimeType.toString().toLowerCase();

    // Network-related exceptions are transient
    if (typeName.contains('socket') ||
        typeName.contains('timeout') ||
        typeName.contains('connection') ||
        typeName.contains('network') ||
        typeName.contains('http')) {
      return FailureType.transient;
    }

    // Auth-related exceptions
    if (typeName.contains('auth') ||
        typeName.contains('permission') ||
        typeName.contains('unauthorized') ||
        typeName.contains('forbidden')) {
      return FailureType.auth;
    }

    // Format/schema exceptions
    if (typeName.contains('format') ||
        typeName.contains('parse') ||
        typeName.contains('schema') ||
        typeName.contains('version')) {
      return FailureType.schema;
    }

    // Default to permanent for unknown exceptions
    return FailureType.permanent;
  }
}

/// Abstract interface for sync consumers.
///
/// Implementations of this interface handle the actual syncing of
/// pending operations to a backend. The queue processor calls this
/// interface without knowing the specifics of the sync implementation.
///
/// Contract:
/// 1. process() must be idempotent - calling with same op ID is safe
/// 2. process() must return a valid SyncResult, never throw
/// 3. process() must complete in reasonable time (use timeouts internally)
/// 4. Implementations must handle their own auth token management
///
/// Example implementation:
/// ```dart
/// class HttpSyncConsumer implements SyncConsumer {
///   final Dio _client;
///   final AuthService _auth;
///
///   @override
///   Future<SyncResult> process(PendingOp op) async {
///     try {
///       final token = await _auth.getValidToken();
///       final response = await _client.post(
///         '/api/${op.type}',
///         data: op.payload,
///         options: Options(headers: {'Authorization': 'Bearer $token'}),
///       );
///       return SyncResult.success(serverId: response.data['id']);
///     } on DioException catch (e) {
///       final failureType = e.response?.statusCode?.toFailureType();
///       if (failureType == FailureType.transient) {
///         return SyncResult.transientFailure(e.message ?? 'Network error');
///       }
///       return SyncResult.permanentFailure(e.message ?? 'Request failed');
///     }
///   }
/// }
/// ```
abstract class SyncConsumer {
  /// Processes a pending operation, attempting to sync it to the backend.
  ///
  /// [op] - The pending operation to sync.
  ///
  /// Returns a [SyncResult] indicating success or classified failure.
  /// This method must not throw - all errors should be caught and
  /// returned as appropriate SyncResult types.
  Future<SyncResult> process(PendingOp op);

  /// Optional: Checks if the consumer is ready to process operations.
  ///
  /// Override this to check network connectivity, auth state, etc.
  /// Default implementation always returns true.
  Future<bool> isReady() async => true;

  /// Optional: Called when the queue is about to start processing.
  ///
  /// Override this to perform setup, refresh tokens, etc.
  /// Default implementation does nothing.
  Future<void> onQueueStart() async {}

  /// Optional: Called when the queue finishes processing.
  ///
  /// Override this to perform cleanup, log stats, etc.
  /// Default implementation does nothing.
  Future<void> onQueueEnd() async {}
}

/// No-op sync consumer for testing and offline mode.
///
/// Always returns success without actually syncing anywhere.
/// Useful for:
/// - Unit testing queue logic
/// - Offline-first mode where sync is deferred
/// - Development/debugging
class NoOpSyncConsumer implements SyncConsumer {
  @override
  Future<SyncResult> process(PendingOp op) async {
    // Simulate network delay for realistic testing
    await Future.delayed(const Duration(milliseconds: 10));
    return SyncResult.success(
      serverId: 'local_${op.id}',
      serverTimestamp: DateTime.now(),
    );
  }

  @override
  Future<bool> isReady() async => true;

  @override
  Future<void> onQueueStart() async {}

  @override
  Future<void> onQueueEnd() async {}
}

/// Failing sync consumer for testing error handling.
///
/// Always returns the configured failure type.
/// Useful for testing:
/// - Retry logic
/// - Poison op detection
/// - Failure escalation
class FailingSyncConsumer implements SyncConsumer {
  final FailureType failureType;
  final String message;

  const FailingSyncConsumer({
    this.failureType = FailureType.transient,
    this.message = 'Simulated failure',
  });

  @override
  Future<SyncResult> process(PendingOp op) async {
    await Future.delayed(const Duration(milliseconds: 10));
    switch (failureType) {
      case FailureType.transient:
        return SyncResult.transientFailure(message);
      case FailureType.permanent:
        return SyncResult.permanentFailure(message);
      case FailureType.auth:
        return SyncResult.authFailure(message);
      case FailureType.schema:
        return SyncResult.schemaFailure(message);
    }
  }

  @override
  Future<bool> isReady() async => true;

  @override
  Future<void> onQueueStart() async {}

  @override
  Future<void> onQueueEnd() async {}
}
