import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:guardian_angel_fyp/services/backend_idempotency_service.dart';
import 'package:guardian_angel_fyp/services/failed_ops_service.dart';
import 'package:guardian_angel_fyp/models/pending_op.dart';
import 'package:guardian_angel_fyp/models/failed_op_model.dart';
import 'package:guardian_angel_fyp/persistence/box_registry.dart';
import 'package:guardian_angel_fyp/persistence/index/pending_index.dart';
import 'package:guardian_angel_fyp/persistence/adapters/pending_op_adapter.dart';
import 'package:guardian_angel_fyp/persistence/adapters/failed_op_adapter.dart';

/// Mock interceptor to simulate backend responses for idempotency testing
class MockBackendInterceptor extends Interceptor {
  final Map<String, dynamic Function(RequestOptions)> _handlers = {};
  final Set<String> _seenIdempotencyKeys = {};
  
  void onPost(String path, dynamic Function(RequestOptions) handler) {
    _handlers[path] = handler;
  }
  
  bool hasSeenKey(String key) => _seenIdempotencyKeys.contains(key);
  
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final path = options.path;
    
    // Track idempotency keys
    final idempotencyKey = options.headers['X-Idempotency-Key'] as String?;
    if (idempotencyKey != null) {
      _seenIdempotencyKeys.add(idempotencyKey);
    }
    
    if (_handlers.containsKey(path)) {
      try {
        final result = _handlers[path]!(options);
        if (result is Response) {
          handler.resolve(result);
        } else {
          throw result;
        }
      } catch (e) {
        if (e is DioException) {
          handler.reject(e);
        } else {
          handler.reject(DioException(requestOptions: options, error: e));
        }
      }
    } else {
      handler.reject(DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: 'No mock configured for ${options.path}',
      ));
    }
  }
}

/// Simulates a simple operation processor that uses idempotency
class MockOperationProcessor {
  final Dio client;
  final BackendIdempotencyService idempotencyService;
  final FailedOpsService failedOpsService;
  final Box<PendingOp> pendingBox;
  
  MockOperationProcessor({
    required this.client,
    required this.idempotencyService,
    required this.failedOpsService,
    required this.pendingBox,
  });
  
  /// Process a pending operation with idempotency support
  Future<bool> processOperation(PendingOp op) async {
    try {
      // Build request with idempotency key
      final options = idempotencyService.buildIdempotentOptions(
        idempotencyKey: op.idempotencyKey,
      );
      
      // Send operation to backend
      final response = await client.post(
        '/api/operations',
        data: {
          'op_type': op.opType,
          'payload': op.payload,
        },
        options: options,
      );
      
      // Verify backend accepted the idempotency key (non-fatal)
      // If backend doesn't support idempotency, we still process the operation
      // but lose the idempotency guarantee
      if (idempotencyService.support == IdempotencySupport.supported) {
        idempotencyService.verifyOperationResponse(response);
        // Note: verifyOperationResponse logs degradation metrics internally
        // but we don't fail the operation - graceful degradation
      }
      
      // Success - remove from pending
      await pendingBox.delete(op.id);
      return true;
      
    } on DioException catch (e) {
      // Network error - move to failed ops for retry
      final now = DateTime.now().toUtc();
      final failedOp = FailedOpModel(
        id: 'failed_${op.id}',
        sourcePendingOpId: op.id,
        opType: op.opType,
        payload: op.payload,
        errorCode: e.type.name,
        errorMessage: e.message ?? 'Network error',
        idempotencyKey: op.idempotencyKey,
        attempts: op.attempts + 1,
        archived: false,
        createdAt: op.createdAt,
        updatedAt: now,
      );
      
      final failedBox = Hive.box<FailedOpModel>(BoxRegistry.failedOpsBox);
      await failedBox.put(failedOp.id, failedOp);
      await pendingBox.delete(op.id);
      
      return false;
    }
  }
}

/// End-to-end idempotency integration test suite
/// Validates: operation → backend handshake → dedup → retry flow
void main() {
  late Dio dio;
  late MockBackendInterceptor mockBackend;
  late BackendIdempotencyService idempotencyService;
  late FailedOpsService failedOpsService;
  late MockOperationProcessor processor;
  late BoxRegistry registry;
  late PendingIndex index;

  // Register adapters once before all tests
  setUpAll(() {
    Hive.registerAdapter(PendingOpAdapter());
    Hive.registerAdapter(FailedOpModelAdapter());
  });

  setUp(() async {
    await setUpTestHive();
    
    // Open boxes
    await Hive.openBox<PendingOp>(BoxRegistry.pendingOpsBox);
    await Hive.openBox<FailedOpModel>(BoxRegistry.failedOpsBox);
    await Hive.openBox(BoxRegistry.pendingIndexBox);
    
    // Initialize services
    dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    mockBackend = MockBackendInterceptor();
    dio.interceptors.add(mockBackend);
    
    idempotencyService = BackendIdempotencyService(client: dio);
    registry = BoxRegistry();
    index = await PendingIndex.create();
    failedOpsService = FailedOpsService(
      registry: registry,
      index: index,
      maxAttempts: 3,
      maxBackoffSeconds: 60,
      retentionDays: 30,
    );
    
    processor = MockOperationProcessor(
      client: dio,
      idempotencyService: idempotencyService,
      failedOpsService: failedOpsService,
      pendingBox: Hive.box<PendingOp>(BoxRegistry.pendingOpsBox),
    );
  });

  tearDown(() async {
    await tearDownTestHive();
  });

  group('E2E Idempotency Flow', () {
    test('Full flow: handshake → operation with idempotency → success', () async {
      // Step 1: Perform handshake
      mockBackend.onPost('https://api.example.com/handshake', (req) {
        return Response(
          requestOptions: req,
          statusCode: 200,
          data: {'status': 'ok'},
          headers: Headers.fromMap({'X-Idempotency-Accepted': ['true']}),
        );
      });
      
      final supported = await idempotencyService.performHandshake(
        handshakeEndpoint: 'https://api.example.com/handshake',
      );
      
      expect(supported, isTrue);
      expect(idempotencyService.support, IdempotencySupport.supported);
      
      // Step 2: Create operation
      final now = DateTime.now().toUtc();
      final op = PendingOp(
        id: 'op-001',
        opType: 'create_device',
        idempotencyKey: 'idem-key-001',
        payload: {'device_id': 'dev-001', 'name': 'Sensor 1'},
        attempts: 0,
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      );
      
      final pendingBox = Hive.box<PendingOp>(BoxRegistry.pendingOpsBox);
      await pendingBox.put(op.id, op);
      
      // Step 3: Mock backend to accept operation
      mockBackend.onPost('/api/operations', (req) {
        final idempKey = req.headers['X-Idempotency-Key'];
        expect(idempKey, 'idem-key-001');
        
        return Response(
          requestOptions: req,
          statusCode: 200,
          data: {'success': true, 'operation_id': 'op-001'},
          headers: Headers.fromMap({'X-Idempotency-Accepted': ['true']}),
        );
      });
      
      // Step 4: Process operation
      final success = await processor.processOperation(op);
      
      expect(success, isTrue);
      expect(pendingBox.get(op.id), isNull); // Removed from pending
      expect(mockBackend.hasSeenKey('idem-key-001'), isTrue);
    });

    test('Deduplication: backend receives duplicate idempotency key', () async {
      // Handshake
      mockBackend.onPost('https://api.example.com/handshake', (req) {
        return Response(
          requestOptions: req,
          statusCode: 200,
          headers: Headers.fromMap({'X-Idempotency-Accepted': ['true']}),
        );
      });
      
      await idempotencyService.performHandshake(
        handshakeEndpoint: 'https://api.example.com/handshake',
      );
      
      final now = DateTime.now().toUtc();
      final pendingBox = Hive.box<PendingOp>(BoxRegistry.pendingOpsBox);
      
      // First operation
      final op1 = PendingOp(
        id: 'op-dup-1',
        opType: 'create_device',
        idempotencyKey: 'idem-duplicate',
        payload: {'device_id': 'dev-dup'},
        attempts: 0,
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      );
      
      await pendingBox.put(op1.id, op1);
      
      int requestCount = 0;
      mockBackend.onPost('/api/operations', (req) {
        requestCount++;
        return Response(
          requestOptions: req,
          statusCode: 200,
          data: {'success': true, 'deduplicated': requestCount > 1},
          headers: Headers.fromMap({'X-Idempotency-Accepted': ['true']}),
        );
      });
      
      // Process first operation
      await processor.processOperation(op1);
      expect(requestCount, 1);
      
      // Second operation with SAME idempotency key (simulating retry/duplicate)
      final op2 = PendingOp(
        id: 'op-dup-2',
        opType: 'create_device',
        idempotencyKey: 'idem-duplicate', // Same key
        payload: {'device_id': 'dev-dup'},
        attempts: 0,
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      );
      
      await pendingBox.put(op2.id, op2);
      
      // Process second operation - backend should recognize duplicate
      await processor.processOperation(op2);
      expect(requestCount, 2);
      expect(mockBackend.hasSeenKey('idem-duplicate'), isTrue);
    });

    test('Retry flow: failed operation moves to FailedOps and retries', () async {
      // Handshake
      mockBackend.onPost('https://api.example.com/handshake', (req) {
        return Response(
          requestOptions: req,
          statusCode: 200,
          headers: Headers.fromMap({'X-Idempotency-Accepted': ['true']}),
        );
      });
      
      await idempotencyService.performHandshake(
        handshakeEndpoint: 'https://api.example.com/handshake',
      );
      
      final now = DateTime.now().toUtc();
      final pendingBox = Hive.box<PendingOp>(BoxRegistry.pendingOpsBox);
      final failedBox = Hive.box<FailedOpModel>(BoxRegistry.failedOpsBox);
      
      final op = PendingOp(
        id: 'op-retry',
        opType: 'update_device',
        idempotencyKey: 'idem-retry-001',
        payload: {'device_id': 'dev-retry', 'status': 'active'},
        attempts: 0,
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      );
      
      await pendingBox.put(op.id, op);
      
      // First attempt: network error
      int attemptCount = 0;
      mockBackend.onPost('/api/operations', (req) {
        attemptCount++;
        if (attemptCount == 1) {
          throw DioException(
            requestOptions: req,
            type: DioExceptionType.connectionTimeout,
            error: 'Connection timeout',
          );
        }
        // Second attempt succeeds
        return Response(
          requestOptions: req,
          statusCode: 200,
          data: {'success': true},
          headers: Headers.fromMap({'X-Idempotency-Accepted': ['true']}),
        );
      });
      
      // First attempt - should fail
      final firstAttempt = await processor.processOperation(op);
      expect(firstAttempt, isFalse);
      expect(pendingBox.get(op.id), isNull); // Removed from pending
      expect(failedBox.length, 1); // Moved to failed
      
      final failedOp = failedBox.values.first;
      expect(failedOp.idempotencyKey, 'idem-retry-001');
      expect(failedOp.sourcePendingOpId, 'op-retry');
      
      // Retry the failed operation
      final retriedOp = await failedOpsService.retryOp(failedOp.id);
      expect(retriedOp.idempotencyKey, 'idem-retry-001'); // Same key
      expect(pendingBox.get(retriedOp.id), isNotNull);
      
      // Second attempt - should succeed
      final secondAttempt = await processor.processOperation(retriedOp);
      expect(secondAttempt, isTrue);
      expect(attemptCount, 2);
    });

    test('Unsupported backend: operations still work without idempotency headers', () async {
      // Handshake indicates no support
      mockBackend.onPost('https://api.example.com/handshake', (req) {
        return Response(
          requestOptions: req,
          statusCode: 200,
          data: {'status': 'ok'},
          // No X-Idempotency-Accepted header
        );
      });
      
      final supported = await idempotencyService.performHandshake(
        handshakeEndpoint: 'https://api.example.com/handshake',
      );
      
      expect(supported, isFalse);
      expect(idempotencyService.support, IdempotencySupport.unsupported);
      
      final now = DateTime.now().toUtc();
      final op = PendingOp(
        id: 'op-no-idem',
        opType: 'create_room',
        idempotencyKey: 'idem-key-no-support',
        payload: {'room_id': 'room-001', 'name': 'Living Room'},
        attempts: 0,
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      );
      
      final pendingBox = Hive.box<PendingOp>(BoxRegistry.pendingOpsBox);
      await pendingBox.put(op.id, op);
      
      mockBackend.onPost('/api/operations', (req) {
        // Idempotency key still sent, but backend doesn't acknowledge
        return Response(
          requestOptions: req,
          statusCode: 200,
          data: {'success': true},
          // No X-Idempotency-Accepted header
        );
      });
      
      // Operation should still succeed (local fallback)
      final success = await processor.processOperation(op);
      expect(success, isTrue);
    });

    test('Backend degradation: previously supported, now unsupported', () async {
      // Initial handshake: supported
      mockBackend.onPost('https://api.example.com/handshake', (req) {
        return Response(
          requestOptions: req,
          statusCode: 200,
          headers: Headers.fromMap({'X-Idempotency-Accepted': ['true']}),
        );
      });
      
      await idempotencyService.performHandshake(
        handshakeEndpoint: 'https://api.example.com/handshake',
      );
      expect(idempotencyService.support, IdempotencySupport.supported);
      
      final now = DateTime.now().toUtc();
      final op = PendingOp(
        id: 'op-degraded',
        opType: 'update_settings',
        idempotencyKey: 'idem-degraded',
        payload: {'setting': 'theme', 'value': 'dark'},
        attempts: 0,
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      );
      
      final pendingBox = Hive.box<PendingOp>(BoxRegistry.pendingOpsBox);
      await pendingBox.put(op.id, op);
      
      // Backend responds without idempotency header (degraded)
      mockBackend.onPost('/api/operations', (req) {
        return Response(
          requestOptions: req,
          statusCode: 200,
          data: {'success': true},
          // No X-Idempotency-Accepted header (degradation)
        );
      });
      
      // Operation should still succeed, but verification will detect degradation
      final success = await processor.processOperation(op);
      expect(success, isTrue);
    });

    test('Multiple operations processed in sequence with idempotency', () async {
      // Handshake
      mockBackend.onPost('https://api.example.com/handshake', (req) {
        return Response(
          requestOptions: req,
          statusCode: 200,
          headers: Headers.fromMap({'X-Idempotency-Accepted': ['true']}),
        );
      });
      
      await idempotencyService.performHandshake(
        handshakeEndpoint: 'https://api.example.com/handshake',
      );
      
      final now = DateTime.now().toUtc();
      final pendingBox = Hive.box<PendingOp>(BoxRegistry.pendingOpsBox);
      
      // Create multiple operations
      final ops = List.generate(5, (i) => PendingOp(
        id: 'op-multi-$i',
        opType: 'create_device',
        idempotencyKey: 'idem-multi-$i',
        payload: {'device_id': 'dev-$i', 'index': i},
        attempts: 0,
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      ));
      
      for (final op in ops) {
        await pendingBox.put(op.id, op);
      }
      
      final processedKeys = <String>[];
      mockBackend.onPost('/api/operations', (req) {
        final key = req.headers['X-Idempotency-Key'] as String;
        processedKeys.add(key);
        
        return Response(
          requestOptions: req,
          statusCode: 200,
          data: {'success': true, 'key': key},
          headers: Headers.fromMap({'X-Idempotency-Accepted': ['true']}),
        );
      });
      
      // Process all operations
      for (final op in ops) {
        final success = await processor.processOperation(op);
        expect(success, isTrue);
      }
      
      expect(processedKeys.length, 5);
      expect(processedKeys, containsAll(['idem-multi-0', 'idem-multi-1', 'idem-multi-2', 'idem-multi-3', 'idem-multi-4']));
      expect(pendingBox.isEmpty, isTrue);
    });

    test('Idempotency key preserved through retry chain', () async {
      // Handshake
      mockBackend.onPost('https://api.example.com/handshake', (req) {
        return Response(
          requestOptions: req,
          statusCode: 200,
          headers: Headers.fromMap({'X-Idempotency-Accepted': ['true']}),
        );
      });
      
      await idempotencyService.performHandshake(
        handshakeEndpoint: 'https://api.example.com/handshake',
      );
      
      final now = DateTime.now().toUtc();
      final pendingBox = Hive.box<PendingOp>(BoxRegistry.pendingOpsBox);
      final failedBox = Hive.box<FailedOpModel>(BoxRegistry.failedOpsBox);
      
      const originalKey = 'idem-preserve-key';
      final op = PendingOp(
        id: 'op-preserve',
        opType: 'delete_device',
        idempotencyKey: originalKey,
        payload: {'device_id': 'dev-delete'},
        attempts: 0,
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      );
      
      await pendingBox.put(op.id, op);
      
      int attemptCount = 0;
      final seenKeys = <String>[];
      
      mockBackend.onPost('/api/operations', (req) {
        attemptCount++;
        final key = req.headers['X-Idempotency-Key'] as String;
        seenKeys.add(key);
        
        if (attemptCount <= 2) {
          throw DioException(
            requestOptions: req,
            type: DioExceptionType.connectionTimeout,
          );
        }
        
        return Response(
          requestOptions: req,
          statusCode: 200,
          data: {'success': true},
          headers: Headers.fromMap({'X-Idempotency-Accepted': ['true']}),
        );
      });
      
      // First attempt fails
      await processor.processOperation(op);
      expect(failedBox.length, 1);
      
      // Retry 1 - also fails, creates second failed op
      var failedOp = failedBox.values.first;
      var retriedOp = await failedOpsService.retryOp(failedOp.id);
      await processor.processOperation(retriedOp);
      expect(failedBox.length, 2); // Now have original + retry failure
      
      // Retry 2 - succeeds, cleans up the retried pending op
      failedOp = failedBox.values.firstWhere((f) => f.attempts == 1);
      retriedOp = await failedOpsService.retryOp(failedOp.id);
      await processor.processOperation(retriedOp);
      
      // Verify same idempotency key used in all attempts
      expect(seenKeys.length, 3);
      expect(seenKeys.every((key) => key == originalKey), isTrue);
    });
  });
}
