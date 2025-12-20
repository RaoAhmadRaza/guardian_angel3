import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_angel_fyp/persistence/monitoring/storage_monitor.dart';

/// Unit tests for StorageMonitor
void main() {
  group('StorageMonitor', () {
    test('StoragePressure enum values', () {
      expect(StoragePressure.values.length, equals(3));
      expect(StoragePressure.normal.name, equals('normal'));
      expect(StoragePressure.warning.name, equals('warning'));
      expect(StoragePressure.critical.name, equals('critical'));
    });

    test('StorageCheckResult isHealthy', () {
      final healthyResult = StorageCheckResult(
        totalBytes: 1000,
        quotaBytes: 10000,
        usagePercent: 0.1,
        pressure: StoragePressure.normal,
        boxSizes: {},
        cleanupTriggered: false,
        checkedAt: DateTime.now(),
      );
      
      expect(healthyResult.isHealthy, isTrue);
      expect(healthyResult.needsAttention, isFalse);
    });

    test('StorageCheckResult needsAttention for warning', () {
      final warningResult = StorageCheckResult(
        totalBytes: 8500,
        quotaBytes: 10000,
        usagePercent: 0.85,
        pressure: StoragePressure.warning,
        boxSizes: {},
        cleanupTriggered: false,
        checkedAt: DateTime.now(),
      );
      
      expect(warningResult.isHealthy, isFalse);
      expect(warningResult.needsAttention, isTrue);
    });

    test('StorageCheckResult needsAttention for critical', () {
      final criticalResult = StorageCheckResult(
        totalBytes: 9800,
        quotaBytes: 10000,
        usagePercent: 0.98,
        pressure: StoragePressure.critical,
        boxSizes: {},
        cleanupTriggered: true,
        checkedAt: DateTime.now(),
      );
      
      expect(criticalResult.isHealthy, isFalse);
      expect(criticalResult.needsAttention, isTrue);
    });

    test('StorageCheckResult toJson', () {
      final result = StorageCheckResult(
        totalBytes: 5000,
        quotaBytes: 10000,
        usagePercent: 0.5,
        pressure: StoragePressure.normal,
        boxSizes: {'box1': 1000, 'box2': 4000},
        cleanupTriggered: false,
        checkedAt: DateTime.utc(2025, 1, 15, 10, 30),
      );
      
      final json = result.toJson();
      
      expect(json['total_bytes'], equals(5000));
      expect(json['quota_bytes'], equals(10000));
      expect(json['usage_percent'], equals(0.5));
      expect(json['pressure'], equals('normal'));
      expect(json['cleanup_triggered'], isFalse);
      expect((json['box_sizes'] as Map)['box1'], equals(1000));
    });

    test('StorageMonitor default quota', () {
      final monitor = StorageMonitor();
      expect(monitor.maxAllowedBytes, equals(kDefaultMaxStorageBytes));
    });

    test('StorageMonitor custom quota', () {
      final monitor = StorageMonitor(maxAllowedBytes: 50 * 1024 * 1024);
      expect(monitor.maxAllowedBytes, equals(50 * 1024 * 1024));
    });
  });
}
