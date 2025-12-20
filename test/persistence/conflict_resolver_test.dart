/// Conflict Resolver Tests
///
/// Tests for the version-based conflict resolution service.
/// Part of 10% CLIMB #4 - Final audit closure.
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_angel_fyp/persistence/sync/conflict_resolver.dart';

void main() {
  group('ConflictResolver', () {
    late ConflictResolver resolver;
    
    setUp(() {
      resolver = ConflictResolver.forTest();
    });
    
    group('resolve', () {
      test('remote wins when remote version is higher', () {
        final result = resolver.resolve(
          localVersion: 1,
          remoteVersion: 2,
        );
        
        expect(result.resolution, equals(ConflictResolution.remoteWins));
        expect(result.localVersion, equals(1));
        expect(result.remoteVersion, equals(2));
      });
      
      test('local wins when local version equals remote version', () {
        final result = resolver.resolve(
          localVersion: 2,
          remoteVersion: 2,
        );
        
        expect(result.resolution, equals(ConflictResolution.localWins));
      });
      
      test('local wins when local version is higher', () {
        final result = resolver.resolve(
          localVersion: 3,
          remoteVersion: 1,
        );
        
        expect(result.resolution, equals(ConflictResolution.localWins));
        expect(result.reason, contains('Local version'));
      });
      
      test('provides reason for decision', () {
        final result = resolver.resolve(
          localVersion: 1,
          remoteVersion: 5,
        );
        
        expect(result.reason, isNotEmpty);
        expect(result.reason, contains('5'));
        expect(result.reason, contains('1'));
      });
      
      test('records resolution timestamp', () {
        final before = DateTime.now();
        final result = resolver.resolve(
          localVersion: 1,
          remoteVersion: 2,
        );
        final after = DateTime.now();
        
        expect(result.resolvedAt.isAfter(before) || result.resolvedAt.isAtSameMomentAs(before), isTrue);
        expect(result.resolvedAt.isBefore(after) || result.resolvedAt.isAtSameMomentAs(after), isTrue);
      });
    });
    
    group('applyResolution', () {
      test('returns remote data when remote wins', () {
        final result = ConflictResolutionResult(
          resolution: ConflictResolution.remoteWins,
          reason: 'test',
          localVersion: 1,
          remoteVersion: 2,
        );
        
        final localData = {'id': '1', 'name': 'Local'};
        final remoteData = {'id': '1', 'name': 'Remote'};
        
        final (data, shouldSync) = resolver.applyResolution(
          result: result,
          localData: localData,
          remoteData: remoteData,
        );
        
        expect(data['name'], equals('Remote'));
        expect(shouldSync, isFalse);
      });
      
      test('returns local data when local wins', () {
        final result = ConflictResolutionResult(
          resolution: ConflictResolution.localWins,
          reason: 'test',
          localVersion: 2,
          remoteVersion: 1,
        );
        
        final localData = {'id': '1', 'name': 'Local'};
        final remoteData = {'id': '1', 'name': 'Remote'};
        
        final (data, shouldSync) = resolver.applyResolution(
          result: result,
          localData: localData,
          remoteData: remoteData,
        );
        
        expect(data['name'], equals('Local'));
        expect(shouldSync, isTrue);
      });
    });
    
    group('singleton', () {
      test('ConflictResolver.I returns same instance', () {
        final instance1 = ConflictResolver.I;
        final instance2 = ConflictResolver.I;
        
        expect(identical(instance1, instance2), isTrue);
      });
    });
  });

  group('ConflictResolutionResult', () {
    test('toString includes all relevant info', () {
      final result = ConflictResolutionResult(
        resolution: ConflictResolution.remoteWins,
        reason: 'Version check',
        localVersion: 1,
        remoteVersion: 2,
      );
      
      final str = result.toString();
      
      expect(str, contains('remoteWins'));
      expect(str, contains('v1'));
      expect(str, contains('v2'));
    });
  });

  group('ConflictResolutionExtension', () {
    test('resolveWith extracts versions from maps', () {
      final local = {'id': '1', 'version': 1, 'name': 'Local'};
      final remote = {'id': '1', 'version': 3, 'name': 'Remote'};
      
      final result = local.resolveWith(remote);
      
      expect(result.resolution, equals(ConflictResolution.remoteWins));
      expect(result.localVersion, equals(1));
      expect(result.remoteVersion, equals(3));
    });
    
    test('handles missing version fields', () {
      final local = {'id': '1', 'name': 'Local'};
      final remote = {'id': '1', 'version': 1, 'name': 'Remote'};
      
      final result = local.resolveWith(remote);
      
      // Missing local version defaults to 0
      expect(result.localVersion, equals(0));
      expect(result.remoteVersion, equals(1));
      expect(result.resolution, equals(ConflictResolution.remoteWins));
    });
    
    test('handles numeric version types', () {
      final local = {'id': '1', 'version': 2.0, 'name': 'Local'};
      final remote = {'id': '1', 'version': 1, 'name': 'Remote'};
      
      final result = local.resolveWith(remote);
      
      expect(result.localVersion, equals(2));
      expect(result.resolution, equals(ConflictResolution.localWins));
    });
  });

  group('ConflictResolution enum', () {
    test('has all expected values', () {
      expect(ConflictResolution.values, contains(ConflictResolution.localWins));
      expect(ConflictResolution.values, contains(ConflictResolution.remoteWins));
      expect(ConflictResolution.values, contains(ConflictResolution.mergeRequired));
    });
  });
  
  group('Version-based conflict strategy', () {
    // These tests document the core conflict resolution strategy
    
    test('if remote.version > local.version: discard local', () {
      final local = {'version': 1};
      final remote = {'version': 2};
      
      final result = local.resolveWith(remote);
      
      // Discard local = remote wins
      expect(result.resolution, equals(ConflictResolution.remoteWins));
    });
    
    test('else: overwrite remote', () {
      final local = {'version': 2};
      final remote = {'version': 1};
      
      final result = local.resolveWith(remote);
      
      // Overwrite remote = local wins
      expect(result.resolution, equals(ConflictResolution.localWins));
    });
    
    test('equal versions: local wins (overwrite remote)', () {
      final local = {'version': 2};
      final remote = {'version': 2};
      
      final result = local.resolveWith(remote);
      
      expect(result.resolution, equals(ConflictResolution.localWins));
    });
  });
}
