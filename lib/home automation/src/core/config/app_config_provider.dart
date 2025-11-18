import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppConfig {
  final bool? useMockAutomation;
  final String? defaultAutomation; // 'mqtt' | 'tuya'
  final String? mqttBroker;
  final int? mqttPort;
  final String? mqttUsernameKey;
  final String? mqttPasswordKey;
  final String? clientId;
  final bool? logAutomation;
  final Dio dio;
  final String? backendUrl;

  AppConfig({
    this.useMockAutomation,
    this.defaultAutomation,
    this.mqttBroker,
    this.mqttPort,
    this.mqttUsernameKey,
    this.mqttPasswordKey,
    this.clientId,
    this.logAutomation,
    Dio? dio,
    this.backendUrl,
  }) : dio = dio ?? Dio();

  AppConfig copyWith({
    bool? useMockAutomation,
    String? defaultAutomation,
    String? mqttBroker,
    int? mqttPort,
    String? mqttUsernameKey,
    String? mqttPasswordKey,
    String? clientId,
    bool? logAutomation,
    Dio? dio,
    String? backendUrl,
  }) => AppConfig(
        useMockAutomation: useMockAutomation ?? this.useMockAutomation,
        defaultAutomation: defaultAutomation ?? this.defaultAutomation,
        mqttBroker: mqttBroker ?? this.mqttBroker,
        mqttPort: mqttPort ?? this.mqttPort,
        mqttUsernameKey: mqttUsernameKey ?? this.mqttUsernameKey,
        mqttPasswordKey: mqttPasswordKey ?? this.mqttPasswordKey,
        clientId: clientId ?? this.clientId,
        logAutomation: logAutomation ?? this.logAutomation,
        dio: dio ?? this.dio,
        backendUrl: backendUrl ?? this.backendUrl,
      );
}

/// Basic app config provider with safe defaults.
final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig(
    useMockAutomation: true,
    defaultAutomation: 'mqtt',
    mqttBroker: 'localhost',
    mqttPort: 1883,
    clientId: 'home-automation-app',
    logAutomation: false,
    backendUrl: 'https://api.example.com',
  );
});
