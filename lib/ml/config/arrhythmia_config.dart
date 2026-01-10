/// Configuration for arrhythmia analysis.
class ArrhythmiaConfig {
  ArrhythmiaConfig._();

  /// Base URL for the inference service.
  /// Uses Firebase Functions in production.
  /// Set via environment or use default Cloud Function URL.
  static String get inferenceServiceUrl {
    // In production, this should be your deployed Firebase Functions URL
    // Format: https://<region>-<project-id>.cloudfunctions.net
    const cloudFunctionUrl = String.fromEnvironment(
      'ARRHYTHMIA_SERVICE_URL',
      defaultValue: 'https://us-central1-guardian-angel-app.cloudfunctions.net',
    );
    return cloudFunctionUrl;
  }

  /// Inference endpoint path
  static const String inferenceEndpoint = '/analyzeArrhythmia';

  /// Full inference URL
  static String get fullInferenceUrl => '$inferenceServiceUrl$inferenceEndpoint';

  /// Request timeout duration.
  static const Duration requestTimeout = Duration(seconds: 10);

  /// Retry count for failed requests
  static const int maxRetries = 3;

  /// Delay between retries
  static const Duration retryDelay = Duration(seconds: 2);

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
