class RestoSupplier {
  final int id;
  final String name;
  final String phone;
  final String category;
  final String nif;
  final String address;
  final double balanceDueMru;
  final String notes;

  const RestoSupplier({
    required this.id,
    required this.name,
    this.phone = '',
    this.category = 'Alimentaire',
    this.nif = '',
    this.address = '',
    this.balanceDueMru = 0,
    this.notes = '',
  });

  factory RestoSupplier.fromJson(Map<String, dynamic> j) => RestoSupplier(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: '${j['name'] ?? ''}',
        phone: '${j['phone'] ?? ''}',
        category: '${j['category'] ?? 'Alimentaire'}',
        nif: '${j['nif'] ?? ''}',
        address: '${j['address'] ?? ''}',
        balanceDueMru:
            ((j['balance_due_mru'] ?? j['balanceDueMru']) as num?)?.toDouble() ??
                0,
        notes: '${j['notes'] ?? ''}',
      );
}

class RestoPurchaseLine {
  final String ingredientId;
  final String name;
  final String unit;
  final double qty;
  final double unitCostMru;

  const RestoPurchaseLine({
    this.ingredientId = '',
    required this.name,
    this.unit = 'kg',
    required this.qty,
    required this.unitCostMru,
  });

  double get lineTotalMru => qty * unitCostMru;

  Map<String, dynamic> toJson() => {
        'ingredientId': ingredientId,
        'name': name,
        'unit': unit,
        'qty': qty,
        'unitCostMru': unitCostMru,
      };

  factory RestoPurchaseLine.fromJson(Map<String, dynamic> j) =>
      RestoPurchaseLine(
        ingredientId: '${j['ingredientId'] ?? ''}',
        name: '${j['name'] ?? ''}',
        unit: '${j['unit'] ?? 'kg'}',
        qty: ((j['qty'] ?? 0) as num).toDouble(),
        unitCostMru: ((j['unitCostMru'] ?? 0) as num).toDouble(),
      );
}

class RestoPurchase {
  final int id;
  final String docNumber;
  final int? supplierId;
  final String supplierName;
  final String docDate;
  final String status; // UNPAID | PARTIAL | PAID
  final double subtotalHtMru;
  final double tvaMru;
  final double totalTtcMru;
  final double paidMru;
  final String payMethod;
  final List<RestoPurchaseLine> items;
  final String notes;

  const RestoPurchase({
    required this.id,
    required this.docNumber,
    this.supplierId,
    required this.supplierName,
    required this.docDate,
    this.status = 'UNPAID',
    this.subtotalHtMru = 0,
    this.tvaMru = 0,
    required this.totalTtcMru,
    this.paidMru = 0,
    this.payMethod = 'Cash',
    this.items = const [],
    this.notes = '',
  });

  double get remainingMru =>
      (totalTtcMru - paidMru) > 0 ? (totalTtcMru - paidMru) : 0;

  factory RestoPurchase.fromJson(Map<String, dynamic> j) {
    final rawItems = (j['items'] as List?) ?? const [];
    return RestoPurchase(
      id: (j['id'] as num?)?.toInt() ?? 0,
      docNumber: '${j['doc_number'] ?? j['docNumber'] ?? ''}',
      supplierId: (j['supplier_id'] as num?)?.toInt(),
      supplierName: '${j['supplier_name'] ?? j['supplierName'] ?? ''}',
      docDate: '${j['doc_date'] ?? j['docDate'] ?? ''}',
      status: '${j['status'] ?? 'UNPAID'}',
      subtotalHtMru: ((j['subtotal_ht_mru'] ?? 0) as num).toDouble(),
      tvaMru: ((j['tva_mru'] ?? 0) as num).toDouble(),
      totalTtcMru: ((j['total_ttc_mru'] ?? 0) as num).toDouble(),
      paidMru: ((j['paid_mru'] ?? 0) as num).toDouble(),
      payMethod: '${j['pay_method'] ?? 'Cash'}',
      items: rawItems
          .whereType<Map>()
          .map((m) => RestoPurchaseLine.fromJson(m.cast<String, dynamic>()))
          .toList(),
      notes: '${j['notes'] ?? ''}',
    );
  }
}

class RestoExpense {
  final int id;
  final String category;
  final String label;
  final double amountMru;
  final double tvaMru;
  final String payMethod;
  final String expenseDate;
  final String ref;
  final String notes;

  const RestoExpense({
    required this.id,
    required this.category,
    required this.label,
    required this.amountMru,
    this.tvaMru = 0,
    this.payMethod = 'Cash',
    required this.expenseDate,
    this.ref = '',
    this.notes = '',
  });

  factory RestoExpense.fromJson(Map<String, dynamic> j) => RestoExpense(
        id: (j['id'] as num?)?.toInt() ?? 0,
        category: '${j['category'] ?? 'Divers'}',
        label: '${j['label'] ?? ''}',
        amountMru: ((j['amount_mru'] ?? 0) as num).toDouble(),
        tvaMru: ((j['tva_mru'] ?? 0) as num).toDouble(),
        payMethod: '${j['pay_method'] ?? 'Cash'}',
        expenseDate: '${j['expense_date'] ?? ''}',
        ref: '${j['ref'] ?? ''}',
        notes: '${j['notes'] ?? ''}',
      );
}

class RestoInvoiceLine {
  final String label;
  final double qty;
  final double unitPriceMru;

  const RestoInvoiceLine({
    required this.label,
    required this.qty,
    required this.unitPriceMru,
  });

  double get lineTotalMru => qty * unitPriceMru;

  Map<String, dynamic> toJson() => {
        'label': label,
        'qty': qty,
        'unitPriceMru': unitPriceMru,
      };

  factory RestoInvoiceLine.fromJson(Map<String, dynamic> j) =>
      RestoInvoiceLine(
        label: '${j['label'] ?? j['name'] ?? ''}',
        qty: ((j['qty'] ?? 1) as num).toDouble(),
        unitPriceMru: ((j['unitPriceMru'] ?? j['price'] ?? 0) as num).toDouble(),
      );
}

class RestoB2bInvoice {
  final int id;
  final String docType; // DEVIS | FACTURE
  final String docNumber;
  final String clientName;
  final String clientPhone;
  final String clientNif;
  final String docDate;
  final String status; // DRAFT | UNPAID | PARTIAL | PAID
  final double subtotalHtMru;
  final double tvaMru;
  final double totalTtcMru;
  final double paidMru;
  final String payMethod;
  final List<RestoInvoiceLine> items;
  final String notes;

  const RestoB2bInvoice({
    required this.id,
    this.docType = 'FACTURE',
    required this.docNumber,
    required this.clientName,
    this.clientPhone = '',
    this.clientNif = '',
    required this.docDate,
    this.status = 'UNPAID',
    this.subtotalHtMru = 0,
    this.tvaMru = 0,
    required this.totalTtcMru,
    this.paidMru = 0,
    this.payMethod = 'Bankily',
    this.items = const [],
    this.notes = '',
  });

  double get remainingMru =>
      (totalTtcMru - paidMru) > 0 ? (totalTtcMru - paidMru) : 0;

  factory RestoB2bInvoice.fromJson(Map<String, dynamic> j) {
    final rawItems = (j['items'] as List?) ?? const [];
    return RestoB2bInvoice(
      id: (j['id'] as num?)?.toInt() ?? 0,
      docType: '${j['doc_type'] ?? 'FACTURE'}',
      docNumber: '${j['doc_number'] ?? ''}',
      clientName: '${j['client_name'] ?? ''}',
      clientPhone: '${j['client_phone'] ?? ''}',
      clientNif: '${j['client_nif'] ?? ''}',
      docDate: '${j['doc_date'] ?? ''}',
      status: '${j['status'] ?? 'UNPAID'}',
      subtotalHtMru: ((j['subtotal_ht_mru'] ?? 0) as num).toDouble(),
      tvaMru: ((j['tva_mru'] ?? 0) as num).toDouble(),
      totalTtcMru: ((j['total_ttc_mru'] ?? 0) as num).toDouble(),
      paidMru: ((j['paid_mru'] ?? 0) as num).toDouble(),
      payMethod: '${j['pay_method'] ?? 'Bankily'}',
      items: rawItems
          .whereType<Map>()
          .map((m) => RestoInvoiceLine.fromJson(m.cast<String, dynamic>()))
          .toList(),
      notes: '${j['notes'] ?? ''}',
    );
  }
}

/// Converts a Mauritanian Ouguiya (MRU) amount into French legal invoice words.
String restoAmountToFrenchWords(double amount) {
  final n = amount.round();
  if (n <= 0) return 'zéro Ouguiya (0 MRU)';
  const units = [
    '',
    'un',
    'deux',
    'trois',
    'quatre',
    'cinq',
    'six',
    'sept',
    'huit',
    'neuf',
    'dix',
    'onze',
    'douze',
    'treize',
    'quatorze',
    'quinze',
    'seize',
    'dix-sept',
    'dix-huit',
    'dix-neuf'
  ];
  const tens = [
    '',
    '',
    'vingt',
    'trente',
    'quarante',
    'cinquante',
    'soixante',
    'soixante',
    'quatre-vingt',
    'quatre-vingt'
  ];

  String under100(int x) {
    if (x < 20) return units[x];
    final t = x ~/ 10;
    final u = x % 10;
    if (t == 7 || t == 9) {
      return '${tens[t]}-${units[10 + u]}';
    }
    if (u == 0) return tens[t];
    if (u == 1 && t < 8) return '${tens[t]} et un';
    return '${tens[t]}-${units[u]}';
  }

  String under1000(int x) {
    final h = x ~/ 100;
    final r = x % 100;
    final hStr = h == 0 ? '' : (h == 1 ? 'cent' : '${units[h]} cent');
    final rStr = r == 0 ? '' : under100(r);
    if (hStr.isEmpty) return rStr;
    if (rStr.isEmpty) return hStr;
    return '$hStr $rStr';
  }

  final parts = <String>[];
  int rem = n;
  final millions = rem ~/ 1000000;
  rem %= 1000000;
  final thousands = rem ~/ 1000;
  rem %= 1000;

  if (millions > 0) {
    parts.add(millions == 1
        ? 'un million'
        : '${under1000(millions)} millions');
  }
  if (thousands > 0) {
    parts.add(thousands == 1 ? 'mille' : '${under1000(thousands)} mille');
  }
  if (rem > 0) {
    parts.add(under1000(rem));
  }
  final words = parts.join(' ').trim();
  final cap = words.isEmpty
      ? 'Zéro'
      : '${words[0].toUpperCase()}${words.substring(1)}';
  return '$cap Ouguiyas ($n MRU)';
}
