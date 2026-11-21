import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum StoreModule { resto, market, pharma, commercial }

enum StoreStatus { active, trial, warn, expired, locked }

class TenantStore {
  int id;
  String name;
  final StoreModule module;
  String city;
  String phone;
  final String plan;
  final int mrr;
  int tills;
  int daysLeft;
  StoreStatus status;
  bool online;
  int pendingSync;
  List<String> enabledThemes;
  String ownerPin;

  // Fiche professionnelle (assistant de création)
  String subType = '';
  String legalName = '';
  String nif = '';
  String rc = '';
  String district = '';
  String address = '';
  String manager = '';
  String email = '';
  String billing = 'monthly';
  String tenantId = '';
  String username = '';
  String accountPassword = '';
  String defaultLang = 'fr';
  Set<String> features = <String>{};
  Set<String> payMethods = <String>{};
  Set<String> hardware = <String>{};
  String notes = '';
  String initialPayMethod = '';
  String initialPayRef = '';
  String initialOfflineCode = '';

  TenantStore({
    required this.id,
    required this.name,
    required this.module,
    required this.city,
    required this.phone,
    required this.plan,
    required this.mrr,
    required this.tills,
    required this.daysLeft,
    required this.status,
    this.online = true,
    this.pendingSync = 0,
    this.enabledThemes = const ['01', '06', '07', '11'],
    this.ownerPin = '4242',
  });

  factory TenantStore.fromJson(Map<String, dynamic> j) {
    final mod = StoreModule.values.firstWhere(
      (m) => m.name == (j['module'] ?? 'resto'),
      orElse: () => StoreModule.resto,
    );
    final st = StoreStatus.values.firstWhere(
      (x) => x.name == (j['status'] ?? 'active'),
      orElse: () => StoreStatus.active,
    );
    return TenantStore(
      id: (j['id'] as num?)?.toInt() ?? 0,
      name: j['name'] as String? ?? '',
      module: mod,
      city: j['city'] as String? ?? 'Tevragh Zeina',
      phone: j['phone'] as String? ?? '',
      plan: j['plan'] as String? ?? 'Pro',
      mrr: (j['mrr'] as num?)?.toInt() ?? 0,
      tills: (j['tills'] as num?)?.toInt() ?? 1,
      daysLeft: (j['daysLeft'] as num?)?.toInt() ?? 30,
      status: st,
      online: j['online'] as bool? ?? true,
      pendingSync: (j['pendingSync'] as num?)?.toInt() ?? 0,
      enabledThemes: List<String>.from(j['enabledThemes'] as List? ?? ['01', '06', '07', '11']),
      ownerPin: j['ownerPin'] as String? ?? '4242',
    )
      ..subType = j['subType'] as String? ?? ''
      ..legalName = j['legalName'] as String? ?? ''
      ..nif = j['nif'] as String? ?? ''
      ..rc = j['rc'] as String? ?? ''
      ..district = j['district'] as String? ?? ''
      ..address = j['address'] as String? ?? ''
      ..manager = j['manager'] as String? ?? ''
      ..email = j['email'] as String? ?? ''
      ..billing = j['billing'] as String? ?? 'monthly'
      ..tenantId = j['tenantId'] as String? ?? ''
      ..username = j['username'] as String? ?? ''
      ..accountPassword = j['accountPassword'] as String? ?? ''
      ..defaultLang = j['defaultLang'] as String? ?? 'fr'
      ..features = Set<String>.from(j['features'] as List? ?? const [])
      ..payMethods = Set<String>.from(j['payMethods'] as List? ?? const [])
      ..hardware = Set<String>.from(j['hardware'] as List? ?? const [])
      ..notes = j['notes'] as String? ?? ''
      ..initialPayMethod = j['initialPayMethod'] as String? ?? ''
      ..initialPayRef = j['initialPayRef'] as String? ?? ''
      ..initialOfflineCode = j['initialOfflineCode'] as String? ?? '';
  }

  Map<String, dynamic> toJson() => {
        'tenantId': tenantId,
        'name': name,
        'module': module.name,
        'subType': subType,
        'city': city,
        'district': district,
        'address': address,
        'legalName': legalName,
        'nif': nif,
        'rc': rc,
        'phone': phone,
        'email': email,
        'manager': manager,
        'defaultLang': defaultLang,
        'plan': plan,
        'billing': billing,
        'mrr': mrr,
        'tills': tills,
        'daysLeft': daysLeft,
        'status': status.name,
        'enabledThemes': enabledThemes,
        'features': features.toList(),
        'payMethods': payMethods.toList(),
        'hardware': hardware.toList(),
        'notes': notes,
        'username': username,
        'accountPassword': accountPassword,
        'ownerPin': ownerPin,
        'initialPayMethod': initialPayMethod,
        'initialPayRef': initialPayRef,
        'initialOfflineCode': initialOfflineCode,
      };

  Color get moduleColor {
    switch (module) {
      case StoreModule.resto:
        return FTColors.resto;
      case StoreModule.market:
        return FTColors.market;
      case StoreModule.pharma:
        return FTColors.pharma;
      case StoreModule.commercial:
        return FTColors.commercial;
    }
  }

  String get moduleName {
    switch (module) {
      case StoreModule.resto:
        return 'Full·Tek Resto';
      case StoreModule.market:
        return 'Full·Tek Market';
      case StoreModule.pharma:
        return 'Full·Tek Pharma';
      case StoreModule.commercial:
        return 'Full·Tek Commercial';
    }
  }
}

class SubscriptionPayment {
  final String id;
  final int storeId;
  final String storeName;
  final String method;
  final String ref;
  final int amount;
  final String time;

  SubscriptionPayment({
    required this.id,
    required this.storeId,
    required this.storeName,
    required this.method,
    required this.ref,
    required this.amount,
    required this.time,
  });

  factory SubscriptionPayment.fromJson(Map<String, dynamic> j) => SubscriptionPayment(
        id: j['id'] as String? ?? '',
        storeId: (j['storeId'] as num?)?.toInt() ?? 0,
        storeName: j['storeName'] as String? ?? '',
        method: j['method'] as String? ?? 'Bankily',
        ref: j['ref'] as String? ?? '',
        amount: (j['amount'] as num?)?.toInt() ?? 0,
        time: j['time'] as String? ?? '',
      );
}

class AuditEntry {
  final String title;
  final String subtitle;
  final String time;

  AuditEntry({
    required this.title,
    required this.subtitle,
    required this.time,
  });

  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
        title: j['title'] as String? ?? '',
        subtitle: j['subtitle'] as String? ?? '',
        time: j['time'] as String? ?? '',
      );
}

class AdminProfile {
  final int id;
  final String username;
  final String email;
  final String fullName;
  final String role;

  const AdminProfile({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    this.role = 'SUPER_ADMIN',
  });

  factory AdminProfile.fromJson(Map<String, dynamic> j) => AdminProfile(
        id: (j['id'] as num?)?.toInt() ?? 0,
        username: j['username'] as String? ?? '',
        email: j['email'] as String? ?? '',
        fullName: j['fullName'] as String? ?? (j['full_name'] as String? ?? 'M. Taha Chouaib'),
        role: j['role'] as String? ?? 'SUPER_ADMIN',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'fullName': fullName,
        'role': role,
      };
}

class OfflineLicenseResponse {
  final String code;
  final int days;
  final int graceDays;
  final String storeName;
  final String keyId;
  final String issuedAt;
  final String expiresAt;
  final String signature;
  final String leaseToken;
  final String publicKey;
  final Map<String, dynamic> payload;

  const OfflineLicenseResponse({
    required this.code,
    required this.days,
    this.graceDays = 7,
    this.storeName = '',
    required this.keyId,
    required this.issuedAt,
    required this.expiresAt,
    required this.signature,
    required this.leaseToken,
    this.publicKey = '',
    this.payload = const {},
  });

  factory OfflineLicenseResponse.fromJson(Map<String, dynamic> j) {
    final rawPayload = j['payload'];
    final payloadMap = rawPayload is Map<String, dynamic>
        ? Map<String, dynamic>.from(rawPayload)
        : (rawPayload is Map
            ? rawPayload.map((k, v) => MapEntry(k.toString(), v))
            : <String, dynamic>{});
    return OfflineLicenseResponse(
      code: j['code'] as String? ?? (payloadMap['code'] as String? ?? ''),
      days: (j['days'] as num?)?.toInt() ??
          (payloadMap['days'] as num?)?.toInt() ??
          30,
      graceDays: (j['graceDays'] as num?)?.toInt() ??
          (payloadMap['graceDays'] as num?)?.toInt() ??
          7,
      storeName: j['storeName'] as String? ??
          (payloadMap['storeName'] as String? ?? ''),
      keyId: j['keyId'] as String? ?? (payloadMap['keyId'] as String? ?? ''),
      issuedAt: j['issuedAt'] as String? ??
          (payloadMap['issuedAt'] as String? ?? ''),
      expiresAt: j['expiresAt'] as String? ??
          (payloadMap['expiresAt'] as String? ?? ''),
      signature: j['signature'] as String? ?? '',
      leaseToken: j['leaseToken'] as String? ?? '',
      publicKey: j['publicKey'] as String? ?? '',
      payload: payloadMap,
    );
  }
}

class CatalogImportRowError {
  final int row;
  final String message;

  const CatalogImportRowError({
    required this.row,
    required this.message,
  });

  factory CatalogImportRowError.fromJson(Map<String, dynamic> j) =>
      CatalogImportRowError(
        row: (j['row'] as num?)?.toInt() ?? 0,
        message: j['message'] as String? ?? '',
      );
}

class CatalogImportResult {
  final bool ok;
  final int tenantId;
  final String format;
  final int totalRows;
  final int created;
  final int updated;
  final int categoriesCreated;
  final String? error;
  final List<CatalogImportRowError> errors;

  const CatalogImportResult({
    required this.ok,
    required this.tenantId,
    required this.format,
    required this.totalRows,
    required this.created,
    required this.updated,
    required this.categoriesCreated,
    this.error,
    this.errors = const [],
  });

  factory CatalogImportResult.fromJson(
    Map<String, dynamic> j, {
    bool? forceOk,
  }) {
    final rawErrors = j['errors'] as List? ?? const [];
    return CatalogImportResult(
      ok: forceOk ?? (j['ok'] as bool? ?? false),
      tenantId: (j['tenantId'] as num?)?.toInt() ?? 0,
      format: j['format'] as String? ?? '',
      totalRows: (j['totalRows'] as num?)?.toInt() ?? 0,
      created: (j['created'] as num?)?.toInt() ?? 0,
      updated: (j['updated'] as num?)?.toInt() ?? 0,
      categoriesCreated: (j['categoriesCreated'] as num?)?.toInt() ?? 0,
      error: j['error'] as String?,
      errors: rawErrors
          .whereType<Map>()
          .map(
            (e) => CatalogImportRowError.fromJson(
              e.map((k, v) => MapEntry(k.toString(), v)),
            ),
          )
          .toList(),
    );
  }
}

String formatMru(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}

const Map<String, Map<String, String>> kStrings = {
  'fr': {
    'cur': 'MRU',
    'sp_sub': 'Console Super-Admin · M. Taha Chouaib',
    'cloud_ok': 'Cloud Mauritanie · En ligne',
    'mrr_lbl': 'REVENU MENSUEL RÉCURRENT (MRR)',
    'st_active': 'Actives',
    'st_trial': 'Essai 15j',
    'st_warn': 'J-5 / J-2',
    'st_exp': 'Expirées',
    'chart_h': 'Croissance SaaS (6 mois)',
    'chart_sub': 'Appuyer sur un mois',
    'pay_split_h': 'Encaissements Abonnements',
    'cash_lbl': 'Espèces',
    'urgent_h': 'Actions Urgentes (Échéances)',
    'search_ph': 'Rechercher boutique, ville, téléphone...',
    'flt_all': 'Toutes',
    'flt_commercial': 'Commercial',
    'flt_due': 'Échéance / Expirées',
    'mod_resto': 'Resto',
    'mod_market': 'Market',
    'mod_pharma': 'Pharma',
    'mod_commercial': 'Commercial',
    'off_gen_h': 'Code Déblocage Hors-Ligne (8 chiffres)',
    'off_gen_s': 'Lease 30j sans Internet',
    'sel_store': 'Boutique cliente',
    'sel_dur': 'Durée à débloquer',
    'btn_gen': 'Générer le code à 8 chiffres',
    'code_lbl': 'CODE DE SECOURS CAISSE',
    'copy_btn': 'Copier le code',
    'pending_pay_h': 'Paiements à valider (Bankily / Masrivi)',
    'vps_h': 'Santé Cloud & Sync (Hetzner VPS)',
    'fleet_h': 'Caisses Déployées (Temps Réel)',
    'admin_h': 'Super-Admin · M. Taha Chouaib',
    'adm_tel': 'WhatsApp Officiel',
    'adm_bk': 'Code Marchand Bankily',
    'adm_ms': 'Code Marchand Masrivi',
    'audit_h': 'Journal d\'Audit Sécurisé',
    'nav_home': 'Cockpit',
    'nav_stores': 'Boutiques',
    'nav_pay': 'Licences',
    'nav_fleet': 'Parc',
    'nav_audit': 'Audit',
    'new_h': 'Nouvelle Boutique (1 clic)',
    'mod_lbl': 'Module métier',
    'ns_name_l': 'Nom du commerce *',
    'ns_city_l': 'Ville / Quartier',
    'ns_wa_l': 'WhatsApp gérant *',
    'ns_plan_l': 'Formule',
    'ns_tills_l': 'Caisses',
    'ns_submit': 'Créer & Générer accès',
    'btn_extend': '+30 jours',
    'btn_wa': 'Relancer',
    'btn_lock': 'Suspendre',
    'btn_unlock': 'Réactiver',
    'btn_val': 'Valider +30j',
    'btn_support': 'Support',
    'tills': 'caisses',
    'online': 'En ligne',
    'offline': 'Mode LAN',
    'b_active': 'Actif · {d}j',
    'b_trial': 'Essai · {d}j',
    'b_warn': 'Échéance J-{d}',
    'b_exp': 'Expiré',
    'b_lock': 'Suspendu',
    'themes_h': 'Thèmes POS autorisés (Modèles)',
    'pin_h': 'Code PIN Propriétaire',
    // Auth & Session
    'auth_title': 'Console Super-Admin',
    'auth_sub': 'Connexion sécurisée JWT · Cloud Mauritanie',
    'auth_user_lbl': 'Identifiant ou email',
    'auth_pass_lbl': 'Mot de passe',
    'auth_btn': 'Se connecter',
    'auth_loading': 'Connexion en cours...',
    'auth_err_empty': 'Veuillez saisir l\'identifiant et le mot de passe.',
    'auth_err_bad': 'Identifiants invalides ou accès refusé.',
    'auth_expired': 'Session expirée (401). Veuillez vous reconnecter.',
    'btn_logout': 'Déconnexion',
    'logout_ok': 'Session fermée',
    'api_err_sync': 'Impossible de synchroniser avec le cloud.',
    // 1-Click Catalog Import
    'cat_h': 'Catalogue Produits (1 clic)',
    'cat_sub': 'Import CSV ou Excel (.xlsx) vers la caisse cloud',
    'cat_btn': 'Importer CSV / Excel',
    'cat_sample_btn': 'Modèle 1-clic',
    'cat_importing': 'Import en cours...',
    'cat_ok': 'Import réussi : {total} lignes ({created} créés, {updated} maj, {cats} cat.)',
    'cat_err': 'Échec import catalogue',
    'cat_row_err': 'Ligne {row} : {msg}',
    'cat_store_lbl': 'Boutique cible',
    'cat_total': 'Total',
    'cat_created': 'Créés',
    'cat_updated': 'Mis à jour',
    'cat_cats': 'Catégories',
    'cat_sheet_title': 'Importer un catalogue (.csv / .xlsx)',
    'cat_path_lbl': 'Chemin du fichier local (.csv ou .xlsx)',
    'cat_path_btn': 'Lire & Importer',
    'cat_paste_lbl': 'Ou coller le contenu CSV',
    'cat_paste_btn': 'Importer CSV collé',
    // Ed25519 Offline License
    'lic_gen_btn': 'Licence Ed25519',
    'lic_generating': 'Signature Ed25519...',
    'lic_err': 'Impossible de générer la licence cloud',
    'lic_days_left': '{d} jours restants',
    'lic_expires': 'Expire le',
    'lic_key_id': 'Clé Ed25519 (keyId)',
    'lic_grace': 'Grâce {d}j',
    'lic_token_lbl': 'Jeton signé (Lease Token)',
    'lic_sig_lbl': 'Signature Ed25519',
    'lic_pub_lbl': 'Clé publique Ed25519 (PEM)',
    'lic_copy_token': 'Copier Lease Token',
    'lic_copy_sig': 'Copier signature',
    'lic_copy_pub': 'Copier clé publique',
    'copied_ok': 'Copié dans le presse-papiers',
    // Web Console & Login
    'web_badge': 'SUPER-ADMIN WEB',
    'web_console_badge': 'CONSOLE WEB SUPER-ADMIN SAAS',
    'new_client_btn': 'Nouveau client',
    'supervised_stores': '{n} établissements supervisés',
    'refresh_api': 'Actualiser API',
    'login_hero_title': 'Pilotez votre réseau de caisses Resto, Market, Pharma & Commercial en Mauritanie.',
    'login_f1_t': 'Licences cryptographiques Ed25519',
    'login_f1_s': 'Génération et renouvellement de clés hors-ligne sécurisées.',
    'login_f2_t': 'Multi-établissements & Flotte POS',
    'login_f2_s': 'Supervision MRR, verrouillage à distance et suivi des terminaux.',
    'login_f3_t': 'Import Catalogue 1-Clic (CSV / Excel)',
    'login_f3_s': 'Déployez menus, stocks et modificateurs instantanément.',
  },
  'ar': {
    'cur': 'أوقية',
    'sp_sub': 'لوحة المشرف العام · السيد طه شعيب',
    'cloud_ok': 'سحابة موريتانيا · متصل',
    'mrr_lbl': 'الإيرادات الشهرية المتكررة (MRR)',
    'st_active': 'نشطة',
    'st_trial': 'تجربة 15ي',
    'st_warn': 'قرب الانتهاء',
    'st_exp': 'منتهية',
    'chart_h': 'نمو الاشتراكات (6 أشهر)',
    'chart_sub': 'اضغط على شهر',
    'pay_split_h': 'تحصيل الاشتراكات',
    'cash_lbl': 'نقدي',
    'urgent_h': 'إجراءات عاجلة (تنتهي قريباً)',
    'search_ph': 'ابحث عن متجر، مدينة، رقم هاتف...',
    'flt_all': 'الكل',
    'flt_commercial': 'تجاري',
    'flt_due': 'قريبة / منتهية',
    'mod_resto': 'مطعم',
    'mod_market': 'متجر',
    'mod_pharma': 'صيدلية',
    'mod_commercial': 'تجاري',
    'off_gen_h': 'رمز فك القفل بدون إنترنت (8 أرقام)',
    'off_gen_s': 'تمديد 30 يوماً أوفلاين',
    'sel_store': 'المتجر',
    'sel_dur': 'مدة التمديد',
    'btn_gen': 'توليد رمز من 8 أرقام',
    'code_lbl': 'رمز الطوارئ للكاشير',
    'copy_btn': 'نسخ الرمز',
    'pending_pay_h': 'مدفوعات بانتظار التأكيد',
    'vps_h': 'حالة السحابة والمزامنة (VPS)',
    'fleet_h': 'الصناديق النشطة (مباشر)',
    'admin_h': 'المشرف العام · السيد طه شعيب',
    'adm_tel': 'الواتساب الرسمي',
    'adm_bk': 'رمز تاجر بنكيلي',
    'adm_ms': 'رمز تاجر مصرفي',
    'audit_h': 'سجل التدقيق والأمان',
    'nav_home': 'الرئيسية',
    'nav_stores': 'المتاجر',
    'nav_pay': 'التراخيص',
    'nav_fleet': 'الصناديق',
    'nav_audit': 'التدقيق',
    'new_h': 'إنشاء متجر جديد (بنقرة واحدة)',
    'mod_lbl': 'النشاط',
    'ns_name_l': 'اسم المتجر *',
    'ns_city_l': 'المدينة / الحي',
    'ns_wa_l': 'واتساب المدير *',
    'ns_plan_l': 'الباقة',
    'ns_tills_l': 'عدد الصناديق',
    'ns_submit': 'إنشاء وتوليد بيانات الدخول',
    'btn_extend': '+30 يوماً',
    'btn_wa': 'تذكير',
    'btn_lock': 'إيقاف',
    'btn_unlock': 'تفعيل',
    'btn_val': 'تأكيد +30ي',
    'btn_support': 'دعم فني',
    'tills': 'صناديق',
    'online': 'متصل',
    'offline': 'شبكة محلية',
    'b_active': 'نشط · {d}ي',
    'b_trial': 'تجربة · {d}ي',
    'b_warn': 'متبقي {d}ي',
    'b_exp': 'منتهي',
    'b_lock': 'موقوف',
    'themes_h': 'الواجهات المفعّلة للمتجر',
    'pin_h': 'رمز الدخول السري للمالك (PIN)',
    // Auth & Session
    'auth_title': 'لوحة تحكم المشرف العام',
    'auth_sub': 'تسجيل دخول آمن JWT · سحابة موريتانيا',
    'auth_user_lbl': 'اسم المستخدم أو البريد',
    'auth_pass_lbl': 'كلمة المرور',
    'auth_btn': 'تسجيل الدخول',
    'auth_loading': 'جاري تسجيل الدخول...',
    'auth_err_empty': 'يرجى إدخال اسم المستخدم وكلمة المرور.',
    'auth_err_bad': 'بيانات الدخول غير صحيحة أو الوصول مرفوض.',
    'auth_expired': 'انتهت الجلسة (401). يرجى إعادة تسجيل الدخول.',
    'btn_logout': 'تسجيل الخروج',
    'logout_ok': 'تم تسجيل الخروج',
    'api_err_sync': 'تعذرت المزامنة مع السحابة.',
    // 1-Click Catalog Import
    'cat_h': 'كتالوج المنتجات (نقرة واحدة)',
    'cat_sub': 'استيراد CSV أو Excel (.xlsx) إلى السحابة',
    'cat_btn': 'استيراد CSV / Excel',
    'cat_sample_btn': 'نموذج بنقرة واحدة',
    'cat_importing': 'جاري الاستيراد...',
    'cat_ok': 'تم الاستيراد: {total} سطر ({created} جديد، {updated} محدث، {cats} تصنيف)',
    'cat_err': 'فشل استيراد الكتالوج',
    'cat_row_err': 'سطر {row}: {msg}',
    'cat_store_lbl': 'المتجر المستهدف',
    'cat_total': 'الإجمالي',
    'cat_created': 'جديد',
    'cat_updated': 'محدث',
    'cat_cats': 'التصنيفات',
    'cat_sheet_title': 'استيراد الكتالوج (.csv / .xlsx)',
    'cat_path_lbl': 'مسار الملف المحلي (.csv أو .xlsx)',
    'cat_path_btn': 'قراءة واستيراد',
    'cat_paste_lbl': 'أو الصق محتوى CSV',
    'cat_paste_btn': 'استيراد CSV الملصق',
    // Ed25519 Offline License
    'lic_gen_btn': 'ترخيص Ed25519',
    'lic_generating': 'جاري التوقيع Ed25519...',
    'lic_err': 'تعذر توليد الترخيص السحابي',
    'lic_days_left': 'متبقي {d} يوماً',
    'lic_expires': 'ينتهي في',
    'lic_key_id': 'معرّف المفتاح (keyId)',
    'lic_grace': 'سماح {d}ي',
    'lic_token_lbl': 'الرمز الموقّع (Lease Token)',
    'lic_sig_lbl': 'توقيع Ed25519',
    'lic_pub_lbl': 'المفتاح العام Ed25519 (PEM)',
    'lic_copy_token': 'نسخ Lease Token',
    'lic_copy_sig': 'نسخ التوقيع',
    'lic_copy_pub': 'نسخ المفتاح العام',
    'copied_ok': 'تم النسخ إلى الحافظة',
    // Web Console & Login
    'web_badge': 'مشرف المنصة الويب',
    'web_console_badge': 'لوحة تحكم الويب للمشرف العام SaaS',
    'new_client_btn': 'عميل جديد',
    'supervised_stores': '{n} متجر تحت الإشراف',
    'refresh_api': 'تحديث API',
    'login_hero_title': 'أدِر شبكة نقاط البيع للمطاعم والأسواق والصيدليات والتجارة في موريتانيا.',
    'login_f1_t': 'تراخيص مشفرة Ed25519',
    'login_f1_s': 'توليد وتجديد مفاتيح العمل بدون إنترنت بأمان.',
    'login_f2_t': 'متاجر متعددة وأسطول نقاط البيع',
    'login_f2_s': 'مراقبة الإيرادات الشهرية والقفل عن بعد ومتابعة الأجهزة.',
    'login_f3_t': 'استيراد الكتالوج بنقرة واحدة (CSV / Excel)',
    'login_f3_s': 'انشر القوائم والمخزون والإضافات فوراً.',
  },
  'en': {
    'cur': 'MRU',
    'sp_sub': 'Super-Admin Console · Mr. Taha Chouaib',
    'cloud_ok': 'Mauritania Cloud · Online',
    'mrr_lbl': 'MONTHLY RECURRING REVENUE (MRR)',
    'st_active': 'Active',
    'st_trial': '15d Trial',
    'st_warn': 'D-5 / D-2',
    'st_exp': 'Expired',
    'chart_h': 'SaaS Growth (6 months)',
    'chart_sub': 'Tap a month',
    'pay_split_h': 'Subscription Payments',
    'cash_lbl': 'Cash',
    'urgent_h': 'Urgent Actions (Due soon)',
    'search_ph': 'Search store, city, phone...',
    'flt_all': 'All',
    'flt_commercial': 'Commercial',
    'flt_due': 'Due / Expired',
    'mod_resto': 'Resto',
    'mod_market': 'Market',
    'mod_pharma': 'Pharma',
    'mod_commercial': 'Commercial',
    'off_gen_h': 'Offline Unlock Code (8 digits)',
    'off_gen_s': '30d Lease without Internet',
    'sel_store': 'Client store',
    'sel_dur': 'Duration',
    'btn_gen': 'Generate 8-digit code',
    'code_lbl': 'REGISTER UNLOCK CODE',
    'copy_btn': 'Copy code',
    'pending_pay_h': 'Payments to Verify (Bankily / Masrivi)',
    'vps_h': 'Cloud & Sync Health (Hetzner VPS)',
    'fleet_h': 'Deployed Registers (Live)',
    'admin_h': 'Super-Admin · Mr. Taha Chouaib',
    'adm_tel': 'Official WhatsApp',
    'adm_bk': 'Bankily Merchant Code',
    'adm_ms': 'Masrivi Merchant Code',
    'audit_h': 'Immutable Audit Log',
    'nav_home': 'Cockpit',
    'nav_stores': 'Stores',
    'nav_pay': 'Licenses',
    'nav_fleet': 'Fleet',
    'nav_audit': 'Audit',
    'new_h': 'New Store (1-Click)',
    'mod_lbl': 'Business module',
    'ns_name_l': 'Business name *',
    'ns_city_l': 'City / District',
    'ns_wa_l': 'Owner WhatsApp *',
    'ns_plan_l': 'Plan',
    'ns_tills_l': 'Registers',
    'ns_submit': 'Create & Generate Access',
    'btn_extend': '+30 days',
    'btn_wa': 'Remind',
    'btn_lock': 'Suspend',
    'btn_unlock': 'Reactivate',
    'btn_val': 'Approve +30d',
    'btn_support': 'Support',
    'tills': 'tills',
    'online': 'Online',
    'offline': 'LAN Mode',
    'b_active': 'Active · {d}d',
    'b_trial': 'Trial · {d}d',
    'b_warn': 'Due D-{d}',
    'b_exp': 'Expired',
    'b_lock': 'Suspended',
    'themes_h': 'Enabled POS Themes',
    'pin_h': 'Owner PIN Code',
    // Auth & Session
    'auth_title': 'Super-Admin Console',
    'auth_sub': 'Secure JWT Login · Mauritania Cloud',
    'auth_user_lbl': 'Username or email',
    'auth_pass_lbl': 'Password',
    'auth_btn': 'Sign In',
    'auth_loading': 'Signing in...',
    'auth_err_empty': 'Please enter username and password.',
    'auth_err_bad': 'Invalid credentials or access denied.',
    'auth_expired': 'Session expired (401). Please sign in again.',
    'btn_logout': 'Log out',
    'logout_ok': 'Signed out',
    'api_err_sync': 'Unable to sync with cloud.',
    // 1-Click Catalog Import
    'cat_h': 'Product Catalog (1-Click)',
    'cat_sub': 'Import CSV or Excel (.xlsx) to cloud register',
    'cat_btn': 'Import CSV / Excel',
    'cat_sample_btn': '1-Click Sample',
    'cat_importing': 'Importing...',
    'cat_ok': 'Imported {total} rows ({created} created, {updated} updated, {cats} cat.)',
    'cat_err': 'Catalog import failed',
    'cat_row_err': 'Row {row}: {msg}',
    'cat_store_lbl': 'Target store',
    'cat_total': 'Total',
    'cat_created': 'Created',
    'cat_updated': 'Updated',
    'cat_cats': 'Categories',
    'cat_sheet_title': 'Import Catalog (.csv / .xlsx)',
    'cat_path_lbl': 'Local file path (.csv or .xlsx)',
    'cat_path_btn': 'Read & Import',
    'cat_paste_lbl': 'Or paste CSV content',
    'cat_paste_btn': 'Import pasted CSV',
    // Ed25519 Offline License
    'lic_gen_btn': 'Ed25519 License',
    'lic_generating': 'Signing Ed25519...',
    'lic_err': 'Unable to generate cloud license',
    'lic_days_left': '{d} days left',
    'lic_expires': 'Expires at',
    'lic_key_id': 'Ed25519 Key ID',
    'lic_grace': 'Grace {d}d',
    'lic_token_lbl': 'Signed Lease Token',
    'lic_sig_lbl': 'Ed25519 Signature',
    'lic_pub_lbl': 'Ed25519 Public Key (PEM)',
    'lic_copy_token': 'Copy Lease Token',
    'lic_copy_sig': 'Copy signature',
    'lic_copy_pub': 'Copy public key',
    'copied_ok': 'Copied to clipboard',
    // Web Console & Login
    'web_badge': 'SUPER-ADMIN WEB',
    'web_console_badge': 'SUPER-ADMIN SAAS WEB CONSOLE',
    'new_client_btn': 'New client',
    'supervised_stores': '{n} supervised stores',
    'refresh_api': 'Refresh API',
    'login_hero_title': 'Manage your Resto, Market, Pharma & Commercial POS network in Mauritania.',
    'login_f1_t': 'Ed25519 Cryptographic Licenses',
    'login_f1_s': 'Secure offline license key generation & renewal.',
    'login_f2_t': 'Multi-Store & POS Fleet',
    'login_f2_s': 'MRR monitoring, remote lock & terminal tracking.',
    'login_f3_t': '1-Click Catalog Import (CSV / Excel)',
    'login_f3_s': 'Deploy menus, stock & modifiers instantly.',
  },
};

String catalogSampleCsvForModule(StoreModule module) {
  switch (module) {
    case StoreModule.resto:
      return 'sku,barcode,name_fr,name_ar,category,unit,price_retail,price_whole,price_cost,track_fefo,requires_cnam\n'
          'RES-001,6150000001011,Shawarma Poulet,شاورما دجاج,Plats,portion,180,150,90,false,false\n'
          'RES-002,6150000001028,Jus Bissap Frais,عصير كركديه,Boissons,verre,70,55,25,false,false\n'
          'RES-003,6150000001035,Tajine Agneau,طاجين لحم,Plats,portion,350,300,190,false,false\n';
    case StoreModule.market:
      return 'sku,barcode,name_fr,name_ar,category,unit,price_retail,price_whole,price_cost,track_fefo,requires_cnam\n'
          'MKT-001,6150000002018,Sucre Cristal 1kg,سكر أبيض 1كغ,Épicerie,kg,45,42,38,false,false\n'
          'MKT-002,6150000002025,Huile Végétale 1L,زيت نباتي 1ل,Épicerie,bouteille,85,80,72,false,false\n'
          'MKT-003,6150000002032,Thé Vert Chunmee 250g,شاي أخضر 250غ,Boissons,boite,120,110,95,false,false\n';
    case StoreModule.pharma:
      return 'sku,barcode,name_fr,name_ar,category,unit,price_retail,price_whole,price_cost,track_fefo,requires_cnam\n'
          'PHM-001,6150000003015,Paracétamol 500mg,باراسيتامول 500مغ,Antalgiques,boite,110,95,70,true,true\n'
          'PHM-002,6150000003022,Amoxicilline 1g,أموكسيسيلين 1غ,Antibiotiques,boite,260,230,180,true,true\n'
          'PHM-003,6150000003039,Sérum Physiologique,محلول ملحي,Soins,flacon,90,75,55,true,false\n';
    case StoreModule.commercial:
      return 'sku,barcode,name_fr,name_ar,category,unit,price_retail,price_whole,price_cost,qty,track_fefo,requires_cnam\n'
          'COM-001,6150000004012,Ramette Papier A4 80g,رزمة ورق A4,Fournitures Bureau,ramette,240,210,175,120,false,false\n'
          'COM-002,6150000004029,Ciment CPJ45 Sac 50kg,أسمنت CPJ45 50كغ,Matériaux,sac,380,355,320,250,false,false\n'
          'COM-003,6150000004036,Câble Réseau Cat6 305m,كابل شبكة Cat6 305م,Équipements IT,carton,2800,2500,2150,18,false,false\n';
  }
}

List<TenantStore> initialStores() => [
  TenantStore(
    id: 1,
    name: 'Dar El-Karam Resto',
    module: StoreModule.resto,
    city: 'Tevragh Zeina',
    phone: '+222 46 11 22 33',
    plan: 'Pro',
    mrr: 3000,
    tills: 3,
    daysLeft: 2,
    status: StoreStatus.warn,
    ownerPin: '7410',
  )
    ..tenantId = 'FT-1041'
    ..username = 'darelkram41'
    ..manager = 'Ahmed Ould Salem'
    ..subType = 'Salon Khaima VIP'
    ..district = 'Îlot C · Nouakchott'
    ..hardware = {'printer', 'kds_screen', 'tablet'}
    ..payMethods = {'Bankily', 'Masrivi', 'Sedad', 'Cash'}
    ..features = {'kds', 'khaima', 'tablet', 'split', 'boss', 'offline', 'lan', 'printer'},
  TenantStore(
    id: 2,
    name: 'Al-Baraka Market',
    module: StoreModule.market,
    city: 'Ksar',
    phone: '+222 44 88 19 02',
    plan: 'Pro',
    mrr: 3000,
    tills: 4,
    daysLeft: 24,
    status: StoreStatus.active,
    ownerPin: '5920',
  )
    ..tenantId = 'FT-2088'
    ..username = 'albaraka88'
    ..manager = 'Mohamed Ould Sidi'
    ..subType = 'Supermarché'
    ..district = 'Carrefour Madrid'
    ..hardware = {'printer', 'scanner', 'scale', 'drawer'}
    ..payMethods = {'Bankily', 'Masrivi', 'Cash', 'Karni'}
    ..features = {'scale', 'barcode', 'wholesale', 'karni', 'boss', 'offline', 'lan', 'printer'},
  TenantStore(
    id: 3,
    name: 'Pharmacie Chinguetti',
    module: StoreModule.pharma,
    city: 'Tevragh Zeina',
    phone: '+222 42 33 77 10',
    plan: 'Entreprise',
    mrr: 5500,
    tills: 5,
    daysLeft: 18,
    status: StoreStatus.active,
    online: false,
    pendingSync: 42,
    ownerPin: '8831',
  )
    ..tenantId = 'FT-3019'
    ..username = 'chinguetti19'
    ..manager = 'Dr. Mariem Mint Cheikh'
    ..subType = 'Pharmacie d\'officine'
    ..nif = '00419284'
    ..rc = 'RC-NKC-9921'
    ..hardware = {'printer', 'scanner', 'drawer'}
    ..payMethods = {'Bankily', 'Masrivi', 'Sedad', 'Cash'}
    ..features = {'fefo', 'cnam', 'cold', 'generic', 'boss', 'offline', 'lan', 'printer'},
  TenantStore(
    id: 4,
    name: 'Boucherie El-Wiam',
    module: StoreModule.market,
    city: 'Arafat',
    phone: '+222 36 55 41 12',
    plan: 'Start',
    mrr: 1500,
    tills: 1,
    daysLeft: 0,
    status: StoreStatus.expired,
    ownerPin: '3019',
  )
    ..tenantId = 'FT-4012'
    ..manager = 'Brahim Fall'
    ..subType = 'Boucherie'
    ..hardware = {'printer', 'scale'}
    ..payMethods = {'Bankily', 'Cash', 'Karni'}
    ..features = {'scale', 'karni', 'offline', 'printer'},
  TenantStore(
    id: 5,
    name: 'Café Khaima Nouadhibou',
    module: StoreModule.resto,
    city: 'Nouadhibou',
    phone: '+222 48 90 14 25',
    plan: 'Essai 15j',
    mrr: 0,
    tills: 2,
    daysLeft: 9,
    status: StoreStatus.trial,
    ownerPin: '1540',
  )
    ..tenantId = 'FT-5090'
    ..manager = 'Sidi Mohamed'
    ..subType = 'Café / Salon de thé'
    ..hardware = {'printer', 'tablet'}
    ..payMethods = {'Bankily', 'Masrivi', 'Cash'}
    ..features = {'kds', 'khaima', 'tablet', 'boss', 'offline', 'printer'},
  TenantStore(
    id: 6,
    name: 'Pharmacie Atar Centre',
    module: StoreModule.pharma,
    city: 'Atar',
    phone: '+222 45 64 31 09',
    plan: 'Pro',
    mrr: 3000,
    tills: 2,
    daysLeft: 4,
    status: StoreStatus.warn,
    online: false,
    pendingSync: 19,
    ownerPin: '6604',
  )
    ..tenantId = 'FT-6031'
    ..manager = 'Dr. Abdallahi'
    ..subType = 'Pharmacie d\'officine'
    ..hardware = {'printer', 'scanner'}
    ..payMethods = {'Bankily', 'Cash'}
    ..features = {'fefo', 'cnam', 'cold', 'offline', 'printer'},
  TenantStore(
    id: 7,
    name: 'Épicerie Rosso Express',
    module: StoreModule.market,
    city: 'Rosso',
    phone: '+222 33 21 89 44',
    plan: 'Start',
    mrr: 1500,
    tills: 1,
    daysLeft: 27,
    status: StoreStatus.active,
    ownerPin: '9218',
  )
    ..tenantId = 'FT-7089'
    ..manager = 'Oumar Diop'
    ..subType = 'Épicerie / Alimentation'
    ..hardware = {'printer', 'scanner'}
    ..payMethods = {'Bankily', 'Sedad', 'Cash', 'Karni'}
    ..features = {'barcode', 'karni', 'offline', 'printer'},
  TenantStore(
    id: 8,
    name: 'Mauritanie Négoce & Distribution',
    module: StoreModule.commercial,
    city: 'Tevragh Zeina',
    phone: '+222 45 25 80 90',
    plan: 'Entreprise',
    mrr: 5500,
    tills: 3,
    daysLeft: 29,
    status: StoreStatus.active,
    ownerPin: '4820',
  )
    ..tenantId = 'FT-8014'
    ..username = 'mauritanienegoce'
    ..manager = 'Cheikh Ould Brahim'
    ..subType = 'Négoce / Distribution'
    ..legalName = 'Mauritanie Négoce & Distribution SARL'
    ..nif = '00528190'
    ..rc = 'RC-NKC-4418'
    ..district = 'Zone Industrielle · Nouakchott'
    ..hardware = {'printer', 'scanner', 'drawer'}
    ..payMethods = {'Cash', 'Bankily', 'Masrivi', 'Sedad', 'Bimbank', 'Click', 'Karni'}
    ..features = {
      'quotes_invoices',
      'sales_cycle',
      'purchases_pmp',
      'pos_register',
      'treasury',
      'cheques_due',
      'objectives',
      'karni_credit',
      'boss',
      'offline',
      'lan',
      'printer',
    },
];

List<SubscriptionPayment> initialPayments() => [
  SubscriptionPayment(
    id: 'P-901',
    storeId: 1,
    storeName: 'Dar El-Karam Resto',
    method: 'Bankily',
    ref: 'BK-884210',
    amount: 3000,
    time: '14:12',
  ),
  SubscriptionPayment(
    id: 'P-902',
    storeId: 4,
    storeName: 'Boucherie El-Wiam',
    method: 'Masrivi',
    ref: 'MS-190442',
    amount: 1500,
    time: '11:45',
  ),
  SubscriptionPayment(
    id: 'P-903',
    storeId: 6,
    storeName: 'Pharmacie Atar Centre',
    method: 'Sedad',
    ref: 'SD-773105',
    amount: 3000,
    time: '09:30',
  ),
];

List<AuditEntry> initialAudit() => [
  AuditEntry(
    title: 'Validation Bankily +30j · Al-Baraka Market',
    subtitle: 'M. Taha · Réf. BK-77310 · +3 000 MRU',
    time: '13:20',
  ),
  AuditEntry(
    title: 'Code Offline 8 chiffres · Pharmacie Atar',
    subtitle: 'M. Taha · Lease +30j généré',
    time: 'Hier 19:05',
  ),
  AuditEntry(
    title: 'Provisioning · Café Khaima Nouadhibou',
    subtitle: 'M. Taha · Essai gratuit 15j · 2 caisses',
    time: 'Hier 16:40',
  ),
];
