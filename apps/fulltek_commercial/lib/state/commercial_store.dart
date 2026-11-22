import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/commercial_models.dart';
import '../services/export_helper.dart';
import '../services/http_bridge.dart';
import '../services/local_storage.dart';
import '../utils/amount_in_words.dart';

typedef HttpBridgeFn = Future<HttpBridgeResponse> Function(
  String method,
  String url, {
  Map<String, String>? headers,
  String? body,
});

String fmtMru(double v) {
  final rounded = v.round();
  final s = rounded.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return '${v < 0 ? '-' : ''}${buf.toString()} MRU';
}

/// Pure helper calculations tested in unit tests.
class CommercialMath {
  static double computeLineHt({
    required double qty,
    required double unitPriceHt,
    double discountPct = 0,
  }) {
    final raw = qty * unitPriceHt * (1 - discountPct / 100.0);
    return (raw * 100).round() / 100;
  }

  static double computeLineTva({
    required double lineHt,
    required bool isExempt,
    double tvaRate = 16,
  }) {
    if (isExempt || tvaRate <= 0) return 0;
    return ((lineHt * tvaRate / 100.0) * 100).round() / 100;
  }

  static double computeWeightedPmp({
    required double currentStock,
    required double currentPmp,
    required double incomingQty,
    required double incomingCostHt,
  }) {
    final safeStock = currentStock < 0 ? 0.0 : currentStock;
    final totalQty = safeStock + incomingQty;
    if (totalQty <= 0) return incomingCostHt;
    return (((safeStock * currentPmp) + (incomingQty * incomingCostHt)) /
                totalQty *
                100)
            .round() /
        100;
  }

  static double computeMarginPct({
    required double caHt,
    required double costMru,
  }) {
    if (caHt <= 0) return 0;
    return (((caHt - costMru) / caHt) * 100 * 10).round() / 10;
  }
}

class CommercialStore extends ChangeNotifier {
  final HttpBridgeFn _http;
  final bool _enablePersistence;

  String apiBaseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000',
  );

  bool loggedIn = false;
  bool isOfflineDemo = false;
  bool isBusy = false;
  String? jwtToken;
  String activePreset = 'this_year';
  String? customFrom;
  String? customTo;
  String lang = 'fr';
  String activeRole = 'OWNER';

  bool get isRtl => lang == 'ar';

  void setLanguage(String next) {
    if (lang == next) return;
    lang = next;
    notifyListeners();
  }

  void setActiveRole(String role) {
    activeRole = role.toUpperCase();
    notifyListeners();
  }

  bool canAccessRoute(String routeId) {
    if (activeRole == 'OWNER' || activeRole == 'MANAGER') return true;
    if (activeRole == 'CASHIER') {
      return const {'pos_register', 'pos_sessions', 'pos_tickets'}
          .contains(routeId);
    }
    if (activeRole == 'COMMERCIAL') {
      return const {
        'dashboard',
        'analytics_sales',
        'clients',
        'articles',
        'sales_devis',
        'sales_commandes',
        'sales_bl',
        'sales_factures',
        'sales_avoirs',
        'pos_register',
        'pos_tickets',
        'statements',
      }.contains(routeId);
    }
    if (activeRole == 'ACCOUNTANT') {
      return const {
        'dashboard',
        'analytics_sales',
        'analytics_purchases',
        'treasury',
        'cheques',
        'expenses',
        'tva_report',
        'statements',
        'objectives',
        'sales_factures',
        'sales_avoirs',
        'pur_fac',
        'pur_av',
      }.contains(routeId);
    }
    return true;
  }

  CompanySettings companySettings = const CompanySettings();
  List<OperatingExpense> expenses = [];
  List<WarehouseLocation> warehouses = [];
  List<StockTransferRecord> stockTransfers = [];
  List<InventorySessionRecord> inventorySessions = [];
  List<ParkedPosOrder> parkedOrders = [];

  CommercialTenantInfo tenant = const CommercialTenantInfo();
  DashboardData dashboard = const DashboardData();
  List<CommercialClient> clients = [];
  List<CommercialSupplier> suppliers = [];
  List<CommercialArticle> articles = [];
  List<StockMovement> stockMovements = [];
  List<CommercialDoc> salesDocs = [];
  List<CommercialDoc> purchaseDocs = [];
  List<CommercialPosSession> posSessions = [];
  CommercialPosSession? openPosSession;
  List<CommercialPosTicket> posTickets = [];
  List<TreasuryAccount> treasuryAccounts = [];
  List<TreasuryMovement> treasuryMovements = [];
  List<ChequeDraft> cheques = [];
  List<MonthlyObjective> objectives = [];
  int objectivesYear = DateTime.now().year;

  Map<String, dynamic> analyticsSales = const {};
  Map<String, dynamic> analyticsPurchases = const {};
  Map<String, dynamic> analyticsTreasury = const {};
  Map<String, dynamic> analyticsObjectives = const {};

  static const _storageKey = 'fulltek_commercial_session_v1';

  CommercialStore({HttpBridgeFn? httpRequest, bool? enablePersistence})
      : _http = httpRequest ?? httpBridgeRequest,
        _enablePersistence = enablePersistence ?? kIsWeb {
    if (_enablePersistence) {
      _restoreSession();
    }
  }

  Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        if (jwtToken != null) 'Authorization': 'Bearer $jwtToken',
      };

  void _restoreSession() {
    try {
      final raw = localStorageRead(_storageKey);
      if (raw == null || raw.isEmpty) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (map['loggedIn'] == true && map['jwtToken'] is String) {
        jwtToken = map['jwtToken'] as String;
        if (map['tenant'] is Map) {
          tenant = CommercialTenantInfo.fromJson(
              (map['tenant'] as Map).cast<String, dynamic>());
        }
        loggedIn = true;
        refreshAll();
      }
    } catch (_) {}
  }

  void _saveSession() {
    if (!_enablePersistence) return;
    try {
      if (!loggedIn || isOfflineDemo) {
        localStorageWrite(_storageKey, '');
        return;
      }
      localStorageWrite(
        _storageKey,
        jsonEncode({
          'loggedIn': loggedIn,
          'jwtToken': jwtToken,
          'tenant': {
            'tenantId': tenant.tenantId,
            'name': tenant.name,
            'nif': tenant.nif,
            'rc': tenant.rc,
            'city': tenant.city,
            'address': tenant.address,
            'phone': tenant.phone,
            'manager': tenant.manager,
            'plan': tenant.plan,
            'daysLeft': tenant.daysLeft,
            'payMethods': tenant.payMethods,
          },
        }),
      );
    } catch (_) {}
  }

  Future<String?> loginAccount(String username, String password) async {
    final u = username.trim();
    if (u.isEmpty || password.isEmpty) {
      return 'Identifiant et mot de passe requis.';
    }
    try {
      final res = await _http(
        'POST',
        '$apiBaseUrl/api/auth/login',
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': u, 'password': password}),
      );
      if (res.statusCode == 401) {
        return 'Identifiant ou mot de passe incorrect.';
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return 'Erreur serveur (HTTP ${res.statusCode})';
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final tMap = (data['tenant'] as Map).cast<String, dynamic>();
      if (tMap['module'] != 'commercial') {
        return 'Ce compte est un espace "${tMap['module']}" — utilisez un compte Gestion Commerciale.';
      }
      jwtToken = data['token'] as String?;
      tenant = CommercialTenantInfo.fromJson(tMap);
      isOfflineDemo = false;
      loggedIn = true;
      _saveSession();
      await refreshAll();
      return null;
    } catch (_) {
      return 'Serveur inaccessible — vérifiez votre connexion internet.';
    }
  }

  void enterOfflineDemo() {
    isOfflineDemo = true;
    loggedIn = true;
    tenant = const CommercialTenantInfo();
    _seedOfflineDemoData();
    notifyListeners();
  }

  void logout() {
    loggedIn = false;
    isOfflineDemo = false;
    jwtToken = null;
    _saveSession();
    notifyListeners();
  }

  Future<void> refreshAll() async {
    if (isOfflineDemo) {
      notifyListeners();
      return;
    }
    if (jwtToken == null) return;
    isBusy = true;
    notifyListeners();
    try {
      await Future.wait([
        loadBootstrap(),
        loadDashboard(),
        loadClients(),
        loadSuppliers(),
        loadArticles(),
        loadSalesDocs(),
        loadPurchaseDocs(),
        loadPosData(),
        loadTreasury(),
        loadCheques(),
        loadObjectives(objectivesYear),
      ]);
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> loadBootstrap() async {
    final res =
        await _http('GET', '$apiBaseUrl/api/commercial/bootstrap', headers: _authHeaders);
    if (res.statusCode == 200) {
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      if (j['tenant'] is Map) {
        tenant = CommercialTenantInfo.fromJson(
            (j['tenant'] as Map).cast<String, dynamic>());
      }
      if (j['openPosSession'] is Map) {
        openPosSession = CommercialPosSession.fromJson(
            (j['openPosSession'] as Map).cast<String, dynamic>());
      } else {
        openPosSession = null;
      }
    }
  }

  Future<void> loadDashboard({String? preset, String? from, String? to}) async {
    if (preset != null) {
      activePreset = preset;
      customFrom = null;
      customTo = null;
    }
    if (from != null && to != null) {
      customFrom = from;
      customTo = to;
    }
    if (isOfflineDemo) {
      notifyListeners();
      return;
    }
    final q = (customFrom != null && customTo != null)
        ? 'from=$customFrom&to=$customTo'
        : 'preset=$activePreset';
    final res = await _http(
      'GET',
      '$apiBaseUrl/api/commercial/dashboard?$q',
      headers: _authHeaders,
    );
    if (res.statusCode == 200) {
      dashboard = DashboardData.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
      notifyListeners();
    }
  }

  Future<void> loadAnalytics() async {
    if (isOfflineDemo) return;
    final q = (customFrom != null && customTo != null)
        ? 'from=$customFrom&to=$customTo'
        : 'preset=$activePreset';
    final responses = await Future.wait([
      _http('GET', '$apiBaseUrl/api/commercial/analytics/sales?$q',
          headers: _authHeaders),
      _http('GET', '$apiBaseUrl/api/commercial/analytics/purchases-stock?$q',
          headers: _authHeaders),
      _http('GET', '$apiBaseUrl/api/commercial/analytics/treasury?$q',
          headers: _authHeaders),
      _http('GET', '$apiBaseUrl/api/commercial/analytics/objectives?year=$objectivesYear',
          headers: _authHeaders),
    ]);
    if (responses[0].statusCode == 200) {
      analyticsSales = jsonDecode(responses[0].body) as Map<String, dynamic>;
    }
    if (responses[1].statusCode == 200) {
      analyticsPurchases =
          jsonDecode(responses[1].body) as Map<String, dynamic>;
    }
    if (responses[2].statusCode == 200) {
      analyticsTreasury =
          jsonDecode(responses[2].body) as Map<String, dynamic>;
    }
    if (responses[3].statusCode == 200) {
      analyticsObjectives =
          jsonDecode(responses[3].body) as Map<String, dynamic>;
    }
    notifyListeners();
  }

  Future<void> loadClients() async {
    if (isOfflineDemo) return;
    final res =
        await _http('GET', '$apiBaseUrl/api/commercial/clients', headers: _authHeaders);
    if (res.statusCode == 200) {
      final list = (jsonDecode(res.body)['clients'] as List?) ?? const [];
      clients = list
          .whereType<Map>()
          .map((m) => CommercialClient.fromJson(m.cast<String, dynamic>()))
          .toList();
    }
  }

  Future<String?> createClient({
    required String name,
    bool isB2b = false,
    String nif = '',
    String rc = '',
    String phone = '',
    String address = '',
    String city = 'Nouakchott',
    double creditLimitMru = 0,
  }) async {
    if (name.trim().isEmpty) return 'Nom du client requis.';
    if (isOfflineDemo) {
      clients.insert(
        0,
        CommercialClient(
          id: clients.length + 1,
          code: 'CLI-${(clients.length + 1).toString().padLeft(4, '0')}',
          name: name.trim(),
          isB2b: isB2b,
          nif: nif.trim(),
          rc: rc.trim(),
          phone: phone.trim(),
          address: address.trim(),
          city: city.trim(),
          creditLimitMru: creditLimitMru,
        ),
      );
      notifyListeners();
      return null;
    }
    final res = await _http(
      'POST',
      '$apiBaseUrl/api/commercial/clients',
      headers: _authHeaders,
      body: jsonEncode({
        'name': name.trim(),
        'isB2b': isB2b,
        'nif': nif.trim(),
        'rc': rc.trim(),
        'phone': phone.trim(),
        'address': address.trim(),
        'city': city.trim(),
        'creditLimitMru': creditLimitMru,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      await loadClients();
      await loadDashboard();
      notifyListeners();
      return null;
    }
    return _extractErr(res);
  }

  Future<String?> updateClient(
    int id, {
    required String name,
    bool isB2b = false,
    String nif = '',
    String rc = '',
    String phone = '',
    String address = '',
    String city = 'Nouakchott',
    int paymentTermsDays = 0,
    double creditLimitMru = 0,
  }) async {
    if (name.trim().isEmpty) return 'Nom du client requis.';
    if (isOfflineDemo) {
      final idx = clients.indexWhere((c) => c.id == id);
      if (idx >= 0) {
        final old = clients[idx];
        clients[idx] = CommercialClient(
          id: old.id,
          code: old.code,
          name: name.trim(),
          isB2b: isB2b,
          nif: nif.trim(),
          rc: rc.trim(),
          phone: phone.trim(),
          address: address.trim(),
          city: city.trim(),
          paymentTermsDays: paymentTermsDays,
          creditLimitMru: creditLimitMru,
          karniDebtMru: old.karniDebtMru,
          invoiceEncoursMru: old.invoiceEncoursMru,
          encoursTtcMru: old.encoursTtcMru,
        );
        notifyListeners();
      }
      return null;
    }
    final res = await _http(
      'PATCH',
      '$apiBaseUrl/api/commercial/clients/$id',
      headers: _authHeaders,
      body: jsonEncode({
        'name': name.trim(),
        'isB2b': isB2b,
        'nif': nif.trim(),
        'rc': rc.trim(),
        'phone': phone.trim(),
        'address': address.trim(),
        'city': city.trim(),
        'paymentTermsDays': paymentTermsDays,
        'creditLimitMru': creditLimitMru,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      await loadClients();
      notifyListeners();
      return null;
    }
    return _extractErr(res);
  }

  Future<String?> deleteClient(int id) async {
    if (isOfflineDemo) {
      clients.removeWhere((c) => c.id == id);
      notifyListeners();
      return null;
    }
    final res = await _http(
      'DELETE',
      '$apiBaseUrl/api/commercial/clients/$id',
      headers: _authHeaders,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      await loadClients();
      notifyListeners();
      return null;
    }
    return _extractErr(res);
  }

  Future<String?> karniPayClient(
      int clientId, double amountMru, String payMethod) async {
    if (amountMru <= 0) return 'Montant invalide.';
    if (isOfflineDemo) {
      final idx = clients.indexWhere((c) => c.id == clientId);
      if (idx >= 0) {
        final c = clients[idx];
        final applied = amountMru > c.karniDebtMru ? c.karniDebtMru : amountMru;
        final newDebt = (c.karniDebtMru - applied).clamp(0.0, double.infinity);
        clients[idx] = CommercialClient(
          id: c.id,
          code: c.code,
          name: c.name,
          isB2b: c.isB2b,
          nif: c.nif,
          rc: c.rc,
          phone: c.phone,
          address: c.address,
          city: c.city,
          paymentTermsDays: c.paymentTermsDays,
          creditLimitMru: c.creditLimitMru,
          karniDebtMru: newDebt,
          invoiceEncoursMru: c.invoiceEncoursMru,
          encoursTtcMru: newDebt + c.invoiceEncoursMru,
        );
        _recordOfflineTreasury(
          direction: 'IN',
          amountMru: applied,
          payMethod: payMethod,
          label: 'Règlement Karni · ${c.name}',
        );
        notifyListeners();
      }
      return null;
    }
    final res = await _http(
      'POST',
      '$apiBaseUrl/api/commercial/clients/$clientId/karni-pay',
      headers: _authHeaders,
      body: jsonEncode({'amountMru': amountMru, 'payMethod': payMethod}),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      await Future.wait([loadClients(), loadTreasury(), loadDashboard()]);
      notifyListeners();
      return null;
    }
    return _extractErr(res);
  }

  Future<void> loadSuppliers() async {
    if (isOfflineDemo) return;
    final res = await _http('GET', '$apiBaseUrl/api/commercial/suppliers',
        headers: _authHeaders);
    if (res.statusCode == 200) {
      final list = (jsonDecode(res.body)['suppliers'] as List?) ?? const [];
      suppliers = list
          .whereType<Map>()
          .map((m) => CommercialSupplier.fromJson(m.cast<String, dynamic>()))
          .toList();
    }
  }

  Future<String?> createSupplier({
    required String name,
    String nif = '',
    String phone = '',
    String city = 'Nouakchott',
    int paymentTermsDays = 30,
  }) async {
    if (name.trim().isEmpty) return 'Nom du fournisseur requis.';
    if (isOfflineDemo) {
      suppliers.insert(
        0,
        CommercialSupplier(
          id: suppliers.length + 1,
          code: 'FRN-${(suppliers.length + 1).toString().padLeft(4, '0')}',
          name: name.trim(),
          nif: nif.trim(),
          phone: phone.trim(),
          city: city.trim(),
          paymentTermsDays: paymentTermsDays,
        ),
      );
      notifyListeners();
      return null;
    }
    final res = await _http(
      'POST',
      '$apiBaseUrl/api/commercial/suppliers',
      headers: _authHeaders,
      body: jsonEncode({
        'name': name.trim(),
        'nif': nif.trim(),
        'phone': phone.trim(),
        'city': city.trim(),
        'paymentTermsDays': paymentTermsDays,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      await loadSuppliers();
      notifyListeners();
      return null;
    }
    return _extractErr(res);
  }

  Future<String?> updateSupplier(
    int id, {
    required String name,
    String nif = '',
    String rc = '',
    String phone = '',
    String city = 'Nouakchott',
    int paymentTermsDays = 30,
  }) async {
    if (name.trim().isEmpty) return 'Nom du fournisseur requis.';
    if (isOfflineDemo) {
      final idx = suppliers.indexWhere((s) => s.id == id);
      if (idx >= 0) {
        final old = suppliers[idx];
        suppliers[idx] = CommercialSupplier(
          id: old.id,
          code: old.code,
          name: name.trim(),
          nif: nif.trim(),
          rc: rc.trim(),
          phone: phone.trim(),
          city: city.trim(),
          paymentTermsDays: paymentTermsDays,
          balanceDueMru: old.balanceDueMru,
        );
        notifyListeners();
      }
      return null;
    }
    final res = await _http(
      'PATCH',
      '$apiBaseUrl/api/commercial/suppliers/$id',
      headers: _authHeaders,
      body: jsonEncode({
        'name': name.trim(),
        'nif': nif.trim(),
        'rc': rc.trim(),
        'phone': phone.trim(),
        'city': city.trim(),
        'paymentTermsDays': paymentTermsDays,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      await loadSuppliers();
      notifyListeners();
      return null;
    }
    return _extractErr(res);
  }

  Future<String?> deleteSupplier(int id) async {
    if (isOfflineDemo) {
      suppliers.removeWhere((s) => s.id == id);
      notifyListeners();
      return null;
    }
    final res = await _http(
      'DELETE',
      '$apiBaseUrl/api/commercial/suppliers/$id',
      headers: _authHeaders,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      await loadSuppliers();
      notifyListeners();
      return null;
    }
    return _extractErr(res);
  }

  Future<void> loadArticles() async {
    if (isOfflineDemo) return;
    final res = await _http('GET', '$apiBaseUrl/api/commercial/articles',
        headers: _authHeaders);
    if (res.statusCode == 200) {
      final list = (jsonDecode(res.body)['articles'] as List?) ?? const [];
      articles = list
          .whereType<Map>()
          .map((m) => CommercialArticle.fromJson(m.cast<String, dynamic>()))
          .toList();
    }
    final mRes = await _http(
        'GET', '$apiBaseUrl/api/commercial/stock-movements',
        headers: _authHeaders);
    if (mRes.statusCode == 200) {
      final list = (jsonDecode(mRes.body)['movements'] as List?) ?? const [];
      stockMovements = list
          .whereType<Map>()
          .map((m) => StockMovement.fromJson(m.cast<String, dynamic>()))
          .toList();
    }
  }

  Future<String?> createArticle({
    required String sku,
    required String name,
    String category = 'Général',
    String unit = 'unité',
    required double priceRetailHt,
    double priceWholeHt = 0,
    double priceCostMru = 0,
    double stockQty = 0,
    double minStock = 0,
    bool isExempt = false,
  }) async {
    if (sku.trim().isEmpty || name.trim().isEmpty) {
      return 'SKU et désignation requis.';
    }
    if (isOfflineDemo) {
      articles.insert(
        0,
        CommercialArticle(
          id: articles.length + 1,
          sku: sku.trim(),
          name: name.trim(),
          category: category,
          unit: unit,
          priceRetailHt: priceRetailHt,
          priceWholeHt: priceWholeHt > 0 ? priceWholeHt : priceRetailHt,
          priceRetailTtc: isExempt ? priceRetailHt : priceRetailHt * 1.16,
          priceCostMru: priceCostMru,
          pmpCostMru: priceCostMru,
          stockQty: stockQty,
          minStock: minStock,
          tvaRate: isExempt ? 0 : 16,
          isExempt: isExempt,
          stockValuePmpMru: stockQty * priceCostMru,
          isLowStock: stockQty <= minStock,
        ),
      );
      notifyListeners();
      return null;
    }
    final res = await _http(
      'POST',
      '$apiBaseUrl/api/commercial/articles',
      headers: _authHeaders,
      body: jsonEncode({
        'sku': sku.trim(),
        'name': name.trim(),
        'category': category.trim(),
        'unit': unit.trim(),
        'priceRetailHt': priceRetailHt,
        'priceWholeHt': priceWholeHt > 0 ? priceWholeHt : priceRetailHt,
        'priceCostMru': priceCostMru,
        'stockQty': stockQty,
        'minStock': minStock,
        'tvaRate': isExempt ? 0 : 16,
        'isExempt': isExempt,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      await loadArticles();
      await loadDashboard();
      notifyListeners();
      return null;
    }
    return _extractErr(res);
  }

  Future<String?> updateArticle(
    int id, {
    required String sku,
    String barcode = '',
    required String name,
    String category = 'Général',
    String unit = 'unité',
    required double priceRetailHt,
    double priceWholeHt = 0,
    double priceCostMru = 0,
    double minStock = 0,
    bool isExempt = false,
  }) async {
    if (sku.trim().isEmpty || name.trim().isEmpty) {
      return 'SKU et désignation requis.';
    }
    final wholeHt = priceWholeHt > 0 ? priceWholeHt : priceRetailHt;
    if (isOfflineDemo) {
      final idx = articles.indexWhere((a) => a.id == id);
      if (idx >= 0) {
        final old = articles[idx];
        final pmp = priceCostMru > 0 ? priceCostMru : old.pmpCostMru;
        articles[idx] = CommercialArticle(
          id: old.id,
          sku: sku.trim(),
          barcode: barcode.trim(),
          name: name.trim(),
          category: category.trim(),
          unit: unit.trim(),
          priceRetailHt: priceRetailHt,
          priceWholeHt: wholeHt,
          priceRetailTtc: isExempt ? priceRetailHt : priceRetailHt * 1.16,
          priceWholeTtc: isExempt ? wholeHt : wholeHt * 1.16,
          priceCostMru: priceCostMru,
          pmpCostMru: pmp,
          stockQty: old.stockQty,
          minStock: minStock,
          tvaRate: isExempt ? 0 : 16,
          isExempt: isExempt,
          stockValuePmpMru: old.stockQty * pmp,
          isLowStock: old.stockQty <= minStock,
        );
        notifyListeners();
      }
      return null;
    }
    final res = await _http(
      'PATCH',
      '$apiBaseUrl/api/commercial/articles/$id',
      headers: _authHeaders,
      body: jsonEncode({
        'sku': sku.trim(),
        'barcode': barcode.trim(),
        'name': name.trim(),
        'category': category.trim(),
        'unit': unit.trim(),
        'priceRetailHt': priceRetailHt,
        'priceWholeHt': wholeHt,
        'priceCostMru': priceCostMru,
        'minStock': minStock,
        'tvaRate': isExempt ? 0 : 16,
        'isExempt': isExempt,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      await loadArticles();
      notifyListeners();
      return null;
    }
    return _extractErr(res);
  }

  Future<String?> deleteArticle(int id) async {
    if (isOfflineDemo) {
      articles.removeWhere((a) => a.id == id);
      notifyListeners();
      return null;
    }
    final res = await _http(
      'DELETE',
      '$apiBaseUrl/api/commercial/articles/$id',
      headers: _authHeaders,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      await loadArticles();
      notifyListeners();
      return null;
    }
    return _extractErr(res);
  }

  Future<String?> adjustArticleStock(
      int articleId, double qtyDelta, String reason) async {
    if (qtyDelta == 0) return 'Variation de stock invalide.';
    if (isOfflineDemo) {
      final idx = articles.indexWhere((a) => a.id == articleId);
      if (idx >= 0) {
        final a = articles[idx];
        final newQty = (a.stockQty + qtyDelta).clamp(0.0, double.infinity);
        articles[idx] = CommercialArticle(
          id: a.id,
          sku: a.sku,
          barcode: a.barcode,
          name: a.name,
          category: a.category,
          unit: a.unit,
          priceRetailHt: a.priceRetailHt,
          priceWholeHt: a.priceWholeHt,
          priceRetailTtc: a.priceRetailTtc,
          priceWholeTtc: a.priceWholeTtc,
          priceCostMru: a.priceCostMru,
          pmpCostMru: a.pmpCostMru,
          stockQty: newQty,
          minStock: a.minStock,
          tvaRate: a.tvaRate,
          isExempt: a.isExempt,
          stockValuePmpMru: newQty * a.pmpCostMru,
          isLowStock: newQty <= a.minStock,
        );
        stockMovements.insert(
          0,
          StockMovement(
            id: stockMovements.length + 1,
            articleId: a.id,
            sku: a.sku,
            articleName: a.name,
            movementType: qtyDelta > 0 ? 'AJUST_IN' : 'AJUST_OUT',
            qtyDelta: qtyDelta,
            stockAfter: newQty,
            unitCostMru: a.pmpCostMru,
            pmpAfterMru: a.pmpCostMru,
            reason: reason.trim().isEmpty ? 'Ajustement manuel' : reason.trim(),
            createdAt: DateTime.now().toIso8601String().substring(0, 16),
          ),
        );
        notifyListeners();
      }
      return null;
    }
    final res = await _http(
      'POST',
      '$apiBaseUrl/api/commercial/articles/$articleId/adjust-stock',
      headers: _authHeaders,
      body: jsonEncode({'qtyDelta': qtyDelta, 'reason': reason}),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      await Future.wait([loadArticles(), loadDashboard()]);
      notifyListeners();
      return null;
    }
    return _extractErr(res);
  }

  Future<void> loadSalesDocs() async {
    if (isOfflineDemo) return;
    final res = await _http('GET', '$apiBaseUrl/api/commercial/sales-docs',
        headers: _authHeaders);
    if (res.statusCode == 200) {
      final list = (jsonDecode(res.body)['docs'] as List?) ?? const [];
      salesDocs = list
          .whereType<Map>()
          .map((m) => CommercialDoc.fromJson(m.cast<String, dynamic>()))
          .toList();
    }
  }

  Future<CommercialDoc?> getSalesDocDetail(int id) async {
    if (isOfflineDemo) {
      final found = salesDocs.where((d) => d.id == id);
      return found.isNotEmpty ? found.first : null;
    }
    final res = await _http('GET', '$apiBaseUrl/api/commercial/sales-docs/$id',
        headers: _authHeaders);
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final docMap = (data['doc'] as Map?)?.cast<String, dynamic>() ?? data;
      final rawLines = (data['lines'] as List?) ?? const [];
      final parsedLines = rawLines
          .whereType<Map>()
          .map((m) => DocLineModel.fromJson(m.cast<String, dynamic>()))
          .toList();
      return CommercialDoc.fromJson(docMap, lines: parsedLines);
    }
    return null;
  }

  Future<String?> deleteSalesDoc(int id) async {
    if (isOfflineDemo) {
      salesDocs.removeWhere((d) => d.id == id);
      notifyListeners();
      return null;
    }
    final res = await _http(
      'DELETE',
      '$apiBaseUrl/api/commercial/sales-docs/$id',
      headers: _authHeaders,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      await loadSalesDocs();
      notifyListeners();
      return null;
    }
    return _extractErr(res);
  }

  Future<String?> createSalesDoc({
    required String docType,
    required int clientId,
    required List<Map<String, dynamic>> lines,
    double globalDiscountPct = 0,
    bool validateNow = true,
    int? sourceDocId,
    bool restock = true,
    String? dueDate,
  }) async {
    if (lines.isEmpty) return 'Ajoutez au moins une ligne article.';
    if (isOfflineDemo) {
      final cli = clients.firstWhere((c) => c.id == clientId);
      double totalHt = 0;
      double totalTva = 0;
      double totalCost = 0;
      final builtLines = <DocLineModel>[];
      for (final l in lines) {
        final art = articles.firstWhere((a) => a.id == l['articleId']);
        final qty = (l['qty'] as num).toDouble();
        final pu = (l['unitPriceHtMru'] as num?)?.toDouble() ?? art.priceRetailHt;
        final disc = (l['discountPct'] as num?)?.toDouble() ?? 0;
        final lHt = CommercialMath.computeLineHt(
                qty: qty, unitPriceHt: pu, discountPct: disc) *
            (1 - globalDiscountPct / 100);
        final lTva = CommercialMath.computeLineTva(
            lineHt: lHt, isExempt: art.isExempt, tvaRate: art.tvaRate);
        totalHt += lHt;
        totalTva += lTva;
        totalCost += qty * art.pmpCostMru;
        builtLines.add(DocLineModel(
          articleId: art.id,
          sku: art.sku,
          designation: art.name,
          qty: qty,
          unitPriceHtMru: pu,
          discountPct: disc,
          tvaRate: art.tvaRate,
          isExempt: art.isExempt,
          lineHtMru: lHt,
          lineTvaMru: lTva,
          lineTtcMru: lHt + lTva,
        ));
        if (validateNow && (docType == 'BL' || docType == 'FACTURE')) {
          _applyOfflineStockDelta(art.id, -qty, 'VENTE', '$docType-${salesDocs.length + 1}');
        } else if (validateNow && docType == 'AVOIR' && restock) {
          _applyOfflineStockDelta(art.id, qty, 'AVOIR_CLIENT', 'AV-${salesDocs.length + 1}');
        }
      }
      final issue = DateTime.now().toIso8601String().substring(0, 10);
      salesDocs.insert(
        0,
        CommercialDoc(
          id: salesDocs.length + 100,
          docType: docType,
          docNumber: '$docType-${DateTime.now().year}-${(salesDocs.length + 1).toString().padLeft(4, '0')}',
          status: validateNow ? 'VALIDEE' : 'BROUILLON',
          partyId: cli.id,
          partyName: cli.name,
          partyNif: cli.nif,
          issueDate: issue,
          dueDate: dueDate ?? issue,
          globalDiscountPct: globalDiscountPct,
          totalHtMru: totalHt,
          totalTvaMru: totalTva,
          totalTtcMru: totalHt + totalTva,
          grossMarginMru: totalHt - totalCost,
          remainingMru: totalHt + totalTva,
          stockApplied: validateNow && (docType == 'BL' || docType == 'FACTURE'),
          lines: builtLines,
        ),
      );
      notifyListeners();
      return null;
    }
    final res = await _http(
      'POST',
      '$apiBaseUrl/api/commercial/sales-docs',
      headers: _authHeaders,
      body: jsonEncode({
        'docType': docType,
        'clientId': clientId,
        'globalDiscountPct': globalDiscountPct,
        'validateNow': validateNow,
        if (dueDate != null && dueDate.isNotEmpty) 'dueDate': dueDate,
        if (sourceDocId != null) 'sourceDocId': sourceDocId,
        if (docType == 'AVOIR') 'restock': restock,
        'lines': lines,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      await Future.wait(
          [loadSalesDocs(), loadArticles(), loadClients(), loadDashboard()]);
      notifyListeners();
      return null;
    }
    return _extractErr(res);
  }

  Future<String?> validateSalesDoc(int id) async {
    if (isOfflineDemo) {
      final idx = salesDocs.indexWhere((d) => d.id == id);
      if (idx >= 0) {
        final d = salesDocs[idx];
        if (!d.stockApplied && (d.docType == 'BL' || d.docType == 'FACTURE')) {
          for (final l in d.lines) {
            _applyOfflineStockDelta(l.articleId, -l.qty, 'VENTE', d.docNumber);
          }
        }
        salesDocs[idx] = CommercialDoc(
          id: d.id,
          docType: d.docType,
          docNumber: d.docNumber,
          status: 'VALIDEE',
          partyId: d.partyId,
          partyName: d.partyName,
          partyNif: d.partyNif,
          issueDate: d.issueDate,
          dueDate: d.dueDate,
          globalDiscountPct: d.globalDiscountPct,
          totalHtMru: d.totalHtMru,
          totalTvaMru: d.totalTvaMru,
          totalTtcMru: d.totalTtcMru,
          grossMarginMru: d.grossMarginMru,
          paidMru: d.paidMru,
          remainingMru: d.remainingMru,
          stockApplied: true,
          lines: d.lines,
        );
        notifyListeners();
      }
      return null;
    }
    final res = await _http(
      'POST',
      '$apiBaseUrl/api/commercial/sales-docs/$id/validate',
      headers: _authHeaders,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      await Future.wait(
          [loadSalesDocs(), loadArticles(), loadClients(), loadDashboard()]);
      notifyListeners();
      return null;
    }
    return _extractErr(res);
  }

  Future<String?> convertSalesDoc(int id, String targetType) async {
    if (isOfflineDemo) {
      final src = salesDocs.firstWhere((d) => d.id == id);
      salesDocs.insert(
        0,
        CommercialDoc(
          id: salesDocs.length + 200,
          docType: targetType,
          docNumber: '$targetType-${DateTime.now().year}-${(salesDocs.length + 1).toString().padLeft(4, '0')}',
          status: 'VALIDEE',
          partyId: src.partyId,
          partyName: src.partyName,
          partyNif: src.partyNif,
          issueDate: DateTime.now().toIso8601String().substring(0, 10),
          dueDate: src.dueDate,
          globalDiscountPct: src.globalDiscountPct,
          totalHtMru: src.totalHtMru,
          totalTvaMru: src.totalTvaMru,
          totalTtcMru: src.totalTtcMru,
          grossMarginMru: src.grossMarginMru,
          remainingMru: src.totalTtcMru,
          stockApplied: src.stockApplied || targetType == 'BL' || targetType == 'FACTURE',
          lines: src.lines,
        ),
      );
      notifyListeners();
      return null;
    }
    final res = await _http(
      'POST',
      '$apiBaseUrl/api/commercial/sales-docs/$id/convert',
      headers: _authHeaders,
      body: jsonEncode({'targetType': targetType}),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      await Future.wait(
          [loadSalesDocs(), loadArticles(), loadClients(), loadDashboard()]);
      notifyListeners();
      return null;
    }
    return _extractErr(res);
  }

  Future<String?> paySalesDoc(
    int id, {
    required String payMethod,
    required double amountMru,
    String ref = '',
    String? dueDate,
  }) async {
    if (amountMru <= 0) return 'Montant invalide.';
    if (isOfflineDemo) {
      final idx = salesDocs.indexWhere((d) => d.id == id);
      if (idx >= 0) {
        final d = salesDocs[idx];
        final applied = amountMru > d.remainingMru ? d.remainingMru : amountMru;
        final newPaid = d.paidMru + applied;
        final newRem = (d.totalTtcMru - newPaid).clamp(0.0, double.infinity);
        salesDocs[idx] = CommercialDoc(
          id: d.id,
          docType: d.docType,
          docNumber: d.docNumber,
          status: newRem <= 0.01 ? 'PAYEE' : 'PARTIELLE',
          partyId: d.partyId,
          partyName: d.partyName,
          partyNif: d.partyNif,
          issueDate: d.issueDate,
          dueDate: d.dueDate,
          globalDiscountPct: d.globalDiscountPct,
          totalHtMru: d.totalHtMru,
          totalTvaMru: d.totalTvaMru,
          totalTtcMru: d.totalTtcMru,
          grossMarginMru: d.grossMarginMru,
          paidMru: newPaid,
          remainingMru: newRem,
          stockApplied: d.stockApplied,
          lines: d.lines,
        );
        _recordOfflineTreasury(
          direction: 'IN',
          amountMru: applied,
          payMethod: payMethod,
          label: 'Encaissement ${d.docNumber} (${d.partyName})',
        );
        notifyListeners();
      }
      return null;
    }
    final res = await _http(
      'POST',
      '$apiBaseUrl/api/commercial/sales-docs/$id/payments',
      headers: _authHeaders,
      body: jsonEncode({
        'payMethod': payMethod,
        'amountMru': amountMru,
        'ref': ref,
        if (dueDate != null && dueDate.isNotEmpty) 'dueDate': dueDate,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      await Future.wait([
        loadSalesDocs(),
        loadClients(),
        loadTreasury(),
        loadCheques(),
        loadDashboard(),
      ]);
      notifyListeners();
      return null;
    }
    return _extractErr(res);
  }

  Future<void> loadPurchaseDocs() async {
    if (isOfflineDemo) return;
    final res = await _http('GET', '$apiBaseUrl/api/commercial/purchase-docs',
        headers: _authHeaders);
    if (res.statusCode == 200) {
      final list = (jsonDecode(res.body)['docs'] as List?) ?? const [];
      purchaseDocs = list
          .whereType<Map>()
          .map((m) => CommercialDoc.fromJson(m.cast<String, dynamic>()))
          .toList();
    }
  }

  Future<CommercialDoc?> getPurchaseDocDetail(int id) async {
    if (isOfflineDemo) {
      final found = purchaseDocs.where((d) => d.id == id);
      return found.isNotEmpty ? found.first : null;
    }
    final res = await _http(
        'GET', '$apiBaseUrl/api/commercial/purchase-docs/$id',
        headers: _authHeaders);
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final docMap = (data['doc'] as Map?)?.cast<String, dynamic>() ?? data;
      final rawLines = (data['lines'] as List?) ?? const [];
      final parsedLines = rawLines
          .whereType<Map>()
          .map((m) => DocLineModel.fromJson(m.cast<String, dynamic>()))
          .toList();
      return CommercialDoc.fromJson(docMap, lines: parsedLines);
    }
    return null;
  }

  Future<String?> validatePurchaseDoc(int id) async {
    if (isOfflineDemo) {
      final idx = purchaseDocs.indexWhere((d) => d.id == id);
      if (idx >= 0) {
        final d = purchaseDocs[idx];
        if (!d.stockApplied &&
            (d.docType == 'RECEPTION' || d.docType == 'FACTURE_ACHAT')) {
          for (final l in d.lines) {
            _applyOfflineStockDelta(l.articleId, l.qty, 'RECEPTION',
                d.docNumber, incomingCostHt: l.unitPriceHtMru);
          }
        }
        purchaseDocs[idx] = CommercialDoc(
          id: d.id,
          docType: d.docType,
          docNumber: d.docNumber,
          status: 'VALIDEE',
          partyId: d.partyId,
          partyName: d.partyName,
          partyNif: d.partyNif,
          issueDate: d.issueDate,
          dueDate: d.dueDate,
          totalHtMru: d.totalHtMru,
          totalTvaMru: d.totalTvaMru,
          totalTtcMru: d.totalTtcMru,
          paidMru: d.paidMru,
          remainingMru: d.remainingMru,
          stockApplied: true,
          lines: d.lines,
        );
        notifyListeners();
      }
      return null;
    }
    final res = await _http(
      'POST',
      '$apiBaseUrl/api/commercial/purchase-docs/$id/validate',
      headers: _authHeaders,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      await Future.wait(
          [loadPurchaseDocs(), loadArticles(), loadSuppliers(), loadDashboard()]);
      notifyListeners();
      return null;
    }
    return _extractErr(res);
  }

  Future<String?> deletePurchaseDoc(int id) async {
    if (isOfflineDemo) {
      purchaseDocs.removeWhere((d) => d.id == id);
      notifyListeners();
      return null;
    }
    final res = await _http(
      'DELETE',
      '$apiBaseUrl/api/commercial/purchase-docs/$id',
      headers: _authHeaders,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      await loadPurchaseDocs();
      notifyListeners();
      return null;
    }
    return _extractErr(res);
  }

  Future<String?> createPurchaseDoc({
    required String docType,
    required int supplierId,
    required List<Map<String, dynamic>> lines,
    bool validateNow = true,
    String? dueDate,
  }) async {
    if (lines.isEmpty) return 'Ajoutez au moins une ligne article.';
    if (isOfflineDemo) {
      final sup = suppliers.firstWhere((s) => s.id == supplierId);
      double totalHt = 0;
      double totalTva = 0;
      final builtLines = <DocLineModel>[];
      final numDoc =
          '$docType-${DateTime.now().year}-${(purchaseDocs.length + 1).toString().padLeft(4, '0')}';
      for (final l in lines) {
        final art = articles.firstWhere((a) => a.id == l['articleId']);
        final qty = (l['qty'] as num).toDouble();
        final pu = (l['unitCostHt'] as num?)?.toDouble() ?? art.pmpCostMru;
        final lHt = CommercialMath.computeLineHt(qty: qty, unitPriceHt: pu);
        final lTva = CommercialMath.computeLineTva(
            lineHt: lHt, isExempt: art.isExempt, tvaRate: art.tvaRate);
        totalHt += lHt;
        totalTva += lTva;
        builtLines.add(DocLineModel(
          articleId: art.id,
          sku: art.sku,
          designation: art.name,
          qty: qty,
          unitPriceHtMru: pu,
          tvaRate: art.tvaRate,
          isExempt: art.isExempt,
          lineHtMru: lHt,
          lineTvaMru: lTva,
          lineTtcMru: lHt + lTva,
        ));
        if (validateNow &&
            (docType == 'RECEPTION' || docType == 'FACTURE_ACHAT')) {
          _applyOfflineStockDelta(art.id, qty, 'RECEPTION', numDoc,
              incomingCostHt: pu);
        }
      }
      final issue = DateTime.now().toIso8601String().substring(0, 10);
      purchaseDocs.insert(
        0,
        CommercialDoc(
          id: purchaseDocs.length + 100,
          docType: docType,
          docNumber: numDoc,
          status: validateNow ? 'VALIDEE' : 'BROUILLON',
          partyId: sup.id,
          partyName: sup.name,
          partyNif: sup.nif,
          issueDate: issue,
          dueDate: dueDate ?? issue,
          totalHtMru: totalHt,
          totalTvaMru: totalTva,
          totalTtcMru: totalHt + totalTva,
          remainingMru: totalHt + totalTva,
          stockApplied:
              validateNow && (docType == 'RECEPTION' || docType == 'FACTURE_ACHAT'),
          lines: builtLines,
        ),
      );
      notifyListeners();
      return null;
    }
    final res = await _http(
      'POST',
      '$apiBaseUrl/api/commercial/purchase-docs',
      headers: _authHeaders,
      body: jsonEncode({
        'docType': docType,
        'supplierId': supplierId,
        'validateNow': validateNow,
        if (dueDate != null && dueDate.isNotEmpty) 'dueDate': dueDate,
        'lines': lines,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      await Future.wait(
          [loadPurchaseDocs(), loadArticles(), loadSuppliers(), loadDashboard()]);
      notifyListeners();
      return null;
    }
    return _extractErr(res);
  }

  Future<String?> convertPurchaseDoc(int id, String targetType) async {
    if (isOfflineDemo) {
      final src = purchaseDocs.firstWhere((d) => d.id == id);
      final numDoc =
          '$targetType-${DateTime.now().year}-${(purchaseDocs.length + 1).toString().padLeft(4, '0')}';
      if (!src.stockApplied && targetType == 'RECEPTION') {
        for (final l in src.lines) {
          _applyOfflineStockDelta(l.articleId, l.qty, 'RECEPTION', numDoc,
              incomingCostHt: l.unitPriceHtMru);
        }
      }
      purchaseDocs.insert(
        0,
        CommercialDoc(
          id: purchaseDocs.length + 200,
          docType: targetType,
          docNumber: numDoc,
          status: 'VALIDEE',
          partyId: src.partyId,
          partyName: src.partyName,
          partyNif: src.partyNif,
          issueDate: DateTime.now().toIso8601String().substring(0, 10),
          dueDate: src.dueDate,
          totalHtMru: src.totalHtMru,
          totalTvaMru: src.totalTvaMru,
          totalTtcMru: src.totalTtcMru,
          remainingMru: src.totalTtcMru,
          stockApplied: src.stockApplied || targetType == 'RECEPTION',
          lines: src.lines,
        ),
      );
      notifyListeners();
      return null;
    }
    final res = await _http(
      'POST',
      '$apiBaseUrl/api/commercial/purchase-docs/$id/convert',
      headers: _authHeaders,
      body: jsonEncode({'targetType': targetType, 'validateNow': true}),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      await Future.wait(
          [loadPurchaseDocs(), loadArticles(), loadSuppliers(), loadDashboard()]);
      notifyListeners();
      return null;
    }
    return _extractErr(res);
  }

  Future<String?> payPurchaseDoc(
      int id, String payMethod, double amountMru) async {
    if (amountMru <= 0) return 'Montant invalide.';
    if (isOfflineDemo) {
      final idx = purchaseDocs.indexWhere((d) => d.id == id);
      if (idx >= 0) {
        final d = purchaseDocs[idx];
        final applied = amountMru > d.remainingMru ? d.remainingMru : amountMru;
        final newPaid = d.paidMru + applied;
        final newRem = (d.totalTtcMru - newPaid).clamp(0.0, double.infinity);
        purchaseDocs[idx] = CommercialDoc(
          id: d.id,
          docType: d.docType,
          docNumber: d.docNumber,
          status: newRem <= 0.01 ? 'PAYEE' : 'PARTIELLE',
          partyId: d.partyId,
          partyName: d.partyName,
          partyNif: d.partyNif,
          issueDate: d.issueDate,
          dueDate: d.dueDate,
          totalHtMru: d.totalHtMru,
          totalTvaMru: d.totalTvaMru,
          totalTtcMru: d.totalTtcMru,
          paidMru: newPaid,
          remainingMru: newRem,
          stockApplied: d.stockApplied,
          lines: d.lines,
        );
        _recordOfflineTreasury(
          direction: 'OUT',
          amountMru: applied,
          payMethod: payMethod,
          label: 'Règlement ${d.docNumber} (${d.partyName})',
        );
        notifyListeners();
      }
      return null;
    }
    final res = await _http(
      'POST',
      '$apiBaseUrl/api/commercial/purchase-docs/$id/payments',
      headers: _authHeaders,
      body: jsonEncode({'payMethod': payMethod, 'amountMru': amountMru}),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      await Future.wait([
        loadPurchaseDocs(),
        loadSuppliers(),
        loadTreasury(),
        loadDashboard(),
      ]);
      notifyListeners();
      return null;
    }
    return _extractErr(res);
  }

  Future<void> loadPosData() async {
    if (isOfflineDemo) return;
    final sRes = await _http('GET', '$apiBaseUrl/api/commercial/pos/sessions',
        headers: _authHeaders);
    if (sRes.statusCode == 200) {
      final list = (jsonDecode(sRes.body)['sessions'] as List?) ?? const [];
      posSessions = list
          .whereType<Map>()
          .map((m) => CommercialPosSession.fromJson(m.cast<String, dynamic>()))
          .toList();
      openPosSession =
          posSessions.where((s) => s.status == 'OPEN').firstOrNull;
    }
    final tRes = await _http('GET', '$apiBaseUrl/api/commercial/pos/tickets',
        headers: _authHeaders);
    if (tRes.statusCode == 200) {
      final list = (jsonDecode(tRes.body)['tickets'] as List?) ?? const [];
      posTickets = list
          .whereType<Map>()
          .map((m) => CommercialPosTicket.fromJson(m.cast<String, dynamic>()))
          .toList();
    }
  }

  Future<String?> openNewPosSession({
    required String registerCode,
    required String cashierName,
    required double openingFloatMru,
  }) async {
    if (isOfflineDemo) {
      openPosSession = CommercialPosSession(
        id: posSessions.length + 1,
        sessionNumber: 'SES-001',
        registerCode: registerCode,
        cashierName: cashierName,
        status: 'OPEN',
        openingFloatMru: openingFloatMru,
        expectedCashMru: openingFloatMru,
      );
      posSessions.insert(0, openPosSession!);
      notifyListeners();
      return null;
    }
    final res = await _http(
      'POST',
      '$apiBaseUrl/api/commercial/pos/sessions/open',
      headers: _authHeaders,
      body: jsonEncode({
        'registerCode': registerCode,
        'cashierName': cashierName,
        'openingFloatMru': openingFloatMru,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      await loadPosData();
      notifyListeners();
      return null;
    }
    return _extractErr(res);
  }

  Future<String?> closePosSession(int sessionId, double countedCashMru) async {
    if (isOfflineDemo) {
      openPosSession = null;
      notifyListeners();
      return null;
    }
    final res = await _http(
      'POST',
      '$apiBaseUrl/api/commercial/pos/sessions/$sessionId/close',
      headers: _authHeaders,
      body: jsonEncode({'countedCashMru': countedCashMru}),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      await Future.wait([loadPosData(), loadTreasury(), loadDashboard()]);
      notifyListeners();
      return null;
    }
    return _extractErr(res);
  }

  Future<String?> submitPosTicket({
    required List<Map<String, dynamic>> lines,
    required List<Map<String, dynamic>> payments,
    String priceTier = 'retail',
    int? clientId,
  }) async {
    if (openPosSession == null) return 'Ouvrez d\'abord une session de caisse.';
    if (lines.isEmpty) return 'Panier vide.';
    if (isOfflineDemo) {
      double ht = 0;
      double tva = 0;
      final tNum = 'TK-${(posTickets.length + 1).toString().padLeft(4, '0')}';
      for (final l in lines) {
        final art = articles.firstWhere((a) => a.id == l['articleId']);
        final qty = (l['qty'] as num).toDouble();
        final pu = priceTier == 'wholesale' ? art.priceWholeHt : art.priceRetailHt;
        final disc = (l['discountPct'] as num?)?.toDouble() ?? 0;
        final lHt = CommercialMath.computeLineHt(
            qty: qty, unitPriceHt: pu, discountPct: disc);
        final lTva = CommercialMath.computeLineTva(
            lineHt: lHt, isExempt: art.isExempt, tvaRate: art.tvaRate);
        ht += lHt;
        tva += lTva;
        _applyOfflineStockDelta(art.id, -qty, 'POS', tNum);
      }
      final ttc = ht + tva;
      double cashAdd = 0;
      final methods = <String>[];
      for (final p in payments) {
        final m = '${p['payMethod'] ?? 'Cash'}';
        final amt = (p['amountMru'] as num?)?.toDouble() ?? 0;
        methods.add(m);
        if (m == 'Cash') cashAdd += amt;
        if (m == 'Karni' && clientId != null) {
          final cIdx = clients.indexWhere((c) => c.id == clientId);
          if (cIdx >= 0) {
            final c = clients[cIdx];
            clients[cIdx] = CommercialClient(
              id: c.id,
              code: c.code,
              name: c.name,
              isB2b: c.isB2b,
              nif: c.nif,
              rc: c.rc,
              phone: c.phone,
              address: c.address,
              city: c.city,
              paymentTermsDays: c.paymentTermsDays,
              creditLimitMru: c.creditLimitMru,
              karniDebtMru: c.karniDebtMru + amt,
              invoiceEncoursMru: c.invoiceEncoursMru,
              encoursTtcMru: c.encoursTtcMru + amt,
            );
          }
        } else if (amt > 0) {
          _recordOfflineTreasury(
            direction: 'IN',
            amountMru: amt,
            payMethod: m,
            label: 'Ticket POS $tNum',
          );
        }
      }
      String customerName = 'Comptoir';
      if (clientId != null) {
        final matches = clients.where((c) => c.id == clientId);
        if (matches.isNotEmpty) customerName = matches.first.name;
      }
      posTickets.insert(
        0,
        CommercialPosTicket(
          id: posTickets.length + 100,
          ticketNumber: tNum,
          status: 'PAID',
          payMethod: methods.join(' + '),
          totalHtMru: ht,
          totalTvaMru: tva,
          totalTtcMru: ttc,
          customerName: customerName,
          createdAt: DateTime.now().toIso8601String().substring(0, 16),
        ),
      );
      final s = openPosSession!;
      openPosSession = CommercialPosSession(
        id: s.id,
        sessionNumber: s.sessionNumber,
        registerCode: s.registerCode,
        cashierName: s.cashierName,
        status: s.status,
        openingFloatMru: s.openingFloatMru,
        expectedCashMru: s.expectedCashMru + cashAdd,
        totalSalesTtcMru: s.totalSalesTtcMru + ttc,
        ticketsCount: s.ticketsCount + 1,
        openedAt: s.openedAt,
      );
      final sIdx = posSessions.indexWhere((x) => x.id == s.id);
      if (sIdx >= 0) posSessions[sIdx] = openPosSession!;
      notifyListeners();
      return null;
    }
    final res = await _http(
      'POST',
      '$apiBaseUrl/api/commercial/pos/tickets',
      headers: _authHeaders,
      body: jsonEncode({
        'sessionId': openPosSession!.id,
        'priceTier': priceTier,
        if (clientId != null) 'clientId': clientId,
        'lines': lines,
        'payments': payments,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      await Future.wait([
        loadPosData(),
        loadArticles(),
        loadClients(),
        loadTreasury(),
        loadDashboard(),
      ]);
      notifyListeners();
      return null;
    }
    return _extractErr(res);
  }

  Future<String?> voidPosTicket(int ticketId, String reason) async {
    if (isOfflineDemo) {
      final idx = posTickets.indexWhere((t) => t.id == ticketId);
      if (idx >= 0) {
        final t = posTickets[idx];
        posTickets[idx] = CommercialPosTicket(
          id: t.id,
          ticketNumber: t.ticketNumber,
          status: 'VOID',
          payMethod: t.payMethod,
          totalHtMru: t.totalHtMru,
          totalTvaMru: t.totalTvaMru,
          totalTtcMru: t.totalTtcMru,
          customerName: t.customerName,
          createdAt: t.createdAt,
        );
        notifyListeners();
      }
      return null;
    }
    final res = await _http(
      'POST',
      '$apiBaseUrl/api/commercial/pos/tickets/$ticketId/void',
      headers: _authHeaders,
      body: jsonEncode({'reason': reason}),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      await Future.wait([loadPosData(), loadArticles(), loadDashboard()]);
      notifyListeners();
      return null;
    }
    return _extractErr(res);
  }

  Future<void> loadTreasury() async {
    if (isOfflineDemo) return;
    final aRes = await _http(
        'GET', '$apiBaseUrl/api/commercial/treasury/accounts',
        headers: _authHeaders);
    if (aRes.statusCode == 200) {
      final list = (jsonDecode(aRes.body)['accounts'] as List?) ?? const [];
      treasuryAccounts = list
          .whereType<Map>()
          .map((m) => TreasuryAccount.fromJson(m.cast<String, dynamic>()))
          .toList();
    }
    final mRes = await _http(
        'GET', '$apiBaseUrl/api/commercial/treasury/movements',
        headers: _authHeaders);
    if (mRes.statusCode == 200) {
      final list = (jsonDecode(mRes.body)['movements'] as List?) ?? const [];
      treasuryMovements = list
          .whereType<Map>()
          .map((m) => TreasuryMovement.fromJson(m.cast<String, dynamic>()))
          .toList();
    }
  }

  Future<String?> createTreasuryAccount({
    required String code,
    required String name,
    required String accountType,
    String bankName = '',
    double openingBalanceMru = 0,
  }) async {
    if (code.trim().isEmpty || name.trim().isEmpty) {
      return 'Code et nom du compte requis.';
    }
    if (isOfflineDemo) {
      treasuryAccounts.add(TreasuryAccount(
        id: treasuryAccounts.length + 10,
        code: code.trim().toUpperCase(),
        name: name.trim(),
        accountType: accountType,
        bankName: bankName.trim(),
        currentBalanceMru: openingBalanceMru,
      ));
      notifyListeners();
      return null;
    }
    final res = await _http(
      'POST',
      '$apiBaseUrl/api/commercial/treasury/accounts',
      headers: _authHeaders,
      body: jsonEncode({
        'code': code.trim().toUpperCase(),
        'name': name.trim(),
        'accountType': accountType,
        'bankName': bankName.trim(),
        'openingBalanceMru': openingBalanceMru,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      await loadTreasury();
      notifyListeners();
      return null;
    }
    return _extractErr(res);
  }

  Future<String?> addTreasuryMovement({
    required int accountId,
    required String direction,
    required double amountMru,
    required String label,
    String payMethod = 'Cash',
  }) async {
    if (amountMru <= 0) return 'Montant invalide.';
    if (isOfflineDemo) {
      _recordOfflineTreasury(
        accountId: accountId,
        direction: direction,
        amountMru: amountMru,
        payMethod: payMethod,
        label: label.trim().isEmpty ? 'Mouvement manuel' : label.trim(),
      );
      notifyListeners();
      return null;
    }
    final res = await _http(
      'POST',
      '$apiBaseUrl/api/commercial/treasury/movements',
      headers: _authHeaders,
      body: jsonEncode({
        'accountId': accountId,
        'direction': direction,
        'amountMru': amountMru,
        'payMethod': payMethod,
        'label': label,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      await Future.wait([loadTreasury(), loadDashboard()]);
      notifyListeners();
      return null;
    }
    return _extractErr(res);
  }

  Future<String?> transferTreasury({
    required int fromId,
    required int toId,
    required double amountMru,
  }) async {
    if (fromId == toId) return 'Choisissez deux comptes différents.';
    if (amountMru <= 0) return 'Montant invalide.';
    if (isOfflineDemo) {
      _recordOfflineTreasury(
        accountId: fromId,
        direction: 'OUT',
        amountMru: amountMru,
        payMethod: 'Virement',
        label: 'Virement interne sortant',
      );
      _recordOfflineTreasury(
        accountId: toId,
        direction: 'IN',
        amountMru: amountMru,
        payMethod: 'Virement',
        label: 'Virement interne entrant',
      );
      notifyListeners();
      return null;
    }
    final res = await _http(
      'POST',
      '$apiBaseUrl/api/commercial/treasury/transfer',
      headers: _authHeaders,
      body: jsonEncode({
        'fromAccountId': fromId,
        'toAccountId': toId,
        'amountMru': amountMru,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      await loadTreasury();
      notifyListeners();
      return null;
    }
    return _extractErr(res);
  }

  Future<void> loadCheques() async {
    if (isOfflineDemo) return;
    final res = await _http('GET', '$apiBaseUrl/api/commercial/cheques',
        headers: _authHeaders);
    if (res.statusCode == 200) {
      final list = (jsonDecode(res.body)['cheques'] as List?) ?? const [];
      cheques = list
          .whereType<Map>()
          .map((m) => ChequeDraft.fromJson(m.cast<String, dynamic>()))
          .toList();
    }
  }

  Future<String?> createCheque({
    required String direction,
    required String instrumentType,
    required String number,
    required String dueDate,
    required double amountMru,
    String bankName = '',
    int? clientId,
    int? supplierId,
  }) async {
    if (number.trim().isEmpty || amountMru <= 0) {
      return 'Numéro et montant requis.';
    }
    if (isOfflineDemo) {
      String party = direction == 'IN' || direction == 'CLIENT'
          ? 'Client divers'
          : 'Fournisseur divers';
      if (clientId != null) {
        final m = clients.where((c) => c.id == clientId);
        if (m.isNotEmpty) party = m.first.name;
      } else if (supplierId != null) {
        final m = suppliers.where((s) => s.id == supplierId);
        if (m.isNotEmpty) party = m.first.name;
      }
      cheques.insert(
        0,
        ChequeDraft(
          id: cheques.length + 100,
          direction: direction,
          instrumentType: instrumentType,
          number: number.trim(),
          bankName: bankName.trim(),
          partyName: party,
          dueDate: dueDate,
          amountMru: amountMru,
          status: 'EN_PORTEFEUILLE',
        ),
      );
      notifyListeners();
      return null;
    }
    final res = await _http(
      'POST',
      '$apiBaseUrl/api/commercial/cheques',
      headers: _authHeaders,
      body: jsonEncode({
        'direction': direction,
        'instrumentType': instrumentType,
        'number': number.trim(),
        'bankName': bankName.trim(),
        'dueDate': dueDate,
        'amountMru': amountMru,
        if (clientId != null) 'clientId': clientId,
        if (supplierId != null) 'supplierId': supplierId,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      await Future.wait([loadCheques(), loadDashboard()]);
      notifyListeners();
      return null;
    }
    return _extractErr(res);
  }

  Future<String?> updateChequeStatus(
    int id,
    String status, {
    int? treasuryAccountId,
  }) async {
    if (isOfflineDemo) {
      final idx = cheques.indexWhere((c) => c.id == id);
      if (idx >= 0) {
        final ch = cheques[idx];
        cheques[idx] = ChequeDraft(
          id: ch.id,
          direction: ch.direction,
          instrumentType: ch.instrumentType,
          number: ch.number,
          bankName: ch.bankName,
          partyName: ch.partyName,
          dueDate: ch.dueDate,
          amountMru: ch.amountMru,
          status: status,
        );
        if (status == 'ENCAISSE' || status == 'PAYE') {
          _recordOfflineTreasury(
            accountId: treasuryAccountId,
            direction: status == 'ENCAISSE' ? 'IN' : 'OUT',
            amountMru: ch.amountMru,
            payMethod: ch.instrumentType,
            label: '${ch.instrumentType} ${ch.number} · ${ch.partyName}',
          );
        }
        notifyListeners();
      }
      return null;
    }
    final res = await _http(
      'PATCH',
      '$apiBaseUrl/api/commercial/cheques/$id/status',
      headers: _authHeaders,
      body: jsonEncode({
        'status': status,
        if (treasuryAccountId != null) 'treasuryAccountId': treasuryAccountId,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      await Future.wait(
          [loadCheques(), loadTreasury(), loadSalesDocs(), loadDashboard()]);
      notifyListeners();
      return null;
    }
    return _extractErr(res);
  }

  Future<void> loadObjectives(int year) async {
    objectivesYear = year;
    if (isOfflineDemo) return;
    final res = await _http(
        'GET', '$apiBaseUrl/api/commercial/objectives?year=$year',
        headers: _authHeaders);
    if (res.statusCode == 200) {
      final list = (jsonDecode(res.body)['objectives'] as List?) ?? const [];
      objectives = list
          .whereType<Map>()
          .map((m) => MonthlyObjective.fromJson(m.cast<String, dynamic>()))
          .toList();
      notifyListeners();
    }
  }

  Future<String?> saveObjective(int year, int month, double targetCaHtMru) async {
    if (isOfflineDemo) {
      final idx = objectives.indexWhere((o) => o.year == year && o.month == month);
      if (idx >= 0) {
        final o = objectives[idx];
        final pct = targetCaHtMru > 0
            ? (o.realizedCaHtMru / targetCaHtMru) * 100
            : null;
        objectives[idx] = MonthlyObjective(
          year: o.year,
          month: o.month,
          label: o.label,
          targetCaHtMru: targetCaHtMru,
          targetMarginPct: o.targetMarginPct,
          realizedCaHtMru: o.realizedCaHtMru,
          prevCaHtMru: o.prevCaHtMru,
          attainmentPct: pct,
          status: targetCaHtMru > 0 ? 'ACTIF' : 'NON_DEFINI',
        );
      } else {
        objectives.add(MonthlyObjective(
          year: year,
          month: month,
          label: '$month/$year',
          targetCaHtMru: targetCaHtMru,
          realizedCaHtMru: 0,
          attainmentPct: 0,
          status: targetCaHtMru > 0 ? 'ACTIF' : 'NON_DEFINI',
        ));
      }
      notifyListeners();
      return null;
    }
    final res = await _http(
      'PUT',
      '$apiBaseUrl/api/commercial/objectives',
      headers: _authHeaders,
      body: jsonEncode({
        'year': year,
        'month': month,
        'targetCaHtMru': targetCaHtMru,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      await Future.wait([loadObjectives(year), loadDashboard()]);
      return null;
    }
    return _extractErr(res);
  }

  void exportDashboardCsv() {
    final buf = StringBuffer('Mois;CA HT (MRU);N-1 (MRU);Objectif (MRU)\n');
    for (final s in dashboard.series) {
      buf.writeln(
          '${s.label};${s.periodCaHtMru.toStringAsFixed(2)};${s.prevCaHtMru.toStringAsFixed(2)};${s.targetCaHtMru.toStringAsFixed(2)}');
    }
    downloadCsvFile('fulltek_commercial_dashboard.csv', buf.toString());
  }

  void exportSalesJournalCsv() {
    final buf = StringBuffer(
        'Numéro;Type;Date;Échéance;Client;NIF;Total HT;TVA;Total TTC;Payé;Reste;Statut\n');
    for (final d in salesDocs) {
      buf.writeln(
          '${d.docNumber};${d.docType};${d.issueDate};${d.dueDate};${d.partyName};${d.partyNif};${d.totalHtMru.toStringAsFixed(2)};${d.totalTvaMru.toStringAsFixed(2)};${d.totalTtcMru.toStringAsFixed(2)};${d.paidMru.toStringAsFixed(2)};${d.remainingMru.toStringAsFixed(2)};${d.status}');
    }
    downloadCsvFile('journal_ventes_fulltek.csv', buf.toString());
  }

  void exportPurchasesJournalCsv() {
    final buf = StringBuffer(
        'Numéro;Type;Date;Fournisseur;Total HT;TVA;Total TTC;Payé;Reste;Statut\n');
    for (final d in purchaseDocs) {
      buf.writeln(
          '${d.docNumber};${d.docType};${d.issueDate};${d.partyName};${d.totalHtMru.toStringAsFixed(2)};${d.totalTvaMru.toStringAsFixed(2)};${d.totalTtcMru.toStringAsFixed(2)};${d.paidMru.toStringAsFixed(2)};${d.remainingMru.toStringAsFixed(2)};${d.status}');
    }
    downloadCsvFile('journal_achats_fulltek.csv', buf.toString());
  }

  void exportTreasuryJournalCsv() {
    final buf =
        StringBuffer('Date;Compte;Sens;Mode;Montant (MRU);Solde Après;Libellé\n');
    for (final m in treasuryMovements) {
      buf.writeln(
          '${m.movementDate};${m.accountName};${m.direction};${m.payMethod};${m.amountMru.toStringAsFixed(2)};${m.balanceAfterMru.toStringAsFixed(2)};${m.label}');
    }
    downloadCsvFile('journal_tresorerie_fulltek.csv', buf.toString());
  }

  void exportArticlesCsv() {
    final buf = StringBuffer(
        'SKU;Designation;Famille;Unite;PrixDetailHT;PrixGrosHT;CoutPMP;Stock;StockMin;ExonereTVA\n');
    for (final a in articles) {
      buf.writeln(
          '${a.sku};${a.name};${a.category};${a.unit};${a.priceRetailHt.toStringAsFixed(0)};${a.priceWholeHt.toStringAsFixed(0)};${a.pmpCostMru.toStringAsFixed(0)};${a.stockQty.toStringAsFixed(1)};${a.minStock.toStringAsFixed(1)};${a.isExempt ? 1 : 0}');
    }
    downloadCsvFile('catalogue_articles_fulltek.csv', buf.toString());
  }

  Future<({int imported, int errors})> importArticlesCsv(String csvText) async {
    final lines = csvText
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.length <= 1) return (imported: 0, errors: 0);
    int imported = 0;
    int errors = 0;
    for (var i = 1; i < lines.length; i++) {
      final sep = lines[i].contains(';') ? ';' : ',';
      final cols = lines[i].split(sep).map((c) => c.trim()).toList();
      if (cols.length < 5) {
        errors++;
        continue;
      }
      final err = await createArticle(
        sku: cols[0],
        name: cols[1],
        category: cols.length > 2 && cols[2].isNotEmpty ? cols[2] : 'Général',
        unit: cols.length > 3 && cols[3].isNotEmpty ? cols[3] : 'unité',
        priceRetailHt: double.tryParse(cols[4]) ?? 0,
        priceWholeHt: cols.length > 5 ? (double.tryParse(cols[5]) ?? 0) : 0,
        priceCostMru: cols.length > 6 ? (double.tryParse(cols[6]) ?? 0) : 0,
        stockQty: cols.length > 7 ? (double.tryParse(cols[7]) ?? 0) : 0,
        minStock: cols.length > 8 ? (double.tryParse(cols[8]) ?? 0) : 5,
        isExempt: cols.length > 9 && (cols[9] == '1' || cols[9].toLowerCase() == 'true'),
      );
      if (err == null) {
        imported++;
      } else {
        errors++;
      }
    }
    return (imported: imported, errors: errors);
  }

  void saveCompanySettings(CompanySettings next) {
    companySettings = next;
    if (_enablePersistence) {
      localStorageWrite(
          'fulltek_commercial_company_v1', jsonEncode(next.toJson()));
    }
    notifyListeners();
  }

  Future<String?> updateSalesDocDraft(
    int id, {
    required int clientId,
    required List<Map<String, dynamic>> lines,
    double globalDiscountPct = 0,
    String? dueDate,
  }) async {
    if (lines.isEmpty) return 'Ajoutez au moins une ligne article.';
    if (isOfflineDemo) {
      final idx = salesDocs.indexWhere((d) => d.id == id);
      if (idx < 0) return 'Document introuvable.';
      final old = salesDocs[idx];
      final cli = clients.firstWhere((c) => c.id == clientId);
      double totalHt = 0;
      double totalTva = 0;
      double totalCost = 0;
      final builtLines = <DocLineModel>[];
      for (final l in lines) {
        final art = articles.firstWhere((a) => a.id == l['articleId']);
        final qty = (l['qty'] as num).toDouble();
        final pu = (l['unitPriceHtMru'] as num?)?.toDouble() ?? art.priceRetailHt;
        final disc = (l['discountPct'] as num?)?.toDouble() ?? 0;
        final lHt = CommercialMath.computeLineHt(
                qty: qty, unitPriceHt: pu, discountPct: disc) *
            (1 - globalDiscountPct / 100);
        final lTva = CommercialMath.computeLineTva(
            lineHt: lHt, isExempt: art.isExempt, tvaRate: art.tvaRate);
        totalHt += lHt;
        totalTva += lTva;
        totalCost += qty * art.pmpCostMru;
        builtLines.add(DocLineModel(
          articleId: art.id,
          sku: art.sku,
          designation: art.name,
          qty: qty,
          unitPriceHtMru: pu,
          discountPct: disc,
          tvaRate: art.tvaRate,
          isExempt: art.isExempt,
          lineHtMru: lHt,
          lineTvaMru: lTva,
          lineTtcMru: lHt + lTva,
        ));
      }
      salesDocs[idx] = CommercialDoc(
        id: old.id,
        docType: old.docType,
        docNumber: old.docNumber,
        status: old.status,
        partyId: cli.id,
        partyName: cli.name,
        partyNif: cli.nif,
        issueDate: old.issueDate,
        dueDate: dueDate ?? old.dueDate,
        globalDiscountPct: globalDiscountPct,
        totalHtMru: totalHt,
        totalTvaMru: totalTva,
        totalTtcMru: totalHt + totalTva,
        grossMarginMru: totalHt - totalCost,
        paidMru: old.paidMru,
        remainingMru: (totalHt + totalTva - old.paidMru).clamp(0.0, double.infinity),
        stockApplied: old.stockApplied,
        lines: builtLines,
      );
      notifyListeners();
      return null;
    }
    final res = await _http(
      'PATCH',
      '$apiBaseUrl/api/commercial/sales-docs/$id',
      headers: _authHeaders,
      body: jsonEncode({
        'clientId': clientId,
        'globalDiscountPct': globalDiscountPct,
        if (dueDate != null && dueDate.isNotEmpty) 'dueDate': dueDate,
        'lines': lines,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      await loadSalesDocs();
      notifyListeners();
      return null;
    }
    return _extractErr(res);
  }

  Future<String?> duplicateSalesDoc(CommercialDoc src) async {
    final full = await getSalesDocDetail(src.id) ?? src;
    final payloadLines = full.lines.isNotEmpty
        ? full.lines
            .map((l) => {
                  'articleId': l.articleId,
                  'qty': l.qty,
                  'unitPriceHtMru': l.unitPriceHtMru,
                  'discountPct': l.discountPct,
                })
            .toList()
        : (articles.isNotEmpty
            ? [
                {
                  'articleId': articles.first.id,
                  'qty': 1,
                  'unitPriceHtMru': full.totalHtMru,
                  'discountPct': 0,
                }
              ]
            : <Map<String, dynamic>>[]);
    return createSalesDoc(
      docType: full.docType,
      clientId: full.partyId > 0 ? full.partyId : clients.first.id,
      globalDiscountPct: full.globalDiscountPct,
      validateNow: false,
      lines: payloadLines,
    );
  }

  // Pack 2: Operating Expenses & Net Result
  double get totalExpensesMru =>
      expenses.fold<double>(0, (s, e) => s + e.amountMru);

  double get netResultMru => dashboard.kpis.grossMarginMru - totalExpensesMru;

  Future<String?> addExpense({
    required String category,
    required String label,
    required double amountMru,
    required String payMethod,
    String beneficiary = '',
    String ref = '',
  }) async {
    if (label.trim().isEmpty || amountMru <= 0) {
      return 'Libellé et montant requis.';
    }
    expenses.insert(
      0,
      OperatingExpense(
        id: expenses.length + 100,
        date: DateTime.now().toIso8601String().substring(0, 10),
        category: category,
        label: label.trim(),
        amountMru: amountMru,
        payMethod: payMethod,
        beneficiary: beneficiary.trim(),
        ref: ref.trim(),
      ),
    );
    if (treasuryAccounts.isNotEmpty) {
      if (isOfflineDemo) {
        _recordOfflineTreasury(
          direction: 'OUT',
          amountMru: amountMru,
          payMethod: payMethod,
          label: 'Charge [$category] · ${label.trim()}',
        );
      } else {
        await addTreasuryMovement(
          accountId: treasuryAccounts.first.id,
          direction: 'OUT',
          amountMru: amountMru,
          payMethod: payMethod,
          label: 'Charge [$category] · ${label.trim()}',
        );
      }
    }
    notifyListeners();
    return null;
  }

  void deleteExpense(int id) {
    expenses.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  // Pack 2: Rapport TVA Mauritanie (16% / Exonéré)
  ({
    double salesHtTaxable,
    double salesHtExempt,
    double salesTvaCollected,
    double purchasesHtTaxable,
    double purchasesTvaDeductible,
    double netTvaToPay,
  }) computeTvaSummary() {
    double sTax = 0, sEx = 0, sTva = 0;
    for (final d in salesDocs) {
      if (d.docType != 'FACTURE' && d.docType != 'AVOIR') continue;
      final sign = d.docType == 'AVOIR' ? -1.0 : 1.0;
      if (d.totalTvaMru > 0) {
        sTax += sign * d.totalHtMru;
        sTva += sign * d.totalTvaMru;
      } else {
        sEx += sign * d.totalHtMru;
      }
    }
    double pTax = 0, pTva = 0;
    for (final d in purchaseDocs) {
      if (d.docType != 'FACTURE_ACHAT' && d.docType != 'AVOIR_ACHAT') continue;
      final sign = d.docType == 'AVOIR_ACHAT' ? -1.0 : 1.0;
      if (d.totalTvaMru > 0) {
        pTax += sign * d.totalHtMru;
        pTva += sign * d.totalTvaMru;
      }
    }
    return (
      salesHtTaxable: sTax,
      salesHtExempt: sEx,
      salesTvaCollected: sTva,
      purchasesHtTaxable: pTax,
      purchasesTvaDeductible: pTva,
      netTvaToPay: sTva - pTva,
    );
  }

  // Pack 1: Balance Âgée (Impayés)
  ({
    double bucket0To30,
    double bucket31To60,
    double bucketOver60,
    List<CommercialDoc> overdueInvoices,
  }) computeAgedReceivables() {
    final now = DateTime.now();
    double b1 = 0, b2 = 0, b3 = 0;
    final overdue = <CommercialDoc>[];
    for (final d in salesDocs) {
      if (d.docType != 'FACTURE' || d.remainingMru <= 0.5) continue;
      final due = DateTime.tryParse(d.dueDate.isNotEmpty ? d.dueDate : d.issueDate) ?? now;
      final days = now.difference(due).inDays;
      overdue.add(d);
      if (days <= 30) {
        b1 += d.remainingMru;
      } else if (days <= 60) {
        b2 += d.remainingMru;
      } else {
        b3 += d.remainingMru;
      }
    }
    return (
      bucket0To30: b1,
      bucket31To60: b2,
      bucketOver60: b3,
      overdueInvoices: overdue,
    );
  }

  // Pack 3: Multi-Dépôts & Inventaire Physique
  void createWarehouse({
    required String code,
    required String name,
    String city = 'Nouakchott',
  }) {
    if (code.trim().isEmpty || name.trim().isEmpty) return;
    warehouses.add(WarehouseLocation(
      id: warehouses.length + 10,
      code: code.trim().toUpperCase(),
      name: name.trim(),
      city: city.trim(),
    ));
    notifyListeners();
  }

  String? transferStock({
    required String fromWarehouse,
    required String toWarehouse,
    required int articleId,
    required double qty,
    String note = '',
  }) {
    if (fromWarehouse == toWarehouse) return 'Choisissez 2 dépôts différents.';
    if (qty <= 0) return 'Quantité invalide.';
    final art = articles.firstWhere((a) => a.id == articleId);
    stockTransfers.insert(
      0,
      StockTransferRecord(
        id: stockTransfers.length + 1,
        date: DateTime.now().toIso8601String().substring(0, 10),
        fromWarehouse: fromWarehouse,
        toWarehouse: toWarehouse,
        sku: art.sku,
        articleName: art.name,
        qty: qty,
        note: note.trim(),
      ),
    );
    stockMovements.insert(
      0,
      StockMovement(
        id: stockMovements.length + 100,
        articleId: art.id,
        articleName: art.name,
        sku: art.sku,
        movementType: 'TRANSFERT',
        qtyDelta: 0,
        unitCostMru: art.pmpCostMru,
        pmpAfterMru: art.pmpCostMru,
        stockAfter: art.stockQty,
        reason: 'Transfert $qty ${art.unit} ($fromWarehouse → $toWarehouse)',
        createdAt: DateTime.now().toIso8601String().substring(0, 16),
      ),
    );
    notifyListeners();
    return null;
  }

  Future<void> applyPhysicalInventory({
    required String warehouseName,
    required Map<int, double> countedByArticleId,
  }) async {
    double netQty = 0;
    double netVal = 0;
    int counted = 0;
    for (final entry in countedByArticleId.entries) {
      final idx = articles.indexWhere((a) => a.id == entry.key);
      if (idx < 0) continue;
      final a = articles[idx];
      final delta = entry.value - a.stockQty;
      counted++;
      if (delta.abs() > 0.001) {
        netQty += delta;
        netVal += delta * a.pmpCostMru;
        await adjustArticleStock(
            a.id, delta, 'Inventaire physique ($warehouseName)');
      }
    }
    inventorySessions.insert(
      0,
      InventorySessionRecord(
        id: inventorySessions.length + 1,
        date: DateTime.now().toIso8601String().substring(0, 10),
        warehouseName: warehouseName,
        articlesCounted: counted,
        netVarianceQty: netQty,
        netVarianceValueMru: netVal,
      ),
    );
    notifyListeners();
  }

  // Pack 3: POS Park / Resume
  void parkPosOrder({
    required String label,
    required String priceTier,
    int? clientId,
    required List<Map<String, dynamic>> lines,
  }) {
    parkedOrders.insert(
      0,
      ParkedPosOrder(
        id: 'PK-${DateTime.now().millisecondsSinceEpoch}',
        label: label,
        priceTier: priceTier,
        clientId: clientId,
        lines: lines,
        createdAt: DateTime.now().toIso8601String().substring(11, 16),
      ),
    );
    notifyListeners();
  }

  void removeParkedOrder(String id) {
    parkedOrders.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  void printPosTicket80mm(CommercialPosTicket t) {
    final s = companySettings;
    final html = '''
<div style="max-width:300px;margin:0 auto;font-family:monospace;font-size:12px;">
  <div style="text-align:center;font-weight:bold;font-size:15px;">${s.companyName}</div>
  <div style="text-align:center;">${s.address} · ${s.city}</div>
  <div style="text-align:center;">Tél: ${s.phone} · ${s.nif}</div>
  <hr/>
  <div>Ticket : <strong>${t.ticketNumber}</strong></div>
  <div>Date : ${t.createdAt}</div>
  <div>Client : ${t.customerName.isEmpty ? 'Comptoir' : t.customerName}</div>
  <div>Paiement : ${t.payMethod}</div>
  <hr/>
  <div style="display:flex;justify-content:space-between;"><span>Total HT</span><span>${fmtMru(t.totalHtMru)}</span></div>
  <div style="display:flex;justify-content:space-between;"><span>TVA</span><span>${fmtMru(t.totalTvaMru)}</span></div>
  <div style="display:flex;justify-content:space-between;font-weight:bold;font-size:14px;"><span>NET TTC</span><span>${fmtMru(t.totalTtcMru)}</span></div>
  <hr/>
  <div style="text-align:center;font-size:11px;">Merci de votre visite · Full·Tek POS</div>
</div>
''';
    openA4PrintWindow('Ticket ${t.ticketNumber}', html);
  }

  void printPartyStatement({
    required bool isClient,
    required int partyId,
    required String partyName,
    String partyNif = '',
  }) {
    final s = companySettings;
    final docs = (isClient ? salesDocs : purchaseDocs)
        .where((d) => d.partyId == partyId)
        .toList();
    double totalInvoiced = 0;
    double totalPaid = 0;
    final rows = docs.map((d) {
      totalInvoiced += d.totalTtcMru;
      totalPaid += d.paidMru;
      return '<tr><td>${d.issueDate}</td><td>${d.docNumber}</td><td>${d.docType}</td><td class="num">${fmtMru(d.totalTtcMru)}</td><td class="num">${fmtMru(d.paidMru)}</td><td class="num"><strong>${fmtMru(d.remainingMru)}</strong></td></tr>';
    }).join();
    final balance = totalInvoiced - totalPaid;
    final html = '''
<div class="hdr">
  <div>
    <div class="brand">${s.companyName}</div>
    <div>${s.address} · ${s.city}</div>
    <div>Tél: ${s.phone} · ${s.nif} ${s.rc}</div>
  </div>
  <div class="meta">
    <div style="font-size:15px;font-weight:900;">RELEVÉ DE COMPTE ${isClient ? 'CLIENT' : 'FOURNISSEUR'}</div>
    <div>Tiers : <strong>$partyName</strong></div>
    ${partyNif.isNotEmpty ? '<div>NIF : $partyNif</div>' : ''}
    <div>Édité le : ${DateTime.now().toIso8601String().substring(0, 10)}</div>
  </div>
</div>
<table>
  <thead><tr><th>Date</th><th>Numéro</th><th>Type</th><th class="num">Débit TTC</th><th class="num">Crédit / Payé</th><th class="num">Solde</th></tr></thead>
  <tbody>$rows</tbody>
</table>
<table class="totals">
  <tr><td>Total Facturé TTC</td><td class="num">${fmtMru(totalInvoiced)}</td></tr>
  <tr><td>Total Réglé</td><td class="num">${fmtMru(totalPaid)}</td></tr>
  <tr class="grand"><td>SOLDE NET À RÉGLER</td><td class="num">${fmtMru(balance)}</td></tr>
</table>
<p style="margin-top:16px;font-style:italic;">Arrêté le présent relevé à la somme de : <strong>${amountToFrenchWords(balance)}</strong>.</p>
''';
    openA4PrintWindow('Relevé $partyName', html);
  }

  void printDocumentA4(CommercialDoc doc) {
    final s = companySettings;
    final rows = doc.lines.isNotEmpty
        ? doc.lines
            .map((l) =>
                '<tr><td>${l.designation}</td><td class="num">${l.qty}</td><td class="num">${fmtMru(l.unitPriceHtMru)}</td><td class="num">${l.isExempt ? 'Exonéré' : '${l.tvaRate}%'}</td><td class="num">${fmtMru(l.lineTtcMru)}</td></tr>')
            .join()
        : '<tr><td colspan="4">${doc.docType} ${doc.docNumber}</td><td class="num">${fmtMru(doc.totalTtcMru)}</td></tr>';
    final html = '''
<div class="hdr">
  <div>
    <div class="brand">${s.companyName}</div>
    <div>${s.address} · ${s.city}</div>
    <div>Tél: ${s.phone} · ${s.nif} ${s.rc}</div>
  </div>
  <div class="meta">
    <div style="font-size:15px;font-weight:900;">${doc.docType} ${doc.docNumber}</div>
    <div>Date: ${doc.issueDate}${doc.dueDate.isNotEmpty ? ' · Échéance: ${doc.dueDate}' : ''}</div>
    <div>Client / Tiers: <strong>${doc.partyName}</strong></div>
    ${doc.partyNif.isNotEmpty ? '<div>NIF: ${doc.partyNif}</div>' : ''}
  </div>
</div>
<table>
  <thead><tr><th>Désignation</th><th class="num">Qté</th><th class="num">PU HT</th><th class="num">TVA</th><th class="num">Total TTC</th></tr></thead>
  <tbody>$rows</tbody>
</table>
<table class="totals">
  <tr><td>Total HT</td><td class="num">${fmtMru(doc.totalHtMru)}</td></tr>
  <tr><td>Total TVA (16%)</td><td class="num">${fmtMru(doc.totalTvaMru)}</td></tr>
  <tr class="grand"><td>Total TTC</td><td class="num">${fmtMru(doc.totalTtcMru)}</td></tr>
  <tr><td>Payé</td><td class="num">${fmtMru(doc.paidMru)}</td></tr>
  <tr><td>Reste à payer</td><td class="num">${fmtMru(doc.remainingMru)}</td></tr>
</table>
<p style="margin-top:16px;font-size:12px;">Arrêtée la présente pièce à la somme de : <strong>${amountToFrenchWords(doc.totalTtcMru)}</strong>.</p>
<div style="margin-top:20px;padding-top:10px;border-top:1px solid #E2E8F0;font-size:11px;color:#475569;">
  <div><strong>RIB :</strong> ${s.bankRib} · <strong>Bankily :</strong> ${s.bankilyNumber} · <strong>Masrivi :</strong> ${s.masriviNumber}</div>
  <div style="margin-top:4px;">${s.invoiceFooter}</div>
</div>
''';
    openA4PrintWindow('${doc.docType} ${doc.docNumber}', html);
  }

  String _extractErr(HttpBridgeResponse res) {
    try {
      final j = jsonDecode(res.body);
      if (j is Map && j['error'] != null) return '${j['error']}';
    } catch (_) {}
    return 'Erreur HTTP ${res.statusCode}';
  }

  void _recordOfflineTreasury({
    int? accountId,
    required String direction,
    required double amountMru,
    required String payMethod,
    required String label,
  }) {
    if (treasuryAccounts.isEmpty || amountMru <= 0) return;
    int idx = accountId != null
        ? treasuryAccounts.indexWhere((a) => a.id == accountId)
        : (payMethod == 'Cash'
            ? treasuryAccounts.indexWhere((a) => a.accountType == 'CAISSE')
            : treasuryAccounts.indexWhere((a) => a.accountType != 'CAISSE'));
    if (idx < 0) idx = 0;
    final acc = treasuryAccounts[idx];
    final delta = direction == 'IN' ? amountMru : -amountMru;
    final nextBal = acc.currentBalanceMru + delta;
    treasuryAccounts[idx] = TreasuryAccount(
      id: acc.id,
      code: acc.code,
      name: acc.name,
      accountType: acc.accountType,
      bankName: acc.bankName,
      currentBalanceMru: nextBal,
    );
    treasuryMovements.insert(
      0,
      TreasuryMovement(
        id: treasuryMovements.length + 100,
        accountId: acc.id,
        accountName: acc.name,
        movementDate: DateTime.now().toIso8601String().substring(0, 10),
        direction: direction,
        amountMru: amountMru,
        balanceAfterMru: nextBal,
        payMethod: payMethod,
        label: label,
      ),
    );
  }

  void _applyOfflineStockDelta(
    int articleId,
    double qtyDelta,
    String movementType,
    String sourceNumber, {
    double? incomingCostHt,
  }) {
    final idx = articles.indexWhere((a) => a.id == articleId);
    if (idx < 0) return;
    final a = articles[idx];
    final nextPmp = (incomingCostHt != null && qtyDelta > 0)
        ? CommercialMath.computeWeightedPmp(
            currentStock: a.stockQty,
            currentPmp: a.pmpCostMru,
            incomingQty: qtyDelta,
            incomingCostHt: incomingCostHt,
          )
        : a.pmpCostMru;
    final nextQty = (a.stockQty + qtyDelta).clamp(0.0, double.infinity);
    articles[idx] = CommercialArticle(
      id: a.id,
      sku: a.sku,
      barcode: a.barcode,
      name: a.name,
      category: a.category,
      unit: a.unit,
      priceRetailHt: a.priceRetailHt,
      priceWholeHt: a.priceWholeHt,
      priceRetailTtc: a.priceRetailTtc,
      priceWholeTtc: a.priceWholeTtc,
      priceCostMru: incomingCostHt ?? a.priceCostMru,
      pmpCostMru: nextPmp,
      stockQty: nextQty,
      minStock: a.minStock,
      tvaRate: a.tvaRate,
      isExempt: a.isExempt,
      stockValuePmpMru: nextQty * nextPmp,
      isLowStock: nextQty <= a.minStock,
    );
    stockMovements.insert(
      0,
      StockMovement(
        id: stockMovements.length + 100,
        articleId: a.id,
        articleName: a.name,
        sku: a.sku,
        movementType: movementType,
        qtyDelta: qtyDelta,
        unitCostMru: incomingCostHt ?? a.pmpCostMru,
        pmpAfterMru: nextPmp,
        stockAfter: nextQty,
        sourceNumber: sourceNumber,
        reason: '$movementType · $sourceNumber',
        createdAt: DateTime.now().toIso8601String().substring(0, 16),
      ),
    );
  }

  void _seedOfflineDemoData() {
    clients = [
      const CommercialClient(
        id: 1,
        code: 'CLI-0001',
        name: 'Chinguetti Distribution SARL',
        isB2b: true,
        nif: 'NIF 44901234',
        rc: 'RC NKC-2024-88',
        phone: '+222 45 25 44 11',
        creditLimitMru: 500000,
        karniDebtMru: 45000,
        encoursTtcMru: 142290,
      ),
      const CommercialClient(
        id: 2,
        code: 'CLI-0002',
        name: 'Supermarché Al-Amal',
        isB2b: true,
        nif: 'NIF 77219088',
        phone: '+222 36 88 12 00',
        creditLimitMru: 250000,
      ),
    ];
    suppliers = [
      const CommercialSupplier(
        id: 1,
        code: 'FRN-0001',
        name: 'Mauritanie Import Export',
        nif: 'NIF 99100234',
        phone: '+222 45 29 00 11',
        balanceDueMru: 40400,
      ),
    ];
    articles = [
      const CommercialArticle(
        id: 1,
        sku: 'INF-001',
        barcode: '6130001000011',
        name: 'PC Portable Pro 15"',
        category: 'Informatique',
        priceRetailHt: 28000,
        priceWholeHt: 25000,
        priceRetailTtc: 32480,
        priceCostMru: 21000,
        pmpCostMru: 21000,
        stockQty: 14,
        minStock: 3,
        stockValuePmpMru: 294000,
      ),
      const CommercialArticle(
        id: 2,
        sku: 'ALIM-001',
        barcode: '6130002000028',
        name: 'Riz Basmati Sac 25kg',
        category: 'Alimentation',
        unit: 'sac',
        priceRetailHt: 1450,
        priceWholeHt: 1320,
        priceRetailTtc: 1450,
        priceCostMru: 1100,
        pmpCostMru: 1100,
        stockQty: 120,
        minStock: 20,
        tvaRate: 0,
        isExempt: true,
        stockValuePmpMru: 132000,
      ),
    ];
    treasuryAccounts = [
      const TreasuryAccount(
          id: 1,
          code: 'CAI-01',
          name: 'Caisse Principale',
          accountType: 'CAISSE',
          currentBalanceMru: 85000),
      const TreasuryAccount(
          id: 2,
          code: 'BNQ-01',
          name: 'BMCI Compte Courant',
          accountType: 'BANQUE',
          bankName: 'BMCI',
          currentBalanceMru: 139114),
    ];
    warehouses = [
      const WarehouseLocation(
          id: 1,
          code: 'DEP-NKC',
          name: 'Dépôt Principal El-Mina',
          city: 'Nouakchott',
          isDefault: true),
      const WarehouseLocation(
          id: 2,
          code: 'MAG-TZ',
          name: 'Showroom Tevragh Zeina',
          city: 'Nouakchott'),
    ];
    expenses = [
      const OperatingExpense(
        id: 1,
        date: '2026-11-05',
        category: 'Loyer',
        label: 'Loyer Dépôt El-Mina Novembre',
        amountMru: 25000,
        payMethod: 'Virement',
        beneficiary: 'SCI Al-Baraka',
      ),
      const OperatingExpense(
        id: 2,
        date: '2026-11-12',
        category: 'Électricité / Eau',
        label: 'Facture Somelec Showroom',
        amountMru: 8400,
        payMethod: 'Bankily',
        beneficiary: 'SOMELEC',
      ),
    ];
    salesDocs = [
      const CommercialDoc(
        id: 1,
        docType: 'FACTURE',
        docNumber: 'FAC-2026-0142',
        status: 'PARTIELLE',
        partyId: 1,
        partyName: 'Chinguetti Distribution SARL',
        partyNif: 'NIF 44901234',
        issueDate: '2026-10-15',
        dueDate: '2026-11-14',
        totalHtMru: 140000,
        totalTvaMru: 22400,
        totalTtcMru: 162400,
        grossMarginMru: 35000,
        paidMru: 80000,
        remainingMru: 82400,
        stockApplied: true,
      ),
    ];
    dashboard = const DashboardData(
      fromDate: '2026-01-01',
      toDate: '2026-11-20',
      kpis: DashboardKpis(
        caHtMru: 580052,
        caVsN1Pct: 178.3,
        objectiveTargetMru: 1200000,
        objectiveAttainmentPct: 48.3,
        grossMarginMru: 185832,
        marginRatePct: 32.0,
        marginRatePrevPct: 29.4,
        marginVsN1Pct: 203.8,
        receiptsMru: 642330,
        receiptsVsN1Pct: 303.9,
        disbursementsMru: 426000,
        purchasesHtMru: 326600,
        purchasesVsN1Pct: 254.6,
        supplierDebtMru: 40400,
        clientReceivablesTtcMru: 142290,
        pendingEffectsMru: 168000,
        treasuryBalanceMru: 224114,
        stockValuePmpMru: 426000,
        quotesEmittedHtMru: 95000,
        quotesCount: 4,
      ),
      series: [
        DashboardSeriesPoint(
            monthKey: '2026-01',
            label: 'janv. 26',
            periodCaHtMru: 82000,
            prevCaHtMru: 38000,
            targetCaHtMru: 100000),
        DashboardSeriesPoint(
            monthKey: '2026-02',
            label: 'févr. 26',
            periodCaHtMru: 64000,
            prevCaHtMru: 42000,
            targetCaHtMru: 105000),
        DashboardSeriesPoint(
            monthKey: '2026-03',
            label: 'mars 26',
            periodCaHtMru: 72000,
            prevCaHtMru: 45000,
            targetCaHtMru: 110000),
        DashboardSeriesPoint(
            monthKey: '2026-04',
            label: 'avr. 26',
            periodCaHtMru: 51000,
            prevCaHtMru: 39000,
            targetCaHtMru: 112000),
        DashboardSeriesPoint(
            monthKey: '2026-05',
            label: 'mai 26',
            periodCaHtMru: 59000,
            prevCaHtMru: 48000,
            targetCaHtMru: 115000),
        DashboardSeriesPoint(
            monthKey: '2026-06',
            label: 'juin 26',
            periodCaHtMru: 63000,
            prevCaHtMru: 52000,
            targetCaHtMru: 120000),
      ],
      overdueClientInvoices: DashboardAlertGroup(count: 3, totalMru: 93800),
      dueCheques7d: DashboardAlertGroup(count: 2, totalMru: 68000),
      overdueSupplierInvoices: DashboardAlertGroup(count: 1, totalMru: 35500),
    );
  }
}
