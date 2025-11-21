// AutomationSyncService: watches pending ops and flushes control operations via drivers.

import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// hive: boxes accessed via LocalHiveService
import '../../automation/automation_providers.dart';
import '../../automation/device_protocol.dart';
import '../../automation/adapters/mqtt_driver.dart';
import '../../data/hive_adapters/pending_op_hive.dart';
import '../../data/hive_adapters/device_model_hive.dart';
import '../../data/local_hive_service.dart';
import 'package:guardian_angel_fyp/services/lock_service.dart';

class AutomationSyncService {
  final Ref ref;
  final LockService _lockService;
  StreamSubscription? _sub;
  Timer? _scanTimer;
  static const String _lockName = 'automation_sync_service_processing';
  
  AutomationSyncService(this.ref, {LockService? lockService})
      : _lockService = lockService ?? LockService() {
    _start();
  }

  Future<void> _start() async {
    await _lockService.init();
    // Initialize global driver once (non-fatal if fails; retries later)
    try {
      await ref.read(automationDriverProvider).init();
    } catch (_) {
      // ignore init errors; publish will attempt reconnect
    }

    // Initial scan
    unawaited(_processAll());

    // Watch for new/changed pending ops
    final box = LocalHiveService.pendingOpsBox();
    _sub = box.watch().listen((_) {
      unawaited(_processAll());
    });

    // Periodic retry with simple backoff gating. Keep this fairly responsive so
    // debounced control ops (e.g., intensity) can flush without long waits.
    _scanTimer = Timer.periodic(const Duration(milliseconds: 350), (_) => _processAll());
  }

  void dispose() {
    _sub?.cancel();
    _scanTimer?.cancel();
    _lockService.stopHeartbeat(_lockName);
    _lockService.releaseLock(_lockName);
  }

  /// Convenience: attempt an immediate non-blocking flush for a specific pending op id.
  Future<void> tryFlushPendingOpId(String opId) async {
    final box = LocalHiveService.pendingOpsBox();
    final op = box.get(opId);
    if (op == null) return;
    unawaited(tryFlushOp(op));
  }

  Future<void> _processAll() async {
    // Try to acquire distributed lock with heartbeat monitoring
    final acquired = await _lockService.acquireLock(_lockName, metadata: {
      'source': 'AutomationSyncService',
      'operation': 'processAll',
    });
    
    if (!acquired) {
      // Another runner is processing or lock is held
      return;
    }
    
    // Start automatic heartbeat to keep lock alive during processing
    _lockService.startHeartbeat(_lockName);
    
    try {
      final box = LocalHiveService.pendingOpsBox();
      // Snapshot and sort to preserve global order
      final ops = box.values.toList()
        ..sort((a, b) => a.queuedAt.compareTo(b.queuedAt));

    // Coalesce frequent intensity updates per device: keep only the latest
    // 'setIntensity' control op for each device. Older ones will be dropped
    // before publish to avoid flooding brokers/backends.
    final Map<String, PendingOp> latestIntensityByDevice = {};
    for (final op in ops) {
      if (op.entityType != 'device') continue;
      if (op.opType != 'control') continue;
      final payload = op.payload;
      final action = payload['action'] as String?;
      if (action != 'setIntensity') continue;
      final deviceId = (payload['deviceId'] as String?) ?? (payload['id'] as String?);
      if (deviceId == null) continue;
      final existing = latestIntensityByDevice[deviceId];
      if (existing == null || existing.queuedAt.isBefore(op.queuedAt)) {
        latestIntensityByDevice[deviceId] = op;
      }
    }

    // Debounce window for intensity to allow rapid slider updates to settle
    const debounceWindow = Duration(milliseconds: 150);

    for (final op in ops) {
      // Only device control ops (standardized 'control').
      // The general SyncService will handle legacy 'toggle' for backend persistence.
      if (op.entityType != 'device') continue;
      if (op.opType != 'control') continue;

      // Backoff gating
      final backoffSec = _backoffSeconds(op.attempts);
      final due = op.queuedAt.add(Duration(seconds: backoffSec));
      if (DateTime.now().isBefore(due)) continue;

      // If this is a control/setIntensity and not the latest for the device, drop it
      if (op.opType == 'control') {
        final payload = op.payload;
        final action = payload['action'] as String?;
        if (action == 'setIntensity') {
          final deviceId = (payload['deviceId'] as String?) ?? (payload['id'] as String?);
          final latest = (deviceId != null) ? latestIntensityByDevice[deviceId] : null;
          if (latest != null && latest.opId != op.opId) {
            // Remove older duplicate intensity ops
            await box.delete(op.opId);
            continue;
          }
          // Latest intensity op: if very fresh, wait a bit for possible further updates
          final age = DateTime.now().difference(op.queuedAt);
          if (age < debounceWindow) {
            // Skip for now; periodic timer will pick it up on next tick
            continue;
          }
        }
      }

      await tryFlushOp(op);
      }
    } finally {
      _lockService.stopHeartbeat(_lockName);
      await _lockService.releaseLock(_lockName);
    }
  }

  int _backoffSeconds(int attempts) {
    final a = attempts.clamp(0, 6);
    final v = 1 << a; // 1,2,4,8,16,32,64
    return v > 60 ? 60 : v;
  }

  Future<void> tryFlushOp(PendingOp op) async {
    final pendingBox = LocalHiveService.pendingOpsBox();
    final payload = op.payload;

    // Extract device id and action
    final deviceId = (payload['deviceId'] as String?) ?? (payload['id'] as String?);
    if (deviceId == null) {
      // malformed; drop after a few attempts
      op.attempts += 1;
      if (op.attempts > 3) await pendingBox.delete(op.opId); else await pendingBox.put(op.opId, op);
      return;
    }
    String? action = payload['action'] as String?;
    if (action == null && payload.containsKey('isOn')) {
      action = (payload['isOn'] == true) ? 'turnOn' : 'turnOff';
    }

    // Attempt to get protocolData either from payload or from device record
    Map<String, dynamic>? protocolData = (payload['protocolData'] as Map?)?.cast<String, dynamic>();
    protocolData ??= _protocolDataFromDevice(deviceId);

    try {
      if (protocolData != null && isProtocol(protocolData, Protocols.mqtt)) {
        // Normalize legacy MQTT maps to ensure cmd/state topics are present
        protocolData = normalizeMqttProtocolData(Map<String, dynamic>.from(protocolData));
        // MQTT path: determine payload string
        final mqtt = ref.read(automationDriverProvider);
        if (mqtt is! MqttDriver) {
          // Fallback: create an ad-hoc MQTT driver from protocolData
          final broker = protocolData[ProtocolDataKeys.broker] as String;
          final port = (protocolData[ProtocolDataKeys.port] as int?) ?? 1883;
          await MqttDriver(broker: broker, port: port).init();
        }
        final publishDriver = (mqtt is MqttDriver) ? mqtt : MqttDriver(broker: protocolData[ProtocolDataKeys.broker] as String, port: (protocolData[ProtocolDataKeys.port] as int?) ?? 1883);
        // Prefer new cmdTopic key; fall back to legacy topic.
        final cmdTopic = (protocolData['cmdTopic'] as String?) ?? (protocolData[ProtocolDataKeys.topic] as String?);
        final stateTopic = (protocolData['stateTopic'] as String?) ?? (protocolData[ProtocolDataKeys.topic] as String?);
        // Derive a protocol-facing device id from topics (preferred by many simulators)
        final protocolDeviceId = _deriveDeviceIdFromTopics(cmdTopic, stateTopic) ?? deviceId;
        String payloadString = payload['payloadString'] as String? ?? '';
        if (payloadString.isEmpty) {
          if (action == 'turnOn' && cmdTopic != null) {
            payloadString = (protocolData[ProtocolDataKeys.payloadOn] as String?) ?? jsonEncode({'deviceId': protocolDeviceId, 'isOn': true});
          } else if (action == 'turnOff' && cmdTopic != null) {
            payloadString = (protocolData[ProtocolDataKeys.payloadOff] as String?) ?? jsonEncode({'deviceId': protocolDeviceId, 'isOn': false});
          } else if (action == 'setIntensity' && cmdTopic != null) {
            final template = (protocolData[ProtocolDataKeys.payloadSet] as String?) ?? r'{"level":${value}}';
            payloadString = applyValueTemplate(template, (payload['value'] as int?) ?? 0);
          } else {
            payloadString = jsonEncode({'deviceId': protocolDeviceId, 'action': action});
          }
        }
        // Replace placeholders ${deviceId} if present in template
        if (payloadString.contains(r'${deviceId}')) {
          payloadString = payloadString.replaceAll(r'${deviceId}', protocolDeviceId);
        }
        // If payload is JSON and lacks deviceId, inject it for simulators that require it
        try {
          final parsed = jsonDecode(payloadString);
          if (parsed is Map) {
            // Ensure deviceId is present
            if (!parsed.containsKey('deviceId')) {
              parsed['deviceId'] = protocolDeviceId;
            }
            // Mirror id alias if not present
            if (!parsed.containsKey('id')) {
              parsed['id'] = protocolDeviceId;
            }
            // Derive desired on/off from any of the common keys
            bool? desiredOn;
            if (parsed['isOn'] is bool) {
              desiredOn = parsed['isOn'] as bool;
            } else if (parsed['state'] is String) {
              final s = (parsed['state'] as String).toUpperCase();
              if (s == 'ON') desiredOn = true; else if (s == 'OFF') desiredOn = false;
            } else if (parsed['on'] is bool) {
              desiredOn = parsed['on'] as bool;
            } else if (parsed['power'] is num) {
              desiredOn = (parsed['power'] as num) != 0;
            }
            // Broad compatibility: ensure consistent keys and action when we can infer desired state
            if (desiredOn != null) {
              parsed.putIfAbsent('isOn', () => desiredOn!);
              parsed.putIfAbsent('state', () => desiredOn! ? 'ON' : 'OFF');
              parsed.putIfAbsent('power', () => desiredOn! ? 1 : 0);
              parsed.putIfAbsent('on', () => desiredOn!);
              parsed.putIfAbsent('action', () => desiredOn! ? 'turnOn' : 'turnOff');
            }
            payloadString = jsonEncode(parsed);
          }
        } catch (_) {
          // Non-JSON payloads (e.g., plain ON/OFF) are left as-is
        }
        await publishDriver.publishForDevice(protocolData, payloadString);
      } else {
        // High-level API path (Tuya/Cloud/Mock/...)
        final driver = ref.read(automationDriverProvider);
        if (action == 'turnOn') {
          await driver.turnOn(deviceId);
        } else if (action == 'turnOff') {
          await driver.turnOff(deviceId);
        } else if (action == 'setIntensity') {
          await driver.setIntensity(deviceId, (payload['value'] as int?) ?? 0);
        } else {
          // Unknown action: consider success to avoid deadlocks
        }
      }
      await pendingBox.delete(op.opId);
    } catch (e) {
      op.attempts = (op.attempts) + 1;
      await pendingBox.put(op.opId, op);
    }
  }

  String? _deriveDeviceIdFromTopics(String? cmdTopic, String? stateTopic) {
    String? pick = stateTopic ?? cmdTopic;
    if (pick == null || pick.isEmpty) return null;
    final parts = pick.split('/');
    if (parts.isEmpty) return null;
    if (parts.length >= 2 && (parts.last.toLowerCase() == 'state' || parts.last.toLowerCase() == 'cmd' || parts.last.toLowerCase() == 'set')) {
      return parts[parts.length - 2];
    }
    return parts.last;
  }

  Map<String, dynamic>? _protocolDataFromDevice(String deviceId) {
    final box = LocalHiveService.deviceBox();
    final h = box.get(deviceId);
    if (h is DeviceModelHive) {
      final state = h.state;
      final p = state['protocolData'];
      if (p is Map) return p.cast<String, dynamic>();
    }
    return null;
  }
}

/// Provider to access and start the sync service.
final automationSyncServiceProvider = Provider<AutomationSyncService>((ref) {
  final svc = AutomationSyncService(ref);
  ref.onDispose(svc.dispose);
  return svc;
});
