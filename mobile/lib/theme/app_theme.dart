import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color primary = Color(0xFF1E88E5);
  static const Color primaryDark = Color(0xFF1565C0);
  static const Color primaryLight = Color(0xFFE3F2FD);

  static const Color background = Color(0xFFFBFDFF);
  static const Color cardBg = Colors.white;

  static const Color textMain = Color(0xFF1A1C1E);
  static const Color textSecondary = Color(0xFF6C727A);
  static const Color textPlaceholder = Color(0xFFADB5BD);

  static const Color border = Color(0xFFE9ECEF);

  static const Color success = Color(0xFF00C88C);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // Specific colors from mockup
  static const Color iconBlueBg = Color(0xFFE8F2FF);
  static const Color iconRedBg = Color(0xFFFFE8E8);
  static const Color iconOrangeBg = Color(0xFFFFF4E8);
  static const Color iconGreenBg = Color(0xFFE8FFF4);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.primaryDark,
        surface: AppColors.cardBg,
      ),
      textTheme: GoogleFonts.outfitTextTheme().copyWith(
        displayLarge: GoogleFonts.outfit(
          color: AppColors.textMain,
          fontWeight: FontWeight.w900,
          fontSize: 32,
        ),
        displayMedium: GoogleFonts.outfit(
          color: AppColors.textMain,
          fontWeight: FontWeight.w800,
          fontSize: 26,
        ),
        titleLarge: GoogleFonts.outfit(
          color: AppColors.textMain,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
        bodyLarge: GoogleFonts.outfit(
          color: AppColors.textMain,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        bodyMedium: GoogleFonts.outfit(color: AppColors.textMain, fontSize: 14),
        labelLarge: GoogleFonts.outfit(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          fontSize: 10,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 20,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        hintStyle: GoogleFonts.outfit(
          color: AppColors.textPlaceholder,
          fontWeight: FontWeight.w500,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 64),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
          elevation: 2,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0A0F1A),
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: AppColors.primary,
        secondary: AppColors.primaryDark,
        surface: const Color(0xFF141B2D),
      ),
      textTheme: GoogleFonts.outfitTextTheme(
        ThemeData.dark().textTheme,
      ).copyWith(
        displayLarge: GoogleFonts.outfit(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 32,
        ),
        displayMedium: GoogleFonts.outfit(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 26,
        ),
        titleLarge: GoogleFonts.outfit(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
        bodyLarge: GoogleFonts.outfit(
          color: const Color(0xFFE2E8F0),
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        bodyMedium: GoogleFonts.outfit(
          color: const Color(0xFFCBD5E1),
          fontSize: 14,
        ),
        labelLarge: GoogleFonts.outfit(
          color: const Color(0xFF94A3B8),
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          fontSize: 10,
        ),
      ),
      cardColor: const Color(0xFF141B2D),
      dividerColor: const Color(0xFF1E293B),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF141B2D),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 20,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF1E293B)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF1E293B)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        hintStyle: GoogleFonts.outfit(
          color: const Color(0xFF475569),
          fontWeight: FontWeight.w500,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 64),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
          elevation: 2,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0A0F1A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF0A0F1A),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Color(0xFF475569),
      ),
    );
  }
}
