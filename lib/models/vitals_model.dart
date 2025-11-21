import 'dart:convert';

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
