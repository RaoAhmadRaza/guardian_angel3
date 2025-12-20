// lib/src/logic/sync/control_op_helper.dart

import 'package:uuid/uuid.dart';
import 'package:hive/hive.dart';
import 'package:guardian_angel_fyp/persistence/models/pending_op.dart';

/// Standardized control op payload shape:
/// {
///   "operationId": "<uuid>",
///   "clientId": "<client-id>",
///   "deviceId": "<device-id>",
///   "action": "turnOn" | "turnOff" | "setIntensity" | "toggle" | "custom",
///   "value": <optional numeric/string payload>,
///   "protocolData": { ... } // optional, if you want to inline it
///   "meta": { ... } // optional extra metadata
/// }
///
/// The helper writes a PendingOp into the provided pendingBox and returns the created op.
class ControlOpHelper {
  static final _uuid = Uuid();

  /// Enqueue a control operation in the pending ops Hive box.
  /// - [pendingBox] is the Hive box for PendingOp (Box<PendingOp>)
  /// - [deviceId] target device id
  /// - [action] semantic action string (turnOn/turnOff/setIntensity/toggle/custom)
  /// - [value] optional numeric/string payload (e.g., intensity)
  /// - [protocolData] optional protocolData snapshot (map) — you can omit and the SyncService will read from device record
  /// - [clientId] optional client id (defaults to UUID)
  static PendingOp enqueueControlOp({
    required Box<PendingOp> pendingBox,
    required String deviceId,
    required String action,
    Object? value,
    Map<String, dynamic>? protocolData,
    String? clientId,
    Map<String, dynamic>? meta,
  }) {
    final opId = 'ctrl_${_uuid.v4()}';
    final operationId = _uuid.v4();
    final payload = <String, dynamic>{
      'operationId': operationId,
      'clientId': clientId ?? _uuid.v4(),
      'deviceId': deviceId,
      'action': action,
      if (value != null) 'value': value,
      if (protocolData != null) 'protocolData': protocolData,
      if (meta != null) 'meta': meta,
    };

    final pending = PendingOp.forHomeAutomation(
      opId: opId,
      entityId: deviceId,
      entityType: 'device',
      opType: 'control',
      payload: payload.cast<String, dynamic>(),
      queuedAt: DateTime.now(),
      attempts: 0,
    );

    pendingBox.put(pending.opId, pending);
    return pending;
  }
}
