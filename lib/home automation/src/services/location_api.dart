import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart' as geo;

/// Device location + reverse geocoding helpers.
///
/// Reverse geocoding uses OpenCage (free tier): https://opencagedata.com/
/// Get an API key and pass it to ReverseGeocodingApi.
class DeviceLocationService {
  /// Requests permission and returns current coordinates.
  static Future<GeoPoint> getCurrentCoordinates() async {
    bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationException('Location services are disabled');
    }

    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) {
        throw LocationException('Location permission denied');
      }
    }

    if (permission == geo.LocationPermission.deniedForever) {
      throw LocationException('Location permission permanently denied. Enable from settings.');
    }

    final pos = await geo.Geolocator.getCurrentPosition(desiredAccuracy: geo.LocationAccuracy.best);
    return GeoPoint(latitude: pos.latitude, longitude: pos.longitude);
  }
}

class ReverseGeocodingApi {
  final String apiKey;
  final http.Client _client;

  ReverseGeocodingApi({required this.apiKey, http.Client? client}) : _client = client ?? http.Client();

  /// Returns a human-friendly place for coordinates (city, state, country).
  Future<LocationPlace> getPlace({required double lat, required double lon, String language = 'en'}) async {
    final uri = Uri.https('api.opencagedata.com', '/geocode/v1/json', {
      'q': '$lat,$lon',
      'key': apiKey,
      'language': language,
      'no_annotations': '1',
    });
    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      throw LocationException('OpenCage error ${res.statusCode}: ${res.body}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final results = (json['results'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    if (results.isEmpty) return LocationPlace.empty();
    final comp = (results.first['components'] as Map<String, dynamic>?);
    final formatted = (results.first['formatted'] as String?) ?? '';

    return LocationPlace(
      city: comp?['city'] ?? comp?['town'] ?? comp?['village'] ?? '',
      state: comp?['state'] ?? '',
      country: comp?['country'] ?? '',
      formatted: formatted,
    );
  }
}

class GeoPoint {
  final double latitude;
  final double longitude;
  const GeoPoint({required this.latitude, required this.longitude});
}

class LocationPlace {
  final String city;
  final String state;
  final String country;
  final String formatted;

  const LocationPlace({required this.city, required this.state, required this.country, required this.formatted});
  const LocationPlace.empty() : city = '', state = '', country = '', formatted = '';
}

class LocationException implements Exception {
  final String message;
  LocationException(this.message);
  @override
  String toString() => 'LocationException: $message';
}
