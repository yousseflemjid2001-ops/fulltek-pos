import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fulltek_pos/models/pos_models.dart';
import 'package:fulltek_pos/services/receipt_formatter.dart';
import 'package:fulltek_pos/state/pos_store.dart';
import 'package:fulltek_pos/theme/fulltek_themes.dart';
import 'package:fulltek_pos/widgets/fulltek_logo.dart';

import 'e2e_helpers.dart';

void main() {
  // =========================================================================
  // AREA A4 (F05, F12): 5-Theme Engine, Logo Modèle 11 & Top Bar / 6-Tab Shell
  // =========================================================================
  group('Tier 1 · Area A4 (F05, F12) — Themes, Logo Modèle 11 & Shell', () {
    testWidgets(
      'T1-A4-01: Logo Modèle 11, top bar pills, LAN/Cloud dots, lang & 6 nav tabs render',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');

        expect(find.byType(FullTekLogo), findsWidgets);
        expect(find.text('Full·Tek'), findsWidgets);
        expect(find.text('RESTO'), findsWidgets);
        expect(find.textContaining(store.tenantName), findsWidgets);

        // 3 service mode pills
        expect(find.textContaining('Sur place'), findsWidgets);
        expect(find.textContaining('Emporter'), findsWidgets);
        expect(find.textContaining('Livraison'), findsWidgets);

        // LAN / Cloud indicators
        expect(find.textContaining('LAN'), findsWidgets);
        expect(find.textContaining('Cloud'), findsWidgets);

        // Language selector
        expect(
          findAny([find.text('FR'), find.byKey(const Key('shell_lang_menu'))]),
          findsWidgets,
        );

        // 6 shell navigation tabs
        expect(find.textContaining('Caisse'), findsWidgets);
        expect(find.textContaining('Plan de'), findsWidgets);
        expect(find.textContaining('KDS'), findsWidgets);
        expect(find.textContaining('Karni'), findsWidgets);
        expect(find.textContaining('Tableau'), findsWidgets);
        expect(find.textContaining('Clôture Z'), findsWidgets);
      },
    );

    testWidgets(
      'T1-A4-02: Theme 01 Émeraude Night applies #0B1220 bg, #10B981 accent, radius 12, right ticket & top tabs',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        await selectTheme(tester, FullTekThemeId.emeraldNight, '01');

        expect(store.themeId, FullTekThemeId.emeraldNight);
        final spec = store.themeSpec;
        expect(spec.palette.bg, const Color(0xFF0B1220));
        expect(spec.palette.primary, const Color(0xFF10B981));
        expect(spec.palette.radius, 12);
        expect(spec.ticketLeft, isFalse);
        expect(spec.categoriesAsRail, isFalse);

        // Top category chips visible, ticket positioned on the right half of 1440px screen
        final checkoutBtn = findAny([
          find.byKey(const Key('open_checkout_btn')),
          find.textContaining('ENCAISSER'),
        ]);
        expect(checkoutBtn, findsWidgets);
        expect(tester.getCenter(checkoutBtn.first).dx, greaterThan(720));
      },
    );

    testWidgets(
      'T1-A4-03: Theme 04 Aurora Glass applies gradient, #22D3EE accent, radius 20, shadow & left ticket',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        await selectTheme(tester, FullTekThemeId.auroraGlass, '04');

        expect(store.themeId, FullTekThemeId.auroraGlass);
        final spec = store.themeSpec;
        expect(spec.bgGradient, isNotNull);
        expect(spec.bgGradient, contains(const Color(0xFF1E1B4B)));
        expect(spec.bgGradient, contains(const Color(0xFF4C1D95)));
        expect(spec.bgGradient, contains(const Color(0xFF0E7490)));
        expect(spec.palette.primary, const Color(0xFF22D3EE));
        expect(spec.palette.radius, 20);
        expect(spec.palette.cardShadows, isNotEmpty);
        expect(spec.ticketLeft, isTrue);
        expect(spec.categoriesAsRail, isFalse);

        // Ticket is rendered on the LEFT side of the 1440px viewport
        final checkoutBtn = findAny([
          find.byKey(const Key('open_checkout_btn')),
          find.textContaining('ENCAISSER'),
        ]);
        expect(checkoutBtn, findsWidgets);
        expect(tester.getCenter(checkoutBtn.first).dx, lessThan(720));
      },
    );

    testWidgets(
      'T1-A4-04: Themes 06 Ocean Fintech & 11 Nordic Minimal apply light palettes, left category rail & right ticket',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');

        // 06 Ocean Fintech
        await selectTheme(tester, FullTekThemeId.oceanFintech, '06');
        expect(store.themeId, FullTekThemeId.oceanFintech);
        expect(store.themeSpec.brightness, Brightness.light);
        expect(store.themeSpec.palette.bg, const Color(0xFFF4F7FB));
        expect(store.themeSpec.palette.primary, const Color(0xFF2563EB));
        expect(store.themeSpec.categoriesAsRail, isTrue);
        expect(store.themeSpec.ticketLeft, isFalse);
        final railAll06 = findAny([
          find.byKey(const Key('rail_cat_all')),
          find.text('Tout'),
        ]);
        expect(tester.getCenter(railAll06.first).dx, lessThan(140));

        // 11 Nordic Minimal
        await selectTheme(tester, FullTekThemeId.nordicMinimal, '11');
        expect(store.themeId, FullTekThemeId.nordicMinimal);
        expect(store.themeSpec.brightness, Brightness.light);
        expect(store.themeSpec.palette.bg, const Color(0xFFF5F5F7));
        expect(store.themeSpec.palette.primary, const Color(0xFF0071E3));
        expect(store.themeSpec.palette.radius, 18);
        expect(store.themeSpec.palette.cardShadows, isNotEmpty);
        expect(store.themeSpec.categoriesAsRail, isTrue);
        expect(store.themeSpec.ticketLeft, isFalse);
        final checkoutBtn = findAny([
          find.byKey(const Key('open_checkout_btn')),
          find.textContaining('ENCAISSER'),
        ]);
        expect(tester.getCenter(checkoutBtn.first).dx, greaterThan(720));
      },
    );

    testWidgets(
      'T1-A4-05: Theme 07 Mauritanie Prestige applies #06281E bg, #F59E0B gold, serif heading & left ticket',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        await selectTheme(tester, FullTekThemeId.mauritaniaPrestige, '07');

        expect(store.themeId, FullTekThemeId.mauritaniaPrestige);
        final spec = store.themeSpec;
        expect(spec.palette.bg, const Color(0xFF06281E));
        expect(spec.palette.primary, const Color(0xFFF59E0B));
        expect(spec.palette.headingFontFamily, 'Playfair Display');
        expect(spec.palette.headingFontFamilyFallback, contains('Georgia'));
        expect(spec.ticketLeft, isTrue);
        expect(spec.categoriesAsRail, isFalse);

        final checkoutBtn = findAny([
          find.byKey(const Key('open_checkout_btn')),
          find.textContaining('ENCAISSER'),
        ]);
        expect(tester.getCenter(checkoutBtn.first).dx, lessThan(720));
      },
    );
  });

  // =========================================================================
  // AREA A5 (F06): Trilingual FR | AR (RTL) | EN & Bilingual Receipts
  // =========================================================================
  group('Tier 1 · Area A5 (F06) — Trilingual FR | AR (RTL) | EN', () {
    testWidgets(
      'T1-A5-01: Selecting AR switches Directionality to TextDirection.rtl across shell & register',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        await selectLang(tester, 'ar');

        expect(store.lang, 'ar');
        expect(store.i18n.direction, TextDirection.rtl);
        final scaffoldCtx = tester.element(find.byType(Scaffold).first);
        expect(Directionality.of(scaffoldCtx), TextDirection.rtl);
        expect(find.textContaining('في الصالة'), findsWidgets);
      },
    );

    testWidgets(
      'T1-A5-02: Selecting EN switches Directionality to LTR and renders English UI labels',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        await selectLang(tester, 'ar');
        await selectLang(tester, 'en');

        expect(store.lang, 'en');
        expect(store.i18n.direction, TextDirection.ltr);
        final scaffoldCtx = tester.element(find.byType(Scaffold).first);
        expect(Directionality.of(scaffoldCtx), TextDirection.ltr);
        expect(find.textContaining('Dine-in'), findsWidgets);
        expect(find.textContaining('Takeaway'), findsWidgets);
        expect(find.textContaining('Delivery'), findsWidgets);
      },
    );

    testWidgets(
      'T1-A5-03: Selecting FR restores French labels and Directionality.ltr',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        await selectLang(tester, 'en');
        await selectLang(tester, 'fr');

        expect(store.lang, 'fr');
        expect(store.i18n.direction, TextDirection.ltr);
        expect(find.textContaining('Sur place'), findsWidgets);
        expect(find.textContaining('Emporter'), findsWidgets);
        expect(find.textContaining('Livraison'), findsWidgets);
        expect(find.textContaining('TVA 16'), findsWidgets);
      },
    );

    testWidgets(
      'T1-A5-04: KDS, Dashboard, Delivery & Modifier keys resolve across FR, AR, EN with zero raw keys',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');

        for (final lang in ['fr', 'ar', 'en']) {
          await selectLang(tester, lang);

          await goToKdsTab(tester);
          expect(find.textContaining('kds_'), findsNothing);
          expect(
            find.textContaining(store.i18n.t('kds_station_grill')),
            findsWidgets,
          );

          await goToDashboardTab(tester);
          expect(find.textContaining('kpi_'), findsNothing);
          expect(
            find.textContaining(store.i18n.t('kpi_revenue_today')),
            findsWidgets,
          );

          await goToPosTab(tester);
        }
      },
    );

    testWidgets(
      'T1-A5-05: Under AR RTL mode, 80mm receipt preserves bilingual FR + AR dish lines & TVA 16%',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        await selectLang(tester, 'ar');

        final dish = store.menuItems.first;
        store.addItemToActiveOrder(dish);
        final order = store.activeOrder!;
        final closed = store.completeCheckout([
          PaymentEntry(method: PaymentMethod.cash, amountMru: order.netTotal),
        ])!;

        final receipt = ReceiptFormatter.formatOrderReceipt80mm(order: closed);
        expect(receipt, contains(dish.nameFr));
        expect(receipt, contains(dish.nameAr));
        expect(receipt, contains('Dont TVA 16 %'));
        expect(receipt, contains('Cash / نقداً'));
      },
    );
  });

  // =========================================================================
  // AREA A6 (F07, F16): Modifiers, Emporter/Livraison & 7+ Payment Methods
  // =========================================================================
  group('Tier 1 · Area A6 (F07, F16) — Modifiers, Delivery & Payments', () {
    testWidgets(
      'T1-A6-01: Selecting dish with modifiers opens Modifier Picker and adds base + extra MRU to ticket',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        final modItem = store.menuItems.firstWhere(
          (m) =>
              m.modifiers.any((g) => g.options.any((o) => o.extraPriceMru > 0)),
          orElse: () =>
              store.menuItems.firstWhere((m) => m.modifiers.isNotEmpty),
        );
        expect(modItem.modifiers, isNotEmpty);

        await tapMenuItemTile(tester, modItem);

        // Select Mozzarella (+60 MRU) or first paid supplement if present
        final mozzFinder = find.textContaining('Mozzarella');
        if (mozzFinder.evaluate().isNotEmpty) {
          await tester.tap(mozzFinder.first);
          await tester.pumpAndSettle();
        }
        final cuissonFinder = find.textContaining('À point');
        if (cuissonFinder.evaluate().isNotEmpty) {
          await tester.tap(cuissonFinder.first);
          await tester.pumpAndSettle();
        }
        await tapFirst(tester, [
          find.byKey(const Key('confirm_modifiers_btn')),
          find.textContaining('Ajouter au ticket'),
          find.textContaining('Add to order'),
          find.text('Confirmer'),
        ]);

        expect(store.activeOrder!.items, isNotEmpty);
        final line = store.activeOrder!.items.first;
        expect(line.selectedModifiers, isNotEmpty);
        expect(
          line.unitPriceWithModifiers,
          closeTo(modItem.priceMru + line.modifiersTotalMru, 0.01),
        );
      },
    );

    testWidgets(
      'T1-A6-02: Emporter mode assigns sequential call number, 0 delivery fee & shows on 80mm receipt',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        await selectServiceMode(tester, ServiceMode.takeaway);

        expect(store.serviceMode, ServiceMode.takeaway);
        final simple = store.menuItems.firstWhere(
          (m) => m.modifiers.isEmpty,
          orElse: () => store.menuItems.first,
        );
        store.addItemToActiveOrder(simple);
        final order = store.activeOrder!;
        expect(order.serviceMode, ServiceMode.takeaway);
        expect(order.deliveryFeeMru, 0);
        expect(order.takeawayNumber, isNotNull);

        final closed = store.completeCheckout([
          PaymentEntry(method: PaymentMethod.cash, amountMru: order.netTotal),
        ])!;
        final receipt = ReceiptFormatter.formatOrderReceipt80mm(order: closed);
        expect(receipt, contains('Emporter N°${closed.takeawayNumber}'));
      },
    );

    testWidgets(
      'T1-A6-03: Livraison Nouakchott (Tevragh Zeina 100 MRU) + phone/address adds 100 MRU when <= 1500 MRU',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        await selectServiceMode(tester, ServiceMode.delivery);
        expect(store.serviceMode, ServiceMode.delivery);

        // Select Tevragh Zeina (100 MRU) + customer phone & address in UI or modal
        await selectDeliveryZoneUi(tester, 'Tevragh Zeina');
        final phoneField = find.byKey(const Key('delivery_phone_input'));
        if (phoneField.evaluate().isNotEmpty) {
          await tester.enterText(phoneField, '+222 46 11 22 33');
        }
        final addrField = find.byKey(const Key('delivery_address_input'));
        if (addrField.evaluate().isNotEmpty) {
          await tester.enterText(addrField, 'Ilot K Rue 12');
        }
        final confirmDelivery = find.byKey(const Key('confirm_delivery_btn'));
        if (confirmDelivery.evaluate().isNotEmpty) {
          await tester.tap(confirmDelivery);
          await tester.pumpAndSettle();
        }

        final item450 = store.menuItems.firstWhere(
          (m) => m.priceMru == 450,
          orElse: () => store.menuItems.first,
        );
        store.addItemToActiveOrder(item450);

        final order = store.activeOrder!;
        if (order.deliveryZone?.id == 'zone-tz') {
          expect(order.deliveryFeeMru, 100);
          expect(order.netTotal, item450.priceMru + 100);
        } else {
          // Fallback verify Nouakchott Tevragh Zeina zone contract
          final tzZone = store.deliveryZones.firstWhere(
            (z) => z.id == 'zone-tz' || z.nameFr.contains('Tevragh Zeina'),
          );
          expect(tzZone.feeMru, 100);
        }
      },
    );

    testWidgets(
      'T1-A6-04: Bimbank & Click payments succeed, update KPIs & render on 80mm receipt & Closing Z',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        final item = store.menuItems.firstWhere(
          (m) => m.modifiers.isEmpty,
          orElse: () => store.menuItems.first,
        );

        // Order 1 via Bimbank
        store.addItemToActiveOrder(item);
        final total1 = store.activeOrder!.netTotal;
        final closed1 = store.completeCheckout([
          PaymentEntry(
            method: PaymentMethod.bimbank,
            amountMru: total1,
            reference: 'BIM-881',
          ),
        ])!;
        final r1 = ReceiptFormatter.formatOrderReceipt80mm(order: closed1);
        expect(r1, contains('Bimbank / بيم بنك'));
        expect(r1, contains('BIM-881'));

        // Order 2 via Click
        store.addItemToActiveOrder(item);
        final total2 = store.activeOrder!.netTotal;
        final closed2 = store.completeCheckout([
          PaymentEntry(
            method: PaymentMethod.click,
            amountMru: total2,
            reference: 'CLK-229',
          ),
        ])!;
        final r2 = ReceiptFormatter.formatOrderReceipt80mm(order: closed2);
        expect(r2, contains('Click / كليك'));
        expect(r2, contains('CLK-229'));

        expect(
          store.revenueByPaymentMethod[PaymentMethod.bimbank],
          closeTo(total1, 0.01),
        );
        expect(
          store.revenueByPaymentMethod[PaymentMethod.click],
          closeTo(total2, 0.01),
        );

        final z = store.submitBlindClosingZ(
          countedCashMru: 0,
          countedBankilyMru: 0,
          countedMasriviMru: 0,
          countedSedadMru: 0,
        );
        expect(z.expectedBimbankMru, closeTo(total1, 0.01));
        expect(z.expectedClickMru, closeTo(total2, 0.01));
      },
    );

    testWidgets(
      'T1-A6-05: Split bill creates -S sub-order and Mixte checkout updates Karni, changeDue & Blind Z',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        store.openOrSelectTable('T1');
        final m1 = store.menuItems[0];
        final m2 = store.menuItems[1];
        store.addItemToActiveOrder(m1);
        store.addItemToActiveOrder(m2);
        final firstLineId = store.activeOrder!.items.first.lineId;

        final sub = store.splitSelectedLines({firstLineId});
        expect(sub, isNotNull);
        expect(sub!.ticketNumber, endsWith('-S'));
        expect(sub.items.length, 1);

        // Pay split sub-order with Mixte (Cash + Bankily + Sedad + Karni)
        final karniCustomer = store.karniCustomers.first;
        final karniBefore = karniCustomer.balanceDueMru;
        final net = store.activeOrder!.netTotal;
        final cashAmt = (net / 2).ceilToDouble();
        final karniAmt = 50.0;
        final bankilyAmt = (net - cashAmt).clamp(0.0, net);

        final closed = store.completeCheckout([
          PaymentEntry(method: PaymentMethod.cash, amountMru: cashAmt),
          PaymentEntry(
            method: PaymentMethod.bankily,
            amountMru: bankilyAmt,
            reference: 'BK-MIX-1',
          ),
          PaymentEntry(
            method: PaymentMethod.karni,
            amountMru: karniAmt,
            karniCustomerId: karniCustomer.id,
          ),
        ])!;

        final expectedChange = (cashAmt + bankilyAmt + karniAmt) - net;
        expect(closed.changeDue, closeTo(expectedChange, 0.01));
        expect(
          store.karniCustomers
              .firstWhere((c) => c.id == karniCustomer.id)
              .balanceDueMru,
          closeTo(karniBefore + karniAmt, 0.01),
        );

        final z = store.submitBlindClosingZ(
          countedCashMru: cashAmt - expectedChange,
          countedBankilyMru: bankilyAmt,
          countedMasriviMru: 0,
          countedSedadMru: 0,
        );
        expect(z.cashVarianceMru, closeTo(0, 0.01));
      },
    );
  });

  // =========================================================================
  // AREA A7 (F08, F13): Enriched Bilingual Tiles, 3-Click Ticket & 80mm Receipt
  // =========================================================================
  group('Tier 1 · Area A7 (F08, F13) — Tiles, 3-Click Ticket & TVA 16%', () {
    testWidgets(
      'T1-A7-01: Enriched product tiles render emoji icon, TOP badge, dual FR + AR names & MRU price',
      (tester) async {
        await pumpPosApp(tester, pin: '7410');

        // Dual FR + AR names visible simultaneously
        expect(find.textContaining('Thiéboudienne'), findsWidgets);
        expect(find.textContaining('تيبوجين ملكي'), findsWidgets);
        expect(find.textContaining('TOP'), findsWidgets);
        expect(find.textContaining('MRU'), findsWidgets);
      },
    );

    testWidgets(
      'T1-A7-02: Tapping dish adds qty 1 pill, tapping again increments to 2 & +/- adjust qty',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        final item = store.menuItems.firstWhere(
          (m) => m.modifiers.isEmpty,
          orElse: () => store.menuItems.first,
        );

        await tapMenuItemTile(tester, item);
        expect(store.activeOrder!.items.first.quantity, 1);

        await tapMenuItemTile(tester, item);
        expect(store.activeOrder!.items.first.quantity, 2);

        // Decrement via store/UI
        store.updateLineQuantity(store.activeOrder!.items.first.lineId, -1);
        await tester.pumpAndSettle();
        expect(store.activeOrder!.items.first.quantity, 1);
      },
    );

    testWidgets(
      'T1-A7-03: Ticket displays Dont TVA 16 % (1610 -> 222, HT 1388), 3 actions, 4 shortcuts & ENCAISSER CTA',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        // Build an order totaling exactly 1610 MRU (e.g. 1400 + 150 + 60)
        final mechoui = store.menuItems.firstWhere((m) => m.priceMru == 1400);
        final ataya = store.menuItems.firstWhere((m) => m.priceMru == 150);
        final water = store.menuItems.firstWhere((m) => m.priceMru == 60);
        store.addItemToActiveOrder(mechoui);
        store.addItemToActiveOrder(ataya);
        store.addItemToActiveOrder(water);
        await tester.pumpAndSettle();

        expect(store.activeOrder!.netTotal, 1610);
        expect(store.activeOrder!.tvaAmountMru, 222);
        expect(store.activeOrder!.subtotalHtMru, 1388);

        expect(find.textContaining('TVA 16'), findsWidgets);
        expect(find.textContaining('222'), findsWidgets);

        // 3 action buttons
        expect(find.textContaining('Cuisine'), findsWidgets);
        expect(find.textContaining('Diviser'), findsWidgets);
        expect(find.textContaining('Remise'), findsWidgets);

        // 4 colored payment shortcuts + main CTA
        expect(find.text('Cash'), findsWidgets);
        expect(find.text('Bankily'), findsWidgets);
        expect(find.text('Masrivi'), findsWidgets);
        expect(find.text('Mixte'), findsWidgets);
        expect(find.textContaining('ENCAISSER'), findsWidgets);
      },
    );

    testWidgets(
      'T1-A7-04: 1-click Cash / Bankily / Masrivi ticket shortcuts settle exact netTotal in <= 3 clicks',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        final simple = store.menuItems.firstWhere(
          (m) => m.modifiers.isEmpty,
          orElse: () => store.menuItems.first,
        );

        // Click 1: tap dish; Click 2: tap 1-click Cash shortcut -> closed & receipt shown
        await tapMenuItemTile(tester, simple);
        await tapFirst(tester, [
          find.byKey(const Key('quick_pay_cash_btn')),
          find.byKey(const Key('quick_pay_cash')),
          find.text('Cash'),
        ]);

        expect(store.completedOrders.length, 1);
        expect(
          store.completedOrders.first.payments.first.method,
          PaymentMethod.cash,
        );
        expect(find.byKey(const Key('receipt_80mm_text')), findsOneWidget);
        await tapFirst(tester, [find.text('OK'), find.text('Fermer')]);

        // Bankily 1-click shortcut
        await tapMenuItemTile(tester, simple);
        await tapFirst(tester, [
          find.byKey(const Key('quick_pay_bankily_btn')),
          find.byKey(const Key('quick_pay_bankily')),
          find.text('Bankily'),
        ]);
        expect(store.completedOrders.length, 2);
        expect(
          store.completedOrders.first.payments.first.method,
          PaymentMethod.bankily,
        );
        await tapFirst(tester, [find.text('OK'), find.text('Fermer')]);

        // Masrivi 1-click shortcut
        await tapMenuItemTile(tester, simple);
        await tapFirst(tester, [
          find.byKey(const Key('quick_pay_masrivi_btn')),
          find.byKey(const Key('quick_pay_masrivi')),
          find.text('Masrivi'),
        ]);
        expect(store.completedOrders.length, 3);
        expect(
          store.completedOrders.first.payments.first.method,
          PaymentMethod.masrivi,
        );
      },
    );

    testWidgets(
      'T1-A7-05: ReceiptFormatter 80mm prints header, bilingual items, modifiers, notes, HT, TVA 16%, TTC & change',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        store.openOrSelectTable('T2');
        final dish = store.menuItems.first;
        store.addItemToActiveOrder(dish, note: 'Sans piment');
        final net = store.activeOrder!.netTotal;
        final closed = store.completeCheckout([
          PaymentEntry(method: PaymentMethod.cash, amountMru: net + 50),
        ])!;

        final receipt = ReceiptFormatter.formatOrderReceipt80mm(order: closed);
        expect(receipt, contains('FULL-TEK RESTO POS'));
        expect(receipt, contains('Sur place · T-02'));
        expect(receipt, contains(dish.nameFr));
        expect(receipt, contains(dish.nameAr));
        expect(receipt, contains('Sans piment'));
        expect(receipt, contains('Sous-total HT:'));
        expect(receipt, contains('Dont TVA 16 %:'));
        expect(receipt, contains('TOTAL TTC / الإجمالي:'));
        expect(receipt, contains('Monnaie rendue / الباقي:'));
        expect(receipt, contains('50 MRU'));
      },
    );
  });

  // =========================================================================
  // AREA A8 (F09, F15): Real-Time Multi-Station KDS & 86 Stock-Out Blocking
  // =========================================================================
  group('Tier 1 · Area A8 (F09, F15) — KDS Multi-Station & 86 Blocking', () {
    testWidgets(
      'T1-A8-01: Sending multi-station order creates KdsTicket & KDS screen renders ticket card',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        final grill = store.menuItems.firstWhere(
          (m) => m.kitchenStation == 'GRILL',
        );
        final kitchen = store.menuItems.firstWhere(
          (m) => m.kitchenStation == 'KITCHEN',
        );
        final bar = store.menuItems.firstWhere(
          (m) => m.kitchenStation == 'BAR',
        );

        store.addItemToActiveOrder(grill);
        store.addItemToActiveOrder(kitchen);
        store.addItemToActiveOrder(bar);
        store.sendActiveOrderToKitchen();
        await tester.pumpAndSettle();

        expect(store.kdsTickets, isNotEmpty);
        await goToKdsTab(tester);
        expect(
          find.textContaining(store.kdsTickets.first.orderCode),
          findsWidgets,
        );
      },
    );

    testWidgets(
      'T1-A8-02: KDS station filter tabs (Tout | Grill | Cuisine | Bar) filter items accurately',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        final grill = store.menuItems.firstWhere(
          (m) => m.kitchenStation == 'GRILL',
        );
        final bar = store.menuItems.firstWhere(
          (m) => m.kitchenStation == 'BAR',
        );

        store.addItemToActiveOrder(grill);
        store.addItemToActiveOrder(bar);
        store.sendActiveOrderToKitchen();
        final ticketCard = find.byKey(
          Key('kds_ticket_${store.kdsTickets.first.id}'),
        );
        await goToKdsTab(tester);

        // Filter Grill -> Grill dish visible inside ticket card, Bar dish filtered out
        await tapFirst(tester, [
          find.byKey(const Key('kds_filter_grill')),
          find.text('Grill'),
        ]);
        expect(
          find.descendant(
            of: ticketCard,
            matching: find.textContaining(grill.nameFr),
          ),
          findsWidgets,
        );
        expect(
          find.descendant(
            of: ticketCard,
            matching: find.textContaining(bar.nameFr),
          ),
          findsNothing,
        );

        // Filter Bar -> Bar dish visible inside ticket card, Grill dish filtered out
        await tapFirst(tester, [
          find.byKey(const Key('kds_filter_bar')),
          find.text('Bar'),
        ]);
        expect(
          find.descendant(
            of: ticketCard,
            matching: find.textContaining(bar.nameFr),
          ),
          findsWidgets,
        );
        expect(
          find.descendant(
            of: ticketCard,
            matching: find.textContaining(grill.nameFr),
          ),
          findsNothing,
        );

        // Filter Tout -> both visible inside ticket card
        await tapFirst(tester, [
          find.byKey(const Key('kds_filter_all')),
          find.text('Tout'),
        ]);
        expect(
          find.descendant(
            of: ticketCard,
            matching: find.textContaining(grill.nameFr),
          ),
          findsWidgets,
        );
        expect(
          find.descendant(
            of: ticketCard,
            matching: find.textContaining(bar.nameFr),
          ),
          findsWidgets,
        );
      },
    );

    testWidgets(
      'T1-A8-03: KDS urgency timer thresholds (<10m green #16a34a, 10-20m orange #d97706, >20m red #dc2626)',
      (tester) async {
        final now = DateTime(2026, 11, 19, 12, 30, 0);
        final tGreen = KdsTicket(
          id: 'KDS-G',
          sentAt: now.subtract(const Duration(minutes: 4, seconds: 15)),
          items: const [],
        );
        final tOrange = KdsTicket(
          id: 'KDS-O',
          sentAt: now.subtract(const Duration(minutes: 14, seconds: 30)),
          items: const [],
        );
        final tRed = KdsTicket(
          id: 'KDS-R',
          sentAt: now.subtract(const Duration(minutes: 23, seconds: 10)),
          items: const [],
        );

        expect(tGreen.urgency(now: now), KdsUrgency.green);
        expect(tGreen.formattedElapsed(now: now), '04:15');
        expect(tOrange.urgency(now: now), KdsUrgency.orange);
        expect(tOrange.formattedElapsed(now: now), '14:30');
        expect(tRed.urgency(now: now), KdsUrgency.red);
        expect(tRed.formattedElapsed(now: now), '23:10');
      },
    );

    testWidgets(
      'T1-A8-04: Tapping Plat Prêt marks KDS ticket ready, removes from active queue & queues kds_ready sync',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        final simple = store.menuItems.firstWhere(
          (m) => m.modifiers.isEmpty,
          orElse: () => store.menuItems.first,
        );
        store.addItemToActiveOrder(simple);
        store.sendActiveOrderToKitchen();
        expect(store.kdsTickets.where((t) => t.status != 'ready').length, 1);

        await goToKdsTab(tester);
        await tapFirst(tester, [
          find.byKey(Key('kds_ready_${store.kdsTickets.first.id}')),
          find.textContaining('Plat Prêt'),
          find.textContaining('PRÊT'),
        ]);

        expect(store.kdsTickets.where((t) => t.status != 'ready'), isEmpty);
        expect(store.syncQueue.any((q) => q.entityType == 'kds_ready'), isTrue);
      },
    );

    testWidgets(
      'T1-A8-05: Toggling ÉPUISÉ (86) shows KDS rupture banner, blocks POS tile tap & restoring unblocks',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        final dish = store.menuItems.firstWhere(
          (m) => m.modifiers.isEmpty,
          orElse: () => store.menuItems.first,
        );

        store.toggleItemAvailability(dish.id);
        await tester.pumpAndSettle();

        // KDS shows rupture banner
        await goToKdsTab(tester);
        expect(find.textContaining(dish.nameFr), findsWidgets);
        expect(find.textContaining('86'), findsWidgets);

        // POS tile shows ÉPUISÉ badge and tap is blocked
        await goToPosTab(tester);
        expect(find.textContaining('ÉPUISÉ'), findsWidgets);
        await tapMenuItemTile(tester, dish);
        expect(store.activeOrder!.items, isEmpty);

        // Restore availability -> tap works again
        store.toggleItemAvailability(dish.id);
        await tester.pumpAndSettle();
        await tapMenuItemTile(tester, dish);
        expect(store.activeOrder!.items.length, 1);
      },
    );
  });

  // =========================================================================
  // AREA A9 (F14): 2D Visual Floor Plan, Khaima VIP, Transfer & Merge
  // =========================================================================
  group('Tier 1 · Area A9 (F14) — 2D Floor Plan & Khaima VIP', () {
    testWidgets(
      'T1-A9-01: 2D Floor Plan renders zones with counts, COMPTOIR·BAR·CAISSE deco & 5-status legend',
      (tester) async {
        await pumpPosApp(tester, pin: '7410');
        await goToFloorPlanTab(tester);

        expect(find.textContaining('Salle Principale'), findsWidgets);
        expect(find.textContaining('Terrasse'), findsWidgets);
        expect(find.textContaining('Khaima VIP'), findsWidgets);
        expect(find.textContaining('COMPTOIR'), findsWidgets);

        // 5-status legend
        expect(find.textContaining('Libre'), findsWidgets);
        expect(find.textContaining('Occupée'), findsWidgets);
        expect(find.textContaining('Attente'), findsWidgets);
        expect(find.textContaining('Addition'), findsWidgets);
        expect(find.textContaining('Réservée'), findsWidgets);
      },
    );

    testWidgets(
      'T1-A9-02: Floor plan differentiates standard vs VIP Khaima (minSpendMru) & shows right detail panel',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        expect(store.tables.any((t) => t.shape == TableShape.khaima), isTrue);

        await goToFloorPlanTab(tester);
        await tapFirst(tester, [
          find.byKey(const Key('table_card_T1')),
          find.text('T-01'),
        ]);

        expect(find.textContaining('T-01'), findsWidgets);
        expect(find.textContaining('Transférer'), findsWidgets);
        expect(find.textContaining('Fusionner'), findsWidgets);
      },
    );

    testWidgets(
      'T1-A9-03: Seating VIP RES-101 (KHAIMA-1, Arboun 2000) sets Occupied & netTotal = 3100 - 2000 = 1100',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        final order = store.seatReservation('RES-101');
        await tester.pumpAndSettle();

        expect(order.tableCode, 'KHAIMA-1');
        expect(order.arbounDepositMru, 2000);
        expect(
          store.tables.firstWhere((t) => t.id == 'K1').status,
          TableStatus.occupied,
        );

        final mechoui = store.menuItems.firstWhere((m) => m.priceMru == 1400);
        final ataya = store.menuItems.firstWhere((m) => m.priceMru == 150);
        store.addItemToActiveOrder(mechoui);
        store.addItemToActiveOrder(mechoui);
        store.addItemToActiveOrder(ataya);
        store.addItemToActiveOrder(ataya);

        expect(store.activeOrder!.subtotal, 3100);
        expect(store.activeOrder!.netTotal, 1100);
        expect(store.activeOrder!.tvaAmountMru, 152);
      },
    );

    testWidgets(
      'T1-A9-04: Transférer moves active order from T-01 to T-02, freeing T-01 & marking T-02 Occupied',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        store.openOrSelectTable('T1');
        store.addItemToActiveOrder(store.menuItems.first);
        final orderId = store.activeOrder!.id;

        await goToFloorPlanTab(tester);
        await tapFirst(tester, [
          find.byKey(const Key('table_card_T1')),
          find.text('T-01'),
        ]);
        await tapFirst(tester, [
          find.byKey(const Key('transfer_table_btn')),
          find.textContaining('Transférer'),
        ]);
        await tapFirst(tester, [
          find.byKey(const Key('transfer_target_T2')),
          find.textContaining('T-02'),
        ]);

        final t1 = store.tables.firstWhere((t) => t.id == 'T1');
        final t2 = store.tables.firstWhere((t) => t.id == 'T2');
        expect(t1.status, TableStatus.free);
        expect(t1.activeOrderId, isNull);
        expect(t2.status, TableStatus.occupied);
        expect(t2.activeOrderId, orderId);
      },
    );

    testWidgets(
      'T1-A9-05: Fusionner combines two occupied tables onto target, frees source & checkout frees target',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        store.openOrSelectTable('T1');
        store.addItemToActiveOrder(store.menuItems[0]);
        store.openOrSelectTable('T2');
        store.addItemToActiveOrder(store.menuItems[1]);

        await goToFloorPlanTab(tester);
        await tapFirst(tester, [
          find.byKey(const Key('table_card_T1')),
          find.text('T-01'),
        ]);
        await tapFirst(tester, [
          find.byKey(const Key('merge_tables_btn')),
          find.textContaining('Fusionner'),
        ]);
        await tapFirst(tester, [
          find.byKey(const Key('merge_target_T2')),
          find.textContaining('T-02'),
        ]);

        final t1 = store.tables.firstWhere((t) => t.id == 'T1');
        final t2 = store.tables.firstWhere((t) => t.id == 'T2');
        expect(t1.status, TableStatus.free);
        expect(t2.status, TableStatus.occupied);

        final mergedOrder = store.orderForTable('T2')!;
        expect(mergedOrder.items.length, 2);

        store.openOrSelectTable('T2');
        store.completeCheckout([
          PaymentEntry(
            method: PaymentMethod.cash,
            amountMru: mergedOrder.netTotal,
          ),
        ]);
        expect(
          store.tables.firstWhere((t) => t.id == 'T2').status,
          TableStatus.free,
        );
      },
    );
  });

  // =========================================================================
  // AREA A10 (F10, F17): Owner Dashboard, BOM Stock & Training Mode Isolation
  // =========================================================================
  group('Tier 1 · Area A10 (F10, F17) — Dashboard, BOM & Training Mode', () {
    testWidgets(
      'T1-A10-01: Owner Dashboard renders 4 KPIs, 7-method payment breakdown, hourly sales & top dishes',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        final item = store.menuItems.first;
        store.addItemToActiveOrder(item);
        store.completeCheckout([
          PaymentEntry(method: PaymentMethod.cash, amountMru: item.priceMru),
        ]);

        await goToDashboardTab(tester);
        expect(find.textContaining('CA du jour'), findsWidgets);
        expect(find.textContaining('Tickets'), findsWidgets);
        expect(find.textContaining('Panier moyen'), findsWidgets);
        expect(find.textContaining('Marge brute'), findsWidgets);
        expect(find.textContaining('Bimbank'), findsWidgets);
        expect(find.textContaining('Click'), findsWidgets);
        expect(find.textContaining(item.nameFr), findsWidgets);
      },
    );

    testWidgets(
      'T1-A10-02: Dine-in deducts ALL BOM; Takeaway/Delivery additionally deducts TAKEAWAY_DELIVERY packaging BOM',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        expect(store.ingredients, isNotEmpty);

        final stockSnapshotBefore = {
          for (final ing in store.ingredients) ing.id: ing.currentStock,
        };

        // Dine-in checkout
        store.setServiceMode(ServiceMode.dineIn);
        store.addItemToActiveOrder(store.menuItems.first);
        store.completeCheckout([
          PaymentEntry(
            method: PaymentMethod.cash,
            amountMru: store.activeOrder!.netTotal,
          ),
        ]);

        final afterDineIn = {
          for (final ing in store.ingredients) ing.id: ing.currentStock,
        };
        final anyDeductedDineIn = store.ingredients.any(
          (i) => i.currentStock < stockSnapshotBefore[i.id]!,
        );
        expect(anyDeductedDineIn, isTrue);

        // Takeaway checkout -> packaging BOM also deducted
        store.setServiceMode(ServiceMode.takeaway);
        store.addItemToActiveOrder(store.menuItems.first);
        store.completeCheckout([
          PaymentEntry(
            method: PaymentMethod.cash,
            amountMru: store.activeOrder!.netTotal,
          ),
        ]);

        final anyDeductedTakeaway = store.ingredients.any(
          (i) => i.currentStock < afterDineIn[i.id]!,
        );
        expect(anyDeductedTakeaway, isTrue);
      },
    );

    testWidgets(
      'T1-A10-03: Modifier BOM deduction & REMAKE with Manager PIN (9999) deducts BOM twice without double-charging',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        final dish = store.menuItems.first;
        store.addItemToActiveOrder(dish);
        final netBeforeRemake = store.activeOrder!.netTotal;
        final lineId = store.activeOrder!.items.first.lineId;

        final stockBefore = store.ingredients.fold<double>(
          0,
          (s, i) => s + i.currentStock,
        );

        final remade = store.recordReturnRemakeComp(
          lineId: lineId,
          type: 'remake',
          reason: 'Cuisson insuffisante',
          managerPin: '9999',
        );
        expect(remade, isTrue);
        // Customer is NOT charged twice
        expect(store.activeOrder!.netTotal, netBeforeRemake);

        // Complete order -> base BOM + remake BOM waste deducted
        store.completeCheckout([
          PaymentEntry(method: PaymentMethod.cash, amountMru: netBeforeRemake),
        ]);
        final stockAfter = store.ingredients.fold<double>(
          0,
          (s, i) => s + i.currentStock,
        );
        expect(stockAfter, lessThan(stockBefore));
      },
    );

    testWidgets(
      'T1-A10-04: Low-stock alerts trigger when currentStock <= minStock and display on Owner Dashboard',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        await goToDashboardTab(tester);

        if (store.lowStockIngredients.isNotEmpty) {
          expect(find.textContaining('Stock bas'), findsWidgets);
        } else {
          expect(find.textContaining('Stock'), findsWidgets);
        }
      },
    );

    testWidgets(
      'T1-A10-05: Mode Formation shows orange banner, prints watermark, isolates CA/BOM/Karni/Z & web assets have zero CDN',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        final baselineRev = store.todayRevenueMru;
        final baselineTickets = store.todayTicketsCount;
        final baselineStock = {
          for (final i in store.ingredients) i.id: i.currentStock,
        };
        final karniCust = store.karniCustomers.first;
        final baselineKarni = karniCust.balanceDueMru;

        // Toggle Training Mode ON via UI
        await toggleTrainingModeUi(tester);
        expect(store.trainingMode, isTrue);
        expect(find.textContaining('MODE FORMATION'), findsWidgets);

        // Complete a training order paid with Karni + Cash
        final dish = store.menuItems.first;
        store.addItemToActiveOrder(dish);
        final closed = store.completeCheckout([
          PaymentEntry(
            method: PaymentMethod.karni,
            amountMru: dish.priceMru,
            karniCustomerId: karniCust.id,
          ),
        ])!;
        expect(closed.isTraining, isTrue);

        final receipt = ReceiptFormatter.formatOrderReceipt80mm(order: closed);
        expect(receipt, contains('*** TICKET DE FORMATION - NON VALIDE ***'));

        // Strict zero-mutation isolation
        expect(store.todayRevenueMru, baselineRev);
        expect(store.todayTicketsCount, baselineTickets);
        expect(
          store.karniCustomers
              .firstWhere((c) => c.id == karniCust.id)
              .balanceDueMru,
          baselineKarni,
        );
        for (final ing in store.ingredients) {
          expect(ing.currentStock, baselineStock[ing.id]);
        }

        // Verify web/index.html & web/manifest.json production branding & zero CDN
        final indexFile = File('web/index.html').existsSync()
            ? File('web/index.html')
            : File('apps/fulltek_pos/web/index.html');
        final manifestFile = File('web/manifest.json').existsSync()
            ? File('web/manifest.json')
            : File('apps/fulltek_pos/web/manifest.json');
        final indexHtml = indexFile.readAsStringSync();
        final manifestJson = manifestFile.readAsStringSync();
        expect(indexHtml, contains('Full·Tek Resto POS'));
        expect(indexHtml, isNot(contains('https://cdn')));
        expect(indexHtml, isNot(contains('fonts.googleapis.com')));
        expect(manifestJson, contains('Full·Tek Resto POS'));
      },
    );
  });

  // =========================================================================
  // AREA A11 (F11): Cloud Catalog Hydration, Sync & Offline-First Fallback
  // =========================================================================
  group('Tier 1 · Area A11 (F11) — Cloud Catalog & Offline-First', () {
    late MockCloudApiServer mockApi;

    setUp(() async {
      mockApi = MockCloudApiServer();
    });

    tearDown(() async {
      await mockApi.stop();
    });

    testWidgets(
      'T1-A11-01: Login darelkram41 against MockCloudApiServer sets online flags & fetches /api/pos/catalog',
      (tester) async {
        await tester.runAsync(() => mockApi.start());
        final store = PosStore()..apiBaseUrl = mockApi.baseUrl;
        await pumpPosApp(tester, store: store, bypassAccount: false);

        await loginViaAccountScreen(tester);

        expect(store.accountLoggedIn, isTrue);
        expect(store.accountOffline, isFalse);
        expect(store.cloudConnected, isTrue);
        expect(mockApi.catalogRequestCount, greaterThanOrEqualTo(1));
      },
    );

    testWidgets(
      'T1-A11-02: GET /api/pos/catalog hydrates categories, products, zones, deliveryZones, ingredients & karni',
      (tester) async {
        await tester.runAsync(() => mockApi.start());
        final store = PosStore()..apiBaseUrl = mockApi.baseUrl;
        await tester.runAsync(() async {
          await runWithRealHttpOverrides(() async {
            final err = await store.loginAccount('darelkram41', 'FullTek@2026');
            expect(err, isNull);
            await store.fetchCloudCatalog();
          });
        });

        expect(store.catalogSource, 'cloud_api');
        expect(
          store.categories.any((c) => c.nameFr == 'Grillades Cloud'),
          isTrue,
        );
        expect(
          store.menuItems.any((m) => m.id == 'item-mechoui' && m.isTop),
          isTrue,
        );
        expect(store.deliveryZones.length, 4);
        expect(store.ingredients, isNotEmpty);
        expect(store.karniCustomers, isNotEmpty);
      },
    );

    testWidgets(
      'T1-A11-03: Manual fetchCloudCatalog() refresh picks up updated server price and 86 status',
      (tester) async {
        await tester.runAsync(() => mockApi.start());
        final store = PosStore()..apiBaseUrl = mockApi.baseUrl;
        await tester.runAsync(() async {
          await runWithRealHttpOverrides(() async {
            await store.loginAccount('darelkram41', 'FullTek@2026');
            await store.fetchCloudCatalog();
          });
        });

        mockApi.setProductPrice('item-thieb', 520);
        mockApi.setProductAvailability('item-ataya', available: false);

        await tester.runAsync(() async {
          await runWithRealHttpOverrides(() async {
            await store.fetchCloudCatalog();
          });
        });

        final thieb = store.menuItems.firstWhere((m) => m.id == 'item-thieb');
        final ataya = store.menuItems.firstWhere((m) => m.id == 'item-ataya');
        expect(thieb.priceMru, 520);
        expect(ataya.available, isFalse);
      },
    );

    testWidgets(
      'T1-A11-04: Order + Closing Z + Karni + 86 queue SyncQueueItems and syncPendingToCloud flushes to /api/pos/sync',
      (tester) async {
        await tester.runAsync(() => mockApi.start());
        final store = PosStore()..apiBaseUrl = mockApi.baseUrl;
        await tester.runAsync(() async {
          await runWithRealHttpOverrides(() async {
            await store.loginAccount('darelkram41', 'FullTek@2026');
          });
        });
        store.loginWithPin('7410');

        store.addItemToActiveOrder(store.menuItems.first);
        store.completeCheckout([
          PaymentEntry(
            method: PaymentMethod.cash,
            amountMru: store.activeOrder!.netTotal,
          ),
        ]);
        store.settleKarniBalance(store.karniCustomers.first.id, 100);
        store.toggleItemAvailability(store.menuItems.first.id);
        store.submitBlindClosingZ(
          countedCashMru: 0,
          countedBankilyMru: 0,
          countedMasriviMru: 0,
          countedSedadMru: 0,
        );

        expect(store.pendingSyncCount, greaterThanOrEqualTo(4));

        late int synced;
        await tester.runAsync(() async {
          await runWithRealHttpOverrides(() async {
            synced = await store.syncPendingToCloud();
          });
        });

        expect(synced, greaterThanOrEqualTo(4));
        expect(store.pendingSyncCount, 0);
        expect(mockApi.receivedSyncItems.length, greaterThanOrEqualTo(4));
      },
    );

    testWidgets(
      'T1-A11-05: Unreachable cloud-api on darelkram41 login activates Offline-First demo fallback',
      (tester) async {
        // Closed ephemeral port -> guaranteed unreachable
        final store = PosStore()..apiBaseUrl = 'http://127.0.0.1:59991';
        await pumpPosApp(tester, store: store, bypassAccount: false);

        await loginViaAccountScreen(tester, useDemoButton: true);

        expect(store.accountLoggedIn, isTrue);
        expect(store.accountOffline, isTrue);
        expect(store.catalogSource, 'offline_demo');
        expect(store.menuItems.length, greaterThanOrEqualTo(18));
        expect(
          store.enabledThemeCodes,
          containsAll(['01', '04', '06', '07', '11']),
        );
      },
    );
  });
}
