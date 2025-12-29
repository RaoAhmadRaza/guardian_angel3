/// Demo Mode Service
///
/// Centralized service to control demo mode across all screens.
/// When enabled, data providers return fake/sample data to showcase UI.
/// When disabled, screens show only real user data.
library;

import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';

/// Service that manages demo mode state across the app
class DemoModeService {
  static DemoModeService? _instance;
  
  /// Singleton instance
  static DemoModeService get instance {
    _instance ??= DemoModeService._();
    return _instance!;
  }
  
  DemoModeService._();
  
  /// Hive box for persistence
  static const String _boxName = 'demo_mode_settings';
  static const String _enabledKey = 'demo_mode_enabled';
  
  Box<dynamic>? _box;
  
  /// Stream controller for demo mode changes
  final _controller = StreamController<bool>.broadcast();
  
  /// Stream of demo mode state changes
  Stream<bool> get onDemoModeChanged => _controller.stream;
  
  /// Current demo mode state (cached)
  bool _isEnabled = false;
  
  /// Whether demo mode is currently enabled
  bool get isEnabled => _isEnabled;
  
  /// Initialize the service
  Future<void> initialize() async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox(_boxName);
    }
    _isEnabled = _box?.get(_enabledKey, defaultValue: false) ?? false;
  }
  
  /// Enable demo mode and notify all listeners
  Future<void> enableDemoMode() async {
    await initialize();
    _isEnabled = true;
    await _box?.put(_enabledKey, true);
    _controller.add(true);
  }
  
  /// Disable demo mode and notify all listeners
  Future<void> disableDemoMode() async {
    await initialize();
    _isEnabled = false;
    await _box?.put(_enabledKey, false);
    _controller.add(false);
  }
  
  /// Toggle demo mode
  Future<void> toggleDemoMode() async {
    if (_isEnabled) {
      await disableDemoMode();
    } else {
      await enableDemoMode();
    }
  }
  
  /// Dispose the service
  void dispose() {
    _controller.close();
  }
}
