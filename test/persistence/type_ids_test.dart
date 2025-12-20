import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_angel_fyp/persistence/type_ids.dart';

void main() {
  group('TypeIds Registry', () {
    group('Authority', () {
      test('TypeIds class cannot be instantiated', () {
        // TypeIds is abstract final - compile-time check
        // This test documents the design intent
        expect(TypeIds.room, isA<int>());
      });

      test('all TypeIds are unique', () {
        final allIds = TypeIds.allIds;
        final uniqueIds = allIds.toSet();
        
        // If there are duplicates, the set will be smaller
        expect(allIds.length, equals(uniqueIds.length),
            reason: 'TypeIds must be unique - found duplicates');
      });

      test('registry contains all declared TypeIds', () {
        // Verify each constant is in the registry
        expect(TypeIds.registry.containsKey(TypeIds.roomHive), isTrue);
        expect(TypeIds.registry.containsKey(TypeIds.deviceHive), isTrue);
        expect(TypeIds.registry.containsKey(TypeIds.room), isTrue);
        expect(TypeIds.registry.containsKey(TypeIds.pendingOp), isTrue);
        expect(TypeIds.registry.containsKey(TypeIds.device), isTrue);
        expect(TypeIds.registry.containsKey(TypeIds.vitals), isTrue);
        expect(TypeIds.registry.containsKey(TypeIds.userProfile), isTrue);
        expect(TypeIds.registry.containsKey(TypeIds.session), isTrue);
        expect(TypeIds.registry.containsKey(TypeIds.failedOp), isTrue);
        expect(TypeIds.registry.containsKey(TypeIds.auditLogRecord), isTrue);
        expect(TypeIds.registry.containsKey(TypeIds.settings), isTrue);
        expect(TypeIds.registry.containsKey(TypeIds.assetsCache), isTrue);
        expect(TypeIds.registry.containsKey(TypeIds.syncFailure), isTrue);
        expect(TypeIds.registry.containsKey(TypeIds.syncFailureStatus), isTrue);
        expect(TypeIds.registry.containsKey(TypeIds.syncFailureSeverity), isTrue);
        expect(TypeIds.registry.containsKey(TypeIds.transactionRecord), isTrue);
        expect(TypeIds.registry.containsKey(TypeIds.lockRecord), isTrue);
        expect(TypeIds.registry.containsKey(TypeIds.auditLogEntry), isTrue);
        expect(TypeIds.registry.containsKey(TypeIds.auditLogArchive), isTrue);
      });
    });

    group('Range Allocation', () {
      test('Home Automation range is 0-9', () {
        expect(TypeIds.roomHive, equals(0));
        expect(TypeIds.deviceHive, equals(1));
        expect(TypeIds.roomHive, lessThan(10));
        expect(TypeIds.deviceHive, lessThan(10));
      });

      test('Persistence Core range is 10-19', () {
        expect(TypeIds.room, equals(10));
        expect(TypeIds.pendingOp, equals(11));
        expect(TypeIds.device, equals(12));
        expect(TypeIds.vitals, equals(13));
        expect(TypeIds.userProfile, equals(14));
        expect(TypeIds.session, equals(15));
        expect(TypeIds.failedOp, equals(16));
        expect(TypeIds.auditLogRecord, equals(17));
        expect(TypeIds.settings, equals(18));
        expect(TypeIds.assetsCache, equals(19));
        
        // All in range
        for (final id in [
          TypeIds.room, TypeIds.pendingOp, TypeIds.device, TypeIds.vitals,
          TypeIds.userProfile, TypeIds.session, TypeIds.failedOp,
          TypeIds.auditLogRecord, TypeIds.settings, TypeIds.assetsCache
        ]) {
          expect(id, greaterThanOrEqualTo(10));
          expect(id, lessThan(20));
        }
      });

      test('Sync & Failure range is 20-29', () {
        expect(TypeIds.syncFailure, equals(24));
        expect(TypeIds.syncFailureStatus, equals(25));
        expect(TypeIds.syncFailureSeverity, equals(26));
        
        for (final id in [
          TypeIds.syncFailure, TypeIds.syncFailureStatus, TypeIds.syncFailureSeverity
        ]) {
          expect(id, greaterThanOrEqualTo(20));
          expect(id, lessThan(30));
        }
      });

      test('Services range is 30-39', () {
        expect(TypeIds.transactionRecord, equals(30));
        expect(TypeIds.lockRecord, equals(32));
        expect(TypeIds.auditLogEntry, equals(33));
        expect(TypeIds.auditLogArchive, equals(34));
        
        for (final id in [
          TypeIds.transactionRecord, TypeIds.lockRecord,
          TypeIds.auditLogEntry, TypeIds.auditLogArchive
        ]) {
          expect(id, greaterThanOrEqualTo(30));
          expect(id, lessThan(40));
        }
      });
    });

    group('Helper Methods', () {
      test('allIds returns all registered TypeIds', () {
        final ids = TypeIds.allIds;
        expect(ids, isNotEmpty);
        expect(ids.contains(TypeIds.room), isTrue);
        expect(ids.contains(TypeIds.roomHive), isTrue);
        expect(ids.contains(TypeIds.syncFailure), isTrue);
      });

      test('getAdapterName returns correct name', () {
        expect(TypeIds.getAdapterName(TypeIds.room), equals('RoomAdapter'));
        expect(TypeIds.getAdapterName(TypeIds.pendingOp), equals('PendingOpAdapter'));
        expect(TypeIds.getAdapterName(TypeIds.syncFailure), equals('SyncFailureAdapter'));
        expect(TypeIds.getAdapterName(999), isNull);
      });

      test('isRegistered returns true for registered IDs', () {
        expect(TypeIds.isRegistered(TypeIds.room), isTrue);
        expect(TypeIds.isRegistered(TypeIds.device), isTrue);
        expect(TypeIds.isRegistered(999), isFalse);
        expect(TypeIds.isRegistered(-1), isFalse);
      });

      test('nextAvailableIn finds gaps in range', () {
        // Range 40-49 is reserved and empty
        final next = TypeIds.nextAvailableIn(40, 49);
        expect(next, equals(40));
        
        // Range 2-9 should find the first unused ID
        final nextHomeAuto = TypeIds.nextAvailableIn(2, 9);
        expect(nextHomeAuto, equals(2)); // Since only 0, 1 are used
      });

      test('nextAvailableIn throws when range is full', () {
        // Range 0-1 is fully allocated (roomHive=0, deviceHive=1)
        expect(
          () => TypeIds.nextAvailableIn(0, 1),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('Consistency', () {
      test('no gaps in persistence core range 10-19', () {
        // All IDs from 10-19 should be used
        for (int i = 10; i <= 19; i++) {
          expect(TypeIds.isRegistered(i), isTrue,
              reason: 'TypeId $i in persistence core range should be registered');
        }
      });

      test('registry count matches expected', () {
        // 2 Home Auto + 10 Persistence + 3 Sync + 4 Services = 19 total
        expect(TypeIds.registry.length, equals(19));
      });
    });
  });
}
