/// Health Module - Observability & Repair Authority
///
/// This module provides:
/// - BackendHealth: Single source of truth for health status
/// - AdminRepairToolkit: Confirmed, audited, idempotent repair actions
/// - QueueStatusUI: Minimal read-only queue monitoring widgets
///
/// FINAL 10% CLIMB Phase 1: Observability & Repair Authority
/// Target: 92% → ~97% confidence
///
/// See also:
/// - docs/FINAL_10_PHASE_1_COMPLETE.md
library health;

export 'backend_health.dart';
export 'admin_repair_toolkit.dart';
export 'queue_status_ui.dart';
