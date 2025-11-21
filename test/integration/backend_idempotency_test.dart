import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:guardian_angel_fyp/services/backend_idempotency_service.dart';
import 'package:guardian_angel_fyp/services/telemetry_service.dart';

/// Custom interceptor to mock responses
class MockIdempotencyInterceptor extends Interceptor {
  final Map<String, dynamic Function(RequestOptions)> _handlers = {};

  void onPost(String path, dynamic Function(RequestOptions) handler) {
    _handlers[path] = handler;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final path = options.path;
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

void main() {
  late Dio dio;
  late MockIdempotencyInterceptor mockInterceptor;
  late BackendIdempotencyService service;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    mockInterceptor = MockIdempotencyInterceptor();
    dio.interceptors.add(mockInterceptor);
    service = BackendIdempotencyService(client: dio);
    // Reset telemetry
    TelemetryService.I;
  });

  group('BackendIdempotencyService handshake', () {
    const handshakeUrl = 'https://api.example.com/handshake';

    test('detects backend support when X-Idempotency-Accepted header present', () async {
      mockInterceptor.onPost(handshakeUrl, (req) {
        return Response(
          requestOptions: req,
          statusCode: 200,
          data: {'status': 'ok'},
          headers: Headers.fromMap({'X-Idempotency-Accepted': ['true']}),
        );
      });

      final supported = await service.performHandshake(handshakeEndpoint: handshakeUrl);
      
      expect(supported, isTrue);
      expect(service.support, IdempotencySupport.supported);
      expect(service.supportStatus, contains('Backend supports idempotency'));
    });

    test('detects unsupported backend when header missing', () async {
      mockInterceptor.onPost(handshakeUrl, (req) {
        return Response(
          requestOptions: req,
          statusCode: 200,
          data: {'status': 'ok'},
        );
      });

      final supported = await service.performHandshake(handshakeEndpoint: handshakeUrl);
      
      expect(supported, isFalse);
      expect(service.support, IdempotencySupport.unsupported);
      expect(service.supportStatus, contains('does not support idempotency'));
    });

    test('detects support via body field idempotencyAccepted', () async {
      mockInterceptor.onPost(handshakeUrl, (req) {
        return Response(
          requestOptions: req,
          statusCode: 200,
          data: {'idempotencyAccepted': true},
        );
      });

      final supported = await service.performHandshake(handshakeEndpoint: handshakeUrl);
      
      expect(supported, isTrue);
      expect(service.support, IdempotencySupport.supported);
    });

    test('treats network error as unsupported', () async {
      mockInterceptor.onPost(handshakeUrl, (req) {
        throw DioException(
          requestOptions: req,
          type: DioExceptionType.connectionTimeout,
        );
      });

      final supported = await service.performHandshake(handshakeEndpoint: handshakeUrl);
      
      expect(supported, isFalse);
      expect(service.support, IdempotencySupport.unsupported);
    });

    test('successfully completes handshake request', () async {
      mockInterceptor.onPost(handshakeUrl, (req) {
        return Response(
          requestOptions: req,
          statusCode: 200,
          data: {'status': 'ok'},
          headers: Headers.fromMap({'X-Idempotency-Accepted': ['true']}),
        );
      });

      final supported = await service.performHandshake(handshakeEndpoint: handshakeUrl);
      
      expect(supported, isTrue);
      expect(service.support, IdempotencySupport.supported);
    });

    test('increments telemetry on handshake error', () async {
      mockInterceptor.onPost(handshakeUrl, (req) {
        throw DioException(
          requestOptions: req,
          error: 'Connection failed',
        );
      });

      await service.performHandshake(handshakeEndpoint: handshakeUrl);
      
      final snapshot = TelemetryService.I.snapshot();
      expect(snapshot['counters']['backend_idempotency.handshake.errors'], greaterThanOrEqualTo(1));
      expect(snapshot['gauges']['backend_idempotency.supported'], 0);
    });
  });

  group('BackendIdempotencyService operation verification', () {
    test('verifyOperationResponse accepts header X-Idempotency-Accepted: true', () {
      final response = Response(
        requestOptions: RequestOptions(path: '/ops'),
        statusCode: 200,
        headers: Headers.fromMap({'X-Idempotency-Accepted': ['true']}),
      );

      final accepted = service.verifyOperationResponse(response);
      expect(accepted, isTrue);
    });

    test('verifyOperationResponse rejects when header missing', () {
      final response = Response(
        requestOptions: RequestOptions(path: '/ops'),
        statusCode: 200,
        headers: Headers(),
      );

      final accepted = service.verifyOperationResponse(response);
      expect(accepted, isFalse);
    });

    test('verifyOperationResponse accepts body field idempotencyAccepted', () {
      final response = Response(
        requestOptions: RequestOptions(path: '/ops'),
        statusCode: 200,
        data: {'idempotencyAccepted': true},
      );

      final accepted = service.verifyOperationResponse(response);
      expect(accepted, isTrue);
    });

    test('increments degradation counter when support changes', () async {
      // First mark as supported
      mockInterceptor.onPost('https://api.example.com/handshake', (req) {
        return Response(
          requestOptions: req,
          statusCode: 200,
          data: {'status': 'ok'},
          headers: Headers.fromMap({'X-Idempotency-Accepted': ['true']}),
        );
      });
      await service.performHandshake(handshakeEndpoint: 'https://api.example.com/handshake');
      expect(service.support, IdempotencySupport.supported);

      // Now verify a response without acceptance
      final response = Response(
        requestOptions: RequestOptions(path: '/ops'),
        statusCode: 200,
        headers: Headers(),
      );
      service.verifyOperationResponse(response);

      final snapshot = TelemetryService.I.snapshot();
      expect(snapshot['counters']['backend_idempotency.support_degraded'], greaterThanOrEqualTo(1));
    });
  });

  group('BackendIdempotencyService options builder', () {
    test('buildIdempotentOptions adds X-Idempotency-Key header', () {
      final options = service.buildIdempotentOptions(idempotencyKey: 'test-key-123');
      
      expect(options.headers, isNotNull);
      expect(options.headers!['X-Idempotency-Key'], 'test-key-123');
    });

    test('buildIdempotentOptions preserves existing headers', () {
      final baseOptions = Options(headers: {'Authorization': 'Bearer token'});
      final options = service.buildIdempotentOptions(
        idempotencyKey: 'key-456',
        baseOptions: baseOptions,
      );
      
      expect(options.headers!['Authorization'], 'Bearer token');
      expect(options.headers!['X-Idempotency-Key'], 'key-456');
    });

    test('buildIdempotentOptions preserves other options', () {
      final baseOptions = Options(
        method: 'PUT',
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      );
      final options = service.buildIdempotentOptions(
        idempotencyKey: 'key-789',
        baseOptions: baseOptions,
      );
      
      expect(options.method, 'PUT');
      expect(options.sendTimeout, const Duration(seconds: 10));
      expect(options.receiveTimeout, const Duration(seconds: 15));
    });
  });

  group('BackendIdempotencyService revalidation', () {
    test('shouldRevalidate returns true initially', () {
      expect(service.shouldRevalidate(), isTrue);
    });

    test('shouldRevalidate returns false immediately after handshake', () async {
      mockInterceptor.onPost('https://api.example.com/handshake', (req) {
        return Response(
          requestOptions: req,
          statusCode: 200,
          data: {'status': 'ok'},
          headers: Headers.fromMap({'X-Idempotency-Accepted': ['true']}),
        );
      });

      await service.performHandshake(handshakeEndpoint: 'https://api.example.com/handshake');
      expect(service.shouldRevalidate(), isFalse);
    });

    test('shouldRevalidate returns true after revalidateAfter duration', () async {
      mockInterceptor.onPost('https://api.example.com/handshake', (req) {
        return Response(
          requestOptions: req,
          statusCode: 200,
          data: {'status': 'ok'},
          headers: Headers.fromMap({'X-Idempotency-Accepted': ['true']}),
        );
      });

      await service.performHandshake(handshakeEndpoint: 'https://api.example.com/handshake');
      
      // Check revalidation with very short duration
      expect(service.shouldRevalidate(revalidateAfter: Duration.zero), isTrue);
    });
  });

  group('BackendIdempotencyService header detection', () {
    test('accepts lowercase x-idempotency-accepted header', () {
      final response = Response(
        requestOptions: RequestOptions(path: '/ops'),
        statusCode: 200,
        headers: Headers.fromMap({'x-idempotency-accepted': ['true']}),
      );

      final accepted = service.verifyOperationResponse(response);
      expect(accepted, isTrue);
    });

    test('accepts value "1" as true', () {
      final response = Response(
        requestOptions: RequestOptions(path: '/ops'),
        statusCode: 200,
        headers: Headers.fromMap({'X-Idempotency-Accepted': ['1']}),
      );

      final accepted = service.verifyOperationResponse(response);
      expect(accepted, isTrue);
    });

    test('rejects value "false"', () {
      final response = Response(
        requestOptions: RequestOptions(path: '/ops'),
        statusCode: 200,
        headers: Headers.fromMap({'X-Idempotency-Accepted': ['false']}),
      );

      final accepted = service.verifyOperationResponse(response);
      expect(accepted, isFalse);
    });
  });
}
