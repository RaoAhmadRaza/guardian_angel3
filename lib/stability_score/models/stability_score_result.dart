/// Health Stability Score Result Model
///
/// The output of the HSS fusion engine. Contains the overall score
/// plus detailed breakdown for explainability.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Risk level classification based on HSS score.
enum StabilityLevel {
  /// Score 80-100: Stable health patterns
  stable,

  /// Score 60-79: Minor variations detected
  moderate,

  /// Score 40-59: Notable instability
  attention,

  /// Score 0-39: Significant instability detected
  alert,
}

/// Extension to get display properties for stability levels.
extension StabilityLevelExtension on StabilityLevel {
  String get displayName {
    switch (this) {
      case StabilityLevel.stable:
        return 'Stable';
      case StabilityLevel.moderate:
        return 'Moderate';
      case StabilityLevel.attention:
        return 'Attention';
      case StabilityLevel.alert:
        return 'Alert';
    }
  }

  String get description {
    switch (this) {
      case StabilityLevel.stable:
        return 'Your health patterns are stable and consistent.';
      case StabilityLevel.moderate:
        return 'Minor variations detected in your health patterns.';
      case StabilityLevel.attention:
        return 'Some health patterns need attention.';
      case StabilityLevel.alert:
        return 'Significant changes detected. Consider consulting your caregiver.';
    }
  }

  Color get color {
    switch (this) {
      case StabilityLevel.stable:
        return const Color(0xFF22C55E); // Green
      case StabilityLevel.moderate:
        return const Color(0xFFFBBF24); // Yellow
      case StabilityLevel.attention:
        return const Color(0xFFF97316); // Orange
      case StabilityLevel.alert:
        return const Color(0xFFEF4444); // Red
    }
  }

  IconData get icon {
    switch (this) {
      case StabilityLevel.stable:
        return Icons.check_circle;
      case StabilityLevel.moderate:
        return Icons.info;
      case StabilityLevel.attention:
        return Icons.warning_amber;
      case StabilityLevel.alert:
        return Icons.error;
    }
  }
}

/// Contribution from a single subsystem to the overall score.
@immutable
class SubsystemContribution {
  /// Subsystem name
  final String name;

  /// Display name for UI
  final String displayName;

  /// Raw stability score from subsystem (0.0-1.0)
  final double stabilityScore;

  /// Weight applied to this subsystem
  final double weight;

  /// Weighted contribution to overall score
  final double contribution;

  /// Whether this subsystem contributed negatively (pulling score down)
  final bool isDetractor;

  /// Whether data was available for this subsystem
  final bool hasData;

  /// Human-readable insight about this subsystem
  final String? insight;

  const SubsystemContribution({
    required this.name,
    required this.displayName,
    required this.stabilityScore,
    required this.weight,
    required this.contribution,
    required this.isDetractor,
    required this.hasData,
    this.insight,
  });

  /// Get icon for this subsystem
  IconData get icon {
    switch (name) {
      case 'physical':
        return Icons.directions_walk;
      case 'cardiac':
        return Icons.favorite;
      case 'sleep':
        return Icons.bedtime;
      case 'cognitive':
        return Icons.psychology;
      default:
        return Icons.analytics;
    }
  }

  /// Get color based on stability score
  Color get statusColor {
    if (!hasData) return Colors.grey;
    if (stabilityScore >= 0.8) return const Color(0xFF22C55E);
    if (stabilityScore >= 0.6) return const Color(0xFFFBBF24);
    if (stabilityScore >= 0.4) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }

  @override
  String toString() =>
      'Contribution($name: ${(stabilityScore * 100).toStringAsFixed(0)}% × ${weight.toStringAsFixed(2)} = ${contribution.toStringAsFixed(2)})';
}

/// Complete Health Stability Score result.
@immutable
class StabilityScoreResult {
  /// The overall Health Stability Score (0-100)
  final double score;

  /// Stability level classification
  final StabilityLevel level;

  /// Individual subsystem contributions
  final List<SubsystemContribution> contributions;

  /// Primary detractors (subsystems pulling score down)
  final List<String> detractors;

  /// Whether the score is reliable (enough data)
  final bool isReliable;

  /// Confidence level in the score (0.0-1.0)
  final double confidence;

  /// Trend compared to personal baseline (-1.0 to 1.0)
  final double trend;

  /// Human-readable trend description
  final String trendDescription;

  /// Timestamp when this score was computed
  final DateTime computedAt;

  /// Any warnings or alerts
  final List<String> warnings;

  const StabilityScoreResult({
    required this.score,
    required this.level,
    required this.contributions,
    required this.detractors,
    required this.isReliable,
    required this.confidence,
    required this.trend,
    required this.trendDescription,
    required this.computedAt,
    required this.warnings,
  });

  /// Create a placeholder result when no data is available
  StabilityScoreResult.noData()
      : score = 0.0,
        level = StabilityLevel.moderate,
        contributions = const [],
        detractors = const [],
        isReliable = false,
        confidence = 0.0,
        trend = 0.0,
        trendDescription = 'No data available',
        computedAt = DateTime.now(),
        warnings = const ['Insufficient data to compute stability score'];

  /// Get the primary insight (most impactful information)
  String get primaryInsight {
    if (!isReliable) {
      return 'More health data is needed for accurate scoring.';
    }

    if (detractors.isEmpty) {
      return 'All health indicators are stable.';
    }

    if (detractors.length == 1) {
      return '${_formatSubsystemName(detractors.first)} needs attention.';
    }

    return '${detractors.length} areas need attention: ${detractors.map(_formatSubsystemName).join(", ")}.';
  }

  String _formatSubsystemName(String name) {
    switch (name) {
      case 'physical':
        return 'Physical mobility';
      case 'cardiac':
        return 'Heart health';
      case 'sleep':
        return 'Sleep quality';
      case 'cognitive':
        return 'Medication & wellness';
      default:
        return name;
    }
  }

  /// Get score as percentage string
  String get scorePercentage => '${score.round()}%';

  /// Get gradient colors for gauge based on level
  List<Color> get gaugeGradient {
    switch (level) {
      case StabilityLevel.stable:
        return [const Color(0xFF22C55E), const Color(0xFF86EFAC)];
      case StabilityLevel.moderate:
        return [const Color(0xFFFBBF24), const Color(0xFFFDE68A)];
      case StabilityLevel.attention:
        return [const Color(0xFFF97316), const Color(0xFFFED7AA)];
      case StabilityLevel.alert:
        return [const Color(0xFFEF4444), const Color(0xFFFECACA)];
    }
  }

  StabilityScoreResult copyWith({
    double? score,
    StabilityLevel? level,
    List<SubsystemContribution>? contributions,
    List<String>? detractors,
    bool? isReliable,
    double? confidence,
    double? trend,
    String? trendDescription,
    DateTime? computedAt,
    List<String>? warnings,
  }) {
    return StabilityScoreResult(
      score: score ?? this.score,
      level: level ?? this.level,
      contributions: contributions ?? this.contributions,
      detractors: detractors ?? this.detractors,
      isReliable: isReliable ?? this.isReliable,
      confidence: confidence ?? this.confidence,
      trend: trend ?? this.trend,
      trendDescription: trendDescription ?? this.trendDescription,
      computedAt: computedAt ?? this.computedAt,
      warnings: warnings ?? this.warnings,
    );
  }

  /// Convert to JSON for logging/analytics
  Map<String, dynamic> toJson() => {
        'score': score,
        'level': level.name,
        'contributions': contributions
            .map((c) => {
                  'name': c.name,
                  'stabilityScore': c.stabilityScore,
                  'weight': c.weight,
                  'contribution': c.contribution,
                  'hasData': c.hasData,
                })
            .toList(),
        'detractors': detractors,
        'isReliable': isReliable,
        'confidence': confidence,
        'trend': trend,
        'trendDescription': trendDescription,
        'computedAt': computedAt.toIso8601String(),
        'warnings': warnings,
      };

  @override
  String toString() =>
      'StabilityScore(${score.toStringAsFixed(1)}, ${level.name}, reliable=$isReliable, detractors=$detractors)';
}

/// Historical entry for trend tracking.
@immutable
class StabilityScoreHistoryEntry {
  final double score;
  final StabilityLevel level;
  final DateTime timestamp;
  final Map<String, double> subsystemScores;

  const StabilityScoreHistoryEntry({
    required this.score,
    required this.level,
    required this.timestamp,
    required this.subsystemScores,
  });

  Map<String, dynamic> toJson() => {
        'score': score,
        'level': level.name,
        'timestamp': timestamp.toIso8601String(),
        'subsystemScores': subsystemScores,
      };

  factory StabilityScoreHistoryEntry.fromJson(Map<String, dynamic> json) {
    return StabilityScoreHistoryEntry(
      score: (json['score'] as num).toDouble(),
      level: StabilityLevel.values.firstWhere(
        (l) => l.name == json['level'],
        orElse: () => StabilityLevel.moderate,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      subsystemScores: (json['subsystemScores'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toDouble())),
    );
  }

  @override
  String toString() =>
      'HistoryEntry(${score.toStringAsFixed(1)} @ ${timestamp.toIso8601String()})';
}
