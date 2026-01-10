import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';

import '../../ml/fall_detection/fall_model.dart';
import '../../ml/fall_detection/preprocessing.dart';
import '../../sensors/imu_stream.dart';
import '../../models/fall_detection/log_entry.dart';
import 'fall_detection_logging_service.dart';

/// Fall Detection Manager
/// 
/// Core pipeline for real-time fall detection:
/// 1. Collect IMU data via sensors_plus
/// 2. Buffer into 400-sample windows (2 seconds @ 200Hz)
/// 3. Preprocess (unit conversion, high-pass filter, z-score normalization)
/// 4. Run TFLite inference
/// 5. Apply temporal aggregation (2-of-3 voting)
/// 6. Trigger callback on confirmed fall
/// 
/// This is a 1:1 copy of fall_detection_sandbox's implementation,
/// adapted for Guardian Angel's SOS integration.
class FallDetectionManager extends ChangeNotifier {
  // Callback when fall is confirmed
  final VoidCallback onFallDetected;
  
  // Core components
  final ImuStream _imuStream = ImuStream();
  final FallModel _fallModel = FallModel();
  
  // Temporal aggregation with 2-of-3 voting
  final TemporalAggregator _temporalAggregator = TemporalAggregator(
    bufferSize: 3,
    requiredPositives: 2,
    threshold: 0.35,
    refractoryPeriod: const Duration(seconds: 15),
  );
  
  // Stillness checker (currently disabled but ready for activation)
  final StillnessChecker _stillnessChecker = StillnessChecker();
  final bool enableStillnessGating = false; // Enable when testing shows it helps
  
  // Raw data buffer
  final List<List<double>> _rawBuffer = [];
  static const int _windowSize = 400;  // 2 seconds @ 200Hz
  static const int _stepSize = 100;    // 0.5 second sliding step
  
  // State tracking
  bool _isMonitoring = false;
  double _lastProbability = 0.0;
  StreamSubscription? _imuSubscription;
  DateTime? _windowStartTime;
  
  // Logging service
  FallDetectionLoggingService? _loggingService;
  
  // Public getters
  bool get isMonitoring => _isMonitoring;
  bool get isModelLoaded => _fallModel.isLoaded;
  double get lastProbability => _lastProbability;
  int get bufferSize => _rawBuffer.length;
  int get windowSize => _windowSize;
  double get bufferFillPercent => (_rawBuffer.length / _windowSize) * 100;

  FallDetectionManager({required this.onFallDetected});
  
  /// Set the logging service for detailed monitoring
  void setLoggingService(FallDetectionLoggingService service) {
    _loggingService = service;
  }

  /// Initialize the fall detection system
  Future<void> initialize() async {
    log('[FallDetectionManager] Initializing...');
    await _fallModel.loadModel();
    Preprocessor.resetFilter();
    log('[FallDetectionManager] Initialized. Model loaded: ${_fallModel.isLoaded}');
    notifyListeners();
  }

  /// Start fall detection monitoring
  void startMonitoring() {
    if (_isMonitoring) return;
    if (!_fallModel.isLoaded) {
      log('[FallDetectionManager] Cannot start - model not loaded');
      return;
    }

    log('[FallDetectionManager] Starting monitoring');
    _isMonitoring = true;
    _rawBuffer.clear();
    _windowStartTime = DateTime.now();
    Preprocessor.resetFilter();
    _temporalAggregator.reset();
    _stillnessChecker.reset();

    _imuStream.start();
    _imuSubscription = _imuStream.dataStream.listen(_onSensorData);
    
    _loggingService?.startSession();
    notifyListeners();
  }

  /// Stop fall detection monitoring
  void stopMonitoring() {
    if (!_isMonitoring) return;

    log('[FallDetectionManager] Stopping monitoring');
    _isMonitoring = false;
    _imuSubscription?.cancel();
    _imuSubscription = null;
    _imuStream.stop();
    
    _loggingService?.endSession();
    notifyListeners();
  }

  /// Toggle monitoring state
  void toggleMonitoring() {
    if (_isMonitoring) {
      stopMonitoring();
    } else {
      startMonitoring();
    }
  }

  /// Process incoming sensor data
  void _onSensorData(List<double> sample) {
    if (!_isMonitoring) return;

    // Add to buffer
    _rawBuffer.add(sample);

    // Run inference when we have enough samples
    if (_rawBuffer.length >= _windowSize) {
      _runInference();
      
      // Slide buffer by step size
      if (_rawBuffer.length > _stepSize) {
        _rawBuffer.removeRange(0, _stepSize);
      }
    }
  }

  /// Run the ML inference pipeline
  void _runInference() {
    final startTime = DateTime.now();
    
    // Get the window for inference
    final window = _rawBuffer.take(_windowSize).toList();
    
    // Preprocess
    final preprocessed = Preprocessor.preprocessWindow(window);
    if (preprocessed == null) {
      log('[FallDetectionManager] Preprocessing failed - skipping inference');
      return;
    }
    
    // Run inference
    final probability = _fallModel.predict(preprocessed);
    _lastProbability = probability;
    
    final endTime = DateTime.now();
    final latency = endTime.difference(startTime);
    
    // Apply temporal aggregation
    final shouldTrigger = _temporalAggregator.addProbabilityAndCheck(probability);
    
    // Determine decision
    FallDecision decision;
    if (shouldTrigger) {
      if (enableStillnessGating) {
        // Check stillness before confirming
        _stillnessChecker.onSpike();
        decision = FallDecision.noFall; // Wait for stillness confirmation
      } else {
        decision = FallDecision.fall;
      }
    } else if (_temporalAggregator.isInRefractoryPeriod) {
      decision = FallDecision.suppressed;
    } else {
      decision = FallDecision.noFall;
    }
    
    // Log the inference
    _logInference(window, probability, decision, latency);
    
    // Trigger alert if fall confirmed
    if (decision == FallDecision.fall) {
      log('[FallDetectionManager] FALL DETECTED! Triggering alert.');
      stopMonitoring();
      onFallDetected();
    }
    
    notifyListeners();
  }

  /// Log inference details
  void _logInference(
    List<List<double>> window,
    double probability,
    FallDecision decision,
    Duration latency,
  ) {
    if (_loggingService == null) return;
    
    final buffer = _temporalAggregator.currentBuffer;
    final positiveCount = buffer.where((p) => p > 0.35).length;
    
    final sensorStats = SensorStatistics.fromRawWindow(window);
    
    final inferenceResult = InferenceResult(
      windowStartTime: _windowStartTime ?? DateTime.now(),
      windowEndTime: DateTime.now(),
      windowSize: window.length,
      fallProbability: probability,
      thresholdUsed: 0.35,
      temporalAggregationState: '$positiveCount of ${buffer.length}',
      thresholdExceeded: probability > 0.35,
      finalDecision: decision,
      inferenceLatency: latency,
    );
    
    final systemState = SystemState(
      timestamp: DateTime.now(),
      isMonitoring: _isMonitoring,
      modelLoaded: _fallModel.isLoaded,
      alertState: decision == FallDecision.fall 
          ? AlertState.triggered 
          : (decision == FallDecision.suppressed ? AlertState.suppressed : AlertState.allowed),
      bufferFillLevel: ((_rawBuffer.length / _windowSize) * 100).clamp(0, 100).toInt(),
    );
    
    _loggingService!.addLogEntry(
      sensorStats: sensorStats,
      inferenceResult: inferenceResult,
      systemState: systemState,
    );
  }

  /// For testing: manually trigger the alert flow
  void simulateFall() {
    log('[FallDetectionManager] Simulating fall detection');
    stopMonitoring();
    onFallDetected();
  }

  @override
  void dispose() {
    stopMonitoring();
    _imuStream.dispose();
    _fallModel.dispose();
    super.dispose();
  }
}
