import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fulltek_superadmin/main.dart';
import 'package:fulltek_superadmin/services/api_service.dart';

void main() {
  tearDown(() {
    ApiService.resetForTest();
  });

  Map<String, dynamic> dashboardPayload() => {
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
        'audits': [
          {
            'title': 'Connexion Super-Admin',
            'subtitle': 'taha · Session JWT active',
            'time': '12:00',
          },
        ],
      };

  testWidgets('Invalid login shows error banner and keeps AdminLoginScreen locked',
      (WidgetTester tester) async {
    ApiService.httpTransport = (
      method,
      url, {
      body,
      headers,
      timeout = const Duration(seconds: 5),
    }) async {
      return (status: 401, body: '{"error":"Identifiants invalides"}');
    };

    await tester.pumpWidget(const FullTekSuperAdminApp(enableSplash: false));
    await tester.pumpAndSettle();

    // Empty validation check
    await tester.ensureVisible(find.byKey(const Key('login_submit')));
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login_error_banner')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    // Invalid credentials
    await tester.enterText(find.byKey(const Key('login_username')), 'taha');
    await tester.enterText(find.byKey(const Key('login_password')), 'badpass');
    await tester.ensureVisible(find.byKey(const Key('login_submit')));
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login_error_banner')), findsOneWidget);
    expect(find.text('Identifiants invalides'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(ApiService.isAuthenticated, isFalse);
  });

  testWidgets('Valid login unlocks SuperAdminHome, 401 pops pushed routes, and Logout resets session',
      (WidgetTester tester) async {
    var forceUnauthorized = false;
    final authHeadersSeen = <String?>[];

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
            'token': 'jwt-live-token',
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

      authHeadersSeen.add(headers?['Authorization']);
      if (forceUnauthorized) {
        return (status: 401, body: '{"error":"Token expired"}');
      }
      if (url.endsWith('/api/admin/dashboard')) {
        return (status: 200, body: jsonEncode(dashboardPayload()));
      }
      if (url.endsWith('/api/admin/tenants/1/extend')) {
        return (status: 200, body: jsonEncode(dashboardPayload()['stores']![0]));
      }
      return (status: 404, body: '{"error":"Not found"}');
    };

    await tester.pumpWidget(const FullTekSuperAdminApp(enableSplash: false));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('login_username')), 'taha');
    await tester.enterText(
      find.byKey(const Key('login_password')),
      'FullTekAdmin@2026',
    );
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(authHeadersSeen, contains('Bearer jwt-live-token'));

    // Navigate to Stores tab and push StoreDetailScreen
    await tester.tap(find.text('Boutiques'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('store_card_1')), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, -260));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('store_card_1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('catalog_import_card')), findsOneWidget);

    // Simulate token expiration -> 401 on an admin action inside pushed route
    forceUnauthorized = true;
    await tester.ensureVisible(find.byKey(const Key('store_generate_license_btn')));
    await tester.tap(find.byKey(const Key('store_generate_license_btn')));
    await tester.pumpAndSettle();

    expect(ApiService.token, isNull);
    expect(find.byKey(const Key('login_username')), findsOneWidget);
    expect(find.byKey(const Key('login_error_banner')), findsOneWidget);
    expect(find.byKey(const Key('catalog_import_card')), findsNothing);

    // Log back in, check Audit profile & test explicit Logout button
    forceUnauthorized = false;
    await tester.enterText(find.byKey(const Key('login_username')), 'taha');
    await tester.enterText(
      find.byKey(const Key('login_password')),
      'FullTekAdmin@2026',
    );
    await tester.ensureVisible(find.byKey(const Key('login_submit')));
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.text('Audit'));
    await tester.pumpAndSettle();
    expect(find.textContaining('M. Taha Chouaib'), findsOneWidget);
    expect(find.text('taha@fulltek.mr'), findsOneWidget);

    await tester.tap(find.byKey(const Key('logout_button')));
    await tester.pumpAndSettle();

    expect(ApiService.token, isNull);
    expect(find.byKey(const Key('login_username')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('App switches to RTL Arabic without layout overflow before and after login',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 960);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

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
            'token': 'jwt-ar-token',
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
        return (status: 200, body: jsonEncode(dashboardPayload()));
      }
      return (status: 404, body: '{}');
    };

    await tester.pumpWidget(const FullTekSuperAdminApp(enableSplash: false));
    await tester.pumpAndSettle();

    await tester.tap(find.text('AR'));
    await tester.pumpAndSettle();
    expect(find.text('تسجيل الدخول'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('login_username')), 'taha');
    await tester.enterText(
      find.byKey(const Key('login_password')),
      'FullTekAdmin@2026',
    );
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.tap(find.text('المتاجر'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('stores_catalog_import_bar')), findsOneWidget);

    await tester.tap(find.text('التدقيق'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('audit_logout_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login_username')), findsOneWidget);
  });
}
