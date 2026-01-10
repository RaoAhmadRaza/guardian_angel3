import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fall_detection_manager.dart';
import 'fall_detection_logging_service.dart';

/// Global Fall Detection Service
/// 
/// Singleton service that manages fall detection for patients.
/// - Provides global access to the fall detection manager
/// - Handles settings persistence (enabled/disabled toggle)
/// - Integrates with patient home screen and SOS workflow
class FallDetectionService extends ChangeNotifier {
  static FallDetectionService? _instance;
  static FallDetectionService get instance {
    _instance ??= FallDetectionService._internal();
    return _instance!;
  }
  
  FallDetectionService._internal();
  
  // Core components
  FallDetectionManager? _manager;
  FallDetectionLoggingService? _loggingService;
  
  // Settings
  bool _isEnabled = true;
  bool _isInitialized = false;
  
  // Callback for when fall is detected (set by UI layer)
  VoidCallback? onFallDetectedCallback;
  
  // Public getters
  FallDetectionManager? get manager => _manager;
  FallDetectionLoggingService? get loggingService => _loggingService;
  bool get isEnabled => _isEnabled;
  bool get isInitialized => _isInitialized;
  bool get isMonitoring => _manager?.isMonitoring ?? false;
  bool get isModelLoaded => _manager?.isModelLoaded ?? false;
  double get lastProbability => _manager?.lastProbability ?? 0.0;
  
  static const String _enabledKey = 'fall_detection_enabled';
  
  /// Initialize the fall detection service
  Future<void> initialize({required VoidCallback onFallDetected}) async {
    if (_isInitialized) return;
    
    log('[FallDetectionService] Initializing...');
    
    // Load settings
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(_enabledKey) ?? true; // Default enabled
    
    // Set callback
    onFallDetectedCallback = onFallDetected;
    
    // Create logging service
    _loggingService = FallDetectionLoggingService();
    
    // Create manager
    _manager = FallDetectionManager(
      onFallDetected: _handleFallDetected,
    );
    _manager!.setLoggingService(_loggingService!);
    
    // Add listener for state changes
    _manager!.addListener(_onManagerStateChanged);
    
    // Initialize the model
    await _manager!.initialize();
    
    _isInitialized = true;
    log('[FallDetectionService] Initialized. Enabled: $_isEnabled, Model loaded: ${_manager!.isModelLoaded}');
    notifyListeners();
  }
  
  /// Handle fall detection from manager
  void _handleFallDetected() {
    log('[FallDetectionService] Fall detected! Triggering callback.');
    onFallDetectedCallback?.call();
  }
  
  /// Handle manager state changes
  void _onManagerStateChanged() {
    notifyListeners();
  }
  
  /// Start fall detection monitoring
  void startMonitoring() {
    if (!_isInitialized) {
      log('[FallDetectionService] Cannot start - not initialized');
      return;
    }
    if (!_isEnabled) {
      log('[FallDetectionService] Cannot start - disabled in settings');
      return;
    }
    
    log('[FallDetectionService] Starting monitoring');
    _manager?.startMonitoring();
  }
  
  /// Stop fall detection monitoring
  void stopMonitoring() {
    log('[FallDetectionService] Stopping monitoring');
    _manager?.stopMonitoring();
  }
  
  /// Toggle monitoring state
  void toggleMonitoring() {
    if (isMonitoring) {
      stopMonitoring();
    } else {
      startMonitoring();
    }
  }
  
  /// Enable/disable fall detection
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    
    // Persist setting
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    
    // Stop monitoring if disabled
    if (!enabled && isMonitoring) {
      stopMonitoring();
    }
    
    log('[FallDetectionService] Enabled: $enabled');
    notifyListeners();
  }
  
  /// Simulate a fall (for testing)
  void simulateFall() {
    log('[FallDetectionService] Simulating fall');
    _manager?.simulateFall();
  }
  
  /// Dispose resources
  @override
  void dispose() {
    _manager?.removeListener(_onManagerStateChanged);
    _manager?.dispose();
    _loggingService?.dispose();
    _manager = null;
    _loggingService = null;
    _isInitialized = false;
    super.dispose();
  }
}
