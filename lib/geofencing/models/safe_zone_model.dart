/// SafeZoneModel - Represents a geographic safe zone for patient monitoring.
///
/// A safe zone is a circular area defined by:
/// - Center point (latitude, longitude)
/// - Radius in meters
/// - Name and type for identification
///
/// When the patient exits or enters a safe zone, caregivers are notified.
library;

import 'package:flutter/cupertino.dart';

/// Type of safe zone for categorization and icon display
enum SafeZoneType {
  home,
  work,
  park,
  gym,
  school,
  medical,
  grocery,
  other,
}

extension SafeZoneTypeExtension on SafeZoneType {
  String get displayName {
    switch (this) {
      case SafeZoneType.home:
        return 'Home';
      case SafeZoneType.work:
        return 'Work';
      case SafeZoneType.park:
        return 'Park';
      case SafeZoneType.gym:
        return 'Gym';
      case SafeZoneType.school:
        return 'School';
      case SafeZoneType.medical:
        return 'Medical';
      case SafeZoneType.grocery:
        return 'Grocery';
      case SafeZoneType.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case SafeZoneType.home:
        return CupertinoIcons.house_fill;
      case SafeZoneType.work:
        return CupertinoIcons.briefcase_fill;
      case SafeZoneType.park:
        return CupertinoIcons.tree;
      case SafeZoneType.gym:
        return CupertinoIcons.sportscourt_fill;
      case SafeZoneType.school:
        return CupertinoIcons.book_fill;
      case SafeZoneType.medical:
        return CupertinoIcons.heart_fill;
      case SafeZoneType.grocery:
        return CupertinoIcons.cart_fill;
      case SafeZoneType.other:
        return CupertinoIcons.location_fill;
    }
  }

  int get colorValue {
    switch (this) {
      case SafeZoneType.home:
        return 0xFF2563EB; // blue-600
      case SafeZoneType.work:
        return 0xFF7C3AED; // violet-600
      case SafeZoneType.park:
        return 0xFF059669; // emerald-600
      case SafeZoneType.gym:
        return 0xFFDC2626; // red-600
      case SafeZoneType.school:
        return 0xFFF59E0B; // amber-500
      case SafeZoneType.medical:
        return 0xFFEC4899; // pink-500
      case SafeZoneType.grocery:
        return 0xFF10B981; // emerald-500
      case SafeZoneType.other:
        return 0xFF6B7280; // gray-500
    }
  }

  int get backgroundColorValue {
    switch (this) {
      case SafeZoneType.home:
        return 0xFFEFF6FF; // blue-50
      case SafeZoneType.work:
        return 0xFFF5F3FF; // violet-50
      case SafeZoneType.park:
        return 0xFFECFDF5; // emerald-50
      case SafeZoneType.gym:
        return 0xFFFEF2F2; // red-50
      case SafeZoneType.school:
        return 0xFFFFFBEB; // amber-50
      case SafeZoneType.medical:
        return 0xFFFDF2F8; // pink-50
      case SafeZoneType.grocery:
        return 0xFFECFDF5; // emerald-50
      case SafeZoneType.other:
        return 0xFFF9FAFB; // gray-50
    }
  }

  static SafeZoneType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'home':
        return SafeZoneType.home;
      case 'work':
        return SafeZoneType.work;
      case 'park':
        return SafeZoneType.park;
      case 'gym':
        return SafeZoneType.gym;
      case 'school':
        return SafeZoneType.school;
      case 'medical':
        return SafeZoneType.medical;
      case 'grocery':
        return SafeZoneType.grocery;
      default:
        return SafeZoneType.other;
    }
  }
}

/// Safe zone data model
class SafeZoneModel {
  /// Unique identifier
  final String id;

  /// Patient UID who owns this zone
  final String patientUid;

  /// Display name (e.g., "Home", "Mom's House")
  final String name;

  /// Optional address description
  final String? address;

  /// Center latitude
  final double latitude;

  /// Center longitude
  final double longitude;

  /// Radius in meters
  final double radiusMeters;

  /// Zone type for categorization
  final SafeZoneType type;

  /// Whether this zone is actively monitored
  final bool isActive;

  /// Whether alerts should be sent when patient ENTERS this zone
  final bool alertOnEntry;

  /// Whether alerts should be sent when patient EXITS this zone
  final bool alertOnExit;

  /// When the zone was created
  final DateTime createdAt;

  /// When the zone was last updated
  final DateTime updatedAt;

  /// Whether the patient is currently inside this zone
  final bool? isCurrentlyInside;

  /// Last time presence was checked
  final DateTime? lastCheckedAt;

  const SafeZoneModel({
    required this.id,
    required this.patientUid,
    required this.name,
    this.address,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.type,
    this.isActive = true,
    this.alertOnEntry = false,
    this.alertOnExit = true,
    required this.createdAt,
    required this.updatedAt,
    this.isCurrentlyInside,
    this.lastCheckedAt,
  });

  /// Create a copy with updated fields
  SafeZoneModel copyWith({
    String? id,
    String? patientUid,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    SafeZoneType? type,
    bool? isActive,
    bool? alertOnEntry,
    bool? alertOnExit,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isCurrentlyInside,
    DateTime? lastCheckedAt,
  }) {
    return SafeZoneModel(
      id: id ?? this.id,
      patientUid: patientUid ?? this.patientUid,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
      alertOnEntry: alertOnEntry ?? this.alertOnEntry,
      alertOnExit: alertOnExit ?? this.alertOnExit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isCurrentlyInside: isCurrentlyInside ?? this.isCurrentlyInside,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
    );
  }

  /// Convert to JSON for Firestore/Hive
  Map<String, dynamic> toJson() => {
        'id': id,
        'patient_uid': patientUid,
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'radius_meters': radiusMeters,
        'type': type.name,
        'is_active': isActive,
        'alert_on_entry': alertOnEntry,
        'alert_on_exit': alertOnExit,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'is_currently_inside': isCurrentlyInside,
        'last_checked_at': lastCheckedAt?.toUtc().toIso8601String(),
      };

  /// Create from JSON
  factory SafeZoneModel.fromJson(Map<String, dynamic> json) {
    return SafeZoneModel(
      id: json['id'] as String,
      patientUid: json['patient_uid'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radiusMeters: (json['radius_meters'] as num).toDouble(),
      type: SafeZoneTypeExtension.fromString(json['type'] as String? ?? 'other'),
      isActive: json['is_active'] as bool? ?? true,
      alertOnEntry: json['alert_on_entry'] as bool? ?? false,
      alertOnExit: json['alert_on_exit'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isCurrentlyInside: json['is_currently_inside'] as bool?,
      lastCheckedAt: json['last_checked_at'] != null
          ? DateTime.parse(json['last_checked_at'] as String)
          : null,
    );
  }

  /// Get formatted radius string
  String get radiusDisplay {
    if (radiusMeters >= 1000) {
      return '${(radiusMeters / 1000).toStringAsFixed(1)}km';
    }
    return '${radiusMeters.toInt()}m';
  }

  /// Get status display string
  String get statusDisplay => isActive ? 'Monitoring' : 'Paused';

  @override
  String toString() =>
      'SafeZoneModel(id: $id, name: $name, lat: $latitude, lng: $longitude, radius: $radiusMeters)';
}

/// Geofence event when patient enters or exits a zone
class GeofenceEvent {
  final String id;
  final String zoneId;
  final String zoneName;
  final String patientUid;
  final GeofenceEventType eventType;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final bool alertSent;

  const GeofenceEvent({
    required this.id,
    required this.zoneId,
    required this.zoneName,
    required this.patientUid,
    required this.eventType,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.alertSent = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'zone_id': zoneId,
        'zone_name': zoneName,
        'patient_uid': patientUid,
        'event_type': eventType.name,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'alert_sent': alertSent,
      };

  factory GeofenceEvent.fromJson(Map<String, dynamic> json) {
    return GeofenceEvent(
      id: json['id'] as String,
      zoneId: json['zone_id'] as String,
      zoneName: json['zone_name'] as String,
      patientUid: json['patient_uid'] as String,
      eventType: GeofenceEventType.values.firstWhere(
        (e) => e.name == json['event_type'],
        orElse: () => GeofenceEventType.exit,
      ),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      alertSent: json['alert_sent'] as bool? ?? false,
    );
  }
}

enum GeofenceEventType {
  entry,
  exit,
}

extension GeofenceEventTypeExtension on GeofenceEventType {
  String get displayName {
    switch (this) {
      case GeofenceEventType.entry:
        return 'Entered';
      case GeofenceEventType.exit:
        return 'Left';
    }
  }

  String get emoji {
    switch (this) {
      case GeofenceEventType.entry:
        return '📍';
      case GeofenceEventType.exit:
        return '🚶';
    }
  }
}
