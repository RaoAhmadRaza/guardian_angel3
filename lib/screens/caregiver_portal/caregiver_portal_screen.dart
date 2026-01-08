import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/caregiver_portal_provider.dart';
import 'caregiver_dashboard_screen.dart';
import 'caregiver_patient_overview_screen.dart';
import 'caregiver_alerts_screen.dart';
import 'caregiver_tasks_screen.dart';
import 'caregiver_reports_screen.dart';
import 'caregiver_communication_screen.dart';
// Use the existing caregiver settings screen from the main app
import '../../caregiver_settings_screen.dart';
// Navigation and session management
import '../../welcome.dart';
import '../../services/session_service.dart';
import '../../services/onboarding_service.dart';

class CaregiverPortalScreen extends ConsumerStatefulWidget {
  const CaregiverPortalScreen({super.key});

  @override
  ConsumerState<CaregiverPortalScreen> createState() => _CaregiverPortalScreenState();
}

class _CaregiverPortalScreenState extends ConsumerState<CaregiverPortalScreen> {
  int _selectedIndex = 0;

  final List<Widget> _mainScreens = [
    const CaregiverDashboardScreen(),
    const CaregiverPatientOverviewScreen(),
    const CaregiverAlertsScreen(),
    const CaregiverCommunicationScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final portalState = ref.watch(caregiverPortalProvider);
    final alertCount = portalState.activeAlertCount;
    final unreadCount = portalState.unreadMessageCount;

    // Handle different loading/error states
    if (portalState.loadingStatus == CaregiverLoadingStatus.loading) {
      return _buildLoadingScreen();
    }

    if (portalState.loadingStatus == CaregiverLoadingStatus.notAuthenticated) {
      return _buildNotAuthenticatedScreen();
    }

    if (portalState.loadingStatus == CaregiverLoadingStatus.error) {
      return _buildErrorScreen(portalState.errorMessage ?? 'Unknown error');
    }

    if (portalState.loadingStatus == CaregiverLoadingStatus.noRelationship) {
      return _buildNoRelationshipScreen();
    }

    if (portalState.loadingStatus == CaregiverLoadingStatus.relationshipPending) {
      return _buildPendingRelationshipScreen();
    }

    if (portalState.loadingStatus == CaregiverLoadingStatus.relationshipRevoked) {
      return _buildRevokedAccessScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: _selectedIndex < 4
          ? IndexedStack(
              index: _selectedIndex,
              children: _mainScreens,
            )
          : _buildMoreMenu(portalState),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0x0D000000))),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xB3FFFFFF),
          selectedItemColor: const Color(0xFF007AFF),
          unselectedItemColor: const Color(0xFF8E8E93),
          selectedLabelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.home),
              activeIcon: Icon(CupertinoIcons.house_fill),
              label: 'Dashboard',
            ),
            const BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.person),
              activeIcon: Icon(CupertinoIcons.person_fill),
              label: 'Patient',
            ),
            BottomNavigationBarItem(
              icon: _buildBadgeIcon(CupertinoIcons.bell, alertCount),
              activeIcon: _buildBadgeIcon(CupertinoIcons.bell_fill, alertCount),
              label: 'Alerts',
            ),
            BottomNavigationBarItem(
              icon: _buildBadgeIcon(CupertinoIcons.chat_bubble_2, unreadCount),
              activeIcon: _buildBadgeIcon(CupertinoIcons.chat_bubble_2_fill, unreadCount),
              label: 'Chat',
            ),
            const BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.bars),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeIcon(IconData icon, int count) {
    if (count == 0) return Icon(icon);
    
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        Positioned(
          right: -6,
          top: -4,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Color(0xFFFF3B30),
              shape: BoxShape.circle,
            ),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            child: Text(
              count > 9 ? '9+' : count.toString(),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF007AFF)),
            const SizedBox(height: 24),
            Text(
              'Loading your care dashboard...',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF8E8E93),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotAuthenticatedScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Color(0xFFE5F1FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.lock_fill, color: Color(0xFF007AFF), size: 48),
              ),
              const SizedBox(height: 24),
              Text(
                'Sign In Required',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Please sign in to access your caregiver dashboard.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: const Color(0xFF8E8E93),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () async {
                  // Clear any stale session and navigate to welcome/login
                  await SessionService.instance.endSession();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const WelcomePage()),
                      (route) => false,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('Sign In', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen(String error) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF0F0),
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Color(0xFFFF3B30), size: 48),
              ),
              const SizedBox(height: 24),
              Text(
                'Something Went Wrong',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                error,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: const Color(0xFF8E8E93),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  ref.read(caregiverPortalProvider.notifier).refresh();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('Try Again', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoRelationshipScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F4FD),
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.person_2_fill, color: Color(0xFF007AFF), size: 48),
              ),
              const SizedBox(height: 24),
              Text(
                'No Patient Linked',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You don\'t have any patients linked to your account yet. Ask a patient to add you as their caregiver.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: const Color(0xFF8E8E93),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: () {
                  ref.read(caregiverPortalProvider.notifier).refresh();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF007AFF),
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  side: const BorderSide(color: Color(0xFF007AFF)),
                ),
                child: Text('Refresh', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
              // Debug mode: Reset session button
              if (kDebugMode) ...[
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () async {
                    // Reset session and onboarding
                    await SessionService.instance.resetSession();
                    await OnboardingService.instance.resetOnboarding();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const WelcomePage()),
                        (route) => false,
                      );
                    }
                  },
                  child: Text(
                    '🔧 Reset Session (Debug)',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFFF3B30),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingRelationshipScreen() {
    final portalState = ref.watch(caregiverPortalProvider);
    final patientName = portalState.linkedPatient?.name ?? 'Patient';
    
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF7ED),
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.clock_fill, color: Color(0xFFFF9500), size: 48),
              ),
              const SizedBox(height: 24),
              Text(
                'Awaiting Approval',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your caregiver request to $patientName is pending approval. You\'ll be notified once they accept.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: const Color(0xFF8E8E93),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: () {
                  ref.read(caregiverPortalProvider.notifier).refresh();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF007AFF),
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  side: const BorderSide(color: Color(0xFF007AFF)),
                ),
                child: Text('Check Status', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRevokedAccessScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF0F0),
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.xmark_shield_fill, color: Color(0xFFFF3B30), size: 48),
              ),
              const SizedBox(height: 24),
              Text(
                'Access Revoked',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your caregiver access has been revoked by the patient. Please contact them if you believe this is an error.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: const Color(0xFF8E8E93),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF007AFF),
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  side: const BorderSide(color: Color(0xFF007AFF)),
                ),
                child: Text('Go Back', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoreMenu(CaregiverPortalState portalState) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.95),
        elevation: 0,
        title: Text(
          'Menu',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFF2F2F7), height: 1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildMenuItem(
            icon: CupertinoIcons.list_bullet,
            color: Colors.orange,
            title: 'Tasks',
            onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (context) => const CaregiverTasksScreen())),
          ),
          const SizedBox(height: 16),
          _buildMenuItem(
            icon: CupertinoIcons.doc_text,
            color: Colors.blue,
            title: 'Reports',
            onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (context) => const CaregiverReportsScreen())),
          ),
          const SizedBox(height: 16),
          _buildMenuItem(
            icon: CupertinoIcons.settings,
            color: Colors.grey,
            title: 'Settings',
            onTap: () => Navigator.push(
              context, 
              CupertinoPageRoute(
                builder: (context) => CaregiverSettingsScreen(
                  caregiverName: portalState.caregiverName,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color color,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const Spacer(),
            const Icon(CupertinoIcons.chevron_right, color: Color(0xFFC7C7CC), size: 20),
          ],
        ),
      ),
    );
  }
}
