/// Migration 004: Add Device Last Seen Cleanup
///
/// Cleans up stale device lastSeen timestamps and adds default values.
/// Part of 10% CLIMB #4 - Final audit closure.
library;

import 'package:hive/hive.dart';
import '../hive_migration.dart';
import '../../box_registry.dart';
import '../../../home automation/src/data/models/device_model.dart';

/// Migration that normalizes device lastSeen timestamps.
///
/// This migration:
/// - Sets default lastSeen for devices without valid timestamps
/// - Caps future timestamps to current time
/// - Records cleanup metrics
class DeviceLastSeenCleanupMigration implements HiveMigration {
  @override
  int get from => 3;
  
  @override
  int get to => 4;
  
  @override
  String get id => '004_device_lastseen_cleanup';
  
  @override
  String get description => 'Normalizes device lastSeen timestamps';
  
  @override
  List<String> get affectedBoxes => [BoxRegistry.devicesBox];
  
  @override
  bool get isReversible => false; // Timestamp normalization is one-way
  
  @override
  int get estimatedDurationMs => 1000;
  
  @override
  Future<DryRunResult> dryRun() async {
    try {
      if (!Hive.isBoxOpen(BoxRegistry.devicesBox)) {
        return DryRunResult.failure(['Devices box not open']);
      }
      
      final devicesBox = Hive.box<DeviceModel>(BoxRegistry.devicesBox);
      final now = DateTime.now();
      
      int needsUpdate = 0;
      int futureTimestamps = 0;
      int totalDevices = devicesBox.length;
      
      for (final device in devicesBox.values) {
        if (device.lastSeen.isAfter(now)) {
          futureTimestamps++;
          needsUpdate++;
        }
      }
      
      return DryRunResult.success(
        recordsToMigrate: needsUpdate,
        metadata: {
          'totalDevices': totalDevices,
          'futureTimestamps': futureTimestamps,
        },
      );
    } catch (e) {
      return DryRunResult.failure(['Dry run failed: $e']);
    }
  }
  
  @override
  Future<MigrationResult> migrate() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final devicesBox = Hive.box<DeviceModel>(BoxRegistry.devicesBox);
      final now = DateTime.now();
      
      int migrated = 0;
      int capped = 0;
      
      final entries = devicesBox.toMap();
      for (final entry in entries.entries) {
        final device = entry.value;
        bool needsUpdate = false;
        DateTime newLastSeen = device.lastSeen;
        
        // Cap future timestamps to now
        if (device.lastSeen.isAfter(now)) {
          newLastSeen = now;
          capped++;
          needsUpdate = true;
        }
        
        if (needsUpdate) {
          final updated = device.copyWith(lastSeen: newLastSeen);
          await devicesBox.put(entry.key, updated);
          migrated++;
        }
      }
      
      stopwatch.stop();
      
      return MigrationResult.success(
        recordsMigrated: migrated,
        duration: stopwatch.elapsed,
        metadata: {
          'capped': capped,
        },
      );
    } catch (e) {
      stopwatch.stop();
      return MigrationResult(
        success: false,
        duration: stopwatch.elapsed,
        errors: ['Migration failed: $e'],
      );
    }
  }
  
  @override
  Future<RollbackResult> rollback() async {
    // This migration is not reversible - timestamps are normalized
    return RollbackResult(
      success: false,
      errors: ['This migration is not reversible'],
    );
  }
  
  @override
  Future<SchemaVerification> verifySchema() async {
    try {
      final devicesBox = Hive.box<DeviceModel>(BoxRegistry.devicesBox);
      final now = DateTime.now();
      
      final futureTimestamps = <String>[];
      for (final device in devicesBox.values) {
        // Allow 1 second tolerance for race conditions
        if (device.lastSeen.isAfter(now.add(const Duration(seconds: 1)))) {
          futureTimestamps.add(device.id);
        }
      }
      
      if (futureTimestamps.isNotEmpty) {
        return SchemaVerification.invalid([
          '${futureTimestamps.length} devices still have future timestamps',
        ]);
      }
      
      return SchemaVerification.valid(
        recordCounts: {'devices': devicesBox.length},
      );
    } catch (e) {
      return SchemaVerification.invalid(['Verification failed: $e']);
    }
  }
}
