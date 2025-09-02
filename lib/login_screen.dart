import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'colors.dart';
import 'widgets.dart';
import 'providers/theme_provider.dart';
import 'signup.dart';
import 'user_selection_screen.dart';
import 'otp_verification_screen.dart';

class TimeLuxLoginScreen extends StatefulWidget {
  const TimeLuxLoginScreen({super.key});

  @override
  State<TimeLuxLoginScreen> createState() => _TimeLuxLoginScreenState();
}

class _TimeLuxLoginScreenState extends State<TimeLuxLoginScreen> {
  String selectedCountryCode = '+92';
  final TextEditingController phoneController = TextEditingController();
  bool isLoading = false;

  bool _isValidPhoneNumber(String phone) {
    // Remove any whitespace and check if it's exactly 10 digits
    final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
    return RegExp(r'^\d{10}$').hasMatch(cleanPhone);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _login() {
    final phone = phoneController.text.trim();

    // Validate phone number
    if (phone.isEmpty) {
      _showError('Please enter your phone number');
      return;
    }

    if (!_isValidPhoneNumber(phone)) {
      _showError('Please enter a valid 10-digit phone number');
      return;
    }

    // Navigate to OTP verification for login
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OTPVerificationScreen(
          phoneNumber: '$selectedCountryCode$phone',
          isFromSignup: false, // This is for login
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
            // Top section with gradient background filling upper half
            SizedBox(
              height: size.height * 0.39,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: isDarkMode
                            ? AppTheme.primaryGradient
                            : const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(
                                      0xFFFBFBFB), // Very light off-white at top
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
                    ),
                  ),
                  // Back button
                  Padding(
                    padding: const EdgeInsets.only(top: 80.0, left: 16),
                    child: Positioned(
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
                  ),
                  // Theme toggle button
                  Padding(
                    padding: const EdgeInsets.only(top: 80.0, left: 330),
                    child: Positioned(
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
                  ),
                  // Main content stays centered as before
                  Padding(
                    padding: const EdgeInsets.only(top: 50.0),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo
                          Hero(
                            tag: 'logo',
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.white.withOpacity(0.2)
                                    : Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(20),
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
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                          spreadRadius: 0,
                                        ),
                                      ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
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
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode
                                  ? Colors.white
                                  : const Color(0xFF404040),
                            ),
                          ).animate().slideY(
                                delay: 300.ms,
                                duration: 600.ms,
                                begin: 0.5,
                              ),

                          const SizedBox(height: 4),

                          // Subtitle
                          Text(
                            'Watching over when you can\'t',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: isDarkMode
                                  ? Colors.white.withOpacity(0.9)
                                  : const Color(0xFF6B7280),
                            ),
                          ).animate().slideY(
                                delay: 400.ms,
                                duration: 600.ms,
                                begin: 0.5,
                              ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom section with form
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),

                  // Welcome back text
                  Center(
                    child: Text(
                      'Welcome Back!',
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
                      'Sign in to continue monitoring \n\t\t\t\t\t\t       your loved ones',
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

                  const SizedBox(height: 40),

                  // Social login buttons
                  SocialLoginButton(
                    text: 'Continue with Google',
                    imagePath: 'images/google-logo.png',
                    onPressed: () {
                      // Handle Google login
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
                      // Handle Apple login
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
                          'or continue with phone',
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
                        delay: 1000.ms,
                        duration: 600.ms,
                        begin: 0.5,
                      ),

                  const SizedBox(height: 32),

                  // Login button
                  GradientButton(
                    text: 'Continue',
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
                    isLoading: isLoading,
                    onPressed: () {
                      setState(() {
                        isLoading = true;
                      });

                      // Add small delay for UX, then perform login
                      Future.delayed(const Duration(milliseconds: 500), () {
                        setState(() {
                          isLoading = false;
                        });
                        _login();
                      });
                    },
                  ).animate().slideY(
                        delay: 1100.ms,
                        duration: 600.ms,
                        begin: 0.5,
                      ),

                  const SizedBox(height: 32),

                  // Sign up link
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          PageRouteBuilder(
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    const SignUP(),
                            transitionsBuilder: (context, animation,
                                secondaryAnimation, child) {
                              return SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(1.0, 0.0),
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
                              const TextSpan(text: 'New to Guardian Angel? '),
                              TextSpan(
                                text: 'Sign up',
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
                        delay: 1200.ms,
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
    super.dispose();
  }
}
