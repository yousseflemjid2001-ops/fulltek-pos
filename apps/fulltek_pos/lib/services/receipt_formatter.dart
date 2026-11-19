import '../models/pos_models.dart';

/// Generates 80mm thermal receipt text (42 columns, bilingual FR/AR)
/// and KDS kitchen tickets / Blind Z-Closing reports ready for ESC/POS.
class ReceiptFormatter {
  static const int width = 42;

  static String _line([String ch = '-']) => ch * width;

  static String _padRow(String left, String right) {
    final space = width - left.length - right.length;
    if (space <= 1) return '$left $right';
    return '$left${' ' * space}$right';
  }

  static String _center(String text) {
    if (text.length >= width) return text;
    final pad = ((width - text.length) / 2).floor();
    return '${' ' * pad}$text';
  }

  static String formatMru(double v) => '${v.toStringAsFixed(0)} MRU';

  static String formatOrderReceipt80mm({
    required PosOrder order,
    String storeName = 'RESTAURANT OASIS · TEVRAGH-ZEINA',
    String storeNameAr = 'مطعم الواحة · تفرغ زينة - نواكشوط',
    String phone = '+222 45 25 11 00',
  }) {
    final buf = StringBuffer();
    buf.writeln(_line('='));
    buf.writeln(_center('FULL-TEK RESTO POS'));
    buf.writeln(_center(storeName));
    buf.writeln(_center(storeNameAr));
    buf.writeln(_center('Tel: $phone'));
    buf.writeln(_line('='));
    buf.writeln(_padRow('Ticket: ${order.ticketNumber}',
        order.tableCode != null ? 'Table: ${order.tableCode}' : 'COMPTOIR'));
    final dt = order.paidAt ?? order.createdAt;
    final dateStr =
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    buf.writeln(_padRow('Date: $dateStr', 'Staff: ${order.staffName}'));
    buf.writeln(_line());

    for (final line in order.items) {
      final qtyName = '${line.quantity}x ${line.item.nameFr}';
      final priceStr = line.isComp ? 'OFFERT' : formatMru(line.lineTotal);
      buf.writeln(_padRow(qtyName, priceStr));
      buf.writeln('   ${line.item.nameAr}');
      if (line.kitchenNote != null && line.kitchenNote!.isNotEmpty) {
        buf.writeln('   * ${line.kitchenNote}');
      }
    }

    buf.writeln(_line());
    buf.writeln(_padRow('Sous-total / المجموع:', formatMru(order.subtotal)));
    if (order.discountAmount > 0) {
      buf.writeln(_padRow(
        'Remise (${order.discountPercent.toStringAsFixed(0)}%):',
        '-${formatMru(order.discountAmount)}',
      ));
    }
    if (order.arbounDepositMru > 0) {
      buf.writeln(_padRow(
        'Arboun / عربون:',
        '-${formatMru(order.arbounDepositMru)}',
      ));
    }
    buf.writeln(_line('='));
    buf.writeln(_padRow('TOTAL NET / الإجمالي:', formatMru(order.netTotal)));
    buf.writeln(_line('='));

    for (final p in order.payments) {
      final label = switch (p.method) {
        PaymentMethod.cash => 'Especes / نقداً',
        PaymentMethod.bankily => 'Bankily / بنكيلي',
        PaymentMethod.masrivi => 'Masrivi / مصرفي',
        PaymentMethod.sedad => 'Sedad / سداد',
        PaymentMethod.karni => 'Credit Karni / كارني',
      };
      buf.writeln(_padRow(label, formatMru(p.amountMru)));
      if (p.reference != null && p.reference!.isNotEmpty) {
        buf.writeln('   Ref: ${p.reference}');
      }
    }
    if (order.changeDue > 0) {
      buf.writeln(_padRow('Monnaie rendue / الباقي:', formatMru(order.changeDue)));
    }
    buf.writeln(_line());
    buf.writeln(_center('Merci de votre visite ! شكراً لزيارتكم'));
    buf.writeln(_center('Propulse par Full-Tek POS (Mauritanie)'));
    buf.writeln(_line('='));
    return buf.toString();
  }

  static String formatKitchenTicket({
    required PosOrder order,
    required List<OrderItem> newItems,
  }) {
    final buf = StringBuffer();
    buf.writeln(_line('*'));
    buf.writeln(_center('*** BON CUISINE / KDS ***'));
    buf.writeln(_padRow(
      order.tableCode != null ? 'TABLE: ${order.tableCode}' : 'A EMPORTER',
      order.ticketNumber,
    ));
    buf.writeln(_padRow('Serveur: ${order.staffName}',
        '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}'));
    buf.writeln(_line());
    for (final i in newItems) {
      buf.writeln('[${i.item.kitchenStation}] ${i.quantity}x ${i.item.nameFr}');
      buf.writeln('   ${i.item.nameAr}');
      if (i.kitchenNote != null && i.kitchenNote!.isNotEmpty) {
        buf.writeln('   >>> NOTE: ${i.kitchenNote}');
      }
    }
    buf.writeln(_line('*'));
    return buf.toString();
  }

  static String formatClosingZReport(CashClosingZ z) {
    final buf = StringBuffer();
    buf.writeln(_line('='));
    buf.writeln(_center('CLOTURE Z AVEUGLE · FULL-TEK'));
    buf.writeln(_line('='));
    buf.writeln(_padRow('ID:', z.id));
    buf.writeln(_padRow('Caissier:', z.cashierName));
    buf.writeln(_padRow('Commandes:', '${z.ordersCount}'));
    buf.writeln(_padRow('Remakes/Offerts:', '${z.remakesCount}'));
    buf.writeln(_line());
    buf.writeln(_padRow('Especes comptees:', formatMru(z.countedCashMru)));
    buf.writeln(_padRow('Especes theoriques:', formatMru(z.expectedCashMru)));
    final sign = z.cashVarianceMru >= 0 ? '+' : '';
    buf.writeln(
        _padRow('ECART CAISSE:', '$sign${formatMru(z.cashVarianceMru)}'));
    buf.writeln(_line());
    buf.writeln(_padRow('Bankily:', formatMru(z.expectedBankilyMru)));
    buf.writeln(_padRow('Masrivi:', formatMru(z.expectedMasriviMru)));
    buf.writeln(_padRow('Sedad:', formatMru(z.expectedSedadMru)));
    buf.writeln(_padRow('Karni emis:', formatMru(z.karniIssuedMru)));
    buf.writeln(_line('='));
    buf.writeln(_padRow('TOTAL CA JOUR:', formatMru(z.totalExpectedMru)));
    buf.writeln(_line('='));
    return buf.toString();
  }
}
