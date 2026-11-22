import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:fulltek_pos/services/http_bridge.dart';
import 'package:fulltek_pos/state/pos_store.dart';

void main() {
  test('loginWithPin triggers fetchCloudCatalog when session has cloudJwtToken and not yet synced', () async {
    int catalogCalls = 0;
    final store = PosStore(
      enablePersistence: false,
      httpRequest: (method, url, {headers, body}) async {
        if (method == 'GET' && url.endsWith('/api/pos/catalog')) {
          catalogCalls++;
          return HttpBridgeResponse(
            200,
            jsonEncode({
              'tenant': {
                'tenantId': 'FT-2026',
                'name': 'Resto Test',
                'enabledThemes': ['01'],
                'payMethods': ['CASH'],
                'defaultLang': 'fr',
                'ownerPin': '7410',
              },
              'categories': [
                {'id': 10, 'name_fr': 'Plats', 'name_ar': 'أطباق', 'name_en': 'Dishes', 'icon': '🍽', 'active': 1},
              ],
              'products': [
                {
                  'id': 99,
                  'sku': 'SKU-NEW-99',
                  'category_id': 10,
                  'name_fr': 'Méchoui Royal Persistant',
                  'name_ar': 'مشوي ملكي',
                  'name_en': 'Royal Mechoui',
                  'price_retail': 2500,
                  'kitchen_station': 'GRILL',
                  'active': 1,
                },
              ],
              'staff': [
                {
                  'id': 'USR-1',
                  'name': 'Chef Persistant',
                  'role': 'OWNER',
                  'pinCode': '7410',
                  'isActive': true,
                },
              ],
            }),
          );
        }
        return const HttpBridgeResponse(404, '{"error":"not found"}');
      },
    );

    // Simulate restored logged-in state before catalog sync
    store.accountLoggedIn = true;
    store.accountOffline = false;
    store.cloudJwtToken = 'test-jwt-token';
    store.catalogSource = 'offline_demo';

    expect(store.loginWithPin('7410'), isTrue);

    // Let microtask fetchCloudCatalog complete
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(catalogCalls, 1);
    expect(store.catalogSource, 'cloud_api');
    expect(store.menuItems.any((m) => m.nameFr == 'Méchoui Royal Persistant'), isTrue);
    expect(store.staff.any((s) => s.name == 'Chef Persistant'), isTrue);
  });

  test('saveMenuItem surfaces server 401/400 error instead of silently creating ghost item', () async {
    final store = PosStore(
      enablePersistence: false,
      httpRequest: (method, url, {headers, body}) async {
        if (method == 'POST' && url.endsWith('/api/pos/products')) {
          return const HttpBridgeResponse(401, '{"error":"Invalid or expired token"}');
        }
        return const HttpBridgeResponse(404, '{}');
      },
    );

    store.accountLoggedIn = true;
    store.accountOffline = false;
    store.cloudJwtToken = 'expired-jwt';

    final beforeCount = store.menuItems.length;
    final err = await store.saveMenuItem(
      nameFr: 'Article Test 401',
      categoryId: '1',
      priceMru: 300,
    );

    expect(err, isNotNull);
    expect(err, contains('Session expirée'));
    expect(store.menuItems.length, beforeCount);
  });
}
