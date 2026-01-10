import 'dart:math';

/// ============================================================================
/// FALL DETECTOR PREPROCESSING - VERSION 1.0 (FROZEN)
/// ============================================================================
/// 
/// ⚠️  DO NOT MODIFY without version increment and full regression testing.
/// 
/// INPUT CONTRACT:
/// - 400 samples per window
/// - 200 Hz sampling rate  
/// - 6 raw channels: [ax, ay, az, gx, gy, gz] in SI units
/// - ax, ay, az: accelerometer in m/s²
/// - gx, gy, gz: gyroscope in rad/s
/// 
/// OUTPUT CONTRACT:
/// - 8 normalized channels: [ax, ay, az, accel_mag, gx, gy, gz, gyro_mag]
/// - Z-score normalized using fixed training statistics
/// - Values clamped to [-10, +10] to prevent numerical instability
/// 
/// TRAINING DATA: SisFall dataset (bandpass filtered 0.5-20Hz)
/// MODEL VERSION: FallDetector_v1_baseline
/// FROZEN DATE: 2024-12-25
/// ============================================================================

class Preprocessor {
  // ============================================================
  // VERSION LOCK - DO NOT CHANGE
  // ============================================================
  static const String version = '1.0.0';
  static const String modelVersion = 'FallDetector_v1_baseline';
  static const String frozenDate = '2024-12-25';
  
  // ============================================================
  // INPUT CONTRACT CONSTANTS
  // ============================================================
  static const int requiredWindowSize = 400;
  static const int requiredRawChannels = 6;
  static const int outputChannels = 8;
  static const double samplingRateHz = 200.0;
  
  // ============================================================
  // SAFETY BOUNDS - Clamp normalized values to prevent instability
  // ============================================================
  static const double normalizedMin = -10.0;
  static const double normalizedMax = 10.0;
  
  // ============================================================
  // UNIT CONVERSION FACTORS (Phone SI -> SisFall counts)
  // ============================================================
  // SisFall MMA8451Q: 1024 counts/g at ±8g, 1g = 9.80665 m/s²
  // SisFall ITG3200: 14.375 LSB/(°/s), 1 rad/s = 57.2958°/s
  static const double accelScale = 104.4189;  // counts per m/s²
  static const double gyroScale = 823.6271;   // counts per rad/s
  
  // ============================================================
  // HIGH-PASS FILTER STATE (to remove gravity)
  // ============================================================
  // The training data used 0.5Hz high-pass (from bandpass 0.5-20Hz)
  // We use a simple exponential high-pass with alpha ~= 0.98
  // This removes slow-changing components like gravity orientation
  static const double hpAlpha = 0.98;  // Higher = more high-pass (removes more DC)
  
  // Persistent filter state for each accelerometer axis
  static List<double> _accelHpState = [0.0, 0.0, 0.0];
  static List<double> _accelPrevRaw = [0.0, 0.0, 0.0];
  static bool _filterInitialized = false;
  
  // ============================================================
  // TRAINING STATISTICS (FROZEN - extracted from SisFall 2024-12-25)
  // These are in SisFall sensor counts after bandpass filtering
  // Order: [ax, ay, az, accel_mag, gx, gy, gz, gyro_mag]
  // ============================================================
  static const List<double> trainMean = [
    -0.108100,   // ax - near zero because bandpass removes DC
    -0.181585,   // ay
    -0.108891,   // az
    -0.242277,   // accel_mag
    0.113382,    // gx
    0.156914,    // gy
    253.465736,  // gz - slight bias in gyro z
    417.484682,  // gyro_mag
  ];
  
  static const List<double> trainStd = [
    212.180482,  // ax
    415.224954,  // ay
    234.732531,  // az
    574.561888,  // accel_mag
    406.914084,  // gx
    381.328314,  // gy
    456.384550,  // gz
    683.241066,  // gyro_mag
  ];
  
  /// Reset the high-pass filter state (call when starting new monitoring session)
  static void resetFilter() {
    _accelHpState = [0.0, 0.0, 0.0];
    _accelPrevRaw = [0.0, 0.0, 0.0];
    _filterInitialized = false;
  }
  
  /// Clamp a value to safe bounds to prevent numerical instability
  static double _clamp(double value) {
    if (value.isNaN || value.isInfinite) return 0.0;
    return value.clamp(normalizedMin, normalizedMax);
  }
  
  /// Validate raw sample - returns true if valid, false if should skip
  static bool isValidSample(List<double> rawSample) {
    if (rawSample.length != requiredRawChannels) return false;
    for (final v in rawSample) {
      if (v.isNaN || v.isInfinite) return false;
    }
    return true;
  }
  
  /// Convert raw 6-channel sensor data to 8-channel preprocessed data.
  /// 
  /// Input: [ax, ay, az, gx, gy, gz] in SI units (m/s², rad/s)
  /// Output: [ax, ay, az, accel_mag, gx, gy, gz, gyro_mag] (normalized, clamped)
  /// 
  /// Returns null if input is invalid (skip inference for this sample)
  static List<double>? preprocessSample(List<double> rawSample) {
    // CONTRACT: Validate input
    if (!isValidSample(rawSample)) {
      return null; // Signal to skip this sample
    }
    
    // Step 1: Convert to SisFall-equivalent counts
    double ax = rawSample[0] * accelScale;
    double ay = rawSample[1] * accelScale;
    double az = rawSample[2] * accelScale;
    double gx = rawSample[3] * gyroScale;
    double gy = rawSample[4] * gyroScale;
    double gz = rawSample[5] * gyroScale;
    
    // Step 2: High-pass filter accelerometer to remove gravity
    // Formula: hp_out = alpha * (hp_prev + raw - raw_prev)
    if (!_filterInitialized) {
      _accelPrevRaw = [ax, ay, az];
      _accelHpState = [0.0, 0.0, 0.0];
      _filterInitialized = true;
    }
    
    // Apply high-pass filter to each accel axis
    final hpAx = hpAlpha * (_accelHpState[0] + ax - _accelPrevRaw[0]);
    final hpAy = hpAlpha * (_accelHpState[1] + ay - _accelPrevRaw[1]);
    final hpAz = hpAlpha * (_accelHpState[2] + az - _accelPrevRaw[2]);
    
    // Update filter state
    _accelHpState = [hpAx, hpAy, hpAz];
    _accelPrevRaw = [ax, ay, az];
    
    // Use filtered values for accelerometer
    ax = hpAx;
    ay = hpAy;
    az = hpAz;
    
    // Step 3: Compute magnitude features (on filtered data)
    final accelMag = sqrt(ax * ax + ay * ay + az * az);
    final gyroMag = sqrt(gx * gx + gy * gy + gz * gz);
    
    // Step 4: Create 8-channel feature vector
    final features = [ax, ay, az, accelMag, gx, gy, gz, gyroMag];
    
    // Step 5: Z-score normalization with clamping
    final normalized = <double>[];
    for (int i = 0; i < outputChannels; i++) {
      final std = trainStd[i] != 0 ? trainStd[i] : 1.0;
      final norm = (features[i] - trainMean[i]) / std;
      normalized.add(_clamp(norm)); // Clamp to [-10, +10]
    }
    
    return normalized;
  }
  
  /// Preprocess an entire window of raw sensor data.
  /// 
  /// Input: List of 400 samples, each with 6 features [ax, ay, az, gx, gy, gz]
  /// Output: List of 400 samples, each with 8 features (normalized, clamped)
  /// 
  /// Returns null if window has invalid data (skip inference)
  static List<List<double>>? preprocessWindow(List<List<double>> rawWindow) {
    // CONTRACT: Validate window size
    if (rawWindow.length != requiredWindowSize) {
      return null; // Wrong window size - skip inference
    }
    
    final processed = <List<double>>[];
    for (final sample in rawWindow) {
      final result = preprocessSample(sample);
      if (result == null) {
        return null; // Invalid sample - skip entire window
      }
      processed.add(result);
    }
    return processed;
  }
  
  /// Simple moving average filter (lightweight alternative to bandpass).
  /// Call this before preprocessWindow if you want smoothing.
  static List<List<double>> smoothWindow(List<List<double>> window, {int kernelSize = 5}) {
    if (window.length < kernelSize) return window;
    
    final smoothed = <List<double>>[];
    final halfKernel = kernelSize ~/ 2;
    
    for (int i = 0; i < window.length; i++) {
      final sample = <double>[];
      for (int f = 0; f < window[i].length; f++) {
        double sum = 0;
        int count = 0;
        for (int k = -halfKernel; k <= halfKernel; k++) {
          final idx = i + k;
          if (idx >= 0 && idx < window.length) {
            sum += window[idx][f];
            count++;
          }
        }
        sample.add(sum / count);
      }
      smoothed.add(sample);
    }
    
    return smoothed;
  }
}

/// Handles the temporal aggregation logic for fall detection.
/// 
/// Instead of single-window decisions, we use:
/// - Rolling probability buffer
/// - 2-of-3 voting rule
/// - Refractory period to prevent repeated alerts
class TemporalAggregator {
  final int bufferSize;
  final int requiredPositives;
  final Duration refractoryPeriod;
  final double threshold;
  
  final List<double> _probabilityBuffer = [];
  DateTime? _lastAlertTime;
  
  TemporalAggregator({
    this.bufferSize = 3,           // Keep last 3 probabilities
    this.requiredPositives = 2,    // Need 2 of 3 above threshold
    this.refractoryPeriod = const Duration(seconds: 15),
    this.threshold = 0.35,         // Lower threshold (tune based on testing)
  });
  
  /// Add a new probability and check if fall should be triggered.
  /// Returns true if fall detection criteria are met.
  bool addProbabilityAndCheck(double probability) {
    // Add to buffer
    _probabilityBuffer.add(probability);
    
    // Maintain buffer size
    while (_probabilityBuffer.length > bufferSize) {
      _probabilityBuffer.removeAt(0);
    }
    
    // Don't trigger if buffer not full yet
    if (_probabilityBuffer.length < bufferSize) {
      return false;
    }
    
    // Check refractory period
    if (_lastAlertTime != null) {
      final elapsed = DateTime.now().difference(_lastAlertTime!);
      if (elapsed < refractoryPeriod) {
        return false;
      }
    }
    
    // Count how many exceed threshold
    int positiveCount = _probabilityBuffer.where((p) => p > threshold).length;
    
    // Apply voting rule
    if (positiveCount >= requiredPositives) {
      _lastAlertTime = DateTime.now();
      _probabilityBuffer.clear(); // Reset after alert
      return true;
    }
    
    return false;
  }
  
  /// Reset the aggregator state (e.g., after user cancels alert)
  void reset() {
    _probabilityBuffer.clear();
    _lastAlertTime = null;
  }
  
  /// Get current buffer for debugging
  List<double> get currentBuffer => List.unmodifiable(_probabilityBuffer);
  
  /// Get last alert time for logging
  DateTime? get lastAlertTime => _lastAlertTime;
  
  /// Check if in refractory period
  bool get isInRefractoryPeriod {
    if (_lastAlertTime == null) return false;
    return DateTime.now().difference(_lastAlertTime!) < refractoryPeriod;
  }
}

/// ============================================================================
/// POST-IMPACT STILLNESS CHECKER (V1 Enhancement)
/// ============================================================================
/// 
/// Purpose: Reduce false alerts from "drop & catch" or "quick flip" motions.
/// 
/// Logic: A real fall ends with stillness (person on ground).
///        A phone drop + catch does NOT end with stillness.
/// 
/// Implementation:
/// - After a fall probability spike, check if acceleration stabilizes
/// - Stabilized = magnitude near gravity (9.8 m/s²) ± tolerance
/// - For at least N consecutive samples (~1 second)
/// 
/// This is a GATE, not a replacement for ML detection.
/// ============================================================================
class StillnessChecker {
  // Configuration
  static const double gravityMagnitude = 9.80665;  // m/s²
  static const double stabilityTolerance = 2.0;    // ±2 m/s² from gravity
  static const int requiredStillSamples = 150;     // ~0.75s at 200Hz
  static const double stillnessLowThreshold = gravityMagnitude - stabilityTolerance;
  static const double stillnessHighThreshold = gravityMagnitude + stabilityTolerance;
  
  // State
  int _consecutiveStillSamples = 0;
  bool _spikeDetected = false;
  DateTime? _spikeTime;
  static const Duration maxWaitForStillness = Duration(seconds: 3);
  
  /// Call this when a probability spike is detected (before confirming alert)
  void onSpike() {
    _spikeDetected = true;
    _spikeTime = DateTime.now();
    _consecutiveStillSamples = 0;
  }
  
  /// Process a raw sensor sample and check for stillness
  /// Returns true if stillness criteria met after spike
  bool processSample(List<double> rawSample) {
    if (!_spikeDetected) return false;
    
    // Timeout: if we've waited too long, reset
    if (_spikeTime != null && 
        DateTime.now().difference(_spikeTime!) > maxWaitForStillness) {
      reset();
      return false;
    }
    
    // Calculate acceleration magnitude (raw SI units)
    final ax = rawSample[0];
    final ay = rawSample[1];
    final az = rawSample[2];
    final accelMag = sqrt(ax * ax + ay * ay + az * az);
    
    // Check if near gravity (person at rest)
    if (accelMag >= stillnessLowThreshold && accelMag <= stillnessHighThreshold) {
      _consecutiveStillSamples++;
    } else {
      _consecutiveStillSamples = 0; // Reset if not still
    }
    
    // Check if stillness criteria met
    if (_consecutiveStillSamples >= requiredStillSamples) {
      return true; // Confirmed stillness after spike
    }
    
    return false;
  }
  
  /// Reset state (call when alert is triggered or canceled)
  void reset() {
    _spikeDetected = false;
    _spikeTime = null;
    _consecutiveStillSamples = 0;
  }
  
  /// Check if we're waiting for stillness
  bool get isWaitingForStillness => _spikeDetected;
  
  /// Get progress toward stillness threshold (0.0 - 1.0)
  double get stillnessProgress => 
      _consecutiveStillSamples / requiredStillSamples;
}
