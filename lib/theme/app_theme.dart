import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Pawly Inspired Warm Color Palette
  static const Color bgWarmCream = Color(0xFFFDF6EE);
  static const Color surfaceWarm = Color(0xFFFFF0E5);
  static const Color cardWarm = Color(0xFFFCE8DB);
  static const Color primaryTerracotta = Color(0xFF7C1D1D);
  static const Color primaryTerracottaDark = Color(0xFF591717);
  static const Color accentOrange = Color(0xFFEA580C);
  static const Color emeraldGreen = Color(0xFF059669);
  static const Color solanaPurple = Color(0xFF9945FF);
  static const Color solanaGreen = Color(0xFF14F195);

  static const Color textPrimaryDark = Color(0xFF3B1414);
  static const Color textMutedWarm = Color(0xFF7A5C5C);
  static const Color borderWarm = Color(0xFFEED5C5);

  // Legacy aliases for backward compatibility
  static const Color bgDark = bgWarmCream;
  static const Color surfaceDark = surfaceWarm;
  static const Color cardDark = cardWarm;
  static const Color borderDark = borderWarm;
  static const Color textMuted = textMutedWarm;

  static ThemeData get warmTheme {
    return ThemeData.light().copyWith(
      scaffoldBackgroundColor: bgWarmCream,
      primaryColor: primaryTerracotta,
      colorScheme: const ColorScheme.light(
        primary: primaryTerracotta,
        secondary: accentOrange,
        tertiary: emeraldGreen,
        surface: surfaceWarm,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgWarmCream,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: textPrimaryDark),
        titleTextStyle: GoogleFonts.fredoka(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: textPrimaryDark,
        ),
      ),
      cardTheme: CardTheme(
        color: surfaceWarm,
        elevation: 2,
        shadowColor: primaryTerracotta.withOpacity(0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: borderWarm, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryTerracotta,
          foregroundColor: Colors.white,
          elevation: 3,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: GoogleFonts.fredoka(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme).copyWith(
        headlineMedium: GoogleFonts.fredoka(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: primaryTerracotta,
        ),
        titleLarge: GoogleFonts.fredoka(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textPrimaryDark,
        ),
        titleMedium: GoogleFonts.fredoka(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: textPrimaryDark,
        ),
        bodyLarge: GoogleFonts.outfit(
          fontSize: 15,
          color: textPrimaryDark,
        ),
        bodyMedium: GoogleFonts.outfit(
          fontSize: 13,
          color: textMutedWarm,
        ),
      ),
    );
  }

  // Alias darkTheme to warmTheme so existing references stay fully functional
  static ThemeData get darkTheme => warmTheme;
}
