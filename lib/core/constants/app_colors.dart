import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Backgrounds
  static const bgPrimary    = Color(0xFFF8F5EF); // warm parchment — main bg
  static const bgSecondary  = Color(0xFFEFEBE3); // slightly darker — section bg
  static const bgCard       = Color(0xFFFFFFFF); // cards
  static const bgDark       = Color(0xFF151210); // dark surfaces (bottom sheets, overlays)

  // Brand
  static const ink          = Color(0xFF1A1714); // primary text — near black, warm
  static const inkMid       = Color(0xFF4A4540); // secondary text
  static const inkLight     = Color(0xFF9A948E); // tertiary / placeholder

  // Accent
  static const accent       = Color(0xFFD4622A); // terracotta — primary CTA, highlights
  static const accentSoft   = Color(0xFFFAEDE6); // accent bg tint
  static const accentGlow   = Color(0xFFFF8A5C); // lighter accent for gradients

  // Semantic
  static const success      = Color(0xFF2A7A4B);
  static const successSoft  = Color(0xFFE6F5ED);
  static const warning      = Color(0xFFB87A00);
  static const warningSoft  = Color(0xFFFFF3D6);
  static const error        = Color(0xFFC0392B);
  static const errorSoft    = Color(0xFFFAEAE8);

  // Borders
  static const border       = Color(0xFFE3DDD6); // standard border
  static const borderStrong = Color(0xFFCBC4BC); // emphasized border

  // Subject colors — warm, distinct, readable
  static const subjectColors = <Color>[
    Color(0xFFD4622A), // terracotta
    Color(0xFF2E6B9E), // ocean blue
    Color(0xFF3A7D5C), // forest green
    Color(0xFF7B4EA0), // plum
    Color(0xFFB5860D), // golden
    Color(0xFF2E7D8C), // teal
    Color(0xFFC0392B), // red
  ];

  // Backwards compatibility aliases to support existing unchanged widgets
  static const bg = bgPrimary;
  static const primary = accent;
  static const textPrimary = ink;
  static const textTertiary = inkLight;
  static const surfaceAlt = bgSecondary;
  static const surface = bgCard;
}
