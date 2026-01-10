/// Health Stability Score (HSS) Module
///
/// A comprehensive health stability scoring system that aggregates signals from:
/// - Physical mobility (fall detection)
/// - Cardiac health (arrhythmia detection, HRV)
/// - Sleep quality (duration, stages, consistency)
/// - Cognitive/behavioral (medication adherence, mood)
///
/// ## Usage
///
/// ```dart
/// import 'package:guardian_angel/stability_score/stability_score.dart';
///
/// // Initialize the provider
/// await StabilityScoreProvider.instance.initialize();
///
/// // Get current score
/// final score = StabilityScoreProvider.instance.currentScore;
/// print('HSS: ${score?.score}');
///
/// // Record a mood check-in
/// await StabilityScoreProvider.instance.recordMoodCheckIn(4); // 1-5 scale
///
/// // Display in UI
/// StabilityGaugeWidget(
///   score: score,
///   size: 200,
///   showBreakdown: true,
/// );
/// ```
///
/// ## Architecture
///
/// ```
/// ┌─────────────────────────────────────────────────────────────┐
/// │                    StabilityScoreProvider                    │
/// │                    (UI State Management)                     │
/// └───────────────────────────┬─────────────────────────────────┘
///                             │
///                             ▼
/// ┌─────────────────────────────────────────────────────────────┐
/// │                   StabilityScoreService                      │
/// │                   (Fusion Engine)                            │
/// └───────────────────────────┬─────────────────────────────────┘
///                             │
///           ┌────────┬────────┼────────┬────────┐
///           ▼        ▼        ▼        ▼        ▼
///     ┌─────────┐┌─────────┐┌─────────┐┌─────────┐┌─────────────┐
///     │Physical ││Cardiac  ││ Sleep   ││Cognitive││  Personal   │
///     │Signals  ││Signals  ││Signals  ││Signals  ││  Baseline   │
///     └─────────┘└─────────┘└─────────┘└─────────┘└─────────────┘
///           ▲        ▲        ▲        ▲              ▲
///           │        │        │        │              │
///     FallDetection Arrhythmia Sleep   Medication  Baseline
///     Service       Service   Analyzer Collector   Persistence
/// ```
///
/// ## Key Components
///
/// - [StabilityInput] - Aggregated input from all subsystems
/// - [StabilityScoreResult] - Output with score, level, and breakdown
/// - [PersonalBaseline] - Adaptive baseline for personalization
/// - [StabilityScoreService] - Core fusion algorithm
/// - [StabilityScoreProvider] - UI state management
/// - [StabilityGaugeWidget] - Visual display widget
library;

// Models
export 'models/subsystem_signals.dart';
export 'models/personal_baseline.dart';
export 'models/stability_score_result.dart';

// Services
export 'services/stability_score_service.dart';
export 'services/sleep_trend_analyzer.dart';
export 'services/cognitive_signal_collector.dart';
export 'services/baseline_persistence_service.dart';

// Providers
export 'providers/stability_score_provider.dart';

// Widgets
export 'widgets/stability_gauge_widget.dart';
export 'widgets/hss_badge.dart';
