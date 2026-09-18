import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class PetAttributeBar extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final double progress; // 0.0 to 1.0
  final String percentageText;

  const PetAttributeBar({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.progress,
    required this.percentageText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: GoogleFonts.fredoka(
                fontSize: 12,
                color: AppTheme.textPrimaryDark,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: AppTheme.pawTealLight,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.pawTeal),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 36,
            child: Text(
              percentageText,
              textAlign: TextAlign.right,
              style: GoogleFonts.fredoka(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
