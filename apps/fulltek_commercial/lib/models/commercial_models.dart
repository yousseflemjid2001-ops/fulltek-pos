double _d(dynamic v, [double fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  return double.tryParse('$v') ?? fallback;
}

int _i(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v') ?? fallback;
}

class CommercialTenantInfo {
  final String tenantId;
  final String name;
  final String nif;
  final String rc;
  final String city;
  final String address;
  final String phone;
  final String manager;
  final String plan;
  final int daysLeft;
  final List<String> payMethods;

  const CommercialTenantInfo({
    this.tenantId = 'FT-COM-DEMO',
    this.name = 'Full·Tek Négoce SARL',
    this.nif = 'NIF 0123456789',
    this.rc = 'RC NKC-2026-B104',
    this.city = 'Nouakchott',
    this.address = 'Tevragh Zeina',
    this.phone = '+222 45 25 11 00',
    this.manager = 'Administrateur',
    this.plan = 'Pro',
    this.daysLeft = 14,
    this.payMethods = const [
      'Cash',
      'Bankily',
      'Masrivi',
      'Sedad',
      'Bimbank',
      'Click',
      'Karni',
    ],
  });

  factory CommercialTenantInfo.fromJson(Map<String, dynamic> j) {
    final pays = (j['payMethods'] as List?)?.map((e) => '$e').toList();
    return CommercialTenantInfo(
      tenantId: '${j['tenantId'] ?? j['tenant_code'] ?? 'FT-COM'}',
      name: '${j['name'] ?? 'Entreprise'}',
      nif: '${j['nif'] ?? ''}',
      rc: '${j['rc'] ?? ''}',
      city: '${j['city'] ?? 'Nouakchott'}',
      address: '${j['address'] ?? ''}',
      phone: '${j['phone'] ?? ''}',
      manager: '${j['manager'] ?? 'Administrateur'}',
      plan: '${j['plan'] ?? 'Pro'}',
      daysLeft: _i(j['daysLeft'] ?? j['days_left'], 14),
      payMethods: (pays != null && pays.isNotEmpty)
          ? pays
          : const ['Cash', 'Bankily', 'Masrivi', 'Sedad', 'Bimbank', 'Click', 'Karni'],
    );
  }
}

class DashboardKpis {
  final double caHtMru;
  final double? caVsN1Pct;
  final double objectiveTargetMru;
  final double? objectiveAttainmentPct;
  final double grossMarginMru;
  final double marginRatePct;
  final double marginRatePrevPct;
  final double? marginVsN1Pct;
  final double receiptsMru;
  final double? receiptsVsN1Pct;
  final double disbursementsMru;
  final double purchasesHtMru;
  final double? purchasesVsN1Pct;
  final double supplierDebtMru;
  final double clientReceivablesTtcMru;
  final double pendingEffectsMru;
  final double treasuryBalanceMru;
  final double stockValuePmpMru;
  final double quotesEmittedHtMru;
  final int quotesCount;
  final double? quoteConversionRatePct;

  const DashboardKpis({
    this.caHtMru = 0,
    this.caVsN1Pct,
    this.objectiveTargetMru = 0,
    this.objectiveAttainmentPct,
    this.grossMarginMru = 0,
    this.marginRatePct = 0,
    this.marginRatePrevPct = 0,
    this.marginVsN1Pct,
    this.receiptsMru = 0,
    this.receiptsVsN1Pct,
    this.disbursementsMru = 0,
    this.purchasesHtMru = 0,
    this.purchasesVsN1Pct,
    this.supplierDebtMru = 0,
    this.clientReceivablesTtcMru = 0,
    this.pendingEffectsMru = 0,
    this.treasuryBalanceMru = 0,
    this.stockValuePmpMru = 0,
    this.quotesEmittedHtMru = 0,
    this.quotesCount = 0,
    this.quoteConversionRatePct,
  });

  factory DashboardKpis.fromJson(Map<String, dynamic> j) => DashboardKpis(
        caHtMru: _d(j['caHtMru']),
        caVsN1Pct: j['caVsN1Pct'] != null ? _d(j['caVsN1Pct']) : null,
        objectiveTargetMru: _d(j['objectiveTargetMru']),
        objectiveAttainmentPct: j['objectiveAttainmentPct'] != null
            ? _d(j['objectiveAttainmentPct'])
            : null,
        grossMarginMru: _d(j['grossMarginMru']),
        marginRatePct: _d(j['marginRatePct']),
        marginRatePrevPct: _d(j['marginRatePrevPct']),
        marginVsN1Pct: j['marginVsN1Pct'] != null ? _d(j['marginVsN1Pct']) : null,
        receiptsMru: _d(j['receiptsMru']),
        receiptsVsN1Pct:
            j['receiptsVsN1Pct'] != null ? _d(j['receiptsVsN1Pct']) : null,
        disbursementsMru: _d(j['disbursementsMru']),
        purchasesHtMru: _d(j['purchasesHtMru']),
        purchasesVsN1Pct:
            j['purchasesVsN1Pct'] != null ? _d(j['purchasesVsN1Pct']) : null,
        supplierDebtMru: _d(j['supplierDebtMru']),
        clientReceivablesTtcMru: _d(j['clientReceivablesTtcMru']),
        pendingEffectsMru: _d(j['pendingEffectsMru']),
        treasuryBalanceMru: _d(j['treasuryBalanceMru']),
        stockValuePmpMru: _d(j['stockValuePmpMru']),
        quotesEmittedHtMru: _d(j['quotesEmittedHtMru']),
        quotesCount: _i(j['quotesCount']),
        quoteConversionRatePct: j['quoteConversionRatePct'] != null
            ? _d(j['quoteConversionRatePct'])
            : null,
      );
}

class DashboardSeriesPoint {
  final String monthKey;
  final String label;
  final double periodCaHtMru;
  final double prevCaHtMru;
  final double targetCaHtMru;

  const DashboardSeriesPoint({
    required this.monthKey,
    required this.label,
    required this.periodCaHtMru,
    required this.prevCaHtMru,
    required this.targetCaHtMru,
  });

  factory DashboardSeriesPoint.fromJson(Map<String, dynamic> j) =>
      DashboardSeriesPoint(
        monthKey: '${j['monthKey'] ?? ''}',
        label: '${j['label'] ?? ''}',
        periodCaHtMru: _d(j['periodCaHtMru']),
        prevCaHtMru: _d(j['prevCaHtMru']),
        targetCaHtMru: _d(j['targetCaHtMru']),
      );
}

class DashboardAlertGroup {
  final int count;
  final double totalMru;
  const DashboardAlertGroup({this.count = 0, this.totalMru = 0});

  factory DashboardAlertGroup.fromJson(Map<String, dynamic>? j) =>
      DashboardAlertGroup(
        count: _i(j?['count']),
        totalMru: _d(j?['totalMru']),
      );
}

class DashboardData {
  final String fromDate;
  final String toDate;
  final DashboardKpis kpis;
  final List<DashboardSeriesPoint> series;
  final DashboardAlertGroup overdueClientInvoices;
  final DashboardAlertGroup dueCheques7d;
  final DashboardAlertGroup overdueSupplierInvoices;
  final int lowStockCount;

  const DashboardData({
    this.fromDate = '',
    this.toDate = '',
    this.kpis = const DashboardKpis(),
    this.series = const [],
    this.overdueClientInvoices = const DashboardAlertGroup(),
    this.dueCheques7d = const DashboardAlertGroup(),
    this.overdueSupplierInvoices = const DashboardAlertGroup(),
    this.lowStockCount = 0,
  });

  factory DashboardData.fromJson(Map<String, dynamic> j) {
    final range = (j['range'] as Map?)?.cast<String, dynamic>() ?? const {};
    final alerts = (j['alerts'] as Map?)?.cast<String, dynamic>() ?? const {};
    return DashboardData(
      fromDate: '${range['from'] ?? ''}',
      toDate: '${range['to'] ?? ''}',
      kpis: DashboardKpis.fromJson(
          (j['kpis'] as Map?)?.cast<String, dynamic>() ?? const {}),
      series: ((j['series'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => DashboardSeriesPoint.fromJson(m.cast<String, dynamic>()))
          .toList(),
      overdueClientInvoices: DashboardAlertGroup.fromJson(
          (alerts['overdueClientInvoices'] as Map?)?.cast<String, dynamic>()),
      dueCheques7d: DashboardAlertGroup.fromJson(
          (alerts['dueCheques7d'] as Map?)?.cast<String, dynamic>()),
      overdueSupplierInvoices: DashboardAlertGroup.fromJson(
          (alerts['overdueSupplierInvoices'] as Map?)?.cast<String, dynamic>()),
      lowStockCount: _i((alerts['lowStockArticles'] as Map?)?['count']),
    );
  }
}

class CommercialClient {
  final int id;
  final String code;
  final String name;
  final bool isB2b;
  final String nif;
  final String rc;
  final String phone;
  final String address;
  final String city;
  final int paymentTermsDays;
  final double creditLimitMru;
  final double karniDebtMru;
  final double invoiceEncoursMru;
  final double encoursTtcMru;

  const CommercialClient({
    required this.id,
    required this.code,
    required this.name,
    this.isB2b = false,
    this.nif = '',
    this.rc = '',
    this.phone = '',
    this.address = '',
    this.city = 'Nouakchott',
    this.paymentTermsDays = 0,
    this.creditLimitMru = 0,
    this.karniDebtMru = 0,
    this.invoiceEncoursMru = 0,
    this.encoursTtcMru = 0,
  });

  factory CommercialClient.fromJson(Map<String, dynamic> j) => CommercialClient(
        id: _i(j['id']),
        code: '${j['code'] ?? ''}',
        name: '${j['name'] ?? ''}',
        isB2b: j['isB2b'] == true,
        nif: '${j['nif'] ?? ''}',
        rc: '${j['rc'] ?? ''}',
        phone: '${j['phone'] ?? ''}',
        address: '${j['address'] ?? ''}',
        city: '${j['city'] ?? 'Nouakchott'}',
        paymentTermsDays: _i(j['paymentTermsDays']),
        creditLimitMru: _d(j['creditLimitMru']),
        karniDebtMru: _d(j['karniDebtMru'] ?? j['currentDebtMru']),
        invoiceEncoursMru: _d(j['invoiceEncoursMru']),
        encoursTtcMru: _d(j['encoursTtcMru']),
      );
}

class CommercialSupplier {
  final int id;
  final String code;
  final String name;
  final String nif;
  final String rc;
  final String phone;
  final String city;
  final int paymentTermsDays;
  final double balanceDueMru;

  const CommercialSupplier({
    required this.id,
    required this.code,
    required this.name,
    this.nif = '',
    this.rc = '',
    this.phone = '',
    this.city = 'Nouakchott',
    this.paymentTermsDays = 30,
    this.balanceDueMru = 0,
  });

  factory CommercialSupplier.fromJson(Map<String, dynamic> j) =>
      CommercialSupplier(
        id: _i(j['id']),
        code: '${j['code'] ?? ''}',
        name: '${j['name'] ?? ''}',
        nif: '${j['nif'] ?? ''}',
        rc: '${j['rc'] ?? ''}',
        phone: '${j['phone'] ?? ''}',
        city: '${j['city'] ?? 'Nouakchott'}',
        paymentTermsDays: _i(j['paymentTermsDays'], 30),
        balanceDueMru: _d(j['balanceDueMru']),
      );
}

class CommercialArticle {
  final int id;
  final String sku;
  final String barcode;
  final String name;
  final String category;
  final String unit;
  final double priceRetailHt;
  final double priceWholeHt;
  final double priceRetailTtc;
  final double priceWholeTtc;
  final double priceCostMru;
  final double pmpCostMru;
  final double stockQty;
  final double minStock;
  final double tvaRate;
  final bool isExempt;
  final bool trackStock;
  final double stockValuePmpMru;
  final bool isLowStock;

  const CommercialArticle({
    required this.id,
    required this.sku,
    this.barcode = '',
    required this.name,
    this.category = 'Général',
    this.unit = 'unité',
    required this.priceRetailHt,
    this.priceWholeHt = 0,
    this.priceRetailTtc = 0,
    this.priceWholeTtc = 0,
    this.priceCostMru = 0,
    this.pmpCostMru = 0,
    this.stockQty = 0,
    this.minStock = 0,
    this.tvaRate = 16,
    this.isExempt = false,
    this.trackStock = true,
    this.stockValuePmpMru = 0,
    this.isLowStock = false,
  });

  factory CommercialArticle.fromJson(Map<String, dynamic> j) =>
      CommercialArticle(
        id: _i(j['id']),
        sku: '${j['sku'] ?? ''}',
        barcode: '${j['barcode'] ?? ''}',
        name: '${j['name'] ?? ''}',
        category: '${j['category'] ?? 'Général'}',
        unit: '${j['unit'] ?? 'unité'}',
        priceRetailHt: _d(j['priceRetailHt']),
        priceWholeHt: _d(j['priceWholeHt']),
        priceRetailTtc: _d(j['priceRetailTtc']),
        priceWholeTtc: _d(j['priceWholeTtc']),
        priceCostMru: _d(j['priceCostMru']),
        pmpCostMru: _d(j['pmpCostMru']),
        stockQty: _d(j['stockQty']),
        minStock: _d(j['minStock']),
        tvaRate: _d(j['tvaRate'], 16),
        isExempt: j['isExempt'] == true,
        trackStock: j['trackStock'] != false,
        stockValuePmpMru: _d(j['stockValuePmpMru']),
        isLowStock: j['isLowStock'] == true,
      );
}

class StockMovement {
  final int id;
  final int articleId;
  final String articleName;
  final String sku;
  final String movementType;
  final double qtyDelta;
  final double unitCostMru;
  final double pmpAfterMru;
  final double stockAfter;
  final String sourceNumber;
  final String reason;
  final String createdAt;

  const StockMovement({
    required this.id,
    required this.articleId,
    required this.articleName,
    required this.sku,
    required this.movementType,
    required this.qtyDelta,
    required this.unitCostMru,
    required this.pmpAfterMru,
    required this.stockAfter,
    this.sourceNumber = '',
    this.reason = '',
    this.createdAt = '',
  });

  factory StockMovement.fromJson(Map<String, dynamic> j) => StockMovement(
        id: _i(j['id']),
        articleId: _i(j['articleId']),
        articleName: '${j['articleName'] ?? ''}',
        sku: '${j['sku'] ?? ''}',
        movementType: '${j['movementType'] ?? ''}',
        qtyDelta: _d(j['qtyDelta']),
        unitCostMru: _d(j['unitCostMru']),
        pmpAfterMru: _d(j['pmpAfterMru']),
        stockAfter: _d(j['stockAfter']),
        sourceNumber: '${j['sourceNumber'] ?? ''}',
        reason: '${j['reason'] ?? ''}',
        createdAt: '${j['createdAt'] ?? ''}',
      );
}

class DocLineModel {
  final int articleId;
  final String sku;
  final String designation;
  final double qty;
  final double unitPriceHtMru;
  final double discountPct;
  final double tvaRate;
  final bool isExempt;
  final double lineHtMru;
  final double lineTvaMru;
  final double lineTtcMru;

  const DocLineModel({
    required this.articleId,
    this.sku = '',
    this.designation = '',
    required this.qty,
    required this.unitPriceHtMru,
    this.discountPct = 0,
    this.tvaRate = 16,
    this.isExempt = false,
    this.lineHtMru = 0,
    this.lineTvaMru = 0,
    this.lineTtcMru = 0,
  });

  factory DocLineModel.fromJson(Map<String, dynamic> j) => DocLineModel(
        articleId: _i(j['articleId']),
        sku: '${j['sku'] ?? ''}',
        designation: '${j['designation'] ?? ''}',
        qty: _d(j['qty'], 1),
        unitPriceHtMru: _d(j['unitPriceHtMru'] ?? j['unitCostHtMru']),
        discountPct: _d(j['discountPct']),
        tvaRate: _d(j['tvaRate'], 16),
        isExempt: j['isExempt'] == true,
        lineHtMru: _d(j['lineHtMru']),
        lineTvaMru: _d(j['lineTvaMru']),
        lineTtcMru: _d(j['lineTtcMru']),
      );
}

class CommercialDoc {
  final int id;
  final String docType;
  final String docNumber;
  final String status;
  final int partyId;
  final String partyName;
  final String partyNif;
  final String issueDate;
  final String dueDate;
  final double globalDiscountPct;
  final double totalHtMru;
  final double totalTvaMru;
  final double totalTtcMru;
  final double grossMarginMru;
  final double paidMru;
  final double remainingMru;
  final bool stockApplied;
  final List<DocLineModel> lines;

  const CommercialDoc({
    required this.id,
    required this.docType,
    required this.docNumber,
    required this.status,
    required this.partyId,
    required this.partyName,
    this.partyNif = '',
    required this.issueDate,
    this.dueDate = '',
    this.globalDiscountPct = 0,
    this.totalHtMru = 0,
    this.totalTvaMru = 0,
    this.totalTtcMru = 0,
    this.grossMarginMru = 0,
    this.paidMru = 0,
    this.remainingMru = 0,
    this.stockApplied = false,
    this.lines = const [],
  });

  factory CommercialDoc.fromJson(Map<String, dynamic> j,
      {List<DocLineModel> lines = const []}) {
    return CommercialDoc(
      id: _i(j['id']),
      docType: '${j['docType'] ?? ''}',
      docNumber: '${j['docNumber'] ?? ''}',
      status: '${j['status'] ?? ''}',
      partyId: _i(j['clientId'] ?? j['supplierId']),
      partyName: '${j['clientName'] ?? j['supplierName'] ?? ''}',
      partyNif: '${j['clientNif'] ?? j['supplierNif'] ?? ''}',
      issueDate: '${j['issueDate'] ?? ''}',
      dueDate: '${j['dueDate'] ?? ''}',
      globalDiscountPct: _d(j['globalDiscountPct']),
      totalHtMru: _d(j['totalHtMru']),
      totalTvaMru: _d(j['totalTvaMru']),
      totalTtcMru: _d(j['totalTtcMru']),
      grossMarginMru: _d(j['grossMarginMru']),
      paidMru: _d(j['paidMru']),
      remainingMru: _d(j['remainingMru']),
      stockApplied: j['stockDeducted'] == true || j['stockApplied'] == true,
      lines: lines,
    );
  }
}

class CommercialPosSession {
  final int id;
  final String sessionNumber;
  final String registerCode;
  final String cashierName;
  final String status;
  final double openingFloatMru;
  final double expectedCashMru;
  final double? countedCashMru;
  final double varianceMru;
  final double totalSalesTtcMru;
  final int ticketsCount;
  final String openedAt;
  final String closedAt;

  const CommercialPosSession({
    required this.id,
    required this.sessionNumber,
    required this.registerCode,
    required this.cashierName,
    required this.status,
    this.openingFloatMru = 0,
    this.expectedCashMru = 0,
    this.countedCashMru,
    this.varianceMru = 0,
    this.totalSalesTtcMru = 0,
    this.ticketsCount = 0,
    this.openedAt = '',
    this.closedAt = '',
  });

  factory CommercialPosSession.fromJson(Map<String, dynamic> j) =>
      CommercialPosSession(
        id: _i(j['id']),
        sessionNumber: '${j['sessionNumber'] ?? ''}',
        registerCode: '${j['registerCode'] ?? 'C1'}',
        cashierName: '${j['cashierName'] ?? ''}',
        status: '${j['status'] ?? 'OPEN'}',
        openingFloatMru: _d(j['openingFloatMru']),
        expectedCashMru: _d(j['expectedCashMru']),
        countedCashMru:
            j['countedCashMru'] != null ? _d(j['countedCashMru']) : null,
        varianceMru: _d(j['varianceMru']),
        totalSalesTtcMru: _d(j['totalSalesTtcMru']),
        ticketsCount: _i(j['ticketsCount']),
        openedAt: '${j['openedAt'] ?? ''}',
        closedAt: '${j['closedAt'] ?? ''}',
      );
}

class CommercialPosTicket {
  final int id;
  final String ticketNumber;
  final String status;
  final String payMethod;
  final double totalHtMru;
  final double totalTvaMru;
  final double totalTtcMru;
  final double changeMru;
  final String customerName;
  final String createdAt;

  const CommercialPosTicket({
    required this.id,
    required this.ticketNumber,
    required this.status,
    required this.payMethod,
    this.totalHtMru = 0,
    this.totalTvaMru = 0,
    this.totalTtcMru = 0,
    this.changeMru = 0,
    this.customerName = '',
    this.createdAt = '',
  });

  factory CommercialPosTicket.fromJson(Map<String, dynamic> j) =>
      CommercialPosTicket(
        id: _i(j['id']),
        ticketNumber: '${j['ticketNumber'] ?? ''}',
        status: '${j['status'] ?? 'PAID'}',
        payMethod: '${j['payMethod'] ?? 'Cash'}',
        totalHtMru: _d(j['totalHtMru']),
        totalTvaMru: _d(j['totalTvaMru']),
        totalTtcMru: _d(j['totalTtcMru']),
        changeMru: _d(j['changeMru']),
        customerName: '${j['customerName'] ?? ''}',
        createdAt: '${j['createdAt'] ?? ''}',
      );
}

class TreasuryAccount {
  final int id;
  final String code;
  final String name;
  final String accountType;
  final String bankName;
  final double currentBalanceMru;

  const TreasuryAccount({
    required this.id,
    required this.code,
    required this.name,
    required this.accountType,
    this.bankName = '',
    this.currentBalanceMru = 0,
  });

  factory TreasuryAccount.fromJson(Map<String, dynamic> j) => TreasuryAccount(
        id: _i(j['id']),
        code: '${j['code'] ?? ''}',
        name: '${j['name'] ?? ''}',
        accountType: '${j['accountType'] ?? 'CAISSE'}',
        bankName: '${j['bankName'] ?? ''}',
        currentBalanceMru: _d(j['currentBalanceMru']),
      );
}

class TreasuryMovement {
  final int id;
  final int accountId;
  final String accountName;
  final String movementDate;
  final String direction;
  final double amountMru;
  final double balanceAfterMru;
  final String payMethod;
  final String label;

  const TreasuryMovement({
    required this.id,
    required this.accountId,
    required this.accountName,
    required this.movementDate,
    required this.direction,
    required this.amountMru,
    required this.balanceAfterMru,
    this.payMethod = '',
    this.label = '',
  });

  factory TreasuryMovement.fromJson(Map<String, dynamic> j) => TreasuryMovement(
        id: _i(j['id']),
        accountId: _i(j['accountId']),
        accountName: '${j['accountName'] ?? ''}',
        movementDate: '${j['movementDate'] ?? ''}',
        direction: '${j['direction'] ?? 'IN'}',
        amountMru: _d(j['amountMru']),
        balanceAfterMru: _d(j['balanceAfterMru']),
        payMethod: '${j['payMethod'] ?? ''}',
        label: '${j['label'] ?? ''}',
      );
}

class ChequeDraft {
  final int id;
  final String direction;
  final String instrumentType;
  final String number;
  final String bankName;
  final String partyName;
  final String dueDate;
  final double amountMru;
  final String status;

  const ChequeDraft({
    required this.id,
    required this.direction,
    required this.instrumentType,
    required this.number,
    this.bankName = '',
    required this.partyName,
    required this.dueDate,
    required this.amountMru,
    required this.status,
  });

  factory ChequeDraft.fromJson(Map<String, dynamic> j) => ChequeDraft(
        id: _i(j['id']),
        direction: '${j['direction'] ?? 'CLIENT'}',
        instrumentType: '${j['instrumentType'] ?? 'CHEQUE'}',
        number: '${j['number'] ?? ''}',
        bankName: '${j['bankName'] ?? ''}',
        partyName: '${j['partyName'] ?? ''}',
        dueDate: '${j['dueDate'] ?? ''}',
        amountMru: _d(j['amountMru']),
        status: '${j['status'] ?? 'EN_PORTEFEUILLE'}',
      );
}

class MonthlyObjective {
  final int year;
  final int month;
  final String label;
  final double targetCaHtMru;
  final double? targetMarginPct;
  final double realizedCaHtMru;
  final double prevCaHtMru;
  final double? attainmentPct;
  final String status;

  const MonthlyObjective({
    required this.year,
    required this.month,
    required this.label,
    this.targetCaHtMru = 0,
    this.targetMarginPct,
    this.realizedCaHtMru = 0,
    this.prevCaHtMru = 0,
    this.attainmentPct,
    this.status = 'NON_DEFINI',
  });

  factory MonthlyObjective.fromJson(Map<String, dynamic> j) => MonthlyObjective(
        year: _i(j['year']),
        month: _i(j['month']),
        label: '${j['label'] ?? ''}',
        targetCaHtMru: _d(j['targetCaHtMru']),
        targetMarginPct:
            j['targetMarginPct'] != null ? _d(j['targetMarginPct']) : null,
        realizedCaHtMru: _d(j['realizedCaHtMru']),
        prevCaHtMru: _d(j['prevCaHtMru']),
        attainmentPct:
            j['attainmentPct'] != null ? _d(j['attainmentPct']) : null,
        status: '${j['status'] ?? 'NON_DEFINI'}',
      );
}

class CompanySettings {
  final String companyName;
  final String nif;
  final String rc;
  final String address;
  final String city;
  final String phone;
  final String email;
  final String bankRib;
  final String bankilyNumber;
  final String masriviNumber;
  final String invoiceFooter;

  const CompanySettings({
    this.companyName = 'Full·Tek Négoce SARL',
    this.nif = 'NIF 0123456789',
    this.rc = 'RC NKC-2026-B104',
    this.address = 'Tevragh Zeina, Avenue Gamal Abdel Nasser',
    this.city = 'Nouakchott',
    this.phone = '+222 45 25 11 00',
    this.email = 'contact@full-tek.com',
    this.bankRib = 'BMCI 00012 00100 04589210011 42',
    this.bankilyNumber = '42 74 42 42',
    this.masriviNumber = '42 74 42 42',
    this.invoiceFooter =
        'Règlement à réception ou selon échéance. Tout retard entraîne des pénalités.',
  });

  Map<String, dynamic> toJson() => {
        'companyName': companyName,
        'nif': nif,
        'rc': rc,
        'address': address,
        'city': city,
        'phone': phone,
        'email': email,
        'bankRib': bankRib,
        'bankilyNumber': bankilyNumber,
        'masriviNumber': masriviNumber,
        'invoiceFooter': invoiceFooter,
      };

  factory CompanySettings.fromJson(Map<String, dynamic> j) => CompanySettings(
        companyName: '${j['companyName'] ?? 'Full·Tek Négoce SARL'}',
        nif: '${j['nif'] ?? ''}',
        rc: '${j['rc'] ?? ''}',
        address: '${j['address'] ?? ''}',
        city: '${j['city'] ?? 'Nouakchott'}',
        phone: '${j['phone'] ?? ''}',
        email: '${j['email'] ?? ''}',
        bankRib: '${j['bankRib'] ?? ''}',
        bankilyNumber: '${j['bankilyNumber'] ?? ''}',
        masriviNumber: '${j['masriviNumber'] ?? ''}',
        invoiceFooter: '${j['invoiceFooter'] ?? ''}',
      );
}

class OperatingExpense {
  final int id;
  final String date;
  final String category;
  final String label;
  final double amountMru;
  final String payMethod;
  final String beneficiary;
  final String ref;

  const OperatingExpense({
    required this.id,
    required this.date,
    required this.category,
    required this.label,
    required this.amountMru,
    required this.payMethod,
    this.beneficiary = '',
    this.ref = '',
  });
}

class WarehouseLocation {
  final int id;
  final String code;
  final String name;
  final String city;
  final bool isDefault;

  const WarehouseLocation({
    required this.id,
    required this.code,
    required this.name,
    this.city = 'Nouakchott',
    this.isDefault = false,
  });
}

class StockTransferRecord {
  final int id;
  final String date;
  final String fromWarehouse;
  final String toWarehouse;
  final String sku;
  final String articleName;
  final double qty;
  final String note;

  const StockTransferRecord({
    required this.id,
    required this.date,
    required this.fromWarehouse,
    required this.toWarehouse,
    required this.sku,
    required this.articleName,
    required this.qty,
    this.note = '',
  });
}

class InventorySessionRecord {
  final int id;
  final String date;
  final String warehouseName;
  final int articlesCounted;
  final double netVarianceQty;
  final double netVarianceValueMru;

  const InventorySessionRecord({
    required this.id,
    required this.date,
    required this.warehouseName,
    required this.articlesCounted,
    required this.netVarianceQty,
    required this.netVarianceValueMru,
  });
}

class ParkedPosOrder {
  final String id;
  final String label;
  final String priceTier;
  final int? clientId;
  final List<Map<String, dynamic>> lines;
  final String createdAt;

  const ParkedPosOrder({
    required this.id,
    required this.label,
    required this.priceTier,
    this.clientId,
    required this.lines,
    required this.createdAt,
  });
}
