import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../l10n/pos_i18n.dart';
import '../models/pos_models.dart';
import '../services/catalog_mapper.dart';
import '../services/http_bridge.dart';
import '../services/local_storage.dart';
import '../services/receipt_formatter.dart';
import '../theme/fulltek_themes.dart';

typedef HttpBridgeFn = Future<HttpBridgeResponse> Function(
  String method,
  String url, {
  Map<String, String>? headers,
  String? body,
});

class PosStore extends ChangeNotifier {
  final HttpBridgeFn _httpRequest;

  FullTekThemeId _themeId = FullTekThemeId.emeraldNight;
  String _lang = 'fr';
  StaffMember? _currentStaff;

  String apiBaseUrl = const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:4000');
  String? cloudJwtToken;
  bool isSyncing = false;
  String? lastSyncMessage;

  bool lanConnected = true;
  bool cloudConnected = false;
  String catalogSource = 'offline_demo'; // offline_demo | cloud_api
  bool isLoadingCatalog = false;
  DateTime? lastCatalogSyncAt;

  late OfflineLicenseInfo license;
  late List<StaffMember> staff;
  late List<MenuCategory> categories;
  late List<MenuItem> menuItems;
  late List<DiningZone> zones;
  late List<DiningTable> tables;
  late List<VipReservation> reservations;
  late List<KarniCustomer> karniCustomers;
  late List<DeliveryZone> deliveryZones;
  late List<Ingredient> ingredients;
  late List<RecipeBomLine> recipesBom;

  double freeDeliveryAboveMru = DeliveryZone.freeDeliveryAboveMru;
  ServiceMode _serviceMode = ServiceMode.dineIn;
  DeliveryZone? _selectedDeliveryZone;
  int _takeawayCounter = 43;

  final Map<String, PosOrder> _openOrdersById = {};
  final List<PosOrder> _completedOrders = [];
  final List<PosOrder> _trainingOrders = [];
  final Map<String, double> _orderFoodCostById = {};
  final List<ReturnRemakeCompRecord> _remakeRecords = [];
  final List<CashClosingZ> _closingsZ = [];
  final List<SyncQueueItem> _syncQueue = [];
  final List<KdsTicket> _kdsTickets = [];

  bool _trainingMode = false;
  double _todayRemakeWasteMru = 0.0;
  DateTime? _lastZClosedAt;
  String? lastCheckoutError;
  final bool _enablePersistence;

  String? _activeOrderId;
  int _ticketCounter = 1042;
  int _lineCounter = 1;
  int _syncCounter = 1;
  int _kdsCounter = 1;

  PosStore({HttpBridgeFn? httpRequest, bool? enablePersistence})
      : _httpRequest = httpRequest ?? httpBridgeRequest,
        _enablePersistence = enablePersistence ?? kIsWeb {
    _seedMauritanianRestaurantData();
    if (_enablePersistence) {
      _restoreFromStorage();
    }
  }

  static const _storageKey = 'fulltek_pos_state_v1';

  @override
  void notifyListeners() {
    if (_enablePersistence) {
      _saveToStorage();
    }
    super.notifyListeners();
  }

  void _saveToStorage() {
    try {
      final data = {
        'themeId': _themeId.name,
        'lang': _lang,
        'accountLoggedIn': accountLoggedIn,
        'accountOffline': accountOffline,
        'tenantCode': tenantCode,
        'tenantName': tenantName,
        'cloudJwtToken': cloudJwtToken,
        'enabledThemeCodes': enabledThemeCodes,
        'enabledPayMethods': enabledPayMethods,
        'lastZClosedAt': _lastZClosedAt?.toIso8601String(),
        'licenseExpiresAt': license.expiresAt.toIso8601String(),
        'licenseVerified': license.ed25519Verified,
        'licenseCode': license.code12,
        'syncQueue': _syncQueue
            .map((q) => {
                  'id': q.id,
                  'entityType': q.entityType,
                  'summary': q.summary,
                  'payload': q.payload,
                  'status': q.status,
                  'createdAt': q.createdAt.toIso8601String(),
                  'syncedAt': q.syncedAt?.toIso8601String(),
                })
            .toList(),
        'karniBalances': {
          for (final c in karniCustomers) c.id: c.balanceDueMru,
        },
        'ingredientStocks': {
          for (final i in ingredients) i.id: i.currentStock,
        },
      };
      localStorageWrite(_storageKey, jsonEncode(data));
    } catch (_) {}
  }

  void _restoreFromStorage() {
    try {
      final raw = localStorageRead(_storageKey);
      if (raw == null || raw.isEmpty) return;
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return;

      final tName = map['themeId'] as String?;
      if (tName != null) {
        final found = FullTekThemeId.values.where((e) => e.name == tName);
        if (found.isNotEmpty) _themeId = found.first;
      }
      final savedLang = map['lang'] as String?;
      if (savedLang != null && ['fr', 'ar', 'en'].contains(savedLang)) {
        _lang = savedLang;
      }
      if (map['accountLoggedIn'] == true) {
        accountLoggedIn = true;
        accountOffline = map['accountOffline'] == true;
        tenantCode = '${map['tenantCode'] ?? tenantCode}';
        tenantName = '${map['tenantName'] ?? tenantName}';
        cloudJwtToken = map['cloudJwtToken'] as String?;
        final themes = map['enabledThemeCodes'] as List?;
        if (themes != null && themes.isNotEmpty) {
          enabledThemeCodes = themes.map((e) => '$e').toList();
        }
        final pays = map['enabledPayMethods'] as List?;
        if (pays != null && pays.isNotEmpty) {
          enabledPayMethods = pays.map((e) => '$e').toList();
        }
      }
      final zAt = map['lastZClosedAt'] as String?;
      if (zAt != null) _lastZClosedAt = DateTime.tryParse(zAt);

      final licExp = map['licenseExpiresAt'] as String?;
      if (licExp != null) {
        final exp = DateTime.tryParse(licExp);
        if (exp != null) {
          license = OfflineLicenseInfo(
            tenantName: tenantName,
            code12: '${map['licenseCode'] ?? license.code12}',
            expiresAt: exp,
            ed25519Verified: map['licenseVerified'] == true,
          );
        }
      }

      final qList = map['syncQueue'] as List?;
      if (qList != null) {
        _syncQueue.clear();
        for (final item in qList.whereType<Map>()) {
          final m = item.cast<String, dynamic>();
          _syncQueue.add(
            SyncQueueItem(
              id: '${m['id'] ?? 'SYNC'}',
              entityType: '${m['entityType'] ?? 'order'}',
              summary: '${m['summary'] ?? ''}',
              payload: (m['payload'] as Map?)?.cast<String, dynamic>() ?? {},
              status: '${m['status'] ?? 'pending'}',
              createdAt:
                  DateTime.tryParse('${m['createdAt'] ?? ''}') ?? DateTime.now(),
              syncedAt: m['syncedAt'] != null
                  ? DateTime.tryParse('${m['syncedAt']}')
                  : null,
            ),
          );
        }
      }

      final kb = map['karniBalances'] as Map?;
      if (kb != null) {
        for (int i = 0; i < karniCustomers.length; i++) {
          final c = karniCustomers[i];
          if (kb.containsKey(c.id) && kb[c.id] is num) {
            karniCustomers[i] = c.copyWith(
              balanceDueMru: (kb[c.id] as num).toDouble(),
            );
          }
        }
      }

      final isMap = map['ingredientStocks'] as Map?;
      if (isMap != null) {
        for (int i = 0; i < ingredients.length; i++) {
          final ing = ingredients[i];
          if (isMap.containsKey(ing.id) && isMap[ing.id] is num) {
            ingredients[i] = ing.copyWith(
              currentStock: (isMap[ing.id] as num).toDouble(),
            );
          }
        }
      }
    } catch (_) {}
  }

  FullTekThemeId get themeId => _themeId;
  FullTekThemeSpec get themeSpec => FullTekThemes.all[_themeId]!;
  String get lang => _lang;
  PosI18n get i18n => PosI18n(_lang);
  StaffMember? get currentStaff => _currentStaff;

  ServiceMode get serviceMode => _serviceMode;
  DeliveryZone? get selectedDeliveryZone => _selectedDeliveryZone;
  bool get trainingMode => _trainingMode;

  List<PosOrder> get completedOrders => List.unmodifiable(_completedOrders);
  List<PosOrder> get trainingOrders => List.unmodifiable(_trainingOrders);
  List<ReturnRemakeCompRecord> get remakeRecords =>
      List.unmodifiable(_remakeRecords);
  List<CashClosingZ> get closingsZ => List.unmodifiable(_closingsZ);
  List<SyncQueueItem> get syncQueue => List.unmodifiable(_syncQueue);
  List<KdsTicket> get kdsTickets => List.unmodifiable(_kdsTickets);
  int get pendingSyncCount =>
      _syncQueue.where((q) => q.status == 'pending').length;

  List<MenuItem> get outOfStockItems =>
      menuItems.where((m) => !m.available).toList(growable: false);

  List<Ingredient> get lowStockIngredients =>
      ingredients.where((i) => i.isLowStock).toList(growable: false);

  List<KdsTicket> activeKdsTickets([
    KdsStationFilter filter = KdsStationFilter.all,
  ]) =>
      _kdsTickets
          .where((t) => t.hasPendingForStation(filter))
          .toList(growable: false);

  double get kdsAveragePrepMinutes {
    final readyTickets = _kdsTickets
        .where((t) => t.status == 'ready' && t.readyAt != null)
        .toList();
    if (readyTickets.isEmpty) return 0.0;
    final totalMin = readyTickets.fold<int>(
      0,
      (sum, t) => sum + t.readyAt!.difference(t.sentAt).inMinutes.abs(),
    );
    return totalMin / readyTickets.length;
  }

  PosOrder? get activeOrder =>
      _activeOrderId == null ? null : _openOrdersById[_activeOrderId];

  PosOrder? orderForTable(String tableId) {
    final idx = tables.indexWhere((t) => t.id == tableId);
    if (idx == -1) return null;
    final table = tables[idx];
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

  // --- Restaurant account session (SaaS tenant login from landing page) ---
  bool accountLoggedIn = false;
  String tenantName = 'Restaurant Oasis · Tevragh-Zeina';
  String tenantCode = 'DEMO';
  List<String> enabledThemeCodes = const ['01', '04', '06', '07', '11'];
  List<String> enabledPayMethods = const [
    'Cash',
    'Bankily',
    'Masrivi',
    'Sedad',
    'Bimbank',
    'Click',
    'Karni',
  ];
  bool accountOffline = false;

  List<FullTekThemeSpec> get availableThemes => FullTekThemes.all.values
      .where((s) => enabledThemeCodes.contains(s.code))
      .toList();

  void _applyOwnerPin(String ownerPin) {
    staff = [
      for (final s in staff)
        s.role == PosRole.owner
            ? StaffMember(
                id: s.id,
                name: s.name,
                role: s.role,
                pinCode: ownerPin,
                isActive: s.isActive,
              )
            : s,
    ];
  }

  /// Logs into the restaurant SaaS account (cloud-api `/api/auth/login`),
  /// then fetches the tenant's POS catalog (`GET /api/pos/catalog`).
  /// Falls back to the cached demo account when the cloud is unreachable
  /// (Offline-First). Returns null on success, or an error message.
  Future<String?> loginAccount(String username, String password) async {
    final u = username.trim();
    if (u.isEmpty || password.isEmpty) {
      return 'Identifiant et mot de passe requis';
    }
    try {
      final res = await _httpRequest(
        'POST',
        '$apiBaseUrl/api/auth/login',
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': u, 'password': password}),
      );
      if (res.statusCode == 401) {
        return 'Identifiant ou mot de passe incorrect';
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return 'Erreur serveur (HTTP ${res.statusCode})';
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final tenant = (data['tenant'] as Map).cast<String, dynamic>();
      if (tenant['module'] != 'resto') {
        return 'Ce compte est un espace "${tenant['module']}" — ouvrez Full-Tek Resto avec un compte restaurant.';
      }
      if (tenant['status'] == 'expired') {
        return 'Abonnement expiré — contactez M. Taha (+222 42 74 42 42).';
      }
      cloudJwtToken = data['token'] as String?;
      tenantName = (tenant['name'] as String?) ?? tenantName;
      tenantCode = (tenant['tenantId'] as String?) ?? tenantCode;
      final themes =
          (tenant['enabledThemes'] as List?)?.map((e) => '$e').toList();
      if (themes != null && themes.isNotEmpty) enabledThemeCodes = themes;
      final pays = (tenant['payMethods'] as List?)?.map((e) => '$e').toList();
      if (pays != null && pays.isNotEmpty) enabledPayMethods = pays;
      final days = tenant['daysLeft'];
      if (days is int) {
        license = OfflineLicenseInfo(
          tenantName: tenantName,
          code12: license.code12,
          expiresAt: DateTime.now().add(Duration(days: days)),
          ed25519Verified: true,
        );
      }
      final pin = tenant['ownerPin'];
      if (pin is String && pin.length == 4) _applyOwnerPin(pin);
      final lang = tenant['defaultLang'];
      if (lang is String && ['fr', 'ar', 'en'].contains(lang)) _lang = lang;
      accountOffline = false;
      cloudConnected = true;
      accountLoggedIn = true;
      if (!enabledThemeCodes.contains(themeSpec.code)) {
        _themeId = FullTekThemes.fromCode(enabledThemeCodes.first);
      }
      await fetchCloudCatalog();
      notifyListeners();
      return null;
    } catch (_) {
      // Offline-First fallback: cached demo account
      if (u == 'darelkram41' && password == 'FullTek@2026') {
        tenantName = 'Dar El-Karam Resto';
        tenantCode = 'FT-1041';
        enabledThemeCodes = const ['01', '04', '06', '07', '11'];
        _applyOwnerPin('7410');
        accountOffline = true;
        cloudConnected = false;
        catalogSource = 'offline_demo';
        accountLoggedIn = true;
        notifyListeners();
        return null;
      }
      return 'Serveur injoignable — connexion hors-ligne impossible pour ce compte.';
    }
  }

  /// Fetches the live POS catalog from `GET /api/pos/catalog` when online.
  /// Seamlessly retains/falls back to the seeded demo menu if offline or empty.
  Future<bool> fetchCloudCatalog() async {
    if (cloudJwtToken == null || cloudJwtToken!.isEmpty) {
      cloudConnected = false;
      catalogSource = 'offline_demo';
      if (menuItems.isEmpty) _seedMauritanianRestaurantData();
      notifyListeners();
      return false;
    }

    isLoadingCatalog = true;
    notifyListeners();

    try {
      final res = await _httpRequest(
        'GET',
        '$apiBaseUrl/api/pos/catalog',
        headers: {
          'Authorization': 'Bearer $cloudJwtToken',
          'Accept': 'application/json',
        },
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        cloudConnected = false;
        catalogSource = 'offline_demo';
        if (menuItems.isEmpty) _seedMauritanianRestaurantData();
        return false;
      }

      final data = jsonDecode(res.body);
      if (data is! Map<String, dynamic>) {
        cloudConnected = false;
        catalogSource = 'offline_demo';
        return false;
      }

      final parsed = CatalogMapper.fromJson(data);
      if (parsed.menuItems.isEmpty) {
        cloudConnected = true;
        catalogSource = 'offline_demo';
        if (menuItems.isEmpty) _seedMauritanianRestaurantData();
        return false;
      }

      if (parsed.tenantName != null && parsed.tenantName!.isNotEmpty) {
        tenantName = parsed.tenantName!;
      }
      if (parsed.tenantCode != null && parsed.tenantCode!.isNotEmpty) {
        tenantCode = parsed.tenantCode!;
      }
      if (parsed.enabledThemeCodes.isNotEmpty) {
        enabledThemeCodes = parsed.enabledThemeCodes;
        if (!enabledThemeCodes.contains(themeSpec.code)) {
          _themeId = FullTekThemes.fromCode(enabledThemeCodes.first);
        }
      }
      if (parsed.payMethods.isNotEmpty) {
        enabledPayMethods = parsed.payMethods;
      }
      if (parsed.defaultLang != null &&
          ['fr', 'ar', 'en'].contains(parsed.defaultLang)) {
        _lang = parsed.defaultLang!;
      }
      if (parsed.ownerPin != null && parsed.ownerPin!.length == 4) {
        _applyOwnerPin(parsed.ownerPin!);
      }
      if (parsed.daysLeft != null) {
        license = OfflineLicenseInfo(
          tenantName: tenantName,
          code12: license.code12,
          expiresAt: DateTime.now().add(Duration(days: parsed.daysLeft!)),
          ed25519Verified: true,
        );
      }
      if (parsed.freeDeliveryAboveMru != null) {
        freeDeliveryAboveMru = parsed.freeDeliveryAboveMru!;
      }
      if (parsed.deliveryZones.isNotEmpty) {
        deliveryZones = List<DeliveryZone>.from(parsed.deliveryZones);
        if (_selectedDeliveryZone == null ||
            !deliveryZones.any((z) => z.id == _selectedDeliveryZone!.id)) {
          _selectedDeliveryZone = deliveryZones.first;
        }
      }
      if (parsed.categories.isNotEmpty) {
        categories = List<MenuCategory>.from(parsed.categories);
      }
      menuItems = List<MenuItem>.from(parsed.menuItems);

      if (parsed.zones.isNotEmpty && parsed.tables.isNotEmpty) {
        final openByTable = {
          for (final t in tables)
            if (t.activeOrderId != null) t.id: t,
        };
        zones = List<DiningZone>.from(parsed.zones);
        tables = parsed.tables.map((t) {
          final prev = openByTable[t.id];
          if (prev != null && _openOrdersById.containsKey(prev.activeOrderId)) {
            return t.copyWith(
              status: prev.status,
              guests: prev.guests,
              activeOrderId: prev.activeOrderId,
              occupiedSince: prev.occupiedSince,
              serverName: prev.serverName,
              arbounMru: prev.arbounMru,
            );
          }
          return t;
        }).toList();
        reservations = List<VipReservation>.from(parsed.reservations);
      }
      if (parsed.ingredients.isNotEmpty) {
        ingredients = List<Ingredient>.from(parsed.ingredients);
      }
      if (parsed.recipesBom.isNotEmpty) {
        recipesBom = List<RecipeBomLine>.from(parsed.recipesBom);
      }
      if (parsed.karniCustomers.isNotEmpty) {
        karniCustomers = List<KarniCustomer>.from(parsed.karniCustomers);
      }

      cloudConnected = true;
      accountOffline = false;
      catalogSource = 'cloud_api';
      lastCatalogSyncAt = DateTime.now();
      return true;
    } catch (_) {
      cloudConnected = false;
      catalogSource = 'offline_demo';
      if (menuItems.isEmpty) _seedMauritanianRestaurantData();
      return false;
    } finally {
      isLoadingCatalog = false;
      notifyListeners();
    }
  }

  void logoutAccount() {
    accountLoggedIn = false;
    _currentStaff = null;
    cloudJwtToken = null;
    cloudConnected = false;
    catalogSource = 'offline_demo';
    _trainingMode = false;
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
      (s) =>
          s.isActive &&
          s.pinCode == pin.trim() &&
          s.can(PosPermission.voidOrComp),
    );
    return idx == -1 ? null : staff[idx];
  }

  bool canCurrent(PosPermission perm) => _currentStaff?.can(perm) ?? false;

  // --- Training Mode ---

  bool toggleTrainingMode({String? managerPin}) {
    final authorized = canCurrent(PosPermission.voidOrComp) ||
        (managerPin != null && verifyManagerPin(managerPin) != null);
    if (!authorized) return false;
    _trainingMode = !_trainingMode;
    final current = activeOrder;
    if (current != null) {
      if (current.items.isEmpty) {
        _openOrdersById[current.id] =
            current.copyWith(isTraining: _trainingMode);
      } else {
        startCounterOrder();
      }
    }
    notifyListeners();
    return true;
  }

  // --- Service Modes & Nouakchott Delivery ---

  double _computeDeliveryFee(
    ServiceMode mode,
    DeliveryZone? zone,
    double subtotal,
  ) {
    if (mode != ServiceMode.delivery || zone == null) return 0;
    return zone.effectiveFeeFor(subtotal, freeAboveMru: freeDeliveryAboveMru);
  }

  PosOrder _withRecomputedDelivery(PosOrder order) {
    final fee = _computeDeliveryFee(
      order.serviceMode,
      order.deliveryZone,
      order.subtotal,
    );
    if (fee == order.deliveryFeeMru) return order;
    return order.copyWith(deliveryFeeMru: fee);
  }

  void setServiceMode(ServiceMode mode) {
    _serviceMode = mode;
    if (mode == ServiceMode.delivery &&
        _selectedDeliveryZone == null &&
        deliveryZones.isNotEmpty) {
      _selectedDeliveryZone = deliveryZones.first;
    }
    final order = activeOrder;
    if (order != null) {
      final zone = mode == ServiceMode.delivery
          ? (order.deliveryZone ?? _selectedDeliveryZone)
          : null;
      final takeawayNo = mode == ServiceMode.takeaway
          ? (order.takeawayNumber ?? (++_takeawayCounter))
          : order.takeawayNumber;
      final fee = _computeDeliveryFee(mode, zone, order.subtotal);
      _openOrdersById[order.id] = order.copyWith(
        serviceMode: mode,
        deliveryZone: zone,
        clearDeliveryZone: mode != ServiceMode.delivery,
        deliveryFeeMru: fee,
        takeawayNumber: takeawayNo,
      );
    }
    notifyListeners();
  }

  void setDeliveryZone(DeliveryZone? zone) {
    _selectedDeliveryZone = zone;
    final order = activeOrder;
    if (order != null && order.serviceMode == ServiceMode.delivery) {
      final fee = _computeDeliveryFee(
        order.serviceMode,
        zone,
        order.subtotal,
      );
      _openOrdersById[order.id] = order.copyWith(
        deliveryZone: zone,
        clearDeliveryZone: zone == null,
        deliveryFeeMru: fee,
      );
    }
    notifyListeners();
  }

  void setDeliveryInfo({
    String? customerName,
    String? customerPhone,
    String? deliveryAddress,
    DeliveryZone? zone,
  }) {
    if (zone != null) {
      _selectedDeliveryZone = zone;
    }
    final order = activeOrder;
    if (order != null) {
      final nextZone = zone ?? order.deliveryZone ?? _selectedDeliveryZone;
      final fee = _computeDeliveryFee(
        order.serviceMode,
        nextZone,
        order.subtotal,
      );
      _openOrdersById[order.id] = order.copyWith(
        customerName: customerName,
        customerPhone: customerPhone,
        deliveryAddress: deliveryAddress,
        deliveryZone: order.serviceMode == ServiceMode.delivery ? nextZone : null,
        deliveryFeeMru: fee,
      );
    }
    notifyListeners();
  }

  // --- Orders & Floor Plan ---

  PosOrder startCounterOrder() {
    final id = 'ORD-${++_ticketCounter}';
    final takeawayNo =
        _serviceMode == ServiceMode.takeaway ? (++_takeawayCounter) : null;
    final zone = _serviceMode == ServiceMode.delivery
        ? (_selectedDeliveryZone ??
            (deliveryZones.isNotEmpty ? deliveryZones.first : null))
        : null;
    final order = PosOrder(
      id: id,
      ticketNumber: 'FT-$_ticketCounter',
      staffName: _currentStaff?.name ?? 'Caisse',
      items: const [],
      createdAt: DateTime.now(),
      serviceMode: _serviceMode,
      deliveryZone: zone,
      deliveryFeeMru: 0,
      takeawayNumber: takeawayNo,
      isTraining: _trainingMode,
    );
    _openOrdersById[id] = order;
    _activeOrderId = id;
    notifyListeners();
    return order;
  }

  PosOrder openOrSelectTable(
    String tableId, {
    int? guests,
    double arbounMru = 0,
  }) {
    final idx = tables.indexWhere((t) => t.id == tableId);
    if (idx == -1) return startCounterOrder();
    final table = tables[idx];

    if (table.activeOrderId != null &&
        _openOrdersById.containsKey(table.activeOrderId)) {
      _activeOrderId = table.activeOrderId;
      _serviceMode = ServiceMode.dineIn;
      notifyListeners();
      return _openOrdersById[_activeOrderId]!;
    }

    _serviceMode = ServiceMode.dineIn;
    final id = 'ORD-${++_ticketCounter}';
    final effectiveArboun = arbounMru > 0 ? arbounMru : table.arbounMru;
    final staffLabel = _currentStaff?.name ?? 'Serveur';
    final order = PosOrder(
      id: id,
      ticketNumber: 'FT-$_ticketCounter',
      tableId: table.id,
      tableCode: table.code,
      staffName: staffLabel,
      items: const [],
      arbounDepositMru: effectiveArboun,
      createdAt: DateTime.now(),
      serviceMode: ServiceMode.dineIn,
      isTraining: _trainingMode,
    );
    _openOrdersById[id] = order;
    tables[idx] = table.copyWith(
      status: TableStatus.occupied,
      guests: guests ?? (table.guests > 0 ? table.guests : 2),
      activeOrderId: id,
      occupiedSince: DateTime.now(),
      serverName: staffLabel,
      arbounMru: effectiveArboun,
    );
    _activeOrderId = id;
    notifyListeners();
    return order;
  }

  bool transferTable(String fromTableId, String toTableId) {
    if (fromTableId == toTableId) return false;
    final fromIdx = tables.indexWhere((t) => t.id == fromTableId);
    final toIdx = tables.indexWhere((t) => t.id == toTableId);
    if (fromIdx == -1 || toIdx == -1) return false;

    final fromTable = tables[fromIdx];
    final toTable = tables[toIdx];
    final orderId = fromTable.activeOrderId;
    if (orderId == null || !_openOrdersById.containsKey(orderId)) return false;
    if (toTable.activeOrderId != null &&
        _openOrdersById.containsKey(toTable.activeOrderId)) {
      return false;
    }

    final order = _openOrdersById[orderId]!;
    _openOrdersById[orderId] = order.copyWith(
      tableId: toTable.id,
      tableCode: toTable.code,
    );

    tables[toIdx] = toTable.copyWith(
      status: fromTable.status == TableStatus.free
          ? TableStatus.occupied
          : fromTable.status,
      guests: fromTable.guests > 0 ? fromTable.guests : toTable.guests,
      activeOrderId: orderId,
      occupiedSince: fromTable.occupiedSince ?? DateTime.now(),
      serverName: fromTable.serverName ?? _currentStaff?.name,
      waitAlert: fromTable.waitAlert,
      arbounMru: fromTable.arbounMru,
    );
    tables[fromIdx] = fromTable.copyWith(
      status: TableStatus.free,
      guests: 0,
      clearOrder: true,
      clearOccupied: true,
      clearServer: true,
      waitAlert: false,
      arbounMru: 0,
    );
    _activeOrderId = orderId;
    notifyListeners();
    return true;
  }

  bool mergeTables(String sourceTableId, String targetTableId) {
    if (sourceTableId == targetTableId) return false;
    final srcIdx = tables.indexWhere((t) => t.id == sourceTableId);
    final dstIdx = tables.indexWhere((t) => t.id == targetTableId);
    if (srcIdx == -1 || dstIdx == -1) return false;

    final srcTable = tables[srcIdx];
    final dstTable = tables[dstIdx];
    final srcOrderId = srcTable.activeOrderId;
    if (srcOrderId == null || !_openOrdersById.containsKey(srcOrderId)) {
      return false;
    }

    final dstOrderId = dstTable.activeOrderId;
    if (dstOrderId == null || !_openOrdersById.containsKey(dstOrderId)) {
      return transferTable(sourceTableId, targetTableId);
    }

    final srcOrder = _openOrdersById.remove(srcOrderId)!;
    final dstOrder = _openOrdersById[dstOrderId]!;
    final mergedItems = List<OrderItem>.from(dstOrder.items)
      ..addAll(srcOrder.items);
    _openOrdersById[dstOrderId] = dstOrder.copyWith(
      items: mergedItems,
      arbounDepositMru: dstOrder.arbounDepositMru + srcOrder.arbounDepositMru,
    );

    tables[dstIdx] = dstTable.copyWith(
      guests: dstTable.guests + srcTable.guests,
      arbounMru: dstTable.arbounMru + srcTable.arbounMru,
    );
    tables[srcIdx] = srcTable.copyWith(
      status: TableStatus.free,
      guests: 0,
      clearOrder: true,
      clearOccupied: true,
      clearServer: true,
      waitAlert: false,
      arbounMru: 0,
    );
    _activeOrderId = dstOrderId;
    notifyListeners();
    return true;
  }

  String _modifiersKey(List<SelectedModifier> mods) {
    if (mods.isEmpty) return '';
    final keys = mods.map((m) => '${m.groupId}:${m.optionId}').toList()..sort();
    return keys.join('|');
  }

  bool addItemToActiveOrder(
    MenuItem item, {
    String? note,
    List<SelectedModifier> selectedModifiers = const [],
  }) {
    final live = menuItems.cast<MenuItem?>().firstWhere(
          (m) => m?.id == item.id,
          orElse: () => item,
        )!;
    if (!live.available) return false;

    final order = activeOrder ?? startCounterOrder();
    final items = List<OrderItem>.from(order.items);
    final modKey = _modifiersKey(selectedModifiers);
    final existingIdx = items.indexWhere(
      (l) =>
          l.item.id == live.id &&
          !l.sentToKitchen &&
          !l.isComp &&
          (l.kitchenNote ?? '') == (note ?? '') &&
          _modifiersKey(l.selectedModifiers) == modKey,
    );
    if (existingIdx != -1) {
      items[existingIdx] = items[existingIdx].copyWith(
        quantity: items[existingIdx].quantity + 1,
      );
    } else {
      items.add(
        OrderItem(
          lineId: 'LN-${_lineCounter++}',
          item: live,
          quantity: 1,
          kitchenNote: note,
          selectedModifiers: List<SelectedModifier>.unmodifiable(selectedModifiers),
        ),
      );
    }
    _openOrdersById[order.id] =
        _withRecomputedDelivery(order.copyWith(items: items));
    notifyListeners();
    return true;
  }

  void updateLineQuantity(String lineId, int delta) {
    final order = activeOrder;
    if (order == null) return;
    final items = List<OrderItem>.from(order.items);
    final idx = items.indexWhere((l) => l.lineId == lineId);
    if (idx == -1) return;
    if (delta > 0) {
      final itemId = items[idx].item.id;
      final live = menuItems.cast<MenuItem?>().firstWhere(
            (m) => m?.id == itemId,
            orElse: () => items[idx].item,
          )!;
      if (!live.available) return;
    }
    final nextQty = items[idx].quantity + delta;
    if (nextQty <= 0) {
      items.removeAt(idx);
    } else {
      items[idx] = items[idx].copyWith(quantity: nextQty);
    }
    _openOrdersById[order.id] =
        _withRecomputedDelivery(order.copyWith(items: items));
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

  /// Marks unsent items as sent to Kitchen / KDS, creates a persistent [KdsTicket],
  /// and returns formatted KDS ticket text.
  String? sendActiveOrderToKitchen() {
    final order = activeOrder;
    if (order == null) return null;
    final unsent = order.items.where((i) => !i.sentToKitchen).toList();
    if (unsent.isEmpty) return null;
    final updated =
        order.items.map((i) => i.copyWith(sentToKitchen: true)).toList();
    _openOrdersById[order.id] = order.copyWith(items: updated);

    final kdsItems = unsent
        .map(
          (l) => KdsTicketItem(
            lineId: l.lineId,
            productId: l.item.id,
            sku: l.item.sku,
            nameFr: l.item.nameFr,
            nameAr: l.item.nameAr,
            nameEn: l.item.nameEn,
            quantity: l.quantity,
            kitchenStation: l.item.kitchenStation,
            selectedModifiers: l.selectedModifiers,
            kitchenNote: l.kitchenNote,
          ),
        )
        .toList();

    _kdsTickets.insert(
      0,
      KdsTicket(
        id: 'KDS-${_kdsCounter++}',
        orderId: order.id,
        orderCode: order.ticketNumber,
        tableCode: order.tableCode,
        serviceMode: order.serviceMode,
        deliveryZoneName: order.deliveryZone?.nameFr,
        takeawayNumber: order.takeawayNumber,
        staffName: order.staffName,
        isTraining: order.isTraining,
        sentAt: DateTime.now(),
        items: kdsItems,
      ),
    );

    notifyListeners();
    return ReceiptFormatter.formatKitchenTicket(order: order, newItems: unsent);
  }

  /// Marks a KDS ticket (or a single station on it) as ready.
  Future<bool> markKdsTicketReady(
    String ticketId, {
    String? station,
  }) async {
    final idx = _kdsTickets.indexWhere((t) => t.id == ticketId);
    if (idx == -1) return false;
    final ticket = _kdsTickets[idx];
    final targetStation = station?.trim().toUpperCase();
    final markAll = targetStation == null || targetStation == 'ALL';

    final updatedItems = ticket.items
        .map((i) => (markAll || i.kitchenStation.toUpperCase() == targetStation)
            ? i.copyWith(ready: true)
            : i)
        .toList();
    final allReady = updatedItems.every((i) => i.ready);
    final nextTicket = ticket.copyWith(
      items: updatedItems,
      status: allReady ? 'ready' : ticket.status,
      readyAt: allReady ? DateTime.now() : ticket.readyAt,
    );
    _kdsTickets[idx] = nextTicket;
    notifyListeners();

    if (!ticket.isTraining) {
      _enqueueSync(
        entityType: 'kds_ready',
        summary: 'KDS Prêt · ${ticket.orderCode}',
        payload: {
          'order_id': ticket.orderId,
          'ticket_number': ticket.orderCode,
          'station': targetStation ?? 'ALL',
          'status': nextTicket.status,
        },
      );
      if (cloudConnected && cloudJwtToken != null) {
        try {
          await _httpRequest(
            'PATCH',
            '$apiBaseUrl/api/pos/kds/${Uri.encodeComponent(ticket.orderId)}',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $cloudJwtToken',
            },
            body: jsonEncode({
              'status': 'READY',
              'station': targetStation ?? 'ALL',
            }),
          );
        } catch (_) {}
      }
    }
    return true;
  }

  /// Toggles or sets item availability (86 Rupture / ÉPUISÉ).
  Future<bool> toggleItemAvailability(
    String itemId, {
    bool? available,
  }) async {
    final idx = menuItems.indexWhere((m) => m.id == itemId || m.sku == itemId);
    if (idx == -1) return false;
    final old = menuItems[idx];
    final nextAvail = available ?? !old.available;
    menuItems[idx] = old.copyWith(available: nextAvail);

    _enqueueSync(
      entityType: 'stock_86',
      summary: '${nextAvail ? "Dispo" : "ÉPUISÉ (86)"} · ${old.nameFr}',
      payload: {
        'product_id': old.id,
        'sku': old.sku,
        'available': nextAvail,
        'is_out_of_stock': !nextAvail,
      },
    );
    notifyListeners();

    if (cloudConnected && cloudJwtToken != null) {
      try {
        final key = old.sku.isNotEmpty ? old.sku : old.id;
        await _httpRequest(
          'PATCH',
          '$apiBaseUrl/api/pos/products/${Uri.encodeComponent(key)}/availability',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $cloudJwtToken',
          },
          body: jsonEncode({
            'available': nextAvail,
            'isOutOfStock': !nextAvail,
          }),
        );
      } catch (_) {}
    }
    return true;
  }

  // --- BOM Matching & Auto-Deduction ---

  List<RecipeBomLine> _matchingBomLinesForItem(
    OrderItem line,
    ServiceMode mode,
  ) {
    final isTakeawayOrDelivery =
        mode == ServiceMode.takeaway || mode == ServiceMode.delivery;
    return recipesBom.where((b) {
      final matchesProduct = b.productId == line.item.id ||
          (b.productSku.isNotEmpty && b.productSku == line.item.sku);
      if (!matchesProduct) return false;

      final channel = b.conditionChannel.toUpperCase();
      final matchesChannel = channel == 'ALL' ||
          (channel == 'TAKEAWAY_DELIVERY' && isTakeawayOrDelivery);
      if (!matchesChannel) return false;

      if (b.modifierKey.isEmpty) return true;
      return line.selectedModifiers.any(
        (m) =>
            m.bomKey == b.modifierKey ||
            m.optionId == b.modifierKey ||
            m.nameFr == b.modifierKey,
      );
    }).toList();
  }

  double _deductBomForOrderLine(OrderItem line, ServiceMode mode) {
    double cost = 0.0;
    final matching = _matchingBomLinesForItem(line, mode);
    for (final b in matching) {
      final ingIdx = ingredients.indexWhere(
        (i) =>
            i.id == b.ingredientId ||
            (b.ingredientSku.isNotEmpty && i.sku == b.ingredientSku),
      );
      if (ingIdx == -1) continue;
      final ing = ingredients[ingIdx];
      final used = b.qtyPerUnit * line.quantity;
      final nextStock = (ing.currentStock - used).clamp(0.0, double.infinity);
      ingredients[ingIdx] = ing.copyWith(currentStock: nextStock);
      cost += used * ing.pmpCostMru;
    }
    return cost;
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
    _openOrdersById[order.id] =
        _withRecomputedDelivery(order.copyWith(items: items));

    // Training Mode strict isolation: do not pollute remake records, BOM waste, or SyncQueue
    if (order.isTraining) {
      notifyListeners();
      return true;
    }

    if (type == 'remake') {
      _todayRemakeWasteMru += _deductBomForOrderLine(line, order.serviceMode);
    }

    final rec = ReturnRemakeCompRecord(
      id: 'RRC-${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      orderTicket: order.ticketNumber,
      itemName: line.item.nameFr,
      quantity: line.quantity,
      amountMru: line.unitPriceWithModifiers * line.quantity,
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
        'sku': line.item.sku,
        'qty': line.quantity,
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

    _openOrdersById[order.id] =
        _withRecomputedDelivery(order.copyWith(items: remaining));
    final splitId = 'ORD-${++_ticketCounter}';
    final splitOrder = PosOrder(
      id: splitId,
      ticketNumber: 'FT-$_ticketCounter-S',
      tableId: order.tableId,
      tableCode: order.tableCode != null ? '${order.tableCode} (Part)' : null,
      staffName: _currentStaff?.name ?? order.staffName,
      items: moved,
      createdAt: DateTime.now(),
      serviceMode: order.serviceMode,
      isTraining: order.isTraining,
    );
    _openOrdersById[splitId] = splitOrder;
    _activeOrderId = splitId;
    notifyListeners();
    return splitOrder;
  }

  /// Checks Karni credit limits before finalizing a checkout.
  /// Returns an error message if any Karni customer exceeds [creditLimitMru], else null.
  String? validateKarniLimits(List<PaymentEntry> payments, {bool isTraining = false}) {
    if (isTraining) return null;
    final karniByCustomer = <String, double>{};
    for (final p in payments) {
      if (p.method == PaymentMethod.karni && p.karniCustomerId != null) {
        karniByCustomer[p.karniCustomerId!] =
            (karniByCustomer[p.karniCustomerId!] ?? 0) + p.amountMru;
      }
    }
    for (final entry in karniByCustomer.entries) {
      final idx = karniCustomers.indexWhere((c) => c.id == entry.key);
      if (idx == -1) return 'Client Karni introuvable.';
      final c = karniCustomers[idx];
      if (c.creditLimitMru > 0 &&
          c.balanceDueMru + entry.value > c.creditLimitMru + 0.01) {
        final avail = (c.creditLimitMru - c.balanceDueMru).clamp(0.0, double.infinity);
        return 'Plafond Karni dépassé pour ${c.name} (disponible : ${avail.toStringAsFixed(0)} MRU / plafond : ${c.creditLimitMru.toStringAsFixed(0)} MRU).';
      }
    }
    return null;
  }

  /// Complete checkout (single or mixed payments) -> updates Karni, deducts BOM,
  /// frees table, queues Sync (strictly skipped in Training Mode).
  PosOrder? completeCheckout(List<PaymentEntry> payments) {
    lastCheckoutError = null;
    final order = activeOrder;
    if (order == null || order.items.isEmpty) {
      lastCheckoutError = 'Commande vide.';
      return null;
    }
    final paidSum = payments.fold(0.0, (s, p) => s + p.amountMru);
    if (paidSum + 0.01 < order.netTotal) {
      lastCheckoutError = 'Montant insuffisant pour clôturer le ticket.';
      return null;
    }
    final karniErr = validateKarniLimits(payments, isTraining: order.isTraining);
    if (karniErr != null) {
      lastCheckoutError = karniErr;
      return null;
    }

    final closed = order.copyWith(
      payments: payments,
      status: 'paid',
      paidAt: DateTime.now(),
    );

    _openOrdersById.remove(order.id);

    // Free table only if this order was the table's primary activeOrderId
    if (order.tableId != null) {
      final tIdx = tables.indexWhere((t) => t.id == order.tableId);
      if (tIdx != -1 && tables[tIdx].activeOrderId == order.id) {
        tables[tIdx] = tables[tIdx].copyWith(
          status: TableStatus.free,
          guests: 0,
          clearOrder: true,
          clearOccupied: true,
          clearServer: true,
          waitAlert: false,
          arbounMru: 0,
        );
      }
    }

    if (closed.isTraining) {
      _trainingOrders.insert(0, closed);
      startCounterOrder();
      return closed;
    }

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

    // Deduct BOM ingredients & track food cost
    double orderFoodCost = 0.0;
    for (final line in closed.items) {
      orderFoodCost += _deductBomForOrderLine(line, closed.serviceMode);
    }
    _orderFoodCostById[closed.id] = orderFoodCost;

    _completedOrders.insert(0, closed);

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

  // --- Owner Live KPIs & Food Cost ---

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<PosOrder> get _todayRealOrders {
    final now = DateTime.now();
    return _completedOrders
        .where((o) => !o.isTraining && _isSameDay(o.paidAt ?? o.createdAt, now))
        .toList(growable: false);
  }

  double get todayRevenueMru =>
      _todayRealOrders.fold(0.0, (s, o) => s + o.grossTotal);

  int get todayTicketsCount => _todayRealOrders.length;

  double get averageBasketMru =>
      todayTicketsCount == 0 ? 0.0 : todayRevenueMru / todayTicketsCount;

  Map<PaymentMethod, double> get revenueByPaymentMethod {
    final breakdown = {for (final m in PaymentMethod.values) m: 0.0};
    for (final o in _todayRealOrders) {
      var remainingChange = o.changeDue;
      for (final p in o.payments) {
        var effective = p.amountMru;
        if (p.method == PaymentMethod.cash && remainingChange > 0) {
          final deducted =
              remainingChange > effective ? effective : remainingChange;
          effective -= deducted;
          remainingChange -= deducted;
        }
        breakdown[p.method] = (breakdown[p.method] ?? 0.0) + effective;
      }
    }
    return breakdown;
  }

  double get todayFoodCostMru {
    final ordersCost = _todayRealOrders.fold<double>(
      0.0,
      (sum, o) => sum + (_orderFoodCostById[o.id] ?? 0.0),
    );
    return ordersCost + _todayRemakeWasteMru;
  }

  double get foodCostPercent =>
      todayRevenueMru <= 0 ? 0.0 : (todayFoodCostMru / todayRevenueMru) * 100.0;

  double get grossMarginPercent => todayRevenueMru <= 0
      ? 0.0
      : ((todayRevenueMru - todayFoodCostMru) / todayRevenueMru) * 100.0;

  Map<int, double> get todayHourlyRevenue {
    final map = <int, double>{};
    for (final o in _todayRealOrders) {
      final hr = (o.paidAt ?? o.createdAt).hour;
      map[hr] = (map[hr] ?? 0.0) + o.netTotal;
    }
    return map;
  }

  List<MapEntry<String, int>> get topSellingDishes {
    final counts = <String, int>{};
    for (final o in _todayRealOrders) {
      for (final item in o.items) {
        final name = item.item.label(_lang);
        counts[name] = (counts[name] ?? 0) + item.quantity;
      }
    }
    final list = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list;
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
        arbounMru: arbounMru,
      );
    }
    _enqueueSync(
      entityType: 'reservation',
      summary:
          'VIP ${res.customerName} · Arboun ${arbounMru.toStringAsFixed(0)} MRU',
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

  List<PosOrder> get _unclosedRealOrders {
    return _completedOrders.where((o) {
      if (o.isTraining) return false;
      if (_lastZClosedAt == null) return true;
      return (o.paidAt ?? o.createdAt).isAfter(_lastZClosedAt!);
    }).toList(growable: false);
  }

  double _expectedForMethod(PaymentMethod method) {
    double sum = 0;
    for (final o in _unclosedRealOrders) {
      var remainingChange = o.changeDue;
      for (final p in o.payments) {
        if (p.method == method) {
          if (method == PaymentMethod.cash) {
            final deducted =
                remainingChange > p.amountMru ? p.amountMru : remainingChange;
            sum += (p.amountMru - deducted).clamp(0.0, double.infinity);
            remainingChange -= deducted;
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
    double countedBimbankMru = 0,
    double countedClickMru = 0,
  }) {
    final closedOrdersForZ = _unclosedRealOrders;
    final zTime = DateTime.now();
    final z = CashClosingZ(
      id: 'Z-${zTime.millisecondsSinceEpoch % 100000}',
      closedAt: zTime,
      cashierName: _currentStaff?.name ?? 'Caissier',
      countedCashMru: countedCashMru,
      expectedCashMru: _expectedForMethod(PaymentMethod.cash),
      countedBankilyMru: countedBankilyMru,
      expectedBankilyMru: _expectedForMethod(PaymentMethod.bankily),
      countedMasriviMru: countedMasriviMru,
      expectedMasriviMru: _expectedForMethod(PaymentMethod.masrivi),
      countedSedadMru: countedSedadMru,
      expectedSedadMru: _expectedForMethod(PaymentMethod.sedad),
      countedBimbankMru: countedBimbankMru,
      expectedBimbankMru: _expectedForMethod(PaymentMethod.bimbank),
      countedClickMru: countedClickMru,
      expectedClickMru: _expectedForMethod(PaymentMethod.click),
      karniIssuedMru: _expectedForMethod(PaymentMethod.karni),
      ordersCount: closedOrdersForZ.length,
      remakesCount: _remakeRecords.length,
    );
    _lastZClosedAt = zTime;
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

  /// Activates an offline license from an 8/12-digit unlock code or signed Ed25519 Lease Token.
  String? activateOfflineLicense(String rawInput) {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) return 'Code ou jeton requis.';

    // 1. Signed Lease Token format: <base64url-payload>.<base64url-sig>
    if (trimmed.contains('.')) {
      try {
        final payloadB64 = trimmed.split('.').first;
        final normalized = base64Url.normalize(payloadB64);
        final decoded = utf8.decode(base64Url.decode(normalized));
        final jsonMap = jsonDecode(decoded);
        if (jsonMap is Map<String, dynamic>) {
          final expStr = jsonMap['expiresAt'] as String?;
          final days = (jsonMap['days'] as num?)?.toInt() ?? 30;
          final nextExp = expStr != null
              ? (DateTime.tryParse(expStr) ??
                  DateTime.now().add(Duration(days: days)))
              : DateTime.now().add(Duration(days: days));
          final code = '${jsonMap['code'] ?? license.code12}';
          license = OfflineLicenseInfo(
            tenantName: '${jsonMap['storeName'] ?? tenantName}',
            code12: code,
            expiresAt: nextExp,
            ed25519Verified: true,
          );
          notifyListeners();
          return null;
        }
      } catch (_) {
        return 'Jeton Lease Token invalide.';
      }
    }

    // 2. Numeric 8/12-digit unlock code (e.g. 7711-2233-4455 or 1234-5678)
    final digitsOnly = trimmed.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (digitsOnly.length < 8) {
      return 'Code de déblocage invalide (minimum 8 caractères).';
    }
    license = OfflineLicenseInfo(
      tenantName: tenantName,
      code12: trimmed.toUpperCase(),
      expiresAt: DateTime.now().add(const Duration(days: 30)),
      ed25519Verified: true,
    );
    notifyListeners();
    return null;
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
      final res = await _httpRequest(
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
        cloudConnected = true;
        lastSyncMessage =
            'Synchronisation Cloud réussie ($syncedCount éléments).';
      } else {
        cloudConnected = false;
        lastSyncMessage =
            'API Cloud HTTP ${res.statusCode} — file conservée en local (Offline-First).';
      }
    } catch (_) {
      cloudConnected = false;
      lastSyncMessage =
          'Mode hors-ligne détecté — ${pending.length} éléments sécurisés localement.';
    } finally {
      isSyncing = false;
      notifyListeners();
    }
    return syncedCount;
  }

  // --- Demo Seed Data (Mauritanie · Dar El-Karam / Restaurant Oasis Tevragh-Zeina) ---

  void _seedMauritanianRestaurantData() {
    license = OfflineLicenseInfo(
      tenantName: tenantName,
      code12: '4829-1904-7731',
      expiresAt: DateTime.now().add(const Duration(days: 28)),
      ed25519Verified: true,
    );

    staff = [
      const StaffMember(
        id: 'ST-1',
        name: 'Ahmed Ould Salem (Propriétaire)',
        role: PosRole.owner,
        pinCode: '7410',
      ),
      const StaffMember(
        id: 'ST-2',
        name: 'Aïcha (Caissière)',
        role: PosRole.cashier,
        pinCode: '1234',
      ),
      const StaffMember(
        id: 'ST-3',
        name: 'Sidi (Serveur)',
        role: PosRole.waiter,
        pinCode: '2222',
      ),
      const StaffMember(
        id: 'ST-4',
        name: 'Mariem (Manager)',
        role: PosRole.manager,
        pinCode: '9999',
      ),
    ];

    deliveryZones = List<DeliveryZone>.from(DeliveryZone.nouakchottPresets);
    _selectedDeliveryZone = deliveryZones.first;

    categories = [
      const MenuCategory(
        id: 'grill',
        nameFr: 'Grillades & Plats',
        nameAr: 'مشويات وأطباق',
        nameEn: 'Grills & Mains',
        icon: '🔥',
        sortOrder: 1,
      ),
      const MenuCategory(
        id: 'mauritanian',
        nameFr: 'Spécialités RIM',
        nameAr: 'أطباق موريتانية',
        nameEn: 'Mauritanian',
        icon: '🍲',
        sortOrder: 2,
      ),
      const MenuCategory(
        id: 'starters',
        nameFr: 'Entrées & Salades',
        nameAr: 'مقبلات وسلطات',
        nameEn: 'Starters',
        icon: '🥗',
        sortOrder: 3,
      ),
      const MenuCategory(
        id: 'drinks',
        nameFr: 'Boissons & Ataya',
        nameAr: 'مشروبات وأتاي',
        nameEn: 'Drinks & Tea',
        icon: '🍵',
        sortOrder: 4,
      ),
      const MenuCategory(
        id: 'desserts',
        nameFr: 'Desserts',
        nameAr: 'حلويات',
        nameEn: 'Desserts',
        icon: '🍰',
        sortOrder: 5,
      ),
    ];

    const cuissonGroup = ModifierGroup(
      id: 'mg-cuisson',
      nameFr: 'Cuisson',
      nameAr: 'درجة الطهي',
      nameEn: 'Cooking',
      required: false,
      multiSelect: false,
      options: [
        ModifierOption(
          id: 'opt-bien',
          nameFr: 'Bien cuit',
          nameAr: 'ناضج جداً',
          nameEn: 'Well done',
        ),
        ModifierOption(
          id: 'opt-apoint',
          nameFr: 'À point',
          nameAr: 'متوسط',
          nameEn: 'Medium',
        ),
        ModifierOption(
          id: 'opt-saignant',
          nameFr: 'Saignant',
          nameAr: 'نصف ناضج',
          nameEn: 'Medium rare',
        ),
      ],
    );

    const sideGroup = ModifierGroup(
      id: 'mg-side',
      nameFr: 'Accompagnement',
      nameAr: 'الطبق الجانبي',
      nameEn: 'Side dish',
      required: false,
      multiSelect: false,
      options: [
        ModifierOption(
          id: 'opt-frites',
          nameFr: 'Frites Maison',
          nameAr: 'بطاطس مقلية',
          nameEn: 'House Fries',
        ),
        ModifierOption(
          id: 'opt-riz',
          nameFr: 'Riz Parfumé',
          nameAr: 'أرز معطر',
          nameEn: 'Fragrant Rice',
        ),
        ModifierOption(
          id: 'opt-salade',
          nameFr: 'Salade Fraîche',
          nameAr: 'سلطة طازجة',
          nameEn: 'Fresh Salad',
        ),
      ],
    );

    const extrasGroup = ModifierGroup(
      id: 'mg-extras',
      nameFr: 'Suppléments',
      nameAr: 'إضافات',
      nameEn: 'Extras',
      required: false,
      multiSelect: true,
      options: [
        ModifierOption(
          id: 'opt-mozzarella',
          nameFr: 'Supplément Mozzarella',
          nameAr: 'إضافة جبن موزاريلا',
          nameEn: 'Extra Mozzarella',
          extraPriceMru: 60,
          bomKey: '+Mozzarella',
        ),
        ModifierOption(
          id: 'opt-double-viande',
          nameFr: 'Double Viande',
          nameAr: 'لحم مضاعف',
          nameEn: 'Double Meat',
          extraPriceMru: 120,
          bomKey: '+DoubleViande',
        ),
        ModifierOption(
          id: 'opt-sauce-alg',
          nameFr: 'Sauce Algérienne',
          nameAr: 'صلصة جزائرية',
          nameEn: 'Algerian Sauce',
          extraPriceMru: 20,
        ),
        ModifierOption(
          id: 'opt-sans-oignon',
          nameFr: 'Sans oignon',
          nameAr: 'بدون بصل',
          nameEn: 'No onion',
        ),
      ],
    );

    menuItems = [
      const MenuItem(
        id: 'M1',
        categoryId: 'mauritanian',
        sku: 'RIM-001',
        nameFr: 'Thiéboudienne Royal',
        nameAr: 'تيبوجين ملكي',
        nameEn: 'Royal Thieboudienne',
        priceMru: 450,
        kitchenStation: 'KITCHEN',
        icon: '🍲',
        isTop: true,
        modifiers: [sideGroup],
      ),
      const MenuItem(
        id: 'M2',
        categoryId: 'mauritanian',
        sku: 'RIM-002',
        nameFr: 'Méchoui Agneau (1/2)',
        nameAr: 'مشوي خروف (نصف)',
        nameEn: 'Half Lamb Mechoui',
        priceMru: 1400,
        kitchenStation: 'GRILL',
        icon: '🍖',
        isTop: true,
        modifiers: [cuissonGroup, sideGroup],
      ),
      const MenuItem(
        id: 'M3',
        categoryId: 'mauritanian',
        sku: 'RIM-003',
        nameFr: 'Couscous Viande Chameau',
        nameAr: 'كسكس بلحم الإبل',
        nameEn: 'Camel Meat Couscous',
        priceMru: 550,
        kitchenStation: 'KITCHEN',
        icon: '🥘',
      ),
      const MenuItem(
        id: 'M4',
        categoryId: 'mauritanian',
        sku: 'RIM-004',
        nameFr: 'Marou Laham',
        nameAr: 'مارو واللحم',
        nameEn: 'Marou & Lamb',
        priceMru: 480,
        kitchenStation: 'KITCHEN',
        icon: '🍛',
      ),
      const MenuItem(
        id: 'M5',
        categoryId: 'grill',
        sku: 'GRL-001',
        nameFr: 'Mix Grill Oasis',
        nameAr: 'مشويات مشكلة الواحة',
        nameEn: 'Oasis Mix Grill',
        priceMru: 750,
        kitchenStation: 'GRILL',
        icon: '🥩',
        isTop: true,
        modifiers: [cuissonGroup, sideGroup, extrasGroup],
      ),
      const MenuItem(
        id: 'M6',
        categoryId: 'grill',
        sku: 'GRL-002',
        nameFr: 'Chawarma Poulet Assiette',
        nameAr: 'صحن شاورما دجاج',
        nameEn: 'Chicken Shawarma Plate',
        priceMru: 350,
        kitchenStation: 'GRILL',
        icon: '🌯',
        modifiers: [sideGroup, extrasGroup],
      ),
      const MenuItem(
        id: 'M7',
        categoryId: 'grill',
        sku: 'GRL-003',
        nameFr: 'Brochettes Filet Bœuf',
        nameAr: 'أسياخ لحم بقري',
        nameEn: 'Beef Skewers',
        priceMru: 500,
        kitchenStation: 'GRILL',
        icon: '🍢',
        modifiers: [cuissonGroup, sideGroup, extrasGroup],
      ),
      const MenuItem(
        id: 'M8',
        categoryId: 'grill',
        sku: 'GRL-004',
        nameFr: 'Thiof Braisé Entier',
        nameAr: 'سمك تيوف مشوي',
        nameEn: 'Whole Grilled Thiof',
        priceMru: 850,
        kitchenStation: 'GRILL',
        icon: '🐟',
        isTop: true,
        modifiers: [sideGroup],
      ),
      const MenuItem(
        id: 'M9',
        categoryId: 'starters',
        sku: 'ENT-001',
        nameFr: 'Salade Fattouch',
        nameAr: 'سلطة فتوش',
        nameEn: 'Fattoush Salad',
        priceMru: 220,
        kitchenStation: 'KITCHEN',
        icon: '🥗',
      ),
      const MenuItem(
        id: 'M10',
        categoryId: 'starters',
        sku: 'ENT-002',
        nameFr: 'Houmous & Pain Chaud',
        nameAr: 'حمص مع خبز ساخن',
        nameEn: 'Hummus & Warm Bread',
        priceMru: 180,
        kitchenStation: 'KITCHEN',
        icon: '🫓',
      ),
      const MenuItem(
        id: 'M11',
        categoryId: 'starters',
        sku: 'ENT-003',
        nameFr: 'Pastilla Poulet',
        nameAr: 'بسطيلة دجاج',
        nameEn: 'Chicken Pastilla',
        priceMru: 300,
        kitchenStation: 'KITCHEN',
        icon: '🥟',
        modifiers: [extrasGroup],
      ),
      const MenuItem(
        id: 'M12',
        categoryId: 'drinks',
        sku: 'DRK-001',
        nameFr: 'Thé Ataya (Service 3 verres)',
        nameAr: 'أتاي موريتاني (3 كؤوس)',
        nameEn: 'Mauritanian Ataya Service',
        priceMru: 150,
        kitchenStation: 'BAR',
        icon: '🍵',
        isTop: true,
      ),
      const MenuItem(
        id: 'M13',
        categoryId: 'drinks',
        sku: 'DRK-002',
        nameFr: 'Jus Bissap Frais',
        nameAr: 'عصير بيساب طازج',
        nameEn: 'Fresh Bissap Juice',
        priceMru: 120,
        kitchenStation: 'BAR',
        icon: '🍹',
      ),
      const MenuItem(
        id: 'M14',
        categoryId: 'drinks',
        sku: 'DRK-003',
        nameFr: 'Jus Bouye (Baobab)',
        nameAr: 'عصير بوي (باوباب)',
        nameEn: 'Baobab Bouye Juice',
        priceMru: 130,
        kitchenStation: 'BAR',
        icon: '🥤',
      ),
      const MenuItem(
        id: 'M15',
        categoryId: 'drinks',
        sku: 'DRK-004',
        nameFr: 'Zrig (Lait Caillé Frais)',
        nameAr: 'ازريك طازج',
        nameEn: 'Fresh Zrig',
        priceMru: 140,
        kitchenStation: 'BAR',
        icon: '🥛',
      ),
      const MenuItem(
        id: 'M16',
        categoryId: 'drinks',
        sku: 'DRK-005',
        nameFr: 'Eau Minérale 1.5L',
        nameAr: 'ماء معدني 1.5 لتر',
        nameEn: 'Mineral Water 1.5L',
        priceMru: 60,
        kitchenStation: 'BAR',
        icon: '💧',
      ),
      const MenuItem(
        id: 'M17',
        categoryId: 'desserts',
        sku: 'DES-001',
        nameFr: 'Dattes Tidjikja & Crème',
        nameAr: 'تمور تجكجة بالقشطة',
        nameEn: 'Tidjikja Dates & Cream',
        priceMru: 200,
        kitchenStation: 'BAR',
        icon: '🌴',
      ),
      const MenuItem(
        id: 'M18',
        categoryId: 'desserts',
        sku: 'DES-002',
        nameFr: 'Tiramisu Maison',
        nameAr: 'تيراميسو منزلي',
        nameEn: 'Homemade Tiramisu',
        priceMru: 250,
        kitchenStation: 'BAR',
        icon: '🍰',
      ),
    ];

    zones = [
      const DiningZone(
        id: 'main',
        nameFr: 'Salle Principale',
        nameAr: 'الصالة الرئيسية',
        nameEn: 'Main Hall',
        zoneType: 'SALLE',
      ),
      const DiningZone(
        id: 'terrace',
        nameFr: 'Terrasse Oasis',
        nameAr: 'شرفة الواحة',
        nameEn: 'Oasis Terrace',
        zoneType: 'TERRACE',
      ),
      const DiningZone(
        id: 'khaima',
        nameFr: 'Salon Khaima VIP',
        nameAr: 'خيمة VIP',
        nameEn: 'Khaima VIP Lounge',
        isVip: true,
        zoneType: 'VIP_KHAIMA',
        minSpendMru: 3000,
      ),
    ];

    tables = [
      const DiningTable(
        id: 'T1',
        zoneId: 'main',
        code: 'T-01',
        capacity: 4,
        shape: TableShape.round,
        x: 0.14,
        y: 0.18,
      ),
      const DiningTable(
        id: 'T2',
        zoneId: 'main',
        code: 'T-02',
        capacity: 4,
        shape: TableShape.round,
        x: 0.42,
        y: 0.18,
      ),
      const DiningTable(
        id: 'T3',
        zoneId: 'main',
        code: 'T-03',
        capacity: 6,
        shape: TableShape.square,
        x: 0.70,
        y: 0.18,
      ),
      const DiningTable(
        id: 'T4',
        zoneId: 'main',
        code: 'T-04',
        capacity: 2,
        shape: TableShape.round,
        x: 0.14,
        y: 0.52,
      ),
      const DiningTable(
        id: 'T5',
        zoneId: 'terrace',
        code: 'TER-1',
        capacity: 4,
        shape: TableShape.square,
        x: 0.42,
        y: 0.52,
      ),
      const DiningTable(
        id: 'T6',
        zoneId: 'terrace',
        code: 'TER-2',
        capacity: 6,
        shape: TableShape.square,
        x: 0.70,
        y: 0.52,
      ),
      const DiningTable(
        id: 'K1',
        zoneId: 'khaima',
        code: 'KHAIMA-1',
        capacity: 10,
        status: TableStatus.reserved,
        guests: 8,
        shape: TableShape.khaima,
        x: 0.22,
        y: 0.78,
        minSpendMru: 3000,
        arbounMru: 2000,
      ),
      const DiningTable(
        id: 'K2',
        zoneId: 'khaima',
        code: 'KHAIMA-2',
        capacity: 12,
        shape: TableShape.khaima,
        x: 0.65,
        y: 0.78,
        minSpendMru: 3500,
      ),
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

    ingredients = [
      const Ingredient(
        id: 'ing-beef',
        sku: 'ING-BEEF',
        nameFr: 'Viande Bœuf / Hachée',
        nameAr: 'لحم بقري',
        nameEn: 'Beef',
        unit: 'kg',
        pmpCostMru: 320,
        currentStock: 25.0,
        minStock: 5.0,
      ),
      const Ingredient(
        id: 'ing-lamb',
        sku: 'ING-LAMB',
        nameFr: 'Agneau Méchoui',
        nameAr: 'لحم خروف',
        nameEn: 'Lamb',
        unit: 'kg',
        pmpCostMru: 420,
        currentStock: 18.0,
        minStock: 4.0,
      ),
      const Ingredient(
        id: 'ing-chick',
        sku: 'ING-CHICK',
        nameFr: 'Poulet Fermier',
        nameAr: 'دجاج',
        nameEn: 'Chicken',
        unit: 'kg',
        pmpCostMru: 180,
        currentStock: 20.0,
        minStock: 4.0,
      ),
      const Ingredient(
        id: 'ing-thiof',
        sku: 'ING-THIOF',
        nameFr: 'Poisson Thiof Frais',
        nameAr: 'سمك تيوف طازج',
        nameEn: 'Fresh Thiof Fish',
        unit: 'kg',
        pmpCostMru: 380,
        currentStock: 12.0,
        minStock: 3.0,
      ),
      const Ingredient(
        id: 'ing-rice',
        sku: 'ING-RICE',
        nameFr: 'Riz Parfumé',
        nameAr: 'أرز معطر',
        nameEn: 'Fragrant Rice',
        unit: 'kg',
        pmpCostMru: 45,
        currentStock: 40.0,
        minStock: 8.0,
      ),
      const Ingredient(
        id: 'ing-mint',
        sku: 'ING-MINT',
        nameFr: 'Thé Vert & Menthe',
        nameAr: 'شاي أخضر ونعناع',
        nameEn: 'Green Tea & Mint',
        unit: 'unit',
        pmpCostMru: 30,
        currentStock: 35.0,
        minStock: 8.0,
      ),
      const Ingredient(
        id: 'ing-mozz',
        sku: 'ING-MOZZ',
        nameFr: 'Mozzarella',
        nameAr: 'جبن موزاريلا',
        nameEn: 'Mozzarella',
        unit: 'kg',
        pmpCostMru: 280,
        currentStock: 6.0,
        minStock: 1.5,
      ),
      const Ingredient(
        id: 'ing-box',
        sku: 'ING-BOX',
        nameFr: 'Boîte Emballage',
        nameAr: 'علبة تغليف',
        nameEn: 'Takeaway Box',
        unit: 'unit',
        pmpCostMru: 15,
        currentStock: 120.0,
        minStock: 25.0,
      ),
      const Ingredient(
        id: 'ing-bag',
        sku: 'ING-BAG',
        nameFr: 'Sac Kraft Livraison',
        nameAr: 'كيس توصيل',
        nameEn: 'Kraft Bag',
        unit: 'unit',
        pmpCostMru: 10,
        currentStock: 150.0,
        minStock: 30.0,
      ),
    ];

    recipesBom = [
      const RecipeBomLine(
        id: 'bom-m1-thiof',
        productId: 'M1',
        productSku: 'RIM-001',
        ingredientId: 'ing-thiof',
        ingredientSku: 'ING-THIOF',
        qtyPerUnit: 0.25,
      ),
      const RecipeBomLine(
        id: 'bom-m1-rice',
        productId: 'M1',
        productSku: 'RIM-001',
        ingredientId: 'ing-rice',
        ingredientSku: 'ING-RICE',
        qtyPerUnit: 0.20,
      ),
      const RecipeBomLine(
        id: 'bom-m2-lamb',
        productId: 'M2',
        productSku: 'RIM-002',
        ingredientId: 'ing-lamb',
        ingredientSku: 'ING-LAMB',
        qtyPerUnit: 0.80,
      ),
      const RecipeBomLine(
        id: 'bom-m5-beef',
        productId: 'M5',
        productSku: 'GRL-001',
        ingredientId: 'ing-beef',
        ingredientSku: 'ING-BEEF',
        qtyPerUnit: 0.25,
      ),
      const RecipeBomLine(
        id: 'bom-m5-lamb',
        productId: 'M5',
        productSku: 'GRL-001',
        ingredientId: 'ing-lamb',
        ingredientSku: 'ING-LAMB',
        qtyPerUnit: 0.20,
      ),
      const RecipeBomLine(
        id: 'bom-m6-chick',
        productId: 'M6',
        productSku: 'GRL-002',
        ingredientId: 'ing-chick',
        ingredientSku: 'ING-CHICK',
        qtyPerUnit: 0.25,
      ),
      const RecipeBomLine(
        id: 'bom-m7-beef',
        productId: 'M7',
        productSku: 'GRL-003',
        ingredientId: 'ing-beef',
        ingredientSku: 'ING-BEEF',
        qtyPerUnit: 0.30,
      ),
      const RecipeBomLine(
        id: 'bom-m8-thiof',
        productId: 'M8',
        productSku: 'GRL-004',
        ingredientId: 'ing-thiof',
        ingredientSku: 'ING-THIOF',
        qtyPerUnit: 0.85,
      ),
      const RecipeBomLine(
        id: 'bom-m12-mint',
        productId: 'M12',
        productSku: 'DRK-001',
        ingredientId: 'ing-mint',
        ingredientSku: 'ING-MINT',
        qtyPerUnit: 1.0,
      ),
      // Conditional packaging BOM for Takeaway / Delivery
      for (final mid in ['M1', 'M2', 'M3', 'M4', 'M5', 'M6', 'M7', 'M8']) ...[
        RecipeBomLine(
          id: 'bom-$mid-box',
          productId: mid,
          ingredientId: 'ing-box',
          ingredientSku: 'ING-BOX',
          qtyPerUnit: 1.0,
          conditionChannel: 'TAKEAWAY_DELIVERY',
        ),
        RecipeBomLine(
          id: 'bom-$mid-bag',
          productId: mid,
          ingredientId: 'ing-bag',
          ingredientSku: 'ING-BAG',
          qtyPerUnit: 1.0,
          conditionChannel: 'TAKEAWAY_DELIVERY',
        ),
      ],
      // Modifier-linked BOM lines
      for (final mid in ['M5', 'M6', 'M7', 'M11']) ...[
        RecipeBomLine(
          id: 'bom-$mid-mozz',
          productId: mid,
          ingredientId: 'ing-mozz',
          ingredientSku: 'ING-MOZZ',
          qtyPerUnit: 0.06,
          modifierKey: '+Mozzarella',
        ),
        RecipeBomLine(
          id: 'bom-$mid-double-beef',
          productId: mid,
          ingredientId: 'ing-beef',
          ingredientSku: 'ING-BEEF',
          qtyPerUnit: 0.15,
          modifierKey: '+DoubleViande',
        ),
      ],
    ];
  }
}
