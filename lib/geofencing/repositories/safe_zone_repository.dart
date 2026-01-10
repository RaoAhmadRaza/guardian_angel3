/// SafeZoneRepository - Local-first persistence for safe zones.
///
/// Architecture:
/// - Hive is the source of truth (local-first)
/// - Firestore is a non-blocking mirror for caregiver access
/// - All operations are optimistic (UI updates immediately)
///
/// Firestore Path: patients/{patientUid}/safe_zones/{zoneId}
library;

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/safe_zone_model.dart';
import '../adapters/safe_zone_adapter.dart';

/// Box names for Hive storage
const String _safeZonesBoxName = 'safe_zones_box';
const String _geofenceEventsBoxName = 'geofence_events_box';

/// Repository for safe zone CRUD operations
class SafeZoneRepository {
  SafeZoneRepository._();

  static final SafeZoneRepository _instance = SafeZoneRepository._();
  static SafeZoneRepository get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  Box<SafeZoneModel>? _zonesBox;
  Box<GeofenceEvent>? _eventsBox;
  bool _isInitialized = false;

  /// Whether the repository is initialized
  bool get isInitialized => _isInitialized;

  // ═══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Initialize the repository (call once at app startup)
  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('[SafeZoneRepository] Initializing...');

    // Register adapters
    registerGeofencingAdapters();

    // Open boxes
    _zonesBox = await Hive.openBox<SafeZoneModel>(_safeZonesBoxName);
    _eventsBox = await Hive.openBox<GeofenceEvent>(_geofenceEventsBoxName);

    _isInitialized = true;
    debugPrint('[SafeZoneRepository] Initialized with ${_zonesBox!.length} zones');
  }

  /// Ensure initialized before operations
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SAFE ZONE CRUD
  // ═══════════════════════════════════════════════════════════════════════════

  /// Create a new safe zone
  Future<SafeZoneModel> createZone({
    required String patientUid,
    required String name,
    String? address,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    required SafeZoneType type,
    bool alertOnEntry = false,
    bool alertOnExit = true,
  }) async {
    await _ensureInitialized();

    final now = DateTime.now().toUtc();
    final zone = SafeZoneModel(
      id: _uuid.v4(),
      patientUid: patientUid,
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      type: type,
      isActive: true,
      alertOnEntry: alertOnEntry,
      alertOnExit: alertOnExit,
      createdAt: now,
      updatedAt: now,
    );

    // Save to Hive (local first)
    await _zonesBox!.put(zone.id, zone);
    debugPrint('[SafeZoneRepository] Created zone: ${zone.name}');

    // Mirror to Firestore (non-blocking)
    _mirrorZoneToFirestore(zone);

    return zone;
  }

  /// Get all zones for a patient
  Future<List<SafeZoneModel>> getZonesForPatient(String patientUid) async {
    await _ensureInitialized();

    final zones = _zonesBox!.values
        .where((z) => z.patientUid == patientUid)
        .toList();

    // Sort by creation date (newest first)
    zones.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return zones;
  }

  /// Get active zones for a patient (for monitoring)
  Future<List<SafeZoneModel>> getActiveZonesForPatient(String patientUid) async {
    await _ensureInitialized();

    return _zonesBox!.values
        .where((z) => z.patientUid == patientUid && z.isActive)
        .toList();
  }

  /// Get a zone by ID
  Future<SafeZoneModel?> getZoneById(String zoneId) async {
    await _ensureInitialized();
    return _zonesBox!.get(zoneId);
  }

  /// Update a zone
  Future<SafeZoneModel> updateZone(SafeZoneModel zone) async {
    await _ensureInitialized();

    final updated = zone.copyWith(updatedAt: DateTime.now().toUtc());
    await _zonesBox!.put(updated.id, updated);
    debugPrint('[SafeZoneRepository] Updated zone: ${updated.name}');

    // Mirror to Firestore
    _mirrorZoneToFirestore(updated);

    return updated;
  }

  /// Toggle zone active status
  Future<SafeZoneModel> toggleZoneActive(String zoneId) async {
    await _ensureInitialized();

    final zone = _zonesBox!.get(zoneId);
    if (zone == null) {
      throw Exception('Zone not found: $zoneId');
    }

    final updated = zone.copyWith(
      isActive: !zone.isActive,
      updatedAt: DateTime.now().toUtc(),
    );

    await _zonesBox!.put(zoneId, updated);
    debugPrint('[SafeZoneRepository] Toggled zone ${zone.name}: ${updated.isActive ? 'active' : 'paused'}');

    // Mirror to Firestore
    _mirrorZoneToFirestore(updated);

    return updated;
  }

  /// Update zone presence (whether patient is inside)
  Future<void> updateZonePresence(String zoneId, bool isInside) async {
    await _ensureInitialized();

    final zone = _zonesBox!.get(zoneId);
    if (zone == null) return;

    final updated = zone.copyWith(
      isCurrentlyInside: isInside,
      lastCheckedAt: DateTime.now().toUtc(),
    );

    await _zonesBox!.put(zoneId, updated);
  }

  /// Delete a zone
  Future<void> deleteZone(String zoneId) async {
    await _ensureInitialized();

    final zone = _zonesBox!.get(zoneId);
    if (zone == null) return;

    await _zonesBox!.delete(zoneId);
    debugPrint('[SafeZoneRepository] Deleted zone: ${zone.name}');

    // Delete from Firestore
    _deleteZoneFromFirestore(zone.patientUid, zoneId);
  }

  /// Delete all zones for a patient
  Future<void> deleteAllZonesForPatient(String patientUid) async {
    await _ensureInitialized();

    final zones = _zonesBox!.values
        .where((z) => z.patientUid == patientUid)
        .toList();

    for (final zone in zones) {
      await _zonesBox!.delete(zone.id);
      _deleteZoneFromFirestore(patientUid, zone.id);
    }

    debugPrint('[SafeZoneRepository] Deleted ${zones.length} zones for patient');
  }

  /// Watch zones for a patient (reactive stream)
  Stream<List<SafeZoneModel>> watchZonesForPatient(String patientUid) async* {
    await _ensureInitialized();

    // Initial data
    yield await getZonesForPatient(patientUid);

    // Watch for changes
    yield* _zonesBox!.watch().map((_) {
      return _zonesBox!.values
          .where((z) => z.patientUid == patientUid)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GEOFENCE EVENTS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Record a geofence event (entry or exit)
  Future<GeofenceEvent> recordEvent({
    required SafeZoneModel zone,
    required GeofenceEventType eventType,
    required double latitude,
    required double longitude,
    bool alertSent = false,
  }) async {
    await _ensureInitialized();

    final event = GeofenceEvent(
      id: _uuid.v4(),
      zoneId: zone.id,
      zoneName: zone.name,
      patientUid: zone.patientUid,
      eventType: eventType,
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now().toUtc(),
      alertSent: alertSent,
    );

    await _eventsBox!.put(event.id, event);
    debugPrint('[SafeZoneRepository] Recorded event: ${event.eventType.displayName} ${zone.name}');

    // Mirror to Firestore
    _mirrorEventToFirestore(event);

    return event;
  }

  /// Get recent events for a patient
  Future<List<GeofenceEvent>> getRecentEvents(
    String patientUid, {
    int limit = 50,
  }) async {
    await _ensureInitialized();

    final events = _eventsBox!.values
        .where((e) => e.patientUid == patientUid)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return events.take(limit).toList();
  }

  /// Mark event as alert sent
  Future<void> markEventAlertSent(String eventId) async {
    await _ensureInitialized();

    final event = _eventsBox!.get(eventId);
    if (event == null) return;

    final updated = GeofenceEvent(
      id: event.id,
      zoneId: event.zoneId,
      zoneName: event.zoneName,
      patientUid: event.patientUid,
      eventType: event.eventType,
      latitude: event.latitude,
      longitude: event.longitude,
      timestamp: event.timestamp,
      alertSent: true,
    );

    await _eventsBox!.put(eventId, updated);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FIRESTORE MIRROR (Non-blocking)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Mirror a zone to Firestore
  void _mirrorZoneToFirestore(SafeZoneModel zone) {
    _firestore
        .collection('patients')
        .doc(zone.patientUid)
        .collection('safe_zones')
        .doc(zone.id)
        .set(zone.toJson(), SetOptions(merge: true))
        .catchError((e) {
      debugPrint('[SafeZoneRepository] Firestore mirror failed: $e');
    });
  }

  /// Delete a zone from Firestore
  void _deleteZoneFromFirestore(String patientUid, String zoneId) {
    _firestore
        .collection('patients')
        .doc(patientUid)
        .collection('safe_zones')
        .doc(zoneId)
        .delete()
        .catchError((e) {
      debugPrint('[SafeZoneRepository] Firestore delete failed: $e');
    });
  }

  /// Mirror an event to Firestore
  void _mirrorEventToFirestore(GeofenceEvent event) {
    _firestore
        .collection('patients')
        .doc(event.patientUid)
        .collection('geofence_events')
        .doc(event.id)
        .set(event.toJson())
        .catchError((e) {
      debugPrint('[SafeZoneRepository] Event mirror failed: $e');
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SYNC FROM FIRESTORE (for new device / reinstall)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Sync zones from Firestore (call on login/app start)
  Future<void> syncFromFirestore(String patientUid) async {
    await _ensureInitialized();

    try {
      debugPrint('[SafeZoneRepository] Syncing from Firestore...');

      final snapshot = await _firestore
          .collection('patients')
          .doc(patientUid)
          .collection('safe_zones')
          .get();

      int synced = 0;
      for (final doc in snapshot.docs) {
        try {
          final zone = SafeZoneModel.fromJson(doc.data());
          
          // Only add if not already in Hive
          final existing = _zonesBox!.get(zone.id);
          if (existing == null) {
            await _zonesBox!.put(zone.id, zone);
            synced++;
          }
        } catch (e) {
          debugPrint('[SafeZoneRepository] Failed to parse zone: $e');
        }
      }

      debugPrint('[SafeZoneRepository] Synced $synced zones from Firestore');
    } catch (e) {
      debugPrint('[SafeZoneRepository] Firestore sync failed: $e');
    }
  }

  /// Clear all local data (for logout)
  Future<void> clearLocalData() async {
    await _ensureInitialized();

    await _zonesBox!.clear();
    await _eventsBox!.clear();
    debugPrint('[SafeZoneRepository] Cleared local data');
  }
}
