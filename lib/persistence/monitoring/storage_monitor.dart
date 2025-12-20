/// StorageMonitor - Storage Quota & Pressure Monitoring
///
/// Part of 10% CLIMB #2: Operational safety & consistency.
///
/// Monitors Hive storage usage and triggers cleanup when quota exceeded.
///
/// USAGE:
/// ```dart
/// // Via provider (recommended)
/// final monitor = ref.read(storageMonitorProvider);
/// await monitor.checkQuota();
///
/// // Run on startup
/// await StorageMonitor.runStartupCheck();
///
/// // Run on app resume
/// await StorageMonitor.runResumeCheck();
/// ```
library;

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../box_registry.dart';
import '../../services/telemetry_service.dart';
import '../../services/ttl_compaction_service.dart';
import '../wrappers/box_accessor.dart';

/// Default storage quota: 100 MB
const int kDefaultMaxStorageBytes = 100 * 1024 * 1024;

/// Warning threshold: 80% of quota
const double kWarningThresholdPercent = 0.80;

/// Critical threshold: 95% of quota
const double kCriticalThresholdPercent = 0.95;

/// Riverpod provider for StorageMonitor
final storageMonitorProvider = Provider<StorageMonitor>((ref) {
  return StorageMonitor();
});

/// Storage pressure levels
enum StoragePressure {
  /// Under 80% - normal operation
  normal,
  /// 80-95% - warning, consider cleanup
  warning,
  /// Over 95% - critical, force cleanup
  critical,
}

/// Result of a storage check
class StorageCheckResult {
  final int totalBytes;
  final int quotaBytes;
  final double usagePercent;
  final StoragePressure pressure;
  final Map<String, int> boxSizes;
  final bool cleanupTriggered;
  final DateTime checkedAt;

  StorageCheckResult({
    required this.totalBytes,
    required this.quotaBytes,
    required this.usagePercent,
    required this.pressure,
    required this.boxSizes,
    required this.cleanupTriggered,
    required this.checkedAt,
  });

  bool get isHealthy => pressure == StoragePressure.normal;
  bool get needsAttention => pressure != StoragePressure.normal;

  Map<String, dynamic> toJson() => {
        'total_bytes': totalBytes,
        'quota_bytes': quotaBytes,
        'usage_percent': usagePercent,
        'pressure': pressure.name,
        'box_sizes': boxSizes,
        'cleanup_triggered': cleanupTriggered,
        'checked_at': checkedAt.toIso8601String(),
      };
}

/// Storage monitor for quota enforcement and cleanup triggering.
class StorageMonitor {
  final int maxAllowedBytes;
  final TelemetryService? _telemetry;

  StorageMonitor({
    this.maxAllowedBytes = kDefaultMaxStorageBytes,
    TelemetryService? telemetry,
  }) : _telemetry = telemetry;

  /// Check storage quota and trigger cleanup if needed.
  ///
  /// Returns the result of the storage check.
  Future<StorageCheckResult> checkQuota() async {
    final boxSizes = await HiveInspector.getBoxSizes();
    final totalSize = boxSizes.values.fold<int>(0, (sum, size) => sum + size);
    final usagePercent = totalSize / maxAllowedBytes;

    StoragePressure pressure;
    if (usagePercent >= kCriticalThresholdPercent) {
      pressure = StoragePressure.critical;
    } else if (usagePercent >= kWarningThresholdPercent) {
      pressure = StoragePressure.warning;
    } else {
      pressure = StoragePressure.normal;
    }

    bool cleanupTriggered = false;

    // Log telemetry
    _telemetry?.gauge('storage.total_bytes', totalSize);
    _telemetry?.gauge('storage.usage_percent', usagePercent * 100);
    _telemetry?.increment('storage.check.${pressure.name}');

    // Trigger cleanup if over quota
    if (totalSize > maxAllowedBytes) {
      cleanupTriggered = await _triggerCleanup(totalSize, boxSizes);
      _logWarning(totalSize, pressure);
    } else if (pressure == StoragePressure.warning) {
      _logWarning(totalSize, pressure);
    }

    return StorageCheckResult(
      totalBytes: totalSize,
      quotaBytes: maxAllowedBytes,
      usagePercent: usagePercent,
      pressure: pressure,
      boxSizes: boxSizes,
      cleanupTriggered: cleanupTriggered,
      checkedAt: DateTime.now().toUtc(),
    );
  }

  /// Trigger cleanup operations to reduce storage usage.
  Future<bool> _triggerCleanup(int currentSize, Map<String, int> boxSizes) async {
    _telemetry?.increment('storage.cleanup.triggered');
    print('[StorageMonitor] Storage over quota ($currentSize > $maxAllowedBytes bytes). Triggering cleanup...');

    try {
      // 1. Run TTL compaction (purges old vitals)
      final compactionResult = await TtlCompactionService.runIfNeeded();
      final purged = compactionResult['purged'] as int? ?? 0;
      
      if (purged > 0) {
        _telemetry?.increment('storage.cleanup.vitals_purged', purged);
        print('[StorageMonitor] Purged $purged old vitals records.');
      }

      // 2. Compact large boxes
      await _compactLargeBoxes(boxSizes);

      // 3. Clear assets cache if still over
      final newSize = await HiveInspector.totalSize();
      if (newSize > maxAllowedBytes) {
        await _clearAssetsCache();
      }

      _telemetry?.increment('storage.cleanup.completed');
      return true;
    } catch (e) {
      _telemetry?.increment('storage.cleanup.failed');
      print('[StorageMonitor] Cleanup failed: $e');
      return false;
    }
  }

  /// Compact boxes that are larger than threshold.
  Future<void> _compactLargeBoxes(Map<String, int> boxSizes) async {
    const compactThreshold = 1024 * 1024; // 1 MB

    for (final entry in boxSizes.entries) {
      if (entry.value > compactThreshold && Hive.isBoxOpen(entry.key)) {
        try {
          final box = BoxAccess.I.boxUntyped(entry.key);
          await box.compact();
          _telemetry?.increment('storage.compact.${entry.key}');
          print('[StorageMonitor] Compacted box: ${entry.key}');
        } catch (e) {
          print('[StorageMonitor] Failed to compact ${entry.key}: $e');
        }
      }
    }
  }

  /// Clear assets cache to free up space.
  Future<void> _clearAssetsCache() async {
    if (!Hive.isBoxOpen(BoxRegistry.assetsCacheBox)) return;

    try {
      final cacheBox = BoxAccess.I.assetsCache();
      final count = cacheBox.length;
      await cacheBox.clear();
      _telemetry?.increment('storage.cache_cleared', count);
      print('[StorageMonitor] Cleared $count items from assets cache.');
    } catch (e) {
      print('[StorageMonitor] Failed to clear assets cache: $e');
    }
  }

  /// Log a storage warning.
  void _logWarning(int currentSize, StoragePressure pressure) {
    final percentUsed = (currentSize / maxAllowedBytes * 100).toStringAsFixed(1);
    final message = pressure == StoragePressure.critical
        ? 'CRITICAL: Storage at $percentUsed% ($currentSize bytes)'
        : 'WARNING: Storage at $percentUsed% ($currentSize bytes)';
    
    print('[StorageMonitor] $message');
    _telemetry?.increment('storage.warning.logged');
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STATIC CONVENIENCE METHODS FOR BOOTSTRAP
  // ═══════════════════════════════════════════════════════════════════════

  /// Run storage check on app startup.
  static Future<StorageCheckResult> runStartupCheck() async {
    final monitor = StorageMonitor();
    final result = await monitor.checkQuota();
    
    if (result.needsAttention) {
      print('[StorageMonitor] Startup check: ${result.pressure.name} - ${result.usagePercent * 100}% used');
    }
    
    return result;
  }

  /// Run storage check on app resume.
  static Future<StorageCheckResult> runResumeCheck() async {
    final monitor = StorageMonitor();
    return monitor.checkQuota();
  }
}

/// HiveInspector - Utilities for inspecting Hive storage.
class HiveInspector {
  /// Get total size of all Hive boxes in bytes.
  static Future<int> totalSize() async {
    final sizes = await getBoxSizes();
    return sizes.values.fold<int>(0, (sum, size) => sum + size);
  }

  /// Get size of each box in bytes.
  static Future<Map<String, int>> getBoxSizes() async {
    final sizes = <String, int>{};
    
    // Find Hive directory from any open box
    final hivePath = _findHivePath();
    if (hivePath == null) return sizes;

    final hiveDir = Directory(hivePath);
    if (!await hiveDir.exists()) return sizes;

    // Measure each box file
    for (final boxName in BoxRegistry.allBoxes) {
      final file = File('$hivePath/$boxName.hive');
      if (await file.exists()) {
        sizes[boxName] = await file.length();
      }
    }

    return sizes;
  }

  /// Get the largest boxes sorted by size.
  static Future<List<MapEntry<String, int>>> getLargestBoxes({int limit = 5}) async {
    final sizes = await getBoxSizes();
    final sorted = sizes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).toList();
  }

  /// Find Hive directory path.
  static String? _findHivePath() {
    for (final name in BoxRegistry.allBoxes) {
      if (!Hive.isBoxOpen(name)) continue;
      try {
        final box = BoxAccess.I.boxUntyped(name);
        final path = box.path;
        if (path != null && path.contains('/$name')) {
          return path.replaceAll('/$name.hive', '');
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// Get storage statistics.
  static Future<Map<String, dynamic>> getStats() async {
    final sizes = await getBoxSizes();
    final total = sizes.values.fold<int>(0, (sum, size) => sum + size);
    final largest = await getLargestBoxes(limit: 3);

    return {
      'total_bytes': total,
      'total_mb': (total / 1024 / 1024).toStringAsFixed(2),
      'box_count': sizes.length,
      'largest_boxes': largest.map((e) => {
        'name': e.key,
        'bytes': e.value,
        'mb': (e.value / 1024 / 1024).toStringAsFixed(2),
      }).toList(),
    };
  }
}
