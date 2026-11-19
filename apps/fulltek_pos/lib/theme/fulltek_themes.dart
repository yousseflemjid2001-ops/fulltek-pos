import 'package:flutter/material.dart';

enum FullTekThemeId {
  emeraldNight, // Modèle 01 — Émeraude Night
  auroraGlass, // Modèle 04 — Aurora Glass
  oceanFintech, // Modèle 06 — Ocean Fintech
  mauritaniaPrestige, // Modèle 07 — Mauritanie Prestige
  nordicMinimal, // Modèle 11 — Nordic Minimal
}

class PosPalette extends ThemeExtension<PosPalette> {
  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color primary;
  final Color accent;
  final Color textPrimary;
  final Color textMuted;
  final Color success;
  final Color warning;
  final Color danger;
  final Color vipGold;

  const PosPalette({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.primary,
    required this.accent,
    required this.textPrimary,
    required this.textMuted,
    required this.success,
    required this.warning,
    required this.danger,
    required this.vipGold,
  });

  @override
  PosPalette copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? primary,
    Color? accent,
    Color? textPrimary,
    Color? textMuted,
    Color? success,
    Color? warning,
    Color? danger,
    Color? vipGold,
  }) {
    return PosPalette(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      primary: primary ?? this.primary,
      accent: accent ?? this.accent,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      vipGold: vipGold ?? this.vipGold,
    );
  }

  @override
  PosPalette lerp(ThemeExtension<PosPalette>? other, double t) {
    if (other is! PosPalette) return this;
    return PosPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      vipGold: Color.lerp(vipGold, other.vipGold, t)!,
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
  final PosPalette palette;

  const FullTekThemeSpec({
    required this.id,
    required this.code,
    required this.labelFr,
    required this.labelAr,
    required this.labelEn,
    required this.brightness,
    required this.palette,
  });

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
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: p.bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: p.primary,
        onPrimary: isDark ? const Color(0xFF04130D) : Colors.white,
        secondary: p.accent,
        onSecondary: isDark ? const Color(0xFF07111A) : Colors.white,
        error: p.danger,
        onError: Colors.white,
        surface: p.surface,
        onSurface: p.textPrimary,
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: p.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.primary, width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: isDark ? const Color(0xFF04130D) : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          side: BorderSide(color: p.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    FullTekThemeId.emeraldNight: FullTekThemeSpec(
      id: FullTekThemeId.emeraldNight,
      code: '01',
      labelFr: '01 · Émeraude Night',
      labelAr: '01 · ليل الزمرد',
      labelEn: '01 · Emerald Night',
      brightness: Brightness.dark,
      palette: PosPalette(
        bg: Color(0xFF07110E),
        surface: Color(0xFF0E1D18),
        surfaceAlt: Color(0xFF152922),
        border: Color(0xFF1F3C32),
        primary: Color(0xFF10B981),
        accent: Color(0xFF34D399),
        textPrimary: Color(0xFFF0FDF4),
        textMuted: Color(0xFF8AA89C),
        success: Color(0xFF22C55E),
        warning: Color(0xFFF59E0B),
        danger: Color(0xFFEF4444),
        vipGold: Color(0xFFFBBF24),
      ),
    ),
    FullTekThemeId.auroraGlass: FullTekThemeSpec(
      id: FullTekThemeId.auroraGlass,
      code: '04',
      labelFr: '04 · Aurora Glass',
      labelAr: '04 · زجاج الشفق',
      labelEn: '04 · Aurora Glass',
      brightness: Brightness.dark,
      palette: PosPalette(
        bg: Color(0xFF090D1C),
        surface: Color(0xFF121830),
        surfaceAlt: Color(0xFF1B2342),
        border: Color(0xFF2B3763),
        primary: Color(0xFF8B5CF6),
        accent: Color(0xFF06B6D4),
        textPrimary: Color(0xFFF8FAFC),
        textMuted: Color(0xFF94A3B8),
        success: Color(0xFF10B981),
        warning: Color(0xFFF59E0B),
        danger: Color(0xFFF43F5E),
        vipGold: Color(0xFFFACC15),
      ),
    ),
    FullTekThemeId.oceanFintech: FullTekThemeSpec(
      id: FullTekThemeId.oceanFintech,
      code: '06',
      labelFr: '06 · Ocean Fintech',
      labelAr: '06 · أوشن فينتك',
      labelEn: '06 · Ocean Fintech',
      brightness: Brightness.dark,
      palette: PosPalette(
        bg: Color(0xFF06131F),
        surface: Color(0xFF0C2033),
        surfaceAlt: Color(0xFF132D45),
        border: Color(0xFF1E4263),
        primary: Color(0xFF0EA5E9),
        accent: Color(0xFF38BDF8),
        textPrimary: Color(0xFFF0F9FF),
        textMuted: Color(0xFF8CB0CE),
        success: Color(0xFF10B981),
        warning: Color(0xFFF59E0B),
        danger: Color(0xFFEF4444),
        vipGold: Color(0xFFFBBF24),
      ),
    ),
    FullTekThemeId.mauritaniaPrestige: FullTekThemeSpec(
      id: FullTekThemeId.mauritaniaPrestige,
      code: '07',
      labelFr: '07 · Mauritanie Prestige',
      labelAr: '07 · موريتانيا بريستيج',
      labelEn: '07 · Mauritania Prestige',
      brightness: Brightness.dark,
      palette: PosPalette(
        bg: Color(0xFF0B1410),
        surface: Color(0xFF13211B),
        surfaceAlt: Color(0xFF1B2E25),
        border: Color(0xFF3A4A2E),
        primary: Color(0xFFD4AF37),
        accent: Color(0xFF15803D),
        textPrimary: Color(0xFFFAF7EE),
        textMuted: Color(0xFFA7B3A3),
        success: Color(0xFF22C55E),
        warning: Color(0xFFF59E0B),
        danger: Color(0xFFDC2626),
        vipGold: Color(0xFFFDE047),
      ),
    ),
    FullTekThemeId.nordicMinimal: FullTekThemeSpec(
      id: FullTekThemeId.nordicMinimal,
      code: '11',
      labelFr: '11 · Nordic Minimal',
      labelAr: '11 · نورديك مينيمال',
      labelEn: '11 · Nordic Minimal',
      brightness: Brightness.light,
      palette: PosPalette(
        bg: Color(0xFFF4F6F9),
        surface: Color(0xFFFFFFFF),
        surfaceAlt: Color(0xFFEBF0F5),
        border: Color(0xFFD5DFE9),
        primary: Color(0xFF0F766E),
        accent: Color(0xFF0284C7),
        textPrimary: Color(0xFF0F172A),
        textMuted: Color(0xFF64748B),
        success: Color(0xFF16A34A),
        warning: Color(0xFFD97706),
        danger: Color(0xFFDC2626),
        vipGold: Color(0xFFB45309),
      ),
    ),
  };

  static PosPalette paletteOf(BuildContext context) {
    return Theme.of(context).extension<PosPalette>() ??
        all[FullTekThemeId.emeraldNight]!.palette;
  }
}
