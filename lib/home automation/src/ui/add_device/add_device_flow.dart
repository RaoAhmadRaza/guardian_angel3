import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../automation/device_protocol.dart';
import '../../data/models/device_model.dart' as domain;
import '../../logic/providers/device_providers.dart';
import '../../logic/providers/room_providers.dart';

/// Add Device multi-step flow
/// Steps:
/// 1) Choose device type
/// 2) Choose connection mode
/// 3) Configure based on mode (Cloud / MQTT / BLE)
/// 4) Name and Room
/// 5) Review & Save (persists DeviceModel with protocolData)
class AddDeviceFlow extends ConsumerStatefulWidget {
  const AddDeviceFlow({super.key});

  @override
  ConsumerState<AddDeviceFlow> createState() => _AddDeviceFlowState();
}

enum _ConnMode { cloud, mqtt, ble }

class _AddDeviceFlowState extends ConsumerState<AddDeviceFlow> {
  // Step state
  int _currentStep = 0;
  DeviceKind _kind = DeviceKind.bulb;
  _ConnMode _mode = _ConnMode.mqtt;

  // MQTT inputs
  final _brokerCtrl = TextEditingController(text: '192.168.1.23');
  final _portCtrl = TextEditingController(text: '1883');
  final _topicCtrl = TextEditingController(text: 'home/livingroom/ceiling');
  final _payloadOnCtrl = TextEditingController(text: '{"isOn":true}');
  final _payloadOffCtrl = TextEditingController(text: '{"isOn":false}');

  // Cloud inputs
  final _backendUrlCtrl = TextEditingController(text: 'https://api.example.com');
  final _cloudDeviceIdCtrl = TextEditingController();

  // BLE inputs (optional stub)
  String? _bleAddress;

  // Common inputs
  final _nameCtrl = TextEditingController();
  String? _selectedRoomId;

  final _formKeys = List.generate(4, (_) => GlobalKey<FormState>());

  @override
  void dispose() {
    _brokerCtrl.dispose();
    _portCtrl.dispose();
    _topicCtrl.dispose();
    _payloadOnCtrl.dispose();
    _payloadOffCtrl.dispose();
    _backendUrlCtrl.dispose();
    _cloudDeviceIdCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  domain.DeviceType _mapKind(DeviceKind k) {
    switch (k) {
      case DeviceKind.lamp:
        return domain.DeviceType.lamp;
      case DeviceKind.fan:
        return domain.DeviceType.fan;
      case DeviceKind.bulb:
        return domain.DeviceType.bulb;
    }
  }

  Future<void> _onSave() async {
    // Validate last step
    if (!(_formKeys[3].currentState?.validate() ?? true)) return;
    final rooms = ref.read(roomsListProvider) ?? const [];
    final roomId = _selectedRoomId ?? (rooms.isNotEmpty ? rooms.first.id : '1');
    final name = _nameCtrl.text.trim().isEmpty ? 'New Device' : _nameCtrl.text.trim();
    final id = const Uuid().v4();

    Map<String, dynamic> protocolData;
    switch (_mode) {
      case _ConnMode.mqtt:
        protocolData = buildMqttProtocolData(
          broker: _brokerCtrl.text.trim(),
          port: int.tryParse(_portCtrl.text.trim()) ?? 1883,
          topic: _topicCtrl.text.trim(),
          payloadOn: _payloadOnCtrl.text.trim(),
          payloadOff: _payloadOffCtrl.text.trim(),
        );
        break;
      case _ConnMode.cloud:
        protocolData = buildTuyaProtocolData(
          backend: _backendUrlCtrl.text.trim(),
          backendDeviceId: _cloudDeviceIdCtrl.text.trim(),
        );
        break;
      case _ConnMode.ble:
        if (_bleAddress == null || _bleAddress!.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a BLE device')),
          );
          return;
        }
        protocolData = buildBleProtocolData(deviceAddress: _bleAddress!);
        break;
    }

    final device = domain.DeviceModel(
      id: id,
      roomId: roomId,
      type: _mapKind(_kind),
      name: name,
      isOn: false,
      state: {
        'protocolData': protocolData,
      },
    );

    await ref.read(devicesControllerProvider(roomId).notifier).addDevice(device);

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rooms = ref.watch(roomsListProvider) ?? const [];
    _selectedRoomId ??= rooms.isNotEmpty ? rooms.first.id : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Device')),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          // Validate per-step
          if (_currentStep < 3) {
            if (!(_formKeys[_currentStep].currentState?.validate() ?? true)) return;
            setState(() => _currentStep += 1);
          } else {
            _onSave();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) setState(() => _currentStep -= 1);
          else Navigator.of(context).maybePop();
        },
        steps: [
          Step(
            title: const Text('Device type'),
            isActive: _currentStep >= 0,
            content: Form(
              key: _formKeys[0],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<DeviceKind>(
                    value: _kind,
                    items: const [
                      DropdownMenuItem(value: DeviceKind.bulb, child: Text('Bulb')),
                      DropdownMenuItem(value: DeviceKind.lamp, child: Text('Lamp')),
                      DropdownMenuItem(value: DeviceKind.fan, child: Text('Fan')),
                    ],
                    onChanged: (v) => setState(() => _kind = v ?? DeviceKind.bulb),
                    decoration: const InputDecoration(labelText: 'Device Type'),
                  ),
                ],
              ),
            ),
          ),
          Step(
            title: const Text('Connection mode'),
            isActive: _currentStep >= 1,
            content: Form(
              key: _formKeys[1],
              child: Column(
                children: [
                  RadioListTile<_ConnMode>(
                    title: const Text('Cloud'),
                    value: _ConnMode.cloud,
                    groupValue: _mode,
                    onChanged: (v) => setState(() => _mode = v ?? _ConnMode.cloud),
                  ),
                  RadioListTile<_ConnMode>(
                    title: const Text('Local (MQTT)'),
                    value: _ConnMode.mqtt,
                    groupValue: _mode,
                    onChanged: (v) => setState(() => _mode = v ?? _ConnMode.mqtt),
                  ),
                  RadioListTile<_ConnMode>(
                    title: const Text('BLE (optional)'),
                    value: _ConnMode.ble,
                    groupValue: _mode,
                    onChanged: (v) => setState(() => _mode = v ?? _ConnMode.ble),
                  ),
                ],
              ),
            ),
          ),
          Step(
            title: const Text('Configure'),
            isActive: _currentStep >= 2,
            content: Form(
              key: _formKeys[2],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_mode == _ConnMode.cloud) ...[
                    TextFormField(
                      controller: _backendUrlCtrl,
                      decoration: const InputDecoration(labelText: 'Backend URL (proxy)'),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _cloudDeviceIdCtrl,
                      decoration: const InputDecoration(labelText: 'Cloud Device ID'),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton(
                        onPressed: () {
                          // Placeholder for OAuth/backend fetch
                          if (_cloudDeviceIdCtrl.text.isEmpty) {
                            _cloudDeviceIdCtrl.text = 'cloud-device-123';
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Fetched devices (example)')),
                          );
                        },
                        child: const Text('Fetch from Cloud'),
                      ),
                    ),
                  ] else if (_mode == _ConnMode.mqtt) ...[
                    Text('Put your device in pairing mode and ensure it is reachable on the network.',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _brokerCtrl,
                      decoration: const InputDecoration(labelText: 'MQTT Broker'),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _portCtrl,
                      decoration: const InputDecoration(labelText: 'Port'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _topicCtrl,
                      decoration: const InputDecoration(labelText: 'Topic'),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _payloadOnCtrl,
                      decoration: const InputDecoration(labelText: 'Payload ON (JSON/string)'),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _payloadOffCtrl,
                      decoration: const InputDecoration(labelText: 'Payload OFF (JSON/string)'),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton(
                        onPressed: () {
                          // Optional mDNS discovery stub
                          _brokerCtrl.text = 'mqtt.local';
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Discovered mqtt.local (example)')),
                          );
                        },
                        child: const Text('Scan (mDNS)'),
                      ),
                    ),
                  ] else if (_mode == _ConnMode.ble) ...[
                    Text('Scan for BLE devices (stub).', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() => _bleAddress = 'AA:BB:CC:DD:EE:FF');
                        },
                        child: Text(_bleAddress == null ? 'Scan' : 'Selected $_bleAddress'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Step(
            title: const Text('Name & Room'),
            isActive: _currentStep >= 3,
            content: Form(
              key: _formKeys[3],
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Device Name'),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedRoomId,
                    decoration: const InputDecoration(labelText: 'Room'),
                    items: [
                      for (final r in rooms)
                        DropdownMenuItem(value: r.id, child: Text(r.name)),
                    ],
                    onChanged: (v) => setState(() => _selectedRoomId = v),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'On save, we will store protocolData in the device state and start any onboarding as needed.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
        controlsBuilder: (context, details) {
          final isLast = _currentStep == 3;
          return Row(
            children: [
              ElevatedButton(
                onPressed: details.onStepContinue,
                child: Text(isLast ? 'Save' : 'Next'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: details.onStepCancel,
                child: const Text('Back'),
              ),
            ],
          );
        },
      ),
    );
  }
}
