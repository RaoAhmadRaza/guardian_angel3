import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/session_service.dart';
import '../services/patient_service.dart';

class ProfileSheet extends StatefulWidget {
  final VoidCallback onClose;

  const ProfileSheet({super.key, required this.onClose});

  @override
  State<ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<ProfileSheet> {
  String _patientName = 'Patient';
  String? _patientImageUrl;
  bool _isLoading = true;
  bool _isLoggingOut = false;
  
  @override
  void initState() {
    super.initState();
    _loadPatientData();
  }
  
  Future<void> _loadPatientData() async {
    try {
      final patientName = await PatientService.instance.getPatientName();
      if (mounted) {
        setState(() {
          _patientName = patientName.isNotEmpty && patientName != 'Patient' 
              ? patientName 
              : 'Patient';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  /// Issue #19: Implement logout with confirmation
  Future<void> _handleLogout() async {
    // Show confirmation dialog
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out? You\'ll need to sign in again to access your health data.'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    setState(() => _isLoggingOut = true);
    
    try {
      // End session
      await SessionService.instance.endSession();
      
      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();
      
      if (mounted) {
        widget.onClose();
        // Navigate to login screen
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoggingOut = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to sign out. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Semantic Overlay
        GestureDetector(
          onTap: widget.onClose,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Container(
              color: const Color(0xFF0F172A).withOpacity(0.4),
            ),
          ),
        ),

        // Sheet Surface
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.92,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(48)),
              border: Border(
                top: BorderSide(color: Color(0xFFE2E8F0)),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 24,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                GestureDetector(
                  onTap: widget.onClose,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    color: Colors.transparent, // Hit target
                    child: Center(
                      child: Container(
                        width: 48,
                        height: 6,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ),

                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                    child: Column(
                      children: [
                        // Profile Card
                        Stack(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(40),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // Avatar
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        width: 112,
                                        height: 112,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(38),
                                          border: Border.all(
                                            color: const Color(0xFFF5F5F7),
                                            width: 4,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.1),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                          color: const Color(0xFFF1F5F9),
                                        ),
                                        child: Center(
                                          child: Text(
                                            _patientName.isNotEmpty 
                                                ? _patientName.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join()
                                                : 'P',
                                            style: GoogleFonts.inter(
                                              fontSize: 40,
                                              fontWeight: FontWeight.w900,
                                              color: const Color(0xFF64748B),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: -8,
                                        right: -8,
                                        child: Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0F172A),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.1),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            CupertinoIcons.shield_fill,
                                            size: 18,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 20),
                                  
                                  _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : Text(
                                        _patientName,
                                        style: GoogleFonts.inter(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF0F172A),
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                  
                                  const SizedBox(height: 4),
                                  
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5F5F7),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Text(
                                      'PATIENT ID: #84920',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF64748B),
                                        letterSpacing: 1.5, // tracking-widest
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Verified Badge
                            Positioned(
                              top: 16,
                              right: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: const Color(0xFFD1FAE5)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF059669),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'VERIFIED',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF059669),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // List Items
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
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
                              _buildListItem(
                                icon: FontAwesomeIcons.userGroup,
                                label: 'Caregivers',
                                value: 'Emily Miller (Primary)',
                                isLast: false,
                              ),
                              _buildListItem(
                                icon: FontAwesomeIcons.stethoscope,
                                label: 'Linked Doctors',
                                value: 'Dr. Aris Thorne, MD',
                                isLast: false,
                              ),
                              _buildListItem(
                                icon: FontAwesomeIcons.language,
                                label: 'Primary Language',
                                value: 'English (United States)',
                                isLast: false,
                              ),
                              _buildListItem(
                                icon: CupertinoIcons.phone_fill,
                                label: 'Emergency Contact',
                                value: '+1 (555) 012-3456',
                                isLast: true,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Logout Button
                        Container(
                          width: double.infinity,
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFFFEE2E2)),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _isLoggingOut ? null : _handleLogout,
                              borderRadius: BorderRadius.circular(24),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_isLoggingOut)
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFFDC2626),
                                      ),
                                    )
                                  else
                                    const Icon(
                                      Icons.logout, // LogOut
                                      size: 20,
                                      color: Color(0xFFDC2626),
                                    ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _isLoggingOut ? 'SIGNING OUT...' : 'LOG OUT',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFFDC2626),
                                      letterSpacing: 1.5, // tracking-widest
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        Opacity(
                          opacity: 0.5,
                          child: Text(
                            'DATA IS END-TO-END ENCRYPTED',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF64748B),
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListItem({
    required IconData icon,
    required String label,
    required String value,
    required bool isLast,
  }) {
    return Container(
      decoration: !isLast
          ? const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFF1F5F9)),
              ),
            )
          : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: isLast 
              ? const BorderRadius.vertical(bottom: Radius.circular(32))
              : (label == 'Caregivers' ? const BorderRadius.vertical(top: Radius.circular(32)) : BorderRadius.zero),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Icon(
                        icon,
                        size: 18,
                        color: const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF94A3B8),
                            letterSpacing: 2.0, // tracking-[0.2em]
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          value,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Icon(
                  CupertinoIcons.chevron_right,
                  size: 18,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
