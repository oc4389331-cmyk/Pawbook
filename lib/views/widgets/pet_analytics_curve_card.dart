import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class PetAnalyticsCurveCard extends StatefulWidget {
  final int followersCount;
  final int totalScore;
  final double popularityPercent;
  final String earningsText;
  final String performanceText;
  final List<double>? weeklyPoints;
  final List<double>? monthlyPoints;
  final List<double>? yearlyPoints;

  const PetAnalyticsCurveCard({
    super.key,
    this.followersCount = 0,
    this.totalScore = 0,
    this.popularityPercent = 0.0,
    this.earningsText = '\$0.00',
    this.performanceText = '+0.0%',
    this.weeklyPoints,
    this.monthlyPoints,
    this.yearlyPoints,
  });

  @override
  State<PetAnalyticsCurveCard> createState() => _PetAnalyticsCurveCardState();
}

class _PetAnalyticsCurveCardState extends State<PetAnalyticsCurveCard> {
  int _selectedPeriod = 0; // 0: Semanal, 1: Mensual, 2: Anual

  @override
  Widget build(BuildContext context) {
    final formattedScore = widget.totalScore.toString();
    final formattedFollowers = widget.followersCount.toString();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppTheme.softCardShadow,
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row of Stat Metrics (Real Data)
          Row(
            children: [
              _buildStatBox('Followers', formattedFollowers),
              const SizedBox(width: 8),
              _buildStatBox('Popularidad', '${widget.popularityPercent.toInt()}%'),
              const SizedBox(width: 8),
              _buildStatBox('Score', formattedScore),
            ],
          ),
          const SizedBox(height: 18),

          // Header with earnings & badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      widget.performanceText,
                      style: GoogleFonts.fredoka(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Patrocinios Reales',
                    style: GoogleFonts.fredoka(
                      color: AppTheme.textMutedWarm,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Text(
                widget.earningsText,
                style: GoogleFonts.fredoka(
                  color: AppTheme.textPrimaryDark,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Smooth curved chart
          SizedBox(
            height: 130,
            width: double.infinity,
            child: CustomPaint(
              painter: _CurveChartPainter(
                period: _selectedPeriod,
                weeklyPoints: widget.weeklyPoints,
                monthlyPoints: widget.monthlyPoints,
                yearlyPoints: widget.yearlyPoints,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Period Selector (Weekly / Monthly / Yearly)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPeriodTab('Semanal', 0),
              const SizedBox(width: 8),
              _buildPeriodTab('Mensual', 1),
              const SizedBox(width: 8),
              _buildPeriodTab('Anual', 2),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: AppTheme.textMutedWarm,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.fredoka(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodTab(String title, int index) {
    final isSelected = _selectedPeriod == index;
    return InkWell(
      onTap: () => setState(() => _selectedPeriod = index),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.brandCoral.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          title,
          style: GoogleFonts.fredoka(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppTheme.brandCoral : AppTheme.textMutedWarm,
          ),
        ),
      ),
    );
  }
}

class _CurveChartPainter extends CustomPainter {
  final int period;
  final List<double>? weeklyPoints;
  final List<double>? monthlyPoints;
  final List<double>? yearlyPoints;

  _CurveChartPainter({
    required this.period,
    this.weeklyPoints,
    this.monthlyPoints,
    this.yearlyPoints,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background Grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, h * 0.25), Offset(w, h * 0.25), gridPaint);
    canvas.drawLine(Offset(0, h * 0.60), Offset(w, h * 0.60), gridPaint);
    canvas.drawLine(Offset(0, h * 0.95), Offset(w, h * 0.95), gridPaint);

    final rawPoints = period == 0
        ? weeklyPoints
        : (period == 1 ? monthlyPoints : yearlyPoints);

    final points = (rawPoints != null && rawPoints.isNotEmpty)
        ? rawPoints
        : [0.05, 0.1, 0.2, 0.35, 0.5, 0.7, 0.85];

    // Primary Teal Curve (Earnings / Sponsorships)
    final path = Path();
    final stepX = points.length > 1 ? w / (points.length - 1) : w;
    final coords = <Offset>[];
    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      final y = h * 0.90 - (points[i].clamp(0.0, 1.0) * (h * 0.70));
      coords.add(Offset(x, y));
    }

    path.moveTo(coords.first.dx, coords.first.dy);
    for (int i = 0; i < coords.length - 1; i++) {
      final p0 = i > 0 ? coords[i - 1] : coords[i];
      final p1 = coords[i];
      final p2 = coords[i + 1];
      final p3 = i + 2 < coords.length ? coords[i + 2] : p2;

      final cp1 = Offset(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
      );
      final cp2 = Offset(
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
      );
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }

    // Area Fill under the Curve
    final fillPath = Path.from(path)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppTheme.pawTeal.withValues(alpha: 0.25),
          AppTheme.pawTeal.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = AppTheme.pawTeal
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    // Secondary Purple Curve (Activity / Views scaled)
    final path2 = Path();
    final coords2 = <Offset>[];
    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      final y = h * 0.92 - (points[i].clamp(0.0, 1.0) * (h * 0.55));
      coords2.add(Offset(x, y));
    }
    path2.moveTo(coords2.first.dx, coords2.first.dy);
    for (int i = 0; i < coords2.length - 1; i++) {
      final p0 = i > 0 ? coords2[i - 1] : coords2[i];
      final p1 = coords2[i];
      final p2 = coords2[i + 1];
      final p3 = i + 2 < coords2.length ? coords2[i + 2] : p2;

      final cp1 = Offset(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
      );
      final cp2 = Offset(
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
      );
      path2.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }

    final linePaint2 = Paint()
      ..color = const Color(0xFF6366F1).withValues(alpha: 0.65)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path2, linePaint2);

    // Dot indicators at peak or latest point
    final lastPoint = coords.isNotEmpty ? coords[min(coords.length - 1, (coords.length * 0.7).toInt())] : Offset(w * 0.5, h * 0.5);
    final dotPaint = Paint()..color = AppTheme.pawTeal;
    final dotOuter = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(lastPoint, 5, dotPaint);
    canvas.drawCircle(lastPoint, 5, dotOuter);

    final lastPoint2 = coords2.isNotEmpty ? coords2[min(coords2.length - 1, (coords2.length * 0.7).toInt())] : Offset(w * 0.5, h * 0.5);
    final dotPaint2 = Paint()..color = const Color(0xFF6366F1);
    canvas.drawCircle(lastPoint2, 4, dotPaint2);
    canvas.drawCircle(lastPoint2, 4, dotOuter);
  }

  @override
  bool shouldRepaint(covariant _CurveChartPainter oldDelegate) =>
      oldDelegate.period != period ||
      oldDelegate.weeklyPoints != weeklyPoints ||
      oldDelegate.monthlyPoints != monthlyPoints ||
      oldDelegate.yearlyPoints != yearlyPoints;
}
