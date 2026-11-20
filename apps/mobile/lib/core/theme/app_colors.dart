import 'package:flutter/material.dart';

/// Colour tokens from docs/DESIGN.md. No colour literal may appear outside this file.
abstract final class AppColors {
  static const Color primary = Color(0xFF0F2A44);
  static const Color accent = Color(0xFF22B573);
  static const Color accentSoft = Color(0xFFE6F7EF);
  static const Color surface = Color(0xFFF5F7FA);
  static const Color card = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFE11D48);

  // Derived helpers (kept here so widgets never need colour literals).
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onAccent = Color(0xFFFFFFFF);
  static const Color warningSoft = Color(0xFFFEF3C7);
  static const Color dangerSoft = Color(0xFFFFE4EA);
  static const Color neutral = Color(0xFF9CA3AF);
  static const Color neutralSoft = Color(0xFFF3F4F6);
  static const Color overlay = Color(0x99000000);
  static const Color shadow = Color(0x14000000);
  static const Color transparent = Color(0x00000000);
}
