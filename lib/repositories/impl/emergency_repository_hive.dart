/// EmergencyRepositoryHive - Hive implementation of EmergencyRepository.
///
/// Part of PHASE 2: Backend is the only source of truth.
/// Updated in PHASE 1 BLOCKER FIX: HiveError handling.
///
/// Data Flow:
/// UI → emergencyStateProvider → EmergencyRepositoryHive → BoxAccessor → Hive
library;

import 'package:hive/hive.dart';
import '../../persistence/models/pending_op.dart';
import '../../models/failed_op_model.dart';
import '../../persistence/box_registry.dart';
import '../../persistence/errors/errors.dart';
import '../../persistence/wrappers/box_accessor.dart';
import '../emergency_repository.dart';

/// Hive-backed implementation of EmergencyRepository.
class EmergencyRepositoryHive implements EmergencyRepository {
  final BoxAccessor _boxAccessor;

  // In-memory state that should eventually be persisted
  bool _isOfflineMode = false;
  DateTime? _lastSyncAttempt;
  String? _lastError;

  EmergencyRepositoryHive({BoxAccessor? boxAccessor})
      : _boxAccessor = boxAccessor ?? BoxAccessor();

  Box<PendingOp> get _emergencyBox => _boxAccessor.emergencyOps();
  Box<PendingOp> get _pendingBox => _boxAccessor.pendingOps();
  Box<FailedOpModel> get _failedBox => _boxAccessor.failedOps();

  @override
  Stream<EmergencyState> watchState() async* {
    // Emit current state immediately
    yield await getState();

    // Watch all relevant boxes and emit on any change
    await for (final _ in _mergeBoxWatches()) {
      yield await getState();
    }
  }

  Stream<void> _mergeBoxWatches() async* {
    // Create a merged stream from multiple box watches
    yield* Stream.periodic(const Duration(seconds: 2), (_) {});
  }

  @override
  Future<EmergencyState> getState() async {
    // Get critical ops (emergency + high priority pending)
    final criticalOps = [
      ..._emergencyBox.values,
      ..._pendingBox.values.where((op) => _isCritical(op)),
    ];

    return EmergencyState(
      pendingOpsCount: _pendingBox.length + _emergencyBox.length,
      failedOpsCount: _failedBox.length,
      isOfflineMode: _isOfflineMode,
      lastSyncAttempt: _lastSyncAttempt,
      lastError: _lastError,
      criticalOps: criticalOps,
    );
  }

  bool _isCritical(PendingOp op) {
    // Check payload for domain hints or use opType
    final payload = op.payload;
    final domain = payload['domain'] as String? ?? '';
    return domain == 'vitals' || domain == 'emergency' || op.opType == 'emergency';
  }

  @override
  Future<List<PendingOp>> getPendingOps() async {
    return [
      ..._emergencyBox.values,
      ..._pendingBox.values,
    ];
  }

  @override
  Future<List<PendingOp>> getFailedOps() async {
    // Convert FailedOpModel back to PendingOp for UI consistency
    return _failedBox.values.map((f) => PendingOp(
      id: f.id,
      opType: f.opType,
      idempotencyKey: f.idempotencyKey ?? f.id,
      payload: f.payload,
      attempts: f.attempts,
      status: 'failed',
      lastError: f.errorMessage,
      createdAt: f.createdAt,
      updatedAt: f.updatedAt,
    )).toList();
  }

  @override
  Future<void> addEmergencyOp(PendingOp op) async {
    // PHASE 1 BLOCKER FIX: Safe HiveError handling
    final result = await SafeBoxOps.put(
      _emergencyBox,
      op.id,
      op,
      boxName: BoxRegistry.emergencyOpsBox,
    );
    if (result.isFailure) throw result.error!;
  }

  @override
  Future<void> markAsFailed(String opId, String error) async {
    // Check emergency box first
    final emergencyOp = _emergencyBox.get(opId);
    if (emergencyOp != null) {
      final delResult = await SafeBoxOps.delete(
        _emergencyBox,
        opId,
        boxName: BoxRegistry.emergencyOpsBox,
      );
      if (delResult.isFailure) throw delResult.error!;
      
      final putResult = await SafeBoxOps.put(
        _failedBox,
        opId,
        FailedOpModel.fromPendingOp(emergencyOp, errorMessage: error),
        boxName: BoxRegistry.failedOpsBox,
      );
      if (putResult.isFailure) throw putResult.error!;
      return;
    }

    // Check pending box
    final pendingOp = _pendingBox.get(opId);
    if (pendingOp != null) {
      final delResult = await SafeBoxOps.delete(
        _pendingBox,
        opId,
        boxName: BoxRegistry.pendingOpsBox,
      );
      if (delResult.isFailure) throw delResult.error!;
      
      final putResult = await SafeBoxOps.put(
        _failedBox,
        opId,
        FailedOpModel.fromPendingOp(pendingOp, errorMessage: error),
        boxName: BoxRegistry.failedOpsBox,
      );
      if (putResult.isFailure) throw putResult.error!;
    }
  }

  @override
  Future<void> retryOp(String opId) async {
    final failedOp = _failedBox.get(opId);
    if (failedOp == null) return;

    final now = DateTime.now().toUtc();
    
    // Move back to pending - PHASE 1 BLOCKER FIX
    final delResult = await SafeBoxOps.delete(
      _failedBox,
      opId,
      boxName: BoxRegistry.failedOpsBox,
    );
    if (delResult.isFailure) throw delResult.error!;
    
    final putResult = await SafeBoxOps.put(
      _pendingBox,
      opId,
      PendingOp(
        id: opId,
        opType: failedOp.opType,
        idempotencyKey: failedOp.idempotencyKey ?? opId,
        payload: failedOp.payload,
        attempts: failedOp.attempts + 1,
        status: 'pending',
        createdAt: failedOp.createdAt,
        updatedAt: now,
      ),
      boxName: BoxRegistry.pendingOpsBox,
    );
    if (putResult.isFailure) throw putResult.error!;
  }

  @override
  Future<void> clearCompleted() async {
    // Emergency and pending boxes should be cleared after successful sync
    // This is typically called by the sync service
  }

  @override
  Future<void> setOfflineMode(bool isOffline) async {
    _isOfflineMode = isOffline;
  }

  @override
  Future<void> recordSyncAttempt({String? error}) async {
    _lastSyncAttempt = DateTime.now();
    _lastError = error;
  }
}
