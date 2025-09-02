// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/onboarding_content.dart';
import '../services/onboarding_service.dart';
import '../widgets/onboarding_page.dart';
import '../widgets/onboarding_indicators.dart';
import '../providers/theme_provider.dart';
import '../utils/image_optimizer.dart';
import '../welcome.dart';

/// Main onboarding screen with smooth swipe transitions and beautiful UI
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  int _currentIndex = 0;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Fade animation controller
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    // Start fade animation
    _fadeController.forward();

    // Initialize theme provider and preload images
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ThemeProvider.instance.initialize();
      // Preload images for better performance
      ImageOptimizer.preloadOnboardingImages(context);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  /// Navigate to next page with smooth animation
  void _nextPage() async {
    if (_isNavigating) return;

    setState(() {
      _isNavigating = true;
    });

    // Haptic feedback
    HapticFeedback.lightImpact();

    if (_currentIndex < OnboardingData.contents.length - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }

    setState(() {
      _isNavigating = false;
    });
  }

  /// Skip onboarding and go to welcome screen
  void _skipOnboarding() async {
    if (_isNavigating) return;

    setState(() {
      _isNavigating = true;
    });

    // Haptic feedback
    HapticFeedback.selectionClick();

    await _completeOnboardingAndNavigate();
  }

  /// Complete onboarding and navigate to welcome screen
  Future<void> _completeOnboardingAndNavigate() async {
    try {
      // Mark onboarding as completed
      await OnboardingService.instance.completeOnboarding();

      // Fade out animation before navigation
      await _fadeController.reverse();

      if (mounted) {
        // Navigate to welcome screen with smooth transition
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const WelcomePage(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.3),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  )),
                  child: child,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    } catch (e) {
      // Handle error gracefully
      print('Error completing onboarding: $e');
      setState(() {
        _isNavigating = false;
      });
    }
  }

  /// Handle page change
  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });

    // Light haptic feedback for page changes
    HapticFeedback.selectionClick();
  }

  /// Handle get started button press
  void _onGetStarted() async {
    // Haptic feedback
    HapticFeedback.mediumImpact();
    await _completeOnboardingAndNavigate();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          // Theme toggle button
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 8),
            child: Container(
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.2)
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
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
                icon: Icon(
                  ThemeProvider.instance.themeIcon,
                  color: isDarkMode ? Colors.white : const Color(0xFF404040),
                  size: 20,
                ),
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  await ThemeProvider.instance.toggleTheme();
                },
              ),
            ),
          )
              .animate()
              .slideX(
                delay: 1000.ms,
                duration: 600.ms,
                begin: 1.0,
                curve: Curves.easeOutCubic,
              )
              .fadeIn(
                delay: 1000.ms,
                duration: 600.ms,
              ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          children: [
            // Page view with onboarding screens
            PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              physics: const BouncingScrollPhysics(),
              itemCount: OnboardingData.contents.length,
              itemBuilder: (context, index) {
                final content = OnboardingData.contents[index];
                final isLastPage = index == OnboardingData.contents.length - 1;

                return OnboardingPage(
                  content: content,
                  isLastPage: isLastPage,
                  onButtonPressed: isLastPage ? _onGetStarted : null,
                );
              },
            ),

            // Navigation controls overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDarkMode
                        ? [
                            Colors.transparent,
                            Colors.black.withOpacity(0.1),
                          ]
                        : [
                            Colors.transparent,
                            const Color(0xFFF0F0F0).withOpacity(0.01),
                          ],
                  ),
                ),
                child: OnboardingNavigationControls(
                  currentIndex: _currentIndex,
                  totalPages: OnboardingData.contents.length,
                  onNext: _nextPage,
                  onSkip: _skipOnboarding,
                  onGetStarted: _onGetStarted,
                ),
              ),
            )
                .animate()
                .slideY(
                  delay: 800.ms,
                  duration: 800.ms,
                  begin: 1.0,
                  curve: Curves.easeOutCubic,
                )
                .fadeIn(
                  delay: 800.ms,
                  duration: 800.ms,
                ),

            // Loading overlay (if navigating)
            if (_isNavigating)
              Container(
                color: isDarkMode
                    ? Colors.black.withOpacity(0.2)
                    : const Color(0xFFF0F0F0).withOpacity(0.7),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDarkMode ? Colors.white : const Color(0xFF404040),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
