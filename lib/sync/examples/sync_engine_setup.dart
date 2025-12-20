// Example: Initializing SyncEngine with Phase 3 Components
// 
// This example shows how to set up the complete sync engine
// with all reliability and crash recovery features.

import 'package:hive/hive.dart';
import '../sync_engine.dart';
import '../api_client.dart';
import '../auth_service.dart';
import '../pending_queue_service.dart';
import '../op_router.dart';
import '../processing_lock.dart';
import '../backoff_policy.dart';
import '../circuit_breaker.dart';
import '../reconciler.dart';
import '../optimistic_store.dart';
import '../batch_coalescer.dart';
import '../metrics/telemetry.dart';
import '../realtime_service.dart';
import '../models/pending_op.dart';

/// Example of setting up SyncEngine with all Phase 3 components
Future<SyncEngine> createSyncEngine() async {
  // Initialize Hive boxes (assuming Hive.init() already called)
  final pendingBox = await Hive.openBox<PendingOp>('pending_operations');
  final indexBox = await Hive.openBox<String>('pending_index');
  final lockBox = await Hive.openBox<Map>('processing_lock');
  final failedBox = await Hive.openBox<Map>('failed_ops');

  // Create auth service (implement your own)
  final authService = AuthService();

  // Create API client
  final apiClient = ApiClient(
    baseUrl: 'https://api.example.com',
    authService: authService,
    appVersion: '1.0.0',
    deviceId: 'device-id-here',
  );

  // Create queue service
  final queueService = PendingQueueService(
    pendingBox,
    indexBox,
    failedBox,
  );

  // Create op router with your routes
  final router = OpRouter();
  _registerRoutes(router);

  // Create processing lock
  final lock = ProcessingLock(
    lockBox,
    heartbeatInterval: const Duration(seconds: 10),
    lockTimeout: const Duration(minutes: 2),
  );

  // Create backoff policy
  final backoffPolicy = BackoffPolicy(
    baseMs: 1000, // 1 second
    maxBackoffMs: 300000, // 5 minutes
    maxAttempts: 10,
  );

  // Phase 3 Components

  // Circuit breaker - protects API from meltdown
  final circuitBreaker = CircuitBreaker(
    failureThreshold: 10, // Trip after 10 failures
    window: const Duration(minutes: 1), // In 1-minute window
    cooldown: const Duration(minutes: 1), // 1-minute cooldown
  );

  // Reconciler - handles 409 conflicts automatically
  final reconciler = Reconciler(apiClient);

  // Optimistic store - manages rollbacks
  final optimisticStore = OptimisticStore();

  // Batch coalescer - optimizes queue
  final coalescer = BatchCoalescer(pendingBox, indexBox);

  // Telemetry - comprehensive metrics
  final metrics = SyncMetrics();

  // Real-time service (optional) - WebSocket support
  final realtimeService = RealtimeService(
    url: 'wss://api.example.com/ws',
    reconnectDelay: const Duration(seconds: 5),
    maxReconnectAttempts: 10,
  );

  // Create sync engine with all components
  final syncEngine = SyncEngine(
    api: apiClient,
    queue: queueService,
    router: router,
    lock: lock,
    backoffPolicy: backoffPolicy,
    circuitBreaker: circuitBreaker,
    reconciler: reconciler,
    optimisticStore: optimisticStore,
    coalescer: coalescer,
    metrics: metrics,
    realtimeService: realtimeService,
  );

  return syncEngine;
}

/// Register your operation routes
void _registerRoutes(OpRouter router) {
  // Device operations
  router.register(
    'CREATE',
    'DEVICE',
    RouteDef(
      method: 'POST',
      pathBuilder: (payload) => '/devices',
      requiresIdempotency: true,
    ),
  );

  router.register(
    'UPDATE',
    'DEVICE',
    RouteDef(
      method: 'PATCH',
      pathBuilder: (payload) => '/devices/${payload['id']}',
      requiresIdempotency: true,
    ),
  );

  router.register(
    'DELETE',
    'DEVICE',
    RouteDef(
      method: 'DELETE',
      pathBuilder: (payload) => '/devices/${payload['id']}',
      requiresIdempotency: true,
    ),
  );

  // Add more routes as needed...
}

/// Example: Using the sync engine with optimistic updates
Future<void> exampleOptimisticUpdate(SyncEngine syncEngine) async {
  // 1. Generate transaction token
  final txnToken = 'txn-${DateTime.now().millisecondsSinceEpoch}';

  // 2. Save original state
  final originalState = {
    'id': 'device-123',
    'state': 'off',
    'brightness': 50,
  };

  // 3. Apply optimistic update to UI
  final newState = {
    'id': 'device-123',
    'state': 'on',
    'brightness': 100,
  };
  _updateUI(newState); // Update UI immediately

  // 4. Register rollback handler
  syncEngine.optimisticStore.register(
    txnToken: txnToken,
    originalState: originalState,
    rollbackHandler: () {
      print('Rolling back device state');
      _updateUI(originalState); // Restore original state
    },
    onSuccess: () {
      print('Device updated successfully!');
      _showSuccessNotification('Device turned on');
    },
    onError: (error) {
      print('Failed to update device: $error');
      _showErrorNotification('Failed: $error');
    },
  );

  // 5. Create pending operation
  final op = PendingOp(
    id: 'op-${DateTime.now().millisecondsSinceEpoch}',
    opType: 'UPDATE',
    entityType: 'DEVICE',
    payload: newState,
    txnToken: txnToken, // Link to optimistic update
  );

  // 6. Enqueue operation (with automatic coalescing)
  await syncEngine.enqueue(op);

  // The sync engine will:
  // - Try to coalesce with existing operations
  // - Process when network available
  // - Call commit() on success (triggers onSuccess callback)
  // - Call rollback() on failure (triggers rollbackHandler + onError)
}

/// Example: Manually checking metrics
void exampleMetrics(SyncEngine syncEngine) {
  // Get metrics summary
  final metrics = syncEngine.getMetrics();
  
  print('Operations processed: ${metrics['operations']['processed']}');
  print('Success rate: ${metrics['operations']['success_rate']}%');
  print('Average latency: ${metrics['latency']['avg_ms']}ms');
  print('P95 latency: ${metrics['latency']['p95_ms']}ms');
  print('Queue depth: ${metrics['queue']['avg_depth']}');
  print('Network health: ${metrics['network']['health_score']}%');
  
  // Or print full summary
  syncEngine.printMetrics();
}

/// Example: Handling circuit breaker trip
void exampleCircuitBreaker(SyncEngine syncEngine) {
  // Check if circuit breaker is tripped
  if (syncEngine.circuitBreaker.isTripped()) {
    final cooldown = syncEngine.circuitBreaker.getCooldownRemaining();
    print('Circuit breaker tripped! Cooling down for ${cooldown?.inSeconds}s');
    
    // Show user notification
    _showWarningNotification(
      'Sync temporarily paused due to server issues. '
      'Will resume in ${cooldown?.inSeconds} seconds.',
    );
  }
}

/// Example: Starting and stopping the engine
Future<void> exampleLifecycle() async {
  final syncEngine = await createSyncEngine();
  
  // Start the engine
  await syncEngine.start();
  print('Sync engine running: ${syncEngine.isRunning}');
  
  // Engine is now processing operations...
  
  // Stop the engine (prints metrics summary)
  await syncEngine.stop();
  print('Sync engine stopped');
}

// Placeholder functions for UI updates
void _updateUI(Map<String, dynamic> state) {
  // Update your UI state management (Provider, Bloc, etc.)
}

void _showSuccessNotification(String message) {
  // Show success snackbar/toast
}

void _showErrorNotification(String message) {
  // Show error snackbar/toast
}

void _showWarningNotification(String message) {
  // Show warning notification
}

// Placeholder auth service
class YourAuthService {
  Future<String> getToken() async => 'your-auth-token';
  Future<bool> tryRefresh() async => true;
}
