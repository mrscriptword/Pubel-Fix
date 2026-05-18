import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ─── Primary Brand Colors (Dark Violet) ───────────────────────────────────
  static const Color primaryColor = Color(0xFF7C4DFF);   // Main purple
  static const Color primaryDark  = Color(0xFF0D0F1E);   // Deep dark background
  static const Color primaryLight = Color(0xFFB47CFF);   // Light purple

  // ─── Accent Colors ────────────────────────────────────────────────────────
  static const Color accentColor  = Color(0xFF00E5FF);   // Cyan accent
  static const Color accentGreen  = Color(0xFF00E676);   // Green
  static const Color accentBlue   = Color(0xFF3B82F6);   // Blue
  static const Color accentRed    = Color(0xFFEF4444);   // Red
  static const Color accentAmber  = Color(0xFFF59E0B);   // Amber

  // ─── Background & Surface ─────────────────────────────────────────────────
  static const Color backgroundColorDark = Color(0xFF0F111A);
  static const Color cardDark            = Color(0xFF1A1D2E);
  static const Color backgroundColor     = Color(0xFFF7F5F1); // Light bg

  // ─── Text ─────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF7A7A7A);

  // ─── Gradients ────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF7C4DFF), Color(0xFF00B4D8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF00B4D8), Color(0xFF00E5FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF0D0F1E), Color(0xFF151832), Color(0xFF0F111A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Material Themes ──────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      fontFamily: GoogleFonts.epilogue().fontFamily,
      textTheme: TextTheme(
        displayLarge: GoogleFonts.syne(fontSize: 32, fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -1),
        displayMedium: GoogleFonts.syne(fontSize: 24, fontWeight: FontWeight.w700, color: textPrimary),
        bodyLarge: GoogleFonts.epilogue(fontSize: 16, color: textPrimary),
        bodyMedium: GoogleFonts.epilogue(fontSize: 14, color: textSecondary),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        color: Colors.white,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColorDark,
      fontFamily: GoogleFonts.epilogue().fontFamily,
      textTheme: TextTheme(
        displayLarge: GoogleFonts.syne(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1),
        displayMedium: GoogleFonts.syne(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
        bodyLarge: GoogleFonts.epilogue(fontSize: 16, color: Colors.white),
        bodyMedium: GoogleFonts.epilogue(fontSize: 14, color: Colors.white70),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        color: cardDark,
      ),
    );
  }
}
