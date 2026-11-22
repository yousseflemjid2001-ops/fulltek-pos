import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fulltek_commercial/main.dart';
import 'package:fulltek_commercial/state/commercial_store.dart';

void main() {
  group('CommercialMath financial calculations', () {
    test('computeLineHt & computeLineTva apply 16% TVA and discount correctly',
        () {
      final ht = CommercialMath.computeLineHt(
        qty: 2,
        unitPriceHt: 1000,
        discountPct: 10,
      );
      final tva = CommercialMath.computeLineTva(
        lineHt: ht,
        isExempt: false,
        tvaRate: 16,
      );
      expect(ht, 1800);
      expect(tva, 288);
    });

    test('computeLineTva respects TVA exemption (0%)', () {
      final ht = CommercialMath.computeLineHt(
        qty: 3,
        unitPriceHt: 500,
      );
      final tva = CommercialMath.computeLineTva(
        lineHt: ht,
        isExempt: true,
        tvaRate: 16,
      );
      expect(ht, 1500);
      expect(tva, 0);
    });

    test('computeWeightedPmp & computeMarginPct calculate accurately', () {
      final pmp = CommercialMath.computeWeightedPmp(
        currentStock: 10,
        currentPmp: 100,
        incomingQty: 10,
        incomingCostHt: 140,
      );
      expect(pmp, 120);

      final marginPct = CommercialMath.computeMarginPct(
        caHt: 1000,
        costMru: 750,
      );
      expect(marginPct, 25.0);
    });
  });

  group('CommercialStore full ERP business processes (offline demo)', () {
    test('sales cycle, purchase PMP reception, POS split & treasury work end-to-end',
        () async {
      final store = CommercialStore(enablePersistence: false);
      store.enterOfflineDemo();

      final initialMovements = store.treasuryMovements.length;
      final firstArt = store.articles.first;
      final initialStock = firstArt.stockQty;
      final firstCli = store.clients.first;

      // 1. Multi-line Sales Invoice + Payment
      final errSale = await store.createSalesDoc(
        docType: 'FACTURE',
        clientId: firstCli.id,
        validateNow: true,
        lines: [
          {'articleId': firstArt.id, 'qty': 2, 'unitPriceHtMru': 1000, 'discountPct': 0},
        ],
      );
      expect(errSale, isNull);
      expect(store.articles.first.stockQty, initialStock - 2);
      final createdDoc = store.salesDocs.first;
      expect(createdDoc.lines.length, 1);

      final errPay = await store.paySalesDoc(
        createdDoc.id,
        payMethod: 'Bankily',
        amountMru: createdDoc.totalTtcMru,
      );
      expect(errPay, isNull);
      expect(store.salesDocs.first.status, 'PAYEE');
      expect(store.treasuryMovements.length, greaterThan(initialMovements));

      // 2. Purchase Reception recalculates stock & PMP
      final firstSup = store.suppliers.first;
      final stockBeforeRec = store.articles.first.stockQty;
      final errRec = await store.createPurchaseDoc(
        docType: 'RECEPTION',
        supplierId: firstSup.id,
        validateNow: true,
        lines: [
          {'articleId': firstArt.id, 'qty': 10, 'unitCostHt': 500},
        ],
      );
      expect(errRec, isNull);
      expect(store.articles.first.stockQty, stockBeforeRec + 10);

      // 3. POS session + split payment ticket
      await store.openNewPosSession(
        registerCode: 'C1',
        cashierName: 'Test',
        openingFloatMru: 5000,
      );
      final errPos = await store.submitPosTicket(
        lines: [
          {'articleId': firstArt.id, 'qty': 1},
        ],
        payments: [
          {'payMethod': 'Cash', 'amountMru': 500},
          {'payMethod': 'Bankily', 'amountMru': 500},
        ],
      );
      expect(errPos, isNull);
      expect(store.posTickets.first.payMethod, 'Cash + Bankily');
    });
  });

  group('FullTekCommercialApp offline demo & navigation', () {
    testWidgets('enters offline demo and navigates across commercial modules',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final store = CommercialStore(enablePersistence: false);
      await tester.pumpWidget(FullTekCommercialApp(store: store));
      await tester.pumpAndSettle();

      // Starts on login screen
      expect(find.text('Full·Tek Commercial'), findsOneWidget);

      // Enter offline demo
      store.enterOfflineDemo();
      await tester.pumpAndSettle();

      // Shell sidebar & dashboard rendered
      expect(find.text('Tableau de bord'), findsWidgets);
      expect(find.text('Clients & Karni'), findsOneWidget);
      expect(find.text('Écran de caisse'), findsOneWidget);
      expect(find.text('Trésorerie'), findsWidgets);

      // Navigate to Clients & Karni
      await tester.tap(find.text('Clients & Karni'));
      await tester.pumpAndSettle();
      expect(find.text('Clients & Comptes Karni'), findsOneWidget);

      // Navigate to Articles & Stock
      await tester.tap(find.text('Articles & Stock'));
      await tester.pumpAndSettle();
      expect(find.text('Catalogue Articles & Stock PMP'), findsOneWidget);

      // Navigate to Écran de caisse
      await tester.tap(find.text('Écran de caisse'));
      await tester.pumpAndSettle();
      expect(find.text('Ticket en cours'), findsOneWidget);

      // Navigate to Trésorerie
      await tester.tap(find.text('Trésorerie').first);
      await tester.pumpAndSettle();
      expect(find.text('Trésorerie — Caisses & Banques'), findsOneWidget);

      // Navigate to Factures clients (scroll sidebar if needed)
      await tester.scrollUntilVisible(
        find.text('Factures clients'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Factures clients'));
      await tester.pumpAndSettle();
      expect(find.text('Factures clients'), findsWidgets);
    });
  });
}
