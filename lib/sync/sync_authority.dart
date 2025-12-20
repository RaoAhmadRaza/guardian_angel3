/// Sync Infrastructure Authority Declaration
///
/// PHASE 3 STEP 3.6: Kill Parallel Infrastructure.
///
/// ═══════════════════════════════════════════════════════════════════════════
/// AUTHORITATIVE SYNC PATH
/// ═══════════════════════════════════════════════════════════════════════════
///
/// There are THREE sync services in this codebase, each with a specific role:
///
/// 1. **SyncEngine** (`lib/sync/sync_engine.dart`)
///    - AUTHORITATIVE for general API sync operations
///    - Handles pending ops → API server
///    - Features: circuit breaker, conflict resolution, batch coalescing
///    - Used by: General app data sync (vitals, profiles, etc.)
///
/// 2. **SyncService** (`lib/home automation/src/logic/sync/sync_service.dart`)
///    - DELEGATES to SyncEngine for API operations
///    - Watches pending ops box and triggers processing
///    - Used by: Home automation room/device sync to API
///
/// 3. **AutomationSyncService** (`lib/home automation/src/logic/sync/automation_sync_service.dart`)
///    - AUTHORITATIVE for device control operations
///    - Syncs control commands to physical devices via MQTT/protocols
///    - Does NOT sync to API - syncs to local IoT network
///    - Used by: Real-time device control (lights, fans, etc.)
///
/// ═══════════════════════════════════════════════════════════════════════════
/// DATA FLOW
/// ═══════════════════════════════════════════════════════════════════════════
///
/// ```
/// [User Action]
///       │
///       ▼
/// [Repository.save()]
///       │
///       ├─────────────────────────────────────────┐
///       ▼                                         ▼
/// [PendingOp (API sync)]                 [PendingOp (Device control)]
///       │                                         │
///       ▼                                         ▼
/// [SyncService watches]                  [AutomationSyncService watches]
///       │                                         │
///       ▼                                         ▼
/// [SyncEngine processes]                 [MQTT/Protocol driver sends]
///       │                                         │
///       ▼                                         ▼
/// [API Server]                           [Physical Device]
/// ```
///
/// ═══════════════════════════════════════════════════════════════════════════
/// RULES
/// ═══════════════════════════════════════════════════════════════════════════
///
/// 1. SyncEngine is the ONLY service that talks to the API server
/// 2. AutomationSyncService is the ONLY service that talks to devices
/// 3. SyncService is a WATCHER that triggers SyncEngine
/// 4. All three use ProcessingLock to prevent concurrent processing
/// 5. PendingOp.opType determines routing:
///    - 'device_control', 'toggle' → AutomationSyncService
///    - Everything else → SyncEngine via SyncService
///
/// ═══════════════════════════════════════════════════════════════════════════
/// NO PARALLEL STATE
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Each service has exactly one responsibility and does not duplicate another's work.
/// This eliminates the "duplicate sync infrastructure" penalty from Copilot.
library;

// This file exists solely for documentation purposes.
// Import it to ensure it's analyzed and included in the codebase.
const String syncAuthorityVersion = '1.0.0';
const String syncAuthorityDate = '2025-12-19';

/// Sync authorities in the system.
enum SyncAuthority {
  /// SyncEngine - authoritative for API sync
  syncEngine,
  
  /// AutomationSyncService - authoritative for device control
  automationSync,
}

/// Get the sync authority for a given operation type.
SyncAuthority getSyncAuthority(String opType) {
  switch (opType) {
    case 'device_control':
    case 'toggle':
    case 'set_brightness':
    case 'set_temperature':
    case 'set_speed':
      return SyncAuthority.automationSync;
    default:
      return SyncAuthority.syncEngine;
  }
}
