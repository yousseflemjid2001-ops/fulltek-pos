import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fulltek_pos/main.dart';
import 'package:fulltek_pos/state/pos_store.dart';
import 'package:fulltek_pos/theme/fulltek_themes.dart';

void main() {
  group('5 thèmes du cahier des charges (NOTES_DECISIONS_CLIENT_FULL-TEK.md)', () {
    test('Modèle 01 Émeraude Night : sombre #0B1220 / accent #10B981 / ticket à droite / onglets', () {
      final t = FullTekThemes.all[FullTekThemeId.emeraldNight]!;
      expect(t.palette.bg, const Color(0xFF0B1220));
      expect(t.palette.surface, const Color(0xFF131C2E));
      expect(t.palette.surfaceAlt, const Color(0xFF1B2742));
      expect(t.palette.primary, const Color(0xFF10B981));
      expect(t.palette.accent, const Color(0xFF34D399));
      expect(t.palette.textPrimary, const Color(0xFFE8EEFC));
      expect(t.palette.radius, 12);
      expect(t.ticketLeft, isFalse);
      expect(t.categoriesAsRail, isFalse);
    });

    test('Modèle 04 Aurora Glass : dégradé violet/cyan, ticket à gauche', () {
      final t = FullTekThemes.all[FullTekThemeId.auroraGlass]!;
      expect(t.bgGradient, isNotNull);
      expect(t.palette.primary, const Color(0xFF22D3EE));
      expect(t.palette.accent, const Color(0xFFC084FC));
      expect(t.ticketLeft, isTrue);
    });

    test('Modèle 06 Ocean Fintech : CLAIR #F4F7FB / accent #2563EB / rail', () {
      final t = FullTekThemes.all[FullTekThemeId.oceanFintech]!;
      expect(t.brightness, Brightness.light);
      expect(t.palette.bg, const Color(0xFFF4F7FB));
      expect(t.palette.primary, const Color(0xFF2563EB));
      expect(t.palette.accent, const Color(0xFF06B6D4));
      expect(t.palette.textPrimary, const Color(0xFF0F1B33));
      expect(t.palette.radius, 14);
      expect(t.categoriesAsRail, isTrue);
      expect(t.ticketLeft, isFalse);
    });

    test('Modèle 07 Mauritanie Prestige : vert #06281E + or #F59E0B, ticket à gauche, onglets', () {
      final t = FullTekThemes.all[FullTekThemeId.mauritaniaPrestige]!;
      expect(t.palette.bg, const Color(0xFF06281E));
      expect(t.palette.surface, const Color(0xFF0C3B2E));
      expect(t.palette.surfaceAlt, const Color(0xFF134E3E));
      expect(t.palette.primary, const Color(0xFFF59E0B));
      expect(t.palette.textPrimary, const Color(0xFFF7FEE7));
      expect(t.ticketLeft, isTrue);
      expect(t.categoriesAsRail, isFalse);
    });

    test('Modèle 11 Nordic Minimal : CLAIR #F5F5F7 / accent #0071E3 / rail / rayon 18', () {
      final t = FullTekThemes.all[FullTekThemeId.nordicMinimal]!;
      expect(t.brightness, Brightness.light);
      expect(t.palette.bg, const Color(0xFFF5F5F7));
      expect(t.palette.primary, const Color(0xFF0071E3));
      expect(t.palette.accent, const Color(0xFF34C759));
      expect(t.palette.textPrimary, const Color(0xFF1D1D1F));
      expect(t.palette.radius, 18);
      expect(t.categoriesAsRail, isTrue);
    });
  });

  group('Compte restaurant → PIN → Caisse', () {
    testWidgets('sans session : écran de connexion compte ; champs vides refusés', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final store = PosStore();
      await tester.pumpWidget(FullTekPosApp(store: store));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('account_login_btn')), findsOneWidget);
      expect(find.byKey(const Key('pin_key_1')), findsNothing);

      await tester.tap(find.byKey(const Key('account_login_btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('account_error')), findsOneWidget);
      expect(store.accountLoggedIn, isFalse);
    });

    testWidgets('session compte active : PIN pad ; mauvais PIN refusé ; bon PIN ouvre la caisse', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final store = PosStore()..accountLoggedIn = true;
      await tester.pumpWidget(FullTekPosApp(store: store));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tenant_name_label')), findsOneWidget);

      for (final d in ['1', '1', '1', '1']) {
        await tester.tap(find.byKey(Key('pin_key_$d')));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(store.currentStaff, isNull);

      for (final d in ['1', '2', '3', '4']) {
        await tester.tap(find.byKey(Key('pin_key_$d')));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(store.currentStaff, isNotNull);
      expect(find.byKey(const Key('open_checkout_btn')), findsOneWidget);
    });

    testWidgets('thème 11 : catégories en rail ; thème 01 : onglets', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final store = PosStore()..accountLoggedIn = true;
      await tester.pumpWidget(FullTekPosApp(store: store));
      await tester.pumpAndSettle();
      expect(store.loginWithPin('7410'), isTrue);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('rail_cat_all')), findsNothing);

      store.setTheme(FullTekThemeId.nordicMinimal);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('rail_cat_all')), findsOneWidget);
    });
  });
}
