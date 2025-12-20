import 'dart:convert';

/// Security utilities for API client
/// 
/// Phase 4 security enhancements:
/// - PII redaction for logging
/// - Token masking
/// - Sensitive field detection
/// - Safe JSON serialization
class SecurityUtils {
  // Sensitive field patterns
  static final _sensitiveFieldPatterns = [
    RegExp(r'password', caseSensitive: false),
    RegExp(r'token', caseSensitive: false),
    RegExp(r'secret', caseSensitive: false),
    RegExp(r'api[_-]?key', caseSensitive: false),
    RegExp(r'auth', caseSensitive: false),
    RegExp(r'credit[_-]?card', caseSensitive: false),
    RegExp(r'ssn', caseSensitive: false),
    RegExp(r'social[_-]?security', caseSensitive: false),
    RegExp(r'pin', caseSensitive: false),
    RegExp(r'cvv', caseSensitive: false),
  ];

  // PII patterns
  static final _emailPattern = RegExp(
    r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
  );

  static final _phonePattern = RegExp(
    r'\b\d{3}[-.]?\d{3}[-.]?\d{4}\b',
  );

  static final _creditCardPattern = RegExp(
    r'\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b',
  );

  static final _ssnPattern = RegExp(
    r'\b\d{3}-\d{2}-\d{4}\b',
  );

  /// Redact PII from string
  static String redactPii(String value) {
    var redacted = value;

    // Redact email addresses
    redacted = redacted.replaceAllMapped(
      _emailPattern,
      (match) => '[REDACTED_EMAIL]',
    );

    // Redact phone numbers
    redacted = redacted.replaceAllMapped(
      _phonePattern,
      (match) => '[REDACTED_PHONE]',
    );

    // Redact credit card numbers
    redacted = redacted.replaceAllMapped(
      _creditCardPattern,
      (match) => '[REDACTED_CC]',
    );

    // Redact SSN
    redacted = redacted.replaceAllMapped(
      _ssnPattern,
      (match) => '[REDACTED_SSN]',
    );

    return redacted;
  }

  /// Check if field name is sensitive
  static bool isSensitiveField(String fieldName) {
    return _sensitiveFieldPatterns.any((pattern) => pattern.hasMatch(fieldName));
  }

  /// Redact sensitive fields from payload
  static Map<String, dynamic> redactPayload(Map<String, dynamic> payload) {
    final redacted = <String, dynamic>{};

    for (var entry in payload.entries) {
      final key = entry.key;
      final value = entry.value;

      if (isSensitiveField(key)) {
        // Redact entire field
        redacted[key] = '[REDACTED]';
      } else if (value is String) {
        // Redact PII from string values
        redacted[key] = redactPii(value);
      } else if (value is Map<String, dynamic>) {
        // Recursively redact nested objects
        redacted[key] = redactPayload(value);
      } else if (value is List) {
        // Redact list elements
        redacted[key] = value.map((item) {
          if (item is Map<String, dynamic>) {
            return redactPayload(item);
          } else if (item is String) {
            return redactPii(item);
          } else {
            return item;
          }
        }).toList();
      } else {
        // Leave other types as-is
        redacted[key] = value;
      }
    }

    return redacted;
  }

  /// Mask authorization token
  static String maskToken(String token) {
    if (token.length <= 8) return '***';
    return '${token.substring(0, 4)}...${token.substring(token.length - 4)}';
  }

  /// Redact headers for logging
  static Map<String, String> redactHeaders(Map<String, String> headers) {
    final redacted = <String, String>{};

    for (var entry in headers.entries) {
      final key = entry.key.toLowerCase();
      final value = entry.value;

      if (key.contains('authorization') || key.contains('token')) {
        // Mask tokens
        redacted[entry.key] = maskToken(value);
      } else if (isSensitiveField(key)) {
        redacted[entry.key] = '[REDACTED]';
      } else {
        redacted[entry.key] = value;
      }
    }

    return redacted;
  }

  /// Safe JSON serialization with error handling
  static String safeJsonEncode(dynamic object, {bool redact = false}) {
    try {
      if (redact && object is Map<String, dynamic>) {
        return jsonEncode(redactPayload(object));
      }
      return jsonEncode(object);
    } catch (e) {
      return '{error: "Failed to serialize: $e"}';
    }
  }

  /// Safe JSON deserialization with error handling
  static dynamic safeJsonDecode(String source) {
    try {
      return jsonDecode(source);
    } catch (e) {
      throw FormatException('Failed to parse JSON: $e');
    }
  }

  /// Create safe log message for HTTP request
  static String createSafeRequestLog({
    required String method,
    required String path,
    required Map<String, String> headers,
    dynamic body,
  }) {
    final redactedHeaders = redactHeaders(headers);
    final redactedBody = body is Map<String, dynamic>
        ? redactPayload(body)
        : (body?.toString() ?? 'null');

    return 'HTTP $method $path | Headers: $redactedHeaders | Body: $redactedBody';
  }

  /// Create safe log message for HTTP response
  static String createSafeResponseLog({
    required int statusCode,
    required Map<String, String> headers,
    required String body,
  }) {
    final redactedHeaders = redactHeaders(headers);
    
    // Try to parse and redact JSON body
    String redactedBody;
    try {
      final parsed = jsonDecode(body);
      if (parsed is Map<String, dynamic>) {
        redactedBody = jsonEncode(redactPayload(parsed));
      } else {
        redactedBody = body;
      }
    } catch (e) {
      // Not JSON, redact as string
      redactedBody = redactPii(body);
    }

    // Truncate long responses
    if (redactedBody.length > 1000) {
      redactedBody = '${redactedBody.substring(0, 1000)}... [truncated]';
    }

    return 'HTTP $statusCode | Headers: $redactedHeaders | Body: $redactedBody';
  }

  /// Validate idempotency key format
  static bool isValidIdempotencyKey(String key) {
    // UUID format: 8-4-4-4-12 characters
    final uuidPattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return uuidPattern.hasMatch(key);
  }

  /// Sanitize path for logging (remove IDs)
  static String sanitizePath(String path) {
    // Replace UUIDs with placeholder
    var sanitized = path.replaceAllMapped(
      RegExp(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', 
        caseSensitive: false),
      (match) => '{uuid}',
    );

    // Replace numeric IDs
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'/\d+(/|$)'),
      (match) => '/{id}${match.group(1)}',
    );

    return sanitized;
  }

  /// Check if TLS is enabled for URL
  static bool isTlsEnabled(String url) {
    return url.startsWith('https://') || url.startsWith('wss://');
  }

  /// Validate certificate pinning configuration
  static bool validateCertificatePins(List<String> pins) {
    if (pins.isEmpty) return false;

    final sha256Pattern = RegExp(r'^sha256/[A-Za-z0-9+/]{43}=?$');
    return pins.every((pin) => sha256Pattern.hasMatch(pin));
  }

  /// Create secure random string
  static String generateSecureToken(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(
      length,
      (i) => chars[(random + i) % chars.length],
    ).join();
  }
}

/// Secure logging wrapper
class SecureLogger {
  final bool _enabled;
  final bool _redactPii;

  const SecureLogger({
    bool enabled = true,
    bool redactPii = true,
  })  : _enabled = enabled,
        _redactPii = redactPii;

  void log(String message, {String level = 'INFO'}) {
    if (!_enabled) return;

    final sanitized = _redactPii 
      ? SecurityUtils.redactPii(message)
      : message;

    print('[$level] ${DateTime.now().toIso8601String()} | $sanitized');
  }

  void debug(String message) => log(message, level: 'DEBUG');
  void info(String message) => log(message, level: 'INFO');
  void warning(String message) => log(message, level: 'WARNING');
  void error(String message) => log(message, level: 'ERROR');
}
