# Guardian Angel — Local Backend Architecture Documentation

> **Version:** 1.0  
> **Last Updated:** January 10, 2026  
> **Flutter SDK:** ^3.8.1  
> **State Management:** Riverpod  
> **Local Storage:** Hive (Encrypted)  
> **Cloud Backend:** Firebase (Auth, Firestore, FCM, Storage)

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Core Principles](#2-core-principles)
3. [Service Layer](#3-service-layer)
4. [Provider Layer](#4-provider-layer)
5. [Repository Layer](#5-repository-layer)
6. [Persistence Layer (Hive)](#6-persistence-layer-hive)
7. [Firebase Integration](#7-firebase-integration)
8. [Sync Engine](#8-sync-engine)
9. [Feature Modules](#9-feature-modules)
10. [Data Models](#10-data-models)
11. [API Keys & Configuration](#11-api-keys--configuration)
12. [Security Architecture](#12-security-architecture)

---

## 1. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              PRESENTATION LAYER                              │
│                     (Flutter Widgets / Screens / UI)                        │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              PROVIDER LAYER                                  │
│                    (Riverpod StateNotifiers / Providers)                    │
│                                                                             │
│  ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────────────────┐ │
│  │ Service Providers│ │ Domain Providers │ │ Feature-Specific Providers   │ │
│  └──────────────────┘ └──────────────────┘ └──────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              SERVICE LAYER                                   │
│                   (Business Logic / Orchestration)                          │
│                                                                             │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐ │
│  │ Auth       │ │ Chat       │ │ Health     │ │ Geofencing │ │ AI         │ │
│  │ Service    │ │ Service    │ │ Services   │ │ Service    │ │ Services   │ │
│  └────────────┘ └────────────┘ └────────────┘ └────────────┘ └────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                             REPOSITORY LAYER                                 │
│                    (Data Access Abstraction)                                │
│                                                                             │
│  ┌─────────────────────────────┐  ┌─────────────────────────────────────┐   │
│  │     Hive Repositories       │  │     Firestore Services (Mirror)    │   │
│  │     (Source of Truth)       │  │     (Non-blocking sync)            │   │
│  └─────────────────────────────┘  └─────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            PERSISTENCE LAYER                                 │
│                                                                             │
│  ┌───────────────────────────┐  ┌───────────────────────────────────────┐   │
│  │         Hive              │  │       Firebase                        │   │
│  │  (Local Encrypted DB)     │  │  (Auth / Firestore / Storage / FCM)   │   │
│  └───────────────────────────┘  └───────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Core Principles

### 2.1 Local-First Architecture
- **Hive is the single source of truth** for all user data
- Firebase/Firestore is a **non-blocking mirror** for cloud sync
- App works fully offline; syncs when connectivity resumes
- User experience never blocked by network operations

### 2.2 Dependency Injection via Riverpod
- No global singletons (migrated to proper DI)
- All services injectable and testable via provider overrides
- Clean dependency graph with explicit relationships

### 2.3 Security by Design
- All Hive boxes encrypted with device-bound keys
- Secure storage for encryption keys (Keychain/Keystore)
- HIPAA-compliant audit logging
- Secure data erasure capabilities

---

## 3. Service Layer

### 3.1 Core Services (`lib/services/`)

| Service | File | Purpose |
|---------|------|---------|
| **TelemetryService** | `telemetry_service.dart` | Metrics collection, performance monitoring, event logging |
| **AuditLogService** | `audit_log_service.dart` | HIPAA-compliant audit trail for data access |
| **SessionService** | `session_service.dart` | User session management, token refresh |
| **OnboardingService** | `onboarding_service.dart` | Onboarding flow state management |
| **FCMService** | `fcm_service.dart` | Push notifications (Firebase Cloud Messaging) |
| **PatientService** | `patient_service.dart` | Patient profile persistence (SharedPreferences) |
| **MedicationService** | `medication_service.dart` | Medication CRUD with soft-delete support |
| **NewsService** | `news_service.dart` | Daily news fetching (TheNewsAPI) |
| **DemoModeService** | `demo_mode_service.dart` | Demo/showcase mode toggle |
| **EmergencyContactService** | `emergency_contact_service.dart` | Emergency contacts management |
| **SyncFailureService** | `sync_failure_service.dart` | Sync failure tracking and retry logic |
| **SecureEraseService** | `secure_erase_service.dart` | Secure data deletion |
| **SecureEraseHardened** | `secure_erase_hardened.dart` | Multi-pass secure erasure |

### 3.2 AI Services

| Service | File | Purpose | API Used |
|---------|------|---------|----------|
| **GuardianAIService** | `guardian_ai_service.dart` | AI companion chat for elderly | OpenAI GPT-4o-mini |
| **PeaceOfMindAIService** | `peace_of_mind_ai_service.dart` | Mindfulness/reflection responses | OpenAI GPT-4o-mini |
| **AIChatService** | `ai_chat_service.dart` | General AI chat interface | OpenAI |

### 3.3 Fall Detection Services (`lib/services/fall_detection/`)

| Service | File | Purpose |
|---------|------|---------|
| **FallDetectionService** | `fall_detection_service.dart` | Global fall detection singleton |
| **FallDetectionManager** | `fall_detection_manager.dart` | TFLite model management, inference orchestration |
| **FallDetectionLoggingService** | `fall_detection_logging_service.dart` | Fall event logging and history |

### 3.4 SOS/Emergency Services

| Service | File | Purpose |
|---------|------|---------|
| **SOSEmergencyActionService** | `sos_emergency_action_service.dart` | Real emergency actions (SMS, calls, push) |
| **SOSAlertChatService** | `sos_alert_chat_service.dart` | SOS chat thread management |
| **PushNotificationSender** | `push_notification_sender.dart` | FCM notification dispatch |

### 3.5 Home Automation Services (`lib/home automation/src/services/`)

| Service | File | Purpose |
|---------|------|---------|
| **WeatherApi** | `weather_api.dart` | OpenWeatherMap integration |
| **LocationApi** | `location_api.dart` | OpenCage reverse geocoding |
| **ApiKeys** | `api_keys.dart` | Centralized API key storage |

### 3.6 Idempotency & Transaction Services

| Service | File | Purpose |
|---------|------|---------|
| **BackendIdempotencyService** | `backend_idempotency_service.dart` | Prevents duplicate operations |
| **LocalIdempotencyFallback** | `local_idempotency_fallback.dart` | Offline idempotency handling |
| **TransactionService** | `transaction_service.dart` | Database transaction management |
| **LockService** | `lock_service.dart` | Distributed lock management |
| **TTLCompactionService** | `ttl_compaction_service.dart` | Time-to-live data cleanup |

---

## 4. Provider Layer

### 4.1 Service Providers (`lib/providers/service_providers.dart`)

Core service dependency injection:

```dart
/// Telemetry service provider
final telemetryServiceProvider = Provider<TelemetryService>((ref) {
  return TelemetryService();
});

/// Audit log service provider (depends on telemetry)
final auditLogServiceProvider = Provider<AuditLogService>((ref) {
  final telemetry = ref.watch(telemetryServiceProvider);
  return AuditLogService(telemetry: telemetry);
});

/// Sync failure service provider
final syncFailureServiceProvider = Provider<SyncFailureService>((ref) {
  final telemetry = ref.watch(telemetryServiceProvider);
  return SyncFailureService(telemetry: telemetry);
});

/// Secure erase service provider
final secureEraseServiceProvider = Provider<SecureEraseService>((ref) {
  final telemetry = ref.watch(telemetryServiceProvider);
  return SecureEraseService(telemetry: telemetry);
});

/// Secure erase hardened provider
final secureEraseHardenedProvider = Provider<SecureEraseHardened>((ref) {
  final telemetry = ref.watch(telemetryServiceProvider);
  return SecureEraseHardened(telemetry: telemetry);
});

/// Production guardrails provider
final productionGuardrailsProvider = Provider<ProductionGuardrails>((ref) {
  final telemetry = ref.watch(telemetryServiceProvider);
  return ProductionGuardrails(telemetry: telemetry);
});

/// Session service provider
final sessionServiceProvider = Provider<SessionService>((ref) {
  return SessionService();
});

/// Onboarding service provider
final onboardingServiceProvider = Provider<OnboardingService>((ref) {
  return OnboardingService();
});
```

**Re-exports for convenience:**
- `storageMonitorProvider` — Storage monitoring
- `cacheInvalidatorProvider` — Cache management
- `boxAccessorProvider` — Hive box access
- `dataExportServiceProvider` — Data export/import
- `conflictResolutionServiceProvider` — Sync conflict UI

### 4.2 Domain Providers (`lib/providers/domain_providers.dart`)

Repository-backed reactive providers:

```dart
// ═══════════════════════════════════════════════════════════════════════════
// REPOSITORY PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

final vitalsRepositoryProvider = Provider<VitalsRepository>((ref) {
  final boxAccessor = ref.watch(boxAccessorProvider);
  return VitalsRepositoryHive(boxAccessor: boxAccessor);
});

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  final boxAccessor = ref.watch(boxAccessorProvider);
  return SessionRepositoryHive(boxAccessor: boxAccessor);
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final boxAccessor = ref.watch(boxAccessorProvider);
  return SettingsRepositoryHive(boxAccessor: boxAccessor);
});

final auditRepositoryProvider = Provider<AuditRepository>((ref) {
  final boxAccessor = ref.watch(boxAccessorProvider);
  return AuditRepositoryHive(boxAccessor: boxAccessor);
});

final emergencyRepositoryProvider = Provider<EmergencyRepository>((ref) {
  final boxAccessor = ref.watch(boxAccessorProvider);
  return EmergencyRepositoryHive(boxAccessor: boxAccessor);
});

final homeAutomationRepositoryProvider = Provider<HomeAutomationRepository>((ref) {
  return HomeAutomationRepositoryHive();
});

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  final boxAccessor = ref.watch(boxAccessorProvider);
  return UserProfileRepositoryHive(boxAccessor: boxAccessor);
});

// ═══════════════════════════════════════════════════════════════════════════
// REACTIVE STREAM PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

/// Watch all vitals
final vitalsProvider = StreamProvider<List<VitalsModel>>((ref) {
  final repo = ref.watch(vitalsRepositoryProvider);
  return repo.watchAll();
});

/// Watch vitals for specific user
final vitalsForUserProvider = StreamProvider.family<List<VitalsModel>, String>((ref, userId) {
  final repo = ref.watch(vitalsRepositoryProvider);
  return repo.watchForUser(userId);
});

/// Watch current session
final sessionProvider = StreamProvider<SessionModel?>((ref) {
  final repo = ref.watch(sessionRepositoryProvider);
  return repo.watchCurrent();
});

/// Watch settings
final settingsProvider = StreamProvider<SettingsModel>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.watchSettings();
});

/// Watch audit logs
final auditLogProvider = StreamProvider<List<AuditLogRecord>>((ref) {
  final repo = ref.watch(auditRepositoryProvider);
  return repo.watchAll();
});

/// Watch emergency state
final emergencyStateProvider = StreamProvider<EmergencyState>((ref) {
  final repo = ref.watch(emergencyRepositoryProvider);
  return repo.watchState();
});

/// Watch automation state
final automationStateProvider = StreamProvider<AutomationState>((ref) {
  final repo = ref.watch(homeAutomationRepositoryProvider);
  return repo.watchState();
});

/// Watch rooms
final roomListProvider = StreamProvider<List<RoomModel>>((ref) {
  final repo = ref.watch(homeAutomationRepositoryProvider);
  return repo.watchRooms();
});

/// Watch devices
final deviceListProvider = StreamProvider<List<DeviceModel>>((ref) {
  final repo = ref.watch(homeAutomationRepositoryProvider);
  return repo.watchDevices();
});

/// Watch user profile
final userProfileProvider = StreamProvider<UserProfileModel?>((ref) {
  final repo = ref.watch(userProfileRepositoryProvider);
  return repo.watchCurrent();
});

// ═══════════════════════════════════════════════════════════════════════════
// DERIVED PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

final hasValidSessionProvider = FutureProvider<bool>((ref) {
  final repo = ref.watch(sessionRepositoryProvider);
  return repo.hasValidSession();
});

final currentUserIdProvider = FutureProvider<String?>((ref) {
  final repo = ref.watch(sessionRepositoryProvider);
  return repo.getCurrentUserId();
});

final notificationsEnabledProvider = Provider<bool>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.maybeWhen(data: (s) => s.notificationsEnabled, orElse: () => true);
});

final devToolsEnabledProvider = Provider<bool>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.maybeWhen(data: (s) => s.devToolsEnabled, orElse: () => false);
});

/// Global sync status
final syncStatusProvider = Provider<SyncStatus>((ref) {
  final pendingCount = ref.watch(pendingOpsCountProvider);
  final failedCount = ref.watch(failedOpsCountProvider);
  final isOffline = ref.watch(isOfflineModeProvider);
  
  if (failedCount > 0) return SyncStatus.failed;
  if (pendingCount > 0) return SyncStatus.pending;
  if (isOffline) return SyncStatus.offline;
  return SyncStatus.synced;
});
```

### 4.3 Theme Provider (`lib/providers/theme_controller.dart`)

```dart
final themeControllerProvider = StateNotifierProvider<ThemeController, ThemeMode>((ref) {
  return ThemeController();
});
```

### 4.4 Sync Providers (`lib/sync/sync_providers.dart`)

```dart
/// API client provider (must be overridden)
final apiClientProvider = Provider<ApiClient>((ref) {
  throw UnimplementedError('apiClientProvider must be overridden');
});

/// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  throw UnimplementedError('authServiceProvider must be overridden');
});

/// Conflict resolver provider
final conflictResolverProvider = Provider<ConflictResolver>((ref) {
  return DefaultConflictResolver();
});

/// Sync consumer provider
final syncConsumerProvider = Provider<SyncConsumer>((ref) {
  final api = ref.watch(apiClientProvider);
  final resolver = ref.watch(conflictResolverProvider);
  return DefaultSyncConsumer(api: api, conflictResolver: resolver);
});

/// Adaptive sync consumer (falls back to NoOp when offline)
final adaptiveSyncConsumerProvider = Provider<SyncConsumer>((ref) {
  try {
    return ref.watch(syncConsumerProvider);
  } catch (_) {
    return NoOpSyncConsumer();
  }
});
```

### 4.5 Feature-Specific Providers

#### Health Providers (`lib/health/providers/`)

| Provider | File | Purpose |
|----------|------|---------|
| `healthExtractionProvider` | `health_extraction_provider.dart` | Health data extraction |
| `healthPersistenceProvider` | `health_persistence_provider.dart` | Health data storage |
| `healthSyncProviders` | `health_sync_providers.dart` | Health data sync |

#### Chat Providers (`lib/chat/providers/`)

| Provider | File | Purpose |
|----------|------|---------|
| `chatProvider` | `chat_provider.dart` | Chat state management |
| `doctorChatProvider` | `doctor_chat_provider.dart` | Doctor chat threads |

#### Geofencing Providers (`lib/geofencing/providers/`)

| Provider | File | Purpose |
|----------|------|---------|
| `safeZoneDataProvider` | `safe_zone_data_provider.dart` | Safe zone CRUD |

#### Stability Score Providers (`lib/stability_score/providers/`)

| Provider | File | Purpose |
|----------|------|---------|
| `stabilityScoreProvider` | `stability_score_provider.dart` | HSS computation and caching |

#### ML Providers (`lib/ml/providers/`)

| Provider | File | Purpose |
|----------|------|---------|
| `arrhythmiaProvider` | `arrhythmia_provider.dart` | Arrhythmia detection state |

#### Home Automation Providers (`lib/home automation/src/logic/providers/`)

| Provider | File | Purpose |
|----------|------|---------|
| `deviceProviders` | `device_providers.dart` | Device CRUD operations |
| `roomProviders` | `room_providers.dart` | Room CRUD operations |
| `hiveProviders` | `hive_providers.dart` | Hive box access |
| `syncProviders` | `sync_providers.dart` | Automation sync |
| `uiStateProviders` | `ui_state_providers.dart` | UI state |
| `weatherLocationProviders` | `weather_location_providers.dart` | Weather & location |

#### Caregiver Portal Provider (`lib/screens/caregiver_portal/providers/`)

| Provider | File | Purpose |
|----------|------|---------|
| `caregiverPortalProvider` | `caregiver_portal_provider.dart` | Multi-patient caregiver state |

---

## 5. Repository Layer

### 5.1 Repository Interfaces (`lib/repositories/`)

| Repository | File | Purpose |
|------------|------|---------|
| **VitalsRepository** | `vitals_repository.dart` | Vitals CRUD interface |
| **SessionRepository** | `session_repository.dart` | Session management interface |
| **SettingsRepository** | `settings_repository.dart` | App settings interface |
| **AuditRepository** | `audit_repository.dart` | Audit log interface |
| **EmergencyRepository** | `emergency_repository.dart` | Emergency state interface |
| **HomeAutomationRepository** | `home_automation_repository.dart` | Smart home interface |
| **UserProfileRepository** | `user_profile_repository.dart` | User profile interface |

### 5.2 Hive Implementations (`lib/repositories/impl/`)

| Implementation | File | Backing Storage |
|----------------|------|-----------------|
| **VitalsRepositoryHive** | `vitals_repository_hive.dart` | `vitals_box` |
| **SessionRepositoryHive** | `session_repository_hive.dart` | `sessions_box` |
| **SettingsRepositoryHive** | `settings_repository_hive.dart` | `settings_box` |
| **AuditRepositoryHive** | `audit_repository_hive.dart` | `audit_box` |
| **EmergencyRepositoryHive** | `emergency_repository_hive.dart` | `emergency_box` |
| **HomeAutomationRepositoryHive** | `home_automation_repository_hive.dart` | `rooms_box`, `devices_box` |
| **UserProfileRepositoryHive** | `user_profile_repository_hive.dart` | `user_profile_box` |

### 5.3 Feature Repositories

#### Chat Repositories (`lib/chat/repositories/`)

| Repository | File | Purpose |
|------------|------|---------|
| **ChatRepository** | `chat_repository.dart` | Chat interface |
| **ChatRepositoryHive** | `chat_repository_hive.dart` | Hive-backed chat storage |

#### Health Repositories (`lib/health/repositories/`)

| Repository | File | Purpose |
|------------|------|---------|
| **HealthDataRepositoryHive** | `health_data_repository_hive.dart` | Health readings storage |

#### Geofencing Repositories (`lib/geofencing/repositories/`)

| Repository | File | Purpose |
|------------|------|---------|
| **SafeZoneRepository** | `safe_zone_repository.dart` | Safe zone storage |

#### Relationship Repositories (`lib/relationships/repositories/`)

| Repository | File | Purpose |
|------------|------|---------|
| **RelationshipRepository** | `relationship_repository.dart` | Relationship interface |
| **RelationshipRepositoryHive** | `relationship_repository_hive.dart` | Hive-backed relationships |

---

## 6. Persistence Layer (Hive)

### 6.1 HiveService (`lib/persistence/hive_service.dart`)

Central Hive initialization and management:

```dart
class HiveService {
  /// Initialize Hive with encryption
  Future<void> initialize() async {
    await Hive.initFlutter();
    
    // Register all type adapters
    await _registerAdapters();
    
    // Generate/load encryption key
    final encryptionKey = await _getOrCreateEncryptionKey();
    
    // Open all boxes with encryption
    await _openBoxes(encryptionKey);
  }
}
```

### 6.2 Hive Type Adapters (`lib/persistence/adapters/`)

| Adapter | File | TypeId | Model |
|---------|------|--------|-------|
| RoomAdapter | `room_adapter.dart` | 0 | RoomModel |
| DeviceAdapter | `device_adapter.dart` | 1 | DeviceModel |
| PendingOpAdapter | `pending_op_adapter.dart` | 2 | PendingOp |
| VitalsAdapter | `vitals_adapter.dart` | 3 | VitalsModel |
| SessionAdapter | `session_adapter.dart` | 4 | SessionModel |
| UserProfileAdapter | `user_profile_adapter.dart` | 5 | UserProfileModel |
| FailedOpAdapter | `failed_op_adapter.dart` | 6 | FailedOpModel |
| AuditLogAdapter | `audit_log_adapter.dart` | 7 | AuditLogRecord |
| SettingsAdapter | `settings_adapter.dart` | 8 | SettingsModel |
| AssetsCacheAdapter | `assets_cache_adapter.dart` | 9 | AssetsCacheEntry |
| UserBaseAdapter | `user_base_adapter.dart` | 10 | UserBaseModel |
| CaregiverUserAdapter | `caregiver_user_adapter.dart` | 11 | CaregiverUserModel |
| CaregiverDetailsAdapter | `caregiver_details_adapter.dart` | 12 | CaregiverDetailsModel |
| PatientUserAdapter | `patient_user_adapter.dart` | 13 | PatientUserModel |
| PatientDetailsAdapter | `patient_details_adapter.dart` | 14 | PatientDetailsModel |
| DoctorUserAdapter | `doctor_user_adapter.dart` | 15 | DoctorUserModel |
| DoctorDetailsAdapter | `doctor_details_adapter.dart` | 16 | DoctorDetailsModel |
| DoctorRelationshipAdapter | `doctor_relationship_adapter.dart` | 17 | DoctorRelationshipModel |
| RelationshipAdapter | `relationship_adapter.dart` | 18 | RelationshipModel |
| ChatAdapter | `chat_adapter.dart` | 19-20 | ChatThread, ChatMessage |
| StoredHealthReadingAdapter | `stored_health_reading_adapter.dart` | 21 | StoredHealthReading |
| SafeZoneAdapter | `safe_zone_adapter.dart` | 22 | SafeZoneModel |

### 6.3 Hive Boxes (Box Registry)

| Box Name | Purpose | Encrypted |
|----------|---------|-----------|
| `rooms_box` | Smart home rooms | ✅ |
| `devices_box` | Smart devices | ✅ |
| `vitals_box` | Health vitals | ✅ |
| `sessions_box` | User sessions | ✅ |
| `settings_box` | App settings | ✅ |
| `audit_box` | Audit logs | ✅ |
| `pending_ops_box` | Pending sync operations | ✅ |
| `failed_ops_box` | Failed operations | ✅ |
| `user_profile_box` | User profiles | ✅ |
| `relationships_box` | Patient-caregiver relationships | ✅ |
| `chat_threads_box` | Chat threads | ✅ |
| `chat_messages_box` | Chat messages | ✅ |
| `health_readings_box` | Health data readings | ✅ |
| `safe_zones_box` | Geofence safe zones | ✅ |
| `assets_cache_box` | Asset caching | ❌ |
| `meta_box` | Metadata/migrations | ❌ |

### 6.4 Persistence Utilities

| Component | File | Purpose |
|-----------|------|---------|
| **BoxAccessor** | `wrappers/box_accessor.dart` | Type-safe box access |
| **BoxRegistry** | `box_registry.dart` | Box name constants |
| **EncryptionPolicy** | `encryption_policy.dart` | Encryption configuration |
| **TypeIds** | `type_ids.dart` | Type adapter ID constants |
| **CacheInvalidator** | `cache/cache_invalidator.dart` | Cache management |
| **StorageMonitor** | `monitoring/storage_monitor.dart` | Storage health monitoring |
| **DataExportService** | `backups/data_export_service.dart` | Data export/import |

### 6.5 Persistence Guardrails (`lib/persistence/guardrails/`)

| Component | File | Purpose |
|-----------|------|---------|
| **ProductionGuardrails** | `production_guardrails.dart` | Prevents accidental data deletion |
| **AdapterCollisionGuard** | `adapter_collision_guard.dart` | Prevents TypeId conflicts |

---

## 7. Firebase Integration

### 7.1 Firebase Services (`lib/firebase/`)

| Service | File | Purpose |
|---------|------|---------|
| **FirebaseInitializer** | `firebase_initializer.dart` | Firebase app initialization |
| **AuthService** | `auth/auth_service.dart` | Firebase Authentication |
| **FirestoreService** | `firestore/firestore_service.dart` | Firestore abstraction |
| **StorageService** | `storage/storage_service.dart` | Firebase Storage |
| **FirebaseOptions** | `firebase_options.dart` | Platform-specific config |

### 7.2 Auth Providers (`lib/firebase/auth/`)

| Provider | File | Purpose |
|----------|------|---------|
| **PhoneAuthProvider** | `phone_auth_provider.dart` | Phone/OTP authentication |
| **GoogleAuthProvider** | `google_auth_provider.dart` | Google Sign-In |
| **AppleAuthProvider** | `apple_auth_provider.dart` | Apple Sign-In |

### 7.3 Firestore Mirroring Services

| Service | File | Purpose |
|---------|------|---------|
| **ChatFirestoreService** | `chat/services/chat_firestore_service.dart` | Chat sync to Firestore |
| **HealthFirestoreService** | `health/services/health_firestore_service.dart` | Health data sync |
| **RelationshipFirestoreService** | `relationships/services/relationship_firestore_service.dart` | Relationship sync |
| **OnboardingFirestoreService** | `onboarding/services/onboarding_firestore_service.dart` | User profile sync |
| **DoctorRelationshipFirestoreService** | `relationships/services/doctor_relationship_firestore_service.dart` | Doctor links sync |

### 7.4 Firebase Data Flow

```
┌─────────────────┐    Save     ┌─────────────────┐
│   UI Action     │ ─────────▶ │  Hive (Local)   │
└─────────────────┘            └─────────────────┘
                                        │
                                        │ Non-blocking
                                        │ fire-and-forget
                                        ▼
                               ┌─────────────────┐
                               │   Firestore     │
                               │   (Cloud)       │
                               └─────────────────┘
```

**Key Rules:**
1. Hive write is synchronous and immediate
2. Firestore write is async and non-blocking
3. Firestore errors NEVER propagate to UI
4. Failed Firestore ops queued for retry

---

## 8. Sync Engine

### 8.1 Sync Engine Components (`lib/sync/`)

| Component | File | Purpose |
|-----------|------|---------|
| **SyncEngine** | `sync_engine.dart` | FIFO operation processor |
| **ApiClient** | `api_client.dart` | HTTP client for backend |
| **PendingQueueService** | `pending_queue_service.dart` | Pending operations queue |
| **OpRouter** | `op_router.dart` | Routes operations to handlers |
| **ProcessingLock** | `processing_lock.dart` | Single-processor guarantee |
| **BackoffPolicy** | `backoff_policy.dart` | Exponential backoff for retries |
| **CircuitBreaker** | `circuit_breaker.dart` | API protection |
| **Reconciler** | `reconciler.dart` | Conflict resolution |
| **OptimisticStore** | `optimistic_store.dart` | Optimistic updates |
| **BatchCoalescer** | `batch_coalescer.dart` | Batch optimization |
| **RealtimeService** | `realtime_service.dart` | WebSocket fallback |
| **ConflictResolver** | `conflict_resolver.dart` | Merge strategies |
| **FailureClassifier** | `failure_classifier.dart` | Error categorization |

### 8.2 Sync Flow

```
┌─────────────────┐
│  User Action    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐     Save      ┌─────────────────┐
│  Create         │ ────────────▶ │  Hive           │
│  PendingOp      │               │  (Immediate)    │
└────────┬────────┘               └─────────────────┘
         │
         ▼
┌─────────────────┐
│  PendingQueue   │
│  Service        │
└────────┬────────┘
         │ FIFO
         ▼
┌─────────────────┐    Check     ┌─────────────────┐
│  SyncEngine     │ ───────────▶ │  CircuitBreaker │
│  (Process)      │              │  (Protection)   │
└────────┬────────┘              └─────────────────┘
         │
         ▼
┌─────────────────┐
│  ApiClient      │ ────────────▶ Backend API
└────────┬────────┘
         │
    Success│Failure
         │
    ┌────┴────┐
    │         │
    ▼         ▼
┌────────┐ ┌────────┐
│ Remove │ │ Retry  │
│ from   │ │ with   │
│ Queue  │ │ Backoff│
└────────┘ └────────┘
```

---

## 9. Feature Modules

### 9.1 Health Module (`lib/health/`)

```
lib/health/
├── health.dart              # Barrel export
├── models/
│   └── stored_health_reading.dart
├── providers/
│   ├── health_extraction_provider.dart
│   ├── health_persistence_provider.dart
│   └── health_sync_providers.dart
├── repositories/
│   └── health_data_repository_hive.dart
└── services/
    ├── health_data_persistence_service.dart
    ├── health_firestore_service.dart
    ├── patient_health_extraction_service.dart
    └── patient_vitals_ingestion_service.dart
```

### 9.2 Chat Module (`lib/chat/`)

```
lib/chat/
├── chat.dart                # Barrel export
├── models/
│   ├── chat_thread_model.dart
│   └── chat_message_model.dart
├── providers/
│   ├── chat_provider.dart
│   └── doctor_chat_provider.dart
├── repositories/
│   ├── chat_repository.dart
│   └── chat_repository_hive.dart
├── screens/
│   └── ... (UI screens)
└── services/
    ├── chat_service.dart
    ├── chat_firestore_service.dart
    └── doctor_chat_service.dart
```

### 9.3 Geofencing Module (`lib/geofencing/`)

```
lib/geofencing/
├── geofencing.dart          # Barrel export
├── adapters/
│   └── safe_zone_adapter.dart
├── models/
│   └── safe_zone_model.dart
├── providers/
│   └── safe_zone_data_provider.dart
├── repositories/
│   └── safe_zone_repository.dart
├── services/
│   ├── geofencing_service.dart
│   ├── geofence_alert_service.dart
│   └── geocoding_service.dart
└── widgets/
    └── safe_zone_map_widget.dart
```

### 9.4 Stability Score Module (`lib/stability_score/`)

```
lib/stability_score/
├── stability_score.dart     # Barrel export
├── models/
│   ├── subsystem_signals.dart
│   ├── personal_baseline.dart
│   └── stability_score_result.dart
├── providers/
│   └── stability_score_provider.dart
├── services/
│   ├── stability_score_service.dart
│   ├── baseline_persistence_service.dart
│   ├── cognitive_signal_collector.dart
│   └── sleep_trend_analyzer.dart
└── widgets/
    ├── stability_gauge_widget.dart
    └── hss_badge.dart
```

### 9.5 ML Module (`lib/ml/`)

```
lib/ml/
├── ml.dart                  # Barrel export
├── config/
│   └── arrhythmia_config.dart
├── fall_detection/
│   └── ... (TFLite models)
├── models/
│   ├── arrhythmia_request.dart
│   ├── arrhythmia_response.dart
│   └── arrhythmia_analysis_state.dart
├── providers/
│   └── arrhythmia_provider.dart
└── services/
    ├── arrhythmia_analysis_service.dart
    └── arrhythmia_inference_client.dart
```

### 9.6 Relationships Module (`lib/relationships/`)

```
lib/relationships/
├── relationships.dart       # Barrel export
├── models/
│   ├── relationship_model.dart
│   └── doctor_relationship_model.dart
├── repositories/
│   ├── relationship_repository.dart
│   └── relationship_repository_hive.dart
└── services/
    ├── relationship_service.dart
    ├── relationship_firestore_service.dart
    ├── doctor_relationship_service.dart
    └── doctor_relationship_firestore_service.dart
```

### 9.7 Home Automation Module (`lib/home automation/`)

```
lib/home automation/
└── src/
    ├── automation/          # Automation rules
    ├── core/               # Core utilities
    ├── data/
    │   ├── hive_adapters/  # Type adapters
    │   └── models/         # Data models
    ├── logic/
    │   └── providers/      # Riverpod providers
    ├── network/            # Network layer
    ├── security/           # Security utilities
    ├── services/           # API services
    └── ui/                 # UI components
```

---

## 10. Data Models

### 10.1 Core Models (`lib/models/`)

| Model | File | Purpose |
|-------|------|---------|
| **VitalsModel** | `vitals_model.dart` | Health vitals (HR, BP, SpO2, etc.) |
| **SessionModel** | `session_model.dart` | User session data |
| **SettingsModel** | `settings_model.dart` | App settings |
| **UserProfileModel** | `user_profile_model.dart` | User profile |
| **PatientModel** | `patient_model.dart` | Patient information |
| **GuardianModel** | `guardian_model.dart` | Guardian/caregiver info |
| **MedicationModel** | `medication_model.dart` | Medication entries |
| **RoomModel** | `room_model.dart` | Smart home rooms |
| **DeviceModel** | `device_model.dart` | Smart devices |
| **EmergencyContactModel** | `emergency_contact_model.dart` | Emergency contacts |
| **HealthThresholdModel** | `health_threshold_model.dart` | Health alert thresholds |
| **PendingOp** | `pending_op.dart` | Pending sync operation |
| **FailedOpModel** | `failed_op_model.dart` | Failed operation |
| **SyncFailure** | `sync_failure.dart` | Sync failure record |
| **AuditLogRecord** | `audit_log_record.dart` | Audit log entry |

### 10.2 Onboarding Models (`lib/onboarding/models/`)

| Model | File | Purpose |
|-------|------|---------|
| **UserBaseModel** | `user_base_model.dart` | Base user model |
| **CaregiverUserModel** | `caregiver_user_model.dart` | Caregiver profile |
| **CaregiverDetailsModel** | `caregiver_details_model.dart` | Caregiver details |
| **PatientUserModel** | `patient_user_model.dart` | Patient profile |
| **PatientDetailsModel** | `patient_details_model.dart` | Patient details |
| **DoctorUserModel** | `doctor_user_model.dart` | Doctor profile |
| **DoctorDetailsModel** | `doctor_details_model.dart` | Doctor details |

---

## 11. API Keys & Configuration

### 11.1 Required API Keys

| API | Environment Variable | Location | Required |
|-----|---------------------|----------|----------|
| **OpenAI** | `OPENAI_API_KEY` | `--dart-define` | ✅ For AI chat |
| **Firebase** | (auto-configured) | `firebase_options.dart` | ✅ Core |
| **Google Maps** | Manual | `AndroidManifest.xml` | ✅ Geofencing |
| **OpenWeatherMap** | Hardcoded | `api_keys.dart` | ✅ Weather |
| **OpenCage** | Hardcoded | `api_keys.dart` | ✅ Geocoding |
| **TheNewsAPI** | Hardcoded | `news_service.dart` | ✅ News |

### 11.2 Configuration Files

| File | Purpose |
|------|---------|
| `lib/firebase/firebase_options.dart` | Firebase platform config |
| `android/app/google-services.json` | Android Firebase config |
| `ios/Runner/GoogleService-Info.plist` | iOS Firebase config |
| `android/app/src/main/AndroidManifest.xml` | Android app manifest |

### 11.3 Run Commands

```bash
# Development run with API keys
flutter run \
  --dart-define=OPENAI_API_KEY=sk-your-key-here

# Production build
flutter build ios \
  --dart-define=OPENAI_API_KEY=sk-your-key-here \
  --release
```

---

## 12. Security Architecture

### 12.1 Encryption

- **Hive Encryption:** AES-256 with device-bound key
- **Key Storage:** iOS Keychain / Android Keystore
- **Key Rotation:** Supported via `HiveService.rotateKey()`

### 12.2 Authentication Flow

```
┌─────────────────┐     OTP      ┌─────────────────┐
│   Phone Input   │ ──────────▶ │  Firebase Auth  │
└─────────────────┘              │  (Phone)        │
                                 └────────┬────────┘
                                          │
                                          ▼
                                 ┌─────────────────┐
                                 │   ID Token      │
                                 │   Generation    │
                                 └────────┬────────┘
                                          │
                    ┌─────────────────────┼─────────────────────┐
                    ▼                     ▼                     ▼
           ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
           │  Session        │   │  Firestore      │   │  FCM Token      │
           │  Hive Storage   │   │  Rules Check    │   │  Registration   │
           └─────────────────┘   └─────────────────┘   └─────────────────┘
```

### 12.3 Data Protection

| Feature | Implementation |
|---------|----------------|
| **Audit Logging** | Every data access logged with actor, action, timestamp |
| **Soft Delete** | Data marked deleted, not immediately removed |
| **Secure Erase** | Multi-pass overwrite for permanent deletion |
| **GDPR Export** | Full data export via `DataExportService` |
| **Production Guards** | Prevents accidental deletion in production |

### 12.4 Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only access their own data
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }
    
    // Patient health readings
    match /patients/{patientId}/health_readings/{readingId} {
      allow read: if isPatientOrCaregiver(patientId);
      allow write: if request.auth.uid == patientId;
    }
    
    // Relationships
    match /relationships/{relationshipId} {
      allow read, write: if isParticipant(relationshipId);
    }
  }
}
```

---

## Appendix A: Service Initialization Order

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // 2. Hive (encrypted local storage)
  await HiveService().initialize();
  
  // 3. FCM (push notifications)
  await FCMService.instance.initialize();
  
  // 4. Run app with Riverpod
  runApp(
    ProviderScope(
      child: GuardianAngelApp(),
    ),
  );
}
```

---

## Appendix B: Provider Dependency Graph

```
telemetryServiceProvider (ROOT)
    ├── auditLogServiceProvider
    ├── syncFailureServiceProvider
    ├── secureEraseServiceProvider
    │   └── secureEraseHardenedProvider
    └── productionGuardrailsProvider

boxAccessorProvider
    ├── vitalsRepositoryProvider
    │   └── vitalsProvider
    ├── sessionRepositoryProvider
    │   └── sessionProvider
    ├── settingsRepositoryProvider
    │   └── settingsProvider
    ├── auditRepositoryProvider
    │   └── auditLogProvider
    ├── emergencyRepositoryProvider
    │   └── emergencyStateProvider
    └── userProfileRepositoryProvider
        └── userProfileProvider

homeAutomationRepositoryProvider
    ├── automationStateProvider
    ├── roomListProvider
    └── deviceListProvider
```

---

## Appendix C: Quick Reference

### Adding a New Service

1. Create service class in `lib/services/`
2. Add provider in `lib/providers/service_providers.dart`
3. Inject dependencies via `ref.watch()`
4. Use in widgets via `ref.read()` or `ref.watch()`

### Adding a New Hive Model

1. Create model class with `@HiveType()` annotation
2. Create adapter in `lib/persistence/adapters/`
3. Register TypeId in `lib/persistence/type_ids.dart`
4. Register adapter in `HiveService._registerAdapters()`
5. Add box to `BoxRegistry`

### Adding a New Repository

1. Create interface in `lib/repositories/`
2. Create Hive implementation in `lib/repositories/impl/`
3. Add provider in `lib/providers/domain_providers.dart`
4. Add StreamProvider for reactive access

---

**Document generated:** January 10, 2026  
**Guardian Angel FYP — Complete Local Backend Reference**
