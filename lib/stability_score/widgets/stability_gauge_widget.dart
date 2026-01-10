/// Health Stability Score Gauge Widget
///
/// Visual display of the HSS score with gradient arc gauge,
/// level indicator, and subsystem breakdown.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/stability_score_result.dart';

/// Gauge widget displaying the Health Stability Score
class StabilityGaugeWidget extends StatelessWidget {
  /// The stability score result to display
  final StabilityScoreResult? score;

  /// Size of the gauge
  final double size;

  /// Whether to show the subsystem breakdown
  final bool showBreakdown;

  /// Whether the widget is in compact mode
  final bool compact;

  /// Callback when gauge is tapped
  final VoidCallback? onTap;

  const StabilityGaugeWidget({
    super.key,
    required this.score,
    this.size = 200,
    this.showBreakdown = true,
    this.compact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (score == null) {
      return _buildNoDataState(isDarkMode);
    }

    return GestureDetector(
      onTap: onTap,
      child: compact ? _buildCompactGauge(isDarkMode) : _buildFullGauge(isDarkMode),
    );
  }

  Widget _buildNoDataState(bool isDarkMode) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: size * 0.25,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'No Data',
              style: TextStyle(
                fontSize: size * 0.08,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.5)
                    : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullGauge(bool isDarkMode) {
    return SizedBox(
      width: size,
      height: size + (showBreakdown ? 120 : 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Gauge
          SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _GaugePainter(
                score: score!.score,
                level: score!.level,
                isDarkMode: isDarkMode,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${score!.score.round()}',
                      style: TextStyle(
                        fontSize: size * 0.25,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      score!.level.displayName,
                      style: TextStyle(
                        fontSize: size * 0.08,
                        fontWeight: FontWeight.w500,
                        color: score!.level.color,
                      ),
                    ),
                    if (!score!.isReliable)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Limited data',
                          style: TextStyle(
                            fontSize: size * 0.06,
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.5)
                                : Colors.grey,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Breakdown
          if (showBreakdown) ...[
            const SizedBox(height: 16),
            _buildSubsystemBreakdown(isDarkMode),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactGauge(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDarkMode
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mini gauge
          SizedBox(
            width: 48,
            height: 48,
            child: CustomPaint(
              painter: _MiniGaugePainter(
                score: score!.score,
                level: score!.level,
                isDarkMode: isDarkMode,
              ),
              child: Center(
                child: Text(
                  '${score!.score.round()}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Label
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Health Stability',
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.7)
                      : const Color(0xFF64748B),
                ),
              ),
              Text(
                score!.level.displayName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: score!.level.color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubsystemBreakdown(bool isDarkMode) {
    return Column(
      children: score!.contributions
          .map((c) => _buildSubsystemRow(c, isDarkMode))
          .toList(),
    );
  }

  Widget _buildSubsystemRow(SubsystemContribution contribution, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            contribution.icon,
            size: 16,
            color: contribution.hasData
                ? contribution.statusColor
                : (isDarkMode ? Colors.white.withOpacity(0.3) : Colors.grey),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              contribution.displayName,
              style: TextStyle(
                fontSize: 13,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.8)
                    : const Color(0xFF475569),
              ),
            ),
          ),
          if (contribution.hasData)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: contribution.statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${(contribution.stabilityScore * 100).round()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: contribution.statusColor,
                ),
              ),
            )
          else
            Text(
              'No data',
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.4)
                    : Colors.grey,
              ),
            ),
        ],
      ),
    );
  }
}

/// Custom painter for the full gauge
class _GaugePainter extends CustomPainter {
  final double score;
  final StabilityLevel level;
  final bool isDarkMode;

  _GaugePainter({
    required this.score,
    required this.level,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.4;
    const strokeWidth = 12.0;
    const startAngle = 135 * (math.pi / 180); // Start at bottom-left
    const sweepAngle = 270 * (math.pi / 180); // 270 degree arc

    // Background arc
    final bgPaint = Paint()
      ..color = isDarkMode
          ? Colors.white.withOpacity(0.1)
          : Colors.grey.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // Score arc with gradient
    final scoreAngle = (score / 100) * sweepAngle;
    
    final gradientPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: [
          const Color(0xFFEF4444), // Red
          const Color(0xFFF97316), // Orange
          const Color(0xFFFBBF24), // Yellow
          const Color(0xFF22C55E), // Green
        ],
        stops: const [0.0, 0.33, 0.66, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      scoreAngle,
      false,
      gradientPaint,
    );

    // Score indicator dot
    final indicatorAngle = startAngle + scoreAngle;
    final indicatorOffset = Offset(
      center.dx + radius * math.cos(indicatorAngle),
      center.dy + radius * math.sin(indicatorAngle),
    );

    final indicatorPaint = Paint()
      ..color = level.color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(indicatorOffset, 8, indicatorPaint);

    // White inner circle for indicator
    final innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(indicatorOffset, 4, innerPaint);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.score != score || oldDelegate.level != level;
  }
}

/// Custom painter for the compact mini gauge
class _MiniGaugePainter extends CustomPainter {
  final double score;
  final StabilityLevel level;
  final bool isDarkMode;

  _MiniGaugePainter({
    required this.score,
    required this.level,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.4;
    const strokeWidth = 4.0;

    // Background circle
    final bgPaint = Paint()
      ..color = isDarkMode
          ? Colors.white.withOpacity(0.1)
          : Colors.grey.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, bgPaint);

    // Score arc
    final scoreAngle = (score / 100) * 2 * math.pi;
    
    final scorePaint = Paint()
      ..color = level.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start from top
      scoreAngle,
      false,
      scorePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniGaugePainter oldDelegate) {
    return oldDelegate.score != score || oldDelegate.level != level;
  }
}

/// Card widget showing HSS with trend
class StabilityScoreCard extends StatelessWidget {
  final StabilityScoreResult? score;
  final VoidCallback? onTap;

  const StabilityScoreCard({
    super.key,
    required this.score,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: score != null
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    score!.level.color.withOpacity(0.15),
                    score!.level.color.withOpacity(0.05),
                  ],
                )
              : null,
          color: score == null
              ? (isDarkMode
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.withOpacity(0.1))
              : null,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: score?.level.color.withOpacity(0.3) ??
                (isDarkMode
                    ? Colors.white.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.2)),
          ),
        ),
        child: Row(
          children: [
            // Mini gauge
            StabilityGaugeWidget(
              score: score,
              size: 60,
              showBreakdown: false,
              compact: false,
            ),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Health Stability',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.7)
                          : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (score != null) ...[
                    Text(
                      score!.primaryInsight,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.8)
                            : const Color(0xFF475569),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (score!.trendDescription.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(
                              score!.trend > 0
                                  ? Icons.trending_up
                                  : score!.trend < 0
                                      ? Icons.trending_down
                                      : Icons.trending_flat,
                              size: 14,
                              color: score!.trend > 0
                                  ? const Color(0xFF22C55E)
                                  : score!.trend < 0
                                      ? const Color(0xFFEF4444)
                                      : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              score!.trendDescription,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode
                                    ? Colors.white.withOpacity(0.5)
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ] else
                    Text(
                      'Collecting health data...',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.5)
                            : Colors.grey,
                      ),
                    ),
                ],
              ),
            ),
            // Arrow
            Icon(
              Icons.chevron_right,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.3)
                  : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }
}
