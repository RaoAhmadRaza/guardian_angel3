class MockMqttClient {
  final List<_PublishCall> publishes = [];
  final Set<String> subscriptions = {};

  void subscribe(String topic) {
    subscriptions.add(topic);
  }

  void publish(String topic, String payload, {bool retain = false, int qos = 0}) {
    publishes.add(_PublishCall(topic, payload, retain: retain, qos: qos));
  }
}

class _PublishCall {
  final String topic;
  final String payload;
  final bool retain;
  final int qos;

  _PublishCall(this.topic, this.payload, {required this.retain, required this.qos});
}
