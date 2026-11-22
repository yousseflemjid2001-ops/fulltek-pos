import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:fulltek_pos/models/pos_models.dart';
import 'package:fulltek_pos/services/catalog_mapper.dart';
import 'package:fulltek_pos/services/http_bridge.dart';
import 'package:fulltek_pos/state/pos_store.dart';

void main() {
  group('F09 — KDS Multi-Station & 86 Stock-Out Blocking', () {
    test('sendActiveOrderToKitchen creates persistent KdsTicket & partial/full ready works',
        () async {
      final store = PosStore()..loginWithPin('7410');
      store.openOrSelectTable('T1');
      final mechoui = store.menuItems.firstWhere((m) => m.id == 'M2'); // GRILL
      final ataya = store.menuItems.firstWhere((m) => m.id == 'M12'); // BAR

      expect(store.addItemToActiveOrder(mechoui), isTrue);
      expect(store.addItemToActiveOrder(ataya), isTrue);

      final text = store.sendActiveOrderToKitchen();
      expect(text, isNotNull);
      expect(store.kdsTickets, hasLength(1));

      final ticket = store.kdsTickets.first;
      expect(store.activeKdsTickets(KdsStationFilter.all), hasLength(1));
      expect(store.activeKdsTickets(KdsStationFilter.grill), hasLength(1));
      expect(store.activeKdsTickets(KdsStationFilter.bar), hasLength(1));
      expect(store.activeKdsTickets(KdsStationFilter.kitchen), isEmpty);

      // Mark GRILL ready only -> BAR still pending
      expect(await store.markKdsTicketReady(ticket.id, station: 'GRILL'),
          isTrue);
      expect(store.activeKdsTickets(KdsStationFilter.grill), isEmpty);
      expect(store.activeKdsTickets(KdsStationFilter.bar), hasLength(1));
      expect(store.kdsTickets.first.status, 'preparing');

      // Mark BAR ready -> ticket becomes fully ready
      expect(await store.markKdsTicketReady(ticket.id, station: 'BAR'), isTrue);
      expect(store.activeKdsTickets(KdsStationFilter.all), isEmpty);
      expect(store.kdsTickets.first.status, 'ready');
      expect(store.kdsTickets.first.readyAt, isNotNull);
    });

    test('86 Rupture (ÉPUISÉ) blocks addItemToActiveOrder & updateLineQuantity(+1)',
        () async {
      final store = PosStore()..loginWithPin('7410');
      final m1 = store.menuItems.firstWhere((m) => m.id == 'M1');

      // Add 1x M1 while available
      expect(store.addItemToActiveOrder(m1), isTrue);
      final lineId = store.activeOrder!.items.first.lineId;

      // Mark M1 out of stock (86)
      expect(await store.toggleItemAvailability('M1'), isTrue);
      expect(store.outOfStockItems.map((m) => m.id), contains('M1'));

      // Adding M1 again is blocked
      expect(store.addItemToActiveOrder(m1), isFalse);
      expect(store.activeOrder!.items.first.quantity, 1);

      // Incrementing line quantity (+1) is blocked while decrement (-1) works
      store.updateLineQuantity(lineId, 1);
      expect(store.activeOrder!.items.first.quantity, 1);

      // Restore M1 availability -> adding works again
      expect(await store.toggleItemAvailability('M1'), isTrue);
      expect(store.outOfStockItems, isEmpty);
      expect(store.addItemToActiveOrder(m1), isTrue);
      expect(store.activeOrder!.items.first.quantity, 2);
    });

    test('Order lines group distinctly by selectedModifiers', () {
      final store = PosStore()..loginWithPin('7410');
      final m5 = store.menuItems.firstWhere((m) => m.id == 'M5');
      final extrasGroup =
          m5.modifiers.firstWhere((g) => g.id == 'mg-extras');
      final mozzOpt =
          extrasGroup.options.firstWhere((o) => o.id == 'opt-mozzarella');
      final mozzSel =
          SelectedModifier.fromOption(group: extrasGroup, option: mozzOpt);

      store.addItemToActiveOrder(m5);
      store.addItemToActiveOrder(m5, selectedModifiers: [mozzSel]);
      store.addItemToActiveOrder(m5, selectedModifiers: [mozzSel]);

      expect(store.activeOrder!.items, hasLength(2));
      expect(store.activeOrder!.items[0].quantity, 1);
      expect(store.activeOrder!.items[1].quantity, 2);
      expect(store.activeOrder!.items[1].unitPriceWithModifiers, 810);
      expect(store.activeOrder!.subtotal, 750 + 1620);
    });
  });

  group('F10 — Delivery, Table Transfer/Merge, BOM, KPIs & Training Isolation',
      () {
    test('Service modes & Nouakchott delivery fees + free >= 1500 MRU', () {
      final store = PosStore()..loginWithPin('7410');
      final ksar =
          store.deliveryZones.firstWhere((z) => z.id == 'zone-ksar'); // 150 MRU
      store.setServiceMode(ServiceMode.delivery);
      store.setDeliveryZone(ksar);
      store.setDeliveryInfo(
        customerName: 'Sidi',
        customerPhone: '+222 46 11 22 33',
        deliveryAddress: 'Ksar Carrefour',
      );

      final m6 = store.menuItems.firstWhere((m) => m.id == 'M6'); // 350 MRU
      store.addItemToActiveOrder(m6);
      expect(store.activeOrder!.deliveryFeeMru, 150);
      expect(store.activeOrder!.netTotal, 500);

      // Push subtotal to 1750 (>= 1500) -> free delivery
      for (int i = 0; i < 4; i++) {
        store.addItemToActiveOrder(m6);
      }
      expect(store.activeOrder!.subtotal, 1750);
      expect(store.activeOrder!.deliveryFeeMru, 0);
      expect(store.activeOrder!.netTotal, 1750);

      // Takeaway assigns sequential call number
      store.setServiceMode(ServiceMode.takeaway);
      expect(store.activeOrder!.takeawayNumber, isNotNull);
      expect(store.activeOrder!.deliveryFeeMru, 0);
    });

    test('transferTable and mergeTables move orders and free source table', () {
      final store = PosStore()..loginWithPin('7410');
      final m1 = store.menuItems.firstWhere((m) => m.id == 'M1');
      final m12 = store.menuItems.firstWhere((m) => m.id == 'M12');

      store.openOrSelectTable('T1', guests: 3);
      store.addItemToActiveOrder(m1);
      expect(store.transferTable('T1', 'T2'), isTrue);
      expect(store.tables.firstWhere((t) => t.id == 'T1').status,
          TableStatus.free);
      expect(store.tables.firstWhere((t) => t.id == 'T2').status,
          TableStatus.occupied);
      expect(store.orderForTable('T2')!.items, hasLength(1));

      store.openOrSelectTable('T3', guests: 2);
      store.addItemToActiveOrder(m12);
      expect(store.mergeTables('T3', 'T2'), isTrue);
      expect(store.tables.firstWhere((t) => t.id == 'T3').status,
          TableStatus.free);
      expect(store.orderForTable('T2')!.items, hasLength(2));
      expect(store.tables.firstWhere((t) => t.id == 'T2').guests, 5);
    });

    test(
        'BOM auto-deduction (base, TAKEAWAY_DELIVERY, modifier, remake) & Owner KPIs',
        () {
      final store = PosStore()..loginWithPin('7410');

      double stockOf(String sku) =>
          store.ingredients.firstWhere((i) => i.sku == sku).currentStock;

      final beefBefore = stockOf('ING-BEEF');
      final lambBefore = stockOf('ING-LAMB');
      final mozzBefore = stockOf('ING-MOZZ');
      final boxBefore = stockOf('ING-BOX');
      final bagBefore = stockOf('ING-BAG');

      // 1. Dine-in M5 + Mozzarella (no packaging deducted)
      final m5 = store.menuItems.firstWhere((m) => m.id == 'M5'); // 750
      final extras = m5.modifiers.firstWhere((g) => g.id == 'mg-extras');
      final mozz =
          extras.options.firstWhere((o) => o.id == 'opt-mozzarella'); // +60
      store.addItemToActiveOrder(
        m5,
        selectedModifiers: [
          SelectedModifier.fromOption(group: extras, option: mozz)
        ],
      );
      store.completeCheckout([
        const PaymentEntry(method: PaymentMethod.bimbank, amountMru: 810),
      ]);

      expect(stockOf('ING-BEEF'), closeTo(beefBefore - 0.25, 1e-6));
      expect(stockOf('ING-LAMB'), closeTo(lambBefore - 0.20, 1e-6));
      expect(stockOf('ING-MOZZ'), closeTo(mozzBefore - 0.06, 1e-6));
      expect(stockOf('ING-BOX'), boxBefore);
      expect(stockOf('ING-BAG'), bagBefore);

      // 2. Takeaway M6 + Remake waste (double deduction + packaging)
      final chickBefore = stockOf('ING-CHICK');
      store.setServiceMode(ServiceMode.takeaway);
      final m6 = store.menuItems.firstWhere((m) => m.id == 'M6'); // 350
      store.addItemToActiveOrder(m6);
      final lineId = store.activeOrder!.items.first.lineId;
      expect(
        store.recordReturnRemakeComp(
          lineId: lineId,
          type: 'remake',
          reason: 'Brûlé',
        ),
        isTrue,
      );
      store.completeCheckout([
        const PaymentEntry(method: PaymentMethod.click, amountMru: 350),
      ]);

      // Remake deducted 0.25 + 1 box + 1 bag, checkout deducted 0.25 + 1 box + 1 bag
      expect(stockOf('ING-CHICK'), closeTo(chickBefore - 0.50, 1e-6));
      expect(stockOf('ING-BOX'), closeTo(boxBefore - 2.0, 1e-6));
      expect(stockOf('ING-BAG'), closeTo(bagBefore - 2.0, 1e-6));

      // Owner KPIs
      expect(store.todayRevenueMru, 810 + 350);
      expect(store.todayTicketsCount, 2);
      expect(store.averageBasketMru, 580);
      expect(store.revenueByPaymentMethod[PaymentMethod.bimbank], 810);
      expect(store.revenueByPaymentMethod[PaymentMethod.click], 350);
      expect(store.todayFoodCostMru, greaterThan(0));
      expect(store.foodCostPercent, greaterThan(0));
      expect(store.grossMarginPercent, lessThan(100));

      // Trigger low stock alert when currentStock <= minStock
      final ingIdx =
          store.ingredients.indexWhere((i) => i.sku == 'ING-MOZZ');
      store.ingredients[ingIdx] =
          store.ingredients[ingIdx].copyWith(currentStock: 1.5);
      expect(store.lowStockIngredients.map((i) => i.sku),
          contains('ING-MOZZ'));
    });

    test('Training Mode strictly isolates orders, KPIs, Closing Z, Karni, BOM & Sync',
        () {
      final store = PosStore()..loginWithPin('1234'); // Cashier cannot voidOrComp
      expect(store.toggleTrainingMode(), isFalse);
      expect(store.toggleTrainingMode(managerPin: '9999'), isTrue);
      expect(store.trainingMode, isTrue);

      final karniBefore = store.karniCustomers.first.balanceDueMru;
      final beefBefore = store.ingredients
          .firstWhere((i) => i.sku == 'ING-BEEF')
          .currentStock;
      final syncBefore = store.pendingSyncCount;

      final m5 = store.menuItems.firstWhere((m) => m.id == 'M5');
      store.addItemToActiveOrder(m5);
      final lineId = store.activeOrder!.items.first.lineId;
      expect(
        store.recordReturnRemakeComp(
          lineId: lineId,
          type: 'remake',
          reason: 'Test formation',
          managerPin: '9999',
        ),
        isTrue,
      );

      final closed = store.completeCheckout([
        PaymentEntry(
          method: PaymentMethod.karni,
          amountMru: 750,
          karniCustomerId: store.karniCustomers.first.id,
        ),
      ]);
      expect(closed, isNotNull);
      expect(closed!.isTraining, isTrue);
      expect(store.trainingOrders, hasLength(1));

      // Strict isolation checks
      expect(store.completedOrders, isEmpty);
      expect(store.todayRevenueMru, 0);
      expect(store.todayTicketsCount, 0);
      expect(store.remakeRecords, isEmpty);
      expect(store.karniCustomers.first.balanceDueMru, karniBefore);
      expect(
        store.ingredients.firstWhere((i) => i.sku == 'ING-BEEF').currentStock,
        beefBefore,
      );
      expect(store.pendingSyncCount, syncBefore);

      final z = store.submitBlindClosingZ(
        countedCashMru: 0,
        countedBankilyMru: 0,
        countedMasriviMru: 0,
        countedSedadMru: 0,
      );
      expect(z.ordersCount, 0);
      expect(z.totalExpectedMru, 0);
    });
  });

  group('F11 — CatalogMapper & Cloud Catalog Client + Offline Fallback', () {
    final sampleCatalogPayload = <String, dynamic>{
      'ok': true,
      'tenantId': 1,
      'tenant': {
        'id': 1,
        'code': 'FT-1041',
        'name': 'Dar El-Karam Cloud',
        'module': 'resto',
        'defaultLang': 'fr',
        'enabledThemes': ['01', '04', '06', '07', '11'],
        'payMethods': [
          'Cash',
          'Bankily',
          'Masrivi',
          'Sedad',
          'Bimbank',
          'Click',
          'Karni'
        ],
        'daysLeft': 15,
        'ownerPin': '7410',
        'deliveryZones': [
          {
            'id': 'zone-centre',
            'nameFr': 'Centre / Ilot K',
            'nameAr': 'المركز',
            'nameEn': 'Center',
            'feeMru': 50,
          },
        ],
        'freeDeliveryAboveMru': 1800,
      },
      'categories': [
        {
          'id': 'cat-grill',
          'nameFr': 'Grillades',
          'nameAr': 'مشويات',
          'nameEn': 'Grills',
          'icon': '🍖',
          'sortOrder': 1,
          'active': true,
        },
      ],
      'products': [
        {
          'id': 'item-mechoui',
          'categoryId': 'cat-grill',
          'sku': 'RST-GRL-01',
          'nameFr': 'Méchoui Royal Cloud',
          'nameAr': 'مشوي ملكي',
          'nameEn': 'Royal Mechoui',
          'icon': '🍖',
          'priceMru': 1500,
          'kitchenStation': 'GRILL',
          'isTop': true,
          'isOutOfStock': false,
          'available': true,
          'modifiers': [
            {
              'id': 'mg-cuisson',
              'nameFr': 'Cuisson',
              'nameAr': 'درجة الطهي',
              'nameEn': 'Cooking',
              'required': false,
              'multiSelect': false,
              'options': [
                {
                  'id': 'opt-bien',
                  'nameFr': 'Bien cuit',
                  'nameAr': 'ناضج جداً',
                  'nameEn': 'Well done',
                  'extraPriceMru': 0,
                  'bomKey': '',
                },
              ],
            },
          ],
        },
      ],
      'diningZones': [
        {
          'id': 'z1',
          'nameFr': 'Terrasse',
          'nameAr': 'الشرفة',
          'nameEn': 'Terrace',
          'zoneType': 'TERRACE',
          'isVip': false,
          'minSpendMru': 0,
          'tables': [
            {
              'id': 't-01',
              'code': 'T-01',
              'seats': 4,
              'shape': 'round',
              'x': 0.2,
              'y': 0.3,
              'status': 'free',
            },
          ],
        },
      ],
      'reservationsVip': [
        {
          'id': 'RES-CLOUD-1',
          'customerName': 'VIP Client',
          'phone': '+222 45 00 00 00',
          'tableId': 'non-existent-id',
          'guests': 6,
          'timeSlot': '21:00',
          'arbounMru': 1000,
        },
      ],
      'ingredients': [
        {
          'id': 'ing-lamb',
          'sku': 'ING-LAMB',
          'nameFr': 'Agneau',
          'nameAr': 'خروف',
          'nameEn': 'Lamb',
          'unit': 'kg',
          'pmpCostMru': 400,
          'currentStock': 10.0,
          'minStock': 2.0,
        },
      ],
      'recipesBom': [
        {
          'id': 1,
          'productId': 'item-mechoui',
          'productSku': 'RST-GRL-01',
          'ingredientId': 'ing-lamb',
          'ingredientSku': 'ING-LAMB',
          'qtyPerUnit': 0.5,
          'conditionChannel': 'ALL',
          'modifierKey': '',
        },
      ],
      'karniCustomers': [
        {
          'id': '1',
          'name': 'Sidi Mohamed',
          'phone': '+222 46 11 22 33',
          'creditLimitMru': 10000,
          'balanceDueMru': 1500,
        },
      ],
    };

    test('CatalogMapper.fromJson parses full payload & safely maps missing reservation tableId',
        () {
      final parsed = CatalogMapper.fromJson(sampleCatalogPayload);
      expect(parsed.tenantName, 'Dar El-Karam Cloud');
      expect(parsed.freeDeliveryAboveMru, 1800);
      expect(parsed.menuItems, hasLength(1));
      expect(parsed.menuItems.first.isTop, isTrue);
      expect(parsed.menuItems.first.modifiers, hasLength(1));
      expect(parsed.tables, hasLength(1));
      expect(parsed.tables.first.shape, TableShape.round);
      expect(parsed.reservations, hasLength(1));
      // Missing tableId fell back to existing table 't-01'
      expect(parsed.reservations.first.tableId, 't-01');
      expect(parsed.ingredients, hasLength(1));
      expect(parsed.recipesBom, hasLength(1));
      expect(parsed.karniCustomers, hasLength(1));
    });

    test('PosStore loginAccount fetches cloud catalog & syncs; falls back cleanly offline',
        () async {
      final calls = <String>[];
      final store = PosStore(
        httpRequest: (method, url, {headers, body}) async {
          calls.add('$method $url');
          if (url.endsWith('/api/auth/login')) {
            return HttpBridgeResponse(
              200,
              jsonEncode({
                'token': 'jwt-test-123',
                'tenant': {
                  'name': 'Dar El-Karam Cloud',
                  'tenantId': 'FT-1041',
                  'module': 'resto',
                  'status': 'active',
                  'enabledThemes': ['01', '04', '06', '07', '11'],
                  'daysLeft': 15,
                  'ownerPin': '7410',
                  'defaultLang': 'fr',
                },
              }),
            );
          }
          if (url.endsWith('/api/pos/catalog')) {
            return HttpBridgeResponse(200, jsonEncode(sampleCatalogPayload));
          }
          if (url.endsWith('/api/pos/sync')) {
            final decoded = jsonDecode(body!) as Map<String, dynamic>;
            final items = decoded['items'] as List;
            final orderPayload =
                (items.first as Map)['payload'] as Map<String, dynamic>;
            expect(orderPayload['service_mode'], 'DINE_IN');
            expect(orderPayload['tva_mru'], isNotNull);
            expect(orderPayload['is_training'], isFalse);
            return HttpBridgeResponse(
              200,
              jsonEncode({'ok': true, 'synced': items.length}),
            );
          }
          return const HttpBridgeResponse(404, '{}');
        },
      );

      final err = await store.loginAccount('darelkram41', 'FullTek@2026');
      expect(err, isNull);
      expect(store.cloudConnected, isTrue);
      expect(store.catalogSource, 'cloud_api');
      expect(store.menuItems.single.nameFr, 'Méchoui Royal Cloud');
      expect(calls, contains('GET http://localhost:4000/api/pos/catalog'));

      // Checkout & sync to cloud
      store.loginWithPin('7410');
      store.addItemToActiveOrder(store.menuItems.single);
      store.completeCheckout([
        const PaymentEntry(method: PaymentMethod.cash, amountMru: 1500),
      ]);
      final synced = await store.syncPendingToCloud();
      expect(synced, 1);
      expect(store.pendingSyncCount, 0);

      // Production mode: server unreachable must NOT allow hardcoded demo backdoor
      final offlineStore = PosStore(
        httpRequest: (method, url, {headers, body}) async {
          throw Exception('Network unreachable');
        },
      );
      final offErr =
          await offlineStore.loginAccount('darelkram41', 'FullTek@2026');
      expect(offErr, isNotNull);
      expect(offlineStore.accountLoggedIn, isFalse);
      expect(offlineStore.cloudConnected, isFalse);
    });
  });
}
