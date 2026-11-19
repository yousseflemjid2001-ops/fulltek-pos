import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fulltek_superadmin/main.dart';
import 'package:fulltek_superadmin/screens/new_store_wizard.dart';
import 'package:fulltek_superadmin/services/api_service.dart';
import 'package:fulltek_superadmin/theme/app_theme.dart';

void main() {
  tearDown(() {
    ApiService.resetForTest();
  });

  testWidgets('FullTekSuperAdminApp renders smoke test and blocks unauthenticated admin access',
      (WidgetTester tester) async {
    final requestedUrls = <String>[];
    ApiService.httpTransport = (
      method,
      url, {
      body,
      headers,
      timeout = const Duration(seconds: 5),
    }) async {
      requestedUrls.add('$method $url');
      return (status: 401, body: '{"error":"Unauthorized"}');
    };

    await tester.pumpWidget(const FullTekSuperAdminApp());
    await tester.pump(const Duration(seconds: 2));

    expect(find.textContaining('Full·Tek'), findsWidgets);
    expect(find.byKey(const Key('login_username')), findsOneWidget);
    expect(find.byKey(const Key('login_password')), findsOneWidget);
    expect(find.byKey(const Key('login_submit')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(requestedUrls, isEmpty);
  });

  testWidgets('NewStoreWizard 3-step client onboarding renders cleanly in FR and AR',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme(),
        home: const NewStoreWizard(lang: 'fr'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nouveau client / boutique'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(find.text('Compte de connexion client'), findsOneWidget);
    expect(find.text('Mot de passe du compte *'), findsOneWidget);

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
    expect(find.text('إضافة متجر / عميل جديد'), findsOneWidget);
  });
}
