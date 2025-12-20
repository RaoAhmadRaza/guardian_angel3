/// Circuit Breaker pattern for preventing API meltdown
/// 
/// Tracks failure rate and trips when threshold exceeded.
/// Provides cooldown period before resetting.
class CircuitBreaker {
  final int failureThreshold;
  final Duration window;
  final Duration cooldown;
  
  DateTime? _lastTrip;
  List<DateTime> _failures = [];
  
  CircuitBreaker({
    this.failureThreshold = 10,
    this.window = const Duration(minutes: 1),
    this.cooldown = const Duration(minutes: 1),
  });

  /// Record a failure
  void recordFailure() {
    final now = DateTime.now();
    _failures.add(now);
    
    // Remove failures outside the window
    _failures = _failures.where((t) => now.difference(t) <= window).toList();
    
    // Trip if threshold exceeded
    if (_failures.length >= failureThreshold) {
      _lastTrip = now;
      print('[CircuitBreaker] TRIPPED: ${_failures.length} failures in ${window.inSeconds}s');
    }
  }

  /// Record a success (clears failure count)
  void recordSuccess() {
    if (_failures.isNotEmpty) {
      _failures.clear();
      print('[CircuitBreaker] Success recorded, failures cleared');
    }
  }

  /// Check if circuit breaker is tripped
  bool isTripped() {
    if (_lastTrip == null) return false;
    
    final now = DateTime.now();
    if (now.difference(_lastTrip!) > cooldown) {
      // Cooldown expired, reset
      _lastTrip = null;
      _failures.clear();
      print('[CircuitBreaker] Cooldown expired, circuit reset');
      return false;
    }
    
    return true;
  }

  /// Get time remaining in cooldown
  Duration? getCooldownRemaining() {
    if (_lastTrip == null) return null;
    
    final now = DateTime.now();
    final elapsed = now.difference(_lastTrip!);
    
    if (elapsed >= cooldown) return null;
    
    return cooldown - elapsed;
  }

  /// Get current failure count in window
  int getFailureCount() => _failures.length;

  /// Reset the circuit breaker (for testing)
  void reset() {
    _lastTrip = null;
    _failures.clear();
  }
}
