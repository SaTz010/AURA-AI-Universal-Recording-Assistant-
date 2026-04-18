import 'package:flutter/material.dart';

// ════════════════════════════════════════════════════════════════════════
//  AURA Design Tokens — Single source of truth for all visual properties
// ════════════════════════════════════════════════════════════════════════

/// Spacing scale (4-point grid)
class AuraSpacing {
  AuraSpacing._();
  static const double xxs = 2;
  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 12;
  static const double base = 16;
  static const double lg  = 20;
  static const double xl  = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double huge = 48;
  static const double massive = 64;
}

/// Border radii
class AuraRadius {
  AuraRadius._();
  static const double xs   = 4;
  static const double sm   = 8;
  static const double md   = 12;
  static const double lg   = 16;
  static const double xl   = 20;
  static const double full = 999;

  static BorderRadius get xsBr   => BorderRadius.circular(xs);
  static BorderRadius get smBr   => BorderRadius.circular(sm);
  static BorderRadius get mdBr   => BorderRadius.circular(md);
  static BorderRadius get lgBr   => BorderRadius.circular(lg);
  static BorderRadius get xlBr   => BorderRadius.circular(xl);
  static BorderRadius get fullBr => BorderRadius.circular(full);
}

/// Elevation / shadow presets
class AuraElevation {
  AuraElevation._();

  static List<BoxShadow> none = [];

  static List<BoxShadow> low(Color base) => [
    BoxShadow(
      color: base.withOpacity(0.08),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> medium(Color base) => [
    BoxShadow(
      color: base.withOpacity(0.12),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> high(Color base) => [
    BoxShadow(
      color: base.withOpacity(0.16),
      blurRadius: 24,
      spreadRadius: 4,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> glow(Color accent) => [
    BoxShadow(
      color: accent.withOpacity(0.20),
      blurRadius: 40,
      spreadRadius: 10,
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.30),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ];
}

/// Animation durations & curves
class AuraMotion {
  AuraMotion._();
  static const Duration instant  = Duration(milliseconds: 100);
  static const Duration fast     = Duration(milliseconds: 200);
  static const Duration normal   = Duration(milliseconds: 300);
  static const Duration slow     = Duration(milliseconds: 500);
  static const Duration pageTransition = Duration(milliseconds: 350);

  static const Curve standard    = Curves.easeInOut;
  static const Curve decelerate  = Curves.easeOut;
  static const Curve accelerate  = Curves.easeIn;
  static const Curve spring      = Curves.elasticOut;
}

/// Splash screen tokens (kept separate from the brand-locked palette).
class AuraSplashTokens {
  AuraSplashTokens._();

  static const Color darkBackground = Color(0xFF0A0B0E);
  static const Color lightBackground = Color(0xFFD8DEEF);
}

/// Typography scale — all use Poppins
class AuraTypography {
  AuraTypography._();

  static const String _fontFamily = 'Poppins';

  static TextStyle displayLarge(Color color) => TextStyle(
    fontFamily: _fontFamily, fontSize: 28, fontWeight: FontWeight.w600,
    letterSpacing: 4, color: color, height: 1.3,
  );

  static TextStyle headlineLarge(Color color) => TextStyle(
    fontFamily: _fontFamily, fontSize: 24, fontWeight: FontWeight.w600,
    letterSpacing: 6, color: color, height: 1.3,
  );

  static TextStyle headlineMedium(Color color) => TextStyle(
    fontFamily: _fontFamily, fontSize: 20, fontWeight: FontWeight.w600,
    letterSpacing: 0.5, color: color, height: 1.4,
  );

  static TextStyle titleLarge(Color color) => TextStyle(
    fontFamily: _fontFamily, fontSize: 18, fontWeight: FontWeight.w600,
    letterSpacing: 2, color: color, height: 1.4,
  );

  static TextStyle titleMedium(Color color) => TextStyle(
    fontFamily: _fontFamily, fontSize: 16, fontWeight: FontWeight.w600,
    letterSpacing: 0.3, color: color, height: 1.4,
  );

  static TextStyle titleSmall(Color color) => TextStyle(
    fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w600,
    letterSpacing: 0.2, color: color, height: 1.4,
  );

  // Backwards-compat alias (guards against incorrect casing in older UI code).
  static TextStyle titlesmall(Color color) => titleSmall(color);

  static TextStyle bodyLarge(Color color) => TextStyle(
    fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w500,
    letterSpacing: 0.3, color: color, height: 1.5,
  );

  static TextStyle bodyMedium(Color color) => TextStyle(
    fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w400,
    letterSpacing: 0.5, color: color, height: 1.5,
  );

  static TextStyle bodySmall(Color color) => TextStyle(
    fontFamily: _fontFamily, fontSize: 13, fontWeight: FontWeight.w400,
    letterSpacing: 0.3, color: color, height: 1.5,
  );

  static TextStyle caption(Color color) => TextStyle(
    fontFamily: _fontFamily, fontSize: 12, fontWeight: FontWeight.w400,
    letterSpacing: 0.2, color: color, height: 1.5,
  );

  static TextStyle overline(Color color) => TextStyle(
    fontFamily: _fontFamily, fontSize: 11, fontWeight: FontWeight.w400,
    letterSpacing: 1.2, color: color, height: 1.5,
  );

  static TextStyle labelSmall(Color color) => TextStyle(
    fontFamily: _fontFamily, fontSize: 11, fontWeight: FontWeight.w600,
    letterSpacing: 0.2, color: color, height: 1.5,
  );

  static TextStyle button(Color color) => TextStyle(
    fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w600,
    letterSpacing: 0.3, color: color, height: 1,
  );
}
