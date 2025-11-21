# Guardian Angel Persistence Specs (Phase 1)

Phase 1 delivers canonical domain model specifications, JSON wire contracts, and test vectors to enable durable, encrypted Hive storage with future-proof migrations.

## Deliverables

- YAML model specs (`specs/models/*.yaml`)
- Wire contract rules (`specs/wire_contracts.md`)
- Test vectors (`specs/test_vectors/*.json`)
- Sign-off doc (`docs/model_signoff.md`, added later in Phase 1)

## Encryption Policy

Encrypted boxes (PII / sensitive):

- `vitals_box`
- `user_profile_box`
- `sessions_box`
- `pending_ops_box`
- `failed_ops_box`
- `audit_logs_box`

Non-encrypted (cache / low sensitivity):

- `assets_cache_box`
- `ui_preferences_box` (may be upgraded to encrypted if personalizable)

## Indexing & Query Patterns

- `pending_ops_box` / `failed_ops_box`:
  - Primary FIFO index: `created_at`
  - Secondary filters: `attempts`, `op_type`, `status`
  - Operations: fetch oldest N, scan stale ops older than X days, retry queue
- `audit_logs_box`: time-range queries by `created_at` and filter by `actor_type` / `action`
- `vitals_box`: latest by `recorded_at`, aggregate ranges

## Date & Numeric Rules

- ISO8601 UTC with trailing `Z`, millisecond precision: `2025-03-02T14:23:12.123Z`
- Vitals numeric rounding: store with <= 2 decimal places (ROUND_HALF_UP semantics)

## Schema Versioning

Each model contains `schema_version` (int) starting at 1. Migrations will read this value.

## Validation Strategy

Adapters will validate required fields; corrupted / missing required becomes a recoverable error and may trigger quarantine in `failed_ops_box` or audit entry.

See individual model specs for details.
