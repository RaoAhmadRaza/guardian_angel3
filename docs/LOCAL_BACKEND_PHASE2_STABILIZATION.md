# Local Backend Phase 2 Stabilization

**Target:** Move from 72% → 77–78% local backend completeness  
**Status:** ✅ Complete

---

## Summary

This phase unifies behavior **without refactoring storage**. The goal is to stop architectural drift while keeping current data intact.

---

## Deliverables

### 5️⃣ Encryption Policy Enforcement (Soft) ✅

**File:** `lib/persistence/encryption_policy.dart`

Created:
- `EncryptionPolicy` enum: `required`, `optional`, `forbidden`
- `BoxConfig` class: name, encryption policy, description
- `BoxPolicyRegistry`: static registry of all box configurations

```dart
enum EncryptionPolicy {
  required,   // Box MUST be encrypted (PHI, credentials)
  optional,   // Encryption is optional (cache, preferences)
  forbidden,  // No encryption (index boxes for performance)
}
```

Features:
- Runtime compliance check via `checkPolicyCompliance(boxName)`
- Batch check via `checkAllPolicies()`
- Summary via `getSummary()` returning `EncryptionPolicySummary`
- Violations recorded to telemetry, NOT blocked

**Impact:** +1.5%

---

### 6️⃣ Adapter & TypeId Collision Guard ✅

**File:** `lib/persistence/adapter_collision_guard.dart`

Created:
- `AdapterCollisionGuard` class with startup guard
- `reservedTypeIds` map documenting all known TypeIds
- `assertNoCollisions()` - fails fast in debug/profile builds
- `validateTypeId()` - pre-registration validation

```dart
// At startup (after adapters registered, before boxes opened)
AdapterCollisionGuard.assertNoCollisions();
```

Behavior:
- **Debug/Profile builds:** Throws `StateError` on collision
- **Release builds:** Records telemetry, logs warning, continues

**Impact:** +1.5%

---

### 7️⃣ Minimal Observability Surface (Read-Only) ✅

**File:** `lib/persistence/local_backend_status.dart`

Created:
- `LocalBackendStatus` class with key metrics:
  - `pendingOps`, `failedOps`, `retryingOps`
  - `encryptionHealthy`, `queueStalled`
  - `oldestOpAge`, `lastProcessedAt`
  - `openBoxCount`, `isHealthy`

- `LocalBackendStatusCollector` - service to collect status
- Riverpod providers:
  - `localBackendStatusProvider` - on-demand status
  - `localBackendStatusStreamProvider` - auto-refresh every 30s
  - `localBackendHealthyProvider` - simple boolean

```dart
// Usage in UI
final status = ref.watch(localBackendStatusProvider);
if (status.queueStalled) {
  // Handle stalled queue
}
```

No admin UI yet. Just data.

**Impact:** +1.5%

---

### 8️⃣ Queue Integrity Auto-Check (Passive) ✅

**File:** `lib/bootstrap/local_backend_bootstrap.dart` (updated)

Integrated:
```dart
// Step 5: Queue integrity auto-check (Phase 2)
final pendingIndex = await PendingIndex.create();
await pendingIndex.integrityCheckAndRebuild();
```

Features:
- Runs automatically on app start
- Logged to telemetry (`local_backend.queue_integrity.checked`)
- Non-blocking: errors logged but don't fail init
- No user-visible behavior change

**Impact:** +0.5%

---

## Bootstrap Integration

The bootstrap now includes all Phase 2 checks in order:

```dart
// Order of operations:
// 1. HiveService.init() - Core persistence
// 2. AdapterCollisionGuard.assertNoCollisions() - TypeId validation
// 3. HomeAutomationHiveBridge.open() - Automation boxes
// 4. BoxPolicyRegistry.checkAllPolicies() - Encryption policy
// 5. PendingIndex.integrityCheckAndRebuild() - Queue integrity
```

---

## Files Created/Modified

| File | Change |
|------|--------|
| `lib/persistence/encryption_policy.dart` | Created - policy enum, config, registry |
| `lib/persistence/adapter_collision_guard.dart` | Created - TypeId guard |
| `lib/persistence/local_backend_status.dart` | Created - observability providers |
| `lib/bootstrap/local_backend_bootstrap.dart` | Updated - integrated Phase 2 checks |

---

## Telemetry Keys Added

| Key | Description |
|-----|-------------|
| `encryption_policy.violation.*` | Policy compliance violations |
| `adapter_guard.collision_detected` | TypeId collision detected |
| `adapter_guard.registered_count` | Number of registered adapters |
| `local_backend.pending_ops` | Current pending operation count |
| `local_backend.failed_ops` | Current failed operation count |
| `local_backend.queue_stalled` | Queue stalled indicator |
| `local_backend.queue_integrity.checked` | Integrity check completed |

---

## Verification

```bash
# Analyze Phase 2 files
dart analyze lib/persistence/encryption_policy.dart \
  lib/persistence/adapter_collision_guard.dart \
  lib/persistence/local_backend_status.dart \
  lib/bootstrap/local_backend_bootstrap.dart

# Run tests
flutter test test/persistence/
```

---

## Edge Cases Handled

1. **Mixed encryption state** - Detected and logged, not blocked
2. **Silent data corruption** - TypeId collision fails fast in dev
3. **Cross-module adapter clashes** - Centralized TypeId registry
4. **"Everything looks fine" when it isn't** - Status provider exposes truth
5. **Debugging blind spots** - All metrics available via Riverpod

---

## Next Steps (Phase 3 - 78% → 88%)

1. **Consolidate dual HiveService stacks** - One service, one way to open boxes
2. **Add write-ahead log** - True atomicity for critical operations
3. **Implement retry backoff** - Exponential backoff for failed ops
4. **Admin UI foundation** - Surface `LocalBackendStatus` in dev mode
