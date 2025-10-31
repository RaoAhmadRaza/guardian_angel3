import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Animated page indicator for onboarding screens.
class IoPageIndicator extends StatelessWidget {
  final int currentIndex;
  final int totalPages;
  final Color? activeColor;
  final Color? inactiveColor;

  const IoPageIndicator({
    super.key,
    required this.currentIndex,
    required this.totalPages,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        totalPages,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: currentIndex == index ? 32 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: currentIndex == index
                ? (activeColor ?? (isDark ? Colors.white : Colors.black87))
                : (inactiveColor ??
                    (isDark
                        ? Colors.white.withValues(alpha: 0.4)
                        : Colors.black45.withValues(alpha: 0.4))),
            boxShadow: currentIndex == index
                ? [
                    BoxShadow(
                      color: (activeColor ??
                              (isDark ? Colors.white : Colors.black87))
                          .withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
        ).animate(key: ValueKey('io_ind_$index')).scale(
              duration: 300.ms,
              curve: Curves.easeOutCubic,
            ),
      ),
    );
  }
}

/// Text button for skipping the onboarding flow.
class IoSkipButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final Color? color;

  const IoSkipButton({
    super.key,
    required this.onPressed,
    this.label = 'Skip',
    this.color,
  });

  @override
  Widget build(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
    foregroundColor: color ?? (isDark ? Colors.white70 : Colors.black54),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 4),
      Icon(Icons.arrow_forward_ios,
        size: 14, color: color ?? (isDark ? Colors.white70 : Colors.black54)),
        ],
      ),
    );
  }
}

/// Bottom navigation bar with Skip / Next controls and an indicator.
class IoNavigationBar extends StatelessWidget {
  final int currentIndex;
  final int totalPages;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final Color? activeColor;
  final Color? inactiveColor;
  final bool showIndicatorOnLastPage;
  final Color? skipTextColor;
  final Color? nextButtonBgColor;
  final Color? nextButtonIconColor;

  const IoNavigationBar({
    super.key,
    required this.currentIndex,
    required this.totalPages,
    required this.onNext,
    required this.onSkip,
    this.activeColor,
    this.inactiveColor,
    this.showIndicatorOnLastPage = true,
  this.skipTextColor,
  this.nextButtonBgColor,
  this.nextButtonIconColor,
  });

  bool get isLastPage => currentIndex == totalPages - 1;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (!isLastPage)
            IoSkipButton(onPressed: onSkip, color: skipTextColor)
          else
            const SizedBox(width: 80),
          if (showIndicatorOnLastPage || !isLastPage)
            IoPageIndicator(
              currentIndex: currentIndex,
              totalPages: totalPages,
              activeColor: activeColor,
              inactiveColor: inactiveColor,
            )
          else
            const SizedBox(height: 8, width: 80),
          if (!isLastPage)
            Container(
              decoration: BoxDecoration(
                color: nextButtonBgColor ?? (isDark ? Colors.white24 : const Color(0xFFF5F5F5)),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark ? Colors.white30 : const Color(0xFFE0E0E0),
                  width: 1,
                ),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: IconButton(
                onPressed: onNext,
                icon: Icon(
                  Icons.arrow_forward_ios,
                  size: 20,
                  color: nextButtonIconColor ?? (isDark ? Colors.white : Colors.black87),
                ),
                style: IconButton.styleFrom(padding: const EdgeInsets.all(16)),
              ),
            ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack)
          else
            const SizedBox(width: 56),
        ],
      ),
    );
  }
}
