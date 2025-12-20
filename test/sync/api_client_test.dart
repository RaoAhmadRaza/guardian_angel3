import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:guardian_angel_fyp/sync/api_client.dart';
import 'package:guardian_angel_fyp/sync/auth_service.dart';
import 'package:guardian_angel_fyp/sync/exceptions.dart';

@GenerateMocks([http.Client, AuthService])
import 'api_client_test.mocks.dart';

void main() {
  group('ApiClient', () {
    late MockClient mockClient;
    late MockAuthService mockAuth;
    late ApiClient apiClient;

    setUp(() {
      mockClient = MockClient();
      mockAuth = MockAuthService();
      apiClient = ApiClient(
        client: mockClient,
        authService: mockAuth,
        baseUrl: 'https://api.test.com',
        appVersion: '1.0.0',
        deviceId: 'test-device-123',
      );
    });

    group('Error Mapping', () {
      test('400 Bad Request maps to ValidationException', () async {
        when(mockAuth.getAccessToken()).thenAnswer((_) async => 'token123');
        when(mockClient.send(any)).thenAnswer((_) async {
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({
              'error': 'validation_error',
              'fields': {'name': 'required'}
            }))),
            400,
            headers: {'content-type': 'application/json'},
          );
        });

        expect(
          () => apiClient.request(method: 'POST', path: '/users', body: {}),
          throwsA(isA<ValidationException>()
              .having((e) => e.httpStatus, 'httpStatus', 400)
              .having((e) => e.field, 'field', isNotNull)),
        );
      });

      test('401 Unauthorized maps to AuthException', () async {
        when(mockAuth.getAccessToken()).thenAnswer((_) async => 'invalid_token');
        when(mockAuth.tryRefresh()).thenAnswer((_) async => false);
        when(mockClient.send(any)).thenAnswer((_) async {
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({
              'error': 'token_expired',
              'requires_login': true
            }))),
            401,
            headers: {'content-type': 'application/json'},
          );
        });

        expect(
          () => apiClient.request(method: 'GET', path: '/profile'),
          throwsA(isA<AuthException>()
              .having((e) => e.httpStatus, 'httpStatus', 401)
              .having((e) => e.requiresLogin, 'requiresLogin', true)),
        );
      });

      test('403 Forbidden maps to PermissionDeniedException', () async {
        when(mockAuth.getAccessToken()).thenAnswer((_) async => 'token123');
        when(mockClient.send(any)).thenAnswer((_) async {
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({
              'error': 'insufficient_permissions'
            }))),
            403,
            headers: {'content-type': 'application/json'},
          );
        });

        expect(
          () => apiClient.request(method: 'DELETE', path: '/admin'),
          throwsA(isA<PermissionDeniedException>()
              .having((e) => e.httpStatus, 'httpStatus', 403)),
        );
      });

      test('404 Not Found maps to ResourceNotFoundException', () async {
        when(mockAuth.getAccessToken()).thenAnswer((_) async => 'token123');
        when(mockClient.send(any)).thenAnswer((_) async {
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({
              'error': 'user_not_found',
              'resource_id': 'user-123'
            }))),
            404,
            headers: {'content-type': 'application/json'},
          );
        });

        expect(
          () => apiClient.request(method: 'GET', path: '/users/123'),
          throwsA(isA<ResourceNotFoundException>()
              .having((e) => e.httpStatus, 'httpStatus', 404)
              .having((e) => e.resourceId, 'resourceId', 'user-123')),
        );
      });

      test('409 Conflict maps to ConflictException', () async {
        when(mockAuth.getAccessToken()).thenAnswer((_) async => 'token123');
        when(mockClient.send(any)).thenAnswer((_) async {
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({
              'error': 'version_conflict',
              'conflict_type': 'version_mismatch',
              'server_version': 5,
              'client_version': 3
            }))),
            409,
            headers: {'content-type': 'application/json'},
          );
        });

        expect(
          () => apiClient.request(method: 'PUT', path: '/rooms/123', body: {}),
          throwsA(isA<ConflictException>()
              .having((e) => e.httpStatus, 'httpStatus', 409)
              .having((e) => e.conflictType, 'conflictType', 'version_mismatch')
              .having((e) => e.serverVersion, 'serverVersion', 5)
              .having((e) => e.clientVersion, 'clientVersion', 3)),
        );
      });

      test('429 Rate Limit maps to RetryableException with Retry-After', () async {
        when(mockAuth.getAccessToken()).thenAnswer((_) async => 'token123');
        when(mockClient.send(any)).thenAnswer((_) async {
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({
              'error': 'rate_limit_exceeded'
            }))),
            429,
            headers: {
              'content-type': 'application/json',
              'retry-after': '60',
            },
          );
        });

        expect(
          () => apiClient.request(method: 'POST', path: '/events', body: {}),
          throwsA(isA<RetryableException>()
              .having((e) => e.httpStatus, 'httpStatus', 429)
              .having((e) => e.retryAfter, 'retryAfter',
                  const Duration(seconds: 60))),
        );
      });

      test('500 Internal Server Error maps to ServerException', () async {
        when(mockAuth.getAccessToken()).thenAnswer((_) async => 'token123');
        when(mockClient.send(any)).thenAnswer((_) async {
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({
              'error': 'database_error'
            }))),
            500,
            headers: {'content-type': 'application/json'},
          );
        });

        expect(
          () => apiClient.request(method: 'GET', path: '/data'),
          throwsA(isA<ServerException>()
              .having((e) => e.httpStatus, 'httpStatus', 500)
              .having((e) => e.isRetryable, 'isRetryable', true)),
        );
      });

      test('503 Service Unavailable maps to ServiceUnavailableException', () async {
        when(mockAuth.getAccessToken()).thenAnswer((_) async => 'token123');
        when(mockClient.send(any)).thenAnswer((_) async {
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({
              'error': 'maintenance'
            }))),
            503,
            headers: {
              'content-type': 'application/json',
              'retry-after': '300',
            },
          );
        });

        expect(
          () => apiClient.request(method: 'GET', path: '/health'),
          throwsA(isA<ServiceUnavailableException>()
              .having((e) => e.httpStatus, 'httpStatus', 503)
              .having((e) => e.isRetryable, 'isRetryable', true)),
        );
      });
    });

    group('Token Refresh', () {
      test('Refreshes token on 401 and retries request', () async {
        var callCount = 0;
        when(mockAuth.getAccessToken()).thenAnswer((_) async {
          return callCount == 0 ? 'expired_token' : 'new_token';
        });
        when(mockAuth.tryRefresh()).thenAnswer((_) async {
          callCount++;
          return true;
        });
        when(mockClient.send(any)).thenAnswer((_) async {
          if (callCount == 0) {
            return http.StreamedResponse(
              Stream.value(utf8.encode(jsonEncode({
                'error': 'token_expired'
              }))),
              401,
            );
          } else {
            return http.StreamedResponse(
              Stream.value(utf8.encode(jsonEncode({
                'data': 'success'
              }))),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
        });

        final result = await apiClient.request(method: 'GET', path: '/profile');
        expect(result, {'data': 'success'});
        verify(mockAuth.tryRefresh()).called(1);
      });
    });

    group('Header Injection', () {
      test('Injects required headers', () async {
        when(mockAuth.getAccessToken()).thenAnswer((_) async => 'token123');
        when(mockClient.send(any)).thenAnswer((_) async {
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({'data': 'ok'}))),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        await apiClient.request(
          method: 'POST',
          path: '/events',
          body: {},
          headers: {
            'Idempotency-Key': 'idem-123',
            'Trace-Id': 'trace-456',
          },
        );

        final captured = verify(mockClient.send(captureAny)).captured.first
            as http.BaseRequest;
        expect(captured.headers['authorization'], 'Bearer token123');
        expect(captured.headers['idempotency-key'], 'idem-123');
        expect(captured.headers['trace-id'], 'trace-456');
        expect(captured.headers['x-app-version'], isNotNull);
        expect(captured.headers['x-device-id'], isNotNull);
      });
    });

    group('Retry-After Parsing', () {
      test('Parses Retry-After as seconds (integer)', () async {
        when(mockAuth.getAccessToken()).thenAnswer((_) async => 'token123');
        when(mockClient.send(any)).thenAnswer((_) async {
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({'error': 'rate_limited'}))),
            429,
            headers: {
              'retry-after': '120',
            },
          );
        });

        try {
          await apiClient.request(method: 'POST', path: '/events', body: {});
          fail('Should have thrown RetryableException');
        } on RetryableException catch (e) {
          expect(e.retryAfter, const Duration(seconds: 120));
        }
      });

      test('Parses Retry-After as HTTP-date (RFC 7231)', () async {
        when(mockAuth.getAccessToken()).thenAnswer((_) async => 'token123');
        final futureDate = DateTime.now().toUtc().add(const Duration(seconds: 60));
        final httpDate = _formatHttpDate(futureDate);

        when(mockClient.send(any)).thenAnswer((_) async {
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({'error': 'rate_limited'}))),
            429,
            headers: {
              'retry-after': httpDate,
            },
          );
        });

        try {
          await apiClient.request(method: 'POST', path: '/events', body: {});
          fail('Should have thrown RetryableException');
        } on RetryableException catch (e) {
          expect(e.retryAfter!.inSeconds, greaterThanOrEqualTo(55));
          expect(e.retryAfter!.inSeconds, lessThanOrEqualTo(65));
        }
      });
    });
  });
}

// Helper to format HTTP-date (RFC 7231)
String _formatHttpDate(DateTime date) {
  final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];

  final weekday = weekdays[date.weekday - 1];
  final day = date.day.toString().padLeft(2, '0');
  final month = months[date.month - 1];
  final year = date.year;
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  final second = date.second.toString().padLeft(2, '0');

  return '$weekday, $day $month $year $hour:$minute:$second GMT';
}
