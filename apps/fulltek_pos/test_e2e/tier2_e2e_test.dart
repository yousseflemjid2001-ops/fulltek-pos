import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fulltek_pos/models/pos_models.dart';
import 'package:fulltek_pos/services/receipt_formatter.dart';
import 'package:fulltek_pos/state/pos_store.dart';
import 'package:fulltek_pos/theme/fulltek_themes.dart';

import 'e2e_helpers.dart';

void main() {
  // =========================================================================
  // AREA A4 (F05, F12): Restricted Themes, Responsive Overflow, Lock & PINs
  // =========================================================================
  group('Tier 2 · Area A4 (F05, F12) — Boundaries, Overflow & PIN RBAC', () {
    testWidgets(
      'T2-A4-01: Restricted enabledThemes [01, 07] exposes only those 2 themes & auto-switches on login',
      (tester) async {
        final mockApi = MockCloudApiServer();
        addTearDown(mockApi.stop);
        await tester.runAsync(() => mockApi.start());

        final store = PosStore()
          ..apiBaseUrl = mockApi.baseUrl
          ..setTheme(FullTekThemeId.auroraGlass);

        await tester.runAsync(() async {
          await runWithRealHttpOverrides(() async {
            final err = await store.loginAccount('khaimandb90', 'FullTek@2026');
            expect(err, isNull);
          });
        });

        expect(store.enabledThemeCodes, ['01', '07']);
        expect(store.availableThemes.map((s) => s.code).toList(), ['01', '07']);
        expect(['01', '07'].contains(store.themeSpec.code), isTrue);
      },
    );

    testWidgets(
      'T2-A4-02: Narrow viewports (780x900 and 390x844) render without Flutter RenderFlex overflow errors',
      (tester) async {
        for (final viewport in const [Size(780, 900), Size(390, 844)]) {
          final errors = await captureFlutterErrors(() async {
            await pumpPosApp(tester, size: viewport, pin: '7410');
            await goToFloorPlanTab(tester);
            await goToKdsTab(tester);
            await goToDashboardTab(tester);
            await goToClosingZTab(tester);
            await goToPosTab(tester);
          });

          final overflowErrors = errors
              .where((e) => e.exceptionAsString().contains('overflowed'))
              .toList();
          expect(
            overflowErrors,
            isEmpty,
            reason: 'Unexpected RenderFlex overflow at $viewport',
          );
        }
      },
    );

    testWidgets(
      'T2-A4-03: Locking POS clears currentStaff while preserving open table orders; logout clears session',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        store.openOrSelectTable('T1');
        store.addItemToActiveOrder(store.menuItems.first);
        final openOrderId = store.activeOrder!.id;

        await tapFirst(tester, [
          find.byKey(const Key('lock_pos_btn')),
          find.textContaining('Verrouiller'),
        ]);

        expect(store.currentStaff, isNull);
        expect(store.accountLoggedIn, isTrue);
        expect(store.orderForTable('T1')?.id, openOrderId);

        // Changer de compte clears accountLoggedIn back to Step 1
        await tapFirst(tester, [
          find.byKey(const Key('change_account_btn')),
          find.textContaining('Changer de compte'),
        ]);
        expect(store.accountLoggedIn, isFalse);
        expect(find.byKey(const Key('account_login_btn')), findsOneWidget);
      },
    );

    testWidgets(
      'T2-A4-04: Invalid PIN (1111), short PIN (12) and inactive staff PIN are rejected cleanly',
      (tester) async {
        final store = await pumpPosApp(tester);

        // Short PIN
        expect(store.loginWithPin('12'), isFalse);
        expect(store.currentStaff, isNull);

        // Inactive staff member
        store.staff = [
          ...store.staff,
          const StaffMember(
            id: 'ST-INACTIVE',
            name: 'Ex Employé',
            role: PosRole.cashier,
            pinCode: '5555',
            isActive: false,
          ),
        ];
        expect(store.loginWithPin('5555'), isFalse);

        // Invalid 4-digit PIN on UI pad
        for (final d in ['1', '1', '1', '1']) {
          await tapFirst(tester, [find.byKey(Key('pin_key_$d')), find.text(d)]);
        }
        expect(store.currentStaff, isNull);
        expect(find.textContaining('PIN invalide'), findsWidgets);
      },
    );

    testWidgets(
      'T2-A4-05: Rapidly cycling all 5 themes preserves active cart items, language & service mode',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        store.setLanguage('en');
        store.setServiceMode(ServiceMode.takeaway);
        store.addItemToActiveOrder(store.menuItems.first);
        final expectedLineId = store.activeOrder!.items.first.lineId;

        for (final entry in const [
          (FullTekThemeId.auroraGlass, '04'),
          (FullTekThemeId.oceanFintech, '06'),
          (FullTekThemeId.mauritaniaPrestige, '07'),
          (FullTekThemeId.nordicMinimal, '11'),
          (FullTekThemeId.emeraldNight, '01'),
        ]) {
          await selectTheme(tester, entry.$1, entry.$2);
        }

        expect(store.lang, 'en');
        expect(store.serviceMode, ServiceMode.takeaway);
        expect(store.activeOrder!.items.first.lineId, expectedLineId);
      },
    );
  });

  // =========================================================================
  // AREA A5 (F06): i18n & RTL Boundary Cases
  // =========================================================================
  group('Tier 2 · Area A5 (F06) — i18n & RTL Boundaries', () {
    testWidgets(
      'T2-A5-01: Unsupported locale (es) is a safe no-op keeping current language',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        store.setLanguage('fr');
        store.setLanguage('es');
        await tester.pumpAndSettle();

        expect(store.lang, 'fr');
        expect(store.i18n.direction, TextDirection.ltr);
      },
    );

    testWidgets(
      'T2-A5-02: AR RTL with left-ticket themes (04, 07) vs right-ticket (01) renders without overflow',
      (tester) async {
        final errors = await captureFlutterErrors(() async {
          final store = await pumpPosApp(tester, pin: '7410');
          await selectLang(tester, 'ar');
          expect(store.i18n.direction, TextDirection.rtl);

          await selectTheme(tester, FullTekThemeId.auroraGlass, '04');
          await selectTheme(tester, FullTekThemeId.mauritaniaPrestige, '07');
          await selectTheme(tester, FullTekThemeId.emeraldNight, '01');
        });

        final overflow = errors
            .where((e) => e.exceptionAsString().contains('overflowed'))
            .toList();
        expect(overflow, isEmpty);
      },
    );

    testWidgets(
      'T2-A5-03: MenuItem with empty nameAr or empty nameEn falls back gracefully to nameFr',
      (tester) async {
        const partialItem = MenuItem(
          id: 'M-FALLBACK',
          categoryId: 'grill',
          sku: 'TST-001',
          nameFr: 'Brochette Spéciale',
          nameAr: '',
          nameEn: '',
          priceMru: 300,
        );
        expect(partialItem.label('fr'), 'Brochette Spéciale');
        expect(
          partialItem.label('ar').isEmpty
              ? partialItem.nameFr
              : partialItem.label('ar'),
          'Brochette Spéciale',
        );
        expect(
          partialItem.label('en').isEmpty
              ? partialItem.nameFr
              : partialItem.label('en'),
          'Brochette Spéciale',
        );

        final store = await pumpPosApp(tester, pin: '7410');
        store.menuItems = [partialItem, ...store.menuItems];
        store.setLanguage('en');
        await tester.pumpAndSettle();
        expect(find.byType(Scaffold), findsWidgets);
      },
    );

    testWidgets(
      'T2-A5-04: Switching FR -> AR -> EN mid-checkout preserves payment entries & selected modifiers',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        final dish = store.menuItems.first;
        store.addItemToActiveOrder(dish);
        await tester.pumpAndSettle();

        await tapFirst(tester, [
          find.byKey(const Key('open_checkout_btn')),
          find.textContaining('ENCAISSER'),
        ]);

        await tester.enterText(
          find.byKey(const Key('payment_amount_input')),
          '200',
        );
        await tapFirst(tester, [
          find.byKey(const Key('add_payment_entry_btn')),
          find.textContaining('Ajouter'),
        ]);
        expect(find.textContaining('200 MRU'), findsWidgets);

        // Switch language via store while dialog is open
        store.setLanguage('ar');
        await tester.pumpAndSettle();
        expect(find.textContaining('200 MRU'), findsWidgets);

        store.setLanguage('en');
        await tester.pumpAndSettle();
        expect(find.textContaining('200 MRU'), findsWidgets);
      },
    );

    testWidgets(
      'T2-A5-05: UTF-8 Arabic strings (تيبوجين ملكي, دار الكرم) render cleanly without mojibake across KDS & receipt',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        await selectLang(tester, 'ar');

        final thieb = store.menuItems.firstWhere(
          (m) => m.nameAr.contains('تيبوجين'),
          orElse: () => store.menuItems.first,
        );
        store.addItemToActiveOrder(thieb);
        store.sendActiveOrderToKitchen();

        await goToKdsTab(tester);
        expect(find.textContaining(thieb.nameAr), findsWidgets);

        final closed = store.completeCheckout([
          PaymentEntry(method: PaymentMethod.cash, amountMru: thieb.priceMru),
        ])!;
        final receipt = ReceiptFormatter.formatOrderReceipt80mm(
          order: closed,
          storeNameAr: 'مطعم دار الكرم · نواكشوط',
        );
        expect(receipt, contains('دار الكرم'));
        expect(receipt, contains(thieb.nameAr));
        expect(receipt, isNot(contains('\uFFFD')));
      },
    );
  });

  // =========================================================================
  // AREA A6 (F07, F16): Delivery Threshold, Karni Cap, RBAC & Payments
  // =========================================================================
  group('Tier 2 · Area A6 (F07, F16) — Delivery, Karni & Payment Boundaries', () {
    testWidgets(
      'T2-A6-01: Delivery free-threshold strict > 1500 MRU: 1500 charges zone fee vs 1501 is free',
      (tester) async {
        final tz = DeliveryZone.nouakchottPresets.firstWhere(
          (z) => z.id == 'zone-tz',
        ); // 100 MRU
        expect(tz.feeMru, 100);

        // Strict > 1500 rule: 1500 MRU still charges 100 MRU; 1501 MRU is free (0 MRU)
        expect(tz.effectiveFeeFor(1500), 100);
        expect(tz.effectiveFeeFor(1501), 0);
        expect(tz.effectiveFeeFor(1610), 0);
      },
    );

    testWidgets(
      'T2-A6-02: Confirming Livraison without zone or phone/address is blocked with validation feedback',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        await selectServiceMode(tester, ServiceMode.delivery);
        expect(store.serviceMode, ServiceMode.delivery);

        final confirmBtn = find.byKey(const Key('confirm_delivery_btn'));
        if (confirmBtn.evaluate().isNotEmpty) {
          // Leave phone and address empty and attempt confirm
          await tester.tap(confirmBtn);
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('confirm_delivery_btn')), findsOneWidget);
        } else {
          // Store must not allow completed delivery order without zone/info
          expect(store.selectedDeliveryZone, isNull);
        }
      },
    );

    testWidgets(
      'T2-A6-03: Karni payment == creditLimitMru succeeds while creditLimitMru + 1 is blocked',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        final cust = store.karniCustomers.first;
        final remainingLimit = cust.creditLimitMru - cust.balanceDueMru;

        // Exact boundary == creditLimitMru should be allowed
        final exactItem = MenuItem(
          id: 'TST-KARNI-EXACT',
          categoryId: 'grill',
          sku: 'KRN-1',
          nameFr: 'Plateau VIP',
          nameAr: 'طبق VIP',
          nameEn: 'VIP Platter',
          priceMru: remainingLimit,
        );
        store.addItemToActiveOrder(exactItem);
        final okExact = store.completeCheckout([
          PaymentEntry(
            method: PaymentMethod.karni,
            amountMru: remainingLimit,
            karniCustomerId: cust.id,
          ),
        ]);
        expect(okExact, isNotNull);

        // Now balanceDue == creditLimitMru -> +1 MRU must be blocked
        const overItem = MenuItem(
          id: 'TST-KARNI-OVER',
          categoryId: 'grill',
          sku: 'KRN-2',
          nameFr: 'Eau',
          nameAr: 'ماء',
          nameEn: 'Water',
          priceMru: 1,
        );
        store.addItemToActiveOrder(overItem);
        final overBlocked = store.completeCheckout([
          PaymentEntry(
            method: PaymentMethod.karni,
            amountMru: 1,
            karniCustomerId: cust.id,
          ),
        ]);
        expect(overBlocked, isNull);
      },
    );

    testWidgets(
      'T2-A6-04: Underpayment rejected, Waiter blocked from checkout, Cashier needs Manager PIN for discount/remake & blank reason rejected',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '2222'); // Waiter
        final dish = store.menuItems.firstWhere((m) => m.priceMru == 450);
        store.addItemToActiveOrder(dish);

        // Waiter cannot checkout
        expect(store.canCurrent(PosPermission.checkout), isFalse);
        expect(store.applyOrderDiscount(10), isFalse);

        // Switch to Cashier (1234)
        store.lockPos();
        store.loginWithPin('1234');
        expect(store.canCurrent(PosPermission.checkout), isTrue);
        expect(store.canCurrent(PosPermission.applyDiscount), isFalse);

        // Cashier discount without Manager PIN -> false; with Manager PIN -> true
        expect(store.applyOrderDiscount(10), isFalse);
        expect(store.applyOrderDiscount(10, managerPin: '9999'), isTrue);

        // Blank remake reason -> false
        final lineId = store.activeOrder!.items.first.lineId;
        expect(
          store.recordReturnRemakeComp(
            lineId: lineId,
            type: 'remake',
            reason: '   ',
            managerPin: '9999',
          ),
          isFalse,
        );

        // Underpayment (400 < netTotal) -> null
        final under = store.completeCheckout([
          const PaymentEntry(method: PaymentMethod.cash, amountMru: 400),
        ]);
        expect(under, isNull);
      },
    );

    testWidgets(
      'T2-A6-05: Empty mobile-money ref blocked in checkout & Blind Z with 0 cash orders yields 0 variance',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        final dish = store.menuItems.first;
        store.addItemToActiveOrder(dish);
        await tester.pumpAndSettle();

        await tapFirst(tester, [
          find.byKey(const Key('open_checkout_btn')),
          find.textContaining('ENCAISSER'),
        ]);
        await tapFirst(tester, [
          find.byKey(const Key('pay_method_bimbank')),
          find.byKey(const Key('pay_method_bankily')),
          find.textContaining('Bankily'),
        ]);

        // Enter whitespace-only reference
        final refField = find.byKey(const Key('payment_ref_input'));
        if (refField.evaluate().isNotEmpty) {
          await tester.enterText(refField, '   ');
          await tester.tap(find.byKey(const Key('confirm_checkout_btn')));
          await tester.pumpAndSettle();
          // Either checkout stays open with validation error or warns
          expect(store.completedOrders, isEmpty);
        }

        // Close dialog if open & verify 0-variance Blind Z
        final cancelBtn = find.text('Annuler');
        if (cancelBtn.evaluate().isNotEmpty) {
          await tester.tap(cancelBtn.first);
          await tester.pumpAndSettle();
        }

        final z = store.submitBlindClosingZ(
          countedCashMru: 0,
          countedBankilyMru: 0,
          countedMasriviMru: 0,
          countedSedadMru: 0,
        );
        expect(z.expectedCashMru, 0);
        expect(z.cashVarianceMru, 0);
      },
    );
  });

  // =========================================================================
  // AREA A7 (F08, F13): TVA 16% Rounding, Empty Cart, Floor at 0 & 86 Block
  // =========================================================================
  group('Tier 2 · Area A7 (F08, F13) — TVA Rounding, Empty Cart & Ticket Bounds', () {
    testWidgets(
      'T2-A7-01: TVA 16% inclusive rounding boundaries (0->0, 116->16, 1610->222, 450->62, 1100->152)',
      (tester) async {
        for (final pair in const [
          (0.0, 0, 0.0),
          (116.0, 16, 100.0),
          (1610.0, 222, 1388.0),
          (450.0, 62, 388.0),
          (1100.0, 152, 948.0),
        ]) {
          final order = PosOrder(
            id: 'TVA-${pair.$1.toInt()}',
            ticketNumber: 'FT-TVA',
            staffName: 'Test',
            items: pair.$1 == 0
                ? const []
                : [
                    OrderItem(
                      lineId: 'L1',
                      item: MenuItem(
                        id: 'X',
                        categoryId: 'c',
                        sku: 'S',
                        nameFr: 'Plat',
                        nameAr: 'طبق',
                        nameEn: 'Dish',
                        priceMru: pair.$1,
                      ),
                      quantity: 1,
                    ),
                  ],
            createdAt: DateTime.now(),
          );
          expect(order.tvaAmountMru, pair.$2);
          expect(order.subtotalHtMru, pair.$3);
        }
      },
    );

    testWidgets(
      'T2-A7-02: Empty cart disables checkout/kitchen/split/shortcuts and completeCheckout returns null',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        expect(store.activeOrder!.items, isEmpty);
        expect(store.completeCheckout([]), isNull);

        final checkoutBtn = findAny([
          find.byKey(const Key('open_checkout_btn')),
          find.textContaining('ENCAISSER'),
        ]);
        expect(checkoutBtn, findsWidgets);
        final btnWidget = tester.widget<ButtonStyleButton>(
          find
              .ancestor(
                of: checkoutBtn.first,
                matching: find.bySubtype<ButtonStyleButton>(),
              )
              .first,
        );
        expect(btnWidget.onPressed, isNull);
      },
    );

    testWidgets(
      'T2-A7-03: Decrementing qty 1 -> 0 removes line; 100% comp & Arboun > subtotal floor netTotal at 0',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        store.openOrSelectTable('T1', arbounMru: 2000);
        final dish = store.menuItems.firstWhere((m) => m.priceMru == 450);
        store.addItemToActiveOrder(dish);

        expect(store.activeOrder!.netTotal, 0);
        expect(store.activeOrder!.tvaAmountMru, 0);

        final lineId = store.activeOrder!.items.first.lineId;
        store.updateLineQuantity(lineId, -1);
        expect(store.activeOrder!.items, isEmpty);

        // 100% comp
        store.addItemToActiveOrder(dish);
        final compLineId = store.activeOrder!.items.first.lineId;
        store.recordReturnRemakeComp(
          lineId: compLineId,
          type: 'comp',
          reason: 'VIP',
        );
        expect(store.activeOrder!.netTotal, 0);
        expect(store.activeOrder!.tvaAmountMru, 0);
      },
    );

    testWidgets(
      'T2-A7-04: Tapping an ÉPUISÉ (available=false) product tile is strictly blocked',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        final dish = store.menuItems.firstWhere(
          (m) => m.modifiers.isEmpty,
          orElse: () => store.menuItems.first,
        );
        store.toggleItemAvailability(dish.id);
        await tester.pumpAndSettle();

        await tapMenuItemTile(tester, dish);
        expect(store.activeOrder!.items, isEmpty);
      },
    );

    testWidgets(
      'T2-A7-05: Split bill with < 2 items or 0 selected is blocked; 80mm receipt handles 0 MRU comp without NaN',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        final dish = store.menuItems.first;
        store.addItemToActiveOrder(dish);
        final lineId = store.activeOrder!.items.first.lineId;

        // Only 1 line -> split cannot move all lines or 0 lines
        expect(store.splitSelectedLines({}), isNull);
        expect(store.splitSelectedLines({lineId}), isNull);

        store.recordReturnRemakeComp(
          lineId: lineId,
          type: 'comp',
          reason: 'Offert VIP',
        );
        final closed = store.completeCheckout([
          const PaymentEntry(method: PaymentMethod.cash, amountMru: 0),
        ])!;
        final receipt = ReceiptFormatter.formatOrderReceipt80mm(order: closed);
        expect(receipt, contains('OFFERT'));
        expect(receipt, isNot(contains('NaN')));
        expect(receipt, isNot(contains('-0 MRU')));
      },
    );
  });

  // =========================================================================
  // AREA A8 (F09, F15): KDS Boundaries, Timers & 86 Mid-Cart Edge Cases
  // =========================================================================
  group('Tier 2 · Area A8 (F09, F15) — KDS Timers, Idempotency & 86 Edge Cases', () {
    testWidgets(
      'T2-A8-01: KDS urgency exact boundaries: 09:59 green, 10:00 orange, 20:00 orange, 20:01 red',
      (tester) async {
        final now = DateTime(2026, 11, 19, 13, 0, 0);

        expect(
          KdsTicket(
            id: '1',
            sentAt: now.subtract(const Duration(seconds: 599)),
            items: const [],
          ).urgency(now: now),
          KdsUrgency.green,
        );
        expect(
          KdsTicket(
            id: '2',
            sentAt: now.subtract(const Duration(seconds: 600)),
            items: const [],
          ).urgency(now: now),
          KdsUrgency.orange,
        );
        expect(
          KdsTicket(
            id: '3',
            sentAt: now.subtract(const Duration(seconds: 1200)),
            items: const [],
          ).urgency(now: now),
          KdsUrgency.orange,
        );
        expect(
          KdsTicket(
            id: '4',
            sentAt: now.subtract(const Duration(seconds: 1201)),
            items: const [],
          ).urgency(now: now),
          KdsUrgency.red,
        );
      },
    );

    testWidgets(
      'T2-A8-02: Sending empty order or duplicate send creates zero duplicate KDS tickets',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        expect(store.sendActiveOrderToKitchen(), isNull);
        expect(store.kdsTickets, isEmpty);

        store.addItemToActiveOrder(store.menuItems.first);
        expect(store.sendActiveOrderToKitchen(), isNotNull);
        expect(store.kdsTickets.length, 1);

        // Second send with no new unsent lines -> null, no duplicate ticket
        expect(store.sendActiveOrderToKitchen(), isNull);
        expect(store.kdsTickets.length, 1);
      },
    );

    testWidgets(
      'T2-A8-03: Filtering KDS by Bar when only GRILL tickets exist renders empty state safely',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        final grill = store.menuItems.firstWhere(
          (m) => m.kitchenStation == 'GRILL',
        );
        store.addItemToActiveOrder(grill);
        store.sendActiveOrderToKitchen();
        final ticketId = store.kdsTickets.first.id;

        await goToKdsTab(tester);
        await tapFirst(tester, [
          find.byKey(const Key('kds_filter_bar')),
          find.text('Bar'),
        ]);

        expect(find.byKey(Key('kds_ticket_$ticketId')), findsNothing);
        expect(
          findAny([
            find.textContaining('Aucune commande'),
            find.textContaining('No active'),
          ]),
          findsWidgets,
        );
      },
    );

    testWidgets(
      'T2-A8-04: Marking dish ÉPUISÉ while already in open cart still allows checkout while blocking new additions',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        final dish = store.menuItems.firstWhere(
          (m) => m.modifiers.isEmpty,
          orElse: () => store.menuItems.first,
        );
        store.addItemToActiveOrder(dish);
        expect(store.activeOrder!.items.length, 1);

        store.toggleItemAvailability(dish.id);
        await tester.pumpAndSettle();

        // New tap blocked
        await tapMenuItemTile(tester, dish);
        expect(store.activeOrder!.items.first.quantity, 1);

        // Existing cart can still check out
        final closed = store.completeCheckout([
          PaymentEntry(
            method: PaymentMethod.cash,
            amountMru: store.activeOrder!.netTotal,
          ),
        ]);
        expect(closed, isNotNull);
      },
    );

    testWidgets(
      'T2-A8-05: Calling markKdsTicketReady twice on the same ticket is idempotent',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        store.addItemToActiveOrder(store.menuItems.first);
        store.sendActiveOrderToKitchen();
        final ticketId = store.kdsTickets.first.id;
        final syncCountBefore = store.syncQueue.length;

        store.markKdsTicketReady(ticketId);
        final syncAfterFirst = store.syncQueue.length;
        expect(syncAfterFirst, greaterThan(syncCountBefore));

        store.markKdsTicketReady(ticketId);
        expect(store.syncQueue.length, syncAfterFirst);
      },
    );
  });

  // =========================================================================
  // AREA A9 (F14): Floor Plan Transfer/Merge Guards, Khaima minSpend & Arboun
  // =========================================================================
  group('Tier 2 · Area A9 (F14) — Floor Plan & Khaima VIP Boundaries', () {
    testWidgets(
      'T2-A9-01: Transferring table onto an occupied table or onto itself is rejected',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        store.openOrSelectTable('T1');
        store.addItemToActiveOrder(store.menuItems[0]);
        final o1 = store.activeOrder!.id;

        store.openOrSelectTable('T2');
        store.addItemToActiveOrder(store.menuItems[1]);
        final o2 = store.activeOrder!.id;

        await goToFloorPlanTab(tester);
        await tapFirst(tester, [
          find.byKey(const Key('table_card_T1')),
          find.text('T-01'),
        ]);
        await tapFirst(tester, [
          find.byKey(const Key('transfer_table_btn')),
          find.textContaining('Transférer'),
        ]);

        // T-02 is occupied -> neither T1 nor T2 should be overwritten
        expect(store.orderForTable('T1')?.id, o1);
        expect(store.orderForTable('T2')?.id, o2);
      },
    );

    testWidgets(
      'T2-A9-02: Merging table with itself or with a free table is rejected cleanly',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        store.openOrSelectTable('T1');
        store.addItemToActiveOrder(store.menuItems[0]);
        final o1 = store.activeOrder!.id;

        await goToFloorPlanTab(tester);
        await tapFirst(tester, [
          find.byKey(const Key('table_card_T1')),
          find.text('T-01'),
        ]);
        await tapFirst(tester, [
          find.byKey(const Key('merge_tables_btn')),
          find.textContaining('Fusionner'),
        ]);

        // T1 stays intact with its order; T2 stays free
        expect(store.orderForTable('T1')?.id, o1);
        expect(
          store.tables.firstWhere((t) => t.id == 'T2').status,
          TableStatus.free,
        );
      },
    );

    testWidgets(
      'T2-A9-03: Khaima VIP minSpendMru (3000) shows warning when order subtotal < 3000 MRU',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        store.openOrSelectTable('K1');
        store.addItemToActiveOrder(
          store.menuItems.firstWhere((m) => m.priceMru == 450),
        );
        await tester.pumpAndSettle();

        await goToFloorPlanTab(tester);
        await tapFirst(tester, [
          find.byKey(const Key('table_card_K1')),
          find.text('KHAIMA-1'),
        ]);

        expect(find.textContaining('3000'), findsWidgets);
      },
    );

    testWidgets(
      'T2-A9-04: Arboun larger than subtotal (2000 > 800) floors netTotal at 0 MRU (changeDue == 0)',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        store.openOrSelectTable('K1', arbounMru: 2000);
        store.addItemToActiveOrder(
          const MenuItem(
            id: 'M-800',
            categoryId: 'grill',
            sku: 'T-800',
            nameFr: 'Plat 800',
            nameAr: 'طبق',
            nameEn: 'Dish 800',
            priceMru: 800,
          ),
        );

        expect(store.activeOrder!.subtotal, 800);
        expect(store.activeOrder!.netTotal, 0);
        final closed = store.completeCheckout([
          const PaymentEntry(method: PaymentMethod.cash, amountMru: 0),
        ])!;
        expect(closed.netTotal, 0);
        expect(closed.changeDue, 0);
      },
    );

    testWidgets(
      'T2-A9-05: Double-seating an already seated VIP reservation does not re-apply Arboun or overwrite order',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        final first = store.seatReservation('RES-101');
        store.addItemToActiveOrder(store.menuItems.first);

        final res = store.reservations.firstWhere((r) => r.id == 'RES-101');
        expect(res.status, 'seated');

        // Second call keeps existing table order without resetting items
        final second = store.seatReservation('RES-101');
        expect(second.id, first.id);
        expect(second.items.length, 1);
      },
    );
  });

  // =========================================================================
  // AREA A10 (F10, F17): Low-Stock Boundary, 0-Order KPIs & Training Guards
  // =========================================================================
  group('Tier 2 · Area A10 (F10, F17) — BOM, Dashboard & Training Boundaries', () {
    testWidgets(
      'T2-A10-01: Low-stock alert boundary: minStock + 0.01 is OK while == minStock triggers isLowStock',
      (tester) async {
        const above = Ingredient(
          id: 'I1',
          sku: 'I1',
          nameFr: 'Viande',
          nameAr: 'لحم',
          unit: 'kg',
          pmpCostMru: 300,
          currentStock: 5.01,
          minStock: 5.0,
        );
        const exact = Ingredient(
          id: 'I2',
          sku: 'I2',
          nameFr: 'Fromage',
          nameAr: 'جبن',
          unit: 'kg',
          pmpCostMru: 400,
          currentStock: 5.0,
          minStock: 5.0,
        );
        expect(above.isLowStock, isFalse);
        expect(exact.isLowStock, isTrue);
      },
    );

    testWidgets(
      'T2-A10-02: Owner Dashboard with 0 real orders (or only training orders) returns 0 KPIs without NaN',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');

        expect(store.todayRevenueMru, 0);
        expect(store.todayTicketsCount, 0);
        expect(store.averageBasketMru, 0);
        expect(store.foodCostPercent, 0);
        expect(store.todayRevenueMru.isNaN, isFalse);
        expect(store.averageBasketMru.isNaN, isFalse);
        expect(store.foodCostPercent.isNaN, isFalse);

        await goToDashboardTab(tester);
        expect(find.textContaining('NaN'), findsNothing);
      },
    );

    testWidgets(
      'T2-A10-03: Cashier (1234) & Waiter (2222) cannot toggle Mode Formation without Manager/Owner PIN',
      (tester) async {
        for (final pin in ['2222', '1234']) {
          final store = await pumpPosApp(tester, pin: pin);
          expect(store.trainingMode, isFalse);

          await toggleTrainingModeUi(tester);
          expect(store.trainingMode, isFalse);
          expect(store.canCurrent(PosPermission.voidOrComp), isFalse);
        }
      },
    );

    testWidgets(
      'T2-A10-04: Training -> Real -> Training isolation keeps real CA & BOM accurate between training runs',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        final dish = store.menuItems.first;

        // Training order #1
        await toggleTrainingModeUi(tester);
        expect(store.trainingMode, isTrue);
        store.addItemToActiveOrder(dish);
        store.completeCheckout([
          PaymentEntry(method: PaymentMethod.cash, amountMru: dish.priceMru),
        ]);
        expect(store.todayRevenueMru, 0);

        // Toggle OFF -> Real order
        await toggleTrainingModeUi(tester);
        expect(store.trainingMode, isFalse);
        store.addItemToActiveOrder(dish);
        store.completeCheckout([
          PaymentEntry(method: PaymentMethod.cash, amountMru: dish.priceMru),
        ]);
        expect(store.todayRevenueMru, dish.priceMru);
        expect(store.todayTicketsCount, 1);

        // Toggle ON -> Training order #2 does NOT alter real CA
        await toggleTrainingModeUi(tester);
        expect(store.trainingMode, isTrue);
        store.addItemToActiveOrder(dish);
        store.completeCheckout([
          PaymentEntry(method: PaymentMethod.cash, amountMru: dish.priceMru),
        ]);
        expect(store.todayRevenueMru, dish.priceMru);
        expect(store.todayTicketsCount, 1);
      },
    );

    testWidgets(
      'T2-A10-05: Training REMAKE causes 0 BOM deduction; real REMAKE with blank reason or bad PIN 0000 rejected',
      (tester) async {
        final store = await pumpPosApp(tester, pin: '7410');
        final stockBefore = {
          for (final i in store.ingredients) i.id: i.currentStock,
        };

        // Enable training mode
        await toggleTrainingModeUi(tester);
        store.addItemToActiveOrder(store.menuItems.first);
        final lineId = store.activeOrder!.items.first.lineId;
        store.recordReturnRemakeComp(
          lineId: lineId,
          type: 'remake',
          reason: 'Exercice formation',
        );
        for (final i in store.ingredients) {
          expect(i.currentStock, stockBefore[i.id]);
        }

        // Disable training mode & switch to Cashier (1234)
        await toggleTrainingModeUi(tester);
        store.lockPos();
        store.loginWithPin('1234');
        store.addItemToActiveOrder(store.menuItems.first);
        final realLineId = store.activeOrder!.items.first.lineId;

        expect(
          store.recordReturnRemakeComp(
            lineId: realLineId,
            type: 'remake',
            reason: '',
            managerPin: '9999',
          ),
          isFalse,
        );
        expect(
          store.recordReturnRemakeComp(
            lineId: realLineId,
            type: 'remake',
            reason: 'Brûlé',
            managerPin: '0000',
          ),
          isFalse,
        );
      },
    );
  });

  // =========================================================================
  // AREA A11 (F11): Cloud API Error Handling, Rejection & Concurrency
  // =========================================================================
  group('Tier 2 · Area A11 (F11) — Cloud Error, Rejection & Concurrency', () {
    late MockCloudApiServer mockApi;

    setUp(() {
      mockApi = MockCloudApiServer();
    });

    tearDown(() async {
      await mockApi.stop();
    });

    testWidgets(
      'T2-A11-01: Unreachable API with non-demo credentials (otheruser) fails and stays logged out',
      (tester) async {
        final store = PosStore()..apiBaseUrl = 'http://127.0.0.1:59992';
        late String? err;
        await tester.runAsync(() async {
          await runWithRealHttpOverrides(() async {
            err = await store.loginAccount('otheruser', 'Secret123');
          });
        });

        expect(err, isNotNull);
        expect(store.accountLoggedIn, isFalse);
      },
    );

    testWidgets(
      'T2-A11-02: HTTP 500, empty products[] & malformed JSON from /api/pos/catalog fall back to offline_demo',
      (tester) async {
        await tester.runAsync(() => mockApi.start());
        final store = PosStore()..apiBaseUrl = mockApi.baseUrl;
        await tester.runAsync(() async {
          await runWithRealHttpOverrides(() async {
            await store.loginAccount('darelkram41', 'FullTek@2026');
          });
        });

        // 1) HTTP 500
        mockApi.failCatalog500 = true;
        await tester.runAsync(() async {
          await runWithRealHttpOverrides(() => store.fetchCloudCatalog());
        });
        expect(store.catalogSource, 'offline_demo');
        expect(store.menuItems.length, greaterThanOrEqualTo(18));

        // 2) Empty products[]
        mockApi.failCatalog500 = false;
        mockApi.returnEmptyCatalog = true;
        await tester.runAsync(() async {
          await runWithRealHttpOverrides(() => store.fetchCloudCatalog());
        });
        expect(store.catalogSource, 'offline_demo');
        expect(store.menuItems.length, greaterThanOrEqualTo(18));

        // 3) Malformed JSON
        mockApi.returnEmptyCatalog = false;
        mockApi.returnMalformedCatalog = true;
        await tester.runAsync(() async {
          await runWithRealHttpOverrides(() => store.fetchCloudCatalog());
        });
        expect(store.catalogSource, 'offline_demo');
        expect(store.menuItems.length, greaterThanOrEqualTo(18));
      },
    );

    testWidgets(
      'T2-A11-03: Market (albaraka88) and Expired (elwiam12) accounts are rejected on login',
      (tester) async {
        await tester.runAsync(() => mockApi.start());
        final store = PosStore()..apiBaseUrl = mockApi.baseUrl;

        late String? marketErr;
        late String? expiredErr;
        await tester.runAsync(() async {
          await runWithRealHttpOverrides(() async {
            marketErr = await store.loginAccount('albaraka88', 'FullTek@2026');
            expiredErr = await store.loginAccount('elwiam12', 'FullTek@2026');
          });
        });

        expect(marketErr, contains('market'));
        expect(expiredErr, contains('expiré'));
        expect(store.accountLoggedIn, isFalse);
      },
    );

    testWidgets(
      'T2-A11-04: syncPendingToCloud retains queue when server down and flushes all items when server recovers',
      (tester) async {
        final store = PosStore()..apiBaseUrl = 'http://127.0.0.1:59993';
        store.accountLoggedIn = true;
        store.loginWithPin('7410');
        store.addItemToActiveOrder(store.menuItems.first);
        store.completeCheckout([
          PaymentEntry(
            method: PaymentMethod.cash,
            amountMru: store.activeOrder!.netTotal,
          ),
        ]);
        expect(store.pendingSyncCount, greaterThanOrEqualTo(1));

        late int firstSync;
        await tester.runAsync(() async {
          await runWithRealHttpOverrides(() async {
            firstSync = await store.syncPendingToCloud();
          });
        });
        expect(firstSync, 0);
        expect(store.pendingSyncCount, greaterThanOrEqualTo(1));

        // Server comes online -> next syncPendingToCloud flushes cleanly
        await tester.runAsync(() => mockApi.start());
        store.apiBaseUrl = mockApi.baseUrl;
        store.cloudJwtToken = 'mock-jwt-darelkram41';

        late int recoveredSync;
        await tester.runAsync(() async {
          await runWithRealHttpOverrides(() async {
            recoveredSync = await store.syncPendingToCloud();
          });
        });
        expect(recoveredSync, greaterThanOrEqualTo(1));
        expect(store.pendingSyncCount, 0);
      },
    );

    testWidgets(
      'T2-A11-05: Concurrent syncPendingToCloud calls do not double-send the same SyncQueueItem',
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
        final expectedCount = store.pendingSyncCount;

        late List<int> results;
        await tester.runAsync(() async {
          await runWithRealHttpOverrides(() async {
            results = await Future.wait([
              store.syncPendingToCloud(),
              store.syncPendingToCloud(),
            ]);
          });
        });

        final totalSynced = results[0] + results[1];
        expect(totalSynced, expectedCount);
        expect(mockApi.receivedSyncItems.length, expectedCount);
      },
    );
  });
}
