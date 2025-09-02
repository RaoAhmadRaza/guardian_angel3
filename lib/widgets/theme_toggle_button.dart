import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/theme_provider.dart';

/// Animated theme toggle button with smooth transitions
///
/// Features:
/// - Smooth icon transitions between light/dark/system modes
/// - Haptic feedback on toggle
/// - Accessibility support
/// - Customizable appearance
class ThemeToggleButton extends StatefulWidget {
  final double size;
  final Color? iconColor;
  final Color? backgroundColor;
  final double? elevation;
  final EdgeInsets? padding;
  final bool showTooltip;

  const ThemeToggleButton({
    super.key,
    this.size = 24.0,
    this.iconColor,
    this.backgroundColor,
    this.elevation,
    this.padding,
    this.showTooltip = true,
  });

  @override
  State<ThemeToggleButton> createState() => _ThemeToggleButtonState();
}

class _ThemeToggleButtonState extends State<ThemeToggleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Animation controller for smooth transitions
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Rotation animation for icon change
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Scale animation for press effect
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Handles theme toggle with animation
  Future<void> _handleToggle() async {
    // Get theme provider
    final themeProvider = ThemeProvider.of(context);

    // Trigger animation
    await _animationController.forward();

    // Toggle theme
    await themeProvider.toggleTheme();

    // Haptic feedback
    HapticFeedback.selectionClick();

    // Reset animation
    _animationController.reset();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeProvider.of(context),
      builder: (context, child) {
        final themeProvider = ThemeProvider.of(context);

        final buttonWidget = AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Transform.rotate(
                angle: _rotationAnimation.value * 0.5,
                child: Container(
                  padding: widget.padding ?? const EdgeInsets.all(8.0),
                  decoration: widget.backgroundColor != null
                      ? BoxDecoration(
                          color: widget.backgroundColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: widget.elevation != null
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: widget.elevation!,
                                    offset: Offset(0, widget.elevation! / 2),
                                  ),
                                ]
                              : null,
                        )
                      : null,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _handleToggle,
                    child: Icon(
                      themeProvider.themeIcon,
                      size: widget.size,
                      color:
                          widget.iconColor ?? Theme.of(context).iconTheme.color,
                    ),
                  ),
                ),
              ),
            );
          },
        );

        // Wrap with tooltip if enabled
        if (widget.showTooltip) {
          return Tooltip(
            message: 'Switch to ${_getNextThemeDescription(themeProvider)}',
            child: buttonWidget,
          );
        }

        return buttonWidget;
      },
    );
  }

  /// Get description for next theme state
  String _getNextThemeDescription(ThemeProvider themeProvider) {
    switch (themeProvider.themeMode) {
      case ThemeMode.light:
        return 'dark theme';
      case ThemeMode.dark:
        return 'light theme';
      case ThemeMode.system:
        return 'dark theme';
    }
  }
}

/// Compact theme toggle for app bars
class AppBarThemeToggle extends StatelessWidget {
  const AppBarThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return const ThemeToggleButton(
      size: 22.0,
      showTooltip: true,
    );
  }
}

/// Floating action button style theme toggle
class FloatingThemeToggle extends StatelessWidget {
  final VoidCallback? onPressed;

  const FloatingThemeToggle({
    super.key,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeProvider.of(context),
      builder: (context, child) {
        final themeProvider = ThemeProvider.of(context);
        return FloatingActionButton.small(
          onPressed: () async {
            await themeProvider.toggleTheme();
            HapticFeedback.selectionClick();
            onPressed?.call();
          },
          backgroundColor: Theme.of(context).colorScheme.surface,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          elevation: 2,
          tooltip: 'Toggle theme',
          child: Icon(themeProvider.themeIcon),
        );
      },
    );
  }
}
