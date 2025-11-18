import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/location_api.dart';
import '../../services/weather_api.dart';
import '../../services/api_keys.dart';

final deviceLocationProvider = FutureProvider<GeoPoint>((ref) async {
  return DeviceLocationService.getCurrentCoordinates();
});

/// Emits immediately, then every hour, to drive periodic refresh.
final weatherTickProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream<DateTime>.periodic(const Duration(hours: 1), (_) => DateTime.now());
});

final reverseGeocodeProvider = FutureProvider<LocationPlace>((ref) async {
  // Recompute on hourly tick in case user moves
  ref.watch(weatherTickProvider);
  final point = await ref.watch(deviceLocationProvider.future);
  // Key now hard-coded; remove throw to allow graceful fallback
  final api = ReverseGeocodingApi(apiKey: ApiKeys.openCage);
  return api.getPlace(lat: point.latitude, lon: point.longitude);
});

/// Fetches current weather now and then every hour.
final currentWeatherProvider = FutureProvider<WeatherCurrent>((ref) async {
  ref.watch(weatherTickProvider); // refresh on each tick
  final point = await ref.watch(deviceLocationProvider.future);
  final api = WeatherApi(apiKey: ApiKeys.openWeatherMap);
  return api.getCurrent(lat: point.latitude, lon: point.longitude, units: 'metric');
});
