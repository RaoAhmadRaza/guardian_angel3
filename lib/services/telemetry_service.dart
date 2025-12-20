import 'dart:async';

// Forward declaration for ServiceInstances (to avoid circular import)
// The actual instance is managed in service_instances.dart
TelemetryService? _sharedInstance;

/// Sets the shared TelemetryService instance.
/// Called by ServiceInstances during initialization.
void setSharedTelemetryInstance(TelemetryService instance) {
  _sharedInstance = instance;
}

/// Gets or creates the shared TelemetryService instance.
TelemetryService getSharedTelemetryInstance() {
  return _sharedInstance ??= TelemetryService();
}

class TelemetryMetricSummary {
  int count = 0;
  double sumMs = 0;
  double minMs = double.infinity;
  double maxMs = 0;
  void record(Duration d) {
    final ms = d.inMicroseconds / 1000.0;
    count++;
    sumMs += ms;
    if (ms < minMs) minMs = ms;
    if (ms > maxMs) maxMs = ms;
  }
  Map<String, dynamic> toJson() => {
        'count': count,
        'sum_ms': sumMs,
        'min_ms': minMs.isFinite ? minMs : 0,
        'max_ms': maxMs,
        'avg_ms': count == 0 ? 0 : sumMs / count,
      };
}

class TelemetryEvent {
  final DateTime ts;
  final String name;
  final Map<String, dynamic> tags;
  final Map<String, dynamic> fields;
  TelemetryEvent(this.name, {Map<String, dynamic>? tags, Map<String, dynamic>? fields})
      : ts = DateTime.now().toUtc(),
        tags = tags ?? const {},
        fields = fields ?? const {};
  Map<String, dynamic> toJson() => {
        'ts': ts.toIso8601String(),
        'name': name,
        'tags': tags,
        'fields': fields,
      };
}

/// Simple in-app telemetry aggregator with pluggable sink.
class TelemetryService {
  // ═══════════════════════════════════════════════════════════════════════
  // SINGLETON (DEPRECATED - Use ServiceInstances or Riverpod provider)
  // ═══════════════════════════════════════════════════════════════════════
  /// Legacy singleton accessor - routes to shared instance.
  ///
  /// **Migration Path:**
  /// ```dart
  /// // Old (deprecated):
  /// TelemetryService.I.increment('event');
  ///
  /// // New (preferred - Riverpod):
  /// ref.read(telemetryServiceProvider).increment('event');
  ///
  /// // Alternative (ServiceInstances for non-Riverpod code):
  /// ServiceInstances.telemetry.increment('event');
  /// ```
  @Deprecated('Use telemetryServiceProvider or ServiceInstances.telemetry instead')
  static TelemetryService get I => getSharedTelemetryInstance();

  // ═══════════════════════════════════════════════════════════════════════
  // PROPER DI CONSTRUCTOR (Use this via Riverpod)
  // ═══════════════════════════════════════════════════════════════════════
  /// Creates a new TelemetryService instance for dependency injection.
  TelemetryService({this.maxEvents = 200});

  final Map<String, num> _counters = {};
  final Map<String, num> _gauges = {};
  final Map<String, TelemetryMetricSummary> _timers = {};
  final List<TelemetryEvent> _recentEvents = [];
  final int maxEvents;
  final StreamController<TelemetryEvent> _stream = StreamController.broadcast();

  Stream<TelemetryEvent> get eventsStream => _stream.stream;

  void increment(String name, [num by = 1]) {
    _counters[name] = (_counters[name] ?? 0) + by;
    _emit(name, fields: {'value': _counters[name]});
  }

  void gauge(String name, num value) {
    _gauges[name] = value;
    _emit(name, fields: {'value': value});
  }

  T time<T>(String name, T Function() fn, {Map<String, dynamic>? tags}) {
    final sw = Stopwatch()..start();
    try {
      return fn();
    } finally {
      sw.stop();
      _recordTimer(name, sw.elapsed, tags: tags);
    }
  }

  Future<T> timeAsync<T>(String name, Future<T> Function() fn, {Map<String, dynamic>? tags}) async {
    final sw = Stopwatch()..start();
    try {
      return await fn();
    } finally {
      sw.stop();
      _recordTimer(name, sw.elapsed, tags: tags);
    }
  }

  void _recordTimer(String name, Duration d, {Map<String, dynamic>? tags}) {
    final summary = _timers.putIfAbsent(name, () => TelemetryMetricSummary())..record(d);
    _emit(name, tags: tags, fields: summary.toJson());
  }

  void _emit(String name, {Map<String, dynamic>? tags, Map<String, dynamic>? fields}) {
    final ev = TelemetryEvent(name, tags: tags, fields: fields);
    _recentEvents.add(ev);
    if (_recentEvents.length > maxEvents) {
      _recentEvents.removeAt(0);
    }
    _stream.add(ev);
    // Placeholder for external integration (e.g., Sentry/Firebase); add calls here.
  }

  Map<String, dynamic> snapshot() => {
        'counters': _counters,
        'gauges': _gauges,
        'timers': _timers.map((k, v) => MapEntry(k, v.toJson())),
        'events': _recentEvents.map((e) => e.toJson()).toList(),
      };
}