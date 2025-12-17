// lib/config/app_colors.dart

import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF2563EB);

  static const Color scaffold = Color(0xFFF4F7FC);
  static const Color background = scaffold;

  static const Color card = Color(0xFFFFFFFF);

  static const Color white = Colors.white;
  static const Color black = Colors.black;

  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color iconGrey = Color(0xFF6B7280);

  static const Color danger = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);

  // 🔥 YANGI SHADOW COLORS (bottom nav + cardlar uchun)
  static Color shadowLight = Colors.black.withValues(
    alpha: 0.06,
  ); // juda yengil soya
  static Color shadowMedium = Colors.black.withValues(
    alpha: 0.12,
  ); // o‘rtacha soya
}
