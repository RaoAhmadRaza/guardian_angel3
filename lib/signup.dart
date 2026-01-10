import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'colors.dart';
import 'widgets.dart';
import 'providers/theme_provider.dart';
import 'login_screen.dart';
import 'otp_verification_screen.dart';
import 'firebase/auth/google_auth_provider.dart';
import 'firebase/auth/apple_auth_provider.dart';
import 'user_selection_screen.dart';
import 'onboarding/services/onboarding_local_service.dart';
import 'services/session_service.dart';
import 'next_screen.dart';
import 'caregiver_main_screen.dart';
import 'profile/user_profile_remote_service.dart';

class SignUP extends StatefulWidget {
  const SignUP({super.key});

  @override
  State<SignUP> createState() => _SignUPState();
}

class _SignUPState extends State<SignUP> {
  String selectedCountryCode = '+92';
  final TextEditingController phoneController = TextEditingController();
  bool isLoading = false;
  bool agreeToTerms = false;
  bool isGoogleLoading = false;
  bool isAppleLoading = false;

  Future<void> _handleGoogleSignUp() async {
    setState(() => isGoogleLoading = true);
    
    try {
      final result = await GoogleAuthProviderImpl.instance.signInWithGoogle();
      
      if (!mounted) return;
      
      if (result.success && result.user != null) {
        // STEP 1: Save auth basics to Local User Base Table (FIRST)
        final saveResult = await _saveUserBaseLocally(result.user!);
        if (!saveResult) {
          _showError('Failed to save user data locally');
          return;
        }
        
        // Successfully signed up with Google
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome, ${result.user!.displayName ?? result.user!.email}!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Navigate based on user's role (checks local state first, then Firestore)
        final uid = result.user!.uid;
        await _navigateBasedOnRole(uid);
      } else if (result.errorCode != 'cancelled') {
        _showError(result.errorMessage ?? 'Google sign-up failed');
      }
    } catch (e) {
      if (mounted) {
        _showError('An error occurred during sign-up');
      }
    } finally {
      if (mounted) {
        setState(() => isGoogleLoading = false);
      }
    }
  }

  Future<void> _handleAppleSignUp() async {
    setState(() => isAppleLoading = true);
    
    try {
      final result = await AppleAuthProviderImpl.instance.signInWithApple();
      
      if (!mounted) return;
      
      if (result.success && result.user != null) {
        // STEP 1: Save auth basics to Local User Base Table (FIRST)
        final saveResult = await _saveUserBaseLocally(result.user!);
        if (!saveResult) {
          _showError('Failed to save user data locally');
          return;
        }
        
        // Successfully signed up with Apple
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome, ${result.user!.displayName ?? result.user!.email ?? 'User'}!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Navigate based on user's role (checks local state first, then Firestore)
        final uid = result.user!.uid;
        await _navigateBasedOnRole(uid);
      } else if (result.errorCode != 'cancelled') {
        _showError(result.errorMessage ?? 'Apple sign-up failed');
      }
    } catch (e) {
      if (mounted) {
        _showError('An error occurred during sign-up');
      }
    } finally {
      if (mounted) {
        setState(() => isAppleLoading = false);
      }
    }
  }

  /// STEP 1: Saves auth basics to Local User Base Table (OFFLINE-FIRST).
  /// This is the first step in the onboarding flow.
  /// Returns true on success, false on failure.
  Future<bool> _saveUserBaseLocally(dynamic user) async {
    try {
      final uid = user.uid as String?;
      if (uid == null || uid.isEmpty) {
        debugPrint('[SignUp] ERROR: User UID is null or empty');
        return false;
      }

      await OnboardingLocalService.instance.saveUserBase(
        uid: uid,
        email: user.email as String?,
        fullName: user.displayName as String?,
        profileImageUrl: user.photoURL as String?,
      );
      
      debugPrint('[SignUp] Step 1 complete: User base saved locally for $uid');
      return true;
    } catch (e) {
      debugPrint('[SignUp] Step 1 FAILED: $e');
      return false;
    }
  }

  /// Determines the user's role and navigates to the appropriate screen.
  /// 
  /// Priority:
  /// 1. Check local onboarding state (for users who signed up on this device)
  /// 2. Check Firestore profile (for users who signed up on another device)
  /// 3. If neither found, go to role selection (new user)
  Future<void> _navigateBasedOnRole(String uid) async {
    debugPrint('[SignUp] Determining role for user: $uid');
    
    // FIRST: Check local onboarding state
    final onboardingState = OnboardingLocalService.instance.getOnboardingState(uid);
    debugPrint('[SignUp] Local onboarding state: $onboardingState');
    
    if (onboardingState == OnboardingState.caregiverComplete) {
      debugPrint('[SignUp] Local state: caregiver complete');
      await SessionService.instance.startSession(userType: 'caregiver', uid: uid);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const CaregiverMainScreen()),
      );
      return;
    } else if (onboardingState == OnboardingState.patientComplete) {
      debugPrint('[SignUp] Local state: patient complete');
      await SessionService.instance.startSession(userType: 'patient', uid: uid);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const NextScreen()),
      );
      return;
    }
    
    // SECOND: Check Firestore for existing profile
    debugPrint('[SignUp] Local state incomplete, checking Firestore...');
    try {
      final profileService = UserProfileRemoteService();
      final existingProfile = await profileService.fetchProfile(uid);
      
      if (existingProfile != null && existingProfile.role.isNotEmpty) {
        debugPrint('[SignUp] Found Firestore profile with role: ${existingProfile.role}');
        
        if (existingProfile.role == 'caregiver') {
          await SessionService.instance.startSession(userType: 'caregiver', uid: uid);
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const CaregiverMainScreen()),
          );
          return;
        } else if (existingProfile.role == 'patient') {
          await SessionService.instance.startSession(userType: 'patient', uid: uid);
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const NextScreen()),
          );
          return;
        }
      }
    } catch (e) {
      debugPrint('[SignUp] Error fetching Firestore profile: $e');
    }
    
    // THIRD: No profile found - user needs to complete onboarding
    debugPrint('[SignUp] No existing profile found, redirecting to role selection');
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const UserSelectionScreen()),
    );
  }

  /// Returns an error message if phone is invalid, null if valid
  String? _getPhoneValidationError(String phone) {
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    if (cleanPhone.isEmpty) {
      return 'Please enter your phone number';
    }
    if (cleanPhone.length < 7) {
      return 'Phone number is too short (minimum 7 digits)';
    }
    if (cleanPhone.length > 15) {
      return 'Phone number is too long (maximum 15 digits)';
    }
    return null;
  }

  void _createAccount() {
    // Validate phone number with specific error messages
    final phoneError = _getPhoneValidationError(phoneController.text);
    if (phoneError != null) {
      _showError(phoneError);
      return;
    }

    if (!agreeToTerms) {
      _showError('Please agree to the Terms of Service and Privacy Policy');
      return;
    }

    // Navigate to OTP verification
    // Format phone number in E.164 format (no spaces)
    final cleanPhone = phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OTPVerificationScreen(
          phoneNumber: '$selectedCountryCode$cleanPhone',
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
                    text: isGoogleLoading ? 'Signing up...' : 'Continue with Google',
                    imagePath: 'images/google-logo.png',
                    onPressed: isGoogleLoading ? () {} : () => _handleGoogleSignUp(),
                  ).animate().slideX(
                        delay: 700.ms,
                        duration: 600.ms,
                        begin: 0.5,
                      ),

                  const SizedBox(height: 16),

                  SocialLoginButton(
                    text: isAppleLoading ? 'Signing up...' : 'Continue with Apple',
                    imagePath:
                        'images/apple-logo.png', // You'll need to add this
                    onPressed: isAppleLoading ? () {} : () => _handleAppleSignUp(),
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
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[\d\s\-]')),
                                LengthLimitingTextInputFormatter(20),
                              ],
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
   
    super.dispose();
  }
}
