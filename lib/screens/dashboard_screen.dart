import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFDFD),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          CupertinoIcons.chevron_left,
                          color: Color(0xFF0F172A),
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Weekly Insights',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 80),
                children: [
                  // Weekly Adherence Hero Card
                  Container(
                    height: 280, // Approximate height based on content
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(48),
                      border: Border.all(color: const Color(0xFF1E293B)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Background Icon
                        Positioned(
                          top: 32,
                          right: 32,
                          child: Opacity(
                            opacity: 0.2,
                            child: Icon(
                              Icons.trending_up,
                              color: Colors.white,
                              size: 100,
                            ),
                          ),
                        ),
                        // Content
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'OVERALL ADHERENCE',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white.withOpacity(0.5),
                                  letterSpacing: 2.4, // tracking-[0.2em]
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '94%',
                                style: GoogleFonts.inter(
                                  fontSize: 72, // 7xl roughly
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(height: 24),
                              RichText(
                                text: TextSpan(
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white.withOpacity(0.8),
                                    height: 1.6, // leading-relaxed
                                  ),
                                  children: [
                                    const TextSpan(text: 'Great job, Jacob! You only missed '),
                                    TextSpan(
                                      text: '2 doses',
                                      style: const TextStyle(
                                        decoration: TextDecoration.underline,
                                        decorationColor: Color(0xFF34D399),
                                        decorationThickness: 4,
                                      ),
                                    ),
                                    const TextSpan(text: ' this month.'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Stat Grid
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Total Doses',
                          value: '48',
                          icon: CupertinoIcons.calendar,
                          iconColor: const Color(0xFF2563EB),
                          backgroundColor: const Color(0xFFEFF6FF),
                          borderColor: const Color(0xFFDBEAFE),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _StatCard(
                          label: 'Missed Doses',
                          value: '2',
                          icon: CupertinoIcons.exclamationmark_circle,
                          iconColor: const Color(0xFFDC2626),
                          backgroundColor: const Color(0xFFFEF2F2),
                          borderColor: const Color(0xFFFEE2E2),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Health Milestones
                  Text(
                    'Health Milestones',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 24),

                  const _InsightItem(
                    title: '7 Day Streak!',
                    description: 'You have taken all your medicine on time for the last week. Keep it up!',
                    emoji: '⭐',
                    isActive: true,
                  ),
                  const SizedBox(height: 16),
                  const _InsightItem(
                    title: 'Routine Master',
                    description: 'Morning doses are always taken before 10:00 AM. Excellent routine!',
                    emoji: '☀️',
                    isActive: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color borderColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF1F5F9)), // gray-100
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                icon,
                color: iconColor,
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF64748B),
              letterSpacing: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _InsightItem extends StatelessWidget {
  final String title;
  final String description;
  final String emoji;
  final bool isActive;

  const _InsightItem({
    required this.title,
    required this.description,
    required this.emoji,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isActive ? Colors.white : const Color(0xFFF9FAFB), // gray-50
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isActive ? const Color(0xFF0F172A) : Colors.transparent,
          width: 2,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF1F5F9)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 30),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF475569),
                    height: 1.6, // leading-relaxed
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
