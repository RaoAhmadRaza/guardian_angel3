import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'colors.dart';
import 'providers/theme_provider.dart';
import 'theme/motion.dart';
import 'onboarding/services/onboarding_local_service.dart';
import 'doctor_main_screen.dart';

/// Modern doctor details screen with gender selection and form fields
///
/// Implements Material Design 3 principles with smooth animations
/// and responsive design for optimal user experience.
class DoctorDetailsScreen extends StatefulWidget {
  const DoctorDetailsScreen({super.key});

  @override
  State<DoctorDetailsScreen> createState() => _DoctorDetailsScreenState();
}

class _DoctorDetailsScreenState extends State<DoctorDetailsScreen>
    with TickerProviderStateMixin {
  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _specialtyController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _phoneController = TextEditingController();
  final _licenseController = TextEditingController();

  // Gender selection state
  Gender _selectedGender = Gender.male;

  // Animation controllers
  late AnimationController _avatarAnimationController;
  late AnimationController _genderToggleController;
  late Animation<double> _avatarScaleAnimation;
  late Animation<double> _avatarOpacityAnimation;

  // Focus nodes for accessibility
  final _nameFocusNode = FocusNode();
  final _specialtyFocusNode = FocusNode();
  final _hospitalFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _licenseFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    // Avatar change animation controller
    _avatarAnimationController = AnimationController(
      duration: AppMotion.medium,
      vsync: this,
    );

    // Gender toggle animation controller
    _genderToggleController = AnimationController(
      duration: AppMotion.fast,
      vsync: this,
    );

    // Avatar scale and opacity animations for smooth transitions
    _avatarScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _avatarAnimationController,
      curve: AppMotion.standardCurve,
    ));

    _avatarOpacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.3,
    ).animate(CurvedAnimation(
      parent: _avatarAnimationController,
      curve: AppMotion.standardCurve,
    ));
  }

  @override
  void dispose() {
    // Clean up controllers and focus nodes
    _nameController.dispose();
    _specialtyController.dispose();
    _hospitalController.dispose();
    _phoneController.dispose();
    _licenseController.dispose();
    _avatarAnimationController.dispose();
    _genderToggleController.dispose();
    _nameFocusNode.dispose();
    _specialtyFocusNode.dispose();
    _hospitalFocusNode.dispose();
    _phoneFocusNode.dispose();
    _licenseFocusNode.dispose();
    super.dispose();
  }

  /// Handles gender selection with smooth avatar transition
  void _onGenderToggle(Gender gender) async {
    if (_selectedGender != gender) {
      // Provide haptic feedback for better UX
      HapticFeedback.selectionClick();

      // Start avatar transition animation
      await _avatarAnimationController.forward();

      setState(() {
        _selectedGender = gender;
      });

      // Complete avatar transition
      await _avatarAnimationController.reverse();

      // Animate gender toggle indicator
      _genderToggleController.forward().then((_) {
        _genderToggleController.reverse();
      });
    }
  }

  /// Validates and submits the doctor details form
  void _submitDoctorDetails() async {
    if (_formKey.currentState!.validate()) {
      // Provide success haptic feedback
      HapticFeedback.mediumImpact();

      // Get current user ID
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) {
        debugPrint('[DoctorDetailsScreen] ERROR: No authenticated user');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication error. Please sign in again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // TODO: Save Doctor Details to Local Table (OFFLINE-FIRST)
      // For now, we'll just simulate saving and navigate
      
      debugPrint('Doctor Details saved: name=${_nameController.text}, specialty=${_specialtyController.text}');

      // Show success message
      _showSuccessSnackBar();

      // Navigate to Doctor Main Screen with smooth transition
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const DoctorMainScreen(),
          transitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;

            var tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: curve),
            );

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        ),
      );
    } else {
      // Provide error haptic feedback
      HapticFeedback.lightImpact();
    }
  }

  /// Shows success snackbar with modern design
  void _showSuccessSnackBar() {
    final snackBar = SnackBar(
      content: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: Colors.white,
          ),
          const SizedBox(width: 12),
          Text(
            'Doctor details saved successfully!',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
      backgroundColor: Colors.green.shade600,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: isDarkMode
              ? AppTheme.primaryGradient
              : AppTheme.lightPrimaryGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with back button and theme toggle
              _buildHeader(isDarkMode),

              // Main content area
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),

                        // Title section
                        _buildTitleSection(),

                        const SizedBox(height: 40),

                        // Avatar and gender selection
                        _buildGenderSelection(),

                        const SizedBox(height: 40),

                        // Doctor details form
                        _buildDoctorForm(),

                        const SizedBox(height: 32),

                        // Submit button
                        _buildSubmitButton(),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the header with navigation and theme toggle
  Widget _buildHeader(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button
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
                        color: const Color(0xFF475569).withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new,
                color: isDarkMode ? Colors.white : const Color(0xFF404040),
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ).animate().slideX(begin: -0.3, duration: AppMotion.medium),

          // Theme toggle button
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
                        color: const Color(0xFF475569).withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
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
          ).animate().slideX(begin: 0.3, duration: AppMotion.medium),
        ],
      ),
    );
  }

  /// Builds the title section
  Widget _buildTitleSection() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      children: [
        Text(
          'Doctor Profile',
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ).animate().fadeIn(duration: AppMotion.medium).slideY(begin: -0.2),
        const SizedBox(height: 8),
        Text(
          'Please complete your professional profile',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: isDarkMode
                ? Colors.white.withOpacity(0.7)
                : const Color(0xFF64748B),
          ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(duration: AppMotion.medium, delay: 100.ms),
      ],
    );
  }

  /// Builds the gender selection section with avatar
  Widget _buildGenderSelection() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      children: [
        // Avatar with animation
        ScaleTransition(
          scale: _avatarScaleAnimation,
          child: FadeTransition(
            opacity: _avatarOpacityAnimation,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  _selectedGender == Gender.male
                      ? 'images/maledoc.png'
                      : 'images/femaledoc.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ).animate().scale(duration: AppMotion.medium, curve: Curves.easeOutBack),

        const SizedBox(height: 24),

        // Gender toggle
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.white.withOpacity(0.1)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.1)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildGenderOption(Gender.male, 'Male', Icons.male),
              _buildGenderOption(Gender.female, 'Female', Icons.female),
            ],
          ),
        ).animate().fadeIn(duration: AppMotion.medium, delay: 200.ms),
      ],
    );
  }

  /// Builds a single gender option button
  Widget _buildGenderOption(Gender gender, String label, IconData icon) {
    final isSelected = _selectedGender == gender;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _onGenderToggle(gender),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDarkMode
                  ? Colors.white.withOpacity(0.3)
                  : Colors.black.withOpacity(0.08))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? (isDarkMode ? Colors.white : const Color(0xFF404040))
                  : (isDarkMode
                      ? Colors.white.withOpacity(0.6)
                      : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? (isDarkMode ? Colors.white : const Color(0xFF404040))
                    : (isDarkMode
                        ? Colors.white.withOpacity(0.6)
                        : const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the doctor details form fields
  Widget _buildDoctorForm() {
    return Column(
      children: [
        _buildTextField(
          controller: _nameController,
          focusNode: _nameFocusNode,
          label: 'Full Name',
          hint: 'Dr. John Doe',
          icon: Icons.person_outline,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your name';
            }
            return null;
          },
          delay: 300,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _specialtyController,
          focusNode: _specialtyFocusNode,
          label: 'Specialty',
          hint: 'Cardiologist, General Practitioner, etc.',
          icon: Icons.medical_services_outlined,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your specialty';
            }
            return null;
          },
          delay: 400,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _hospitalController,
          focusNode: _hospitalFocusNode,
          label: 'Hospital / Clinic',
          hint: 'City Hospital',
          icon: Icons.local_hospital_outlined,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your hospital or clinic name';
            }
            return null;
          },
          delay: 500,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _phoneController,
          focusNode: _phoneFocusNode,
          label: 'Phone Number',
          hint: '+1 234 567 8900',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your phone number';
            }
            return null;
          },
          delay: 600,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _licenseController,
          focusNode: _licenseFocusNode,
          label: 'Medical License Number',
          hint: 'MD-12345-6789',
          icon: Icons.badge_outlined,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your license number';
            }
            return null;
          },
          delay: 700,
        ),
      ],
    );
  }

  /// Builds a styled text field with animation
  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    required int delay,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.1)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: isDarkMode
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF475569).withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        style: GoogleFonts.inter(
          fontSize: 16,
          color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(
            color: isDarkMode
                ? Colors.white.withOpacity(0.6)
                : const Color(0xFF64748B),
          ),
          hintText: hint,
          hintStyle: GoogleFonts.inter(
            color: isDarkMode
                ? Colors.white.withOpacity(0.3)
                : const Color(0xFF94A3B8),
          ),
          prefixIcon: Icon(
            icon,
            color: isDarkMode
                ? Colors.white.withOpacity(0.5)
                : const Color(0xFF64748B),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          errorStyle: GoogleFonts.inter(
            color: const Color(0xFFEF4444),
            fontSize: 12,
          ),
        ),
        validator: validator,
      ),
    ).animate().fadeIn(duration: AppMotion.medium, delay: delay.ms).slideY(begin: 0.2);
  }

  /// Builds the submit button
  Widget _buildSubmitButton() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: isDarkMode
            ? AppTheme.primaryGradient
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFDFDFD),
                  Color(0xFFF5F5F7),
                  Color(0xFFE0E0E2),
                ],
              ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.white.withOpacity(0.1)
                : const Color(0xFF64748B).withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _submitDoctorDetails,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Save Profile',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward,
                size: 20,
                color: isDarkMode ? Colors.white : const Color(0xFF404040),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: AppMotion.medium, delay: 800.ms).slideY(begin: 0.2);
  }
}

enum Gender { male, female }
