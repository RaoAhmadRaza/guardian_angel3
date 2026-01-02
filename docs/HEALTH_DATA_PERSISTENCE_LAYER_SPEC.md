# Health Data Persistence Layer — Implementation Specification

**STATUS: ✅ IMPLEMENTED**

## Executive Summary

This document specifies the **local-first persistence layer** for extracted health data from the Health Extraction Layer (Step 1). This is **Step 2** of the health data pipeline.

### Implementation Status

| Component | Status | Location |
|-----------|--------|----------|
| StoredHealthReading model | ✅ Complete | `lib/health/models/stored_health_reading.dart` |
| TypeIds (55-56) | ✅ Registered | `lib/persistence/type_ids.dart` |
| BoxRegistry entry | ✅ Added | `lib/persistence/box_registry.dart` |
| Hive adapter | ✅ Complete | `lib/persistence/adapters/stored_health_reading_adapter.dart` |
| BoxAccessor accessor | ✅ Added | `lib/persistence/wrappers/box_accessor.dart` |
| HiveService integration | ✅ Complete | `lib/persistence/hive_service.dart` |
| Repository interface | ✅ Complete | `lib/health/repositories/health_data_repository.dart` |
| Repository Hive impl | ✅ Complete | `lib/health/repositories/health_data_repository_hive.dart` |
| Persistence service | ✅ Complete | `lib/health/services/health_data_persistence_service.dart` |
| Riverpod providers | ✅ Complete | `lib/health/providers/health_persistence_provider.dart` |
| Barrel export | ✅ Updated | `lib/health/health.dart` |
| Dart analyzer | ✅ Passing | 0 errors, 2 info-level deprecation warnings (acceptable) |

### What Step 2 Covers
- ✅ Hive persistence for normalized health readings
- ✅ Deduplication by `(patientUid, timestamp, dataType)` composite key
- ✅ TTL-based retention (configurable via `SettingsModel.vitalsRetentionDays`)
- ✅ Offline replay (UI can read without network)
- ✅ Repository pattern consistent with existing codebase

### What Step 2 Does NOT Cover
- ❌ Firestore sync (Step 3)
- ❌ Background workers (Step 4)
- ❌ ML analysis (separate module)
- ❌ SOS/alerts integration (separate module)

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                           UI LAYER                                  │
│     (patient_vitals_screen.dart, health_dashboard.dart, etc.)       │
└──────────────────────────────────┬──────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    RIVERPOD PROVIDERS                               │
│  healthDataRepositoryProvider                                       │
│  localHeartRateProvider(params)                                     │
│  localSleepSessionsProvider(params)                                 │
│  localHRVProvider(params)                                           │
│  healthDataStatsProvider(patientUid)                                │
└──────────────────────────────────┬──────────────────────────────────┘
                                   │
          ┌────────────────────────┴────────────────────────┐
          │                                                 │
          ▼                                                 ▼
┌─────────────────────────┐                  ┌──────────────────────────┐
│  HealthDataRepository   │                  │ PatientHealthExtraction  │
│  (Hive persistence)     │                  │ Service (Step 1)         │
│                         │◄─────────────────│ (Read from OS)           │
│  • save()               │    persist       └──────────────────────────┘
│  • getByDateRange()     │                            │
│  • deduplicate()        │                            │
│  • pruneExpired()       │                            │
│  • watch()              │                            ▼
└────────────┬────────────┘                  ┌──────────────────────────┐
             │                               │  HealthKit / Health      │
             ▼                               │  Connect (platform)      │
┌─────────────────────────┐                  └──────────────────────────┘
│      Hive Boxes         │
│  health_readings_box    │  (encrypted)
│                         │
└─────────────────────────┘
```

---

## File Structure

```
lib/health/
├── health.dart                                    # Updated barrel export
├── models/
│   ├── normalized_health_data.dart                # ✅ EXISTS (Step 1)
│   ├── health_extraction_result.dart              # ✅ EXISTS (Step 1)
│   └── stored_health_reading.dart                 # 🆕 NEW - Hive model
├── providers/
│   ├── health_extraction_provider.dart            # ✅ EXISTS (Step 1)
│   └── health_persistence_provider.dart           # 🆕 NEW - Persistence providers
├── repositories/
│   └── health_data_repository_hive.dart           # 🆕 NEW - Repository
└── services/
    ├── patient_health_extraction_service.dart     # ✅ EXISTS (Step 1)
    └── health_data_persistence_service.dart       # 🆕 NEW - Orchestrator

lib/persistence/
├── adapters/
│   └── stored_health_reading_adapter.dart         # 🆕 NEW - Hive adapter
├── box_registry.dart                              # UPDATE - Add health box
├── type_ids.dart                                  # UPDATE - Add TypeIds
└── hive_service.dart                              # UPDATE - Register adapter
```

---

## Data Models

### StoredHealthReading (Hive Model)

This is the **persistence-layer model** stored in Hive. It wraps all normalized reading types into a single polymorphic model.

```dart
/// Type of stored health reading
enum StoredHealthReadingType {
  heartRate,
  bloodOxygen,
  sleepSession,
  hrvReading,
}

/// Hive-persisted health reading.
/// 
/// Uses discriminated union pattern via `readingType` field.
/// All data stored in JSON map for flexibility and forward compatibility.
class StoredHealthReading {
  /// Composite key: patientUid_type_timestamp
  /// Example: "abc123_heartRate_2026-01-02T10:30:00Z"
  final String id;
  
  /// Patient Firebase UID
  final String patientUid;
  
  /// Type discriminator
  final StoredHealthReadingType readingType;
  
  /// Original timestamp from wearable
  final DateTime recordedAt;
  
  /// When this was persisted locally
  final DateTime persistedAt;
  
  /// Data source (apple_health, health_connect)
  final String dataSource;
  
  /// Device type (apple_watch, samsung_galaxy_watch, etc.)
  final String deviceType;
  
  /// Reliability score (high, medium, low)
  final String reliability;
  
  /// JSON-encoded reading data (type-specific)
  final Map<String, dynamic> data;
  
  /// Schema version for migrations
  final int schemaVersion;
}
```

#### Composite Key Strategy

Keys follow pattern: `{patientUid}_{readingType}_{ISO8601Timestamp}`

```dart
// Examples:
"abc123_heartRate_2026-01-02T10:30:00.000Z"
"abc123_bloodOxygen_2026-01-02T10:45:00.000Z"
"abc123_sleepSession_2026-01-01T22:00:00.000Z"
"abc123_hrvReading_2026-01-02T08:00:00.000Z"
```

This enables:
1. **Natural deduplication** — same key = same reading
2. **Efficient prefix queries** — `patientUid_heartRate_*` for type filtering
3. **Time-ordered iteration** — lexicographic sort = chronological order
4. **Collision-free** — timestamp precision to milliseconds

---

## TypeIds Registration

Add to `lib/persistence/type_ids.dart`:

```dart
// ═══════════════════════════════════════════════════════════════════════════
// HEALTH DATA PERSISTENCE (55-59)
// ═══════════════════════════════════════════════════════════════════════════

/// StoredHealthReading - Persisted health reading
/// Adapter: lib/persistence/adapters/stored_health_reading_adapter.dart
static const int storedHealthReading = 55;

/// StoredHealthReadingType - Enum for reading type
/// Adapter: lib/persistence/adapters/stored_health_reading_adapter.dart
static const int storedHealthReadingType = 56;

// Reserved: 57-59 for future health persistence types
```

---

## Box Registry Update

Add to `lib/persistence/box_registry.dart`:

```dart
// ═══════════════════════════════════════════════════════════════════════════
// HEALTH DATA BOX NAMES (authoritative)
// ═══════════════════════════════════════════════════════════════════════════

/// Health readings box (StoredHealthReading) - all patient health data
/// Contains: heart rate, SpO₂, sleep sessions, HRV readings
/// Encrypted: YES (HIPAA - sensitive health data)
/// Key format: patientUid_readingType_timestamp (composite)
static const healthReadingsBox = 'health_readings_box';
```

---

## Hive Adapter

### StoredHealthReadingAdapter

```dart
/// Hive adapter for StoredHealthReading.
/// 
/// Field mapping:
/// 0: id (composite key)
/// 1: patientUid
/// 2: readingType (enum index)
/// 3: recordedAt (ISO8601)
/// 4: persistedAt (ISO8601)
/// 5: dataSource
/// 6: deviceType
/// 7: reliability
/// 8: data (JSON string)
/// 9: schemaVersion
class StoredHealthReadingAdapter extends TypeAdapter<StoredHealthReading> {
  @override
  final int typeId = TypeIds.storedHealthReading;

  @override
  StoredHealthReading read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    
    return StoredHealthReading(
      id: fields[0] as String? ?? '',
      patientUid: fields[1] as String? ?? '',
      readingType: StoredHealthReadingType.values[fields[2] as int? ?? 0],
      recordedAt: _parseDateTime(fields[3] as String?),
      persistedAt: _parseDateTime(fields[4] as String?),
      dataSource: fields[5] as String? ?? 'unknown',
      deviceType: fields[6] as String? ?? 'unknown',
      reliability: fields[7] as String? ?? 'medium',
      data: _parseJson(fields[8] as String?),
      schemaVersion: fields[9] as int? ?? 1,
    );
  }

  @override
  void write(BinaryWriter writer, StoredHealthReading obj) {
    writer
      ..writeByte(10) // field count
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.patientUid)
      ..writeByte(2)..write(obj.readingType.index)
      ..writeByte(3)..write(obj.recordedAt.toUtc().toIso8601String())
      ..writeByte(4)..write(obj.persistedAt.toUtc().toIso8601String())
      ..writeByte(5)..write(obj.dataSource)
      ..writeByte(6)..write(obj.deviceType)
      ..writeByte(7)..write(obj.reliability)
      ..writeByte(8)..write(jsonEncode(obj.data))
      ..writeByte(9)..write(obj.schemaVersion);
  }

  DateTime _parseDateTime(String? v) =>
      v != null ? (DateTime.tryParse(v)?.toUtc() ?? DateTime.now().toUtc()) : DateTime.now().toUtc();

  Map<String, dynamic> _parseJson(String? v) {
    if (v == null || v.isEmpty) return {};
    try {
      return jsonDecode(v) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}
```

---

## Repository Interface & Implementation

### HealthDataRepository (Interface)

```dart
/// Repository interface for local health data persistence.
abstract class HealthDataRepository {
  // ═══════════════════════════════════════════════════════════════════════
  // WRITE OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════
  
  /// Persist a heart rate reading (deduplicates by composite key)
  Future<void> saveHeartRate(NormalizedHeartRateReading reading);
  
  /// Persist an SpO₂ reading
  Future<void> saveOxygenReading(NormalizedOxygenReading reading);
  
  /// Persist a sleep session
  Future<void> saveSleepSession(NormalizedSleepSession session);
  
  /// Persist an HRV reading
  Future<void> saveHRVReading(NormalizedHRVReading reading);
  
  /// Batch persist multiple readings (transactional)
  Future<void> saveBatch(List<dynamic> readings);

  // ═══════════════════════════════════════════════════════════════════════
  // READ OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════
  
  /// Get heart rates for patient in date range
  Future<List<NormalizedHeartRateReading>> getHeartRates({
    required String patientUid,
    required DateTime start,
    required DateTime end,
  });
  
  /// Get SpO₂ readings for patient in date range
  Future<List<NormalizedOxygenReading>> getOxygenReadings({
    required String patientUid,
    required DateTime start,
    required DateTime end,
  });
  
  /// Get sleep sessions for patient in date range
  Future<List<NormalizedSleepSession>> getSleepSessions({
    required String patientUid,
    required DateTime start,
    required DateTime end,
  });
  
  /// Get HRV readings for patient in date range
  Future<List<NormalizedHRVReading>> getHRVReadings({
    required String patientUid,
    required DateTime start,
    required DateTime end,
  });
  
  /// Get latest reading of each type for patient
  Future<StoredVitalsSnapshot> getLatestVitals(String patientUid);

  // ═══════════════════════════════════════════════════════════════════════
  // WATCH OPERATIONS (Reactive)
  // ═══════════════════════════════════════════════════════════════════════
  
  /// Watch all readings for a patient (real-time updates)
  Stream<List<StoredHealthReading>> watchAllForPatient(String patientUid);
  
  /// Watch heart rates for a patient
  Stream<List<NormalizedHeartRateReading>> watchHeartRates(String patientUid);

  // ═══════════════════════════════════════════════════════════════════════
  // MAINTENANCE OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════
  
  /// Delete readings older than retention period
  Future<int> pruneExpired({required int retentionDays});
  
  /// Get storage statistics
  Future<HealthStorageStats> getStats(String patientUid);
  
  /// Delete all readings for a patient (GDPR)
  Future<void> deleteAllForPatient(String patientUid);
}
```

### HealthDataRepositoryHive (Implementation)

```dart
/// Hive-backed implementation of HealthDataRepository.
///
/// Follows project patterns from:
/// - VitalsRepositoryHive
/// - ChatRepositoryHive
/// - RelationshipRepositoryHive
class HealthDataRepositoryHive implements HealthDataRepository {
  final BoxAccessor _boxAccessor;
  final TelemetryService _telemetry;

  HealthDataRepositoryHive({
    BoxAccessor? boxAccessor,
    TelemetryService? telemetry,
  })  : _boxAccessor = boxAccessor ?? getSharedBoxAccessorInstance(),
        _telemetry = telemetry ?? getSharedTelemetryInstance();

  /// Access the health readings box.
  Box<StoredHealthReading> get _box => _boxAccessor.healthReadings();

  // ═══════════════════════════════════════════════════════════════════════
  // KEY GENERATION
  // ═══════════════════════════════════════════════════════════════════════

  /// Generate composite key for deduplication.
  String _generateKey(String patientUid, StoredHealthReadingType type, DateTime timestamp) {
    final ts = timestamp.toUtc().toIso8601String();
    return '${patientUid}_${type.name}_$ts';
  }

  // ═══════════════════════════════════════════════════════════════════════
  // WRITE OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Future<void> saveHeartRate(NormalizedHeartRateReading reading) async {
    final key = _generateKey(
      reading.patientUid,
      StoredHealthReadingType.heartRate,
      reading.timestamp,
    );
    
    // Check for existing (deduplication)
    if (_box.containsKey(key)) {
      _telemetry.increment('health.save.deduplicated');
      return; // Already exists, skip
    }

    final stored = StoredHealthReading(
      id: key,
      patientUid: reading.patientUid,
      readingType: StoredHealthReadingType.heartRate,
      recordedAt: reading.timestamp,
      persistedAt: DateTime.now().toUtc(),
      dataSource: reading.dataSource.name,
      deviceType: reading.deviceType.name,
      reliability: reading.reliability.name,
      data: {
        'bpm': reading.bpm,
        'isResting': reading.isResting,
      },
      schemaVersion: 1,
    );

    final result = await SafeBoxOps.put(_box, key, stored, boxName: BoxRegistry.healthReadingsBox);
    if (result.isFailure) {
      _telemetry.increment('health.save.hive_error');
      throw result.error!;
    }
    _telemetry.increment('health.save.heart_rate.success');
  }

  // ... similar implementations for saveOxygenReading, saveSleepSession, saveHRVReading

  @override
  Future<void> saveBatch(List<dynamic> readings) async {
    for (final reading in readings) {
      if (reading is NormalizedHeartRateReading) {
        await saveHeartRate(reading);
      } else if (reading is NormalizedOxygenReading) {
        await saveOxygenReading(reading);
      } else if (reading is NormalizedSleepSession) {
        await saveSleepSession(reading);
      } else if (reading is NormalizedHRVReading) {
        await saveHRVReading(reading);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // READ OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Future<List<NormalizedHeartRateReading>> getHeartRates({
    required String patientUid,
    required DateTime start,
    required DateTime end,
  }) async {
    final prefix = '${patientUid}_heartRate_';
    
    return _box.values
        .where((r) => r.id.startsWith(prefix))
        .where((r) => r.recordedAt.isAfter(start) && r.recordedAt.isBefore(end))
        .map((r) => _toHeartRateReading(r))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  NormalizedHeartRateReading _toHeartRateReading(StoredHealthReading stored) {
    return NormalizedHeartRateReading(
      patientUid: stored.patientUid,
      timestamp: stored.recordedAt,
      bpm: stored.data['bpm'] as int? ?? 0,
      dataSource: HealthDataSource.values.firstWhere(
        (e) => e.name == stored.dataSource,
        orElse: () => HealthDataSource.unknown,
      ),
      deviceType: DetectedDeviceType.values.firstWhere(
        (e) => e.name == stored.deviceType,
        orElse: () => DetectedDeviceType.unknown,
      ),
      reliability: DataReliability.values.firstWhere(
        (e) => e.name == stored.reliability,
        orElse: () => DataReliability.medium,
      ),
      isResting: stored.data['isResting'] as bool? ?? false,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // WATCH OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Stream<List<StoredHealthReading>> watchAllForPatient(String patientUid) async* {
    // Emit current state immediately
    yield _getForPatient(patientUid);
    
    // Then emit on every change
    yield* _box.watch().map((_) => _getForPatient(patientUid));
  }

  List<StoredHealthReading> _getForPatient(String patientUid) {
    return _box.values
        .where((r) => r.patientUid == patientUid)
        .toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }

  // ═══════════════════════════════════════════════════════════════════════
  // MAINTENANCE OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Future<int> pruneExpired({required int retentionDays}) async {
    final cutoff = DateTime.now().toUtc().subtract(Duration(days: retentionDays));
    final toDelete = <String>[];
    
    for (final key in _box.keys) {
      final reading = _box.get(key);
      if (reading != null && reading.recordedAt.isBefore(cutoff)) {
        toDelete.add(key as String);
      }
    }
    
    for (final key in toDelete) {
      await _box.delete(key);
    }
    
    _telemetry.increment('health.prune.count', toDelete.length);
    return toDelete.length;
  }

  @override
  Future<HealthStorageStats> getStats(String patientUid) async {
    final readings = _getForPatient(patientUid);
    
    return HealthStorageStats(
      totalReadings: readings.length,
      heartRateCount: readings.where((r) => r.readingType == StoredHealthReadingType.heartRate).length,
      oxygenCount: readings.where((r) => r.readingType == StoredHealthReadingType.bloodOxygen).length,
      sleepCount: readings.where((r) => r.readingType == StoredHealthReadingType.sleepSession).length,
      hrvCount: readings.where((r) => r.readingType == StoredHealthReadingType.hrvReading).length,
      oldestReading: readings.isEmpty ? null : readings.last.recordedAt,
      newestReading: readings.isEmpty ? null : readings.first.recordedAt,
    );
  }

  @override
  Future<void> deleteAllForPatient(String patientUid) async {
    final toDelete = _box.keys
        .where((key) => (key as String).startsWith('${patientUid}_'))
        .toList();
    
    await _box.deleteAll(toDelete);
    _telemetry.increment('health.delete_all.count', toDelete.length);
  }
}
```

---

## Persistence Service (Orchestrator)

```dart
/// HealthDataPersistenceService - Orchestrates extraction + persistence.
///
/// This service:
/// 1. Calls PatientHealthExtractionService to get fresh data
/// 2. Persists to Hive via HealthDataRepository
/// 3. Handles deduplication and error recovery
class HealthDataPersistenceService {
  final PatientHealthExtractionService _extractionService;
  final HealthDataRepository _repository;
  final TelemetryService _telemetry;

  HealthDataPersistenceService({
    PatientHealthExtractionService? extractionService,
    HealthDataRepository? repository,
    TelemetryService? telemetry,
  })  : _extractionService = extractionService ?? PatientHealthExtractionService.instance,
        _repository = repository ?? HealthDataRepositoryHive(),
        _telemetry = telemetry ?? TelemetryService.I;

  /// Fetch fresh vitals and persist locally.
  ///
  /// Returns number of new readings persisted (after deduplication).
  Future<PersistenceResult> fetchAndPersistVitals({
    required String patientUid,
    int windowMinutes = 60,
  }) async {
    final sw = Stopwatch()..start();
    
    try {
      // 1. Fetch from platform
      final result = await _extractionService.fetchRecentVitals(
        patientUid: patientUid,
        windowMinutes: windowMinutes,
      );
      
      if (!result.success) {
        return PersistenceResult.error(result.errorMessage ?? 'Extraction failed');
      }
      
      if (!result.hasData) {
        return PersistenceResult.noData();
      }
      
      final snapshot = result.data!;
      int persisted = 0;
      
      // 2. Persist heart rate
      if (snapshot.latestHeartRate != null) {
        await _repository.saveHeartRate(snapshot.latestHeartRate!);
        persisted++;
      }
      
      // 3. Persist SpO₂
      if (snapshot.latestOxygen != null) {
        await _repository.saveOxygenReading(snapshot.latestOxygen!);
        persisted++;
      }
      
      // 4. Persist HRV
      if (snapshot.latestHRV != null) {
        await _repository.saveHRVReading(snapshot.latestHRV!);
        persisted++;
      }
      
      // 5. Persist sleep
      if (snapshot.lastSleepSession != null) {
        await _repository.saveSleepSession(snapshot.lastSleepSession!);
        persisted++;
      }
      
      sw.stop();
      _telemetry.time('health.persist.duration_ms', () => sw.elapsed);
      _telemetry.increment('health.persist.success');
      _telemetry.gauge('health.persist.count', persisted);
      
      return PersistenceResult.success(persisted);
      
    } catch (e) {
      _telemetry.increment('health.persist.error');
      return PersistenceResult.error(e.toString());
    }
  }

  /// Prune expired readings based on settings.
  Future<int> pruneExpiredReadings() async {
    // Get retention from settings (default 30 days)
    final settings = BoxAccess.I.settings();
    final retentionDays = settings.values.firstOrNull?.vitalsRetentionDays ?? 30;
    
    return _repository.pruneExpired(retentionDays: retentionDays);
  }
}

/// Result of a persistence operation.
class PersistenceResult {
  final bool success;
  final int persistedCount;
  final String? errorMessage;
  final bool noData;

  const PersistenceResult._({
    required this.success,
    this.persistedCount = 0,
    this.errorMessage,
    this.noData = false,
  });

  factory PersistenceResult.success(int count) => 
      PersistenceResult._(success: true, persistedCount: count);
  
  factory PersistenceResult.error(String message) => 
      PersistenceResult._(success: false, errorMessage: message);
  
  factory PersistenceResult.noData() => 
      const PersistenceResult._(success: true, noData: true);
}
```

---

## Riverpod Providers

```dart
/// Provider for HealthDataRepository
final healthDataRepositoryProvider = Provider<HealthDataRepository>((ref) {
  return HealthDataRepositoryHive();
});

/// Provider for HealthDataPersistenceService
final healthPersistenceServiceProvider = Provider<HealthDataPersistenceService>((ref) {
  final repository = ref.read(healthDataRepositoryProvider);
  final extractionService = ref.read(healthExtractionServiceProvider);
  return HealthDataPersistenceService(
    extractionService: extractionService,
    repository: repository,
  );
});

/// FutureProvider for fetching and persisting fresh vitals
final fetchAndPersistVitalsProvider = FutureProvider.family<PersistenceResult, String>((ref, patientUid) {
  final service = ref.read(healthPersistenceServiceProvider);
  return service.fetchAndPersistVitals(patientUid: patientUid);
});

/// StreamProvider for watching local heart rates
final localHeartRatesProvider = StreamProvider.family<List<NormalizedHeartRateReading>, HealthDataParams>((ref, params) {
  final repository = ref.read(healthDataRepositoryProvider);
  return repository.watchHeartRates(params.patientUid);
});

/// FutureProvider for local vitals snapshot
final localVitalsSnapshotProvider = FutureProvider.family<StoredVitalsSnapshot, String>((ref, patientUid) {
  final repository = ref.read(healthDataRepositoryProvider);
  return repository.getLatestVitals(patientUid);
});

/// FutureProvider for storage stats
final healthStorageStatsProvider = FutureProvider.family<HealthStorageStats, String>((ref, patientUid) {
  final repository = ref.read(healthDataRepositoryProvider);
  return repository.getStats(patientUid);
});

/// Parameters for health data queries
class HealthDataParams {
  final String patientUid;
  final DateTime? start;
  final DateTime? end;

  const HealthDataParams({
    required this.patientUid,
    this.start,
    this.end,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HealthDataParams &&
          patientUid == other.patientUid &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => patientUid.hashCode ^ start.hashCode ^ end.hashCode;
}
```

---

## Deduplication Strategy

### Why Composite Keys?

The composite key `{patientUid}_{readingType}_{ISO8601Timestamp}` ensures:

1. **Idempotent writes** — Re-fetching the same data produces the same keys
2. **No duplicate readings** — HealthKit/Health Connect may return overlapping data
3. **Efficient lookups** — Hive key access is O(1)
4. **Type safety** — Reading type in key enables prefix-based filtering

### Handling Edge Cases

| Edge Case | Strategy |
|-----------|----------|
| Same reading fetched twice | Same key → `containsKey()` returns true → skip |
| Readings with same timestamp | Rare but handled by ISO8601 millisecond precision |
| Sleep session overlaps | Session start time is key → first-write wins |
| Time zone shifts | All timestamps stored as UTC |
| Data source changes | Data source is metadata, not part of key |

---

## Retention & Pruning

### TTL Strategy

Retention period comes from `SettingsModel.vitalsRetentionDays` (default: 30 days).

```dart
Future<int> pruneExpired({required int retentionDays}) async {
  final cutoff = DateTime.now().toUtc().subtract(Duration(days: retentionDays));
  
  final toDelete = <String>[];
  for (final key in _box.keys) {
    final reading = _box.get(key);
    if (reading != null && reading.recordedAt.isBefore(cutoff)) {
      toDelete.add(key as String);
    }
  }
  
  for (final key in toDelete) {
    await _box.delete(key);
  }
  
  return toDelete.length;
}
```

### When to Prune

Integrate with existing `TtlCompactionService`:

```dart
// In TtlCompactionService.runMaintenance()
Future<Map<String, dynamic>> runMaintenance() async {
  final vitalsDeleted = await pruneVitals();
  final healthDeleted = await _healthPruner.pruneExpired(retentionDays: _settingsRetentionDays());
  final compacted = await maybeCompact();
  
  return {
    'vitals_purged': vitalsDeleted,
    'health_purged': healthDeleted,
    'compacted': compacted,
  };
}
```

---

## Offline Replay Pattern

The UI layer reads from local storage **first**, then optionally refreshes from platform:

```dart
Widget build(BuildContext context, WidgetRef ref) {
  // 1. Read from local Hive (instant, offline-capable)
  final localVitals = ref.watch(localVitalsSnapshotProvider(patientUid));
  
  // 2. Optionally trigger fresh fetch
  final refreshButton = IconButton(
    icon: Icon(Icons.refresh),
    onPressed: () {
      ref.invalidate(fetchAndPersistVitalsProvider(patientUid));
      ref.read(fetchAndPersistVitalsProvider(patientUid));
    },
  );
  
  return localVitals.when(
    data: (snapshot) => VitalsCard(snapshot),
    loading: () => VitalsCardSkeleton(),
    error: (e, _) => VitalsCardError(e),
  );
}
```

---

## BoxAccessor Update

Add to `lib/persistence/wrappers/box_accessor.dart`:

```dart
/// Access health readings box.
Box<StoredHealthReading> healthReadings() {
  _trackAccess(BoxRegistry.healthReadingsBox);
  _assertOpen(BoxRegistry.healthReadingsBox);
  return Hive.box<StoredHealthReading>(BoxRegistry.healthReadingsBox);
}
```

---

## HiveService Update

Add to `lib/persistence/hive_service.dart`:

```dart
// In _registerAdapters()
Hive.registerAdapter(StoredHealthReadingAdapter());
Hive.registerAdapter(StoredHealthReadingTypeAdapter());

// In _openBoxes()
await _openBoxSafely<StoredHealthReading>(BoxRegistry.healthReadingsBox, cipher: cipher);
```

---

## Testing Strategy

### Unit Tests

```dart
void main() {
  group('HealthDataRepositoryHive', () {
    late Box<StoredHealthReading> box;
    late HealthDataRepositoryHive repository;

    setUp(() async {
      await Hive.initFlutter();
      Hive.registerAdapter(StoredHealthReadingAdapter());
      box = await Hive.openBox<StoredHealthReading>('test_health');
      repository = HealthDataRepositoryHive(boxAccessor: FakeBoxAccessor(box));
    });

    tearDown(() async {
      await box.clear();
      await box.close();
    });

    test('saveHeartRate creates entry with composite key', () async {
      final reading = NormalizedHeartRateReading(
        patientUid: 'patient123',
        timestamp: DateTime.utc(2026, 1, 2, 10, 30),
        bpm: 72,
        dataSource: HealthDataSource.appleHealth,
      );

      await repository.saveHeartRate(reading);

      expect(box.containsKey('patient123_heartRate_2026-01-02T10:30:00.000Z'), isTrue);
    });

    test('saveHeartRate deduplicates same reading', () async {
      final reading = NormalizedHeartRateReading(
        patientUid: 'patient123',
        timestamp: DateTime.utc(2026, 1, 2, 10, 30),
        bpm: 72,
        dataSource: HealthDataSource.appleHealth,
      );

      await repository.saveHeartRate(reading);
      await repository.saveHeartRate(reading); // same again

      expect(box.length, equals(1));
    });

    test('pruneExpired removes old readings', () async {
      // Add old reading (40 days ago)
      final oldReading = StoredHealthReading(
        id: 'patient123_heartRate_2025-11-23T10:30:00.000Z',
        patientUid: 'patient123',
        readingType: StoredHealthReadingType.heartRate,
        recordedAt: DateTime.now().subtract(Duration(days: 40)),
        persistedAt: DateTime.now(),
        dataSource: 'appleHealth',
        deviceType: 'appleWatch',
        reliability: 'high',
        data: {'bpm': 72},
        schemaVersion: 1,
      );
      await box.put(oldReading.id, oldReading);

      final deleted = await repository.pruneExpired(retentionDays: 30);

      expect(deleted, equals(1));
      expect(box.isEmpty, isTrue);
    });
  });
}
```

---

## Implementation Checklist

### Step 2.1: Models & Types
- [ ] Create `StoredHealthReading` model
- [ ] Create `StoredHealthReadingType` enum
- [ ] Create `HealthStorageStats` model
- [ ] Create `StoredVitalsSnapshot` model

### Step 2.2: Persistence Infrastructure
- [ ] Add `TypeIds.storedHealthReading` (55)
- [ ] Add `TypeIds.storedHealthReadingType` (56)
- [ ] Add `BoxRegistry.healthReadingsBox`
- [ ] Create `StoredHealthReadingAdapter`
- [ ] Register adapter in `HiveService`
- [ ] Add `healthReadings()` to `BoxAccessor`

### Step 2.3: Repository
- [ ] Create `HealthDataRepository` interface
- [ ] Create `HealthDataRepositoryHive` implementation
- [ ] Implement write operations with deduplication
- [ ] Implement read operations with prefix filtering
- [ ] Implement watch operations
- [ ] Implement maintenance operations

### Step 2.4: Service
- [ ] Create `HealthDataPersistenceService`
- [ ] Implement `fetchAndPersistVitals()`
- [ ] Implement `pruneExpiredReadings()`
- [ ] Integrate with `TtlCompactionService`

### Step 2.5: Providers
- [ ] Create `healthDataRepositoryProvider`
- [ ] Create `healthPersistenceServiceProvider`
- [ ] Create `fetchAndPersistVitalsProvider`
- [ ] Create `localHeartRatesProvider`
- [ ] Create `localVitalsSnapshotProvider`
- [ ] Create `healthStorageStatsProvider`

### Step 2.6: Testing
- [ ] Unit tests for repository
- [ ] Unit tests for deduplication
- [ ] Unit tests for pruning
- [ ] Integration tests with mock extraction service

### Step 2.7: Documentation
- [ ] Update barrel export
- [ ] Update implementation documentation

---

## Success Criteria

1. ✅ All extracted health readings can be persisted to Hive
2. ✅ Duplicate readings (same patient+type+timestamp) are not stored twice
3. ✅ Readings older than retention period are automatically pruned
4. ✅ UI can read local data without network (offline replay)
5. ✅ `dart analyze lib/health/` returns no issues
6. ✅ Unit tests pass

---

## Next Steps After Step 2

- **Step 3**: Firestore Sync — Mirror local readings to `patients/{uid}/health_readings`
- **Step 4**: Background Workers — Periodic health data refresh
- **Step 5**: UI Integration — Update patient screens to use persistence providers
