import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fulltek_pos/main.dart';
import 'package:fulltek_pos/models/pos_models.dart';
import 'package:fulltek_pos/services/http_bridge.dart';
import 'package:fulltek_pos/services/receipt_formatter.dart';
import 'package:fulltek_pos/state/pos_store.dart';
import 'package:fulltek_pos/theme/fulltek_themes.dart';
import 'package:fulltek_pos/widgets/qr_code_widget.dart';
import 'package:fulltek_pos/widgets/touch_keyboard.dart';

void main() {
  group('PosStore — Core Full-Tek Resto Business Logic', () {
    test('PIN auth, 9-role RBAC matrix & Manager PIN elevation', () {
      final store = PosStore();
      expect(store.currentStaff, isNull);
      expect(store.loginWithPin('9876'), isFalse);

      // Login as Waiter (2222)
      expect(store.loginWithPin('2222'), isTrue);
      expect(store.currentStaff!.role, PosRole.waiter);
      expect(store.canCurrent(PosPermission.takeOrders), isTrue);
      expect(store.canCurrent(PosPermission.checkout), isFalse);
      expect(store.canCurrent(PosPermission.voidOrComp), isFalse);

      // Add item & attempt comp without Manager PIN -> denied
      store.addItemToActiveOrder(store.menuItems.first);
      final lineId = store.activeOrder!.items.first.lineId;
      expect(
        store.recordReturnRemakeComp(
          lineId: lineId,
          type: 'comp',
          reason: 'Geste client',
        ),
        isFalse,
      );

      // With Manager PIN (9999) -> approved & line becomes free (0 MRU)
      expect(
        store.recordReturnRemakeComp(
          lineId: lineId,
          type: 'comp',
          reason: 'Geste VIP',
          managerPin: '9999',
        ),
        isTrue,
      );
      expect(store.activeOrder!.items.first.isComp, isTrue);
      expect(store.activeOrder!.subtotal, 0);
      expect(store.remakeRecords.length, 1);
      expect(store.remakeRecords.first.approvedBy, contains('Mariem'));
    });

    test('Khaima VIP reservation seating deducts Arboun & mixed payment updates Karni + 80mm receipt', () {
      final store = PosStore();
      expect(store.loginWithPin('7410'), isTrue); // Owner

      // Seat RES-101 (Famille Ould Ahmed, KHAIMA-1, Arboun 2000 MRU)
      final order = store.seatReservation('RES-101');
      expect(order.tableCode, 'KHAIMA-1');
      expect(order.arbounDepositMru, 2000);

      // Add 2x Méchoui (2 * 1400 = 2800) + 2x Ataya (2 * 150 = 300) => Subtotal 3100 - Arboun 2000 = 1100 MRU
      final mechoui = store.menuItems.firstWhere((m) => m.sku == 'RIM-002');
      final ataya = store.menuItems.firstWhere((m) => m.sku == 'DRK-001');
      store.addItemToActiveOrder(mechoui);
      store.addItemToActiveOrder(mechoui);
      store.addItemToActiveOrder(ataya);
      store.addItemToActiveOrder(ataya);

      expect(store.activeOrder!.subtotal, 3100);
      expect(store.activeOrder!.netTotal, 1100);

      // Send to Kitchen (KDS ticket)
      final kdsTicket = store.sendActiveOrderToKitchen();
      expect(kdsTicket, isNotNull);
      expect(kdsTicket, contains('KHAIMA-1'));
      expect(kdsTicket, contains('GRILL'));

      // Mixed payment: 500 Cash + 400 Bankily + 300 Karni = 1200 MRU -> Change 100 MRU
      final karniBefore = store.karniCustomers.first.balanceDueMru;
      final closed = store.completeCheckout([
        const PaymentEntry(method: PaymentMethod.cash, amountMru: 500),
        const PaymentEntry(
            method: PaymentMethod.bankily, amountMru: 400, reference: 'BK-9012'),
        PaymentEntry(
          method: PaymentMethod.karni,
          amountMru: 300,
          karniCustomerId: store.karniCustomers.first.id,
        ),
      ]);

      expect(closed, isNotNull);
      expect(closed!.changeDue, 100);
      expect(store.karniCustomers.first.balanceDueMru, karniBefore + 300);

      // Table K1 freed automatically
      final k1 = store.tables.firstWhere((t) => t.id == 'K1');
      expect(k1.status, TableStatus.free);

      // 80mm bilingual FR/AR receipt formatting
      final receipt = ReceiptFormatter.formatOrderReceipt80mm(order: closed);
      expect(receipt, contains('FULL-TEK RESTO POS'));
      expect(receipt, contains('Arboun / عربون'));
      expect(receipt, contains('Bankily / بنكيلي'));
      expect(receipt, contains('BK-9012'));
      expect(receipt, contains('100 MRU'));

      // Blind Z-Closing: expected cash = 500 - 100 change = 400 MRU
      final z = store.submitBlindClosingZ(
        countedCashMru: 450,
        countedBankilyMru: 400,
        countedMasriviMru: 0,
        countedSedadMru: 0,
      );
      expect(z.expectedCashMru, 400);
      expect(z.cashVarianceMru, 50); // +50 MRU surplus
      expect(z.expectedBankilyMru, 400);
      expect(z.karniIssuedMru, 300);
      expect(store.pendingSyncCount, greaterThanOrEqualTo(2));
    });

    test('Split bill by items moves selected lines to sub-order', () {
      final store = PosStore();
      store.loginWithPin('1234');
      store.openOrSelectTable('T1');
      store.addItemToActiveOrder(store.menuItems[0]);
      store.addItemToActiveOrder(store.menuItems[1]);
      final firstLineId = store.activeOrder!.items.first.lineId;

      final sub = store.splitSelectedLines({firstLineId});
      expect(sub, isNotNull);
      expect(sub!.items.length, 1);
      expect(sub.ticketNumber, endsWith('-S'));
    });
  });

  group('FullTekPosApp — Widget Integration (5 Themes, FR/AR RTL, Checkout & Z)', () {
    testWidgets('Login PIN, switch Arabic RTL & 5 themes, checkout with 80mm receipt',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final store = PosStore()..accountLoggedIn = true;
      await tester.pumpWidget(FullTekPosApp(store: store));
      await tester.pumpAndSettle();

      // Switch to Arabic -> RTL verified
      await tester.tap(find.byKey(const Key('lang_btn_ar')));
      await tester.pumpAndSettle();
      expect(store.lang, 'ar');
      expect(store.i18n.direction, TextDirection.rtl);

      // Switch back to French & switch theme to Mauritanie Prestige (07)
      await tester.tap(find.byKey(const Key('lang_btn_fr')));
      await tester.pumpAndSettle();
      store.setTheme(FullTekThemeId.mauritaniaPrestige);
      await tester.pumpAndSettle();
      expect(store.themeId, FullTekThemeId.mauritaniaPrestige);

      // Unlock POS using Quick Profile PIN 0000 (Owner)
      await tester.tap(find.byKey(const Key('quick_pin_7410')));
      await tester.pumpAndSettle();

      // Tap first menu item (Thiéboudienne Royal — 450 MRU)
      await tester.tap(find.byKey(const Key('menu_item_M1')));
      await tester.pumpAndSettle();
      if (find.byKey(const Key('confirm_modifiers_btn')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('confirm_modifiers_btn')));
        await tester.pumpAndSettle();
      }
      expect(find.textContaining('450 MRU'), findsWidgets);

      // Open Checkout & confirm
      await tester.tap(find.byKey(const Key('open_checkout_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm_checkout_btn')));
      await tester.pumpAndSettle();

      // 80mm thermal receipt preview is displayed
      expect(find.byKey(const Key('receipt_80mm_text')), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Live Zoom 90% -> 110% -> 100% must never unmount Navigator or block UI
      await tester.tap(find.byKey(const Key('zoom_menu_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('90%'));
      await tester.pumpAndSettle();
      expect(store.uiZoom, closeTo(0.9, 0.01));

      await tester.tap(find.byKey(const Key('zoom_menu_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('80%'));
      await tester.pumpAndSettle();
      expect(store.uiZoom, closeTo(0.8, 0.01));

      await tester.tap(find.byKey(const Key('zoom_menu_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('100% (Normal)'));
      await tester.pumpAndSettle();
      expect(store.uiZoom, closeTo(1.0, 0.01));

      // Navigate to Closing Z & submit blind closing
      await tester.tap(find.byKey(const Key('nav_tab_closing')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('z_counted_cash_input')), '450');
      await tester.tap(find.byKey(const Key('submit_closing_z_btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('receipt_80mm_text')), findsOneWidget);
    });

    testWidgets(
      'TouchKeyboardHost switches FR/MAJ/CAPS, Arabic (عربي) and Numeric (123) live',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          TouchKeyboardController.instance.setAutoOpen(false);
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final ctrl = TextEditingController();
        TouchKeyboardController.instance.setAutoOpen(true);

        await tester.pumpWidget(
          MaterialApp(
            theme: FullTekThemes.all[FullTekThemeId.emeraldNight]!.toThemeData(),
            builder: (ctx, child) => TouchKeyboardHost(child: child!),
            home: Scaffold(
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: TextField(
                      key: const Key('kb_test_input'),
                      controller: ctrl,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        // Focus field -> keyboard pops up automatically
        await tester.tap(find.byKey(const Key('kb_test_input')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('global_touch_keyboard')), findsOneWidget);

        // Tap Shift (MAJ) -> tap 'a' -> produces uppercase 'A', then auto-returns to lowercase 'z'
        await tester.tap(find.byKey(const Key('touch_kb_shift_btn')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('touch_kb_key_a')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('touch_kb_key_z')));
        await tester.pumpAndSettle();
        expect(ctrl.text, 'Az');

        // Switch to Arabic (عربي) -> tap 'ض' -> inserts Arabic letter
        await tester.tap(find.byKey(const Key('touch_kb_mode_ar')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('touch_kb_key_ض')));
        await tester.pumpAndSettle();
        expect(ctrl.text, 'Azض');

        // Switch to Numeric (123) -> tap '7' and '5' -> inserts '75'
        await tester.tap(find.byKey(const Key('touch_kb_mode_num')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('touch_kb_num_7')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('touch_kb_num_5')));
        await tester.pumpAndSettle();
        expect(ctrl.text, 'Azض75');

        // Tap anywhere outside the input and keyboard -> keyboard hides automatically
        await tester.tapAt(const Offset(1100, 200));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('global_touch_keyboard')), findsNothing);

        // Tap back into the input -> keyboard re-opens automatically
        await tester.tap(find.byKey(const Key('kb_test_input')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('global_touch_keyboard')), findsOneWidget);

        ctrl.dispose();
      },
    );

    test('Bouton Quantite, Offert (Article & Tout le ticket) dans X/Z, et Profils Back-Office', () {
      final store = PosStore(enablePersistence: false);
      expect(store.loginWithPin('7410'), true); // Owner

      // 1. Bouton Quantite: setLineQuantity sets exact quantity directly & is modifiable (10 -> 7)
      final item1 = store.menuItems.first;
      final item2 = store.menuItems[1];
      store.addItemToActiveOrder(item1);
      store.addItemToActiveOrder(item2);
      final line1 = store.activeOrder!.items.first;
      expect(store.setLineQuantity(line1.lineId, 10), true);
      expect(store.activeOrder!.items.first.quantity, 10);
      expect(store.setLineQuantity(line1.lineId, 7), true);
      expect(store.activeOrder!.items.first.quantity, 7);

      // 2. Partial Comp (1 article) + Whole-ticket Comp with auto-close
      expect(
        store.recordOrderCompOrReturn(
          type: 'comp',
          reason: 'Geste VIP',
          lineIds: [line1.lineId],
          wholeOrder: false,
        ),
        true,
      );
      expect(store.activeOrder!.items.first.isComp, true);
      expect(store.unclosedCompCount, 7);

      // Now offer the remaining item as whole-ticket comp + auto-close
      expect(
        store.recordOrderCompOrReturn(
          type: 'comp',
          reason: 'Offert Direction',
          wholeOrder: true,
          autoCloseCompOrder: true,
        ),
        true,
      );
      expect(store.unclosedCompCount, 8);
      expect(store.unclosedCompTotalMru, greaterThan(0));

      // 3. Rapport X & Cloture Z both include Offerts (Comp) + detail section
      final xReport = store.generateReportX80mm();
      expect(xReport, contains('Offerts (Comp):'));
      expect(xReport, contains('DETAIL OFFRES (OFFERTS)'));
      expect(xReport, contains('Geste VIP'));

      final z = store.submitBlindClosingZ(
        countedCashMru: 0,
        countedBankilyMru: 0,
        countedMasriviMru: 0,
        countedSedadMru: 0,
        countedBimbankMru: 0,
        countedClickMru: 0,
      );
      final zReport = store.formatClosingZ80mm(z);
      expect(zReport, contains('Offerts (Comp):'));
      expect(zReport, contains('DETAIL OFFRES (OFFERTS)'));

      // 4. Back-Office Profiles & granular module permissions
      final boAccountant =
          store.profiles.firstWhere((p) => p.id == 'prof-bo-accountant');
      final boStock =
          store.profiles.firstWhere((p) => p.id == 'prof-bo-stock');
      expect(boAccountant.can(PosPermission.accessBackOffice), true);
      expect(boAccountant.can(PosPermission.boAccounting), true);
      expect(boAccountant.can(PosPermission.boSuppliersPurchases), false);
      expect(boStock.can(PosPermission.accessBackOffice), true);
      expect(boStock.can(PosPermission.boSuppliersPurchases), true);
      expect(boStock.can(PosPermission.boAccounting), false);
    });

    test('Menu QR Code encoder, SVG generation & incoming QR order import', () async {
      final store = PosStore(enablePersistence: false);
      expect(store.loginWithPin('7410'), true);

      final genUrl = store.qrMenuUrl();
      final tableUrl = store.qrMenuUrl(tableCode: 'T1');
      expect(genUrl, contains('/m/'));
      expect(tableUrl, contains('?table=T1'));

      final matrix = QrCodeEncoder.encode(tableUrl);
      expect(matrix.size, greaterThanOrEqualTo(21));
      final svg = matrix.toSvg(pixelSize: 200);
      expect(svg, contains('<svg'));
      expect(svg, contains('<path'));

      final firstItem = store.menuItems.first;
      store.incomingQrOrders = [
        {
          'orderCode': 'QR-99001',
          'serviceMode': 'takeaway',
          'customerName': 'Karim',
          'customerPhone': '36322225',
          'notes': 'Sans piment',
          'totalMru': firstItem.priceMru * 3,
          'items': [
            {
              'sku': firstItem.sku,
              'nameFr': firstItem.nameFr,
              'qty': 3,
              'unitPrice': firstItem.priceMru,
            },
          ],
        },
        {
          'orderCode': 'QR-99002',
          'serviceMode': 'delivery',
          'customerName': 'Sidi',
          'customerPhone': '46112233',
          'deliveryZone': 'Tevragh Zeina',
          'totalMru': firstItem.priceMru,
          'items': [
            {
              'sku': firstItem.sku,
              'nameFr': firstItem.nameFr,
              'qty': 1,
              'unitPrice': firstItem.priceMru,
            },
          ],
        },
      ];

      // Multi-Caisses: Poste Salle uniquement ignores takeaway & delivery QR orders
      store.setRegisterChannelConfig(
        name: 'Poste Salle',
        dineIn: true,
        takeaway: false,
        delivery: false,
      );
      expect(store.incomingQrTotalCount, 0);

      // Caisse Emporter uniquement sees only QR-99001 (takeaway)
      store.setRegisterChannelConfig(
        name: 'Caisse Emporter',
        dineIn: false,
        takeaway: true,
        delivery: false,
      );
      expect(store.incomingQrTotalCount, 1);

      final accepted = await store
          .acceptIncomingQrOrder(store.incomingQrOrdersForRegister.first);
      expect(accepted, true);
      expect(store.incomingQrTotalCount, 0);
      expect(store.activeOrder, isNotNull);
      expect(store.activeOrder!.ticketNumber, 'QR-99001');
      expect(store.activeOrder!.customerName, 'Karim');
      expect(store.activeOrder!.customerPhone, '36322225');
      expect(store.activeOrder!.items.first.quantity, 3);

      // Kitchen ticket & 80mm receipt both print Client & Tel even in Emporter mode
      final kdsTicket = store.sendActiveOrderToKitchen();
      expect(kdsTicket, contains('Client: Karim'));
      expect(kdsTicket, contains('Tel: 36322225'));

      // GPS extraction & WhatsApp driver share on Delivery order
      final delivOrder = PosOrder(
        id: 'ORD-GPS-1',
        ticketNumber: 'QR-99002',
        staffName: 'Caisse',
        serviceMode: ServiceMode.delivery,
        deliveryZone: DeliveryZone.nouakchottPresets.first,
        customerName: 'Sidi',
        customerPhone: '46112233',
        deliveryAddress:
            'Près Pharmacie · 📍 GPS: https://maps.google.com/?q=18.094512,-15.978421',
        items: store.activeOrder!.items,
        createdAt: DateTime.now(),
      );
      expect(
        delivOrder.gpsMapsUrl,
        'https://maps.google.com/?q=18.094512,-15.978421',
      );
      expect(delivOrder.cleanDeliveryAddress, 'Près Pharmacie');
      expect(delivOrder.whatsappDriverShareUrl, contains('wa.me'));
      final receipt80 = ReceiptFormatter.formatOrderReceipt80mm(order: delivOrder);
      expect(receipt80, contains('Adresse: Près Pharmacie'));
      expect(
        receipt80,
        contains('GPS: https://maps.google.com/?q=18.094512,-15.978421'),
      );
    });

    test('Journal Audit caisse (Mouchard) & Facturation tickets A4', () {
      final store = PosStore(enablePersistence: false);
      expect(store.loginWithPin('7410'), true);

      store.addItemToActiveOrder(store.menuItems.first);
      store.requestAdditionForActiveOrder();
      store.recordCashDrawerOpen(reason: 'Test fond de caisse');
      final total = store.activeOrder!.netTotal;
      final paid = store.completeCheckout([
        PaymentEntry(method: PaymentMethod.cash, amountMru: total),
      ]);
      expect(paid, isNotNull);

      final invNo = store.createInvoiceNumberForOrders([paid!]);
      expect(invNo, startsWith('FAC-'));
      expect(store.invoicedTicketsByOrderId[paid.id], invNo);

      final actions = store.fullAuditTimeline.map((e) => e.action).toSet();
      expect(actions, containsAll(['EDITION NOTE', 'OUVERTURE TIROIR', 'VENTE', 'FACTURATION']));
    });

    test('Hydratation Cloud des ventes historiques (Hier, Semaine, Mois, Année)', () async {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final fiveDaysAgo = now.subtract(const Duration(days: 5));
      final twentyDaysAgo = now.subtract(const Duration(days: 20));

      final store = PosStore(
        enablePersistence: false,
        httpRequest: (method, url, {headers, body}) async {
          if (url.endsWith('/api/pos/backoffice/summary')) {
            return HttpBridgeResponse(
              200,
              jsonEncode({
                'ok': true,
                'suppliers': [],
                'purchases': [],
                'expenses': [],
                'invoices': [],
                'orders': [
                  {
                    'id': 'ORD-CLOUD-101',
                    'ticket_number': 'FT-HIER-01',
                    'staff_name': 'Fatimetou',
                    'service_mode': 'DINE_IN',
                    'total_mru': 650,
                    'pay_method': 'Cash',
                    'created_at': yesterday.toUtc().toIso8601String(),
                    'paid_at': yesterday.toUtc().toIso8601String(),
                    'items': [
                      {
                        'name': 'Méchoui Royal',
                        'qty': 1,
                        'unit_price': 650,
                      },
                    ],
                  },
                  {
                    'id': 'ORD-CLOUD-102',
                    'ticket_number': 'FT-SEM-02',
                    'staff_name': 'Mariatta',
                    'service_mode': 'TAKEAWAY',
                    'total_mru': 400,
                    'pay_method': 'Bankily',
                    'created_at': fiveDaysAgo.toUtc().toIso8601String(),
                    'paid_at': fiveDaysAgo.toUtc().toIso8601String(),
                    'items': [
                      {
                        'name': 'Chawarma',
                        'qty': 2,
                        'unit_price': 200,
                      },
                    ],
                  },
                  {
                    'id': 'ORD-CLOUD-103',
                    'ticket_number': 'FT-MOIS-03',
                    'staff_name': 'Med Lemine',
                    'service_mode': 'DELIVERY',
                    'delivery_zone': 'Tevragh Zeina',
                    'total_mru': 1200,
                    'pay_method': 'Masrvi',
                    'created_at': twentyDaysAgo.toUtc().toIso8601String(),
                    'paid_at': twentyDaysAgo.toUtc().toIso8601String(),
                    'items': [
                      {
                        'name': 'Thieboudienne',
                        'qty': 2,
                        'unit_price': 600,
                      },
                    ],
                  },
                ],
                'remakes': [
                  {
                    'id': 'RRC-CLOUD-1',
                    'type': 'comp',
                    'orderTicket': 'FT-HIER-01',
                    'itemName': 'Thé Ataya',
                    'quantity': 1,
                    'amountMru': 100,
                    'reason': 'Offert client fidèle',
                    'staffName': 'Fatimetou',
                    'approvedBy': 'Gérant',
                    'createdAt': yesterday.toUtc().toIso8601String(),
                  },
                ],
              }),
            );
          }
          return const HttpBridgeResponse(200, '{}');
        },
      );
      store.cloudJwtToken = 'test-jwt';
      store.accountOffline = false;
      await store.fetchBackOfficeData();

      final tickets = store.completedOrders.map((o) => o.ticketNumber).toSet();
      expect(tickets, containsAll(['FT-HIER-01', 'FT-SEM-02', 'FT-MOIS-03']));
      expect(
        store.fullAuditTimeline.map((e) => e.ticketNumber),
        containsAll(['FT-HIER-01', 'FT-SEM-02', 'FT-MOIS-03']),
      );
    });
  });
}
