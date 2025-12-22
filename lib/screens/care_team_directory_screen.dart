import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'patient_chat_screen.dart'; // Import for ChatSession and ViewType
import 'caregiver_chat_screen.dart';
import 'doctor_chat_screen.dart';

class CareTeamDirectoryScreen extends StatefulWidget {
  final List<ChatSession> sessions;

  const CareTeamDirectoryScreen({
    super.key,
    required this.sessions,
  });

  @override
  State<CareTeamDirectoryScreen> createState() => _CareTeamDirectoryScreenState();
}

class _CareTeamDirectoryScreenState extends State<CareTeamDirectoryScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  
  bool _isScrolled = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final isScrolled = _scrollController.offset > 40;
    if (isScrolled != _isScrolled) {
      setState(() {
        _isScrolled = isScrolled;
      });
    }
  }

  List<ChatSession> get _filteredSessions {
    final careTeam = widget.sessions.where((s) => 
      s.type == ViewType.CAREGIVER || s.type == ViewType.DOCTOR
    ).toList();

    if (_searchQuery.isEmpty) return careTeam;

    return careTeam.where((member) => 
      member.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      (member.subtitle != null && member.subtitle!.toLowerCase().contains(_searchQuery.toLowerCase()))
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final doctors = _filteredSessions.where((s) => s.type == ViewType.DOCTOR).toList();
    final caregivers = _filteredSessions.where((s) => s.type == ViewType.CAREGIVER).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Stack(
        children: [
          // Scrollable Content
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Header Space (to allow content to scroll behind the sticky header)
              const SliverToBoxAdapter(child: SizedBox(height: 100)), // Approx header height + padding

              // Page Title
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Care Team",
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Your trusted support circle",
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Search Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300.withOpacity(0.2)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _searchQuery = value),
                      style: GoogleFonts.inter(fontSize: 15, color: Colors.black),
                      decoration: InputDecoration(
                        hintText: "Search by name or role...",
                        hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
                        prefixIcon: Icon(CupertinoIcons.search, size: 16, color: Colors.grey.shade400),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        isDense: true,
                      ),
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Medical Professionals Group
              if (doctors.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Text(
                      "MEDICAL PROFESSIONALS",
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade400,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: List.generate(doctors.length, (index) {
                          final member = doctors[index];
                          final isLast = index == doctors.length - 1;
                          return _buildMemberItem(member, isLast, true);
                        }),
                      ),
                    ),
                  ),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Family & Caregivers Group
              if (caregivers.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Text(
                      "FAMILY & CAREGIVERS",
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade400,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: List.generate(caregivers.length, (index) {
                          final member = caregivers[index];
                          final isLast = index == caregivers.length - 1;
                          return _buildMemberItem(member, isLast, false);
                        }),
                      ),
                    ),
                  ),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 80)), // Bottom padding
            ],
          ),

          // Sticky Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: _isScrolled ? 20 : 0,
                  sigmaY: _isScrolled ? 20 : 0,
                ),
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 12,
                    bottom: 12,
                    left: 16,
                    right: 16,
                  ),
                  decoration: BoxDecoration(
                    color: _isScrolled ? Colors.white.withOpacity(0.8) : Colors.transparent,
                    border: Border(
                      bottom: BorderSide(
                        color: _isScrolled ? Colors.grey.shade200 : Colors.transparent,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Row(
                          children: [
                            const Icon(CupertinoIcons.chevron_left, color: Colors.blue, size: 24),
                            Text(
                              "Dashboard",
                              style: GoogleFonts.inter(
                                fontSize: 17,
                                color: Colors.blue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: _isScrolled ? 1.0 : 0.0,
                        child: Text(
                          "Care Team",
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF111827),
                          ),
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.more_horiz, color: Colors.grey.shade600, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberItem(ChatSession member, bool isLast, bool isDoctor) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (isDoctor) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => DoctorChatScreen(session: member),
              ),
            );
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => CaregiverChatScreen(session: member),
              ),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: isLast ? null : Border(
              bottom: BorderSide(color: Colors.grey.shade100),
            ),
          ),
          child: Row(
            children: [
              // Avatar
              Stack(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isDoctor ? Colors.blue.shade50 : Colors.blue.shade100,
                      shape: BoxShape.circle,
                      border: isDoctor ? Border.all(color: Colors.blue.shade100) : null,
                      image: (isDoctor && member.imageUrl != null) 
                          ? DecorationImage(image: NetworkImage(member.imageUrl!), fit: BoxFit.cover)
                          : null,
                    ),
                    child: (isDoctor && member.imageUrl != null) 
                        ? null 
                        : Center(
                            child: isDoctor 
                                ? const Icon(CupertinoIcons.heart_fill, color: Colors.blue, size: 24) // Stethoscope replacement
                                : Text(
                                    member.name.isNotEmpty ? member.name[0] : "?",
                                    style: GoogleFonts.inter(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade600,
                                    ),
                                  ),
                          ),
                  ),
                  if (member.isOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  if (member.unreadCount > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            member.unreadCount.toString(),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          member.name,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        if (isDoctor) ...[
                          const SizedBox(width: 6),
                          const Icon(CupertinoIcons.checkmark_shield_fill, color: Colors.blue, size: 14),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      member.subtitle ?? (isDoctor ? 'Specialist' : 'Family'),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),

              // Actions
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      CupertinoIcons.phone_fill, 
                      size: 16, 
                      color: isDoctor ? Colors.blue.shade600 : Colors.grey.shade400
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isDoctor ? CupertinoIcons.video_camera_solid : CupertinoIcons.chat_bubble_fill, 
                      size: 16, 
                      color: isDoctor ? Colors.blue.shade600 : Colors.grey.shade400
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
