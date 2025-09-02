import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Animated page indicator for onboarding screens
class OnboardingPageIndicator extends StatelessWidget {
  final int currentIndex;
  final int totalPages;
  final Color? activeColor;
  final Color? inactiveColor;

  const OnboardingPageIndicator({
    super.key,
    required this.currentIndex,
    required this.totalPages,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
                ? activeColor ??
                    (isDarkMode ? Colors.white : const Color(0xFF404040))
                : inactiveColor ??
                    (isDarkMode
                        ? Colors.white.withOpacity(0.4)
                        : const Color(0xFF9E9E9E).withOpacity(0.5)),
            boxShadow: currentIndex == index
                ? [
                    BoxShadow(
                      color: (activeColor ??
                              (isDarkMode
                                  ? Colors.white
                                  : const Color(0xFF404040)))
                          .withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
        )
            .animate(
              key: ValueKey('indicator_$index'),
            )
            .scale(
              duration: 300.ms,
              curve: Curves.easeOutCubic,
            ),
      ),
    );
  }
}

/// Skip button widget for onboarding
class OnboardingSkipButton extends StatelessWidget {
  final VoidCallback onPressed;

  const OnboardingSkipButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: isDarkMode
            ? Colors.white.withOpacity(0.8)
            : const Color(0xFF666666),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Skip',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
              shadows: !isDarkMode
                  ? [
                      Shadow(
                        color: Colors.black.withOpacity(0.1),
                        offset: const Offset(0, 1),
                        blurRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: isDarkMode
                ? Colors.white.withOpacity(0.8)
                : const Color(0xFF666666),
          ),
        ],
      ),
    );
  }
}

/// Navigation controls container for onboarding
class OnboardingNavigationControls extends StatelessWidget {
  final int currentIndex;
  final int totalPages;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback? onGetStarted;

  const OnboardingNavigationControls({
    super.key,
    required this.currentIndex,
    required this.totalPages,
    required this.onNext,
    required this.onSkip,
    this.onGetStarted,
  });

  bool get isLastPage => currentIndex == totalPages - 1;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Skip button (hidden on last page)
          if (!isLastPage)
            OnboardingSkipButton(onPressed: onSkip)
          else
            const SizedBox(width: 80), // Placeholder for spacing

          // Page indicator
          OnboardingPageIndicator(
            currentIndex: currentIndex,
            totalPages: totalPages,
          ),

          // Next/Get Started button
          if (!isLastPage)
            Container(
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.2)
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.3)
                      : const Color(0xFFE0E0E0),
                  width: 1,
                ),
                boxShadow: !isDarkMode
                    ? [
                        BoxShadow(
                          color: const Color(0xFF000000).withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: IconButton(
                onPressed: onNext,
                icon: Icon(
                  Icons.arrow_forward_ios,
                  color: isDarkMode ? Colors.white : const Color(0xFF404040),
                  size: 20,
                ),
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ).animate().scale(
                  delay: 200.ms,
                  duration: 600.ms,
                  curve: Curves.easeOutBack,
                )
          else
            const SizedBox(width: 56), // Placeholder for spacing
        ],
      ),
    );
  }
}
