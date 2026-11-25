import 'package:flutter_test/flutter_test.dart';
import 'package:fulltek_pos/models/pos_models.dart';
import 'package:fulltek_pos/services/receipt_formatter.dart';

void main() {
  group('F07 — Core Models: Modifiers, Delivery, Payments, KDS, BOM', () {
    test('Nouakchott DeliveryZone presets and free delivery threshold', () {
      expect(DeliveryZone.nouakchottPresets.length, 4);
      final centre = DeliveryZone.nouakchottPresets
          .firstWhere((z) => z.id == 'zone-centre');
      final tz =
          DeliveryZone.nouakchottPresets.firstWhere((z) => z.id == 'zone-tz');
      final ksar =
          DeliveryZone.nouakchottPresets.firstWhere((z) => z.id == 'zone-ksar');
      final arafat = DeliveryZone.nouakchottPresets
          .firstWhere((z) => z.id == 'zone-arafat');

      expect(centre.feeMru, 100);
      expect(tz.feeMru, 100);
      expect(ksar.feeMru, 150);
      expect(arafat.feeMru, 150);
      expect(DeliveryZone.freeDeliveryAboveMru, 1500.0);

      expect(tz.effectiveFeeFor(0), 0);
      expect(tz.effectiveFeeFor(1499), 100);
      expect(tz.effectiveFeeFor(1500), 0);
      expect(tz.effectiveFeeFor(2200), 0);
    });

    test('Modifier price math, OrderItem lineTotal & PosOrder TVA 16%', () {
      const item = MenuItem(
        id: 'M5',
        categoryId: 'grill',
        sku: 'GRL-001',
        nameFr: 'Mix Grill',
        nameAr: 'مشويات مشكلة',
        nameEn: 'Mix Grill',
        priceMru: 750,
        kitchenStation: 'GRILL',
      );
      const grp = ModifierGroup(
        id: 'mg-extras',
        nameFr: 'Suppléments',
        nameAr: 'إضافات',
        nameEn: 'Extras',
        options: [
          ModifierOption(
            id: 'opt-mozz',
            nameFr: 'Mozzarella',
            nameAr: 'موزاريلا',
            nameEn: 'Mozzarella',
            extraPriceMru: 55,
            bomKey: '+Mozzarella',
          ),
        ],
      );
      final sel1 = SelectedModifier.fromOption(
          group: grp, option: grp.options.first);
      final sel2 = SelectedModifier.fromOption(
          group: grp, option: grp.options.first);
      expect(sel1, equals(sel2));
      expect(sel1.hashCode, equals(sel2.hashCode));

      final line = OrderItem(
        lineId: 'LN-1',
        item: item,
        quantity: 2,
        selectedModifiers: [sel1],
      );
      expect(line.modifiersTotalMru, 55);
      expect(line.unitPriceWithModifiers, 805);
      expect(line.lineTotal, 1610);

      final order = PosOrder(
        id: 'ORD-1',
        ticketNumber: 'FT-2001',
        staffName: 'Aïcha',
        items: [line],
        createdAt: DateTime(2026, 11, 19, 12, 0),
      );
      expect(order.netTotal, 1610);
      expect(order.tvaAmountMru, 222); // round(1610 * 16 / 116) = 222
      expect(order.subtotalHtMru, 1388);

      final emptyOrder = PosOrder(
        id: 'ORD-0',
        ticketNumber: 'FT-2000',
        staffName: 'Aïcha',
        items: const [],
        deliveryFeeMru: 100,
        createdAt: DateTime(2026, 11, 19, 12, 0),
      );
      expect(emptyOrder.netTotal, 0);
      expect(emptyOrder.tvaAmountMru, 0);
      expect(emptyOrder.subtotalHtMru, 0);
    });

    test('KdsTicket urgency thresholds (<10m green, 10-20m orange, >20m red)',
        () {
      final base = DateTime(2026, 11, 19, 12, 0, 0);
      final ticket = KdsTicket(
        id: 'KDS-1',
        orderId: 'ORD-1',
        orderCode: 'FT-1050',
        tableCode: 'T-08',
        sentAt: base,
        items: const [
          KdsTicketItem(
            lineId: 'L1',
            productId: 'M2',
            sku: 'RIM-002',
            nameFr: 'Méchoui',
            nameAr: 'مشوي',
            nameEn: 'Mechoui',
            quantity: 1,
            kitchenStation: 'GRILL',
          ),
        ],
      );

      expect(ticket.urgency(now: base.add(const Duration(minutes: 9))),
          KdsUrgency.green);
      expect(
          ticket.urgency(
              now: base.add(const Duration(minutes: 9, seconds: 59))),
          KdsUrgency.green);
      expect(ticket.urgency(now: base.add(const Duration(minutes: 10))),
          KdsUrgency.orange);
      expect(ticket.urgency(now: base.add(const Duration(minutes: 20))),
          KdsUrgency.orange);
      expect(
          ticket.urgency(
              now: base.add(const Duration(minutes: 20, seconds: 1))),
          KdsUrgency.red);
      expect(ticket.urgency(now: base.add(const Duration(minutes: 21))),
          KdsUrgency.red);
      expect(
          ticket.formattedElapsed(
              now: base.add(const Duration(minutes: 12, seconds: 5))),
          '12:05');
    });

    test('Ingredient.isLowStock and DiningTable compatibility helpers', () {
      const okIng = Ingredient(
        id: '1',
        sku: 'ING-1',
        nameFr: 'Riz',
        nameAr: 'أرز',
        unit: 'kg',
        pmpCostMru: 45,
        currentStock: 8.1,
        minStock: 8.0,
      );
      final lowIng = okIng.copyWith(currentStock: 8.0);
      expect(okIng.isLowStock, isFalse);
      expect(lowIng.isLowStock, isTrue);

      final t0 = DateTime(2026, 11, 19, 13, 0);
      final tbl = DiningTable(
        id: 'T8',
        zoneId: 'terrace',
        code: 'T-08',
        seats: 4,
        status: TableStatus.occupied,
        openedAt: t0,
        shape: TableShape.round,
      );
      expect(tbl.capacity, 4);
      expect(tbl.seats, 4);
      expect(tbl.occupiedSince, t0);
      expect(tbl.isWaiting(t0.add(const Duration(minutes: 19))), isFalse);
      expect(tbl.isWaiting(t0.add(const Duration(minutes: 20))), isTrue);
    });
  });

  group('F08 — 80mm Bilingual Thermal Receipt Formatter', () {
    test(
        'Prints delivery info, modifiers, TVA 16%, all 7 payments & training watermark',
        () {
      const dish = MenuItem(
        id: 'M5',
        categoryId: 'grill',
        sku: 'GRL-001',
        nameFr: 'Mix Grill Oasis',
        nameAr: 'مشويات مشكلة الواحة',
        nameEn: 'Oasis Mix Grill',
        priceMru: 750,
        kitchenStation: 'GRILL',
      );
      final line = OrderItem(
        lineId: 'LN-1',
        item: dish,
        quantity: 2,
        selectedModifiers: const [
          SelectedModifier(
            groupId: 'mg-extras',
            optionId: 'opt-mozz',
            nameFr: 'Supplément Mozzarella',
            extraPriceMru: 55,
          ),
        ],
      );
      final tz = DeliveryZone.nouakchottPresets
          .firstWhere((z) => z.id == 'zone-tz');
      final order = PosOrder(
        id: 'ORD-99',
        ticketNumber: 'FT-9901',
        staffName: 'Ahmed',
        items: [line],
        serviceMode: ServiceMode.delivery,
        deliveryZone: tz,
        deliveryFeeMru: 100,
        customerName: 'Cheikh Ould Sidina',
        customerPhone: '+222 46 00 11 22',
        deliveryAddress: 'Ilot K Rue 14 près de la mosquée Al-Nour Nouakchott',
        isTraining: true,
        createdAt: DateTime(2026, 11, 19, 14, 30),
        paidAt: DateTime(2026, 11, 19, 14, 35),
        payments: const [
          PaymentEntry(method: PaymentMethod.cash, amountMru: 300),
          PaymentEntry(
              method: PaymentMethod.bankily,
              amountMru: 300,
              reference: 'BK-11'),
          PaymentEntry(method: PaymentMethod.masrivi, amountMru: 300),
          PaymentEntry(method: PaymentMethod.sedad, amountMru: 210),
          PaymentEntry(
              method: PaymentMethod.bimbank,
              amountMru: 200,
              reference: 'BM-22'),
          PaymentEntry(
              method: PaymentMethod.click, amountMru: 200, reference: 'CL-33'),
          PaymentEntry(
              method: PaymentMethod.karni,
              amountMru: 200,
              karniCustomerId: 'KAR-1'),
        ],
      );

      final receipt = ReceiptFormatter.formatOrderReceipt80mm(order: order);
      expect(receipt, contains('*** TICKET DE FORMATION - NON VALIDE ***'));
      expect(receipt, contains('Mode: Livraison - Tevragh Zeina'));
      expect(receipt, contains('Client: Cheikh Ould Sidina'));
      expect(receipt, contains('+ Supplément Mozzarella (+55 MRU)'));
      expect(receipt, contains('Frais livraison (Tevragh Zeina):'));
      expect(receipt, contains('Sous-total HT:'));
      expect(receipt, contains('Dont TVA 16 %:'));
      expect(receipt, contains('TOTAL TTC / الإجمالي:'));
      expect(receipt, contains('Cash / نقداً'));
      expect(receipt, contains('Bankily / بنكيلي'));
      expect(receipt, contains('Masrivi / مصرفي'));
      expect(receipt, contains('Sedad / سداد'));
      expect(receipt, contains('Bimbank / بيم بنك'));
      expect(receipt, contains('Click / كليك'));
      expect(receipt, contains('Credit Karni / كارني'));

      // Check 42-col safety on ASCII lines
      for (final rawLine in receipt.split('\n')) {
        final hasArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(rawLine);
        if (!hasArabic) {
          expect(rawLine.length, lessThanOrEqualTo(42),
              reason: 'Line exceeded 42 cols: "$rawLine"');
        }
      }

      // Closing Z formatting includes Bimbank & Click
      final z = CashClosingZ(
        id: 'Z-77',
        closedAt: DateTime(2026, 11, 19, 23, 0),
        cashierName: 'Aïcha',
        countedCashMru: 300,
        expectedCashMru: 300,
        countedBankilyMru: 300,
        expectedBankilyMru: 300,
        countedMasriviMru: 300,
        expectedMasriviMru: 300,
        countedSedadMru: 210,
        expectedSedadMru: 210,
        countedBimbankMru: 200,
        expectedBimbankMru: 200,
        countedClickMru: 200,
        expectedClickMru: 200,
        karniIssuedMru: 200,
        ordersCount: 1,
        remakesCount: 0,
      );
      final zText = ReceiptFormatter.formatClosingZReport(z);
      expect(zText, contains('Bimbank:'));
      expect(zText, contains('Click:'));
      expect(zText, contains('1710 MRU'));
    });
  });
}
