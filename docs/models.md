# Data Models Reference

Complete reference for all domain models in Guardian Angel FYP.

## Core Domain Models

### RoomModel

**Purpose:** Represents a physical room with devices

**Fields:**
| Field | Type | Required | Validation | Description |
|-------|------|----------|------------|-------------|
| id | String | ✅ | Non-empty | Unique room identifier |
| name | String | ✅ | 1-50 chars | Room display name |
| icon | String? | ❌ | - | Icon identifier (nullable) |
| color | String? | ❌ | Hex color | Display color (nullable) |
| devices | List\<String\> | ✅ | - | Device IDs in this room |
| createdAt | DateTime | ✅ | UTC | Creation timestamp |
| updatedAt | DateTime | ✅ | UTC | Last update timestamp |

**Example JSON:**
```json
{
  "id": "room_living",
  "name": "Living Room",
  "icon": "sofa",
  "color": "#4A90E2",
  "devices": ["dev_001", "dev_002"],
  "createdAt": "2024-01-15T10:30:00.000Z",
  "updatedAt": "2024-01-15T10:30:00.000Z"
}
```

**Schema Notes:** `devices` array likely to expand with ordering, grouping metadata.

---

### DeviceModel

**Purpose:** Represents a smart home device

**Fields:**
| Field | Type | Required | Validation | Description |
|-------|------|----------|------------|-------------|
| id | String | ✅ | Non-empty | Unique device identifier |
| name | String | ✅ | 1-100 chars | Device display name |
| roomId | String | ✅ | Valid room ID | Parent room reference |
| type | String | ✅ | Enum | Device type (bulb, switch, sensor, etc.) |
| status | String | ✅ | on/off | Current power status |
| isOnline | bool | ✅ | - | Network connectivity status |
| metadata | Map\<String, dynamic\> | ✅ | - | Device-specific properties |
| lastSeen | DateTime | ✅ | UTC | Last communication timestamp |

**Example JSON:**
```json
{
  "id": "dev_001",
  "name": "Ceiling Light",
  "roomId": "room_living",
  "type": "bulb",
  "status": "on",
  "isOnline": true,
  "metadata": {
    "brightness": 75,
    "colorTemp": 4000
  },
  "lastSeen": "2024-01-15T10:35:00.000Z"
}
```

**Schema Notes:** `metadata` structure varies by device type. May add `batteryLevel`, `firmwareVersion` fields.

---

### PendingOp

**Purpose:** Queued operation awaiting synchronization

**Fields:**
| Field | Type | Required | Validation | Description |
|-------|------|----------|------------|-------------|
| id | String | ✅ | Non-empty, unique | Operation identifier |
| opType | String | ✅ | Enum | Operation type (create, update, delete, control) |
| idempotencyKey | String | ✅ | Non-empty | Deduplication key for backend |
| payload | Map\<String, dynamic\> | ✅ | - | Operation-specific data |
| attempts | int | ✅ | >= 0 | Retry attempt count |
| status | String | ✅ | pending/processing | Current operation status |
| createdAt | DateTime | ✅ | UTC | Queue entry timestamp |
| updatedAt | DateTime | ✅ | UTC | Last modification timestamp |

**Example JSON:**
```json
{
  "id": "op_1705315800_abc123",
  "opType": "control",
  "idempotencyKey": "idem_dev001_toggle_1705315800",
  "payload": {
    "deviceId": "dev_001",
    "action": "toggle",
    "roomId": "room_living"
  },
  "attempts": 0,
  "status": "pending",
  "createdAt": "2024-01-15T10:30:00.000Z",
  "updatedAt": "2024-01-15T10:30:00.000Z"
}
```

**Schema Notes:** `idempotencyKey` format critical for deduplication. Consider adding `scheduledAt` for delayed ops.

---

### FailedOpModel

**Purpose:** Failed operation requiring manual intervention or retry

**Fields:**
| Field | Type | Required | Validation | Description |
|-------|------|----------|------------|-------------|
| id | String | ✅ | Non-empty | Unique failure identifier |
| sourcePendingOpId | String | ✅ | Valid op ID | Original operation reference |
| opType | String | ✅ | Enum | Operation type |
| payload | Map\<String, dynamic\> | ✅ | - | Operation data |
| errorCode | String | ✅ | Non-empty | Error classification code |
| errorMessage | String | ✅ | Non-empty | Human-readable error |
| idempotencyKey | String | ✅ | Non-empty | Preserved from original op |
| attempts | int | ✅ | >= 1 | Total retry attempts made |
| archived | bool | ✅ | - | Archive flag for retention |
| createdAt | DateTime | ✅ | UTC | Failure timestamp |
| updatedAt | DateTime | ✅ | UTC | Last update timestamp |

**Example JSON:**
```json
{
  "id": "failed_op_1705315900",
  "sourcePendingOpId": "op_1705315800_abc123",
  "opType": "control",
  "payload": {
    "deviceId": "dev_001",
    "action": "toggle"
  },
  "errorCode": "DEVICE_OFFLINE",
  "errorMessage": "Device dev_001 not responding",
  "idempotencyKey": "idem_dev001_toggle_1705315800",
  "attempts": 3,
  "archived": false,
  "createdAt": "2024-01-15T10:35:00.000Z",
  "updatedAt": "2024-01-15T10:40:00.000Z"
}
```

**Schema Notes:** Add `retryAfter` timestamp for exponential backoff scheduling.

---

### UserProfileModel

**Purpose:** User account and preferences

**Fields:**
| Field | Type | Required | Validation | Description |
|-------|------|----------|------------|-------------|
| userId | String | ✅ | Non-empty | Unique user identifier |
| name | String | ✅ | 1-100 chars | Display name |
| email | String | ✅ | Valid email | Contact email |
| role | String | ✅ | Enum | User role (admin, caregiver, patient) |
| preferences | Map\<String, dynamic\> | ✅ | - | User-specific settings |
| createdAt | DateTime | ✅ | UTC | Account creation timestamp |
| lastLoginAt | DateTime? | ❌ | UTC | Most recent login |

**Example JSON:**
```json
{
  "userId": "user_001",
  "name": "John Doe",
  "email": "john.doe@example.com",
  "role": "caregiver",
  "preferences": {
    "theme": "dark",
    "notifications": true,
    "language": "en"
  },
  "createdAt": "2024-01-01T00:00:00.000Z",
  "lastLoginAt": "2024-01-15T10:00:00.000Z"
}
```

**Schema Notes:** May add `profileImageUrl`, `phoneNumber`, `emergencyContacts` fields.

---

### SessionModel

**Purpose:** Authentication session tracking

**Fields:**
| Field | Type | Required | Validation | Description |
|-------|------|----------|------------|-------------|
| sessionId | String | ✅ | Non-empty | Unique session identifier |
| userId | String | ✅ | Valid user ID | Session owner reference |
| token | String | ✅ | Non-empty | Auth token |
| deviceInfo | String | ✅ | Non-empty | Device fingerprint |
| createdAt | DateTime | ✅ | UTC | Session start timestamp |
| expiresAt | DateTime | ✅ | UTC | Session expiry timestamp |
| lastActivityAt | DateTime | ✅ | UTC | Last activity timestamp |

**Example JSON:**
```json
{
  "sessionId": "sess_abc123xyz",
  "userId": "user_001",
  "token": "eyJhbGc...truncated",
  "deviceInfo": "iOS 17.0 - iPhone 14 Pro",
  "createdAt": "2024-01-15T10:00:00.000Z",
  "expiresAt": "2024-01-22T10:00:00.000Z",
  "lastActivityAt": "2024-01-15T10:30:00.000Z"
}
```

**Schema Notes:** Consider refresh token mechanism, multi-device support.

---

### VitalsModel

**Purpose:** Health vitals tracking for elderly care

**Fields:**
| Field | Type | Required | Validation | Description |
|-------|------|----------|------------|-------------|
| id | String | ✅ | Non-empty | Unique vitals record ID |
| userId | String | ✅ | Valid user ID | Patient reference |
| timestamp | DateTime | ✅ | UTC | Measurement timestamp |
| heartRate | int? | ❌ | 30-200 bpm | Heart rate measurement |
| bloodPressureSystolic | int? | ❌ | 70-200 | Systolic BP |
| bloodPressureDiastolic | int? | ❌ | 40-130 | Diastolic BP |
| temperature | double? | ❌ | 35-42 °C | Body temperature |
| oxygenSaturation | int? | ❌ | 70-100 % | SpO2 level |
| notes | String? | ❌ | Max 500 chars | Additional observations |

**Example JSON:**
```json
{
  "id": "vitals_1705315800",
  "userId": "user_patient_001",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "heartRate": 72,
  "bloodPressureSystolic": 120,
  "bloodPressureDiastolic": 80,
  "temperature": 36.5,
  "oxygenSaturation": 98,
  "notes": "Patient feeling well"
}
```

**Schema Notes:** May add `glucoseLevel`, `weight`, `activityLevel` fields. Consider time-series optimization.

---

### SettingsModel

**Purpose:** Application configuration and user preferences

**Fields:**
| Field | Type | Required | Validation | Description |
|-------|------|----------|------------|-------------|
| userId | String | ✅ | Non-empty | Settings owner |
| theme | String | ✅ | light/dark | UI theme preference |
| language | String | ✅ | ISO 639-1 | Locale code |
| notificationsEnabled | bool | ✅ | - | Global notification toggle |
| syncEnabled | bool | ✅ | - | Auto-sync toggle |
| customSettings | Map\<String, dynamic\> | ✅ | - | Feature-specific settings |

**Example JSON:**
```json
{
  "userId": "user_001",
  "theme": "dark",
  "language": "en",
  "notificationsEnabled": true,
  "syncEnabled": true,
  "customSettings": {
    "autoBackup": true,
    "backupFrequency": "daily",
    "vitalsReminderTime": "08:00"
  }
}
```

**Schema Notes:** Settings structure may vary per feature module. Consider versioning.

---

## Transaction Models (TypeIds 30-39)

### TransactionRecord

**Purpose:** Atomic multi-box transaction record

**Fields:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| transactionId | String | ✅ | Unique transaction identifier |
| createdAt | DateTime | ✅ | Transaction start timestamp |
| state | TransactionState | ✅ | pending/committed/applied/failed |
| committedAt | DateTime? | ❌ | Commit timestamp |
| appliedAt | DateTime? | ❌ | Application timestamp |
| modelChanges | Map\<String, Map\<String, dynamic\>\> | ✅ | Changes per box |
| pendingOp | Map\<String, dynamic\>? | ❌ | Associated pending operation |
| indexEntries | Map\<String, List\<String\>\> | ✅ | Index updates |
| errorMessage | String? | ❌ | Failure reason |

**TypeId:** 30

---

### LockRecord

**Purpose:** Distributed lock for queue processing

**Fields:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| lockName | String | ✅ | Lock identifier |
| runnerId | String | ✅ | Current lock holder |
| acquiredAt | DateTime | ✅ | Lock acquisition time |
| lastHeartbeat | DateTime | ✅ | Last heartbeat update |
| metadata | Map\<String, dynamic\>? | ❌ | Debug information |

**TypeId:** 32

---

### AuditLogEntry

**Purpose:** Security and compliance audit trail

**Fields:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| entryId | String | ✅ | Unique entry identifier |
| timestamp | DateTime | ✅ | Event timestamp (UTC) |
| userId | String | ✅ | Actor user ID |
| action | String | ✅ | Action type (login, logout, data_access, etc.) |
| entityType | String? | ❌ | Affected entity type |
| entityId | String? | ❌ | Affected entity ID |
| metadata | Map\<String, dynamic\> | ✅ | Additional context |
| severity | String | ✅ | info/warning/critical |

**TypeId:** 33

**Example JSON:**
```json
{
  "entryId": "audit_1705315800",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "userId": "user_001",
  "action": "device_control",
  "entityType": "device",
  "entityId": "dev_001",
  "metadata": {
    "command": "toggle",
    "ipAddress": "192.168.1.100"
  },
  "severity": "info"
}
```

---

## Sync Models (TypeIds 24-26)

### SyncFailure

**Purpose:** Track synchronization failures requiring user attention

**Fields:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | String | ✅ | Unique failure identifier |
| entityType | String | ✅ | Entity type that failed to sync |
| entityId | String | ✅ | Entity identifier |
| operation | String | ✅ | Operation that failed |
| reason | String | ✅ | Failure reason code |
| errorMessage | String | ✅ | Human-readable error |
| firstFailedAt | DateTime | ✅ | Initial failure timestamp |
| lastAttemptAt | DateTime | ✅ | Most recent retry timestamp |
| retryCount | int | ✅ | Number of retry attempts |
| status | SyncFailureStatus | ✅ | pending/retrying/failed/resolved/dismissed |
| severity | SyncFailureSeverity | ✅ | low/medium/high/critical |
| requiresUserAction | bool | ✅ | Manual intervention flag |

**TypeId:** 24

---

## TypeId Allocation Map

| Range | Purpose | Models |
|-------|---------|--------|
| 10-19 | Domain Models | Room, PendingOp, Device, Vitals, UserProfile, Session, FailedOp, AuditLog, Settings, AssetsCache |
| 20-29 | Reserved | Future domain extensions |
| 24-26 | Sync Models | SyncFailure, SyncFailureStatus, SyncFailureSeverity |
| 30-39 | Transaction/Service Models | TransactionRecord, TransactionState, LockRecord, AuditLogEntry, AuditLogArchive |

## Validation Rules

### Common Patterns
- **Timestamps:** Always UTC, ISO8601 format
- **IDs:** Non-empty strings, often prefixed (e.g., `user_`, `dev_`, `op_`)
- **Enums:** Validated against predefined sets
- **Maps:** Type-safe deserialization with fallbacks

### Best Practices
1. **Nullability:** Prefer required fields with defaults over nullable fields
2. **Versioning:** Include schema version in complex models for migration support
3. **Immutability:** Domain models should be immutable where possible
4. **Validation:** Validate at construction time, not on access
5. **JSON Keys:** Use snake_case for wire format, camelCase for Dart

## Migration Considerations

When modifying models:
1. **Adding Fields:** Add with defaults, increment schema version
2. **Removing Fields:** Deprecate first, remove after grace period
3. **Renaming Fields:** Treat as remove + add, provide migration
4. **Type Changes:** Requires explicit migration with data transformation

See `docs/persistence.md` for migration implementation guide.
