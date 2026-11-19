import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:fulltek_superadmin/models/models.dart';
import 'package:fulltek_superadmin/services/api_service.dart';
import 'package:fulltek_superadmin/utils/file_reader_types.dart';

void main() {
  tearDown(() {
    ApiService.resetForTest();
  });

  group('parseCatalogFileBytes', () {
    test('parses UTF-8 CSV with BOM stripped', () {
      final raw = [0xEF, 0xBB, 0xBF, ...utf8.encode('name_fr,price_retail\nCafé,150\n')];
      final parsed = parseCatalogFileBytes('catalogue.csv', raw);
      expect(parsed.filename, 'catalogue.csv');
      expect(parsed.format, 'csv');
      expect(parsed.csvText, 'name_fr,price_retail\nCafé,150\n');
      expect(parsed.contentBase64, isNull);
    });

    test('falls back to Latin-1 for Excel FR CSVs', () {
      final raw = latin1.encode('name_fr,price_retail\nThé Épicé,90\n');
      final parsed = parseCatalogFileBytes('export_fr.csv', raw);
      expect(parsed.format, 'csv');
      expect(parsed.csvText, contains('Thé Épicé'));
    });

    test('encodes .xlsx bytes as Base64', () {
      final bytes = [0x50, 0x4B, 0x03, 0x04, 0x14, 0x00];
      final parsed = parseCatalogFileBytes('items.xlsx', bytes);
      expect(parsed.format, 'xlsx');
      expect(parsed.contentBase64, base64Encode(bytes));
      expect(parsed.csvText, isNull);
    });

    test('throws FormatException on empty or unsupported files', () {
      expect(
        () => parseCatalogFileBytes('', [1, 2]),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => parseCatalogFileBytes('empty.csv', []),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => parseCatalogFileBytes('archive.pdf', [1, 2, 3]),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('ApiService Auth & Endpoints', () {
    test('loginSuperAdmin stores JWT and attaches Bearer on protected routes', () async {
      final calls = <({String method, String url, Map<String, String>? headers, String? body, Duration timeout})>[];
      ApiService.baseUrl = 'http://api.test:4000';
      ApiService.httpTransport = (
        method,
        url, {
        body,
        headers,
        timeout = const Duration(seconds: 5),
      }) async {
        calls.add((method: method, url: url, headers: headers, body: body, timeout: timeout));
        if (url.endsWith('/api/admin/login')) {
          return (
            status: 200,
            body: jsonEncode({
              'ok': true,
              'token': 'jwt-superadmin-123',
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
                  'id': 10,
                  'tenantId': 'FT-100',
                  'name': 'Boutique Test',
                  'module': 'market',
                  'city': 'Nouakchott',
                  'phone': '+22244001122',
                  'plan': 'Pro',
                  'mrr': 3000,
                  'tills': 2,
                  'daysLeft': 25,
                  'status': 'active',
                },
              ],
              'payments': [],
              'audits': [],
            }),
          );
        }
        return (status: 404, body: '{"error":"Not found"}');
      };

      final loginRes = await ApiService.loginSuperAdmin('taha', 'secret');
      expect(loginRes.ok, isTrue);
      expect(loginRes.data!.token, 'jwt-superadmin-123');
      expect(loginRes.data!.admin.role, 'SUPER_ADMIN');
      expect(ApiService.isAuthenticated, isTrue);
      expect(calls[0].headers?['Authorization'], isNull);

      final dashRes = await ApiService.fetchDashboard();
      expect(dashRes.ok, isTrue);
      expect(dashRes.data!.stores.single.name, 'Boutique Test');
      expect(calls[1].headers?['Authorization'], 'Bearer jwt-superadmin-123');
    });

    test('fetchMe attaches Bearer token, updates profile, and clears session on 401', () async {
      var return401 = false;
      var unauthorizedCalled = 0;
      ApiService.onUnauthorized = () => unauthorizedCalled++;
      ApiService.setToken('jwt-me-test');
      ApiService.httpTransport = (
        method,
        url, {
        body,
        headers,
        timeout = const Duration(seconds: 5),
      }) async {
        expect(method, 'GET');
        expect(url, endsWith('/api/admin/me'));
        expect(headers?['Authorization'], 'Bearer jwt-me-test');
        if (return401) {
          return (status: 401, body: '{"error":"Expired"}');
        }
        return (
          status: 200,
          body: jsonEncode({
            'ok': true,
            'admin': {
              'id': 1,
              'username': 'taha',
              'email': 'taha@fulltek.mr',
              'fullName': 'M. Taha Chouaib',
              'role': 'SUPER_ADMIN',
            },
          }),
        );
      };

      final meOk = await ApiService.fetchMe();
      expect(meOk.ok, isTrue);
      expect(meOk.data!.username, 'taha');
      expect(ApiService.adminProfile?.email, 'taha@fulltek.mr');

      return401 = true;
      final meFail = await ApiService.fetchMe();
      expect(meFail.ok, isFalse);
      expect(meFail.statusCode, 401);
      expect(ApiService.isAuthenticated, isFalse);
      expect(unauthorizedCalled, 1);
    });

    test('401 on login does not trigger onUnauthorized, while 401 on /api/admin/* clears token', () async {
      var unauthorizedCount = 0;
      ApiService.onUnauthorized = () => unauthorizedCount++;
      ApiService.httpTransport = (
        method,
        url, {
        body,
        headers,
        timeout = const Duration(seconds: 5),
      }) async {
        return (status: 401, body: '{"error":"Jeton invalide ou expiré"}');
      };

      final badLogin = await ApiService.loginSuperAdmin('taha', 'wrong');
      expect(badLogin.ok, isFalse);
      expect(badLogin.statusCode, 401);
      expect(ApiService.isAuthenticated, isFalse);
      expect(unauthorizedCount, 0);

      ApiService.setToken(
        'expired-jwt',
        admin: const AdminProfile(
          id: 1,
          username: 'taha',
          email: 'taha@fulltek.mr',
          fullName: 'M. Taha Chouaib',
        ),
      );
      final dashRes = await ApiService.fetchDashboard();
      expect(dashRes.ok, isFalse);
      expect(dashRes.statusCode, 401);
      expect(ApiService.token, isNull);
      expect(ApiService.adminProfile, isNull);
      expect(unauthorizedCount, 1);
    });

    test('generateOfflineCode parses full Ed25519 payload and surfaces 500 error without fallback', () async {
      ApiService.setToken('jwt-ok');
      ApiService.httpTransport = (
        method,
        url, {
        body,
        headers,
        timeout = const Duration(seconds: 5),
      }) async {
        expect(headers?['Authorization'], 'Bearer jwt-ok');
        expect(url, endsWith('/api/admin/tenants/3/offline-code'));
        return (
          status: 200,
          body: jsonEncode({
            'ok': true,
            'code': '4829-1034-9921',
            'days': 90,
            'graceDays': 7,
            'storeName': 'Pharmacie Chinguetti',
            'keyId': 'ed25519-key-01',
            'issuedAt': '2026-11-18T20:00:00.000Z',
            'expiresAt': '2027-02-16T20:00:00.000Z',
            'signature': 'sigBase64UrlExample',
            'leaseToken': 'payloadB64.sigBase64UrlExample',
            'publicKey': '-----BEGIN PUBLIC KEY-----\nMCowBQYDK2VwAyEAtest\n-----END PUBLIC KEY-----',
            'payload': {'tenantId': 3, 'days': 90},
          }),
        );
      };

      final okRes = await ApiService.generateOfflineCode(3, 90);
      expect(okRes.ok, isTrue);
      expect(okRes.data!.code, '4829-1034-9921');
      expect(okRes.data!.days, 90);
      expect(okRes.data!.keyId, 'ed25519-key-01');
      expect(okRes.data!.leaseToken, 'payloadB64.sigBase64UrlExample');
      expect(okRes.data!.signature, 'sigBase64UrlExample');
      expect(okRes.data!.publicKey, contains('BEGIN PUBLIC KEY'));

      ApiService.httpTransport = (
        method,
        url, {
        body,
        headers,
        timeout = const Duration(seconds: 5),
      }) async =>
          (status: 500, body: '{"error":"Signing key error"}');

      final errRes = await ApiService.generateOfflineCode(3, 90);
      expect(errRes.ok, isFalse);
      expect(errRes.statusCode, 500);
      expect(errRes.error, 'Signing key error');
      expect(errRes.data, isNull);
    });

    test('importCatalog sends CSV and XLSX payloads with 30s timeout and parses 200 & 400 row errors', () async {
      Duration? capturedTimeout;
      Map<String, dynamic>? capturedBody;
      ApiService.setToken('jwt-cat');
      ApiService.httpTransport = (
        method,
        url, {
        body,
        headers,
        timeout = const Duration(seconds: 5),
      }) async {
        capturedTimeout = timeout;
        capturedBody = jsonDecode(body!) as Map<String, dynamic>;
        expect(headers?['Authorization'], 'Bearer jwt-cat');
        return (
          status: 200,
          body: jsonEncode({
            'ok': true,
            'tenantId': 2,
            'format': capturedBody!['format'],
            'totalRows': 4,
            'created': 3,
            'updated': 1,
            'categoriesCreated': 2,
            'errors': [],
          }),
        );
      };

      final csvRes = await ApiService.importCatalog(
        2,
        filename: 'prod.csv',
        format: 'csv',
        csvText: 'name_fr,price_retail\nThé,120\n',
      );
      expect(csvRes.ok, isTrue);
      expect(capturedTimeout, const Duration(seconds: 30));
      expect(capturedBody!['format'], 'csv');
      expect(csvRes.data!.created, 3);
      expect(csvRes.data!.updated, 1);
      expect(csvRes.data!.categoriesCreated, 2);

      final xlsxRes = await ApiService.importCatalog(
        2,
        filename: 'prod.xlsx',
        format: 'xlsx',
        contentBase64: 'UEsDBBQ=',
      );
      expect(xlsxRes.ok, isTrue);
      expect(capturedBody!['format'], 'xlsx');
      expect(capturedBody!['contentBase64'], 'UEsDBBQ=');

      ApiService.httpTransport = (
        method,
        url, {
        body,
        headers,
        timeout = const Duration(seconds: 5),
      }) async =>
          (
            status: 400,
            body: jsonEncode({
              'error': 'Validation catalogue échouée',
              'errors': [
                {'row': 2, 'message': 'Prix invalide'},
                {'row': 5, 'message': 'Nom manquant'},
              ],
            }),
          );

      final badRes = await ApiService.importCatalog(
        2,
        filename: 'bad.csv',
        format: 'csv',
        csvText: 'name_fr,price_retail\nX,abc\n',
      );
      expect(badRes.ok, isFalse);
      expect(badRes.statusCode, 400);
      expect(badRes.error, 'Validation catalogue échouée');
      expect(badRes.errors.length, 2);
      expect(badRes.errors[0].row, 2);
      expect(badRes.errors[0].message, 'Prix invalide');
    });
  });
}
