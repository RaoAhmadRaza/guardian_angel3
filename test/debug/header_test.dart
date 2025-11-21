import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:guardian_angel_fyp/services/backend_idempotency_service.dart';

void main() {
  test('debug header detection', () {
    // Test 1: Direct Headers construction
    final headers1 = Headers.fromMap({'X-Idempotency-Accepted': ['true']});
    print('Map keys: ${headers1.map.keys}');
    print('Value via .value(): ${headers1.value('X-Idempotency-Accepted')}');
    print('Value via .value() lowercase: ${headers1.value('x-idempotency-accepted')}');
    
    // Test 2: Response with headers
    final response = Response(
      requestOptions: RequestOptions(path: '/test'),
      statusCode: 200,
      headers: Headers.fromMap({'X-Idempotency-Accepted': ['true']}),
    );
    print('Response header value: ${response.headers.value('x-idempotency-accepted')}');
    print('Response header value (uppercase): ${response.headers.value('X-Idempotency-Accepted')}');
  });
}
