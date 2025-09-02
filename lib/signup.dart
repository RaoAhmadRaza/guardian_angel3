import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'colors.dart';
import 'widgets.dart';
import 'providers/theme_provider.dart';
import 'login_screen.dart';
import 'otp_verification_screen.dart';

class SignUP extends StatefulWidget {
  const SignUP({super.key});

  @override
  State<SignUP> createState() => _SignUPState();
}

class _SignUPState extends State<SignUP> {
  String selectedCountryCode = '+92';
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  bool isLoading = false;
  bool agreeToTerms = false;

  bool _isValidPhoneNumber(String phone) {
    // Remove any non-digit characters for validation
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');

    // Check if it's exactly 10 digits
    return cleanPhone.length == 10 && RegExp(r'^\d{10}$').hasMatch(cleanPhone);
  }

  void _createAccount() {
    // Validate required fields
    if (nameController.text.trim().isEmpty) {
      _showError('Please enter your full name');
      return;
    }

    if (emailController.text.trim().isEmpty) {
      _showError('Please enter your email address');
      return;
    }

    if (!emailController.text.contains('@')) {
      _showError('Please enter a valid email address');
      return;
    }

    if (!_isValidPhoneNumber(phoneController.text)) {
      _showError('Please enter a valid 10-digit phone number');
      return;
    }

    if (!agreeToTerms) {
      _showError('Please agree to the Terms of Service and Privacy Policy');
      return;
    }

    // Navigate to OTP verification
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OTPVerificationScreen(
          phoneNumber: '$selectedCountryCode ${phoneController.text}',
          isFromSignup: true,
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(color: Colors.white),
        ),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
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
                    // Back button
                    Positioned(
                      top: 16,
                      left: 16,
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
                            Icons.arrow_back_ios_new,
                            color: isDarkMode
                                ? Colors.white
                                : const Color(0xFF404040),
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),

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
                          // Logo
                          Hero(
                            tag: 'logo',
                            child: Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.white.withOpacity(0.2)
                                    : Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(18),
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
                                          offset: const Offset(0, 2),
                                          spreadRadius: 0,
                                        ),
                                      ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Image.asset(
                                  isDarkMode
                                      ? 'images/logo.png'
                                      : 'images/dark_logo.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ).animate().scale(
                                delay: 200.ms,
                                duration: 600.ms,
                                curve: Curves.elasticOut,
                              ),

                          const SizedBox(height: 16),

                          // Title
                          Text(
                            'Guardian Angel',
                            style: GoogleFonts.inter(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ).animate().slideY(
                                delay: 300.ms,
                                duration: 600.ms,
                                begin: 0.5,
                              ),

                          const SizedBox(height: 4),

                          // Subtitle
                          Text(
                            'Start protecting your loved ones today',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: isDarkMode
                                  ? Colors.white.withOpacity(0.9)
                                  : const Color(0xFF475569),
                            ),
                          ).animate().slideY(
                                delay: 400.ms,
                                duration: 600.ms,
                                begin: 0.5,
                              ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom section with form
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),

                  // Create account text
                  Center(
                    child: Text(
                      'Create Account',
                      style: GoogleFonts.inter(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode
                            ? AppTheme.primaryText
                            : AppTheme.lightPrimaryText,
                      ),
                    ).animate().slideX(
                          delay: 500.ms,
                          duration: 600.ms,
                          begin: -0.5,
                        ),
                  ),

                  const SizedBox(height: 8),

                  Center(
                    child: Text(
                      'Join our community of caring families',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: isDarkMode
                            ? AppTheme.secondaryText
                            : AppTheme.lightSecondaryText,
                      ),
                    ).animate().slideX(
                          delay: 600.ms,
                          duration: 600.ms,
                          begin: -0.5,
                        ),
                  ),

                  const SizedBox(height: 32),

                  // Social signup buttons
                  SocialLoginButton(
                    text: 'Continue with Google',
                    imagePath: 'images/google-logo.png',
                    onPressed: () {
                      // Handle Google signup
                    },
                  ).animate().slideX(
                        delay: 700.ms,
                        duration: 600.ms,
                        begin: 0.5,
                      ),

                  const SizedBox(height: 16),

                  SocialLoginButton(
                    text: 'Continue with Apple',
                    imagePath:
                        'images/apple-logo.png', // You'll need to add this
                    onPressed: () {
                      // Handle Apple signup
                    },
                  ).animate().slideX(
                        delay: 800.ms,
                        duration: 600.ms,
                        begin: 0.5,
                      ),

                  const SizedBox(height: 32),

                  // Divider
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1,
                          color: isDarkMode
                              ? AppTheme.borderColor
                              : AppTheme.lightBorderColor,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'or sign up with email',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: isDarkMode
                                ? AppTheme.placeholderText
                                : AppTheme.lightPlaceholderText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 1,
                          color: isDarkMode
                              ? AppTheme.borderColor
                              : AppTheme.lightBorderColor,
                        ),
                      ),
                    ],
                  ).animate().fadeIn(
                        delay: 900.ms,
                        duration: 600.ms,
                      ),

                  const SizedBox(height: 32),

                  // Form fields
                  CustomTextField(
                    hint: 'Full Name',
                    prefixIcon: Icons.person_outline,
                    controller: nameController,
                  ).animate().slideY(
                        delay: 1000.ms,
                        duration: 600.ms,
                        begin: 0.5,
                      ),

                  const SizedBox(height: 20),

                  CustomTextField(
                    hint: 'Email Address',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    controller: emailController,
                  ).animate().slideY(
                        delay: 1100.ms,
                        duration: 600.ms,
                        begin: 0.5,
                      ),

                  const SizedBox(height: 20),

                  // Phone number input
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context)
                              .shadowColor
                              .withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Theme.of(context)
                            .colorScheme
                            .surface
                            .withValues(alpha: 0.8),
                      ),
                      child: Row(
                        children: [
                          // Country code picker
                          CountryCodePicker(
                            selectedCode: selectedCountryCode,
                            onChanged: (code) {
                              setState(() {
                                selectedCountryCode = code;
                              });
                            },
                          ),

                          // Phone number field
                          Expanded(
                            child: TextField(
                              controller: phoneController,
                              keyboardType: TextInputType.phone,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Phone number',
                                hintStyle: GoogleFonts.inter(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6),
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                focusedBorder: UnderlineInputBorder(
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
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().slideY(
                        delay: 1200.ms,
                        duration: 600.ms,
                        begin: 0.5,
                      ),

                  const SizedBox(height: 24),

                  // Terms and conditions
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.only(top: 2),
                        child: Checkbox(
                          value: agreeToTerms,
                          onChanged: (value) {
                            setState(() {
                              agreeToTerms = value ?? false;
                            });
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          activeColor: AppTheme.eliteBlue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: isDarkMode
                                  ? AppTheme.secondaryText
                                  : AppTheme.lightSecondaryText,
                              height: 1.5,
                            ),
                            children: [
                              const TextSpan(text: 'I agree to the '),
                              TextSpan(
                                text: 'Terms of Service',
                                style: GoogleFonts.inter(
                                  color: isDarkMode
                                      ? Colors.white
                                      : const Color(0xFF404040),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: GoogleFonts.inter(
                                  color: isDarkMode
                                      ? Colors.white
                                      : const Color(0xFF404040),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(
                        delay: 1300.ms,
                        duration: 600.ms,
                      ),

                  const SizedBox(height: 32),

                  // Sign up button
                  GradientButton(
                    text: 'Create Account',
                    width: double.infinity,
                    gradient: isDarkMode
                        ? AppTheme.warmGradient
                        : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFFFDFDFD), // off-white
                              const Color(0xFFF5F5F7), // light cloud grey
                              const Color(0xFFE0E0E2), // gentle cool grey
                            ],
                          ),
                    textColor: isDarkMode
                        ? null // Use default text color
                        : const Color(0xFF0F172A),
                    isLoading: isLoading,
                    onPressed: _createAccount,
                  ).animate().slideY(
                        delay: 1400.ms,
                        duration: 600.ms,
                        begin: 0.5,
                      ),

                  const SizedBox(height: 32),

                  // Login link
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          PageRouteBuilder(
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    const TimeLuxLoginScreen(),
                            transitionsBuilder: (context, animation,
                                secondaryAnimation, child) {
                              return SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(-1.0, 0.0),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              );
                            },
                            transitionDuration:
                                const Duration(milliseconds: 300),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? AppTheme.backgroundColor
                              : AppTheme.lightBackgroundColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDarkMode
                                ? AppTheme.borderColor
                                : AppTheme.lightBorderColor,
                          ),
                        ),
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: isDarkMode
                                  ? AppTheme.secondaryText
                                  : AppTheme.lightSecondaryText,
                            ),
                            children: [
                              const TextSpan(text: 'Already have an account? '),
                              TextSpan(
                                text: 'Sign in',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode
                                      ? Colors.white
                                      : const Color(0xFF404040),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(
                        delay: 1500.ms,
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

  @override
  void dispose() {
    phoneController.dispose();
    nameController.dispose();
    emailController.dispose();
    super.dispose();
  }
}
