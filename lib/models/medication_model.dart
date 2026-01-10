/// MedicationModel - Persistent medication data model.
///
/// Used for tracking patient medications with Hive persistence.
library;

import 'package:flutter/material.dart';
import '../persistence/type_ids.dart';

/// Represents a single medication entry in the patient's schedule.
class MedicationModel {
  final String id;
  final String patientId;
  final String name;
  final String dose;
  final String time; // 24h format HH:mm
  final String type; // 'pill', 'capsule', 'liquid', 'injection'
  final bool isTaken;
  final int currentStock;
  final int lowStockThreshold;
  final DateTime createdAt;
  final DateTime updatedAt;
  // Critical Issue #10: Add soft delete support
  final bool isDeleted;
  final DateTime? deletedAt;

  const MedicationModel({
    required this.id,
    required this.patientId,
    required this.name,
    required this.dose,
    required this.time,
    required this.type,
    this.isTaken = false,
    this.currentStock = 30,
    this.lowStockThreshold = 5,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
  });

  /// Create a new medication with generated ID
  factory MedicationModel.create({
    required String patientId,
    required String name,
    required String dose,
    required String time,
    required String type,
    int currentStock = 30,
    int lowStockThreshold = 5,
  }) {
    final now = DateTime.now().toUtc();
    return MedicationModel(
      id: 'med_${now.millisecondsSinceEpoch}',
      patientId: patientId,
      name: name,
      dose: dose,
      time: time,
      type: type,
      isTaken: false,
      currentStock: currentStock,
      lowStockThreshold: lowStockThreshold,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Check if stock is low
  bool get isLowStock => currentStock <= lowStockThreshold;

  /// Get display color based on type
  Color get displayColor {
    switch (type.toLowerCase()) {
      case 'capsule':
        return const Color(0xFFEFF6FF);
      case 'liquid':
        return const Color(0xFFFFF7ED);
      case 'injection':
        return const Color(0xFFF0FDF4);
      default:
        return const Color(0xFFF5F3FF);
    }
  }

  /// Get icon color based on type
  Color get iconColor {
    switch (type.toLowerCase()) {
      case 'capsule':
        return const Color(0xFF2563EB);
      case 'liquid':
        return const Color(0xFFEA580C);
      case 'injection':
        return const Color(0xFF16A34A);
      default:
        return const Color(0xFF7C3AED);
    }
  }

  MedicationModel copyWith({
    String? id,
    String? patientId,
    String? name,
    String? dose,
    String? time,
    String? type,
    bool? isTaken,
    int? currentStock,
    int? lowStockThreshold,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
  }) {
    return MedicationModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      name: name ?? this.name,
      dose: dose ?? this.dose,
      time: time ?? this.time,
      type: type ?? this.type,
      isTaken: isTaken ?? this.isTaken,
      currentStock: currentStock ?? this.currentStock,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'patientId': patientId,
    'name': name,
    'dose': dose,
    'time': time,
    'type': type,
    'isTaken': isTaken,
    'currentStock': currentStock,
    'lowStockThreshold': lowStockThreshold,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isDeleted': isDeleted,
    'deletedAt': deletedAt?.toIso8601String(),
  };

  factory MedicationModel.fromJson(Map<String, dynamic> json) => MedicationModel(
    id: json['id'] as String,
    patientId: json['patientId'] as String,
    name: json['name'] as String,
    dose: json['dose'] as String,
    time: json['time'] as String,
    type: json['type'] as String,
    isTaken: json['isTaken'] as bool? ?? false,
    currentStock: json['currentStock'] as int? ?? 30,
    lowStockThreshold: json['lowStockThreshold'] as int? ?? 5,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    isDeleted: json['isDeleted'] as bool? ?? false,
    deletedAt: json['deletedAt'] != null ? DateTime.parse(json['deletedAt'] as String) : null,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicationModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
