# Operation Router Specification

**Version:** 1.0.0  
**Last Updated:** November 22, 2025

---

## Overview

The Operation Router is responsible for mapping local pending operations to their corresponding backend API endpoints and transforming payloads between local and wire formats. It serves as the translation layer between the client's domain model and the server's HTTP API.

---

## Core Responsibilities

### 1. Endpoint Mapping
Map operation types to HTTP endpoints and methods

**Example:**
```dart
OperationType.createUser → POST /api/v1/users
OperationType.updateRoom → PUT /api/v1/rooms/{room_id}
OperationType.deleteDevice → DELETE /api/v1/devices/{device_id}
```

### 2. Payload Transformation
Transform local domain models to API request format

**Example:**
```dart
// Local format (Hive model)
User(
  id: '123',
  email: 'john@example.com',
  displayName: 'John Doe',
  birthDate: DateTime(1990, 5, 15),
)

// Wire format (JSON API)
{
  "email": "john@example.com",
  "display_name": "John Doe",
  "birth_date": "1990-05-15"
}
```

### 3. Response Parsing
Parse API responses back to local domain models

**Example:**
```dart
// Wire format (JSON response)
{
  "data": {
    "user_id": "123e4567-e89b-12d3-a456-426614174000",
    "email": "john@example.com",
    "created_at": "2025-11-22T12:00:00.000Z"
  }
}

// Local format (domain model)
User(
  id: '123e4567-e89b-12d3-a456-426614174000',
  email: 'john@example.com',
  createdAt: DateTime.parse('2025-11-22T12:00:00.000Z'),
)
```

### 4. Parameter Extraction
Extract path/query parameters from operation payload

**Example:**
```dart
// Operation payload
{
  "room_id": "987",
  "name": "Living Room",
}

// Extract room_id for path parameter
PUT /api/v1/rooms/987

// Body contains remaining fields
{
  "name": "Living Room"
}
```

---

## Operation Types

### Domain Model Operations

#### User Operations

**CREATE_USER**
- **Endpoint:** `POST /api/v1/users`
- **Payload:** `{email, display_name, birth_date}`
- **Response:** `User` object with `user_id`
- **Optimistic Update:** Yes (transaction token required)

**UPDATE_USER**
- **Endpoint:** `PUT /api/v1/users/{user_id}`
- **Payload:** `{display_name?, birth_date?, version}`
- **Response:** Updated `User` object
- **Optimistic Update:** Yes
- **Idempotency:** Required (version-based conflict detection)

**DELETE_USER**
- **Endpoint:** `DELETE /api/v1/users/{user_id}`
- **Payload:** `{user_id}`
- **Response:** 204 No Content
- **Optimistic Update:** Yes

#### Room Operations

**CREATE_ROOM**
- **Endpoint:** `POST /api/v1/rooms`
- **Payload:** `{name, type, floor_number?}`
- **Response:** `Room` object with `room_id`
- **Optimistic Update:** Yes

**UPDATE_ROOM**
- **Endpoint:** `PUT /api/v1/rooms/{room_id}`
- **Payload:** `{room_id, name?, type?, version}`
- **Response:** Updated `Room` object
- **Optimistic Update:** Yes

**DELETE_ROOM**
- **Endpoint:** `DELETE /api/v1/rooms/{room_id}`
- **Payload:** `{room_id}`
- **Response:** 204 No Content
- **Optimistic Update:** Yes

#### Device Operations

**CREATE_DEVICE**
- **Endpoint:** `POST /api/v1/devices`
- **Payload:** `{room_id, device_type, model, mqtt_topic}`
- **Response:** `Device` object with `device_id`
- **Optimistic Update:** Yes

**UPDATE_DEVICE**
- **Endpoint:** `PUT /api/v1/devices/{device_id}`
- **Payload:** `{device_id, room_id?, mqtt_topic?, version}`
- **Response:** Updated `Device` object
- **Optimistic Update:** Yes

**DELETE_DEVICE**
- **Endpoint:** `DELETE /api/v1/devices/{device_id}`
- **Payload:** `{device_id}`
- **Response:** 204 No Content
- **Optimistic Update:** Yes

**UPDATE_DEVICE_STATE**
- **Endpoint:** `POST /api/v1/devices/{device_id}/state`
- **Payload:** `{device_id, state}`
- **Response:** `DeviceState` object
- **Optimistic Update:** No (telemetry, best-effort)

#### Health Data Operations

**RECORD_HEART_RATE**
- **Endpoint:** `POST /api/v1/health/heart-rate`
- **Payload:** `{bpm, measured_at, source}`
- **Response:** `HeartRate` object with `id`
- **Optimistic Update:** No (append-only, no rollback needed)

**RECORD_BLOOD_PRESSURE**
- **Endpoint:** `POST /api/v1/health/blood-pressure`
- **Payload:** `{systolic, diastolic, measured_at, source}`
- **Response:** `BloodPressure` object with `id`
- **Optimistic Update:** No

**RECORD_FALL_EVENT**
- **Endpoint:** `POST /api/v1/health/fall-events`
- **Payload:** `{timestamp, location?, severity}`
- **Response:** `FallEvent` object with `id`
- **Optimistic Update:** No (critical, no optimistic UI)

#### Automation Operations

**CREATE_AUTOMATION**
- **Endpoint:** `POST /api/v1/automations`
- **Payload:** `{name, trigger, actions, enabled}`
- **Response:** `Automation` object with `automation_id`
- **Optimistic Update:** Yes

**UPDATE_AUTOMATION**
- **Endpoint:** `PUT /api/v1/automations/{automation_id}`
- **Payload:** `{automation_id, name?, trigger?, actions?, enabled?, version}`
- **Response:** Updated `Automation` object
- **Optimistic Update:** Yes

**DELETE_AUTOMATION**
- **Endpoint:** `DELETE /api/v1/automations/{automation_id}`
- **Payload:** `{automation_id}`
- **Response:** 204 No Content
- **Optimistic Update:** Yes

---

## Router Implementation

### Interface

```dart
abstract class OpRouter {
  /// Route operation to API endpoint and execute
  Future<RouteResult> route(PendingOp operation);
  
  /// Get endpoint info for operation type (for testing/debugging)
  EndpointInfo getEndpointInfo(OperationType type);
}

class RouteResult {
  final bool success;
  final dynamic data; // Parsed response data
  final SyncException? error;
  
  RouteResult.success(this.data) : success = true, error = null;
  RouteResult.failure(this.error) : success = false, data = null;
}

class EndpointInfo {
  final String method; // GET, POST, PUT, DELETE
  final String pathTemplate; // e.g., "/api/v1/users/{user_id}"
  final bool requiresAuth;
  final bool requiresIdempotency;
  
  EndpointInfo({
    required this.method,
    required this.pathTemplate,
    this.requiresAuth = true,
    this.requiresIdempotency = true,
  });
}
```

### Concrete Implementation

```dart
class OpRouterImpl implements OpRouter {
  final ApiClient _apiClient;
  final Map<OperationType, EndpointInfo> _endpoints;
  
  OpRouterImpl(this._apiClient) : _endpoints = _buildEndpointMap();
  
  static Map<OperationType, EndpointInfo> _buildEndpointMap() {
    return {
      // User endpoints
      OperationType.createUser: EndpointInfo(
        method: 'POST',
        pathTemplate: '/api/v1/users',
      ),
      OperationType.updateUser: EndpointInfo(
        method: 'PUT',
        pathTemplate: '/api/v1/users/{user_id}',
      ),
      OperationType.deleteUser: EndpointInfo(
        method: 'DELETE',
        pathTemplate: '/api/v1/users/{user_id}',
      ),
      
      // Room endpoints
      OperationType.createRoom: EndpointInfo(
        method: 'POST',
        pathTemplate: '/api/v1/rooms',
      ),
      OperationType.updateRoom: EndpointInfo(
        method: 'PUT',
        pathTemplate: '/api/v1/rooms/{room_id}',
      ),
      OperationType.deleteRoom: EndpointInfo(
        method: 'DELETE',
        pathTemplate: '/api/v1/rooms/{room_id}',
      ),
      
      // Device endpoints
      OperationType.createDevice: EndpointInfo(
        method: 'POST',
        pathTemplate: '/api/v1/devices',
      ),
      OperationType.updateDevice: EndpointInfo(
        method: 'PUT',
        pathTemplate: '/api/v1/devices/{device_id}',
      ),
      OperationType.deleteDevice: EndpointInfo(
        method: 'DELETE',
        pathTemplate: '/api/v1/devices/{device_id}',
      ),
      OperationType.updateDeviceState: EndpointInfo(
        method: 'POST',
        pathTemplate: '/api/v1/devices/{device_id}/state',
        requiresIdempotency: false, // Best-effort telemetry
      ),
      
      // Health data endpoints
      OperationType.recordHeartRate: EndpointInfo(
        method: 'POST',
        pathTemplate: '/api/v1/health/heart-rate',
      ),
      OperationType.recordBloodPressure: EndpointInfo(
        method: 'POST',
        pathTemplate: '/api/v1/health/blood-pressure',
      ),
      OperationType.recordFallEvent: EndpointInfo(
        method: 'POST',
        pathTemplate: '/api/v1/health/fall-events',
      ),
      
      // Automation endpoints
      OperationType.createAutomation: EndpointInfo(
        method: 'POST',
        pathTemplate: '/api/v1/automations',
      ),
      OperationType.updateAutomation: EndpointInfo(
        method: 'PUT',
        pathTemplate: '/api/v1/automations/{automation_id}',
      ),
      OperationType.deleteAutomation: EndpointInfo(
        method: 'DELETE',
        pathTemplate: '/api/v1/automations/{automation_id}',
      ),
    };
  }
  
  @override
  Future<RouteResult> route(PendingOp operation) async {
    final endpointInfo = _endpoints[operation.type];
    if (endpointInfo == null) {
      return RouteResult.failure(
        ValidationException(message: 'Unknown operation type: ${operation.type}')
      );
    }
    
    try {
      // Build request components
      final path = _buildPath(endpointInfo.pathTemplate, operation.payload);
      final body = _buildRequestBody(operation.type, operation.payload);
      final headers = _buildHeaders(operation, endpointInfo);
      
      // Execute request
      final response = await _executeRequest(
        method: endpointInfo.method,
        path: path,
        body: body,
        headers: headers,
      );
      
      // Parse response
      final data = _parseResponse(operation.type, response);
      
      return RouteResult.success(data);
    } on SyncException catch (e) {
      return RouteResult.failure(e);
    }
  }
  
  String _buildPath(String template, Map<String, dynamic> payload) {
    var path = template;
    
    // Replace path parameters (e.g., {user_id} → 123)
    final pathParams = RegExp(r'\{(\w+)\}').allMatches(template);
    for (final match in pathParams) {
      final paramName = match.group(1)!;
      final paramValue = payload[paramName];
      
      if (paramValue == null) {
        throw ValidationException(
          message: 'Missing required path parameter: $paramName',
        );
      }
      
      path = path.replaceAll('{$paramName}', paramValue.toString());
    }
    
    return path;
  }
  
  Map<String, dynamic> _buildRequestBody(
    OperationType type,
    Map<String, dynamic> payload,
  ) {
    // Remove path parameters from body
    final body = Map<String, dynamic>.from(payload);
    
    // Extract path parameter names
    final endpointInfo = _endpoints[type]!;
    final pathParams = RegExp(r'\{(\w+)\}')
        .allMatches(endpointInfo.pathTemplate)
        .map((m) => m.group(1)!)
        .toSet();
    
    // Remove path params from body
    for (final param in pathParams) {
      body.remove(param);
    }
    
    // Apply transformations (e.g., camelCase → snake_case)
    return _transformPayload(type, body);
  }
  
  Map<String, dynamic> _transformPayload(
    OperationType type,
    Map<String, dynamic> payload,
  ) {
    // Convert field names to API format (snake_case)
    final transformed = <String, dynamic>{};
    
    for (final entry in payload.entries) {
      final key = _camelToSnake(entry.key);
      var value = entry.value;
      
      // Transform DateTime to ISO 8601
      if (value is DateTime) {
        value = value.toIso8601String();
      }
      
      transformed[key] = value;
    }
    
    return transformed;
  }
  
  String _camelToSnake(String camelCase) {
    return camelCase
        .replaceAllMapped(
          RegExp(r'([A-Z])'),
          (match) => '_${match.group(1)!.toLowerCase()}',
        )
        .replaceFirst(RegExp(r'^_'), '');
  }
  
  Map<String, String> _buildHeaders(PendingOp operation, EndpointInfo endpointInfo) {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'X-App-Version': appVersion, // e.g., "1.2.3"
      'X-Device-Id': deviceId, // Stable device UUID
      'Trace-Id': operation.traceId,
    };
    
    // Add idempotency key if required
    if (endpointInfo.requiresIdempotency) {
      headers['Idempotency-Key'] = operation.idempotencyKey;
    }
    
    // Add auth token if required
    if (endpointInfo.requiresAuth) {
      final token = await _authService.getToken();
      headers['Authorization'] = 'Bearer $token';
    }
    
    return headers;
  }
  
  Future<Response> _executeRequest({
    required String method,
    required String path,
    required Map<String, dynamic>? body,
    required Map<String, String> headers,
  }) async {
    switch (method) {
      case 'GET':
        return await _apiClient.get(path, headers: headers);
      case 'POST':
        return await _apiClient.post(path, body, headers: headers);
      case 'PUT':
        return await _apiClient.put(path, body, headers: headers);
      case 'DELETE':
        return await _apiClient.delete(path, headers: headers);
      default:
        throw ValidationException(message: 'Unsupported HTTP method: $method');
    }
  }
  
  dynamic _parseResponse(OperationType type, Response response) {
    // Most responses have 'data' field in envelope
    final data = response.body['data'];
    
    if (data == null) {
      // 204 No Content responses (e.g., DELETE)
      return null;
    }
    
    // Parse response based on operation type
    return _transformResponseData(type, data);
  }
  
  dynamic _transformResponseData(OperationType type, Map<String, dynamic> data) {
    // Convert snake_case → camelCase
    final transformed = <String, dynamic>{};
    
    for (final entry in data.entries) {
      final key = _snakeToCamel(entry.key);
      var value = entry.value;
      
      // Transform ISO 8601 strings to DateTime
      if (value is String && _isIso8601(value)) {
        value = DateTime.parse(value);
      }
      
      transformed[key] = value;
    }
    
    return transformed;
  }
  
  String _snakeToCamel(String snakeCase) {
    return snakeCase.replaceAllMapped(
      RegExp(r'_([a-z])'),
      (match) => match.group(1)!.toUpperCase(),
    );
  }
  
  bool _isIso8601(String value) {
    try {
      DateTime.parse(value);
      return true;
    } catch (_) {
      return false;
    }
  }
  
  @override
  EndpointInfo getEndpointInfo(OperationType type) {
    final info = _endpoints[type];
    if (info == null) {
      throw ValidationException(message: 'Unknown operation type: $type');
    }
    return info;
  }
}
```

---

## Payload Transformation Examples

### Example 1: Create User

**Local Payload (camelCase):**
```dart
{
  "email": "john@example.com",
  "displayName": "John Doe",
  "birthDate": DateTime(1990, 5, 15),
}
```

**API Request Body (snake_case):**
```json
{
  "email": "john@example.com",
  "display_name": "John Doe",
  "birth_date": "1990-05-15T00:00:00.000Z"
}
```

**API Response:**
```json
{
  "data": {
    "user_id": "123e4567-e89b-12d3-a456-426614174000",
    "email": "john@example.com",
    "display_name": "John Doe",
    "birth_date": "1990-05-15T00:00:00.000Z",
    "created_at": "2025-11-22T12:00:00.000Z",
    "version": 1
  }
}
```

**Parsed Response (camelCase):**
```dart
{
  "userId": "123e4567-e89b-12d3-a456-426614174000",
  "email": "john@example.com",
  "displayName": "John Doe",
  "birthDate": DateTime.parse("1990-05-15T00:00:00.000Z"),
  "createdAt": DateTime.parse("2025-11-22T12:00:00.000Z"),
  "version": 1,
}
```

### Example 2: Update Room

**Local Payload:**
```dart
{
  "roomId": "987fcdeb-51a2-43f8-b6d5-3a2e1f4b8c9a",
  "name": "Living Room (Updated)",
  "version": 2,
}
```

**Endpoint:** `PUT /api/v1/rooms/987fcdeb-51a2-43f8-b6d5-3a2e1f4b8c9a`

**API Request Body:**
```json
{
  "name": "Living Room (Updated)",
  "version": 2
}
```

**Note:** `roomId` extracted as path parameter, not in body

### Example 3: Record Heart Rate

**Local Payload:**
```dart
{
  "bpm": 72,
  "measuredAt": DateTime.parse("2025-11-22T12:00:00.000Z"),
  "source": "watch",
}
```

**API Request Body:**
```json
{
  "bpm": 72,
  "measured_at": "2025-11-22T12:00:00.000Z",
  "source": "watch"
}
```

**API Response:**
```json
{
  "data": {
    "id": "hr_abc123",
    "bpm": 72,
    "measured_at": "2025-11-22T12:00:00.000Z",
    "source": "watch",
    "recorded_at": "2025-11-22T12:00:01.234Z"
  }
}
```

---

## Error Handling

### Routing Errors

**Unknown Operation Type:**
```dart
final result = await opRouter.route(PendingOp(
  type: OperationType.unknownType, // Not in endpoint map
  ...
));

// result.error → ValidationException('Unknown operation type')
```

**Missing Path Parameter:**
```dart
final result = await opRouter.route(PendingOp(
  type: OperationType.updateRoom,
  payload: {
    "name": "Living Room", // Missing roomId!
  },
));

// result.error → ValidationException('Missing required path parameter: room_id')
```

**Network/Server Errors:**
```dart
// Network timeout
final result = await opRouter.route(...);
// result.error → NetworkException('Connection timeout')

// Server error
final result = await opRouter.route(...);
// result.error → ServerException('Internal server error')
```

---

## Testing Recommendations

### Unit Tests

**Test Endpoint Mapping:**
```dart
test('maps create user to correct endpoint', () {
  final router = OpRouterImpl(mockApiClient);
  final info = router.getEndpointInfo(OperationType.createUser);
  
  expect(info.method, 'POST');
  expect(info.pathTemplate, '/api/v1/users');
  expect(info.requiresAuth, true);
  expect(info.requiresIdempotency, true);
});

test('maps update room to correct endpoint', () {
  final router = OpRouterImpl(mockApiClient);
  final info = router.getEndpointInfo(OperationType.updateRoom);
  
  expect(info.method, 'PUT');
  expect(info.pathTemplate, '/api/v1/rooms/{room_id}');
});
```

**Test Path Building:**
```dart
test('builds path with parameters', () {
  final router = OpRouterImpl(mockApiClient);
  final path = router._buildPath(
    '/api/v1/rooms/{room_id}',
    {'room_id': '987', 'name': 'Living Room'},
  );
  
  expect(path, '/api/v1/rooms/987');
});

test('throws on missing path parameter', () {
  final router = OpRouterImpl(mockApiClient);
  
  expect(
    () => router._buildPath(
      '/api/v1/rooms/{room_id}',
      {'name': 'Living Room'}, // Missing room_id
    ),
    throwsA(isA<ValidationException>()),
  );
});
```

**Test Payload Transformation:**
```dart
test('converts camelCase to snake_case', () {
  final router = OpRouterImpl(mockApiClient);
  final transformed = router._transformPayload(
    OperationType.createUser,
    {
      'email': 'john@example.com',
      'displayName': 'John Doe',
      'birthDate': DateTime(1990, 5, 15),
    },
  );
  
  expect(transformed, {
    'email': 'john@example.com',
    'display_name': 'John Doe',
    'birth_date': '1990-05-15T00:00:00.000Z',
  });
});

test('converts snake_case to camelCase', () {
  final router = OpRouterImpl(mockApiClient);
  final transformed = router._transformResponseData(
    OperationType.createUser,
    {
      'user_id': '123',
      'display_name': 'John Doe',
      'created_at': '2025-11-22T12:00:00.000Z',
    },
  );
  
  expect(transformed, {
    'userId': '123',
    'displayName': 'John Doe',
    'createdAt': DateTime.parse('2025-11-22T12:00:00.000Z'),
  });
});
```

### Integration Tests

**Test Full Routing:**
```dart
testWidgets('routes create user operation', (tester) async {
  final mockClient = MockApiClient();
  final router = OpRouterImpl(mockClient);
  
  when(() => mockClient.post(any(), any(), headers: any(named: 'headers')))
      .thenAnswer((_) async => Response(
        statusCode: 201,
        body: {
          'data': {
            'user_id': '123',
            'email': 'john@example.com',
            'created_at': '2025-11-22T12:00:00.000Z',
          }
        },
      ));
  
  final result = await router.route(PendingOp(
    id: uuid.v4(),
    idempotencyKey: uuid.v4(),
    type: OperationType.createUser,
    payload: {
      'email': 'john@example.com',
      'displayName': 'John Doe',
    },
  ));
  
  expect(result.success, true);
  expect(result.data['userId'], '123');
  
  // Verify API called with correct parameters
  final captured = verify(() => mockClient.post(
    captureAny(),
    captureAny(),
    headers: captureAny(named: 'headers'),
  )).captured;
  
  expect(captured[0], '/api/v1/users'); // Path
  expect(captured[1]['email'], 'john@example.com'); // Body
  expect(captured[2]['Content-Type'], 'application/json; charset=utf-8'); // Headers
});
```

---

## Performance Optimization

### Endpoint Map Caching

**Pre-build endpoint map at initialization:**
```dart
class OpRouterImpl implements OpRouter {
  static final _endpointCache = _buildEndpointMap();
  
  OpRouterImpl(ApiClient apiClient) : _apiClient = apiClient;
  
  // Use cached map (no repeated construction)
  EndpointInfo getEndpointInfo(OperationType type) => _endpointCache[type]!;
}
```

### Path Building Optimization

**Cache regex patterns:**
```dart
class OpRouterImpl {
  static final _pathParamRegex = RegExp(r'\{(\w+)\}');
  
  String _buildPath(String template, Map<String, dynamic> payload) {
    var path = template;
    
    // Reuse compiled regex
    for (final match in _pathParamRegex.allMatches(template)) {
      final paramName = match.group(1)!;
      path = path.replaceAll('{$paramName}', payload[paramName].toString());
    }
    
    return path;
  }
}
```

### Payload Transformation Caching

**Cache field name conversions:**
```dart
class OpRouterImpl {
  static final _camelToSnakeCache = <String, String>{};
  static final _snakeToCamelCache = <String, String>{};
  
  String _camelToSnake(String camelCase) {
    return _camelToSnakeCache.putIfAbsent(camelCase, () {
      return camelCase.replaceAllMapped(...);
    });
  }
  
  String _snakeToCamel(String snakeCase) {
    return _snakeToCamelCache.putIfAbsent(snakeCase, () {
      return snakeCase.replaceAllMapped(...);
    });
  }
}
```

---

## Monitoring & Metrics

**Route Success/Failure Rates:**
```
sync.router.route.success.count
sync.router.route.failure.count
sync.router.route.success_rate = success / (success + failure)
```

**Route Duration:**
```
sync.router.route.duration.avg
sync.router.route.duration.p99
```

**Routes by Operation Type:**
```
sync.router.routes.by_type.create_user
sync.router.routes.by_type.update_room
sync.router.routes.by_type.record_heart_rate
```

**Routing Errors:**
```
sync.router.errors.unknown_operation_type
sync.router.errors.missing_path_parameter
sync.router.errors.invalid_payload
```

---

## Best Practices

### Do's
✅ Pre-build and cache endpoint map  
✅ Extract path parameters from payload before sending body  
✅ Transform field names consistently (camelCase ↔ snake_case)  
✅ Convert DateTime objects to ISO 8601 strings  
✅ Include all required headers (auth, idempotency, etc.)  
✅ Parse and transform response data back to local format  
✅ Handle missing parameters gracefully with validation errors

### Don'ts
❌ Don't include path parameters in request body  
❌ Don't hardcode endpoint URLs (use endpoint map)  
❌ Don't skip field name transformations (causes API errors)  
❌ Don't send DateTime objects directly (not JSON serializable)  
❌ Don't ignore response parsing errors  
❌ Don't reuse router instances across operations (stateless design)

---

## Future Enhancements

### 1. GraphQL Support

**Concept:** Map operations to GraphQL queries/mutations instead of REST

```dart
class GraphQLOpRouter implements OpRouter {
  Future<RouteResult> route(PendingOp operation) async {
    final query = _buildGraphQLQuery(operation.type, operation.payload);
    final response = await _graphqlClient.query(query);
    return RouteResult.success(response.data);
  }
  
  String _buildGraphQLQuery(OperationType type, Map<String, dynamic> payload) {
    return switch (type) {
      OperationType.createUser => '''
        mutation CreateUser(\$email: String!, \$displayName: String!) {
          createUser(email: \$email, displayName: \$displayName) {
            userId
            email
            createdAt
          }
        }
      ''',
      // ... other mutations
    };
  }
}
```

### 2. Batch Routing

**Concept:** Route multiple operations in single HTTP request

```dart
Future<List<RouteResult>> routeBatch(List<PendingOp> operations) async {
  final batch = operations.map((op) => {
    'operation_id': op.id,
    'type': op.type.name,
    'payload': op.payload,
  }).toList();
  
  final response = await _apiClient.post('/api/v1/batch', {'operations': batch});
  
  return response.data['results'].map((result) {
    return result['success']
      ? RouteResult.success(result['data'])
      : RouteResult.failure(parseError(result['error']));
  }).toList();
}
```

### 3. Dynamic Endpoint Discovery

**Concept:** Fetch endpoint map from server (support versioning)

```dart
class DynamicOpRouter implements OpRouter {
  Map<OperationType, EndpointInfo>? _endpoints;
  
  Future<void> initialize() async {
    final response = await _apiClient.get('/api/v1/endpoints');
    _endpoints = _parseEndpoints(response.data);
  }
  
  Future<RouteResult> route(PendingOp operation) async {
    if (_endpoints == null) {
      await initialize();
    }
    // ... use _endpoints
  }
}
```

---

## References

- [API Envelope Specification](api_envelope.md)
- [Error Mapping Specification](error_mapping.md)
- [Data Models Documentation](../../docs/models.md)

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-11-22 | Initial specification |
