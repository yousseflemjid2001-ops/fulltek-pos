import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../l10n/pos_i18n.dart';
import '../models/pos_models.dart';
import '../services/http_bridge.dart';
import '../services/receipt_formatter.dart';
import '../theme/fulltek_themes.dart';

class PosStore extends ChangeNotifier {
  FullTekThemeId _themeId = FullTekThemeId.emeraldNight;
  String _lang = 'fr';
  StaffMember? _currentStaff;

  String apiBaseUrl = 'http://localhost:4000';
  String? cloudJwtToken;
  bool isSyncing = false;
  String? lastSyncMessage;

  late OfflineLicenseInfo license;
  late List<StaffMember> staff;
  late List<MenuCategory> categories;
  late List<MenuItem> menuItems;
  late List<DiningZone> zones;
  late List<DiningTable> tables;
  late List<VipReservation> reservations;
  late List<KarniCustomer> karniCustomers;

  final Map<String, PosOrder> _openOrdersById = {};
  final List<PosOrder> _completedOrders = [];
  final List<ReturnRemakeCompRecord> _remakeRecords = [];
  final List<CashClosingZ> _closingsZ = [];
  final List<SyncQueueItem> _syncQueue = [];

  String? _activeOrderId;
  int _ticketCounter = 1042;
  int _lineCounter = 1;
  int _syncCounter = 1;

  PosStore() {
    _seedMauritanianRestaurantData();
  }

  FullTekThemeId get themeId => _themeId;
  FullTekThemeSpec get themeSpec => FullTekThemes.all[_themeId]!;
  String get lang => _lang;
  PosI18n get i18n => PosI18n(_lang);
  StaffMember? get currentStaff => _currentStaff;

  List<PosOrder> get completedOrders => List.unmodifiable(_completedOrders);
  List<ReturnRemakeCompRecord> get remakeRecords =>
      List.unmodifiable(_remakeRecords);
  List<CashClosingZ> get closingsZ => List.unmodifiable(_closingsZ);
  List<SyncQueueItem> get syncQueue => List.unmodifiable(_syncQueue);
  int get pendingSyncCount =>
      _syncQueue.where((q) => q.status == 'pending').length;

  PosOrder? get activeOrder =>
      _activeOrderId == null ? null : _openOrdersById[_activeOrderId];

  PosOrder? orderForTable(String tableId) {
    final table = tables.firstWhere((t) => t.id == tableId);
    if (table.activeOrderId == null) return null;
    return _openOrdersById[table.activeOrderId];
  }

  void setTheme(FullTekThemeId id) {
    if (_themeId == id) return;
    _themeId = id;
    notifyListeners();
  }

  void setLanguage(String code) {
    if (!['fr', 'ar', 'en'].contains(code) || _lang == code) return;
    _lang = code;
    notifyListeners();
  }

  bool loginWithPin(String pin) {
    final idx = staff.indexWhere((s) => s.isActive && s.pinCode == pin.trim());
    if (idx == -1) return false;
    _currentStaff = staff[idx];
    if (_activeOrderId == null) {
      startCounterOrder();
    }
    notifyListeners();
    return true;
  }

  void lockPos() {
    _currentStaff = null;
    notifyListeners();
  }

  StaffMember? verifyManagerPin(String pin) {
    final idx = staff.indexWhere(
      (s) => s.isActive && s.pinCode == pin.trim() && s.can(PosPermission.voidOrComp),
    );
    return idx == -1 ? null : staff[idx];
  }

  bool canCurrent(PosPermission perm) => _currentStaff?.can(perm) ?? false;

  // --- Orders & Floor Plan ---

  PosOrder startCounterOrder() {
    final id = 'ORD-${++_ticketCounter}';
    final order = PosOrder(
      id: id,
      ticketNumber: 'FT-$_ticketCounter',
      staffName: _currentStaff?.name ?? 'Caisse',
      items: const [],
      createdAt: DateTime.now(),
    );
    _openOrdersById[id] = order;
    _activeOrderId = id;
    notifyListeners();
    return order;
  }

  PosOrder openOrSelectTable(String tableId, {int? guests, double arbounMru = 0}) {
    final idx = tables.indexWhere((t) => t.id == tableId);
    if (idx == -1) return startCounterOrder();
    final table = tables[idx];

    if (table.activeOrderId != null &&
        _openOrdersById.containsKey(table.activeOrderId)) {
      _activeOrderId = table.activeOrderId;
      notifyListeners();
      return _openOrdersById[_activeOrderId]!;
    }

    final id = 'ORD-${++_ticketCounter}';
    final order = PosOrder(
      id: id,
      ticketNumber: 'FT-$_ticketCounter',
      tableId: table.id,
      tableCode: table.code,
      staffName: _currentStaff?.name ?? 'Serveur',
      items: const [],
      arbounDepositMru: arbounMru,
      createdAt: DateTime.now(),
    );
    _openOrdersById[id] = order;
    tables[idx] = table.copyWith(
      status: TableStatus.occupied,
      guests: guests ?? (table.guests > 0 ? table.guests : 2),
      activeOrderId: id,
      occupiedSince: DateTime.now(),
    );
    _activeOrderId = id;
    notifyListeners();
    return order;
  }

  void addItemToActiveOrder(MenuItem item, {String? note}) {
    var order = activeOrder ?? startCounterOrder();
    final items = List<OrderItem>.from(order.items);
    final existingIdx = items.indexWhere(
      (l) =>
          l.item.id == item.id &&
          !l.sentToKitchen &&
          !l.isComp &&
          (l.kitchenNote ?? '') == (note ?? ''),
    );
    if (existingIdx != -1) {
      items[existingIdx] = items[existingIdx].copyWith(
        quantity: items[existingIdx].quantity + 1,
      );
    } else {
      items.add(
        OrderItem(
          lineId: 'LN-${_lineCounter++}',
          item: item,
          quantity: 1,
          kitchenNote: note,
        ),
      );
    }
    _openOrdersById[order.id] = order.copyWith(items: items);
    notifyListeners();
  }

  void updateLineQuantity(String lineId, int delta) {
    final order = activeOrder;
    if (order == null) return;
    final items = List<OrderItem>.from(order.items);
    final idx = items.indexWhere((l) => l.lineId == lineId);
    if (idx == -1) return;
    final nextQty = items[idx].quantity + delta;
    if (nextQty <= 0) {
      items.removeAt(idx);
    } else {
      items[idx] = items[idx].copyWith(quantity: nextQty);
    }
    _openOrdersById[order.id] = order.copyWith(items: items);
    notifyListeners();
  }

  void updateLineNote(String lineId, String note) {
    final order = activeOrder;
    if (order == null) return;
    final items = List<OrderItem>.from(order.items);
    final idx = items.indexWhere((l) => l.lineId == lineId);
    if (idx == -1) return;
    items[idx] = items[idx].copyWith(kitchenNote: note.trim());
    _openOrdersById[order.id] = order.copyWith(items: items);
    notifyListeners();
  }

  bool applyOrderDiscount(double percent, {String? managerPin}) {
    final order = activeOrder;
    if (order == null) return false;
    final authorized = canCurrent(PosPermission.applyDiscount) ||
        (managerPin != null && verifyManagerPin(managerPin) != null);
    if (!authorized) return false;
    final clamped = percent.clamp(0.0, 50.0);
    _openOrdersById[order.id] = order.copyWith(discountPercent: clamped);
    notifyListeners();
    return true;
  }

  /// Marks unsent items as sent to Kitchen / KDS and returns formatted KDS ticket
  String? sendActiveOrderToKitchen() {
    final order = activeOrder;
    if (order == null) return null;
    final unsent = order.items.where((i) => !i.sentToKitchen).toList();
    if (unsent.isEmpty) return null;
    final updated =
        order.items.map((i) => i.copyWith(sentToKitchen: true)).toList();
    _openOrdersById[order.id] = order.copyWith(items: updated);
    notifyListeners();
    return ReceiptFormatter.formatKitchenTicket(order: order, newItems: unsent);
  }

  /// Return / Remake / Comp with mandatory reason & RBAC check
  bool recordReturnRemakeComp({
    required String lineId,
    required String type, // remake | return | comp
    required String reason,
    String? managerPin,
  }) {
    final order = activeOrder;
    if (order == null || reason.trim().isEmpty) return false;

    String? approver;
    if (canCurrent(PosPermission.voidOrComp)) {
      approver = _currentStaff!.name;
    } else if (managerPin != null) {
      final mgr = verifyManagerPin(managerPin);
      if (mgr == null) return false;
      approver = mgr.name;
    } else {
      return false;
    }

    final items = List<OrderItem>.from(order.items);
    final idx = items.indexWhere((l) => l.lineId == lineId);
    if (idx == -1) return false;
    final line = items[idx];

    if (type == 'return') {
      items.removeAt(idx);
    } else if (type == 'comp') {
      items[idx] = line.copyWith(isComp: true);
    }
    _openOrdersById[order.id] = order.copyWith(items: items);

    final rec = ReturnRemakeCompRecord(
      id: 'RRC-${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      orderTicket: order.ticketNumber,
      itemName: line.item.nameFr,
      quantity: line.quantity,
      amountMru: line.item.priceMru * line.quantity,
      reason: reason.trim(),
      staffName: _currentStaff?.name ?? 'Staff',
      approvedBy: approver,
      createdAt: DateTime.now(),
    );
    _remakeRecords.insert(0, rec);
    _enqueueSync(
      entityType: 'remake',
      summary: '${type.toUpperCase()} · ${line.item.nameFr} (${rec.reason})',
      payload: {
        'id': rec.id,
        'type': rec.type,
        'ticket': rec.orderTicket,
        'item': rec.itemName,
        'amount_mru': rec.amountMru,
        'reason': rec.reason,
        'approved_by': rec.approvedBy,
      },
    );
    notifyListeners();
    return true;
  }

  /// Split bill by selected line IDs -> creates a separate paid/open sub-order
  PosOrder? splitSelectedLines(Set<String> lineIds) {
    final order = activeOrder;
    if (order == null || lineIds.isEmpty) return null;
    final moved = order.items.where((l) => lineIds.contains(l.lineId)).toList();
    final remaining =
        order.items.where((l) => !lineIds.contains(l.lineId)).toList();
    if (moved.isEmpty || remaining.isEmpty) return null;

    _openOrdersById[order.id] = order.copyWith(items: remaining);
    final splitId = 'ORD-${++_ticketCounter}';
    final splitOrder = PosOrder(
      id: splitId,
      ticketNumber: 'FT-$_ticketCounter-S',
      tableId: order.tableId,
      tableCode: order.tableCode != null ? '${order.tableCode} (Part)' : null,
      staffName: _currentStaff?.name ?? order.staffName,
      items: moved,
      createdAt: DateTime.now(),
    );
    _openOrdersById[splitId] = splitOrder;
    _activeOrderId = splitId;
    notifyListeners();
    return splitOrder;
  }

  /// Complete checkout (single or mixed payments) -> updates Karni, frees table, queues Sync
  PosOrder? completeCheckout(List<PaymentEntry> payments) {
    final order = activeOrder;
    if (order == null || order.items.isEmpty) return null;
    final paidSum = payments.fold(0.0, (s, p) => s + p.amountMru);
    if (paidSum + 0.01 < order.netTotal) return null;

    // Update Karni balance if Karni payment is used
    for (final p in payments) {
      if (p.method == PaymentMethod.karni && p.karniCustomerId != null) {
        final cIdx =
            karniCustomers.indexWhere((c) => c.id == p.karniCustomerId);
        if (cIdx != -1) {
          final c = karniCustomers[cIdx];
          karniCustomers[cIdx] = c.copyWith(
            balanceDueMru: c.balanceDueMru + p.amountMru,
            lastActivity: DateTime.now(),
          );
        }
      }
    }

    final closed = order.copyWith(
      payments: payments,
      status: 'paid',
      paidAt: DateTime.now(),
    );

    _openOrdersById.remove(order.id);
    _completedOrders.insert(0, closed);

    // Free table only if this order was the table's primary activeOrderId
    if (order.tableId != null) {
      final tIdx = tables.indexWhere((t) => t.id == order.tableId);
      if (tIdx != -1 && tables[tIdx].activeOrderId == order.id) {
        tables[tIdx] = tables[tIdx].copyWith(
          status: TableStatus.free,
          guests: 0,
          clearOrder: true,
          clearOccupied: true,
        );
      }
    }

    _enqueueSync(
      entityType: 'order',
      summary:
          'Ticket ${closed.ticketNumber} · ${closed.netTotal.toStringAsFixed(0)} MRU',
      payload: closed.toSyncJson(),
    );

    // Start fresh counter order
    startCounterOrder();
    return closed;
  }

  // --- VIP Reservations & Arboun ---

  void addVipReservation({
    required String customerName,
    required String phone,
    required String tableId,
    required int guests,
    required String timeSlot,
    required double arbounMru,
    String? note,
  }) {
    final table = tables.firstWhere((t) => t.id == tableId);
    final res = VipReservation(
      id: 'RES-${DateTime.now().millisecondsSinceEpoch}',
      customerName: customerName.trim(),
      phone: phone.trim(),
      zoneId: table.zoneId,
      tableId: table.id,
      guests: guests,
      timeSlot: timeSlot.trim(),
      arbounMru: arbounMru,
      status: 'confirmed',
      note: note?.trim(),
    );
    reservations.insert(0, res);
    final tIdx = tables.indexWhere((t) => t.id == tableId);
    if (tIdx != -1 && tables[tIdx].status == TableStatus.free) {
      tables[tIdx] = tables[tIdx].copyWith(
        status: TableStatus.reserved,
        guests: guests,
      );
    }
    _enqueueSync(
      entityType: 'reservation',
      summary: 'VIP ${res.customerName} · Arboun ${arbounMru.toStringAsFixed(0)} MRU',
      payload: {
        'id': res.id,
        'customer': res.customerName,
        'table_id': res.tableId,
        'arboun_mru': res.arbounMru,
      },
    );
    notifyListeners();
  }

  PosOrder seatReservation(String reservationId) {
    final rIdx = reservations.indexWhere((r) => r.id == reservationId);
    if (rIdx == -1) return startCounterOrder();
    final res = reservations[rIdx];
    reservations[rIdx] = res.copyWith(status: 'seated');
    return openOrSelectTable(
      res.tableId,
      guests: res.guests,
      arbounMru: res.arbounMru,
    );
  }

  // --- Karni Credit ---

  void settleKarniBalance(String customerId, double amountMru) {
    if (amountMru <= 0) return;
    final idx = karniCustomers.indexWhere((c) => c.id == customerId);
    if (idx == -1) return;
    final c = karniCustomers[idx];
    final nextBal = (c.balanceDueMru - amountMru).clamp(0.0, double.infinity);
    karniCustomers[idx] = c.copyWith(
      balanceDueMru: nextBal,
      lastActivity: DateTime.now(),
    );
    _enqueueSync(
      entityType: 'karni',
      summary: 'Règlement Karni ${c.name} · -${amountMru.toStringAsFixed(0)} MRU',
      payload: {
        'customer_id': c.id,
        'customer_name': c.name,
        'paid_mru': amountMru,
        'remaining_balance_mru': nextBal,
      },
    );
    notifyListeners();
  }

  // --- Blind Z-Closing ---

  double _expectedForMethod(PaymentMethod method) {
    double sum = 0;
    for (final o in _completedOrders) {
      for (final p in o.payments) {
        if (p.method == method) {
          if (method == PaymentMethod.cash) {
            sum += (p.amountMru - o.changeDue).clamp(0.0, double.infinity);
          } else {
            sum += p.amountMru;
          }
        }
      }
    }
    return sum;
  }

  CashClosingZ submitBlindClosingZ({
    required double countedCashMru,
    required double countedBankilyMru,
    required double countedMasriviMru,
    required double countedSedadMru,
  }) {
    final z = CashClosingZ(
      id: 'Z-${DateTime.now().millisecondsSinceEpoch % 100000}',
      closedAt: DateTime.now(),
      cashierName: _currentStaff?.name ?? 'Caissier',
      countedCashMru: countedCashMru,
      expectedCashMru: _expectedForMethod(PaymentMethod.cash),
      countedBankilyMru: countedBankilyMru,
      expectedBankilyMru: _expectedForMethod(PaymentMethod.bankily),
      countedMasriviMru: countedMasriviMru,
      expectedMasriviMru: _expectedForMethod(PaymentMethod.masrivi),
      countedSedadMru: countedSedadMru,
      expectedSedadMru: _expectedForMethod(PaymentMethod.sedad),
      karniIssuedMru: _expectedForMethod(PaymentMethod.karni),
      ordersCount: _completedOrders.length,
      remakesCount: _remakeRecords.length,
    );
    _closingsZ.insert(0, z);
    _enqueueSync(
      entityType: 'closing_z',
      summary:
          'Clôture ${z.id} · Écart ${z.cashVarianceMru >= 0 ? '+' : ''}${z.cashVarianceMru.toStringAsFixed(0)} MRU',
      payload: z.toSyncJson(),
    );
    notifyListeners();
    return z;
  }

  // --- Offline SyncQueue ---

  void _enqueueSync({
    required String entityType,
    required String summary,
    required Map<String, dynamic> payload,
  }) {
    _syncQueue.insert(
      0,
      SyncQueueItem(
        id: 'SYNC-${_syncCounter++}',
        entityType: entityType,
        summary: summary,
        payload: payload,
        status: 'pending',
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<int> syncPendingToCloud() async {
    if (isSyncing) return 0;
    final pending = _syncQueue.where((q) => q.status == 'pending').toList();
    if (pending.isEmpty) {
      lastSyncMessage = 'Aucun élément en attente.';
      notifyListeners();
      return 0;
    }

    isSyncing = true;
    notifyListeners();
    int syncedCount = 0;

    try {
      final res = await httpBridgeRequest(
        'POST',
        '$apiBaseUrl/api/pos/sync',
        headers: {
          'Content-Type': 'application/json',
          if (cloudJwtToken != null) 'Authorization': 'Bearer $cloudJwtToken',
        },
        body: jsonEncode({
          'items': pending
              .map((q) => {
                    'id': q.id,
                    'entity_type': q.entityType,
                    'payload': q.payload,
                  })
              .toList(),
        }),
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final now = DateTime.now();
        for (int i = 0; i < _syncQueue.length; i++) {
          if (_syncQueue[i].status == 'pending') {
            _syncQueue[i] =
                _syncQueue[i].copyWith(status: 'synced', syncedAt: now);
            syncedCount++;
          }
        }
        lastSyncMessage =
            'Synchronisation Cloud réussie ($syncedCount éléments).';
      } else {
        lastSyncMessage =
            'API Cloud HTTP ${res.statusCode} — file conservée en local (Offline-First).';
      }
    } catch (_) {
      lastSyncMessage =
          'Mode hors-ligne détecté — ${pending.length} éléments sécurisés localement.';
    } finally {
      isSyncing = false;
      notifyListeners();
    }
    return syncedCount;
  }

  // --- Demo Seed Data (Mauritanie · Restaurant Oasis Tevragh-Zeina) ---

  void _seedMauritanianRestaurantData() {
    license = OfflineLicenseInfo(
      tenantName: 'Restaurant Oasis · Tevragh-Zeina',
      code12: '4829-1904-7731',
      expiresAt: DateTime.now().add(const Duration(days: 28)),
      ed25519Verified: true,
    );

    staff = const [
      StaffMember(
          id: 'ST-1', name: 'M. Taha (Owner)', role: PosRole.owner, pinCode: '0000'),
      StaffMember(
          id: 'ST-2', name: 'Aïcha (Caissière)', role: PosRole.cashier, pinCode: '1234'),
      StaffMember(
          id: 'ST-3', name: 'Sidi (Serveur)', role: PosRole.waiter, pinCode: '2222'),
      StaffMember(
          id: 'ST-4', name: 'Mariem (Manager)', role: PosRole.manager, pinCode: '9999'),
    ];

    categories = const [
      MenuCategory(
          id: 'grill',
          nameFr: 'Grillades & Plats',
          nameAr: 'مشويات وأطباق',
          nameEn: 'Grills & Mains',
          icon: '🔥'),
      MenuCategory(
          id: 'mauritanian',
          nameFr: 'Spécialités RIM',
          nameAr: 'أطباق موريتانية',
          nameEn: 'Mauritanian',
          icon: '🍲'),
      MenuCategory(
          id: 'starters',
          nameFr: 'Entrées & Salades',
          nameAr: 'مقبلات وسلطات',
          nameEn: 'Starters',
          icon: '🥗'),
      MenuCategory(
          id: 'drinks',
          nameFr: 'Boissons & Ataya',
          nameAr: 'مشروبات وأتاي',
          nameEn: 'Drinks & Tea',
          icon: '🍵'),
      MenuCategory(
          id: 'desserts',
          nameFr: 'Desserts',
          nameAr: 'حلويات',
          nameEn: 'Desserts',
          icon: '🍰'),
    ];

    menuItems = const [
      MenuItem(
          id: 'M1',
          categoryId: 'mauritanian',
          sku: 'RIM-001',
          nameFr: 'Thiéboudienne Royal',
          nameAr: 'تيبوجين ملكي',
          nameEn: 'Royal Thieboudienne',
          priceMru: 450,
          kitchenStation: 'KITCHEN'),
      MenuItem(
          id: 'M2',
          categoryId: 'mauritanian',
          sku: 'RIM-002',
          nameFr: 'Méchoui Agneau (1/2)',
          nameAr: 'مشوي خروف (نصف)',
          nameEn: 'Half Lamb Mechoui',
          priceMru: 1400,
          kitchenStation: 'GRILL'),
      MenuItem(
          id: 'M3',
          categoryId: 'mauritanian',
          sku: 'RIM-003',
          nameFr: 'Couscous Viande Chameau',
          nameAr: 'كسكس بلحم الإبل',
          nameEn: 'Camel Meat Couscous',
          priceMru: 550,
          kitchenStation: 'KITCHEN'),
      MenuItem(
          id: 'M4',
          categoryId: 'mauritanian',
          sku: 'RIM-004',
          nameFr: 'Marou Laham',
          nameAr: 'مارو واللحم',
          nameEn: 'Marou & Lamb',
          priceMru: 480,
          kitchenStation: 'KITCHEN'),
      MenuItem(
          id: 'M5',
          categoryId: 'grill',
          sku: 'GRL-001',
          nameFr: 'Mix Grill Oasis',
          nameAr: 'مشويات مشكلة الواحة',
          nameEn: 'Oasis Mix Grill',
          priceMru: 750,
          kitchenStation: 'GRILL'),
      MenuItem(
          id: 'M6',
          categoryId: 'grill',
          sku: 'GRL-002',
          nameFr: 'Chawarma Poulet Assiette',
          nameAr: 'صحن شاورما دجاج',
          nameEn: 'Chicken Shawarma Plate',
          priceMru: 350,
          kitchenStation: 'GRILL'),
      MenuItem(
          id: 'M7',
          categoryId: 'grill',
          sku: 'GRL-003',
          nameFr: 'Brochettes Filet Bœuf',
          nameAr: 'أسياخ لحم بقري',
          nameEn: 'Beef Skewers',
          priceMru: 500,
          kitchenStation: 'GRILL'),
      MenuItem(
          id: 'M8',
          categoryId: 'grill',
          sku: 'GRL-004',
          nameFr: 'Thiof Braisé Entier',
          nameAr: 'سمك تيوف مشوي',
          nameEn: 'Whole Grilled Thiof',
          priceMru: 850,
          kitchenStation: 'GRILL'),
      MenuItem(
          id: 'M9',
          categoryId: 'starters',
          sku: 'ENT-001',
          nameFr: 'Salade Fattouch',
          nameAr: 'سلطة فتوش',
          nameEn: 'Fattoush Salad',
          priceMru: 220,
          kitchenStation: 'KITCHEN'),
      MenuItem(
          id: 'M10',
          categoryId: 'starters',
          sku: 'ENT-002',
          nameFr: 'Houmous & Pain Chaud',
          nameAr: 'حمص مع خبز ساخن',
          nameEn: 'Hummus & Warm Bread',
          priceMru: 180,
          kitchenStation: 'KITCHEN'),
      MenuItem(
          id: 'M11',
          categoryId: 'starters',
          sku: 'ENT-003',
          nameFr: 'Pastilla Poulet',
          nameAr: 'بسطيلة دجاج',
          nameEn: 'Chicken Pastilla',
          priceMru: 300,
          kitchenStation: 'KITCHEN'),
      MenuItem(
          id: 'M12',
          categoryId: 'drinks',
          sku: 'DRK-001',
          nameFr: 'Thé Ataya (Service 3 verres)',
          nameAr: 'أتاي موريتاني (3 كؤوس)',
          nameEn: 'Mauritanian Ataya Service',
          priceMru: 150,
          kitchenStation: 'BAR'),
      MenuItem(
          id: 'M13',
          categoryId: 'drinks',
          sku: 'DRK-002',
          nameFr: 'Jus Bissap Frais',
          nameAr: 'عصير بيساب طازج',
          nameEn: 'Fresh Bissap Juice',
          priceMru: 120,
          kitchenStation: 'BAR'),
      MenuItem(
          id: 'M14',
          categoryId: 'drinks',
          sku: 'DRK-003',
          nameFr: 'Jus Bouye (Baobab)',
          nameAr: 'عصير بوي (باوباب)',
          nameEn: 'Baobab Bouye Juice',
          priceMru: 130,
          kitchenStation: 'BAR'),
      MenuItem(
          id: 'M15',
          categoryId: 'drinks',
          sku: 'DRK-004',
          nameFr: 'Zrig (Lait Caillé Frais)',
          nameAr: 'ازريك طازج',
          nameEn: 'Fresh Zrig',
          priceMru: 140,
          kitchenStation: 'BAR'),
      MenuItem(
          id: 'M16',
          categoryId: 'drinks',
          sku: 'DRK-005',
          nameFr: 'Eau Minérale 1.5L',
          nameAr: 'ماء معدني 1.5 لتر',
          nameEn: 'Mineral Water 1.5L',
          priceMru: 60,
          kitchenStation: 'BAR'),
      MenuItem(
          id: 'M17',
          categoryId: 'desserts',
          sku: 'DES-001',
          nameFr: 'Dattes Tidjikja & Crème',
          nameAr: 'تمور تجكجة بالقشطة',
          nameEn: 'Tidjikja Dates & Cream',
          priceMru: 200,
          kitchenStation: 'BAR'),
      MenuItem(
          id: 'M18',
          categoryId: 'desserts',
          sku: 'DES-002',
          nameFr: 'Tiramisu Maison',
          nameAr: 'تيراميسو منزلي',
          nameEn: 'Homemade Tiramisu',
          priceMru: 250,
          kitchenStation: 'BAR'),
    ];

    zones = const [
      DiningZone(
          id: 'main',
          nameFr: 'Salle Principale',
          nameAr: 'الصالة الرئيسية',
          nameEn: 'Main Hall'),
      DiningZone(
          id: 'terrace',
          nameFr: 'Terrasse Oasis',
          nameAr: 'شرفة الواحة',
          nameEn: 'Oasis Terrace'),
      DiningZone(
          id: 'khaima',
          nameFr: 'Salon Khaima VIP',
          nameAr: 'خيمة VIP',
          nameEn: 'Khaima VIP Lounge',
          isVip: true),
    ];

    tables = [
      const DiningTable(id: 'T1', zoneId: 'main', code: 'T-01', capacity: 4),
      const DiningTable(id: 'T2', zoneId: 'main', code: 'T-02', capacity: 4),
      const DiningTable(id: 'T3', zoneId: 'main', code: 'T-03', capacity: 6),
      const DiningTable(id: 'T4', zoneId: 'main', code: 'T-04', capacity: 2),
      const DiningTable(id: 'T5', zoneId: 'terrace', code: 'TER-1', capacity: 4),
      const DiningTable(id: 'T6', zoneId: 'terrace', code: 'TER-2', capacity: 6),
      const DiningTable(
          id: 'K1',
          zoneId: 'khaima',
          code: 'KHAIMA-1',
          capacity: 10,
          status: TableStatus.reserved,
          guests: 8),
      const DiningTable(
          id: 'K2', zoneId: 'khaima', code: 'KHAIMA-2', capacity: 12),
    ];

    reservations = [
      const VipReservation(
        id: 'RES-101',
        customerName: 'Famille Ould Ahmed',
        phone: '+222 36 12 44 90',
        zoneId: 'khaima',
        tableId: 'K1',
        guests: 8,
        timeSlot: '20:30',
        arbounMru: 2000,
        status: 'confirmed',
        note: 'Méchoui préparé à l’avance + Ataya',
      ),
      const VipReservation(
        id: 'RES-102',
        customerName: 'Cabinet Chinguetti Conseil',
        phone: '+222 44 80 15 22',
        zoneId: 'khaima',
        tableId: 'K2',
        guests: 10,
        timeSlot: '21:15',
        arbounMru: 3000,
        status: 'confirmed',
        note: 'Déjeuner d’affaires VIP',
      ),
    ];

    karniCustomers = [
      KarniCustomer(
        id: 'KAR-1',
        name: 'Mohamed Salem Ould Cheikh',
        phone: '+222 36 44 10 20',
        creditLimitMru: 15000,
        balanceDueMru: 3200,
        lastActivity: DateTime.now().subtract(const Duration(days: 2)),
      ),
      KarniCustomer(
        id: 'KAR-2',
        name: 'Société MauriTech SARL',
        phone: '+222 45 29 77 11',
        creditLimitMru: 50000,
        balanceDueMru: 12450,
        lastActivity: DateTime.now().subtract(const Duration(days: 1)),
      ),
      KarniCustomer(
        id: 'KAR-3',
        name: 'Aminetou Mint Sidi',
        phone: '+222 22 91 33 05',
        creditLimitMru: 10000,
        balanceDueMru: 850,
        lastActivity: DateTime.now().subtract(const Duration(hours: 6)),
      ),
    ];
  }
}
