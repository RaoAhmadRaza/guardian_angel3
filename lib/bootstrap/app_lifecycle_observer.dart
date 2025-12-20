/// AppLifecycleObserver - Observes app lifecycle for storage and safety operations.
///
/// Part of PHASE 3: Production Closure & Audit Saturation.
///
/// Responsibilities:
/// - Run StorageMonitor on app resume
/// - Close boxes on app terminate/logout
/// - Force exercise safety paths at runtime
library;

import 'package:flutter/widgets.dart';
import '../persistence/monitoring/storage_monitor.dart';
import '../services/telemetry_service.dart';
import 'package:hive/hive.dart';

/// Singleton lifecycle observer that hooks into WidgetsBindingObserver.
///
/// STEP 3.2 & 3.3: Force-exercise safety paths and enforce box lifecycle.
class AppLifecycleObserver with WidgetsBindingObserver {
  static AppLifecycleObserver? _instance;
  static AppLifecycleObserver get I {
    _instance ??= AppLifecycleObserver._();
    return _instance!;
  }

  AppLifecycleObserver._();

  bool _isRegistered = false;

  /// Initialize and register the observer.
  ///
  /// Call this in bootstrap after WidgetsFlutterBinding.ensureInitialized().
  void register() {
    if (_isRegistered) return;
    WidgetsBinding.instance.addObserver(this);
    _isRegistered = true;
    TelemetryService.I.increment('lifecycle.observer.registered');
  }

  /// Unregister the observer.
  void unregister() {
    if (!_isRegistered) return;
    WidgetsBinding.instance.removeObserver(this);
    _isRegistered = false;
    TelemetryService.I.increment('lifecycle.observer.unregistered');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    TelemetryService.I.increment('lifecycle.state_change.${state.name}');

    switch (state) {
      case AppLifecycleState.resumed:
        _onResume();
        break;
      case AppLifecycleState.paused:
        _onPause();
        break;
      case AppLifecycleState.detached:
        _onDetached();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // No action needed
        break;
    }
  }

  /// Called when app resumes from background.
  ///
  /// STEP 3.2: Run StorageMonitor on resume.
  Future<void> _onResume() async {
    TelemetryService.I.increment('lifecycle.resume');
    try {
      final result = await StorageMonitor.runResumeCheck();
      if (result.needsAttention) {
        TelemetryService.I.increment('lifecycle.resume.storage_warning');
      }
    } catch (e) {
      TelemetryService.I.increment('lifecycle.resume.storage_check_failed');
    }
  }

  /// Called when app goes to background.
  void _onPause() {
    TelemetryService.I.increment('lifecycle.pause');
    // Optionally flush pending writes here
  }

  /// Called when app is about to terminate.
  ///
  /// STEP 3.3: Close all boxes on app terminate.
  Future<void> _onDetached() async {
    TelemetryService.I.increment('lifecycle.detached');
    await closeAllBoxes();
  }

  /// Close all Hive boxes.
  ///
  /// Call this on:
  /// - App terminate (detached)
  /// - User logout
  /// - Fatal startup error
  static Future<void> closeAllBoxes() async {
    try {
      TelemetryService.I.increment('lifecycle.close_all_boxes.started');
      await Hive.close();
      TelemetryService.I.increment('lifecycle.close_all_boxes.success');
    } catch (e) {
      TelemetryService.I.increment('lifecycle.close_all_boxes.failed');
    }
  }

  /// Perform secure erase and close all storage.
  ///
  /// STEP 3.3: On secure erase, delete from disk.
  static Future<void> secureEraseAll() async {
    try {
      TelemetryService.I.increment('lifecycle.secure_erase.started');
      await Hive.deleteFromDisk();
      TelemetryService.I.increment('lifecycle.secure_erase.success');
    } catch (e) {
      TelemetryService.I.increment('lifecycle.secure_erase.failed');
    }
  }

  /// Handle fatal startup error.
  ///
  /// STEP 3.3: On fatal error, close Hive.
  static Future<void> onFatalStartupError() async {
    try {
      TelemetryService.I.increment('lifecycle.fatal_error.started');
      await Hive.close();
      TelemetryService.I.increment('lifecycle.fatal_error.closed');
    } catch (e) {
      TelemetryService.I.increment('lifecycle.fatal_error.close_failed');
    }
  }

  /// Called on user logout.
  ///
  /// STEP 3.3: Close all boxes on logout.
  static Future<void> onLogout() async {
    TelemetryService.I.increment('lifecycle.logout.started');
    await closeAllBoxes();
    TelemetryService.I.increment('lifecycle.logout.complete');
  }
}
