import 'dart:async';
import 'package:flutter/material.dart';
import 'package:battery/battery.dart';

/// Enhanced Battery service for real-time battery monitoring
///
/// Provides both periodic battery level updates and instant state change detection
/// for a comprehensive battery monitoring experience in the Guardian Angel app.
class BatteryStream {
  factory BatteryStream() {
    _singleton ??= BatteryStream._();
    return _singleton!;
  }

  BatteryStream._();

  static BatteryStream? _singleton;
  final Battery _battery = Battery();

  Timer? _timer;
  StreamSubscription? _stateSubscription;

  int _batteryLevel = 100;
  BatteryState _batteryState = BatteryState.full;

  /// Get current battery level
  int get batteryLevel => _batteryLevel;

  /// Get current battery state
  BatteryState get batteryState => _batteryState;

  /// Start listening to battery changes with periodic updates
  void startListening() {
    _listenBatteryLevel();
    _listenBatteryState();
  }

  /// Stop all battery monitoring
  void stopListening() {
    _timer?.cancel();
    _stateSubscription?.cancel();
  }

  void _listenBatteryState() {
    _stateSubscription = _battery.onBatteryStateChanged.listen(
      (batteryState) => _batteryState = batteryState,
    );
  }

  void _listenBatteryLevel() {
    _updateBatteryLevel();

    _timer = Timer.periodic(
      const Duration(seconds: 10),
      (_) async => _updateBatteryLevel(),
    );
  }

  Future<void> _updateBatteryLevel() async {
    try {
      final batteryLevel = await _battery.batteryLevel;
      _batteryLevel = batteryLevel;
    } catch (e) {
      debugPrint('Battery level update error: $e');
      // Keep current level on error
    }
  }

  /// Stream for continuous battery percentage updates
  Stream<int> batteryLevelStream(
      {Duration interval = const Duration(seconds: 10)}) async* {
    // Start monitoring if not already started
    if (_timer == null) {
      startListening();
    }

    // Yield initial value
    yield _batteryLevel;

    // Create a stream controller for real-time updates
    late StreamController<int> controller;
    late Timer timer;

    controller = StreamController<int>(
      onListen: () {
        timer = Timer.periodic(interval, (_) async {
          try {
            final currentLevel = await _battery.batteryLevel;
            if (currentLevel != _batteryLevel) {
              _batteryLevel = currentLevel;
              controller.add(_batteryLevel);
            }
          } catch (e) {
            debugPrint('Battery stream error: $e');
          }
        });
      },
      onCancel: () {
        timer.cancel();
      },
    );

    yield* controller.stream;
  }

  /// Stream for battery level with immediate state change detection
  Stream<int> batteryLevelStreamWithStateChanges(
      {Duration interval = const Duration(seconds: 10)}) async* {
    late StreamSubscription<BatteryState> stateSubscription;
    late StreamSubscription<int> levelSubscription;

    final StreamController<int> controller = StreamController<int>();

    // Listen to battery level changes
    levelSubscription = batteryLevelStream(interval: interval).listen((level) {
      controller.add(level);
    });

    // Listen to battery state changes for immediate updates
    stateSubscription = _battery.onBatteryStateChanged.listen((_) async {
      try {
        final currentLevel = await _battery.batteryLevel;
        _batteryLevel = currentLevel;
        controller.add(_batteryLevel);
      } catch (e) {
        debugPrint('Battery state change error: $e');
      }
    });

    yield* controller.stream;

    // Clean up when stream is cancelled
    controller.onCancel = () {
      levelSubscription.cancel();
      stateSubscription.cancel();
      controller.close();
    };
  }

  /// Dispose of all resources
  void dispose() {
    stopListening();
  }
}
