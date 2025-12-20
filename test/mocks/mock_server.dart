// test/mocks/mock_server.dart
// Deterministic mock HTTP server for testing sync engine
// Supports: idempotency, 429 with Retry-After, 5xx errors, 409 conflicts

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Mock HTTP server for sync engine testing
/// Provides deterministic responses for testing idempotency, retries, conflicts
class MockServer {
  HttpServer? _server;
  int _port = 0;
  
  /// All requests received by server (for assertions)
  final List<MockRequest> requests = [];
  
  /// Idempotency store: key -> response
  final Map<String, Map<String, dynamic>> idempotencyStore = {};
  
  /// Behavior configuration
  MockServerBehavior behavior = MockServerBehavior();
  
  /// Response delays (simulate network latency)
  Duration responseDelay = Duration.zero;

  /// Start server on specified port (0 = random available port)
  Future<int> start({int port = 0}) async {
    final handler = Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_recordRequests())
        .addHandler(_router);
    
    _server = await shelf_io.serve(handler, '127.0.0.1', port);
    _port = _server!.port;
    print('MockServer started on http://127.0.0.1:$_port');
    return _port;
  }

  /// Stop server
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    print('MockServer stopped');
  }

  /// Get server base URL
  String get baseUrl => 'http://127.0.0.1:$_port';

  /// Clear all recorded requests and idempotency state
  void reset() {
    requests.clear();
    idempotencyStore.clear();
    behavior = MockServerBehavior();
    responseDelay = Duration.zero;
  }

  /// Middleware to record all requests
  Middleware _recordRequests() {
    return (Handler innerHandler) {
      return (Request request) async {
        final body = await request.readAsString();
        
        requests.add(MockRequest(
          method: request.method,
          path: request.url.path,
          headers: Map.from(request.headers),
          body: body,
          timestamp: DateTime.now(),
        ));
        
        // Recreate request with body (it's consumed after readAsString)
        final newRequest = request.change(body: body);
        
        return await innerHandler(newRequest);
      };
    };
  }

  /// Main router
  Future<Response> _router(Request req) async {
    // Simulate network delay
    if (responseDelay > Duration.zero) {
      await Future.delayed(responseDelay);
    }

    final path = req.url.path;
    final method = req.method;
    final body = await req.readAsString();
    final idempKey = req.headers['idempotency-key'];
    final auth = req.headers['authorization'];

    // Check idempotency first
    if (idempKey != null && idempotencyStore.containsKey(idempKey)) {
      final cached = idempotencyStore[idempKey]!;
      return Response(
        cached['status'] as int? ?? 200,
        body: jsonEncode(cached['body']),
        headers: {'content-type': 'application/json'},
      );
    }

    // Check auth requirement
    if (behavior.requireAuth && (auth == null || !auth.startsWith('Bearer '))) {
      return Response(401, body: jsonEncode({
        'error': {'code': 'UNAUTHORIZED', 'message': 'Missing or invalid token'}
      }), headers: {'content-type': 'application/json'});
    }

    // Test behavior routes
    if (path == 'error/429') {
      return Response(429, headers: {
        'retry-after': behavior.retryAfterSeconds.toString(),
        'content-type': 'application/json',
      }, body: jsonEncode({'error': {'code': 'RATE_LIMIT', 'message': 'Too many requests'}}));
    }

    if (path == 'error/500') {
      return Response(500, body: jsonEncode({
        'error': {'code': 'INTERNAL_ERROR', 'message': 'Server error'}
      }), headers: {'content-type': 'application/json'});
    }

    if (path == 'error/503') {
      return Response(503, headers: {
        'retry-after': '5',
        'content-type': 'application/json',
      }, body: jsonEncode({'error': {'code': 'SERVICE_UNAVAILABLE', 'message': 'Service temporarily unavailable'}}));
    }

    if (path == 'error/409') {
      return Response(409, body: jsonEncode({
        'error': {
          'code': 'CONFLICT',
          'message': 'Resource conflict',
          'details': {'server_version': behavior.conflictVersion}
        }
      }), headers: {'content-type': 'application/json'});
    }

    // API routes
    if (path == 'devices' && method == 'POST') {
      return _handleDeviceCreate(req, body, idempKey);
    }

    if (path.startsWith('devices/') && method == 'PUT') {
      final deviceId = path.split('/').last;
      return _handleDeviceUpdate(req, deviceId, body, idempKey);
    }

    if (path.startsWith('devices/') && method == 'DELETE') {
      final deviceId = path.split('/').last;
      return _handleDeviceDelete(req, deviceId, idempKey);
    }

    if (path == 'rooms' && method == 'POST') {
      return _handleRoomCreate(req, body, idempKey);
    }

    if (path.startsWith('rooms/') && method == 'PUT') {
      final roomId = path.split('/').last;
      return _handleRoomUpdate(req, roomId, body, idempKey);
    }

    if (path == 'auth/refresh' && method == 'POST') {
      return _handleAuthRefresh(req, body);
    }

    // Default: 404
    return Response.notFound(
      jsonEncode({'error': {'code': 'NOT_FOUND', 'message': 'Endpoint not found'}}),
      headers: {'content-type': 'application/json'},
    );
  }

  // Handler methods
  Response _handleDeviceCreate(Request req, String body, String? idempKey) {
    final response = {
      'status': 'ok',
      'deviceId': 'dev-${DateTime.now().millisecondsSinceEpoch}',
      'name': _extractField(body, 'name') ?? 'Unknown Device',
      'createdAt': DateTime.now().toIso8601String(),
    };

    // Store in idempotency cache
    if (idempKey != null) {
      idempotencyStore[idempKey] = {'status': 201, 'body': response};
    }

    return Response(201, 
      body: jsonEncode(response),
      headers: {'content-type': 'application/json'},
    );
  }

  Response _handleDeviceUpdate(Request req, String deviceId, String body, String? idempKey) {
    // Check for conflict scenario
    if (behavior.simulateConflict) {
      return Response(409, body: jsonEncode({
        'error': {
          'code': 'CONFLICT',
          'message': 'Device version mismatch',
          'details': {'server_version': behavior.conflictVersion, 'device_id': deviceId}
        }
      }), headers: {'content-type': 'application/json'});
    }

    final response = {
      'status': 'ok',
      'deviceId': deviceId,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    if (idempKey != null) {
      idempotencyStore[idempKey] = {'status': 200, 'body': response};
    }

    return Response.ok(
      jsonEncode(response),
      headers: {'content-type': 'application/json'},
    );
  }

  Response _handleDeviceDelete(Request req, String deviceId, String? idempKey) {
    final response = {
      'status': 'ok',
      'deviceId': deviceId,
      'deletedAt': DateTime.now().toIso8601String(),
    };

    if (idempKey != null) {
      idempotencyStore[idempKey] = {'status': 200, 'body': response};
    }

    return Response.ok(
      jsonEncode(response),
      headers: {'content-type': 'application/json'},
    );
  }

  Response _handleRoomCreate(Request req, String body, String? idempKey) {
    final response = {
      'status': 'ok',
      'roomId': 'room-${DateTime.now().millisecondsSinceEpoch}',
      'name': _extractField(body, 'name') ?? 'Unknown Room',
      'createdAt': DateTime.now().toIso8601String(),
    };

    if (idempKey != null) {
      idempotencyStore[idempKey] = {'status': 201, 'body': response};
    }

    return Response(201,
      body: jsonEncode(response),
      headers: {'content-type': 'application/json'},
    );
  }

  Response _handleRoomUpdate(Request req, String roomId, String body, String? idempKey) {
    final response = {
      'status': 'ok',
      'roomId': roomId,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    if (idempKey != null) {
      idempotencyStore[idempKey] = {'status': 200, 'body': response};
    }

    return Response.ok(
      jsonEncode(response),
      headers: {'content-type': 'application/json'},
    );
  }

  Response _handleAuthRefresh(Request req, String body) {
    final refreshToken = _extractField(body, 'refresh_token');
    
    if (refreshToken == null || refreshToken.isEmpty) {
      return Response(401, body: jsonEncode({
        'error': {'code': 'INVALID_TOKEN', 'message': 'Invalid refresh token'}
      }), headers: {'content-type': 'application/json'});
    }

    final response = {
      'access_token': 'new_access_token_${DateTime.now().millisecondsSinceEpoch}',
      'refresh_token': 'new_refresh_token_${DateTime.now().millisecondsSinceEpoch}',
      'expires_in': 3600,
    };

    return Response.ok(
      jsonEncode(response),
      headers: {'content-type': 'application/json'},
    );
  }

  // Utility to extract field from JSON body
  String? _extractField(String body, String field) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json[field]?.toString();
    } catch (e) {
      return null;
    }
  }
}

/// Recorded request for assertions
class MockRequest {
  final String method;
  final String path;
  final Map<String, String> headers;
  final String body;
  final DateTime timestamp;

  MockRequest({
    required this.method,
    required this.path,
    required this.headers,
    required this.body,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'method': method,
      'path': path,
      'headers': headers,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String toString() => '$method /$path';
}

/// Server behavior configuration
class MockServerBehavior {
  /// Require Authorization header
  bool requireAuth = false;
  
  /// Retry-After value for 429 responses (seconds)
  int retryAfterSeconds = 2;
  
  /// Simulate conflict on updates
  bool simulateConflict = false;
  
  /// Server version for conflict responses
  int conflictVersion = 5;

  /// Reset to defaults
  void reset() {
    requireAuth = false;
    retryAfterSeconds = 2;
    simulateConflict = false;
    conflictVersion = 5;
  }
}
