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

  test(
    'requestAdditionForActiveOrder generates 80mm Pre-note and marks table billRequested',
    () {
      final store = PosStore(enablePersistence: false);
      final waiter = store.staff.firstWhere((s) => s.role == PosRole.waiter);
      expect(store.loginWithPin(waiter.pinCode), isTrue);
      final tbl = store.tables.first;
      store.openOrSelectTable(tbl.id);
      store.addItemToActiveOrder(store.menuItems.first);
      store.sendActiveOrderToKitchen();

      final addition = store.requestAdditionForActiveOrder();
      expect(addition, isNotNull);
      expect(addition, contains('NOTE'));
      expect(addition, contains('Serveur: ${waiter.name}'));
      expect(addition, contains('TOTAL A PAYER:'));
      expect(
        store.tables.firstWhere((t) => t.id == tbl.id).status,
        TableStatus.billRequested,
      );

      // Option "Impression après Note" OFF -> checkout skips auto-print for orders that had a Note
      store.setPrintReceiptAfterNote(false);
      final total = store.activeOrder!.netTotal;
      final paid = store.completeCheckout([
        PaymentEntry(method: PaymentMethod.bankily, amountMru: total),
      ]);
      expect(paid, isNotNull);
      expect(store.lastCheckoutHadNote, isTrue);
      expect(store.shouldAutoPrintLastReceipt, isFalse);

      // Direct counter order without Note still auto-prints even when printReceiptAfterNote == false
      store.addItemToActiveOrder(store.menuItems.first);
      final total2 = store.activeOrder!.netTotal;
      store.completeCheckout([
        PaymentEntry(method: PaymentMethod.cash, amountMru: total2),
      ]);
      expect(store.lastCheckoutHadNote, isFalse);
      expect(store.shouldAutoPrintLastReceipt, isTrue);
    },
  );

  test(
    'Strict movement integrity blocks deleting moved products, families, and staff accounts',
    () async {
      final store = PosStore(enablePersistence: false);
      final cashier = store.staff.firstWhere((s) => s.role == PosRole.cashier);
      expect(store.loginWithPin(cashier.pinCode), isTrue);

      // Create a fresh category and dish, then sell it once
      await store.saveCategory(nameFr: 'Catégorie Test Mouvement');
      final cat = store.categories
          .firstWhere((c) => c.nameFr == 'Catégorie Test Mouvement');
      await store.saveMenuItem(
        nameFr: 'Riz au Poisson Test',
        categoryId: cat.id,
        priceMru: 200,
      );
      final dish = store.menuItems
          .firstWhere((m) => m.nameFr == 'Riz au Poisson Test');

      store.addItemToActiveOrder(dish);
      final paid = store.completeCheckout([
        PaymentEntry(method: PaymentMethod.cash, amountMru: dish.priceMru),
      ]);
      expect(paid, isNotNull);

      // 1. Deleting moved product -> BLOCKED
      expect(await store.deleteMenuItem(dish.id), isFalse);
      expect(store.lastDeleteError, contains('déjà mouvementé'));
      expect(store.menuItems.any((m) => m.id == dish.id), isTrue);

      // 2. Deleting moved family -> BLOCKED
      final catErr = await store.deleteCategory(cat.id);
      expect(catErr, isNotNull);
      expect(catErr, contains('déjà mouvementée'));
      expect(store.categories.any((c) => c.id == cat.id), isTrue);

      // 3. Deleting moved staff account -> BLOCKED
      final staffErr = store.deleteStaffMember(cashier.id);
      expect(staffErr, isNotNull);
      expect(staffErr, contains('déjà mouvementé'));
      expect(store.staff.any((s) => s.id == cashier.id), isTrue);
    },
  );

  test(
    'abandonActiveOrder clears entire unsent order in 1 call and enforces manager PIN + reason after kitchen send',
    () {
      final store = PosStore(enablePersistence: false);
      final owner = store.staff.firstWhere((s) => s.role == PosRole.owner);
      final cashier = store.staff.firstWhere((s) => s.role == PosRole.cashier);
      expect(store.loginWithPin(cashier.pinCode), isTrue);

      // Add 6x dish1 + 1x dish2 (unsent) -> remove 6x line in 1 call, or abandon all in 1 call
      final d1 = store.menuItems[0];
      final d2 = store.menuItems[1];
      for (var i = 0; i < 6; i++) {
        store.addItemToActiveOrder(d1);
      }
      store.addItemToActiveOrder(d2);
      expect(store.activeOrder!.items.first.quantity, 6);
      expect(store.abandonActiveOrder(), '');
      expect(store.activeOrder!.items, isEmpty);

      // Sent-to-kitchen order -> abandon requires reason + manager PIN
      store.openOrSelectTable(store.tables.first.id);
      store.addItemToActiveOrder(d1);
      store.sendActiveOrderToKitchen();
      expect(store.abandonActiveOrder(reason: 'Client parti'), isNull);
      final cancelText = store.abandonActiveOrder(
        reason: 'Client parti',
        managerPin: owner.pinCode,
      );
      expect(cancelText, isNotNull);
      expect(cancelText, contains('ANNULATION CUISINE'));
      expect(store.activeOrder!.items, isEmpty);
      expect(store.tables.first.status, TableStatus.free);
    },
  );

  test(
    'Report X filters per cashier without closing Z, and Shift Transfer moves open tables between cashiers and servers',
    () {
      final store = PosStore(enablePersistence: false);
      final owner = store.staff.firstWhere((s) => s.role == PosRole.owner);
      final cashier = store.staff.firstWhere((s) => s.role == PosRole.cashier);
      final waiter = store.staff.firstWhere((s) => s.role == PosRole.waiter);
      final dish = store.menuItems.first;

      // Cashier completes 1 cash order
      expect(store.loginWithPin(cashier.pinCode), isTrue);
      store.addItemToActiveOrder(dish);
      final total = store.activeOrder!.netTotal;
      store.completeCheckout([
        PaymentEntry(method: PaymentMethod.cash, amountMru: total),
      ]);
      expect(store.unclosedOrdersCount, 1);

      // X Report for cashier shows 1 ticket and DOES NOT close Z
      final xCashier = store.generateReportX80mm(staffName: cashier.name);
      expect(xCashier, contains('RAPPORT X'));
      expect(xCashier, contains('X Caissier: ${cashier.name}'));
      expect(xCashier, contains('Tickets encaisses:'));
      expect(store.unclosedOrdersCount, 1); // still unclosed!

      // Open 2 tables under cashier/waiter and send to kitchen
      final t1 = store.tables[0];
      final t2 = store.tables[1];
      store.openOrSelectTable(t1.id);
      store.setActiveOrderServer(waiter.name);
      store.addItemToActiveOrder(dish);
      store.sendActiveOrderToKitchenAndPark();

      store.openOrSelectTable(t2.id);
      store.setActiveOrderServer(waiter.name);
      store.addItemToActiveOrder(dish);
      store.sendActiveOrderToKitchenAndPark();

      // Transfer shift: waiter -> owner (server transfer) & cashier -> owner (cashier transfer)
      final movedServers = store.transferShiftServer(waiter.name, owner.name);
      expect(movedServers, 2);
      expect(store.orderForTable(t1.id)!.serverName, owner.name);
      expect(store.tables.firstWhere((t) => t.id == t1.id).serverName, owner.name);

      final movedCashier = store.transferShiftCashier(cashier.name, owner.name);
      expect(movedCashier, 2);
      expect(store.orderForTable(t2.id)!.cashierName, owner.name);
    },
  );

  test(
    'Zones anti-duplicate, rename, delete empty vs moved, and 1-click duplicate cleanup',
    () async {
      final store = PosStore(enablePersistence: false);
      final initialZonesCount = store.zones.length;

      // Add a new zone "PRICIPALE" (typo) then rename it to "PRINCIPALE"
      expect(await store.addDiningZone(nameFr: 'PRICIPALE'), isNull);
      expect(store.zones.length, initialZonesCount + 1);
      // Duplicate name (case-insensitive) is strictly blocked
      expect(await store.addDiningZone(nameFr: 'pricipale'), isNotNull);

      final added = store.zones.last;
      expect(
        await store.renameDiningZone(zoneId: added.id, nameFr: 'PRINCIPALE'),
        isNull,
      );
      expect(store.zones.last.nameFr, 'PRINCIPALE');

      // Zone with tables cannot be deleted
      final zoneWithTables = store.zones.first;
      expect(await store.deleteDiningZone(zoneWithTables.id), isNotNull);

      // Empty zone can be deleted
      expect(await store.deleteDiningZone(added.id), isNull);
      expect(store.zones.length, initialZonesCount);

      // Simulate pre-existing duplicate empty TERRASSE zones from server & cleanup in 1 call
      store.zones.addAll(const [
        DiningZone(
          id: 'dup-1',
          nameFr: 'TERRASSE',
          nameAr: 'TERRASSE',
          nameEn: 'TERRASSE',
        ),
        DiningZone(
          id: 'dup-2',
          nameFr: 'TERRASSE',
          nameAr: 'TERRASSE',
          nameEn: 'TERRASSE',
        ),
        DiningZone(
          id: 'dup-3',
          nameFr: 'TERRASSE',
          nameAr: 'TERRASSE',
          nameEn: 'TERRASSE',
        ),
      ]);
      final removed = await store.cleanupDuplicateEmptyZones();
      expect(removed, 2);
      expect(
        store.zones.where((z) => z.nameFr == 'TERRASSE').length,
        1,
      );
    },
  );

  test(
    'All 16 Mauritanian wallets + custom wallet parameterization + Delivery driver on 80mm receipt, X and Z',
    () async {
      final store = PosStore(enablePersistence: false);
      final owner = store.staff.firstWhere((s) => s.role == PosRole.owner);
      expect(store.loginWithPin(owner.pinCode), isTrue);

      // Verify all 16 official Mauritanian wallets are pre-configured & active
      expect(MauritanianWallets.official16.length, 16);
      for (final w in const [
        'Bankily',
        'Masrvi',
        'Sedad',
        'BIM-Bank',
        'BCI-Pay',
        'Click',
        'Amanty',
        'BAMIS Digital',
        'Moov Money',
        'GazaPay',
        'Mattel Money',
        'BaridCash',
        'Rassidy',
        'Chinguitty Mobile',
        'Cashily',
        'Attijari ePAY',
      ]) {
        expect(store.isWalletEnabled(w), isTrue);
      }

      // Add custom wallet "SaharaPay" & toggle "Cashily" off
      expect(await store.addCustomWallet('SaharaPay'), isNull);
      expect(store.isWalletEnabled('SaharaPay'), isTrue);
      await store.toggleWalletEnabled('Cashily', false);
      expect(store.isWalletEnabled('Cashily'), isFalse);

      // Create a Delivery order with Zone + Client + Driver, pay split BCI-Pay + Attijari ePAY
      store.setServiceMode(ServiceMode.delivery);
      store.setDeliveryInfo(
        customerName: 'Sidi Mohamed',
        customerPhone: '+222 36 10 20 30',
        deliveryAddress: 'Ilot K près Pharmacie',
        deliveryDriverName: 'Moussa Moto',
        zone: store.deliveryZones.first,
      );
      store.addItemToActiveOrder(store.menuItems.first);
      final kdsTicket = store.sendActiveOrderToKitchen();
      expect(kdsTicket, contains('Livreur: Moussa Moto'));

      final net = store.activeOrder!.netTotal;
      final closed = store.completeCheckout([
        const PaymentEntry(
          method: PaymentMethod.otherWallet,
          walletLabel: 'BCI-Pay',
          amountMru: 200,
          reference: 'BCI-991',
        ),
        PaymentEntry(
          method: PaymentMethod.otherWallet,
          walletLabel: 'Attijari ePAY',
          amountMru: net - 200,
          reference: 'ATT-442',
        ),
      ]);
      expect(closed, isNotNull);

      final xText = store.generateReportX80mm();
      expect(xText, contains('BCI-Pay:'));
      expect(xText, contains('Attijari ePAY:'));

      final z = store.submitBlindClosingZ(
        countedCashMru: 0,
        countedBankilyMru: 0,
        countedMasriviMru: 0,
        countedSedadMru: 0,
        countedOtherWallets: {'BCI-Pay': 200, 'Attijari ePAY': net - 200},
      );
      expect(z.expectedOtherWalletsMru, net);
      expect(z.totalExpectedMru, net);

      // Used custom/official wallet cannot be removed once used
      expect(await store.addCustomWallet('BCI-Test'), isNull);
      expect(await store.removeCustomWallet('BCI-Test'), isNull);
    },
  );
}
