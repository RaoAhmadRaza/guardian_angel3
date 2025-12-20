/// Migration 003: Add Room Index Migration
///
/// Creates a search index for rooms to enable fast lookups.
/// Part of 10% CLIMB #4 - Final audit closure.
library;

import 'package:hive/hive.dart';
import '../hive_migration.dart';
import '../../box_registry.dart';
import '../../../home automation/src/data/models/room_model.dart';

/// Migration that creates a room index for fast lookups.
///
/// This migration:
/// - Creates an index mapping room names to room IDs
/// - Enables case-insensitive room search
/// - Is fully reversible
class AddRoomIndexMigration implements HiveMigration {
  static const String indexBoxName = 'room_name_index';
  
  @override
  int get from => 2;
  
  @override
  int get to => 3;
  
  @override
  String get id => '003_add_room_index';
  
  @override
  String get description => 'Creates room name index for fast lookups';
  
  @override
  List<String> get affectedBoxes => [BoxRegistry.roomsBox, indexBoxName];
  
  @override
  bool get isReversible => true;
  
  @override
  int get estimatedDurationMs => 2000;
  
  @override
  Future<DryRunResult> dryRun() async {
    try {
      // Verify rooms box exists and is accessible
      if (!Hive.isBoxOpen(BoxRegistry.roomsBox)) {
        return DryRunResult.failure(['Rooms box not open']);
      }
      
      final roomsBox = Hive.box<RoomModel>(BoxRegistry.roomsBox);
      final recordCount = roomsBox.length;
      
      return DryRunResult.success(
        recordsToMigrate: recordCount,
        metadata: {'roomCount': recordCount},
      );
    } catch (e) {
      return DryRunResult.failure(['Dry run failed: $e']);
    }
  }
  
  @override
  Future<MigrationResult> migrate() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Open or create the index box
      final indexBox = await Hive.openBox<String>(indexBoxName);
      
      // Get rooms
      final roomsBox = Hive.box<RoomModel>(BoxRegistry.roomsBox);
      
      int migrated = 0;
      for (final room in roomsBox.values) {
        // Create lowercase index entry: name -> id
        final indexKey = room.name.toLowerCase().trim();
        await indexBox.put(indexKey, room.id);
        migrated++;
      }
      
      stopwatch.stop();
      
      return MigrationResult.success(
        recordsMigrated: migrated,
        duration: stopwatch.elapsed,
        metadata: {'indexEntries': migrated},
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
    try {
      // Delete the index box entirely
      if (Hive.isBoxOpen(indexBoxName)) {
        final box = Hive.box<String>(indexBoxName);
        await box.deleteFromDisk();
      } else {
        await Hive.deleteBoxFromDisk(indexBoxName);
      }
      
      return RollbackResult.success();
    } catch (e) {
      return RollbackResult(
        success: false,
        errors: ['Rollback failed: $e'],
      );
    }
  }
  
  @override
  Future<SchemaVerification> verifySchema() async {
    try {
      // Verify index box exists
      if (!Hive.isBoxOpen(indexBoxName)) {
        await Hive.openBox<String>(indexBoxName);
      }
      
      final indexBox = Hive.box<String>(indexBoxName);
      final roomsBox = Hive.box<RoomModel>(BoxRegistry.roomsBox);
      
      // Verify all rooms have index entries
      final missingEntries = <String>[];
      for (final room in roomsBox.values) {
        final indexKey = room.name.toLowerCase().trim();
        if (!indexBox.containsKey(indexKey)) {
          missingEntries.add(room.id);
        }
      }
      
      if (missingEntries.isNotEmpty) {
        return SchemaVerification.invalid([
          'Missing index entries for ${missingEntries.length} rooms',
        ]);
      }
      
      return SchemaVerification.valid(
        recordCounts: {'rooms': roomsBox.length},
      );
    } catch (e) {
      return SchemaVerification.invalid(['Verification failed: $e']);
    }
  }
}
