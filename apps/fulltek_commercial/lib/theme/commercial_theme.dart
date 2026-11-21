import 'package:flutter/material.dart';

class CommercialColors {
  static const Color sidebarBg = Color(0xFF0F172A);
  static const Color sidebarHover = Color(0xFF1E293B);
  static const Color sidebarActive = Color(0xFF1E293B);
  static const Color brandOrange = Color(0xFFF97316);
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color successGreen = Color(0xFF10B981);
  static const Color dangerRed = Color(0xFFEF4444);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color canvasBg = Color(0xFFF8FAFC);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color trialBannerBg = Color(0xFFFFF7ED);
  static const Color trialBannerBorder = Color(0xFFFED7AA);
  static const Color trialBannerText = Color(0xFF9A3412);
}

ThemeData buildCommercialTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: CommercialColors.canvasBg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: CommercialColors.primaryBlue,
      primary: CommercialColors.primaryBlue,
      surface: CommercialColors.cardBg,
    ),
    cardTheme: CardThemeData(
      color: CommercialColors.cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: CommercialColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: CommercialColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: CommercialColors.border),
      ),
    ),
  );
}
