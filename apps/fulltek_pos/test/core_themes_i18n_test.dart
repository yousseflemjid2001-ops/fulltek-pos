import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fulltek_pos/l10n/pos_i18n.dart';
import 'package:fulltek_pos/theme/fulltek_themes.dart';
import 'package:fulltek_pos/widgets/fulltek_logo.dart';

void main() {
  group('F05 — 5-Theme Engine & PosPalette', () {
    test('Exact tokens, radii, shadows, layouts & serif heading for all 5 themes',
        () {
      final t01 = FullTekThemes.all[FullTekThemeId.emeraldNight]!;
      expect(t01.palette.border, const Color(0x14FFFFFF));
      expect(t01.palette.radius, 12);
      expect(t01.ticketLeft, isFalse);
      expect(t01.categoriesAsRail, isFalse);
      expect(t01.boxShadow, isEmpty);
      expect(t01.headingFontFamily, isNull);

      final t04 = FullTekThemes.all[FullTekThemeId.auroraGlass]!;
      expect(t04.bgGradientStops, [0.0, 0.48, 1.0]);
      expect(t04.palette.headerBg, const Color(0x12FFFFFF));
      expect(t04.palette.surface, const Color(0x1AFFFFFF));
      expect(t04.palette.surfaceAlt, const Color(0x2BFFFFFF));
      expect(t04.palette.border, const Color(0x33FFFFFF));
      expect(t04.palette.textMuted, const Color(0xA8FFFFFF));
      expect(t04.palette.radius, 20);
      expect(t04.ticketLeft, isTrue);
      expect(t04.categoriesAsRail, isFalse);
      expect(t04.boxShadow, hasLength(1));
      expect(t04.boxShadow.first.color, const Color(0x2E000000));
      expect(t04.boxShadow.first.blurRadius, 24);
      expect(t04.boxShadow.first.offset, const Offset(0, 8));

      final t06 = FullTekThemes.all[FullTekThemeId.oceanFintech]!;
      expect(t06.palette.radius, 14);
      expect(t06.ticketLeft, isFalse);
      expect(t06.categoriesAsRail, isTrue);
      expect(t06.boxShadow, hasLength(1));
      expect(t06.boxShadow.first.color, const Color(0x142563EB));
      expect(t06.boxShadow.first.blurRadius, 16);
      expect(t06.boxShadow.first.offset, const Offset(0, 4));

      final t07 = FullTekThemes.all[FullTekThemeId.mauritaniaPrestige]!;
      expect(t07.palette.radius, 14);
      expect(t07.ticketLeft, isTrue);
      expect(t07.categoriesAsRail, isFalse);
      expect(t07.boxShadow, isEmpty);
      expect(t07.headingFontFamily, 'Playfair Display');
      expect(
        t07.palette.headingFontFamilyFallback,
        containsAll(['Georgia', 'serif']),
      );
      final theme07 = t07.toThemeData();
      expect(theme07.textTheme.titleLarge?.fontFamily, 'Playfair Display');
      expect(t07.palette.headingStyle(fontSize: 20).fontFamily,
          'Playfair Display');

      final t11 = FullTekThemes.all[FullTekThemeId.nordicMinimal]!;
      expect(t11.palette.radius, 18);
      expect(t11.ticketLeft, isFalse);
      expect(t11.categoriesAsRail, isTrue);
      expect(t11.boxShadow, hasLength(1));
      expect(t11.boxShadow.first.color, const Color(0x0D000000));
      expect(t11.boxShadow.first.blurRadius, 20);
      expect(t11.boxShadow.first.offset, const Offset(0, 6));
    });

    test('PosPalette.copyWith, lerp and PosPalette.of(context)', () {
      final p1 = FullTekThemes.all[FullTekThemeId.emeraldNight]!.palette;
      final p2 = FullTekThemes.all[FullTekThemeId.auroraGlass]!.palette;
      final mid = p1.lerp(p2, 0.5);
      expect(mid.radius, 16);
      expect(mid.shadowBlurRadius, 12);

      final copied = p1.copyWith(radius: 22, shadowBlurRadius: 10);
      expect(copied.radius, 22);
      expect(copied.shadowElevation, 2.5);
    });

    testWidgets('PosPalette.of(context) resolves active theme extension',
        (tester) async {
      late PosPalette resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: FullTekThemes.all[FullTekThemeId.oceanFintech]!.toThemeData(),
          home: Builder(
            builder: (ctx) {
              resolved = PosPalette.of(ctx);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(resolved.primary, const Color(0xFF2563EB));
    });

    testWidgets(
        'FullTekLogo supports variants, appIcon and stays LTR inside RTL tree',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              children: [
                FullTekLogo(variant: 'Resto', animate: false),
                FullTekLogo(variant: 'Market', animate: false),
                FullTekLogo(variant: 'Pharma', animate: false),
                FullTekLogo(variant: 'Boss', animate: false, asAppIcon: true),
              ],
            ),
          ),
        ),
      );

      expect(find.text('RESTO'), findsOneWidget);
      expect(find.text('MARKET'), findsOneWidget);
      expect(find.text('PHARMA'), findsOneWidget);
      expect(find.text('BOSS'), findsOneWidget);

      final logoDir = tester.widget<Directionality>(
        find.descendant(
          of: find.byType(FullTekLogo).first,
          matching: find.byType(Directionality),
        ),
      );
      expect(logoDir.textDirection, TextDirection.ltr);
    });
  });

  group('F06 — Trilingual FR | AR (RTL) | EN Dictionary', () {
    test('Directionality switches to RTL for Arabic and LTR for FR/EN', () {
      const ar = PosI18n('ar');
      const fr = PosI18n('fr');
      const en = PosI18n('en');

      expect(ar.isRtl, isTrue);
      expect(ar.direction, TextDirection.rtl);
      expect(fr.isRtl, isFalse);
      expect(fr.direction, TextDirection.ltr);
      expect(en.isRtl, isFalse);
      expect(en.direction, TextDirection.ltr);
    });

    test('All M2/M3 keys exist and are non-empty across fr, ar, en', () {
      const requiredKeys = [
        'mode_dine_in',
        'mode_takeaway',
        'mode_delivery',
        'status_lan',
        'status_cloud',
        'status_offline',
        'refresh_catalog',
        'nav_kds',
        'nav_dashboard',
        'badge_top',
        'badge_out_of_stock',
        'subtotal_ht',
        'tva_included',
        'action_kitchen',
        'action_split',
        'action_discount',
        'payment_mixed',
        'checkout_cta',
        'payment_bimbank',
        'payment_click',
        'counted_bimbank',
        'counted_click',
        'status_waiting',
        'floor_counter_deco',
        'transfer_table',
        'merge_tables',
        'kds_title',
        'kds_station_all',
        'kds_station_grill',
        'kds_station_kitchen',
        'kds_station_bar',
        'kds_dish_ready',
        'kds_rupture_86',
        'modifiers_title',
        'mod_cooking',
        'mod_side',
        'mod_extras',
        'delivery_title',
        'delivery_zone',
        'delivery_fee',
        'kpi_revenue_today',
        'kpi_tickets',
        'kpi_avg_basket',
        'kpi_gross_margin',
        'kpi_food_cost',
        'stock_title',
        'stock_low_alert',
        'training_mode',
        'training_banner',
        'training_receipt_watermark',
      ];

      for (final lang in ['fr', 'ar', 'en']) {
        final i18n = PosI18n(lang);
        for (final k in requiredKeys) {
          final val = i18n.t(k);
          expect(val.trim(), isNotEmpty, reason: '$lang missing $k');
          expect(val, isNot(k), reason: '$lang fell back to raw key $k');
        }
      }

      expect(const PosI18n('fr').t('tva_included'), 'Dont TVA 16 %');
      expect(const PosI18n('fr').t('payment_bimbank'), 'Bimbank');
      expect(const PosI18n('fr').t('payment_click'), 'Click');
    });
  });
}
