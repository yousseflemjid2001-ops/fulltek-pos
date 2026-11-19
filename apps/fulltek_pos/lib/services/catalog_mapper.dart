import 'dart:convert';
import '../models/pos_models.dart';

class ParsedCloudCatalog {
  final String? tenantName;
  final String? tenantCode;
  final String? defaultLang;
  final List<String> enabledThemeCodes;
  final List<String> payMethods;
  final int? daysLeft;
  final String? ownerPin;
  final double? freeDeliveryAboveMru;
  final List<DeliveryZone> deliveryZones;
  final List<MenuCategory> categories;
  final List<MenuItem> menuItems;
  final List<DiningZone> zones;
  final List<DiningTable> tables;
  final List<VipReservation> reservations;
  final List<Ingredient> ingredients;
  final List<RecipeBomLine> recipesBom;
  final List<KarniCustomer> karniCustomers;

  const ParsedCloudCatalog({
    this.tenantName,
    this.tenantCode,
    this.defaultLang,
    this.enabledThemeCodes = const [],
    this.payMethods = const [],
    this.daysLeft,
    this.ownerPin,
    this.freeDeliveryAboveMru,
    this.deliveryZones = const [],
    this.categories = const [],
    this.menuItems = const [],
    this.zones = const [],
    this.tables = const [],
    this.reservations = const [],
    this.ingredients = const [],
    this.recipesBom = const [],
    this.karniCustomers = const [],
  });
}

class CatalogMapper {
  static List<dynamic> _asList(dynamic raw) {
    if (raw is List) return raw;
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded;
      } catch (_) {}
    }
    return const [];
  }

  static bool _asBool(dynamic v, {bool fallback = false}) {
    if (v == null) return fallback;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = '$v'.trim().toLowerCase();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
    return fallback;
  }

  static double _asDouble(dynamic v, {double fallback = 0.0}) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? fallback;
  }

  static int _asInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? fallback;
  }

  static TableStatus _parseTableStatus(String? raw) {
    return switch ((raw ?? '').trim().toLowerCase()) {
      'occupied' || 'busy' => TableStatus.occupied,
      'reserved' => TableStatus.reserved,
      'billrequested' || 'bill_requested' || 'bill' => TableStatus.billRequested,
      _ => TableStatus.free,
    };
  }

  static ParsedCloudCatalog fromJson(Map<String, dynamic> json) {
    final tenantRaw = json['tenant'];
    final tenant = tenantRaw is Map
        ? tenantRaw.cast<String, dynamic>()
        : const <String, dynamic>{};

    final enabledThemes = _asList(
            tenant['enabledThemes'] ?? tenant['enabled_themes'])
        .map((e) => '$e')
        .where((e) => e.isNotEmpty)
        .toList();

    final payMethods =
        _asList(tenant['payMethods'] ?? tenant['pay_methods'])
            .map((e) => '$e')
            .where((e) => e.isNotEmpty)
            .toList();

    final deliveryZonesRaw = _asList(
      tenant['deliveryZones'] ??
          tenant['delivery_zones'] ??
          tenant['delivery_zones_json'] ??
          json['deliveryZones'] ??
          json['delivery_zones'],
    );
    final deliveryZones = deliveryZonesRaw
        .whereType<Map>()
        .map((m) => DeliveryZone.fromJson(m.cast<String, dynamic>()))
        .toList();

    final categories = _asList(json['categories'])
        .whereType<Map>()
        .map((raw) {
          final c = raw.cast<String, dynamic>();
          final nameFr = '${c['nameFr'] ?? c['name_fr'] ?? c['name'] ?? ''}';
          return MenuCategory(
            id: '${c['id'] ?? c['code'] ?? ''}',
            nameFr: nameFr,
            nameAr: '${c['nameAr'] ?? c['name_ar'] ?? nameFr}',
            nameEn: '${c['nameEn'] ?? c['name_en'] ?? nameFr}',
            icon: '${c['icon'] ?? '🍽'}',
            sortOrder: _asInt(c['sortOrder'] ?? c['sort_order']),
            active: _asBool(c['active'], fallback: true),
          );
        })
        .where((c) => c.id.isNotEmpty && c.active)
        .toList();

    final menuItems = _asList(json['products'] ?? json['menuItems'])
        .whereType<Map>()
        .map((raw) {
          final p = raw.cast<String, dynamic>();
          final nameFr = '${p['nameFr'] ?? p['name_fr'] ?? p['name'] ?? ''}';
          final modsRaw = _asList(p['modifiers'] ?? p['modifiers_json']);
          final modifiers = modsRaw
              .whereType<Map>()
              .map((g) => ModifierGroup.fromJson(g.cast<String, dynamic>()))
              .toList();

          final hasExplicitOut =
              p.containsKey('isOutOfStock') || p.containsKey('is_out_of_stock');
          final outOfStock = _asBool(
            p['isOutOfStock'] ?? p['is_out_of_stock'],
            fallback: false,
          );
          final available = p.containsKey('available')
              ? _asBool(p['available'], fallback: !outOfStock)
              : (hasExplicitOut ? !outOfStock : true);

          return MenuItem(
            id: '${p['id'] ?? p['sku'] ?? ''}',
            categoryId: '${p['categoryId'] ?? p['category_id'] ?? ''}',
            sku: '${p['sku'] ?? ''}',
            nameFr: nameFr,
            nameAr: '${p['nameAr'] ?? p['name_ar'] ?? nameFr}',
            nameEn: '${p['nameEn'] ?? p['name_en'] ?? nameFr}',
            priceMru: _asDouble(
              p['priceMru'] ?? p['price_mru'] ?? p['price_retail'] ?? p['price'],
            ),
            kitchenStation:
                '${p['kitchenStation'] ?? p['kitchen_station'] ?? 'KITCHEN'}'
                    .toUpperCase(),
            available: available,
            icon: '${p['icon'] ?? '🍽'}',
            imageUrl: '${p['imageUrl'] ?? p['image_url'] ?? ''}'.trim(),
            isTop: _asBool(p['isTop'] ?? p['is_top'], fallback: false),
            modifiers: modifiers,
          );
        })
        .where((m) => m.id.isNotEmpty)
        .toList();

    final zones = <DiningZone>[];
    final tables = <DiningTable>[];
    for (final rawZ in _asList(json['diningZones'] ?? json['dining_zones'])
        .whereType<Map>()) {
      final z = rawZ.cast<String, dynamic>();
      final zoneId = '${z['id'] ?? ''}';
      if (zoneId.isEmpty) continue;
      final nameFr = '${z['nameFr'] ?? z['name_fr'] ?? z['name'] ?? ''}';
      final isVip = _asBool(z['isVip'] ?? z['is_vip'], fallback: false);
      final zoneMinSpend =
          _asDouble(z['minSpendMru'] ?? z['min_spend_mru']);
      zones.add(
        DiningZone(
          id: zoneId,
          nameFr: nameFr,
          nameAr: '${z['nameAr'] ?? z['name_ar'] ?? nameFr}',
          nameEn: '${z['nameEn'] ?? z['name_en'] ?? nameFr}',
          isVip: isVip,
          zoneType: '${z['zoneType'] ?? z['zone_type'] ?? 'SALLE'}',
          minSpendMru: zoneMinSpend,
        ),
      );

      final zoneTables = _asList(z['tables']).whereType<Map>().toList();
      if (zoneTables.isNotEmpty) {
        for (final rawT in zoneTables) {
          final t = rawT.cast<String, dynamic>();
          final tId = '${t['id'] ?? ''}';
          if (tId.isEmpty) continue;
          tables.add(
            DiningTable(
              id: tId,
              zoneId: zoneId,
              code: '${t['code'] ?? tId}',
              seats: _asInt(t['seats'] ?? t['capacity'], fallback: 4),
              status: _parseTableStatus(t['status'] as String?),
              guests: _asInt(t['guests']),
              shape: TableShape.fromString(
                (t['shape'] ?? (isVip ? 'khaima' : 'square')) as String?,
              ),
              x: _asDouble(t['x']),
              y: _asDouble(t['y']),
              serverName: (t['serverName'] ?? t['server_name']) as String?,
              minSpendMru: _asDouble(
                t['minSpendMru'] ?? t['min_spend_mru'],
                fallback: zoneMinSpend,
              ),
              arbounMru: _asDouble(t['arbounMru'] ?? t['arboun_mru']),
            ),
          );
        }
      } else {
        final count = _asInt(z['tableCount'] ?? z['table_count']);
        for (int i = 1; i <= count; i++) {
          tables.add(
            DiningTable(
              id: '$zoneId-T$i',
              zoneId: zoneId,
              code: '${isVip ? 'KHAIMA' : 'T'}-$i',
              seats: isVip ? 10 : 4,
              shape: isVip ? TableShape.khaima : TableShape.square,
              minSpendMru: zoneMinSpend,
            ),
          );
        }
      }
    }

    final tableIds = tables.map((t) => t.id).toSet();
    final tableByCode = {for (final t in tables) t.code.toUpperCase(): t};
    final reservations = <VipReservation>[];
    for (final rawR
        in _asList(json['reservationsVip'] ?? json['reservations_vip'])
            .whereType<Map>()) {
      final r = rawR.cast<String, dynamic>();
      if (tables.isEmpty) continue;
      final rawTableId = '${r['tableId'] ?? r['table_id'] ?? ''}';
      final rawTableLabel =
          '${r['tableLabel'] ?? r['table_label'] ?? ''}'.toUpperCase();
      String resolvedTableId;
      String resolvedZoneId = '${r['zoneId'] ?? r['zone_id'] ?? ''}';
      if (tableIds.contains(rawTableId)) {
        resolvedTableId = rawTableId;
      } else if (tableByCode.containsKey(rawTableLabel)) {
        resolvedTableId = tableByCode[rawTableLabel]!.id;
      } else {
        resolvedTableId = tables.first.id;
      }
      if (resolvedZoneId.isEmpty) {
        resolvedZoneId =
            tables.firstWhere((t) => t.id == resolvedTableId).zoneId;
      }
      reservations.add(
        VipReservation(
          id: '${r['id'] ?? 'RES-${reservations.length + 1}'}',
          customerName:
              '${r['customerName'] ?? r['customer_name'] ?? 'Client VIP'}',
          phone: '${r['phone'] ?? ''}',
          zoneId: resolvedZoneId,
          tableId: resolvedTableId,
          guests: _asInt(r['guests'], fallback: 6),
          timeSlot: '${r['timeSlot'] ?? r['time_slot'] ?? '20:30'}',
          arbounMru: _asDouble(r['arbounMru'] ?? r['arboun_mru']),
          status: '${r['status'] ?? 'confirmed'}',
          note: r['note'] as String?,
        ),
      );
    }

    final ingredients = _asList(json['ingredients'])
        .whereType<Map>()
        .map((m) => Ingredient.fromJson(m.cast<String, dynamic>()))
        .where((i) => i.id.isNotEmpty)
        .toList();

    final recipesBom = _asList(
      json['recipesBom'] ?? json['recipes_bom'] ?? json['recipes'],
    )
        .whereType<Map>()
        .map((m) => RecipeBomLine.fromJson(m.cast<String, dynamic>()))
        .toList();

    final karniCustomers =
        _asList(json['karniCustomers'] ?? json['karni_customers'])
            .whereType<Map>()
            .map((raw) {
              final k = raw.cast<String, dynamic>();
              final lastStr =
                  (k['lastActivity'] ?? k['last_activity']) as String?;
              return KarniCustomer(
                id: '${k['id'] ?? ''}',
                name: '${k['name'] ?? k['customer_name'] ?? ''}',
                phone: '${k['phone'] ?? k['phone_whatsapp'] ?? ''}',
                creditLimitMru: _asDouble(
                    k['creditLimitMru'] ?? k['credit_limit_mru'],
                    fallback: 10000),
                balanceDueMru:
                    _asDouble(k['balanceDueMru'] ?? k['balance_due_mru']),
                lastActivity: lastStr != null
                    ? (DateTime.tryParse(lastStr) ?? DateTime.now())
                    : DateTime.now(),
              );
            })
            .where((k) => k.id.isNotEmpty)
            .toList();

    final freeDeliveryRaw =
        tenant['freeDeliveryAboveMru'] ?? tenant['free_delivery_above_mru'];
    final daysRaw = tenant['daysLeft'] ?? tenant['days_left'];

    return ParsedCloudCatalog(
      tenantName: tenant['name'] as String?,
      tenantCode: (tenant['code'] ?? tenant['tenantId']) as String?,
      defaultLang: (tenant['defaultLang'] ?? tenant['default_lang']) as String?,
      enabledThemeCodes: enabledThemes,
      payMethods: payMethods,
      daysLeft: daysRaw == null ? null : _asInt(daysRaw),
      ownerPin: (tenant['ownerPin'] ?? tenant['owner_pin']) as String?,
      freeDeliveryAboveMru:
          freeDeliveryRaw == null ? null : _asDouble(freeDeliveryRaw),
      deliveryZones: deliveryZones,
      categories: categories,
      menuItems: menuItems,
      zones: zones,
      tables: tables,
      reservations: reservations,
      ingredients: ingredients,
      recipesBom: recipesBom,
      karniCustomers: karniCustomers,
    );
  }
}
