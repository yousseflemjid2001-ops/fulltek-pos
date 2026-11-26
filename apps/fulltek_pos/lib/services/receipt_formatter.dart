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
    bool showTva = true,
    double tvaRatePercent = 16.0,
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
    if (order.customerName != null && order.customerName!.trim().isNotEmpty) {
      buf.writeln('Client: ${order.customerName!.trim()}');
    }
    if (order.customerPhone != null &&
        order.customerPhone!.trim().isNotEmpty) {
      buf.writeln('Tel: ${order.customerPhone!.trim()}');
    }
    if (order.serviceMode == ServiceMode.delivery) {
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

    if (order.orderComment != null && order.orderComment!.trim().isNotEmpty) {
      buf.writeln(_line());
      for (final l in _wrapLines('COMMENTAIRE: ${order.orderComment!.trim()}',
          indent: '')) {
        buf.writeln(l);
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
    if (showTva && tvaRatePercent > 0) {
      final tvaAmt = order.grossTotal <= 0
          ? 0
          : (order.grossTotal * tvaRatePercent / (100.0 + tvaRatePercent))
              .round();
      final htAmt = order.grossTotal - tvaAmt;
      final rateLabel = tvaRatePercent == tvaRatePercent.roundToDouble()
          ? tvaRatePercent.toStringAsFixed(0)
          : tvaRatePercent.toStringAsFixed(1);
      buf.writeln(_line());
      buf.writeln(_padRow('Sous-total HT:', formatMru(htAmt)));
      buf.writeln(_padRow('Dont TVA $rateLabel %:', formatMru(tvaAmt.toDouble())));
    }
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
    bool showTva = true,
    double tvaRatePercent = 16.0,
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
    if (order.customerName != null && order.customerName!.trim().isNotEmpty) {
      buf.writeln('Client: ${order.customerName!.trim()}');
    }
    if (order.customerPhone != null &&
        order.customerPhone!.trim().isNotEmpty) {
      buf.writeln('Tel: ${order.customerPhone!.trim()}');
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
      if (line.item.nameAr.isNotEmpty) {
        buf.writeln('   ${line.item.nameAr}');
      }
      for (final m in line.selectedModifiers) {
        final extra =
            m.extraPriceMru > 0 ? ' (+${formatMru(m.extraPriceMru)})' : '';
        buf.writeln('   + ${m.nameFr}$extra');
      }
    }

    if (order.orderComment != null && order.orderComment!.trim().isNotEmpty) {
      buf.writeln(_line());
      for (final l in _wrapLines('COMMENTAIRE: ${order.orderComment!.trim()}',
          indent: '')) {
        buf.writeln(l);
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
    if (showTva && tvaRatePercent > 0) {
      final tvaAmt = order.grossTotal <= 0
          ? 0
          : (order.grossTotal * tvaRatePercent / (100.0 + tvaRatePercent))
              .round();
      final htAmt = order.grossTotal - tvaAmt;
      final rateLabel = tvaRatePercent == tvaRatePercent.roundToDouble()
          ? tvaRatePercent.toStringAsFixed(0)
          : tvaRatePercent.toStringAsFixed(1);
      buf.writeln(_line());
      buf.writeln(_padRow('Sous-total HT:', formatMru(htAmt)));
      buf.writeln(_padRow('Dont TVA $rateLabel %:', formatMru(tvaAmt.toDouble())));
    }
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
    const kWidth = 30;
    String kLine([String ch = '-']) => ch * kWidth;
    String kPad(String left, String right) {
      final sp = kWidth - left.length - right.length;
      return sp >= 1 ? '$left${' ' * sp}$right' : '$left $right';
    }

    final buf = StringBuffer();
    buf.writeln(kLine('='));
    if (order.isTraining) {
      buf.writeln('*** FORMATION ***');
    }
    buf.writeln('*** BON CUISINE / KDS ***');
    final targetLabel = switch (order.serviceMode) {
      ServiceMode.dineIn =>
        order.tableCode != null ? 'TABLE: ${order.tableCode}' : 'COMPTOIR',
      ServiceMode.takeaway =>
        'EMPORTER${order.takeawayNumber != null ? ' N°${order.takeawayNumber}' : ''}',
      ServiceMode.delivery =>
        'LIVRAISON - ${order.deliveryZone?.nameFr ?? 'Nouakchott'}',
    };
    buf.writeln(kPad(targetLabel, order.ticketNumber));
    final kitchenServer =
        (order.serverName != null && order.serverName!.trim().isNotEmpty)
            ? order.serverName!.trim()
            : order.staffName;
    buf.writeln(kPad(
      'Serveur: $kitchenServer',
      '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
    ));
    if (order.customerName != null && order.customerName!.trim().isNotEmpty) {
      buf.writeln('Client: ${order.customerName!.trim()}');
    }
    if (order.customerPhone != null &&
        order.customerPhone!.trim().isNotEmpty) {
      buf.writeln('Tel: ${order.customerPhone!.trim()}');
    }
    if (order.serviceMode == ServiceMode.delivery &&
        order.deliveryDriverName != null &&
        order.deliveryDriverName!.trim().isNotEmpty) {
      buf.writeln('Livreur: ${order.deliveryDriverName!.trim()}');
    }
    if (order.orderComment != null && order.orderComment!.trim().isNotEmpty) {
      buf.writeln(kLine());
      buf.writeln('COMMENTAIRE: ${order.orderComment!.trim()}');
    }
    buf.writeln(kLine('='));
    for (final i in newItems) {
      final takeawayTag =
          (i.isTakeaway && order.serviceMode != ServiceMode.takeaway)
              ? ' [EMPORTER]'
              : '';
      buf.writeln(
          '[${i.item.kitchenStation}] ${i.quantity}x ${i.item.nameFr.toUpperCase()}$takeawayTag');
      if (i.item.nameAr.trim().isNotEmpty) {
        buf.writeln('   ${i.item.nameAr}');
      }
      for (final m in i.selectedModifiers) {
        buf.writeln('   + ${m.nameFr}');
      }
      if (i.kitchenNote != null && i.kitchenNote!.isNotEmpty) {
        buf.writeln('   >>> ${i.kitchenNote}');
      }
      buf.writeln(kLine('-'));
    }
    buf.writeln(kLine('='));
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
    double walletCashbackMru = 0,
    int compCount = 0,
    double compTotalMru = 0,
    int returnCount = 0,
    double returnTotalMru = 0,
    List<({String label, int qty, double amountMru, String reason})> compDetails =
        const [],
    String restaurantName = 'FULL-TEK RESTO POS',
    bool showByFamily = false,
    bool showByArticle = false,
    bool showByCustomer = false,
    List<({String name, int qty, double totalMru})> byFamily = const [],
    List<({String name, int qty, double totalMru})> byArticle = const [],
    List<({String name, int ordersCount, double totalMru})> byCustomer =
        const [],
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
    buf.writeln(_padRow('Offerts (Comp):',
        '$compCount (${formatMru(compTotalMru)})'));
    buf.writeln(_padRow('Retours/Annul.:',
        '$returnCount (${formatMru(returnTotalMru)})'));
    if (remakesCount > compCount + returnCount) {
      buf.writeln(_padRow(
          'Remakes cuisine:', '${remakesCount - compCount - returnCount}'));
    }
    buf.writeln(_line());
    buf.writeln(_padRow('Especes (Cash):', formatMru(cashMru)));
    if (walletCashbackMru > 0) {
      buf.writeln(_padRow(
          '  dont rendu s/Wallets:', '-${formatMru(walletCashbackMru)}'));
    }
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
    _appendCompDetailsSection(buf, compDetails);
    _appendBreakdownSections(
      buf,
      showByFamily: showByFamily,
      showByArticle: showByArticle,
      showByCustomer: showByCustomer,
      byFamily: byFamily,
      byArticle: byArticle,
      byCustomer: byCustomer,
    );
    buf.writeln(_center('COMPTEURS NON REMIS A ZERO'));
    buf.writeln(_line('='));
    return buf.toString();
  }

  static void _appendCompDetailsSection(
    StringBuffer buf,
    List<({String label, int qty, double amountMru, String reason})> compDetails,
  ) {
    if (compDetails.isEmpty) return;
    buf.writeln(_center('--- DETAIL OFFRES (OFFERTS) ---'));
    for (final c in compDetails) {
      final name = c.label.length > 20
          ? '${c.label.substring(0, 18)}..'
          : c.label;
      buf.writeln(_padRow('${c.qty}x $name', '-${formatMru(c.amountMru)}'));
      if (c.reason.trim().isNotEmpty) {
        buf.writeln('   Motif: ${c.reason.trim()}');
      }
    }
    buf.writeln(_line());
  }

  static void _appendBreakdownSections(
    StringBuffer buf, {
    required bool showByFamily,
    required bool showByArticle,
    required bool showByCustomer,
    required List<({String name, int qty, double totalMru})> byFamily,
    required List<({String name, int qty, double totalMru})> byArticle,
    required List<({String name, int ordersCount, double totalMru})> byCustomer,
  }) {
    if (showByFamily) {
      buf.writeln(_center('--- VENTES PAR FAMILLE ---'));
      if (byFamily.isEmpty) {
        buf.writeln('  (Aucune vente)');
      } else {
        for (final f in byFamily) {
          final label = f.name.length > 21
              ? '${f.name.substring(0, 19)}..'
              : f.name;
          buf.writeln(_padRow('${f.qty}x $label', formatMru(f.totalMru)));
        }
      }
      buf.writeln(_line());
    }
    if (showByArticle) {
      buf.writeln(_center('--- VENTES PAR ARTICLE ---'));
      if (byArticle.isEmpty) {
        buf.writeln('  (Aucune vente)');
      } else {
        for (final a in byArticle) {
          final label = a.name.length > 21
              ? '${a.name.substring(0, 19)}..'
              : a.name;
          buf.writeln(_padRow('${a.qty}x $label', formatMru(a.totalMru)));
        }
      }
      buf.writeln(_line());
    }
    if (showByCustomer) {
      buf.writeln(_center('--- VENTES PAR CLIENT ---'));
      if (byCustomer.isEmpty) {
        buf.writeln('  (Aucun client)');
      } else {
        for (final c in byCustomer) {
          final label = c.name.length > 20
              ? '${c.name.substring(0, 18)}..'
              : c.name;
          buf.writeln(
              _padRow('$label (${c.ordersCount})', formatMru(c.totalMru)));
        }
      }
      buf.writeln(_line());
    }
  }

  static String formatClosingZReport(
    CashClosingZ z, {
    int compCount = 0,
    double compTotalMru = 0,
    int returnCount = 0,
    double returnTotalMru = 0,
    List<({String label, int qty, double amountMru, String reason})> compDetails =
        const [],
    bool showByFamily = false,
    bool showByArticle = false,
    bool showByCustomer = false,
    List<({String name, int qty, double totalMru})> byFamily = const [],
    List<({String name, int qty, double totalMru})> byArticle = const [],
    List<({String name, int ordersCount, double totalMru})> byCustomer =
        const [],
  }) {
    final buf = StringBuffer();
    buf.writeln(_line('='));
    buf.writeln(_center('CLOTURE Z AVEUGLE · FULL-TEK'));
    buf.writeln(_line('='));
    buf.writeln(_padRow('ID:', z.id));
    buf.writeln(_padRow('Caissier:', z.cashierName));
    buf.writeln(_padRow('Commandes:', '${z.ordersCount}'));
    buf.writeln(_padRow('Offerts (Comp):',
        '$compCount (${formatMru(compTotalMru)})'));
    buf.writeln(_padRow('Retours/Annul.:',
        '$returnCount (${formatMru(returnTotalMru)})'));
    if (z.remakesCount > compCount + returnCount) {
      buf.writeln(_padRow(
          'Remakes cuisine:', '${z.remakesCount - compCount - returnCount}'));
    }
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
    _appendCompDetailsSection(buf, compDetails);
    _appendBreakdownSections(
      buf,
      showByFamily: showByFamily,
      showByArticle: showByArticle,
      showByCustomer: showByCustomer,
      byFamily: byFamily,
      byArticle: byArticle,
      byCustomer: byCustomer,
    );
    return buf.toString();
  }
}
