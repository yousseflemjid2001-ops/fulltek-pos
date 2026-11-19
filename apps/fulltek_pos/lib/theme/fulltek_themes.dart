import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';

enum FullTekThemeId {
  emeraldNight, // Modèle 01 — Émeraude Night (Sombre Pro)
  auroraGlass, // Modèle 04 — Aurora Glass (Glassmorphism)
  oceanFintech, // Modèle 06 — Ocean Fintech (Clair SaaS Moderne)
  mauritaniaPrestige, // Modèle 07 — Mauritanie Prestige (Vert & Or, Ticket à gauche)
  nordicMinimal, // Modèle 11 — Nordic Minimal (Apple Style iPadOS)
}

/// Official Full-Tek Brand Palette (NOTES_DECISIONS_CLIENT_FULL-TEK.md & index.html)
class FullTekBrand {
  static const Color petrol = Color(0xFF264653);
  static const Color petrol2 = Color(0xFF315869);
  static const Color ochre = Color(0xFFE9A23B);
  static const Color night = Color(0xFF0F1B20);
  static const Color night2 = Color(0xFF14262D);
  static const Color night3 = Color(0xFF1B323B);

  static const Color restoOrange = Color(0xFFE4572E);
  static const Color marketGreen = Color(0xFF2E9E5B);
  static const Color pharmaBlue = Color(0xFF1B8FD9);
  static const Color bossGold = Color(0xFFC99A2E);
}

class PosPalette extends ThemeExtension<PosPalette> {
  final Color bg;
  final Color headerBg;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color primary;
  final Color accent;
  final Color onPrimary;
  final Color textPrimary;
  final Color textMuted;
  final Color success;
  final Color warning;
  final Color danger;
  final Color vipGold;
  final double radius;
  final Color info;
  final Color shadowColor;
  final double shadowBlurRadius;
  final double shadowOffsetY;
  final String? headingFontFamily;
  final List<String> headingFontFamilyFallback;

  const PosPalette({
    required this.bg,
    required this.headerBg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.primary,
    required this.accent,
    required this.onPrimary,
    required this.textPrimary,
    required this.textMuted,
    required this.success,
    required this.warning,
    required this.danger,
    required this.vipGold,
    this.radius = 12,
    this.info = const Color(0xFF3B82F6),
    this.shadowColor = Colors.transparent,
    this.shadowBlurRadius = 0,
    this.shadowOffsetY = 0,
    this.headingFontFamily,
    this.headingFontFamilyFallback = const ['Inter', 'Segoe UI', 'sans-serif'],
  });

  static PosPalette of(BuildContext context) =>
      FullTekThemes.paletteOf(context);

  double get shadowElevation =>
      shadowBlurRadius > 0 ? (shadowBlurRadius / 4.0) : 0.0;

  List<BoxShadow> get cardShadows =>
      (shadowBlurRadius > 0 && shadowColor.a > 0)
          ? [
              BoxShadow(
                color: shadowColor,
                blurRadius: shadowBlurRadius,
                offset: Offset(0, shadowOffsetY),
              ),
            ]
          : const [];

  TextStyle headingStyle({
    double? fontSize,
    FontWeight fontWeight = FontWeight.w800,
    Color? color,
  }) =>
      TextStyle(
        fontFamily: headingFontFamily,
        fontFamilyFallback: headingFontFamilyFallback,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color ?? textPrimary,
      );

  @override
  PosPalette copyWith({
    Color? bg,
    Color? headerBg,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? primary,
    Color? accent,
    Color? onPrimary,
    Color? textPrimary,
    Color? textMuted,
    Color? success,
    Color? warning,
    Color? danger,
    Color? vipGold,
    double? radius,
    Color? info,
    Color? shadowColor,
    double? shadowBlurRadius,
    double? shadowOffsetY,
    String? headingFontFamily,
    List<String>? headingFontFamilyFallback,
  }) {
    return PosPalette(
      bg: bg ?? this.bg,
      headerBg: headerBg ?? this.headerBg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      primary: primary ?? this.primary,
      accent: accent ?? this.accent,
      onPrimary: onPrimary ?? this.onPrimary,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      vipGold: vipGold ?? this.vipGold,
      radius: radius ?? this.radius,
      info: info ?? this.info,
      shadowColor: shadowColor ?? this.shadowColor,
      shadowBlurRadius: shadowBlurRadius ?? this.shadowBlurRadius,
      shadowOffsetY: shadowOffsetY ?? this.shadowOffsetY,
      headingFontFamily: headingFontFamily ?? this.headingFontFamily,
      headingFontFamilyFallback:
          headingFontFamilyFallback ?? this.headingFontFamilyFallback,
    );
  }

  @override
  PosPalette lerp(ThemeExtension<PosPalette>? other, double t) {
    if (other is! PosPalette) return this;
    return PosPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      headerBg: Color.lerp(headerBg, other.headerBg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      vipGold: Color.lerp(vipGold, other.vipGold, t)!,
      radius: radius + (other.radius - radius) * t,
      info: Color.lerp(info, other.info, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
      shadowBlurRadius:
          lerpDouble(shadowBlurRadius, other.shadowBlurRadius, t) ?? 0,
      shadowOffsetY: lerpDouble(shadowOffsetY, other.shadowOffsetY, t) ?? 0,
      headingFontFamily: t < 0.5 ? headingFontFamily : other.headingFontFamily,
      headingFontFamilyFallback: t < 0.5
          ? headingFontFamilyFallback
          : other.headingFontFamilyFallback,
    );
  }
}

class FullTekThemeSpec {
  final FullTekThemeId id;
  final String code;
  final String labelFr;
  final String labelAr;
  final String labelEn;
  final Brightness brightness;
  final bool ticketLeft;
  final bool categoriesAsRail;
  final List<Color>? bgGradient;
  final List<double>? bgGradientStops;
  final PosPalette palette;

  const FullTekThemeSpec({
    required this.id,
    required this.code,
    required this.labelFr,
    required this.labelAr,
    required this.labelEn,
    required this.brightness,
    required this.ticketLeft,
    required this.categoriesAsRail,
    this.bgGradient,
    this.bgGradientStops,
    required this.palette,
  });

  List<BoxShadow> get boxShadow => palette.cardShadows;
  String? get headingFontFamily => palette.headingFontFamily;

  String label(String lang) {
    switch (lang) {
      case 'ar':
        return labelAr;
      case 'en':
        return labelEn;
      default:
        return labelFr;
    }
  }

  ThemeData toThemeData() {
    final p = palette;
    final baseText = (brightness == Brightness.dark
            ? ThemeData.dark()
            : ThemeData.light())
        .textTheme;
    TextStyle? applyHeading(TextStyle? style) => p.headingFontFamily == null
        ? style
        : (style ?? const TextStyle()).copyWith(
            fontFamily: p.headingFontFamily,
            fontFamilyFallback: p.headingFontFamilyFallback,
          );
    final textTheme = p.headingFontFamily == null
        ? baseText
        : baseText.copyWith(
            displayLarge: applyHeading(baseText.displayLarge),
            displayMedium: applyHeading(baseText.displayMedium),
            displaySmall: applyHeading(baseText.displaySmall),
            headlineLarge: applyHeading(baseText.headlineLarge),
            headlineMedium: applyHeading(baseText.headlineMedium),
            headlineSmall: applyHeading(baseText.headlineSmall),
            titleLarge: applyHeading(baseText.titleLarge),
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      textTheme: textTheme,
      scaffoldBackgroundColor:
          bgGradient != null ? Colors.transparent : p.bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: p.primary,
        onPrimary: p.onPrimary,
        secondary: p.accent,
        onSecondary: p.onPrimary,
        error: p.danger,
        onError: Colors.white,
        surface: p.surface,
        onSurface: p.textPrimary,
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: p.shadowElevation,
        shadowColor: p.shadowColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(p.radius),
          side: BorderSide(color: p.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(p.radius),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(p.radius),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(p.radius),
          borderSide: BorderSide(color: p.primary, width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(p.radius)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          side: BorderSide(color: p.border),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(p.radius)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
      dividerColor: p.border,
      extensions: [p],
    );
  }
}

class FullTekThemes {
  static const Map<FullTekThemeId, FullTekThemeSpec> all = {
    // Modèle 01 : Émeraude Night — exact CSS from Maquettes & NOTES_DECISIONS_CLIENT_FULL-TEK.md
    FullTekThemeId.emeraldNight: FullTekThemeSpec(
      id: FullTekThemeId.emeraldNight,
      code: '01',
      labelFr: '01 · Émeraude Night',
      labelAr: '01 · ليل الزمرد',
      labelEn: '01 · Emerald Night',
      brightness: Brightness.dark,
      ticketLeft: false,
      categoriesAsRail: false,
      palette: PosPalette(
        bg: Color(0xFF0B1220),
        headerBg: Color(0xFF0F1729),
        surface: Color(0xFF131C2E),
        surfaceAlt: Color(0xFF1B2742),
        border: Color(0x14FFFFFF),
        primary: Color(0xFF10B981),
        accent: Color(0xFF34D399),
        onPrimary: Color(0xFF03180F),
        textPrimary: Color(0xFFE8EEFC),
        textMuted: Color(0xFF8B9BB8),
        success: Color(0xFF22C55E),
        warning: Color(0xFFF59E0B),
        danger: Color(0xFFEF4444),
        vipGold: Color(0xFFF59E0B),
        radius: 12,
      ),
    ),

    // Modèle 04 : Aurora Glass — exact CSS from Maquettes_Interfaces_POS_Taha_Chouaib.html
    FullTekThemeId.auroraGlass: FullTekThemeSpec(
      id: FullTekThemeId.auroraGlass,
      code: '04',
      labelFr: '04 · Aurora Glass',
      labelAr: '04 · زجاج الشفق',
      labelEn: '04 · Aurora Glass',
      brightness: Brightness.dark,
      ticketLeft: true,
      categoriesAsRail: false,
      bgGradient: [
        Color(0xFF1E1B4B),
        Color(0xFF4C1D95),
        Color(0xFF0E7490),
      ],
      bgGradientStops: [0.0, 0.48, 1.0],
      palette: PosPalette(
        bg: Color(0xFF1E1B4B),
        headerBg: Color(0x12FFFFFF),
        surface: Color(0x1AFFFFFF),
        surfaceAlt: Color(0x2BFFFFFF),
        border: Color(0x33FFFFFF),
        primary: Color(0xFF22D3EE),
        accent: Color(0xFFC084FC),
        onPrimary: Color(0xFF06222B),
        textPrimary: Color(0xFFFFFFFF),
        textMuted: Color(0xA8FFFFFF),
        success: Color(0xFF22C55E),
        warning: Color(0xFFF59E0B),
        danger: Color(0xFFEF4444),
        vipGold: Color(0xFFFDE047),
        radius: 20,
        shadowColor: Color(0x2E000000),
        shadowBlurRadius: 24,
        shadowOffsetY: 8,
      ),
    ),

    // Modèle 06 : Ocean Fintech — Mode CLAIR SaaS Moderne (exact CSS from Maquettes & NOTES)
    FullTekThemeId.oceanFintech: FullTekThemeSpec(
      id: FullTekThemeId.oceanFintech,
      code: '06',
      labelFr: '06 · Ocean Fintech',
      labelAr: '06 · أوشن فينتك',
      labelEn: '06 · Ocean Fintech',
      brightness: Brightness.light,
      ticketLeft: false,
      categoriesAsRail: true,
      palette: PosPalette(
        bg: Color(0xFFF4F7FB),
        headerBg: Color(0xFFFFFFFF),
        surface: Color(0xFFFFFFFF),
        surfaceAlt: Color(0xFFEAF0F9),
        border: Color(0xFFE1E8F4),
        primary: Color(0xFF2563EB),
        accent: Color(0xFF06B6D4),
        onPrimary: Color(0xFFFFFFFF),
        textPrimary: Color(0xFF0F1B33),
        textMuted: Color(0xFF6B7A99),
        success: Color(0xFF22C55E),
        warning: Color(0xFFF59E0B),
        danger: Color(0xFFEF4444),
        vipGold: Color(0xFFD97706),
        radius: 14,
        shadowColor: Color(0x142563EB),
        shadowBlurRadius: 16,
        shadowOffsetY: 4,
      ),
    ),

    // Modèle 07 : Mauritanie Prestige — Vert Mauritanie #06281E + Or Sable #F59E0B + Ticket à gauche
    FullTekThemeId.mauritaniaPrestige: FullTekThemeSpec(
      id: FullTekThemeId.mauritaniaPrestige,
      code: '07',
      labelFr: '07 · Mauritanie Prestige',
      labelAr: '07 · موريتانيا بريستيج',
      labelEn: '07 · Mauritania Prestige',
      brightness: Brightness.dark,
      ticketLeft: true,
      categoriesAsRail: false,
      palette: PosPalette(
        bg: Color(0xFF06281E),
        headerBg: Color(0xFF041F17),
        surface: Color(0xFF0C3B2E),
        surfaceAlt: Color(0xFF134E3E),
        border: Color(0x40F59E0B),
        primary: Color(0xFFF59E0B),
        accent: Color(0xFF10B981),
        onPrimary: Color(0xFF052E16),
        textPrimary: Color(0xFFF7FEE7),
        textMuted: Color(0xFFA7F3D0),
        success: Color(0xFF22C55E),
        warning: Color(0xFFF59E0B),
        danger: Color(0xFFEF4444),
        vipGold: Color(0xFFF59E0B),
        radius: 14,
        headingFontFamily: 'Playfair Display',
        headingFontFamilyFallback: ['Georgia', 'serif'],
      ),
    ),

    // Modèle 11 : Nordic Minimal (Apple Style) — Mode CLAIR iPadOS #F5F5F7 + #0071E3 + Rail
    FullTekThemeId.nordicMinimal: FullTekThemeSpec(
      id: FullTekThemeId.nordicMinimal,
      code: '11',
      labelFr: '11 · Nordic Minimal',
      labelAr: '11 · نورديك مينيمال',
      labelEn: '11 · Nordic Minimal',
      brightness: Brightness.light,
      ticketLeft: false,
      categoriesAsRail: true,
      palette: PosPalette(
        bg: Color(0xFFF5F5F7),
        headerBg: Color(0xFFFFFFFF),
        surface: Color(0xFFFFFFFF),
        surfaceAlt: Color(0xFFEEF0F4),
        border: Color(0xFFE5E5EA),
        primary: Color(0xFF0071E3),
        accent: Color(0xFF34C759),
        onPrimary: Color(0xFFFFFFFF),
        textPrimary: Color(0xFF1D1D1F),
        textMuted: Color(0xFF86868B),
        success: Color(0xFF34C759),
        warning: Color(0xFFF59E0B),
        danger: Color(0xFFEF4444),
        vipGold: Color(0xFFB45309),
        radius: 18,
        shadowColor: Color(0x0D000000),
        shadowBlurRadius: 20,
        shadowOffsetY: 6,
      ),
    ),
  };

  static PosPalette paletteOf(BuildContext context) {
    return Theme.of(context).extension<PosPalette>() ??
        all[FullTekThemeId.emeraldNight]!.palette;
  }

  static FullTekThemeId fromCode(String code) {
    return switch (code.trim()) {
      '04' => FullTekThemeId.auroraGlass,
      '06' => FullTekThemeId.oceanFintech,
      '07' => FullTekThemeId.mauritaniaPrestige,
      '11' => FullTekThemeId.nordicMinimal,
      _ => FullTekThemeId.emeraldNight,
    };
  }
}
