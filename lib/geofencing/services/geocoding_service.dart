/// GeocodingService - Convert between coordinates and human-readable addresses.
///
/// Uses the geocoding package for address lookups.
/// Provides:
/// - Forward geocoding: Address string → lat/lng
/// - Reverse geocoding: lat/lng → Address string
/// - Caching to reduce API calls
library;

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';

/// Result of a geocoding operation
class GeocodingResult {
  final bool success;
  final String? address;
  final String? street;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;
  final double? latitude;
  final double? longitude;
  final String? error;

  const GeocodingResult({
    required this.success,
    this.address,
    this.street,
    this.city,
    this.state,
    this.country,
    this.postalCode,
    this.latitude,
    this.longitude,
    this.error,
  });

  factory GeocodingResult.fromPlacemark(Placemark placemark, double lat, double lng) {
    final parts = <String>[];
    
    // Build a readable address
    if (placemark.street != null && placemark.street!.isNotEmpty) {
      parts.add(placemark.street!);
    }
    if (placemark.locality != null && placemark.locality!.isNotEmpty) {
      parts.add(placemark.locality!);
    }
    if (placemark.administrativeArea != null && placemark.administrativeArea!.isNotEmpty) {
      parts.add(placemark.administrativeArea!);
    }
    if (placemark.postalCode != null && placemark.postalCode!.isNotEmpty) {
      parts.add(placemark.postalCode!);
    }
    
    return GeocodingResult(
      success: true,
      address: parts.isNotEmpty ? parts.join(', ') : 'Unknown Location',
      street: placemark.street,
      city: placemark.locality,
      state: placemark.administrativeArea,
      country: placemark.country,
      postalCode: placemark.postalCode,
      latitude: lat,
      longitude: lng,
    );
  }

  factory GeocodingResult.failure(String error) => GeocodingResult(
    success: false,
    error: error,
  );

  /// Short address (street + city)
  String get shortAddress {
    if (street != null && city != null) {
      return '$street, $city';
    }
    if (city != null) return city!;
    if (street != null) return street!;
    return address ?? 'Unknown';
  }
}

/// Service for geocoding operations
class GeocodingService {
  GeocodingService._();

  static final GeocodingService _instance = GeocodingService._();
  static GeocodingService get instance => _instance;

  // Simple cache to reduce API calls
  final Map<String, GeocodingResult> _reverseCache = {};
  final Map<String, GeocodingResult> _forwardCache = {};

  /// Cache duration
  static const Duration _cacheDuration = Duration(hours: 1);
  final Map<String, DateTime> _cacheTimestamps = {};

  // ═══════════════════════════════════════════════════════════════════════════
  // REVERSE GEOCODING (Coordinates → Address)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Convert latitude/longitude to a human-readable address.
  ///
  /// Returns cached result if available and not expired.
  Future<GeocodingResult> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    // Create cache key (rounded to 4 decimal places for ~11m precision)
    final cacheKey = '${latitude.toStringAsFixed(4)},${longitude.toStringAsFixed(4)}';

    // Check cache
    if (_isCacheValid(cacheKey, _reverseCache)) {
      debugPrint('[GeocodingService] Returning cached result for $cacheKey');
      return _reverseCache[cacheKey]!;
    }

    try {
      debugPrint('[GeocodingService] Reverse geocoding: $latitude, $longitude');
      
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      
      if (placemarks.isNotEmpty) {
        final result = GeocodingResult.fromPlacemark(placemarks.first, latitude, longitude);
        
        // Cache the result
        _reverseCache[cacheKey] = result;
        _cacheTimestamps[cacheKey] = DateTime.now();
        
        debugPrint('[GeocodingService] Found address: ${result.address}');
        return result;
      }
      
      return GeocodingResult.failure('No address found for coordinates');
    } catch (e) {
      debugPrint('[GeocodingService] Reverse geocoding error: $e');
      return GeocodingResult.failure('Geocoding failed: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FORWARD GEOCODING (Address → Coordinates)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Convert an address string to coordinates.
  ///
  /// Returns the first matching location.
  Future<GeocodingResult> forwardGeocode(String address) async {
    if (address.trim().isEmpty) {
      return GeocodingResult.failure('Address cannot be empty');
    }

    final cacheKey = address.toLowerCase().trim();

    // Check cache
    if (_isCacheValid(cacheKey, _forwardCache)) {
      debugPrint('[GeocodingService] Returning cached result for "$address"');
      return _forwardCache[cacheKey]!;
    }

    try {
      debugPrint('[GeocodingService] Forward geocoding: "$address"');
      
      final locations = await locationFromAddress(address);
      
      if (locations.isNotEmpty) {
        final location = locations.first;
        
        // Do reverse geocoding to get full address details
        final result = await reverseGeocode(
          latitude: location.latitude,
          longitude: location.longitude,
        );
        
        // Cache the forward result
        _forwardCache[cacheKey] = result;
        _cacheTimestamps[cacheKey] = DateTime.now();
        
        return result;
      }
      
      return GeocodingResult.failure('No location found for address');
    } catch (e) {
      debugPrint('[GeocodingService] Forward geocoding error: $e');
      return GeocodingResult.failure('Geocoding failed: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SEARCH SUGGESTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Search for address suggestions.
  ///
  /// Returns a list of possible addresses matching the query.
  /// Note: The geocoding package doesn't support autocomplete,
  /// so this returns the first few matches from forward geocoding.
  Future<List<GeocodingResult>> searchAddresses(String query) async {
    if (query.trim().length < 3) {
      return [];
    }

    try {
      final locations = await locationFromAddress(query);
      final results = <GeocodingResult>[];

      // Get details for first 5 results
      for (final location in locations.take(5)) {
        final result = await reverseGeocode(
          latitude: location.latitude,
          longitude: location.longitude,
        );
        if (result.success) {
          results.add(result);
        }
      }

      return results;
    } catch (e) {
      debugPrint('[GeocodingService] Search error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CACHE MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════════

  bool _isCacheValid(String key, Map<String, GeocodingResult> cache) {
    if (!cache.containsKey(key)) return false;
    
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return false;
    
    return DateTime.now().difference(timestamp) < _cacheDuration;
  }

  /// Clear all cached results
  void clearCache() {
    _reverseCache.clear();
    _forwardCache.clear();
    _cacheTimestamps.clear();
    debugPrint('[GeocodingService] Cache cleared');
  }
}
