/// Home Automation Hive Bridge
///
/// Opens Home Automation-specific Hive boxes using the SAME Hive instance
/// that was initialized by HiveService. This ensures:
/// - No duplicate Hive.initFlutter() calls
/// - Consistent encryption if needed
/// - Adapters from local_hive_service are registered here
///
/// This file is called by [initLocalBackend] after HiveService.init().
///
/// PHASE 1 BLOCKER FIX: Box names unified via BoxRegistry.
/// All box names come from LocalHiveService which uses BoxRegistry.
library;

import 'package:hive/hive.dart';
import 'hive_adapters/room_model_hive.dart';
import 'hive_adapters/device_model_hive.dart';
import 'package:guardian_angel_fyp/persistence/models/pending_op.dart';
import 'package:guardian_angel_fyp/models/failed_op_model.dart';
import 'package:guardian_angel_fyp/persistence/adapters/pending_op_adapter.dart';
import 'package:guardian_angel_fyp/persistence/box_registry.dart';
import 'local_hive_service.dart';
import '../../../services/telemetry_service.dart';

/// Bridge to open Home Automation boxes using the shared Hive instance.
class HomeAutomationHiveBridge {
  static bool _opened = false;

  /// Opens all Home Automation boxes.
  ///
  /// This method:
  /// - Registers Home Automation-specific adapters (if not already registered)
  /// - Opens home automation boxes (names from LocalHiveService → BoxRegistry)
  /// - Does NOT call Hive.initFlutter() (already done by HiveService)
  ///
  /// Box names used:
  /// - LocalHiveService.roomBoxName → BoxRegistry.homeAutomationRoomsBoxLegacy ('rooms_v1')
  /// - LocalHiveService.deviceBoxName → BoxRegistry.homeAutomationDevicesBoxLegacy ('devices_v1')
  /// - LocalHiveService.pendingOpsBoxName → BoxRegistry.pendingOpsBox
  /// - LocalHiveService.failedOpsBoxName → BoxRegistry.failedOpsBox
  ///
  /// Idempotent: safe to call multiple times.
  static Future<void> open() async {
    if (_opened) {
      TelemetryService.I.increment('home_automation.bridge.skipped_already_open');
      return;
    }

    final sw = Stopwatch()..start();
    try {
      // Register adapters if not already registered
      // TypeIds must not collide with core adapters (see box_registry.dart TypeIds)
      // Home Automation uses typeIds: RoomModelHive=0, DeviceModelHive=1, PendingOp=2
      _registerAdaptersIfNeeded();

      // Open boxes (unencrypted by default for Home Automation)
      // If encryption is needed, use LocalHiveService.openEncryptedBox instead
      await _openBoxesIfNeeded();

      _opened = true;
      sw.stop();
      TelemetryService.I.time('home_automation.bridge.open.duration_ms', () => sw.elapsed);
      TelemetryService.I.increment('home_automation.bridge.open.success');
      print('[HomeAutomationHiveBridge] Opened in ${sw.elapsedMilliseconds}ms');
    } catch (e) {
      sw.stop();
      TelemetryService.I.increment('home_automation.bridge.open.failed');
      print('[HomeAutomationHiveBridge] Failed to open: $e');
      rethrow;
    }
  }

  static void _registerAdaptersIfNeeded() {
    // RoomModelHive - typeId 0
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(RoomModelHiveAdapter());
    }
    // DeviceModelHive - typeId 1
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(DeviceModelHiveAdapter());
    }
    // PendingOp (CANONICAL) - typeId 11 (TypeIds.pendingOp)
    // Uses the canonical adapter from persistence layer
    if (!Hive.isAdapterRegistered(TypeIds.pendingOp)) {
      Hive.registerAdapter(PendingOpAdapter());
    }
  }

  static Future<void> _openBoxesIfNeeded() async {
    // Open each box only if not already open
    if (!Hive.isBoxOpen(LocalHiveService.roomBoxName)) {
      await Hive.openBox<RoomModelHive>(LocalHiveService.roomBoxName);
    }
    if (!Hive.isBoxOpen(LocalHiveService.deviceBoxName)) {
      await Hive.openBox<DeviceModelHive>(LocalHiveService.deviceBoxName);
    }
    if (!Hive.isBoxOpen(LocalHiveService.pendingOpsBoxName)) {
      await Hive.openBox<PendingOp>(LocalHiveService.pendingOpsBoxName);
    }
    if (!Hive.isBoxOpen(LocalHiveService.failedOpsBoxName)) {
      await Hive.openBox<PendingOp>(LocalHiveService.failedOpsBoxName);
    }
  }

  /// Resets the opened flag (for testing only).
  static void resetForTesting() {
    _opened = false;
  }

  /// Whether the bridge has been opened.
  static bool get isOpened => _opened;
}
