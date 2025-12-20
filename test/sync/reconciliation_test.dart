import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:guardian_angel_fyp/sync/reconciler.dart';
import 'package:guardian_angel_fyp/sync/api_client.dart';
import 'package:guardian_angel_fyp/sync/auth_service.dart';
import 'package:guardian_angel_fyp/sync/exceptions.dart';
import 'package:guardian_angel_fyp/sync/models/pending_op.dart';

@GenerateMocks([http.Client, AuthService])
import 'reconciliation_test.mocks.dart';

/// Reconciliation tests
/// 
/// Validates conflict resolution strategies for 409 responses:
/// - Version mismatch handling
/// - Server-side merge logic
/// - Duplicate detection
void main() {
  group('Reconciliation', () {
    late MockClient mockClient;
    late MockAuthService mockAuth;
    late ApiClient apiClient;
    late Reconciler reconciler;

    setUp(() {
      mockClient = MockClient();
      mockAuth = MockAuthService();
      apiClient = ApiClient(
        client: mockClient,
        authService: mockAuth,
        baseUrl: 'https://api.test.com',
        appVersion: '1.0.0',
        deviceId: 'test-device',
      );
      reconciler = Reconciler(apiClient);
    });

    test('UPDATE conflict - merges with server state', () async {
      final op = PendingOp(
        id: 'op-update-conflict',
        opType: 'UPDATE',
        entityType: 'ROOM',
        payload: {
          'id': 'room-123',
          'name': 'Living Room (Updated)',
          'temperature': 72,
          'version': 3,
        },
        idempotencyKey: 'idem-update',
      );

      final conflict = ConflictException(
        message: 'Version mismatch',
        conflictType: 'version_mismatch',
        serverVersion: 5,
        clientVersion: 3,
        httpStatus: 409,
      );

      // Mock GET request to fetch latest server state
      when(mockAuth.getAccessToken()).thenAnswer((_) async => 'token123');
      when(mockClient.get(any, headers: anyNamed('headers')))
          .thenAnswer((_) async => http.Response(
                jsonEncode({
                  'id': 'room-123',
                  'name': 'Living Room',
                  'temperature': 70,
                  'humidity': 45,
                  'version': 5,
                }),
                200,
                headers: {'content-type': 'application/json'},
              ));

      // Reconcile conflict
      final resolved = await reconciler.reconcileConflict(op, conflict);

      expect(resolved, true);
      expect(op.payload['version'], 5); // Updated to server version
      expect(op.payload['name'], 'Living Room (Updated)'); // Local change preserved
      expect(op.payload['temperature'], 72); // Local change preserved
      expect(op.payload['humidity'], 45); // Server field merged

      verify(mockClient.get(any, headers: anyNamed('headers'))).called(1);
    });

    test('CREATE conflict - resource already exists with matching state', () async {
      final op = PendingOp(
        id: 'op-create-conflict',
        opType: 'CREATE',
        entityType: 'DEVICE',
        payload: {
          'id': 'device-456',
          'name': 'Smart Light',
          'type': 'light',
        },
        idempotencyKey: 'idem-create',
      );

      final conflict = ConflictException(
        message: 'Resource already exists',
        conflictType: 'duplicate',
        httpStatus: 409,
      );

      // Mock GET request returns existing resource with matching state
      when(mockAuth.getAccessToken()).thenAnswer((_) async => 'token123');
      when(mockClient.get(any, headers: anyNamed('headers')))
          .thenAnswer((_) async => http.Response(
                jsonEncode({
                  'id': 'device-456',
                  'name': 'Smart Light',
                  'type': 'light',
                  'created_at': '2025-01-01T00:00:00Z',
                }),
                200,
                headers: {'content-type': 'application/json'},
              ));

      // Reconcile conflict
      final resolved = await reconciler.reconcileConflict(op, conflict);

      expect(resolved, true); // Idempotent create treated as success

      verify(mockClient.get(any, headers: anyNamed('headers'))).called(1);
    });

    test('CREATE conflict - resource exists but differs', () async {
      final op = PendingOp(
        id: 'op-create-conflict-diff',
        opType: 'CREATE',
        entityType: 'DEVICE',
        payload: {
          'id': 'device-789',
          'name': 'Smart Thermostat',
          'type': 'thermostat',
        },
        idempotencyKey: 'idem-create-diff',
      );

      final conflict = ConflictException(
        message: 'Resource already exists',
        conflictType: 'duplicate',
        httpStatus: 409,
      );

      // Mock GET request returns existing resource with different state
      when(mockAuth.getAccessToken()).thenAnswer((_) async => 'token123');
      when(mockClient.get(any, headers: anyNamed('headers')))
          .thenAnswer((_) async => http.Response(
                jsonEncode({
                  'id': 'device-789',
                  'name': 'Different Device',
                  'type': 'sensor',
                }),
                200,
                headers: {'content-type': 'application/json'},
              ));

      // Reconcile conflict
      final resolved = await reconciler.reconcileConflict(op, conflict);

      expect(resolved, false); // Cannot reconcile - different resource

      verify(mockClient.get(any, headers: anyNamed('headers'))).called(1);
    });

    test('DELETE conflict - resource already deleted', () async {
      final op = PendingOp(
        id: 'op-delete-conflict',
        opType: 'DELETE',
        entityType: 'USER',
        payload: {'id': 'user-999'},
        idempotencyKey: 'idem-delete',
      );

      final conflict = ConflictException(
        message: 'Resource not found',
        conflictType: 'not_found',
        httpStatus: 409,
      );

      // Mock GET request returns 404 (resource already deleted)
      when(mockAuth.getAccessToken()).thenAnswer((_) async => 'token123');
      when(mockClient.get(any, headers: anyNamed('headers')))
          .thenAnswer((_) async => http.Response(
                jsonEncode({'error': 'not_found'}),
                404,
                headers: {'content-type': 'application/json'},
              ));

      // Reconcile conflict
      final resolved = await reconciler.reconcileConflict(op, conflict);

      expect(resolved, true); // Idempotent delete treated as success

      verify(mockClient.get(any, headers: anyNamed('headers'))).called(1);
    });

    test('DELETE conflict - resource still exists', () async {
      final op = PendingOp(
        id: 'op-delete-conflict-exists',
        opType: 'DELETE',
        entityType: 'DEVICE',
        payload: {'id': 'device-111'},
        idempotencyKey: 'idem-delete-exists',
      );

      final conflict = ConflictException(
        message: 'Concurrent modification',
        conflictType: 'version_mismatch',
        httpStatus: 409,
      );

      // Mock GET request returns resource (still exists)
      when(mockAuth.getAccessToken()).thenAnswer((_) async => 'token123');
      when(mockClient.get(any, headers: anyNamed('headers')))
          .thenAnswer((_) async => http.Response(
                jsonEncode({
                  'id': 'device-111',
                  'name': 'Active Device',
                  'version': 7,
                }),
                200,
                headers: {'content-type': 'application/json'},
              ));

      // Reconcile conflict
      final resolved = await reconciler.reconcileConflict(op, conflict);

      expect(resolved, true); // Can retry delete

      verify(mockClient.get(any, headers: anyNamed('headers'))).called(1);
    });

    test('Reconciliation strategy for different conflict types', () {
      final versionMismatch = ConflictException(
        message: 'Version mismatch',
        conflictType: 'version_mismatch',
        serverVersion: 5,
        clientVersion: 3,
        httpStatus: 409,
      );

      final duplicate = ConflictException(
        message: 'Duplicate',
        conflictType: 'duplicate',
        httpStatus: 409,
      );

      final constraint = ConflictException(
        message: 'Constraint violation',
        conflictType: 'constraint_violation',
        httpStatus: 409,
      );

      expect(
        reconciler.getStrategyForConflict(versionMismatch),
        'merge_and_retry',
      );

      expect(
        reconciler.getStrategyForConflict(duplicate),
        'check_and_treat_as_success',
      );

      expect(
        reconciler.getStrategyForConflict(constraint),
        'fail_permanent',
      );
    });

    test('UPDATE conflict - resource deleted on server', () async {
      final op = PendingOp(
        id: 'op-update-deleted',
        opType: 'UPDATE',
        entityType: 'ROOM',
        payload: {
          'id': 'room-deleted',
          'name': 'Updated Room',
          'version': 2,
        },
        idempotencyKey: 'idem-update-deleted',
      );

      final conflict = ConflictException(
        message: 'Resource not found',
        conflictType: 'not_found',
        httpStatus: 409,
      );

      // Mock GET request returns 404
      when(mockAuth.getAccessToken()).thenAnswer((_) async => 'token123');
      when(mockClient.get(any, headers: anyNamed('headers')))
          .thenAnswer((_) async => http.Response(
                jsonEncode({'error': 'not_found'}),
                404,
                headers: {'content-type': 'application/json'},
              ));

      // Reconcile conflict
      final resolved = await reconciler.reconcileConflict(op, conflict);

      expect(resolved, false); // Cannot update deleted resource

      verify(mockClient.get(any, headers: anyNamed('headers'))).called(1);
    });
  });
}
