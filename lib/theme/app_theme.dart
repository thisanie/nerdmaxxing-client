import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // ---- Dark theme (primary) ----
  static const background = Color(0xFF0F0F0E); // near-black charcoal
  static const surface = Color(
    0xFF161615,
  ); // one step up from bg, for sheets/top bars only
  static const surfaceAlt = Color(0xFF1B1B19); // inputs, slightly lifted
  static const primary = Color(0xFFC8FF2E); // acid lime — the one accent
  static const primaryLight = Color(
    0xFF6E8A1E,
  ); // lime, dimmed for light-theme legibility
  static const accent = Color(
    0xFFFFAB3D,
  ); // amber — reserved for warnings/gates only
  static const puzzle = Color(
    0xFFFF7A3D,
  ); // ember — secondary accent, used sparingly (e.g. "trending")
  static const primaryMuted = Color(
    0xFF232414,
  ); // lime at ~14% over bg, for wash fills behind lime text
  static const textPrimary = Color(0xFFECEBE3); // off-white
  static const textSecondary = Color(0xFF8C8C84); // muted gray
  static const textDim = Color(0xFF5A5A53); // faint metadata / disabled
  static const border = Color(0xFF2C2C2A); // hairline, ~13% ink over bg
  static const borderStrong = Color(
    0xFF444441,
  ); // ~24% ink over bg, for emphasis rules
  static const success = Color(0xFFC8FF2E);
  static const dark = Color(0xFF0B0C05); // text-on-lime
  static const warning = Color(0xFFFFAB3D);
  static const danger = Color(0xFFE8556B);
  static const ink = Color(0xFF0B0C05);

  // ---- Light theme ----
  static const lightBackground = Color(0xFFF7F7F2);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceAlt = Color(0xFFECEBE2);
  static const lightTextPrimary = Color(0xFF14140F);
  static const lightTextSecondary = Color(0xFF5C5C53);
  static const lightBorder = Color(0xFFD9D8CC);
  static const lightPrimary = Color(0xff16803C); // deep lime, 6:1+ on white
  static const limeWash = Color(
    0xFFE6F3B0,
  ); // pale lime chip/tile fill on light

  // Rank/difficulty scale — keep it inside the same restrained palette
  // rather than a generic green/orange/red traffic light.
  static const difficultyBeginner = Color(0xFFC8FF2E); // lime
  static const difficultyIntermediate = Color(0xFFFFAB3D); // amber
  static const difficultyAdvanced = Color(0xFFFF6B57); // ember-red
}

/// Home-screen palette tokens taken from the dark and light HTML prototypes.
class HomePalette {
  static const primary = Color(0xFFCFFF47);
  static const bright = Color(0xFFC3FD3F);
  static const mint = Color(0xFF9FF1C0);
  static const ink = Color(0xFF0B0C05);
  static const peach = Color(0xFFFFDCC6);
  static const peachTextLight = Color(0xFF8A4A1F);
  static const lightLink = Color(0xFF4F6B00);
  static const imageText = Color(0xFFECEBE3);
  static const resumeRingFill = Color(0xFFD9FFA0);
  static const imageOverlay = Color(0xEB0F0F0E);
  static const pausedDarkBackground = Color(0xFF4A3B12);
  static const pausedDarkText = Color(0xFFFFD98A);
  static const pausedLightBackground = Color(0xFFFFE7A3);
  static const pausedLightText = Color(0xFF7A5A00);

  static const darkBackground = Color(0xFF0F0F0E);
  static const darkSurface = Color(0xFF161615);
  static const darkSurfaceAlt = Color(0xFF1B1B19);
  static const darkPrimaryMuted = Color(0xFF252B16);
  static const darkTextPrimary = Color(0xFFECEBE3);
  static const darkTextSecondary = Color(0xFF8C8C84);
  static const darkBorder = Color(0xFF2C2C2A);
  static const darkBorderStrong = Color(0xFF444441);
  static const darkPeachWash = Color(0xFF33271F);

  static const lightBackground = Color(0xFFFFFFFF);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceAlt = Color(0xFFF7F7F2);
  static const lightPrimaryMuted = Color(0xFFF4FABE);
  static const lightTextPrimary = Color(0xFF101008);
  static const lightTextSecondary = Color(0xFF5C5C53);
  static const lightBorder = Color(0xFFE5E5DC);

  static const challengePurple = Color(0xFF7B5CC4);
  static const challengePurpleDeep = Color(0xFF2A1A4D);
  static const challengeGreen = Color(0xFF3AA57A);
  static const challengeGreenDeep = Color(0xFF0F3324);
  static const challengeEmber = Color(0xFFE0894A);
  static const challengeEmberDeep = Color(0xFF47200C);
  static const challengeBlue = Color(0xFF4A8FD8);
  static const challengeBlueDeep = Color(0xFF0F2A47);

  static Color background(Brightness brightness) => brightness == Brightness.dark
      ? darkBackground
      : lightBackground;

  static Color surface(Brightness brightness) => brightness == Brightness.dark
      ? darkSurface
      : lightSurface;

  static Color surfaceAlt(Brightness brightness) =>
      brightness == Brightness.dark ? darkSurfaceAlt : lightSurfaceAlt;

  static Color primaryMuted(Brightness brightness) =>
      brightness == Brightness.dark ? darkPrimaryMuted : lightPrimaryMuted;

  static Color textPrimary(Brightness brightness) =>
      brightness == Brightness.dark ? darkTextPrimary : lightTextPrimary;

  static Color textSecondary(Brightness brightness) =>
      brightness == Brightness.dark ? darkTextSecondary : lightTextSecondary;

  static Color border(Brightness brightness) =>
      brightness == Brightness.dark ? darkBorder : lightBorder;

  static Color borderStrong(Brightness brightness) =>
      brightness == Brightness.dark ? darkBorderStrong : lightBorder;

  static Color peachWash(Brightness brightness) =>
      brightness == Brightness.dark ? darkPeachWash : peach;

  static Color peachText(Brightness brightness) =>
      brightness == Brightness.dark ? peach : peachTextLight;

  static Color link(Brightness brightness) =>
      brightness == Brightness.dark ? primary : lightLink;

  static Color rankText(Brightness brightness) =>
      brightness == Brightness.dark ? primary : ink;

  static List<Color> challengeGradient(String title) {
    final normalized = title.toLowerCase();
    if (normalized.contains('fire')) {
      return const [challengeGreen, challengeGreenDeep];
    }
    if (normalized.contains('plank') || normalized.contains('lift')) {
      return const [challengeBlue, challengeBlueDeep];
    }
    if (normalized.contains('handstand') || normalized.contains('juggle')) {
      return const [challengePurple, challengePurpleDeep];
    }
    return const [challengeEmber, challengeEmberDeep];
  }
}

/// Font roles, matching the HTML prototypes:
///  - display (Bricolage Grotesque): headlines, section titles, and the big
///    poster numerals ("60", "42 WPM"). Bricolage ships as a variable font
///    with a width axis, which is what gives the numerals their tight,
///    slightly compressed "poster" look.
///  - body (Instrument Sans): paragraphs, labels, buttons, form fields.
class AppFonts {
  static TextStyle home({
    required Color color,
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w400,
    double? height,
    double letterSpacingEm = 0,
  }) {
    return GoogleFonts.inter(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacingEm * fontSize,
    );
  }

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
    primary: AppColors.lightPrimary,
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
    final textTheme = GoogleFonts.instrumentSansTextTheme(base.textTheme)
        .copyWith(
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
        surfaceContainerHighest: surfaceAlt,
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
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
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 16,
        ),
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
        unselectedLabelStyle: AppFonts.label(
          color: textSecondary,
          fontSize: 10,
        ),
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
