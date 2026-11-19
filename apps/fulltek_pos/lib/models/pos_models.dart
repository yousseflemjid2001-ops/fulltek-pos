enum PosRole {
  owner('OWNER', 'Propriétaire', 'المالك', 'Owner'),
  adminSite('ADMIN_SITE', 'Admin Site', 'مدير الفرع', 'Site Admin'),
  manager('MANAGER', 'Gérant / Manager', 'مدير الصالة', 'Manager'),
  cashier('CASHIER', 'Caissier', 'أمين الصندوق', 'Cashier'),
  waiter('WAITER', 'Serveur', 'نادل', 'Waiter'),
  kitchen('KITCHEN', 'Cuisine / KDS', 'المطبخ', 'Kitchen'),
  stockKeeper('STOCK_KEEPER', 'Magasinier', 'أمين المخزن', 'Stock Keeper'),
  accountant('ACCOUNTANT', 'Comptable', 'محاسب', 'Accountant'),
  delivery('DELIVERY', 'Livreur', 'موصل', 'Delivery');

  final String code;
  final String fr;
  final String ar;
  final String en;
  const PosRole(this.code, this.fr, this.ar, this.en);

  String label(String lang) => lang == 'ar' ? ar : (lang == 'en' ? en : fr);
}

enum PosPermission {
  takeOrders,
  checkout,
  applyDiscount,
  voidOrComp,
  splitBill,
  manageReservations,
  manageKarni,
  closeCashZ,
  syncCloud,
}

class RbacMatrix {
  static const Map<PosRole, Set<PosPermission>> grants = {
    PosRole.owner: {
      PosPermission.takeOrders,
      PosPermission.checkout,
      PosPermission.applyDiscount,
      PosPermission.voidOrComp,
      PosPermission.splitBill,
      PosPermission.manageReservations,
      PosPermission.manageKarni,
      PosPermission.closeCashZ,
      PosPermission.syncCloud,
    },
    PosRole.adminSite: {
      PosPermission.takeOrders,
      PosPermission.checkout,
      PosPermission.applyDiscount,
      PosPermission.voidOrComp,
      PosPermission.splitBill,
      PosPermission.manageReservations,
      PosPermission.manageKarni,
      PosPermission.closeCashZ,
      PosPermission.syncCloud,
    },
    PosRole.manager: {
      PosPermission.takeOrders,
      PosPermission.checkout,
      PosPermission.applyDiscount,
      PosPermission.voidOrComp,
      PosPermission.splitBill,
      PosPermission.manageReservations,
      PosPermission.manageKarni,
      PosPermission.closeCashZ,
      PosPermission.syncCloud,
    },
    PosRole.cashier: {
      PosPermission.takeOrders,
      PosPermission.checkout,
      PosPermission.splitBill,
      PosPermission.manageReservations,
      PosPermission.manageKarni,
      PosPermission.closeCashZ,
      PosPermission.syncCloud,
    },
    PosRole.waiter: {
      PosPermission.takeOrders,
      PosPermission.splitBill,
      PosPermission.manageReservations,
    },
    PosRole.kitchen: {},
    PosRole.stockKeeper: {},
    PosRole.accountant: {PosPermission.closeCashZ, PosPermission.syncCloud},
    PosRole.delivery: {PosPermission.takeOrders},
  };

  static bool can(PosRole role, PosPermission perm) {
    return grants[role]?.contains(perm) ?? false;
  }
}

class StaffMember {
  final String id;
  final String name;
  final PosRole role;
  final String pinCode;
  final bool isActive;

  const StaffMember({
    required this.id,
    required this.name,
    required this.role,
    required this.pinCode,
    this.isActive = true,
  });

  bool can(PosPermission perm) => RbacMatrix.can(role, perm);
}

class MenuCategory {
  final String id;
  final String nameFr;
  final String nameAr;
  final String nameEn;
  final String icon;

  const MenuCategory({
    required this.id,
    required this.nameFr,
    required this.nameAr,
    required this.nameEn,
    required this.icon,
  });

  String label(String lang) =>
      lang == 'ar' ? nameAr : (lang == 'en' ? nameEn : nameFr);
}

class MenuItem {
  final String id;
  final String categoryId;
  final String sku;
  final String nameFr;
  final String nameAr;
  final String nameEn;
  final double priceMru;
  final String kitchenStation; // KITCHEN | GRILL | BAR
  final bool available;

  const MenuItem({
    required this.id,
    required this.categoryId,
    required this.sku,
    required this.nameFr,
    required this.nameAr,
    required this.nameEn,
    required this.priceMru,
    this.kitchenStation = 'KITCHEN',
    this.available = true,
  });

  String label(String lang) =>
      lang == 'ar' ? nameAr : (lang == 'en' ? nameEn : nameFr);
}

enum TableStatus { free, occupied, reserved, billRequested }

class DiningZone {
  final String id;
  final String nameFr;
  final String nameAr;
  final String nameEn;
  final bool isVip;

  const DiningZone({
    required this.id,
    required this.nameFr,
    required this.nameAr,
    required this.nameEn,
    this.isVip = false,
  });

  String label(String lang) =>
      lang == 'ar' ? nameAr : (lang == 'en' ? nameEn : nameFr);
}

class DiningTable {
  final String id;
  final String zoneId;
  final String code;
  final int capacity;
  final TableStatus status;
  final int guests;
  final String? activeOrderId;
  final DateTime? occupiedSince;

  const DiningTable({
    required this.id,
    required this.zoneId,
    required this.code,
    required this.capacity,
    this.status = TableStatus.free,
    this.guests = 0,
    this.activeOrderId,
    this.occupiedSince,
  });

  DiningTable copyWith({
    TableStatus? status,
    int? guests,
    String? activeOrderId,
    bool clearOrder = false,
    DateTime? occupiedSince,
    bool clearOccupied = false,
  }) {
    return DiningTable(
      id: id,
      zoneId: zoneId,
      code: code,
      capacity: capacity,
      status: status ?? this.status,
      guests: guests ?? this.guests,
      activeOrderId: clearOrder ? null : (activeOrderId ?? this.activeOrderId),
      occupiedSince:
          clearOccupied ? null : (occupiedSince ?? this.occupiedSince),
    );
  }
}

class VipReservation {
  final String id;
  final String customerName;
  final String phone;
  final String zoneId;
  final String tableId;
  final int guests;
  final String timeSlot;
  final double arbounMru;
  final String status; // confirmed | seated | cancelled
  final String? note;

  const VipReservation({
    required this.id,
    required this.customerName,
    required this.phone,
    required this.zoneId,
    required this.tableId,
    required this.guests,
    required this.timeSlot,
    required this.arbounMru,
    this.status = 'confirmed',
    this.note,
  });

  VipReservation copyWith({String? status}) {
    return VipReservation(
      id: id,
      customerName: customerName,
      phone: phone,
      zoneId: zoneId,
      tableId: tableId,
      guests: guests,
      timeSlot: timeSlot,
      arbounMru: arbounMru,
      status: status ?? this.status,
      note: note,
    );
  }
}

class OrderItem {
  final String lineId;
  final MenuItem item;
  final int quantity;
  final String? kitchenNote;
  final bool sentToKitchen;
  final bool isComp;

  const OrderItem({
    required this.lineId,
    required this.item,
    required this.quantity,
    this.kitchenNote,
    this.sentToKitchen = false,
    this.isComp = false,
  });

  double get lineTotal => isComp ? 0 : item.priceMru * quantity;

  OrderItem copyWith({
    int? quantity,
    String? kitchenNote,
    bool? sentToKitchen,
    bool? isComp,
  }) {
    return OrderItem(
      lineId: lineId,
      item: item,
      quantity: quantity ?? this.quantity,
      kitchenNote: kitchenNote ?? this.kitchenNote,
      sentToKitchen: sentToKitchen ?? this.sentToKitchen,
      isComp: isComp ?? this.isComp,
    );
  }
}

enum PaymentMethod { cash, bankily, masrivi, sedad, karni }

class PaymentEntry {
  final PaymentMethod method;
  final double amountMru;
  final String? reference;
  final String? karniCustomerId;

  const PaymentEntry({
    required this.method,
    required this.amountMru,
    this.reference,
    this.karniCustomerId,
  });

  Map<String, dynamic> toJson() => {
        'method': method.name.toUpperCase(),
        'amount_mru': amountMru,
        if (reference != null && reference!.isNotEmpty) 'reference': reference,
        if (karniCustomerId != null) 'karni_customer_id': karniCustomerId,
      };
}

class PosOrder {
  final String id;
  final String ticketNumber;
  final String? tableId;
  final String? tableCode;
  final String staffName;
  final List<OrderItem> items;
  final double discountPercent;
  final double arbounDepositMru;
  final List<PaymentEntry> payments;
  final String status; // open | paid | voided
  final DateTime createdAt;
  final DateTime? paidAt;

  const PosOrder({
    required this.id,
    required this.ticketNumber,
    this.tableId,
    this.tableCode,
    required this.staffName,
    required this.items,
    this.discountPercent = 0,
    this.arbounDepositMru = 0,
    this.payments = const [],
    this.status = 'open',
    required this.createdAt,
    this.paidAt,
  });

  double get subtotal => items.fold(0.0, (s, e) => s + e.lineTotal);
  double get discountAmount => subtotal * (discountPercent / 100.0);
  double get netTotal {
    final v = subtotal - discountAmount - arbounDepositMru;
    return v < 0 ? 0 : v;
  }

  double get totalPaid => payments.fold(0.0, (s, p) => s + p.amountMru);
  double get changeDue => totalPaid > netTotal ? totalPaid - netTotal : 0;

  PosOrder copyWith({
    List<OrderItem>? items,
    double? discountPercent,
    double? arbounDepositMru,
    List<PaymentEntry>? payments,
    String? status,
    DateTime? paidAt,
  }) {
    return PosOrder(
      id: id,
      ticketNumber: ticketNumber,
      tableId: tableId,
      tableCode: tableCode,
      staffName: staffName,
      items: items ?? this.items,
      discountPercent: discountPercent ?? this.discountPercent,
      arbounDepositMru: arbounDepositMru ?? this.arbounDepositMru,
      payments: payments ?? this.payments,
      status: status ?? this.status,
      createdAt: createdAt,
      paidAt: paidAt ?? this.paidAt,
    );
  }

  Map<String, dynamic> toSyncJson() => {
        'id': id,
        'ticket_number': ticketNumber,
        'table_code': tableCode ?? 'COMPTOIR',
        'staff_name': staffName,
        'subtotal_mru': subtotal,
        'discount_percent': discountPercent,
        'arboun_mru': arbounDepositMru,
        'total_mru': netTotal,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'paid_at': paidAt?.toIso8601String(),
        'items': items
            .map((i) => {
                  'sku': i.item.sku,
                  'name': i.item.nameFr,
                  'qty': i.quantity,
                  'unit_price': i.item.priceMru,
                  'line_total': i.lineTotal,
                  'is_comp': i.isComp,
                })
            .toList(),
        'payments': payments.map((p) => p.toJson()).toList(),
      };
}

class KarniCustomer {
  final String id;
  final String name;
  final String phone;
  final double creditLimitMru;
  final double balanceDueMru;
  final DateTime lastActivity;

  const KarniCustomer({
    required this.id,
    required this.name,
    required this.phone,
    required this.creditLimitMru,
    required this.balanceDueMru,
    required this.lastActivity,
  });

  KarniCustomer copyWith({double? balanceDueMru, DateTime? lastActivity}) {
    return KarniCustomer(
      id: id,
      name: name,
      phone: phone,
      creditLimitMru: creditLimitMru,
      balanceDueMru: balanceDueMru ?? this.balanceDueMru,
      lastActivity: lastActivity ?? this.lastActivity,
    );
  }
}

class ReturnRemakeCompRecord {
  final String id;
  final String type; // remake | return | comp
  final String orderTicket;
  final String itemName;
  final int quantity;
  final double amountMru;
  final String reason;
  final String staffName;
  final String? approvedBy;
  final DateTime createdAt;

  const ReturnRemakeCompRecord({
    required this.id,
    required this.type,
    required this.orderTicket,
    required this.itemName,
    required this.quantity,
    required this.amountMru,
    required this.reason,
    required this.staffName,
    this.approvedBy,
    required this.createdAt,
  });
}

class CashClosingZ {
  final String id;
  final DateTime closedAt;
  final String cashierName;
  final double countedCashMru;
  final double expectedCashMru;
  final double countedBankilyMru;
  final double expectedBankilyMru;
  final double countedMasriviMru;
  final double expectedMasriviMru;
  final double countedSedadMru;
  final double expectedSedadMru;
  final double karniIssuedMru;
  final int ordersCount;
  final int remakesCount;

  const CashClosingZ({
    required this.id,
    required this.closedAt,
    required this.cashierName,
    required this.countedCashMru,
    required this.expectedCashMru,
    required this.countedBankilyMru,
    required this.expectedBankilyMru,
    required this.countedMasriviMru,
    required this.expectedMasriviMru,
    required this.countedSedadMru,
    required this.expectedSedadMru,
    required this.karniIssuedMru,
    required this.ordersCount,
    required this.remakesCount,
  });

  double get cashVarianceMru => countedCashMru - expectedCashMru;
  double get totalExpectedMru =>
      expectedCashMru +
      expectedBankilyMru +
      expectedMasriviMru +
      expectedSedadMru +
      karniIssuedMru;

  Map<String, dynamic> toSyncJson() => {
        'id': id,
        'closed_at': closedAt.toIso8601String(),
        'cashier_name': cashierName,
        'counted_cash_mru': countedCashMru,
        'expected_cash_mru': expectedCashMru,
        'cash_variance_mru': cashVarianceMru,
        'expected_bankily_mru': expectedBankilyMru,
        'expected_masrivi_mru': expectedMasriviMru,
        'expected_sedad_mru': expectedSedadMru,
        'karni_issued_mru': karniIssuedMru,
        'orders_count': ordersCount,
        'remakes_count': remakesCount,
      };
}

class SyncQueueItem {
  final String id;
  final String entityType; // order | closing_z | karni | remake | reservation
  final String summary;
  final Map<String, dynamic> payload;
  final String status; // pending | synced | error
  final DateTime createdAt;
  final DateTime? syncedAt;

  const SyncQueueItem({
    required this.id,
    required this.entityType,
    required this.summary,
    required this.payload,
    this.status = 'pending',
    required this.createdAt,
    this.syncedAt,
  });

  SyncQueueItem copyWith({String? status, DateTime? syncedAt}) {
    return SyncQueueItem(
      id: id,
      entityType: entityType,
      summary: summary,
      payload: payload,
      status: status ?? this.status,
      createdAt: createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }
}

class OfflineLicenseInfo {
  final String tenantName;
  final String code12;
  final DateTime expiresAt;
  final bool ed25519Verified;

  const OfflineLicenseInfo({
    required this.tenantName,
    required this.code12,
    required this.expiresAt,
    required this.ed25519Verified,
  });

  int get daysRemaining {
    final diff = expiresAt.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }
}
