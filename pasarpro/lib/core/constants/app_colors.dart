import 'package:flutter/material.dart';

/// PasarPro design system colors (Malaysian street food vibe).
class AppColors {
  AppColors._();

  // Brand colors
  static const Color primary = Color(0xFFFF6B35); // Warm orange - energy, food
  static const Color secondary = Color(
    0xFF004E3E,
  ); // Deep green - sustainability
  static const Color accent = Color(0xFFFFB81C); // Gold - premium feel

  // Surface colors
  static const Color surface = Color(0xFFF5F5F0); // Warm off-white
  static const Color surfaceDark = Color(0xFF1A1A1A);
  static const Color cardWhite = Colors.white;

  // Text colors
  static const Color onPrimary = Colors.white;
  static const Color onSecondary = Colors.white;
  static const Color onSurface = Color(0xFF2D2D2D);
  static const Color onSurfaceVariant = Color(0xFF6B6B6B);

  // Utility colors
  static const Color outline = Color(0xFFE0E0DC);
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
}
