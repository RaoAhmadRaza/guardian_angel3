import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

Future<bool> _canConnect(String host, int port) async {
  final clientId = 'probe-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(1 << 32)}';
  final client = MqttServerClient(host, clientId);
  client.setProtocolV311();
  client.connectTimeoutPeriod = 3000;
  try {
    await client.connect();
    client.disconnect();
    return true;
  } catch (_) {
    return false;
  }
}

Future<String?> _roundTrip(String host, int port) async {
  final clientId = 'smoke-${DateTime.now().microsecondsSinceEpoch}';
  final client = MqttServerClient(host, clientId);
  await client.connect();

  final topic = 'test/$clientId';
  final payload = 'hello-$clientId';
  final completer = Completer<String?>();

  client.updates?.listen((events) {
    for (final event in events) {
      final msg = event.payload as MqttPublishMessage;
      final text = MqttPublishPayload.bytesToStringAsString(msg.payload.message);
      if (event.topic == topic && !completer.isCompleted) {
        completer.complete(text);
      }
    }
  });

  client.subscribe(topic, MqttQos.atLeastOnce);

  final builder = MqttClientPayloadBuilder();
  builder.addString(payload);
  client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);

  final received = await completer.future.timeout(const Duration(seconds: 5), onTimeout: () => null);

  client.disconnect();
  return received;
}

void main() {
  test('MQTT broker round-trip publish/subscribe', () async {
    final host = const String.fromEnvironment('MQTT_HOST', defaultValue: 'localhost');
    final port = int.tryParse(const String.fromEnvironment('MQTT_PORT', defaultValue: '1883')) ?? 1883;

    final reachable = await _canConnect(host, port);
    if (!reachable) {
      // CI-safe graceful skip
      // ignore: avoid_print
      print('SKIP mqtt_smoke_test: broker not reachable at $host:$port');
      return;
    }

    final received = await _roundTrip(host, port);
    expect(received, isNotNull);
    expect(received!.startsWith('hello-'), isTrue);
  });
}
