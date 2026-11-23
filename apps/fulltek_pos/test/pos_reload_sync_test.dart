import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:fulltek_pos/models/pos_models.dart';
import 'package:fulltek_pos/services/http_bridge.dart';
import 'package:fulltek_pos/services/receipt_formatter.dart';
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

  test('Mixed Sur place + Emporter lines & Receipt Serveur vs Caissier formatting', () {
    final store = PosStore(enablePersistence: false);
    final waiter = store.staff.firstWhere((s) => s.role == PosRole.waiter);
    final cashier = store.staff.firstWhere((s) => s.role == PosRole.cashier);
    final owner = store.staff.firstWhere((s) => s.role == PosRole.owner);

    // Waiter opens table and takes a mixed order
    expect(store.loginWithPin(waiter.pinCode), isTrue);
    final waiterName = store.currentStaff!.name;
    final tbl = store.tables.first;
    store.openOrSelectTable(tbl.id);
    final dish1 = store.menuItems.firstWhere((m) => m.available);
    final dish2 = store.menuItems.lastWhere((m) => m.available);
    store.addItemToActiveOrder(dish1);
    store.addItemToActiveOrder(dish2);
    final secondLineId = store.activeOrder!.items.last.lineId;
    store.toggleLineTakeaway(secondLineId);
    expect(store.activeOrder!.items.first.isTakeaway, isFalse);
    expect(store.activeOrder!.items.last.isTakeaway, isTrue);

    // Cashier takes payment for that table
    expect(store.loginWithPin(cashier.pinCode), isTrue);
    final cashierName = store.currentStaff!.name;
    store.openOrSelectTable(tbl.id);
    final total = store.activeOrder!.netTotal;
    final paid = store.completeCheckout([
      PaymentEntry(method: PaymentMethod.cash, amountMru: total),
    ]);
    expect(paid, isNotNull);
    final receipt = ReceiptFormatter.formatOrderReceipt80mm(order: paid!);
    expect(receipt, contains('Serveur: $waiterName'));
    expect(receipt, contains('Caissier: $cashierName'));
    expect(receipt, contains('[EMPORTER]'));

    // Takeaway counter order (no table server) prints Caissier directly
    store.setServiceMode(ServiceMode.takeaway);
    store.startCounterOrder();
    store.addItemToActiveOrder(dish1);
    final t2 = store.activeOrder!.netTotal;
    final paidTakeaway = store.completeCheckout([
      PaymentEntry(method: PaymentMethod.cash, amountMru: t2),
    ]);
    final receiptTakeaway =
        ReceiptFormatter.formatOrderReceipt80mm(order: paidTakeaway!);
    expect(receiptTakeaway, contains('Caissier: $cashierName'));
    expect(receiptTakeaway, isNot(contains('Serveur:')));

    // Back-Office PIN check: owner passes, standard cashier without grant fails
    expect(store.verifyBackOfficePin(owner.pinCode), isNotNull);
    expect(store.verifyBackOfficePin(cashier.pinCode), isNull);
  });

  test(
    'Post-kitchen void blocks direct deletion, enforces reason + manager PIN, prints kitchen cancellation ticket & logs history',
    () {
      final store = PosStore(enablePersistence: false);
      final owner = store.staff.firstWhere((s) => s.role == PosRole.owner);
      final cashier = store.staff.firstWhere((s) => s.role == PosRole.cashier);
      final dish = store.menuItems.first;

      // Login as cashier (no voidOrComp permission)
      expect(store.loginWithPin(cashier.pinCode), isTrue);
      store.openOrSelectTable(store.tables.first.id);
      store.addItemToActiveOrder(dish);
      store.addItemToActiveOrder(dish);
      final lineId = store.activeOrder!.items.first.lineId;

      // Before sending to kitchen: direct decrement is allowed
      expect(store.updateLineQuantity(lineId, -1), isTrue);
      expect(store.activeOrder!.items.first.quantity, 1);

      // Send to kitchen
      store.sendActiveOrderToKitchen();
      expect(store.activeOrder!.items.first.sentToKitchen, isTrue);

      // After sending to kitchen: direct decrement & direct remove MUST be blocked
      expect(store.updateLineQuantity(lineId, -1), isFalse);
      expect(store.removeLineFromActiveOrder(lineId), isFalse);
      expect(store.activeOrder!.items.length, 1);

      // Missing reason -> rejected
      expect(
        store.voidSentLineWithAuth(
          lineId: lineId,
          reason: '   ',
          managerPin: owner.pinCode,
        ),
        isNull,
      );

      // Missing or wrong manager PIN for cashier -> rejected
      expect(
        store.voidSentLineWithAuth(
          lineId: lineId,
          reason: 'Client a changé d\'avis',
          managerPin: cashier.pinCode,
        ),
        isNull,
      );

      // Valid manager PIN + reason -> succeeds, prints cancellation ticket, logs history + KDS + SyncQueue
      final cancelTicket = store.voidSentLineWithAuth(
        lineId: lineId,
        reason: 'Client a changé d\'avis',
        managerPin: owner.pinCode,
      );
      expect(cancelTicket, isNotNull);
      expect(cancelTicket, contains('ANNULATION CUISINE'));
      expect(cancelTicket, contains('Client a changé d\'avis'));
      expect(cancelTicket, contains(owner.name));
      expect(store.activeOrder!.items, isEmpty);
      expect(store.remakeRecords.length, 1);
      expect(store.remakeRecords.first.type, 'void_kitchen');
      expect(store.remakeRecords.first.approvedBy, owner.name);
      expect(store.kdsTickets.first.status, 'cancelled');
      expect(
        store.syncQueue.any((q) =>
            q.entityType == 'remake' &&
            q.payload['type'] == 'VOID_KITCHEN'),
        isTrue,
      );
    },
  );
}
