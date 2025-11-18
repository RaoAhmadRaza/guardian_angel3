import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'interfaces/automation_interface.dart';

enum AutomationConnection { disconnected, connecting, connected }

class DeviceEventLogNotifier extends StateNotifier<List<DeviceEvent>> {
  static const int maxEvents = 50;
  DeviceEventLogNotifier() : super(const []);

  void add(DeviceEvent e) {
    final copy = List<DeviceEvent>.from(state);
    copy.insert(0, e);
    if (copy.length > maxEvents) copy.removeRange(maxEvents, copy.length);
    state = copy;
  }

  void clear() => state = const [];
}

final deviceEventLogProvider = StateNotifierProvider<DeviceEventLogNotifier, List<DeviceEvent>>(
  (ref) => DeviceEventLogNotifier(),
  name: 'deviceEventLogProvider',
);

/// Connection status provider. Implemented in automation_providers using driver hooks.
final automationStatusProvider = StateProvider<AutomationConnection>(
  (ref) => AutomationConnection.disconnected,
  name: 'automationStatusProvider',
);
