import 'package:flutter/material.dart';

/// Official brand color tokens for MCCG (Machakos County Government EOC).
abstract final class AppColors {
  // Brand identity: Navy Blue + Yellow/Gold
  static const Color primary = Color(0xFF0B1B3D);
  static const Color primaryLight = Color(0xFF162D5A);
  static const Color brandNavy = Color(0xFF0B1B3D);
  static const Color accent = Color(0xFFF4B41A);
  static const Color accentDark = Color(0xFFD49B0E);
  static const Color brandGold = Color(0xFFF4B41A);

  // Surface & backgrounds
  static const Color background = Color(0xFFF6F8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color inputBg = Color(0xFFF1F4F9);
  static const Color border = Color(0xFFE2E8F0);

  // Typography & contrast
  static const Color text = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onAccent = Color(0xFF0B1B3D);

  // Status tokens
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerBg = Color(0xFFFEF2F2);
  static const Color success = Color(0xFF10B981);
  static const Color successBg = Color(0xFFECFDF5);
  static const Color noteBg = Color(0xFFF8FAFC);
  static const Color locationBg = Color(0xFFEFF6FF);
}
