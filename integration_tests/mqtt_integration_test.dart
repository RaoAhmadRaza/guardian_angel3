// Requires a running MQTT broker on localhost:1883 (see docker-compose in integration_tests/docker/mosquitto)
// Run: docker compose -f integration_tests/docker/mosquitto/docker-compose.yml up -d
// Then: flutter test integration_tests/mqtt_integration_test.dart

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:guardian_angel_fyp/home%20automation/src/automation/adapters/mqtt_driver.dart';

Future<bool> _canConnect() async {
  try {
    final c = MqttServerClient('localhost', 'probe');
    c.logging(on: false);
    c.keepAlivePeriod = 10;
    await c.connect();
    c.disconnect();
    return true;
  } catch (_) {
    return false;
  }
}

void main() {
  test('MQTT publish end-to-end reaches subscriber (requires local broker)', () async {
    final ok = await _canConnect();
    if (!ok) return; // skip if broker is not available

    final topic = 'integration/test/topic';

    // Subscriber client
    final sub = MqttServerClient('localhost', 'sub');
    sub.logging(on: false);
    await sub.connect();
    final completer = Completer<String>();
    sub.updates!.listen((messages) {
      for (final m in messages) {
        final p = m.payload as MqttPublishMessage;
        final s = MqttPublishPayload.bytesToStringAsString(p.payload.message);
        if (m.topic == topic) {
          completer.complete(s);
        }
      }
    });
    sub.subscribe(topic, MqttQos.atLeastOnce);

    // Publisher via our driver
    final driver = MqttDriver(broker: 'localhost');
    await driver.init();
    await driver.publishForDevice({'topic': topic, 'deviceId': 'dX'}, 'hello');

    final payload = await completer.future.timeout(const Duration(seconds: 5));
    expect(payload, 'hello');

    sub.disconnect();
    await driver.dispose();
  });
}
