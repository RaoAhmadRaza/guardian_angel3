// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'colors.dart';

/// A customizable gradient button with smooth animations and accessibility support.
///
/// This widget provides a beautiful gradient button with press animations,
/// loading states, and full accessibility support. It can be used with
/// various predefined styles or completely customized.
///
/// Example:
/// ```dart
/// GradientButton.primary(
///   text: 'Continue',
///   onPressed: () => print('Pressed!'),
/// )
/// ```
///
/// The button supports:
/// - **Smooth animations**: Scale and glow effects on interaction
/// - **Loading states**: Built-in loading indicator
/// - **Accessibility**: Semantic labels and screen reader support
/// - **Customization**: Custom gradients, icons, and dimensions
class GradientButton extends StatefulWidget {
  /// The text to display on the button.
  final String text;

  /// Callback function called when the button is pressed.
  ///
  /// This will not be called if [isLoading] is true.
  final VoidCallback onPressed;

  /// The gradient to apply to the button background.
  ///
  /// If null, uses a default theme-appropriate gradient.
  final LinearGradient? gradient;

  /// Optional icon to display before the text.
  ///
  /// The icon will be automatically hidden when [isLoading] is true.
  final IconData? icon;

  /// Whether the button is in a loading state.
  ///
  /// When true:
  /// - Shows a loading spinner instead of the icon
  /// - Disables the [onPressed] callback
  /// - Announces loading state to screen readers
  final bool isLoading;

  /// Custom padding for the button content.
  ///
  /// Defaults to EdgeInsets.symmetric(horizontal: 24, vertical: 16).
  final EdgeInsets? padding;

  /// The width of the button.
  ///
  /// If null, the button will expand to fill available width.
  final double? width;

  /// The height of the button.
  ///
  /// Defaults to 56.0 for optimal touch targets.
  final double? height;

  /// Semantic label for accessibility.
  ///
  /// If provided, this will be used by screen readers instead of [text].
  /// This is useful when [text] might not be descriptive enough.
  final String? semanticLabel;

  /// Whether this button represents a destructive action.
  ///
  /// This affects the semantic properties for screen readers.
  final bool isDestructive;

  /// The color of the text and icon.
  ///
  /// If null, defaults to white.
  final Color? textColor;

  /// The color of the icon.
  ///
  /// If null, defaults to theme-responsive color (white for dark theme, dark gray for light theme).
  final Color? iconColor;

  const GradientButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.gradient,
    this.icon,
    this.isLoading = false,
    this.padding,
    this.width,
    this.height,
    this.semanticLabel,
    this.isDestructive = false,
    this.textColor,
    this.iconColor,
  });

  /// Creates a primary gradient button with brand colors.
  ///
  /// This is the recommended style for primary actions like "Continue",
  /// "Sign Up", or "Get Started".
  factory GradientButton.primary({
    required String text,
    required VoidCallback onPressed,
    IconData? icon,
    bool isLoading = false,
    String? semanticLabel,
  }) {
    return GradientButton(
      text: text,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      semanticLabel: semanticLabel,
      gradient: null, // Uses default primary gradient
    );
  }

  /// Creates a secondary gradient button with muted colors.
  ///
  /// This style is suitable for secondary actions like "Cancel",
  /// "Back", or alternative options.
  factory GradientButton.secondary({
    required String text,
    required VoidCallback onPressed,
    IconData? icon,
    bool isLoading = false,
    String? semanticLabel,
  }) {
    return GradientButton(
      text: text,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      semanticLabel: semanticLabel,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF6B73FF), Color(0xFF9A9CE8)],
      ),
    );
  }

  /// Creates a destructive action button with warning colors.
  ///
  /// Use this for dangerous actions like "Delete", "Remove", or "Sign Out".
  factory GradientButton.destructive({
    required String text,
    required VoidCallback onPressed,
    IconData? icon,
    bool isLoading = false,
    String? semanticLabel,
  }) {
    return GradientButton(
      text: text,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      semanticLabel: semanticLabel,
      isDestructive: true,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
      ),
    );
  }

  /// Creates a success action button with green colors.
  ///
  /// Perfect for positive actions like "Save", "Confirm", or "Complete".
  factory GradientButton.success({
    required String text,
    required VoidCallback onPressed,
    IconData? icon,
    bool isLoading = false,
    String? semanticLabel,
  }) {
    return GradientButton(
      text: text,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      semanticLabel: semanticLabel,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
      ),
    );
  }

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();

    // Scale animation for press effect
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      label: widget.semanticLabel ?? widget.text,
      hint: widget.isLoading
          ? 'Loading, please wait'
          : widget.isDestructive
              ? 'This action cannot be undone'
              : null,
      button: true,
      enabled: !widget.isLoading,
      child: GestureDetector(
        onTapDown: widget.isLoading
            ? null
            : (_) {
                setState(() {
                  _isPressed = true;
                });
                _scaleController.forward();
                HapticFeedback.lightImpact();
              },
        onTapUp: widget.isLoading
            ? null
            : (_) {
                setState(() {
                  _isPressed = false;
                });
                _scaleController.reverse();
                widget.onPressed();
              },
        onTapCancel: () {
          setState(() {
            _isPressed = false;
          });
          _scaleController.reverse();
        },
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: widget.width ?? double.infinity,
                height: widget.height ?? 56,
                decoration: BoxDecoration(
                  gradient: widget.gradient ??
                      (isDarkMode
                          ? AppTheme.premiumGradient
                          : AppTheme.lightPrimaryGradient),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _isPressed || widget.isLoading
                      ? []
                      : isDarkMode
                          ? [
                              // Dark theme: Subtle light glow effect
                              BoxShadow(
                                color: const Color(0xFFF8F9FA)
                                    .withOpacity(0.5), // Very subtle light glow
                                blurRadius: 15,
                                offset: const Offset(0, 2),
                                spreadRadius: 0,
                              ),
                              BoxShadow(
                                color: const Color(0xFF000000).withOpacity(
                                    0.25), // Gentle shadow for depth
                                blurRadius: 12,
                                offset: const Offset(0, 1),
                                spreadRadius: 0,
                              ),
                            ]
                          : [
                              // Light theme: Grayish professional shadows
                              BoxShadow(
                                color: const Color(0xFF475569)
                                    .withOpacity(0.4), // Grayish shadow
                                blurRadius: 20,
                                offset: const Offset(0, 2),
                                spreadRadius: 0,
                              ),
                              BoxShadow(
                                color: const Color(0xFF64748B)
                                    .withOpacity(0.06), // Lighter gray ambient
                                blurRadius: 35,
                                offset: const Offset(0, 8),
                                spreadRadius: 0,
                              ),
                            ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.isLoading ? null : widget.onPressed,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        padding: widget.padding ??
                            const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (widget.icon != null && !widget.isLoading) ...[
                              Icon(
                                widget.icon,
                                color: widget.iconColor ??
                                    (isDarkMode
                                        ? Colors.white
                                        : const Color(0xFF404040)),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (widget.isLoading)
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    (widget.iconColor ??
                                            (isDarkMode
                                                ? Colors.white
                                                : const Color(0xFF404040)))
                                        .withOpacity(0.8),
                                  ),
                                ),
                              )
                            else
                              Flexible(
                                child: Text(
                                  widget.text,
                                  style: GoogleFonts.inter(
                                    color: widget.textColor ?? Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A glass morphism card widget with customizable blur and transparency effects.
///
/// This widget creates a modern glass-like appearance with:
/// - Semi-transparent background
/// - Blur effects
/// - Subtle borders and shadows
///
/// Perfect for overlays, modal content, or creating depth in your UI.
///
/// Example:
/// ```dart
/// GlassCard(
///   child: Text('Glass content'),
///   borderRadius: BorderRadius.circular(20),
/// )
/// ```
class GlassCard extends StatelessWidget {
  /// The widget to display inside the glass card.
  final Widget child;

  /// Internal padding for the card content.
  ///
  /// Defaults to EdgeInsets.all(24).
  final EdgeInsets? padding;

  /// Border radius for the card corners.
  ///
  /// Defaults to BorderRadius.circular(20).
  final BorderRadius? borderRadius;

  /// Blur intensity for the glass effect.
  ///
  /// Higher values create more blur. Defaults to 20.
  final double? blur;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.blur,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: borderRadius ?? BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: blur ?? 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// A highly customizable text input field with animations and accessibility support.
///
/// This text field provides:
/// - **Smooth animations**: Focus effects, glow animations, and color transitions
/// - **Validation support**: Built-in error handling with semantic announcements
/// - **Accessibility**: Autofill hints, semantic labels, and screen reader support
/// - **Theme integration**: Automatically adapts to light/dark themes
///
/// Example:
/// ```dart
/// CustomTextField.email(
///   hint: 'Email Address',
///   controller: emailController,
///   validator: (value) => value?.isEmpty == true ? 'Required' : null,
/// )
/// ```
///
/// The field supports various input types through factory constructors:
/// - `CustomTextField.email()` for email inputs
/// - `CustomTextField.password()` for password inputs
/// - `CustomTextField.phone()` for phone number inputs
/// - `CustomTextField.name()` for name inputs
class CustomTextField extends StatefulWidget {
  /// The placeholder text shown when the field is empty.
  final String hint;

  /// Optional icon displayed at the start of the field.
  final IconData? prefixIcon;

  /// Whether to obscure the text (for passwords).
  final bool obscureText;

  /// The type of keyboard to show for this input.
  final TextInputType? keyboardType;

  /// Controller for managing the text field's value.
  final TextEditingController? controller;

  /// Validation function that returns an error message or null.
  final String? Function(String?)? validator;

  /// Callback fired when the text changes.
  final void Function(String)? onChanged;

  /// Semantic label for accessibility.
  ///
  /// This helps screen readers understand the purpose of the field.
  final String? semanticLabel;

  /// List of autofill hints to help with form completion.
  ///
  /// Common values include:
  /// - AutofillHints.email
  /// - AutofillHints.password
  /// - AutofillHints.telephoneNumber
  /// - AutofillHints.name
  final Iterable<String>? autofillHints;

  /// Whether this field is required.
  ///
  /// This affects the semantic properties for screen readers.
  final bool isRequired;

  /// Additional context for the field purpose.
  ///
  /// This is announced to screen readers as a hint.
  final String? semanticHint;

  const CustomTextField({
    super.key,
    required this.hint,
    this.prefixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.controller,
    this.validator,
    this.onChanged,
    this.semanticLabel,
    this.autofillHints,
    this.isRequired = false,
    this.semanticHint,
  });

  /// Creates an email input field with appropriate keyboard and autofill.
  factory CustomTextField.email({
    required String hint,
    TextEditingController? controller,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    String? semanticLabel,
    bool isRequired = false,
  }) {
    return CustomTextField(
      hint: hint,
      prefixIcon: Icons.email_outlined,
      keyboardType: TextInputType.emailAddress,
      controller: controller,
      validator: validator,
      onChanged: onChanged,
      semanticLabel: semanticLabel ?? 'Email address',
      autofillHints: const [AutofillHints.email],
      isRequired: isRequired,
      semanticHint: 'Enter your email address for account access',
    );
  }

  /// Creates a password input field with obscured text and security features.
  factory CustomTextField.password({
    required String hint,
    TextEditingController? controller,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    String? semanticLabel,
    bool isRequired = true,
  }) {
    return CustomTextField(
      hint: hint,
      prefixIcon: Icons.lock_outlined,
      obscureText: true,
      controller: controller,
      validator: validator,
      onChanged: onChanged,
      semanticLabel: semanticLabel ?? 'Password',
      autofillHints: const [AutofillHints.password],
      isRequired: isRequired,
      semanticHint: 'Enter a secure password',
    );
  }

  /// Creates a phone number input field with numeric keyboard.
  factory CustomTextField.phone({
    required String hint,
    TextEditingController? controller,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    String? semanticLabel,
    bool isRequired = false,
  }) {
    return CustomTextField(
      hint: hint,
      prefixIcon: Icons.phone_outlined,
      keyboardType: TextInputType.phone,
      controller: controller,
      validator: validator,
      onChanged: onChanged,
      semanticLabel: semanticLabel ?? 'Phone number',
      autofillHints: const [AutofillHints.telephoneNumber],
      isRequired: isRequired,
      semanticHint: 'Enter your phone number',
    );
  }

  /// Creates a name input field optimized for personal names.
  factory CustomTextField.name({
    required String hint,
    TextEditingController? controller,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    String? semanticLabel,
    bool isRequired = true,
  }) {
    return CustomTextField(
      hint: hint,
      prefixIcon: Icons.person_outlined,
      keyboardType: TextInputType.name,
      controller: controller,
      validator: validator,
      onChanged: onChanged,
      semanticLabel: semanticLabel ?? 'Full name',
      autofillHints: const [AutofillHints.name],
      isRequired: isRequired,
      semanticHint: 'Enter your full name',
    );
  }

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField>
    with TickerProviderStateMixin {
  bool _isFocused = false;
  String? _errorText;
  late AnimationController _focusController;
  late AnimationController _glowController;
  late AnimationController _errorController;
  late Animation<double> _focusAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _errorAnimation;
  late Animation<Color?> _borderColorAnimation;
  late Animation<Color?> _iconColorAnimation;

  @override
  void initState() {
    super.initState();

    // Focus animation
    _focusController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _focusAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _focusController,
      curve: Curves.easeOutCubic,
    ));

    // Glow animation
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));

    // Error animation
    _errorController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _errorAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _errorController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _focusController.dispose();
    _glowController.dispose();
    _errorController.dispose();
    super.dispose();
  }

  void _validateInput(String? value) {
    if (widget.validator != null) {
      final errorMessage = widget.validator!(value);
      if (errorMessage != _errorText) {
        setState(() {
          _errorText = errorMessage;
        });

        if (errorMessage != null) {
          _errorController.forward();
          HapticFeedback.lightImpact();
          // Announce error to screen readers
          Feedback.forLongPress(context);
        } else {
          _errorController.reverse();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final hasError = _errorText != null;

    // Set color animations based on theme and error state
    _borderColorAnimation = ColorTween(
      begin: hasError
          ? Colors.red.shade400
          : (isDarkMode ? AppTheme.borderColor : AppTheme.lightBorderColor),
      end: hasError ? Colors.red.shade600 : AppTheme.eliteBlue,
    ).animate(_focusAnimation);

    _iconColorAnimation = ColorTween(
      begin: hasError
          ? Colors.red.shade400
          : (isDarkMode
              ? AppTheme.placeholderText
              : AppTheme.lightPlaceholderText),
      end: hasError ? Colors.red.shade600 : AppTheme.eliteBlue,
    ).animate(_focusAnimation);

    return Semantics(
      label: widget.semanticLabel ?? widget.hint,
      hint: widget.semanticHint,
      textField: true,
      enabled: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: Listenable.merge(
                [_focusAnimation, _glowAnimation, _errorAnimation]),
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Theme.of(context).shadowColor.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Focus(
                  onFocusChange: (focused) {
                    setState(() {
                      _isFocused = focused;
                    });
                    if (focused) {
                      _focusController.forward();
                      if (!hasError) {
                        _glowController.repeat(reverse: true);
                      }
                    } else {
                      _focusController.reverse();
                      _glowController.stop();
                      _glowController.reset();
                      // Validate on focus loss
                      if (widget.controller?.text.isNotEmpty == true) {
                        _validateInput(widget.controller!.text);
                      }
                    }
                  },
                  child: TextFormField(
                    controller: widget.controller,
                    obscureText: widget.obscureText,
                    keyboardType: widget.keyboardType,
                    autofillHints: widget.autofillHints,
                    validator: (value) {
                      _validateInput(value);
                      return null; // We handle errors manually for better UX
                    },
                    onChanged: (value) {
                      widget.onChanged?.call(value);
                      // Clear error on typing if field becomes valid
                      if (hasError && widget.validator != null) {
                        final newError = widget.validator!(value);
                        if (newError == null && _errorText != null) {
                          setState(() {
                            _errorText = null;
                          });
                          _errorController.reverse();
                        }
                      }
                    },
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      hintStyle: GoogleFonts.inter(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                      prefixIcon: widget.prefixIcon != null
                          ? Icon(
                              widget.prefixIcon,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.7),
                            )
                          : null,
                      filled: true,
                      fillColor: Theme.of(context)
                          .colorScheme
                          .surface
                          .withValues(alpha: 0.8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: isDarkMode
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.8)
                              : const Color(
                                  0xFF475569), // Gray focus border for light theme
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.error,
                          width: 2,
                        ),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.error,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      errorStyle:
                          const TextStyle(height: 0), // Hide default error
                    ),
                  ),
                ),
              );
            },
          ),
          // Custom error message with semantic announcement
          AnimatedBuilder(
            animation: _errorAnimation,
            builder: (context, child) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: hasError ? 24 : 0,
                child: hasError
                    ? Semantics(
                        label: 'Error: $_errorText',
                        liveRegion: true,
                        child: Transform.translate(
                          offset: Offset(0, -8 * (1 - _errorAnimation.value)),
                          child: Opacity(
                            opacity: _errorAnimation.value,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 16, top: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 16,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorText!,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color:
                                            Theme.of(context).colorScheme.error,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    : null,
              );
            },
          ),
        ],
      ),
    );
  }
}

class SocialLoginButton extends StatefulWidget {
  final String text;
  final String imagePath;
  final VoidCallback onPressed;
  final Color? backgroundColor;

  const SocialLoginButton({
    super.key,
    required this.text,
    required this.imagePath,
    required this.onPressed,
    this.backgroundColor,
  });

  @override
  State<SocialLoginButton> createState() => _SocialLoginButtonState();
}

class _SocialLoginButtonState extends State<SocialLoginButton>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _hoverController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  late Animation<Color?> _shadowColorAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();

    // Scale animation for press effect
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutCubic,
    ));

    // Hover animation for subtle elevation
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _elevationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeOut,
    ));

    _shadowColorAnimation = ColorTween(
      begin: Colors.transparent,
      end: AppTheme.borderColor.withOpacity(0.1),
    ).animate(_elevationAnimation);
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _isPressed = true;
        });
        _scaleController.forward();
      },
      onTapUp: (_) {
        setState(() {
          _isPressed = false;
        });
        _scaleController.reverse();
        widget.onPressed();
      },
      onTapCancel: () {
        setState(() {
          _isPressed = false;
        });
        _scaleController.reverse();
      },
      child: MouseRegion(
        onEnter: (_) => _hoverController.forward(),
        onExit: (_) => _hoverController.reverse(),
        child: AnimatedBuilder(
          animation: Listenable.merge([_scaleAnimation, _elevationAnimation]),
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  color: widget.backgroundColor ??
                      (isDarkMode
                          ? AppTheme.surfaceColor
                          : AppTheme.lightSurfaceColor),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDarkMode
                        ? AppTheme.borderColor
                        : AppTheme.lightBorderColor,
                    width: 1,
                  ),
                  boxShadow: [
                    ...(_isPressed
                        ? []
                        : (isDarkMode
                            ? AppTheme.socialButtonShadow
                            : AppTheme.lightSocialButtonShadow)),
                    BoxShadow(
                      color: _shadowColorAnimation.value ?? Colors.transparent,
                      blurRadius: 12 * _elevationAnimation.value,
                      offset: Offset(0, 4 * _elevationAnimation.value),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onPressed,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Icon container with fixed size to prevent overflow
                          Container(
                            width: 24,
                            height: 24,
                            child: widget.imagePath.contains('apple')
                                ? Icon(
                                    Icons.apple,
                                    size: 24,
                                    color: isDarkMode
                                        ? AppTheme.primaryText
                                        : AppTheme.lightPrimaryText,
                                  )
                                : Image.asset(
                                    widget.imagePath,
                                    width: 24,
                                    height: 24,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(
                                        widget.imagePath.contains('google')
                                            ? Icons.g_mobiledata
                                            : Icons.login,
                                        size: 24,
                                        color: isDarkMode
                                            ? AppTheme.primaryText
                                            : AppTheme.lightPrimaryText,
                                      );
                                    },
                                  ),
                          ),
                          const SizedBox(width: 16),
                          // Text with Flexible to prevent overflow
                          Flexible(
                            child: Text(
                              widget.text,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode
                                    ? AppTheme.primaryText
                                    : AppTheme.lightPrimaryText,
                                letterSpacing: 0.1,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    )
        .animate()
        .slideY(
          delay: Duration(milliseconds: 200),
          duration: Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          begin: 0.3,
          end: 0.0,
        )
        .fadeIn(
          delay: Duration(milliseconds: 100),
          duration: Duration(milliseconds: 500),
        );
  }
}

class AnimatedBackground extends StatelessWidget {
  final Widget child;
  final LinearGradient gradient;

  const AnimatedBackground({
    super.key,
    required this.child,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: gradient),
      child: child,
    );
  }
}

class CountryCodePicker extends StatefulWidget {
  final String selectedCode;
  final Function(String) onChanged;

  const CountryCodePicker({
    super.key,
    required this.selectedCode,
    required this.onChanged,
  });

  @override
  State<CountryCodePicker> createState() => _CountryCodePickerState();
}

class _CountryCodePickerState extends State<CountryCodePicker> {
  final List<Map<String, String>> countries = [
    {'flag': '🇺🇸', 'code': '+1', 'name': 'United States'},
    {'flag': '🇵🇰', 'code': '+92', 'name': 'Pakistan'},
    {'flag': '🇮🇳', 'code': '+91', 'name': 'India'},
    {'flag': '🇬🇧', 'code': '+44', 'name': 'United Kingdom'},
    {'flag': '🇨🇦', 'code': '+1', 'name': 'Canada'},
    {'flag': '🇦🇺', 'code': '+61', 'name': 'Australia'},
    {'flag': '🇩🇪', 'code': '+49', 'name': 'Germany'},
    {'flag': '🇫🇷', 'code': '+33', 'name': 'France'},
    {'flag': '🇸🇦', 'code': '+966', 'name': 'Saudi Arabia'},
    {'flag': '🇦🇪', 'code': '+971', 'name': 'United Arab Emirates'},
  ];

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color:
                isDarkMode ? AppTheme.borderColor : AppTheme.lightBorderColor,
          ),
        ),
      ),
      child: DropdownButton<String>(
        value: widget.selectedCode,
        underline: const SizedBox(),
        icon: Icon(
          Icons.keyboard_arrow_down,
          size: 20,
          color: isDarkMode ? AppTheme.primaryText : AppTheme.lightPrimaryText,
        ),
        items: countries.map((country) {
          return DropdownMenuItem<String>(
            value: country['code'],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  country['flag']!,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 8),
                Text(
                  country['code']!,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode
                        ? AppTheme.primaryText
                        : AppTheme.lightPrimaryText,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            widget.onChanged(value);
          }
        },
      ),
    );
  }
}
