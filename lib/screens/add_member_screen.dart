import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'patient_chat_screen.dart'; // For ViewType

class AddMemberScreen extends StatefulWidget {
  const AddMemberScreen({super.key});

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  final TextEditingController _nameController = TextEditingController();
  
  // Roles definition
  final List<Map<String, dynamic>> _roles = [
    {'type': ViewType.CAREGIVER, 'label': 'Family', 'icon': CupertinoIcons.heart_fill, 'color': Colors.blue.shade500},
    {'type': ViewType.DOCTOR, 'label': 'Doctor', 'icon': CupertinoIcons.heart_circle_fill, 'color': Colors.indigo.shade500}, // Stethoscope approx
    {'type': ViewType.COMMUNITY, 'label': 'Neighbor', 'icon': CupertinoIcons.person_3_fill, 'color': Colors.orange.shade500},
    {'type': ViewType.AI_COMPANION, 'label': 'Assistant', 'icon': CupertinoIcons.shield_fill, 'color': Colors.purple.shade500},
  ];

  late Map<String, dynamic> _selectedRole;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedRole = _roles[0];
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (_nameController.text.trim().isEmpty) return;

    setState(() => _isSubmitting = true);

    // Simulate processing
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        Navigator.of(context).pop();
        // In a real app, we would pass the new member back
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Backdrop
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              color: Colors.black.withOpacity(0.4),
            ),
          ).animate().fade(duration: 300.ms),

          // Bottom Sheet
          Align(
            alignment: Alignment.bottomCenter,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    border: Border(top: BorderSide(color: Colors.white.withOpacity(0.5))),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 48),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Grabber Handle
                          Container(
                            width: 40,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.of(context).pop(),
                                child: Text(
                                  "Cancel",
                                  style: GoogleFonts.inter(
                                    fontSize: 17,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Text(
                                "New Member",
                                style: GoogleFonts.inter(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF111827),
                                ),
                              ),
                              GestureDetector(
                                onTap: _nameController.text.trim().isNotEmpty && !_isSubmitting ? _handleSubmit : null,
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
                                  opacity: _nameController.text.trim().isNotEmpty && !_isSubmitting ? 1.0 : 0.3,
                                  child: Text(
                                    _isSubmitting ? "Adding..." : "Add",
                                    style: GoogleFonts.inter(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // Profile Creation Section
                          Column(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 112,
                                height: 112,
                                decoration: BoxDecoration(
                                  color: _selectedRole['color'],
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: (_selectedRole['color'] as Color).withOpacity(0.4),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Icon(
                                    _selectedRole['icon'],
                                    color: Colors.white,
                                    size: 48,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 0,
                                      offset: Offset(0, 0),
                                      spreadRadius: 0,
                                      blurStyle: BlurStyle.inner
                                    )
                                  ]
                                ),
                                padding: const EdgeInsets.all(4),
                                child: TextField(
                                  controller: _nameController,
                                  onChanged: (val) => setState(() {}),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF111827),
                                  ),
                                  decoration: InputDecoration(
                                    hintText: "Member Name",
                                    hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                  ),
                                  autofocus: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // Role Selector
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 4, bottom: 12),
                                child: Text(
                                  "CHOOSE ROLE",
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade400,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: _roles.map((role) {
                                  final isSelected = _selectedRole['type'] == role['type'];
                                  return GestureDetector(
                                    onTap: () => setState(() => _selectedRole = role),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                      decoration: BoxDecoration(
                                        color: isSelected ? Colors.white : Colors.transparent,
                                        borderRadius: BorderRadius.circular(16),
                                        border: isSelected ? Border.all(color: Colors.grey.shade100) : null,
                                        boxShadow: isSelected ? [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          )
                                        ] : null,
                                      ),
                                      child: Column(
                                        children: [
                                          AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: isSelected ? role['color'] : Colors.grey.shade100,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Icon(
                                                role['icon'],
                                                color: isSelected ? Colors.white : Colors.grey.shade400,
                                                size: 24,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            role['label'],
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isSelected ? const Color(0xFF111827) : Colors.grey.shade400,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 40),

                          // Verification Note
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.blue.shade100.withOpacity(0.5)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(CupertinoIcons.shield_fill, color: Colors.blue.shade500, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "This member will be able to message you and see your recent health status if shared.",
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.blue.shade700,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ).animate().slideY(begin: 1, end: 0, duration: 500.ms, curve: Curves.easeOutQuart),
          ),
        ],
      ),
    );
  }
}
