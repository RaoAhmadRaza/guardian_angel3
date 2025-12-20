import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_angel_fyp/persistence/cache/cache_invalidator.dart';

/// Unit tests for CacheInvalidator
void main() {
  late CacheInvalidator cache;

  setUp(() {
    cache = CacheInvalidator();
  });

  tearDown(() {
    cache.dispose();
  });

  group('CacheInvalidator', () {
    test('put and get basic value', () {
      cache.put('rooms', 'room1', {'name': 'Living Room'});
      
      final value = cache.get<Map<String, dynamic>>('rooms', 'room1');
      expect(value, isNotNull);
      expect(value!['name'], equals('Living Room'));
    });

    test('get returns null for missing key', () {
      final value = cache.get<String>('rooms', 'missing');
      expect(value, isNull);
    });

    test('has returns true for cached key', () {
      cache.put('rooms', 'room1', 'test');
      expect(cache.has('rooms', 'room1'), isTrue);
      expect(cache.has('rooms', 'missing'), isFalse);
    });

    test('invalidateOnWrite removes cached entry', () {
      cache.put('vitals', 'vital1', 100);
      expect(cache.has('vitals', 'vital1'), isTrue);
      
      cache.invalidateOnWrite('vitals', 'vital1');
      expect(cache.has('vitals', 'vital1'), isFalse);
    });

    test('invalidateOnSync removes multiple entries', () {
      cache.put('rooms', 'room1', 'r1');
      cache.put('rooms', 'room2', 'r2');
      cache.put('rooms', 'room3', 'r3');
      
      cache.invalidateOnSync('rooms', ['room1', 'room2']);
      
      expect(cache.has('rooms', 'room1'), isFalse);
      expect(cache.has('rooms', 'room2'), isFalse);
      expect(cache.has('rooms', 'room3'), isTrue);
    });

    test('invalidateOnDelete removes entry', () {
      cache.put('devices', 'device1', 'test');
      cache.invalidateOnDelete('devices', 'device1');
      expect(cache.has('devices', 'device1'), isFalse);
    });

    test('invalidateType clears all entries of type', () {
      cache.put('rooms', 'room1', 'r1');
      cache.put('rooms', 'room2', 'r2');
      cache.put('vitals', 'vital1', 'v1');
      
      cache.invalidateType('rooms');
      
      expect(cache.has('rooms', 'room1'), isFalse);
      expect(cache.has('rooms', 'room2'), isFalse);
      expect(cache.has('vitals', 'vital1'), isTrue);
    });

    test('invalidateAll clears entire cache', () {
      cache.put('rooms', 'room1', 'r1');
      cache.put('vitals', 'vital1', 'v1');
      cache.put('devices', 'device1', 'd1');
      
      cache.invalidateAll();
      
      expect(cache.has('rooms', 'room1'), isFalse);
      expect(cache.has('vitals', 'vital1'), isFalse);
      expect(cache.has('devices', 'device1'), isFalse);
    });

    test('invalidateOnRefresh clears type', () {
      cache.put('rooms', 'room1', 'r1');
      cache.put('rooms', 'room2', 'r2');
      
      cache.invalidateOnRefresh('rooms');
      
      expect(cache.has('rooms', 'room1'), isFalse);
      expect(cache.has('rooms', 'room2'), isFalse);
    });

    test('getStats returns correct counts', () {
      cache.put('rooms', 'room1', 'r1');
      cache.put('rooms', 'room2', 'r2');
      cache.put('vitals', 'vital1', 'v1');
      
      final stats = cache.getStats();
      
      expect(stats['total_entries'], equals(3));
      expect(stats['entity_types'], equals(2));
      expect((stats['entries_by_type'] as Map)['rooms'], equals(2));
      expect((stats['entries_by_type'] as Map)['vitals'], equals(1));
    });

    test('events stream emits invalidation events', () async {
      final events = <CacheInvalidationEvent>[];
      final subscription = cache.events.listen(events.add);
      
      cache.put('rooms', 'room1', 'test');
      cache.invalidateOnWrite('rooms', 'room1');
      
      await Future.delayed(Duration(milliseconds: 10));
      
      expect(events.length, equals(1));
      expect(events[0].entityType, equals('rooms'));
      expect(events[0].entityId, equals('room1'));
      expect(events[0].reason, equals(CacheInvalidationReason.write));
      
      await subscription.cancel();
    });
  });
}
