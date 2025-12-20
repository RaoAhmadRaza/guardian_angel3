import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:guardian_angel_fyp/persistence/errors/errors.dart';

void main() {
  group('HiveErrorHandler', () {
    group('categorize', () {
      test('categorizes HiveError with corruption message', () {
        final error = HiveError('Box is corrupt: invalid checksum');
        final result = HiveErrorHandler.categorize(
          error,
          StackTrace.current,
          boxName: 'test_box',
        );

        expect(result, isA<BoxCorruptionError>());
        expect(result.boxName, 'test_box');
        expect(result.isRecoverable, true);
        expect(result.suggestedAction, RecoveryAction.deleteAndRecreate);
      });

      test('categorizes HiveError with lock message', () {
        final error = HiveError('Box is already opened');
        final result = HiveErrorHandler.categorize(
          error,
          StackTrace.current,
          boxName: 'test_box',
        );

        expect(result, isA<BoxLockError>());
        expect(result.suggestedAction, RecoveryAction.retryWithDelay);
      });

      test('categorizes HiveError with encryption message', () {
        final error = HiveError('Failed to decrypt data');
        final result = HiveErrorHandler.categorize(
          error,
          StackTrace.current,
          boxName: 'test_box',
        );

        expect(result, isA<BoxEncryptionError>());
        expect(result.suggestedAction, RecoveryAction.refetchEncryptionKey);
      });

      test('categorizes FileSystemException with no space', () {
        final error = FileSystemException(
          'No space left on device',
          '/path/to/box.hive',
          const OSError('No space left on device', 28),
        );
        final result = HiveErrorHandler.categorize(
          error,
          StackTrace.current,
          boxName: 'test_box',
        );

        expect(result, isA<StorageQuotaError>());
        expect(result.isRecoverable, false);
        expect(result.suggestedAction, RecoveryAction.userActionRequired);
      });

      test('categorizes StateError with box not open', () {
        final error = StateError('Box not found: test_box');
        final result = HiveErrorHandler.categorize(
          error,
          StackTrace.current,
          boxName: 'test_box',
        );

        expect(result, isA<BoxNotOpenError>());
        expect(result.suggestedAction, RecoveryAction.reopenBox);
      });

      test('categorizes TypeError as type mismatch', () {
        final error = TypeError();
        final result = HiveErrorHandler.categorize(
          error,
          StackTrace.current,
          boxName: 'test_box',
        );

        expect(result, isA<BoxTypeMismatchError>());
        expect(result.suggestedAction, RecoveryAction.migrationRequired);
      });

      test('categorizes unknown error as BoxUnknownError', () {
        final error = Exception('Something unexpected');
        final result = HiveErrorHandler.categorize(
          error,
          StackTrace.current,
          boxName: 'test_box',
        );

        expect(result, isA<BoxUnknownError>());
        expect(result.isRecoverable, true);
        expect(result.suggestedAction, RecoveryAction.retry);
      });
    });

    group('user messages', () {
      test('BoxCorruptionError has user-friendly message', () {
        final error = BoxCorruptionError(
          message: 'Internal error',
          boxName: 'test_box',
        );
        expect(error.userMessage, contains('corrupted'));
      });

      test('StorageQuotaError has user-friendly message', () {
        final error = StorageQuotaError(
          message: 'ENOSPC',
          boxName: 'test_box',
        );
        expect(error.userMessage, contains('full'));
      });

      test('BoxEncryptionError has user-friendly message', () {
        final error = BoxEncryptionError(
          message: 'Decryption failed',
          boxName: 'test_box',
        );
        expect(error.userMessage, contains('secure'));
      });
    });
  });

  group('BoxOpResult', () {
    test('BoxOpSuccess.isSuccess returns true', () {
      final result = BoxOpSuccess<int>(42);
      expect(result.isSuccess, true);
      expect(result.isFailure, false);
      expect(result.valueOrThrow, 42);
      expect(result.valueOrNull, 42);
    });

    test('BoxOpVoid.isSuccess returns true', () {
      const result = BoxOpVoid<void>();
      expect(result.isSuccess, true);
      expect(result.isFailure, false);
    });

    test('BoxOpFailure.isFailure returns true', () {
      final error = BoxCorruptionError(
        message: 'test',
        boxName: 'test_box',
      );
      final result = BoxOpFailure<int>(error);
      expect(result.isFailure, true);
      expect(result.isSuccess, false);
      expect(result.error, error);
      expect(result.valueOrNull, null);
      expect(() => result.valueOrThrow, throwsA(isA<PersistenceError>()));
    });

    test('onSuccess callback is called on success', () {
      var called = false;
      final result = BoxOpSuccess<int>(42);
      result.onSuccess((value) {
        called = true;
        expect(value, 42);
      });
      expect(called, true);
    });

    test('onFailure callback is called on failure', () {
      var called = false;
      final error = BoxCorruptionError(
        message: 'test',
        boxName: 'test_box',
      );
      final result = BoxOpFailure<int>(error);
      result.onFailure((e) {
        called = true;
        expect(e, error);
      });
      expect(called, true);
    });

    test('onSuccess is not called on failure', () {
      var called = false;
      final error = BoxCorruptionError(
        message: 'test',
        boxName: 'test_box',
      );
      final result = BoxOpFailure<int>(error);
      result.onSuccess((_) {
        called = true;
      });
      expect(called, false);
    });

    test('onFailure is not called on success', () {
      var called = false;
      final result = BoxOpSuccess<int>(42);
      result.onFailure((_) {
        called = true;
      });
      expect(called, false);
    });
  });

  group('RecoveryAction', () {
    test('all recovery actions have meaningful names', () {
      for (final action in RecoveryAction.values) {
        expect(action.name, isNotEmpty);
      }
    });

    test('RecoveryAction enum has expected values', () {
      expect(RecoveryAction.values, containsAll([
        RecoveryAction.retry,
        RecoveryAction.retryWithDelay,
        RecoveryAction.reopenBox,
        RecoveryAction.deleteAndRecreate,
        RecoveryAction.refetchEncryptionKey,
        RecoveryAction.migrationRequired,
        RecoveryAction.userActionRequired,
        RecoveryAction.none,
      ]));
    });
  });

  group('PersistenceError sealed class', () {
    test('switch statement covers all error types', () {
      final errors = <PersistenceError>[
        BoxCorruptionError(message: 'test', boxName: 'test'),
        BoxLockError(message: 'test', boxName: 'test'),
        StorageQuotaError(message: 'test', boxName: 'test'),
        BoxNotOpenError(message: 'test', boxName: 'test'),
        BoxTypeMismatchError(message: 'test', boxName: 'test'),
        BoxEncryptionError(message: 'test', boxName: 'test'),
        BoxUnknownError(message: 'test', boxName: 'test'),
      ];

      for (final error in errors) {
        // This switch must be exhaustive due to sealed class
        final category = switch (error) {
          BoxCorruptionError() => 'corruption',
          BoxLockError() => 'lock',
          StorageQuotaError() => 'quota',
          BoxNotOpenError() => 'not_open',
          BoxTypeMismatchError() => 'type_mismatch',
          BoxEncryptionError() => 'encryption',
          BoxUnknownError() => 'unknown',
        };
        expect(category, isNotEmpty);
      }
    });
  });
}
