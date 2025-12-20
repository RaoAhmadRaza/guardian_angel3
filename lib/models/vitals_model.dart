import 'dart:convert';

/// PHASE 3 STEP 3.4: Validation error for model data integrity.
class VitalsValidationError implements Exception {
  final String message;
  VitalsValidationError(this.message);
  @override
  String toString() => 'VitalsValidationError: $message';
}

class VitalsModel {
  final String id;
  final String userId;
  final int heartRate;
  final int systolicBp;
  final int diastolicBp;
  final double? temperatureC;
  final int? oxygenPercent;
  final double? stressIndex;
  final DateTime recordedAt;
  final int schemaVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int modelVersion; // internal shape version for adapter compatibility

  const VitalsModel({
    required this.id,
    required this.userId,
    required this.heartRate,
    required this.systolicBp,
    required this.diastolicBp,
    this.temperatureC,
    this.oxygenPercent,
    this.stressIndex,
    required this.recordedAt,
    this.schemaVersion = 1,
    required this.createdAt,
    required this.updatedAt,
    this.modelVersion = 1,
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 3 STEP 3.4: DATA VALIDATION AT WRITE BOUNDARIES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Validates the model and returns it if valid.
  /// Throws [VitalsValidationError] if any field is out of range.
  ///
  /// Usage in repository:
  /// ```dart
  /// await box.put(id, vitals.validated());
  /// ```
  VitalsModel validated() {
    // Heart rate: 20-300 bpm (covers extremes)
    if (heartRate < 20 || heartRate > 300) {
      throw VitalsValidationError('Heart rate must be 20-300 bpm, got $heartRate');
    }

    // Blood pressure: systolic 50-250, diastolic 30-150
    if (systolicBp < 50 || systolicBp > 250) {
      throw VitalsValidationError('Systolic BP must be 50-250 mmHg, got $systolicBp');
    }
    if (diastolicBp < 30 || diastolicBp > 150) {
      throw VitalsValidationError('Diastolic BP must be 30-150 mmHg, got $diastolicBp');
    }

    // Oxygen: 0-100%
    if (oxygenPercent != null && (oxygenPercent! < 0 || oxygenPercent! > 100)) {
      throw VitalsValidationError('Oxygen percent must be 0-100%, got $oxygenPercent');
    }

    // Temperature: 30-45°C (covers extremes)
    if (temperatureC != null && (temperatureC! < 30.0 || temperatureC! > 45.0)) {
      throw VitalsValidationError('Temperature must be 30-45°C, got $temperatureC');
    }

    // Stress index: 0-100
    if (stressIndex != null && (stressIndex! < 0.0 || stressIndex! > 100.0)) {
      throw VitalsValidationError('Stress index must be 0-100, got $stressIndex');
    }

    // ID and userId must not be empty
    if (id.isEmpty) {
      throw VitalsValidationError('ID cannot be empty');
    }
    if (userId.isEmpty) {
      throw VitalsValidationError('User ID cannot be empty');
    }

    return this;
  }

  /// Returns true if all fields are within valid ranges.
  bool get isValid {
    try {
      validated();
      return true;
    } catch (_) {
      return false;
    }
  }

  VitalsModel copyWith({
    int? heartRate,
    int? systolicBp,
    int? diastolicBp,
    double? temperatureC,
    int? oxygenPercent,
    double? stressIndex,
    DateTime? updatedAt,
    int? modelVersion,
  }) => VitalsModel(
        id: id,
        userId: userId,
        heartRate: heartRate ?? this.heartRate,
        systolicBp: systolicBp ?? this.systolicBp,
        diastolicBp: diastolicBp ?? this.diastolicBp,
        temperatureC: temperatureC ?? this.temperatureC,
        oxygenPercent: oxygenPercent ?? this.oxygenPercent,
        stressIndex: stressIndex ?? this.stressIndex,
        recordedAt: recordedAt,
        schemaVersion: schemaVersion,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        modelVersion: modelVersion ?? this.modelVersion,
      );

  factory VitalsModel.fromJson(Map<String, dynamic> json) => VitalsModel(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        heartRate: (json['heart_rate'] as num).toInt(),
        systolicBp: (json['systolic_bp'] as num).toInt(),
        diastolicBp: (json['diastolic_bp'] as num).toInt(),
        temperatureC: (json['temperature_c'] as num?)?.toDouble(),
        oxygenPercent: (json['oxygen_percent'] as num?)?.toInt(),
        stressIndex: (json['stress_index'] as num?)?.toDouble(),
        recordedAt: DateTime.parse(json['recorded_at'] as String).toUtc(),
        schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 1,
        createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
        updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
        modelVersion: (json['model_version'] as num?)?.toInt() ?? 1,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'schema_version': schemaVersion,
        'model_version': modelVersion,
        'user_id': userId,
        'heart_rate': heartRate,
        'systolic_bp': systolicBp,
        'diastolic_bp': diastolicBp,
        'temperature_c': temperatureC,
        'oxygen_percent': oxygenPercent,
        'stress_index': stressIndex,
        'recorded_at': recordedAt.toUtc().toIso8601String(),
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      }..removeWhere((k, v) => v == null);

  @override
  String toString() => jsonEncode(toJson());
}
