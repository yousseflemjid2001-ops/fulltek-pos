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
      store1.staff = [
        const StaffMember(
          id: 'STF-1',
          name: 'Patron Test',
          role: PosRole.owner,
          pinCode: '7410',
        ),
      ];
      store1.menuItems = [
        const MenuItem(
          id: 'M-1',
          sku: 'SKU-1',
          categoryId: 'CAT-1',
          nameFr: 'Plat Test',
          nameAr: 'طبق',
          nameEn: 'Test Dish',
          priceMru: 500,
          kitchenStation: 'KITCHEN',
        ),
      ];
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

    test('Menu & Stock CRUD: add/edit/delete dish and restock ingredient with weighted PMP', () async {
      final store = PosStore(enablePersistence: false);
      store.loginWithPin('7410');

      final initialCount = store.menuItems.length;
      final errAdd = await store.saveMenuItem(
        nameFr: 'Sandwich Chawarma VIP',
        nameAr: 'ساندويتش شاورما',
        categoryId: store.categories.first.id,
        priceMru: 220,
        kitchenStation: 'GRILL',
      );
      expect(errAdd, isNull);
      expect(store.menuItems.length, initialCount + 1);
      final added = store.menuItems.first;
      expect(added.priceMru, 220);

      await store.saveMenuItem(
        existingId: added.id,
        nameFr: 'Sandwich Chawarma VIP',
        categoryId: added.categoryId,
        priceMru: 250,
      );
      expect(store.menuItems.firstWhere((m) => m.id == added.id).priceMru, 250);

      await store.deleteMenuItem(added.id);
      expect(store.menuItems.length, initialCount);

      // Restock ingredient & verify weighted PMP: (10*200 + 10*300)/20 = 250
      await store.addIngredient(
        nameFr: 'Tomate Fraîche',
        unit: 'kg',
        currentStock: 10,
        minThreshold: 2,
        pmpCostMru: 200,
      );
      final ing = store.ingredients.last;
      await store.restockIngredient(
        ingredientId: ing.id,
        deltaQty: 10,
        unitCostMru: 300,
      );
      final updatedIng = store.ingredients.firstWhere((i) => i.id == ing.id);
      expect(updatedIng.currentStock, 20);
      expect(updatedIng.pmpCostMru, 250);
    });

    test('Granular PosProfile permissions & magnetic badge login', () {
      final store = PosStore(enablePersistence: false);
      // Custom profile: Caissier-Superviseur (can viewStats + closeCashZ, cannot manageProfilesUsers)
      final errProf = store.saveProfile(
        name: 'Caissier Superviseur',
        baseRole: PosRole.cashier,
        permissions: {
          PosPermission.openTable,
          PosPermission.serveTable,
          PosPermission.editCovers,
          PosPermission.openRegister,
          PosPermission.takeOrders,
          PosPermission.checkout,
          PosPermission.closeCashZ,
          PosPermission.viewStats,
        },
      );
      expect(errProf, isNull);
      final customProf = store.profiles.last;

      // Create user with PIN + magnetic badge + custom profile
      final errUser = store.saveStaffMember(
        name: 'Moussa',
        pinCode: '5566',
        profileId: customProf.id,
        badgeUid: 'MAG-9988',
      );
      expect(errUser, isNull);

      expect(store.loginWithBadge('MAG-9988'), isTrue);
      expect(store.currentStaff?.name, 'Moussa');
      expect(store.canCurrent(PosPermission.closeCashZ), isTrue);
      expect(store.canCurrent(PosPermission.viewStats), isTrue);
      expect(store.canCurrent(PosPermission.manageProfilesUsers), isFalse);

      // Waiter login via badge has restricted permissions
      expect(store.loginWithBadge('BADGE-003'), isTrue);
      expect(store.canCurrent(PosPermission.takeOrders), isTrue);
      expect(store.canCurrent(PosPermission.openTable), isTrue);
      expect(store.canCurrent(PosPermission.checkout), isFalse);
      expect(store.canCurrent(PosPermission.closeCashZ), isFalse);
      expect(store.canCurrent(PosPermission.viewStats), isFalse);
    });

    test('Familles / Catégories (Sans famille, Ajouter, Renommer, Supprimer)',
        () async {
      final store = PosStore(enablePersistence: false);
      expect(store.categories.any((c) => c.id == 'sans-famille'), isTrue);

      final addErr = await store.saveCategory(
        nameFr: 'Pizzas & Snacks',
        nameAr: 'بيتزا',
        icon: '🍕',
      );
      expect(addErr, isNull);
      final created =
          store.categories.firstWhere((c) => c.nameFr == 'Pizzas & Snacks');

      final renameErr = await store.saveCategory(
        existingId: created.id,
        nameFr: 'Pizzas Maison',
        icon: '🍕',
      );
      expect(renameErr, isNull);
      expect(
        store.categories.firstWhere((c) => c.id == created.id).nameFr,
        'Pizzas Maison',
      );

      final dishErr = await store.saveMenuItem(
        nameFr: 'Pizza Royale',
        categoryId: created.id,
        priceMru: 400,
        kitchenStation: 'PIZZA',
      );
      expect(dishErr, isNull);
      final dish =
          store.menuItems.firstWhere((m) => m.nameFr == 'Pizza Royale');
      expect(dish.kitchenStation, 'PIZZA');
      expect(KdsStationFilter.pizza.matchesStation(dish.kitchenStation), isTrue);

      // Cannot delete default 'sans-famille'
      expect(await store.deleteCategory('sans-famille'), isNotNull);

      // Deleting custom family reassigns its dishes to 'sans-famille'
      expect(await store.deleteCategory(created.id), isNull);
      expect(store.categories.any((c) => c.id == created.id), isFalse);
      expect(
        store.menuItems.firstWhere((m) => m.id == dish.id).categoryId,
        'sans-famille',
      );
    });

    test('Saisie prix manuel (manualPrice) creates distinct lines with customPriceMru',
        () async {
      final store = PosStore(enablePersistence: false);
      final err = await store.saveMenuItem(
        nameFr: 'Poisson du jour (au poids)',
        categoryId: 'sans-famille',
        priceMru: 0,
        kitchenStation: 'GRILL',
        manualPrice: true,
      );
      expect(err, isNull);
      final item = store.menuItems
          .firstWhere((m) => m.nameFr == 'Poisson du jour (au poids)');
      expect(item.manualPrice, isTrue);

      store.startCounterOrder();
      store.addItemToActiveOrder(item, customPriceMru: 650);
      store.addItemToActiveOrder(item, customPriceMru: 900);

      final order = store.activeOrder!;
      expect(order.items.length, 2);
      expect(order.items[0].item.priceMru, 650);
      expect(order.items[1].item.priceMru, 900);
      expect(order.grossTotal, 1550);
    });
  });
}
