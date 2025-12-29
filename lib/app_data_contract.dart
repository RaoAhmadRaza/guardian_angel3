/// App Data Contract - Canonical Data Flow Definition
///
/// PHASE 2: Backend is the only source of truth everywhere.
///
/// This file defines the MANDATORY data flow for all domains:
/// UI → Provider → Repository → BoxAccessor → Hive
///
/// NO EXCEPTIONS. If a screen displays business data, it MUST
/// follow this contract.
library;

// ═══════════════════════════════════════════════════════════════════════════
// DATA FLOW CONTRACT TABLE
// ═══════════════════════════════════════════════════════════════════════════
//
// ┌────────────────┬─────────────────────────┬─────────────────────────────┬────────────────────┐
// │ Domain         │ Repository              │ Provider                    │ Box                │
// ├────────────────┼─────────────────────────┼─────────────────────────────┼────────────────────┤
// │ Rooms          │ RoomRepository          │ roomListProvider            │ rooms_box          │
// │ Devices        │ DeviceRepository        │ deviceListProvider          │ devices_box        │
// │ Vitals         │ VitalsRepository        │ vitalsProvider              │ vitals_box         │
// │ Sessions       │ SessionRepository       │ sessionProvider             │ sessions_box       │
// │ Settings       │ SettingsRepository      │ settingsProvider            │ settings_box       │
// │ Automation     │ HomeAutomationRepository│ automationStateProvider     │ rooms/devices      │
// │ Emergency      │ EmergencyRepository     │ emergencyStateProvider      │ emergency_ops_box  │
// │ Audit          │ AuditRepository         │ auditLogProvider            │ audit_logs_box     │
// │ User Profile   │ UserProfileRepository   │ userProfileProvider         │ user_profile_box   │
// └────────────────┴─────────────────────────┴─────────────────────────────┴────────────────────┘
//
// ═══════════════════════════════════════════════════════════════════════════

/// Data flow verification enum for runtime checks.
enum DataFlowDomain {
  rooms,
  devices,
  vitals,
  sessions,
  settings,
  automation,
  emergency,
  audit,
  userProfile,
  relationships,
}

/// Maps domains to their canonical box names.
const Map<DataFlowDomain, String> domainBoxMapping = {
  DataFlowDomain.rooms: 'rooms_box',
  DataFlowDomain.devices: 'devices_box',
  DataFlowDomain.vitals: 'vitals_box',
  DataFlowDomain.sessions: 'sessions_box',
  DataFlowDomain.settings: 'settings_box',
  DataFlowDomain.automation: 'rooms_box', // Uses rooms + devices
  DataFlowDomain.emergency: 'emergency_ops_box',
  DataFlowDomain.audit: 'audit_logs_box',
  DataFlowDomain.userProfile: 'user_profile_box',
  DataFlowDomain.relationships: 'relationships_box',
};

/// Contract verification helper.
///
/// Use in dev mode to assert proper data flow:
/// ```dart
/// assert(DataFlowContract.verifySource(DataFlowDomain.rooms, 'rooms_box'));
/// ```
class DataFlowContract {
  /// Verifies that data is sourced from the correct box.
  static bool verifySource(DataFlowDomain domain, String boxName) {
    return domainBoxMapping[domain] == boxName;
  }

  /// Returns the required data flow path for a domain.
  static String getFlowPath(DataFlowDomain domain) {
    switch (domain) {
      case DataFlowDomain.rooms:
        return 'UI → roomListProvider → RoomRepository → BoxAccessor.rooms() → Hive';
      case DataFlowDomain.devices:
        return 'UI → deviceListProvider → DeviceRepository → BoxAccessor.devices() → Hive';
      case DataFlowDomain.vitals:
        return 'UI → vitalsProvider → VitalsRepository → BoxAccessor.vitals() → Hive';
      case DataFlowDomain.sessions:
        return 'UI → sessionProvider → SessionRepository → BoxAccessor.sessions() → Hive';
      case DataFlowDomain.settings:
        return 'UI → settingsProvider → SettingsRepository → BoxAccessor.settings() → Hive';
      case DataFlowDomain.automation:
        return 'UI → automationStateProvider → HomeAutomationRepository → BoxAccessor.rooms()/devices() → Hive';
      case DataFlowDomain.emergency:
        return 'UI → emergencyStateProvider → EmergencyRepository → BoxAccessor.emergencyOps() → Hive';
      case DataFlowDomain.audit:
        return 'UI → auditLogProvider → AuditRepository → BoxAccessor.auditLogs() → Hive';
      case DataFlowDomain.userProfile:
        return 'UI → userProfileProvider → UserProfileRepository → BoxAccessor.userProfile() → Hive';
      case DataFlowDomain.relationships:
        return 'UI → relationshipProvider → RelationshipRepository → BoxAccessor.relationships() → Hive';
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FORBIDDEN PATTERNS (DO NOT USE)
// ═══════════════════════════════════════════════════════════════════════════
//
// ❌ In-memory mock repositories as default:
//    return InMemoryRoomRepository();
//
// ❌ StatefulWidget holding domain data:
//    List<Room> _rooms = [];
//
// ❌ initState() fetching domain data:
//    void initState() { _loadRooms(); }
//
// ❌ Hardcoded sample data in UI:
//    final List<Map<String, dynamic>> allRooms = [...]
//
// ❌ Parallel/cached state:
//    _currentHome, _cachedRooms, _selectedDevice
//
// ═══════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════
// REQUIRED PATTERNS (ALWAYS USE)
// ═══════════════════════════════════════════════════════════════════════════
//
// ✅ Provider-backed data:
//    final rooms = ref.watch(roomListProvider);
//
// ✅ Async state handling:
//    rooms.when(data: render, loading: showLoading, error: showError);
//
// ✅ Repository writes:
//    await ref.read(roomRepositoryProvider).createRoom(room);
//
// ✅ Reactive streams:
//    yield* box.watch().map((_) => box.values.toList());
//
// ✅ UI-only state (allowed):
//    Selected tab, expanded card, animation progress
//
// ═══════════════════════════════════════════════════════════════════════════
