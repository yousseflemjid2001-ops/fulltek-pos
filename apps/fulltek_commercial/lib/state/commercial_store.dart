import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/commercial_models.dart';
import '../services/export_helper.dart';
import '../services/http_bridge.dart';
import '../services/local_storage.dart';

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
      return 'Serveur inaccessible — utilisez le mode Démo locale pour tester.';
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

  Future<String?> karniPayClient(
      int clientId, double amountMru, String payMethod) async {
    if (amountMru <= 0) return 'Montant invalide.';
    if (isOfflineDemo) return null;
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

  Future<String?> adjustArticleStock(
      int articleId, double qtyDelta, String reason) async {
    if (isOfflineDemo) return null;
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

  Future<String?> createSalesDoc({
    required String docType,
    required int clientId,
    required List<Map<String, dynamic>> lines,
    double globalDiscountPct = 0,
    bool validateNow = true,
    int? sourceDocId,
    bool restock = true,
  }) async {
    if (isOfflineDemo) {
      final cli = clients.firstWhere((c) => c.id == clientId);
      double totalHt = 0;
      double totalTva = 0;
      for (final l in lines) {
        final art = articles.firstWhere((a) => a.id == l['articleId']);
        final qty = (l['qty'] as num).toDouble();
        final pu = (l['unitPriceHtMru'] as num?)?.toDouble() ?? art.priceRetailHt;
        final lHt = CommercialMath.computeLineHt(
            qty: qty, unitPriceHt: pu) * (1 - globalDiscountPct / 100);
        final lTva = CommercialMath.computeLineTva(
            lineHt: lHt, isExempt: art.isExempt, tvaRate: art.tvaRate);
        totalHt += lHt;
        totalTva += lTva;
      }
      salesDocs.insert(
        0,
        CommercialDoc(
          id: salesDocs.length + 10,
          docType: docType,
          docNumber: '$docType-${salesDocs.length + 1}',
          status: validateNow ? 'VALIDEE' : 'BROUILLON',
          partyId: cli.id,
          partyName: cli.name,
          partyNif: cli.nif,
          issueDate: DateTime.now().toIso8601String().substring(0, 10),
          totalHtMru: totalHt,
          totalTvaMru: totalTva,
          totalTtcMru: totalHt + totalTva,
          remainingMru: totalHt + totalTva,
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
    if (isOfflineDemo) return null;
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
          id: salesDocs.length + 20,
          docType: targetType,
          docNumber: '$targetType-${salesDocs.length + 1}',
          status: 'BROUILLON',
          partyId: src.partyId,
          partyName: src.partyName,
          partyNif: src.partyNif,
          issueDate: DateTime.now().toIso8601String().substring(0, 10),
          totalHtMru: src.totalHtMru,
          totalTvaMru: src.totalTvaMru,
          totalTtcMru: src.totalTtcMru,
          remainingMru: src.totalTtcMru,
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
    if (isOfflineDemo) return null;
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

  Future<String?> createPurchaseDoc({
    required String docType,
    required int supplierId,
    required List<Map<String, dynamic>> lines,
    bool validateNow = true,
  }) async {
    if (isOfflineDemo) return null;
    final res = await _http(
      'POST',
      '$apiBaseUrl/api/commercial/purchase-docs',
      headers: _authHeaders,
      body: jsonEncode({
        'docType': docType,
        'supplierId': supplierId,
        'validateNow': validateNow,
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
    if (isOfflineDemo) return null;
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
    if (isOfflineDemo) return null;
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
    if (isOfflineDemo) return null;
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
    if (isOfflineDemo) return null;
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

  Future<String?> addTreasuryMovement({
    required int accountId,
    required String direction,
    required double amountMru,
    required String label,
  }) async {
    if (isOfflineDemo) return null;
    final res = await _http(
      'POST',
      '$apiBaseUrl/api/commercial/treasury/movements',
      headers: _authHeaders,
      body: jsonEncode({
        'accountId': accountId,
        'direction': direction,
        'amountMru': amountMru,
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
    if (isOfflineDemo) return null;
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
    int? clientId,
    int? supplierId,
  }) async {
    if (isOfflineDemo) return null;
    final res = await _http(
      'POST',
      '$apiBaseUrl/api/commercial/cheques',
      headers: _authHeaders,
      body: jsonEncode({
        'direction': direction,
        'instrumentType': instrumentType,
        'number': number,
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
    if (isOfflineDemo) return null;
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
    if (isOfflineDemo) return null;
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

  void printDocumentA4(CommercialDoc doc) {
    final rows = doc.lines.isNotEmpty
        ? doc.lines
            .map((l) =>
                '<tr><td>${l.designation}</td><td class="num">${l.qty}</td><td class="num">${fmtMru(l.unitPriceHtMru)}</td><td class="num">${l.isExempt ? 'Exonéré' : '${l.tvaRate}%'}</td><td class="num">${fmtMru(l.lineTtcMru)}</td></tr>')
            .join()
        : '<tr><td colspan="4">${doc.docType} ${doc.docNumber}</td><td class="num">${fmtMru(doc.totalTtcMru)}</td></tr>';
    final html = '''
<div class="hdr">
  <div>
    <div class="brand">${tenant.name}</div>
    <div>${tenant.address} · ${tenant.city}</div>
    <div>Tél: ${tenant.phone} · ${tenant.nif} ${tenant.rc}</div>
  </div>
  <div class="meta">
    <div style="font-size:15px;font-weight:900;">${doc.docType} ${doc.docNumber}</div>
    <div>Date: ${doc.issueDate}</div>
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

  void _seedOfflineDemoData() {
    clients = const [
      CommercialClient(
        id: 1,
        code: 'CLI-0001',
        name: 'Chinguetti Distribution SARL',
        isB2b: true,
        nif: 'NIF 44901234',
        rc: 'RC NKC-2024-88',
        phone: '+222 45 25 44 11',
        creditLimitMru: 500000,
        encoursTtcMru: 142290,
      ),
      CommercialClient(
        id: 2,
        code: 'CLI-0002',
        name: 'Supermarché Al-Amal',
        isB2b: true,
        nif: 'NIF 77219088',
        phone: '+222 36 88 12 00',
        creditLimitMru: 250000,
      ),
    ];
    suppliers = const [
      CommercialSupplier(
        id: 1,
        code: 'FRN-0001',
        name: 'Mauritanie Import Export',
        nif: 'NIF 99100234',
        phone: '+222 45 29 00 11',
        balanceDueMru: 40400,
      ),
    ];
    articles = const [
      CommercialArticle(
        id: 1,
        sku: 'INF-001',
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
      CommercialArticle(
        id: 2,
        sku: 'ALIM-001',
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
    treasuryAccounts = const [
      TreasuryAccount(
          id: 1,
          code: 'CAI-01',
          name: 'Caisse Principale',
          accountType: 'CAISSE',
          currentBalanceMru: 85000),
      TreasuryAccount(
          id: 2,
          code: 'BNQ-01',
          name: 'BMCI Compte Courant',
          accountType: 'BANQUE',
          currentBalanceMru: 139114),
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
