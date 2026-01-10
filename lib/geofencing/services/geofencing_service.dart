/// GeofencingService - Background location monitoring and breach detection.
///
/// Responsibilities:
/// - Periodic location checks (configurable interval)
/// - Zone entry/exit detection using Haversine formula
/// - Debouncing to prevent alert spam
/// - Integration with GeofenceAlertService for notifications
///
/// Uses geolocator package for location access.
library;

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/safe_zone_model.dart';
import '../repositories/safe_zone_repository.dart';
import 'geofence_alert_service.dart';

/// Geofencing configuration
class GeofencingConfig {
  /// How often to check location (default: 1 minute)
  final Duration checkInterval;

  /// Minimum distance change to trigger update (meters)
  final double distanceFilter;

  /// Debounce duration to prevent alert spam
  final Duration debounceDuration;

  /// Buffer zone to prevent rapid entry/exit at boundary (meters)
  final double boundaryBuffer;

  const GeofencingConfig({
    this.checkInterval = const Duration(minutes: 1),
    this.distanceFilter = 10.0,
    this.debounceDuration = const Duration(minutes: 5),
    this.boundaryBuffer = 20.0, // 20 meter buffer
  });
}

/// Service for monitoring safe zones
class GeofencingService {
  GeofencingService._();

  static final GeofencingService _instance = GeofencingService._();
  static GeofencingService get instance => _instance;

  final SafeZoneRepository _repository = SafeZoneRepository.instance;
  final GeofenceAlertService _alertService = GeofenceAlertService.instance;

  GeofencingConfig _config = const GeofencingConfig();

  Timer? _monitoringTimer;
  StreamSubscription<Position>? _locationSubscription;
  String? _activePatientUid;
  bool _isMonitoring = false;

  /// Track last alert time per zone to debounce
  final Map<String, DateTime> _lastAlertTime = {};

  /// Track previous inside status for transition detection
  final Map<String, bool> _previousInsideStatus = {};

  /// Whether monitoring is active
  bool get isMonitoring => _isMonitoring;

  /// Current patient UID being monitored
  String? get activePatientUid => _activePatientUid;

  // ═══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Initialize the service with optional config
  Future<void> initialize({GeofencingConfig? config}) async {
    if (config != null) {
      _config = config;
    }
    debugPrint('[GeofencingService] Initialized');
  }

  /// Check and request location permissions
  Future<bool> checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[GeofencingService] Location services disabled');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('[GeofencingService] Permission denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('[GeofencingService] Permission permanently denied');
      return false;
    }

    debugPrint('[GeofencingService] Permission granted: $permission');
    return true;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MONITORING CONTROL
  // ═══════════════════════════════════════════════════════════════════════════

  /// Start monitoring for a patient
  Future<bool> startMonitoring(String patientUid) async {
    if (_isMonitoring && _activePatientUid == patientUid) {
      debugPrint('[GeofencingService] Already monitoring $patientUid');
      return true;
    }

    // Check permissions
    final hasPermission = await checkPermissions();
    if (!hasPermission) {
      debugPrint('[GeofencingService] Cannot start - no permission');
      return false;
    }

    _activePatientUid = patientUid;
    _isMonitoring = true;
    _lastAlertTime.clear();
    _previousInsideStatus.clear();

    // Initialize zone states
    await _initializeZoneStates();

    // Start periodic monitoring
    _monitoringTimer?.cancel();
    _monitoringTimer = Timer.periodic(_config.checkInterval, (_) {
      _performLocationCheck();
    });

    // Also start position stream for real-time updates
    _startPositionStream();

    // Perform initial check
    await _performLocationCheck();

    debugPrint('[GeofencingService] Started monitoring for $patientUid');
    return true;
  }

  /// Stop monitoring
  void stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _isMonitoring = false;
    _activePatientUid = null;
    _lastAlertTime.clear();
    _previousInsideStatus.clear();
    debugPrint('[GeofencingService] Stopped monitoring');
  }

  /// Initialize zone states (check current position vs all zones)
  Future<void> _initializeZoneStates() async {
    if (_activePatientUid == null) return;

    try {
      final position = await _getCurrentPosition();
      if (position == null) return;

      final zones = await _repository.getActiveZonesForPatient(_activePatientUid!);

      for (final zone in zones) {
        final isInside = _isInsideZone(position, zone);
        _previousInsideStatus[zone.id] = isInside;
        
        // Update zone presence in repository
        await _repository.updateZonePresence(zone.id, isInside);
      }

      debugPrint('[GeofencingService] Initialized ${zones.length} zone states');
    } catch (e) {
      debugPrint('[GeofencingService] Failed to initialize states: $e');
    }
  }

  /// Start position stream for real-time updates
  void _startPositionStream() {
    _locationSubscription?.cancel();

    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: _config.distanceFilter.toInt(),
    );

    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (position) => _handlePositionUpdate(position),
      onError: (e) {
        debugPrint('[GeofencingService] Position stream error: $e');
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LOCATION CHECKING
  // ═══════════════════════════════════════════════════════════════════════════

  /// Perform a location check against all active zones
  Future<void> _performLocationCheck() async {
    if (!_isMonitoring || _activePatientUid == null) return;

    try {
      final position = await _getCurrentPosition();
      if (position == null) return;

      await _handlePositionUpdate(position);
    } catch (e) {
      debugPrint('[GeofencingService] Location check failed: $e');
    }
  }

  /// Get current position
  Future<Position?> _getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint('[GeofencingService] Failed to get position: $e');
      return null;
    }
  }

  /// Handle a position update
  Future<void> _handlePositionUpdate(Position position) async {
    if (!_isMonitoring || _activePatientUid == null) return;

    final zones = await _repository.getActiveZonesForPatient(_activePatientUid!);

    for (final zone in zones) {
      await _checkZone(zone, position);
    }
  }

  /// Check a single zone for entry/exit
  Future<void> _checkZone(SafeZoneModel zone, Position position) async {
    final isInside = _isInsideZone(position, zone);
    final wasInside = _previousInsideStatus[zone.id] ?? false;

    // Update presence
    await _repository.updateZonePresence(zone.id, isInside);

    // Detect transition
    if (isInside != wasInside) {
      _previousInsideStatus[zone.id] = isInside;

      if (isInside && !wasInside) {
        // Entry
        await _handleZoneEntry(zone, position);
      } else if (!isInside && wasInside) {
        // Exit
        await _handleZoneExit(zone, position);
      }
    }
  }

  /// Handle zone entry
  Future<void> _handleZoneEntry(SafeZoneModel zone, Position position) async {
    debugPrint('[GeofencingService] Entered zone: ${zone.name}');

    // Check debounce
    if (!_shouldAlert(zone.id)) {
      debugPrint('[GeofencingService] Debounced entry alert for ${zone.name}');
      return;
    }

    // Record event
    final event = await _repository.recordEvent(
      zone: zone,
      eventType: GeofenceEventType.entry,
      latitude: position.latitude,
      longitude: position.longitude,
    );

    // Send alert if configured
    if (zone.alertOnEntry) {
      await _sendAlert(zone, event, position);
    }
  }

  /// Handle zone exit
  Future<void> _handleZoneExit(SafeZoneModel zone, Position position) async {
    debugPrint('[GeofencingService] Exited zone: ${zone.name}');

    // Check debounce
    if (!_shouldAlert(zone.id)) {
      debugPrint('[GeofencingService] Debounced exit alert for ${zone.name}');
      return;
    }

    // Record event
    final event = await _repository.recordEvent(
      zone: zone,
      eventType: GeofenceEventType.exit,
      latitude: position.latitude,
      longitude: position.longitude,
    );

    // Send alert if configured
    if (zone.alertOnExit) {
      await _sendAlert(zone, event, position);
    }
  }

  /// Send alert to caregivers
  Future<void> _sendAlert(
    SafeZoneModel zone,
    GeofenceEvent event,
    Position position,
  ) async {
    try {
      await _alertService.sendGeofenceAlert(
        zone: zone,
        event: event,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      // Mark alert sent
      await _repository.markEventAlertSent(event.id);
      _lastAlertTime[zone.id] = DateTime.now();

      debugPrint('[GeofencingService] Alert sent for ${zone.name}');
    } catch (e) {
      debugPrint('[GeofencingService] Failed to send alert: $e');
    }
  }

  /// Check if we should send an alert (debounce)
  bool _shouldAlert(String zoneId) {
    final lastAlert = _lastAlertTime[zoneId];
    if (lastAlert == null) return true;

    final elapsed = DateTime.now().difference(lastAlert);
    return elapsed > _config.debounceDuration;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GEOMETRY
  // ═══════════════════════════════════════════════════════════════════════════

  /// Check if position is inside zone (with buffer)
  bool _isInsideZone(Position position, SafeZoneModel zone) {
    final distance = _calculateDistance(
      position.latitude,
      position.longitude,
      zone.latitude,
      zone.longitude,
    );

    // Use buffer to prevent rapid in/out at boundary
    // If inside, use radius + buffer to determine exit
    // If outside, use radius - buffer to determine entry
    final wasInside = _previousInsideStatus[zone.id] ?? false;

    if (wasInside) {
      // Must go beyond radius + buffer to register exit
      return distance <= zone.radiusMeters + _config.boundaryBuffer;
    } else {
      // Must be within radius - buffer to register entry
      return distance <= math.max(zone.radiusMeters - _config.boundaryBuffer, 0);
    }
  }

  /// Calculate distance between two points using Haversine formula
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // meters

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * (math.pi / 180);

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC UTILITIES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get current location (for UI)
  Future<Position?> getCurrentLocation() async {
    final hasPermission = await checkPermissions();
    if (!hasPermission) return null;
    return _getCurrentPosition();
  }

  /// Calculate distance from current position to a zone center
  Future<double?> getDistanceToZone(SafeZoneModel zone) async {
    final position = await _getCurrentPosition();
    if (position == null) return null;

    return _calculateDistance(
      position.latitude,
      position.longitude,
      zone.latitude,
      zone.longitude,
    );
  }

  /// Force refresh zone states
  Future<void> refreshZoneStates() async {
    await _initializeZoneStates();
  }
}
