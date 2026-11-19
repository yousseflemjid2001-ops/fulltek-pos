import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:fulltek_pos/models/pos_models.dart';
import 'package:fulltek_pos/services/local_storage.dart';
import 'package:fulltek_pos/state/pos_store.dart';

void main() {
  group('Phase 1 — Business Logic, Accounting & Offline Persistence', () {
    test('Karni creditLimitMru blocks over-limit checkout and surfaces error', () {
      final store = PosStore(enablePersistence: false);
      store.loginWithPin('7410');
      store.startCounterOrder();
      final item = store.menuItems.firstWhere((m) => m.priceMru >= 1000);
      // Add enough quantity to exceed customer credit limit
      final cust = store.karniCustomers.first;
      final remainingLimit = cust.creditLimitMru - cust.balanceDueMru;
      final qtyNeeded = (remainingLimit / item.priceMru).ceil() + 2;
      for (int i = 0; i < qtyNeeded; i++) {
        store.addItemToActiveOrder(item);
      }
      final order = store.activeOrder!;
      expect(order.netTotal, greaterThan(remainingLimit));

      final blocked = store.completeCheckout([
        PaymentEntry(
          method: PaymentMethod.karni,
          amountMru: order.netTotal,
          karniCustomerId: cust.id,
        ),
      ]);
      expect(blocked, isNull);
      expect(store.lastCheckoutError, contains('Plafond Karni dépassé'));
    });

    test('Arboun deducts from netTotal while TVA 16% and todayRevenueMru use grossTotal', () {
      final store = PosStore(enablePersistence: false);
      store.loginWithPin('7410');
      final freeTable =
          store.tables.firstWhere((t) => t.status == TableStatus.free);
      store.openOrSelectTable(freeTable.id, guests: 4, arbounMru: 500);
      final mechoui = store.menuItems.firstWhere((m) => m.id == 'M1');
      store.addItemToActiveOrder(mechoui);
      store.addItemToActiveOrder(mechoui);

      final order = store.activeOrder!;
      final expectedGross = mechoui.priceMru * 2;
      expect(order.grossTotal, expectedGross);
      expect(order.netTotal, expectedGross - 500);
      expect(order.tvaAmountMru, (expectedGross * 16 / 116).round());

      final closed = store.completeCheckout([
        PaymentEntry(method: PaymentMethod.cash, amountMru: order.netTotal),
      ]);
      expect(closed, isNotNull);
      expect(store.todayRevenueMru, expectedGross);
    });

    test('Closing Z isolates unclosed orders (no double-counting) and tracks Bimbank/Click', () {
      final store = PosStore(enablePersistence: false);
      store.loginWithPin('7410');
      final item = store.menuItems.firstWhere((m) => m.available);

      // Order 1 paid via Bimbank
      store.startCounterOrder();
      store.addItemToActiveOrder(item);
      final net1 = store.activeOrder!.netTotal;
      store.completeCheckout([
        PaymentEntry(method: PaymentMethod.bimbank, amountMru: net1, reference: 'BM-1'),
      ]);

      final z1 = store.submitBlindClosingZ(
        countedCashMru: 0,
        countedBankilyMru: 0,
        countedMasriviMru: 0,
        countedSedadMru: 0,
        countedBimbankMru: net1,
      );
      expect(z1.expectedBimbankMru, net1);
      expect(z1.ordersCount, 1);

      // Order 2 paid via Click after Z1
      store.startCounterOrder();
      store.addItemToActiveOrder(item);
      final net2 = store.activeOrder!.netTotal;
      store.completeCheckout([
        PaymentEntry(method: PaymentMethod.click, amountMru: net2, reference: 'CLK-1'),
      ]);

      final z2 = store.submitBlindClosingZ(
        countedCashMru: 0,
        countedBankilyMru: 0,
        countedMasriviMru: 0,
        countedSedadMru: 0,
        countedClickMru: net2,
      );
      expect(z2.expectedBimbankMru, 0);
      expect(z2.expectedClickMru, net2);
      expect(z2.ordersCount, 1);
    });

    test('Offline license activation parses 8-digit code and signed Lease Token', () {
      final store = PosStore(enablePersistence: false);
      expect(store.activateOfflineLicense('bad'), isNotNull);

      expect(store.activateOfflineLicense('7711-2233-4455'), isNull);
      expect(store.license.code12, '7711-2233-4455');
      expect(store.license.ed25519Verified, isTrue);

      final payloadB64 = base64Url.encode(utf8.encode(jsonEncode({
        'code': '9988-7766-5544',
        'days': 90,
        'storeName': 'Dar El-Karam Resto',
        'expiresAt': DateTime.now().add(const Duration(days: 90)).toIso8601String(),
      })));
      expect(store.activateOfflineLicense('$payloadB64.FakeSig'), isNull);
      expect(store.license.code12, '9988-7766-5544');
      expect(store.license.daysRemaining, greaterThanOrEqualTo(89));
    });

    test('Local persistence saves and restores SyncQueue, Karni, and session across reloads', () {
      localStorageRemove('fulltek_pos_state_v1');
      final store1 = PosStore(enablePersistence: true);
      store1.loginWithPin('7410');
      store1.accountLoggedIn = true;
      store1.tenantName = 'Resto Persistant';
      store1.startCounterOrder();
      store1.addItemToActiveOrder(store1.menuItems.firstWhere((m) => m.available));
      final net = store1.activeOrder!.netTotal;
      store1.completeCheckout([
        PaymentEntry(method: PaymentMethod.cash, amountMru: net),
      ]);
      expect(store1.pendingSyncCount, 1);

      final store2 = PosStore(enablePersistence: true);
      expect(store2.accountLoggedIn, isTrue);
      expect(store2.tenantName, 'Resto Persistant');
      expect(store2.pendingSyncCount, 1);
      localStorageRemove('fulltek_pos_state_v1');
    });
  });
}
