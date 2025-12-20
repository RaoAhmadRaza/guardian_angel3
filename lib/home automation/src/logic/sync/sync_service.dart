import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:guardian_angel_fyp/persistence/models/pending_op.dart';
import '../../data/local_hive_service.dart';
import '../../network/api_client.dart';
import '../../utils/network_status_provider.dart';
import 'conflict_provider.dart';
import '../../data/hive_adapters/room_model_hive.dart';
import '../../data/hive_adapters/device_model_hive.dart';
import 'package:guardian_angel_fyp/services/lock_service.dart';

/// SyncService watches the pending ops box and attempts to flush queued operations
/// when online. It applies exponential backoff on repeated failures.
typedef Reader = T Function<T>(ProviderListenable<T>);

class SyncService {
  final Reader read;
  final LockService _lockService;
  late final Box<PendingOp> _pending;
  late final Box<PendingOp> _failed;
  static const String _lockName = 'sync_service_processing';

  SyncService(this.read, {LockService? lockService}) 
      : _lockService = lockService ?? LockService() {
    _init();
  }

  Future<void> _init() async {
    await _lockService.init();
    _pending = LocalHiveService.pendingOpsBox();
    _failed = LocalHiveService.failedOpsBox();
    _boxSub = _pending.watch().listen((_) => _processQueue());
    // Optional: periodic flush
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _processQueue());
  }

  StreamSubscription? _boxSub;
  Timer? _timer;

  void dispose() {
    _boxSub?.cancel();
    _timer?.cancel();
    _lockService.stopHeartbeat(_lockName);
    _lockService.releaseLock(_lockName);
  }

  Future<void> _processQueue() async {
    // Try to acquire distributed lock with heartbeat monitoring
    final acquired = await _lockService.acquireLock(_lockName, metadata: {
      'source': 'SyncService',
      'operation': 'processQueue',
    });
    
    if (!acquired) {
      // Another runner is processing or lock is held
      return;
    }
    
    // Start automatic heartbeat to keep lock alive during processing
    _lockService.startHeartbeat(_lockName);

    final isOnline = read(networkStatusProvider);
    if (!isOnline) {
      _lockService.stopHeartbeat(_lockName);
      await _lockService.releaseLock(_lockName);
      return;
    }

    try {
      // Work on a snapshot to avoid concurrent modification
      final ops = _pending.values.toList()
        ..sort((a, b) => a.queuedAt.compareTo(b.queuedAt));

      for (final op in ops) {
        try {
          await _executeOp(op);
          await _pending.delete(op.opId);
        } catch (e) {
          // Increment attempts and re-store, update lastAttemptAt
          final updatedOp = op.copyWith(
            attempts: op.attempts + 1,
            lastTriedAt: DateTime.now(),
          );

          if (updatedOp.attempts >= 5) {
            // Move to failed ops box for visibility and manual retry
            await _pending.delete(op.opId);
            await _failed.put(op.opId, updatedOp);
            // Don't delay further here; proceed to next op
            continue;
          } else {
            await _pending.put(op.opId, updatedOp);
            // Apply backoff up to 30s before next attempt
            final delayMs = min(30000, pow(2, updatedOp.attempts) * 1000).toInt();
            await Future.delayed(Duration(milliseconds: delayMs));
          }
        }
      }
    } finally {
      _lockService.stopHeartbeat(_lockName);
      await _lockService.releaseLock(_lockName);
    }
  }

  Future<void> _executeOp(PendingOp op) async {
    final api = read(apiClientProvider);
    final entityId = op.entityId ?? '';
    final entityType = op.entityType ?? 'unknown';
    try {
      switch (op.opType) {
        case 'create':
          if (entityType == 'room') {
            await api.createRoom(op.payload);
          } else {
            await api.createDevice(op.payload);
          }
          break;
        case 'update':
          if (entityType == 'room') {
            await api.updateRoom(entityId, op.payload);
          } else {
            await api.updateDevice(entityId, op.payload);
          }
          break;
        case 'delete':
          if (entityType == 'room') {
            await api.deleteRoom(entityId);
          } else {
            await api.deleteDevice(entityId);
          }
          break;
        case 'toggle':
          // device toggle
          await api.toggleDevice(entityId, op.payload['isOn'] as bool);
          break;
        default:
          throw Exception('Unknown opType ${op.opType}');
      }
    } on ConflictException catch (e) {
      // Attempt conflict resolution; may re-queue or update local with server
      await _handleConflict(op, e.serverEntity);
    }
  }

  Future<void> _handleConflict(PendingOp op, Map<String, dynamic> serverEntity) async {
    final entityId = op.entityId ?? '';
    final entityType = op.entityType ?? 'unknown';
    // Last-writer-wins by updatedAt; fallback to version if timestamps equal/unavailable
    DateTime? localUpdated;
    DateTime? remoteUpdated;
    try {
      final l = op.payload['updatedAt'];
      if (l is String) localUpdated = DateTime.tryParse(l);
      final r = serverEntity['updatedAt'];
      if (r is String) remoteUpdated = DateTime.tryParse(r);
    } catch (_) {}

    final localVersion = (op.payload['version'] as num?)?.toInt();
    final remoteVersion = (serverEntity['version'] as num?)?.toInt();

    bool remoteWins;
    if (localUpdated != null && remoteUpdated != null) {
      remoteWins = remoteUpdated.isAfter(localUpdated);
    } else if (localVersion != null && remoteVersion != null) {
      remoteWins = remoteVersion > localVersion;
    } else {
      // Default to remote-wins to avoid thrash
      remoteWins = true;
    }

    if (remoteWins) {
      // Accept server: update local storage and drop the op
      await _applyServerEntityToLocal(entityType, serverEntity);
      // no re-queue; resolution complete
      return;
    }

    // Local is newer; try optimistic replay by bumping version and merging maps
    final merged = Map<String, dynamic>.from(serverEntity);
    op.payload.forEach((key, value) {
      if (key == 'version') return; // we'll set below
      if (key == 'updatedAt') return;
      if (key == 'state' && value is Map && serverEntity['state'] is Map) {
        // Field-level merge for device state maps: prefer local keys present
        final mergedState = Map<String, dynamic>.from(serverEntity['state'] as Map);
        value.forEach((k, v) {
          mergedState[k] = v;
        });
        merged['state'] = mergedState;
      } else {
        // Primitive and other fields: prefer local change
        merged[key] = value;
      }
    });

    // Bump version and timestamp
    merged['version'] = (remoteVersion ?? 0) + 1;
    merged['updatedAt'] = DateTime.now().toIso8601String();

    // Re-queue as a fresh op to retry
    final newOp = PendingOp.forHomeAutomation(
      opId: 'op_${DateTime.now().millisecondsSinceEpoch}_$entityId',
      entityId: entityId,
      entityType: entityType,
      opType: op.opType,
      payload: merged,
      attempts: op.attempts + 1,
    );
    await _pending.put(newOp.opId, newOp);

    // If we've tried many times, surface to UI for manual resolution
    if (newOp.attempts >= 5) {
      read(conflictProvider.notifier).add(ConflictRecord(
        entityType: entityType,
        entityId: entityId,
        opType: op.opType,
        localPayload: op.payload,
        serverEntity: serverEntity,
        attempts: newOp.attempts,
      ));
    }
  }

  Future<void> _applyServerEntityToLocal(String entityType, Map<String, dynamic> server) async {
    if (entityType == 'room') {
      final box = LocalHiveService.roomBox();
      final model = RoomModelHive(
        id: server['id'] as String,
        name: server['name'] as String,
        iconId: server['iconId'] as String? ?? 'default',
        color: server['color'] as int? ?? 0xFF000000,
        createdAt: DateTime.tryParse(server['createdAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(server['updatedAt'] as String? ?? '') ?? DateTime.now(),
        version: (server['version'] as num?)?.toInt() ?? 0,
      );
      await box.put(model.id, model);
    } else {
      final box = LocalHiveService.deviceBox();
      final model = DeviceModelHive(
        id: server['id'] as String,
        roomId: server['roomId'] as String? ?? '',
        type: server['type'] as String? ?? 'bulb',
        name: server['name'] as String? ?? 'Device',
        isOn: server['isOn'] as bool? ?? false,
        state: Map<String, dynamic>.from(server['state'] as Map? ?? const {}),
        lastSeen: DateTime.tryParse(server['lastSeen'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(server['updatedAt'] as String? ?? '') ?? DateTime.now(),
        version: (server['version'] as num?)?.toInt() ?? 0,
      );
      await box.put(model.id, model);
    }
  }
}

/// Provider that instantiates and keeps a SyncService alive.
final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(ref.read);
  ref.onDispose(service.dispose);
  return service;
});
