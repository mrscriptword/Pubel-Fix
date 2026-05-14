import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // New Design Palette (Premium Minimalist)
  static const Color backgroundColor = Color(0xFFF7F5F1);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF7A7A7A);
  static const Color primaryColor = Color(0xFF1A1A1A); // Minimalist black
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color accentGreen = Color(0xFF10B981);
  static const Color accentRed = Color(0xFFEF4444);
  static const Color accentAmber = Color(0xFFF59E0B);

  // Older dark constants for compatibility if needed
  static const Color backgroundColorDark = Color(0xFF0F111A);
  static const Color cardDark = Color(0xFF1A1D2E);
  static const Color primaryLight = Color(0xFF9FA8DA);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1A1A1A), Color(0xFF4A4A4A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

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
      primaryColor: Colors.white,
      scaffoldBackgroundColor: const Color(0xFF0A0A0A),
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
        color: const Color(0xFF141414),
      ),
    );
  }
}
