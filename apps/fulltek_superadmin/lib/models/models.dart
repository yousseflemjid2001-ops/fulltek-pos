import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum StoreModule { resto, market, pharma }

enum StoreStatus { active, trial, warn, expired, locked }

class TenantStore {
  final int id;
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

  Color get moduleColor {
    switch (module) {
      case StoreModule.resto:
        return FTColors.resto;
      case StoreModule.market:
        return FTColors.market;
      case StoreModule.pharma:
        return FTColors.pharma;
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
    'flt_due': 'Échéance / Expirées',
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
    'flt_due': 'قريبة / منتهية',
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
    'flt_due': 'Due / Expired',
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
  },
};

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
