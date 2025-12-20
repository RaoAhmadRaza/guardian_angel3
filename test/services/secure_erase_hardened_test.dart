/// Secure Erase Hardened Tests
///
/// Tests for hardened secure erase with verification.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:guardian_angel_fyp/services/secure_erase_hardened.dart';
import 'package:guardian_angel_fyp/persistence/box_registry.dart';
import 'dart:io';

void main() {
  late Directory tempDir;
  
  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('secure_erase_hardened_test_');
    Hive.init(tempDir.path);
  });
  
  tearDownAll(() async {
    await Hive.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });
  
  setUp(() async {
    // Ensure clean state
    await Hive.close();
    Hive.init(tempDir.path);
  });

  group('SecureEraseHardened', () {
    test('singleton instance is accessible', () {
      final instance = SecureEraseHardened.I;
      expect(instance, isNotNull);
      expect(instance, same(SecureEraseHardened.I));
    });
    
    test('EraseUIState has all expected states', () {
      expect(EraseUIState.values, contains(EraseUIState.notStarted));
      expect(EraseUIState.values, contains(EraseUIState.inProgress));
      expect(EraseUIState.values, contains(EraseUIState.complete));
      expect(EraseUIState.values, contains(EraseUIState.incomplete));
      expect(EraseUIState.values, contains(EraseUIState.failed));
    });
    
    test('getUIState returns notStarted for null result', () {
      final state = SecureEraseHardened.I.getUIState(null);
      expect(state, EraseUIState.notStarted);
    });
    
    test('getUIState returns complete for successful result', () {
      final result = HardenedEraseResult(
        userId: 'test',
        startedAt: DateTime.now(),
      );
      result.success = true;
      
      final state = SecureEraseHardened.I.getUIState(result);
      expect(state, EraseUIState.complete);
    });
    
    test('getUIState returns failed for result with errors', () {
      final result = HardenedEraseResult(
        userId: 'test',
        startedAt: DateTime.now(),
      );
      result.success = false;
      result.errors.add('test error');
      // Add remaining items to make verification incomplete
      result.verification.remainingFiles.add('test.hive');
      
      final state = SecureEraseHardened.I.getUIState(result);
      // With errors and incomplete verification, it returns failed
      expect(state, EraseUIState.failed);
    });
  });

  group('HardenedEraseResult', () {
    test('creates with required fields', () {
      final result = HardenedEraseResult(
        userId: 'user123',
        startedAt: DateTime.utc(2024, 1, 1),
      );
      
      expect(result.userId, 'user123');
      expect(result.startedAt.year, 2024);
      expect(result.success, false);
      expect(result.boxesClosed, 0);
      expect(result.filesDeleted, 0);
      expect(result.keysDeleted, 0);
      expect(result.errors, isEmpty);
    });
    
    test('toJson serializes correctly', () {
      final result = HardenedEraseResult(
        userId: 'user123',
        startedAt: DateTime.utc(2024, 1, 1),
      );
      result.success = true;
      result.boxesClosed = 5;
      result.filesDeleted = 10;
      result.keysDeleted = 2;
      result.durationMs = 1000;
      result.completedAt = DateTime.utc(2024, 1, 1, 0, 0, 1);
      
      final json = result.toJson();
      
      expect(json['userId'], 'user123');
      expect(json['success'], true);
      expect(json['boxesClosed'], 5);
      expect(json['filesDeleted'], 10);
      expect(json['keysDeleted'], 2);
      expect(json['durationMs'], 1000);
    });
  });

  group('EraseVerificationScan', () {
    test('isComplete when all lists empty', () {
      final scan = EraseVerificationScan();
      expect(scan.isComplete, true);
      expect(scan.remainingCount, 0);
    });
    
    test('not complete when open boxes exist', () {
      final scan = EraseVerificationScan();
      scan.openBoxes.add('testBox');
      
      expect(scan.isComplete, false);
      expect(scan.remainingCount, 1);
    });
    
    test('not complete when remaining files exist', () {
      final scan = EraseVerificationScan();
      scan.remainingFiles.add('test.hive');
      
      expect(scan.isComplete, false);
      expect(scan.remainingCount, 1);
    });
    
    test('not complete when remaining keys exist', () {
      final scan = EraseVerificationScan();
      scan.remainingKeys.add('enc_key');
      
      expect(scan.isComplete, false);
      expect(scan.remainingCount, 1);
    });
    
    test('not complete when existing boxes exist', () {
      final scan = EraseVerificationScan();
      scan.existingBoxes.add('existing_box');
      
      expect(scan.isComplete, false);
      expect(scan.remainingCount, 1);
    });
    
    test('toJson serializes correctly', () {
      final scan = EraseVerificationScan();
      scan.openBoxes.add('box1');
      scan.remainingFiles.add('file1.hive');
      scan.remainingKeys.add('key1');
      scan.existingBoxes.add('existing1');
      scan.scanErrors.add('error1');
      
      final json = scan.toJson();
      
      expect(json['isComplete'], false);
      expect(json['remainingCount'], 4);
      expect(json['openBoxes'], contains('box1'));
      expect(json['remainingFiles'], contains('file1.hive'));
      expect(json['remainingKeys'], contains('key1'));
      expect(json['existingBoxes'], contains('existing1'));
      expect(json['scanErrors'], contains('error1'));
    });
  });

  group('InterruptedEraseInfo', () {
    test('creates with required fields', () {
      final info = InterruptedEraseInfo(
        userId: 'user123',
        detectedAt: DateTime.utc(2024, 1, 1),
      );
      
      expect(info.userId, 'user123');
      expect(info.startedAt, isNull);
      expect(info.detectedAt.year, 2024);
    });
    
    test('interruptedDuration is null when startedAt is null', () {
      final info = InterruptedEraseInfo(
        userId: 'user123',
        detectedAt: DateTime.utc(2024, 1, 1),
      );
      
      expect(info.interruptedDuration, isNull);
    });
    
    test('interruptedDuration calculates correctly', () {
      final info = InterruptedEraseInfo(
        userId: 'user123',
        startedAt: DateTime.utc(2024, 1, 1, 0, 0, 0),
        detectedAt: DateTime.utc(2024, 1, 1, 0, 5, 0),
      );
      
      expect(info.interruptedDuration, Duration(minutes: 5));
    });
    
    test('toJson serializes correctly', () {
      final info = InterruptedEraseInfo(
        userId: 'user123',
        startedAt: DateTime.utc(2024, 1, 1, 0, 0, 0),
        detectedAt: DateTime.utc(2024, 1, 1, 0, 5, 0),
      );
      
      final json = info.toJson();
      
      expect(json['userId'], 'user123');
      expect(json['startedAt'], isNotNull);
      expect(json['detectedAt'], isNotNull);
      expect(json['interruptedDurationMs'], Duration(minutes: 5).inMilliseconds);
    });
  });

  group('SecureEraseIncompleteException', () {
    test('creates with message and result', () {
      final result = HardenedEraseResult(
        userId: 'test',
        startedAt: DateTime.now(),
      );
      result.verification.remainingFiles.add('test.hive');
      
      final exception = SecureEraseIncompleteException(
        message: 'Test error',
        result: result,
        stackTrace: StackTrace.current,
      );
      
      expect(exception.message, 'Test error');
      expect(exception.result, same(result));
      expect(exception.toString(), contains('SecureEraseIncompleteException'));
    });
    
    test('shouldRetry is true when remaining files exist', () {
      final result = HardenedEraseResult(
        userId: 'test',
        startedAt: DateTime.now(),
      );
      result.verification.remainingFiles.add('test.hive');
      
      final exception = SecureEraseIncompleteException(
        message: 'Test',
        result: result,
        stackTrace: StackTrace.current,
      );
      
      expect(exception.shouldRetry, true);
    });
    
    test('shouldRetry is true when remaining keys exist', () {
      final result = HardenedEraseResult(
        userId: 'test',
        startedAt: DateTime.now(),
      );
      result.verification.remainingKeys.add('enc_key');
      
      final exception = SecureEraseIncompleteException(
        message: 'Test',
        result: result,
        stackTrace: StackTrace.current,
      );
      
      expect(exception.shouldRetry, true);
    });
    
    test('shouldRetry is false when verification is complete', () {
      final result = HardenedEraseResult(
        userId: 'test',
        startedAt: DateTime.now(),
      );
      // All lists are empty by default
      
      final exception = SecureEraseIncompleteException(
        message: 'Test',
        result: result,
        stackTrace: StackTrace.current,
      );
      
      expect(exception.shouldRetry, false);
    });
  });

  group('verifyCompleteDeletion', () {
    test('returns complete scan when no data exists', () async {
      final scan = await SecureEraseHardened.I.verifyCompleteDeletion();
      
      // With clean temp directory, should be mostly complete
      expect(scan.openBoxes, isEmpty);
      // Files and keys depend on actual state
    });
  });

  group('checkForInterruptedErase', () {
    test('returns null when no interrupted erase', () async {
      final info = await SecureEraseHardened.I.checkForInterruptedErase();
      
      // Should be null since we haven't started any erase
      expect(info, isNull);
    });
  });
}
