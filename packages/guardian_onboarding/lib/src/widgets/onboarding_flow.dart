import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/onboarding_page_data.dart';
import 'onboarding_page.dart';
import 'onboarding_indicators.dart';

/// Reusable onboarding flow that renders a list of [OnboardingPageData]
/// with a PageView, indicator and Skip/Next controls.
class OnboardingFlow extends StatefulWidget {
  final List<OnboardingPageData> pages;
  final VoidCallback onCompleted;

  // Optional styling hooks
  final Gradient? backgroundGradient;
  final Color? navActiveColor;
  final Color? navInactiveColor;

  const OnboardingFlow({
    super.key,
    required this.pages,
    required this.onCompleted,
    this.backgroundGradient,
    this.navActiveColor,
    this.navInactiveColor,
  }) : assert(pages.length >= 1, 'Provide at least 1 onboarding page');

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow>
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
    await _complete();
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
          colors: isDark
              ? [const Color(0xFF0F172A), const Color(0xFF1F2937)]
              : [const Color(0xFFF9FAFB), const Color(0xFFF3F4F6)],
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
                  return GoPage(
                    data: data,
                    isLastPage: i == widget.pages.length - 1,
                    onPrimaryPressed: _complete,
                  );
                },
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: GoNavigationBar(
                  currentIndex: _index,
                  totalPages: widget.pages.length,
                  onNext: _next,
                  onSkip: _skip,
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
