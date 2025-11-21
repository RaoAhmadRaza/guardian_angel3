# Wire Contracts (Canonical JSON Rules)

This document defines the exact JSON wire format for all persisted models and any remote sync payloads.

## Global Conventions
- Key naming: `snake_case` in JSON; Dart fields use `camelCase`.
- Dates: ISO8601 UTC millisecond precision, trailing `Z`. Example: `2025-03-02T14:23:12.123Z`.
- Nullability: Omit keys for null optional fields (never include as `null`).
- Numbers: For vitals metrics, round to <= 2 decimals using ROUND_HALF_UP.
- Booleans: Only `true` / `false`.
- Empty collections: Represent as `[]` or `{}` (never `null`).
- Enums: Lowercase identifiers, underscores if needed (e.g., `heart_rate`).
- UUIDs: RFC4122 v4 format.

## Common Metadata Keys
- `id` (uuid)
- `schema_version` (int)
- `created_at` (iso8601 UTC)
- `updated_at` (iso8601 UTC)

## Standard Field Key Map
| Dart Field     | JSON Key      |
|----------------|---------------|
| createdAt      | created_at    |
| updatedAt      | updated_at    |
| deviceIds      | device_ids    |
| recordedAt     | recorded_at   |
| userId         | user_id       |
| sessionToken   | session_token |
| attempts       | attempts      |
| opType         | op_type       |
| actorType      | actor_type    |
| auditDetails   | audit_details |

## Example: RoomModel
```json
{
  "id": "9f8c1f24-07c4-4e5c-9d47-5f2e5e3e4d12",
  "schema_version": 1,
  "name": "Living Room",
  "icon": "sofa",
  "color": "#FFA500",
  "device_ids": ["d1", "d2"],
  "meta": {"floor": 1},
  "created_at": "2025-03-02T14:23:12.123Z",
  "updated_at": "2025-03-02T14:23:12.123Z"
}
```

## Example: PendingOp
```json
{
  "id": "4a5d0d66-2e4e-4cd8-9aba-56a5c3e7d1ef",
  "schema_version": 1,
  "op_type": "device_toggle",
  "idempotency_key": "2025-03-02-device_toggle-d1-001",
  "payload": {"device_id": "d1", "target_state": true},
  "attempts": 0,
  "status": "pending",
  "created_at": "2025-03-02T14:23:12.123Z",
  "updated_at": "2025-03-02T14:23:12.123Z"
}
```

## Numeric Rounding (Vitals)
- Apply at ingestion.
- Example: incoming `98.765` → stored `98.77`.
- Serialize with fixed decimals (avoid scientific notation).

## Corruption Handling
If `fromJson` detects missing required keys or type mismatches:
1. Emit audit log entry.
2. Route record to quarantine (`failed_ops_box`) if applicable.
3. Skip insertion into primary box.

## Future Extension Hook
- Reserved optional metadata key: `ext` (object) for experimental fields.

Authoritative for adapter implementation & migration tests.