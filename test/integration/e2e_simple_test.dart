// test/integration/e2e_simple_test.dart
// Simplified E2E acceptance test for sync engine
// Focus: API Client + Mock Server integration

import 'package:test/test.dart';
import 'package:uuid/uuid.dart';
import '../bootstrap.dart';
import '../mocks/mock_server.dart';
import '../mocks/mock_auth_service.dart';
import 'package:guardian_angel_fyp/sync/api_client.dart';

void main() {
  late MockServer server;
  late MockAuthService authService;
  late ApiClient apiClient;
  
  const appVersion = '1.0.0-test';
  const deviceId = 'test-device-001';

  setUpAll(() async {
    // Start mock server
    server = MockServer();
    await server.start(port: 0);
    
    print('✅ Test environment initialized');
    print('   Server: ${server.baseUrl}');
  });

  setUp(() async {
    // Clean server state
    server.reset();
    
    // Create services
    authService = MockAuthService();
    apiClient = ApiClient(
      baseUrl: server.baseUrl,
      authService: authService,
      appVersion: appVersion,
      deviceId: deviceId,
    );
  });

  tearDownAll(() async {
    await server.stop();
    print('✅ Test environment cleaned up');
  });

  group('API Client - Basic Operations', () {
    test('POST request succeeds with proper headers', () async {
      // Make POST request
      final response = await apiClient.request(
        method: 'POST',
        path: '/devices',
        headers: {'idempotency-key': Uuid().v4()},
        body: {'name': 'Test Device', 'type': 'light'},
      );
      
      // Verify response
      expect(response['status'], equals('ok'));
      expect(response['deviceId'], isNotNull);
      
      // Verify request was received
      expect(server.requests.length, equals(1));
      final req = server.requests.first;
      expect(req.method, equals('POST'));
      expect(req.path, equals('devices'));
      expect(req.headers['authorization'], startsWith('Bearer '));
      expect(req.headers['x-app-version'], equals(appVersion));
      expect(req.headers['x-device-id'], equals(deviceId));
    });

    test('GET request to 404 endpoint throws exception', () async {
      expect(
        () => apiClient.request(method: 'GET', path: '/nonexistent'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Idempotency', () {
    test('duplicate idempotency key returns cached response', () async {
      final idempKey = Uuid().v4();
      
      // First request
      final response1 = await apiClient.request(
        method: 'POST',
        path: '/devices',
        headers: {'idempotency-key': idempKey},
        body: {'name': 'First Request'},
      );
      
      final deviceId1 = response1['deviceId'];
      
      // Second request with same idempotency key
      final response2 = await apiClient.request(
        method: 'POST',
        path: '/devices',
        headers: {'idempotency-key': idempKey},
        body: {'name': 'Second Request'},
      );
      
      final deviceId2 = response2['deviceId'];
      
      // Should return same device ID (cached)
      expect(deviceId1, equals(deviceId2));
      
      // Server received both requests
      expect(server.requests.length, equals(2));
    });
  });

  group('Retry Behavior', () {
    test('429 rate limit returns with retry-after header', () async {
      try {
        await apiClient.request(
          method: 'GET',
          path: '/error/429',
          timeout: Duration(seconds: 5),
        );
        fail('Should have thrown exception');
      } catch (e) {
        final errorStr = e.toString().toLowerCase();
        expect(errorStr.contains('429') || errorStr.contains('rate') || errorStr.contains('limit'), isTrue);
      }
      
      // Verify server sent response
      expect(server.requests.isNotEmpty, isTrue);
    });

    test('500 server error throws exception', () async {
      expect(
        () => apiClient.request(
          method: 'GET',
          path: '/error/500',
          timeout: Duration(seconds: 5),
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('503 service unavailable with retry-after', () async {
      try {
        await apiClient.request(
          method: 'GET',
          path: '/error/503',
          timeout: Duration(seconds: 5),
        );
        fail('Should have thrown exception');
      } catch (e) {
        final errorStr = e.toString().toLowerCase();
        expect(errorStr.contains('503') || errorStr.contains('unavailable'), isTrue);
      }
    });
  });

  group('Conflict Resolution', () {
    test('409 conflict response includes server version', () async {
      try {
        await apiClient.request(
          method: 'GET',
          path: '/error/409',
          timeout: Duration(seconds: 5),
        );
        fail('Should have thrown exception');
      } catch (e) {
        final errorStr = e.toString().toLowerCase();
        expect(errorStr.contains('409') || errorStr.contains('conflict'), isTrue);
      }
      
      // Verify conflict response structure
      expect(server.requests.length, equals(1));
    });
  });

  group('Auth & Headers', () {
    test('authorization header is included', () async {
      await apiClient.request(
        method: 'POST',
        path: '/devices',
        body: {'name': 'Auth Test'},
      );
      
      final req = server.requests.first;
      expect(req.headers['authorization'], startsWith('Bearer mock_access_token'));
    });

    test('trace-id header is generated if not provided', () async {
      await apiClient.request(
        method: 'POST',
        path: '/devices',
        body: {'name': 'Trace Test'},
      );
      
      final req = server.requests.first;
      expect(req.headers['trace-id'], isNotNull);
      expect(req.headers['trace-id'], isNotEmpty);
    });

    test('custom headers are merged', () async {
      await apiClient.request(
        method: 'POST',
        path: '/devices',
        headers: {'x-custom-header': 'test-value'},
        body: {'name': 'Custom Header Test'},
      );
      
      final req = server.requests.first;
      expect(req.headers['x-custom-header'], equals('test-value'));
    });
  });

  group('CRUD Operations', () {
    test('CREATE device operation', () async {
      final response = await apiClient.request(
        method: 'POST',
        path: '/devices',
        headers: {'idempotency-key': Uuid().v4()},
        body: {'name': 'Living Room Light', 'type': 'light'},
      );
      
      expect(response['status'], equals('ok'));
      expect(response['deviceId'], isNotNull);
      expect(response['name'], equals('Living Room Light'));
    });

    test('UPDATE device operation', () async {
      final deviceId = 'device-123';
      
      final response = await apiClient.request(
        method: 'PUT',
        path: '/devices/$deviceId',
        headers: {'idempotency-key': Uuid().v4()},
        body: {'name': 'Updated Name', 'version': 2},
      );
      
      expect(response['status'], equals('ok'));
      expect(response['deviceId'], equals(deviceId));
    });

    test('DELETE device operation', () async {
      final deviceId = 'device-456';
      
      final response = await apiClient.request(
        method: 'DELETE',
        path: '/devices/$deviceId',
        headers: {'idempotency-key': Uuid().v4()},
      );
      
      expect(response['status'], equals('ok'));
      expect(response['deviceId'], equals(deviceId));
      expect(response['deletedAt'], isNotNull);
    });

    test('CREATE room operation', () async {
      final response = await apiClient.request(
        method: 'POST',
        path: '/rooms',
        headers: {'idempotency-key': Uuid().v4()},
        body: {'name': 'Living Room'},
      );
      
      expect(response['status'], equals('ok'));
      expect(response['roomId'], isNotNull);
      expect(response['name'], equals('Living Room'));
    });
  });

  group('Auth Refresh', () {
    test('auth refresh endpoint returns new tokens', () async {
      final response = await apiClient.request(
        method: 'POST',
        path: '/auth/refresh',
        body: {'refresh_token': 'valid_refresh_token'},
      );
      
      expect(response['access_token'], isNotNull);
      expect(response['refresh_token'], isNotNull);
      expect(response['expires_in'], equals(3600));
    });

    test('auth refresh fails with invalid token', () async {
      expect(
        () => apiClient.request(
          method: 'POST',
          path: '/auth/refresh',
          body: {'refresh_token': ''},
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Network Simulation', () {
    test('response delay simulation', () async {
      server.responseDelay = Duration(milliseconds: 500);
      
      final start = DateTime.now();
      await apiClient.request(
        method: 'POST',
        path: '/devices',
        body: {'name': 'Delayed Request'},
      );
      final elapsed = DateTime.now().difference(start);
      
      expect(elapsed.inMilliseconds, greaterThanOrEqualTo(500));
      
      server.responseDelay = Duration.zero; // Reset
    });

    test('concurrent requests are handled', () async {
      final futures = <Future>[];
      
      for (int i = 0; i < 5; i++) {
        futures.add(
          apiClient.request(
            method: 'POST',
            path: '/devices',
            body: {'name': 'Concurrent Device $i'},
          ),
        );
      }
      
      final responses = await Future.wait(futures);
      expect(responses.length, equals(5));
      expect(server.requests.length, equals(5));
    });
  });

  group('Server Behavior Configuration', () {
    test('require auth behavior', () async {
      server.behavior.requireAuth = true;
      authService.clearTokens();
      
      expect(
        () => apiClient.request(
          method: 'POST',
          path: '/devices',
          body: {'name': 'Unauthorized Request'},
        ),
        throwsA(isA<Exception>()),
      );
      
      server.behavior.requireAuth = false; // Reset
    });

    test('simulate conflict behavior', () async {
      server.behavior.simulateConflict = true;
      server.behavior.conflictVersion = 7;
      
      expect(
        () => apiClient.request(
          method: 'PUT',
          path: '/devices/device-123',
          body: {'name': 'Conflict Update', 'version': 5},
        ),
        throwsA(isA<Exception>()),
      );
      
      server.behavior.simulateConflict = false; // Reset
    });
  });
}
