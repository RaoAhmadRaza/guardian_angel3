/// HealthThresholdModel - Persistent health threshold settings.
///
/// Used for configuring alert thresholds for patient monitoring.
library;

/// Health threshold configuration for a patient.
class HealthThresholdModel {
  final String id;
  final String patientId;
  final int heartRateMin;
  final int heartRateMax;
  final bool fallDetectionEnabled;
  final bool inactivityAlertEnabled;
  final double inactivityHours;
  final int oxygenMin; // SpO2 percentage
  final int systolicBpMax;
  final int diastolicBpMax;
  final DateTime createdAt;
  final DateTime updatedAt;

  const HealthThresholdModel({
    required this.id,
    required this.patientId,
    this.heartRateMin = 60,
    this.heartRateMax = 100,
    this.fallDetectionEnabled = true,
    this.inactivityAlertEnabled = true,
    this.inactivityHours = 2.0,
    this.oxygenMin = 90,
    this.systolicBpMax = 140,
    this.diastolicBpMax = 90,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create default thresholds for a patient
  factory HealthThresholdModel.defaults(String patientId) {
    final now = DateTime.now().toUtc();
    return HealthThresholdModel(
      id: 'thresh_$patientId',
      patientId: patientId,
      createdAt: now,
      updatedAt: now,
    );
  }

  HealthThresholdModel copyWith({
    String? id,
    String? patientId,
    int? heartRateMin,
    int? heartRateMax,
    bool? fallDetectionEnabled,
    bool? inactivityAlertEnabled,
    double? inactivityHours,
    int? oxygenMin,
    int? systolicBpMax,
    int? diastolicBpMax,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HealthThresholdModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      heartRateMin: heartRateMin ?? this.heartRateMin,
      heartRateMax: heartRateMax ?? this.heartRateMax,
      fallDetectionEnabled: fallDetectionEnabled ?? this.fallDetectionEnabled,
      inactivityAlertEnabled: inactivityAlertEnabled ?? this.inactivityAlertEnabled,
      inactivityHours: inactivityHours ?? this.inactivityHours,
      oxygenMin: oxygenMin ?? this.oxygenMin,
      systolicBpMax: systolicBpMax ?? this.systolicBpMax,
      diastolicBpMax: diastolicBpMax ?? this.diastolicBpMax,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'patientId': patientId,
    'heartRateMin': heartRateMin,
    'heartRateMax': heartRateMax,
    'fallDetectionEnabled': fallDetectionEnabled,
    'inactivityAlertEnabled': inactivityAlertEnabled,
    'inactivityHours': inactivityHours,
    'oxygenMin': oxygenMin,
    'systolicBpMax': systolicBpMax,
    'diastolicBpMax': diastolicBpMax,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory HealthThresholdModel.fromJson(Map<String, dynamic> json) => HealthThresholdModel(
    id: json['id'] as String,
    patientId: json['patientId'] as String,
    heartRateMin: json['heartRateMin'] as int? ?? 60,
    heartRateMax: json['heartRateMax'] as int? ?? 100,
    fallDetectionEnabled: json['fallDetectionEnabled'] as bool? ?? true,
    inactivityAlertEnabled: json['inactivityAlertEnabled'] as bool? ?? true,
    inactivityHours: (json['inactivityHours'] as num?)?.toDouble() ?? 2.0,
    oxygenMin: json['oxygenMin'] as int? ?? 90,
    systolicBpMax: json['systolicBpMax'] as int? ?? 140,
    diastolicBpMax: json['diastolicBpMax'] as int? ?? 90,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HealthThresholdModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
