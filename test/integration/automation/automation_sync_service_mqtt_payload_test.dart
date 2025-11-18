import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AutomationSyncService MQTT payload enrichment', () {
    test('injects placeholders and compat keys', () async {
      // TODO: Use fake driver and verify payload transformation
      expect(true, isTrue);
    }, skip: 'Pending driver/service wiring.');
  });
}

/*
SNIPPET (for future implementation):

class FakeMqttDriver extends MqttDriver {
  String? lastTopic;
  String? lastPayload;

  @override
  Future<bool> publishForDevice(Map<String, dynamic> protocolData, String payload) async {
    final cmdTopic = protocolData['cmdTopic'] as String? ?? protocolData['topic'] as String?;
    lastTopic = cmdTopic;
    lastPayload = payload;
    return true;
  }
}

test('injects deviceId placeholder and compat keys in MQTT payload', () async {
  final fakeDriver = FakeMqttDriver();
  final container = ProviderContainer(overrides: [
    automationDriverProvider.overrideWithValue(fakeDriver),
  ]);

  final protocolData = buildMqttProtocolData(
    broker: 'localhost',
    topic: 'home/bulb1/cmd',
    cmdTopic: 'home/bulb1/cmd',
    stateTopic: 'home/bulb1/state',
    // Template with placeholder
    payloadOn: '{"isOn":true, "deviceId":"${deviceId}"}',
    payloadOff: '{"isOn":false, "deviceId":"${deviceId}"}',
  );

  final op = PendingOp(
    opId: 'op-mqtt-1',
    entityId: 'uuid-123',
    entityType: 'device',
    opType: 'control',
    payload: {
      'deviceId': 'uuid-123',
      'action': 'turnOn',
      'protocolData': protocolData,
    },
  );
  await pending.put(op.opId, op);

  final svc = container.read(automationSyncServiceProvider);
  await svc.tryFlushOp(op);

  final parsed = jsonDecode(fakeDriver.lastPayload!);
  expect(parsed['deviceId'], 'bulb1'); // replaced from topic
  expect(parsed['id'], 'bulb1'); // alias added
  expect(parsed['isOn'], true);
  // Compatibility keys added
  expect(parsed['state'], 'ON');
  expect(parsed['power'], 1);
  expect(parsed['on'], true);
  expect(parsed['action'], 'turnOn');
});
*/
