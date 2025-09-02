import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Animation performance utilities for optimal user experience
///
/// Provides performance monitoring, optimization utilities, and
/// adaptive animation controls based on device capabilities.
class AnimationPerformance {
  AnimationPerformance._();

  static bool _reducedMotionEnabled = false;
  static bool _highPerformanceMode = true;

  /// Initialize performance monitoring
  static void initialize() {
    _checkDeviceCapabilities();
    _checkAccessibilitySettings();
  }

  /// Check if reduced motion is enabled for accessibility
  static bool get reducedMotionEnabled => _reducedMotionEnabled;

  /// Check if device supports high performance animations
  static bool get highPerformanceMode => _highPerformanceMode;

  /// Get appropriate animation duration based on performance settings
  static Duration getOptimalDuration(Duration standard) {
    if (_reducedMotionEnabled) return Duration.zero;
    if (!_highPerformanceMode)
      return Duration(milliseconds: (standard.inMilliseconds * 0.5).round());
    return standard;
  }

  /// Get appropriate animation curve based on performance
  static Curve getOptimalCurve(Curve standard) {
    if (_reducedMotionEnabled) return Curves.linear;
    if (!_highPerformanceMode) return Curves.easeOut;
    return standard;
  }

  /// Provide haptic feedback with performance consideration
  static void provideFeedback(HapticFeedbackType type) {
    if (_highPerformanceMode) {
      switch (type) {
        case HapticFeedbackType.lightImpact:
          HapticFeedback.lightImpact();
          break;
        case HapticFeedbackType.mediumImpact:
          HapticFeedback.mediumImpact();
          break;
        case HapticFeedbackType.heavyImpact:
          HapticFeedback.heavyImpact();
          break;
        case HapticFeedbackType.selectionClick:
          HapticFeedback.selectionClick();
          break;
        case HapticFeedbackType.vibrate:
          HapticFeedback.vibrate();
          break;
      }
    }
  }

  static void _checkDeviceCapabilities() {
    // In a real implementation, you might check:
    // - Device RAM, CPU cores, Graphics capabilities
    // For now, we'll assume high performance
    _highPerformanceMode = true;
  }

  static void _checkAccessibilitySettings() {
    // In a real implementation, you might check:
    // - System accessibility settings, Reduced motion preferences
    // For now, we'll default to false
    _reducedMotionEnabled = false;
  }
}

enum HapticFeedbackType {
  lightImpact,
  mediumImpact,
  heavyImpact,
  selectionClick,
  vibrate,
}
