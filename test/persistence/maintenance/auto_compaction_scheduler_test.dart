import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_angel_fyp/persistence/maintenance/auto_compaction_scheduler.dart';
import 'package:guardian_angel_fyp/services/ttl_compaction_service.dart';

/// Mock battery provider for testing.
class MockBatteryProvider implements BatteryStatusProvider {
  int batteryLevel = 100;
  bool charging = false;

  @override
  Future<int?> getBatteryLevel() async => batteryLevel;

  @override
  Future<bool> isCharging() async => charging;
}

/// Mock compaction service for testing.
class MockCompactionService extends TtlCompactionService {
  int runCount = 0;
  bool shouldFail = false;

  @override
  Future<Map<String, dynamic>> runMaintenance() async {
    if (shouldFail) {
      throw Exception('Mock compaction failure');
    }
    runCount++;
    return {'purged': runCount, 'compacted': true};
  }
}

void main() {
  group('AutoCompactionScheduler', () {
    late MockBatteryProvider mockBattery;
    late MockCompactionService mockCompaction;
    late AutoCompactionScheduler scheduler;

    setUp(() {
      mockBattery = MockBatteryProvider();
      mockCompaction = MockCompactionService();
    });

    tearDown(() {
      scheduler.stop();
    });

    group('Lifecycle', () {
      test('starts and reports isRunning = true', () async {
        scheduler = AutoCompactionScheduler(
          batteryProvider: mockBattery,
          compactionService: mockCompaction,
          interval: const Duration(hours: 1),
        );

        expect(scheduler.isRunning, isFalse);
        await scheduler.start();
        expect(scheduler.isRunning, isTrue);
      });

      test('stops and reports isRunning = false', () async {
        scheduler = AutoCompactionScheduler(
          batteryProvider: mockBattery,
          compactionService: mockCompaction,
          interval: const Duration(hours: 1),
        );

        await scheduler.start();
        expect(scheduler.isRunning, isTrue);
        
        scheduler.stop();
        expect(scheduler.isRunning, isFalse);
      });

      test('double start is idempotent', () async {
        scheduler = AutoCompactionScheduler(
          batteryProvider: mockBattery,
          compactionService: mockCompaction,
          interval: const Duration(hours: 1),
        );

        await scheduler.start();
        await scheduler.start(); // Should not throw
        expect(scheduler.isRunning, isTrue);
      });

      test('double stop is safe', () async {
        scheduler = AutoCompactionScheduler(
          batteryProvider: mockBattery,
          compactionService: mockCompaction,
          interval: const Duration(hours: 1),
        );

        await scheduler.start();
        scheduler.stop();
        scheduler.stop(); // Should not throw
        expect(scheduler.isRunning, isFalse);
      });
    });

    group('Immediate Run', () {
      test('runImmediately=true runs compaction on start', () async {
        scheduler = AutoCompactionScheduler(
          batteryProvider: mockBattery,
          compactionService: mockCompaction,
          interval: const Duration(hours: 24),
        );

        await scheduler.start(runImmediately: true);
        
        expect(mockCompaction.runCount, equals(1));
        expect(scheduler.successfulRuns, equals(1));
        expect(scheduler.lastCompactionTime, isNotNull);
      });

      test('runImmediately=false does not run compaction on start', () async {
        scheduler = AutoCompactionScheduler(
          batteryProvider: mockBattery,
          compactionService: mockCompaction,
          interval: const Duration(hours: 24),
        );

        await scheduler.start(runImmediately: false);
        
        expect(mockCompaction.runCount, equals(0));
        expect(scheduler.successfulRuns, equals(0));
      });
    });

    group('Battery Awareness', () {
      test('skips compaction when battery < 20% and not charging', () async {
        mockBattery.batteryLevel = 15;
        mockBattery.charging = false;

        scheduler = AutoCompactionScheduler(
          batteryProvider: mockBattery,
          compactionService: mockCompaction,
          interval: const Duration(hours: 24),
        );

        await scheduler.start();
        final result = await scheduler.triggerManually();
        
        expect(result, equals(CompactionResult.skippedLowBattery));
        expect(mockCompaction.runCount, equals(0));
        expect(scheduler.skippedRuns, equals(1));
      });

      test('runs compaction when battery >= 20%', () async {
        mockBattery.batteryLevel = 20;
        mockBattery.charging = false;

        scheduler = AutoCompactionScheduler(
          batteryProvider: mockBattery,
          compactionService: mockCompaction,
          interval: const Duration(hours: 24),
        );

        await scheduler.start();
        final result = await scheduler.triggerManually();
        
        expect(result, equals(CompactionResult.success));
        expect(mockCompaction.runCount, equals(1));
      });

      test('runs compaction when charging regardless of battery level', () async {
        mockBattery.batteryLevel = 5; // Very low
        mockBattery.charging = true;

        scheduler = AutoCompactionScheduler(
          batteryProvider: mockBattery,
          compactionService: mockCompaction,
          interval: const Duration(hours: 24),
        );

        await scheduler.start();
        final result = await scheduler.triggerManually();
        
        expect(result, equals(CompactionResult.success));
        expect(mockCompaction.runCount, equals(1));
      });

      test('forceBatteryOverride bypasses battery check', () async {
        mockBattery.batteryLevel = 5;
        mockBattery.charging = false;

        scheduler = AutoCompactionScheduler(
          batteryProvider: mockBattery,
          compactionService: mockCompaction,
          interval: const Duration(hours: 24),
        );

        await scheduler.start();
        final result = await scheduler.triggerManually(forceBatteryOverride: true);
        
        expect(result, equals(CompactionResult.success));
        expect(mockCompaction.runCount, equals(1));
      });
    });

    group('Error Handling', () {
      test('handles compaction failure gracefully', () async {
        mockCompaction.shouldFail = true;

        scheduler = AutoCompactionScheduler(
          batteryProvider: mockBattery,
          compactionService: mockCompaction,
          interval: const Duration(hours: 24),
        );

        await scheduler.start();
        final result = await scheduler.triggerManually();
        
        expect(result, equals(CompactionResult.failed));
        expect(scheduler.failedRuns, equals(1));
        expect(scheduler.isRunning, isTrue); // Should not stop
      });

      test('triggerManually returns notRunning when stopped', () async {
        scheduler = AutoCompactionScheduler(
          batteryProvider: mockBattery,
          compactionService: mockCompaction,
          interval: const Duration(hours: 24),
        );

        // Don't start
        final result = await scheduler.triggerManually();
        
        expect(result, equals(CompactionResult.notRunning));
      });
    });

    group('Statistics', () {
      test('tracks run statistics correctly', () async {
        scheduler = AutoCompactionScheduler(
          batteryProvider: mockBattery,
          compactionService: mockCompaction,
          interval: const Duration(hours: 24),
        );

        await scheduler.start();
        
        // Run 3 successful compactions
        await scheduler.triggerManually();
        await scheduler.triggerManually();
        await scheduler.triggerManually();

        expect(scheduler.totalRuns, equals(3));
        expect(scheduler.successfulRuns, equals(3));
        expect(scheduler.skippedRuns, equals(0));
        expect(scheduler.failedRuns, equals(0));
      });

      test('getStatistics returns complete data', () async {
        scheduler = AutoCompactionScheduler(
          batteryProvider: mockBattery,
          compactionService: mockCompaction,
          interval: const Duration(hours: 24),
        );

        await scheduler.start(runImmediately: true);
        
        final stats = scheduler.getStatistics();
        
        expect(stats['is_running'], isTrue);
        expect(stats['interval_hours'], equals(24));
        expect(stats['total_runs'], equals(1));
        expect(stats['successful_runs'], equals(1));
        expect(stats['last_compaction_time'], isNotNull);
        expect(stats['success_rate'], equals('100.0'));
      });
    });

    group('Timer Behavior', () {
      test('timer fires at specified interval', () async {
        scheduler = AutoCompactionScheduler(
          batteryProvider: mockBattery,
          compactionService: mockCompaction,
          interval: const Duration(milliseconds: 50), // Short for testing
        );

        await scheduler.start();
        
        // Wait for 3 intervals
        await Future.delayed(const Duration(milliseconds: 180));
        
        // Should have run at least 2-3 times
        expect(mockCompaction.runCount, greaterThanOrEqualTo(2));
      });
    });

    group('Global Scheduler', () {
      test('globalAutoCompactionScheduler creates singleton', () {
        final scheduler1 = globalAutoCompactionScheduler;
        final scheduler2 = globalAutoCompactionScheduler;
        
        expect(identical(scheduler1, scheduler2), isTrue);
        
        disposeGlobalAutoCompactionScheduler();
      });

      test('setGlobalAutoCompactionScheduler replaces instance', () {
        final custom = AutoCompactionScheduler(
          batteryProvider: mockBattery,
          compactionService: mockCompaction,
          interval: const Duration(hours: 12),
        );
        
        setGlobalAutoCompactionScheduler(custom);
        
        expect(identical(globalAutoCompactionScheduler, custom), isTrue);
        
        disposeGlobalAutoCompactionScheduler();
      });

      test('disposeGlobalAutoCompactionScheduler stops and clears', () async {
        final scheduler = globalAutoCompactionScheduler;
        await scheduler.start();
        expect(scheduler.isRunning, isTrue);
        
        disposeGlobalAutoCompactionScheduler();
        expect(scheduler.isRunning, isFalse);
      });
    });
  });

  group('Constants', () {
    test('battery threshold is 20%', () {
      expect(kBatteryLowThreshold, equals(20));
    });

    test('compaction interval is 24 hours', () {
      expect(kCompactionInterval, equals(const Duration(hours: 24)));
    });
  });

  group('DefaultBatteryProvider', () {
    test('returns 100% battery and charging=true', () async {
      const provider = DefaultBatteryProvider();
      
      expect(await provider.getBatteryLevel(), equals(100));
      expect(await provider.isCharging(), isTrue);
    });
  });
}
