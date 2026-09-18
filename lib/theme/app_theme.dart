import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── OFICIAL PASTEL PALETTE PARA PAWBOOKLIFE ─────────────────────────────
  // 1. Colores Principales Pastel
  static const Color pastelSkyBlue = Color(0xFFE3F2FD);    // Azul Cielo Claro
  static const Color pastelMint = Color(0xFFE8F5E9);       // Verde Menta Suave
  static const Color pastelVanilla = Color(0xFFFFFDE7);    // Crema Vainilla (Fondo base)
  static const Color pastelPeach = Color(0xFFFFECB3);      // Melocotón Suave
  static const Color pastelPink = Color(0xFFF8BBD0);       // Rosa Pastel Dulce
  static const Color pastelLavender = Color(0xFFD1C4E9);   // Lavanda Pálida

  // 2. Colores de Acento (Sutiles y Agradables)
  static const Color accentCoral = Color(0xFFFFAB91);      // Coral Claro
  static const Color accentTurquoise = Color(0xFFB2EBF2);  // Turquesa Suave
  static const Color accentTeaGreen = Color(0xFFC8E6C9);   // Verde Té

  // 3. Tonos de Marca & Contraste (para botones primarios y textos destacados)
  static const Color brandCoral = Color(0xFFFF7043);       // Coral Vibrante de Marca
  static const Color primaryTerracotta = Color(0xFFE64A19);// Coral Cálido de Alto Contraste
  static const Color primaryTerracottaDark = Color(0xFFD84315);
  static const Color accentOrange = Color(0xFFFF8A65);     // Coral Melocotón de Acento
  static const Color emeraldGreen = Color(0xFF10B981);     // Menta Esmeralda
  static const Color solanaPurple = Color(0xFF9945FF);     // Lavanda Solana
  static const Color solanaGreen = Color(0xFF14F195);      // Verde Solana

  // 4. Fondos y Superficies
  static const Color bgWarmCream = Color(0xFFFFFDF5);      // Crema Vainilla Luminosa
  static const Color surfaceWarm = Color(0xFFFFF9F0);      // Superficie Melocotón Sutil
  static const Color cardWarm = Color(0xFFFFFFFF);         // Tarjetas Blancas con Sombra Pastel
  static const Color borderWarm = Color(0xFFFFE0B2);       // Borde Melocotón Suave
  static const Color pawTeal = Color(0xFF14B8A6);          // Verde Menta/Turquesa de Barras
  static const Color pawTealLight = Color(0xFFCCFBF1);     // Fondo de Barras Menta
  static const Color pawPillBg = Color(0xFFF8FAFC);        // Píldoras y Badges

  // Sombras y Gradientes para la Nueva UI
  static List<BoxShadow> get softCardShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.05),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: brandCoral.withValues(alpha: 0.04),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ];

  static List<BoxShadow> get elevatedPawShadow => [
        BoxShadow(
          color: brandCoral.withValues(alpha: 0.4),
          blurRadius: 18,
          spreadRadius: 2,
          offset: const Offset(0, 6),
        ),
      ];

  static const LinearGradient pawButtonGradient = LinearGradient(
    colors: [Color(0xFFFF8A65), Color(0xFFFF5722)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient sendTipGradient = LinearGradient(
    colors: [Color(0xFFD1FAE5), Color(0xFFEDE9FE)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // 5. Tipografía de Alto Contraste
  static const Color textPrimaryDark = Color(0xFF2D3142);  // Carbón Suave Elegante
  static const Color warmBrown = Color(0xFF4A4E69);        // Lavanda Carbón
  static const Color textMutedWarm = Color(0xFF757F9A);    // Gris Azulado Muted

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
        secondary: accentCoral,
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
        color: Colors.white,
        elevation: 3,
        shadowColor: accentCoral.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: borderWarm, width: 1.2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryTerracotta,
          foregroundColor: Colors.white,
          elevation: 3,
          shadowColor: primaryTerracotta.withValues(alpha: 0.35),
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
