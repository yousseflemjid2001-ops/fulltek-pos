import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fulltek_superadmin/main.dart';
import 'package:fulltek_superadmin/models/models.dart';
import 'package:fulltek_superadmin/screens/store_detail_screen.dart';
import 'package:fulltek_superadmin/services/api_service.dart';
import 'package:fulltek_superadmin/theme/app_theme.dart';
import 'package:fulltek_superadmin/utils/file_reader.dart';

void main() {
  final List<String> clipboardLog = [];

  setUp(() {
    clipboardLog.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        final args = call.arguments as Map?;
        final text = args?['text'] as String?;
        if (text != null) clipboardLog.add(text);
      }
      return null;
    });
  });

  tearDown(() {
    FileReaderBridge.pickerOverride = null;
    ApiService.resetForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  String trFr(String key) => kStrings['fr']?[key] ?? key;

  TenantStore sampleStore() => TenantStore(
        id: 2,
        name: 'Al-Baraka Market',
        module: StoreModule.market,
        city: 'Ksar',
        phone: '+222 44 88 19 02',
        plan: 'Pro',
        mrr: 3000,
        tills: 4,
        daysLeft: 24,
        status: StoreStatus.active,
      )..tenantId = 'FT-2088';

  testWidgets('StoreDetailScreen 1-click CSV & XLSX catalog import displays counts and row errors',
      (WidgetTester tester) async {
    ApiService.setToken('jwt-m3-test');
    final importBodies = <Map<String, dynamic>>[];

    ApiService.httpTransport = (
      method,
      url, {
      body,
      headers,
      timeout = const Duration(seconds: 5),
    }) async {
      expect(headers?['Authorization'], 'Bearer jwt-m3-test');
      final decoded = jsonDecode(body!) as Map<String, dynamic>;
      importBodies.add(decoded);

      if (decoded['filename'] == 'broken.csv') {
        return (
          status: 400,
          body: jsonEncode({
            'error': 'Erreurs dans le fichier CSV',
            'errors': [
              {'row': 2, 'message': 'Prix invalide'},
            ],
          }),
        );
      }
      return (
        status: 200,
        body: jsonEncode({
          'ok': true,
          'tenantId': 2,
          'format': decoded['format'],
          'totalRows': 3,
          'created': 2,
          'updated': 1,
          'categoriesCreated': 1,
          'errors': [],
        }),
      );
    };

    var catalogCallbacks = 0;
    var patchCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme(),
        home: StoreDetailScreen(
          store: sampleStore(),
          lang: 'fr',
          tr: trFr,
          onExtend: () {},
          onToggleLock: () {},
          onChanged: () => patchCalls++,
          onCatalogImported: () => catalogCallbacks++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. 1-click CSV file import via pickerOverride
    FileReaderBridge.pickerOverride = () async => const PickedCatalogFile(
          filename: 'market.csv',
          format: 'csv',
          csvText: 'name_fr,price_retail\nSucre,45\n',
        );

    await tester.ensureVisible(find.byKey(const Key('catalog_import_btn')));
    await tester.tap(find.byKey(const Key('catalog_import_btn')));
    await tester.pumpAndSettle();

    expect(importBodies.last['format'], 'csv');
    expect(find.byKey(const Key('catalog_import_result')), findsOneWidget);
    expect(find.textContaining('Total: 3'), findsOneWidget);
    expect(find.textContaining('Créés: 2'), findsOneWidget);
    expect(find.textContaining('Mis à jour: 1'), findsOneWidget);
    expect(find.textContaining('Catégories: 1'), findsOneWidget);
    expect(catalogCallbacks, 1);
    expect(patchCalls, 0);

    // 2. 1-click .xlsx file import via parseCatalogFileBytes
    FileReaderBridge.pickerOverride = () async =>
        parseCatalogFileBytes('produits.xlsx', [0x50, 0x4B, 0x03, 0x04]);

    await tester.tap(find.byKey(const Key('catalog_import_btn')));
    await tester.pumpAndSettle();

    expect(importBodies.last['format'], 'xlsx');
    expect(importBodies.last['contentBase64'], isNotEmpty);
    expect(catalogCallbacks, 2);

    // 3. 1-click sample template fallback without pickerOverride
    FileReaderBridge.pickerOverride = null;
    await tester.tap(find.byKey(const Key('catalog_sample_btn')));
    await tester.pumpAndSettle();
    expect(importBodies.last['filename'], 'modele_market.csv');
    expect(catalogCallbacks, 3);

    // 4. IO fallback modal (paste CSV) when pickerOverride is null
    await tester.tap(find.byKey(const Key('catalog_import_btn')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('catalog_paste_input')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('catalog_paste_input')),
      'name_fr,price_retail\nCouscous,120\n',
    );
    await tester.ensureVisible(find.byKey(const Key('catalog_paste_submit')));
    await tester.tap(find.byKey(const Key('catalog_paste_submit')));
    await tester.pumpAndSettle();
    expect(importBodies.last['format'], 'csv');
    expect(importBodies.last['csvText'], contains('Couscous'));
    expect(catalogCallbacks, 4);

    // 5. 400 error displays row-level error details
    FileReaderBridge.pickerOverride = () async => const PickedCatalogFile(
          filename: 'broken.csv',
          format: 'csv',
          csvText: 'name_fr,price_retail\nBad,xyz\n',
        );
    await tester.tap(find.byKey(const Key('catalog_import_btn')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('catalog_import_error')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('catalog_import_error')),
        matching: find.text('Erreurs dans le fichier CSV'),
      ),
      findsOneWidget,
    );
    expect(find.text('Ligne 2 : Prix invalide'), findsOneWidget);
  });

  testWidgets('StoreDetailScreen generates Ed25519 license, copies fields, and rejects fake fallback on error',
      (WidgetTester tester) async {
    ApiService.setToken('jwt-lic-test');
    var returnError = false;

    ApiService.httpTransport = (
      method,
      url, {
      body,
      headers,
      timeout = const Duration(seconds: 5),
    }) async {
      if (returnError) {
        return (status: 500, body: '{"error":"Clé Ed25519 indisponible"}');
      }
      return (
        status: 200,
        body: jsonEncode({
          'ok': true,
          'code': '4829-1034-9921',
          'days': 30,
          'graceDays': 7,
          'storeName': 'Al-Baraka Market',
          'keyId': 'ed25519-prod-01',
          'issuedAt': '2026-11-18T20:00:00.000Z',
          'expiresAt': '2026-12-18T20:00:00.000Z',
          'signature': 'EdSigValueXYZ',
          'leaseToken': 'PayloadB64.EdSigValueXYZ',
          'publicKey': '-----BEGIN PUBLIC KEY-----\nPUBKEY\n-----END PUBLIC KEY-----',
          'payload': {'tenantId': 2},
        }),
      );
    };

    var licCallbacks = 0;
    var patchCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme(),
        home: StoreDetailScreen(
          store: sampleStore(),
          lang: 'fr',
          tr: trFr,
          onExtend: () {},
          onToggleLock: () {},
          onChanged: () => patchCalls++,
          onLicenseGenerated: () => licCallbacks++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('store_generate_license_btn')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('offline_license_result_card')), findsOneWidget);
    expect(find.text('4829-1034-9921'), findsOneWidget);
    expect(find.text('ed25519-prod-01'), findsOneWidget);
    expect(find.text('PayloadB64.EdSigValueXYZ'), findsOneWidget);
    expect(find.text('EdSigValueXYZ'), findsOneWidget);
    expect(clipboardLog, contains('4829-1034-9921'));
    expect(licCallbacks, 1);
    expect(patchCalls, 0);

    await tester.drag(find.byType(ListView).first, const Offset(0, -250));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('copy_lease_token')));
    await tester.pumpAndSettle();
    expect(clipboardLog, contains('PayloadB64.EdSigValueXYZ'));

    await tester.drag(find.byType(ListView).first, const Offset(0, -250));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('copy_public_key')));
    await tester.pumpAndSettle();
    expect(
      clipboardLog,
      contains('-----BEGIN PUBLIC KEY-----\nPUBKEY\n-----END PUBLIC KEY-----'),
    );

    // Error state must surface error banner and NEVER fabricate a PRNG code
    returnError = true;
    await tester.ensureVisible(find.byKey(const Key('store_generate_license_btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('store_generate_license_btn')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('store_license_error')), findsOneWidget);
    expect(find.text('Clé Ed25519 indisponible'), findsWidgets);
  });

  testWidgets('LicensesTab generates Ed25519 license and surfaces error without PRNG fallback inside 430px frame',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 960);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    ApiService.setToken(
      'jwt-admin',
      admin: const AdminProfile(
        id: 1,
        username: 'taha',
        email: 'taha@fulltek.mr',
        fullName: 'M. Taha Chouaib',
      ),
    );

    var failLicense = false;
    ApiService.httpTransport = (
      method,
      url, {
      body,
      headers,
      timeout = const Duration(seconds: 5),
    }) async {
      if (url.endsWith('/api/admin/dashboard')) {
        return (
          status: 200,
          body: jsonEncode({
            'stores': [
              {
                'id': 1,
                'tenantId': 'FT-1041',
                'name': 'Dar El-Karam Resto',
                'module': 'resto',
                'city': 'Tevragh Zeina',
                'phone': '+222 46 11 22 33',
                'plan': 'Pro',
                'mrr': 3000,
                'tills': 3,
                'daysLeft': 12,
                'status': 'active',
              },
            ],
            'payments': [],
            'audits': [],
          }),
        );
      }
      if (url.endsWith('/api/admin/tenants/1/offline-code')) {
        if (failLicense) {
          return (status: 500, body: '{"error":"Erreur signature Ed25519"}');
        }
        return (
          status: 200,
          body: jsonEncode({
            'ok': true,
            'code': '7711-2233-4455',
            'days': 30,
            'graceDays': 7,
            'storeName': 'Dar El-Karam Resto',
            'keyId': 'ed25519-tab-01',
            'issuedAt': '2026-11-18T20:00:00.000Z',
            'expiresAt': '2026-12-18T20:00:00.000Z',
            'signature': 'TabSig123',
            'leaseToken': 'TabPayload.TabSig123',
            'publicKey': '-----BEGIN PUBLIC KEY-----\nTAB\n-----END PUBLIC KEY-----',
          }),
        );
      }
      return (status: 404, body: '{}');
    };

    await tester.pumpWidget(const FullTekSuperAdminApp(enableSplash: false));
    await tester.pumpAndSettle();

    // Switch to Tab 2 (Licences)
    await tester.tap(find.text('Licences'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('licenses_generate_btn')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('offline_license_result_card')), findsOneWidget);
    expect(find.text('7711-2233-4455'), findsOneWidget);
    expect(find.text('TabPayload.TabSig123'), findsOneWidget);
    expect(clipboardLog, contains('7711-2233-4455'));

    // Test failure case
    failLicense = true;
    await tester.tap(find.byKey(const Key('licenses_generate_btn')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('licenses_tab_error')), findsOneWidget);
    expect(find.text('Erreur signature Ed25519'), findsWidgets);
  });
}
