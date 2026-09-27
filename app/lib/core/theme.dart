import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for the "tech dashboard" redesign. Dark-first: a resident
/// checking this at 3am during a storm shouldn't get a blast of white
/// light, and the deep background is what makes the risk-state glow
/// colours (the whole point of the redesign) actually read as glowing.
class AppColors {
  AppColors._();

  static const bgTop = Color(0xFF0A0F1E);
  static const bgBottom = Color(0xFF050810);
  static const surface = Color(0xFF121A2E);
  static const surfaceRaised = Color(0xFF1A2338);
  static const hairline = Color(0x1AFFFFFF); // white @ 10% — soft "frosted glass" edge, not a hard line
  static const textPrimary = Color(0xFFF3F5FA);
  static const textSecondary = Color(0xFF97A2B8);
  static const textMuted = Color(0xFF616E85);

  /// Electric blue — the "tech" accent for non-hazard chrome (nav, links,
  /// the device-location marker). Deliberately distinct from the hazard
  /// palette below so a glance never confuses "this is SIAGA" with
  /// "this is a warning."
  static const accent = Color(0xFF3D8BFF);
  static const accentSoft = Color(0xFF1B2E52);

  // Risk-state palette — see riskStateColor() in widgets/risk_badge.dart,
  // which is the single place these are actually consumed. Brighter than
  // stock Material tones on purpose: muted "material light" colours (the
  // old #2E7D32/#F9A825/#EF6C00/#C62828 set) read as muddy on a near-black
  // background, and this app needs each state legible at a glance.
  static const normal = Color(0xFF34D399);
  static const watch = Color(0xFFFBBF24);
  static const warning = Color(0xFFFB923C);
  static const evacuate = Color(0xFFF43F5E);
}

class AppRadius {
  AppRadius._();
  static const sm = 12.0;
  static const md = 18.0;
  static const lg = 24.0;
  static const pill = 999.0;
}

/// Command-center typography: exactly two families, each with one job.
///
/// Plus Jakarta Sans is the ONLY sans in the app — every header, label,
/// button, hazard message and settings row uses it (via the global
/// textTheme below, or AppFonts.heading() for display-weight text). It
/// replaces an earlier mix of Manrope (body) and Rajdhani (headings),
/// which was two typefaces doing the same job and reading as inconsistent
/// rather than deliberate.
///
/// JetBrains Mono is reserved *strictly* for live telemetry: sensor
/// readings, coordinates, and timestamps — the numbers a district officer
/// would actually verify against the raw feed. It must never be used for
/// a proper noun, a category label, or prose (a node's name or a unit
/// caption like "tips since last tx" is not telemetry, and setting it in
/// monospace reads as a mistake, not a style choice).
class AppFonts {
  AppFonts._();

  static TextStyle heading({
    double fontSize = 20,
    FontWeight fontWeight = FontWeight.w700,
    Color color = AppColors.textPrimary,
    double letterSpacing = 0.1,
  }) =>
      GoogleFonts.plusJakartaSans(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: 1.15,
      );

  static TextStyle mono({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w600,
    Color color = AppColors.textPrimary,
    double letterSpacing = 0.2,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
      );
}

/// A soft colour-matched "glow" shadow — the dark-theme equivalent of a
/// drop shadow. Plain black shadows barely register against a background
/// this dark, so depth here comes from a blurred, low-alpha halo in the
/// element's own accent colour instead.
List<BoxShadow> appGlow(Color color, {double alpha = 0.35, double blur = 28}) {
  return [
    BoxShadow(color: color.withValues(alpha: alpha), blurRadius: blur, spreadRadius: -6, offset: const Offset(0, 10)),
  ];
}

class SiagaTheme {
  SiagaTheme._();

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bgBottom,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surface,
        primary: AppColors.accent,
        secondary: AppColors.accent,
        error: AppColors.evacuate,
      ),
    );

    final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.textPrimary,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.hairline),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.hairline, space: 32),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        indicatorColor: AppColors.accent.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            letterSpacing: 0.2,
            color: selected ? AppColors.accent : AppColors.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? AppColors.accent : AppColors.textSecondary);
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceRaised,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textMuted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.accent : AppColors.surfaceRaised,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.accent : AppColors.textMuted,
        ),
      ),
      listTileTheme: const ListTileThemeData(iconColor: AppColors.textSecondary),
    );
  }
}
