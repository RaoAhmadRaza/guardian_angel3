import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'patient_chat_screen.dart'; // For ChatSession and ViewType

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
  
  // Mock Data for Medication
  late List<ChatMessage> _messages;
  bool _doseTaken = false;
  bool _isCardFlipped = false;
  double _sliderValue = 0.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _messages = [
      ChatMessage(
        id: '1',
        text: "Good morning! Here is your medication schedule for today.",
        sender: 'system',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      ChatMessage(
        id: '2',
        text: "",
        sender: 'system',
        timestamp: DateTime.now(),
        medication: MedicationReminder(
          name: "Lisinopril",
          dosage: "10mg",
          context: "With food",
          nextDose: NextDose(time: "2:00 PM", name: "Afternoon Dose"),
          inventory: Inventory(remaining: 12, total: 30, status: 'ok'),
          doctorNotes: "Take with a full glass of water. Monitor blood pressure daily.",
          sideEffects: ["Dizziness", "Headache", "Cough"],
          pillColor: Colors.blue.shade100,
        ),
      ),
    ];
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details, double maxWidth) {
    if (_doseTaken) return;
    setState(() {
      _isDragging = true;
      _sliderValue += details.delta.dx;
      _sliderValue = _sliderValue.clamp(0.0, maxWidth - 48); // 48 is thumb width
    });

    if (_sliderValue >= maxWidth - 56) { // Threshold
      setState(() {
        _doseTaken = true;
        _isDragging = false;
        _sliderValue = maxWidth - 48;
      });
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_doseTaken) {
      setState(() {
        _isDragging = false;
        _sliderValue = 0.0;
      });
    }
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

              // Messages
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(top: 20, bottom: 100, left: 16, right: 16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    if (msg.medication != null) {
                      return _buildMedicationCard(msg);
                    }
                    return _buildSystemMessage(msg);
                  },
                ),
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
                              value: _doseTaken ? 1.0 : 0.8, // Mock progress
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
                          // Streak Flame
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
                                  "12 Day Streak",
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
                        _doseTaken ? "All meds taken today" : "80% for today",
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

  Widget _buildSystemMessage(ChatMessage msg) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.9),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Text(
          msg.text,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 15,
            height: 1.5,
            color: Colors.grey.shade800,
          ),
        ),
      ),
    );
  }

  Widget _buildMedicationCard(ChatMessage msg) {
    final med = msg.medication!;
    
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 24),
        width: 340,
        height: 400, // Fixed height for flip
        child: TweenAnimationBuilder(
          tween: Tween<double>(begin: 0, end: _isCardFlipped ? 180 : 0),
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

  Widget _buildCardFront(MedicationReminder med) {
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
                  child: _doseTaken 
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
                      height: 16, // Mock 50%
                      decoration: BoxDecoration(
                        color: Colors.green.shade400,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${med.inventory.remaining} left",
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
                _doseTaken ? "COMPLETED" : "SCHEDULED FOR 2:00 PM",
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
                  color: _doseTaken ? Colors.green.shade600 : Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "${med.dosage} • ${med.context}",
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
              onTap: () => setState(() => _isCardFlipped = true),
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
            child: _doseTaken 
                ? Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.check_mark, color: Colors.green.shade600, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "Taken at ${TimeOfDay.now().format(context)}",
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

  Widget _buildCardBack(MedicationReminder med) {
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
                onTap: () => setState(() => _isCardFlipped = false),
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

          const Spacer(),
          Divider(color: Colors.grey.shade200),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Refill ID: #839210",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                ),
              ),
              Text(
                "View Full Insert",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
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
              iconColor: Colors.amber.shade600,
              label: "Log Side Effect",
              onTap: () {},
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildFooterButton(
              icon: CupertinoIcons.phone_fill,
              iconColor: Colors.blue.shade500,
              label: "Contact Dr. Emily",
              onTap: () {},
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
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- DATA MODELS ---

class ChatMessage {
  final String id;
  final String text;
  final String sender;
  final DateTime timestamp;
  final MedicationReminder? medication;

  ChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    this.medication,
  });
}

class MedicationReminder {
  final String name;
  final String dosage;
  final String context;
  final NextDose nextDose;
  final Inventory inventory;
  final String doctorNotes;
  final List<String> sideEffects;
  final Color pillColor;

  MedicationReminder({
    required this.name,
    required this.dosage,
    required this.context,
    required this.nextDose,
    required this.inventory,
    required this.doctorNotes,
    required this.sideEffects,
    required this.pillColor,
  });
}

class NextDose {
  final String time;
  final String name;

  NextDose({required this.time, required this.name});
}

class Inventory {
  final int remaining;
  final int total;
  final String status;

  Inventory({required this.remaining, required this.total, required this.status});
}
