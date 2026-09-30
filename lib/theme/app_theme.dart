import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // ---- Dark theme (primary) ----
  static const background = Color(0xFF0F0F0E);      // near-black charcoal
  static const surface = Color(0xFF161615);          // one step up from bg, for sheets/top bars only
  static const surfaceAlt = Color(0xFF1B1B19);        // inputs, slightly lifted
  static const primary = Color(0xFFC8FF2E);           // acid lime — the one accent
  static const primaryLight = Color(0xFF6E8A1E);       // lime, dimmed for light-theme legibility
  static const accent = Color(0xFFFFAB3D);            // amber — reserved for warnings/gates only
  static const puzzle = Color(0xFFFF7A3D);            // ember — secondary accent, used sparingly (e.g. "trending")
  static const primaryMuted = Color(0xFF232414);        // lime at ~14% over bg, for wash fills behind lime text
  static const textPrimary = Color(0xFFECEBE3);        // off-white
  static const textSecondary = Color(0xFF8C8C84);       // muted gray
  static const textDim = Color(0xFF5A5A53);            // faint metadata / disabled
  static const border = Color(0xFF2C2C2A);            // hairline, ~13% ink over bg
  static const borderStrong = Color(0xFF444441);        // ~24% ink over bg, for emphasis rules
  static const success = Color(0xFFC8FF2E);
  static const dark = Color(0xFF0B0C05);              // text-on-lime
  static const warning = Color(0xFFFFAB3D);
  static const danger = Color(0xFFE8556B);

  // ---- Light theme ----
  static const lightBackground = Color(0xFFFAFAF6);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceAlt = Color(0xFFF0EFE9);
  static const lightTextPrimary = Color(0xFF111110);
  static const lightTextSecondary = Color(0xFF77776E);
  static const lightBorder = Color(0xFFE6E5DC);
  static const limeWash = Color(0xFFEEF8C4);          // pale lime chip/tile fill on light

  // Rank/difficulty scale — keep it inside the same restrained palette
  // rather than a generic green/orange/red traffic light.
  static const difficultyBeginner = Color(0xFFC8FF2E);     // lime
  static const difficultyIntermediate = Color(0xFFFFAB3D); // amber
  static const difficultyAdvanced = Color(0xFFFF6B57);     // ember-red
}

/// Font roles, matching the HTML prototypes:
///  - display (Bricolage Grotesque): headlines, section titles, and the big
///    poster numerals ("60", "42 WPM"). Bricolage ships as a variable font
///    with a width axis, which is what gives the numerals their tight,
///    slightly compressed "poster" look.
///  - body (Instrument Sans): paragraphs, labels, buttons, form fields.
class AppFonts {
  static TextStyle display({
    required Color color,
    double fontSize = 20,
    FontWeight fontWeight = FontWeight.w700,
    double? height,
    double letterSpacingEm = -0.02,
    double wdth = 100,
  }) {
    return GoogleFonts.bricolageGrotesque(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacingEm * fontSize,
    ).copyWith(
      // Only takes effect if the variable-font asset is loaded (see note in
      // pubspec below); GoogleFonts falls back to the nearest static cut
      // otherwise, which is still fine for anything except the very large
      // poster numerals.
      fontVariations: [FontVariation('wdth', wdth)],
    );
  }

  /// The big poster numerals — "60", "42 WPM", giant challenge goals.
  /// Always call with an explicit [fontSize]; these are meant to be huge.
  static TextStyle poster({
    required double fontSize,
    Color color = AppColors.textPrimary,
    double wdth = 75,
    double height = 0.9,
  }) {
    return display(
      color: color,
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      height: height,
      letterSpacingEm: -0.05,
      wdth: wdth,
    ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
  }

  static TextStyle body({
    required Color color,
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w400,
    double height = 1.4,
    double letterSpacingEm = 0,
  }) {
    return GoogleFonts.instrumentSans(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacingEm * fontSize,
    );
  }

  /// Small uppercase metadata labels ("ACTIVE", "RANK", "TYPING").
  /// Remember to also call `.toUpperCase()` on the string itself.
  static TextStyle label({
    Color color = AppColors.textSecondary,
    double fontSize = 11,
    FontWeight fontWeight = FontWeight.w500,
  }) {
    return body(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacingEm: 0.12,
    );
  }
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
        primary: AppColors.lightTextPrimary,
        textPrimary: AppColors.lightTextPrimary,
        textSecondary: AppColors.lightTextSecondary,
        border: AppColors.lightBorder,
        onPrimary: AppColors.lightSurface,
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

    // Base text theme in Instrument Sans (body copy), with the display
    // roles overridden to Bricolage Grotesque below.
    final textTheme = GoogleFonts.instrumentSansTextTheme(base.textTheme).copyWith(
      // Poster-scale display numerals. Compose with AppFonts.poster() at
      // point of use for anything larger than this (e.g. the giant "60").
      displayLarge: AppFonts.display(
        color: textPrimary,
        fontSize: 64,
        fontWeight: FontWeight.w800,
        height: 0.85,
        letterSpacingEm: -0.05,
        wdth: 75,
      ),
      headlineMedium: AppFonts.display(
        color: textPrimary,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.0,
        letterSpacingEm: -0.03,
        wdth: 88,
      ),
      headlineSmall: AppFonts.display(
        color: textPrimary,
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1.02,
        letterSpacingEm: -0.02,
        wdth: 90,
      ),
      titleLarge: AppFonts.display(
        color: textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.15,
        letterSpacingEm: -0.015,
        wdth: 92,
      ),
      titleMedium: AppFonts.display(
        color: textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.15,
        letterSpacingEm: -0.01,
        wdth: 95,
      ),
      bodyMedium: AppFonts.body(color: textSecondary, fontSize: 15),
      bodyLarge: AppFonts.body(color: textPrimary, fontSize: 16),
      bodySmall: AppFonts.body(color: textSecondary, fontSize: 13),
      labelSmall: AppFonts.label(color: textSecondary),
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
        titleTextStyle: AppFonts.display(
          color: textPrimary,
          fontSize: 21,
          fontWeight: FontWeight.w700,
          letterSpacingEm: -0.02,
        ),
      ),
      // Flatter, hairline-bordered surfaces instead of soft rounded cards —
      // radius 3 reads as "structure," not a SaaS card kit.
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: subtleBorder),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          // Buttons use body font, uppercase + tracked, per the prototype's
          // ".btn" style — not the display font.
          textStyle: AppFonts.body(
            color: onPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacingEm: 0.09,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: AppFonts.body(
            color: onPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacingEm: 0.09,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: border),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: AppFonts.body(
            color: textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacingEm: 0.06,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        hintStyle: AppFonts.body(color: textSecondary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: AppFonts.label(color: primary, fontSize: 10),
        unselectedLabelStyle: AppFonts.label(color: textSecondary, fontSize: 10),
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