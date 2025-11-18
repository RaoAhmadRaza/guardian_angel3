/// Centralized access to API keys supplied via --dart-define at build/run time.
///
/// Example run commands:
/// flutter run \
///   --dart-define=OWM_API_KEY=your_openweather_key \
///   --dart-define=OPENCAGE_API_KEY=your_opencage_key
class ApiKeys {
  // HARD-CODED KEYS (requested). For production, prefer --dart-define or secure storage.
  static const String openWeatherMap = '6090f92a812b4c6ae7e70c3283d9ee68';
  static const String openCage = 'ce8791732e0444bc8529dc401a672bb5';
}
