import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

class DripAlertScreen extends StatefulWidget {
  const DripAlertScreen({super.key});

  @override
  State<DripAlertScreen> createState() => _DripAlertScreenState();
}

class _DripAlertScreenState extends State<DripAlertScreen> with SingleTickerProviderStateMixin {
  bool _isStopped = false;
  late DateTime _now;
  Timer? _timer;
  
  // Mock infusion data
  final _infusion = _InfusionData(
    name: "Normal Saline",
    totalVolume: 500,
    durationMinutes: 120,
    startTime: DateTime.now().subtract(const Duration(minutes: 30)),
    alertThreshold: 10,
  );

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isStopped) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  _InfusionStats get _stats {
    final elapsedMs = _now.difference(_infusion.startTime).inMilliseconds;
    final totalMs = _infusion.durationMinutes * 60 * 1000;
    final progress = (elapsedMs / totalMs).clamp(0.0, 1.0);
    final remainingMins = ((totalMs - elapsedMs) / 60000).floor().clamp(0, double.infinity).toInt();
    // volumeLeft is not strictly used in UI but calculated in React
    final flowRate = (_infusion.totalVolume / (_infusion.durationMinutes / 60)).floor();

    return _InfusionStats(
      progress: progress,
      remainingMins: remainingMins,
      flowRate: flowRate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    final isNearingEnd = stats.remainingMins <= _infusion.alertThreshold;

    return Scaffold(
      backgroundColor: const Color(0xFFFDFDFD),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              CupertinoIcons.chevron_left,
                              color: Color(0xFF0F172A),
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Infusion Live',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),

                // Scrollable Content
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 140),
                    children: [
                      // Progress Container
                      Container(
                        height: 320,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(48),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Pulse Animation (Simulated with simple container for now, could be animated)
                            if (isNearingEnd && !_isStopped)
                              Positioned.fill(
                                child: _PulseBackground(color: const Color(0xFFDC2626).withOpacity(0.05)),
                              ),

                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // IV Bag Visual
                                AnimatedScale(
                                  scale: !_isStopped ? 1.1 : 0.9,
                                  duration: const Duration(milliseconds: 500),
                                  child: Opacity(
                                    opacity: !_isStopped ? 1.0 : 0.5,
                                    child: Column(
                                      children: [
                                        Container(
                                          width: 128,
                                          height: 192,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF5F5F7),
                                            borderRadius: const BorderRadius.vertical(
                                              top: Radius.circular(8),
                                              bottom: Radius.circular(24),
                                            ),
                                            border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.1),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          clipBehavior: Clip.hardEdge,
                                          child: Stack(
                                            alignment: Alignment.bottomCenter,
                                            children: [
                                              AnimatedContainer(
                                                duration: const Duration(seconds: 1),
                                                height: 192 * (1 - stats.progress),
                                                color: isNearingEnd 
                                                    ? const Color(0xFFDC2626).withOpacity(0.3) 
                                                    : const Color(0xFF2563EB).withOpacity(0.2),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (!_isStopped)
                                          _BouncingDrop(
                                            color: isNearingEnd ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 32),

                                // Status Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: !_isStopped 
                                        ? (isNearingEnd ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5))
                                        : const Color(0xFFF3F4F6), // gray-100
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: !_isStopped 
                                          ? (isNearingEnd ? const Color(0xFFFEE2E2) : const Color(0xFFD1FAE5))
                                          : const Color(0xFFE5E7EB), // gray-200
                                      width: 2,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!_isStopped)
                                        _PulsingIcon(
                                          icon: CupertinoIcons.waveform_path_ecg,
                                          color: isNearingEnd ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                        )
                                      else
                                        const Icon(
                                          CupertinoIcons.waveform_path_ecg,
                                          size: 20,
                                          color: Color(0xFF9CA3AF), // gray-400
                                        ),
                                      const SizedBox(width: 12),
                                      Text(
                                        _isStopped 
                                            ? 'STOPPED' 
                                            : (isNearingEnd ? 'CHECK SOON' : 'ACTIVE FLOW'),
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          color: !_isStopped 
                                              ? (isNearingEnd ? const Color(0xFFDC2626) : const Color(0xFF059669))
                                              : const Color(0xFF9CA3AF),
                                          letterSpacing: 2.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Data Points Grid
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(40),
                                border: Border.all(color: const Color(0xFF1E293B)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  const Icon(
                                    CupertinoIcons.gauge,
                                    color: Color(0xFF60A5FA),
                                    size: 28,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'RATE',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white.withOpacity(0.5),
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${stats.flowRate}ml/hr',
                                    style: GoogleFonts.inter(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: isNearingEnd ? const Color(0xFFDC2626) : Colors.white,
                                borderRadius: BorderRadius.circular(40),
                                border: Border.all(
                                  color: isNearingEnd ? const Color(0xFFB91C1C) : const Color(0xFFE2E8F0),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    CupertinoIcons.clock,
                                    color: isNearingEnd ? Colors.white : const Color(0xFF2563EB),
                                    size: 28,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'TIME LEFT',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isNearingEnd ? Colors.white.withOpacity(0.6) : const Color(0xFF64748B),
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${stats.remainingMins} Min',
                                    style: GoogleFonts.inter(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w900,
                                      color: isNearingEnd ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Instructional Alert
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isNearingEnd ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: isNearingEnd ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              CupertinoIcons.exclamationmark_circle,
                              color: isNearingEnd ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                              size: 32,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                isNearingEnd 
                                    ? 'Attention: Only ${stats.remainingMins} minutes left. Please prepare to replace or stop the infusion.'
                                    : 'Check the tube for kinks every 30 minutes for patient safety.',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isNearingEnd ? const Color(0xFF991B1B) : const Color(0xFF92400E),
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Bottom Action Button
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  boxShadow: [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.03),
                      blurRadius: 30,
                      offset: Offset(0, -10),
                    ),
                  ],
                ),
                child: GestureDetector(
                  onTap: () => setState(() => _isStopped = !_isStopped),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 96,
                    decoration: BoxDecoration(
                      color: !_isStopped ? const Color(0xFFDC2626) : const Color(0xFF059669),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _isStopped ? 'RESUME FLOW' : 'EMERGENCY STOP',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 2.4, // tracking-[0.1em]
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfusionData {
  final String name;
  final int totalVolume;
  final int durationMinutes;
  final DateTime startTime;
  final int alertThreshold;

  _InfusionData({
    required this.name,
    required this.totalVolume,
    required this.durationMinutes,
    required this.startTime,
    required this.alertThreshold,
  });
}

class _InfusionStats {
  final double progress;
  final int remainingMins;
  final int flowRate;

  _InfusionStats({
    required this.progress,
    required this.remainingMins,
    required this.flowRate,
  });
}

class _PulseBackground extends StatefulWidget {
  final Color color;
  const _PulseBackground({required this.color});

  @override
  State<_PulseBackground> createState() => _PulseBackgroundState();
}

class _PulseBackgroundState extends State<_PulseBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(color: widget.color),
    );
  }
}

class _BouncingDrop extends StatefulWidget {
  final Color color;
  const _BouncingDrop({required this.color});

  @override
  State<_BouncingDrop> createState() => _BouncingDropState();
}

class _BouncingDropState extends State<_BouncingDrop> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, 0.5),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _animation,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _PulsingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  const _PulsingIcon({required this.icon, required this.color});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Icon(
        widget.icon,
        size: 20,
        color: widget.color,
      ),
    );
  }
}
