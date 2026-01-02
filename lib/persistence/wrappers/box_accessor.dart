/// BoxAccessor - Safe Hive Box Access Pattern
///
/// REPLACES all raw Hive.box<T>() calls with type-safe accessors.
/// Part of 10% CLIMB #2: Operational safety & consistency.
///
/// ❌ FORBIDDEN:
/// ```dart
/// final box = Hive.box<PendingOp>(BoxRegistry.pendingOpsBox);
/// ```
///
/// ✅ REQUIRED:
/// ```dart
/// final box = BoxAccessor.pendingOps();
/// // OR via provider:
/// final box = ref.read(boxAccessorProvider).pendingOps();
/// ```
///
/// Benefits:
/// - Consistent null-safety checks
/// - Centralized box access
/// - Telemetry on access patterns
/// - Easy to mock in tests
library;

import 'package:hive/hive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../box_registry.dart';
import '../../models/pending_op.dart';
import '../../models/failed_op_model.dart';
import '../../models/room_model.dart';
import '../../models/vitals_model.dart';
import '../../models/settings_model.dart';
import '../../models/device_model.dart';
import '../../models/audit_log_record.dart';
import '../../relationships/models/relationship_model.dart';
import '../../relationships/models/doctor_relationship_model.dart';
import '../../chat/models/chat_thread_model.dart';
import '../../chat/models/chat_message_model.dart';
import '../../health/models/stored_health_reading.dart';
import '../../services/telemetry_service.dart';

/// Riverpod provider for BoxAccessor
final boxAccessorProvider = Provider<BoxAccessor>((ref) {
  return BoxAccessor();
});

/// Safe, type-checked Hive box accessor.
///
/// All box access should go through this class to ensure:
/// - Box is open before access
/// - Type safety is enforced
/// - Access patterns are tracked via telemetry
class BoxAccessor {
  final TelemetryService? _telemetry;

  BoxAccessor({TelemetryService? telemetry}) : _telemetry = telemetry;

  // ═══════════════════════════════════════════════════════════════════════
  // TYPED BOX ACCESSORS
  // ═══════════════════════════════════════════════════════════════════════

  /// Access pending operations box.
  Box<PendingOp> pendingOps() {
    _trackAccess(BoxRegistry.pendingOpsBox);
    _assertOpen(BoxRegistry.pendingOpsBox);
    return Hive.box<PendingOp>(BoxRegistry.pendingOpsBox);
  }

  /// Access pending index box.
  Box pendingIndex() {
    _trackAccess(BoxRegistry.pendingIndexBox);
    _assertOpen(BoxRegistry.pendingIndexBox);
    return Hive.box(BoxRegistry.pendingIndexBox);
  }

  /// Access failed operations box.
  Box<FailedOpModel> failedOps() {
    _trackAccess(BoxRegistry.failedOpsBox);
    _assertOpen(BoxRegistry.failedOpsBox);
    return Hive.box<FailedOpModel>(BoxRegistry.failedOpsBox);
  }

  /// Access rooms box.
  Box<RoomModel> rooms() {
    _trackAccess(BoxRegistry.roomsBox);
    _assertOpen(BoxRegistry.roomsBox);
    return Hive.box<RoomModel>(BoxRegistry.roomsBox);
  }

  /// Access devices box.
  Box<DeviceModel> devices() {
    _trackAccess(BoxRegistry.devicesBox);
    _assertOpen(BoxRegistry.devicesBox);
    return Hive.box<DeviceModel>(BoxRegistry.devicesBox);
  }

  /// Access vitals box.
  Box<VitalsModel> vitals() {
    _trackAccess(BoxRegistry.vitalsBox);
    _assertOpen(BoxRegistry.vitalsBox);
    return Hive.box<VitalsModel>(BoxRegistry.vitalsBox);
  }

  /// Access settings box.
  Box<SettingsModel> settings() {
    _trackAccess(BoxRegistry.settingsBox);
    _assertOpen(BoxRegistry.settingsBox);
    return Hive.box<SettingsModel>(BoxRegistry.settingsBox);
  }

  /// Access audit logs box.
  Box<AuditLogRecord> auditLogs() {
    _trackAccess(BoxRegistry.auditLogsBox);
    _assertOpen(BoxRegistry.auditLogsBox);
    return Hive.box<AuditLogRecord>(BoxRegistry.auditLogsBox);
  }

  /// Access user profile box.
  Box userProfile() {
    _trackAccess(BoxRegistry.userProfileBox);
    _assertOpen(BoxRegistry.userProfileBox);
    return Hive.box(BoxRegistry.userProfileBox);
  }

  /// Access sessions box.
  Box sessions() {
    _trackAccess(BoxRegistry.sessionsBox);
    _assertOpen(BoxRegistry.sessionsBox);
    return Hive.box(BoxRegistry.sessionsBox);
  }

  /// Access meta box.
  Box meta() {
    _trackAccess(BoxRegistry.metaBox);
    _assertOpen(BoxRegistry.metaBox);
    return Hive.box(BoxRegistry.metaBox);
  }

  /// Access assets cache box.
  Box assetsCache() {
    _trackAccess(BoxRegistry.assetsCacheBox);
    _assertOpen(BoxRegistry.assetsCacheBox);
    return Hive.box(BoxRegistry.assetsCacheBox);
  }

  /// Access UI preferences box.
  Box uiPreferences() {
    _trackAccess(BoxRegistry.uiPreferencesBox);
    _assertOpen(BoxRegistry.uiPreferencesBox);
    return Hive.box(BoxRegistry.uiPreferencesBox);
  }

  /// Access relationships box.
  Box<RelationshipModel> relationships() {
    _trackAccess(BoxRegistry.relationshipsBox);
    _assertOpen(BoxRegistry.relationshipsBox);
    return Hive.box<RelationshipModel>(BoxRegistry.relationshipsBox);
  }

  /// Access doctor-patient relationships box.
  Box<DoctorRelationshipModel> doctorRelationships() {
    _trackAccess(BoxRegistry.doctorRelationshipsBox);
    _assertOpen(BoxRegistry.doctorRelationshipsBox);
    return Hive.box<DoctorRelationshipModel>(BoxRegistry.doctorRelationshipsBox);
  }

  /// Access chat threads box.
  Box<ChatThreadModel> chatThreads() {
    _trackAccess(BoxRegistry.chatThreadsBox);
    _assertOpen(BoxRegistry.chatThreadsBox);
    return Hive.box<ChatThreadModel>(BoxRegistry.chatThreadsBox);
  }

  /// Access chat messages box.
  Box<ChatMessageModel> chatMessages() {
    _trackAccess(BoxRegistry.chatMessagesBox);
    _assertOpen(BoxRegistry.chatMessagesBox);
    return Hive.box<ChatMessageModel>(BoxRegistry.chatMessagesBox);
  }

  /// Access health readings box.
  Box<StoredHealthReading> healthReadings() {
    _trackAccess(BoxRegistry.healthReadingsBox);
    _assertOpen(BoxRegistry.healthReadingsBox);
    return Hive.box<StoredHealthReading>(BoxRegistry.healthReadingsBox);
  }

  /// Access emergency ops box.
  Box<PendingOp> emergencyOps() {
    _trackAccess(BoxRegistry.emergencyOpsBox);
    _assertOpen(BoxRegistry.emergencyOpsBox);
    return Hive.box<PendingOp>(BoxRegistry.emergencyOpsBox);
  }

  /// Access safety state box.
  Box safetyState() {
    _trackAccess(BoxRegistry.safetyStateBox);
    _assertOpen(BoxRegistry.safetyStateBox);
    return Hive.box(BoxRegistry.safetyStateBox);
  }

  /// Access transaction journal box.
  Box transactionJournal() {
    _trackAccess(BoxRegistry.transactionJournalBox);
    _assertOpen(BoxRegistry.transactionJournalBox);
    return Hive.box(BoxRegistry.transactionJournalBox);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // GENERIC ACCESSOR (for dynamic cases)
  // ═══════════════════════════════════════════════════════════════════════

  /// Generic box accessor for dynamic use cases.
  ///
  /// Prefer using typed accessors above. Use this only when the box
  /// type is determined at runtime.
  Box<T> box<T>(String boxName) {
    _trackAccess(boxName);
    _assertOpen(boxName);
    return Hive.box<T>(boxName);
  }

  /// Generic untyped box accessor.
  Box boxUntyped(String boxName) {
    _trackAccess(boxName);
    _assertOpen(boxName);
    switch (boxName) {
      case BoxRegistry.pendingOpsBox:
        return Hive.box<PendingOp>(boxName);
      case BoxRegistry.failedOpsBox:
        return Hive.box<FailedOpModel>(boxName);
      case BoxRegistry.roomsBox:
        return Hive.box<RoomModel>(boxName);
      case BoxRegistry.devicesBox:
        return Hive.box<DeviceModel>(boxName);
      case BoxRegistry.vitalsBox:
        return Hive.box<VitalsModel>(boxName);
      case BoxRegistry.settingsBox:
        return Hive.box<SettingsModel>(boxName);
      case BoxRegistry.auditLogsBox:
        return Hive.box<AuditLogRecord>(boxName);
      case BoxRegistry.relationshipsBox:
        return Hive.box<RelationshipModel>(boxName);
      case BoxRegistry.chatThreadsBox:
        return Hive.box<ChatThreadModel>(boxName);
      case BoxRegistry.chatMessagesBox:
        return Hive.box<ChatMessageModel>(boxName);
      case BoxRegistry.healthReadingsBox:
        return Hive.box<StoredHealthReading>(boxName);
      default:
        return Hive.box(boxName);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SAFE ACCESSORS (returns null if not open)
  // ═══════════════════════════════════════════════════════════════════════

  /// Safe accessor - returns null if box is not open.
  Box<T>? safeBox<T>(String boxName) {
    if (!Hive.isBoxOpen(boxName)) return null;
    _trackAccess(boxName);
    return Hive.box<T>(boxName);
  }

  /// Check if a box is open.
  bool isOpen(String boxName) => Hive.isBoxOpen(boxName);

  // ═══════════════════════════════════════════════════════════════════════
  // INTERNAL HELPERS
  // ═══════════════════════════════════════════════════════════════════════

  void _assertOpen(String boxName) {
    if (!Hive.isBoxOpen(boxName)) {
      _telemetry?.increment('box_accessor.not_open.$boxName');
      throw StateError(
        'Box "$boxName" is not open. Ensure HiveService.init() was called.',
      );
    }
  }

  void _trackAccess(String boxName) {
    _telemetry?.increment('box_accessor.access.$boxName');
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SHARED INSTANCE MANAGEMENT
// ═══════════════════════════════════════════════════════════════════════════

// Shared instance (avoids circular imports)
BoxAccessor? _sharedBoxAccessorInstance;

/// Sets the shared BoxAccessor instance.
void setSharedBoxAccessorInstance(BoxAccessor instance) {
  _sharedBoxAccessorInstance = instance;
}

/// Gets or creates the shared BoxAccessor instance.
BoxAccessor getSharedBoxAccessorInstance() {
  return _sharedBoxAccessorInstance ??= BoxAccessor();
}

// ═══════════════════════════════════════════════════════════════════════════
// STATIC SINGLETON (for non-Riverpod contexts)
// ═══════════════════════════════════════════════════════════════════════════

/// Static accessor for contexts without Riverpod access.
///
/// Use this in:
/// - Static methods
/// - Constructors that can't use ref
/// - Bootstrap/initialization code
///
/// Prefer `ref.read(boxAccessorProvider)` when Riverpod is available.
///
/// Note: Unlike deprecated service singletons, BoxAccess is intentionally
/// static because box access is a low-level primitive needed during
/// bootstrap before Riverpod is initialized.
class BoxAccess {
  /// Static accessor for non-Riverpod contexts.
  /// 
  /// Example:
  /// ```dart
  /// final box = BoxAccess.I.pendingOps();
  /// ```
  @Deprecated('Use boxAccessorProvider or ServiceInstances.boxAccessor instead')
  static BoxAccessor get I => getSharedBoxAccessorInstance();
}
