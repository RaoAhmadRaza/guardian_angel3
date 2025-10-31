import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/onboarding_page_data.dart';

/// A single onboarding page with image, title and description.
class GoPage extends StatefulWidget {
  final OnboardingPageData data;
  final bool isLastPage;
  final VoidCallback?
      onPrimaryPressed; // Only used on last page when buttonText != null

  const GoPage({
    super.key,
    required this.data,
    this.isLastPage = false,
    this.onPrimaryPressed,
  });

  @override
  State<GoPage> createState() => _GoPageState();
}

class _GoPageState extends State<GoPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            SizedBox(height: size.height * 0.08),

            // Image
            Container(
              height: size.height * 0.35,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? Colors.white12 : const Color(0xFFE5E5E5),
                  width: 1.5,
                ),
                boxShadow: isDark
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 48,
                          offset: const Offset(0, 16),
                        ),
                      ],
              ),
              clipBehavior: Clip.antiAlias,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white12 : const Color(0xFFF5F5F5),
                ),
                child: Image(
                  image: widget.data.image,
                  fit: BoxFit.contain,
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
              widget.data.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: size.width > 400 ? 32 : 28,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF2D2D2D),
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
              widget.data.description,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: size.width > 400 ? 16 : 14,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.9)
                    : const Color(0xFF555555),
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

            // Primary button on last page
            if (widget.isLastPage && widget.data.buttonText != null)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: widget.onPrimaryPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white : Colors.white,
                    foregroundColor: isDark
                        ? const Color(0xFF1A1A1A)
                        : const Color(0xFF2D2D2D),
                    elevation: 8,
                    shadowColor: isDark
                        ? Colors.black.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    widget.data.buttonText!,
                    style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5),
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

            SizedBox(height: size.height * 0.04),
          ],
        ),
      ),
    );
  }
}
