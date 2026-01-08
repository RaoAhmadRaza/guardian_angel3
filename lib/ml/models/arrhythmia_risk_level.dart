/// Arrhythmia risk level classification.
enum ArrhythmiaRiskLevel {
  /// Low risk (probability < 0.30)
  low,

  /// Moderate risk (probability 0.30 - 0.50)
  moderate,

  /// Elevated risk (probability 0.50 - 0.70)
  elevated,

  /// High risk (probability > 0.70)
  high;

  /// Parse from API string value.
  static ArrhythmiaRiskLevel fromString(String value) {
    return ArrhythmiaRiskLevel.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => ArrhythmiaRiskLevel.low,
    );
  }

  /// Human-readable display label.
  String get displayLabel => switch (this) {
        ArrhythmiaRiskLevel.low => 'Low Risk',
        ArrhythmiaRiskLevel.moderate => 'Moderate Risk',
        ArrhythmiaRiskLevel.elevated => 'Elevated Risk',
        ArrhythmiaRiskLevel.high => 'High Risk',
      };

  /// Whether this risk level requires attention.
  bool get requiresAttention =>
      this == ArrhythmiaRiskLevel.elevated || this == ArrhythmiaRiskLevel.high;

  /// Color suggestion for UI (as hex string).
  String get colorHex => switch (this) {
        ArrhythmiaRiskLevel.low => '#4CAF50', // Green
        ArrhythmiaRiskLevel.moderate => '#FFC107', // Amber
        ArrhythmiaRiskLevel.elevated => '#FF9800', // Orange
        ArrhythmiaRiskLevel.high => '#F44336', // Red
      };
}

/// Confidence level of the analysis.
enum ArrhythmiaConfidence {
  high,
  medium,
  low;

  static ArrhythmiaConfidence fromString(String value) {
    return ArrhythmiaConfidence.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => ArrhythmiaConfidence.medium,
    );
  }
}

/// Clinical recommendation based on risk.
enum ArrhythmiaRecommendation {
  normalRhythm,
  continueMonitoring,
  consultPhysician,
  seekImmediateCare;

  static ArrhythmiaRecommendation fromString(String value) {
    return switch (value) {
      'normal_rhythm' => ArrhythmiaRecommendation.normalRhythm,
      'continue_monitoring' => ArrhythmiaRecommendation.continueMonitoring,
      'consult_physician' => ArrhythmiaRecommendation.consultPhysician,
      'seek_immediate_care' => ArrhythmiaRecommendation.seekImmediateCare,
      _ => ArrhythmiaRecommendation.normalRhythm,
    };
  }

  String get displayMessage => switch (this) {
        ArrhythmiaRecommendation.normalRhythm =>
          'Your heart rhythm appears normal',
        ArrhythmiaRecommendation.continueMonitoring =>
          'Continue monitoring your heart rhythm',
        ArrhythmiaRecommendation.consultPhysician =>
          'Consider consulting your physician',
        ArrhythmiaRecommendation.seekImmediateCare =>
          'Please seek medical attention',
      };
}
