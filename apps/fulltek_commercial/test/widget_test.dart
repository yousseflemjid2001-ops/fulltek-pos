import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fulltek_commercial/main.dart';
import 'package:fulltek_commercial/state/commercial_store.dart';
import 'package:fulltek_commercial/utils/amount_in_words.dart';

void main() {
  group('CommercialMath & AmountInWords calculations', () {
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

    test('computeWeightedPmp, computeMarginPct & amountToFrenchWords', () {
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

      expect(amountToFrenchWords(0), 'Zéro ouguiya');
      expect(amountToFrenchWords(480000), 'Quatre cent quatre-vingts mille ouguiyas');
    });
  });

  group('CommercialStore full ERP Packs 1, 2 & 3 (offline demo)', () {
    test('sales, purchase PMP, POS split, expenses, TVA, inventory & RBAC',
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
          {
            'articleId': firstArt.id,
            'qty': 2,
            'unitPriceHtMru': 1000,
            'discountPct': 0,
          },
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

      // 3. POS session + split payment + park/resume
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

      // 4. Pack 2: Expenses & TVA summary
      final expBefore = store.totalExpensesMru;
      await store.addExpense(
        category: 'Loyer',
        label: 'Loyer test',
        amountMru: 10000,
        payMethod: 'Cash',
      );
      expect(store.totalExpensesMru, expBefore + 10000);
      final tva = store.computeTvaSummary();
      expect(tva.salesTvaCollected, greaterThan(0));

      // 5. Pack 3: Physical Inventory & RBAC
      await store.applyPhysicalInventory(
        warehouseName: 'Dépôt Principal El-Mina',
        countedByArticleId: {firstArt.id: 50},
      );
      expect(store.articles.first.stockQty, 50);
      expect(store.inventorySessions.isNotEmpty, isTrue);

      store.setActiveRole('CASHIER');
      expect(store.canAccessRoute('pos_register'), isTrue);
      expect(store.canAccessRoute('treasury'), isFalse);
      store.setActiveRole('OWNER');
      expect(store.canAccessRoute('treasury'), isTrue);
    });
  });

  group('FullTekCommercialApp Packs 1-3 UI & RTL Arabic navigation', () {
    testWidgets('navigates across core + new Pack 1/2/3 modules and toggles RTL',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final store = CommercialStore(enablePersistence: false);
      await tester.pumpWidget(FullTekCommercialApp(store: store));
      await tester.pumpAndSettle();

      expect(find.text('Full·Tek Commercial'), findsOneWidget);

      store.enterOfflineDemo();
      await tester.pumpAndSettle();

      // Navigate to Dépenses & Charges (Pack 2)
      await tester.tap(find.text('Dépenses & Charges'));
      await tester.pumpAndSettle();
      expect(find.text('Dépenses & Charges d\'exploitation'), findsOneWidget);

      // Navigate to TVA & Balance Âgée (Pack 1 & 2)
      await tester.tap(find.text('TVA & Balance Âgée'));
      await tester.pumpAndSettle();
      expect(
          find.text(
              'Déclaration TVA Mauritanie, Exports Comptables & Balance Âgée'),
          findsOneWidget);

      // Navigate to Relevés de Compte (Pack 1)
      await tester.tap(find.text('Relevés de Compte'));
      await tester.pumpAndSettle();
      expect(find.text('Relevés de Compte (Grand Livre Tiers)'), findsOneWidget);

      // Scroll sidebar to Dépôts & Inventaire (Pack 3)
      await tester.scrollUntilVisible(
        find.text('Dépôts & Inventaire'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Dépôts & Inventaire'));
      await tester.pumpAndSettle();
      expect(find.text('Multi-Dépôts, Inventaire Physique & Import Excel'),
          findsOneWidget);

      // Switch to Arabic RTL (Pack 3)
      await tester.tap(find.text('العربية'));
      await tester.pumpAndSettle();
      expect(store.isRtl, isTrue);
      expect(find.text('FR'), findsOneWidget);
    });
  });
}
