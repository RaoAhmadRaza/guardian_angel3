import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'colors.dart';
import 'providers/theme_provider.dart';

class GuardianDetailsScreen extends StatefulWidget {
  const GuardianDetailsScreen({super.key});

  @override
  State<GuardianDetailsScreen> createState() => _GuardianDetailsScreenState();
}

class _GuardianDetailsScreenState extends State<GuardianDetailsScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController relationController = TextEditingController();
  final TextEditingController patientNameController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    relationController.dispose();
    patientNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    // iOS-standard responsive dimensions
    final horizontalPadding = isTablet ? 32.0 : 20.0;
    final headerPadding = isTablet ? 24.0 : 16.0;
    final titleFontSize = isTablet ? 32.0 : 28.0;
    final subtitleFontSize = isTablet ? 18.0 : 16.0;
    final buttonHeight = isTablet ? 56.0 : 50.0;
    final fieldSpacing = isTablet ? 24.0 : 16.0;
    final themeButtonSize = isTablet ? 24.0 : 20.0;

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
              // Header with theme toggle - iOS style
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: headerPadding,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Action Button (Theme Toggle) - Following color scheme
                    Container(
                      width: isTablet ? 48 : 44,
                      height: isTablet ? 48 : 44,
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
                          size: themeButtonSize,
                        ),
                        onPressed: () async {
                          await ThemeProvider.instance.toggleTheme();
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Title Section - iOS typography hierarchy
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  children: [
                    Text(
                      'Guardian Details',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w700,
                        color: isDarkMode
                            ? AppTheme.primaryText
                            : AppTheme.lightPrimaryText,
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                    ).animate().fadeIn(duration: 800.ms).slideY(begin: -0.3),
                    SizedBox(height: isTablet ? 12 : 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isTablet ? 600 : double.infinity,
                      ),
                      child: Text(
                        'Please provide your information to set up care monitoring',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: subtitleFontSize,
                          fontWeight: FontWeight.w400,
                          color: isDarkMode
                              ? AppTheme.secondaryText
                              : AppTheme.lightSecondaryText,
                          height: 1.4,
                          letterSpacing: 0,
                        ),
                      ).animate().fadeIn(duration: 800.ms, delay: 200.ms),
                    ),
                    SizedBox(height: isTablet ? 24 : 16),
                    // Monochromatic accent line
                    Container(
                      width: isTablet ? 120 : 100,
                      height: isTablet ? 4 : 3,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(isTablet ? 2 : 1.5),
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
              ),

              SizedBox(height: isTablet ? 40 : 32),

              // Form Section - Phone Input Container style
              Expanded(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surface
                        .withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: isDarkMode
                            ? Colors.black.withOpacity(
                                0.4) // Enhanced primary shadow for dark theme
                            : Theme.of(context)
                                .shadowColor
                                .withValues(alpha: 0.1),
                        blurRadius: isDarkMode ? 24 : 16,
                        offset: Offset(0, isDarkMode ? 12 : 4),
                      ),
                      if (isDarkMode)
                        // Additional shadow layer for dark theme depth
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                      if (!isDarkMode)
                        BoxShadow(
                          color: const Color(0xFF475569).withOpacity(0.04),
                          blurRadius: 32,
                          offset: const Offset(0, 8),
                        ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isTablet ? 32 : 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isTablet ? 600 : double.infinity,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Guardian Name
                            _buildInputField(
                              controller: nameController,
                              label: 'Your Full Name',
                              icon: Icons.person_outline,
                              hint: 'e.g., John Doe',
                              isTablet: isTablet,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your full name';
                                }
                                return null;
                              },
                            ).animate().slideX(
                                begin: -0.3, duration: 600.ms, delay: 600.ms),

                            SizedBox(height: fieldSpacing),

                            // Phone Number
                            _buildInputField(
                              controller: phoneController,
                              label: 'Phone Number',
                              hint: 'e.g., +1 234 567 890',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              isTablet: isTablet,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your phone number';
                                }
                                return null;
                              },
                            ).animate().slideX(
                                begin: -0.3, duration: 600.ms, delay: 700.ms),

                            SizedBox(height: fieldSpacing),

                            // Email
                            _buildInputField(
                              controller: emailController,
                              label: 'Email Address',
                              hint: 'e.g., john.doe@example.com',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              isTablet: isTablet,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your email address';
                                }
                                if (!value.contains('@')) {
                                  return 'Please enter a valid email address';
                                }
                                return null;
                              },
                            ).animate().slideX(
                                begin: -0.3, duration: 600.ms, delay: 800.ms),

                            SizedBox(height: fieldSpacing),

                            // Relation to Patient
                            _buildInputField(
                              controller: relationController,
                              label: 'Relation to Patient',
                              icon: Icons.family_restroom_outlined,
                              hint: 'e.g., Parent, Spouse, Child, etc.',
                              isTablet: isTablet,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please specify your relation to the patient';
                                }
                                return null;
                              },
                            ).animate().slideX(
                                begin: -0.3, duration: 600.ms, delay: 900.ms),

                            SizedBox(height: fieldSpacing),

                            // Patient Name
                            _buildInputField(
                              controller: patientNameController,
                              label: 'Patient\'s Name',
                              hint: 'e.g., Jane Doe',
                              icon: Icons.local_hospital_outlined,
                              isTablet: isTablet,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter the patient\'s name';
                                }
                                return null;
                              },
                            ).animate().slideX(
                                begin: -0.3, duration: 600.ms, delay: 1000.ms),

                            SizedBox(height: isTablet ? 40 : 32),

                            // Continue Button - GradientButton style following color scheme
                            Container(
                              width: double.infinity,
                              height: buttonHeight,
                              decoration: BoxDecoration(
                                gradient: isDarkMode
                                    ? AppTheme
                                        .primaryGradient // Uses default theme gradient for dark
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
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDarkMode
                                        ? Colors.white.withOpacity(0.1)
                                        : const Color(0xFF64748B)
                                            .withOpacity(0.2),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: TextButton(
                                onPressed: () {
                                  if (_formKey.currentState!.validate()) {
                                    // Handle form submission
                                    debugPrint(
                                        'Guardian Name: ${nameController.text}');
                                    debugPrint(
                                        'Phone: ${phoneController.text}');
                                    debugPrint(
                                        'Email: ${emailController.text}');
                                    debugPrint(
                                        'Relation: ${relationController.text}');
                                    debugPrint(
                                        'Patient Name: ${patientNameController.text}');
                                    // TODO: Save data and navigate to next screen
                                  }
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: isDarkMode
                                      ? Colors.white // Default for dark theme
                                      : const Color(
                                          0xFF0F172A), // Custom for light theme
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Continue',
                                      style: GoogleFonts.inter(
                                        fontSize: isTablet ? 18 : 16,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.1,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.arrow_forward,
                                      size: isTablet ? 20 : 18,
                                      color: isDarkMode
                                          ? Colors
                                              .white // Default for dark theme
                                          : const Color(
                                              0xFF404040), // Custom for light theme
                                    ),
                                  ],
                                ),
                              ),
                            ).animate().slideY(
                                begin: 0.5, duration: 800.ms, delay: 1100.ms),

                            SizedBox(height: isTablet ? 24 : 16),
                          ],
                        ),
                      ),
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

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? hint,
    String? Function(String?)? validator,
    required bool isTablet,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final labelFontSize = isTablet ? 16.0 : 14.0;
    final inputFontSize = isTablet ? 18.0 : 16.0;
    final iconSize = isTablet ? 24.0 : 22.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // iOS-style field label
        Padding(
          padding: EdgeInsets.only(
            left: 4.0,
            bottom: isTablet ? 8.0 : 6.0,
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: labelFontSize,
              fontWeight: FontWeight.w600,
              color: isDarkMode
                  ? AppTheme.secondaryText
                  : AppTheme.lightSecondaryText,
              letterSpacing: 0.1,
            ),
          ),
        ),
        // Input field container following phone input container style
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
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
            keyboardType: keyboardType,
            validator: validator,
            style: GoogleFonts.inter(
              fontSize: inputFontSize,
              fontWeight: FontWeight.w400,
              color:
                  isDarkMode ? AppTheme.primaryText : AppTheme.lightPrimaryText,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(
                fontSize: inputFontSize,
                fontWeight: FontWeight.w400,
                color: isDarkMode
                    ? AppTheme.placeholderText
                    : AppTheme.lightPlaceholderText,
              ),
              prefixIcon: Icon(
                icon,
                size: iconSize,
                color: isDarkMode
                    ? AppTheme.tertiaryText
                    : AppTheme.lightTertiaryText,
              ),
              filled: true,
              fillColor:
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDarkMode
                      ? AppTheme.borderColor
                      : AppTheme.lightBorderColor,
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDarkMode
                      ? AppTheme.borderColor
                      : AppTheme.lightBorderColor,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDarkMode
                      ? AppTheme.primaryText
                      : const Color(0xFF64748B),
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDarkMode ? AppTheme.errorColor : AppTheme.errorColor,
                  width: 2,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDarkMode ? AppTheme.errorColor : AppTheme.errorColor,
                  width: 2,
                ),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: isTablet ? 20 : 16,
                vertical: isTablet ? 18 : 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
