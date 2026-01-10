/// Community Location Service
/// 
/// Manages user location for the community feature:
/// - Gets current location with permissions handling
/// - Updates location in Firestore with geohash
/// - Manages privacy settings
/// - Battery-optimized location updates
library;

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/community_user.dart';

/// Geohash encoding utilities
class GeoHashEncoder {
  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
  
  /// Encode latitude/longitude to geohash string
  /// Precision 6 gives ~±0.6km accuracy, good for 10km queries
  static String encode(double latitude, double longitude, {int precision = 6}) {
    double minLat = -90.0, maxLat = 90.0;
    double minLon = -180.0, maxLon = 180.0;
    
    final buffer = StringBuffer();
    bool isEven = true;
    int bit = 0;
    int ch = 0;
    
    while (buffer.length < precision) {
      if (isEven) {
        final mid = (minLon + maxLon) / 2;
        if (longitude >= mid) {
          ch |= (1 << (4 - bit));
          minLon = mid;
        } else {
          maxLon = mid;
        }
      } else {
        final mid = (minLat + maxLat) / 2;
        if (latitude >= mid) {
          ch |= (1 << (4 - bit));
          minLat = mid;
        } else {
          maxLat = mid;
        }
      }
      
      isEven = !isEven;
      
      if (bit < 4) {
        bit++;
      } else {
        buffer.write(_base32[ch]);
        bit = 0;
        ch = 0;
      }
    }
    
    return buffer.toString();
  }
  
  /// Get neighboring geohashes for a given geohash
  /// Useful for querying adjacent cells
  static List<String> getNeighbors(String geohash) {
    if (geohash.isEmpty) return [];
    
    // For simplicity, we'll use prefix matching for 10km radius
    // A 4-character geohash prefix covers ~40km x 20km
    // A 5-character geohash prefix covers ~5km x 5km
    return [geohash.substring(0, math.min(4, geohash.length))];
  }
}

/// Service for managing community location
class CommunityLocationService {
  CommunityLocationService._();
  
  static final CommunityLocationService _instance = CommunityLocationService._();
  static CommunityLocationService get instance => _instance;
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  /// Firestore collection name
  static const String _collectionName = 'community_users';
  
  /// SharedPreferences keys
  static const String _keyVisibility = 'community_visibility';
  static const String _keyLastUpdate = 'community_last_location_update';
  
  /// Cached current location
  Position? _cachedPosition;
  DateTime? _lastLocationFetch;
  
  /// Cached user data
  CommunityUser? _cachedUser;
  
  /// Location cache duration (5 minutes)
  static const Duration _cacheExpiry = Duration(minutes: 5);
  
  /// Minimum update interval (15 minutes)
  static const Duration _minUpdateInterval = Duration(minutes: 15);
  
  // ═══════════════════════════════════════════════════════════════════════════
  // PERMISSIONS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Check if location services are available and permitted
  Future<bool> checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[CommunityLocation] Location services disabled');
      return false;
    }
    
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('[CommunityLocation] Permission denied');
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      debugPrint('[CommunityLocation] Permission permanently denied');
      return false;
    }
    
    return true;
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // LOCATION FETCHING
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Get current location (uses cache if recent)
  Future<Position?> getCurrentLocation({bool forceRefresh = false}) async {
    // Check cache
    if (!forceRefresh && 
        _cachedPosition != null && 
        _lastLocationFetch != null &&
        DateTime.now().difference(_lastLocationFetch!) < _cacheExpiry) {
      return _cachedPosition;
    }
    
    // Check permissions
    final hasPermission = await checkLocationPermission();
    if (!hasPermission) return null;
    
    try {
      _cachedPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium, // Balance accuracy vs battery
        timeLimit: const Duration(seconds: 15),
      );
      _lastLocationFetch = DateTime.now();
      
      debugPrint('[CommunityLocation] Got location: ${_cachedPosition!.latitude}, ${_cachedPosition!.longitude}');
      return _cachedPosition;
    } catch (e) {
      debugPrint('[CommunityLocation] Failed to get location: $e');
      return null;
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // FIRESTORE SYNC
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Update user's location in Firestore
  /// Returns true if update was successful
  Future<bool> updateLocationInFirestore({
    required String displayName,
    String? profileImageUrl,
    bool forceUpdate = false,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      debugPrint('[CommunityLocation] No authenticated user');
      return false;
    }
    
    // Check if we should update (throttle to prevent excessive writes)
    if (!forceUpdate) {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdate = prefs.getInt(_keyLastUpdate) ?? 0;
      final lastUpdateTime = DateTime.fromMillisecondsSinceEpoch(lastUpdate);
      
      if (DateTime.now().difference(lastUpdateTime) < _minUpdateInterval) {
        debugPrint('[CommunityLocation] Skipping update - too recent');
        return true; // Not an error, just throttled
      }
    }
    
    // Get current location
    final position = await getCurrentLocation(forceRefresh: forceUpdate);
    if (position == null) {
      debugPrint('[CommunityLocation] Cannot update - no location');
      return false;
    }
    
    // Get visibility setting
    final visibility = await getVisibilitySetting();
    
    // Generate geohash
    final geohash = GeoHashEncoder.encode(
      position.latitude, 
      position.longitude,
      precision: 6,
    );
    
    try {
      // Create GeoPoint for Firestore
      final geoPoint = GeoPoint(position.latitude, position.longitude);
      
      // Prepare user data
      final userData = {
        'displayName': displayName,
        'profileImageUrl': profileImageUrl,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'location': geoPoint,
        'geohash': geohash,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
        'isPatient': true,
        'visibility': visibility.name,
        'isOnline': true,
        'joinedAt': FieldValue.serverTimestamp(),
      };
      
      // Update or create user document
      await _firestore.collection(_collectionName).doc(uid).set(
        userData,
        SetOptions(merge: true),
      );
      
      // Save last update time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyLastUpdate, DateTime.now().millisecondsSinceEpoch);
      
      debugPrint('[CommunityLocation] Updated location in Firestore: $geohash');
      return true;
    } catch (e) {
      debugPrint('[CommunityLocation] Failed to update Firestore: $e');
      return false;
    }
  }
  
  /// Get current user's community profile
  Future<CommunityUser?> getCurrentUserProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    
    if (_cachedUser != null) return _cachedUser;
    
    try {
      final doc = await _firestore.collection(_collectionName).doc(uid).get();
      if (!doc.exists) return null;
      
      _cachedUser = CommunityUser.fromFirestore(doc.data()!, uid);
      return _cachedUser;
    } catch (e) {
      debugPrint('[CommunityLocation] Failed to get user profile: $e');
      return null;
    }
  }
  
  /// Set user as offline when leaving community
  Future<void> setOffline() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    try {
      await _firestore.collection(_collectionName).doc(uid).update({
        'isOnline': false,
      });
    } catch (e) {
      debugPrint('[CommunityLocation] Failed to set offline: $e');
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVACY
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Get current visibility setting
  Future<CommunityVisibility> getVisibilitySetting() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keyVisibility);
    
    return CommunityVisibility.values.firstWhere(
      (v) => v.name == value,
      orElse: () => CommunityVisibility.visible,
    );
  }
  
  /// Get if user is visible (convenience getter)
  Future<bool> get isVisible async {
    final visibility = await getVisibilitySetting();
    return visibility == CommunityVisibility.visible;
  }
  
  /// Set visibility setting
  Future<void> setVisibilitySetting(CommunityVisibility visibility) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyVisibility, visibility.name);
    
    // Update in Firestore
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      try {
        await _firestore.collection(_collectionName).doc(uid).update({
          'visibility': visibility.name,
        });
      } catch (e) {
        debugPrint('[CommunityLocation] Failed to update visibility: $e');
      }
    }
  }
  
  /// Set visibility on/off (convenience method)
  Future<void> setVisibility(bool visible) async {
    await setVisibilitySetting(
      visible ? CommunityVisibility.visible : CommunityVisibility.hidden,
    );
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // DISTANCE CALCULATION
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Calculate distance between two points in kilometers (Haversine formula)
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371.0; // km
    
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
  
  /// Check if a location is within 10km of current position
  Future<bool> isWithinRadius(double lat, double lon, {double radiusKm = 10.0}) async {
    final position = await getCurrentLocation();
    if (position == null) return false;
    
    final distance = calculateDistance(
      position.latitude,
      position.longitude,
      lat,
      lon,
    );
    
    return distance <= radiusKm;
  }
  
  /// Clear caches
  void clearCache() {
    _cachedPosition = null;
    _lastLocationFetch = null;
    _cachedUser = null;
  }
}
