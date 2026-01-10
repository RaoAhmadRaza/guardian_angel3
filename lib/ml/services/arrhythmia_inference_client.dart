import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/arrhythmia_config.dart';
import '../models/arrhythmia_request.dart';
import '../models/arrhythmia_response.dart';
import '../models/arrhythmia_analysis_state.dart';

/// Result of an inference operation.
sealed class ArrhythmiaInferenceResult {
  const ArrhythmiaInferenceResult();
}

/// Successful inference.
@immutable
class ArrhythmiaInferenceSuccess extends ArrhythmiaInferenceResult {
  final ArrhythmiaAnalysisResponse response;
  const ArrhythmiaInferenceSuccess(this.response);
}

/// Failed inference.
@immutable
class ArrhythmiaInferenceFailure extends ArrhythmiaInferenceResult {
  final String requestId;
  final InferenceFailureType failureType;
  final String message;
  final int? httpStatusCode;
  final String? errorCode;

  const ArrhythmiaInferenceFailure({
    required this.requestId,
    required this.failureType,
    required this.message,
    this.httpStatusCode,
    this.errorCode,
  });
}

/// HTTP client for the local arrhythmia inference service.
class ArrhythmiaInferenceClient {
  final String _baseUrl;
  final http.Client _httpClient;
  final Duration _timeout;

  ArrhythmiaInferenceClient({
    String? baseUrl,
    http.Client? httpClient,
    Duration? timeout,
  })  : _baseUrl = baseUrl ?? ArrhythmiaConfig.inferenceServiceUrl,
        _httpClient = httpClient ?? http.Client(),
        _timeout = timeout ?? ArrhythmiaConfig.requestTimeout;

  /// Analyze RR intervals for arrhythmia risk with automatic retry.
  Future<ArrhythmiaInferenceResult> analyze(
    ArrhythmiaAnalysisRequest request,
  ) async {
    // Use cloud function endpoint
    final url = Uri.parse(ArrhythmiaConfig.fullInferenceUrl);

    // Retry loop
    for (int attempt = 0; attempt < ArrhythmiaConfig.maxRetries; attempt++) {
      try {
        debugPrint('[ArrhythmiaInferenceClient] Attempt ${attempt + 1} to $url');
        
        final response = await _httpClient
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'rr_intervals_ms': request.rrIntervalsMs,
                'request_id': request.requestId,
                'window_metadata': request.windowMetadata?.toJson(),
              }),
            )
            .timeout(_timeout);

        final result = _handleResponse(response, request.requestId);
        
        // If success, return immediately
        if (result is ArrhythmiaInferenceSuccess) {
          return result;
        }
        
        // If it's a retryable error, continue loop
        if (result is ArrhythmiaInferenceFailure) {
          final isRetryable = result.failureType == InferenceFailureType.serviceUnavailable ||
                              result.failureType == InferenceFailureType.timeout ||
                              result.failureType == InferenceFailureType.networkError;
          
          if (!isRetryable || attempt == ArrhythmiaConfig.maxRetries - 1) {
            return result;
          }
          
          debugPrint('[ArrhythmiaInferenceClient] Retrying after ${ArrhythmiaConfig.retryDelay.inSeconds}s...');
          await Future.delayed(ArrhythmiaConfig.retryDelay);
        }
      } on TimeoutException {
        if (attempt == ArrhythmiaConfig.maxRetries - 1) {
          return ArrhythmiaInferenceFailure(
            requestId: request.requestId,
            failureType: InferenceFailureType.timeout,
            message: 'Analysis request timed out after ${_timeout.inSeconds} seconds',
          );
        }
        await Future.delayed(ArrhythmiaConfig.retryDelay);
      } on SocketException catch (e) {
        if (attempt == ArrhythmiaConfig.maxRetries - 1) {
          return ArrhythmiaInferenceFailure(
            requestId: request.requestId,
            failureType: InferenceFailureType.serviceUnavailable,
            message: 'Inference service unavailable: ${e.message}',
          );
        }
        await Future.delayed(ArrhythmiaConfig.retryDelay);
      } on http.ClientException catch (e) {
        if (attempt == ArrhythmiaConfig.maxRetries - 1) {
          return ArrhythmiaInferenceFailure(
            requestId: request.requestId,
            failureType: InferenceFailureType.networkError,
            message: 'Network error: ${e.message}',
          );
        }
        await Future.delayed(ArrhythmiaConfig.retryDelay);
      } catch (e) {
        return ArrhythmiaInferenceFailure(
          requestId: request.requestId,
          failureType: InferenceFailureType.unknown,
          message: 'Unexpected error: $e',
        );
      }
    }
    
    return ArrhythmiaInferenceFailure(
      requestId: request.requestId,
      failureType: InferenceFailureType.unknown,
      message: 'Max retries exceeded',
    );
  }

  /// Check if inference service is available.
  Future<ArrhythmiaHealthResponse?> healthCheck() async {
    final url = Uri.parse('$_baseUrl/health');

    try {
      final response = await _httpClient
          .get(url)
          .timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return ArrhythmiaHealthResponse.fromJson(json);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Check if service is available (simple bool check).
  Future<bool> isServiceAvailable() async {
    final health = await healthCheck();
    return health?.isHealthy ?? false;
  }

  ArrhythmiaInferenceResult _handleResponse(
    http.Response response,
    String requestId,
  ) {
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final analysisResponse = ArrhythmiaAnalysisResponse.fromJson(json);
        return ArrhythmiaInferenceSuccess(analysisResponse);
      }

      // Handle error responses
      final detail = json['detail'] as Map<String, dynamic>?;
      if (detail != null) {
        final error = detail['error'] as Map<String, dynamic>?;
        final errorCode = error?['code'] as String?;
        final errorMessage = error?['message'] as String? ?? 'Unknown error';

        final failureType = _mapErrorCodeToFailureType(errorCode);

        return ArrhythmiaInferenceFailure(
          requestId: requestId,
          failureType: failureType,
          message: errorMessage,
          httpStatusCode: response.statusCode,
          errorCode: errorCode,
        );
      }

      return ArrhythmiaInferenceFailure(
        requestId: requestId,
        failureType: InferenceFailureType.unknown,
        message: 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        httpStatusCode: response.statusCode,
      );
    } on FormatException catch (e) {
      return ArrhythmiaInferenceFailure(
        requestId: requestId,
        failureType: InferenceFailureType.networkError,
        message: 'Invalid response format: $e',
        httpStatusCode: response.statusCode,
      );
    }
  }

  InferenceFailureType _mapErrorCodeToFailureType(String? errorCode) {
    return switch (errorCode) {
      'INSUFFICIENT_DATA' => InferenceFailureType.invalidInput,
      'INVALID_RR_VALUES' => InferenceFailureType.invalidInput,
      'WINDOW_TOO_SHORT' => InferenceFailureType.invalidInput,
      'WINDOW_TOO_LONG' => InferenceFailureType.invalidInput,
      'INSUFFICIENT_VALID_DATA' => InferenceFailureType.invalidInput,
      'FEATURE_EXTRACTION_FAILED' => InferenceFailureType.modelError,
      'MODEL_UNAVAILABLE' => InferenceFailureType.serviceUnavailable,
      'INFERENCE_ERROR' => InferenceFailureType.modelError,
      _ => InferenceFailureType.unknown,
    };
  }

  /// Dispose the HTTP client.
  void dispose() {
    _httpClient.close();
  }
}
