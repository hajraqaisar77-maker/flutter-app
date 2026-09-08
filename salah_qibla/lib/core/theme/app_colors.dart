import 'package:flutter/material.dart';

/// Central Islamic-inspired color palette used across both light and dark
/// themes. Keep all raw hex values here so the rest of the app never
/// hardcodes a color.
class AppColors {
  AppColors._();

  // Brand
  static const Color gold = Color(0xFFC9A15C);
  static const Color goldSoft = Color(0xFFE4C384);
  static const Color amber = Color(0xFFD97B3D);

  // Dark theme surfaces
  static const Color darkBg = Color(0xFF0A2E29);
  static const Color darkSurface = Color(0xFF0F3A33);
  static const Color darkSurfaceAlt = Color(0xFF123F38);
  static const Color darkTextPrimary = Color(0xFFEDE6D6);
  static const Color darkTextMuted = Color(0xFF8FAFAA);
  static const Color darkLine = Color(0x40C9A15C);

  // Light theme surfaces
  static const Color lightBg = Color(0xFFFAF7F0);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFF1EBDD);
  static const Color lightTextPrimary = Color(0xFF102420);
  static const Color lightTextMuted = Color(0xFF5E7A74);
  static const Color lightLine = Color(0x33123F38);

  // Semantic
  static const Color success = Color(0xFF63A374);
  static const Color danger = Color(0xFFD9613D);
}
