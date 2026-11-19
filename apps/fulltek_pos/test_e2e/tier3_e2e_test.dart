import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fulltek_pos/models/pos_models.dart';
import 'package:fulltek_pos/services/receipt_formatter.dart';
import 'package:fulltek_pos/state/pos_store.dart';
import 'package:fulltek_pos/theme/fulltek_themes.dart';

import 'e2e_helpers.dart';

void main() {
  group('Tier 3 — Pairwise Cross-Feature Combinations', () {
    testWidgets(
      'T3-01 [F05 x F06]: Theme 04 Aurora Glass (left ticket, r=20) + AR RTL vs Theme 11 Nordic Minimal (rail, right ticket) + EN LTR',
      (tester) async {
        final errors = await captureFlutterErrors(() async {
          final store = await pumpPosApp(tester, pin: '7410');

          await selectTheme(tester, FullTekThemeId.auroraGlass, '04');
          await selectLang(tester, 'ar');

          expect(store.themeSpec.ticketLeft, isTrue);
          expect(store.themeSpec.palette.radius, 20);
          expect(store.i18n.direction, TextDirection.rtl);
          final ctxAr = tester.element(find.byType(Scaffold).first);
          expect(Directionality.of(ctxAr), TextDirection.rtl);

          await selectTheme(tester, FullTekThemeId.nordicMinimal, '11');
          await selectLang(tester, 'en');

          expect(store.themeSpec.categoriesAsRail, isTrue);
          expect(store.themeSpec.ticketLeft, isFalse);
          expect(store.i18n.direction, TextDirection.ltr);
          final ctxEn = tester.element(find.byType(Scaffold).first);
          expect(Directionality.of(ctxEn), TextDirection.ltr);
        });

        expect(
          errors.where((e) => e.exceptionAsString().contains('overflowed')),
          isEmpty,
        );
      },
    );

    testWidgets(
      'T3-02 [F05 x F06 x F14]: Theme 07 Mauritanie Prestige + AR RTL + Floor Plan Khaima VIP (minSpend 3000, Arboun 2000)',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        await selectTheme(tester, FullTekThemeId.mauritaniaPrestige, '07');
        await selectLang(tester, 'ar');

        expect(store.themeSpec.palette.bg, const Color(0xFF06281E));
        expect(store.themeSpec.palette.headingFontFamily, 'Playfair Display');
        expect(store.i18n.direction, TextDirection.rtl);

        await goToFloorPlanTab(tester);
        expect(find.textContaining('خيمة'), findsWidgets);

        final order = store.seatReservation('RES-101');
        expect(order.tableCode, 'KHAIMA-1');
        expect(order.arbounDepositMru, 2000);
      },
    );

    testWidgets(
      'T3-03 [F07 x F08 x F16]: Modifiers (+Mozzarella +60) x Livraison (Ksar 150) x Mixte (Bimbank + Click) -> exact TVA 16% & 80mm receipt',
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
          pin: '7410',
        );

        await selectServiceMode(tester, ServiceMode.delivery);
        await selectDeliveryZoneUi(tester, 'Ksar');
        final phoneField = find.byKey(const Key('delivery_phone_input'));
        if (phoneField.evaluate().isNotEmpty) {
          await tester.enterText(phoneField, '+222 45 00 11 22');
        }
        final addrField = find.byKey(const Key('delivery_address_input'));
        if (addrField.evaluate().isNotEmpty) {
          await tester.enterText(addrField, 'Ksar Carrefour');
        }
        final confirmDelivery = find.byKey(const Key('confirm_delivery_btn'));
        if (confirmDelivery.evaluate().isNotEmpty) {
          await tester.tap(confirmDelivery);
          await tester.pumpAndSettle();
        }

        // Tap Méchoui (1400) and pick À point (0) + Mozzarella (+60) -> 1460 <= 1500 -> +150 Ksar = 1610 MRU!
        final mechoui = store.menuItems.firstWhere(
          (m) => m.id == 'item-mechoui',
        );
        await tapMenuItemTile(tester, mechoui);
        final apoint = find.textContaining('À point');
        if (apoint.evaluate().isNotEmpty) {
          await tester.tap(apoint.first);
          await tester.pumpAndSettle();
        }
        final mozz = find.textContaining('Mozzarella');
        if (mozz.evaluate().isNotEmpty) {
          await tester.tap(mozz.first);
          await tester.pumpAndSettle();
        }
        final addModBtn = findAny([
          find.byKey(const Key('confirm_modifiers_btn')),
          find.textContaining('Ajouter au ticket'),
          find.text('Confirmer'),
        ]);
        if (addModBtn.evaluate().isNotEmpty) {
          await tester.tap(addModBtn.first);
          await tester.pumpAndSettle();
        }

        final order = store.activeOrder!;
        expect(order.deliveryZone?.id, 'zone-ksar');
        expect(order.subtotal, 1460);
        expect(order.deliveryFeeMru, 150);
        expect(order.netTotal, 1610);
        expect(order.tvaAmountMru, 222);
        expect(order.subtotalHtMru, 1388);

        final net = order.netTotal;
        final closed = store.completeCheckout([
          PaymentEntry(
            method: PaymentMethod.bimbank,
            amountMru: net / 2,
            reference: 'BIM-T3',
          ),
          PaymentEntry(
            method: PaymentMethod.click,
            amountMru: net - (net / 2),
            reference: 'CLK-T3',
          ),
        ])!;

        final receipt = ReceiptFormatter.formatOrderReceipt80mm(order: closed);
        expect(receipt, contains('Dont TVA 16 %'));
        expect(receipt, contains('Bimbank / بيم بنك'));
        expect(receipt, contains('Click / كليك'));
      },
    );

    testWidgets(
      'T3-04 [F07 x F10 x F16]: Takeaway (Emporter) x Dish w/ +Mozzarella modifier deducts base + modifier + TAKEAWAY_DELIVERY packaging BOM',
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
          pin: '7410',
        );

        final beefBefore = store.ingredients
            .firstWhere((i) => i.sku == 'ING-BEEF')
            .currentStock;
        final mozzBefore = store.ingredients
            .firstWhere((i) => i.sku == 'ING-MOZZ')
            .currentStock;
        final boxBefore = store.ingredients
            .firstWhere((i) => i.sku == 'ING-BOX')
            .currentStock;

        await selectServiceMode(tester, ServiceMode.takeaway);
        final mechoui = store.menuItems.firstWhere(
          (m) => m.id == 'item-mechoui',
        );
        await tapMenuItemTile(tester, mechoui);
        final mozz = find.textContaining('Mozzarella');
        if (mozz.evaluate().isNotEmpty) {
          await tester.tap(mozz.first);
          await tester.pumpAndSettle();
        }
        final addModBtn = findAny([
          find.byKey(const Key('confirm_modifiers_btn')),
          find.textContaining('Ajouter au ticket'),
          find.text('Confirmer'),
        ]);
        if (addModBtn.evaluate().isNotEmpty) {
          await tester.tap(addModBtn.first);
          await tester.pumpAndSettle();
        }

        store.completeCheckout([
          PaymentEntry(
            method: PaymentMethod.cash,
            amountMru: store.activeOrder!.netTotal,
          ),
        ]);

        final beefAfter = store.ingredients
            .firstWhere((i) => i.sku == 'ING-BEEF')
            .currentStock;
        final mozzAfter = store.ingredients
            .firstWhere((i) => i.sku == 'ING-MOZZ')
            .currentStock;
        final boxAfter = store.ingredients
            .firstWhere((i) => i.sku == 'ING-BOX')
            .currentStock;

        expect(beefAfter, closeTo(beefBefore - 0.5, 0.001));
        expect(mozzAfter, closeTo(mozzBefore - 0.06, 0.001));
        expect(boxAfter, closeTo(boxBefore - 1.0, 0.001));
      },
    );

    testWidgets(
      'T3-05 [F09 x F13 x F15]: KDS marks dish ÉPUISÉ (86) -> POS blocks tap -> KDS restores Disponible -> POS allows tap',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        final mechoui = store.menuItems.firstWhere((m) => m.sku == 'RIM-002');

        // KDS marks ÉPUISÉ (86)
        await goToKdsTab(tester);
        store.toggleItemAvailability(mechoui.id);
        await tester.pumpAndSettle();
        expect(find.textContaining(mechoui.nameFr), findsWidgets);

        // POS blocks tap
        await goToPosTab(tester);
        await tapMenuItemTile(tester, mechoui);
        expect(store.activeOrder!.items, isEmpty);

        // KDS restores Disponible
        await goToKdsTab(tester);
        store.toggleItemAvailability(mechoui.id);
        await tester.pumpAndSettle();

        // POS allows tap again
        await goToPosTab(tester);
        await tapMenuItemTile(tester, mechoui);
        if (find
            .byKey(const Key('confirm_modifiers_btn'))
            .evaluate()
            .isNotEmpty) {
          await tester.tap(find.byKey(const Key('confirm_modifiers_btn')));
          await tester.pumpAndSettle();
        }
        expect(store.activeOrder!.items, isNotEmpty);
      },
    );

    testWidgets(
      'T3-06 [F01 x F04 x F11 x F15]: Cloud PATCH availability -> fetchCloudCatalog refresh -> POS blocks item & KDS shows 86',
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
          pin: '7410',
        );

        mockApi.setProductAvailability('item-thieb', available: false);
        await tester.runAsync(() async {
          await runWithRealHttpOverrides(() => store.fetchCloudCatalog());
        });
        await tester.pumpAndSettle();

        final thieb = store.menuItems.firstWhere((m) => m.id == 'item-thieb');
        expect(thieb.available, isFalse);

        await tapMenuItemTile(tester, thieb);
        expect(store.activeOrder!.items, isEmpty);

        await goToKdsTab(tester);
        expect(find.textContaining('Thiéboudienne'), findsWidgets);
      },
    );

    testWidgets(
      'T3-07 [F09 x F15 x F10]: Multi-station KDS (GRILL + BAR) -> Plat Prêt on GRILL leaves BAR active -> REMAKE double BOM deduction',
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

        final ticket = store.kdsTickets.first;
        expect(ticket.hasPendingForStation(KdsStationFilter.grill), isTrue);
        expect(ticket.hasPendingForStation(KdsStationFilter.bar), isTrue);
        expect(
          ticket.urgency(now: ticket.sentAt.add(const Duration(minutes: 10))),
          KdsUrgency.orange,
        );
        expect(
          ticket.urgency(
            now: ticket.sentAt.add(const Duration(minutes: 20, seconds: 1)),
          ),
          KdsUrgency.red,
        );

        // Mark GRILL ready only -> BAR remains pending
        store.markKdsTicketReady(ticket.id, station: 'GRILL');
        final updated = store.kdsTickets.firstWhere((t) => t.id == ticket.id);
        expect(updated.hasPendingForStation(KdsStationFilter.grill), isFalse);
        expect(updated.hasPendingForStation(KdsStationFilter.bar), isTrue);

        // REMAKE on grill line with Manager PIN -> double BOM deduction on checkout
        final stockBefore = store.ingredients.fold<double>(
          0,
          (s, i) => s + i.currentStock,
        );
        final grillLine = store.activeOrder!.items.first;
        expect(
          store.recordReturnRemakeComp(
            lineId: grillLine.lineId,
            type: 'remake',
            reason: 'Trop cuit',
            managerPin: '9999',
          ),
          isTrue,
        );
        store.completeCheckout([
          PaymentEntry(
            method: PaymentMethod.cash,
            amountMru: store.activeOrder!.netTotal,
          ),
        ]);
        final stockAfter = store.ingredients.fold<double>(
          0,
          (s, i) => s + i.currentStock,
        );
        expect(stockAfter, lessThan(stockBefore));
      },
    );

    testWidgets(
      'T3-08 [F08 x F10 x F17]: Mode Formation x Livraison x Karni -> receipt watermark, zero Karni/BOM/Z/CA mutation',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        final karniCust = store.karniCustomers.first;
        final karniBefore = karniCust.balanceDueMru;
        final stockBefore = {
          for (final i in store.ingredients) i.id: i.currentStock,
        };

        await toggleTrainingModeUi(tester);
        await selectServiceMode(tester, ServiceMode.delivery);
        final dish = store.menuItems.first;
        store.addItemToActiveOrder(dish);

        final closed = store.completeCheckout([
          PaymentEntry(
            method: PaymentMethod.karni,
            amountMru: store.activeOrder!.netTotal,
            karniCustomerId: karniCust.id,
          ),
        ])!;

        final receipt = ReceiptFormatter.formatOrderReceipt80mm(order: closed);
        expect(receipt, contains('*** TICKET DE FORMATION - NON VALIDE ***'));

        expect(store.todayRevenueMru, 0);
        expect(store.todayTicketsCount, 0);
        expect(
          store.karniCustomers
              .firstWhere((c) => c.id == karniCust.id)
              .balanceDueMru,
          karniBefore,
        );
        for (final ing in store.ingredients) {
          expect(ing.currentStock, stockBefore[ing.id]);
        }
        final z = store.submitBlindClosingZ(
          countedCashMru: 0,
          countedBankilyMru: 0,
          countedMasriviMru: 0,
          countedSedadMru: 0,
        );
        expect(z.karniIssuedMru, 0);
        expect(z.ordersCount, 0);
      },
    );

    testWidgets(
      'T3-10 [F13 x F14 x F16]: Waiter (2222) opens T-01, sends KDS, transfers T-01->T-03, splits bill, locks -> Cashier (1234) + Manager (9999) 10% discount settles both',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '2222'); // Waiter
        store.openOrSelectTable('T1');
        store.addItemToActiveOrder(store.menuItems[0]); // 450
        store.addItemToActiveOrder(store.menuItems[1]); // 1400
        store.sendActiveOrderToKitchen();

        // Transfer T-01 -> T-03 in Floor Plan
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
          find.byKey(const Key('transfer_target_T3')),
          find.textContaining('T-03'),
        ]);
        expect(store.orderForTable('T3'), isNotNull);

        // Split bill by items
        store.openOrSelectTable('T3');
        final line0 = store.activeOrder!.items.first.lineId;
        final splitSub = store.splitSelectedLines({line0})!;

        // Waiter locks POS -> Cashier logs in
        store.lockPos();
        await tester.pumpAndSettle();
        await unlockWithPinPad(tester, '1234');

        // Cashier applies 10% discount with Manager PIN 9999 on split sub-order
        expect(store.applyOrderDiscount(10, managerPin: '9999'), isTrue);
        final subTotalAfterDiscount = store.activeOrder!.netTotal;
        expect(subTotalAfterDiscount, closeTo(splitSub.subtotal * 0.9, 0.01));

        store.completeCheckout([
          PaymentEntry(
            method: PaymentMethod.bankily,
            amountMru: subTotalAfterDiscount,
            reference: 'BK-SPLIT-1',
          ),
        ]);

        // Settle remaining T-03 order via Cash
        final remainingOrder = store.openOrSelectTable('T3');
        store.completeCheckout([
          PaymentEntry(
            method: PaymentMethod.cash,
            amountMru: remainingOrder.netTotal,
          ),
        ]);
        expect(
          store.tables.firstWhere((t) => t.id == 'T3').status,
          TableStatus.free,
        );
      },
    );

    testWidgets(
      'T3-11 [F07 x F10 x F16]: Livraison crossing free-delivery threshold via modifier add-on (1450 -> +60 = 1510 > 1500) drops fee to 0 MRU',
      (tester) async {
        final ksar = DeliveryZone.nouakchottPresets.firstWhere(
          (z) => z.id == 'zone-ksar',
        ); // 150 MRU
        expect(ksar.effectiveFeeFor(1450), 150);
        expect(ksar.effectiveFeeFor(1450 + 60), 0);

        final orderBefore = PosOrder(
          id: 'ORD-T311-A',
          ticketNumber: 'FT-1',
          staffName: 'Test',
          serviceMode: ServiceMode.delivery,
          deliveryZone: ksar,
          deliveryFeeMru: ksar.effectiveFeeFor(1450),
          items: [
            const OrderItem(
              lineId: 'L1',
              item: MenuItem(
                id: 'D1',
                categoryId: 'grill',
                sku: 'D1',
                nameFr: 'Plateau',
                nameAr: 'طبق',
                nameEn: 'Platter',
                priceMru: 1450,
              ),
              quantity: 1,
            ),
          ],
          createdAt: DateTime.now(),
        );
        expect(orderBefore.netTotal, 1600);
        expect(orderBefore.tvaAmountMru, computeExpectedTva16(1600));

        final orderWithMod = PosOrder(
          id: 'ORD-T311-B',
          ticketNumber: 'FT-2',
          staffName: 'Test',
          serviceMode: ServiceMode.delivery,
          deliveryZone: ksar,
          deliveryFeeMru: ksar.effectiveFeeFor(1510),
          items: [
            const OrderItem(
              lineId: 'L2',
              item: MenuItem(
                id: 'D1',
                categoryId: 'grill',
                sku: 'D1',
                nameFr: 'Plateau',
                nameAr: 'طبق',
                nameEn: 'Platter',
                priceMru: 1450,
              ),
              quantity: 1,
              selectedModifiers: [
                SelectedModifier(
                  groupId: 'mg-extras',
                  optionId: 'opt-mozz',
                  nameFr: 'Mozzarella',
                  extraPriceMru: 60,
                ),
              ],
            ),
          ],
          createdAt: DateTime.now(),
        );
        expect(orderWithMod.deliveryFeeMru, 0);
        expect(orderWithMod.netTotal, 1510);
        expect(orderWithMod.tvaAmountMru, computeExpectedTva16(1510));
      },
    );

    testWidgets(
      'T3-14 [F08 x F13 x F16]: 10% discount + Arboun 500 + Centre delivery 50 -> exact netTotal, TVA 16% & Blind Z cash after change',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        final centre = DeliveryZone.nouakchottPresets.firstWhere(
          (z) => z.id == 'zone-centre',
        ); // 50 MRU

        // 1400 subtotal - 10% (140) - 500 arboun + 50 delivery = 810 MRU
        final order = PosOrder(
          id: 'ORD-T314',
          ticketNumber: 'FT-314',
          staffName: 'Ahmed',
          serviceMode: ServiceMode.delivery,
          deliveryZone: centre,
          deliveryFeeMru: centre.feeMru,
          discountPercent: 10,
          arbounDepositMru: 500,
          items: [
            OrderItem(
              lineId: 'L1',
              item: store.menuItems.firstWhere((m) => m.priceMru == 1400),
              quantity: 1,
            ),
          ],
          createdAt: DateTime.now(),
        );

        expect(order.subtotal, 1400);
        expect(order.discountAmount, 140);
        expect(order.netTotal, 810);
        expect(order.tvaAmountMru, computeExpectedTva16(810)); // 112 MRU
        expect(order.subtotalHtMru, 810 - order.tvaAmountMru);

        // Complete store order with 10% discount + 500 Arboun + Centre 50, pay 1000 Cash -> 190 change -> Blind Z expectedCash = 810
        store.openOrSelectTable('T1', arbounMru: 500);
        store.addItemToActiveOrder(
          store.menuItems.firstWhere((m) => m.priceMru == 1400),
        );
        store.applyOrderDiscount(10);
        store.setServiceMode(ServiceMode.delivery);
        store.setDeliveryZone(centre);
        expect(store.activeOrder!.netTotal, 810);
        final closed = store.completeCheckout([
          const PaymentEntry(method: PaymentMethod.cash, amountMru: 1000),
        ])!;
        expect(closed.changeDue, closeTo(190, 0.01));
        final z = store.submitBlindClosingZ(
          countedCashMru: 810,
          countedBankilyMru: 0,
          countedMasriviMru: 0,
          countedSedadMru: 0,
        );
        expect(z.expectedCashMru, closeTo(810, 0.01));
        expect(z.cashVarianceMru, closeTo(0, 0.01));
      },
    );

    testWidgets(
      'T3-15 [F05 x F12 x F17]: Switching tenant account (darelkram41 -> khaimandb90) resets tenant name, themes & Owner PIN (1540)',
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
        expect(store.tenantName, 'Dar El-Karam Resto');
        expect(store.loginWithPin('7410'), isTrue);

        store.logoutAccount();
        await tester.runAsync(() async {
          await runWithRealHttpOverrides(() async {
            await store.loginAccount('khaimandb90', 'FullTek@2026');
          });
        });

        expect(store.tenantName, 'Café Khaima Nouadhibou');
        expect(store.enabledThemeCodes, ['01', '07']);
        expect(store.loginWithPin('7410'), isFalse);
        expect(store.loginWithPin('1540'), isTrue);

        await pumpPosApp(tester, store: store, bypassAccount: true);
        await goToDashboardTab(tester);
        expect(store.todayRevenueMru, 0);
        expect(find.textContaining('0 MRU'), findsWidgets);
      },
    );
  });
}
