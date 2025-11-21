# Persistence Layer Documentation

Complete guide to Hive-based persistence in Guardian Angel FYP.

## Architecture Overview

### Storage Stack
```
┌─────────────────────────────────────┐
│   Application Layer                 │
│   (UI, Business Logic)              │
└─────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────┐
│   Services Layer                    │
│   (FailedOpsService, etc.)          │
└─────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────┐
│   Hive Service                      │
│   (Init, Encryption, Migration)     │
└─────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────┐
│   Hive Database                     │
│   (Encrypted Local Storage)         │
└─────────────────────────────────────┘
```

---

## Hive Initialization Flow

### 1. App Startup Sequence

```dart
// main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive service
  final hiveService = await HiveService.create();
  await hiveService.init();
  
  // Initialize other services that depend on Hive
  // ...
  
  runApp(MyApp());
}
```

### 2. HiveService.init() Steps

```dart
// lib/persistence/hive_service.dart
Future<void> init() async {
  // 1. Initialize Hive Flutter (sets up local storage path)
  await Hive.initFlutter();
  
  // 2. Register all TypeAdapters
  Hive
    ..registerAdapter(RoomAdapter())
    ..registerAdapter(PendingOpAdapter())
    ..registerAdapter(VitalsAdapter())
    // ... all other adapters
  
  // 3. Retrieve or generate encryption key
  final encryptionKey = await _getOrCreateEncryptionKey();
  
  // 4. Open essential boxes with encryption
  await _openEncryptedBoxes(encryptionKey);
  
  // 5. Run migrations if needed
  await _runMigrations();
  
  // 6. Initialize indices (PendingIndex, etc.)
  await _initializeIndices();
}
```

### 3. Encryption Key Management

**Key Generation:**
```dart
Future<List<int>> _getOrCreateEncryptionKey() async {
  const keyName = 'hive_enc_key_v1';
  
  // Check if key exists
  String? storedKey = await secureStorage.read(key: keyName);
  
  if (storedKey == null) {
    // Generate new 256-bit key
    final key = Hive.generateSecureKey();
    
    // Store in FlutterSecureStorage
    await secureStorage.write(
      key: keyName,
      value: base64Encode(key),
    );
    
    return key;
  }
  
  return base64Decode(storedKey);
}
```

**Security Features:**
- Keys stored in platform-specific secure storage (Keychain on iOS, KeyStore on Android)
- Keys never logged or exposed in memory dumps
- Automatic key rotation support (see Key Rotation section)

---

## Box Management

### Box Types

| Box Name | Type | Encrypted | Purpose |
|----------|------|-----------|---------|
| `rooms_v1` | Box\<RoomModel\> | ❌ | Room data |
| `devices_v1` | Box\<DeviceModel\> | ❌ | Device data |
| `pending_ops` | Box\<PendingOp\> | ✅ | Operation queue |
| `failed_ops` | Box\<FailedOpModel\> | ✅ | Failed operations |
| `vitals_v1` | Box\<VitalsModel\> | ✅ | Health vitals |
| `user_profile` | Box\<UserProfileModel\> | ✅ | User data |
| `sessions` | Box\<SessionModel\> | ✅ | Auth sessions |
| `settings` | Box\<SettingsModel\> | ✅ | User settings |
| `audit_logs` | Box\<AuditLogEntry\> | ✅ | Audit trail |
| `transaction_log` | Box\<TransactionRecord\> | ✅ | Transaction records |
| `meta` | Box | ✅ | Schema version, locks |

### Opening Boxes

**Encrypted Box:**
```dart
final cipher = HiveAesCipher(encryptionKey);
final box = await Hive.openBox<PendingOp>(
  'pending_ops',
  encryptionCipher: cipher,
);
```

**Unencrypted Box:**
```dart
final box = await Hive.openBox<RoomModel>('rooms_v1');
```

**Best Practice:** Always use typed boxes (`Box<T>`) for type safety.

---

## Pending Operations Lifecycle

### 1. Operation Creation

```dart
// Enqueue a new operation
final op = PendingOp(
  id: 'op_${DateTime.now().millisecondsSinceEpoch}',
  opType: 'control',
  idempotencyKey: 'idem_${deviceId}_${action}_${timestamp}',
  payload: {'deviceId': deviceId, 'action': action},
  attempts: 0,
  status: 'pending',
  createdAt: DateTime.now().toUtc(),
  updatedAt: DateTime.now().toUtc(),
);

// Add to pending ops box
final pendingBox = Hive.box<PendingOp>('pending_ops');
await pendingBox.put(op.id, op);

// Add to FIFO index
final index = await PendingIndex.create();
await index.enqueue(op.id, op.createdAt);
```

### 2. FIFO Index Structure

The `PendingIndex` maintains strict FIFO ordering:

```dart
// lib/persistence/index/pending_index.dart
class PendingIndex {
  final Box _indexBox;
  
  // Get oldest operation ID
  Future<String?> getOldest() async {
    final entries = _indexBox.values.cast<Map>();
    if (entries.isEmpty) return null;
    
    // Sort by createdAt timestamp
    final sorted = entries.toList()
      ..sort((a, b) => (a['createdAt'] as String)
          .compareTo(b['createdAt'] as String));
    
    return sorted.first['opId'] as String;
  }
  
  // Enqueue new operation
  Future<void> enqueue(String opId, DateTime createdAt) async {
    await _indexBox.add({
      'opId': opId,
      'createdAt': createdAt.toIso8601String(),
    });
  }
  
  // Dequeue after processing
  Future<void> dequeue(String opId) async {
    final key = _findKey(opId);
    if (key != null) await _indexBox.delete(key);
  }
}
```

### 3. Processing Loop

```dart
// Pseudocode for queue processor
while (true) {
  final opId = await pendingIndex.getOldest();
  if (opId == null) break;
  
  final op = pendingBox.get(opId);
  if (op == null) {
    await pendingIndex.dequeue(opId);
    continue;
  }
  
  try {
    await processOperation(op);
    
    // Success: remove from both
    await pendingBox.delete(opId);
    await pendingIndex.dequeue(opId);
  } catch (e) {
    // Failure: move to failed ops
    final failedOp = FailedOpModel.fromPendingOp(op, error: e);
    await failedOpsBox.put(failedOp.id, failedOp);
    
    await pendingBox.delete(opId);
    await pendingIndex.dequeue(opId);
  }
}
```

### 4. Failed Operations Handling

```dart
// Retry a failed operation
final failedOpsService = FailedOpsService(...);

// Check if can retry
if (failedOp.attempts < maxAttempts) {
  final retriedOp = await failedOpsService.retryOp(failedOp.id);
  // retriedOp is back in pending queue with same idempotencyKey
}

// Archive old failures
await failedOpsService.archive(ageDays: 30);

// Export for analysis
final failures = await failedOpsService.exportFailures(
  since: DateTime.now().subtract(Duration(days: 7)),
);
```

---

## Migration System

### Migration Runner Usage

**1. Check Current Schema Version:**
```dart
final metaBox = Hive.box('meta');
final currentVersion = metaBox.get('schemaVersion', defaultValue: 0);
```

**2. Run Migrations:**
```dart
final runner = MigrationRunner(
  registry: MigrationRegistry.instance,
  metaBox: metaBox,
);

await runner.migrate(
  from: currentVersion,
  to: MigrationRegistry.latestVersion,
  skipBackup: false, // Create backup before migration
);
```

### Creating a Migration

**Step 1: Create Migration File**
```dart
// lib/persistence/migrations/migrations/003_add_device_metadata.dart
import 'package:hive/hive.dart';
import '../migration.dart';

class Migration003AddDeviceMetadata implements Migration {
  @override
  final int fromVersion = 2;
  
  @override
  final int toVersion = 3;
  
  @override
  Future<void> run(MigrationContext ctx) async {
    final devicesBox = await Hive.openBox('devices_v1');
    
    for (final key in devicesBox.keys) {
      final device = devicesBox.get(key);
      
      // Add new metadata field with default
      if (device['metadata'] == null) {
        device['metadata'] = {};
        await devicesBox.put(key, device);
      }
    }
    
    ctx.logger.info('Added metadata field to ${devicesBox.length} devices');
  }
}
```

**Step 2: Register Migration**
```dart
// lib/persistence/migrations/migration_registry.dart
class MigrationRegistry {
  static final instance = MigrationRegistry._();
  
  final List<Migration> migrations = [
    Migration001AddIdempotencyKey(),
    Migration002UpgradeVitalsSchema(),
    Migration003AddDeviceMetadata(), // ← Add here
  ];
  
  static int get latestVersion => instance.migrations.length;
}
```

**Step 3: Test Migration**
```dart
// test/persistence/migration_003_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_test/hive_test.dart';

void main() {
  setUpAll(() {
    Hive.registerAdapter(DeviceModelAdapter());
  });
  
  setUp(() async {
    await setUpTestHive();
  });
  
  tearDown(() async {
    await tearDownTestHive();
  });
  
  test('migration 003 adds metadata field', () async {
    // Seed old data without metadata
    final box = await Hive.openBox('devices_v1');
    await box.put('dev1', {'id': 'dev1', 'name': 'Light'});
    
    // Run migration
    final migration = Migration003AddDeviceMetadata();
    await migration.run(MigrationContext(logger: TestLogger()));
    
    // Verify
    final updated = box.get('dev1');
    expect(updated['metadata'], isNotNull);
    expect(updated['metadata'], isEmpty);
  });
}
```

### Migration Best Practices

1. **Always Backup:** Set `skipBackup: false` in production
2. **Test Rollback:** Verify backup restoration works
3. **Idempotent:** Migrations should be safe to run multiple times
4. **Chunked Processing:** For large datasets, process in batches
5. **Version Gaps:** Support skipping versions (e.g., 1→5 should work)

---

## Backup & Restore

### Creating a Backup

```dart
import 'package:guardian_angel_fyp/persistence/backups/backup_service.dart';

final backupFile = await BackupService.exportEncryptedBackup(
  boxNames: [
    'pending_ops',
    'failed_ops',
    'vitals_v1',
    'user_profile',
    'settings',
  ],
  destinationPath: '/path/to/backup.tar.gz.enc',
  aesKey: encryptionKey,
  schemaVersion: currentVersion,
);

// Backup file structure:
// - Gzip-compressed tarball
// - AES-256 encrypted
// - Contains: box data + metadata.json with schemaVersion
```

### Restoring from Backup

```dart
await BackupService.importEncryptedBackup(
  backupPath: '/path/to/backup.tar.gz.enc',
  aesKey: encryptionKey,
  targetBoxNames: ['pending_ops', 'vitals_v1', ...],
  validateSchema: true, // Check compatibility
);
```

**Schema Validation:**
- If backup schema version > current: Reject (need app update)
- If backup schema version < current: Run migrations automatically
- If backup schema version == current: Direct restore

---

## Admin Debug Tools

### Accessing Admin UI

**Enable Admin Mode:**
```dart
// In debug builds only
const bool kEnableAdminUI = true; // Set via build config

// Admin screen gated by biometric
if (kEnableAdminUI && await _authenticateAdmin()) {
  Navigator.push(context, MaterialPageRoute(
    builder: (_) => AdminDebugScreen(),
  ));
}
```

### Admin Operations

**1. Rebuild Pending Index:**
```dart
// Fixes index corruption
await pendingIndex.rebuild();
```

**2. Process Queue Manually:**
```dart
// Force process all pending ops
await queueProcessor.processAll();
```

**3. Export Backup:**
```dart
// One-tap backup creation
final file = await adminService.createBackup();
await Share.file('Guardian Angel Backup', file.path);
```

**4. View Audit Tail:**
```dart
// Last 100 audit entries
final entries = await auditService.tail(100);
```

**5. Rotate Encryption Key:**
```dart
// Re-encrypt all boxes with new key
await hiveService.rotateEncryptionKey();
```

**6. Retry Failed Op:**
```dart
// From admin UI
await failedOpsService.retryOp(failedOpId);
```

### Admin Debug Workflow

```
User Action → Biometric Auth → Admin Screen
                                     │
                 ┌───────────────────┼───────────────────┐
                 ▼                   ▼                   ▼
          Rebuild Index      Export Backup       View Audit Log
                 │                   │                   │
                 └───────────────────┴───────────────────┘
                                     │
                              Telemetry Event
```

---

## Adding New TypeAdapters

### Step 1: Define Model

```dart
// lib/models/new_model.dart
import 'package:hive/hive.dart';

part 'new_model.g.dart';

@HiveType(typeId: 20) // Use next available typeId
class NewModel {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String name;
  
  @HiveField(2)
  final DateTime createdAt;
  
  NewModel({
    required this.id,
    required this.name,
    required this.createdAt,
  });
  
  // toJson/fromJson for wire protocol
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'created_at': createdAt.toIso8601String(),
  };
  
  factory NewModel.fromJson(Map<String, dynamic> json) => NewModel(
    id: json['id'] as String,
    name: json['name'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
```

### Step 2: Generate Adapter

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Step 3: Register Adapter

```dart
// lib/persistence/hive_service.dart
Future<void> init() async {
  await Hive.initFlutter();
  Hive
    ..registerAdapter(RoomAdapter())
    // ... existing adapters
    ..registerAdapter(NewModelAdapter()); // ← Add here
  
  // ...rest of init
}
```

### Step 4: Update BoxRegistry

```dart
// lib/persistence/box_registry.dart
class BoxRegistry {
  static const newModelBox = 'new_model_v1';
  
  static Future<void> openAll(List<int> encryptionKey) async {
    // ...existing boxes
    
    await Hive.openBox<NewModel>(
      newModelBox,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );
  }
}

class TypeIds {
  // ...existing typeIds
  static const newModel = 20; // Document in allocation map
}
```

### Step 5: Test Adapter

```dart
// test/unit/adapters/new_model_adapter_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_test/hive_test.dart';

void main() {
  setUpAll(() {
    Hive.registerAdapter(NewModelAdapter());
  });
  
  setUp(() async {
    await setUpTestHive();
  });
  
  tearDown(() async {
    await tearDownTestHive();
  });
  
  test('NewModel serialization round-trip', () async {
    final box = await Hive.openBox<NewModel>('test');
    
    final original = NewModel(
      id: 'test_1',
      name: 'Test Item',
      createdAt: DateTime(2024, 1, 15).toUtc(),
    );
    
    await box.put('key1', original);
    final loaded = box.get('key1');
    
    expect(loaded, isNotNull);
    expect(loaded!.id, original.id);
    expect(loaded.name, original.name);
    expect(loaded.createdAt, original.createdAt);
  });
}
```

---

## TypeId Allocation Reference

### Current Allocation

```
10-19: Domain Models (Core App Data)
  10: RoomModel
  11: PendingOp
  12: DeviceModel
  13: VitalsModel
  14: UserProfileModel
  15: SessionModel
  16: FailedOpModel
  17: AuditLog
  18: SettingsModel
  19: AssetsCacheEntry

20-23: Reserved (Future Domain Extensions)

24-26: Sync Models
  24: SyncFailure
  25: SyncFailureStatus
  26: SyncFailureSeverity

27-29: Reserved (Future Sync Extensions)

30-39: Transaction/Service Models
  30: TransactionRecord
  31: TransactionState
  32: LockRecord
  33: AuditLogEntry
  34: AuditLogArchive
  35-39: Reserved

40+: Reserved for Future Use
```

### Allocation Rules

1. **Never Reuse:** Once assigned, typeIds are permanent
2. **Sequential:** Assign next available in range
3. **Document:** Update allocation map in code and docs
4. **Test:** Verify no collisions before merging

---

## Troubleshooting

### Common Issues

**1. TypeId Collision**
```
Error: HiveError: There is already a TypeAdapter for typeId X
```
**Solution:** Check TypeId allocation map, reassign conflicting adapter

**2. Adapter Not Registered**
```
Error: Cannot write, unknown type: ModelName
```
**Solution:** Add `Hive.registerAdapter(ModelNameAdapter())` to init

**3. Box Already Open**
```
Error: Box has already been registered
```
**Solution:** Check if box opened elsewhere, use `Hive.box()` instead

**4. Encryption Key Mismatch**
```
Error: Failed to decrypt box
```
**Solution:** Verify key retrieval logic, check secure storage

**5. Migration Failure**
```
Error: Migration failed at version X
```
**Solution:** Check migration logs, restore from backup, fix migration code

---

## Performance Tips

1. **Batch Writes:** Use `putAll()` instead of multiple `put()` calls
2. **Lazy Boxes:** Use `LazyBox` for large objects accessed infrequently
3. **Index Optimization:** Keep indices small, prune old entries
4. **Compact Regularly:** Run `box.compact()` after bulk deletes
5. **Avoid Overfetching:** Use `getAt()` with indices instead of `values.toList()`

---

## Security Checklist

- ✅ Encryption key stored in secure storage (not code)
- ✅ Sensitive boxes encrypted (vitals, sessions, audit logs)
- ✅ Key rotation implemented and tested
- ✅ Backup files encrypted with separate key derivation
- ✅ Admin UI gated by biometric authentication
- ✅ Audit log captures all sensitive operations
- ✅ Secure erase on account deletion

---

## Related Documentation

- [Data Models Reference](models.md)
- [Migration Guide](../BACKEND_IDEMPOTENCY_IMPLEMENTATION_SUMMARY.md)
- [Admin UI Commands](ADMIN_UI_COMMANDS.md)
- [Runbook](runbook.md)
