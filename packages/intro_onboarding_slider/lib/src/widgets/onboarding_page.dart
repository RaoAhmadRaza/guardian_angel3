import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import '../models/onboarding_page_data.dart';
import '../models/styles.dart';

/// A single onboarding page rendering an image, title, and description.
class IoPage extends StatefulWidget {
  final OnboardingPageData data;
  final bool isLastPage;
  final VoidCallback? onPrimaryPressed;
  final String? primaryText;
  final bool isBreathable;
  final IoLayoutStyle? layoutStyle;
  final Color? titleColor;
  final Color? descriptionColor;
  final Color? primaryButtonBgColor;
  final Color? primaryButtonFgColor;
  final Color? primaryButtonShadowColor;
  final IoLastButtonStyle lastButtonStyle;

  const IoPage({
    super.key,
    required this.data,
    this.isLastPage = false,
    this.onPrimaryPressed,
    this.primaryText,
    this.isBreathable = true,
  this.layoutStyle,
  this.titleColor,
  this.descriptionColor,
  this.primaryButtonBgColor,
  this.primaryButtonFgColor,
  this.primaryButtonShadowColor,
  this.lastButtonStyle = IoLastButtonStyle.large,
  });

  @override
  State<IoPage> createState() => _IoPageState();
}

class _IoPageState extends State<IoPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final layout = widget.layoutStyle ?? (widget.isBreathable ? IoLayoutStyle.breathable : IoLayoutStyle.compact);

    List<Widget> content() {
      Widget mediaWithShadow(Widget child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            child,
            Positioned(
              bottom: 0,
              child: Container(
                width: size.width * 0.45,
                height: 12,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.12),
                      blurRadius: 24,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }

      final mediaContainer = Container(
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
          child: mediaWithShadow(_buildMedia()),
        ),
      )
          .animate()
          .slideY(
            delay: 200.ms,
            duration: 800.ms,
            begin: -0.3,
            curve: Curves.easeOutCubic,
          )
          .fadeIn(delay: 200.ms, duration: 800.ms);

      final mediaPlain = SizedBox(
        height: size.height * 0.35,
        width: double.infinity,
        child: mediaWithShadow(_buildMedia()),
      )
          .animate()
          .slideY(
            delay: 200.ms,
            duration: 800.ms,
            begin: -0.3,
            curve: Curves.easeOutCubic,
          )
          .fadeIn(delay: 200.ms, duration: 800.ms);

    final title = Text(
        widget.data.title,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: size.width > 400 ? 32 : 28,
          fontWeight: FontWeight.bold,
      color: widget.titleColor ?? (isDark ? Colors.white : const Color(0xFF2D2D2D)),
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
          .fadeIn(delay: 400.ms, duration: 800.ms);

    final description = Text(
        widget.data.description,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: size.width > 400 ? 16 : 14,
      color: widget.descriptionColor ?? (isDark
        ? Colors.white.withValues(alpha: 0.9)
        : const Color(0xFF555555)),
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
          .fadeIn(delay: 600.ms, duration: 800.ms);

      switch (layout) {
        case IoLayoutStyle.breathable:
          return [
            SizedBox(height: size.height * 0.08),
            mediaContainer,
            SizedBox(height: size.height * 0.07),
            title,
            SizedBox(height: size.height * 0.035),
            description,
          ];
        case IoLayoutStyle.compact:
          return [
            SizedBox(height: size.height * 0.08),
            title,
            SizedBox(height: size.height * 0.04),
            mediaPlain,
            SizedBox(height: size.height * 0.04),
            description,
          ];
        case IoLayoutStyle.showcase:
          final showcaseMedia = Container(
            height: size.height * 0.38,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [Colors.white.withValues(alpha: 0.08), Colors.white12]
                    : [const Color(0xFFFFFFFF), const Color(0xFFF2F2F2)],
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: mediaWithShadow(_buildMedia()),
            ),
          )
              .animate()
              .slideY(delay: 200.ms, duration: 800.ms, begin: -0.25, curve: Curves.easeOutCubic)
              .fadeIn(delay: 200.ms, duration: 800.ms);
          return [
            SizedBox(height: size.height * 0.06),
            showcaseMedia,
            SizedBox(height: size.height * 0.06),
            title,
            SizedBox(height: size.height * 0.03),
            description,
          ];
      }
    }

    final children = <Widget>[
      ...content(),
      SizedBox(height: size.height * 0.08),
      if (widget.isLastPage &&
          (widget.primaryText != null || widget.data.buttonText != null))
        _buildFinalButton(isDark)
            .animate()
            .slideY(
              delay: 800.ms,
              duration: 800.ms,
              begin: 0.3,
              curve: Curves.easeOutCubic,
            )
            .fadeIn(delay: 800.ms, duration: 800.ms)
            .scale(
              delay: 800.ms,
              duration: 800.ms,
              begin: const Offset(0.8, 0.8),
              curve: Curves.easeOutBack,
            ),
      SizedBox(height: size.height * 0.04),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildFinalButton(bool isDark) {
    final bg = widget.primaryButtonBgColor ?? Colors.white;
    final fg = widget.primaryButtonFgColor ?? (isDark ? const Color(0xFF1A1A1A) : const Color(0xFF2D2D2D));
    final sh = widget.primaryButtonShadowColor ?? (isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.15));

    final label = widget.primaryText ?? widget.data.buttonText ?? 'Continue';

    switch (widget.lastButtonStyle) {
      case IoLastButtonStyle.smallRounded:
        return Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 140),
            child: SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: widget.onPrimaryPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: bg,
                  foregroundColor: fg,
                  elevation: 6,
                  shadowColor: sh,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.3),
                ),
                child: Text(label),
              ),
            ),
          ),
        );
      case IoLastButtonStyle.large:
        return SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: widget.onPrimaryPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: bg,
              foregroundColor: fg,
              elevation: 8,
              shadowColor: sh,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0.5),
            ),
            child: Text(label),
          ),
        );
    }
  }

  Widget _buildMedia() {
    // Priority: lottieAsset > lottieUrl > image
    if (widget.data.lottieAsset != null) {
      return Lottie.asset(
        widget.data.lottieAsset!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _mediaErrorFallback(),
      );
    }
    if (widget.data.lottieUrl != null) {
      return Lottie.network(
        widget.data.lottieUrl!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _mediaErrorFallback(),
      );
    }
    if (widget.data.image != null) {
      return Image(image: widget.data.image!, fit: BoxFit.contain);
    }
    return const SizedBox.shrink();
  }

  Widget _mediaErrorFallback() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Icon(
        Icons.image_not_supported_outlined,
        size: 48,
        color: isDark
            ? Colors.white.withValues(alpha: 0.6)
            : Colors.black.withValues(alpha: 0.4),
      ),
    );
  }

  // No-op loaders kept out; using Lottie.asset/network with errorBuilder.
}
