import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import '../sensors/imu_stream.dart';
import '../ml/fall_model.dart';
import '../ml/preprocessing.dart';
import '../models/log_entry.dart';
import '../services/monitoring_logging_service.dart';

/// ============================================================================
/// FALL DETECTION MANAGER - VERSION 1.0 (FROZEN PIPELINE)
/// ============================================================================
/// 
/// Pipeline stages:
/// 1. Sensor data collection (400 samples @ ~200Hz = 2 seconds)
/// 2. Preprocessing (unit conversion + high-pass + magnitudes + z-score)
/// 3. Model inference (FallDetector_v1_baseline)
/// 4. Temporal aggregation (2-of-3 voting)
/// 5. Post-impact stillness gating (optional, reduces "drop & catch" FPs)
/// 6. Alert triggering with 15s refractory period
/// 
/// FROZEN: Do not modify pipeline without incrementing version.
/// ============================================================================
class FallDetectionManager extends ChangeNotifier {
  final ImuStream _imuStream = ImuStream();
  final FallModel _fallModel = FallModel();
  final TemporalAggregator _aggregator = TemporalAggregator(
    bufferSize: 3,
    requiredPositives: 2,
    threshold: 0.35,  // FROZEN: Do not change without testing
    refractoryPeriod: const Duration(seconds: 15),
  );
  
  // Post-impact stillness checker (reduces false alerts from phone drops)
  final StillnessChecker _stillnessChecker = StillnessChecker();
  
  // Feature flag: Set to true to enable stillness gating
  // Start with false to compare behavior, then enable if helpful
  static const bool enableStillnessGating = false;
  
  // Logging service reference (optional - set via setter)
  MonitoringLoggingService? _loggingService;
  
  bool _isMonitoring = false;
  bool get isMonitoring => _isMonitoring;
  
  // Buffer for raw sensor data: [ax, ay, az, gx, gy, gz]
  final List<List<double>> _rawBuffer = [];
  
  // Sliding window with overlap
  static const int _windowSize = FallModel.windowSize;  // 400
  static const int _stepSize = 100;  // Slide by 100 samples (0.5 seconds)
  int _samplesSinceLastInference = 0;
  
  // Window timing tracking for logs
  DateTime? _windowStartTime;
  
  // Callback for when a fall is detected
  final VoidCallback onFallDetected;
  
  // For debugging
  double _lastProbability = 0.0;
  double get lastProbability => _lastProbability;
  
  // Expose aggregator state for logging
  String get aggregatorState => '${_aggregator.currentBuffer.where((p) => p > _aggregator.threshold).length} of ${_aggregator.bufferSize}';
  bool get isInRefractoryPeriod => _aggregator.isInRefractoryPeriod;
  double get threshold => _aggregator.threshold;

  FallDetectionManager({required this.onFallDetected});
  
  /// Set the logging service for integration with monitoring logs feature.
  void setLoggingService(MonitoringLoggingService service) {
    _loggingService = service;
  }

  Future<void> initialize() async {
    await _fallModel.loadModel();
    log('FallDetectionManager initialized');
  }

  void toggleMonitoring() {
    if (_isMonitoring) {
      stopMonitoring();
    } else {
      startMonitoring();
    }
  }

  void startMonitoring() {
    if (!_fallModel.isLoaded) {
      log('Cannot start: Model not loaded yet');
      return;
    }

    _isMonitoring = true;
    _rawBuffer.clear();
    _samplesSinceLastInference = 0;
    _windowStartTime = DateTime.now();
    _aggregator.reset();
    _stillnessChecker.reset();  // Reset stillness checker
    Preprocessor.resetFilter();  // Reset high-pass filter state for new session
    notifyListeners();

    _imuStream.start();
    _imuStream.dataStream.listen(_processSensorData);
    log('Monitoring started - stillness gating: ${enableStillnessGating ? "ON" : "OFF"}');
  }

  void stopMonitoring() {
    _isMonitoring = false;
    notifyListeners();
    _imuStream.stop();
    _aggregator.reset();
    log('Monitoring stopped');
  }

  void _processSensorData(List<double> data) {
    if (!_isMonitoring) return;
    
    // Track window start time
    if (_rawBuffer.isEmpty) {
      _windowStartTime = DateTime.now();
    }
    
    // Add raw data point: [ax, ay, az, gx, gy, gz]
    _rawBuffer.add(List.from(data));
    _samplesSinceLastInference++;

    // Maintain maximum buffer size (keep 2x window for sliding)
    while (_rawBuffer.length > _windowSize * 2) {
      _rawBuffer.removeAt(0);
    }

    // Run inference when:
    // 1. We have enough samples for a full window
    // 2. We've collected _stepSize new samples since last inference
    if (_rawBuffer.length >= _windowSize && _samplesSinceLastInference >= _stepSize) {
      _runInference();
      _samplesSinceLastInference = 0;
    }
  }

  void _runInference() {
    final inferenceStartTime = DateTime.now();
    final windowEndTime = inferenceStartTime;
    final windowStartTime = _windowStartTime ?? inferenceStartTime.subtract(const Duration(seconds: 2));
    
    // Get the latest window
    final startIdx = _rawBuffer.length - _windowSize;
    final rawWindow = _rawBuffer.sublist(startIdx);
    
    // Apply preprocessing:
    // 1. Optional smoothing
    // 2. Add magnitude features (6 -> 8 channels)
    // 3. Z-score normalization with clamping
    final smoothed = Preprocessor.smoothWindow(rawWindow, kernelSize: 5);
    final preprocessed = Preprocessor.preprocessWindow(smoothed);
    
    // CONTRACT: Skip inference if preprocessing fails (invalid data)
    if (preprocessed == null) {
      log('Skipping inference: preprocessing returned null (invalid data)');
      return;
    }
    
    // Run model inference
    final probability = _fallModel.predict(preprocessed);
    _lastProbability = probability;
    
    final inferenceEndTime = DateTime.now();
    final inferenceLatency = inferenceEndTime.difference(inferenceStartTime);
    
    log('Inference: prob=$probability, buffer=${_aggregator.currentBuffer}');
    
    // Check threshold before aggregation for logging
    final thresholdExceeded = probability > _aggregator.threshold;
    final wasInRefractory = _aggregator.isInRefractoryPeriod;
    
    // Apply temporal aggregation (2-of-3 rule)
    final shouldAlert = _aggregator.addProbabilityAndCheck(probability);
    
    // Determine final decision
    FallDecision decision;
    if (shouldAlert) {
      decision = FallDecision.fall;
    } else if (thresholdExceeded && wasInRefractory) {
      decision = FallDecision.suppressed;
    } else {
      decision = FallDecision.noFall;
    }
    
    // Log the inference if logging service is available
    if (_loggingService != null) {
      _logInference(
        rawWindow: rawWindow,
        windowStartTime: windowStartTime,
        windowEndTime: windowEndTime,
        probability: probability,
        thresholdExceeded: thresholdExceeded,
        decision: decision,
        inferenceLatency: inferenceLatency,
      );
    }
    
    // Update window start time for next inference
    _windowStartTime = DateTime.now();
    
    if (shouldAlert) {
      log('FALL DETECTED! Triggering alert...');
      stopMonitoring();
      onFallDetected();
    }
    
    notifyListeners(); // Update UI with latest probability
  }
  
  /// Log inference results to the monitoring logging service.
  void _logInference({
    required List<List<double>> rawWindow,
    required DateTime windowStartTime,
    required DateTime windowEndTime,
    required double probability,
    required bool thresholdExceeded,
    required FallDecision decision,
    required Duration inferenceLatency,
  }) {
    // Create sensor statistics
    final sensorStats = SensorStatistics.fromRawWindow(rawWindow);
    
    // Create inference result
    final inferenceResult = InferenceResult(
      windowStartTime: windowStartTime,
      windowEndTime: windowEndTime,
      windowSize: _windowSize,
      fallProbability: probability,
      thresholdUsed: _aggregator.threshold,
      temporalAggregationState: aggregatorState,
      thresholdExceeded: thresholdExceeded,
      finalDecision: decision,
      inferenceLatency: inferenceLatency,
    );
    
    // Create system state
    final systemState = SystemState(
      monitoringState: _isMonitoring ? MonitoringState.active : MonitoringState.paused,
      refractoryState: _aggregator.isInRefractoryPeriod ? RefractoryState.active : RefractoryState.idle,
      refractoryTimeRemaining: _aggregator.isInRefractoryPeriod 
          ? _aggregator.refractoryPeriod - DateTime.now().difference(_aggregator.lastAlertTime ?? DateTime.now())
          : null,
      alertState: decision == FallDecision.fall 
          ? AlertState.triggered 
          : (decision == FallDecision.suppressed ? AlertState.suppressed : AlertState.allowed),
      bufferFillLevel: ((_rawBuffer.length / _windowSize) * 100).clamp(0, 100).toInt(),
    );
    
    // Add to logging service
    _loggingService!.addLogEntry(
      sensorStats: sensorStats,
      inferenceResult: inferenceResult,
      systemState: systemState,
    );
  }

  /// For testing: manually trigger the alert flow
  void simulateFall() {
    log('Simulating fall detection');
    stopMonitoring();
    onFallDetected();
  }

  @override
  void dispose() {
    _imuStream.dispose();
    _fallModel.dispose();
    super.dispose();
  }
}
