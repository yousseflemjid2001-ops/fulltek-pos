import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/external_link.dart';

/// Assistant fluide d'ajout client / boutique (3 étapes + accès & WhatsApp).
class NewStoreWizard extends StatefulWidget {
  final String lang;
  const NewStoreWizard({super.key, required this.lang});

  @override
  State<NewStoreWizard> createState() => _NewStoreWizardState();
}

const Map<String, Map<String, String>> _wizStrings = {
  'fr': {
    'title': 'Nouveau client / boutique',
    's1': 'Client',
    's2': 'Offre & POS',
    's3': 'Activation',
    'next': 'Continuer',
    'back': 'Retour',
    'create': 'Activer le client',
    'finish': 'Terminer',
    's1_h': 'Activité & coordonnées du gérant',
    's1_sub': 'Les fonctions caisse s\'adaptent automatiquement au métier choisi.',
    'mod_resto': 'Resto',
    'mod_market': 'Market',
    'mod_pharma': 'Pharma',
    'sub_h': 'Type d\'établissement',
    'trade': 'Nom du commerce *',
    'mgr': 'Nom complet du gérant *',
    'wa': 'WhatsApp gérant *',
    'city': 'Ville',
    'district': 'Quartier / Repère',
    'adm_exp': 'Dossier administratif & notes (Optionnel)',
    'adm_sub': 'Raison sociale, NIF, RC, email, langue caisse',
    'legal': 'Raison sociale',
    'nif': 'NIF',
    'rc': 'Registre commerce',
    'email': 'Email',
    'address': 'Adresse complète',
    'notes': 'Notes installation / support',
    'lang': 'Langue caisse par défaut',
    'req': 'Obligatoire',
    'phone_bad': '8 chiffres requis',
    'email_bad': 'Email invalide',
    'acc_h': 'Compte de connexion client',
    'acc_login': 'Identifiant / Login *',
    'acc_pw': 'Mot de passe du compte *',
    'acc_pw_bad': '6 caractères minimum',
    'acc_pin': 'Code PIN gérant (4 chiffres) *',
    'acc_pin_bad': '4 chiffres requis',
    'acc_gen': 'Générer',
    's2_h': 'Licence, règlement & matériel',
    'billing_m': 'Mensuel',
    'billing_y': 'Annuel -20%',
    'plan_start': 'Start',
    'plan_pro': 'Pro',
    'plan_ent': 'Entreprise',
    'plan_start_d': '1 caisse · hors-ligne',
    'plan_pro_d': '4 caisses · Boss · KDS/FEFO',
    'plan_ent_d': '10 caisses · multi-sites · formation',
    'trial_h': 'Essai gratuit 15 jours (0 MRU)',
    'trial_d': 'Activation immédiate sans règlement.',
    'tills': 'Caisses autorisées',
    'incl': 'incluses',
    'extra': 'supplémentaire(s)',
    'pay_now_h': 'Règlement initial reçu',
    'pay_later': 'À encaisser plus tard',
    'pay_ref': 'Référence transaction (ex: BK-884210)',
    'hw_h': 'Matériel POS installé',
    'adv_exp': 'Fonctions métier, paiements & thèmes UI',
    'adv_sub': 'Pré-configuré automatiquement · modifiable',
    'feat_h': 'Fonctions caisse',
    'pay_h': 'Paiements en caisse',
    'themes_h': 'Thèmes UI autorisés',
    's3_h': 'Récapitulatif avant activation',
    'sum_biz': 'Commerce',
    'sum_mgr': 'Gérant',
    'sum_mod': 'Activité',
    'sum_plan': 'Formule',
    'sum_tills': 'Caisses',
    'sum_pay': 'Règlement initial',
    'sum_hw': 'Matériel',
    'sum_monthly': 'Abonnement mensuel',
    'sum_first': 'Total à facturer',
    'sum_trial': 'Essai gratuit 15 jours (0 MRU)',
    'done_h': 'Client activé avec succès',
    'done_sub': 'Les accès et le code hors-ligne sont prêts à être envoyés au gérant.',
    'tenant_id': 'ID Boutique',
    'username': 'Identifiant',
    'temp_pw': 'Mot de passe du compte',
    'pin': 'Code PIN gérant',
    'off_code': 'Code secours hors-ligne (30j)',
    'copy_msg': 'Copier les accès',
    'send_wa': 'Envoyer sur WhatsApp',
    'copied': 'Message d\'accès copié',
    'cur': 'MRU',
    'perm': 'mois',
    'msg': 'Bonjour {mgr}, votre espace {mod} « {name} » est activé.\nID Boutique : {id}\nIdentifiant : {user}\nMot de passe du compte : {pw}\nCode PIN propriétaire : {pin}\nCode secours hors-ligne : {off}\nSupport M. Taha : +222 42 74 42 42',
  },
  'ar': {
    'title': 'إضافة متجر / عميل جديد',
    's1': 'العميل',
    's2': 'الباقة والمعدات',
    's3': 'التفعيل',
    'next': 'متابعة',
    'back': 'رجوع',
    'create': 'تفعيل العميل الآن',
    'finish': 'إنهاء',
    's1_h': 'النشاط وبيانات المدير',
    's1_sub': 'تُضبط وظائف الكاشير تلقائياً حسب نوع النشاط.',
    'mod_resto': 'مطعم',
    'mod_market': 'متجر',
    'mod_pharma': 'صيدلية',
    'sub_h': 'تصنيف المنشأة',
    'trade': 'اسم المتجر *',
    'mgr': 'اسم المدير الكامل *',
    'wa': 'واتساب المدير *',
    'city': 'المدينة',
    'district': 'الحي / المعلم',
    'adm_exp': 'الملف الإداري والملاحظات (اختياري)',
    'adm_sub': 'الاسم القانوني، NIF، السجل التجاري، البريد، اللغة',
    'legal': 'الاسم القانوني',
    'nif': 'الرقم الضريبي (NIF)',
    'rc': 'السجل التجاري',
    'email': 'البريد الإلكتروني',
    'address': 'العنوان التفصيلي',
    'notes': 'ملاحظات التركيب والدعم',
    'lang': 'لغة الكاشير الافتراضية',
    'req': 'حقل إلزامي',
    'phone_bad': '8 أرقام مطلوبة',
    'email_bad': 'بريد غير صحيح',
    'acc_h': 'حساب دخول العميل',
    'acc_login': 'اسم المستخدم (Login) *',
    'acc_pw': 'كلمة مرور الحساب *',
    'acc_pw_bad': '6 أحرف على الأقل',
    'acc_pin': 'رمز PIN للمالك (4 أرقام) *',
    'acc_pin_bad': '4 أرقام مطلوبة',
    'acc_gen': 'توليد',
    's2_h': 'الترخيص، الدفع والمعدات',
    'billing_m': 'شهري',
    'billing_y': 'سنوي -20%',
    'plan_start': 'الأساسية',
    'plan_pro': 'الاحترافية',
    'plan_ent': 'المؤسسات',
    'plan_start_d': 'صندوق واحد · أوفلاين',
    'plan_pro_d': '4 صناديق · تطبيق المدير · KDS/FEFO',
    'plan_ent_d': '10 صناديق · عدة فروع · تدريب ميداني',
    'trial_h': 'تجربة مجانية 15 يوماً (0 أوقية)',
    'trial_d': 'تفعيل فوري دون دفع مسبق.',
    'tills': 'عدد الصناديق المسموحة',
    'incl': 'مشمولة',
    'extra': 'إضافي',
    'pay_now_h': 'الدفعة الأولى المستلمة',
    'pay_later': 'التحصيل لاحقاً',
    'pay_ref': 'رقم المرجع (مثال: BK-884210)',
    'hw_h': 'معدات نقطة البيع المركّبة',
    'adv_exp': 'الوظائف ووسائل الدفع والواجهات',
    'adv_sub': 'مُعدّة تلقائياً · قابلة للتعديل',
    'feat_h': 'وظائف الكاشير',
    'pay_h': 'وسائل الدفع في الكاشير',
    'themes_h': 'الواجهات المسموحة',
    's3_h': 'ملخص قبل التفعيل',
    'sum_biz': 'المتجر',
    'sum_mgr': 'المدير',
    'sum_mod': 'النشاط',
    'sum_plan': 'الباقة',
    'sum_tills': 'الصناديق',
    'sum_pay': 'الدفع الأولي',
    'sum_hw': 'المعدات',
    'sum_monthly': 'الاشتراك الشهري',
    'sum_first': 'المستحق الآن',
    'sum_trial': 'تجربة مجانية 15 يوماً (0 أوقية)',
    'done_h': 'تم تفعيل العميل بنجاح',
    'done_sub': 'بيانات الدخول ورمز الطوارئ جاهزة للإرسال مباشرة إلى المدير.',
    'tenant_id': 'معرّف المتجر',
    'username': 'اسم المستخدم',
    'temp_pw': 'كلمة مرور الحساب',
    'pin': 'رمز PIN للمالك',
    'off_code': 'رمز فك القفل أوفلاين (30ي)',
    'copy_msg': 'نسخ بيانات الدخول',
    'send_wa': 'إرسال عبر واتساب',
    'copied': 'تم نسخ بيانات الدخول',
    'cur': 'أوقية',
    'perm': 'شهر',
    'msg': 'السلام عليكم {mgr}، تم تفعيل نظام {mod} لمتجركم «{name}».\nمعرّف المتجر: {id}\nاسم المستخدم: {user}\nكلمة مرور الحساب: {pw}\nرمز PIN للمالك: {pin}\nرمز فك القفل أوفلاين: {off}\nدعم السيد طه: +222 42 74 42 42',
  },
  'en': {
    'title': 'New client / store',
    's1': 'Client',
    's2': 'Plan & POS',
    's3': 'Activate',
    'next': 'Continue',
    'back': 'Back',
    'create': 'Activate client',
    'finish': 'Done',
    's1_h': 'Business & manager details',
    's1_sub': 'Register features auto-configure based on the chosen activity.',
    'mod_resto': 'Resto',
    'mod_market': 'Market',
    'mod_pharma': 'Pharma',
    'sub_h': 'Establishment type',
    'trade': 'Business name *',
    'mgr': 'Manager full name *',
    'wa': 'Manager WhatsApp *',
    'city': 'City',
    'district': 'District / Landmark',
    'adm_exp': 'Administrative file & notes (Optional)',
    'adm_sub': 'Legal name, Tax ID, Trade Reg, email, language',
    'legal': 'Legal name',
    'nif': 'Tax ID (NIF)',
    'rc': 'Trade register',
    'email': 'Email',
    'address': 'Full address',
    'notes': 'Installation / support notes',
    'lang': 'Default register language',
    'req': 'Required',
    'phone_bad': '8 digits required',
    'email_bad': 'Invalid email',
    'acc_h': 'Client login account',
    'acc_login': 'Username / Login *',
    'acc_pw': 'Account password *',
    'acc_pw_bad': 'At least 6 characters',
    'acc_pin': 'Owner PIN (4 digits) *',
    'acc_pin_bad': '4 digits required',
    'acc_gen': 'Generate',
    's2_h': 'License, payment & hardware',
    'billing_m': 'Monthly',
    'billing_y': 'Yearly -20%',
    'plan_start': 'Start',
    'plan_pro': 'Pro',
    'plan_ent': 'Enterprise',
    'plan_start_d': '1 till · offline',
    'plan_pro_d': '4 tills · Boss · KDS/FEFO',
    'plan_ent_d': '10 tills · multi-store · training',
    'trial_h': '15-day free trial (0 MRU)',
    'trial_d': 'Immediate activation with no payment.',
    'tills': 'Authorized tills',
    'incl': 'included',
    'extra': 'extra',
    'pay_now_h': 'Initial payment received',
    'pay_later': 'Bill later',
    'pay_ref': 'Transaction ref (e.g. BK-884210)',
    'hw_h': 'Installed POS hardware',
    'adv_exp': 'Features, payments & UI themes',
    'adv_sub': 'Auto-configured · customizable',
    'feat_h': 'POS features',
    'pay_h': 'Accepted payments',
    'themes_h': 'Allowed UI themes',
    's3_h': 'Review before activation',
    'sum_biz': 'Business',
    'sum_mgr': 'Manager',
    'sum_mod': 'Module',
    'sum_plan': 'Plan',
    'sum_tills': 'Tills',
    'sum_pay': 'Initial payment',
    'sum_hw': 'Hardware',
    'sum_monthly': 'Monthly rate',
    'sum_first': 'Amount due now',
    'sum_trial': '15-day free trial (0 MRU)',
    'done_h': 'Client activated',
    'done_sub': 'Credentials and offline unlock code are ready to share with the manager.',
    'tenant_id': 'Store ID',
    'username': 'Username',
    'temp_pw': 'Account password',
    'pin': 'Owner PIN',
    'off_code': 'Offline unlock code (30d)',
    'copy_msg': 'Copy credentials',
    'send_wa': 'Send via WhatsApp',
    'copied': 'Credentials copied',
    'cur': 'MRU',
    'perm': 'mo',
    'msg': 'Hello {mgr}, your {mod} workspace "{name}" is active.\nStore ID: {id}\nUsername: {user}\nAccount password: {pw}\nOwner PIN: {pin}\nOffline code: {off}\nSupport Mr. Taha: +222 42 74 42 42',
  },
};

const Map<StoreModule, List<List<String>>> _subTypes = {
  StoreModule.resto: [
    ['Restaurant', 'مطعم', 'Restaurant'],
    ['Salon Khaima VIP', 'صالون خيمة VIP', 'Khaima VIP'],
    ['Café / Lounge', 'مقهى / صالون', 'Café / Lounge'],
    ['Fast-food', 'وجبات سريعة', 'Fast-food'],
    ['Grillade / Méchoui', 'مشويات', 'Grill house'],
  ],
  StoreModule.market: [
    ['Supermarché', 'سوبرماركت', 'Supermarket'],
    ['Boucherie', 'ملحمة', 'Butchery'],
    ['Épicerie', 'بقالة', 'Grocery'],
    ['Grossiste', 'تاجر جملة', 'Wholesaler'],
  ],
  StoreModule.pharma: [
    ['Pharmacie d\'officine', 'صيدلية', 'Pharmacy'],
    ['Dépôt pharmaceutique', 'مخزن أدوية', 'Pharma depot'],
    ['Parapharmacie', 'مستحضرات طبية', 'Parapharmacy'],
  ],
};

class _HwItem {
  final String key;
  final List<String> label;
  const _HwItem(this.key, this.label);
}

const List<_HwItem> _hardwareList = [
  _HwItem('printer', ['Imprimante 80mm', 'طابعة 80 ملم', '80mm Printer']),
  _HwItem('scanner', ['Douchette EAN-13', 'قارئ باركود', 'EAN-13 Scanner']),
  _HwItem('scale', ['Balance COM1', 'ميزان COM1', 'COM1 Scale']),
  _HwItem('drawer', ['Tiroir RJ11', 'درج نقود RJ11', 'Cash Drawer']),
  _HwItem('tablet', ['Tablette / KDS', 'تابلت / KDS', 'Tablet / KDS']),
];

class _FeatItem {
  final String key;
  final StoreModule? module;
  final List<String> label;
  const _FeatItem(this.key, this.module, this.label);
}

const List<_FeatItem> _featureList = [
  _FeatItem('kds', StoreModule.resto, ['Écran cuisine KDS', 'شاشة المطبخ KDS', 'Kitchen KDS']),
  _FeatItem('khaima', StoreModule.resto, ['Plan Khaima VIP', 'مخطط الخيمة VIP', 'Khaima VIP plan']),
  _FeatItem('tablet', StoreModule.resto, ['Tablette serveur', 'تابلت النادل', 'Waiter tablet']),
  _FeatItem('split', StoreModule.resto, ['Division de note', 'تقسيم الفاتورة', 'Split bill']),
  _FeatItem('scale', StoreModule.market, ['Balance COM1', 'ميزان COM1', 'COM1 Scale']),
  _FeatItem('barcode', StoreModule.market, ['Scanner EAN-13', 'باركود EAN-13', 'EAN-13 Scan']),
  _FeatItem('wholesale', StoreModule.market, ['Détail / Demi-gros', 'تجزئة / نصف جملة', 'Retail / Wholesale']),
  _FeatItem('karni', StoreModule.market, ['Carnet Karni', 'دفتر كارني', 'Karni Credit']),
  _FeatItem('fefo', StoreModule.pharma, ['Lots FEFO & blocage', 'دفعات FEFO ومنع المنتهي', 'FEFO & Expiry block']),
  _FeatItem('cnam', StoreModule.pharma, ['Tiers-payant CNAM', 'تأمين CNAM', 'CNAM Insurance']),
  _FeatItem('cold', StoreModule.pharma, ['Chaîne froid +4°C', 'سلسلة التبريد +4°C', 'Cold chain +4°C']),
  _FeatItem('generic', StoreModule.pharma, ['Équivalents génériques', 'البدائل الجنيسة', 'Generics']),
  _FeatItem('boss', null, ['App Mobile Boss', 'تطبيق المدير Boss', 'Boss Mobile App']),
  _FeatItem('offline', null, ['Mode hors-ligne', 'بدون إنترنت', 'Offline mode']),
  _FeatItem('lan', null, ['Synchro LAN locale', 'مزامنة محلية LAN', 'Local LAN sync']),
  _FeatItem('printer', null, ['Ticket 80mm FR/AR', 'فاتورة 80 ملم', '80mm FR/AR Ticket']),
];

const List<String> _cities = [
  'Tevragh Zeina', 'Ksar', 'Arafat', 'Sebkha', 'Dar Naim',
  'Toujounine', 'Teyarett', 'Nouadhibou', 'Atar', 'Rosso', 'Kiffa', 'Zouérate',
];

const Map<String, String> _themes = {
  '01': '01 · Émeraude',
  '04': '04 · Aurora',
  '06': '06 · Ocean',
  '07': '07 · Mauritanie',
  '11': '11 · Nordic',
};

class _Plan {
  final String key;
  final String name;
  final int price;
  final int tills;
  const _Plan(this.key, this.name, this.price, this.tills);
}

const List<_Plan> _plans = [
  _Plan('start', 'Start', 1500, 1),
  _Plan('pro', 'Pro', 3000, 4),
  _Plan('ent', 'Entreprise', 5500, 10),
];

class _NewStoreWizardState extends State<NewStoreWizard> {
  int _step = 0;
  bool _forward = true;
  bool _done = false;
  TenantStore? _created;

  StoreModule _mod = StoreModule.resto;
  int _subIdx = 0;
  final _formStep1 = GlobalKey<FormState>();

  final _tradeCtrl = TextEditingController();
  final _mgrCtrl = TextEditingController();
  final _waCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _legalCtrl = TextEditingController();
  final _nifCtrl = TextEditingController();
  final _rcCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _payRefCtrl = TextEditingController();

  bool _userEdited = false;
  bool _obscurePw = false;

  String _city = 'Tevragh Zeina';
  late String _regLang = widget.lang;

  String _planKey = 'pro';
  bool _yearly = false;
  bool _trial = false;
  int _tills = 4;
  String _initialPay = 'Bankily';

  late Set<String> _hwSel = _defaultHw(StoreModule.resto);
  late Set<String> _featSel = _defaultFeatures(StoreModule.resto);
  final Set<String> _paySel = {'Bankily', 'Masrivi', 'Sedad', 'Cash'};
  final Set<String> _themesSel = {'01', '06', '07', '11'};

  String _tenantId = '';
  String _username = '';
  String _tempPw = '';
  String _pin = '';
  String _offCode = '';

  String t(String k) => _wizStrings[widget.lang]?[k] ?? _wizStrings['fr']![k] ?? k;
  int get _lIdx => widget.lang == 'ar' ? 1 : (widget.lang == 'en' ? 2 : 0);

  Set<String> _defaultFeatures(StoreModule m) => {
        for (final f in _featureList)
          if (f.module == null || f.module == m) f.key,
      };

  Set<String> _defaultHw(StoreModule m) {
    switch (m) {
      case StoreModule.resto:
        return {'printer', 'tablet'};
      case StoreModule.market:
        return {'printer', 'scanner', 'scale', 'drawer'};
      case StoreModule.pharma:
        return {'printer', 'scanner', 'drawer'};
    }
  }

  _Plan get _plan => _plans.firstWhere((p) => p.key == _planKey);
  int get _extraTills => math.max(0, _tills - _plan.tills);
  int get _monthly {
    if (_trial) return 0;
    final base = _yearly ? (_plan.price * 0.8).round() : _plan.price;
    return base + _extraTills * 400;
  }

  int get _dueNow => _trial ? 0 : (_yearly ? _monthly * 12 : _monthly);

  Color get _accent {
    switch (_mod) {
      case StoreModule.resto:
        return FTColors.resto;
      case StoreModule.market:
        return FTColors.market;
      case StoreModule.pharma:
        return FTColors.pharma;
    }
  }

  String _genPassword() {
    final rnd = math.Random();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
    return List.generate(8, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  @override
  void initState() {
    super.initState();
    _passCtrl.text = _genPassword();
    _pinCtrl.text = '${1000 + math.Random().nextInt(9000)}';
    _tradeCtrl.addListener(() {
      if (_userEdited) return;
      final slug = _tradeCtrl.text
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '');
      if (slug.isNotEmpty) {
        _userCtrl.text = slug.substring(0, math.min(slug.length, 14));
      }
    });
  }

  @override
  void dispose() {
    for (final c in [
      _tradeCtrl, _mgrCtrl, _waCtrl, _userCtrl, _passCtrl, _pinCtrl,
      _districtCtrl, _legalCtrl, _nifCtrl, _rcCtrl, _emailCtrl,
      _addrCtrl, _notesCtrl, _payRefCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _next() {
    if (_step == 0 && !(_formStep1.currentState?.validate() ?? false)) return;
    if (_step < 2) {
      setState(() {
        _forward = true;
        _step++;
      });
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() {
        _forward = false;
        _step--;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  void _activate() {
    final rnd = math.Random();
    final cleanSlug = _tradeCtrl.text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '');
    final prefix = cleanSlug.isEmpty
        ? 'client'
        : cleanSlug.substring(0, math.min(cleanSlug.length, 10));

    _tenantId = 'FT-${1000 + rnd.nextInt(9000)}';
    _username = _userCtrl.text.trim().isNotEmpty
        ? _userCtrl.text.trim()
        : '$prefix${10 + rnd.nextInt(90)}';
    _tempPw = _passCtrl.text.trim().isNotEmpty ? _passCtrl.text.trim() : _genPassword();
    _pin = _pinCtrl.text.trim().length == 4
        ? _pinCtrl.text.trim()
        : '${1000 + rnd.nextInt(9000)}';
    _offCode = '${1000 + rnd.nextInt(9000)}-${1000 + rnd.nextInt(9000)}';

    final s = TenantStore(
      id: DateTime.now().millisecondsSinceEpoch,
      name: _tradeCtrl.text.trim(),
      module: _mod,
      city: _city,
      phone: '+222 ${_waCtrl.text.trim()}',
      plan: _trial ? 'Essai 15j' : _plan.name,
      mrr: _monthly,
      tills: _tills,
      daysLeft: _trial ? 15 : (_yearly ? 365 : 30),
      status: _trial ? StoreStatus.trial : StoreStatus.active,
      enabledThemes: _themesSel.toList()..sort(),
      ownerPin: _pin,
    )
      ..subType = _subTypes[_mod]![_subIdx][0]
      ..manager = _mgrCtrl.text.trim()
      ..district = _districtCtrl.text.trim()
      ..legalName = _legalCtrl.text.trim()
      ..nif = _nifCtrl.text.trim()
      ..rc = _rcCtrl.text.trim()
      ..email = _emailCtrl.text.trim()
      ..address = _addrCtrl.text.trim()
      ..notes = _notesCtrl.text.trim()
      ..billing = _yearly ? 'yearly' : 'monthly'
      ..tenantId = _tenantId
      ..username = _username
      ..accountPassword = _tempPw
      ..defaultLang = _regLang
      ..features = Set<String>.from(_featSel)
      ..payMethods = Set<String>.from(_paySel)
      ..hardware = Set<String>.from(_hwSel)
      ..initialPayMethod = _trial ? '' : (_initialPay == 'later' ? '' : _initialPay)
      ..initialPayRef = _trial ? '' : _payRefCtrl.text.trim()
      ..initialOfflineCode = _offCode;

    setState(() {
      _created = s;
      _done = true;
    });
  }

  String _accessMessage() {
    return t('msg')
        .replaceAll('{mgr}', _mgrCtrl.text.trim())
        .replaceAll('{mod}', 'Full·Tek ${t('mod_${_mod.name}')}')
        .replaceAll('{name}', _tradeCtrl.text.trim())
        .replaceAll('{id}', _tenantId)
        .replaceAll('{user}', _username)
        .replaceAll('{pw}', _tempPw)
        .replaceAll('{pin}', _pin)
        .replaceAll('{off}', _offCode);
  }

  void _sendWhatsApp() {
    final msg = _accessMessage();
    Clipboard.setData(ClipboardData(text: msg));
    final digits = '222${_waCtrl.text.trim().replaceAll(RegExp(r'\D'), '')}';
    final url = 'https://wa.me/$digits?text=${Uri.encodeComponent(msg)}';
    if (canOpenUrlDirectly) {
      openExternalUrl(url);
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t('copied'))));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_done,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _done) Navigator.of(context).pop(_created);
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: FTColors.night,
          leading: _done
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
          title: Text(
            t('title'),
            style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
          ),
          bottom: _done
              ? null
              : PreferredSize(
                  preferredSize: const Size.fromHeight(62),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                        child: _buildStepper(),
                      ),
                    ),
                  ),
                ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) {
                final dir = _forward ? 1.0 : -1.0;
                final isRtl = Directionality.of(context) == TextDirection.rtl;
                final dx = (isRtl ? -dir : dir) * 0.1;
                return FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween(begin: Offset(dx, 0), end: Offset.zero).animate(anim),
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey(_done ? 'done' : 's$_step'),
                child: _done ? _buildSuccess() : _buildStep(),
              ),
            ),
          ),
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildStepper() {
    final steps = [t('s1'), t('s2'), t('s3')];
    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final idx = i ~/ 2;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              height: 2.5,
              margin: const EdgeInsets.only(bottom: 16, left: 6, right: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                color: idx < _step ? _accent : Colors.white12,
              ),
            ),
          );
        }
        final n = i ~/ 2;
        final active = n == _step;
        final passed = n < _step;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: passed
                    ? _accent
                    : (active ? _accent.withValues(alpha: 0.22) : Colors.white10),
                border: Border.all(
                  color: active || passed ? _accent : Colors.white24,
                  width: 1.6,
                ),
              ),
              child: Center(
                child: passed
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : Text(
                        '${n + 1}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: active ? Colors.white : FTColors.muted,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              steps[n],
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : FTColors.muted,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: FTColors.night,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Center(
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Row(
            children: [
          if (!_done && _step > 0) ...[
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: _back,
                  child: Text(t('back'), style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 50,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _done ? FTColors.market : FTColors.ochre,
                  foregroundColor: const Color(0xFF101916),
                ),
                onPressed: _done
                    ? () => Navigator.of(context).pop(_created)
                    : (_step == 2 ? _activate : _next),
                icon: Icon(
                  _done
                      ? Icons.check_circle
                      : (_step == 2 ? Icons.rocket_launch : Icons.arrow_forward),
                ),
                label: Text(
                  _done ? t('finish') : (_step == 2 ? t('create') : t('next')),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ),
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      default:
        return _buildStep3();
    }
  }

  InputDecoration _dec(String label, {IconData? icon, String? prefix}) => InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon, size: 19, color: FTColors.muted),
        prefixText: prefix,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _accent, width: 1.6),
        ),
      );

  // =========================================================================
  // ÉTAPE 1 : ACTIVITÉ, COMMERCE & GÉRANT (RAPIDE + ACCORDÉON ADMIN)
  // =========================================================================
  Widget _buildStep1() {
    String? req(String? v) => (v == null || v.trim().isEmpty) ? t('req') : null;
    final mods = [
      (StoreModule.resto, Icons.restaurant, FTColors.resto),
      (StoreModule.market, Icons.shopping_cart_outlined, FTColors.market),
      (StoreModule.pharma, Icons.local_pharmacy_outlined, FTColors.pharma),
    ];
    final subs = _subTypes[_mod]!;

    return Form(
      key: _formStep1,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(t('s1_h'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(t('s1_sub'), style: const TextStyle(fontSize: 12, color: FTColors.muted)),
          const SizedBox(height: 12),

          // 3 Module Cards Row
          Row(
            children: mods.map((m) {
              final sel = _mod == m.$1;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => setState(() {
                      _mod = m.$1;
                      _subIdx = 0;
                      _featSel = _defaultFeatures(m.$1);
                      _hwSel = _defaultHw(m.$1);
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: sel ? m.$3.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.04),
                        border: Border.all(color: sel ? m.$3 : Colors.white12, width: sel ? 1.8 : 1),
                      ),
                      child: Column(
                        children: [
                          Icon(m.$2, color: sel ? m.$3 : FTColors.muted, size: 24),
                          const SizedBox(height: 6),
                          Text(
                            t('mod_${m.$1.name}'),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: sel ? Colors.white : FTColors.ink2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(subs.length, (i) {
              return ChoiceChip(
                label: Text(subs[i][_lIdx], style: const TextStyle(fontSize: 12)),
                selected: _subIdx == i,
                selectedColor: _accent.withValues(alpha: 0.25),
                onSelected: (_) => setState(() => _subIdx = i),
              );
            }),
          ),
          const SizedBox(height: 16),

          // Champs essentiels
          TextFormField(
            controller: _tradeCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: _dec(t('trade'), icon: Icons.storefront_outlined),
            validator: req,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _mgrCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: _dec(t('mgr'), icon: Icons.person_outline),
            validator: req,
          ),
          const SizedBox(height: 12),
          Directionality(
            textDirection: TextDirection.ltr,
            child: TextFormField(
              controller: _waCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
              decoration: _dec(t('wa'), icon: Icons.chat_outlined, prefix: '+222 '),
              validator: (v) => (v == null || v.trim().length != 8) ? t('phone_bad') : null,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _city,
                  isExpanded: true,
                  dropdownColor: FTColors.night2,
                  decoration: _dec(t('city'), icon: Icons.location_city_outlined),
                  items: _cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _city = v);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _districtCtrl,
                  decoration: _dec(t('district')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Compte de connexion client (Identifiant + Mot de passe + PIN)
          GlassCard(
            borderColor: FTColors.ochre.withValues(alpha: 0.4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.vpn_key_outlined, color: FTColors.ochre, size: 19),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(t('acc_h'),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: TextFormField(
                    controller: _userCtrl,
                    onChanged: (_) => _userEdited = true,
                    decoration: _dec(t('acc_login'), icon: Icons.alternate_email),
                    validator: req,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: TextFormField(
                          controller: _passCtrl,
                          obscureText: _obscurePw,
                          decoration: _dec(t('acc_pw'), icon: Icons.lock_outline).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePw ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                size: 19,
                              ),
                              onPressed: () => setState(() => _obscurePw = !_obscurePw),
                            ),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().length < 6) ? t('acc_pw_bad') : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 54,
                      child: FilledButton.tonalIcon(
                        onPressed: () => setState(() => _passCtrl.text = _genPassword()),
                        icon: const Icon(Icons.autorenew, size: 18),
                        label: Text(t('acc_gen'), style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: TextFormField(
                    controller: _pinCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: _dec(t('acc_pin'), icon: Icons.dialpad),
                    validator: (v) => (v == null || v.trim().length != 4) ? t('acc_pin_bad') : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Accordéon Administratif optionnel (propre, ne bloque jamais)
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                border: Border.all(color: Colors.white12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                leading: const Icon(Icons.folder_shared_outlined, color: FTColors.ochre),
                title: Text(t('adm_exp'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                subtitle: Text(t('adm_sub'), style: const TextStyle(fontSize: 11, color: FTColors.muted)),
                childrenPadding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                children: [
                  TextFormField(controller: _legalCtrl, decoration: _dec(t('legal'))),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _nifCtrl,
                          keyboardType: TextInputType.number,
                          decoration: _dec(t('nif')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: TextFormField(controller: _rcCtrl, decoration: _dec(t('rc')))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _dec(t('email')),
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.isEmpty) return null;
                        return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s) ? null : t('email_bad');
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(controller: _addrCtrl, decoration: _dec(t('address'))),
                  const SizedBox(height: 10),
                  TextFormField(controller: _notesCtrl, maxLines: 2, decoration: _dec(t('notes'))),
                  const SizedBox(height: 12),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(t('lang'), style: const TextStyle(fontSize: 12, color: FTColors.muted)),
                  ),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'fr', label: Text('FR')),
                      ButtonSegment(value: 'ar', label: Text('العربية')),
                      ButtonSegment(value: 'en', label: Text('EN')),
                    ],
                    selected: {_regLang},
                    onSelectionChanged: (s) => setState(() => _regLang = s.first),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // ÉTAPE 2 : LICENCE, PAIEMENT INITIAL, MATÉRIEL & OPTIONS
  // =========================================================================
  Widget _buildStep2() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(t('s2_h'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),

        // Essai 15j Switch
        GlassCard(
          borderColor: _trial ? FTColors.pharma.withValues(alpha: 0.6) : null,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _trial,
            onChanged: (v) => setState(() => _trial = v),
            title: Text(t('trial_h'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            subtitle: Text(t('trial_d'), style: const TextStyle(fontSize: 11.5)),
          ),
        ),
        const SizedBox(height: 12),

        if (!_trial) ...[
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text(t('billing_m'))),
              ButtonSegment(value: true, label: Text(t('billing_y'))),
            ],
            selected: {_yearly},
            onSelectionChanged: (s) => setState(() => _yearly = s.first),
          ),
          const SizedBox(height: 12),
          ..._plans.map((p) {
            final sel = _planKey == p.key;
            final price = _yearly ? (p.price * 0.8).round() : p.price;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => setState(() {
                  _planKey = p.key;
                  if (_tills < p.tills) _tills = p.tills;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: sel ? FTColors.ochre.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.04),
                    border: Border.all(color: sel ? FTColors.ochre : Colors.white12, width: sel ? 1.8 : 1),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        sel ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: sel ? FTColors.ochre : FTColors.muted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t('plan_${p.key}'),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                            Text(t('plan_${p.key}_d'),
                                style: const TextStyle(fontSize: 11.5, color: FTColors.muted)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              formatMru(price),
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: FTColors.ochre),
                            ),
                          ),
                          Text('${t('cur')} / ${t('perm')}',
                              style: const TextStyle(fontSize: 10, color: FTColors.muted)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 6),
        ],

        // Nombre de caisses
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.point_of_sale, color: FTColors.ochre),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('tills'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                    if (!_trial && _extraTills > 0)
                      Text('+$_extraTills ${t('extra')} × 400 ${t('cur')}',
                          style: const TextStyle(fontSize: 11, color: FTColors.warn, fontWeight: FontWeight.w700))
                    else
                      Text('${_plan.tills} ${t('incl')}',
                          style: const TextStyle(fontSize: 11, color: FTColors.muted)),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: _tills > 1 ? () => setState(() => _tills--) : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 32,
                child: Center(
                  child: Text('$_tills', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                ),
              ),
              IconButton.filledTonal(
                onPressed: _tills < 20 ? () => setState(() => _tills++) : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Règlement initial (si payant)
        if (!_trial) ...[
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('pay_now_h'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final m in ['Bankily', 'Masrivi', 'Sedad', 'Cash', 'later'])
                      ChoiceChip(
                        label: Text(m == 'later' ? t('pay_later') : m, style: const TextStyle(fontSize: 12)),
                        selected: _initialPay == m,
                        selectedColor: FTColors.ochre.withValues(alpha: 0.25),
                        onSelected: (_) => setState(() => _initialPay = m),
                      ),
                  ],
                ),
                if (_initialPay != 'later' && _initialPay != 'Cash') ...[
                  const SizedBox(height: 10),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: TextField(
                      controller: _payRefCtrl,
                      decoration: _dec(t('pay_ref'), icon: Icons.receipt_outlined),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Matériel installé
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t('hw_h'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _hardwareList.map((hw) {
                  return FilterChip(
                    label: Text(hw.label[_lIdx], style: const TextStyle(fontSize: 12)),
                    selected: _hwSel.contains(hw.key),
                    selectedColor: _accent.withValues(alpha: 0.25),
                    onSelected: (v) => setState(() => v ? _hwSel.add(hw.key) : _hwSel.remove(hw.key)),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Accordéon Options POS avancées
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              border: Border.all(color: Colors.white12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              leading: Icon(Icons.tune, color: _accent),
              title: Text(t('adv_exp'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
              subtitle: Text(t('adv_sub'), style: const TextStyle(fontSize: 11, color: FTColors.muted)),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(t('feat_h'), style: const TextStyle(fontSize: 12, color: FTColors.muted)),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _featureList
                      .where((f) => f.module == null || f.module == _mod)
                      .map((f) => FilterChip(
                            label: Text(f.label[_lIdx], style: const TextStyle(fontSize: 11.5)),
                            selected: _featSel.contains(f.key),
                            selectedColor: _accent.withValues(alpha: 0.25),
                            onSelected: (v) => setState(
                              () => v ? _featSel.add(f.key) : _featSel.remove(f.key),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(t('pay_h'), style: const TextStyle(fontSize: 12, color: FTColors.muted)),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: ['Bankily', 'Masrivi', 'Sedad', 'Cash', 'Karni'].map((p) {
                    return FilterChip(
                      label: Text(p, style: const TextStyle(fontSize: 11.5)),
                      selected: _paySel.contains(p),
                      onSelected: (v) => setState(() {
                        if (v) {
                          _paySel.add(p);
                        } else if (_paySel.length > 1) {
                          _paySel.remove(p);
                        }
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(t('themes_h'), style: const TextStyle(fontSize: 12, color: FTColors.muted)),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _themes.entries.map((e) {
                    return FilterChip(
                      label: Text(e.value, style: const TextStyle(fontSize: 11.5)),
                      selected: _themesSel.contains(e.key),
                      selectedColor: FTColors.ochre.withValues(alpha: 0.22),
                      onSelected: (v) => setState(() {
                        if (v) {
                          _themesSel.add(e.key);
                        } else if (_themesSel.length > 1) {
                          _themesSel.remove(e.key);
                        }
                      }),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // ÉTAPE 3 : RÉCAPITULATIF COMPLET AVANT ACTIVATION
  // =========================================================================
  Widget _buildStep3() {
    Widget row(String k, String v, {bool ltr = false, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: Text(k, style: const TextStyle(fontSize: 12.5, color: FTColors.muted))),
              Expanded(
                flex: 6,
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: ltr
                      ? Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(v, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
                        )
                      : Text(v,
                          textAlign: TextAlign.end,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
                ),
              ),
            ],
          ),
        );

    final hwNames = _hardwareList
        .where((h) => _hwSel.contains(h.key))
        .map((h) => h.label[_lIdx])
        .join(' · ');
    final paySummary = _trial
        ? t('sum_trial')
        : (_initialPay == 'later'
            ? t('pay_later')
            : '$_initialPay${_payRefCtrl.text.trim().isNotEmpty ? ' (${_payRefCtrl.text.trim()})' : ''}');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(t('s3_h'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        GlassCard(
          borderColor: _accent.withValues(alpha: 0.55),
          child: Column(
            children: [
              row(t('sum_biz'), '${_tradeCtrl.text.trim()} · $_city'),
              row(t('sum_mgr'), _mgrCtrl.text.trim()),
              row('WhatsApp', '+222 ${_waCtrl.text.trim()}', ltr: true),
              row(t('username'), _userCtrl.text.trim(), ltr: true),
              row(t('temp_pw'), _passCtrl.text.trim(), ltr: true, color: FTColors.ochre),
              row(t('pin'), _pinCtrl.text.trim(), ltr: true),
              row(t('sum_mod'), 'Full·Tek ${t('mod_${_mod.name}')} · ${_subTypes[_mod]![_subIdx][_lIdx]}'),
              const Divider(color: Colors.white10),
              row(
                t('sum_plan'),
                _trial ? t('sum_trial') : '${t('plan_${_plan.key}')} · ${_yearly ? t('billing_y') : t('billing_m')}',
              ),
              row(t('sum_tills'), '$_tills', ltr: true),
              row(t('sum_pay'), paySummary),
              if (hwNames.isNotEmpty) row(t('sum_hw'), hwNames),
              const Divider(color: Colors.white10),
              row(t('sum_monthly'), '${formatMru(_monthly)} ${t('cur')}', ltr: true, color: FTColors.ochre),
              row(t('sum_first'), '${formatMru(_dueNow)} ${t('cur')}', ltr: true, color: FTColors.greenOk),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // SUCCÈS : CARTE D'ACCÈS + CODE OFFLINE + ENVOI WHATSAPP DIRECT
  // =========================================================================
  Widget _buildSuccess() {
    Widget cred(String label, String val, {bool big = false}) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: FTColors.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: FTColors.muted))),
              Directionality(
                textDirection: TextDirection.ltr,
                child: SelectableText(
                  val,
                  style: TextStyle(
                    fontSize: big ? 20 : 14.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: big ? 3 : 0.4,
                    color: FTColors.ochre,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.copy, size: 17),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: val));
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(content: Text(val)));
                },
              ),
            ],
          ),
        );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 650),
            curve: Curves.elasticOut,
            builder: (context, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: FTColors.market.withValues(alpha: 0.2),
                border: Border.all(color: FTColors.greenOk, width: 2),
                boxShadow: [BoxShadow(color: FTColors.market.withValues(alpha: 0.4), blurRadius: 28)],
              ),
              child: const Icon(Icons.check_rounded, color: FTColors.greenOk, size: 44),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(child: Text(t('done_h'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900))),
        const SizedBox(height: 3),
        Center(
          child: Text(_tradeCtrl.text.trim(),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _accent)),
        ),
        const SizedBox(height: 6),
        Text(t('done_sub'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: FTColors.muted)),
        const SizedBox(height: 14),
        cred(t('tenant_id'), _tenantId),
        cred(t('username'), _username),
        cred(t('temp_pw'), _tempPw),
        cred(t('pin'), _pin, big: true),
        cred(t('off_code'), _offCode),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _accessMessage()));
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(content: Text(t('copied'))));
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text(t('copy_msg'), overflow: TextOverflow.ellipsis),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 48,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: FTColors.market, foregroundColor: Colors.white),
                  onPressed: _sendWhatsApp,
                  icon: const Icon(Icons.chat, size: 18),
                  label: Text(t('send_wa'), overflow: TextOverflow.ellipsis),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
