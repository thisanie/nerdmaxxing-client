import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const background = Color(0xFF15160F);
  static const surface = Color(0xFF1F2117);
  static const surfaceAlt = Color(0xFF1F2117);
  static const primary = Color(0xFFC7EA5C);
  static const primaryLight = Color(0xFF7FAE1A);
  static const accent = Color(0xFF38BDF8);
  static const puzzle = Color(0xFFA78BFA);
  static const primaryMuted = Color(0xFFA9D732);
  static const textPrimary = Color(0xFFF3F2E9);
  static const textSecondary = Color(0xFF9A9C8E);
  static const border = Color(0xFF34362A);
  static const success = Color(0xFFC7EA5C);
  static const dark = Color(0xFF0A0B07);
  static const warning = Color(0xFFFACC15);
  static const danger = Color(0xFFE85D75);
  static const lightBackground = Color(0xFFF7F8F4);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceAlt = Color(0xFFEFF1EC);
  static const lightTextPrimary = Color(0xFF101315);
  static const lightTextSecondary = Color(0xFF626A70);
  static const lightBorder = Color(0xFFDDE1DC);

  static const difficultyBeginner = Color(0xFF8CCF21);
  static const difficultyIntermediate = Color(0xFFFB923C);
  static const difficultyAdvanced = Color(0xFFFB7185);
}

class AppTheme {
  static ThemeData get dark => _buildTheme(
        brightness: Brightness.dark,
        background: AppColors.background,
        surface: AppColors.surface,
        surfaceAlt: AppColors.surfaceAlt,
        primary: AppColors.primary,
        textPrimary: AppColors.textPrimary,
        textSecondary: AppColors.textSecondary,
        border: AppColors.border,
        onPrimary: AppColors.dark,
      );

  static ThemeData get light => _buildTheme(
        brightness: Brightness.light,
        background: AppColors.lightBackground,
        surface: AppColors.lightSurface,
        surfaceAlt: AppColors.lightSurfaceAlt,
        primary: AppColors.primaryLight,
        textPrimary: AppColors.lightTextPrimary,
        textSecondary: AppColors.lightTextSecondary,
        border: AppColors.lightBorder,
        onPrimary: AppColors.lightTextPrimary,
      );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color surfaceAlt,
    required Color primary,
    required Color textPrimary,
    required Color textSecondary,
    required Color border,
    required Color onPrimary,
  }) {
    final subtleBorder = border.withValues(alpha: 0.6);
    final base = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
        surface: surface,
        onSurface: textPrimary,
        primary: primary,
        onPrimary: onPrimary,
        error: AppColors.danger,
      ),
    );
    final textTheme = GoogleFonts.spaceGroteskTextTheme(base.textTheme).copyWith(
      headlineMedium: GoogleFonts.spaceGrotesk(
        color: textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 32,
        height: 1.15,
      ),
      headlineSmall: GoogleFonts.spaceGrotesk(
        color: textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 26,
      ),
      titleLarge: GoogleFonts.spaceGrotesk(
        color: textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 20,
      ),
      titleMedium: GoogleFonts.spaceGrotesk(
        color: textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 17,
      ),
      bodyMedium: GoogleFonts.spaceGrotesk(
        color: textSecondary,
        fontSize: 15,
        height: 1.4,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: base.colorScheme.copyWith(
        primary: primary,
        onPrimary: onPrimary,
        surface: surface,
        onSurface: textPrimary,
        onSurfaceVariant: textSecondary,
        outline: subtleBorder,
        error: AppColors.danger,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          color: textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 21,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: subtleBorder),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: border),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        hintStyle: TextStyle(color: textSecondary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerColor: border,
    );
  }

  static Color difficultyColor(String level) {
    switch (level) {
      case 'BEGINNER':
        return AppColors.difficultyBeginner;
      case 'INTERMEDIATE':
        return AppColors.difficultyIntermediate;
      case 'ADVANCED':
        return AppColors.difficultyAdvanced;
      default:
        return AppColors.textSecondary;
    }
  }
}
