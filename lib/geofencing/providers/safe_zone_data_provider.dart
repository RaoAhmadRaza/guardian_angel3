/// SafeZoneDataProvider - Riverpod providers for safe zone UI.
///
/// Provides reactive data for SafeZonesScreen and AddSafeZoneScreen
/// without modifying the UI structure.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/safe_zone_model.dart';
import '../repositories/safe_zone_repository.dart';
import '../services/geofencing_service.dart';
import '../services/geocoding_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SIMPLE PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

/// Current user UID provider
final safeZoneCurrentUserProvider = Provider<String?>((ref) {
  return FirebaseAuth.instance.currentUser?.uid;
});

/// Safe zone repository instance
final safeZoneRepositoryProvider = Provider<SafeZoneRepository>((ref) {
  return SafeZoneRepository.instance;
});

/// Geofencing service instance
final geofencingServiceProvider = Provider<GeofencingService>((ref) {
  return GeofencingService.instance;
});

// ═══════════════════════════════════════════════════════════════════════════
// SAFE ZONES LIST
// ═══════════════════════════════════════════════════════════════════════════

/// Stream provider for all zones for current user
final safeZonesStreamProvider = StreamProvider<List<SafeZoneModel>>((ref) async* {
  final uid = ref.watch(safeZoneCurrentUserProvider);
  if (uid == null) {
    yield [];
    return;
  }

  final repository = ref.watch(safeZoneRepositoryProvider);
  yield* repository.watchZonesForPatient(uid);
});

/// Future provider for all zones (for initial load)
final safeZonesFutureProvider = FutureProvider<List<SafeZoneModel>>((ref) async {
  final uid = ref.watch(safeZoneCurrentUserProvider);
  if (uid == null) return [];

  final repository = ref.watch(safeZoneRepositoryProvider);
  return repository.getZonesForPatient(uid);
});

/// Active zones count
final activeZonesCountProvider = Provider<int>((ref) {
  final zones = ref.watch(safeZonesStreamProvider);
  return zones.when(
    data: (list) => list.where((z) => z.isActive).length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Total zones count
final totalZonesCountProvider = Provider<int>((ref) {
  final zones = ref.watch(safeZonesStreamProvider);
  return zones.when(
    data: (list) => list.length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

// ═══════════════════════════════════════════════════════════════════════════
// CURRENT LOCATION & STATUS
// ═══════════════════════════════════════════════════════════════════════════

/// Current location provider
final currentLocationProvider = FutureProvider<Position?>((ref) async {
  final service = ref.watch(geofencingServiceProvider);
  return service.getCurrentLocation();
});

/// Whether geofencing monitoring is active
final isMonitoringActiveProvider = Provider<bool>((ref) {
  final service = ref.watch(geofencingServiceProvider);
  return service.isMonitoring;
});

/// Current safe status (which zone is the patient in, if any)
final currentSafeStatusProvider = Provider<SafeZoneStatus>((ref) {
  final zones = ref.watch(safeZonesStreamProvider);
  
  return zones.when(
    data: (list) {
      // Find the zone the patient is currently inside
      final currentZone = list.where((z) => z.isCurrentlyInside == true).firstOrNull;
      
      if (currentZone != null) {
        return SafeZoneStatus(
          isSafe: true,
          currentZoneName: currentZone.name,
          currentZoneType: currentZone.type,
          message: 'Inside ${currentZone.name}',
        );
      }
      
      // Check if there are any active zones to monitor
      final hasActiveZones = list.any((z) => z.isActive);
      
      if (!hasActiveZones) {
        return SafeZoneStatus(
          isSafe: null, // Unknown - no zones configured
          currentZoneName: null,
          currentZoneType: null,
          message: 'No zones configured',
        );
      }
      
      return SafeZoneStatus(
        isSafe: false,
        currentZoneName: null,
        currentZoneType: null,
        message: 'Outside safe zones',
      );
    },
    loading: () => SafeZoneStatus(
      isSafe: null,
      currentZoneName: null,
      currentZoneType: null,
      message: 'Loading...',
    ),
    error: (_, __) => SafeZoneStatus(
      isSafe: null,
      currentZoneName: null,
      currentZoneType: null,
      message: 'Error loading zones',
    ),
  );
});

/// Safe zone status model
class SafeZoneStatus {
  final bool? isSafe; // true = inside safe zone, false = outside, null = unknown
  final String? currentZoneName;
  final SafeZoneType? currentZoneType;
  final String message;

  const SafeZoneStatus({
    required this.isSafe,
    required this.currentZoneName,
    required this.currentZoneType,
    required this.message,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// RECENT EVENTS
// ═══════════════════════════════════════════════════════════════════════════

/// Recent geofence events
final recentGeofenceEventsProvider = FutureProvider<List<GeofenceEvent>>((ref) async {
  final uid = ref.watch(safeZoneCurrentUserProvider);
  if (uid == null) return [];

  final repository = ref.watch(safeZoneRepositoryProvider);
  return repository.getRecentEvents(uid);
});

// ═══════════════════════════════════════════════════════════════════════════
// SAFE ZONE NOTIFIER (FOR CRUD OPERATIONS)
// ═══════════════════════════════════════════════════════════════════════════

/// Notifier for safe zone CRUD operations
class SafeZoneNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  SafeZoneNotifier(this._ref) : super(const AsyncValue.data(null));

  /// Create a new safe zone
  Future<SafeZoneModel?> createZone({
    required String name,
    String? address,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    required SafeZoneType type,
    bool alertOnEntry = false,
    bool alertOnExit = true,
  }) async {
    final uid = _ref.read(safeZoneCurrentUserProvider);
    if (uid == null) {
      state = AsyncValue.error('Not authenticated', StackTrace.current);
      return null;
    }

    state = const AsyncValue.loading();

    try {
      final repository = _ref.read(safeZoneRepositoryProvider);
      final zone = await repository.createZone(
        patientUid: uid,
        name: name,
        address: address,
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
        type: type,
        alertOnEntry: alertOnEntry,
        alertOnExit: alertOnExit,
      );

      state = const AsyncValue.data(null);
      debugPrint('[SafeZoneNotifier] Created zone: ${zone.name}');
      return zone;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      debugPrint('[SafeZoneNotifier] Error creating zone: $e');
      return null;
    }
  }

  /// Update an existing zone
  Future<SafeZoneModel?> updateZone(SafeZoneModel zone) async {
    state = const AsyncValue.loading();

    try {
      final repository = _ref.read(safeZoneRepositoryProvider);
      final updated = await repository.updateZone(zone);
      state = const AsyncValue.data(null);
      return updated;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      debugPrint('[SafeZoneNotifier] Error updating zone: $e');
      return null;
    }
  }

  /// Toggle zone active status
  Future<void> toggleZoneActive(String zoneId) async {
    try {
      final repository = _ref.read(safeZoneRepositoryProvider);
      await repository.toggleZoneActive(zoneId);
    } catch (e) {
      debugPrint('[SafeZoneNotifier] Error toggling zone: $e');
    }
  }

  /// Delete a zone
  Future<void> deleteZone(String zoneId) async {
    state = const AsyncValue.loading();

    try {
      final repository = _ref.read(safeZoneRepositoryProvider);
      await repository.deleteZone(zoneId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      debugPrint('[SafeZoneNotifier] Error deleting zone: $e');
    }
  }
}

/// Provider for safe zone notifier
final safeZoneNotifierProvider = StateNotifierProvider<SafeZoneNotifier, AsyncValue<void>>((ref) {
  return SafeZoneNotifier(ref);
});

// ═══════════════════════════════════════════════════════════════════════════
// GEOFENCING CONTROL
// ═══════════════════════════════════════════════════════════════════════════

/// Notifier for controlling geofencing service
class GeofencingControlNotifier extends StateNotifier<GeofencingControlState> {
  final Ref _ref;

  GeofencingControlNotifier(this._ref) : super(const GeofencingControlState());

  /// Start monitoring
  Future<bool> startMonitoring() async {
    final uid = _ref.read(safeZoneCurrentUserProvider);
    if (uid == null) return false;

    state = state.copyWith(isStarting: true);

    try {
      final service = _ref.read(geofencingServiceProvider);
      final success = await service.startMonitoring(uid);
      
      state = state.copyWith(
        isStarting: false,
        isMonitoring: success,
        error: success ? null : 'Failed to start monitoring',
      );
      
      return success;
    } catch (e) {
      state = state.copyWith(
        isStarting: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Stop monitoring
  void stopMonitoring() {
    final service = _ref.read(geofencingServiceProvider);
    service.stopMonitoring();
    state = state.copyWith(isMonitoring: false);
  }

  /// Check location permissions
  Future<bool> checkPermissions() async {
    final service = _ref.read(geofencingServiceProvider);
    final hasPermission = await service.checkPermissions();
    state = state.copyWith(hasPermission: hasPermission);
    return hasPermission;
  }

  /// Refresh zone states
  Future<void> refreshZoneStates() async {
    state = state.copyWith(isRefreshing: true);
    
    try {
      final service = _ref.read(geofencingServiceProvider);
      await service.refreshZoneStates();
    } finally {
      state = state.copyWith(isRefreshing: false);
    }
  }
}

/// State for geofencing control
class GeofencingControlState {
  final bool isMonitoring;
  final bool isStarting;
  final bool isRefreshing;
  final bool hasPermission;
  final String? error;

  const GeofencingControlState({
    this.isMonitoring = false,
    this.isStarting = false,
    this.isRefreshing = false,
    this.hasPermission = false,
    this.error,
  });

  GeofencingControlState copyWith({
    bool? isMonitoring,
    bool? isStarting,
    bool? isRefreshing,
    bool? hasPermission,
    String? error,
  }) {
    return GeofencingControlState(
      isMonitoring: isMonitoring ?? this.isMonitoring,
      isStarting: isStarting ?? this.isStarting,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      hasPermission: hasPermission ?? this.hasPermission,
      error: error,
    );
  }
}

/// Provider for geofencing control
final geofencingControlProvider = StateNotifierProvider<GeofencingControlNotifier, GeofencingControlState>((ref) {
  return GeofencingControlNotifier(ref);
});

// ═══════════════════════════════════════════════════════════════════════════
// GEOCODING PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

/// Geocoding service instance
final geocodingServiceProvider = Provider<GeocodingService>((ref) {
  return GeocodingService.instance;
});

/// Reverse geocode a location (coordinates to address)
final reverseGeocodeProvider = FutureProvider.family<GeocodingResult, ({double lat, double lng})>((ref, coords) async {
  final service = ref.watch(geocodingServiceProvider);
  return service.reverseGeocode(latitude: coords.lat, longitude: coords.lng);
});

/// Forward geocode an address (address to coordinates)
final forwardGeocodeProvider = FutureProvider.family<GeocodingResult, String>((ref, address) async {
  final service = ref.watch(geocodingServiceProvider);
  return service.forwardGeocode(address);
});

/// Search addresses
final addressSearchProvider = FutureProvider.family<List<GeocodingResult>, String>((ref, query) async {
  final service = ref.watch(geocodingServiceProvider);
  return service.searchAddresses(query);
});
