import 'dart:developer';
import 'package:tflite_flutter/tflite_flutter.dart';

/// TFLite Fall Detection Model Wrapper
/// 
/// Model: best_fall_model_v2.tflite (CNN trained on SisFall dataset)
/// Input: [1, 400, 8] - 400 samples × 8 features (z-score normalized)
/// Output: [1, 1] - Single sigmoid probability (0.0 to 1.0)
class FallModel {
  Interpreter? _interpreter;
  
  // CORRECT Model settings matching training configuration
  // WINDOW = 400 samples (2 seconds at 200Hz)
  // FEATURES = 8 (ax, ay, az, accel_mag, gx, gy, gz, gyro_mag)
  static const int windowSize = 400;
  static const int numFeatures = 8;

  bool get isLoaded => _interpreter != null;

  Future<void> loadModel() async {
    try {
      final options = InterpreterOptions();
      
      _interpreter = await Interpreter.fromAsset('assets/ml/best_fall_model_v2.tflite', options: options);
      log('[FallModel] Model loaded successfully');
      
      // Print input/output shapes for verification
      var inputShape = _interpreter!.getInputTensor(0).shape;
      var outputShape = _interpreter!.getOutputTensor(0).shape;
      log('[FallModel] Input shape: $inputShape');  // Should be [1, 400, 8]
      log('[FallModel] Output shape: $outputShape'); // Should be [1, 1]
      
      // Validate shapes match expectations
      if (inputShape.length >= 2 && (inputShape[1] != windowSize || inputShape[2] != numFeatures)) {
        log('[FallModel] WARNING: Model shape mismatch! Expected [1, $windowSize, $numFeatures], got $inputShape');
      }
      
    } catch (e) {
      log('[FallModel] Error loading model: $e');
    }
  }

  /// Input: Preprocessed window of shape [400, 8]
  /// Each sample: [ax, ay, az, accel_mag, gx, gy, gz, gyro_mag] (Z-score normalized)
  /// Returns: Fall probability (0.0 to 1.0)
  double predict(List<List<double>> inputWindow) {
    if (_interpreter == null) {
      log('[FallModel] Interpreter not initialized');
      return 0.0;
    }

    if (inputWindow.length != windowSize) {
      log('[FallModel] Invalid window size: ${inputWindow.length}, expected $windowSize');
      return 0.0;
    }

    if (inputWindow.isNotEmpty && inputWindow[0].length != numFeatures) {
      log('[FallModel] Invalid feature count: ${inputWindow[0].length}, expected $numFeatures');
      return 0.0;
    }

    // Shape: [1, 400, 8]
    var input = [inputWindow];
    
    // Output: [1, 1] - single sigmoid probability
    var output = List.generate(1, (_) => List.filled(1, 0.0));

    try {
      _interpreter!.run(input, output);
      double fallProbability = output[0][0];
      log('[FallModel] Inference result: $fallProbability');
      return fallProbability;
    } catch (e) {
      log('[FallModel] Inference error: $e');
      return 0.0;
    }
  }

  void dispose() {
    _interpreter?.close();
  }
}
