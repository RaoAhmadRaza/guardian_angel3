import 'dart:async';

/// Optimistic store for managing optimistic updates and rollback
/// 
/// Maps transaction tokens to:
/// - Original state (for rollback)
/// - Rollback handlers
/// - UI notification callbacks
class OptimisticStore {
  // txnToken -> original state snapshot
  final Map<String, Map<String, dynamic>> _stateSnapshots = {};
  
  // txnToken -> rollback handler
  final Map<String, Function()> _rollbackHandlers = {};
  
  // txnToken -> success callback
  final Map<String, Function()> _successCallbacks = {};
  
  // txnToken -> error callback
  final Map<String, Function(String error)> _errorCallbacks = {};

  /// Register an optimistic update
  /// 
  /// [txnToken] - Transaction token from PendingOp
  /// [originalState] - State snapshot before optimistic update
  /// [rollbackHandler] - Function to call if operation fails
  void register({
    required String txnToken,
    required Map<String, dynamic> originalState,
    required Function() rollbackHandler,
    Function()? onSuccess,
    Function(String error)? onError,
  }) {
    _stateSnapshots[txnToken] = Map<String, dynamic>.from(originalState);
    _rollbackHandlers[txnToken] = rollbackHandler;
    
    if (onSuccess != null) {
      _successCallbacks[txnToken] = onSuccess;
    }
    
    if (onError != null) {
      _errorCallbacks[txnToken] = onError;
    }
    
    print('[OptimisticStore] Registered txn: $txnToken');
  }

  /// Commit an optimistic update (operation succeeded)
  void commit(String txnToken) {
    if (!_stateSnapshots.containsKey(txnToken)) {
      print('[OptimisticStore] Warning: commit called for unknown txn: $txnToken');
      return;
    }

    // Call success callback if registered
    final onSuccess = _successCallbacks[txnToken];
    if (onSuccess != null) {
      try {
        onSuccess();
      } catch (e) {
        print('[OptimisticStore] Success callback error: $e');
      }
    }

    // Clean up
    _stateSnapshots.remove(txnToken);
    _rollbackHandlers.remove(txnToken);
    _successCallbacks.remove(txnToken);
    _errorCallbacks.remove(txnToken);
    
    print('[OptimisticStore] Committed txn: $txnToken');
  }

  /// Rollback an optimistic update (operation failed)
  void rollback(String txnToken, {String? errorMessage}) {
    if (!_stateSnapshots.containsKey(txnToken)) {
      print('[OptimisticStore] Warning: rollback called for unknown txn: $txnToken');
      return;
    }

    // Execute rollback handler
    final handler = _rollbackHandlers[txnToken];
    if (handler != null) {
      try {
        handler();
        print('[OptimisticStore] Rolled back txn: $txnToken');
      } catch (e) {
        print('[OptimisticStore] Rollback handler error: $e');
      }
    }

    // Call error callback if registered
    final onError = _errorCallbacks[txnToken];
    if (onError != null && errorMessage != null) {
      try {
        onError(errorMessage);
      } catch (e) {
        print('[OptimisticStore] Error callback error: $e');
      }
    }

    // Clean up
    _stateSnapshots.remove(txnToken);
    _rollbackHandlers.remove(txnToken);
    _successCallbacks.remove(txnToken);
    _errorCallbacks.remove(txnToken);
  }

  /// Get original state snapshot
  Map<String, dynamic>? getOriginalState(String txnToken) {
    return _stateSnapshots[txnToken];
  }

  /// Check if transaction is pending
  bool isPending(String txnToken) {
    return _stateSnapshots.containsKey(txnToken);
  }

  /// Get all pending transaction tokens
  List<String> getPendingTransactions() {
    return _stateSnapshots.keys.toList();
  }

  /// Rollback all pending transactions
  /// 
  /// Useful for cleanup on app restart or critical errors
  void rollbackAll({String? reason}) {
    final tokens = List<String>.from(_stateSnapshots.keys);
    
    print('[OptimisticStore] Rolling back ${tokens.length} pending transactions${reason != null ? ': $reason' : ''}');
    
    for (final token in tokens) {
      rollback(token, errorMessage: reason);
    }
  }

  /// Clear all without executing rollbacks
  /// 
  /// Use with caution - only for cleanup scenarios
  void clearAll() {
    final count = _stateSnapshots.length;
    
    _stateSnapshots.clear();
    _rollbackHandlers.clear();
    _successCallbacks.clear();
    _errorCallbacks.clear();
    
    print('[OptimisticStore] Cleared $count pending transactions');
  }

  /// Get count of pending transactions
  int get pendingCount => _stateSnapshots.length;
}
