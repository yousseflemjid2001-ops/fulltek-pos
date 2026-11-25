import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fulltek_pos/main.dart';
import 'package:fulltek_pos/models/pos_models.dart';
import 'package:fulltek_pos/services/receipt_formatter.dart';
import 'package:fulltek_pos/state/pos_store.dart';
import 'package:fulltek_pos/theme/fulltek_themes.dart';
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
  });
}
