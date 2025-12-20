/// Operation Router - Maps operation types to API endpoints
/// 
/// Follows the specification from specs/sync/op_router.md

/// Path builder function type
typedef PathBuilder = String Function(Map<String, dynamic> payload);

/// Payload transformer function type
typedef PayloadTransformer = Map<String, dynamic> Function(
    Map<String, dynamic> payload);

/// Route definition for an operation
class RouteDef {
  /// HTTP method (GET, POST, PUT, PATCH, DELETE)
  final String method;

  /// Function to build the API path from payload
  final PathBuilder pathBuilder;

  /// Optional payload transformation before sending
  final PayloadTransformer? transform;

  /// Whether this operation requires idempotency key
  final bool requiresIdempotency;

  RouteDef({
    required this.method,
    required this.pathBuilder,
    this.transform,
    this.requiresIdempotency = true,
  });
}

/// Operation Router - Maps operations to HTTP endpoints
class OpRouter {
  final Map<String, RouteDef> _routes = {};

  /// Register a route for an operation type
  /// 
  /// [opType] - Operation type (e.g., 'create', 'update', 'delete')
  /// [entityType] - Entity type (e.g., 'user', 'device', 'room')
  /// [route] - Route definition with method and path builder
  void register(String opType, String entityType, RouteDef route) {
    final key = '$opType::$entityType';
    _routes[key] = route;
  }

  /// Resolve route for an operation
  /// 
  /// Throws [Exception] if no route found for the operation
  RouteDef resolve(String opType, String entityType) {
    final key = '$opType::$entityType';
    final route = _routes[key];
    if (route == null) {
      throw Exception('No route registered for $key');
    }
    return route;
  }

  /// Check if route exists
  bool hasRoute(String opType, String entityType) {
    final key = '$opType::$entityType';
    return _routes.containsKey(key);
  }

  /// Get all registered routes
  Map<String, RouteDef> getAllRoutes() {
    return Map.unmodifiable(_routes);
  }

  /// Register default routes for common operations
  /// 
  /// Call this during app initialization to set up standard routes
  void registerDefaultRoutes() {
    // User operations
    register('create', 'user', RouteDef(
      method: 'POST',
      pathBuilder: (p) => '/api/v1/users',
      transform: (p) => {
        'email': p['email'],
        'display_name': p['displayName'],
        'birth_date': p['birthDate'],
      },
    ));

    register('update', 'user', RouteDef(
      method: 'PUT',
      pathBuilder: (p) => '/api/v1/users/${p['id']}',
      transform: (p) {
        final result = <String, dynamic>{};
        if (p.containsKey('displayName')) {
          result['display_name'] = p['displayName'];
        }
        if (p.containsKey('birthDate')) {
          result['birth_date'] = p['birthDate'];
        }
        if (p.containsKey('version')) {
          result['version'] = p['version'];
        }
        return result;
      },
    ));

    register('delete', 'user', RouteDef(
      method: 'DELETE',
      pathBuilder: (p) => '/api/v1/users/${p['id']}',
    ));

    // Room operations
    register('create', 'room', RouteDef(
      method: 'POST',
      pathBuilder: (p) => '/api/v1/rooms',
      transform: (p) => {
        'name': p['name'],
        'type': p['type'],
        if (p.containsKey('floorNumber')) 'floor_number': p['floorNumber'],
      },
    ));

    register('update', 'room', RouteDef(
      method: 'PUT',
      pathBuilder: (p) => '/api/v1/rooms/${p['id']}',
      transform: (p) {
        final result = <String, dynamic>{};
        if (p.containsKey('name')) result['name'] = p['name'];
        if (p.containsKey('type')) result['type'] = p['type'];
        if (p.containsKey('version')) result['version'] = p['version'];
        return result;
      },
    ));

    register('delete', 'room', RouteDef(
      method: 'DELETE',
      pathBuilder: (p) => '/api/v1/rooms/${p['id']}',
    ));

    // Device operations
    register('create', 'device', RouteDef(
      method: 'POST',
      pathBuilder: (p) => '/api/v1/devices',
      transform: (p) => {
        'room_id': p['roomId'],
        'device_type': p['deviceType'],
        'model': p['model'],
        'mqtt_topic': p['mqttTopic'],
      },
    ));

    register('update', 'device', RouteDef(
      method: 'PUT',
      pathBuilder: (p) => '/api/v1/devices/${p['id']}',
      transform: (p) {
        final result = <String, dynamic>{};
        if (p.containsKey('roomId')) result['room_id'] = p['roomId'];
        if (p.containsKey('mqttTopic')) result['mqtt_topic'] = p['mqttTopic'];
        if (p.containsKey('version')) result['version'] = p['version'];
        return result;
      },
    ));

    register('delete', 'device', RouteDef(
      method: 'DELETE',
      pathBuilder: (p) => '/api/v1/devices/${p['id']}',
    ));

    register('update_state', 'device', RouteDef(
      method: 'POST',
      pathBuilder: (p) => '/api/v1/devices/${p['id']}/state',
      transform: (p) => {'state': p['state']},
      requiresIdempotency: false, // Best-effort telemetry
    ));

    // Health data operations
    register('record', 'heart_rate', RouteDef(
      method: 'POST',
      pathBuilder: (p) => '/api/v1/health/heart-rate',
      transform: (p) => {
        'bpm': p['bpm'],
        'measured_at': p['measuredAt'],
        'source': p['source'],
      },
    ));

    register('record', 'blood_pressure', RouteDef(
      method: 'POST',
      pathBuilder: (p) => '/api/v1/health/blood-pressure',
      transform: (p) => {
        'systolic': p['systolic'],
        'diastolic': p['diastolic'],
        'measured_at': p['measuredAt'],
        'source': p['source'],
      },
    ));

    register('record', 'fall_event', RouteDef(
      method: 'POST',
      pathBuilder: (p) => '/api/v1/health/fall-events',
      transform: (p) => {
        'timestamp': p['timestamp'],
        if (p.containsKey('location')) 'location': p['location'],
        'severity': p['severity'],
      },
    ));

    // Automation operations
    register('create', 'automation', RouteDef(
      method: 'POST',
      pathBuilder: (p) => '/api/v1/automations',
      transform: (p) => {
        'name': p['name'],
        'trigger': p['trigger'],
        'actions': p['actions'],
        'enabled': p['enabled'],
      },
    ));

    register('update', 'automation', RouteDef(
      method: 'PUT',
      pathBuilder: (p) => '/api/v1/automations/${p['id']}',
      transform: (p) {
        final result = <String, dynamic>{};
        if (p.containsKey('name')) result['name'] = p['name'];
        if (p.containsKey('trigger')) result['trigger'] = p['trigger'];
        if (p.containsKey('actions')) result['actions'] = p['actions'];
        if (p.containsKey('enabled')) result['enabled'] = p['enabled'];
        if (p.containsKey('version')) result['version'] = p['version'];
        return result;
      },
    ));

    register('delete', 'automation', RouteDef(
      method: 'DELETE',
      pathBuilder: (p) => '/api/v1/automations/${p['id']}',
    ));
  }
}
