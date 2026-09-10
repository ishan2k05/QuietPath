import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class QuietColors {
  // Primary (Sage Green)
  static const Color primary = Color(0xFF8BB174);
  static const Color primaryDark = Color(0xFF385A27);
  static const Color primaryLight = Color(0xFFE5EFE0);

  // Secondary (Lavender)
  static const Color secondary = Color(0xFFB5A8D5);
  static const Color secondaryDark = Color(0xFF4E426D);
  static const Color secondaryLight = Color(0xFFF1EEF8);

  // Tertiary (Muted Teal / Eucalyptus)
  static const Color tertiary = Color(0xFF6A9C89);
  static const Color tertiaryDark = Color(0xFF244E41);
  static const Color tertiaryLight = Color(0xFFE3EFEA);

  // Neutral (Calm light / charcoal)
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textCharcoal = Color(0xFF2B2D2F);
  static const Color textMuted = Color(0xFF6C757D);
  static const Color borderLight = Color(0xFFE5E7EB);

  // Indicators / Badges
  static const Color tagSilence = Color(0xFFB5A8D5);
  static const Color tagNatural = Color(0xFFE8EEF5);
  static const Color capacityEmpty = Color(0xFF4E9F86);
  static const Color capacityLow = Color(0xFF8BB174);
  static const Color capacityModerate = Color(0xFFE0A855);
  static const Color alertRed = Color(0xFFB83232);
}

class QuietPathTheme {
  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.interTextTheme().copyWith(
      headlineLarge: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: QuietColors.textCharcoal,
        letterSpacing: -0.5,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: QuietColors.textCharcoal,
        letterSpacing: -0.3,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: QuietColors.textCharcoal,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: QuietColors.textCharcoal,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: QuietColors.textMuted,
        height: 1.4,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: QuietColors.textCharcoal,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: QuietColors.textMuted,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: QuietColors.background,
      colorScheme: const ColorScheme.light(
        primary: QuietColors.primary,
        secondary: QuietColors.secondary,
        tertiary: QuietColors.tertiary,
        surface: QuietColors.surface,
        onPrimary: Colors.white,
        onSecondary: QuietColors.textCharcoal,
        onSurface: QuietColors.textCharcoal,
      ),
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: QuietColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: QuietColors.borderLight, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: QuietColors.primaryDark,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
