import 'package:flutter/material.dart';

/// PasarPro design system colors (Malaysian street food vibe).
class AppColors {
  AppColors._();

  // Brand colors
  static const Color primary = Color(0xFFFF8252); // Softer warm orange
  static const Color primarySoft = Color(
    0xFFFFA585,
  ); // Softer orange for gradients
  static const Color secondary = Color(
    0xFF004E3E,
  ); // Deep green - sustainability
  static const Color secondarySoft = Color(
    0xFF0A6B59,
  ); // Richer green for gradients
  static const Color accent = Color(0xFFFFB81C); // Gold - premium feel

  // Surface colors
  static const Color surface = Color(
    0xFFFAFAFA,
  ); // Cooler, very light gray to let white cards pop
  static const Color surfaceDark = Color(0xFF1A1A1A);
  static const Color cardWhite = Colors.white;

  // Text colors
  static const Color onPrimary = Colors.white;
  static const Color onSecondary = Colors.white;
  static const Color onSurface = Color(0xFF1F1F1F); // Slightly softer black
  static const Color onSurfaceVariant = Color(0xFF757575); // Medium gray

  // Utility colors
  static const Color outline = Color(0xFFE8E8E5);
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
}
