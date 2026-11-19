import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fulltek_pos/main.dart';
import 'package:fulltek_pos/models/pos_models.dart';
import 'package:fulltek_pos/state/pos_store.dart';
import 'package:fulltek_pos/theme/fulltek_themes.dart';

/// Authoritative Mauritanian TTC-inclusive VAT 16% helper: round(TTC * 16 / 116).
int computeExpectedTva16(double netTotal) {
  if (netTotal <= 0) return 0;
  return (netTotal * 16.0 / 116.0).round();
}

/// Configures the Flutter test viewport (default 1440x900 desktop POS) and
/// registers tearDown resets so tests stay completely isolated.
void setTestViewport(WidgetTester tester, {Size size = const Size(1440, 900)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Executes [action] with `HttpOverrides.global = null` so `dart:io`
/// `HttpClient` inside `httpBridgeRequest` communicates with real loopback
/// sockets instead of hitting `flutter_test`'s `_TestHttpOverrides` HTTP-400 stub.
Future<T> runWithRealHttpOverrides<T>(Future<T> Function() action) async {
  // `HttpOverrides.global` only exposes a setter; the flutter_test stub is
  // re-installed by the test binding for each test, so no restore is needed.
  HttpOverrides.global = null;
  return await action();
}

/// Returns the first [Finder] in [candidates] that evaluates to at least one
/// widget, or falls back to `candidates.first` so `expect(..., findsOneWidget)`
/// produces a clear failure message if none match.
Finder findAny(List<Finder> candidates) {
  for (final f in candidates) {
    if (f.evaluate().isNotEmpty) return f;
  }
  return candidates.first;
}

/// Taps the first matching widget in [candidates], scrolling into view if needed.
Future<void> tapFirst(
  WidgetTester tester,
  List<Finder> candidates, {
  bool warnIfMissed = false,
}) async {
  final target = findAny(candidates).first;
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target, warnIfMissed: warnIfMissed);
  await tester.pumpAndSettle();
}

/// Pumps [FullTekPosApp] with deterministic viewport and optional account/PIN
/// fast-forward.
Future<PosStore> pumpPosApp(
  WidgetTester tester, {
  PosStore? store,
  Size size = const Size(1440, 900),
  bool bypassAccount = true,
  String? pin,
}) async {
  setTestViewport(tester, size: size);
  final activeStore = store ?? PosStore();
  if (bypassAccount) {
    activeStore.accountLoggedIn = true;
  }
  await tester.pumpWidget(FullTekPosApp(store: activeStore));
  // Advance past Modèle 11 logo animation (800ms) cleanly.
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pumpAndSettle();

  if (pin != null) {
    await unlockWithPinPad(tester, pin);
  }
  return activeStore;
}

/// Unlocks [PinLoginScreen] via quick profile card or 4-digit PIN pad.
Future<void> unlockWithPinPad(WidgetTester tester, String pin) async {
  final quickKey = find.byKey(Key('quick_pin_$pin'));
  if (quickKey.evaluate().isNotEmpty) {
    await tester.ensureVisible(quickKey.first);
    await tester.tap(quickKey.first);
    await tester.pumpAndSettle();
    return;
  }
  for (var i = 0; i < pin.length; i++) {
    final d = pin[i];
    await tapFirst(tester, [find.byKey(Key('pin_key_$d')), find.text(d)]);
  }
}

/// Logs in through [AccountLoginScreen] UI using real `dart:io` HTTP handling.
Future<void> loginViaAccountScreen(
  WidgetTester tester, {
  String username = 'darelkram41',
  String password = 'FullTek@2026',
  bool useDemoButton = false,
}) async {
  if (useDemoButton) {
    await tapFirst(tester, [
      find.byKey(const Key('account_demo_btn')),
      find.textContaining('démo'),
      find.textContaining('Demo'),
    ]);
  } else {
    final userField = findAny([
      find.byKey(const Key('account_user_input')),
      find.byType(TextField).at(0),
    ]);
    final passField = findAny([
      find.byKey(const Key('account_pass_input')),
      find.byType(TextField).at(1),
    ]);
    await tester.enterText(userField, username);
    await tester.enterText(passField, password);
    await tester.pump();
  }

  await tester.runAsync(() async {
    await runWithRealHttpOverrides(() async {
      await tester.tap(
        findAny([
          find.byKey(const Key('account_login_btn')),
          find.textContaining('Ouvrir mon espace'),
          find.textContaining('Open my Resto'),
        ]).first,
      );
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
  });
  await tester.pumpAndSettle();
}

/// Navigates between the 6 top-level shell destinations using visible FR/AR/EN
/// labels with optional known Key fallback.
Future<void> tapTab(
  WidgetTester tester,
  List<String> labels, {
  Key? fallbackKey,
}) async {
  final candidates = <Finder>[
    if (fallbackKey != null) find.byKey(fallbackKey),
    for (final label in labels) find.text(label),
    for (final label in labels) find.textContaining(label),
  ];
  await tapFirst(tester, candidates);
}

/// Convenience tab helpers for all 6 shell screens (`PROJECT.md` F12/F15/F17).
Future<void> goToPosTab(WidgetTester tester) => tapTab(tester, [
  'Caisse',
  'الصندوق',
  'Register',
], fallbackKey: const Key('nav_tab_pos'));

Future<void> goToFloorPlanTab(WidgetTester tester) => tapTab(tester, [
  'Plan de Salle',
  'Plan de salle',
  'مخطط الصالة',
  'Floor Plan',
], fallbackKey: const Key('nav_tab_floor'));

Future<void> goToKdsTab(WidgetTester tester) => tapTab(tester, [
  'Cuisine KDS',
  'KDS Cuisine',
  'شاشة المطبخ',
  'Kitchen KDS',
], fallbackKey: const Key('nav_tab_kds'));

Future<void> goToKarniTab(WidgetTester tester) => tapTab(tester, [
  'Carnet Karni',
  'Karni',
  'دفتر الكارني',
  'Karni Credit',
], fallbackKey: const Key('nav_tab_karni'));

Future<void> goToDashboardTab(WidgetTester tester) => tapTab(tester, [
  'Tableau de Bord',
  'Dashboard',
  'لوحة التحكم',
], fallbackKey: const Key('nav_tab_dashboard'));

Future<void> goToClosingZTab(WidgetTester tester) => tapTab(tester, [
  'Clôture Z & Sync',
  'Clôture Z',
  'إغلاق Z والمزامنة',
  'Z-Close & Sync',
], fallbackKey: const Key('nav_tab_closing'));

/// Selects one of the 5 Full-Tek themes (`01`, `04`, `06`, `07`, `11`) via UI
/// pill or popup/dropdown menu.
Future<void> selectTheme(
  WidgetTester tester,
  FullTekThemeId id,
  String code,
) async {
  final directPill = findAny([
    find.byKey(Key('theme_btn_$code')),
    find.byKey(Key('shell_theme_$code')),
    find.text(code),
  ]);
  if (directPill.evaluate().isNotEmpty) {
    await tester.tap(directPill.first);
    await tester.pumpAndSettle();
    return;
  }

  final shellMenu = findAny([
    find.byKey(const Key('shell_theme_menu')),
    find.byKey(const Key('theme_dropdown_login')),
    find.byIcon(Icons.palette_rounded),
    find.byIcon(Icons.palette_outlined),
  ]);
  if (shellMenu.evaluate().isNotEmpty) {
    await tester.tap(shellMenu.first);
    await tester.pumpAndSettle();
    final spec = FullTekThemes.all[id]!;
    final option = findAny([
      find.textContaining(spec.labelFr),
      find.textContaining(spec.labelEn),
      find.textContaining(spec.labelAr),
      find.textContaining('$code ·'),
    ]);
    if (option.evaluate().isNotEmpty) {
      await tester.tap(option.last);
      await tester.pumpAndSettle();
      return;
    }
  }
}

/// Switches UI language (`fr`, `ar`, `en`) via 1-click pills or menu.
Future<void> selectLang(WidgetTester tester, String code) async {
  final upper = code.toUpperCase();
  final direct = findAny([
    find.byKey(Key('shell_lang_$code')),
    find.byKey(Key('lang_btn_$code')),
    find.byKey(Key('account_lang_$code')),
    find.text(upper),
  ]);
  if (direct.evaluate().isNotEmpty) {
    await tester.tap(direct.first);
    await tester.pumpAndSettle();
    return;
  }

  final menu = find.byKey(const Key('shell_lang_menu'));
  if (menu.evaluate().isNotEmpty) {
    await tester.tap(menu.first);
    await tester.pumpAndSettle();
    final label = switch (code) {
      'ar' => 'العربية',
      'en' => 'English',
      _ => 'Français',
    };
    await tester.tap(find.textContaining(label).last);
    await tester.pumpAndSettle();
  }
}

/// Switches service mode (`Sur place | Emporter | Livraison`) in the top bar.
Future<void> selectServiceMode(WidgetTester tester, ServiceMode mode) async {
  await tapFirst(tester, [
    find.byKey(Key('service_mode_${mode.name}')),
    find.text(mode.fr),
    find.textContaining(mode.fr),
    find.text(mode.ar),
    find.textContaining(mode.ar),
    find.text(mode.en),
    find.textContaining(mode.en),
  ]);
}

/// Selects a Nouakchott delivery zone by [zoneNameFragment] via the delivery
/// dropdown or direct chip/button if rendered.
Future<void> selectDeliveryZoneUi(
  WidgetTester tester,
  String zoneNameFragment,
) async {
  final dropdown = find.byKey(const Key('delivery_zone_dropdown'));
  if (dropdown.evaluate().isNotEmpty) {
    await tester.ensureVisible(dropdown.first);
    await tester.tap(dropdown.first);
    await tester.pumpAndSettle();
    final option = find.textContaining(zoneNameFragment);
    if (option.evaluate().isNotEmpty) {
      await tester.tap(option.last);
      await tester.pumpAndSettle();
      return;
    }
  }
  final direct = find.textContaining(zoneNameFragment);
  if (direct.evaluate().isNotEmpty) {
    await tester.tap(direct.first);
    await tester.pumpAndSettle();
  }
}

/// Toggles Training Mode (« Mode Formation ») via top bar if present, or via
/// Owner Dashboard tab and returns to Register tab when [returnToPos] is true.
Future<void> toggleTrainingModeUi(
  WidgetTester tester, {
  bool returnToPos = true,
}) async {
  final direct = findAny([
    find.byKey(const Key('training_mode_toggle')),
    find.byKey(const Key('dashboard_training_switch')),
    find.textContaining('Mode Formation'),
  ]);
  if (direct.evaluate().isNotEmpty) {
    await tester.ensureVisible(direct.first);
    await tester.tap(direct.first);
    await tester.pumpAndSettle();
    return;
  }
  await goToDashboardTab(tester);
  await tapFirst(tester, [
    find.byKey(const Key('dashboard_training_switch')),
    find.byKey(const Key('training_mode_toggle')),
    find.textContaining('Mode Formation'),
  ]);
  if (returnToPos) {
    await goToPosTab(tester);
  }
}

/// Taps a dish tile in the POS register using its key or bilingual FR/AR/EN name.
Future<void> tapMenuItemTile(WidgetTester tester, MenuItem item) async {
  await tapFirst(tester, [
    find.byKey(Key('menu_item_${item.id}')),
    find.text(item.nameFr),
    find.textContaining(item.nameFr),
    find.text(item.nameAr),
  ]);
}

/// Records any FlutterError thrown during [action] (used to assert zero
/// `RenderFlex` overflow exceptions on narrow viewports).
Future<List<FlutterErrorDetails>> captureFlutterErrors(
  Future<void> Function() action,
) async {
  final errors = <FlutterErrorDetails>[];
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    errors.add(details);
  };
  try {
    await action();
  } finally {
    FlutterError.onError = originalOnError;
  }
  return errors;
}

/// Pure `dart:io` loopback HTTP server mocking `apps/cloud-api` endpoints
/// defined in `PROJECT.md § 1` for deterministic Flutter E2E tests.
class MockCloudApiServer {
  HttpServer? _server;

  bool failCatalog500 = false;
  bool returnEmptyCatalog = false;
  bool returnMalformedCatalog = false;
  bool failSync500 = false;
  bool failAvailability500 = false;

  int catalogRequestCount = 0;
  final List<Map<String, dynamic>> receivedSyncBatches = [];
  final List<Map<String, dynamic>> receivedSyncItems = [];
  final List<Map<String, dynamic>> availabilityUpdates = [];
  final List<Map<String, dynamic>> kdsUpdates = [];

  late List<Map<String, dynamic>> catalogProducts;
  late List<Map<String, dynamic>> catalogCategories;
  final List<Map<String, dynamic>> _syncedRealOrders = [];

  MockCloudApiServer() {
    _resetDefaultCatalog();
  }

  String get baseUrl => 'http://127.0.0.1:${_server!.port}';
  int get port => _server!.port;

  void _resetDefaultCatalog() {
    catalogCategories = [
      {
        'id': 'cat-grill',
        'code': 'GRILL',
        'nameFr': 'Grillades Cloud',
        'nameAr': 'مشويات السحابة',
        'nameEn': 'Cloud Grills',
        'icon': '🍖',
        'sortOrder': 1,
        'active': true,
      },
      {
        'id': 'cat-rim',
        'code': 'RIM',
        'nameFr': 'Spécialités RIM',
        'nameAr': 'أطباق موريتانية',
        'nameEn': 'Mauritanian',
        'icon': '🍲',
        'sortOrder': 2,
        'active': true,
      },
      {
        'id': 'cat-drinks',
        'code': 'DRINKS',
        'nameFr': 'Boissons & Ataya',
        'nameAr': 'مشروبات وأتاي',
        'nameEn': 'Drinks & Tea',
        'icon': '🍵',
        'sortOrder': 3,
        'active': true,
      },
    ];

    catalogProducts = [
      {
        'id': 'item-mechoui',
        'categoryId': 'cat-grill',
        'sku': 'RST-GRL-01',
        'nameFr': 'Méchoui Royal',
        'nameAr': 'مشوي ملكي',
        'nameEn': 'Royal Mechoui',
        'icon': '🍖',
        'priceMru': 1400,
        'kitchenStation': 'GRILL',
        'isTop': true,
        'isOutOfStock': false,
        'available': true,
        'modifiers': [
          {
            'id': 'mg-cuisson',
            'nameFr': 'Cuisson',
            'nameAr': 'درجة الطهي',
            'nameEn': 'Cooking',
            'required': false,
            'multiSelect': false,
            'options': [
              {
                'id': 'opt-bien',
                'nameFr': 'Bien cuit',
                'nameAr': 'ناضج جداً',
                'nameEn': 'Well done',
                'extraPriceMru': 0,
                'bomKey': '',
              },
              {
                'id': 'opt-apoint',
                'nameFr': 'À point',
                'nameAr': 'متوسط',
                'nameEn': 'Medium',
                'extraPriceMru': 0,
                'bomKey': '',
              },
            ],
          },
          {
            'id': 'mg-extras',
            'nameFr': 'Suppléments',
            'nameAr': 'إضافات',
            'nameEn': 'Extras',
            'required': false,
            'multiSelect': true,
            'options': [
              {
                'id': 'opt-mozz',
                'nameFr': 'Mozzarella',
                'nameAr': 'موزاريلا',
                'nameEn': 'Mozzarella',
                'extraPriceMru': 60,
                'bomKey': '+Mozzarella',
              },
            ],
          },
        ],
      },
      {
        'id': 'item-thieb',
        'categoryId': 'cat-rim',
        'sku': 'RIM-001',
        'nameFr': 'Thiéboudienne Royal',
        'nameAr': 'تيبوجين ملكي',
        'nameEn': 'Royal Thieboudienne',
        'icon': '🐟',
        'priceMru': 450,
        'kitchenStation': 'KITCHEN',
        'isTop': true,
        'isOutOfStock': false,
        'available': true,
        'modifiers': const [],
      },
      {
        'id': 'item-ataya',
        'categoryId': 'cat-drinks',
        'sku': 'DRK-001',
        'nameFr': 'Thé Ataya',
        'nameAr': 'أتاي موريتاني',
        'nameEn': 'Mauritanian Ataya',
        'icon': '🍵',
        'priceMru': 150,
        'kitchenStation': 'BAR',
        'isTop': false,
        'isOutOfStock': false,
        'available': true,
        'modifiers': const [],
      },
    ];
  }

  Future<void> start({int port = 0}) async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _server!.listen(_handleRequest);
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  void setProductAvailability(String idOrSku, {required bool available}) {
    for (final p in catalogProducts) {
      if (p['id'] == idOrSku || p['sku'] == idOrSku) {
        p['available'] = available;
        p['isOutOfStock'] = !available;
      }
    }
  }

  void setProductPrice(String idOrSku, double priceMru) {
    for (final p in catalogProducts) {
      if (p['id'] == idOrSku || p['sku'] == idOrSku) {
        p['priceMru'] = priceMru;
      }
    }
  }

  Future<void> _handleRequest(HttpRequest req) async {
    final path = req.uri.path;
    final method = req.method.toUpperCase();
    final rawBody = await utf8.decoder.bind(req).join();
    Map<String, dynamic> bodyJson = {};
    if (rawBody.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawBody);
        if (decoded is Map<String, dynamic>) bodyJson = decoded;
      } catch (_) {}
    }

    req.response.headers.contentType = ContentType.json;

    if (method == 'GET' && path == '/health') {
      req.response.statusCode = 200;
      req.response.write(jsonEncode({'ok': true}));
      await req.response.close();
      return;
    }

    if (method == 'POST' && path == '/api/auth/login') {
      final user = '${bodyJson['username'] ?? ''}'.trim();
      final pass = '${bodyJson['password'] ?? ''}'.trim();
      if (pass != 'FullTek@2026') {
        req.response.statusCode = 401;
        req.response.write(jsonEncode({'error': 'Identifiants invalides'}));
        await req.response.close();
        return;
      }

      final Map<String, dynamic>? tenant = switch (user) {
        'darelkram41' => {
          'id': 1,
          'tenantId': 'FT-1041',
          'code': 'FT-1041',
          'name': 'Dar El-Karam Resto',
          'module': 'resto',
          'status': 'warn',
          'daysLeft': 2,
          'defaultLang': 'fr',
          'enabledThemes': ['01', '04', '06', '07', '11'],
          'payMethods': [
            'Cash',
            'Bankily',
            'Masrivi',
            'Sedad',
            'Bimbank',
            'Click',
            'Karni',
          ],
          'ownerPin': '7410',
        },
        'khaimandb90' => {
          'id': 5,
          'tenantId': 'FT-5090',
          'code': 'FT-5090',
          'name': 'Café Khaima Nouadhibou',
          'module': 'resto',
          'status': 'trial',
          'daysLeft': 9,
          'defaultLang': 'fr',
          'enabledThemes': ['01', '07'],
          'payMethods': ['Cash', 'Bankily', 'Masrivi', 'Sedad'],
          'ownerPin': '1540',
        },
        'albaraka88' => {
          'id': 2,
          'tenantId': 'FT-2088',
          'code': 'FT-2088',
          'name': 'Al-Baraka Market',
          'module': 'market',
          'status': 'active',
          'daysLeft': 30,
        },
        'elwiam12' => {
          'id': 4,
          'tenantId': 'FT-4012',
          'code': 'FT-4012',
          'name': 'Boucherie El-Wiam',
          'module': 'resto',
          'status': 'expired',
          'daysLeft': 0,
        },
        _ => null,
      };

      if (tenant == null) {
        req.response.statusCode = 401;
        req.response.write(jsonEncode({'error': 'Identifiants invalides'}));
        await req.response.close();
        return;
      }

      req.response.statusCode = 200;
      req.response.write(
        jsonEncode({'ok': true, 'token': 'mock-jwt-$user', 'tenant': tenant}),
      );
      await req.response.close();
      return;
    }

    // All /api/pos/* routes require Bearer token
    final auth = req.headers.value('authorization') ?? '';
    if (!auth.startsWith('Bearer ')) {
      req.response.statusCode = 401;
      req.response.write(jsonEncode({'error': 'Unauthorized'}));
      await req.response.close();
      return;
    }

    if (method == 'GET' && path == '/api/pos/catalog') {
      catalogRequestCount++;
      if (failCatalog500) {
        req.response.statusCode = 500;
        req.response.write(jsonEncode({'error': 'Internal Server Error'}));
        await req.response.close();
        return;
      }
      if (returnMalformedCatalog) {
        req.response.statusCode = 200;
        req.response.write('{not-valid-json');
        await req.response.close();
        return;
      }
      final isKhaima = auth.contains('khaimandb90');
      req.response.statusCode = 200;
      req.response.write(
        jsonEncode({
          'ok': true,
          'tenantId': isKhaima ? 5 : 1,
          'tenant': isKhaima
              ? {
                  'id': 5,
                  'code': 'FT-5090',
                  'name': 'Café Khaima Nouadhibou',
                  'module': 'resto',
                  'defaultLang': 'fr',
                  'enabledThemes': ['01', '07'],
                  'payMethods': ['Cash', 'Bankily', 'Masrivi', 'Sedad'],
                  'daysLeft': 9,
                  'ownerPin': '1540',
                  'deliveryZones': DeliveryZone.nouakchottPresets
                      .map((z) => z.toJson())
                      .toList(),
                  'freeDeliveryAboveMru': 1500,
                }
              : {
                  'id': 1,
                  'code': 'FT-1041',
                  'name': 'Dar El-Karam Resto',
                  'module': 'resto',
                  'defaultLang': 'fr',
                  'enabledThemes': ['01', '04', '06', '07', '11'],
                  'payMethods': [
                    'Cash',
                    'Bankily',
                    'Masrivi',
                    'Sedad',
                    'Bimbank',
                    'Click',
                    'Karni',
                  ],
                  'daysLeft': 2,
                  'ownerPin': '7410',
                  'deliveryZones': DeliveryZone.nouakchottPresets
                      .map((z) => z.toJson())
                      .toList(),
                  'freeDeliveryAboveMru': 1500,
                },
          'categories': returnEmptyCatalog ? const [] : catalogCategories,
          'products': returnEmptyCatalog ? const [] : catalogProducts,
          'diningZones': [
            {
              'id': 'zone-main',
              'nameFr': 'Terrasse',
              'nameAr': 'الشرفة',
              'nameEn': 'Terrace',
              'zoneType': 'TERRACE',
              'isVip': false,
              'minSpendMru': 0,
              'tables': [
                {
                  'id': 'T1',
                  'code': 'T-01',
                  'seats': 4,
                  'shape': 'round',
                  'x': 0.15,
                  'y': 0.2,
                  'status': 'free',
                },
                {
                  'id': 'T2',
                  'code': 'T-02',
                  'seats': 4,
                  'shape': 'square',
                  'x': 0.45,
                  'y': 0.2,
                  'status': 'free',
                },
              ],
            },
            {
              'id': 'zone-khaima',
              'nameFr': 'Salon Khaima VIP',
              'nameAr': 'خيمة VIP',
              'nameEn': 'Khaima VIP Lounge',
              'zoneType': 'KHAIMA',
              'isVip': true,
              'minSpendMru': 3000,
              'tables': [
                {
                  'id': 'K1',
                  'code': 'KHAIMA-1',
                  'seats': 10,
                  'shape': 'khaima',
                  'x': 0.75,
                  'y': 0.35,
                  'status': 'reserved',
                  'minSpendMru': 3000,
                },
              ],
            },
          ],
          'reservationsVip': [
            {
              'id': 'RES-101',
              'customerName': 'Famille Ould Ahmed',
              'phone': '+222 36 12 44 90',
              'zoneId': 'zone-khaima',
              'tableId': 'K1',
              'guests': 8,
              'timeSlot': '20:30',
              'arbounMru': 2000,
              'status': 'confirmed',
            },
          ],
          'ingredients': [
            {
              'id': 'ing-beef',
              'sku': 'ING-BEEF',
              'nameFr': 'Viande hachée',
              'nameAr': 'لحم مفروم',
              'nameEn': 'Ground Beef',
              'unit': 'kg',
              'pmpCostMru': 320,
              'currentStock': 25.0,
              'minStock': 5.0,
            },
            {
              'id': 'ing-box',
              'sku': 'ING-BOX',
              'nameFr': 'Boîte Emporter',
              'nameAr': 'علبة سفري',
              'nameEn': 'Takeaway Box',
              'unit': 'unit',
              'pmpCostMru': 15,
              'currentStock': 100.0,
              'minStock': 20.0,
            },
            {
              'id': 'ing-mozz',
              'sku': 'ING-MOZZ',
              'nameFr': 'Mozzarella',
              'nameAr': 'جبن موزاريلا',
              'nameEn': 'Mozzarella',
              'unit': 'kg',
              'pmpCostMru': 280,
              'currentStock': 6.0,
              'minStock': 1.5,
            },
          ],
          'recipesBom': [
            {
              'id': 1,
              'productId': 'item-mechoui',
              'productSku': 'RST-GRL-01',
              'ingredientId': 'ing-beef',
              'ingredientSku': 'ING-BEEF',
              'qtyPerUnit': 0.5,
              'conditionChannel': 'ALL',
              'modifierKey': '',
            },
            {
              'id': 2,
              'productId': 'item-mechoui',
              'productSku': 'RST-GRL-01',
              'ingredientId': 'ing-box',
              'ingredientSku': 'ING-BOX',
              'qtyPerUnit': 1.0,
              'conditionChannel': 'TAKEAWAY_DELIVERY',
              'modifierKey': '',
            },
            {
              'id': 3,
              'productId': 'item-mechoui',
              'productSku': 'RST-GRL-01',
              'ingredientId': 'ing-mozz',
              'ingredientSku': 'ING-MOZZ',
              'qtyPerUnit': 0.06,
              'conditionChannel': 'ALL',
              'modifierKey': '+Mozzarella',
            },
          ],
          'karniCustomers': [
            {
              'id': 'KAR-1',
              'name': 'Sidi Mohamed Ould Ahmed',
              'phone': '+222 46 11 22 33',
              'creditLimitMru': 10000,
              'balanceDueMru': 1500,
            },
          ],
        }),
      );
      await req.response.close();
      return;
    }

    if (method == 'POST' && path == '/api/pos/sync') {
      if (failSync500) {
        req.response.statusCode = 500;
        req.response.write(jsonEncode({'error': 'Sync error'}));
        await req.response.close();
        return;
      }
      receivedSyncBatches.add(bodyJson);
      final items = (bodyJson['items'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      receivedSyncItems.addAll(items);
      for (final item in items) {
        if (item['entity_type'] == 'order') {
          final payload = (item['payload'] as Map?)?.cast<String, dynamic>();
          if (payload != null &&
              payload['is_training'] != true &&
              payload['isTraining'] != true) {
            _syncedRealOrders.add(payload);
          }
        }
      }
      req.response.statusCode = 200;
      req.response.write(
        jsonEncode({
          'ok': true,
          'tenantId': 1,
          'synced': items.length,
          'syncedAt': DateTime.now().toIso8601String(),
        }),
      );
      await req.response.close();
      return;
    }

    if (method == 'PATCH' &&
        path.startsWith('/api/pos/products/') &&
        path.endsWith('/availability')) {
      if (failAvailability500) {
        req.response.statusCode = 500;
        req.response.write(jsonEncode({'error': 'Server error'}));
        await req.response.close();
        return;
      }
      final parts = path.split('/');
      final idOrSku = parts.length >= 5 ? parts[4] : '';
      final available = bodyJson.containsKey('available')
          ? bodyJson['available'] == true
          : bodyJson['isOutOfStock'] != true;
      setProductAvailability(idOrSku, available: available);
      availabilityUpdates.add({'idOrSku': idOrSku, 'available': available});
      req.response.statusCode = 200;
      req.response.write(
        jsonEncode({
          'ok': true,
          'productId': idOrSku,
          'sku': idOrSku,
          'available': available,
          'isOutOfStock': !available,
        }),
      );
      await req.response.close();
      return;
    }

    if (method == 'GET' && path == '/api/pos/kds') {
      req.response.statusCode = 200;
      req.response.write(
        jsonEncode({'ok': true, 'tickets': _syncedRealOrders}),
      );
      await req.response.close();
      return;
    }

    if (method == 'PATCH' && path.startsWith('/api/pos/kds/')) {
      kdsUpdates.add({'path': path, 'body': bodyJson});
      req.response.statusCode = 200;
      req.response.write(jsonEncode({'ok': true}));
      await req.response.close();
      return;
    }

    if (method == 'GET' && path == '/api/pos/kpis') {
      final rev = _syncedRealOrders.fold<double>(
        0,
        (s, o) => s + ((o['total_mru'] as num?)?.toDouble() ?? 0),
      );
      final count = _syncedRealOrders.length;
      req.response.statusCode = 200;
      req.response.write(
        jsonEncode({
          'ok': true,
          'todayRevenueMru': rev,
          'todayTicketsCount': count,
          'averageBasketMru': count == 0 ? 0 : (rev / count),
        }),
      );
      await req.response.close();
      return;
    }

    req.response.statusCode = 404;
    req.response.write(jsonEncode({'error': 'Not found'}));
    await req.response.close();
  }
}
