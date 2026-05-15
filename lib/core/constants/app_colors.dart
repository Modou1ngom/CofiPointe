import 'package:flutter/material.dart';

/// Palette COFINA / CofiPointe — rouge institutionnel et gris anthracite.
abstract final class AppColors {
  /// Rouge COFINA (proche charte groupe).
  static const Color primary = Color(0xFFC8102E);
  static const Color primaryDark = Color(0xFF9E0B24);
  static const Color charcoal = Color(0xFF2D2D2D);

  static const Color success = Color(0xFF0F9D58);
  static const Color error = Color(0xFFC8102E);
  static const Color warning = Color(0xFFE65100);

  static const Color backgroundLight = Color(0xFFF5F5F7);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color outlineLight = Color(0xFFE5E5EA);

  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color outlineDark = Color(0xFF3A3A3A);

  static const Color textPrimaryLight = Color(0xFF2D2D2D);
  static const Color textSecondaryLight = Color(0xFF6B6B6B);

  static const Color textPrimaryDark = Color(0xFFF5F5F5);
  static const Color textSecondaryDark = Color(0xFFB0B0B0);

  static const Color glassLight = Color(0x66FFFFFF);
  static const Color glassDark = Color(0x331E1E1E);
}
