import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'patient_chat_screen.dart'; // For ChatSession and ViewType
import 'medication/medication_state.dart';
import 'medication/medication_data_provider.dart';

class MedicationScreen extends StatefulWidget {
  final ChatSession session;

  const MedicationScreen({
    super.key,
    required this.session,
  });

  @override
  State<MedicationScreen> createState() => _MedicationScreenState();
}

class _MedicationScreenState extends State<MedicationScreen> {
  final ScrollController _scrollController = ScrollController();
  
  // Production state management
  late MedicationDataProvider _dataProvider;
  MedicationState? _state;
  bool _isLoading = true;
  
  // Local UI state for slider (not persisted)
  double _sliderValue = 0.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _dataProvider = MedicationDataProvider(sessionName: widget.session.name);
    
    // Listen to state changes from provider
    _dataProvider.addListener(_onProviderStateChanged);
    
    _loadState();
  }
  
  void _onProviderStateChanged() {
    if (mounted) {
      setState(() {
        _state = _dataProvider.state;
      });
    }
  }
  
  Future<void> _loadState() async {
    try {
      final state = await _dataProvider.loadInitialState();
      if (mounted) {
        setState(() {
          _state = state;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = MedicationState.empty(sessionName: widget.session.name);
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _dataProvider.removeListener(_onProviderStateChanged);
    _scrollController.dispose();
    _dataProvider.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details, double maxWidth) {
    if (_state == null || !_state!.isSlideEnabled) return;
    setState(() {
      _isDragging = true;
      _sliderValue += details.delta.dx;
      _sliderValue = _sliderValue.clamp(0.0, maxWidth - 48); // 48 is thumb width
    });

    if (_sliderValue >= maxWidth - 56) { // Threshold
      _dataProvider.markDoseTaken();
      setState(() {
        _isDragging = false;
        _sliderValue = maxWidth - 48;
      });
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_state == null || _state!.isDoseTaken) return;
    setState(() {
      _isDragging = false;
      _sliderValue = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), // gray-50
      body: Stack(
        children: [
          Column(
            children: [
              // Header
              _buildHeader(),

              // Content Area - shows empty state or medication card
              Expanded(
                child: _isLoading 
                    ? const Center(child: CircularProgressIndicator())
                    : _state?.hasMedication == true
                        ? ListView(
                            controller: _scrollController,
                            padding: const EdgeInsets.only(top: 20, bottom: 100, left: 16, right: 16),
                            children: [
                              _buildMedicationCard(),
                            ],
                          )
                        : _buildEmptyState(),
              ),
            ],
          ),

          // Input Bar (System Placeholder)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildInputBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 12,
            bottom: 12,
            left: 16,
            right: 16,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.chevron_left, color: Colors.blue, size: 28),
                        Text(
                          "Chats",
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Adherence Ring
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Transform.rotate(
                          angle: -math.pi / 2,
                          child: SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              value: _state?.adherenceRingValue ?? 0.0,
                              strokeWidth: 3,
                              color: const Color(0xFF10B981),
                              backgroundColor: Colors.grey.shade200,
                            ),
                          ),
                        ),
                        Icon(CupertinoIcons.capsule_fill, color: Colors.grey.shade500, size: 16),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.session.name,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Streak Flame - only show if streak > 0
                          if (_state?.showStreakBadge == true)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Row(
                                children: [
                                  Icon(CupertinoIcons.flame_fill, size: 10, color: Colors.orange.shade500),
                                  const SizedBox(width: 2),
                                  Text(
                                    _state!.progress.streakDisplayText,
                                    style: GoogleFonts.inter(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      Text(
                        _state?.headerProgressText ?? 'No medications added yet',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(CupertinoIcons.info, color: Colors.grey.shade500, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Empty state when no medications are assigned
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.capsule,
                size: 40,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Medications Yet',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              MedicationState.emptyStateMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                height: 1.5,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationCard() {
    if (_state?.medication == null) return const SizedBox.shrink();
    final med = _state!.medication!;
    
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 24),
        width: 340,
        height: 400, // Fixed height for flip
        child: TweenAnimationBuilder(
          tween: Tween<double>(begin: 0, end: (_state?.isCardFlipped ?? false) ? 180 : 0),
          duration: const Duration(milliseconds: 600),
          builder: (context, double val, child) {
            final isFront = val < 90;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(val * math.pi / 180),
              child: isFront 
                  ? _buildCardFront(med) 
                  : Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(math.pi),
                      child: _buildCardBack(med),
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCardFront(MedicationData med) {
    final isDoseTaken = _state?.isDoseTaken ?? false;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pill Visual
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: isDoseTaken 
                      ? Icon(CupertinoIcons.check_mark_circled_solid, color: Colors.green.shade500, size: 40)
                          .animate().scale(duration: 400.ms, curve: Curves.elasticOut)
                      : Transform.rotate(
                          angle: 0.2,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: med.pillColor,
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                center: const Alignment(-0.3, -0.3),
                                colors: [Colors.white, Colors.grey.shade300],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
              // Supply Indicator
              Column(
                children: [
                  Container(
                    width: 12,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: 12,
                      height: (32 * med.inventory.fillPercentage).clamp(4.0, 32.0),
                      decoration: BoxDecoration(
                        color: med.inventory.status == InventoryStatus.ok 
                            ? Colors.green.shade400 
                            : med.inventory.status == InventoryStatus.low 
                                ? Colors.orange.shade400 
                                : Colors.red.shade400,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    med.inventory.displayText,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Info
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _state?.getScheduleLabel(context) ?? '',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade400,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                med.name,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDoseTaken ? Colors.green.shade600 : Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                med.dosageDisplayText,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),

          // Flip Button
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => _dataProvider.setCardFlipped(true),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(CupertinoIcons.info, size: 14, color: Colors.grey.shade500),
              ),
            ),
          ),

          // Slider
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(100),
            ),
            child: isDoseTaken 
                ? Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.check_mark, color: Colors.green.shade600, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _state?.doseTakenAt != null 
                              ? "Taken at ${TimeOfDay.fromDateTime(_state!.doseTakenAt!).format(context)}"
                              : "Taken",
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade600,
                          ),
                        ),
                      ],
                    ).animate().fade(),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          // Track Fill
                          Container(
                            width: 48 + _sliderValue,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                          // Text
                          Center(
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: _isDragging ? 0.0 : 1.0,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "SLIDE TO TAKE",
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade400,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(CupertinoIcons.chevron_right, size: 14, color: Colors.grey.shade400),
                                ],
                              ),
                            ),
                          ),
                          // Thumb
                          Positioned(
                            left: _sliderValue,
                            child: GestureDetector(
                              onHorizontalDragUpdate: (details) => _handleDragUpdate(details, constraints.maxWidth),
                              onHorizontalDragEnd: _handleDragEnd,
                              child: Container(
                                width: 48, // Reduced width for thumb
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(CupertinoIcons.capsule_fill, color: Colors.blue, size: 20),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack(MedicationData med) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Clinical Details",
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade900,
                ),
              ),
              GestureDetector(
                onTap: () => _dataProvider.setCardFlipped(false),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Icon(CupertinoIcons.arrow_counterclockwise, size: 16, color: Colors.grey.shade500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Doctor's Note - only show if available
          if (med.hasDoctorNotes) ...[
            Text(
              "DOCTOR'S NOTE",
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade400,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Text(
                "\"${med.doctorNotes}\"",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Side Effects - only show if available
          if (med.hasSideEffects) ...[
            Text(
              "POTENTIAL SIDE EFFECTS",
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade400,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
            spacing: 8,
            runSpacing: 8,
            children: med.sideEffects.map((effect) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                effect,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            )).toList(),
          ),
          ],
          
          // Show empty state message if no clinical details
          if (!med.hasDoctorNotes && !med.hasSideEffects)
            Expanded(
              child: Center(
                child: Text(
                  'No clinical details available',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
            ),

          const Spacer(),
          Divider(color: Colors.grey.shade200),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Refill ID - only show if available
              if (med.hasRefillId)
                Text(
                  "Refill ID: ${med.refillId}",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade400,
                  ),
                )
              else
                const SizedBox.shrink(),
              // View Insert - only show if URL available
              if (med.hasInsertUrl)
                GestureDetector(
                  onTap: () {
                    // TODO: Open insert URL
                  },
                  child: Text(
                    "View Full Insert",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade600,
                    ),
                  ),
                )
              else
                Text(
                  "Insert unavailable",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade300,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final canLogSideEffect = _state?.canLogSideEffect ?? false;
    final canContactDoctor = _state?.canContactDoctor ?? false;
    
    return Container(
      padding: EdgeInsets.only(
        left: 16, 
        right: 16, 
        bottom: MediaQuery.of(context).padding.bottom + 12,
        top: 12
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB), // gray-50
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildFooterButton(
              icon: Icons.sentiment_dissatisfied_rounded,
              iconColor: canLogSideEffect ? Colors.amber.shade600 : Colors.grey.shade400,
              label: "Log Side Effect",
              onTap: canLogSideEffect ? () {} : null,
              enabled: canLogSideEffect,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildFooterButton(
              icon: CupertinoIcons.phone_fill,
              iconColor: canContactDoctor ? Colors.blue.shade500 : Colors.grey.shade400,
              label: _state?.contactDoctorText ?? "Contact Doctor",
              onTap: canContactDoctor ? () {} : null,
              enabled: canContactDoctor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterButton({
    required IconData icon,
    required Color iconColor,
    required String label,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: enabled ? Colors.grey.shade700 : Colors.grey.shade400,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Data models moved to lib/screens/medication/medication_state.dart
