import 'dart:convert';
import 'package:http/http.dart' as http;

/// Simple client for OpenWeatherMap current weather API.
///
/// Sign up for a free API key: https://openweathermap.org/
/// Example usage:
/// final api = WeatherApi(apiKey: const String.fromEnvironment('OWM_API_KEY'));
/// final weather = await api.getCurrent(lat: 40.71, lon: -74.0);
class WeatherApi {
  final String apiKey;
  final http.Client _client;

  WeatherApi({required this.apiKey, http.Client? client}) : _client = client ?? http.Client();

  Future<WeatherCurrent> getCurrent({required double lat, required double lon, String units = 'metric'}) async {
    final uri = Uri.https('api.openweathermap.org', '/data/2.5/weather', {
      'lat': lat.toString(),
      'lon': lon.toString(),
      'appid': apiKey,
      'units': units,
    });
    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      throw WeatherApiException('OpenWeatherMap error ${res.statusCode}: ${res.body}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return WeatherCurrent.fromJson(json);
  }
}

class WeatherCurrent {
  final double temperature; // Celsius when units=metric
  final String description;  // e.g., "clear sky"
  final int humidity;        // %
  final double windSpeed;    // m/s
  final String icon;         // OWM icon code
  final String city;

  WeatherCurrent({
    required this.temperature,
    required this.description,
    required this.humidity,
    required this.windSpeed,
    required this.icon,
    required this.city,
  });

  factory WeatherCurrent.fromJson(Map<String, dynamic> json) {
    final main = json['main'] as Map<String, dynamic>;
    final weatherList = (json['weather'] as List).cast<Map<String, dynamic>>();
    final weather0 = weatherList.isNotEmpty ? weatherList.first : const {};
    final wind = (json['wind'] as Map<String, dynamic>?) ?? const {};
    return WeatherCurrent(
      temperature: (main['temp'] as num).toDouble(),
      description: (weather0['description'] as String?) ?? '—',
      humidity: (main['humidity'] as num?)?.toInt() ?? 0,
      windSpeed: (wind['speed'] as num?)?.toDouble() ?? 0.0,
      icon: (weather0['icon'] as String?) ?? '01d',
      city: (json['name'] as String?) ?? '',
    );
  }
}

class WeatherApiException implements Exception {
  final String message;
  WeatherApiException(this.message);
  @override
  String toString() => 'WeatherApiException: $message';
}
