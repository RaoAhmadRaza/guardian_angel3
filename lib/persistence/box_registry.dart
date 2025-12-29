import 'dart:io';
import 'package:hive/hive.dart';
import '../models/pending_op.dart';
import '../models/room_model.dart';
import '../models/vitals_model.dart';
import 'wrappers/box_accessor.dart';

// Re-export TypeIds from authoritative source for backward compatibility
export 'type_ids.dart' show TypeIds;

class BoxRegistry {
  // ═══════════════════════════════════════════════════════════════════════
  // CORE PERSISTENCE BOX NAMES (authoritative)
  // ═══════════════════════════════════════════════════════════════════════
  
  /// Core room data (RoomModel) - used by core persistence layer
  static const roomsBox = 'rooms_box';
  
  /// Core device data (DeviceModel) - used by core persistence layer
  static const devicesBox = 'devices_box';
  
  static const vitalsBox = 'vitals_box';
  static const userProfileBox = 'user_profile_box';
  static const sessionsBox = 'sessions_box';
  static const pendingOpsBox = 'pending_ops_box';
  static const pendingIndexBox = 'pending_index_box';
  static const failedOpsBox = 'failed_ops_box';
  static const auditLogsBox = 'audit_logs_box';
  static const settingsBox = 'settings_box';
  static const assetsCacheBox = 'assets_cache_box';
  static const uiPreferencesBox = 'ui_preferences_box';
  static const metaBox = 'persistence_metadata_box';
  static const emergencyOpsBox = 'emergency_ops_box';
  static const safetyStateBox = 'safety_state_box';
  static const transactionJournalBox = 'transaction_journal_box';

  // ═══════════════════════════════════════════════════════════════════════
  // ONBOARDING & USER TABLE BOX NAMES (authoritative)
  // ═══════════════════════════════════════════════════════════════════════
  
  /// User base data (email, fullName, profileImageUrl) - auth basics
  static const userBaseBox = 'user_base_box';
  
  /// Caregiver user data (role assignment)
  static const caregiverUserBox = 'caregiver_user_box';
  
  /// Caregiver details data (full caregiver profile)
  static const caregiverDetailsBox = 'caregiver_details_box';
  
  /// Patient user data (role assignment + age)
  static const patientUserBox = 'patient_user_box';
  
  /// Patient details data (full patient profile)
  static const patientDetailsBox = 'patient_details_box';
  
  /// Relationship data (patient-caregiver links)
  static const relationshipsBox = 'relationships_box';

  // ═══════════════════════════════════════════════════════════════════════════
  // CHAT SYSTEM BOX NAMES (authoritative)
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Chat threads box (ChatThreadModel) - one thread per relationship
  /// Contains: thread metadata, last message preview, unread counts
  /// Encrypted: YES (contains conversation metadata)
  static const chatThreadsBox = 'chat_threads_box';
  
  /// Chat messages box (ChatMessageModel) - all messages keyed by threadId+messageId
  /// Contains: actual message content, timestamps, delivery status
  /// Encrypted: YES (contains PII - conversation content)
  /// 
  /// BOX STRATEGY JUSTIFICATION:
  /// We use a SINGLE chat_messages_box with composite keys (threadId:messageId)
  /// instead of per-thread boxes because:
  /// 1. Simpler lifecycle management - no dynamic box creation/deletion
  /// 2. Easier backup/restore - single box to handle
  /// 3. Consistent with existing project patterns (rooms, vitals, etc.)
  /// 4. Query pattern: messages are typically loaded by thread, which is 
  ///    efficiently handled via filtering on composite key prefix
  static const chatMessagesBox = 'chat_messages_box';

  // ═══════════════════════════════════════════════════════════════════════════
  // HOME AUTOMATION BOX NAMES (authoritative)
  // These use different Hive models (RoomModelHive, DeviceModelHive)
  // ═══════════════════════════════════════════════════════════════════════
  
  /// Home automation room data (RoomModelHive) - CANONICAL name
  /// @deprecated 'rooms_v1' is legacy. Use homeAutomationRoomsBox for new code.
  static const homeAutomationRoomsBoxLegacy = 'rooms_v1';
  
  /// Home automation room data (RoomModelHive) - CURRENT name
  static const homeAutomationRoomsBox = 'ha_rooms_box';
  
  /// Home automation device data (DeviceModelHive) - CANONICAL name  
  /// @deprecated 'devices_v1' is legacy. Use homeAutomationDevicesBox for new code.
  static const homeAutomationDevicesBoxLegacy = 'devices_v1';
  
  /// Home automation device data (DeviceModelHive) - CURRENT name
  static const homeAutomationDevicesBox = 'ha_devices_box';

  /// Home automation failed operations (PendingOp) - domain-specific
  static const homeAutomationFailedOpsBox = 'ha_failed_ops_box';

  static const allBoxes = <String>[
    roomsBox,
    devicesBox,
    vitalsBox,
    userProfileBox,
    sessionsBox,
    pendingOpsBox,
    pendingIndexBox,
    failedOpsBox,
    auditLogsBox,
    settingsBox,
    assetsCacheBox,
    uiPreferencesBox,
    metaBox,
    emergencyOpsBox,
    safetyStateBox,
    transactionJournalBox,
    // Onboarding & User table boxes
    userBaseBox,
    caregiverUserBox,
    caregiverDetailsBox,
    patientUserBox,
    patientDetailsBox,
    relationshipsBox,
    // Chat system boxes
    chatThreadsBox,
    chatMessagesBox,
    // Home automation boxes
    homeAutomationRoomsBox,
    homeAutomationDevicesBox,
    homeAutomationFailedOpsBox,
  ];
  
  /// Legacy box names that may still contain data (for migration)
  static const legacyBoxes = <String>[
    homeAutomationRoomsBoxLegacy,  // 'rooms_v1'
    homeAutomationDevicesBoxLegacy, // 'devices_v1'
  ];

  /// @deprecated Use BoxAccess.I.box<T>() instead
  Box<T> box<T>(String name) => BoxAccess.I.box<T>(name);

  /// @deprecated Use BoxAccess.I.pendingOps() instead
  Box<PendingOp> pendingOps() => BoxAccess.I.pendingOps();
  
  /// @deprecated Use BoxAccess.I.boxUntyped(pendingIndexBox) instead
  Box pendingIndex() => BoxAccess.I.boxUntyped(pendingIndexBox);
  
  /// @deprecated Use BoxAccess.I.rooms() instead
  Box<RoomModel> rooms() => BoxAccess.I.rooms();
  
  /// @deprecated Use BoxAccess.I.vitals() instead
  Box<VitalsModel> vitals() => BoxAccess.I.vitals();

  Future<Box> openTempBox(String name) async => Hive.openBox(name);

  Future<void> backupAllBoxes({required String suffix}) async {
    // Derive Hive directory path from any open box; if none, skip.
    String hiveDirPath = '';
    for (final name in allBoxes) {
      if (!Hive.isBoxOpen(name)) continue;
      try {
        final dynamic b = BoxAccess.I.boxUntyped(name);
        final String? p = (b as Box).path;
        if (p != null && p.contains('/$name')) {
          hiveDirPath = p.replaceAll('/$name', '');
          break;
        }
      } catch (_) {
        // Skip type-mismatch issues when accessing with dynamic
        continue;
      }
    }
    if (hiveDirPath.isEmpty) return;
    final hiveDir = Directory(hiveDirPath);
    if (!await hiveDir.exists()) return;
    final timestamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final backupDir = Directory('${hiveDir.path}/migration_backups');
    if (!await backupDir.exists()) await backupDir.create(recursive: true);
    for (final boxName in allBoxes) {
      final file = File('${hiveDir.path}/$boxName.hive');
      if (await file.exists()) {
        final copyTarget = File('${backupDir.path}/$boxName.$suffix.$timestamp.bak');
        await file.copy(copyTarget.path);
      }
    }
  }
}
