/// Arrhythmia Detection ML Module
///
/// Provides local-only arrhythmia risk detection using a FastAPI inference service.
/// The service runs the trained XGBoost model unchanged.
///
/// ## Architecture
/// ```
/// Flutter App → ArrhythmiaAnalysisService → ArrhythmiaInferenceClient
///                                               ↓
///                                         HTTP localhost:8000
///                                               ↓
///                            Python FastAPI → XGBoost Model
/// ```
///
/// ## Components
/// - [ArrhythmiaAnalysisRequest] / [ArrhythmiaAnalysisResponse] - DTOs
/// - [ArrhythmiaInferenceClient] - HTTP client for localhost service
/// - [ArrhythmiaAnalysisService] - Orchestration layer with caching
/// - [arrhythmiaAnalysisStateProvider] - Riverpod state management
///
/// ## Quick Start
/// ```dart
/// import 'package:guardian_angel_fyp/ml/ml.dart';
///
/// // Get provider
/// final state = ref.watch(arrhythmiaAnalysisStateProvider);
///
/// // Trigger analysis
/// await ref.read(arrhythmiaAnalysisStateProvider.notifier)
///     .analyzeRRIntervals(rrIntervalsMs);
/// ```
library;

// Configuration
export 'config/arrhythmia_config.dart';

// Models
export 'models/arrhythmia_request.dart';
export 'models/arrhythmia_response.dart';
export 'models/arrhythmia_risk_level.dart';
export 'models/arrhythmia_analysis_state.dart';

// Services
export 'services/arrhythmia_inference_client.dart';
export 'services/arrhythmia_analysis_service.dart';

// Providers (Riverpod)
export 'providers/arrhythmia_provider.dart';
