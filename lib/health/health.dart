/// Health Module — Extraction, Persistence & Cloud Sync Public API
///
/// This module provides:
/// 1. READ-ONLY health data extraction from OS health stores (STEP 1)
/// 2. LOCAL-FIRST persistence to encrypted Hive storage (STEP 2)
/// 3. FIRE-AND-FORGET Firestore mirror for cloud backup (STEP 3)
///
/// ## Supported Data Types
/// - Heart Rate (bpm)
/// - Blood Oxygen / SpO₂ (%)
/// - Sleep Sessions (with stages where available)
/// - Heart Rate Variability (SDNN)
///
/// ## Supported Platforms
/// - iOS: Apple HealthKit (Apple Watch, manual entries)
/// - Android: Health Connect (Samsung, Xiaomi, Fitbit, etc.)
///
/// ## Quick Start — Extraction Only
/// ```dart
/// import 'package:guardian_angel_fyp/health/health.dart';
///
/// // 1. Check availability
/// final availability = await PatientHealthExtractionService.instance.checkAvailability();
///
/// // 2. Request permissions (shows OS dialog)
/// final permissions = await PatientHealthExtractionService.instance.requestPermissions();
///
/// // 3. Fetch data (in-memory only)
/// if (permissions.hasAnyPermission) {
///   final result = await PatientHealthExtractionService.instance.fetchRecentVitals(
///     patientUid: 'patient_123',
///     windowMinutes: 60,
///   );
///
///   if (result.success && result.hasData) {
///     final snapshot = result.data!;
///     print('Heart Rate: ${snapshot.latestHeartRate?.bpm} bpm');
///     print('SpO2: ${snapshot.latestOxygen?.percentage}%');
///   }
/// }
/// ```
///
/// ## Quick Start — Extract + Persist + Sync (Recommended)
/// ```dart
/// import 'package:guardian_angel_fyp/health/health.dart';
///
/// // Using Riverpod providers
/// final result = await ref.read(fetchAndPersistProvider(
///   FetchPersistParams(patientUid: 'patient_123'),
/// ).future);
///
/// if (result.success) {
///   print('Saved ${result.summary.totalPersisted} readings');
///   // Note: Firestore sync happens automatically in background (fire-and-forget)
/// }
///
/// // Later: Read from local storage (offline-first)
/// final snapshot = await ref.read(localVitalsSnapshotProvider('patient_123').future);
/// if (snapshot.success && snapshot.data != null) {
///   print('Cached HR: ${snapshot.data!.heartRateBpm} bpm');
/// }
///
/// // Check sync status (optional)
/// final syncStatus = await ref.read(healthSyncStatusProvider.future);
/// print('Synced: ${syncStatus.syncedCount}/${syncStatus.totalLocal}');
/// ```
///
/// ## Architecture Overview
/// ```
/// UI → Provider → PersistenceService → Repository → BoxAccessor → Hive (encrypted)
///                        ↓                                ↓
///              ExtractionService                HealthFirestoreService
///                        ↓                                ↓
///               OS Health Store              Firestore (fire-and-forget)
///                (read-only)                    (non-blocking mirror)
/// ```
///
/// ## Sync Principles
/// - Hive is ALWAYS the source of truth
/// - Firestore sync is fire-and-forget (errors logged, never thrown)
/// - UI NEVER blocks on Firestore operations
/// - Sync failures do NOT affect local operations
///
/// ## Scope Boundaries
/// ✅ Included:
/// - Platform detection & permission handling
/// - Data extraction from OS health stores
/// - Normalization and deduplication
/// - Local Hive persistence (encrypted)
/// - TTL/retention pruning
/// - Offline-first UI support
/// - Firestore mirror (non-blocking)
/// - GDPR deletion (local + cloud)
///
/// ❌ NOT Included (separate modules):
/// - Background workers (STEP 4)
/// - Real-time streaming
/// - BLE/direct device communication
/// - Raw ECG/PPG waveforms
/// - ML analysis
/// - Alerts and notifications
library;

// ═══════════════════════════════════════════════════════════════════════════
// EXTRACTION LAYER (STEP 1) — Read-only from OS
// ═══════════════════════════════════════════════════════════════════════════

// Models — Normalized in-memory objects
export 'models/normalized_health_data.dart';
export 'models/health_extraction_result.dart';

// Services — Extraction from OS health stores
export 'services/patient_health_extraction_service.dart';

// Providers — Riverpod DI for extraction
export 'providers/health_extraction_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════
// PERSISTENCE LAYER (STEP 2) — Local Hive storage
// ═══════════════════════════════════════════════════════════════════════════

// Models — Hive-persisted storage model
export 'models/stored_health_reading.dart';

// Repositories — Hive CRUD operations
export 'repositories/health_data_repository.dart';
export 'repositories/health_data_repository_hive.dart';

// Services — Extract + Persist orchestration
export 'services/health_data_persistence_service.dart';

// Providers — Riverpod DI for persistence
export 'providers/health_persistence_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════
// FIRESTORE SYNC LAYER (STEP 3) — Cloud mirror (fire-and-forget)
// ═══════════════════════════════════════════════════════════════════════════

// Services — Non-blocking Firestore mirror
export 'services/health_firestore_service.dart';

// Providers — Sync status and manual controls
export 'providers/health_sync_providers.dart';
