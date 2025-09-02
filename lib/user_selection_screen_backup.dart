import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'colors.dart';
import 'providers/theme_provider.dart';
import 'patient_age_selection_screen.dart';
import 'guardian_details_screen.dart';

enum UserRole { patient, guardian, developer }

class UserSelectionScreen extends StatefulWidget {
  const UserSelectionScreen({super.key});

  @override
  State<UserSelectionScreen> createState() => _UserSelectionScreenState();
}

class _UserSelectionScreenState extends State<UserSelectionScreen> {
  UserRole? _selectedRole;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Define role cards data
    final roleCards = [
      {
        'role': UserRole.patient,
        'label': 'Patient',
        'image': 'images/paitient.png',
      },
      {
        'role': UserRole.guardian,
        'label': 'Guardian/Caregiver',
        'image': 'images/caregiver.png',
      }
    ];

    Widget buildRoleCard({
      required UserRole role,
      required String label,
      required String image,
    }) {
      final bool isActive = _selectedRole == role;

      return GestureDetector(
        onTap: () {
          setState(() => _selectedRole = role);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: double.infinity,
          height: 200,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: isActive
                    ? Colors.black.withOpacity(0.2)
                    : Colors.black.withOpacity(0.08),
                blurRadius: isActive ? 20 : 10,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: isActive
                  ? Border.all(color: Colors.white.withOpacity(0.3), width: 2)
                  : Border.all(color: Colors.transparent, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Image placeholder with gradient background
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    gradient: isActive
                        ? AppTheme.primaryGradient
                        : const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFBDBDBD),
                              Color(0xFFE0E0E0),
                            ],
                          ),
                    borderRadius: BorderRadius.circular(65),
                    border: Border.all(
                      color: isActive
                          ? Colors.transparent
                          : Colors.grey.withOpacity(0.4),
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(65),
                    child: Image.asset(
                      image,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Label
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? Colors.white
                        : isDarkMode
                            ? AppTheme.primaryText
                            : AppTheme.lightPrimaryText,
                  ),
                ),
              ],
            ),
          ),
        ),
      )
          .animate()
          .fadeIn(
            duration: 600.ms,
            delay:
                (roleCards.indexWhere((card) => card['role'] == role) * 200).ms,
          )
          .slideX(
            begin: 0.3,
            duration: 600.ms,
            delay:
                (roleCards.indexWhere((card) => card['role'] == role) * 200).ms,
          );
    }

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
              // Header with theme toggle
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Theme toggle button
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(
                          ThemeProvider.instance.themeIcon,
                          color: Colors.white,
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

              const SizedBox(height: 20),

              // Title Section
              Column(
                children: [
                  Text(
                    'Select User Type',
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ).animate().fadeIn(duration: 800.ms).slideY(begin: -0.3),
                  const SizedBox(height: 8),
                  Container(
                    width: 120,
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFF6B9D),
                          Color(0xFFFFA726),
                        ],
                      ),
                    ),
                  ).animate().scaleX(duration: 800.ms, delay: 400.ms),
                ],
              ),

              const SizedBox(height: 40),

              // Role Cards in Column
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: roleCards.map((card) {
                      return buildRoleCard(
                        role: card['role'] as UserRole,
                        label: card['label'] as String,
                        image: card['image'] as String,
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Bottom Navigation
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: _selectedRole != null
                          ? const LinearGradient(
                              colors: [Color(0xFF9B59B6), Color(0xFF8E44AD)],
                            )
                          : LinearGradient(
                              colors: [
                                Colors.grey.withOpacity(0.3),
                                Colors.grey.withOpacity(0.2),
                              ],
                            ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: _selectedRole != null
                          ? [
                              BoxShadow(
                                color: const Color(0xFF9B59B6).withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    child: IconButton(
                      onPressed: _selectedRole != null
                          ? () {
                              // Navigate based on selected role
                              if (_selectedRole == UserRole.patient) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const PatientAgeSelectionScreen(),
                                  ),
                                );
                              } else if (_selectedRole == UserRole.guardian) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const GuardianDetailsScreen(),
                                  ),
                                );
                              }
                              debugPrint('Selected role: $_selectedRole');
                            }
                          : null,
                      icon: const Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                        size: 24,
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
