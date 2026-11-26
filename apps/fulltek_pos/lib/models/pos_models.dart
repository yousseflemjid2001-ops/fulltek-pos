import 'dart:convert';

enum PosRole {
  owner('OWNER', 'Propriétaire', 'المالك', 'Owner'),
  adminSite('ADMIN_SITE', 'Admin Site', 'مدير الفرع', 'Site Admin'),
  manager('MANAGER', 'Gérant / Manager', 'مدير الصالة', 'Manager'),
  cashier('CASHIER', 'Caissier', 'أمين الصندوق', 'Cashier'),
  waiter('WAITER', 'Serveur', 'نادل', 'Waiter'),
  kitchen('KITCHEN', 'Cuisine / KDS', 'المطبخ', 'Kitchen'),
  stockKeeper('STOCK_KEEPER', 'Magasinier', 'أمين المخزن', 'Stock Keeper'),
  accountant('ACCOUNTANT', 'Comptable', 'محاسب', 'Accountant'),
  delivery('DELIVERY', 'Livreur', 'موصل', 'Delivery');

  final String code;
  final String fr;
  final String ar;
  final String en;
  const PosRole(this.code, this.fr, this.ar, this.en);

  String label(String lang) => lang == 'ar' ? ar : (lang == 'en' ? en : fr);
}

enum PosPermission {
  openTable,
  serveTable,
  editCovers,
  openRegister,
  takeOrders,
  checkout,
  applyDiscount,
  voidOrComp,
  splitBill,
  manageReservations,
  manageKarni,
  closeCashZ,
  viewStats,
  manageMenuStock,
  manageProfilesUsers,
  syncCloud,
  accessBackOffice,
  // Granular Back-Office ERP module permissions
  boDashboard,
  boSuppliersPurchases,
  boB2bInvoices,
  boRecipesFoodCost,
  boInventoryWaste,
  boAccounting,
  boTreasuryZ,
  boMenuStock,
  boSalesJournal,
  boKarni,
  boProfilesUsers,
}

extension PosPermissionMeta on PosPermission {
  static const List<PosPermission> backOfficeModulePermissions = [
    PosPermission.boDashboard,
    PosPermission.boSuppliersPurchases,
    PosPermission.boB2bInvoices,
    PosPermission.boRecipesFoodCost,
    PosPermission.boInventoryWaste,
    PosPermission.boAccounting,
    PosPermission.boTreasuryZ,
    PosPermission.boMenuStock,
    PosPermission.boSalesJournal,
    PosPermission.boKarni,
    PosPermission.boProfilesUsers,
  ];

  bool get isBackOfficePermission =>
      this == PosPermission.accessBackOffice ||
      backOfficeModulePermissions.contains(this);

  String get labelFr => switch (this) {
        PosPermission.openTable => 'Ouverture de table',
        PosPermission.serveTable => 'Servir table / Envoi cuisine',
        PosPermission.editCovers => 'Nombre de couverts',
        PosPermission.openRegister => 'Ouverture de caisse',
        PosPermission.takeOrders => 'Prise de commande',
        PosPermission.checkout => 'Encaissement',
        PosPermission.applyDiscount => 'Remises & réductions',
        PosPermission.voidOrComp => 'Annulation / Offert (Comp)',
        PosPermission.splitBill => 'Division d\'addition',
        PosPermission.manageReservations => 'Réservations VIP & Arboun',
        PosPermission.manageKarni => 'Crédit Karni',
        PosPermission.closeCashZ => 'Clôture & impression Z',
        PosPermission.viewStats => 'Statistiques & KPIs',
        PosPermission.manageMenuStock => 'Gestion Menu & Stock',
        PosPermission.manageProfilesUsers => 'Profils, Utilisateurs & Badges',
        PosPermission.syncCloud => 'Synchronisation Cloud',
        PosPermission.accessBackOffice => 'Accès Back-Office (Gestion & Contrôle)',
        PosPermission.boDashboard => 'BO · Tableau de Bord & KPIs',
        PosPermission.boSuppliersPurchases => 'BO · Fournisseurs & Achats',
        PosPermission.boB2bInvoices => 'BO · Facturation B2B / Traiteur',
        PosPermission.boRecipesFoodCost => 'BO · Fiches Techniques & Marges',
        PosPermission.boInventoryWaste => 'BO · Inventaire & Pertes Stock',
        PosPermission.boAccounting => 'BO · Comptabilité, TVA & Grand Livre',
        PosPermission.boTreasuryZ => 'BO · Trésorerie Multi-Comptes & Z',
        PosPermission.boMenuStock => 'BO · Menu, Familles & Suppléments',
        PosPermission.boSalesJournal => 'BO · Journal des Ventes Caisse',
        PosPermission.boKarni => 'BO · Clients & Carnet Karni',
        PosPermission.boProfilesUsers => 'BO · Profils, Utilisateurs & Fiscalité',
      };
}

class PosProfile {
  final String id;
  final String name;
  final PosRole baseRole;
  final Set<PosPermission> permissions;
  final bool isMaster;

  const PosProfile({
    required this.id,
    required this.name,
    required this.baseRole,
    required this.permissions,
    this.isMaster = false,
  });

  bool can(PosPermission perm) => isMaster || permissions.contains(perm);

  PosProfile copyWith({
    String? name,
    PosRole? baseRole,
    Set<PosPermission>? permissions,
  }) {
    return PosProfile(
      id: id,
      name: name ?? this.name,
      baseRole: baseRole ?? this.baseRole,
      permissions: permissions ?? Set<PosPermission>.from(this.permissions),
      isMaster: isMaster,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'baseRole': baseRole.code,
        'permissions': permissions.map((e) => e.name).toList(),
        'isMaster': isMaster,
      };

  factory PosProfile.fromJson(Map<String, dynamic> json) {
    final roleCode = '${json['baseRole'] ?? 'CASHIER'}'.toUpperCase();
    final role = PosRole.values.firstWhere(
      (r) => r.code == roleCode,
      orElse: () => PosRole.cashier,
    );
    final permsRaw = (json['permissions'] as List?) ?? const [];
    final perms = <PosPermission>{};
    for (final p in permsRaw) {
      final found = PosPermission.values.where((e) => e.name == '$p');
      if (found.isNotEmpty) perms.add(found.first);
    }
    // Legacy compatibility: profiles saved before granular BO permissions keep all BO modules
    if (perms.contains(PosPermission.accessBackOffice) &&
        !PosPermissionMeta.backOfficeModulePermissions.any(perms.contains)) {
      perms.addAll(PosPermissionMeta.backOfficeModulePermissions);
    }
    return PosProfile(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? role.fr}',
      baseRole: role,
      permissions: perms,
      isMaster: json['isMaster'] == true,
    );
  }
}

class RbacMatrix {
  static const Map<PosRole, Set<PosPermission>> grants = {
    PosRole.owner: {
      PosPermission.openTable,
      PosPermission.serveTable,
      PosPermission.editCovers,
      PosPermission.openRegister,
      PosPermission.takeOrders,
      PosPermission.checkout,
      PosPermission.applyDiscount,
      PosPermission.voidOrComp,
      PosPermission.splitBill,
      PosPermission.manageReservations,
      PosPermission.manageKarni,
      PosPermission.closeCashZ,
      PosPermission.viewStats,
      PosPermission.manageMenuStock,
      PosPermission.manageProfilesUsers,
      PosPermission.syncCloud,
      PosPermission.accessBackOffice,
      PosPermission.boDashboard,
      PosPermission.boSuppliersPurchases,
      PosPermission.boB2bInvoices,
      PosPermission.boRecipesFoodCost,
      PosPermission.boInventoryWaste,
      PosPermission.boAccounting,
      PosPermission.boTreasuryZ,
      PosPermission.boMenuStock,
      PosPermission.boSalesJournal,
      PosPermission.boKarni,
      PosPermission.boProfilesUsers,
    },
    PosRole.adminSite: {
      PosPermission.openTable,
      PosPermission.serveTable,
      PosPermission.editCovers,
      PosPermission.openRegister,
      PosPermission.takeOrders,
      PosPermission.checkout,
      PosPermission.applyDiscount,
      PosPermission.voidOrComp,
      PosPermission.splitBill,
      PosPermission.manageReservations,
      PosPermission.manageKarni,
      PosPermission.closeCashZ,
      PosPermission.viewStats,
      PosPermission.manageMenuStock,
      PosPermission.manageProfilesUsers,
      PosPermission.syncCloud,
      PosPermission.accessBackOffice,
      PosPermission.boDashboard,
      PosPermission.boSuppliersPurchases,
      PosPermission.boB2bInvoices,
      PosPermission.boRecipesFoodCost,
      PosPermission.boInventoryWaste,
      PosPermission.boAccounting,
      PosPermission.boTreasuryZ,
      PosPermission.boMenuStock,
      PosPermission.boSalesJournal,
      PosPermission.boKarni,
      PosPermission.boProfilesUsers,
    },
    PosRole.manager: {
      PosPermission.openTable,
      PosPermission.serveTable,
      PosPermission.editCovers,
      PosPermission.openRegister,
      PosPermission.takeOrders,
      PosPermission.checkout,
      PosPermission.applyDiscount,
      PosPermission.voidOrComp,
      PosPermission.splitBill,
      PosPermission.manageReservations,
      PosPermission.manageKarni,
      PosPermission.closeCashZ,
      PosPermission.viewStats,
      PosPermission.manageMenuStock,
      PosPermission.syncCloud,
      PosPermission.accessBackOffice,
      PosPermission.boDashboard,
      PosPermission.boSuppliersPurchases,
      PosPermission.boB2bInvoices,
      PosPermission.boRecipesFoodCost,
      PosPermission.boInventoryWaste,
      PosPermission.boTreasuryZ,
      PosPermission.boMenuStock,
      PosPermission.boSalesJournal,
      PosPermission.boKarni,
    },
    PosRole.cashier: {
      PosPermission.openTable,
      PosPermission.serveTable,
      PosPermission.editCovers,
      PosPermission.openRegister,
      PosPermission.takeOrders,
      PosPermission.checkout,
      PosPermission.splitBill,
      PosPermission.manageReservations,
      PosPermission.manageKarni,
      PosPermission.closeCashZ,
      PosPermission.syncCloud,
    },
    PosRole.waiter: {
      PosPermission.openTable,
      PosPermission.serveTable,
      PosPermission.editCovers,
      PosPermission.takeOrders,
      PosPermission.splitBill,
      PosPermission.manageReservations,
    },
    PosRole.kitchen: {},
    PosRole.stockKeeper: {
      PosPermission.manageMenuStock,
      PosPermission.accessBackOffice,
      PosPermission.boDashboard,
      PosPermission.boSuppliersPurchases,
      PosPermission.boRecipesFoodCost,
      PosPermission.boInventoryWaste,
      PosPermission.boMenuStock,
    },
    PosRole.accountant: {
      PosPermission.closeCashZ,
      PosPermission.viewStats,
      PosPermission.syncCloud,
      PosPermission.accessBackOffice,
      PosPermission.boDashboard,
      PosPermission.boB2bInvoices,
      PosPermission.boAccounting,
      PosPermission.boTreasuryZ,
      PosPermission.boSalesJournal,
      PosPermission.boKarni,
    },
    PosRole.delivery: {PosPermission.takeOrders},
  };

  static bool can(PosRole role, PosPermission perm) {
    return grants[role]?.contains(perm) ?? false;
  }
}

class StaffMember {
  final String id;
  final String name;
  final PosRole role;
  final String pinCode;
  final String? profileId;
  final String badgeUid;
  final bool isActive;

  const StaffMember({
    required this.id,
    required this.name,
    required this.role,
    required this.pinCode,
    this.profileId,
    this.badgeUid = '',
    this.isActive = true,
  });

  bool can(PosPermission perm) => RbacMatrix.can(role, perm);

  StaffMember copyWith({
    String? name,
    PosRole? role,
    String? pinCode,
    String? profileId,
    String? badgeUid,
    bool? isActive,
  }) {
    return StaffMember(
      id: id,
      name: name ?? this.name,
      role: role ?? this.role,
      pinCode: pinCode ?? this.pinCode,
      profileId: profileId ?? this.profileId,
      badgeUid: badgeUid ?? this.badgeUid,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role.code,
        'pinCode': pinCode,
        'profileId': profileId,
        'badgeUid': badgeUid,
        'isActive': isActive,
      };

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    final roleCode = '${json['role'] ?? 'CASHIER'}'.toUpperCase();
    final role = PosRole.values.firstWhere(
      (r) => r.code == roleCode,
      orElse: () => PosRole.cashier,
    );
    return StaffMember(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      role: role,
      pinCode: '${json['pinCode'] ?? '0000'}',
      profileId: json['profileId'] as String?,
      badgeUid: '${json['badgeUid'] ?? ''}',
      isActive: json['isActive'] != false,
    );
  }
}

enum ServiceMode {
  dineIn('DINE_IN', 'Sur place', 'في الصالة', 'Dine-in', '🍽'),
  takeaway('TAKEAWAY', 'Emporter', 'سفري', 'Takeaway', '🥡'),
  delivery('DELIVERY', 'Livraison', 'توصيل', 'Delivery', '🛵');

  final String apiValue;
  final String fr;
  final String ar;
  final String en;
  final String emoji;

  const ServiceMode(
    this.apiValue,
    this.fr,
    this.ar,
    this.en,
    this.emoji,
  );

  String label(String lang) => lang == 'ar' ? ar : (lang == 'en' ? en : fr);

  static ServiceMode fromString(String? raw) {
    final norm = (raw ?? '').trim().toUpperCase();
    return switch (norm) {
      'TAKEAWAY' || 'EMPORTER' => ServiceMode.takeaway,
      'DELIVERY' || 'LIVRAISON' => ServiceMode.delivery,
      _ => ServiceMode.dineIn,
    };
  }
}

class DeliveryZone {
  final String id;
  final String nameFr;
  final String nameAr;
  final String nameEn;
  final double feeMru;

  const DeliveryZone({
    required this.id,
    required this.nameFr,
    required this.nameAr,
    required this.nameEn,
    required this.feeMru,
  });

  static const double freeDeliveryAboveMru = 1500.0;

  static const List<DeliveryZone> nouakchottPresets = [
    DeliveryZone(
      id: 'zone-centre',
      nameFr: 'Centre / Ilot K',
      nameAr: 'المركز / إيلو ك',
      nameEn: 'Center / Ilot K',
      feeMru: 100,
    ),
    DeliveryZone(
      id: 'zone-tz',
      nameFr: 'Tevragh Zeina',
      nameAr: 'تفرغ زينة',
      nameEn: 'Tevragh Zeina',
      feeMru: 100,
    ),
    DeliveryZone(
      id: 'zone-ksar',
      nameFr: 'Ksar / Socogim',
      nameAr: 'لكصر / سوكوجيم',
      nameEn: 'Ksar / Socogim',
      feeMru: 150,
    ),
    DeliveryZone(
      id: 'zone-arafat',
      nameFr: 'Arafat / Dar Naim',
      nameAr: 'عرفات / دار النعيم',
      nameEn: 'Arafat / Dar Naim',
      feeMru: 150,
    ),
  ];

  String label(String lang) =>
      lang == 'ar' ? nameAr : (lang == 'en' ? nameEn : nameFr);

  double effectiveFeeFor(
    double subtotal, {
    double freeAboveMru = freeDeliveryAboveMru,
  }) {
    if (subtotal <= 0) return 0;
    if (freeAboveMru > 0 && subtotal >= freeAboveMru) return 0;
    return feeMru;
  }

  factory DeliveryZone.fromJson(Map<String, dynamic> json) {
    final nameFr = '${json['nameFr'] ?? json['name_fr'] ?? json['name'] ?? ''}';
    return DeliveryZone(
      id: '${json['id'] ?? ''}',
      nameFr: nameFr,
      nameAr: '${json['nameAr'] ?? json['name_ar'] ?? nameFr}',
      nameEn: '${json['nameEn'] ?? json['name_en'] ?? nameFr}',
      feeMru: ((json['feeMru'] ?? json['fee_mru'] ?? 0) as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nameFr': nameFr,
        'nameAr': nameAr,
        'nameEn': nameEn,
        'feeMru': feeMru,
      };
}

class ModifierOption {
  final String id;
  final String nameFr;
  final String nameAr;
  final String nameEn;
  final double extraPriceMru;
  final String bomKey;

  const ModifierOption({
    required this.id,
    required this.nameFr,
    required this.nameAr,
    required this.nameEn,
    this.extraPriceMru = 0,
    this.bomKey = '',
  });

  String label(String lang) =>
      lang == 'ar' ? nameAr : (lang == 'en' ? nameEn : nameFr);

  factory ModifierOption.fromJson(Map<String, dynamic> json) {
    final nameFr = '${json['nameFr'] ?? json['name_fr'] ?? json['name'] ?? ''}';
    return ModifierOption(
      id: '${json['id'] ?? ''}',
      nameFr: nameFr,
      nameAr: '${json['nameAr'] ?? json['name_ar'] ?? nameFr}',
      nameEn: '${json['nameEn'] ?? json['name_en'] ?? nameFr}',
      extraPriceMru:
          ((json['extraPriceMru'] ?? json['extra_price_mru'] ?? 0) as num)
              .toDouble(),
      bomKey: '${json['bomKey'] ?? json['bom_key'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nameFr': nameFr,
        'nameAr': nameAr,
        'nameEn': nameEn,
        'extraPriceMru': extraPriceMru,
        'bomKey': bomKey,
      };
}

class ModifierGroup {
  final String id;
  final String nameFr;
  final String nameAr;
  final String nameEn;
  final bool required;
  final bool multiSelect;
  final List<ModifierOption> options;

  const ModifierGroup({
    required this.id,
    required this.nameFr,
    required this.nameAr,
    required this.nameEn,
    this.required = false,
    this.multiSelect = false,
    this.options = const [],
  });

  String label(String lang) =>
      lang == 'ar' ? nameAr : (lang == 'en' ? nameEn : nameFr);

  factory ModifierGroup.fromJson(Map<String, dynamic> json) {
    final nameFr = '${json['nameFr'] ?? json['name_fr'] ?? json['name'] ?? ''}';
    final rawOpts = json['options'] as List? ?? const [];
    return ModifierGroup(
      id: '${json['id'] ?? ''}',
      nameFr: nameFr,
      nameAr: '${json['nameAr'] ?? json['name_ar'] ?? nameFr}',
      nameEn: '${json['nameEn'] ?? json['name_en'] ?? nameFr}',
      required: json['required'] == true || json['required'] == 1,
      multiSelect: (json['multiSelect'] ?? json['multi_select']) == true ||
          (json['multiSelect'] ?? json['multi_select']) == 1,
      options: rawOpts
          .whereType<Map>()
          .map((o) => ModifierOption.fromJson(o.cast<String, dynamic>()))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nameFr': nameFr,
        'nameAr': nameAr,
        'nameEn': nameEn,
        'required': required,
        'multiSelect': multiSelect,
        'options': options.map((o) => o.toJson()).toList(),
      };
}

class SelectedModifier {
  final String groupId;
  final String groupNameFr;
  final String groupNameAr;
  final String groupNameEn;
  final String optionId;
  final String nameFr;
  final String nameAr;
  final String nameEn;
  final double extraPriceMru;
  final String bomKey;

  const SelectedModifier({
    required this.groupId,
    this.groupNameFr = '',
    this.groupNameAr = '',
    this.groupNameEn = '',
    required this.optionId,
    required this.nameFr,
    this.nameAr = '',
    this.nameEn = '',
    this.extraPriceMru = 0,
    this.bomKey = '',
  });

  factory SelectedModifier.fromOption({
    required ModifierGroup group,
    required ModifierOption option,
  }) {
    return SelectedModifier(
      groupId: group.id,
      groupNameFr: group.nameFr,
      groupNameAr: group.nameAr,
      groupNameEn: group.nameEn,
      optionId: option.id,
      nameFr: option.nameFr,
      nameAr: option.nameAr,
      nameEn: option.nameEn,
      extraPriceMru: option.extraPriceMru,
      bomKey: option.bomKey,
    );
  }

  String label(String lang) {
    if (lang == 'ar' && nameAr.isNotEmpty) return nameAr;
    if (lang == 'en' && nameEn.isNotEmpty) return nameEn;
    return nameFr;
  }

  factory SelectedModifier.fromJson(Map<String, dynamic> json) {
    final nameFr = '${json['nameFr'] ?? json['name_fr'] ?? ''}';
    return SelectedModifier(
      groupId: '${json['groupId'] ?? json['group_id'] ?? ''}',
      groupNameFr: '${json['groupNameFr'] ?? json['group_name_fr'] ?? ''}',
      groupNameAr: '${json['groupNameAr'] ?? json['group_name_ar'] ?? ''}',
      groupNameEn: '${json['groupNameEn'] ?? json['group_name_en'] ?? ''}',
      optionId: '${json['optionId'] ?? json['option_id'] ?? ''}',
      nameFr: nameFr,
      nameAr: '${json['nameAr'] ?? json['name_ar'] ?? nameFr}',
      nameEn: '${json['nameEn'] ?? json['name_en'] ?? nameFr}',
      extraPriceMru:
          ((json['extraPriceMru'] ?? json['extra_price_mru'] ?? 0) as num)
              .toDouble(),
      bomKey: '${json['bomKey'] ?? json['bom_key'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'groupNameFr': groupNameFr,
        'groupNameAr': groupNameAr,
        'groupNameEn': groupNameEn,
        'optionId': optionId,
        'nameFr': nameFr,
        'nameAr': nameAr,
        'nameEn': nameEn,
        'extraPriceMru': extraPriceMru,
        'bomKey': bomKey,
      };

  @override
  bool operator ==(Object other) {
    return other is SelectedModifier &&
        other.groupId == groupId &&
        other.optionId == optionId &&
        other.extraPriceMru == extraPriceMru &&
        other.bomKey == bomKey;
  }

  @override
  int get hashCode => Object.hash(groupId, optionId, extraPriceMru, bomKey);
}

class MenuCategory {
  final String id;
  final String nameFr;
  final String nameAr;
  final String nameEn;
  final String icon;
  final String imageUrl;
  final int sortOrder;
  final bool active;

  const MenuCategory({
    required this.id,
    required this.nameFr,
    required this.nameAr,
    required this.nameEn,
    required this.icon,
    this.imageUrl = '',
    this.sortOrder = 0,
    this.active = true,
  });

  String label(String lang) =>
      lang == 'ar' ? nameAr : (lang == 'en' ? nameEn : nameFr);
}

class MenuItem {
  final String id;
  final String categoryId;
  final String sku;
  final String nameFr;
  final String nameAr;
  final String nameEn;
  final double priceMru;
  final String kitchenStation; // KITCHEN | GRILL | BAR | POULET | PIZZA | SNACK | TRADITIONAL
  final bool available;
  final String icon;
  final String imageUrl;
  final bool manualPrice;
  final bool isTop;
  final List<ModifierGroup> modifiers;

  const MenuItem({
    required this.id,
    required this.categoryId,
    required this.sku,
    required this.nameFr,
    required this.nameAr,
    required this.nameEn,
    required this.priceMru,
    this.kitchenStation = 'KITCHEN',
    this.available = true,
    this.icon = '🍽',
    this.imageUrl = '',
    this.manualPrice = false,
    this.isTop = false,
    this.modifiers = const [],
  });

  bool get isOutOfStock => !available;
  bool get hasModifiers => modifiers.isNotEmpty;

  String label(String lang) =>
      lang == 'ar' ? nameAr : (lang == 'en' ? nameEn : nameFr);

  MenuItem copyWith({
    String? categoryId,
    String? sku,
    String? nameFr,
    String? nameAr,
    String? nameEn,
    double? priceMru,
    String? kitchenStation,
    bool? available,
    bool? isOutOfStock,
    String? icon,
    String? imageUrl,
    bool? manualPrice,
    bool? isTop,
    List<ModifierGroup>? modifiers,
  }) {
    final nextAvailable =
        isOutOfStock != null ? !isOutOfStock : (available ?? this.available);
    return MenuItem(
      id: id,
      categoryId: categoryId ?? this.categoryId,
      sku: sku ?? this.sku,
      nameFr: nameFr ?? this.nameFr,
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      priceMru: priceMru ?? this.priceMru,
      kitchenStation: kitchenStation ?? this.kitchenStation,
      available: nextAvailable,
      icon: icon ?? this.icon,
      imageUrl: imageUrl ?? this.imageUrl,
      manualPrice: manualPrice ?? this.manualPrice,
      isTop: isTop ?? this.isTop,
      modifiers: modifiers ?? this.modifiers,
    );
  }
}

// Keep exactly 4 statuses so untouched lib/screens/floor_plan_view.dart switches stay exhaustive.
enum TableStatus { free, occupied, reserved, billRequested }

enum TableShape {
  round,
  square,
  khaima;

  static TableShape fromString(String? raw) {
    return switch ((raw ?? '').trim().toLowerCase()) {
      'round' || 'circle' => TableShape.round,
      'khaima' || 'vip' => TableShape.khaima,
      _ => TableShape.square,
    };
  }
}

class DiningZone {
  final String id;
  final String nameFr;
  final String nameAr;
  final String nameEn;
  final bool isVip;
  final String zoneType;
  final double minSpendMru;

  const DiningZone({
    required this.id,
    required this.nameFr,
    required this.nameAr,
    required this.nameEn,
    this.isVip = false,
    this.zoneType = 'SALLE',
    this.minSpendMru = 0,
  });

  String label(String lang) =>
      lang == 'ar' ? nameAr : (lang == 'en' ? nameEn : nameFr);
}

class DiningTable {
  final String id;
  final String zoneId;
  final String code;
  final int capacity;
  final TableStatus status;
  final int guests;
  final String? activeOrderId;
  final DateTime? occupiedSince;
  final TableShape shape;
  final double x;
  final double y;
  final String? serverName;
  final bool waitAlert;
  final double minSpendMru;
  final double arbounMru;

  const DiningTable({
    required this.id,
    required this.zoneId,
    required this.code,
    int? capacity,
    int? seats,
    this.status = TableStatus.free,
    this.guests = 0,
    this.activeOrderId,
    DateTime? occupiedSince,
    DateTime? openedAt,
    this.shape = TableShape.square,
    this.x = 0.0,
    this.y = 0.0,
    this.serverName,
    this.waitAlert = false,
    this.minSpendMru = 0,
    this.arbounMru = 0,
  })  : capacity = seats ?? capacity ?? 4,
        occupiedSince = openedAt ?? occupiedSince;

  int get seats => capacity;
  DateTime? get openedAt => occupiedSince;

  bool isWaiting([DateTime? now]) {
    if (status != TableStatus.occupied) return false;
    if (waitAlert) return true;
    if (occupiedSince == null) return false;
    return (now ?? DateTime.now()).difference(occupiedSince!).inMinutes >= 20;
  }

  bool get isWaitingAlert => isWaiting();

  DiningTable copyWith({
    String? zoneId,
    String? code,
    int? capacity,
    int? seats,
    TableStatus? status,
    int? guests,
    String? activeOrderId,
    bool clearOrder = false,
    DateTime? occupiedSince,
    bool clearOccupied = false,
    TableShape? shape,
    double? x,
    double? y,
    String? serverName,
    bool clearServer = false,
    bool? waitAlert,
    double? minSpendMru,
    double? arbounMru,
  }) {
    return DiningTable(
      id: id,
      zoneId: zoneId ?? this.zoneId,
      code: code ?? this.code,
      capacity: seats ?? capacity ?? this.capacity,
      status: status ?? this.status,
      guests: guests ?? this.guests,
      activeOrderId: clearOrder ? null : (activeOrderId ?? this.activeOrderId),
      occupiedSince:
          clearOccupied ? null : (occupiedSince ?? this.occupiedSince),
      shape: shape ?? this.shape,
      x: x ?? this.x,
      y: y ?? this.y,
      serverName: clearServer ? null : (serverName ?? this.serverName),
      waitAlert: waitAlert ?? this.waitAlert,
      minSpendMru: minSpendMru ?? this.minSpendMru,
      arbounMru: arbounMru ?? this.arbounMru,
    );
  }
}

class VipReservation {
  final String id;
  final String customerName;
  final String phone;
  final String zoneId;
  final String tableId;
  final int guests;
  final String timeSlot;
  final double arbounMru;
  final String status; // confirmed | seated | cancelled
  final String? note;

  const VipReservation({
    required this.id,
    required this.customerName,
    required this.phone,
    required this.zoneId,
    required this.tableId,
    required this.guests,
    required this.timeSlot,
    required this.arbounMru,
    this.status = 'confirmed',
    this.note,
  });

  VipReservation copyWith({String? status}) {
    return VipReservation(
      id: id,
      customerName: customerName,
      phone: phone,
      zoneId: zoneId,
      tableId: tableId,
      guests: guests,
      timeSlot: timeSlot,
      arbounMru: arbounMru,
      status: status ?? this.status,
      note: note,
    );
  }
}

class OrderItem {
  final String lineId;
  final MenuItem item;
  final int quantity;
  final String? kitchenNote;
  final bool sentToKitchen;
  final bool isComp;
  final bool isTakeaway;
  final List<SelectedModifier> selectedModifiers;

  const OrderItem({
    required this.lineId,
    required this.item,
    required this.quantity,
    this.kitchenNote,
    this.sentToKitchen = false,
    this.isComp = false,
    this.isTakeaway = false,
    this.selectedModifiers = const [],
  });

  double get modifiersTotalMru =>
      selectedModifiers.fold(0.0, (s, m) => s + m.extraPriceMru);

  double get unitPriceWithModifiers => item.priceMru + modifiersTotalMru;

  double get lineTotal => isComp ? 0 : unitPriceWithModifiers * quantity;

  OrderItem copyWith({
    int? quantity,
    String? kitchenNote,
    bool? sentToKitchen,
    bool? isComp,
    bool? isTakeaway,
    List<SelectedModifier>? selectedModifiers,
  }) {
    return OrderItem(
      lineId: lineId,
      item: item,
      quantity: quantity ?? this.quantity,
      kitchenNote: kitchenNote ?? this.kitchenNote,
      sentToKitchen: sentToKitchen ?? this.sentToKitchen,
      isComp: isComp ?? this.isComp,
      isTakeaway: isTakeaway ?? this.isTakeaway,
      selectedModifiers: selectedModifiers ?? this.selectedModifiers,
    );
  }

  Map<String, dynamic> toSyncJson() {
    final modsJson = selectedModifiers.map((m) => m.toJson()).toList();
    return {
      'product_id': item.id,
      'sku': item.sku,
      'name': item.nameFr,
      'qty': quantity,
      'base_price': item.priceMru,
      'modifiers_total_mru': modifiersTotalMru,
      'unit_price': unitPriceWithModifiers,
      'line_total': lineTotal,
      'is_comp': isComp,
      'is_takeaway': isTakeaway,
      'kitchen_station': item.kitchenStation,
      if (kitchenNote != null && kitchenNote!.isNotEmpty)
        'kitchen_note': kitchenNote,
      'modifiers': modsJson,
      'modifiers_json': jsonEncode(modsJson),
    };
  }
}

enum PaymentMethod {
  cash,
  bankily,
  masrivi,
  sedad,
  bimbank,
  click,
  otherWallet,
  karni;

  static PaymentMethod fromString(String? raw) {
    final norm = (raw ?? '').trim().toUpperCase();
    return switch (norm) {
      'CASH' || 'ESPECES' || 'ESPÈCES' || '' => PaymentMethod.cash,
      'BANKILY' => PaymentMethod.bankily,
      'MASRIVI' || 'MASRVI' => PaymentMethod.masrivi,
      'SEDAD' => PaymentMethod.sedad,
      'BIMBANK' || 'BIM-BANK' => PaymentMethod.bimbank,
      'CLICK' => PaymentMethod.click,
      'KARNI' || 'CREDIT' || 'CRÉDIT' => PaymentMethod.karni,
      _ => PaymentMethod.otherWallet,
    };
  }
}

/// Official catalog of Mauritanian electronic wallets + helpers for custom wallets.
class MauritanianWallets {
  static const List<String> official16 = [
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
  ];

  static const Map<String, String> arabicNames = {
    'Bankily': 'بنكيلي',
    'Masrvi': 'مصرفي',
    'Masrivi': 'مصرفي',
    'Sedad': 'سداد',
    'BIM-Bank': 'بيم بنك',
    'Bimbank': 'بيم بنك',
    'BCI-Pay': 'بي سي آي باي',
    'Click': 'كليك',
    'Amanty': 'أمانتي',
    'BAMIS Digital': 'باميس ديجيتال',
    'Moov Money': 'موف موني',
    'GazaPay': 'غازا باي',
    'Mattel Money': 'ماتيل موني',
    'BaridCash': 'بريد كاش',
    'Rassidy': 'رصيدي',
    'Chinguitty Mobile': 'شنقيطي موبايل',
    'Cashily': 'كاشيلي',
    'Attijari ePAY': 'التجاري إي باي',
  };

  static String canonicalName(String raw) {
    final clean = raw.trim();
    final low = clean.toLowerCase();
    if (low == 'masrivi' || low == 'masrvi') return 'Masrvi';
    if (low == 'bimbank' || low == 'bim-bank') return 'BIM-Bank';
    for (final w in official16) {
      if (w.toLowerCase() == low) return w;
    }
    return clean;
  }

  static PaymentMethod methodForWallet(String raw) {
    final low = raw.trim().toLowerCase();
    return switch (low) {
      'cash' || 'especes' || 'espèces' => PaymentMethod.cash,
      'bankily' => PaymentMethod.bankily,
      'masrvi' || 'masrivi' => PaymentMethod.masrivi,
      'sedad' => PaymentMethod.sedad,
      'bim-bank' || 'bimbank' => PaymentMethod.bimbank,
      'click' => PaymentMethod.click,
      'karni' => PaymentMethod.karni,
      _ => PaymentMethod.otherWallet,
    };
  }
}

class PaymentEntry {
  final PaymentMethod method;
  final double amountMru;
  final String? reference;
  final String? karniCustomerId;
  final String? walletLabel;

  const PaymentEntry({
    required this.method,
    required this.amountMru,
    this.reference,
    this.karniCustomerId,
    this.walletLabel,
  });

  String get displayLabel {
    if (walletLabel != null && walletLabel!.trim().isNotEmpty) {
      return walletLabel!.trim();
    }
    return switch (method) {
      PaymentMethod.cash => 'Cash',
      PaymentMethod.bankily => 'Bankily',
      PaymentMethod.masrivi => 'Masrvi',
      PaymentMethod.sedad => 'Sedad',
      PaymentMethod.bimbank => 'BIM-Bank',
      PaymentMethod.click => 'Click',
      PaymentMethod.otherWallet => 'Portefeuille',
      PaymentMethod.karni => 'Karni',
    };
  }

  Map<String, dynamic> toJson() => {
        'method': (method == PaymentMethod.otherWallet &&
                walletLabel != null &&
                walletLabel!.trim().isNotEmpty)
            ? walletLabel!.trim()
            : method.name.toUpperCase(),
        if (walletLabel != null && walletLabel!.trim().isNotEmpty)
          'wallet_label': walletLabel!.trim(),
        'amount_mru': amountMru,
        if (reference != null && reference!.isNotEmpty) 'reference': reference,
        if (karniCustomerId != null) 'karni_customer_id': karniCustomerId,
      };
}

class PosOrder {
  final String id;
  final String ticketNumber;
  final String? tableId;
  final String? tableCode;
  final String staffName;
  final String? serverName;
  final String? cashierName;
  final List<OrderItem> items;
  final double discountPercent;
  final double arbounDepositMru;
  final List<PaymentEntry> payments;
  final String status; // open | paid | voided
  final DateTime createdAt;
  final DateTime? paidAt;
  final ServiceMode serviceMode;
  final DeliveryZone? deliveryZone;
  final double deliveryFeeMru;
  final String? customerName;
  final String? customerPhone;
  final String? deliveryAddress;
  final String? deliveryDriverName;
  final String? orderComment;
  final bool isTraining;
  final int? takeawayNumber;

  const PosOrder({
    required this.id,
    required this.ticketNumber,
    this.tableId,
    this.tableCode,
    required this.staffName,
    this.serverName,
    this.cashierName,
    required this.items,
    this.discountPercent = 0,
    this.arbounDepositMru = 0,
    this.payments = const [],
    this.status = 'open',
    required this.createdAt,
    this.paidAt,
    this.serviceMode = ServiceMode.dineIn,
    this.deliveryZone,
    this.deliveryFeeMru = 0,
    this.customerName,
    this.customerPhone,
    this.deliveryAddress,
    this.deliveryDriverName,
    this.orderComment,
    this.isTraining = false,
    this.takeawayNumber,
  });

  double get subtotal => items.fold(0.0, (s, e) => s + e.lineTotal);
  double get discountAmount => subtotal * (discountPercent / 100.0);

  /// Full TTC consumption value before deducting any prior Arboun deposit.
  double get grossTotal {
    if (items.isEmpty) return 0;
    final v = subtotal - discountAmount + deliveryFeeMru;
    return v < 0 ? 0 : v;
  }

  /// Remaining balance due at checkout after Arboun deposit deduction.
  double get netTotal {
    if (items.isEmpty) return 0;
    final v = grossTotal - arbounDepositMru;
    return v < 0 ? 0 : v;
  }

  /// Mauritanian TTC inclusive VAT 16% on full consumption: round(TTC * 16 / 116)
  int get tvaAmountMru => grossTotal <= 0 ? 0 : (grossTotal * 16 / 116).round();

  double get subtotalHtMru => grossTotal - tvaAmountMru;

  double get totalPaid => payments.fold(0.0, (s, p) => s + p.amountMru);
  double get changeDue => totalPaid > netTotal ? totalPaid - netTotal : 0;

  PosOrder copyWith({
    String? ticketNumber,
    String? tableId,
    bool clearTable = false,
    String? tableCode,
    String? serverName,
    String? cashierName,
    List<OrderItem>? items,
    double? discountPercent,
    double? arbounDepositMru,
    List<PaymentEntry>? payments,
    String? status,
    DateTime? paidAt,
    ServiceMode? serviceMode,
    DeliveryZone? deliveryZone,
    bool clearDeliveryZone = false,
    double? deliveryFeeMru,
    String? customerName,
    String? customerPhone,
    String? deliveryAddress,
    String? deliveryDriverName,
    bool clearDeliveryDriver = false,
    String? orderComment,
    bool clearOrderComment = false,
    bool? isTraining,
    int? takeawayNumber,
  }) {
    return PosOrder(
      id: id,
      ticketNumber: ticketNumber ?? this.ticketNumber,
      tableId: clearTable ? null : (tableId ?? this.tableId),
      tableCode: clearTable ? null : (tableCode ?? this.tableCode),
      staffName: staffName,
      serverName: serverName ?? this.serverName,
      cashierName: cashierName ?? this.cashierName,
      items: items ?? this.items,
      discountPercent: discountPercent ?? this.discountPercent,
      arbounDepositMru: arbounDepositMru ?? this.arbounDepositMru,
      payments: payments ?? this.payments,
      status: status ?? this.status,
      createdAt: createdAt,
      paidAt: paidAt ?? this.paidAt,
      serviceMode: serviceMode ?? this.serviceMode,
      deliveryZone:
          clearDeliveryZone ? null : (deliveryZone ?? this.deliveryZone),
      deliveryFeeMru: deliveryFeeMru ?? this.deliveryFeeMru,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryDriverName: clearDeliveryDriver
          ? null
          : (deliveryDriverName ?? this.deliveryDriverName),
      orderComment:
          clearOrderComment ? null : (orderComment ?? this.orderComment),
      isTraining: isTraining ?? this.isTraining,
      takeawayNumber: takeawayNumber ?? this.takeawayNumber,
    );
  }

  Map<String, dynamic> toSyncJson() {
    final paymentsList = payments.map((p) => p.toJson()).toList();
    return {
      'id': id,
      'ticket_number': ticketNumber,
      'table_code': tableCode ?? 'COMPTOIR',
      'staff_name': staffName,
      'service_mode': serviceMode.apiValue,
      'channel': serviceMode.apiValue,
      if (deliveryZone != null) 'delivery_zone': deliveryZone!.nameFr,
      if (deliveryZone != null) 'delivery_zone_id': deliveryZone!.id,
      'delivery_fee_mru': deliveryFeeMru,
      if (customerName != null) 'customer_name': customerName,
      if (customerPhone != null) 'customer_phone': customerPhone,
      if (deliveryAddress != null) 'delivery_address': deliveryAddress,
      if (deliveryDriverName != null && deliveryDriverName!.isNotEmpty)
        'delivery_driver': deliveryDriverName,
      if (orderComment != null && orderComment!.trim().isNotEmpty)
        'notes': orderComment!.trim(),
      if (takeawayNumber != null) 'takeaway_number': takeawayNumber,
      'is_training': isTraining,
      'subtotal_mru': subtotal,
      'subtotal_ht_mru': subtotalHtMru,
      'tva_mru': tvaAmountMru,
      'discount_percent': discountPercent,
      'arboun_mru': arbounDepositMru,
      'total_mru': netTotal,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'paid_at': paidAt?.toIso8601String(),
      'items': items.map((i) => i.toSyncJson()).toList(),
      'payments': paymentsList,
      'payments_json': paymentsList,
    };
  }
}

class KarniCustomer {
  final String id;
  final String name;
  final String phone;
  final double creditLimitMru;
  final double balanceDueMru;
  final DateTime lastActivity;

  const KarniCustomer({
    required this.id,
    required this.name,
    required this.phone,
    required this.creditLimitMru,
    required this.balanceDueMru,
    required this.lastActivity,
  });

  KarniCustomer copyWith({double? balanceDueMru, DateTime? lastActivity}) {
    return KarniCustomer(
      id: id,
      name: name,
      phone: phone,
      creditLimitMru: creditLimitMru,
      balanceDueMru: balanceDueMru ?? this.balanceDueMru,
      lastActivity: lastActivity ?? this.lastActivity,
    );
  }
}

class ReturnRemakeCompRecord {
  final String id;
  final String type; // remake | return | comp
  final String orderTicket;
  final String itemName;
  final int quantity;
  final double amountMru;
  final String reason;
  final String staffName;
  final String? approvedBy;
  final DateTime createdAt;

  const ReturnRemakeCompRecord({
    required this.id,
    required this.type,
    required this.orderTicket,
    required this.itemName,
    required this.quantity,
    required this.amountMru,
    required this.reason,
    required this.staffName,
    this.approvedBy,
    required this.createdAt,
  });
}

class CashClosingZ {
  final String id;
  final DateTime closedAt;
  final String cashierName;
  final double countedCashMru;
  final double expectedCashMru;
  final double countedBankilyMru;
  final double expectedBankilyMru;
  final double countedMasriviMru;
  final double expectedMasriviMru;
  final double countedSedadMru;
  final double expectedSedadMru;
  final double countedBimbankMru;
  final double expectedBimbankMru;
  final double countedClickMru;
  final double expectedClickMru;
  final Map<String, double> otherWalletsCounted;
  final Map<String, double> otherWalletsExpected;
  final double karniIssuedMru;
  final int ordersCount;
  final int remakesCount;

  const CashClosingZ({
    required this.id,
    required this.closedAt,
    required this.cashierName,
    required this.countedCashMru,
    required this.expectedCashMru,
    required this.countedBankilyMru,
    required this.expectedBankilyMru,
    required this.countedMasriviMru,
    required this.expectedMasriviMru,
    required this.countedSedadMru,
    required this.expectedSedadMru,
    this.countedBimbankMru = 0,
    this.expectedBimbankMru = 0,
    this.countedClickMru = 0,
    this.expectedClickMru = 0,
    this.otherWalletsCounted = const {},
    this.otherWalletsExpected = const {},
    required this.karniIssuedMru,
    required this.ordersCount,
    required this.remakesCount,
  });

  double get cashVarianceMru => countedCashMru - expectedCashMru;

  double get expectedOtherWalletsMru =>
      otherWalletsExpected.values.fold(0.0, (s, v) => s + v);

  double get countedOtherWalletsMru =>
      otherWalletsCounted.values.fold(0.0, (s, v) => s + v);

  double get totalExpectedMru =>
      expectedCashMru +
      expectedBankilyMru +
      expectedMasriviMru +
      expectedSedadMru +
      expectedBimbankMru +
      expectedClickMru +
      expectedOtherWalletsMru +
      karniIssuedMru;

  Map<String, dynamic> toSyncJson() => {
        'id': id,
        'closed_at': closedAt.toIso8601String(),
        'cashier_name': cashierName,
        'counted_cash_mru': countedCashMru,
        'expected_cash_mru': expectedCashMru,
        'cash_variance_mru': cashVarianceMru,
        'counted_bankily_mru': countedBankilyMru,
        'expected_bankily_mru': expectedBankilyMru,
        'counted_masrivi_mru': countedMasriviMru,
        'expected_masrivi_mru': expectedMasriviMru,
        'counted_sedad_mru': countedSedadMru,
        'expected_sedad_mru': expectedSedadMru,
        'counted_bimbank_mru': countedBimbankMru,
        'expected_bimbank_mru': expectedBimbankMru,
        'counted_click_mru': countedClickMru,
        'expected_click_mru': expectedClickMru,
        'counted_other_wallets_mru': countedOtherWalletsMru,
        'expected_other_wallets_mru': expectedOtherWalletsMru,
        if (otherWalletsCounted.isNotEmpty)
          'other_wallets_counted': otherWalletsCounted,
        if (otherWalletsExpected.isNotEmpty)
          'other_wallets_expected': otherWalletsExpected,
        'karni_issued_mru': karniIssuedMru,
        'total_expected_mru': totalExpectedMru,
        'orders_count': ordersCount,
        'remakes_count': remakesCount,
      };
}

class SyncQueueItem {
  final String id;
  final String entityType; // order | closing_z | karni | remake | reservation | stock_86 | kds_ready
  final String summary;
  final Map<String, dynamic> payload;
  final String status; // pending | synced | error
  final DateTime createdAt;
  final DateTime? syncedAt;

  const SyncQueueItem({
    required this.id,
    required this.entityType,
    required this.summary,
    required this.payload,
    this.status = 'pending',
    required this.createdAt,
    this.syncedAt,
  });

  SyncQueueItem copyWith({String? status, DateTime? syncedAt}) {
    return SyncQueueItem(
      id: id,
      entityType: entityType,
      summary: summary,
      payload: payload,
      status: status ?? this.status,
      createdAt: createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }
}

class OfflineLicenseInfo {
  final String tenantName;
  final String code12;
  final DateTime expiresAt;
  final bool ed25519Verified;

  const OfflineLicenseInfo({
    required this.tenantName,
    required this.code12,
    required this.expiresAt,
    required this.ed25519Verified,
  });

  int get daysRemaining {
    final diff = expiresAt.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }
}

enum KdsStationFilter {
  all,
  grill,
  kitchen,
  bar,
  poulet,
  pizza,
  snack,
  traditional;

  bool matchesStation(String station) {
    if (this == KdsStationFilter.all) return true;
    return station.trim().toUpperCase() == name.toUpperCase();
  }
}

enum KdsUrgency { green, orange, red }

class KdsTicketItem {
  final String lineId;
  final String productId;
  final String sku;
  final String nameFr;
  final String nameAr;
  final String nameEn;
  final int quantity;
  final String kitchenStation;
  final List<SelectedModifier> selectedModifiers;
  final String? kitchenNote;
  final bool ready;

  const KdsTicketItem({
    required this.lineId,
    required this.productId,
    required this.sku,
    required this.nameFr,
    required this.nameAr,
    required this.nameEn,
    required this.quantity,
    required this.kitchenStation,
    this.selectedModifiers = const [],
    this.kitchenNote,
    this.ready = false,
  });

  String label(String lang) =>
      lang == 'ar' ? nameAr : (lang == 'en' ? nameEn : nameFr);

  KdsTicketItem copyWith({bool? ready}) {
    return KdsTicketItem(
      lineId: lineId,
      productId: productId,
      sku: sku,
      nameFr: nameFr,
      nameAr: nameAr,
      nameEn: nameEn,
      quantity: quantity,
      kitchenStation: kitchenStation,
      selectedModifiers: selectedModifiers,
      kitchenNote: kitchenNote,
      ready: ready ?? this.ready,
    );
  }
}

class KdsTicket {
  final String id;
  final String orderId;
  final String orderCode;
  final String tableOrTargetLabel;
  final String? tableCode;
  final ServiceMode serviceMode;
  final String? deliveryZoneName;
  final int? takeawayNumber;
  final String staffName;
  final String? orderComment;
  final bool isTraining;
  final DateTime sentAt;
  final DateTime? readyAt;
  final List<KdsTicketItem> items;
  final String status; // preparing | ready

  KdsTicket({
    required this.id,
    this.orderId = '',
    String? orderCode,
    String? ticketNumber,
    String? tableOrTargetLabel,
    this.tableCode,
    this.serviceMode = ServiceMode.dineIn,
    this.deliveryZoneName,
    this.takeawayNumber,
    this.staffName = '',
    this.orderComment,
    this.isTraining = false,
    DateTime? sentAt,
    DateTime? createdAt,
    this.readyAt,
    required this.items,
    this.status = 'preparing',
  })  : orderCode = orderCode ?? ticketNumber ?? id,
        tableOrTargetLabel = tableOrTargetLabel ??
            tableCode ??
            (serviceMode == ServiceMode.takeaway
                ? 'Emporter${takeawayNumber != null ? ' N°$takeawayNumber' : ''}'
                : (serviceMode == ServiceMode.delivery
                    ? 'Livraison${deliveryZoneName != null ? ' · $deliveryZoneName' : ''}'
                    : 'Comptoir')),
        sentAt = sentAt ?? createdAt ?? DateTime.now();

  String get ticketNumber => orderCode;
  DateTime get createdAt => sentAt;

  Duration elapsed({DateTime? now}) {
    final diff = (now ?? DateTime.now()).difference(sentAt);
    return diff.isNegative ? Duration.zero : diff;
  }

  int elapsedMinutes({DateTime? now}) => elapsed(now: now).inMinutes;

  KdsUrgency urgency({DateTime? now}) {
    final secs = elapsed(now: now).inSeconds;
    if (secs < 600) return KdsUrgency.green;
    if (secs <= 1200) return KdsUrgency.orange;
    return KdsUrgency.red;
  }

  String formattedElapsed({DateTime? now}) {
    final d = elapsed(now: now);
    final mins = d.inMinutes.toString().padLeft(2, '0');
    final secs = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  bool hasPendingForStation(KdsStationFilter filter) {
    if (status == 'ready') return false;
    if (filter == KdsStationFilter.all) {
      return items.any((i) => !i.ready);
    }
    return items.any((i) => !i.ready && filter.matchesStation(i.kitchenStation));
  }

  List<KdsTicketItem> itemsForFilter(KdsStationFilter filter) {
    if (filter == KdsStationFilter.all) return items;
    return items
        .where((i) => filter.matchesStation(i.kitchenStation))
        .toList(growable: false);
  }

  KdsTicket copyWith({
    List<KdsTicketItem>? items,
    String? status,
    DateTime? readyAt,
  }) {
    return KdsTicket(
      id: id,
      orderId: orderId,
      orderCode: orderCode,
      tableOrTargetLabel: tableOrTargetLabel,
      tableCode: tableCode,
      serviceMode: serviceMode,
      deliveryZoneName: deliveryZoneName,
      takeawayNumber: takeawayNumber,
      staffName: staffName,
      orderComment: orderComment,
      isTraining: isTraining,
      sentAt: sentAt,
      readyAt: readyAt ?? this.readyAt,
      items: items ?? this.items,
      status: status ?? this.status,
    );
  }
}

class Ingredient {
  final String id;
  final String sku;
  final String nameFr;
  final String nameAr;
  final String nameEn;
  final String unit;
  final double pmpCostMru;
  final double currentStock;
  final double minStock;

  const Ingredient({
    required this.id,
    required this.sku,
    required this.nameFr,
    required this.nameAr,
    this.nameEn = '',
    required this.unit,
    required this.pmpCostMru,
    required this.currentStock,
    required this.minStock,
  });

  bool get isLowStock => currentStock <= minStock;

  String label(String lang) {
    if (lang == 'ar' && nameAr.isNotEmpty) return nameAr;
    if (lang == 'en' && nameEn.isNotEmpty) return nameEn;
    return nameFr;
  }

  Ingredient copyWith({
    double? currentStock,
    double? minStock,
    double? pmpCostMru,
  }) {
    return Ingredient(
      id: id,
      sku: sku,
      nameFr: nameFr,
      nameAr: nameAr,
      nameEn: nameEn,
      unit: unit,
      pmpCostMru: pmpCostMru ?? this.pmpCostMru,
      currentStock: currentStock ?? this.currentStock,
      minStock: minStock ?? this.minStock,
    );
  }

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    final nameFr = '${json['nameFr'] ?? json['name_fr'] ?? ''}';
    return Ingredient(
      id: '${json['id'] ?? json['sku'] ?? ''}',
      sku: '${json['sku'] ?? ''}',
      nameFr: nameFr,
      nameAr: '${json['nameAr'] ?? json['name_ar'] ?? nameFr}',
      nameEn: '${json['nameEn'] ?? json['name_en'] ?? nameFr}',
      unit: '${json['unit'] ?? 'unit'}',
      pmpCostMru:
          ((json['pmpCostMru'] ?? json['pmp_cost_mru'] ?? 0) as num).toDouble(),
      currentStock:
          ((json['currentStock'] ?? json['current_stock'] ?? 0) as num)
              .toDouble(),
      minStock:
          ((json['minStock'] ?? json['min_stock'] ?? 0) as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sku': sku,
        'nameFr': nameFr,
        'nameAr': nameAr,
        'nameEn': nameEn,
        'unit': unit,
        'pmpCostMru': pmpCostMru,
        'currentStock': currentStock,
        'minStock': minStock,
      };
}

class RecipeBomLine {
  final String id;
  final String productId;
  final String productSku;
  final String ingredientId;
  final String ingredientSku;
  final double qtyPerUnit;
  final String conditionChannel; // ALL | TAKEAWAY_DELIVERY
  final String modifierKey;

  const RecipeBomLine({
    required this.id,
    this.productId = '',
    this.productSku = '',
    this.ingredientId = '',
    this.ingredientSku = '',
    required this.qtyPerUnit,
    this.conditionChannel = 'ALL',
    this.modifierKey = '',
  });

  factory RecipeBomLine.fromJson(Map<String, dynamic> json) {
    return RecipeBomLine(
      id: '${json['id'] ?? ''}',
      productId: '${json['productId'] ?? json['product_id'] ?? ''}',
      productSku: '${json['productSku'] ?? json['product_sku'] ?? ''}',
      ingredientId: '${json['ingredientId'] ?? json['ingredient_id'] ?? ''}',
      ingredientSku:
          '${json['ingredientSku'] ?? json['ingredient_sku'] ?? ''}',
      qtyPerUnit:
          ((json['qtyPerUnit'] ?? json['qty_per_unit'] ?? 0) as num).toDouble(),
      conditionChannel:
          '${json['conditionChannel'] ?? json['condition_channel'] ?? 'ALL'}'
              .toUpperCase(),
      modifierKey: '${json['modifierKey'] ?? json['modifier_key'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'productId': productId,
        'productSku': productSku,
        'ingredientId': ingredientId,
        'ingredientSku': ingredientSku,
        'qtyPerUnit': qtyPerUnit,
        'conditionChannel': conditionChannel,
        'modifierKey': modifierKey,
      };
}
