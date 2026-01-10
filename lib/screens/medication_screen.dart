import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'patient_chat_screen.dart'; // For ChatSession and ViewType
import 'medication/medication_state.dart';
import 'medication/medication_data_provider.dart';

// --- THEME COLORS ---

class _ScreenColors {
  final bool isDark;

  _ScreenColors(this.isDark);

  static _ScreenColors of(BuildContext context) {
    return _ScreenColors(Theme.of(context).brightness == Brightness.dark);
  }

  // 1. Foundation
  Color get bgPrimary => isDark ? const Color(0xFF0F0F0F) : const Color(0xFFFDFDFD);
  Color get bgSecondary => isDark ? const Color(0xFFFFFFFF).withOpacity(0.05) : const Color(0xFFF5F5F7);
  Color get surfacePrimary => isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
  Color get surfaceSecondary => isDark ? const Color(0xFF2C2C2E) : const Color(0xFFFFFFFF);
  Color get surfaceGlass => isDark ? const Color(0xFFFFFFFF).withOpacity(0.10) : Colors.white.withOpacity(0.5); // Fallback for light
  Color get borderSubtle => isDark ? const Color(0xFFFFFFFF).withOpacity(0.10) : const Color(0xFFFFFFFF).withOpacity(0.30);
  List<BoxShadow> get shadowCard => isDark 
      ? [BoxShadow(color: const Color(0xFF000000).withOpacity(0.40), blurRadius: 16, offset: const Offset(0, 6))]
      : [BoxShadow(color: const Color(0xFF475569).withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 6))];

  // 2. Containers
  Color get containerDefault => isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
  Color get containerHighlight => isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF5F5F7);
  Color get containerSlot => isDark ? const Color(0xFFFFFFFF).withOpacity(0.05) : const Color(0xFFF5F5F7);
  Color get containerSlotAlt => isDark ? const Color(0xFFFFFFFF).withOpacity(0.10) : const Color(0xFFE0E0E2);
  Color get overlayModal => isDark ? const Color(0xFF1A1A1A).withOpacity(0.80) : const Color(0xFFFFFFFF).withOpacity(0.80);

  // 3. Typography
  Color get textPrimary => isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0F172A);
  Color get textSecondary => isDark ? const Color(0xFFFFFFFF).withOpacity(0.70) : const Color(0xFF475569);
  Color get textTertiary => isDark ? const Color(0xFFFFFFFF).withOpacity(0.50) : const Color(0xFF64748B);
  Color get textInverse => isDark ? const Color(0xFF0F172A) : const Color(0xFFFFFFFF);
  Color get textLink => isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);

  // 4. Iconography
  Color get iconPrimary => isDark ? const Color(0xFFFFFFFF).withOpacity(0.70) : const Color(0xFF475569);
  Color get iconSecondary => isDark ? const Color(0xFFFFFFFF).withOpacity(0.40) : const Color(0xFF94A3B8);
  Color get iconBgPrimary => isDark ? const Color(0xFFFFFFFF).withOpacity(0.10) : const Color(0xFFF5F5F7);
  Color get iconBgActive => isDark ? const Color(0xFFFFFFFF).withOpacity(0.10) : const Color(0xFFFFFFFF);

  // 5. Interactive
  Color get actionPrimaryBg => isDark ? const Color(0xFF2C2C2E) : const Color(0xFFFFFFFF);
  Color get actionPrimaryFg => isDark ? const Color(0xFFFFFFFF).withOpacity(0.80) : const Color(0xFF475569);
  Color get actionHover => isDark ? const Color(0xFFFFFFFF).withOpacity(0.05) : const Color(0xFFF8FAFC);
  Color get actionPressed => isDark ? const Color(0xFF000000).withOpacity(0.20) : const Color(0xFFE2E8F0);
  Color get actionDisabledBg => isDark ? const Color(0xFFFFFFFF).withOpacity(0.05) : const Color(0xFFF1F5F9);
  Color get actionDisabledFg => isDark ? const Color(0xFFFFFFFF).withOpacity(0.30) : const Color(0xFF94A3B8);

  // 6. Status
  Color get statusSuccess => isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
  Color get statusWarning => isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
  Color get statusError => isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
  Color get statusInfo => isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
  Color get statusNeutral => isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

  // 7. Input
  Color get inputBg => isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFEFEFE);
  Color get inputBorder => isDark ? const Color(0xFF3C4043) : const Color(0xFFE2E8F0);
  Color get inputBorderFocus => isDark ? const Color(0xFFF8F9FA) : const Color(0xFF3B82F6);
  Color get controlActive => isDark ? const Color(0xFFF5F5F5) : const Color(0xFF2563EB);
  Color get controlTrack => isDark ? const Color(0xFF3C4043) : const Color(0xFFE2E8F0);
}

class MedicationScreen extends StatefulWidget {
  final ChatSession? session;
  final String? sessionName;

  const MedicationScreen({
    super.key,
    this.session,
    this.sessionName,
  });

  /// Get the session name - from session object or sessionName parameter or default
  String get effectiveSessionName => session?.name ?? sessionName ?? 'My Medications';

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
    _dataProvider = MedicationDataProvider(sessionName: widget.effectiveSessionName);
    
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
          _state = MedicationState.empty(sessionName: widget.effectiveSessionName);
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
    final colors = _ScreenColors.of(context);
    return Scaffold(
      backgroundColor: colors.bgPrimary,
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
    final colors = _ScreenColors.of(context);
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
            color: colors.surfaceGlass,
            border: Border(bottom: BorderSide(color: colors.borderSubtle)),
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
                        Icon(CupertinoIcons.chevron_left, color: colors.statusInfo, size: 28),
                        Text(
                          "Chats",
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            color: colors.statusInfo,
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
                              color: colors.statusSuccess,
                              backgroundColor: colors.containerSlot,
                            ),
                          ),
                        ),
                        Icon(CupertinoIcons.capsule_fill, color: colors.iconSecondary, size: 16),
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
                            widget.effectiveSessionName,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Streak Flame - only show if streak > 0
                          if (_state?.showStreakBadge == true)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: colors.statusWarning.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Row(
                                children: [
                                  Icon(CupertinoIcons.flame_fill, size: 10, color: colors.statusWarning),
                                  const SizedBox(width: 2),
                                  Text(
                                    _state!.progress.streakDisplayText,
                                    style: GoogleFonts.inter(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: colors.statusWarning,
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
                          color: colors.textSecondary,
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
                  color: colors.bgSecondary,
                  shape: BoxShape.circle,
                ),
                child: Icon(CupertinoIcons.info, color: colors.iconSecondary, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Empty state when no medications are assigned
  Widget _buildEmptyState() {
    final colors = _ScreenColors.of(context);
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
                color: colors.bgSecondary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.capsule,
                size: 40,
                color: colors.iconSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Medications Yet',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              MedicationState.emptyStateMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                height: 1.5,
                color: colors.textSecondary,
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
    final colors = _ScreenColors.of(context);
    final isDoseTaken = _state?.isDoseTaken ?? false;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surfacePrimary,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: colors.borderSubtle),
        boxShadow: colors.shadowCard,
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
                  color: colors.bgSecondary,
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
                      ? Icon(CupertinoIcons.check_mark_circled_solid, color: colors.statusSuccess, size: 40)
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
                      color: colors.containerSlot,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: colors.borderSubtle),
                    ),
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: 12,
                      height: (32 * med.inventory.fillPercentage).clamp(4.0, 32.0),
                      decoration: BoxDecoration(
                        color: med.inventory.status == InventoryStatus.ok 
                            ? colors.statusSuccess 
                            : med.inventory.status == InventoryStatus.low 
                                ? colors.statusWarning 
                                : colors.statusError,
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
                      color: colors.textTertiary,
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
                  color: colors.textSecondary,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                med.name,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDoseTaken ? colors.statusSuccess : colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                med.dosageDisplayText,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary,
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
                  color: colors.bgSecondary,
                  shape: BoxShape.circle,
                ),
                child: Icon(CupertinoIcons.info, size: 14, color: colors.iconSecondary),
              ),
            ),
          ),

          // Slider
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: colors.containerSlot,
              borderRadius: BorderRadius.circular(100),
            ),
            child: isDoseTaken 
                ? Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.check_mark, color: colors.statusSuccess, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _state?.doseTakenAt != null 
                              ? "Taken at ${TimeOfDay.fromDateTime(_state!.doseTakenAt!).format(context)}"
                              : "Taken",
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: colors.statusSuccess,
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
                              color: colors.statusSuccess.withOpacity(0.2),
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
                                      color: colors.textTertiary,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(CupertinoIcons.chevron_right, size: 14, color: colors.textTertiary),
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
                                  color: colors.surfacePrimary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(CupertinoIcons.capsule_fill, color: colors.statusInfo, size: 20),
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
    final colors = _ScreenColors.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.containerHighlight,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: colors.borderSubtle),
        boxShadow: colors.shadowCard,
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
                  color: colors.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => _dataProvider.setCardFlipped(false),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colors.surfacePrimary,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.borderSubtle),
                  ),
                  child: Icon(CupertinoIcons.arrow_counterclockwise, size: 16, color: colors.iconSecondary),
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
                color: colors.textTertiary,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfacePrimary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Text(
                "\"${med.doctorNotes}\"",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: colors.textSecondary,
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
                color: colors.textTertiary,
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
                color: colors.surfacePrimary,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Text(
                effect,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary,
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
                    color: colors.textTertiary,
                  ),
                ),
              ),
            ),

          const Spacer(),
          Divider(color: colors.borderSubtle),
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
                    color: colors.textTertiary,
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
                      color: colors.textLink,
                    ),
                  ),
                )
              else
                Text(
                  "Insert unavailable",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: colors.textTertiary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final colors = _ScreenColors.of(context);
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
        color: colors.surfaceGlass,
        border: Border(top: BorderSide(color: colors.borderSubtle)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildFooterButton(
              icon: Icons.sentiment_dissatisfied_rounded,
              iconColor: canLogSideEffect ? colors.statusWarning : colors.iconSecondary,
              label: "Log Side Effect",
              onTap: canLogSideEffect ? () {} : null,
              enabled: canLogSideEffect,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildFooterButton(
              icon: CupertinoIcons.phone_fill,
              iconColor: canContactDoctor ? colors.statusInfo : colors.iconSecondary,
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
    final colors = _ScreenColors.of(context);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: enabled ? colors.surfacePrimary : colors.actionDisabledBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.borderSubtle),
          boxShadow: enabled ? colors.shadowCard : null,
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
                  color: enabled ? colors.textSecondary : colors.actionDisabledFg,
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
