/// Configuration for arrhythmia analysis.
class ArrhythmiaConfig {
  ArrhythmiaConfig._();

  /// Base URL for the local inference service.
  static const String inferenceServiceUrl = 'http://127.0.0.1:8000';

  /// Request timeout duration.
  static const Duration requestTimeout = Duration(seconds: 5);

  /// Health check interval.
  static const Duration healthCheckInterval = Duration(minutes: 1);

  /// Minimum RR intervals required for analysis.
  static const int minRRIntervalsRequired = 40;

  /// Maximum RR intervals to send.
  static const int maxRRIntervals = 200;

  /// Analysis window duration.
  static const Duration analysisWindowDuration = Duration(seconds: 60);

  /// Threshold for considering analysis data stale.
  static const Duration staleAnalysisThreshold = Duration(minutes: 15);

  /// Valid RR interval range (ms).
  static const int minRRValueMs = 200;
  static const int maxRRValueMs = 2000;
}
