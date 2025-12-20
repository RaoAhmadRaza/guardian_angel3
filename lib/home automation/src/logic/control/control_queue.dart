import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian_angel_fyp/persistence/models/pending_op.dart';
import '../../data/local_hive_service.dart';

/// Debounced control queue to reduce write pressure to the pending ops box
/// when users scrub sliders rapidly (e.g., brightness/fan speed).
///
/// Contract:
/// - queueSetIntensity(deviceId, value): schedules a single PendingOp 'control'
///   with action 'setIntensity' after a short debounce window per device.
/// - Writes are batched across devices via putAll.
/// - Order per device is preserved: only the latest intensity is emitted,
///   and toggle/other actions should be enqueued separately (not debounced here).
class ControlQueue {
  final Ref ref;
  ControlQueue(this.ref);

  // Per-device debounce state
  final Map<String, _IntensityDebounce> _intensity = {};

  // Write batching buffer
  final Map<String, PendingOp> _writeBuffer = {};
  bool _flushScheduled = false;

  void dispose() {
    for (final d in _intensity.values) {
      d.dispose();
    }
    _intensity.clear();
  }

  void queueSetIntensity(String deviceId, int value, {Duration debounce = const Duration(milliseconds: 150)}) {
    final d = _intensity.putIfAbsent(deviceId, () => _IntensityDebounce(deviceId, _enqueue));
    d.update(value, debounce);
  }

  // Enqueue a control op into the write buffer and schedule a batched flush
  void _enqueue(PendingOp op) {
    _writeBuffer[op.opId] = op;
    if (_flushScheduled) return;
    _flushScheduled = true;
    // Micro-batch shortly to collect multiple ops
    Timer(const Duration(milliseconds: 10), _flushNow);
  }

  Future<void> _flushNow() async {
    _flushScheduled = false;
    if (_writeBuffer.isEmpty) return;
    final pending = LocalHiveService.pendingOpsBox();
    final toWrite = Map<String, PendingOp>.fromEntries(
      _writeBuffer.values.map((op) => MapEntry(op.opId, op)),
    );
    _writeBuffer.clear();
    await pending.putAll(toWrite);
  }
}

class _IntensityDebounce {
  final String deviceId;
  final void Function(PendingOp) onReady;
  Timer? _t;
  int _lastValue = 0;
  _IntensityDebounce(this.deviceId, this.onReady);

  void update(int value, Duration debounce) {
    _lastValue = value.clamp(0, 100);
    _t?.cancel();
    _t = Timer(debounce, _fire);
  }

  void _fire() {
    final now = DateTime.now();
    final opId = 'op_${now.millisecondsSinceEpoch}_$deviceId';
    final op = PendingOp.forHomeAutomation(
      opId: opId,
      entityId: deviceId,
      entityType: 'device',
      opType: 'control',
      payload: {
        'deviceId': deviceId,
        'action': 'setIntensity',
        'value': _lastValue,
      },
    );
    onReady(op);
  }

  void dispose() {
    _t?.cancel();
  }
}

final controlQueueProvider = Provider<ControlQueue>((ref) {
  final q = ControlQueue(ref);
  ref.onDispose(q.dispose);
  return q;
});
