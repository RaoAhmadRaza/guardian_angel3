import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/onboarding_page_data.dart';
import 'onboarding_page.dart';
import 'onboarding_indicators.dart';
import '../models/styles.dart';

/// Layout styles for onboarding pages.
// enums are defined in ../models/styles.dart

/// A drop-in onboarding flow that renders a [PageView] with indicators
/// and navigation controls. Provide a list of [pages] and handle completion
/// in [onCompleted].
class IntroOnboardingFlow extends StatefulWidget {
  /// The pages to display in the onboarding flow.
  final List<OnboardingPageData> pages;

  /// Callback invoked when the user completes onboarding.
  final VoidCallback onCompleted;

  /// Optional: background gradient for the whole screen.
  final Gradient? backgroundGradient;

  /// Optional: active color for the page indicator.
  final Color? navActiveColor;

  /// Optional: inactive color for the page indicator.
  final Color? navInactiveColor;

  /// Optional: start color for the background gradient. Ignored if
  /// [backgroundGradient] is provided.
  final Color? gradientStartColor;

  /// Optional: end color for the background gradient. Ignored if
  /// [backgroundGradient] is provided.
  final Color? gradientEndColor;

  /// Text colors
  final Color? titleColor;
  final Color? descriptionColor;

  /// Primary (final) button colors
  final Color? primaryButtonBgColor;
  final Color? primaryButtonFgColor;
  final Color? primaryButtonShadowColor;

  /// Skip button color
  final Color? skipTextColor;

  /// Next (arrow) button colors
  final Color? nextButtonBgColor;
  final Color? nextButtonIconColor;

  /// Optional: called when user taps Skip. If not provided, defaults to onCompleted.
  final VoidCallback? onSkip;

  /// Optional: override the text for the final page primary button.
  final String? getStartedText;

  /// Layout option: when true (default), media is inside a styled container.
  /// When false, title is placed above the media and media is shown without container.
  final bool isBreathable;

  /// Controls whether the page indicator remains visible on the last page.
  /// Defaults to false to keep the final screen clean; set to true to show it.
  final bool showIndicatorOnLastPage;

  /// Choose between breathable, compact, or showcase layout.
  final IoLayoutStyle? layoutStyle;

  /// Choose final button style (large or small rounded pill).
  final IoLastButtonStyle lastButtonStyle;

  /// Create an [IntroOnboardingFlow].
  const IntroOnboardingFlow({
    super.key,
    required this.pages,
    required this.onCompleted,
    this.backgroundGradient,
    this.navActiveColor,
    this.navInactiveColor,
    this.onSkip,
    this.getStartedText,
    this.isBreathable = true,
    this.gradientStartColor,
    this.gradientEndColor,
    this.showIndicatorOnLastPage = false,
  this.layoutStyle,
  this.lastButtonStyle = IoLastButtonStyle.large,
  this.titleColor,
  this.descriptionColor,
  this.primaryButtonBgColor,
  this.primaryButtonFgColor,
  this.primaryButtonShadowColor,
  this.skipTextColor,
  this.nextButtonBgColor,
  this.nextButtonIconColor,
  }) : assert(pages.length >= 1, 'Provide at least 1 onboarding page');

  @override
  State<IntroOnboardingFlow> createState() => _IntroOnboardingFlowState();
}

class _IntroOnboardingFlowState extends State<IntroOnboardingFlow>
    with TickerProviderStateMixin {
  late final PageController _controller;
  late final AnimationController _fade;
  late final Animation<double> _fadeAnim;

  int _index = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _fade = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fade, curve: Curves.easeInOut);
    _fade.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _fade.dispose();
    super.dispose();
  }

  bool get _isLast => _index == widget.pages.length - 1;

  Future<void> _next() async {
    if (_busy || _isLast) return;
    setState(() => _busy = true);
    HapticFeedback.lightImpact();
    await _controller.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
    setState(() => _busy = false);
  }

  Future<void> _skip() async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.selectionClick();
    final cb = widget.onSkip ?? widget.onCompleted;
    try {
      await _fade.reverse();
      if (!mounted) return;
      cb();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete() async {
    try {
      await _fade.reverse();
      if (!mounted) return;
      widget.onCompleted();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient = widget.backgroundGradient ??
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.gradientStartColor ??
                (isDark ? const Color(0xFF0F172A) : const Color(0xFFF9FAFB)),
            widget.gradientEndColor ??
                (isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6)),
          ],
        );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: gradient),
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Stack(
            children: [
              PageView.builder(
                controller: _controller,
                onPageChanged: (i) {
                  setState(() => _index = i);
                  HapticFeedback.selectionClick();
                },
                physics: const BouncingScrollPhysics(),
                itemCount: widget.pages.length,
                itemBuilder: (context, i) {
                  final data = widget.pages[i];
                  final isLast = i == widget.pages.length - 1;
                  return IoPage(
                    data: data,
                    isLastPage: isLast,
                    onPrimaryPressed: _complete,
                    primaryText: isLast
                        ? (widget.getStartedText ?? data.buttonText)
                        : null,
                    isBreathable: widget.isBreathable,
                    layoutStyle: widget.layoutStyle,
                    titleColor: widget.titleColor,
                    descriptionColor: widget.descriptionColor,
                    primaryButtonBgColor: widget.primaryButtonBgColor,
                    primaryButtonFgColor: widget.primaryButtonFgColor,
                    primaryButtonShadowColor: widget.primaryButtonShadowColor,
                    lastButtonStyle: widget.lastButtonStyle,
                  );
                },
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: IoNavigationBar(
                  currentIndex: _index,
                  totalPages: widget.pages.length,
                  onNext: _next,
                  onSkip: _skip,
                  activeColor: widget.navActiveColor,
                  inactiveColor: widget.navInactiveColor,
                  showIndicatorOnLastPage: widget.showIndicatorOnLastPage,
                  skipTextColor: widget.skipTextColor,
                  nextButtonBgColor: widget.nextButtonBgColor,
                  nextButtonIconColor: widget.nextButtonIconColor,
                )
                    .animate()
                    .slideY(
                        delay: 300.ms,
                        duration: 600.ms,
                        begin: 1,
                        curve: Curves.easeOutCubic)
                    .fadeIn(delay: 300.ms, duration: 600.ms),
              ),
              if (_busy)
                Container(
                  color: isDark ? Colors.black26 : Colors.black12,
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
