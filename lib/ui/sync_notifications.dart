import 'package:flutter/material.dart';
import '../models/sync_failure.dart';
import '../services/sync_failure_service.dart';

/// Helper class for displaying sync failure notifications
class SyncNotifications {
  /// Show a snackbar for a sync failure
  static void showFailureSnackbar(
    BuildContext context,
    SyncFailure failure, {
    VoidCallback? onRetry,
    VoidCallback? onViewDetails,
  }) {
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(
      SnackBar(
        content: _buildFailureContent(failure),
        duration: _getDurationForSeverity(failure.severity),
        backgroundColor: _getColorForSeverity(failure.severity),
        behavior: SnackBarBehavior.floating,
        action: failure.requiresUserAction && onViewDetails != null
            ? SnackBarAction(
                label: 'View',
                textColor: Colors.white,
                onPressed: onViewDetails,
              )
            : onRetry != null
                ? SnackBarAction(
                    label: 'Retry',
                    textColor: Colors.white,
                    onPressed: onRetry,
                  )
                : null,
      ),
    );
  }

  /// Show a success snackbar when sync succeeds after failure
  static void showSuccessSnackbar(
    BuildContext context,
    String message,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Build failure content widget
  static Widget _buildFailureContent(SyncFailure failure) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(_getIconForSeverity(failure.severity), size: 20, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sync Failed: ${failure.operation}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          failure.reason,
          style: const TextStyle(fontSize: 13),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (failure.requiresUserAction) ...[
          const SizedBox(height: 4),
          const Text(
            'Action required',
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ],
      ],
    );
  }

  /// Get duration based on severity
  static Duration _getDurationForSeverity(SyncFailureSeverity severity) {
    switch (severity) {
      case SyncFailureSeverity.low:
        return const Duration(seconds: 3);
      case SyncFailureSeverity.medium:
        return const Duration(seconds: 5);
      case SyncFailureSeverity.high:
        return const Duration(seconds: 7);
      case SyncFailureSeverity.critical:
        return const Duration(seconds: 10);
    }
  }

  /// Get color based on severity
  static Color _getColorForSeverity(SyncFailureSeverity severity) {
    switch (severity) {
      case SyncFailureSeverity.low:
        return Colors.blue[700]!;
      case SyncFailureSeverity.medium:
        return Colors.orange[700]!;
      case SyncFailureSeverity.high:
        return Colors.deepOrange[700]!;
      case SyncFailureSeverity.critical:
        return Colors.red[700]!;
    }
  }

  /// Get icon based on severity
  static IconData _getIconForSeverity(SyncFailureSeverity severity) {
    switch (severity) {
      case SyncFailureSeverity.low:
        return Icons.info_outline;
      case SyncFailureSeverity.medium:
        return Icons.warning_amber_outlined;
      case SyncFailureSeverity.high:
        return Icons.error_outline;
      case SyncFailureSeverity.critical:
        return Icons.dangerous_outlined;
    }
  }
}

/// Badge widget showing sync failure count
class SyncFailureBadge extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;

  const SyncFailureBadge({
    super.key,
    required this.count,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (count == 0) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        constraints: const BoxConstraints(minWidth: 24),
        child: Text(
          count > 99 ? '99+' : count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Stream builder that listens to sync failures
class SyncFailureListener extends StatefulWidget {
  final Widget child;
  final void Function(BuildContext context, SyncFailure failure)? onFailure;
  final void Function(BuildContext context, SyncFailure failure)? onResolved;

  const SyncFailureListener({
    super.key,
    required this.child,
    this.onFailure,
    this.onResolved,
  });

  @override
  State<SyncFailureListener> createState() => _SyncFailureListenerState();
}

class _SyncFailureListenerState extends State<SyncFailureListener> {
  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    // Listen to new failures
    SyncFailureService.I.onFailure.listen((failure) {
      if (mounted && widget.onFailure != null) {
        widget.onFailure!(context, failure);
      }
    });

    // Listen to resolved failures
    SyncFailureService.I.onResolved.listen((failure) {
      if (mounted && widget.onResolved != null) {
        widget.onResolved!(context, failure);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
