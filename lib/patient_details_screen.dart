import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'colors.dart';
import 'providers/theme_provider.dart';
import 'theme/motion.dart';
import 'watch_connection_screen.dart';
import 'services/patient_service.dart';
import 'onboarding/services/onboarding_local_service.dart';
import 'onboarding/services/onboarding_firestore_service.dart';
import 'relationships/services/relationship_service.dart';
import 'relationships/services/doctor_relationship_service.dart';

/// Modern patient details screen with gender selection and form fields
///
/// Implements Material Design 3 principles with smooth animations
/// and responsive design for optimal user experience.
class PatientDetailsScreen extends StatefulWidget {
  final int patientAge;

  const PatientDetailsScreen({
    super.key,
    required this.patientAge,
  });

  @override
  State<PatientDetailsScreen> createState() => _PatientDetailsScreenState();
}

class _PatientDetailsScreenState extends State<PatientDetailsScreen>
    with TickerProviderStateMixin {
  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _medicalHistoryController = TextEditingController();

  // Gender selection state
  Gender _selectedGender = Gender.male;

  // Animation controllers
  late AnimationController _avatarAnimationController;
  late AnimationController _genderToggleController;
  late Animation<double> _avatarScaleAnimation;
  late Animation<double> _avatarOpacityAnimation;

  // Focus nodes for accessibility
  final _nameFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _addressFocusNode = FocusNode();
  final _medicalHistoryFocusNode = FocusNode();

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
    _phoneController.dispose();
    _addressController.dispose();
    _medicalHistoryController.dispose();
    _avatarAnimationController.dispose();
    _genderToggleController.dispose();
    _nameFocusNode.dispose();
    _phoneFocusNode.dispose();
    _addressFocusNode.dispose();
    _medicalHistoryFocusNode.dispose();
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

  /// Validates and submits the patient details form
  /// STEP 5B: Saves Patient Details to Local Table (OFFLINE-FIRST)
  /// STEP 6B: Mirrors to Firestore (NON-BLOCKING)
  void _submitPatientDetails() async {
    if (_formKey.currentState!.validate()) {
      // Provide success haptic feedback
      HapticFeedback.mediumImpact();

      // Get current user ID - try Firebase Auth first, fallback to local storage
      String? uid = FirebaseAuth.instance.currentUser?.uid;
      
      // Fallback for simulator mode: get UID from local storage
      if (uid == null || uid.isEmpty) {
        uid = OnboardingLocalService.instance.getLastSavedUid();
        debugPrint('[PatientDetailsScreen] Using fallback UID from local storage: $uid');
      }
      
      if (uid == null || uid.isEmpty) {
        debugPrint('[PatientDetailsScreen] ERROR: No authenticated user');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication error. Please sign in again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // STEP 5B: Save Patient Details to Local Table (OFFLINE-FIRST - BLOCKING)
      try {
        await OnboardingLocalService.instance.savePatientDetails(
          uid: uid,
          gender: _selectedGender.name,
          name: _nameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          address: _addressController.text.trim().isNotEmpty 
              ? _addressController.text.trim() 
              : '',
          medicalHistory: _medicalHistoryController.text.trim().isNotEmpty 
              ? _medicalHistoryController.text.trim() 
              : '',
        );
        debugPrint('[PatientDetailsScreen] Step 5B: Patient details saved locally');
      } catch (e) {
        debugPrint('[PatientDetailsScreen] Step 5B FAILED: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save details. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Save patient data to local storage (SharedPreferences - legacy support)
      await PatientService.instance.savePatientData(
        fullName: _nameController.text.trim(),
        gender: _selectedGender.name,
        age: widget.patientAge,
        phoneNumber: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        medicalHistory: _medicalHistoryController.text.trim(),
      );

      // STEP 6B: Mirror to Firestore (NON-BLOCKING)
      // Fire-and-forget - errors logged but don't block navigation
      OnboardingFirestoreService.instance.mirrorPatientToFirestore(uid).then((_) {
        debugPrint('[PatientDetailsScreen] Step 6B: Patient data mirrored to Firestore');
      }).catchError((e) {
        debugPrint('[PatientDetailsScreen] Step 6B Firestore mirror failed (will retry): $e');
      });

      // STEP 7B: Create pending relationship with invite code (NON-BLOCKING)
      // This allows patient to share invite code with caregivers
      RelationshipService.instance.createPatientInvite(patientId: uid).then((result) {
        if (result.success && result.data != null) {
          debugPrint('[PatientDetailsScreen] Step 7B: Caregiver invite created: ${result.data!.inviteCode}');
        } else {
          debugPrint('[PatientDetailsScreen] Step 7B: Failed to create caregiver invite: ${result.errorMessage}');
        }
      }).catchError((e) {
        debugPrint('[PatientDetailsScreen] Step 7B: Caregiver invite creation error: $e');
      });

      // STEP 7C: Create pending doctor relationship with invite code (NON-BLOCKING)
      // This allows patient to share invite code with doctors
      DoctorRelationshipService.instance.createPatientDoctorInvite(patientId: uid).then((result) {
        if (result.success && result.data != null) {
          debugPrint('[PatientDetailsScreen] Step 7C: Doctor invite created: ${result.data!.inviteCode}');
        } else {
          debugPrint('[PatientDetailsScreen] Step 7C: Failed to create doctor invite: ${result.errorMessage}');
        }
      }).catchError((e) {
        debugPrint('[PatientDetailsScreen] Step 7C: Doctor invite creation error: $e');
      });

      debugPrint('Patient Details saved: age=${widget.patientAge}, gender=${_selectedGender.name}');

      // Show success message
      _showSuccessSnackBar();

      // Debug prints to check what data is being passed
      print(
          'PatientDetailsScreen - passing selectedGender: ${_selectedGender.name}');
      print(
          'PatientDetailsScreen - passing patientName: ${_nameController.text.trim()}');

      // Navigate to Watch Connection screen with smooth transition
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              WatchConnectionScreen(
            selectedGender: _selectedGender.name,
            patientName: _nameController.text.trim().isNotEmpty
                ? _nameController.text.trim()
                : 'Patient',
          ),
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
          Icon(
            Icons.check_circle_outline,
            color: Colors.white,
          ),
          const SizedBox(width: 12),
          Text(
            'Patient details saved successfully!',
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

                        // Patient details form
                        _buildPatientForm(),

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

  /// Builds the header with navigation and theme toggle - iOS style with consistent color scheme
  Widget _buildHeader(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button - Following action button color scheme
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
                await ThemeProvider.instance.toggleTheme();
              },
            ),
          ).animate().slideX(begin: 0.3, duration: AppMotion.medium),
        ],
      ),
    );
  }

  /// Builds the title section with animations - iOS typography and theme-appropriate colors
  Widget _buildTitleSection() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Text(
          'Patient Details',
          style: GoogleFonts.inter(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color:
                isDarkMode ? AppTheme.primaryText : AppTheme.lightPrimaryText,
            height: 1.2,
            letterSpacing: -0.5,
          ),
        ).animate().fadeIn(duration: AppMotion.ultraSlow).slideY(begin: -0.3),

        const SizedBox(height: 8),

        Text(
          'Complete your profile information',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: isDarkMode
                ? AppTheme.secondaryText
                : AppTheme.lightSecondaryText,
            height: 1.4,
            letterSpacing: 0,
          ),
        ).animate().fadeIn(
              duration: AppMotion.ultraSlow,
              delay: AppMotion.staggerDelay(1),
            ),

        const SizedBox(height: 16),

        // Monochromatic decorative line - following user selection screen
        Container(
          width: 120,
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
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
        ).animate().scaleX(
              duration: AppMotion.ultraSlow,
              delay: AppMotion.staggerDelay(2),
            ),
      ],
    );
  }

  /// Builds gender selection with animated avatar - iOS style with theme-appropriate colors
  Widget _buildGenderSelection() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Animated avatar container - Enhanced iOS style
        AnimatedBuilder(
          animation: _avatarAnimationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _avatarScaleAnimation.value,
              child: Opacity(
                opacity: _avatarOpacityAnimation.value,
                child: Hero(
                  tag: 'patient_avatar',
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.3)
                            : const Color(0xFFE0E0E0).withOpacity(0.8),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDarkMode
                              ? Colors.black.withOpacity(0.3)
                              : const Color(0xFF475569).withOpacity(0.1),
                          blurRadius: isDarkMode ? 20 : 16,
                          offset: Offset(0, isDarkMode ? 10 : 8),
                        ),
                        if (!isDarkMode)
                          BoxShadow(
                            color: const Color(0xFF475569).withOpacity(0.05),
                            blurRadius: 32,
                            offset: const Offset(0, 12),
                          ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        _selectedGender == Gender.male
                            ? 'images/male.jpg'
                            : 'images/female.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade300,
                            child: Icon(
                              _selectedGender == Gender.male
                                  ? Icons.man
                                  : Icons.woman,
                              size: 80,
                              color: Colors.grey.shade600,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ).animate().fadeIn(
              duration: AppMotion.ultraSlow,
              delay: AppMotion.staggerDelay(3),
            ),

        const SizedBox(height: 24),

        // Gender toggle buttons - iOS style with theme-appropriate colors
        AnimatedBuilder(
          animation: _genderToggleController,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + (_genderToggleController.value * 0.05),
              child: Container(
                padding: const EdgeInsets.all(4),
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
                  borderRadius: BorderRadius.circular(16),
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildGenderButton(
                      gender: Gender.male,
                      label: 'Male',
                      imagePath: 'images/male.jpg',
                    ),
                    _buildGenderButton(
                      gender: Gender.female,
                      label: 'Female',
                      imagePath: 'images/female.jpg',
                    ),
                  ],
                ),
              ),
            );
          },
        ).animate().fadeIn(
              duration: AppMotion.ultraSlow,
              delay: AppMotion.staggerDelay(4),
            ),
      ],
    );
  }

  /// Builds individual gender selection button - iOS style with theme-appropriate colors
  Widget _buildGenderButton({
    required Gender gender,
    required String label,
    required String imagePath,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedGender == gender;

    return GestureDetector(
      onTap: () => _onGenderToggle(gender),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.standardCurve,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDarkMode
                  ? Colors.white.withOpacity(0.3)
                  : Colors.black.withOpacity(0.08))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.6)
                      : const Color(0xFF404040).withOpacity(0.6),
                  width: 1,
                ),
              ),
              child: ClipOval(
                child: Image.asset(
                  imagePath,
                  width: 24,
                  height: 24,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.2)
                          : Colors.black.withOpacity(0.1),
                      child: Icon(
                        gender == Gender.male ? Icons.man : Icons.woman,
                        color:
                            isDarkMode ? Colors.white : const Color(0xFF404040),
                        size: 16,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isDarkMode ? Colors.white : const Color(0xFF404040),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the patient information form
  Widget _buildPatientForm() {
    return Column(
      children: [
        // Full Name field
        _buildFormField(
          controller: _nameController,
          focusNode: _nameFocusNode,
          label: 'Full Name',
          hint: 'Enter your full name',
          prefixIcon: Icons.person_outline,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your full name';
            }
            if (value.trim().length < 2) {
              return 'Name must be at least 2 characters';
            }
            return null;
          },
          animationDelay: AppMotion.staggerDelay(5),
        ),

        const SizedBox(height: 20),

        // Phone Number field
        _buildFormField(
          controller: _phoneController,
          focusNode: _phoneFocusNode,
          label: 'Phone Number',
          hint: 'Enter your phone number',
          prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your phone number';
            }
            if (value.trim().length < 10) {
              return 'Please enter a valid phone number';
            }
            return null;
          },
          animationDelay: AppMotion.staggerDelay(6),
        ),

        const SizedBox(height: 20),

        // Address field
        _buildFormField(
          controller: _addressController,
          focusNode: _addressFocusNode,
          label: 'Address',
          hint: 'Enter your address',
          prefixIcon: Icons.location_on_outlined,
          maxLines: 3,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your address';
            }
            return null;
          },
          animationDelay: AppMotion.staggerDelay(7),
        ),

        const SizedBox(height: 20),

        // Medical History field (optional)
        _buildFormField(
          controller: _medicalHistoryController,
          focusNode: _medicalHistoryFocusNode,
          label: 'Medical History (Optional)',
          hint: 'Any relevant medical conditions or notes',
          prefixIcon: Icons.medical_information_outlined,
          maxLines: 4,
          isRequired: false,
          animationDelay: AppMotion.staggerDelay(8),
        ),
      ],
    );
  }

  /// Builds a modern form field with animations and validation - iOS style with theme integration
  Widget _buildFormField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool isRequired = true,
    String? Function(String?)? validator,
    Duration? animationDelay,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
            blurRadius: isDarkMode ? 12 : 8,
            offset: Offset(0, isDarkMode ? 4 : 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: isDarkMode ? AppTheme.primaryText : AppTheme.lightPrimaryText,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(
            prefixIcon,
            size: 22,
            color:
                isDarkMode ? AppTheme.tertiaryText : AppTheme.lightTertiaryText,
          ),
          labelStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDarkMode
                ? AppTheme.secondaryText
                : AppTheme.lightSecondaryText,
          ),
          hintStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: isDarkMode
                ? AppTheme.placeholderText
                : AppTheme.lightPlaceholderText,
          ),
          filled: true,
          fillColor:
              Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color:
                  isDarkMode ? AppTheme.borderColor : AppTheme.lightBorderColor,
              width: 1,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color:
                  isDarkMode ? AppTheme.borderColor : AppTheme.lightBorderColor,
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color:
                  isDarkMode ? AppTheme.primaryText : const Color(0xFF64748B),
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: isDarkMode ? AppTheme.errorColor : AppTheme.errorColor,
              width: 2,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: isDarkMode ? AppTheme.errorColor : AppTheme.errorColor,
              width: 2,
            ),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 20,
            vertical: maxLines > 1 ? 20 : 16,
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: AppMotion.ultraSlow,
          delay: animationDelay ?? Duration.zero,
        )
        .slideY(begin: 0.3);
  }

  /// Builds the submit button - GradientButton style following color scheme
  Widget _buildSubmitButton() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: isDarkMode
            ? AppTheme.primaryGradient // Uses default theme gradient for dark
            : const LinearGradient(
                // Custom gradient for light theme
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFDFDFD), // off-white
                  Color(0xFFF5F5F7), // light cloud grey
                  Color(0xFFE0E0E2), // gentle cool grey
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
      child: TextButton(
        onPressed: _submitPatientDetails,
        style: TextButton.styleFrom(
          foregroundColor: isDarkMode
              ? Colors.white // Default for dark theme
              : const Color(0xFF0F172A), // Custom for light theme
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Save Patient Details',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward,
              size: 20,
              color: isDarkMode
                  ? Colors.white // Default for dark theme
                  : const Color(0xFF404040), // Custom for light theme
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: AppMotion.ultraSlow,
          delay: AppMotion.staggerDelay(9),
        )
        .slideY(begin: 0.5);
  }
}

/// Enum for gender selection
enum Gender {
  male,
  female,
}
