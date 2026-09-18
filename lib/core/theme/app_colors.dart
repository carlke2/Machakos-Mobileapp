import 'package:flutter/material.dart';

/// Official brand color tokens matching the Machakos County EOC frontend design system.
abstract final class AppColors {
  // Brand identity: Machakos Blue (#1B5FAC) + Deep Navy (#0A1B2E) + Gold (#D4A017)
  static const Color primary = Color(0xFF1B5FAC);
  static const Color primaryLight = Color(0xFFE7F0FA);
  static const Color primaryDark = Color(0xFF123A68);
  static const Color brandNavy = Color(0xFF0A1B2E);
  static const Color brandNavyLight = Color(0xFF0F2740);
  static const Color accent = Color(0xFF1B5FAC);
  static const Color accentDark = Color(0xFF164B87);
  static const Color brandGold = Color(0xFFD4A017);
  static const Color brandGoldSoft = Color(0xFFFBF3DD);

  // Surface & backgrounds matching frontend CSS variables (--surface-page, --surface, --surface-2)
  static const Color background = Color(0xFFF4F7F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color inputBg = Color(0xFFF8FAF9);
  static const Color surface3 = Color(0xFFF1F5F3);
  static const Color border = Color(0xFFE3E8E5);
  static const Color borderStrong = Color(0xFFD3DAD6);

  // Typography & contrast matching frontend (--ink, --ink-2, --muted)
  static const Color text = Color(0xFF15211B);
  static const Color textSecondary = Color(0xFF3D4A44);
  static const Color textMuted = Color(0xFF6B7670);
  static const Color textMutedLight = Color(0xFF94A099);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onAccent = Color(0xFFFFFFFF);

  // Status tokens matching frontend (--status-danger, --status-warning, etc.)
  static const Color danger = Color(0xFFD62828);
  static const Color dangerBg = Color(0xFFFBEAEA);
  static const Color warning = Color(0xFFB7791F);
  static const Color warningBg = Color(0xFFFBF1DD);
  static const Color success = Color(0xFF169A5B);
  static const Color successBg = Color(0xFFECFDF5);
  static const Color info = Color(0xFF2563EB);
  static const Color infoBg = Color(0xFFE8EFFD);
  static const Color noteBg = Color(0xFFF4F7F5);
  static const Color locationBg = Color(0xFFE7F0FA);
}
