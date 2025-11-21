import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:guardian_angel_fyp/services/backend_idempotency_service.dart';

class TestInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    print('Request to: ${options.path}');
    final response = Response(
      requestOptions: options,
      statusCode: 200,
      data: {'status': 'ok'},
      headers: Headers.fromMap({'X-Idempotency-Accepted': ['true']}),
    );
    print('Resolving with headers: ${response.headers.map}');
    print('Header value check: ${response.headers.value('X-Idempotency-Accepted')}');
    handler.resolve(response);
  }
}

void main() {
  test('debug handshake call', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    dio.interceptors.add(TestInterceptor());
    final service = BackendIdempotencyService(client: dio);
    
    final result = await service.performHandshake(
      handshakeEndpoint: 'https://api.example.com/handshake',
    );
    
    print('Result: $result');
    print('Support: ${service.support}');
    print('Status: ${service.supportStatus}');
    
    expect(result, isTrue);
  });
}
