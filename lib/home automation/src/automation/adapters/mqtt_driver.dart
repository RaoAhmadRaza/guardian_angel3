import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:uuid/uuid.dart';
import '../interfaces/automation_interface.dart';
import '../automation_observability.dart';

/// Copy-pasteable MQTT driver with a production-friendly structure.
///
/// Note: Prefer calling [publishForDevice] using a device's protocolData
/// instead of direct [turnOn]/[turnOff]/[setIntensity]; those can be wired
/// via templates in protocolData.
class MqttDriver implements AutomationDriver {
  final String broker;
  final int port;
  final String clientId;
  final String? username;
  final String? password;
  final String? usernameKey;
  final String? passwordKey;
  final Future<String?> Function(String key)? secretResolver;
  final bool useTls;
  final int keepAliveSeconds;

  late final MqttServerClient _client;
  Object? _clientOverride; // test-only client stub
  final Map<String, StreamController<DeviceEvent>> _controllers = {};
  final Map<String, DeviceState> _stateCache = {};
  bool _connected = false;
  AutomationConnection _status = AutomationConnection.disconnected;
  final _statusCtrl = StreamController<AutomationConnection>.broadcast();
  final Set<String> _subscribedTopics = <String>{};
  final void Function(String message)? onLog;
  final void Function(DeviceEvent event)? onEvent;

  MqttDriver({
    required this.broker,
    this.port = 1883,
    String? clientId,
    this.username,
    this.password,
    this.usernameKey,
    this.passwordKey,
    this.secretResolver,
    this.useTls = false,
    this.keepAliveSeconds = 20,
    MqttServerClient? client,
    this.onLog,
    this.onEvent,
  }) : clientId = clientId ?? const Uuid().v4() {
    _client = client ?? MqttServerClient(broker, this.clientId);
    _client.port = port;
    _client.keepAlivePeriod = keepAliveSeconds;
    _client.logging(on: false);
    _client.onConnected = _onConnected;
    _client.onDisconnected = _onDisconnected;
    _client.onSubscribed = _onSubscribed;
    _client.secure = useTls;
  }

  // Test-only constructor allowing a lightweight client stub to be injected.
  MqttDriver.testCtor({
    required this.broker,
    int this.port = 1883,
    String? clientId,
    Object? client,
    this.onLog,
    this.onEvent,
  })  : clientId = clientId ?? 'test-client',
        username = null,
        password = null,
        usernameKey = null,
        passwordKey = null,
        secretResolver = null,
        useTls = false,
        keepAliveSeconds = 20 {
    // create a dummy client to satisfy late init, but we won't use it in test mode
    _client = MqttServerClient(broker, this.clientId);
    _clientOverride = client;
  }

  @override
  Future<void> init() async {
    if (_clientOverride != null) {
      // test mode: mark connected and emit status
      _connected = true;
      _setStatus(AutomationConnection.connected);
      return;
    }
    _setStatus(AutomationConnection.connecting);
    onLog?.call('MQTT: init connecting to $broker:$port (tls=$useTls)');
    // Resolve secrets if keys provided
    String? user = username;
    String? pass = password;
    if (secretResolver != null) {
      if (user == null && usernameKey != null) {
        user = await secretResolver!(usernameKey!);
      }
      if (pass == null && passwordKey != null) {
        pass = await secretResolver!(passwordKey!);
      }
    }
    final connMsg = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean(); // or set persistent session
    _client.connectionMessage = connMsg;

    try {
  final _ = await _client.connect(user, pass);
      if (_client.connectionStatus?.state == MqttConnectionState.connected) {
        _connected = true;
        _setStatus(AutomationConnection.connected);
        onLog?.call('MQTT: connected as $clientId');
        _client.updates?.listen(_onMqttMessages);
      } else {
        _connected = false;
        _client.disconnect();
        _setStatus(AutomationConnection.disconnected);
        throw Exception('MQTT connection failed: ${_client.connectionStatus}');
      }
    } catch (e) {
      _connected = false;
      _setStatus(AutomationConnection.disconnected);
      onLog?.call('MQTT: connect error $e');
      rethrow;
    }
  }

  void _onConnected() {
    _connected = true;
    _setStatus(AutomationConnection.connected);
  }

  void _onDisconnected() {
    _connected = false;
    _setStatus(AutomationConnection.disconnected);
    // handle reconnection/backoff externally or here
  }

  void _onSubscribed(String topic) {
    // noop or logging
    _subscribedTopics.add(topic);
    onLog?.call('MQTT: subscribed $topic');
  }

  void _onMqttMessages(List<MqttReceivedMessage<MqttMessage?>>? rec) {
    if (rec == null) return;
    for (final msg in rec) {
      final payload = msg.payload;
      if (payload is MqttPublishMessage) {
        final pt = MqttPublishPayload.bytesToStringAsString(payload.payload.message);
        final topic = msg.topic;
        try {
          final parsed = jsonDecode(pt);
          // assume payload contains {"deviceId":"id","isOn":true,"level":80, ...}
          if (parsed is Map && parsed['deviceId'] != null) {
            final deviceId = parsed['deviceId'] as String;
            final state = DeviceState(
              isOn: parsed['isOn'] == true,
              level: parsed['level'] is int ? parsed['level'] as int : null,
              raw: parsed.cast<String, dynamic>(),
            );
            _stateCache[deviceId] = state;
            final event = DeviceEvent(deviceId: deviceId, state: state);
            _controllers[deviceId]?.add(event);
            onEvent?.call(event);
          } else if (parsed is Map) {
            // No explicit deviceId: derive from topic and common fields
            final deviceId = _deriveDeviceIdFromTopic(topic);
            final isOn = _extractIsOn(parsed);
            final level = _extractLevel(parsed);
            final state = DeviceState(isOn: isOn, level: level, raw: parsed.cast<String, dynamic>());
            _stateCache[deviceId] = state;
            final event = DeviceEvent(deviceId: deviceId, state: state);
            _controllers[deviceId]?.add(event);
            onEvent?.call(event);
          } else {
            // Non-map JSON value; fall back to raw handling below
            throw const FormatException('Non-map JSON');
          }
        } catch (e) {
          // not JSON: treat as raw ON/OFF string
          final deviceId = topic; // or map topic->deviceId externally
          final isOn = pt.toUpperCase() == 'ON' || pt.toLowerCase() == 'true';
          final state = DeviceState(isOn: isOn, level: null, raw: {'raw': pt});
          _stateCache[deviceId] = state;
          final event = DeviceEvent(deviceId: deviceId, state: state);
          _controllers[deviceId]?.add(event);
          onEvent?.call(event);
        }
      }
    }
  }

  String _deriveDeviceIdFromTopic(String topic) {
    final parts = topic.split('/');
    if (parts.isEmpty) return topic;
    if (parts.length >= 2 && (parts.last.toLowerCase() == 'state' || parts.last.toLowerCase() == 'status')) {
      return parts[parts.length - 2];
    }
    return parts.last;
  }

  bool _extractIsOn(Map parsed) {
    final v = parsed['isOn'] ?? parsed['state'] ?? parsed['power'] ?? parsed['on'];
    if (v is bool) return v;
    if (v is String) {
      final s = v.toLowerCase();
      if (s == 'on' || s == 'true' || s == '1') return true;
      if (s == 'off' || s == 'false' || s == '0') return false;
    }
    return false;
  }

  int? _extractLevel(Map parsed) {
    final v = parsed['level'] ?? parsed['brightness'] ?? parsed['dim'] ?? parsed['intensity'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) {
      final p = int.tryParse(v);
      return p;
    }
    return null;
  }

  Future<void> _ensureSubscribed(String topic, String deviceId) async {
    if (_clientOverride != null) {
      try {
        // allow stub to implement subscribe(topic, qos)
        ( _clientOverride as dynamic ).subscribe(topic, MqttQos.atLeastOnce);
      } catch (_) {}
      _subscribedTopics.add(topic);
      _controllers.putIfAbsent(deviceId, () => StreamController<DeviceEvent>.broadcast());
      return;
    }
    if (!_connected) {
      await _tryReconnect();
    }
    // subscribe once per topic/device
    _client.subscribe(topic, MqttQos.atLeastOnce);
    _subscribedTopics.add(topic);
    _controllers.putIfAbsent(deviceId, () => StreamController<DeviceEvent>.broadcast());
  }

  Future<void> _tryReconnect() async {
    if (_connected) return;
    // basic linear backoff, enhance with exponential backoff
    var tries = 0;
    while (!_connected && tries < 5) {
      try {
        onLog?.call('MQTT: reconnect attempt ${tries + 1}');
        await init();
      } catch (e) {
        tries++;
        await Future.delayed(Duration(seconds: 1 << tries));
      }
    }
  }

  Future<void> _publish(String topic, String payload, {MqttQos qos = MqttQos.atLeastOnce, bool retain = false}) async {
    if (_clientOverride != null) {
      try {
        final builder = MqttClientPayloadBuilder();
        builder.addString(payload);
        onLog?.call('MQTT[test]: publish $topic retain=$retain qos=$qos len=${payload.length}');
        ( _clientOverride as dynamic ).publishMessage(topic, qos, builder.payload!, retain: retain);
        return;
      } catch (e) {
        onLog?.call('MQTT[test]: publish error $e');
        rethrow;
      }
    }
    if (!_connected) await _tryReconnect();
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    onLog?.call('MQTT: publish $topic retain=$retain qos=$qos payload=${payload.length}B');
    _client.publishMessage(topic, qos, builder.payload!, retain: retain);
  }

  @override
  Future<bool> turnOn(String deviceId) async {
    // deviceId must map to topic from protocolData stored in DeviceModel.state
    throw UnimplementedError('Use per-device factory or pass topic in call');
  }

  @override
  Future<bool> turnOff(String deviceId) async {
    // deviceId must map to topic from protocolData stored in DeviceModel.state
    throw UnimplementedError('Use per-device factory or pass topic in call');
  }

  /// Per-project integration: prefer factory usage where caller provides topic+payload
  Future<bool> publishForDevice(Map<String, dynamic> protocolData, String payload) async {
    // Normalize legacy maps (topic only) to cmd/state
    protocolData = Map<String, dynamic>.from(protocolData); // defensive copy
    if (protocolData['protocol'] == 'mqtt' && protocolData['cmdTopic'] == null) {
      final legacyTopic = protocolData['topic'];
      if (legacyTopic is String) {
        protocolData['cmdTopic'] = legacyTopic;
        protocolData['stateTopic'] = legacyTopic;
      }
    }
    final cmdTopic = protocolData['cmdTopic'] as String? ?? protocolData['topic'] as String;
    final stateTopic = protocolData['stateTopic'] as String?; // may equal cmdTopic
    final qos = (protocolData['qos'] as int?) ?? 1;
    final retain = (protocolData['retain'] as bool?) ?? false;
    final deviceId = protocolData['deviceId'] as String? ?? cmdTopic;
    // Subscribe to command topic (for echo or retained state)
    await _ensureSubscribed(cmdTopic, deviceId);
    // Subscribe separately to state topic when distinct
    if (stateTopic != null && stateTopic != cmdTopic) {
      await _ensureSubscribed(stateTopic, deviceId);
    }
    await _publish(cmdTopic, payload, qos: qos == 0 ? MqttQos.atMostOnce : MqttQos.atLeastOnce, retain: retain);
    return true;
  }

  @override
  Future<DeviceState> getState(String deviceId) async {
    return _stateCache[deviceId] ?? DeviceState(isOn: false, level: null, raw: null);
  }

  @override
  Stream<DeviceEvent> watchDevice(String deviceId) {
    final controller = _controllers.putIfAbsent(deviceId, () => StreamController<DeviceEvent>.broadcast());
    return controller.stream;
  }

  @override
  Future<bool> setIntensity(String deviceId, int value) async {
    throw UnimplementedError('Use publishForDevice with payload template replacement');
  }

  @override
  Future<void> dispose() async {
    for (final c in _controllers.values) {
      await c.close();
    }
    _client.disconnect();
    _statusCtrl.close();
  }

  void _setStatus(AutomationConnection s) {
    _status = s;
    if (!_statusCtrl.isClosed) {
      _statusCtrl.add(s);
    }
  }

  AutomationConnection get currentStatus => _status;
  Stream<AutomationConnection> get statusStream => _statusCtrl.stream;
  List<String> get subscribedTopics => _subscribedTopics.toList(growable: false);
}
