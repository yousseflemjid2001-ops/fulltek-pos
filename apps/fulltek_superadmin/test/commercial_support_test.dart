import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fulltek_superadmin/main.dart';
import 'package:fulltek_superadmin/models/models.dart';
import 'package:fulltek_superadmin/screens/new_store_wizard.dart';
import 'package:fulltek_superadmin/screens/store_detail_screen.dart';
import 'package:fulltek_superadmin/services/api_service.dart';
import 'package:fulltek_superadmin/theme/app_theme.dart';

void main() {
  const allMauritanianPayMethods = [
    'Cash',
    'Bankily',
    'Masrivi',
    'Sedad',
    'Bimbank',
    'Click',
    'Karni',
  ];

  tearDown(() {
    ApiService.resetForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  TenantStore buildCommercialStore({int id = 88}) => TenantStore(
        id: id,
        name: 'Mauritanie Négoce B2B',
        module: StoreModule.commercial,
        city: 'Tevragh Zeina',
        phone: '+222 45 25 80 90',
        plan: 'Entreprise',
        mrr: 5500,
        tills: 3,
        daysLeft: 29,
        status: StoreStatus.active,
        ownerPin: '4820',
      )
        ..tenantId = 'FT-8801'
        ..username = 'mauritanienegoce'
        ..manager = 'Cheikh Ould Brahim'
        ..subType = 'Négoce / Distribution'
        ..legalName = 'Mauritanie Négoce SARL'
        ..nif = '00528190'
        ..rc = 'RC-NKC-4418'
        ..district = 'Zone Industrielle'
        ..payMethods = Set<String>.from(allMauritanianPayMethods)
        ..hardware = {'printer', 'scanner', 'drawer'}
        ..features = {
          'quotes_invoices',
          'sales_cycle',
          'purchases_pmp',
          'pos_register',
          'treasury',
          'cheques_due',
          'objectives',
          'karni_credit',
        };

  group('StoreModule.commercial Model, Theme, i18n & CSV', () {
    test('serializes and deserializes commercial tenant with Mauritanian fields', () {
      expect(StoreModule.commercial.name, 'commercial');

      final store = buildCommercialStore();
      expect(store.moduleName, 'Full·Tek Commercial');
      expect(store.moduleColor, FTColors.commercial);

      final json = store.toJson();
      expect(json['module'], 'commercial');
      expect(json['nif'], '00528190');
      expect(json['rc'], 'RC-NKC-4418');
      expect(json['subType'], 'Négoce / Distribution');
      expect(Set<String>.from(json['payMethods'] as List),
          Set<String>.from(allMauritanianPayMethods));

      final roundTrip = TenantStore.fromJson({...json, 'id': 88});
      expect(roundTrip.module, StoreModule.commercial);
      expect(roundTrip.moduleName, 'Full·Tek Commercial');
      expect(roundTrip.moduleColor, FTColors.commercial);
      expect(roundTrip.nif, '00528190');
      expect(roundTrip.rc, 'RC-NKC-4418');
      expect(roundTrip.legalName, 'Mauritanie Négoce SARL');
      expect(roundTrip.payMethods, Set<String>.from(allMauritanianPayMethods));
    });

    test('kStrings provides fr, ar, en commercial keys and updated login_hero_title', () {
      for (final lang in ['fr', 'ar', 'en']) {
        final strings = kStrings[lang]!;
        expect(strings['mod_commercial'], isNotNull);
        expect(strings['mod_commercial'], isNotEmpty);
        expect(strings['flt_commercial'], isNotNull);
        expect(strings['flt_commercial'], isNotEmpty);
        expect(strings['login_hero_title'], isNotNull);
      }
      expect(kStrings['fr']!['login_hero_title'], contains('Commercial'));
      expect(kStrings['en']!['login_hero_title'], contains('Commercial'));
      expect(kStrings['ar']!['login_hero_title'], contains('التجارة'));
    });

    test('catalogSampleCsvForModule(commercial) uses catalogImport.js-compatible headers & rows', () {
      final csv = catalogSampleCsvForModule(StoreModule.commercial);
      final lines = csv.trim().split('\n');
      expect(lines.length, greaterThanOrEqualTo(4));
      expect(
        lines.first,
        'sku,barcode,name_fr,name_ar,category,unit,price_retail,price_whole,price_cost,qty,track_fefo,requires_cnam',
      );
      expect(csv, contains('COM-001'));
      expect(csv, contains('COM-002'));
      expect(csv, contains('COM-003'));
    });

    test('initialStores includes a realistic Mauritanian commercial demo store', () {
      final commercialStores =
          initialStores().where((s) => s.module == StoreModule.commercial).toList();
      expect(commercialStores, isNotEmpty);
      final demo = commercialStores.first;
      expect(demo.nif, isNotEmpty);
      expect(demo.rc, isNotEmpty);
      expect(demo.payMethods, containsAll(allMauritanianPayMethods));
    });
  });

  group('ApiService commercial tenant CRUD', () {
    test('createTenant & updateTenant send and parse commercial payload', () async {
      ApiService.baseUrl = 'http://api.test:4000';
      ApiService.setToken('jwt-superadmin-test');

      final calls = <({String method, String url, Map<String, dynamic> body})>[];
      ApiService.httpTransport = (
        method,
        url, {
        body,
        headers,
        timeout = const Duration(seconds: 5),
      }) async {
        final decoded = jsonDecode(body!) as Map<String, dynamic>;
        calls.add((method: method, url: url, body: decoded));

        if (method == 'POST' && url.endsWith('/api/admin/tenants')) {
          return (
            status: 201,
            body: jsonEncode({
              'tenant': {
                ...decoded,
                'id': 42,
                'status': 'active',
              },
            }),
          );
        }
        if (method == 'PATCH' && url.endsWith('/api/admin/tenants/42')) {
          return (
            status: 200,
            body: jsonEncode({
              'tenant': {
                ...decoded,
                'id': 42,
                'status': 'active',
              },
            }),
          );
        }
        return (status: 404, body: '{"error":"Not found"}');
      };

      final input = buildCommercialStore(id: 42);
      final created = await ApiService.createTenant(input);
      expect(created.ok, isTrue);
      expect(created.data, isNotNull);
      expect(created.data!.id, 42);
      expect(created.data!.module, StoreModule.commercial);
      expect(created.data!.payMethods, containsAll(allMauritanianPayMethods));
      expect(calls[0].method, 'POST');
      expect(calls[0].body['module'], 'commercial');
      expect(calls[0].body['nif'], '00528190');
      expect(calls[0].body['rc'], 'RC-NKC-4418');
      expect(calls[0].body['subType'], 'Négoce / Distribution');
      expect(calls[0].body['payMethods'], containsAll(allMauritanianPayMethods));

      input.nif = '00999888';
      input.rc = 'RC-NKC-9999';
      input.tills = 5;
      final updated = await ApiService.updateTenant(input);
      expect(updated.ok, isTrue);
      expect(updated.data!.nif, '00999888');
      expect(updated.data!.rc, 'RC-NKC-9999');
      expect(updated.data!.tills, 5);
      expect(calls[1].method, 'PATCH');
      expect(calls[1].url, endsWith('/api/admin/tenants/42'));
      expect(calls[1].body['nif'], '00999888');
      expect(calls[1].body['rc'], 'RC-NKC-9999');
    });
  });

  group('NewStoreWizard Commercial Flow', () {
    testWidgets(
        'renders 4 modules without overflow on narrow 360x800 screen and creates commercial store',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      TenantStore? poppedStore;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme(),
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    poppedStore = await Navigator.of(ctx).push<TenantStore>(
                      MaterialPageRoute(
                        builder: (_) => const NewStoreWizard(lang: 'fr'),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Verify 4 module cards render with no overflow on 360px screen
      expect(find.byKey(const ValueKey('wizard_mod_resto')), findsOneWidget);
      expect(find.byKey(const ValueKey('wizard_mod_market')), findsOneWidget);
      expect(find.byKey(const ValueKey('wizard_mod_pharma')), findsOneWidget);
      expect(find.byKey(const ValueKey('wizard_mod_commercial')), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Select Commercial
      await tester.tap(find.byKey(const ValueKey('wizard_mod_commercial')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Verify exact 4 commercial subtypes
      expect(find.text('Négoce / Distribution'), findsOneWidget);
      expect(find.text('Grossiste / Import-Export'), findsOneWidget);
      expect(find.text('Quincaillerie / Matériaux'), findsOneWidget);
      expect(find.text('Services & Facturation B2B'), findsOneWidget);

      await tester.tap(find.text('Grossiste / Import-Export'));
      await tester.pumpAndSettle();

      // Fill required Step 1 fields
      final step1List = find.byType(ListView).first;
      await tester.dragUntilVisible(
        find.widgetWithText(TextFormField, 'Nom du commerce *'),
        step1List,
        const Offset(0, -150),
      );
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Nom du commerce *'), 'Atlas Import SARL');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Nom complet du gérant *'), 'Sidi Mohamed');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'WhatsApp gérant *'), '45112233');

      // Administrative dossier auto-expands for commercial module
      await tester.dragUntilVisible(
        find.widgetWithText(TextFormField, 'Raison sociale'),
        step1List,
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Raison sociale'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'NIF'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Registre commerce'), findsOneWidget);

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Raison sociale'), 'Atlas Import Export SARL');
      await tester.enterText(find.widgetWithText(TextFormField, 'NIF'), '00771234');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Registre commerce'), 'RC-NKC-7788');

      // Advance to Step 2
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      expect(find.text('Licence, règlement & matériel'), findsOneWidget);
      expect(find.text('4 postes · Achats/PMP · Caisse & Trésorerie'), findsOneWidget);

      // Verify Bimbank & Click in initial SaaS payment choices
      final step2List = find.byType(ListView).first;
      await tester.dragUntilVisible(
        find.text('Règlement initial reçu'),
        step2List,
        const Offset(0, -250),
      );
      expect(find.widgetWithText(ChoiceChip, 'Bimbank'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Click'), findsOneWidget);

      // Expand advanced options & verify Commercial features + all 7 Mauritanian payment chips
      await tester.dragUntilVisible(
        find.text('Fonctions métier, paiements & thèmes UI'),
        step2List,
        const Offset(0, -250),
      );
      await tester.tap(find.text('Fonctions métier, paiements & thèmes UI'));
      await tester.pumpAndSettle();

      await tester.dragUntilVisible(
        find.text('Modules commerciaux'),
        step2List,
        const Offset(0, -200),
      );
      expect(find.text('Devis & Factures A4'), findsOneWidget);
      expect(find.text('Commandes, BL & Avoirs'), findsOneWidget);
      expect(find.text('Achats, Fournisseurs & PMP'), findsOneWidget);
      expect(find.text('Caisse intégrée & Rapports Z'), findsOneWidget);
      expect(find.text('Trésorerie Caisse & Banques'), findsOneWidget);
      expect(find.text('Chèques & traites à échéance'), findsOneWidget);
      expect(find.text('Objectifs mensuels & Analyses'), findsOneWidget);
      expect(find.text('Encours clients & Karni'), findsOneWidget);

      await tester.dragUntilVisible(
        find.text('Paiements en caisse'),
        step2List,
        const Offset(0, -200),
      );
      for (final method in allMauritanianPayMethods) {
        final chipFinder = find.widgetWithText(FilterChip, method);
        expect(chipFinder, findsOneWidget);
        final chip = tester.widget<FilterChip>(chipFinder);
        expect(chip.selected, isTrue);
      }

      // Toggle Karni off and back on to confirm interactive state
      await tester.dragUntilVisible(
        find.widgetWithText(FilterChip, 'Karni'),
        step2List,
        const Offset(0, -150),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Karni'));
      await tester.pumpAndSettle();
      expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Karni')).selected,
          isFalse);
      await tester.tap(find.widgetWithText(FilterChip, 'Karni'));
      await tester.pumpAndSettle();
      expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Karni')).selected,
          isTrue);

      // Advance to Step 3 and verify summary shows commercial + legal/nif/rc
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      expect(find.text('Récapitulatif avant activation'), findsOneWidget);
      expect(find.text('Full·Tek Commercial · Grossiste / Import-Export'), findsOneWidget);
      expect(find.text('Atlas Import Export SARL'), findsOneWidget);
      expect(find.text('00771234'), findsOneWidget);
      expect(find.text('RC-NKC-7788'), findsOneWidget);

      // Activate & Finish
      await tester.tap(find.text('Activer le client'));
      await tester.pumpAndSettle();
      expect(find.text('Client activé avec succès'), findsOneWidget);

      await tester.tap(find.text('Terminer'));
      await tester.pumpAndSettle();

      expect(poppedStore, isNotNull);
      expect(poppedStore!.module, StoreModule.commercial);
      expect(poppedStore!.subType, 'Grossiste / Import-Export');
      expect(poppedStore!.legalName, 'Atlas Import Export SARL');
      expect(poppedStore!.nif, '00771234');
      expect(poppedStore!.rc, 'RC-NKC-7788');
      expect(poppedStore!.payMethods, Set<String>.from(allMauritanianPayMethods));
      expect(poppedStore!.features, containsAll([
        'quotes_invoices',
        'sales_cycle',
        'purchases_pmp',
        'pos_register',
        'treasury',
        'cheques_due',
        'objectives',
        'karni_credit',
      ]));
    });

    testWidgets('renders cleanly at 430x900 and 1280x900 in AR RTL and EN',
        (WidgetTester tester) async {
      // AR RTL at 430x900 (2x2 grid)
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: NewStoreWizard(lang: 'ar'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('wizard_mod_commercial')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('wizard_mod_commercial')));
      await tester.pumpAndSettle();
      expect(find.text('تجارة وتوزيع'), findsOneWidget);
      expect(find.text('تاجر جملة / استيراد وتصدير'), findsOneWidget);
      expect(find.text('خردوات ومواد البناء'), findsOneWidget);
      expect(find.text('خدمات وفوترة للشركات'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // EN at 1280x900 (4-column Row)
      tester.view.physicalSize = const Size(1280, 900);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme(),
          home: const NewStoreWizard(lang: 'en'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('wizard_mod_commercial')));
      await tester.pumpAndSettle();
      expect(find.text('Trading / Distribution'), findsOneWidget);
      expect(find.text('Wholesaler / Import-Export'), findsOneWidget);
      expect(find.text('Hardware / Building Materials'), findsOneWidget);
      expect(find.text('B2B Services & Invoicing'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('SuperAdminHome Commercial Filter & Sample CSV', () {
    testWidgets('Boutiques tab filters by Commercial chip and imports modele_commercial.csv',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final importedCalls = <({String url, Map<String, dynamic> body})>[];

      ApiService.httpTransport = (
        method,
        url, {
        body,
        headers,
        timeout = const Duration(seconds: 5),
      }) async {
        if (url.endsWith('/api/admin/login')) {
          return (
            status: 200,
            body: jsonEncode({
              'ok': true,
              'token': 'jwt-com-filter',
              'expiresIn': 86400,
              'admin': {
                'id': 1,
                'username': 'taha',
                'email': 'taha@fulltek.mr',
                'fullName': 'M. Taha Chouaib',
                'role': 'SUPER_ADMIN',
              },
            }),
          );
        }
        if (url.endsWith('/api/admin/dashboard')) {
          return (
            status: 200,
            body: jsonEncode({
              'stores': [
                {
                  'id': 1,
                  'tenantId': 'FT-1001',
                  'name': 'Resto Sahel',
                  'module': 'resto',
                  'city': 'Nouakchott',
                  'phone': '+22245000001',
                  'plan': 'Pro',
                  'mrr': 3000,
                  'tills': 2,
                  'daysLeft': 20,
                  'status': 'active',
                },
                {
                  'id': 2,
                  'tenantId': 'FT-2002',
                  'name': 'Market Oasis',
                  'module': 'market',
                  'city': 'Ksar',
                  'phone': '+22245000002',
                  'plan': 'Pro',
                  'mrr': 3000,
                  'tills': 2,
                  'daysLeft': 20,
                  'status': 'active',
                },
                {
                  'id': 3,
                  'tenantId': 'FT-3003',
                  'name': 'Pharma Sante',
                  'module': 'pharma',
                  'city': 'Atar',
                  'phone': '+22245000003',
                  'plan': 'Pro',
                  'mrr': 3000,
                  'tills': 2,
                  'daysLeft': 20,
                  'status': 'active',
                },
                {
                  'id': 8,
                  'tenantId': 'FT-8014',
                  'name': 'Mauritanie Négoce & Distribution',
                  'module': 'commercial',
                  'subType': 'Négoce / Distribution',
                  'nif': '00528190',
                  'rc': 'RC-NKC-4418',
                  'city': 'Tevragh Zeina',
                  'phone': '+22245258090',
                  'plan': 'Entreprise',
                  'mrr': 5500,
                  'tills': 3,
                  'daysLeft': 29,
                  'status': 'active',
                  'payMethods': allMauritanianPayMethods,
                },
              ],
              'payments': [],
              'audits': [],
            }),
          );
        }
        if (url.contains('/catalog/import')) {
          final decoded = jsonDecode(body!) as Map<String, dynamic>;
          importedCalls.add((url: url, body: decoded));
          return (
            status: 200,
            body: jsonEncode({
              'ok': true,
              'tenantId': 8,
              'format': 'csv',
              'totalRows': 3,
              'created': 3,
              'updated': 0,
              'categoriesCreated': 3,
              'errors': [],
            }),
          );
        }
        return (status: 404, body: '{"error":"Not found"}');
      };

      await tester.pumpWidget(const FullTekSuperAdminApp(enableSplash: false));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('login_username')), 'taha');
      await tester.enterText(find.byKey(const Key('login_password')), 'secret123');
      await tester.tap(find.byKey(const Key('login_submit')));
      await tester.pumpAndSettle();

      // Switch to Boutiques tab
      await tester.tap(find.text('Boutiques'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('filter_chip_commercial')), findsOneWidget);
      expect(find.byKey(const ValueKey('store_card_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('store_card_2')), findsOneWidget);
      expect(find.byKey(const ValueKey('store_card_3')), findsOneWidget);
      expect(find.byKey(const ValueKey('store_card_8')), findsOneWidget);

      // Tap Commercial filter chip
      await tester.tap(find.byKey(const ValueKey('filter_chip_commercial')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('store_card_8')), findsOneWidget);
      expect(find.byKey(const ValueKey('store_card_1')), findsNothing);
      expect(find.byKey(const ValueKey('store_card_2')), findsNothing);
      expect(find.byKey(const ValueKey('store_card_3')), findsNothing);

      // Tap All filter chip restores all 4
      await tester.tap(find.byKey(const ValueKey('filter_chip_all')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('store_card_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('store_card_8')), findsOneWidget);

      // Select Commercial store in catalog bar dropdown and import sample CSV
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mauritanie Négoce & Distribution').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('stores_catalog_sample_btn')));
      await tester.pumpAndSettle();

      expect(importedCalls, hasLength(1));
      expect(importedCalls.single.url, endsWith('/api/admin/tenants/8/catalog/import'));
      expect(importedCalls.single.body['filename'], 'modele_commercial.csv');
      expect(importedCalls.single.body['csvText'], contains('COM-001'));
    });
  });

  group('StoreDetailScreen Commercial Store', () {
    testWidgets(
        'displays commercial details, NIF/RC, 7 pay methods, edits details, imports sample CSV & generates license',
        (WidgetTester tester) async {
      final clipboardLog = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map?;
          final text = args?['text'] as String?;
          if (text != null) clipboardLog.add(text);
        }
        return null;
      });

      ApiService.setToken('jwt-detail-commercial');
      final importBodies = <Map<String, dynamic>>[];

      ApiService.httpTransport = (
        method,
        url, {
        body,
        headers,
        timeout = const Duration(seconds: 5),
      }) async {
        if (url.contains('/catalog/import')) {
          final decoded = jsonDecode(body!) as Map<String, dynamic>;
          importBodies.add(decoded);
          return (
            status: 200,
            body: jsonEncode({
              'ok': true,
              'tenantId': 88,
              'format': 'csv',
              'totalRows': 3,
              'created': 3,
              'updated': 0,
              'categoriesCreated': 3,
              'errors': [],
            }),
          );
        }
        if (url.contains('/offline-code')) {
          return (
            status: 200,
            body: jsonEncode({
              'ok': true,
              'code': '9182-7364-5501',
              'days': 30,
              'graceDays': 7,
              'storeName': 'Mauritanie Négoce B2B',
              'keyId': 'ed25519-prod-01',
              'issuedAt': '2026-11-20T18:00:00.000Z',
              'expiresAt': '2026-12-20T18:00:00.000Z',
              'signature': 'EdSigCommercialXYZ',
              'leaseToken': 'PayloadCommercial.EdSigCommercialXYZ',
              'publicKey': '-----BEGIN PUBLIC KEY-----\nPUBKEY\n-----END PUBLIC KEY-----',
              'payload': {'tenantId': 88},
            }),
          );
        }
        return (status: 404, body: '{"error":"Not found"}');
      };

      final store = buildCommercialStore();
      var onChangedCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme(),
          home: StoreDetailScreen(
            store: store,
            lang: 'fr',
            tr: (k) => kStrings['fr']?[k] ?? k,
            onExtend: () {},
            onToggleLock: () {},
            onChanged: () => onChangedCalls++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Displays Full·Tek Commercial, NIF, RC, and all 7 Mauritanian payment chips
      expect(find.text('Full·Tek Commercial · Négoce / Distribution'), findsOneWidget);
      expect(find.text('00528190'), findsOneWidget);
      expect(find.text('RC-NKC-4418'), findsOneWidget);

      final detailList = find.byType(ListView).first;
      await tester.dragUntilVisible(
        find.text('Paiements acceptés en caisse'),
        detailList,
        const Offset(0, -250),
      );
      for (final method in allMauritanianPayMethods) {
        expect(find.widgetWithText(Chip, method), findsOneWidget);
      }
      expect(find.text('Devis & Factures A4'), findsOneWidget);
      expect(find.text('Trésorerie Caisse & Banques'), findsOneWidget);

      // Import sample CSV
      await tester.dragUntilVisible(
        find.byKey(const Key('catalog_sample_btn')),
        detailList,
        const Offset(0, 250),
      );
      await tester.tap(find.byKey(const Key('catalog_sample_btn')));
      await tester.pumpAndSettle();
      expect(importBodies.single['filename'], 'modele_commercial.csv');
      expect(importBodies.single['csvText'], contains('COM-001'));

      // Generate Ed25519 offline license
      await tester.dragUntilVisible(
        find.byKey(const Key('store_generate_license_btn')),
        detailList,
        const Offset(0, 250),
      );
      await tester.tap(find.byKey(const Key('store_generate_license_btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('offline_license_result_card')), findsOneWidget);
      expect(find.text('9182-7364-5501'), findsOneWidget);
      expect(clipboardLog, contains('9182-7364-5501'));

      // Edit NIF & RC via edit bottom sheet
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'NIF'), '00112233');
      await tester.enterText(find.widgetWithText(TextField, 'RC'), 'RC-NKC-1122');
      await tester.ensureVisible(find.text('Enregistrer'));
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(onChangedCalls, 1);
      expect(store.nif, '00112233');
      expect(store.rc, 'RC-NKC-1122');
      await tester.dragUntilVisible(
        find.text('00112233'),
        detailList,
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();
      expect(find.text('00112233'), findsOneWidget);
      expect(find.text('RC-NKC-1122'), findsOneWidget);
    });
  });
}
