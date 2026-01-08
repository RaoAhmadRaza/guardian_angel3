/// DoctorsScreen - Patient's view of their linked doctors
/// 
/// Allows patients to:
/// - View their linked doctors
/// - Generate invite codes for new doctors
/// - Revoke doctor access
/// - Initiate chat with doctors
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../relationships/models/doctor_relationship_model.dart';
import '../relationships/services/doctor_relationship_service.dart';
import '../chat/services/doctor_chat_service.dart';
import '../chat/screens/patient_doctor_chat_screen.dart';

class DoctorsScreen extends StatefulWidget {
  const DoctorsScreen({super.key});

  @override
  State<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  List<DoctorRelationshipModel> _relationships = [];
  Map<String, DoctorInfo> _doctorInfoCache = {};
  bool _isLoading = true;
  String? _pendingInviteCode;
  bool _isGeneratingCode = false;

  @override
  void initState() {
    super.initState();
    _loadRelationships();
  }

  Future<void> _loadRelationships() async {
    setState(() => _isLoading = true);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final result = await DoctorRelationshipService.instance.getRelationshipsForUser(uid);
      
      if (result.success && result.data != null) {
        // Filter to only show relationships where current user is patient
        final patientRelationships = result.data!.where((r) => r.patientId == uid).toList();
        
        // Load doctor info for active relationships
        for (final rel in patientRelationships) {
          if (rel.status == DoctorRelationshipStatus.active && rel.doctorId != null) {
            await _loadDoctorInfo(rel.doctorId!);
          }
        }

        // Check for pending invites
        final pending = patientRelationships.where((r) => r.status == DoctorRelationshipStatus.pending).toList();
        
        if (mounted) {
          setState(() {
            _relationships = patientRelationships;
            _pendingInviteCode = pending.isNotEmpty ? pending.first.inviteCode : null;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('[DoctorsScreen] Error loading relationships: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDoctorInfo(String doctorId) async {
    if (_doctorInfoCache.containsKey(doctorId)) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('doctors')
          .doc(doctorId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _doctorInfoCache[doctorId] = DoctorInfo(
          uid: doctorId,
          name: data['full_name'] as String? ?? data['name'] as String? ?? 'Doctor',
          specialization: data['specialization'] as String?,
          clinicName: data['clinic_or_hospital_name'] as String?,
          phoneNumber: data['phone_number'] as String?,
        );
      } else {
        // Try users collection as fallback
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(doctorId)
            .get();
        
        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data()!;
          _doctorInfoCache[doctorId] = DoctorInfo(
            uid: doctorId,
            name: data['display_name'] as String? ?? 'Doctor',
            specialization: null,
            clinicName: null,
            phoneNumber: null,
          );
        }
      }
    } catch (e) {
      debugPrint('[DoctorsScreen] Error loading doctor info: $e');
    }
  }

  Future<void> _generateInviteCode() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isGeneratingCode = true);

    try {
      final result = await DoctorRelationshipService.instance.createPatientDoctorInvite(
        patientId: uid,
        permissions: ['chat', 'view_vitals', 'view_records', 'notes'],
      );

      if (result.success && result.data != null) {
        setState(() {
          _pendingInviteCode = result.data!.inviteCode;
          _relationships.add(result.data!);
        });
        _showInviteCodeDialog(result.data!.inviteCode);
      } else {
        _showError(result.errorMessage ?? 'Failed to generate invite code');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      setState(() => _isGeneratingCode = false);
    }
  }

  void _showInviteCodeDialog(String code) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'Doctor Invite Code',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Share this code with your doctor:',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    code,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      color: const Color(0xFF007AFF),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Color(0xFF007AFF)),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied to clipboard')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'This code expires in 7 days',
              style: TextStyle(
                fontSize: 13,
                color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done', style: TextStyle(color: Color(0xFF007AFF))),
          ),
        ],
      ),
    );
  }

  Future<void> _revokeAccess(DoctorRelationshipModel relationship) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Access?'),
        content: const Text('This will remove the doctor\'s access to your health data. You can re-invite them later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revoke', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final result = await DoctorRelationshipService.instance.revokeRelationship(
      relationshipId: relationship.id,
      requesterId: uid,
    );

    if (result.success) {
      _loadRelationships();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Doctor access revoked')),
        );
      }
    } else {
      _showError(result.errorMessage ?? 'Failed to revoke access');
    }
  }

  Future<void> _openChat(DoctorRelationshipModel relationship) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || relationship.doctorId == null) return;

    final doctorInfo = _doctorInfoCache[relationship.doctorId];
    
    // Get or create chat thread
    final threadResult = await DoctorChatService.instance.getOrCreateDoctorThreadForRelationship(
      relationshipId: relationship.id,
      patientId: relationship.patientId,
      doctorId: relationship.doctorId!,
    );

    if (threadResult.success && threadResult.data != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PatientDoctorChatScreen(
            threadId: threadResult.data!.id,
            otherUserName: doctorInfo?.name ?? 'Doctor',
            specialty: doctorInfo?.specialization,
            organization: doctorInfo?.clinicName,
          ),
        ),
      );
    } else {
      _showError(threadResult.errorMessage ?? 'Could not open chat');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : const Color(0xFFF2F2F7),
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            backgroundColor: isDarkMode ? Colors.black : const Color(0xFFF2F2F7),
            title: Text(
              'My Doctors',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: isDarkMode ? Colors.white : Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: _isGeneratingCode 
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(CupertinoIcons.add_circled, size: 28),
                color: const Color(0xFF007AFF),
                onPressed: _isGeneratingCode ? null : _generateInviteCode,
              ),
            ],
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pending invite section
                    if (_pendingInviteCode != null) ...[
                      _buildPendingInviteSection(isDarkMode),
                      const SizedBox(height: 24),
                    ],

                    // Active doctors section
                    _buildActiveDoctorsSection(isDarkMode),

                    const SizedBox(height: 24),
                    Text(
                      'Doctors can view your health data, vitals, and communicate with you through the app.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPendingInviteSection(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PENDING INVITE',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.schedule, color: Color(0xFFFF9500), size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Waiting for doctor',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Code: $_pendingInviteCode',
                      style: TextStyle(
                        fontSize: 15,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, color: Color(0xFF007AFF)),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _pendingInviteCode!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code copied')),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveDoctorsSection(bool isDarkMode) {
    final activeDoctors = _relationships
        .where((r) => r.status == DoctorRelationshipStatus.active && r.doctorId != null)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LINKED DOCTORS',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        if (activeDoctors.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    CupertinoIcons.person_2,
                    size: 48,
                    color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No doctors linked yet',
                    style: TextStyle(
                      fontSize: 17,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to generate an invite code',
                    style: TextStyle(
                      fontSize: 15,
                      color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                for (int i = 0; i < activeDoctors.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: 76,
                      color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                    ),
                  _buildDoctorTile(activeDoctors[i], isDarkMode),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDoctorTile(DoctorRelationshipModel relationship, bool isDarkMode) {
    final doctorInfo = _doctorInfoCache[relationship.doctorId];
    final name = doctorInfo?.name ?? 'Doctor';
    final specialty = doctorInfo?.specialization ?? 'Healthcare Provider';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFF34C759).withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            name.substring(0, 1).toUpperCase(),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Color(0xFF34C759),
            ),
          ),
        ),
      ),
      title: Text(
        name,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      ),
      subtitle: Text(
        specialty,
        style: TextStyle(
          fontSize: 15,
          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Chat button
          IconButton(
            icon: const Icon(CupertinoIcons.chat_bubble_fill, color: Color(0xFF007AFF)),
            onPressed: () => _openChat(relationship),
          ),
          // More options
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
            onSelected: (value) {
              if (value == 'revoke') {
                _revokeAccess(relationship);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'revoke',
                child: Row(
                  children: [
                    Icon(Icons.block, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Revoke Access', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Doctor info helper class
class DoctorInfo {
  final String uid;
  final String name;
  final String? specialization;
  final String? clinicName;
  final String? phoneNumber;

  DoctorInfo({
    required this.uid,
    required this.name,
    this.specialization,
    this.clinicName,
    this.phoneNumber,
  });
}
