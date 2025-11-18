import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/device_model.dart';
import '../../data/repositories/device_repository.dart';
import '../providers/sync_providers.dart';
import '../sync/sync_models.dart';

/// Per-room devices controller with optimistic updates and stream sync.
class DevicesController extends StateNotifier<AsyncValue<List<DeviceModel>>> {
  final Ref read;
  final DeviceRepository repo;
  final String roomId;
  StreamSubscription<List<DeviceModel>>? _sub;

  DevicesController(this.read, this.repo, this.roomId) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final devices = await repo.getDevicesForRoom(roomId);
      state = AsyncValue.data(devices);
      _sub = repo.watchDevicesForRoom(roomId).listen((devices) {
        state = AsyncValue.data(devices);
      });
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async => _init();

  Future<void> addDevice(DeviceModel device) async {
    final list = state.value ?? [];
    // mark syncing
    _bumpSync(start: true);
    state = AsyncValue.data([...list, device]); // optimistic
    try {
      await repo.createDevice(device);
      _bumpSync(success: true);
    } catch (e, st) {
      _bumpSync(error: e.toString());
      state = AsyncValue.error(e, st);
      await _init();
    }
  }

  Future<void> updateDevice(DeviceModel device) async {
    final list = state.value ?? [];
    final idx = list.indexWhere((d) => d.id == device.id);
    if (idx == -1) return;
    _bumpSync(start: true);
    final optimistic = [...list]..[idx] = device;
    state = AsyncValue.data(optimistic);
    try {
      await repo.updateDevice(device);
      _bumpSync(success: true);
    } catch (e, st) {
      _bumpSync(error: e.toString());
      state = AsyncValue.error(e, st);
      await _init();
    }
  }

  Future<void> deleteDevice(String deviceId) async {
    final list = state.value ?? [];
    _bumpSync(start: true);
    final optimistic = list.where((d) => d.id != deviceId).toList();
    state = AsyncValue.data(optimistic);
    try {
      await repo.deleteDevice(deviceId);
      _bumpSync(success: true);
    } catch (e, st) {
      _bumpSync(error: e.toString());
      state = AsyncValue.error(e, st);
      await _init();
    }
  }

  Future<void> toggleDevice(String deviceId, bool newValue) async {
    final list = state.value ?? [];
    final idx = list.indexWhere((d) => d.id == deviceId);
    if (idx == -1) return;
    // mark pending and syncing
    _markPending(deviceId, pending: true);
    _bumpSync(start: true);
    final old = list[idx];
    final updated = old.copyWith(isOn: newValue);
    final optimistic = [...list]..[idx] = updated;
    state = AsyncValue.data(optimistic);
    try {
      await repo.toggleDevice(deviceId, newValue);
      // update lastSeen if needed by forcing update
      await repo.updateDevice(updated.copyWith(lastSeen: DateTime.now()));
      _markPending(deviceId, pending: false);
      _bumpSync(success: true);
    } catch (e, st) {
      final current = state.value ?? <DeviceModel>[];
      final rollback = List<DeviceModel>.from(current);
      if (idx >= 0 && idx < rollback.length) {
        rollback[idx] = old;
      }
      state = AsyncValue.data(rollback);
      state = AsyncValue.error(e, st);
      _markPending(deviceId, pending: false);
      _bumpSync(error: e.toString());
      await _init();
    }
  }

  void _markPending(String deviceId, {required bool pending}) {
    final notifier = read.read(devicesPendingOpsProvider(roomId).notifier);
    final current = {...notifier.state};
    if (pending) {
      current.add(deviceId);
    } else {
      current.remove(deviceId);
    }
    notifier.state = current;
  }

  void _bumpSync({bool start = false, bool success = false, String? error}) {
    final syncNotifier = read.read(roomSyncStateProvider(roomId).notifier);
    final s = syncNotifier.state;
    if (start) {
      syncNotifier.state = s.copyWith(
        status: SyncStatus.syncing,
        pending: (s.pending + 1),
        lastError: null,
      );
      return;
    }
    if (success) {
      final left = (s.pending - 1).clamp(0, 1 << 30);
      syncNotifier.state = s.copyWith(
        status: left == 0 ? SyncStatus.idle : SyncStatus.syncing,
        pending: left,
        lastError: null,
        lastSuccessAt: DateTime.now(),
      );
      return;
    }
    if (error != null) {
      final left = (s.pending - 1).clamp(0, 1 << 30);
      syncNotifier.state = s.copyWith(
        status: SyncStatus.failed,
        pending: left,
        lastError: error,
      );
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
