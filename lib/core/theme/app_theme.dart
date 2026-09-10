import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary Bumblebee Yellows
  static const Color beeYellow = Color(0xFFFFB800);
  static const Color beeYellowLight = Color(0xFFFFD54F);
  static const Color beeYellowDark = Color(0xFFF59E0B);
  static const Color beeYellowSubtle = Color(0xFFFFFBEB);
  static const Color beeYellowGlow = Color(0x33FFB800);

  // Deep Charcoal & Blacks
  static const Color charcoalDark = Color(0xFF0F0F12);
  static const Color charcoalSurface = Color(0xFF18181D);
  static const Color charcoalCard = Color(0xFF22222B);
  static const Color charcoalBorder = Color(0xFF2F2F3D);
  static const Color charcoalMuted = Color(0xFF8E8E9F);
  
  // Clean Whites & Light Grays
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color cleanWhiteOff = Color(0xFFF8FAFC);
  static const Color lightGray = Color(0xFFE2E8F0);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textDark = Color(0xFF1E293B);

  // Status & Accents
  static const Color onlineGreen = Color(0xFF10B981);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color infoBlue = Color(0xFF3B82F6);
}

class AppTheme {
  // Dark Theme (Default Bumblebee aesthetic)
  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.beeYellow,
      scaffoldBackgroundColor: AppColors.charcoalDark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.beeYellow,
        onPrimary: AppColors.charcoalDark,
        primaryContainer: AppColors.beeYellowDark,
        onPrimaryContainer: Colors.white,
        secondary: AppColors.beeYellowLight,
        onSecondary: AppColors.charcoalDark,
        surface: AppColors.charcoalSurface,
        onSurface: AppColors.pureWhite,
        error: AppColors.errorRed,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.charcoalDark,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.pureWhite),
        titleTextStyle: GoogleFonts.outfit(
          color: AppColors.pureWhite,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardTheme(
        color: AppColors.charcoalSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.charcoalBorder, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.beeYellow,
          foregroundColor: AppColors.charcoalDark,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.beeYellow,
          side: const BorderSide(color: AppColors.beeYellow, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.charcoalSurface,
        hintStyle: GoogleFonts.outfit(color: AppColors.charcoalMuted, fontSize: 15),
        labelStyle: GoogleFonts.outfit(color: AppColors.beeYellow, fontSize: 15),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.charcoalBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.charcoalBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.beeYellow, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.errorRed, width: 1),
        ),
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.pureWhite),
        displayMedium: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.pureWhite),
        titleLarge: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.pureWhite),
        titleMedium: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.pureWhite),
        titleSmall: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.charcoalMuted),
        bodyLarge: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.pureWhite),
        bodyMedium: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.pureWhite.withOpacity(0.9)),
        bodySmall: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.charcoalMuted),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.charcoalBorder,
        thickness: 1,
        space: 24,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.charcoalSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
    );
  }
}
