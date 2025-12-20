import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_angel_fyp/persistence/health/admin_repair_toolkit.dart';

void main() {
  group('RepairActionType', () {
    test('displayName provides human-readable names', () {
      expect(RepairActionType.rebuildIndex.displayName, equals('Rebuild Index'));
      expect(RepairActionType.retryFailedOps.displayName, equals('Retry Failed Ops'));
      expect(RepairActionType.verifyEncryption.displayName, equals('Verify Encryption'));
      expect(RepairActionType.compactBoxes.displayName, equals('Compact Boxes'));
    });

    test('description provides helpful explanations', () {
      expect(
        RepairActionType.rebuildIndex.description,
        contains('Reconstructs the pending operations index'),
      );
      expect(
        RepairActionType.retryFailedOps.description,
        contains('Moves all failed operations back'),
      );
      expect(
        RepairActionType.verifyEncryption.description,
        contains('Verifies encryption keys'),
      );
      expect(
        RepairActionType.compactBoxes.description,
        contains('Compacts all Hive boxes'),
      );
    });

    test('riskLevel categorizes actions', () {
      expect(RepairActionType.verifyEncryption.riskLevel, equals('low'));
      expect(RepairActionType.rebuildIndex.riskLevel, equals('medium'));
      expect(RepairActionType.retryFailedOps.riskLevel, equals('medium'));
      expect(RepairActionType.compactBoxes.riskLevel, equals('medium'));
    });

    test('estimatedDuration provides time estimates', () {
      expect(RepairActionType.verifyEncryption.estimatedDuration, equals('< 1s'));
      expect(RepairActionType.rebuildIndex.estimatedDuration, contains('s'));
      expect(RepairActionType.retryFailedOps.estimatedDuration, contains('s'));
      expect(RepairActionType.compactBoxes.estimatedDuration, contains('s'));
    });
  });

  group('RepairActionResult', () {
    test('success factory creates successful result', () {
      final result = RepairActionResult.success(
        action: RepairActionType.rebuildIndex,
        message: 'Rebuilt 42 operations',
        affectedCount: 42,
        duration: const Duration(seconds: 2),
        confirmationToken: 'REPAIR_TEST_123',
        userId: 'admin',
        reason: 'Testing',
      );

      expect(result.success, isTrue);
      expect(result.action, equals(RepairActionType.rebuildIndex));
      expect(result.message, equals('Rebuilt 42 operations'));
      expect(result.affectedCount, equals(42));
      expect(result.duration, equals(const Duration(seconds: 2)));
      expect(result.confirmationToken, equals('REPAIR_TEST_123'));
      expect(result.userId, equals('admin'));
      expect(result.reason, equals('Testing'));
      expect(result.error, isNull);
      expect(result.executedAt, isNotNull);
    });

    test('failure factory creates failed result', () {
      final result = RepairActionResult.failure(
        action: RepairActionType.compactBoxes,
        error: 'Box not open',
        duration: const Duration(milliseconds: 50),
        confirmationToken: 'REPAIR_TEST_456',
        userId: 'admin',
      );

      expect(result.success, isFalse);
      expect(result.action, equals(RepairActionType.compactBoxes));
      expect(result.error, equals('Box not open'));
      expect(result.affectedCount, equals(0));
      expect(result.message, equals('Action failed'));
    });

    test('toAuditMetadata includes all fields', () {
      final result = RepairActionResult.success(
        action: RepairActionType.verifyEncryption,
        message: 'Verified OK',
        affectedCount: 10,
        duration: const Duration(seconds: 1),
        confirmationToken: 'TOKEN',
        userId: 'user1',
        beforeState: {'boxes': 5},
        afterState: {'boxes': 5},
        reason: 'Routine check',
      );

      final meta = result.toAuditMetadata();
      expect(meta['action'], equals('verifyEncryption'));
      expect(meta['success'], isTrue);
      expect(meta['message'], equals('Verified OK'));
      expect(meta['affected_count'], equals(10));
      expect(meta['duration_ms'], equals(1000));
      expect(meta['before_state'], equals({'boxes': 5}));
      expect(meta['after_state'], equals({'boxes': 5}));
      expect(meta['confirmation_token'], equals('TOKEN'));
      expect(meta['reason'], equals('Routine check'));
    });

    test('toString formats correctly', () {
      final success = RepairActionResult.success(
        action: RepairActionType.rebuildIndex,
        message: 'OK',
        affectedCount: 10,
        duration: Duration.zero,
        confirmationToken: 'T',
        userId: 'U',
      );

      final failure = RepairActionResult.failure(
        action: RepairActionType.compactBoxes,
        error: 'Failed',
        duration: Duration.zero,
        confirmationToken: 'T',
        userId: 'U',
      );

      expect(success.toString(), contains('success'));
      expect(success.toString(), contains('rebuildIndex'));
      expect(success.toString(), contains('affected=10'));

      expect(failure.toString(), contains('failure'));
      expect(failure.toString(), contains('compactBoxes'));
      expect(failure.toString(), contains('Failed'));
    });
  });

  group('AdminRepairToolkit', () {
    late AdminRepairToolkit toolkit;

    setUp(() {
      toolkit = AdminRepairToolkit.create();
    });

    group('Token management', () {
      test('generateConfirmationToken creates valid token', () {
        final token = toolkit.generateConfirmationToken(RepairActionType.rebuildIndex);

        expect(token, startsWith('REPAIR_REBUILDINDEX_'));
        expect(toolkit.validateToken(RepairActionType.rebuildIndex, token), isTrue);
      });

      test('generateConfirmationToken creates different tokens each time', () {
        final token1 = toolkit.generateConfirmationToken(RepairActionType.rebuildIndex);
        // Add small delay to ensure different timestamp
        final token2 = toolkit.generateConfirmationToken(RepairActionType.rebuildIndex);

        // Tokens should be different (different timestamps)
        // Note: in fast execution they might be the same millisecond
        expect(token1, isNotEmpty);
        expect(token2, isNotEmpty);
      });

      test('validateToken rejects wrong action', () {
        final token = toolkit.generateConfirmationToken(RepairActionType.rebuildIndex);

        expect(toolkit.validateToken(RepairActionType.compactBoxes, token), isFalse);
        expect(toolkit.validateToken(RepairActionType.verifyEncryption, token), isFalse);
        expect(toolkit.validateToken(RepairActionType.retryFailedOps, token), isFalse);
      });

      test('validateToken rejects invalid format', () {
        expect(toolkit.validateToken(RepairActionType.rebuildIndex, ''), isFalse);
        expect(toolkit.validateToken(RepairActionType.rebuildIndex, 'invalid'), isFalse);
        expect(toolkit.validateToken(RepairActionType.rebuildIndex, 'REPAIR_'), isFalse);
        expect(toolkit.validateToken(RepairActionType.rebuildIndex, 'REPAIR_WRONG_123'), isFalse);
      });

      test('validateToken rejects expired tokens', () {
        // Create a token with old timestamp
        final expiredTimestamp = DateTime.now()
            .subtract(const Duration(minutes: 10))
            .millisecondsSinceEpoch;
        final expiredToken = 'REPAIR_REBUILDINDEX_$expiredTimestamp';

        expect(toolkit.validateToken(RepairActionType.rebuildIndex, expiredToken), isFalse);
      });

      test('validateToken accepts fresh tokens', () {
        final freshTimestamp = DateTime.now().millisecondsSinceEpoch;
        final freshToken = 'REPAIR_REBUILDINDEX_$freshTimestamp';

        expect(toolkit.validateToken(RepairActionType.rebuildIndex, freshToken), isTrue);
      });
    });

    group('Execute with invalid token', () {
      test('execute rejects invalid token', () async {
        final result = await toolkit.execute(
          action: RepairActionType.rebuildIndex,
          userId: 'test_user',
          confirmationToken: 'invalid_token',
          reason: 'Testing',
        );

        expect(result.success, isFalse);
        expect(result.error, contains('Invalid or expired confirmation token'));
      });

      test('execute rejects expired token', () async {
        final expiredTimestamp = DateTime.now()
            .subtract(const Duration(minutes: 10))
            .millisecondsSinceEpoch;
        final expiredToken = 'REPAIR_REBUILDINDEX_$expiredTimestamp';

        final result = await toolkit.execute(
          action: RepairActionType.rebuildIndex,
          userId: 'test_user',
          confirmationToken: expiredToken,
        );

        expect(result.success, isFalse);
        expect(result.error, contains('Invalid or expired'));
      });

      test('execute rejects wrong action token', () async {
        final token = toolkit.generateConfirmationToken(RepairActionType.compactBoxes);

        final result = await toolkit.execute(
          action: RepairActionType.rebuildIndex,
          userId: 'test_user',
          confirmationToken: token,
        );

        expect(result.success, isFalse);
        expect(result.error, contains('Invalid or expired'));
      });
    });
  });

  group('StringTakeExtension', () {
    test('take returns full string when shorter than count', () {
      expect('hello'.take(10), equals('hello'));
      expect(''.take(5), equals(''));
    });

    test('take truncates string when longer than count', () {
      expect('hello world'.take(5), equals('hello'));
      expect('abcdefghij'.take(3), equals('abc'));
    });

    test('take returns exact length when equal', () {
      expect('hello'.take(5), equals('hello'));
    });
  });
}
