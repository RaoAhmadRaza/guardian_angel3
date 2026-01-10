/// SOS History Screen - Displays past SOS events from Firestore.
///
/// Shows history of SOS events for:
/// - Patients: Their own events
/// - Caregivers: Events for their linked patients
/// - Doctors: Events for their linked patients
library;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../relationships/services/relationship_service.dart';
import '../../relationships/services/doctor_relationship_service.dart';
import '../../relationships/models/relationship_model.dart';
import '../../relationships/models/doctor_relationship_model.dart';

/// Screen for viewing SOS event history.
class SosHistoryScreen extends StatefulWidget {
  final String? patientId; // Optional - if null, shows for current user/all linked patients
  final String? patientName;

  const SosHistoryScreen({
    super.key,
    this.patientId,
    this.patientName,
  });

  @override
  State<SosHistoryScreen> createState() => _SosHistoryScreenState();
}

class _SosHistoryScreenState extends State<SosHistoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _sosEvents = [];
  List<String> _linkedPatientIds = [];
  String? _currentUid;

  @override
  void initState() {
    super.initState();
    _currentUid = FirebaseAuth.instance.currentUser?.uid;
    _loadSosHistory();
  }

  Future<void> _loadSosHistory() async {
    setState(() => _isLoading = true);

    try {
      // Determine which patient IDs to query
      final patientIds = <String>[];
      
      if (widget.patientId != null) {
        // Specific patient requested
        patientIds.add(widget.patientId!);
      } else if (_currentUid != null) {
        // Current user - could be patient, caregiver, or doctor
        patientIds.add(_currentUid!);
        
        // If caregiver, get linked patient IDs
        final caregiverRels = await RelationshipService.instance.getRelationshipsForUser(_currentUid!);
        if (caregiverRels.success && caregiverRels.data != null) {
          for (final rel in caregiverRels.data!) {
            if (rel.caregiverId == _currentUid && rel.status == RelationshipStatus.active) {
              patientIds.add(rel.patientId);
            }
          }
        }
        
        // If doctor, get linked patient IDs
        final doctorRels = await DoctorRelationshipService.instance.getRelationshipsForUser(_currentUid!);
        if (doctorRels.success && doctorRels.data != null) {
          for (final rel in doctorRels.data!) {
            if (rel.doctorId == _currentUid && rel.status == DoctorRelationshipStatus.active) {
              patientIds.add(rel.patientId);
            }
          }
        }
      }
      
      _linkedPatientIds = patientIds.toSet().toList();
      
      if (_linkedPatientIds.isEmpty) {
        setState(() {
          _sosEvents = [];
          _isLoading = false;
        });
        return;
      }

      // Query SOS sessions from Firestore
      final firestore = FirebaseFirestore.instance;
      final allEvents = <Map<String, dynamic>>[];
      
      // Firestore whereIn has a limit of 10, so batch if needed
      for (var i = 0; i < _linkedPatientIds.length; i += 10) {
        final batch = _linkedPatientIds.sublist(
          i, 
          i + 10 > _linkedPatientIds.length ? _linkedPatientIds.length : i + 10
        );
        
        final snapshot = await firestore
            .collection('sos_sessions')
            .where('patient_uid', whereIn: batch)
            .orderBy('created_at', descending: true)
            .limit(50)
            .get();
        
        for (final doc in snapshot.docs) {
          allEvents.add({
            'id': doc.id,
            ...doc.data(),
          });
        }
      }
      
      // Sort all events by date
      allEvents.sort((a, b) {
        final aTime = _parseTimestamp(a['created_at']);
        final bTime = _parseTimestamp(b['created_at']);
        return bTime.compareTo(aTime);
      });

      setState(() {
        _sosEvents = allEvents;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[SosHistoryScreen] Failed to load SOS history: $e');
      setState(() {
        _sosEvents = [];
        _isLoading = false;
      });
    }
  }

  DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SOS History',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            if (widget.patientName != null)
              Text(
                widget.patientName!,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF3B82F6)),
            onPressed: _loadSosHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sosEvents.isEmpty
              ? _buildEmptyState()
              : _buildEventList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Icon(
              Icons.check_circle_outline,
              size: 40,
              color: Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No SOS Events',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No emergency events have been recorded',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sosEvents.length,
      itemBuilder: (context, index) {
        final event = _sosEvents[index];
        return _buildEventCard(event);
      },
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final state = event['state'] as String? ?? 'unknown';
    final patientName = event['patient_name'] as String? ?? 'Patient';
    final createdAt = _parseTimestamp(event['created_at']);
    final resolvedAt = event['resolved_at'] != null 
        ? _parseTimestamp(event['resolved_at']) 
        : null;
    final location = event['location'] as Map<String, dynamic>?;
    final notifiedCaregivers = (event['notified_caregivers'] as List?)?.length ?? 0;
    final notifiedDoctors = (event['notified_doctors'] as List?)?.length ?? 0;
    final resolvedBy = event['resolved_by'] as String?;
    
    // Determine status color
    final isActive = state == 'active' || state == 'escalated';
    final statusColor = isActive 
        ? const Color(0xFFF43F5E) 
        : const Color(0xFF10B981);
    final statusBgColor = isActive 
        ? const Color(0xFFFEE2E2) 
        : const Color(0xFFDCFCE7);
    final statusText = _getStatusText(state);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? const Color(0xFFFECACA) : const Color(0xFFF1F5F9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isActive 
                  ? [const Color(0xFFF43F5E), const Color(0xFFE11D48)]
                  : [const Color(0xFF10B981), const Color(0xFF059669)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isActive ? Icons.warning : Icons.check,
            color: Colors.white,
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Text(
              patientName,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusBgColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                statusText.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            DateFormat('MMM d, yyyy • HH:mm').format(createdAt),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ),
        children: [
          const Divider(color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),
          
          // Duration
          if (resolvedAt != null) ...[
            _buildDetailRow(
              'Duration',
              _formatDuration(resolvedAt.difference(createdAt)),
              Icons.timer,
            ),
            const SizedBox(height: 8),
          ],
          
          // Location
          if (location != null && location['latitude'] != null) ...[
            _buildDetailRow(
              'Location',
              '${location['latitude'].toStringAsFixed(4)}, ${location['longitude'].toStringAsFixed(4)}',
              Icons.location_on,
            ),
            const SizedBox(height: 8),
          ],
          
          // Notified
          _buildDetailRow(
            'Notified',
            '$notifiedCaregivers caregivers, $notifiedDoctors doctors',
            Icons.notifications,
          ),
          
          // Resolved by
          if (resolvedBy != null) ...[
            const SizedBox(height: 8),
            _buildDetailRow(
              'Resolved by',
              resolvedBy,
              Icons.person,
            ),
          ],
          
          // Resolution reason
          if (event['resolution_reason'] != null) ...[
            const SizedBox(height: 8),
            _buildDetailRow(
              'Reason',
              event['resolution_reason'] as String,
              Icons.note,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  String _getStatusText(String state) {
    switch (state) {
      case 'active':
        return 'Active';
      case 'escalated':
        return 'Escalated';
      case 'resolved':
        return 'Resolved';
      case 'cancelled':
        return 'Cancelled';
      case 'false_alarm':
        return 'False Alarm';
      default:
        return state;
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds}s';
    }
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    }
    return '${duration.inHours}h ${duration.inMinutes % 60}m';
  }
}
