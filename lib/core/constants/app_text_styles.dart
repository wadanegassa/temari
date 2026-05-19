import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle display = GoogleFonts.sora(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    height: 1.15,
    letterSpacing: -0.5,
  );

  static TextStyle h1 = GoogleFonts.sora(
    fontSize: 26,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
    height: 1.2,
    letterSpacing: -0.3,
  );

  static TextStyle h2 = GoogleFonts.sora(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
    height: 1.25,
  );

  static TextStyle h3 = GoogleFonts.plusJakartaSans(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
    height: 1.35,
  );

  static TextStyle body = GoogleFonts.plusJakartaSans(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.ink,
    height: 1.65,
  );

  static TextStyle bodyMedium = GoogleFonts.plusJakartaSans(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.ink,
  );

  static TextStyle small = GoogleFonts.plusJakartaSans(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.inkMid,
    height: 1.5,
  );

  static TextStyle label = GoogleFonts.plusJakartaSans(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.inkLight,
    letterSpacing: 0.8,
  );

  static TextStyle btnText = GoogleFonts.plusJakartaSans(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 0.1,
  );

  static TextStyle mono = GoogleFonts.jetBrainsMono(
    fontSize: 13,
    color: AppColors.inkMid,
  );

  // Maintain backward-compatibility bridges if legacy widgets refer to them
  static TextStyle get button => btnText;
  static TextStyle get bodySmall => small;
}
