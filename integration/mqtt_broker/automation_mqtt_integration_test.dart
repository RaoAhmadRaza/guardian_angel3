// integration/mqtt_broker/automation_mqtt_integration_test.dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:guardian_angel_fyp/home%20automation/src/automation/adapters/mqtt_driver.dart';
import 'package:hive_test/hive_test.dart';
import 'package:hive/hive.dart';
import 'package:guardian_angel_fyp/home%20automation/src/data/hive_adapters/device_model_hive.dart';

void main() {
  setUpAll(() async {
    await setUpTestHive();
    try { Hive.registerAdapter(DeviceModelHiveAdapter()); } catch (_) {}
  });

  tearDownAll(() async {
    await tearDownTestHive();
  });

  test('e2e mqtt publish & receive', () async {
    final host = '127.0.0.1';
    final topic = 'test/integration/light1';

    // Subscriber to verify published payloads
    final subscriber = MqttServerClient(host, 'test_sub');
    subscriber.logging(on: false);
    await subscriber.connect();
    subscriber.subscribe(topic, MqttQos.atLeastOnce);

    final completer = Completer<bool>();
    subscriber.updates?.listen((msgs) {
      if (msgs.isEmpty) return;
      final p = msgs.first.payload as MqttPublishMessage;
      final payloadString = MqttPublishPayload.bytesToStringAsString(p.payload.message);
      if (payloadString.contains('isOn') && payloadString.contains('true')) {
        if (!completer.isCompleted) completer.complete(true);
      }
    });

    // Driver under test
    final driver = MqttDriver(broker: host, port: 1883, clientId: 'int_driver');
    await driver.init();

    final protocolData = {'topic': topic, 'deviceId': 'd1'};
    await driver.publishForDevice(protocolData, '{"deviceId":"d1","isOn":true}');

    final ok = await completer.future.timeout(const Duration(seconds: 5));
    expect(ok, true);

    subscriber.disconnect();
    await driver.dispose();
  }, timeout: const Timeout(Duration(seconds: 15)));
}
