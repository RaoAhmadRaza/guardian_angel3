import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../colors.dart';
import '../models/onboarding_content.dart';
import '../utils/image_optimizer.dart';

/// Individual onboarding page widget with optimized image loading and overflow protection
class OnboardingPage extends StatefulWidget {
  final OnboardingContent content;
  final VoidCallback? onButtonPressed;
  final bool isLastPage;

  const OnboardingPage({
    super.key,
    required this.content,
    this.onButtonPressed,
    this.isLastPage = false,
  });

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with AutomaticKeepAliveClientMixin {
  bool _imageLoaded = false;
  String? _imageError;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final size = MediaQuery.of(context).size;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: isDarkMode
            ? AppTheme.primaryGradient
            : AppTheme.lightPrimaryGradient,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              SizedBox(height: size.height * 0.08),

              // Hero Image Section with optimized loading
              Container(
                height: size.height * 0.35,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      // Placeholder/Loading state
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: !_imageLoaded && _imageError == null
                            ? Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              )
                            : null,
                      ),

                      // Actual Image
                      if (_imageError == null)
                        Image.network(
                          ImageOptimizer.getOptimizedImageUrl(
                            widget.content.imageUrl,
                            width: (size.width * 0.9).round(),
                            height: (size.height * 0.35).round(),
                            quality: 85,
                          ),
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) {
                              WidgetsBinding.instance
                                  .addPostFrameCallback((_) {
                                if (mounted) {
                                  setState(() {
                                    _imageLoaded = true;
                                  });
                                }
                              });
                              return child;
                            }
                            return Container();
                          },
                          errorBuilder: (context, error, stackTrace) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                setState(() {
                                  _imageError = 'Failed to load image';
                                });
                              }
                            });
                            return ImageOptimizer.getFallbackImage(
                              context: context,
                              title: 'Guardian Angel',
                              icon: Icons.security_rounded,
                            );
                          },
                        ),

                      // Error fallback image
                      if (_imageError != null)
                        ImageOptimizer.getFallbackImage(
                          context: context,
                          title: 'Guardian Angel',
                          icon: Icons.security_rounded,
                        ),

                      // Gradient overlay for better text readability
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(24),
                              bottomRight: Radius.circular(24),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.3),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  .animate()
                  .slideY(
                    delay: 200.ms,
                    duration: 800.ms,
                    begin: -0.3,
                    curve: Curves.easeOutCubic,
                  )
                  .fadeIn(
                    delay: 200.ms,
                    duration: 800.ms,
                  ),

              SizedBox(height: size.height * 0.06),

              // Title
              Text(
                widget.content.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: size.width > 400 ? 32 : 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.2,
                ),
              )
                  .animate()
                  .slideY(
                    delay: 400.ms,
                    duration: 800.ms,
                    begin: 0.3,
                    curve: Curves.easeOutCubic,
                  )
                  .fadeIn(
                    delay: 400.ms,
                    duration: 800.ms,
                  ),

              SizedBox(height: size.height * 0.03),

              // Description
              Text(
                widget.content.description,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: size.width > 400 ? 16 : 14,
                  color: Colors.white.withOpacity(0.9),
                  height: 1.6,
                  letterSpacing: 0.2,
                ),
              )
                  .animate()
                  .slideY(
                    delay: 600.ms,
                    duration: 800.ms,
                    begin: 0.3,
                    curve: Curves.easeOutCubic,
                  )
                  .fadeIn(
                    delay: 600.ms,
                    duration: 800.ms,
                  ),

              SizedBox(height: size.height * 0.08),

              // Action Button (only for last page)
              if (widget.isLastPage && widget.content.buttonText != null)
                Container(
                  width: double.infinity,
                  height: 56,
                  margin: EdgeInsets.only(bottom: size.height * 0.02),
                  child: ElevatedButton(
                    onPressed: widget.onButtonPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: isDarkMode
                          ? AppTheme.primaryCharcoal
                          : const Color(0xFF667EEA),
                      elevation: 8,
                      shadowColor: Colors.black.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      widget.content.buttonText!,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                )
                    .animate()
                    .slideY(
                      delay: 800.ms,
                      duration: 800.ms,
                      begin: 0.3,
                      curve: Curves.easeOutCubic,
                    )
                    .fadeIn(
                      delay: 800.ms,
                      duration: 800.ms,
                    )
                    .scale(
                      delay: 800.ms,
                      duration: 800.ms,
                      begin: const Offset(0.8, 0.8),
                      curve: Curves.easeOutBack,
                    ),

              // Bottom spacing to ensure scroll capability
              SizedBox(height: size.height * 0.04),
            ],
          ),
        ),
      ),
    );
  }
}
