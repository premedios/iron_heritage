import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Forge Color Palette
  static const Color background = Color(0xFF121415);
  static const Color surface = Color(0xFF1E2022);
  static const Color primaryAccent = Color(0xFFC8102E); // Forge Red
  static const Color textPrimary = Color(0xFFECEFF1);
  static const Color textSecondary = Color(0xFFB0BEC5);

  static ThemeData get darkTheme {
    final base = ThemeData.dark();

    // Use Inter as the base text theme
    final baseTextTheme = GoogleFonts.interTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primaryAccent,
        surface: surface,
        onSurface: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.bebasNeue(
          fontSize: 28,
          color: textPrimary,
          letterSpacing: 1.2,
        ),
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.bebasNeue(
          textStyle: baseTextTheme.displayLarge,
          color: textPrimary,
          letterSpacing: 1.2,
        ),
        displayMedium: GoogleFonts.bebasNeue(
          textStyle: baseTextTheme.displayMedium,
          color: textPrimary,
          letterSpacing: 1.2,
        ),
        displaySmall: GoogleFonts.bebasNeue(
          textStyle: baseTextTheme.displaySmall,
          color: textPrimary,
          letterSpacing: 1.2,
        ),
        headlineLarge: GoogleFonts.bebasNeue(
          textStyle: baseTextTheme.headlineLarge,
          color: textPrimary,
          letterSpacing: 1.2,
        ),
        headlineMedium: GoogleFonts.bebasNeue(
          textStyle: baseTextTheme.headlineMedium,
          color: textPrimary,
          letterSpacing: 1.2,
        ),
        headlineSmall: GoogleFonts.bebasNeue(
          textStyle: baseTextTheme.headlineSmall,
          color: textPrimary,
          letterSpacing: 1.2,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: textPrimary),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: textPrimary),
        bodySmall: baseTextTheme.bodySmall?.copyWith(color: textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryAccent,
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryAccent,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
