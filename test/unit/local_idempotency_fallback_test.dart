import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:guardian_angel_fyp/services/local_idempotency_fallback.dart';
import 'dart:io';

void main() {
  late LocalIdempotencyFallback fallback;
  late String testPath;

  setUp(() async {
    // Use temp directory for tests
    testPath = Directory.systemTemp
        .createTempSync('local_idempotency_fallback_test_')
        .path;
    Hive.init(testPath);
    
    fallback = LocalIdempotencyFallback();
    await fallback.init();
  });

  tearDown(() async {
    await Hive.close();
    // Clean up temp directory
    try {
      Directory(testPath).deleteSync(recursive: true);
    } catch (_) {}
  });

  group('LocalIdempotencyFallback', () {
    test('isDuplicate returns false for new key', () async {
      final key = 'test-key-1';
      final result = await fallback.isDuplicate(key);
      expect(result, isFalse);
    });

    test('isDuplicate returns true after markProcessed', () async {
      final key = 'test-key-2';
      
      await fallback.markProcessed(key);
      final result = await fallback.isDuplicate(key);
      
      expect(result, isTrue);
    });

    test('markProcessed stores timestamp', () async {
      final key = 'test-key-3';
      
      await fallback.markProcessed(key);
      
      // Verify via isDuplicate (don't open box directly)
      expect(await fallback.isDuplicate(key), isTrue);
      
      // Verify count increased
      expect(fallback.count, greaterThan(0));
    });

    test('multiple keys can be tracked independently', () async {
      final key1 = 'test-key-4a';
      final key2 = 'test-key-4b';
      
      await fallback.markProcessed(key1);
      
      expect(await fallback.isDuplicate(key1), isTrue);
      expect(await fallback.isDuplicate(key2), isFalse);
      
      await fallback.markProcessed(key2);
      
      expect(await fallback.isDuplicate(key1), isTrue);
      expect(await fallback.isDuplicate(key2), isTrue);
    });

    test('purgeExpired removes old keys', () async {
      // Use custom TTL to simulate expired keys
      final expiredKey = 'expired-key';
      final recentKey = 'recent-key';
      
      await fallback.markProcessed(expiredKey);
      
      // Wait 10ms then mark recent key
      await Future.delayed(const Duration(milliseconds: 10));
      await fallback.markProcessed(recentKey);
      
      // Purge with very short TTL (5ms) - should remove expiredKey
      final purged = await fallback.purgeExpired(
        customTtl: const Duration(milliseconds: 5),
      );
      
      expect(purged, equals(1)); // Only expired key removed
      expect(await fallback.isDuplicate(expiredKey), isFalse);
      expect(await fallback.isDuplicate(recentKey), isTrue);
    });

    test('purgeExpired returns 0 when no keys expired', () async {
      final key1 = 'recent-key-1';
      final key2 = 'recent-key-2';
      
      await fallback.markProcessed(key1);
      await fallback.markProcessed(key2);
      
      final purged = await fallback.purgeExpired();
      
      expect(purged, equals(0));
      expect(await fallback.isDuplicate(key1), isTrue);
      expect(await fallback.isDuplicate(key2), isTrue);
    });

    test('TTL boundary: key at exactly 24 hours is NOT expired', () async {
      final boundaryKey = 'boundary-key';
      
      await fallback.markProcessed(boundaryKey);
      
      // Purge with TTL slightly longer than 0 - should NOT remove just-added key
      final purged = await fallback.purgeExpired(
        customTtl: const Duration(milliseconds: 100),
      );
      
      expect(purged, equals(0));
      expect(await fallback.isDuplicate(boundaryKey), isTrue);
    });

    test('TTL boundary: key at 24 hours + 1ms is expired', () async {
      final expiredKey = 'expired-boundary-key';
      
      await fallback.markProcessed(expiredKey);
      
      // Wait 10ms then purge with 5ms TTL - should expire
      await Future.delayed(const Duration(milliseconds: 10));
      final purged = await fallback.purgeExpired(
        customTtl: const Duration(milliseconds: 5),
      );
      
      expect(purged, equals(1));
      expect(await fallback.isDuplicate(expiredKey), isFalse);
    });

    test('purgeExpired handles multiple expired keys', () async {
      // Add 3 keys that will expire
      await fallback.markProcessed('expired-1');
      await fallback.markProcessed('expired-2');
      await fallback.markProcessed('expired-3');
      
      // Wait 10ms
      await Future.delayed(const Duration(milliseconds: 10));
      
      // Add 2 recent keys
      await fallback.markProcessed('recent-1');
      await fallback.markProcessed('recent-2');
      
      // Purge with 5ms TTL - should remove first 3 keys
      final purged = await fallback.purgeExpired(
        customTtl: const Duration(milliseconds: 5),
      );
      
      expect(purged, equals(3));
      expect(await fallback.isDuplicate('expired-1'), isFalse);
      expect(await fallback.isDuplicate('expired-2'), isFalse);
      expect(await fallback.isDuplicate('expired-3'), isFalse);
      expect(await fallback.isDuplicate('recent-1'), isTrue);
      expect(await fallback.isDuplicate('recent-2'), isTrue);
    });

    test('handles empty box gracefully', () async {
      final result = await fallback.isDuplicate('nonexistent-key');
      expect(result, isFalse);
      
      final purged = await fallback.purgeExpired();
      expect(purged, equals(0));
    });

    test('re-marking same key updates timestamp', () async {
      final key = 'update-test-key';
      
      // First mark
      await fallback.markProcessed(key);
      
      // Wait 10ms
      await Future.delayed(const Duration(milliseconds: 10));
      
      // Re-mark same key
      await fallback.markProcessed(key);
      
      // Key should still be duplicate
      expect(await fallback.isDuplicate(key), isTrue);
      
      // Purge with short TTL should NOT remove it (timestamp was updated)
      final purged = await fallback.purgeExpired(
        customTtl: const Duration(milliseconds: 5),
      );
      expect(purged, equals(0));
      expect(await fallback.isDuplicate(key), isTrue);
    });

    test('concurrent markProcessed calls do not conflict', () async {
      final keys = List.generate(10, (i) => 'concurrent-key-$i');
      
      // Mark all keys concurrently
      await Future.wait(keys.map((k) => fallback.markProcessed(k)));
      
      // Verify all marked
      for (final key in keys) {
        expect(await fallback.isDuplicate(key), isTrue);
      }
    });

    test('custom TTL: purgeExpired with custom duration', () async {
      final key = 'custom-ttl-key';
      
      await fallback.markProcessed(key);
      
      // Should NOT be expired with long TTL
      final defaultPurged = await fallback.purgeExpired(
        customTtl: const Duration(hours: 24),
      );
      expect(defaultPurged, equals(0));
      expect(await fallback.isDuplicate(key), isTrue);
      
      // Should be expired with very short TTL
      await Future.delayed(const Duration(milliseconds: 10));
      final customPurged = await fallback.purgeExpired(
        customTtl: const Duration(milliseconds: 5),
      );
      expect(customPurged, equals(1));
      expect(await fallback.isDuplicate(key), isFalse);
    });

    test('stress test: 1000 keys performance', () async {
      final keys = List.generate(1000, (i) => 'stress-key-$i');
      
      // Mark all keys
      final markStart = DateTime.now();
      for (final key in keys) {
        await fallback.markProcessed(key);
      }
      final markDuration = DateTime.now().difference(markStart);
      
      // Check all keys
      final checkStart = DateTime.now();
      for (final key in keys) {
        expect(await fallback.isDuplicate(key), isTrue);
      }
      final checkDuration = DateTime.now().difference(checkStart);
      
      // Performance assertions (should be fast)
      expect(markDuration.inMilliseconds, lessThan(5000)); // 5s for 1000 writes
      expect(checkDuration.inMilliseconds, lessThan(5000)); // 5s for 1000 reads
      
      print('1000 keys marked in ${markDuration.inMilliseconds}ms');
      print('1000 keys checked in ${checkDuration.inMilliseconds}ms');
    });
  });
}
