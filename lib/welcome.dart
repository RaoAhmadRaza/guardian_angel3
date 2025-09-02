import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'services/onboarding_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'theme/app_theme.dart' as theme;
import 'widgets.dart';
import 'providers/theme_provider.dart';
import 'login_screen.dart';
import 'signup.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool _showResetButton = kDebugMode;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: isDarkMode
                  ? theme.AppTheme.getPrimaryGradient(context)
                  : theme.AppTheme.lightPrimaryGradient,
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  // Theme toggle button
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.2)
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.3)
                                : const Color(0xFFE0E0E0),
                            width: 1,
                          ),
                          boxShadow: isDarkMode
                              ? [
                                  // Dark theme: Subtle glow for theme toggle
                                  BoxShadow(
                                    color: const Color(0xFFF8F9FA)
                                        .withOpacity(0.05),
                                    blurRadius: 12,
                                    offset: const Offset(0, 2),
                                    spreadRadius: 0,
                                  ),
                                ]
                              : [
                                  // Light theme: Soft professional shadow
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
                            print('Theme button pressed!'); // Debug print
                            try {
                              await ThemeProvider.instance.toggleTheme();
                              print(
                                  'Theme toggled to: ${ThemeProvider.instance.themeMode}'); // Debug print
                            } catch (e) {
                              print('Error toggling theme: $e'); // Debug print
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  // Theme toggle button (temporarily commented out)
                  /*
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const ThemeToggleButton(
                    size: 20,
                    iconColor: Colors.white,
                    padding: EdgeInsets.all(12),
                  ),
                ),
              ),
              */

                  // Main content
                  SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 60),

                          // Logo section with hero animation
                          Hero(
                            tag: 'logo',
                            child: Container(
                              width: size.width * 0.6,
                              height: size.width * 0.6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDarkMode
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.white,
                                border: Border.all(
                                  color: isDarkMode
                                      ? Colors.white.withOpacity(0.2)
                                      : const Color(0xFFE0E0E0),
                                  width: 2,
                                ),
                                boxShadow: isDarkMode
                                    ? [
                                        // Dark theme: Elegant light glow
                                        BoxShadow(
                                          color: const Color(0xFFF8F9FA)
                                              .withOpacity(0.1),
                                          blurRadius: 990,
                                          offset: const Offset(0, 10),
                                          spreadRadius: 0,
                                        ),
                                        BoxShadow(
                                          color: const Color(0xFF000000)
                                              .withOpacity(0.4),
                                          blurRadius: 990,
                                          offset: const Offset(0, 4),
                                          spreadRadius: 0,
                                        ),
                                      ]
                                    : [
                                        // Light theme: Premium healthcare depth using new theme system
                                        BoxShadow(
                                          color: const Color(0xFF475569)
                                              .withOpacity(0.08),
                                          blurRadius: 25,
                                          offset: const Offset(0, 1),
                                          spreadRadius: 0,
                                        ),
                                        BoxShadow(
                                          color: const Color(0xFF475569)
                                              .withOpacity(0.05),
                                          blurRadius: 45,
                                          offset: const Offset(0, 10),
                                          spreadRadius: 0,
                                        ),
                                      ],
                              ),
                              child: Stack(
                                children: [
                                  // Inner glow effect for light theme
                                  if (!isDarkMode)
                                    Positioned.fill(
                                      child: Container(
                                        margin: const EdgeInsets.all(30),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            // Inner glow effect
                                            BoxShadow(
                                              color: const Color(0xFF404040)
                                                  .withOpacity(0.06),
                                              blurRadius: 25,
                                              offset: const Offset(0, 0),
                                              spreadRadius: 8,
                                            ),
                                            // Subtle secondary inner glow
                                            BoxShadow(
                                              color: const Color(0xFF6B7280)
                                                  .withOpacity(0.04),
                                              blurRadius: 40,
                                              offset: const Offset(0, 0),
                                              spreadRadius: 12,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  // Logo image with separate shadow
                                  Center(
                                    child: Container(
                                      padding: const EdgeInsets.all(30),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: isDarkMode
                                            ? [
                                                // Dark theme: Logo shadow - subtle light glow
                                                BoxShadow(
                                                  color: const Color(0xFFF8F9FA)
                                                      .withOpacity(0.08),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 1),
                                                  spreadRadius: 0,
                                                ),
                                                // Subtle depth shadow
                                                BoxShadow(
                                                  color: const Color(0xFF000000)
                                                      .withOpacity(0.15),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 1),
                                                  spreadRadius: 0,
                                                ),
                                              ]
                                            : [
                                                // Light theme: Logo shadow - soft gray
                                                BoxShadow(
                                                  color: const Color(0xFF475569)
                                                      .withOpacity(0.08),
                                                  blurRadius: 90,
                                                  offset: const Offset(0, 1),
                                                  spreadRadius: 0,
                                                ),
                                                // Ambient shadow
                                                BoxShadow(
                                                  color: const Color(0xFF64748B)
                                                      .withOpacity(0.04),
                                                  blurRadius: 18,
                                                  offset: const Offset(0, 2),
                                                  spreadRadius: 0,
                                                ),
                                              ],
                                      ),
                                      child: isDarkMode
                                          ? Image.asset(
                                              'images/logo.png',
                                              fit: BoxFit.contain,
                                            )
                                          : Image.asset(
                                              'images/dark_logo.png',
                                              fit: BoxFit.contain,
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ).animate().scale(
                                delay: 200.ms,
                                duration: 800.ms,
                                curve: Curves.elasticOut,
                              ),

                          const SizedBox(height: 40),

                          // Title section
                          Column(
                            children: [
                              Text(
                                'Guardian Angel',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode
                                      ? Colors.white
                                      : const Color(0xFF2D2D2D),
                                  height: 1.2,
                                ),
                              ).animate().slideY(
                                    delay: 400.ms,
                                    duration: 600.ms,
                                    begin: 1,
                                    curve: Curves.easeOut,
                                  ),
                              const SizedBox(height: 8),
                              Text(
                                'Watching over when you can\'t',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: isDarkMode
                                      ? Colors.white.withOpacity(0.9)
                                      : const Color(0xFF404040),
                                  height: 1.4,
                                ),
                              ).animate().slideY(
                                    delay: 500.ms,
                                    duration: 600.ms,
                                    begin: 1,
                                    curve: Curves.easeOut,
                                  ),
                            ],
                          ),

                          const SizedBox(height: 32),

                          // Subtitle description
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Caring from a distance, made effortless. Health alerts, smart safety, and constant support for your loved ones.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: isDarkMode
                                    ? Colors.white.withOpacity(0.8)
                                    : const Color(0xFF666666),
                                height: 1.6,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ).animate().fadeIn(
                                delay: 600.ms,
                                duration: 800.ms,
                              ),

                          const SizedBox(height: 60),

                          // Action buttons section
                          Column(
                            children: [
                              // Primary CTA button
                              GradientButton(
                                text: 'Join Now',
                                width: double.infinity,
                                textColor: isDarkMode
                                    ? const Color(
                                        0xFF2D2D2D) // Dark text on light gradient in dark mode
                                    : const Color(
                                        0xFF0F172A), // Very dark text on light gradient in light mode
                                gradient: isDarkMode
                                    ? theme.AppTheme.getAccentGradient(context)
                                    : LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          const Color(0xFFFDFDFD), // off-white
                                          const Color(
                                              0xFFF5F5F7), // light cloud grey
                                          const Color(
                                              0xFFE0E0E2), // gentle cool grey
                                        ],
                                      ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (context, animation,
                                              secondaryAnimation) =>
                                          const SignUP(),
                                      transitionsBuilder: (context, animation,
                                          secondaryAnimation, child) {
                                        const begin = Offset(1.0, 0.0);
                                        const end = Offset.zero;
                                        const curve = Curves.easeInOut;

                                        var tween = Tween(
                                                begin: begin, end: end)
                                            .chain(CurveTween(curve: curve));

                                        return SlideTransition(
                                          position: animation.drive(tween),
                                          child: child,
                                        );
                                      },
                                      transitionDuration:
                                          const Duration(milliseconds: 300),
                                    ),
                                  );
                                },
                              ).animate().slideY(
                                    delay: 700.ms,
                                    duration: 600.ms,
                                    begin: 1,
                                    curve: Curves.easeOut,
                                  ),

                              const SizedBox(height: 20),

                              // Login section
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Already a member?',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: isDarkMode
                                            ? Colors.white.withOpacity(0.8)
                                            : const Color(0xFF666666),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          PageRouteBuilder(
                                            pageBuilder: (context, animation,
                                                    secondaryAnimation) =>
                                                const TimeLuxLoginScreen(),
                                            transitionsBuilder: (context,
                                                animation,
                                                secondaryAnimation,
                                                child) {
                                              const begin = Offset(1.0, 0.0);
                                              const end = Offset.zero;
                                              const curve = Curves.easeInOut;

                                              var tween = Tween(
                                                      begin: begin, end: end)
                                                  .chain(
                                                      CurveTween(curve: curve));

                                              return SlideTransition(
                                                position:
                                                    animation.drive(tween),
                                                child: child,
                                              );
                                            },
                                            transitionDuration: const Duration(
                                                milliseconds: 300),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isDarkMode
                                              ? Colors.white.withOpacity(0.2)
                                              : const Color(0xFFF5F5F5),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isDarkMode
                                                ? Colors.white.withOpacity(0.3)
                                                : const Color(0xFFE0E0E0),
                                          ),
                                          boxShadow: isDarkMode
                                              ? [
                                                  // Dark theme: Subtle button glow
                                                  BoxShadow(
                                                    color:
                                                        const Color(0xFFF8F9FA)
                                                            .withOpacity(0.05),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                    spreadRadius: 0,
                                                  ),
                                                ]
                                              : [
                                                  // Light theme: Professional button shadow
                                                  BoxShadow(
                                                    color:
                                                        const Color(0xFF475569)
                                                            .withOpacity(0.06),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                    spreadRadius: 0,
                                                  ),
                                                ],
                                        ),
                                        child: Text(
                                          'Log in',
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: isDarkMode
                                                ? Colors.white
                                                : const Color(0xFF404040),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ).animate().slideY(
                                    delay: 800.ms,
                                    duration: 600.ms,
                                    begin: 1,
                                    curve: Curves.easeOut,
                                  ),
                            ],
                          ),
                        ], // Close the main Column
                      ),
                    ),
                  ),
                  // Debug-only reset onboarding button at the bottom
                  if (_showResetButton)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 24,
                      child: Center(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDarkMode
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFF404040),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          onPressed: () async {
                            await OnboardingService.instance.resetOnboarding();
                            setState(() {
                              _showResetButton = false;
                            });
                            // Optionally show a snackbar
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Onboarding reset! Restart the app to see onboarding screens.')),
                            );
                          },
                          child: const Text('Reset Onboarding (Debug)'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
