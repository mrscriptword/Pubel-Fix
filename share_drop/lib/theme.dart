import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors – deep space violet palette
  static const Color primaryColor   = Color(0xFF7C4DFF);
  static const Color primaryLight   = Color(0xFFB47CFF);
  static const Color primaryDark    = Color(0xFF4A00C8);
  static const Color accentColor    = Color(0xFF00E5FF);
  static const Color accentGreen    = Color(0xFF00E676);

  static const Color backgroundColorDark = Color(0xFF080B1A);
  static const Color surfaceDark    = Color(0xFF111327);
  static const Color cardDark       = Color(0xFF181B30);
  static const Color surfaceColor   = Color(0xFFF4F5FF);
  static const Color cardColor      = Colors.white;
  static const Color textPrimary    = Color(0xFF0F1022);
  static const Color textSecondary  = Color(0xFF7A7B9A);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF7C4DFF), Color(0xFF00B4D8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF0D0F2B), Color(0xFF1A1040), Color(0xFF0D0F2B)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF080B1A), Color(0xFF111327)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF00E5FF), Color(0xFF00B4D8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: primaryColor,
      scaffoldBackgroundColor: surfaceColor,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: accentColor,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 20,
      ),
    );
  }
}
