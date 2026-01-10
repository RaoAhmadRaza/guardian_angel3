import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import 'profile_sheet.dart';
import 'medication_detail_screen.dart';
import 'history_screen.dart';
import 'dashboard_screen.dart';
import 'drip_alert_screen.dart';
import 'add_medication_modal.dart';
import 'calendar_overlay.dart';
import '../services/patient_service.dart';
import '../services/medication_service.dart';
import '../models/medication_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  String _activeTab = 'home';
  bool _isSOSActive = false;
  
  // Critical Issue #6: Load patient name from service instead of hardcoding
  String _patientName = '';
  String? _patientImageUrl;
  bool _isLoadingPatient = true;
  
  // Critical Issue #7: Load medications from MedicationService instead of hardcoding
  List<MedicationModel> _medications = [];
  bool _isLoadingMedications = true;
  
  // Issue #22: Date selector state
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadPatientData();
    _loadMedications();
  }
  
  /// Load patient data from PatientService (Critical Issue #6)
  Future<void> _loadPatientData() async {
    try {
      final patientName = await PatientService.instance.getPatientName();
      final patientData = await PatientService.instance.getPatientData();
      
      if (mounted) {
        setState(() {
          _patientName = patientName.isNotEmpty && patientName != 'Patient' 
              ? patientName 
              : 'Patient';
          // Use profile image from storage if available, otherwise null for fallback
          _patientImageUrl = patientData['profileImageUrl'] as String?;
          _isLoadingPatient = false;
        });
      }
    } catch (e) {
      debugPrint('[PatientHomeScreen] Error loading patient data: $e');
      if (mounted) {
        setState(() {
          _patientName = 'Patient';
          _isLoadingPatient = false;
        });
      }
    }
  }
  
  /// Load medications from MedicationService (Critical Issue #7)
  Future<void> _loadMedications() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        if (mounted) setState(() => _isLoadingMedications = false);
        return;
      }
      
      final medications = await MedicationService.instance.getMedications(uid);
      if (mounted) {
        setState(() {
          _medications = medications;
          _isLoadingMedications = false;
        });
      }
    } catch (e) {
      debugPrint('[PatientHomeScreen] Error loading medications: $e');
      if (mounted) {
        setState(() {
          _medications = [];
          _isLoadingMedications = false;
        });
      }
    }
  }
  
  /// Issue #22: Helper to check if two dates are the same day
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
  
  /// Issue #22: Load medications for a specific date (placeholder for future filtering)
  void _loadMedicationsForDate(DateTime date) {
    // For now, just reload medications
    // In the future, this could filter by schedule date
    _loadMedications();
  }
  
  /// Issue #28: Pull-to-refresh handler
  Future<void> _refreshData() async {
    await Future.wait([
      _loadPatientData(),
      _loadMedications(),
    ]);
  }
  
  /// Issue #29: Open add medication modal
  void _showAddMedicationModal() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) => AddMedicationModal(
          onClose: () => Navigator.of(context).pop(),
          onSave: _addMedication,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
      ),
    );
  }
  
  /// Issue #22: Get display label for selected date
  String _getDateLabel() {
    final now = DateTime.now();
    if (_isSameDay(_selectedDate, now)) {
      return 'Today';
    } else if (_isSameDay(_selectedDate, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    } else if (_isSameDay(_selectedDate, now.add(const Duration(days: 1)))) {
      return 'Tomorrow';
    } else {
      // Format as "Mon, Jan 15"
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${days[_selectedDate.weekday - 1]}, ${months[_selectedDate.month - 1]} ${_selectedDate.day}';
    }
  }

  void _addMedication(Map<String, dynamic> newMed) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    // Create medication model
    final medication = MedicationModel.create(
      patientId: uid,
      name: newMed['name'] as String? ?? 'Unknown',
      dose: newMed['dose'] as String? ?? '',
      time: newMed['time'] as String? ?? '08:00',
      type: newMed['type'] as String? ?? 'pill',
    );
    
    // Save to service (Critical Issue #7: Persist medications)
    final success = await MedicationService.instance.saveMedication(medication);
    if (success) {
      await _loadMedications(); // Reload from service
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save medication')),
        );
      }
    }
  }

  bool get _hasActiveInfusion => _medications.any((m) => m.type.toLowerCase() == 'iv infusion' || m.type.toLowerCase() == 'infusion');
  
  /// Build patient initials widget as fallback for profile image
  Widget _buildPatientInitials() {
    final initials = _patientName.isNotEmpty && _patientName != 'Patient'
        ? _patientName.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join().toUpperCase()
        : 'P';
    
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  void _handleSOS() {
    setState(() => _isSOSActive = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _isSOSActive = false);
    });
    // Alert logic would go here
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFDFD),
      body: Stack(
        children: [
          Column(
            children: [
              // 1. Global Header Pattern
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          PageRouteBuilder(
                            opaque: false,
                            pageBuilder: (context, animation, secondaryAnimation) => ProfileSheet(
                              onClose: () => Navigator.of(context).pop(),
                            ),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              color: const Color(0xFFF5F5F7),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            // Critical Issue #6: Use patient image from service or show initials
                            child: _patientImageUrl != null && _patientImageUrl!.isNotEmpty
                                ? ClipOval(
                                    child: Image.network(
                                      _patientImageUrl!,
                                      fit: BoxFit.cover,
                                      width: 50,
                                      height: 50,
                                      errorBuilder: (context, error, stackTrace) => _buildPatientInitials(),
                                    ),
                                  )
                                : _buildPatientInitials(),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    CupertinoIcons.shield_fill,
                                    size: 12,
                                    color: Color(0xFF059669),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'FAMILY LINKED',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF059669),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                // Critical Issue #6: Use patient name from service
                                _isLoadingPatient ? '...' : _patientName,
                                style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0F172A),
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _handleSOS,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isSOSActive
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFFFEF2F2),
                              border: Border.all(
                                color: _isSOSActive
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFFFEE2E2),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              CupertinoIcons.phone_fill,
                              size: 22,
                              color: _isSOSActive
                                  ? Colors.white
                                  : const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (context) => const DashboardScreen(),
                              ),
                            );
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              CupertinoIcons.chart_bar_fill,
                              size: 22,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              CupertinoIcons.xmark,
                              size: 22,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Date Selector Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          PageRouteBuilder(
                            opaque: false,
                            pageBuilder: (context, animation, secondaryAnimation) => CalendarOverlay(
                              onClose: () => Navigator.of(context).pop(),
                            ),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                          ),
                        );
                      }, // onCalendar
                      child: Row(
                        children: [
                          Text(
                            _getDateLabel(),
                            style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            CupertinoIcons.chevron_down,
                            size: 20,
                            color: Color(0xFF2563EB),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Issue #22: Functional DateSelector component
                    SizedBox(
                      height: 80,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: 7,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          // Calculate date for each slot (centered on today)
                          final today = DateTime.now();
                          final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
                          final date = startOfWeek.add(Duration(days: index));
                          final isSelected = _isSameDay(date, _selectedDate);
                          final isToday = _isSameDay(date, today);
                          final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                          
                          return GestureDetector(
                            onTap: () {
                              setState(() => _selectedDate = date);
                              // Optionally reload data for selected date
                              _loadMedicationsForDate(date);
                            },
                            child: Container(
                              width: 60,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF0F172A)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF0F172A)
                                      : isToday
                                          ? const Color(0xFF2563EB)
                                          : const Color(0xFFE2E8F0),
                                  width: isToday && !isSelected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    dayNames[index],
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? Colors.white.withOpacity(0.6)
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${date.day}',
                                    style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 7. Section Container for Medications
              Expanded(
                // Issue #28: Pull-to-refresh
                child: RefreshIndicator(
                  onRefresh: _refreshData,
                  color: const Color(0xFF2563EB),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 128),
                  children: [
                    if (_hasActiveInfusion) ...[
                      _buildDripAlertCard(),
                      const SizedBox(height: 24),
                    ],

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Schedule',
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '${_medications.where((m) => !m.isTaken).length} remaining',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Show loading state or empty state
                    if (_isLoadingMedications)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CupertinoActivityIndicator(),
                        ),
                      )
                    else if (_medications.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(
                                CupertinoIcons.capsule,
                                size: 48,
                                color: Color(0xFF94A3B8),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No medications scheduled',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Keep track of your medication schedule',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                              // Issue #29: Add CTA button
                              const SizedBox(height: 16),
                              GestureDetector(
                                onTap: () => _showAddMedicationModal(),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(CupertinoIcons.add, color: Colors.white, size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Add Medication',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._medications.map((med) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildMedicationCardFromModel(med),
                      )),

                    const SizedBox(height: 16),
                    
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 2,
                          style: BorderStyle.solid, // Dashed border not native, using solid for now or custom painter
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            CupertinoIcons.exclamationmark_circle,
                            size: 32,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Caregivers have been notified \nof your progress today.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                ),  // Close RefreshIndicator
              ),
            ],
          ),

          // Floating Bottom Nav
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Container(
              height: 84,
              padding: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTabButton(
                        icon: CupertinoIcons.square_grid_2x2,
                        label: 'Home',
                        isActive: _activeTab == 'home',
                        onTap: () => setState(() => _activeTab = 'home'),
                      ),
                      const SizedBox(width: 64), // Spacer for the floating button
                      _buildTabButton(
                        icon: CupertinoIcons.clock,
                        label: 'Track',
                        isActive: _activeTab == 'history',
                        onTap: () {
                          setState(() => _activeTab = 'history');
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (context) => const HistoryScreen(),
                            ),
                          ).then((_) => setState(() => _activeTab = 'home'));
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Floating Add Button (Positioned separately to avoid clipping)
          Positioned(
            bottom: 66, // Calculated to match the previous visual position
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      opaque: false,
                      pageBuilder: (context, animation, secondaryAnimation) => AddMedicationModal(
                        onClose: () => Navigator.of(context).pop(),
                        onSave: _addMedication,
                      ),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        const begin = Offset(0.0, 1.0);
                        const end = Offset.zero;
                        const curve = Curves.easeOutCubic;
                        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                        var offsetAnimation = animation.drive(tween);
                        return SlideTransition(position: offsetAnimation, child: child);
                      },
                    ),
                  );
                },
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 24,
            color: isActive ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isActive ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationCard(Map<String, dynamic> med) {
    final bool isLowStock = (med['currentStock'] ?? 100) <= (med['lowStockThreshold'] ?? 0);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => MedicationDetailScreen(medication: med),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: med['color'] ?? const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                med['type'] == 'infusion' || med['type'] == 'IV Infusion'
                    ? CupertinoIcons.drop_fill
                    : CupertinoIcons.capsule_fill,
                color: med['iconColor'] ?? const Color(0xFF2563EB),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    med['name'],
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${med['dose']} • ${med['time']}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            if (isLowStock)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 1.0, end: 0.5),
                  duration: const Duration(milliseconds: 1000),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: const Icon(
                        CupertinoIcons.exclamationmark_triangle_fill,
                        color: Color(0xFFEF4444),
                        size: 24,
                      ),
                    );
                  },
                  onEnd: () {}, // Loop logic would be more complex, keeping simple for now
                ),
              ),
            if (med['isTaken'])
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.checkmark_alt,
                  color: Color(0xFF16A34A),
                  size: 20,
                ),
              )
            else
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDripAlertCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => const DripAlertScreen(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                CupertinoIcons.drop_fill,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active Infusion',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Saline Drip • 45m remaining',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'LIVE',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Build medication card from MedicationModel (Critical Issue #7)
  Widget _buildMedicationCardFromModel(MedicationModel med) {
    final bool isLowStock = med.isLowStock;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => MedicationDetailScreen(
              medicationModel: med,
              medication: {
                'id': med.id,
                'name': med.name,
                'dose': med.dose,
                'time': med.time,
                'type': med.type,
                'isTaken': med.isTaken,
                'currentStock': med.currentStock,
                'lowStockThreshold': med.lowStockThreshold,
                'color': med.displayColor,
                'iconColor': med.iconColor,
              },
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: med.displayColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                med.type.toLowerCase() == 'infusion' || med.type.toLowerCase() == 'iv infusion'
                    ? CupertinoIcons.drop_fill
                    : CupertinoIcons.capsule_fill,
                color: med.iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    med.name,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${med.dose} • ${med.time}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            if (isLowStock)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 1.0, end: 0.5),
                  duration: const Duration(milliseconds: 1000),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: const Icon(
                        CupertinoIcons.exclamationmark_triangle_fill,
                        color: Color(0xFFEF4444),
                        size: 24,
                      ),
                    );
                  },
                  onEnd: () {},
                ),
              ),
            if (med.isTaken)
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.checkmark_alt,
                  color: Color(0xFF16A34A),
                  size: 20,
                ),
              )
            else
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
              ),
          ],
        ),
      ),
    );
  }

}
