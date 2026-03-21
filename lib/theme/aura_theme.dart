import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'aura_tokens.dart';

// ════════════════════════════════════════════════════════════════════════
//  AURA Color Palette — brand-locked, no modifications allowed
// ════════════════════════════════════════════════════════════════════════

/// Semantic color roles resolved per theme mode.
/// Colors are referenced from the palette defined herein.
class AuraColors {
  // ── Brand palette (immutable) ─────────────────────────────────────
  // These 6 values form the entire visual identity.

  /// Deep space black — primary background (dark)
  static const Color spaceDark    = Color(0xFF0B0D10);

  /// Charcoal surface — cards, drawers, app bars (dark)
  static const Color charcoal     = Color(0xFF1C1F26);

  /// Elevated surface — slightly lighter for layered elements (dark)
  static const Color charcoalLift = Color(0xFF252830);

  /// Cool grey — secondary text, icons, borders
  static const Color coolGrey     = Color(0xFF6B7280);

  /// Muted grey — tertiary text
  static const Color mutedGrey    = Color(0xFF9CA3AF);

  /// Ice blue — primary accent, headings, CTA
  static const Color iceBlue      = Color(0xFFD9DFF0);

  /// Near-white — high-emphasis text
  static const Color frost        = Color(0xFFE6EAF5);

  // ── Light theme palette (derived from brand) ──────────────────────

  /// Light background — soft neutral
  static const Color lightBg      = Color(0xFFF5F6FA);

  /// Light surface — white with slight warmth
  static const Color lightSurface = Color(0xFFFFFFFF);

  /// Light elevated — subtle grey
  static const Color lightElevated = Color(0xFFF0F1F5);

  /// Dark text — near-black for light backgrounds
  static const Color darkText     = Color(0xFF1A1C22);

  /// Medium text — secondary on light backgrounds
  static const Color mediumText   = Color(0xFF4B5563);

  /// Light muted — tertiary text on light backgrounds
  static const Color lightMuted   = Color(0xFF6B7280);

  /// Light accent — slightly saturated ice blue
  static const Color lightAccent  = Color(0xFF3B4A6B);

  /// Light accent alt — for buttons / CTAs on light
  static const Color lightAccentAlt = Color(0xFF2C3751);
}

// ════════════════════════════════════════════════════════════════════════
//  Theme-aware color resolver
// ════════════════════════════════════════════════════════════════════════

/// Returns semantic colors resolved for the given brightness.
class AuraThemeColors {
  final Brightness brightness;

  const AuraThemeColors._(this.brightness);

  factory AuraThemeColors.of(BuildContext context) {
    return AuraThemeColors._(Theme.of(context).brightness);
  }

  bool get isDark => brightness == Brightness.dark;

  Color get background     => isDark ? AuraColors.spaceDark    : AuraColors.lightBg;
  Color get surface        => isDark ? AuraColors.charcoal     : AuraColors.lightSurface;
  Color get surfaceElevated => isDark ? AuraColors.charcoalLift : AuraColors.lightElevated;
  Color get textPrimary    => isDark ? AuraColors.frost         : AuraColors.darkText;
  Color get textSecondary  => isDark ? AuraColors.mutedGrey     : AuraColors.mediumText;
  Color get textTertiary   => isDark ? AuraColors.coolGrey      : AuraColors.lightMuted;
  Color get accent         => isDark ? AuraColors.iceBlue       : AuraColors.lightAccentAlt;
  Color get accentSoft     => isDark ? AuraColors.iceBlue       : AuraColors.lightAccent;
  Color get border         => isDark
      ? AuraColors.coolGrey.withOpacity(0.15)
      : AuraColors.coolGrey.withOpacity(0.12);
  Color get divider        => isDark
      ? AuraColors.coolGrey.withOpacity(0.4)
      : AuraColors.coolGrey.withOpacity(0.2);
  Color get iconDefault    => isDark ? AuraColors.coolGrey : AuraColors.mediumText;
  Color get micButton      => isDark ? AuraColors.iceBlue  : AuraColors.lightAccentAlt;
  Color get micIcon        => isDark ? AuraColors.spaceDark : AuraColors.lightBg;
  Color get shimmer        => isDark
      ? AuraColors.iceBlue.withOpacity(0.06)
      : AuraColors.lightAccent.withOpacity(0.06);
}

// ════════════════════════════════════════════════════════════════════════
//  ThemeData builders
// ════════════════════════════════════════════════════════════════════════

ThemeData buildAuraDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Poppins',
    scaffoldBackgroundColor: AuraColors.spaceDark,
    canvasColor: AuraColors.charcoal,

    colorScheme: const ColorScheme.dark(
      primary: AuraColors.iceBlue,
      onPrimary: AuraColors.spaceDark,
      secondary: AuraColors.coolGrey,
      onSecondary: AuraColors.frost,
      surface: AuraColors.charcoal,
      onSurface: AuraColors.frost,
      error: Color(0xFFCF6679),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: AuraColors.charcoal,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 2,
        color: AuraColors.frost,
      ),
      iconTheme: IconThemeData(color: AuraColors.coolGrey, size: 24),
    ),

    drawerTheme: const DrawerThemeData(
      backgroundColor: AuraColors.charcoal,
      scrimColor: Colors.black54,
    ),

    dividerTheme: DividerThemeData(
      color: AuraColors.coolGrey.withOpacity(0.3),
      thickness: 0.5,
      space: 0,
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: AuraColors.charcoalLift,
      contentTextStyle: AuraTypography.bodySmall(AuraColors.frost),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: AuraRadius.mdBr),
      elevation: 4,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AuraColors.charcoal,
      shape: RoundedRectangleBorder(borderRadius: AuraRadius.lgBr),
      titleTextStyle: AuraTypography.titleMedium(AuraColors.frost),
      contentTextStyle: AuraTypography.bodyMedium(AuraColors.mutedGrey),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AuraColors.charcoal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AuraRadius.lg)),
      ),
      elevation: 8,
    ),

    sliderTheme: SliderThemeData(
      trackHeight: 3,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      activeTrackColor: AuraColors.iceBlue,
      inactiveTrackColor: AuraColors.coolGrey.withOpacity(0.25),
      thumbColor: AuraColors.iceBlue,
      overlayColor: AuraColors.iceBlue.withOpacity(0.12),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AuraColors.iceBlue,
        foregroundColor: AuraColors.spaceDark,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpacing.xl,
          vertical: AuraSpacing.md,
        ),
        shape: RoundedRectangleBorder(borderRadius: AuraRadius.smBr),
        textStyle: AuraTypography.button(AuraColors.spaceDark),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AuraColors.mutedGrey,
        textStyle: AuraTypography.button(AuraColors.mutedGrey),
        shape: RoundedRectangleBorder(borderRadius: AuraRadius.smBr),
      ),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AuraColors.iceBlue,
    ),

    iconTheme: const IconThemeData(
      color: AuraColors.coolGrey,
      size: 24,
    ),
  );
}

ThemeData buildAuraLightTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Poppins',
    scaffoldBackgroundColor: AuraColors.lightBg,
    canvasColor: AuraColors.lightSurface,

    colorScheme: const ColorScheme.light(
      primary: AuraColors.lightAccentAlt,
      onPrimary: AuraColors.lightBg,
      secondary: AuraColors.mediumText,
      onSecondary: AuraColors.lightBg,
      surface: AuraColors.lightSurface,
      onSurface: AuraColors.darkText,
      error: Color(0xFFB00020),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: AuraColors.lightSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 2,
        color: AuraColors.darkText,
      ),
      iconTheme: IconThemeData(color: AuraColors.mediumText, size: 24),
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),

    drawerTheme: const DrawerThemeData(
      backgroundColor: AuraColors.lightSurface,
      scrimColor: Colors.black26,
    ),

    dividerTheme: DividerThemeData(
      color: AuraColors.coolGrey.withOpacity(0.15),
      thickness: 0.5,
      space: 0,
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: AuraColors.darkText,
      contentTextStyle: AuraTypography.bodySmall(AuraColors.lightBg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: AuraRadius.mdBr),
      elevation: 4,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AuraColors.lightSurface,
      shape: RoundedRectangleBorder(borderRadius: AuraRadius.lgBr),
      titleTextStyle: AuraTypography.titleMedium(AuraColors.darkText),
      contentTextStyle: AuraTypography.bodyMedium(AuraColors.mediumText),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AuraColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AuraRadius.lg)),
      ),
      elevation: 8,
    ),

    sliderTheme: SliderThemeData(
      trackHeight: 3,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      activeTrackColor: AuraColors.lightAccentAlt,
      inactiveTrackColor: AuraColors.coolGrey.withOpacity(0.20),
      thumbColor: AuraColors.lightAccentAlt,
      overlayColor: AuraColors.lightAccent.withOpacity(0.12),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AuraColors.lightAccentAlt,
        foregroundColor: AuraColors.lightBg,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpacing.xl,
          vertical: AuraSpacing.md,
        ),
        shape: RoundedRectangleBorder(borderRadius: AuraRadius.smBr),
        textStyle: AuraTypography.button(AuraColors.lightBg),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AuraColors.mediumText,
        textStyle: AuraTypography.button(AuraColors.mediumText),
        shape: RoundedRectangleBorder(borderRadius: AuraRadius.smBr),
      ),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AuraColors.lightAccentAlt,
    ),

    iconTheme: const IconThemeData(
      color: AuraColors.mediumText,
      size: 24,
    ),
  );
}

