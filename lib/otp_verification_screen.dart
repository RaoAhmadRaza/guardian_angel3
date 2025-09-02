import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'colors.dart';
import 'widgets.dart';
import 'providers/theme_provider.dart';
import 'theme/motion.dart';
import 'theme/animation_performance.dart';
import 'user_selection_screen.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final bool isFromSignup;

  const OTPVerificationScreen({
    super.key,
    required this.phoneNumber,
    this.isFromSignup = true,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen>
    with TickerProviderStateMixin {
  final List<TextEditingController> _otpControllers =
      List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  bool _isLoading = false;
  bool _isResending = false;
  int _resendCountdown = 30;

  late AnimationController _shakeController;
  late AnimationController _progressController;
  late Animation<double> _shakeAnimation;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startCountdown();
  }

  void _initializeAnimations() {
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    ));

    _progressAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _resendCountdown > 0) {
        setState(() {
          _resendCountdown--;
        });
        _startCountdown();
      }
    });
  }

  void _onOTPChanged(String value, int index) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    // Auto verify when all fields are filled
    if (index == 5 && value.isNotEmpty) {
      String otp = _otpControllers.map((controller) => controller.text).join();
      if (otp.length == 6) {
        _verifyOTP();
      }
    }
  }

  void _verifyOTP() async {
    String otp = _otpControllers.map((controller) => controller.text).join();

    if (otp.length != 6) {
      _showError();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    AnimationPerformance.provideFeedback(HapticFeedbackType.lightImpact);
    _progressController.forward();

    // Simulate OTP verification
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      _progressController.reverse();
      AnimationPerformance.provideFeedback(HapticFeedbackType.mediumImpact);

      // Navigate based on flow
      if (widget.isFromSignup) {
        Navigator.of(context).pushReplacement(
          AppMotion.slideTransition(page: const UserSelectionScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          AppMotion.slideTransition(page: const UserVerificationScreen()),
        );
      }
    }
  }

  void _showError() {
    AnimationPerformance.provideFeedback(HapticFeedbackType.heavyImpact);
    _shakeController.forward().then((_) {
      _shakeController.reverse();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Invalid OTP. Please try again.',
          style: GoogleFonts.inter(fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _resendOTP() async {
    if (_resendCountdown > 0 || _isResending) return;

    setState(() {
      _isResending = true;
    });

    AnimationPerformance.provideFeedback(HapticFeedbackType.selectionClick);

    // Simulate resend
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      setState(() {
        _isResending = false;
        _resendCountdown = 30;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'OTP sent successfully!',
            style: GoogleFonts.inter(fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.green.shade400,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      _startCountdown();
    }
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _shakeController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // Top section with gradient background
            Container(
              height: size.height * 0.39,
              decoration: BoxDecoration(
                gradient: isDarkMode
                    ? AppTheme.primaryGradient
                    : const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFBFBFB), // Very light off-white at top
                          Color(0xFFF8F9FA), // Neutral light gray
                          Color(0xFFF1F3F4), // Subtle medium gray
                          Color(
                              0xFFE8EAED), // Gentle border-like gray at bottom
                        ],
                        stops: [0.0, 0.3, 0.7, 1.0],
                      ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
                border: isDarkMode
                    ? null
                    : Border.all(
                        color: const Color(0xFFE0E0E0).withOpacity(0.5),
                        width: 1,
                      ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 60.0),
                child: Stack(
                  children: [
                    // Theme toggle button
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.2)
                              : Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                          border: isDarkMode
                              ? null
                              : Border.all(
                                  color: const Color(0xFFE0E0E0),
                                  width: 1,
                                ),
                          boxShadow: isDarkMode
                              ? null
                              : [
                                  BoxShadow(
                                    color: const Color(0xFF475569)
                                        .withOpacity(0.06),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                    spreadRadius: 0,
                                  ),
                                ],
                        ),
                        child: IconButton(
                          icon: Icon(
                            ThemeProvider.instance.themeIcon,
                            color: isDarkMode
                                ? Colors.white
                                : const Color(0xFF404040),
                            size: 20,
                          ),
                          onPressed: () async {
                            await ThemeProvider.instance.toggleTheme();
                          },
                        ),
                      ),
                    ),

                    // Main content
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo/Icon
                          Hero(
                            tag: 'app_logo',
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.white.withOpacity(0.2)
                                    : Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(50),
                                border: Border.all(
                                  color: isDarkMode
                                      ? Colors.white.withOpacity(0.3)
                                      : const Color(0xFFE0E0E0),
                                  width: 2,
                                ),
                                boxShadow: isDarkMode
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: const Color(0xFF475569)
                                              .withOpacity(0.08),
                                          blurRadius: 15,
                                          offset: const Offset(0, 4),
                                          spreadRadius: 0,
                                        ),
                                      ],
                              ),
                              child: Icon(
                                Icons.verified_user,
                                size: 50,
                                color: isDarkMode
                                    ? Colors.white
                                    : const Color(0xFF404040),
                              ),
                            ),
                          ).animate().scale(
                                delay: 200.ms,
                                duration: 600.ms,
                                curve: Curves.elasticOut,
                              ),

                          const SizedBox(height: 24),

                          // Title
                          Text(
                            'Verify OTP',
                            style: GoogleFonts.inter(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ).animate().fadeIn(
                                delay: 400.ms,
                                duration: 600.ms,
                              ),

                          const SizedBox(height: 12),

                          // Subtitle
                          Text(
                            'Enter the 6-digit code sent to',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: isDarkMode
                                  ? Colors.white.withOpacity(0.9)
                                  : const Color(0xFF475569),
                            ),
                            textAlign: TextAlign.center,
                          ).animate().fadeIn(
                                delay: 600.ms,
                                duration: 600.ms,
                              ),

                          const SizedBox(height: 8),

                          // Phone number
                          Text(
                            widget.phoneNumber,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ).animate().fadeIn(
                                delay: 800.ms,
                                duration: 600.ms,
                              ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom section with OTP input
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const SizedBox(height: 40),

                  // OTP Input Fields
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(
                            _shakeAnimation.value *
                                10 *
                                (1 - _shakeAnimation.value),
                            0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(6, (index) {
                            return _buildOTPField(index, isDarkMode);
                          }),
                        ),
                      );
                    },
                  ).animate().slideY(
                        delay: 1000.ms,
                        duration: 600.ms,
                        begin: 0.3,
                      ),

                  const SizedBox(height: 40),

                  // Verify Button
                  AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, child) {
                      return GradientButton(
                        text: _isLoading ? 'Verifying...' : 'Verify OTP',
                        onPressed: _isLoading ? () {} : _verifyOTP,
                        isLoading: _isLoading,
                        icon: _isLoading ? null : Icons.verified,
                        width: double.infinity,
                        gradient: isDarkMode
                            ? null // Use default dark theme gradient
                            : const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFFFDFDFD), // off-white
                                  Color(0xFFF5F5F7), // light cloud grey
                                  Color(0xFFE0E0E2), // gentle cool grey
                                ],
                              ),
                        textColor: isDarkMode
                            ? null // Use default text color
                            : const Color(0xFF0F172A),
                      );
                    },
                  ).animate().slideY(
                        delay: 1200.ms,
                        duration: 600.ms,
                        begin: 0.3,
                      ),

                  const SizedBox(height: 24),

                  // Resend OTP
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Didn't receive the code? ",
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: isDarkMode
                              ? AppTheme.placeholderText
                              : AppTheme.lightPlaceholderText,
                        ),
                      ),
                      GestureDetector(
                        onTap: _resendOTP,
                        child: Text(
                          _resendCountdown > 0
                              ? 'Resend in ${_resendCountdown}s'
                              : _isResending
                                  ? 'Sending...'
                                  : 'Resend OTP',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _resendCountdown > 0 || _isResending
                                ? (isDarkMode
                                    ? AppTheme.placeholderText
                                    : AppTheme.lightPlaceholderText)
                                : isDarkMode
                                    ? null // Use default text color
                                    : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(
                        delay: 1400.ms,
                        duration: 600.ms,
                      ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOTPField(int index, bool isDarkMode) {
    return Container(
      width: 50,
      height: 60,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _otpControllers[index].text.isNotEmpty
              ? (isDarkMode
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.8)
                  : const Color(0xFF475569)) // Gray border for light theme
              : Colors.transparent,
          width: _otpControllers[index].text.isNotEmpty ? 2 : 0,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
            blurRadius: 5,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          counterText: '',
          contentPadding: EdgeInsets.zero,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDarkMode
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.8)
                  : const Color(
                      0xFF475569), // Gray focus border for light theme
              width: 2,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.error,
              width: 2,
            ),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
        ],
        onChanged: (value) => _onOTPChanged(value, index),
      ),
    )
        .animate(delay: Duration(milliseconds: 1000 + (index * 50)))
        .fadeIn(duration: 300.ms)
        .scale(begin: const Offset(0.8, 0.8));
  }
}

class UserVerificationScreen extends StatefulWidget {
  const UserVerificationScreen({super.key});

  @override
  State<UserVerificationScreen> createState() => _UserVerificationScreenState();
}

class _UserVerificationScreenState extends State<UserVerificationScreen> {
  String?
      _selectedRole; // Verification-specific: stores selected role for confirmation

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Verification-specific: Define role verification cards with images
    final verificationCards = [
      {
        'role': 'patient',
        'label': 'Patient', // Matches UserSelectionScreen label structure
        'image': 'images/paitient.png', // Using patient image for verification
      },
      {
        'role': 'guardian',
        'label':
            'Guardian/Caregiver', // Matches UserSelectionScreen label structure
        'image':
            'images/caregiver.png', // Using caregiver image for verification
      }
    ];

    // Replicated from UserSelectionScreen: buildRoleCard with verification-specific adaptations
    Widget buildVerificationCard({
      required String role,
      required String label,
      required String image,
    }) {
      final bool isActive = _selectedRole == role;

      // Match UserSelectionScreen icon mapping
      final IconData icon =
          role == 'patient' ? Icons.health_and_safety : Icons.people_alt;
      final String subtitle = role == 'patient'
          ? 'Health monitoring & care'
          : 'Family member or caregiver';

      return GestureDetector(
        onTap: () {
          setState(() => _selectedRole = role);
          // Verification-specific: Haptic feedback for role confirmation
          HapticFeedback.mediumImpact();
        },
        child: AnimatedScale(
          scale: isActive ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: double.infinity,
            height: 210, // Increased from 190 - moderate increase
            margin: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8), // Match UserSelectionScreen
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(24), // Match UserSelectionScreen
              gradient: isActive
                  ? AppTheme
                      .primaryGradient // Use same gradient as login/signup
                  : (isDarkMode
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF374151)
                                .withOpacity(0.7), // Lighter gray
                            const Color(0xFF4B5563)
                                .withOpacity(0.6), // Medium gray
                            const Color(0xFF6B7280)
                                .withOpacity(0.5), // Light gray
                          ],
                        )
                      : const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFFDFDFD), // off-white
                            Color(0xFFF5F5F7), // light cloud grey
                            Color(0xFFE0E0E2), // gentle cool grey
                          ],
                        )),
              border: isActive
                  ? Border.all(
                      color:
                          Colors.white.withOpacity(0.3), // Match login/signup
                      width: 2,
                    )
                  : Border.all(
                      color: isDarkMode
                          ? Colors.white.withOpacity(
                              0.2) // Increased opacity for better visibility
                          : const Color(0xFFE0E0E0).withOpacity(0.5),
                      width: 1,
                    ),
              boxShadow: [
                BoxShadow(
                  color: isActive
                      ? (isDarkMode
                          ? Colors.black.withOpacity(0.2)
                          : const Color(0xFF475569).withOpacity(0.08))
                      : (isDarkMode
                          ? Colors.black.withOpacity(0.2)
                          : const Color(0xFF475569).withOpacity(0.06)),
                  blurRadius: isActive ? 25 : 15,
                  offset: const Offset(0, 8),
                  spreadRadius: isActive ? 2 : 0,
                ),
                if (isActive && !isDarkMode)
                  BoxShadow(
                    color: const Color(0xFF475569).withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                    spreadRadius: 0,
                  ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.05),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16), // Match UserSelectionScreen
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Profile image with enhanced styling - Match UserSelectionScreen
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Background glow effect
                        if (isActive)
                          Container(
                            width: 110, // Increased from 100
                            height: 110, // Increased from 100
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(55), // Adjusted
                              gradient: RadialGradient(
                                colors: [
                                  Colors.white.withOpacity(0.2),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        // Main image container
                        Container(
                          width: 95, // Increased from 85
                          height: 95, // Increased from 85
                          decoration: BoxDecoration(
                            gradient: isActive
                                ? LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white.withOpacity(0.3),
                                      Colors.white.withOpacity(0.1),
                                    ],
                                  )
                                : LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      const Color(0xFFBDBDBD).withOpacity(0.3),
                                      const Color(0xFFE0E0E0).withOpacity(0.2),
                                    ],
                                  ),
                            borderRadius: BorderRadius.circular(
                                47.5), // Adjusted for new size (95/2)
                            border: Border.all(
                              color: isActive
                                  ? Colors.white.withOpacity(0.4)
                                  : Colors.white.withOpacity(0.2),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                                47.5), // Adjusted for new size
                            child: Image.asset(
                              image,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey.shade300,
                                  child: Icon(
                                    icon,
                                    size: 50,
                                    color: Colors.grey.shade600,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        // Role icon overlay - Match UserSelectionScreen
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 32, // Match UserSelectionScreen
                            height: 32, // Match UserSelectionScreen
                            decoration: BoxDecoration(
                              gradient: isActive
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFFFF6B9D),
                                        Color(0xFFFFA726)
                                      ],
                                    )
                                  : LinearGradient(
                                      colors: [
                                        Colors.grey.withOpacity(0.8),
                                        Colors.grey.withOpacity(0.6),
                                      ],
                                    ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              icon,
                              color: Colors.white,
                              size: 16, // Match UserSelectionScreen
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12), // Slightly increased from 10

                    // Role label with improved typography - Match UserSelectionScreen
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 18, // Match UserSelectionScreen
                        fontWeight: FontWeight.bold,
                        color: isActive
                            ? Colors.white
                            : (isDarkMode
                                ? Colors.white.withOpacity(0.9)
                                : const Color(0xFF0F172A)),
                        letterSpacing: 0.3,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4), // Reduced from 6

                    // Subtitle - Match UserSelectionScreen
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12, // Match UserSelectionScreen
                        fontWeight: FontWeight.w400,
                        color: isActive
                            ? Colors.white.withOpacity(0.9)
                            : (isDarkMode
                                ? Colors.white.withOpacity(0.7)
                                : const Color(0xFF475569)),
                        letterSpacing: 0.1,
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      )
          .animate()
          .fadeIn(
            duration: 600.ms,
            delay:
                (verificationCards.indexWhere((card) => card['role'] == role) *
                        150)
                    .ms,
          )
          .slideX(
            begin: 0.3,
            duration: 600.ms,
            delay:
                (verificationCards.indexWhere((card) => card['role'] == role) *
                        150)
                    .ms,
          )
          .scale(
            begin: const Offset(0.8, 0.8),
            duration: 600.ms,
            delay:
                (verificationCards.indexWhere((card) => card['role'] == role) *
                        150)
                    .ms,
          );
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        // Replicated: Exact same gradient background as UserSelectionScreen
        decoration: BoxDecoration(
          gradient: isDarkMode
              ? AppTheme.primaryGradient
              : AppTheme.lightPrimaryGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Updated header to match current User Selection screen styling
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Theme toggle button - Following action button color scheme
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.2)
                            : Colors.white.withOpacity(0.9),
                        border: isDarkMode
                            ? null
                            : Border.all(
                                color: const Color(0xFFE0E0E0),
                                width: 1,
                              ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isDarkMode
                            ? null
                            : [
                                BoxShadow(
                                  color:
                                      const Color(0xFF475569).withOpacity(0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          ThemeProvider.instance.themeIcon,
                          color: isDarkMode
                              ? Colors.white
                              : const Color(0xFF404040),
                          size: 20,
                        ),
                        onPressed: () async {
                          await ThemeProvider.instance.toggleTheme();
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8), // Reduced spacing for better fit

              // Compact title section to prevent scrolling
              Column(
                children: [
                  Text(
                    'Confirm Your Role',
                    style: GoogleFonts.inter(
                      fontSize: 28, // Further reduced for no scrolling
                      fontWeight: FontWeight.w700,
                      color: isDarkMode
                          ? AppTheme.primaryText
                          : AppTheme.lightPrimaryText,
                      height: 1.2,
                      letterSpacing: -0.5,
                    ),
                  ).animate().fadeIn(duration: 800.ms).slideY(begin: -0.3),
                  const SizedBox(height: 3), // Further reduced spacing
                  Text(
                    'Please confirm your role to continue',
                    style: GoogleFonts.inter(
                      fontSize: 16, // Further reduced
                      fontWeight: FontWeight.w400,
                      color: isDarkMode
                          ? AppTheme.secondaryText
                          : AppTheme.lightSecondaryText,
                      height: 1.3,
                    ),
                  ).animate().fadeIn(duration: 800.ms, delay: 200.ms),
                  const SizedBox(height: 6), // Further reduced spacing
                  // Smaller decorative line
                  Container(
                    width: 130, // Smaller width
                    height: 4, // Smaller height
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(1.5),
                      gradient: LinearGradient(
                        colors: isDarkMode
                            ? [
                                Colors.white.withOpacity(0.6),
                                Colors.white.withOpacity(0.3),
                              ]
                            : [
                                Colors.black.withOpacity(0.3),
                                Colors.black.withOpacity(0.1),
                              ],
                      ),
                    ),
                  ).animate().scaleX(duration: 800.ms, delay: 400.ms),
                ],
              ),

              const SizedBox(height: 10), // Further reduced for no scrolling

              // Updated role cards section to match current User Selection screen
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20), // Replicated: Same padding
                  child: Column(
                    children: [
                      // Add minimal spacing at the top
                      const SizedBox(height: 8), // Reduced from 8
                      // Generate cards with spacing between them
                      ...verificationCards.map((card) {
                        final index = verificationCards.indexOf(card);
                        return Column(
                          children: [
                            buildVerificationCard(
                              role: card['role'] as String,
                              label: card['label'] as String,
                              image: card['image'] as String,
                            ),
                            // Add spacing between cards, but not after the last one
                            if (index < verificationCards.length - 1)
                              const SizedBox(height: 16), // Reduced from 16
                          ],
                        );
                      }).toList(),
                      // Add minimal spacing at the bottom
                      const SizedBox(height: 8), // Reduced from 8
                    ],
                  ),
                ),
              ),

              // Updated continue button to match current User Selection screen design
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    24.0, 8.0, 24.0, 16.0), // Further reduced padding
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: _selectedRole != null ? 160 : 70, // Updated sizing
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: _selectedRole != null
                          ? (isDarkMode
                              ? AppTheme
                                  .primaryGradient // Use default dark theme gradient
                              : const LinearGradient(
                                  // Custom gradient for light theme
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFFDFDFD), // off-white
                                    Color(0xFFF5F5F7), // light cloud grey
                                    Color(0xFFE0E0E2), // gentle cool grey
                                  ],
                                ))
                          : LinearGradient(
                              colors: [
                                Colors.grey.withOpacity(0.3),
                                Colors.grey.withOpacity(0.2),
                              ],
                            ),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: _selectedRole != null
                          ? (isDarkMode
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                    spreadRadius: 2,
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: const Color(0xFF475569)
                                        .withOpacity(0.08),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                    spreadRadius: 2,
                                  ),
                                  BoxShadow(
                                    color: const Color(0xFF475569)
                                        .withOpacity(0.04),
                                    blurRadius: 6,
                                    offset: const Offset(0, -2),
                                  ),
                                ])
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(25),
                        onTap: _selectedRole != null
                            ? () {
                                HapticFeedback.mediumImpact();
                                // Verification-specific: Role confirmation logic
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text('Role confirmed: $_selectedRole'),
                                    backgroundColor: Colors.green.shade400,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                debugPrint('Role verified: $_selectedRole');
                                // TODO: Navigate to main app flow based on confirmed role
                              }
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_selectedRole != null) ...[
                                Text(
                                  'Continue',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDarkMode
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: isDarkMode
                                    ? Colors.white
                                    : (_selectedRole != null
                                        ? const Color(0xFF404040)
                                        : Colors.white),
                                size: _selectedRole != null ? 20 : 24,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ).animate().slideY(begin: 0.5, duration: 800.ms, delay: 600.ms),
            ],
          ),
        ),
      ),
    );
  }
}
