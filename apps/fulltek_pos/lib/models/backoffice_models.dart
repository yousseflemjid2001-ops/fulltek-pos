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
    this.notes = '',
  });

  double get remainingMru =>
      (totalTtcMru - paidMru) > 0 ? (totalTtcMru - paidMru) : 0;

  factory RestoPurchase.fromJson(Map<String, dynamic> j) => RestoPurchase(
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
        notes: '${j['notes'] ?? ''}',
      );
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
    this.notes = '',
  });

  double get remainingMru =>
      (totalTtcMru - paidMru) > 0 ? (totalTtcMru - paidMru) : 0;

  factory RestoB2bInvoice.fromJson(Map<String, dynamic> j) => RestoB2bInvoice(
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
        notes: '${j['notes'] ?? ''}',
      );
}
