import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fulltek_pos/models/pos_models.dart';
import 'package:fulltek_pos/services/receipt_formatter.dart';
import 'package:fulltek_pos/state/pos_store.dart';
import 'package:fulltek_pos/theme/fulltek_themes.dart';

import 'e2e_helpers.dart';

void main() {
  group('Tier 4 — Real-World Mauritanian Restaurant Shift Scenarios', () {
    testWidgets(
      'T4-01: Vendredi Soir au Salon Khaima VIP (Theme 07 + AR/FR, RES-101 Arboun 2000, KDS, Mixte Cash+Bankily+Karni, Z-Close & Sync)',
      (tester) async {
        final mockApi = MockCloudApiServer();
        addTearDown(mockApi.stop);
        await tester.runAsync(() => mockApi.start());

        final store = PosStore()..apiBaseUrl = mockApi.baseUrl;
        await pumpPosApp(tester, store: store, bypassAccount: false);
        await loginViaAccountScreen(tester);
        expect(store.accountLoggedIn, isTrue);
        expect(store.cloudConnected, isTrue);

        await unlockWithPinPad(tester, '7410');

        // Switch to Theme 07 Mauritanie Prestige + AR RTL, verify RTL, then FR
        await selectTheme(tester, FullTekThemeId.mauritaniaPrestige, '07');
        await selectLang(tester, 'ar');
        expect(store.i18n.direction, TextDirection.rtl);
        await selectLang(tester, 'fr');
        expect(store.i18n.direction, TextDirection.ltr);

        // Seat RES-101 (Famille Ould Ahmed, KHAIMA-1, Arboun 2000 MRU)
        await goToFloorPlanTab(tester);
        await tapFirst(tester, [
          find.byKey(const Key('seat_res_RES-101')),
          find.textContaining('Installer'),
        ]);

        expect(store.activeOrder!.tableCode, 'KHAIMA-1');
        expect(store.activeOrder!.arbounDepositMru, 2000);

        // 2x Méchoui (2*1400=2800) + 2x Ataya (2*150=300) = 3100 - 2000 = 1100 MRU (TVA 152 MRU)
        final mechoui = store.menuItems.firstWhere((m) => m.priceMru == 1400);
        final ataya = store.menuItems.firstWhere((m) => m.priceMru == 150);
        store.addItemToActiveOrder(mechoui);
        store.addItemToActiveOrder(mechoui);
        store.addItemToActiveOrder(ataya);
        store.addItemToActiveOrder(ataya);
        await tester.pumpAndSettle();

        expect(store.activeOrder!.subtotal, 3100);
        expect(store.activeOrder!.netTotal, 1100);
        expect(store.activeOrder!.tvaAmountMru, 152);
        expect(store.activeOrder!.subtotalHtMru, 948);

        // Send to KDS (GRILL + BAR) and mark Plat Prêt on KDS
        store.sendActiveOrderToKitchen();
        await goToKdsTab(tester);
        final ticketId = store.kdsTickets.first.id;
        await tapFirst(tester, [
          find.byKey(Key('kds_ready_$ticketId')),
          find.textContaining('Plat Prêt'),
          find.textContaining('PRÊT'),
        ]);
        expect(store.kdsTickets.where((t) => t.status != 'ready'), isEmpty);

        // Mixed checkout: 500 Cash + 400 Bankily BK-9012 + 300 Karni = 1200 -> 100 MRU change
        final karniCust = store.karniCustomers.first;
        final karniBefore = karniCust.balanceDueMru;
        final closed = store.completeCheckout([
          const PaymentEntry(method: PaymentMethod.cash, amountMru: 500),
          const PaymentEntry(
            method: PaymentMethod.bankily,
            amountMru: 400,
            reference: 'BK-9012',
          ),
          PaymentEntry(
            method: PaymentMethod.karni,
            amountMru: 300,
            karniCustomerId: karniCust.id,
          ),
        ])!;

        expect(closed.changeDue, 100);
        expect(
          store.tables.firstWhere((t) => t.id == 'K1').status,
          TableStatus.free,
        );
        expect(
          store.karniCustomers
              .firstWhere((c) => c.id == karniCust.id)
              .balanceDueMru,
          karniBefore + 300,
        );

        final receipt = ReceiptFormatter.formatOrderReceipt80mm(order: closed);
        expect(receipt, contains('Arboun / عربون'));
        expect(receipt, contains('Dont TVA 16 %'));
        expect(receipt, contains('BK-9012'));

        // Blind Z-Closing: expectedCash = 500 - 100 = 400 MRU
        final z = store.submitBlindClosingZ(
          countedCashMru: 400,
          countedBankilyMru: 400,
          countedMasriviMru: 0,
          countedSedadMru: 0,
        );
        expect(z.expectedCashMru, 400);
        expect(z.cashVarianceMru, 0);

        // Sync to MockCloudApiServer
        await tester.runAsync(() async {
          await runWithRealHttpOverrides(() => store.syncPendingToCloud());
        });
        expect(store.pendingSyncCount, 0);
        expect(
          mockApi.receivedSyncItems.any((i) => i['entity_type'] == 'order'),
          isTrue,
        );
        expect(
          mockApi.receivedSyncItems.any((i) => i['entity_type'] == 'closing_z'),
          isTrue,
        );
      },
    );

    testWidgets(
      'T4-02: Rush du Midi Nouakchott (Emporter w/ packaging BOM, Livraison Ksar 150 vs Arafat >1500 free, Bimbank & Click, Dashboard KPIs)',
      (tester) async {
        final mockApi = MockCloudApiServer();
        addTearDown(mockApi.stop);
        await tester.runAsync(() => mockApi.start());

        final store = PosStore()..apiBaseUrl = mockApi.baseUrl;
        await tester.runAsync(() async {
          await runWithRealHttpOverrides(() async {
            await store.loginAccount('darelkram41', 'FullTek@2026');
            await store.fetchCloudCatalog();
          });
        });
        await pumpPosApp(
          tester,
          store: store,
          bypassAccount: true,
          pin: '1234',
        );

        final boxBefore = store.ingredients
            .firstWhere((i) => i.sku == 'ING-BOX')
            .currentStock;

        // (a) Emporter 2x Méchoui (2*1400 = 2800)
        await selectServiceMode(tester, ServiceMode.takeaway);
        final mechoui = store.menuItems.firstWhere(
          (m) => m.id == 'item-mechoui',
        );
        store.addItemToActiveOrder(mechoui);
        store.addItemToActiveOrder(mechoui);
        expect(store.activeOrder!.serviceMode, ServiceMode.takeaway);
        expect(store.activeOrder!.takeawayNumber, isNotNull);
        store.completeCheckout([
          PaymentEntry(
            method: PaymentMethod.cash,
            amountMru: store.activeOrder!.netTotal,
          ),
        ]);

        final boxAfterTakeaway = store.ingredients
            .firstWhere((i) => i.sku == 'ING-BOX')
            .currentStock;
        expect(boxAfterTakeaway, closeTo(boxBefore - 2.0, 0.001));

        // (b) Livraison Ksar (150 MRU) order of 900 MRU (2x Thiéboudienne 450) -> 1050 MRU, TVA = 145 MRU, Bimbank
        await selectServiceMode(tester, ServiceMode.delivery);
        await selectDeliveryZoneUi(tester, 'Ksar');
        final phoneField = find.byKey(const Key('delivery_phone_input'));
        if (phoneField.evaluate().isNotEmpty) {
          await tester.enterText(phoneField, '+222 46 22 33 44');
        }
        final addrField = find.byKey(const Key('delivery_address_input'));
        if (addrField.evaluate().isNotEmpty) {
          await tester.enterText(addrField, 'Ksar Nord');
        }
        final confirmDelivery = find.byKey(const Key('confirm_delivery_btn'));
        if (confirmDelivery.evaluate().isNotEmpty) {
          await tester.tap(confirmDelivery);
          await tester.pumpAndSettle();
        }

        final thieb = store.menuItems.firstWhere((m) => m.id == 'item-thieb');
        store.addItemToActiveOrder(thieb);
        store.addItemToActiveOrder(thieb);
        expect(store.activeOrder!.deliveryZone?.id, 'zone-ksar');
        expect(store.activeOrder!.netTotal, 1050);
        expect(store.activeOrder!.tvaAmountMru, 145);
        final totalB = store.activeOrder!.netTotal;
        store.completeCheckout([
          PaymentEntry(
            method: PaymentMethod.bimbank,
            amountMru: totalB,
            reference: 'BIM-MIDI-1',
          ),
        ]);

        // (c) Livraison Arafat 1610 MRU (> 1500 -> 0 delivery fee, TVA 222, HT 1388, Click)
        final arafat = store.deliveryZones.firstWhere(
          (z) => z.id == 'zone-arafat',
        );
        expect(arafat.effectiveFeeFor(1610), 0);
        expect(computeExpectedTva16(1610), 222);

        store.setServiceMode(ServiceMode.delivery);
        await tester.pumpAndSettle();
        await selectDeliveryZoneUi(tester, 'Arafat');
        if (find
            .byKey(const Key('delivery_phone_input'))
            .evaluate()
            .isNotEmpty) {
          await tester.enterText(
            find.byKey(const Key('delivery_phone_input')),
            '+222 46 55 66 77',
          );
        }
        if (find
            .byKey(const Key('delivery_address_input'))
            .evaluate()
            .isNotEmpty) {
          await tester.enterText(
            find.byKey(const Key('delivery_address_input')),
            'Arafat Poteau 4',
          );
        }
        if (find
            .byKey(const Key('confirm_delivery_btn'))
            .evaluate()
            .isNotEmpty) {
          await tester.tap(find.byKey(const Key('confirm_delivery_btn')));
          await tester.pumpAndSettle();
        }

        final ataya = store.menuItems.firstWhere((m) => m.id == 'item-ataya');
        store.addItemToActiveOrder(mechoui); // 1400
        store.addItemToActiveOrder(
          ataya,
        ); // +150 = 1550 > 1500 -> 0 delivery fee
        expect(store.activeOrder!.deliveryFeeMru, 0);
        final totalC = store.activeOrder!.netTotal;
        store.completeCheckout([
          PaymentEntry(
            method: PaymentMethod.click,
            amountMru: totalC,
            reference: 'CLK-MIDI-2',
          ),
        ]);

        expect(store.todayTicketsCount, 3);
        expect(
          store.revenueByPaymentMethod[PaymentMethod.bimbank],
          closeTo(totalB, 0.01),
        );
        expect(
          store.revenueByPaymentMethod[PaymentMethod.click],
          closeTo(totalC, 0.01),
        );

        await goToDashboardTab(tester);
        expect(find.textContaining('3'), findsWidgets);
      },
    );

    testWidgets(
      'T4-03: Crise Rupture Cuisine (86) & Remake sous PIN Manager (9999) + double BOM waste + sync',
      (tester) async {
        final mockApi = MockCloudApiServer();
        addTearDown(mockApi.stop);
        await tester.runAsync(() => mockApi.start());

        final store = PosStore()..apiBaseUrl = mockApi.baseUrl;
        await tester.runAsync(() async {
          await runWithRealHttpOverrides(() async {
            await store.loginAccount('darelkram41', 'FullTek@2026');
          });
        });
        await pumpPosApp(
          tester,
          store: store,
          bypassAccount: true,
          pin: '1234',
        );

        // Mark Thiof Braisé ÉPUISÉ (86) on KDS -> POS tile blocked
        final thiof = store.menuItems.firstWhere(
          (m) => m.sku == 'GRL-004' || m.nameFr.contains('Thiof'),
          orElse: () => store.menuItems.first,
        );
        await goToKdsTab(tester);
        store.toggleItemAvailability(thiof.id);
        await tester.pumpAndSettle();
        expect(find.textContaining(thiof.nameFr), findsWidgets);

        await goToPosTab(tester);
        await tapMenuItemTile(tester, thiof);
        expect(store.activeOrder!.items, isEmpty);

        // Customer orders available dish -> Cashier (1234) needs Manager PIN (9999) for REMAKE
        final availableDish = store.menuItems.firstWhere((m) => m.available);
        store.addItemToActiveOrder(availableDish);
        final lineId = store.activeOrder!.items.first.lineId;
        final netBefore = store.activeOrder!.netTotal;

        // Denied without Manager PIN
        expect(
          store.recordReturnRemakeComp(
            lineId: lineId,
            type: 'remake',
            reason: 'Cuisson insuffisante',
          ),
          isFalse,
        );

        final stockBefore = store.ingredients.fold<double>(
          0,
          (s, i) => s + i.currentStock,
        );

        // Approved with Mariem (9999)
        expect(
          store.recordReturnRemakeComp(
            lineId: lineId,
            type: 'remake',
            reason: 'Cuisson insuffisante',
            managerPin: '9999',
          ),
          isTrue,
        );
        expect(store.activeOrder!.netTotal, netBefore); // not double-charged

        store.completeCheckout([
          PaymentEntry(method: PaymentMethod.cash, amountMru: netBefore),
        ]);

        final stockAfter = store.ingredients.fold<double>(
          0,
          (s, i) => s + i.currentStock,
        );
        expect(stockAfter, lessThan(stockBefore));

        await tester.runAsync(() async {
          await runWithRealHttpOverrides(() => store.syncPendingToCloud());
        });
        expect(store.pendingSyncCount, 0);
        expect(
          mockApi.receivedSyncItems.any((i) => i['entity_type'] == 'remake'),
          isTrue,
        );
        expect(
          mockApi.receivedSyncItems.any((i) => i['entity_type'] == 'stock_86'),
          isTrue,
        );
      },
    );

    testWidgets(
      'T4-04: Coupure Internet (Offline-First) -> table merge, checkout & Blind Z queued -> reconnect & sync flush',
      (tester) async {
        // Unreachable port during internet outage
        final store = PosStore()..apiBaseUrl = 'http://127.0.0.1:59994';
        await pumpPosApp(tester, store: store, bypassAccount: false);
        await loginViaAccountScreen(tester, useDemoButton: true);

        expect(store.accountOffline, isTrue);
        expect(store.catalogSource, 'offline_demo');

        // Waiter (2222) opens T-01 & T-02
        await unlockWithPinPad(tester, '2222');
        store.openOrSelectTable('T1');
        store.addItemToActiveOrder(store.menuItems[0]);
        store.openOrSelectTable('T2');
        store.addItemToActiveOrder(store.menuItems[1]);

        // Merge T-02 -> T-01
        await goToFloorPlanTab(tester);
        await tapFirst(tester, [
          find.byKey(const Key('table_card_T2')),
          find.text('T-02'),
        ]);
        await tapFirst(tester, [
          find.byKey(const Key('merge_tables_btn')),
          find.textContaining('Fusionner'),
        ]);
        await tapFirst(tester, [
          find.byKey(const Key('merge_target_T1')),
          find.textContaining('T-01'),
        ]);

        // Cashier (1234) settles merged order via Masrivi + Sedad + Cash
        store.lockPos();
        await tester.pumpAndSettle();
        await unlockWithPinPad(tester, '1234');
        final merged = store.openOrSelectTable('T1');
        final net = merged.netTotal;
        store.completeCheckout([
          const PaymentEntry(
            method: PaymentMethod.masrivi,
            amountMru: 500,
            reference: 'MSR-OFF-1',
          ),
          const PaymentEntry(
            method: PaymentMethod.sedad,
            amountMru: 500,
            reference: 'SED-OFF-2',
          ),
          PaymentEntry(
            method: PaymentMethod.cash,
            amountMru: (net - 1000).clamp(0, net),
          ),
        ]);

        store.submitBlindClosingZ(
          countedCashMru: (net - 1000).clamp(0, net),
          countedBankilyMru: 0,
          countedMasriviMru: 500,
          countedSedadMru: 500,
        );
        expect(store.pendingSyncCount, greaterThanOrEqualTo(2));

        // Internet comes back online
        final mockApi = MockCloudApiServer();
        addTearDown(mockApi.stop);
        await tester.runAsync(() => mockApi.start());
        store.apiBaseUrl = mockApi.baseUrl;
        store.cloudJwtToken = 'mock-jwt-darelkram41';

        late int synced;
        await tester.runAsync(() async {
          await runWithRealHttpOverrides(() async {
            synced = await store.syncPendingToCloud();
          });
        });

        expect(synced, greaterThanOrEqualTo(2));
        expect(store.pendingSyncCount, 0);
      },
    );

    testWidgets(
      'T4-05: Mode Formation en plein service: real 450 MRU Cash baseline + training 7000 MRU Karni/Cash -> 0 mutation & watermark',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        final thieb = store.menuItems.firstWhere((m) => m.priceMru == 450);
        store.addItemToActiveOrder(thieb);
        store.completeCheckout([
          const PaymentEntry(method: PaymentMethod.cash, amountMru: 450),
        ]);

        final stockAfterReal = {
          for (final i in store.ingredients) i.id: i.currentStock,
        };
        final karniCust = store.karniCustomers.first;
        final karniAfterReal = karniCust.balanceDueMru;

        // Owner activates Mode Formation
        await toggleTrainingModeUi(tester);
        expect(store.trainingMode, isTrue);
        expect(find.textContaining('MODE FORMATION'), findsWidgets);

        // Trainee rings up 5x Méchoui (7000 MRU), sends to KDS & pays via Karni + Cash
        final mechoui = store.menuItems.firstWhere((m) => m.priceMru == 1400);
        for (var i = 0; i < 5; i++) {
          store.addItemToActiveOrder(mechoui);
        }
        store.sendActiveOrderToKitchen();
        final trainingOrder = store.completeCheckout([
          PaymentEntry(
            method: PaymentMethod.karni,
            amountMru: 3000,
            karniCustomerId: karniCust.id,
          ),
          const PaymentEntry(method: PaymentMethod.cash, amountMru: 4000),
        ])!;

        final receipt = ReceiptFormatter.formatOrderReceipt80mm(
          order: trainingOrder,
        );
        expect(receipt, contains('*** TICKET DE FORMATION - NON VALIDE ***'));

        // Owner deactivates Mode Formation
        await toggleTrainingModeUi(tester);
        expect(store.trainingMode, isFalse);

        // Real KPIs, stock, Karni & Blind Z remain strictly at 450 MRU baseline
        expect(store.todayRevenueMru, 450);
        expect(store.todayTicketsCount, 1);
        expect(
          store.karniCustomers
              .firstWhere((c) => c.id == karniCust.id)
              .balanceDueMru,
          karniAfterReal,
        );
        for (final ing in store.ingredients) {
          expect(ing.currentStock, stockAfterReal[ing.id]);
        }
        final z = store.submitBlindClosingZ(
          countedCashMru: 450,
          countedBankilyMru: 0,
          countedMasriviMru: 0,
          countedSedadMru: 0,
        );
        expect(z.expectedCashMru, 450);
        expect(z.cashVarianceMru, 0);
      },
    );

    testWidgets(
      'T4-06: Parcours Multi-Rôles RBAC (Waiter 2222 -> Cashier 1234 + Manager 9999 -> Owner 7410 w/ Themes 06/11 rail & Karni repayment)',
      (tester) async {
        // 1) Waiter (2222) takes order on TER-1, splits bill, blocked from Checkout/Closing Z
        final store = await pumpPosApp(tester, pin: '2222');
        store.openOrSelectTable('T5'); // TER-1
        store.addItemToActiveOrder(store.menuItems[0]);
        store.addItemToActiveOrder(store.menuItems[1]);
        final l0 = store.activeOrder!.items.first.lineId;
        store.splitSelectedLines({l0});

        expect(store.canCurrent(PosPermission.checkout), isFalse);
        expect(store.canCurrent(PosPermission.closeCashZ), isFalse);
        expect(store.canCurrent(PosPermission.applyDiscount), isFalse);

        // Lock POS
        await tapFirst(tester, [
          find.byKey(const Key('lock_pos_btn')),
          find.textContaining('Verrouiller'),
        ]);

        // 2) Cashier (1234) logs in, needs Manager (9999) for 15% discount, settles split bills & Karni repayment
        await unlockWithPinPad(tester, '1234');
        expect(store.applyOrderDiscount(15), isFalse);
        expect(store.applyOrderDiscount(15, managerPin: '9999'), isTrue);

        final partNet = store.activeOrder!.netTotal;
        store.completeCheckout([
          PaymentEntry(
            method: PaymentMethod.bankily,
            amountMru: partNet,
            reference: 'BK-SHIFT-1',
          ),
        ]);

        final restOrder = store.openOrSelectTable('T5');
        store.completeCheckout([
          PaymentEntry(
            method: PaymentMethod.cash,
            amountMru: restOrder.netTotal,
          ),
        ]);

        // Karni repayment reduces customer debt
        final karniCust = store.karniCustomers.first;
        final beforeBal = karniCust.balanceDueMru;
        await goToKarniTab(tester);
        store.settleKarniBalance(karniCust.id, 500);
        expect(
          store.karniCustomers
              .firstWhere((c) => c.id == karniCust.id)
              .balanceDueMru,
          closeTo(beforeBal - 500, 0.01),
        );

        // Blind Closing Z by Cashier
        store.submitBlindClosingZ(
          countedCashMru: restOrder.netTotal,
          countedBankilyMru: partNet,
          countedMasriviMru: 0,
          countedSedadMru: 0,
        );

        // Lock -> Owner (7410) inspects Dashboard & Themes 06 / 11 rail layout
        store.lockPos();
        await tester.pumpAndSettle();
        await unlockWithPinPad(tester, '7410');

        await selectTheme(tester, FullTekThemeId.oceanFintech, '06');
        expect(store.themeSpec.categoriesAsRail, isTrue);

        await selectTheme(tester, FullTekThemeId.nordicMinimal, '11');
        expect(store.themeSpec.categoriesAsRail, isTrue);

        await goToDashboardTab(tester);
        expect(store.todayTicketsCount, 2);
        expect(
          store.todayRevenueMru,
          closeTo(partNet + restOrder.netTotal, 0.01),
        );
      },
    );
  });
}
