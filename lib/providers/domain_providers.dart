/// Domain Repository Providers - PHASE 2 Data Flow Providers
///
/// PHASE 2: Backend is the only source of truth.
///
/// This file provides all domain-specific providers that:
/// 1. Use Hive-backed repositories (NOT in-memory)
/// 2. Provide reactive streams via StreamProvider
/// 3. Ensure UI always reflects Hive state
///
/// Data Flow:
/// UI → Provider → Repository → BoxAccessor → Hive
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/vitals_repository.dart';
import '../repositories/impl/vitals_repository_hive.dart';
import '../repositories/session_repository.dart';
import '../repositories/impl/session_repository_hive.dart';
import '../repositories/settings_repository.dart';
import '../repositories/impl/settings_repository_hive.dart';
import '../repositories/audit_repository.dart';
import '../repositories/impl/audit_repository_hive.dart';
import '../repositories/emergency_repository.dart';
import '../repositories/impl/emergency_repository_hive.dart';
import '../repositories/home_automation_repository.dart';
import '../repositories/impl/home_automation_repository_hive.dart';
import '../repositories/user_profile_repository.dart';
import '../repositories/impl/user_profile_repository_hive.dart';
import '../models/vitals_model.dart';
import '../models/session_model.dart';
import '../models/settings_model.dart';
import '../models/audit_log_record.dart';
import '../models/user_profile_model.dart';
import '../persistence/wrappers/box_accessor.dart';
// Import home automation models with prefix to avoid collision with global models
import '../home automation/src/data/models/room_model.dart' as ha;
import '../home automation/src/data/models/device_model.dart' as ha;

// Re-export for convenience
export '../repositories/emergency_repository.dart' show EmergencyState;
export '../repositories/home_automation_repository.dart' show AutomationState;

// ═══════════════════════════════════════════════════════════════════════════
// REPOSITORY PROVIDERS (Single Source of Truth)
// ═══════════════════════════════════════════════════════════════════════════

/// Vitals repository provider - Hive backed.
final vitalsRepositoryProvider = Provider<VitalsRepository>((ref) {
  final boxAccessor = ref.watch(boxAccessorProvider);
  return VitalsRepositoryHive(boxAccessor: boxAccessor);
});

/// Session repository provider - Hive backed.
final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  final boxAccessor = ref.watch(boxAccessorProvider);
  return SessionRepositoryHive(boxAccessor: boxAccessor);
});

/// Settings repository provider - Hive backed.
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final boxAccessor = ref.watch(boxAccessorProvider);
  return SettingsRepositoryHive(boxAccessor: boxAccessor);
});

/// Audit repository provider - Hive backed.
final auditRepositoryProvider = Provider<AuditRepository>((ref) {
  final boxAccessor = ref.watch(boxAccessorProvider);
  return AuditRepositoryHive(boxAccessor: boxAccessor);
});

/// Emergency repository provider - Hive backed.
final emergencyRepositoryProvider = Provider<EmergencyRepository>((ref) {
  final boxAccessor = ref.watch(boxAccessorProvider);
  return EmergencyRepositoryHive(boxAccessor: boxAccessor);
});

/// Home automation repository provider - Hive backed.
/// Note: Uses LocalHiveService internally, not BoxAccessor.
final homeAutomationRepositoryProvider = Provider<HomeAutomationRepository>((ref) {
  return HomeAutomationRepositoryHive();
});

/// User profile repository provider - Hive backed.
final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  final boxAccessor = ref.watch(boxAccessorProvider);
  return UserProfileRepositoryHive(boxAccessor: boxAccessor);
});

// ═══════════════════════════════════════════════════════════════════════════
// VITALS PROVIDERS (Reactive)
// ═══════════════════════════════════════════════════════════════════════════

/// Watch all vitals - reactive stream.
final vitalsProvider = StreamProvider<List<VitalsModel>>((ref) {
  final repo = ref.watch(vitalsRepositoryProvider);
  return repo.watchAll();
});

/// Watch vitals for a specific user.
final vitalsForUserProvider = StreamProvider.family<List<VitalsModel>, String>((ref, userId) {
  final repo = ref.watch(vitalsRepositoryProvider);
  return repo.watchForUser(userId);
});

/// Get latest vital for current user (derived).
final latestVitalProvider = FutureProvider<VitalsModel?>((ref) async {
  final session = await ref.watch(sessionRepositoryProvider).getCurrent();
  if (session == null) return null;
  final repo = ref.watch(vitalsRepositoryProvider);
  return repo.getLatestForUser(session.userId);
});

// ═══════════════════════════════════════════════════════════════════════════
// SESSION PROVIDERS (Reactive)
// ═══════════════════════════════════════════════════════════════════════════

/// Watch current session - reactive stream.
final sessionProvider = StreamProvider<SessionModel?>((ref) {
  final repo = ref.watch(sessionRepositoryProvider);
  return repo.watchCurrent();
});

/// Check if session is valid.
final hasValidSessionProvider = FutureProvider<bool>((ref) {
  final repo = ref.watch(sessionRepositoryProvider);
  return repo.hasValidSession();
});

/// Get current user ID.
final currentUserIdProvider = FutureProvider<String?>((ref) {
  final repo = ref.watch(sessionRepositoryProvider);
  return repo.getCurrentUserId();
});

// ═══════════════════════════════════════════════════════════════════════════
// SETTINGS PROVIDERS (Reactive)
// ═══════════════════════════════════════════════════════════════════════════

/// Watch settings - reactive stream.
final settingsProvider = StreamProvider<SettingsModel>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.watchSettings();
});

/// Get notifications enabled.
final notificationsEnabledProvider = Provider<bool>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.maybeWhen(
    data: (s) => s.notificationsEnabled,
    orElse: () => true,
  );
});

/// Get dev tools enabled.
final devToolsEnabledProvider = Provider<bool>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.maybeWhen(
    data: (s) => s.devToolsEnabled,
    orElse: () => false,
  );
});

// ═══════════════════════════════════════════════════════════════════════════
// AUDIT PROVIDERS (Reactive)
// ═══════════════════════════════════════════════════════════════════════════

/// Watch all audit logs - reactive stream.
final auditLogProvider = StreamProvider<List<AuditLogRecord>>((ref) {
  final repo = ref.watch(auditRepositoryProvider);
  return repo.watchAll();
});

/// Watch audit logs for specific actor.
final auditLogForActorProvider = StreamProvider.family<List<AuditLogRecord>, String>((ref, actor) {
  final repo = ref.watch(auditRepositoryProvider);
  return repo.watchForActor(actor);
});

/// Get audit log count.
final auditLogCountProvider = FutureProvider<int>((ref) {
  final repo = ref.watch(auditRepositoryProvider);
  return repo.getCount();
});

// ═══════════════════════════════════════════════════════════════════════════
// EMERGENCY PROVIDERS (Reactive)
// ═══════════════════════════════════════════════════════════════════════════

/// Watch emergency state - reactive stream.
final emergencyStateProvider = StreamProvider<EmergencyState>((ref) {
  final repo = ref.watch(emergencyRepositoryProvider);
  return repo.watchState();
});

/// Check if there are pending operations.
final hasPendingOpsProvider = Provider<bool>((ref) {
  final state = ref.watch(emergencyStateProvider);
  return state.maybeWhen(
    data: (s) => s.hasUnsyncedData,
    orElse: () => false,
  );
});

/// Check if in offline mode.
final isOfflineModeProvider = Provider<bool>((ref) {
  final state = ref.watch(emergencyStateProvider);
  return state.maybeWhen(
    data: (s) => s.isOfflineMode,
    orElse: () => false,
  );
});

/// Get pending operations count.
final pendingOpsCountProvider = Provider<int>((ref) {
  final state = ref.watch(emergencyStateProvider);
  return state.maybeWhen(
    data: (s) => s.pendingOpsCount,
    orElse: () => 0,
  );
});

/// Get failed operations count.
final failedOpsCountProvider = Provider<int>((ref) {
  final state = ref.watch(emergencyStateProvider);
  return state.maybeWhen(
    data: (s) => s.failedOpsCount,
    orElse: () => 0,
  );
});

// ═══════════════════════════════════════════════════════════════════════════
// HOME AUTOMATION PROVIDERS (Reactive)
// ═══════════════════════════════════════════════════════════════════════════

/// Watch automation state - reactive stream.
final automationStateProvider = StreamProvider<AutomationState>((ref) {
  final repo = ref.watch(homeAutomationRepositoryProvider);
  return repo.watchState();
});

/// Watch all rooms - reactive stream.
/// REPLACES InMemoryRoomRepository!
final roomListProvider = StreamProvider<List<ha.RoomModel>>((ref) {
  final repo = ref.watch(homeAutomationRepositoryProvider);
  return repo.watchRooms();
});

/// Watch all devices - reactive stream.
final deviceListProvider = StreamProvider<List<ha.DeviceModel>>((ref) {
  final repo = ref.watch(homeAutomationRepositoryProvider);
  return repo.watchDevices();
});

/// Watch devices for a specific room.
final devicesForRoomProvider = StreamProvider.family<List<ha.DeviceModel>, String>((ref, roomId) {
  final repo = ref.watch(homeAutomationRepositoryProvider);
  return repo.watchDevicesForRoom(roomId);
});

/// Get active devices count.
final activeDevicesCountProvider = Provider<int>((ref) {
  final state = ref.watch(automationStateProvider);
  return state.maybeWhen(
    data: (s) => s.activeDevices,
    orElse: () => 0,
  );
});

/// Get total devices count.
final totalDevicesCountProvider = Provider<int>((ref) {
  final state = ref.watch(automationStateProvider);
  return state.maybeWhen(
    data: (s) => s.totalDevices,
    orElse: () => 0,
  );
});

/// Get total rooms count.
final totalRoomsCountProvider = Provider<int>((ref) {
  final state = ref.watch(automationStateProvider);
  return state.maybeWhen(
    data: (s) => s.totalRooms,
    orElse: () => 0,
  );
});

// ═══════════════════════════════════════════════════════════════════════════
// USER PROFILE PROVIDERS (Reactive)
// ═══════════════════════════════════════════════════════════════════════════

/// Watch current user profile - reactive stream.
final userProfileProvider = StreamProvider<UserProfileModel?>((ref) {
  final repo = ref.watch(userProfileRepositoryProvider);
  return repo.watchCurrent();
});

/// Get current user name.
final currentUserNameProvider = Provider<String>((ref) {
  final profile = ref.watch(userProfileProvider);
  return profile.maybeWhen(
    data: (p) => p?.displayName ?? 'User',
    orElse: () => 'User',
  );
});

/// Get current user role.
final currentUserRoleProvider = Provider<String>((ref) {
  final profile = ref.watch(userProfileProvider);
  return profile.maybeWhen(
    data: (p) => p?.role ?? 'patient',
    orElse: () => 'patient',
  );
});

// ═══════════════════════════════════════════════════════════════════════════
// COMBINED STATE PROVIDERS (Cross-Domain)
// ═══════════════════════════════════════════════════════════════════════════

/// Global sync status - combines multiple states.
final syncStatusProvider = Provider<SyncStatus>((ref) {
  final pendingCount = ref.watch(pendingOpsCountProvider);
  final failedCount = ref.watch(failedOpsCountProvider);
  final isOffline = ref.watch(isOfflineModeProvider);

  if (failedCount > 0) {
    return SyncStatus.failed;
  } else if (pendingCount > 0) {
    return SyncStatus.pending;
  } else if (isOffline) {
    return SyncStatus.offline;
  }
  return SyncStatus.synced;
});

/// Sync status enum.
enum SyncStatus {
  synced,
  pending,
  failed,
  offline,
}

/// Extension for human-readable status.
extension SyncStatusX on SyncStatus {
  String get message {
    switch (this) {
      case SyncStatus.synced:
        return 'All data synced';
      case SyncStatus.pending:
        return 'Syncing changes...';
      case SyncStatus.failed:
        return 'Sync failed - tap to retry';
      case SyncStatus.offline:
        return 'Offline mode - changes will sync later';
    }
  }

  bool get showBanner => this != SyncStatus.synced;
}
