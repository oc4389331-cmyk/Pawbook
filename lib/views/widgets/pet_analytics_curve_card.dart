import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class PetAnalyticsCurveCard extends StatefulWidget {
  final int followersCount;
  final int totalScore;
  final double popularityPercent;
  final String earningsText;

  const PetAnalyticsCurveCard({
    super.key,
    this.followersCount = 23059,
    this.totalScore = 340,
    this.popularityPercent = 94.0,
    this.earningsText = '\$33,900',
  });

  @override
  State<PetAnalyticsCurveCard> createState() => _PetAnalyticsCurveCardState();
}

class _PetAnalyticsCurveCardState extends State<PetAnalyticsCurveCard> {
  int _selectedPeriod = 0; // 0: Semanal, 1: Mensual, 2: Anual

  @override
  Widget build(BuildContext context) {
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
          // Row of Stat Metrics (Image 4 style)
          Row(
            children: [
              _buildStatBox('Followers', widget.followersCount.toString()),
              const SizedBox(width: 8),
              _buildStatBox('Popularidad', '${widget.popularityPercent.toInt()}%'),
              const SizedBox(width: 8),
              _buildStatBox('Score', '${(widget.totalScore / 1000).toStringAsFixed(2)}K'),
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
                      '28.6%',
                      style: GoogleFonts.fredoka(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Rendimiento',
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
              painter: _CurveChartPainter(period: _selectedPeriod),
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

  _CurveChartPainter({required this.period});

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

    // Primary Teal Curve (Earnings / Sponsorships)
    final path = Path();
    path.moveTo(0, h * 0.9);
    path.cubicTo(w * 0.25, h * 0.85, w * 0.45, h * 0.65, w * 0.6, h * 0.5);
    path.cubicTo(w * 0.75, h * 0.35, w * 0.85, h * 0.25, w, h * 0.15);

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

    // Secondary Purple Curve (Activity / Views)
    final path2 = Path();
    path2.moveTo(0, h * 0.8);
    path2.cubicTo(w * 0.3, h * 0.75, w * 0.5, h * 0.55, w * 0.7, h * 0.35);
    path2.cubicTo(w * 0.8, h * 0.25, w * 0.9, h * 0.20, w, h * 0.18);

    final linePaint2 = Paint()
      ..color = const Color(0xFF6366F1).withValues(alpha: 0.65)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path2, linePaint2);

    // Dot indicators at peak
    final dotPaint = Paint()..color = AppTheme.pawTeal;
    final dotOuter = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(w * 0.6, h * 0.5), 5, dotPaint);
    canvas.drawCircle(Offset(w * 0.6, h * 0.5), 5, dotOuter);

    final dotPaint2 = Paint()..color = const Color(0xFF6366F1);
    canvas.drawCircle(Offset(w * 0.6, h * 0.45), 4, dotPaint2);
    canvas.drawCircle(Offset(w * 0.6, h * 0.45), 4, dotOuter);
  }

  @override
  bool shouldRepaint(covariant _CurveChartPainter oldDelegate) => oldDelegate.period != period;
}
