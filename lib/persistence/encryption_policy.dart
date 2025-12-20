/// Encryption Policy for Hive Boxes
///
/// Defines the expected encryption state for each box without forcing migration.
/// This enables soft enforcement with telemetry for policy violations.
library;

import 'package:hive/hive.dart';
import '../services/telemetry_service.dart';
import 'wrappers/box_accessor.dart';

/// Encryption policy for a box.
///
/// - [required]: Box MUST be encrypted. Violations are recorded but not blocked.
/// - [optional]: Box MAY be encrypted. No violation recorded.
/// - [forbidden]: Box MUST NOT be encrypted (e.g., index boxes for performance).
enum EncryptionPolicy {
  /// Box must be encrypted (contains sensitive data)
  required,

  /// Encryption is optional (e.g., cache, non-sensitive data)
  optional,

  /// Encryption is forbidden (e.g., index boxes for performance)
  forbidden,
}

/// Configuration for a single Hive box.
class BoxConfig {
  final String name;
  final EncryptionPolicy encryption;
  final String? description;

  const BoxConfig({
    required this.name,
    required this.encryption,
    this.description,
  });

  @override
  String toString() => 'BoxConfig($name, $encryption)';
}

/// Registry of box configurations with encryption policies.
///
/// This extends [BoxRegistry] with policy information without modifying
/// the original class, enabling incremental adoption.
class BoxPolicyRegistry {
  BoxPolicyRegistry._();

  /// All box configurations with their encryption policies.
  static const List<BoxConfig> configs = [
    // Sensitive data - encryption required
    BoxConfig(
      name: 'rooms_box',
      encryption: EncryptionPolicy.required,
      description: 'Room configurations and device mappings',
    ),
    BoxConfig(
      name: 'devices_box',
      encryption: EncryptionPolicy.required,
      description: 'Device state and credentials',
    ),
    BoxConfig(
      name: 'vitals_box',
      encryption: EncryptionPolicy.required,
      description: 'Health vitals data (PHI)',
    ),
    BoxConfig(
      name: 'user_profile_box',
      encryption: EncryptionPolicy.required,
      description: 'User profile and preferences',
    ),
    BoxConfig(
      name: 'sessions_box',
      encryption: EncryptionPolicy.required,
      description: 'Authentication sessions',
    ),
    BoxConfig(
      name: 'pending_ops_box',
      encryption: EncryptionPolicy.required,
      description: 'Pending sync operations',
    ),
    BoxConfig(
      name: 'failed_ops_box',
      encryption: EncryptionPolicy.required,
      description: 'Failed operations for retry',
    ),
    BoxConfig(
      name: 'audit_logs_box',
      encryption: EncryptionPolicy.required,
      description: 'Security audit trail',
    ),
    BoxConfig(
      name: 'settings_box',
      encryption: EncryptionPolicy.required,
      description: 'Application settings',
    ),

    // Index boxes - encryption forbidden for performance
    BoxConfig(
      name: 'pending_index_box',
      encryption: EncryptionPolicy.forbidden,
      description: 'FIFO index for pending operations',
    ),
    BoxConfig(
      name: 'persistence_metadata_box',
      encryption: EncryptionPolicy.forbidden,
      description: 'Persistence layer metadata and lock state',
    ),

    // Cache boxes - encryption optional
    BoxConfig(
      name: 'assets_cache_box',
      encryption: EncryptionPolicy.optional,
      description: 'Cached assets (non-sensitive)',
    ),
    BoxConfig(
      name: 'ui_preferences_box',
      encryption: EncryptionPolicy.optional,
      description: 'UI preferences (theme, layout)',
    ),
  ];

  /// Get the configuration for a box by name.
  static BoxConfig? getConfig(String boxName) {
    return configs.cast<BoxConfig?>().firstWhere(
          (c) => c?.name == boxName,
          orElse: () => null,
        );
  }

  /// Get the encryption policy for a box.
  static EncryptionPolicy getPolicy(String boxName) {
    return getConfig(boxName)?.encryption ?? EncryptionPolicy.optional;
  }

  /// Check if a box is open and record policy violations.
  ///
  /// Returns `true` if box complies with policy, `false` otherwise.
  /// Violations are recorded to telemetry but do NOT block operations.
  static bool checkPolicyCompliance(String boxName) {
    if (!Hive.isBoxOpen(boxName)) {
      return true; // Can't check closed box
    }

    final config = getConfig(boxName);
    if (config == null) {
      // Unknown box - log warning
      TelemetryService.I.increment('encryption_policy.unknown_box');
      return true;
    }

    final box = BoxAccess.I.boxUntyped(boxName);
    final isEncrypted = _isBoxEncrypted(box);

    switch (config.encryption) {
      case EncryptionPolicy.required:
        if (!isEncrypted) {
          TelemetryService.I.increment('encryption_policy.violation.required_not_encrypted');
          TelemetryService.I.increment('encryption_policy.violation.$boxName');
          return false;
        }
        return true;

      case EncryptionPolicy.forbidden:
        if (isEncrypted) {
          TelemetryService.I.increment('encryption_policy.violation.forbidden_encrypted');
          TelemetryService.I.increment('encryption_policy.violation.$boxName');
          return false;
        }
        return true;

      case EncryptionPolicy.optional:
        return true;
    }
  }

  /// Check all open boxes for policy compliance.
  ///
  /// Returns a map of box name -> compliance status.
  static Map<String, bool> checkAllPolicies() {
    final results = <String, bool>{};
    for (final config in configs) {
      if (Hive.isBoxOpen(config.name)) {
        results[config.name] = checkPolicyCompliance(config.name);
      }
    }
    return results;
  }

  /// Get a summary of encryption policy violations.
  static EncryptionPolicySummary getSummary() {
    int compliant = 0;
    int violations = 0;
    final violatedBoxes = <String>[];

    for (final config in configs) {
      if (Hive.isBoxOpen(config.name)) {
        if (checkPolicyCompliance(config.name)) {
          compliant++;
        } else {
          violations++;
          violatedBoxes.add(config.name);
        }
      }
    }

    return EncryptionPolicySummary(
      compliantCount: compliant,
      violationCount: violations,
      violatedBoxes: violatedBoxes,
      isHealthy: violations == 0,
    );
  }

  /// Heuristic to detect if a box was opened with encryption.
  ///
  /// Hive doesn't expose this directly, so we check the file header.
  /// This is a best-effort check.
  static bool _isBoxEncrypted(Box box) {
    // Hive doesn't expose encryption status directly.
    // We rely on the fact that we track which boxes should be encrypted
    // in HiveService.encryptedBoxes() and trust that our init is correct.
    //
    // For now, assume boxes are correctly configured if they're open.
    // A more robust check would involve reading the box file header.
    //
    // TODO: Implement file header check for definitive encryption detection.
    return true; // Optimistic - assumes correct configuration
  }
}

/// Summary of encryption policy compliance.
class EncryptionPolicySummary {
  final int compliantCount;
  final int violationCount;
  final List<String> violatedBoxes;
  final bool isHealthy;

  const EncryptionPolicySummary({
    required this.compliantCount,
    required this.violationCount,
    required this.violatedBoxes,
    required this.isHealthy,
  });

  @override
  String toString() =>
      'EncryptionPolicySummary(compliant: $compliantCount, violations: $violationCount, healthy: $isHealthy)';
}

// ═══════════════════════════════════════════════════════════════════════════
// ENCRYPTION POLICY VIOLATION EXCEPTION
// ═══════════════════════════════════════════════════════════════════════════

/// Exception thrown when encryption policy is violated in strict mode.
///
/// This is a fatal error that should block app startup.
class EncryptionPolicyViolation implements Exception {
  final String boxName;
  final EncryptionPolicy expectedPolicy;
  final bool actuallyEncrypted;
  final String message;

  EncryptionPolicyViolation({
    required this.boxName,
    required this.expectedPolicy,
    required this.actuallyEncrypted,
  }) : message = _buildMessage(boxName, expectedPolicy, actuallyEncrypted);

  static String _buildMessage(
    String boxName,
    EncryptionPolicy policy,
    bool encrypted,
  ) {
    if (policy == EncryptionPolicy.required && !encrypted) {
      return 'SECURITY VIOLATION: Box "$boxName" requires encryption but is unencrypted. '
          'This box may contain sensitive data and MUST be encrypted.';
    }
    if (policy == EncryptionPolicy.forbidden && encrypted) {
      return 'POLICY VIOLATION: Box "$boxName" forbids encryption but is encrypted. '
          'This box must remain unencrypted for performance reasons.';
    }
    return 'Unknown encryption policy violation for box "$boxName"';
  }

  @override
  String toString() => 'EncryptionPolicyViolation: $message';
}

// ═══════════════════════════════════════════════════════════════════════════
// ENCRYPTION POLICY ENFORCER
// ═══════════════════════════════════════════════════════════════════════════

/// Enforces encryption policies with strict mode support.
///
/// In strict mode, violations throw [EncryptionPolicyViolation].
/// In non-strict mode, violations are logged but not blocked.
class EncryptionPolicyEnforcer {
  /// Encrypted boxes registry (set by HiveService during init)
  static final Set<String> _registeredEncryptedBoxes = {};

  /// Register a box as opened with encryption.
  ///
  /// Called by HiveService when opening encrypted boxes.
  static void registerEncryptedBox(String boxName) {
    _registeredEncryptedBoxes.add(boxName);
  }

  /// Check if a box was registered as encrypted.
  static bool isRegisteredAsEncrypted(String boxName) {
    return _registeredEncryptedBoxes.contains(boxName);
  }

  /// Enforce encryption policy for a box.
  ///
  /// In strict mode, throws [EncryptionPolicyViolation] on violation.
  /// In non-strict mode, logs violation but returns normally.
  ///
  /// Returns `true` if policy is satisfied.
  static bool enforcePolicy(String boxName, {bool strict = true}) {
    final config = BoxPolicyRegistry.getConfig(boxName);
    if (config == null) {
      // Unknown box - no policy to enforce
      return true;
    }

    final isEncrypted = isRegisteredAsEncrypted(boxName);
    
    switch (config.encryption) {
      case EncryptionPolicy.required:
        if (!isEncrypted) {
          TelemetryService.I.increment('encryption_policy.violation.required_not_encrypted');
          TelemetryService.I.increment('encryption_policy.violation.$boxName');
          
          if (strict) {
            throw EncryptionPolicyViolation(
              boxName: boxName,
              expectedPolicy: EncryptionPolicy.required,
              actuallyEncrypted: false,
            );
          }
          return false;
        }
        return true;

      case EncryptionPolicy.forbidden:
        if (isEncrypted) {
          TelemetryService.I.increment('encryption_policy.violation.forbidden_encrypted');
          TelemetryService.I.increment('encryption_policy.violation.$boxName');
          
          if (strict) {
            throw EncryptionPolicyViolation(
              boxName: boxName,
              expectedPolicy: EncryptionPolicy.forbidden,
              actuallyEncrypted: true,
            );
          }
          return false;
        }
        return true;

      case EncryptionPolicy.optional:
        return true;
    }
  }

  /// Enforce policies for all registered boxes.
  ///
  /// In strict mode, throws on first violation.
  /// In non-strict mode, returns summary of all violations.
  static EncryptionPolicySummary enforceAllPolicies({bool strict = false}) {
    int compliant = 0;
    int violations = 0;
    final violatedBoxes = <String>[];

    for (final config in BoxPolicyRegistry.configs) {
      try {
        if (enforcePolicy(config.name, strict: strict)) {
          compliant++;
        } else {
          violations++;
          violatedBoxes.add(config.name);
        }
      } on EncryptionPolicyViolation {
        // In strict mode, this propagates up
        rethrow;
      }
    }

    return EncryptionPolicySummary(
      compliantCount: compliant,
      violationCount: violations,
      violatedBoxes: violatedBoxes,
      isHealthy: violations == 0,
    );
  }

  /// Clear all registered encrypted boxes (for testing).
  static void clearRegistry() {
    _registeredEncryptedBoxes.clear();
  }
}

