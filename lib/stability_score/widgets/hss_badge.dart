/// Health Stability Score Badge Widget
///
/// A compact badge that shows the HSS score with colored indicator.
/// Designed to be placed under profile pictures/avatars.
library;

import 'package:flutter/material.dart';
import '../models/stability_score_result.dart';
import '../providers/stability_score_provider.dart';

/// Compact HSS badge for displaying under profile pictures.
class HSSBadge extends StatelessWidget {
  /// Size variant
  final HSSBadgeSize size;

  /// Whether to show the label
  final bool showLabel;

  /// Optional callback when tapped
  final VoidCallback? onTap;

  const HSSBadge({
    super.key,
    this.size = HSSBadgeSize.medium,
    this.showLabel = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: StabilityScoreProvider.instance,
      builder: (context, _) {
        final score = StabilityScoreProvider.instance.currentScore;
        final isLoading = StabilityScoreProvider.instance.isLoading;

        if (isLoading && score == null) {
          return _buildLoadingBadge(context);
        }

        return _buildScoreBadge(context, score);
      },
    );
  }

  Widget _buildLoadingBadge(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final dimensions = _getDimensions();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dimensions.horizontalPadding,
        vertical: dimensions.verticalPadding,
      ),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(dimensions.borderRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: dimensions.indicatorSize,
            height: dimensions.indicatorSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(
                isDarkMode ? Colors.white.withOpacity(0.5) : Colors.grey,
              ),
            ),
          ),
          if (showLabel) ...[
            SizedBox(width: dimensions.spacing),
            Text(
              '...',
              style: TextStyle(
                fontSize: dimensions.fontSize,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white.withOpacity(0.5) : Colors.grey,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScoreBadge(BuildContext context, StabilityScoreResult? score) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final dimensions = _getDimensions();

    // Determine color based on score
    final Color indicatorColor;
    final String displayText;

    if (score == null || !score.isReliable) {
      indicatorColor = Colors.grey;
      displayText = '--';
    } else {
      indicatorColor = _getScoreColor(score.score);
      displayText = '${score.score.round()}';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: dimensions.horizontalPadding,
          vertical: dimensions.verticalPadding,
        ),
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(dimensions.borderRadius),
          border: Border.all(
            color: indicatorColor.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: indicatorColor.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Colored indicator dot
            Container(
              width: dimensions.indicatorSize,
              height: dimensions.indicatorSize,
              decoration: BoxDecoration(
                color: indicatorColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: indicatorColor.withOpacity(0.4),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            if (showLabel) ...[
              SizedBox(width: dimensions.spacing),
              Text(
                displayText,
                style: TextStyle(
                  fontSize: dimensions.fontSize,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Get color based on score (Red < 40, Yellow 40-70, Green > 70)
  Color _getScoreColor(double score) {
    if (score >= 70) {
      return const Color(0xFF22C55E); // Green
    } else if (score >= 40) {
      return const Color(0xFFFBBF24); // Yellow/Amber
    } else {
      return const Color(0xFFEF4444); // Red
    }
  }

  _BadgeDimensions _getDimensions() {
    switch (size) {
      case HSSBadgeSize.small:
        return const _BadgeDimensions(
          horizontalPadding: 6,
          verticalPadding: 4,
          indicatorSize: 8,
          fontSize: 11,
          spacing: 4,
          borderRadius: 10,
        );
      case HSSBadgeSize.medium:
        return const _BadgeDimensions(
          horizontalPadding: 10,
          verticalPadding: 6,
          indicatorSize: 10,
          fontSize: 13,
          spacing: 6,
          borderRadius: 12,
        );
      case HSSBadgeSize.large:
        return const _BadgeDimensions(
          horizontalPadding: 14,
          verticalPadding: 8,
          indicatorSize: 12,
          fontSize: 15,
          spacing: 8,
          borderRadius: 14,
        );
    }
  }
}

/// Size variants for the badge
enum HSSBadgeSize { small, medium, large }

/// Internal dimensions class
class _BadgeDimensions {
  final double horizontalPadding;
  final double verticalPadding;
  final double indicatorSize;
  final double fontSize;
  final double spacing;
  final double borderRadius;

  const _BadgeDimensions({
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.indicatorSize,
    required this.fontSize,
    required this.spacing,
    required this.borderRadius,
  });
}

/// HSS indicator that can be placed next to or under avatars
class HSSAvatarIndicator extends StatelessWidget {
  /// The avatar widget to wrap
  final Widget avatar;

  /// Position of the badge
  final HSSIndicatorPosition position;

  /// Badge size
  final HSSBadgeSize badgeSize;

  const HSSAvatarIndicator({
    super.key,
    required this.avatar,
    this.position = HSSIndicatorPosition.bottomRight,
    this.badgeSize = HSSBadgeSize.small,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        avatar,
        const SizedBox(height: 6),
        HSSBadge(
          size: badgeSize,
          showLabel: true,
        ),
      ],
    );
  }
}

enum HSSIndicatorPosition { bottomRight, bottomCenter, below }
