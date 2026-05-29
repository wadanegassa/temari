import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Backgrounds
  static const bgPrimary    = Color(0xFFFFFFFF); // pure white
  static const bgSecondary  = Color(0xFFF7F7F8); // very light gray
  static const bgCard       = Color(0xFFFFFFFF); // white cards
  static const bgDark       = Color(0xFF121212); // dark mode / overlays

  // Brand
  static const ink          = Color(0xFF000000); // pure black text
  static const inkMid       = Color(0xFF555555); // secondary text
  static const inkLight     = Color(0xFFA1A1AA); // tertiary / placeholder

  // Accent
  static const accent       = Color(0xFF111111); // almost black for primary CTAs
  static const accentSoft   = Color(0xFFF4F4F5); // soft gray for subtle highlights
  static const accentGlow   = Color(0xFF3F3F46); // dark gray for gradients

  // Semantic
  static const success      = Color(0xFF16A34A);
  static const successSoft  = Color(0xFFDCFCE7);
  static const warning      = Color(0xFFD97706);
  static const warningSoft  = Color(0xFFFEF3C7);
  static const error        = Color(0xFFDC2626);
  static const errorSoft    = Color(0xFFFEE2E2);

  // Borders
  static const border       = Color(0xFFE4E4E7); // standard border
  static const borderStrong = Color(0xFFD4D4D8); // emphasized border

  // Subject colors — cool, distinct, readable
  static const subjectColors = <Color>[
    Color(0xFF0F172A), // slate dark
    Color(0xFF1D4ED8), // cool blue
    Color(0xFF047857), // emerald
    Color(0xFF6D28D9), // vivid purple
    Color(0xFFB45309), // amber
    Color(0xFF0E7490), // cyan
    Color(0xFFBE123C), // rose
  ];

  // Backwards compatibility aliases
  static const bg = bgPrimary;
  static const primary = accent;
  static const textPrimary = ink;
  static const textTertiary = inkLight;
  static const surfaceAlt = bgSecondary;
  static const surface = bgCard;
}
