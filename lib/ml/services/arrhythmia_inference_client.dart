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

  /// Analyze RR intervals for arrhythmia risk.
  Future<ArrhythmiaInferenceResult> analyze(
    ArrhythmiaAnalysisRequest request,
  ) async {
    final url = Uri.parse('$_baseUrl/v1/arrhythmia/analyze');

    try {
      final response = await _httpClient
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(request.toJson()),
          )
          .timeout(_timeout);

      return _handleResponse(response, request.requestId);
    } on TimeoutException {
      return ArrhythmiaInferenceFailure(
        requestId: request.requestId,
        failureType: InferenceFailureType.timeout,
        message: 'Analysis request timed out after ${_timeout.inSeconds} seconds',
      );
    } on SocketException catch (e) {
      return ArrhythmiaInferenceFailure(
        requestId: request.requestId,
        failureType: InferenceFailureType.serviceUnavailable,
        message: 'Inference service unavailable: ${e.message}',
      );
    } on http.ClientException catch (e) {
      return ArrhythmiaInferenceFailure(
        requestId: request.requestId,
        failureType: InferenceFailureType.networkError,
        message: 'Network error: ${e.message}',
      );
    } catch (e) {
      return ArrhythmiaInferenceFailure(
        requestId: request.requestId,
        failureType: InferenceFailureType.unknown,
        message: 'Unexpected error: $e',
      );
    }
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
