import '../models/pos_models.dart';

/// Generates 80mm thermal receipt text (42 columns, bilingual FR/AR)
/// and KDS kitchen tickets / Blind Z-Closing reports ready for ESC/POS.
class ReceiptFormatter {
  static const int width = 42;

  static String _line([String ch = '-']) => ch * width;

  static String _padRow(String left, String right) {
    final space = width - left.length - right.length;
    if (space >= 1) return '$left${' ' * space}$right';
    final maxLeft = width - right.length - 1;
    if (maxLeft > 3 && left.length > maxLeft) {
      return '${left.substring(0, maxLeft - 1)}… $right';
    }
    return '$left $right';
  }

  static List<String> _wrapLines(String text, {String indent = '   '}) {
    final clean = text.trim();
    if (clean.isEmpty) return const [];
    final maxLen = width - indent.length;
    if (clean.length <= maxLen) return ['$indent$clean'];
    final out = <String>[];
    var remaining = clean;
    while (remaining.isNotEmpty) {
      if (remaining.length <= maxLen) {
        out.add('$indent$remaining');
        break;
      }
      var splitAt = remaining.lastIndexOf(' ', maxLen);
      if (splitAt <= 0) splitAt = maxLen;
      out.add('$indent${remaining.substring(0, splitAt).trimRight()}');
      remaining = remaining.substring(splitAt).trimLeft();
    }
    return out;
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
    String address = '',
    String phone = '+222 45 25 11 00',
    String nif = '',
    String rc = '',
    String footer = 'Merci de votre visite ! شكراً لزيارتكم',
  }) {
    final buf = StringBuffer();
    if (order.isTraining) {
      buf.writeln(_line('='));
      buf.writeln('*** TICKET DE FORMATION - NON VALIDE ***');
      buf.writeln(_line('='));
    }
    buf.writeln(_line('='));
    buf.writeln(_center('FULL-TEK RESTO POS'));
    buf.writeln(_center(storeName.trim().isEmpty ? 'FULL-TEK RESTO' : storeName.trim()));
    if (storeNameAr.trim().isNotEmpty) {
      buf.writeln(_center(storeNameAr.trim()));
    }
    if (address.trim().isNotEmpty) {
      buf.writeln(_center(address.trim()));
    }
    if (phone.trim().isNotEmpty) {
      buf.writeln(_center('Tel: ${phone.trim()}'));
    }
    if (nif.trim().isNotEmpty || rc.trim().isNotEmpty) {
      final taxParts = <String>[
        if (nif.trim().isNotEmpty) 'NIF: ${nif.trim()}',
        if (rc.trim().isNotEmpty) 'RC: ${rc.trim()}',
      ];
      buf.writeln(_center(taxParts.join(' · ')));
    }
    buf.writeln(_line('='));
    buf.writeln(_padRow(
      'Ticket: ${order.ticketNumber}',
      order.tableCode != null ? 'Table: ${order.tableCode}' : 'COMPTOIR',
    ));
    final modeLabel = switch (order.serviceMode) {
      ServiceMode.dineIn =>
        'Sur place${order.tableCode != null ? ' · ${order.tableCode}' : ''}',
      ServiceMode.takeaway =>
        'Emporter${order.takeawayNumber != null ? ' N°${order.takeawayNumber}' : ''}',
      ServiceMode.delivery =>
        'Livraison - ${order.deliveryZone?.nameFr ?? 'Nouakchott'}',
    };
    buf.writeln('Mode: $modeLabel');
    if (order.serviceMode == ServiceMode.delivery) {
      if (order.customerName != null && order.customerName!.trim().isNotEmpty) {
        buf.writeln('Client: ${order.customerName!.trim()}');
      }
      if (order.customerPhone != null &&
          order.customerPhone!.trim().isNotEmpty) {
        buf.writeln('Tel: ${order.customerPhone!.trim()}');
      }
      if (order.deliveryAddress != null &&
          order.deliveryAddress!.trim().isNotEmpty) {
        for (final l in _wrapLines('Adresse: ${order.deliveryAddress!.trim()}',
            indent: '')) {
          buf.writeln(l);
        }
      }
      if (order.deliveryDriverName != null &&
          order.deliveryDriverName!.trim().isNotEmpty) {
        buf.writeln('Livreur: ${order.deliveryDriverName!.trim()}');
      }
    }

    final dt = order.paidAt ?? order.createdAt;
    final dateStr =
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final hasTableServer = (order.serverName != null &&
            order.serverName!.trim().isNotEmpty) ||
        order.tableCode != null;
    final effectiveServer =
        (order.serverName != null && order.serverName!.trim().isNotEmpty)
            ? order.serverName!.trim()
            : order.staffName;
    final effectiveCashier =
        (order.cashierName != null && order.cashierName!.trim().isNotEmpty)
            ? order.cashierName!.trim()
            : order.staffName;
    if (hasTableServer) {
      buf.writeln('Date: $dateStr');
      buf.writeln('Serveur: $effectiveServer');
      if (effectiveCashier != effectiveServer) {
        buf.writeln('Caissier: $effectiveCashier');
      }
    } else {
      buf.writeln('Date: $dateStr');
      buf.writeln('Caissier: $effectiveCashier');
    }
    buf.writeln(_line());

    for (final line in order.items) {
      final takeawayTag =
          (line.isTakeaway && order.serviceMode != ServiceMode.takeaway)
              ? ' [EMPORTER]'
              : '';
      final qtyName = '${line.quantity}x ${line.item.nameFr}$takeawayTag';
      final priceStr = line.isComp ? 'OFFERT' : formatMru(line.lineTotal);
      buf.writeln(_padRow(qtyName, priceStr));
      buf.writeln('   ${line.item.nameAr}');
      for (final m in line.selectedModifiers) {
        final extra =
            m.extraPriceMru > 0 ? ' (+${formatMru(m.extraPriceMru)})' : '';
        buf.writeln('   + ${m.nameFr}$extra');
      }
      if (line.kitchenNote != null && line.kitchenNote!.isNotEmpty) {
        for (final l in _wrapLines('* ${line.kitchenNote!}')) {
          buf.writeln(l);
        }
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
    if (order.deliveryFeeMru > 0) {
      final feeStr = formatMru(order.deliveryFeeMru);
      final zoneName = order.deliveryZone?.nameFr;
      if (zoneName != null &&
          'Frais livraison ($zoneName):'.length + feeStr.length + 1 <= width) {
        buf.writeln(_padRow('Frais livraison ($zoneName):', feeStr));
      } else {
        buf.writeln(_padRow('Frais livraison:', feeStr));
        if (zoneName != null) {
          buf.writeln('   Zone: $zoneName');
        }
      }
    }
    buf.writeln(_line());
    buf.writeln(_padRow('Sous-total HT:', formatMru(order.subtotalHtMru)));
    buf.writeln(
        _padRow('Dont TVA 16 %:', formatMru(order.tvaAmountMru.toDouble())));
    buf.writeln(_line('='));
    buf.writeln(_padRow('TOTAL TTC / الإجمالي:', formatMru(order.netTotal)));
    buf.writeln(_line('='));

    for (final p in order.payments) {
      final String label;
      if (p.method == PaymentMethod.otherWallet) {
        final w = p.displayLabel;
        final ar = MauritanianWallets.arabicNames[w];
        label = ar != null ? '$w / $ar' : w;
      } else {
        label = switch (p.method) {
          PaymentMethod.cash => 'Cash / نقداً',
          PaymentMethod.bankily => 'Bankily / بنكيلي',
          PaymentMethod.masrivi => 'Masrivi / مصرفي',
          PaymentMethod.sedad => 'Sedad / سداد',
          PaymentMethod.bimbank => 'Bimbank / بيم بنك',
          PaymentMethod.click => 'Click / كليك',
          PaymentMethod.otherWallet => p.displayLabel,
          PaymentMethod.karni => 'Credit Karni / كارني',
        };
      }
      buf.writeln(_padRow(label, formatMru(p.amountMru)));
      if (p.reference != null && p.reference!.isNotEmpty) {
        buf.writeln('   Ref: ${p.reference}');
      }
    }
    if (order.changeDue > 0) {
      buf.writeln(
          _padRow('Monnaie rendue / الباقي:', formatMru(order.changeDue)));
    }
    buf.writeln(_line());
    if (footer.trim().isNotEmpty) {
      buf.writeln(_center(footer.trim()));
    }
    buf.writeln(_center('Propulse par Full-Tek POS (Mauritanie)'));
    if (order.isTraining) {
      buf.writeln('*** TICKET DE FORMATION - NON VALIDE ***');
    }
    buf.writeln(_line('='));
    return buf.toString();
  }

  /// 80mm Pre-bill / Addition ticket printed BEFORE checkout ("L'Addition")
  static String formatAdditionReceipt80mm({
    required PosOrder order,
    String restaurantName = 'FULL-TEK RESTO POS',
    String restaurantNameAr = 'مطعم فل-تك',
    String address = 'Tevragh-Zeina · Nouakchott',
    String phone = '+222 45 25 00 00',
    String nif = '',
    String rc = '',
  }) {
    final buf = StringBuffer();
    buf.writeln(_line('='));
    if (order.isTraining) {
      buf.writeln(_center('*** MODE FORMATION ***'));
    }
    buf.writeln(_center('*** NOTE / ADDITION ***'));
    buf.writeln(_center('NOTE SANS ENCAISSEMENT / الفاتورة المبدئية'));
    buf.writeln(_center(restaurantName));
    if (restaurantNameAr.trim().isNotEmpty) {
      buf.writeln(_center(restaurantNameAr));
    }
    if (address.trim().isNotEmpty || phone.trim().isNotEmpty) {
      buf.writeln(_center([address.trim(), phone.trim()]
          .where((s) => s.isNotEmpty)
          .join(' · ')));
    }
    if (nif.trim().isNotEmpty || rc.trim().isNotEmpty) {
      final taxParts = <String>[
        if (nif.trim().isNotEmpty) 'NIF: ${nif.trim()}',
        if (rc.trim().isNotEmpty) 'RC: ${rc.trim()}',
      ];
      buf.writeln(_center(taxParts.join(' · ')));
    }
    buf.writeln(_line('='));
    buf.writeln(_padRow(
      'Ticket: ${order.ticketNumber}',
      order.tableCode != null ? 'Table: ${order.tableCode}' : 'COMPTOIR',
    ));
    final dt = DateTime.now();
    final dateStr =
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final effectiveServer =
        (order.serverName != null && order.serverName!.trim().isNotEmpty)
            ? order.serverName!.trim()
            : order.staffName;
    buf.writeln('Date: $dateStr');
    buf.writeln('Serveur: $effectiveServer');
    buf.writeln(_line());

    for (final line in order.items) {
      final takeawayTag =
          (line.isTakeaway && order.serviceMode != ServiceMode.takeaway)
              ? ' [EMPORTER]'
              : '';
      final qtyName = '${line.quantity}x ${line.item.nameFr}$takeawayTag';
      final priceStr = line.isComp ? 'OFFERT' : formatMru(line.lineTotal);
      buf.writeln(_padRow(qtyName, priceStr));
      if (line.item.nameAr.isNotEmpty) {
        buf.writeln('   ${line.item.nameAr}');
      }
      for (final m in line.selectedModifiers) {
        final extra =
            m.extraPriceMru > 0 ? ' (+${formatMru(m.extraPriceMru)})' : '';
        buf.writeln('   + ${m.nameFr}$extra');
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
    if (order.deliveryFeeMru > 0) {
      buf.writeln(_padRow('Frais livraison:', formatMru(order.deliveryFeeMru)));
    }
    buf.writeln(_line());
    buf.writeln(_padRow('Sous-total HT:', formatMru(order.subtotalHtMru)));
    buf.writeln(
        _padRow('Dont TVA 16 %:', formatMru(order.tvaAmountMru.toDouble())));
    buf.writeln(_line('='));
    buf.writeln(_padRow('TOTAL A PAYER:', formatMru(order.netTotal)));
    buf.writeln(_line('='));
    buf.writeln(_center('DOCUMENT NON PAYE - MERCI'));
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
    if (order.isTraining) {
      buf.writeln(_center('*** FORMATION ***'));
    }
    buf.writeln(_center('*** BON CUISINE / KDS ***'));
    final targetLabel = switch (order.serviceMode) {
      ServiceMode.dineIn =>
        order.tableCode != null ? 'TABLE: ${order.tableCode}' : 'COMPTOIR',
      ServiceMode.takeaway =>
        'EMPORTER${order.takeawayNumber != null ? ' N°${order.takeawayNumber}' : ''}',
      ServiceMode.delivery =>
        'LIVRAISON - ${order.deliveryZone?.nameFr ?? 'Nouakchott'}',
    };
    buf.writeln(_padRow(targetLabel, order.ticketNumber));
    final kitchenServer =
        (order.serverName != null && order.serverName!.trim().isNotEmpty)
            ? order.serverName!.trim()
            : order.staffName;
    buf.writeln(_padRow(
      'Serveur: $kitchenServer',
      '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
    ));
    if (order.serviceMode == ServiceMode.delivery) {
      if (order.customerName != null && order.customerName!.trim().isNotEmpty) {
        buf.writeln('Client: ${order.customerName!.trim()}');
      }
      if (order.customerPhone != null &&
          order.customerPhone!.trim().isNotEmpty) {
        buf.writeln('Tel: ${order.customerPhone!.trim()}');
      }
      if (order.deliveryDriverName != null &&
          order.deliveryDriverName!.trim().isNotEmpty) {
        buf.writeln('Livreur: ${order.deliveryDriverName!.trim()}');
      }
    }
    buf.writeln(_line());
    for (final i in newItems) {
      buf.writeln('[${i.item.kitchenStation}] ${i.quantity}x ${i.item.nameFr}');
      buf.writeln('   ${i.item.nameAr}');
      for (final m in i.selectedModifiers) {
        buf.writeln('   + ${m.nameFr}');
      }
      if (i.kitchenNote != null && i.kitchenNote!.isNotEmpty) {
        buf.writeln('   >>> NOTE: ${i.kitchenNote}');
      }
    }
    buf.writeln(_line('*'));
    return buf.toString();
  }

  /// 80mm Kitchen Cancellation Ticket ("Ticket d'annulation cuisine")
  static String formatKitchenCancellationTicket({
    required PosOrder order,
    required OrderItem cancelledLine,
    required int cancelledQty,
    required String reason,
    required String requestedBy,
    required String approvedBy,
  }) {
    final buf = StringBuffer();
    buf.writeln(_line('*'));
    if (order.isTraining) {
      buf.writeln(_center('*** FORMATION ***'));
    }
    buf.writeln(_center('*** ANNULATION CUISINE / إلغاء طلب ***'));
    buf.writeln(_line('*'));
    final targetLabel = switch (order.serviceMode) {
      ServiceMode.dineIn =>
        order.tableCode != null ? 'TABLE: ${order.tableCode}' : 'COMPTOIR',
      ServiceMode.takeaway =>
        'EMPORTER${order.takeawayNumber != null ? ' N°${order.takeawayNumber}' : ''}',
      ServiceMode.delivery =>
        'LIVRAISON - ${order.deliveryZone?.nameFr ?? 'Nouakchott'}',
    };
    final now = DateTime.now();
    final hm =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    buf.writeln(_padRow(targetLabel, order.ticketNumber));
    buf.writeln(_padRow('Demande par: $requestedBy', hm));
    buf.writeln('Autorise par: $approvedBy');
    buf.writeln(_line());
    buf.writeln(
        '[${cancelledLine.item.kitchenStation}] -${cancelledQty}x ${cancelledLine.item.nameFr} (ANNULE)');
    if (cancelledLine.item.nameAr.isNotEmpty) {
      buf.writeln('   ${cancelledLine.item.nameAr}');
    }
    for (final m in cancelledLine.selectedModifiers) {
      buf.writeln('   + ${m.nameFr}');
    }
    buf.writeln(_line());
    for (final l in _wrapLines('MOTIF: $reason')) {
      buf.writeln(l);
    }
    buf.writeln(_line('*'));
    return buf.toString();
  }

  static String formatReportX80mm({
    required String scopeLabel,
    required int ordersCount,
    required int openTablesCount,
    required int remakesCount,
    required double cashMru,
    required double bankilyMru,
    required double masriviMru,
    required double sedadMru,
    required double bimbankMru,
    required double clickMru,
    Map<String, double> otherWallets = const {},
    required double karniMru,
    String restaurantName = 'FULL-TEK RESTO POS',
  }) {
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final otherSum = otherWallets.values.fold(0.0, (s, v) => s + v);
    final total = cashMru +
        bankilyMru +
        masriviMru +
        sedadMru +
        bimbankMru +
        clickMru +
        otherSum +
        karniMru;
    final buf = StringBuffer();
    buf.writeln(_line('='));
    buf.writeln(_center('*** RAPPORT X / قراءة X ***'));
    buf.writeln(_center('LECTURE INTERMEDIAIRE (SANS CLOTURE)'));
    buf.writeln(_center(restaurantName));
    buf.writeln(_line('='));
    buf.writeln('Date: $dateStr');
    buf.writeln('Perimetre: $scopeLabel');
    buf.writeln(_padRow('Tickets encaisses:', '$ordersCount'));
    buf.writeln(_padRow('Tables en cours:', '$openTablesCount'));
    buf.writeln(_padRow('Annulations/Offerts:', '$remakesCount'));
    buf.writeln(_line());
    buf.writeln(_padRow('Especes (Cash):', formatMru(cashMru)));
    buf.writeln(_padRow('Bankily:', formatMru(bankilyMru)));
    buf.writeln(_padRow('Masrivi:', formatMru(masriviMru)));
    buf.writeln(_padRow('Sedad:', formatMru(sedadMru)));
    buf.writeln(_padRow('Bimbank:', formatMru(bimbankMru)));
    buf.writeln(_padRow('Click:', formatMru(clickMru)));
    for (final e in otherWallets.entries) {
      buf.writeln(_padRow('${e.key}:', formatMru(e.value)));
    }
    buf.writeln(_padRow('Karni emis:', formatMru(karniMru)));
    buf.writeln(_line('='));
    buf.writeln(_padRow('TOTAL ENCAISSE (X):', formatMru(total)));
    buf.writeln(_line('='));
    buf.writeln(_center('COMPTEURS NON REMIS A ZERO'));
    buf.writeln(_line('='));
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
    buf.writeln(_padRow('Bimbank:', formatMru(z.expectedBimbankMru)));
    buf.writeln(_padRow('Click:', formatMru(z.expectedClickMru)));
    final allOtherKeys = <String>{
      ...z.otherWalletsExpected.keys,
      ...z.otherWalletsCounted.keys,
    };
    for (final k in allOtherKeys) {
      final exp = z.otherWalletsExpected[k] ?? 0.0;
      buf.writeln(_padRow('$k:', formatMru(exp)));
    }
    buf.writeln(_padRow('Karni emis:', formatMru(z.karniIssuedMru)));
    buf.writeln(_line('='));
    buf.writeln(_padRow('TOTAL CA JOUR:', formatMru(z.totalExpectedMru)));
    buf.writeln(_line('='));
    return buf.toString();
  }
}
