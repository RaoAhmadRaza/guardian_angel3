/// Default Sync Consumer
///
/// Concrete implementation of SyncConsumer that connects the pending
/// queue to the remote API. This is the "real" sync integration that
/// takes pending operations and sends them to the backend.
///
/// Features:
/// - Offline detection (graceful failure when network unavailable)
/// - Partial API failure handling
/// - Conflict detection and resolution
/// - App killed mid-sync safety (idempotency keys)
///
/// Usage:
/// ```dart
/// final consumer = DefaultSyncConsumer(apiClient: apiClient);
/// queueService.setSyncConsumer(consumer);
/// ```
library;

import '../models/pending_op.dart';
import '../services/telemetry_service.dart';
import 'sync_consumer.dart';
import 'api_client.dart';
import 'conflict_resolver.dart';
import 'exceptions.dart';

/// Default sync consumer that processes operations via the API.
///
/// Handles:
/// - Network errors → transient failure (retry)
/// - 4xx errors → permanent failure (no retry)
/// - 5xx errors → transient failure (retry)
/// - 401/403 → auth failure (pause queue)
/// - Conflicts → conflict resolution
class DefaultSyncConsumer implements SyncConsumer {
  final ApiClient _api;
  final ConflictResolver _conflictResolver;
  final TelemetryService _telemetry;
  
  /// Whether the consumer is currently connected (network available).
  bool _isConnected = true;

  DefaultSyncConsumer({
    required ApiClient api,
    ConflictResolver? conflictResolver,
    TelemetryService? telemetry,
  })  : _api = api,
        _conflictResolver = conflictResolver ?? DefaultConflictResolver(),
        _telemetry = telemetry ?? TelemetryService.I;

  @override
  Future<SyncResult> process(PendingOp op) async {
    _telemetry.increment('sync.process.attempt');
    
    try {
      // Determine the API endpoint and method based on op type
      final endpoint = _resolveEndpoint(op);
      final method = _resolveMethod(op);
      
      // Execute the API call
      final response = await _api.request(
        method: method,
        path: endpoint,
        body: op.payload,
        headers: {
          'Idempotency-Key': op.idempotencyKey,
        },
      );
      
      // Extract server-assigned data
      final serverId = response['data']?['id'] as String?;
      final serverTimestamp = response['data']?['updated_at'] != null
          ? DateTime.tryParse(response['data']['updated_at'] as String)
          : null;
      
      _isConnected = true;
      _telemetry.increment('sync.process.success');
      
      return SyncResult.success(
        serverId: serverId,
        serverTimestamp: serverTimestamp,
      );
    } on NetworkException catch (e) {
      _isConnected = false;
      _telemetry.increment('sync.process.network_error');
      return SyncResult.transientFailure('Network error: ${e.message}');
    } on AuthException catch (e) {
      _telemetry.increment('sync.process.auth_error');
      return SyncResult.authFailure('Auth error: ${e.message}');
    } on ConflictException catch (e) {
      _telemetry.increment('sync.process.conflict');
      return _conflictResolver.resolve(op, e);
    } on ValidationException catch (e) {
      _telemetry.increment('sync.process.validation_error');
      return SyncResult.permanentFailure('Validation error: ${e.message}');
    } on RetryableException catch (e) {
      // Handles ServerException, ServiceUnavailableException, TimeoutException, rate limits
      _telemetry.increment('sync.process.retryable_error');
      final retryInfo = e.retryAfter != null ? ' (retry after ${e.retryAfter!.inSeconds}s)' : '';
      return SyncResult.transientFailure('${e.message}$retryInfo');
    } on SyncException catch (e) {
      _telemetry.increment('sync.process.sync_error');
      // Map HTTP status to appropriate result
      if (e.httpStatus != null && e.httpStatus! >= 500) {
        return SyncResult.transientFailure(e.message);
      }
      return SyncResult.permanentFailure(e.message);
    } catch (e) {
      _telemetry.increment('sync.process.unknown_error');
      // Unknown errors default to transient (will retry)
      return SyncResult.transientFailure('Unknown error: $e');
    }
  }

  @override
  Future<bool> isReady() async {
    // Check network connectivity
    if (!_isConnected) {
      // Try a lightweight health check
      try {
        await _api.request(
          method: 'GET',
          path: '/health',
          timeout: const Duration(seconds: 5),
        );
        _isConnected = true;
      } catch (_) {
        _isConnected = false;
      }
    }
    return _isConnected;
  }

  @override
  Future<void> onQueueStart() async {
    _telemetry.increment('sync.queue.start');
  }

  @override
  Future<void> onQueueEnd() async {
    _telemetry.increment('sync.queue.end');
  }

  /// Resolve the API endpoint based on operation type.
  String _resolveEndpoint(PendingOp op) {
    // Extract entity type and ID from payload
    final entityType = op.payload['entity_type'] as String? ?? op.opType;
    final entityId = op.payload['entity_id'] as String?;
    final action = op.payload['action'] as String? ?? 'sync';
    
    switch (entityType) {
      case 'automation':
      case 'home_automation':
        if (entityId != null && action != 'create') {
          return '/api/v1/automations/$entityId';
        }
        return '/api/v1/automations';
      
      case 'vital':
      case 'vitals':
        if (entityId != null && action != 'create') {
          return '/api/v1/vitals/$entityId';
        }
        return '/api/v1/vitals';
      
      case 'user':
      case 'profile':
        if (entityId != null) {
          return '/api/v1/users/$entityId';
        }
        return '/api/v1/users';
      
      case 'device':
        if (entityId != null && action != 'create') {
          return '/api/v1/devices/$entityId';
        }
        return '/api/v1/devices';
      
      case 'chat':
      case 'message':
        if (entityId != null && action != 'create') {
          return '/api/v1/messages/$entityId';
        }
        return '/api/v1/messages';
      
      default:
        // Generic endpoint based on op type
        if (entityId != null && action != 'create') {
          return '/api/v1/${entityType}s/$entityId';
        }
        return '/api/v1/${entityType}s';
    }
  }

  /// Resolve the HTTP method based on operation action.
  String _resolveMethod(PendingOp op) {
    final action = op.payload['action'] as String? ?? 'sync';
    
    switch (action) {
      case 'create':
        return 'POST';
      case 'update':
        return 'PUT';
      case 'patch':
        return 'PATCH';
      case 'delete':
        return 'DELETE';
      case 'sync':
      default:
        // Default to POST for sync operations
        return 'POST';
    }
  }
}
