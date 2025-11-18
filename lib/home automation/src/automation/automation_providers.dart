import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'interfaces/automation_interface.dart';
import 'adapters/mock_driver.dart';
import 'adapters/mqtt_driver.dart';
import 'adapters/tuya_cloud_driver.dart';
import 'adapters/websocket_driver.dart';
import '../core/config/app_config_provider.dart';
import '../security/credentials_store.dart';
import 'automation_observability.dart';

final automationDriverProvider = Provider<AutomationDriver>((ref) {
  final cfg = ref.watch(appConfigProvider);
  final creds = ref.watch(credentialsStoreProvider);
  final logEnabled = cfg.logAutomation == true;
  void Function(String msg)? logger = logEnabled ? (m) => print(m) : null;
  final logNotifier = ref.read(deviceEventLogProvider.notifier);
  void Function(DeviceEvent e) onEvent = (e) => logNotifier.add(e);
  if (cfg.useMockAutomation == true) {
    return MockDriver();
  }
  // prefer a globally configured driver. For mixed per-device modes, use a factory map below
  if (cfg.defaultAutomation == 'mqtt') {
    final driver = MqttDriver(
      broker: cfg.mqttBroker!,
      port: cfg.mqttPort ?? 1883,
      clientId: cfg.clientId,
      usernameKey: cfg.mqttUsernameKey,
      passwordKey: cfg.mqttPasswordKey,
      secretResolver: creds.read,
      useTls: (cfg.mqttPort == 8883),
      onLog: logger,
      onEvent: onEvent,
    );
    // feed status into provider
    ref.onDispose(driver.dispose);
    // initialize status updates
    ref.listenSelf((prev, next) {});
    // Kick a listener on the stream and update provider
    driver.statusStream.listen((s) {
      ref.read(automationStatusProvider.notifier).state = s;
    });
    return driver;
  } else {
    return TuyaCloudDriver(dio: cfg.dio, baseUrl: cfg.backendUrl!);
  }
});

// Optional factory for per-device drivers using protocolData.
final automationDriverFactoryProvider = Provider((ref) {
  final creds = ref.watch(credentialsStoreProvider);
  final cfg = ref.watch(appConfigProvider);
  final logEnabled = cfg.logAutomation == true;
  void Function(String msg)? logger = logEnabled ? (m) => print(m) : null;
  final logNotifier = ref.read(deviceEventLogProvider.notifier);
  void Function(DeviceEvent e) onEvent = (e) => logNotifier.add(e);
  return (Map<String, dynamic> protocolData) {
    if (protocolData['protocol'] == 'mqtt') {
      final d = MqttDriver(
        broker: protocolData['broker'],
        port: (protocolData['port'] as int?) ?? 1883,
        username: protocolData['username'] as String?,
        passwordKey: protocolData['passwordKey'] as String?,
        secretResolver: creds.read,
        useTls: ((protocolData['port'] as int?) == 8883) || (protocolData['tls'] == true),
        onLog: logger,
        onEvent: onEvent,
      );
      d.statusStream.listen((s) {
        ref.read(automationStatusProvider.notifier).state = s;
      });
      return d;
    } else if (protocolData['protocol'] == 'ws' || protocolData.containsKey('wsUrl')) {
      final raw = protocolData['wsUrl'] as String?;
      if (raw != null && raw.isNotEmpty) {
        return WebSocketAutomationDriver(uri: Uri.parse(raw));
      }
      return MockDriver();
    } else {
      return TuyaCloudDriver(dio: Dio(), baseUrl: protocolData['backend'] as String);
    }
  };
});
