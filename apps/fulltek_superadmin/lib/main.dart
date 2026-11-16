import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/models.dart';
import 'screens/new_store_wizard.dart';
import 'screens/store_detail_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FullTekSuperAdminApp());
}

class FullTekSuperAdminApp extends StatefulWidget {
  const FullTekSuperAdminApp({super.key});

  @override
  State<FullTekSuperAdminApp> createState() => _FullTekSuperAdminAppState();
}

class _FullTekSuperAdminAppState extends State<FullTekSuperAdminApp> {
  String _lang = 'fr';
  bool _phoneFrameOnDesktop = true;

  String tr(String key) => kStrings[_lang]?[key] ?? kStrings['fr']![key] ?? key;

  @override
  Widget build(BuildContext context) {
    final isRtl = _lang == 'ar';
    return MaterialApp(
      title: 'Full·Tek Control — Super Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: ThemeMode.dark,
      builder: (context, child) {
        return Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 560;
              if (!isWide || !_phoneFrameOnDesktop) {
                return Stack(
                  children: [
                    child!,
                    if (isWide)
                      Positioned(
                        top: 14,
                        right: 16,
                        child: _FrameToggleBtn(
                          framed: _phoneFrameOnDesktop,
                          onToggle: () => setState(
                            () => _phoneFrameOnDesktop = !_phoneFrameOnDesktop,
                          ),
                        ),
                      ),
                  ],
                );
              }
              return Scaffold(
                backgroundColor: const Color(0xFF050B0E),
                body: Stack(
                  children: [
                    // Ambient Orbs
                    Positioned(
                      top: -100,
                      left: -80,
                      child: _GlowOrb(
                        size: 420,
                        color: FTColors.petrol.withValues(alpha: 0.45),
                      ),
                    ),
                    Positioned(
                      bottom: -120,
                      right: -60,
                      child: _GlowOrb(
                        size: 380,
                        color: FTColors.ochre.withValues(alpha: 0.18),
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Container(
                          width: 430,
                          height: math.min(constraints.maxHeight - 32, 900),
                          decoration: BoxDecoration(
                            color: FTColors.bg,
                            borderRadius: BorderRadius.circular(44),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.16),
                              width: 3,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0xCC000000),
                                blurRadius: 60,
                                spreadRadius: 4,
                                offset: Offset(0, 24),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(41),
                            child: child!,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 18,
                      right: 20,
                      child: _FrameToggleBtn(
                        framed: _phoneFrameOnDesktop,
                        onToggle: () => setState(
                          () => _phoneFrameOnDesktop = !_phoneFrameOnDesktop,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
      home: SuperAdminHome(
        lang: _lang,
        tr: tr,
        onLangChanged: (l) => setState(() => _lang = l),
      ),
    );
  }
}

class _FrameToggleBtn extends StatelessWidget {
  final bool framed;
  final VoidCallback onToggle;

  const _FrameToggleBtn({required this.framed, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FTColors.night2.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                framed ? Icons.fullscreen : Icons.phone_iphone,
                size: 16,
                color: FTColors.ochre,
              ),
              const SizedBox(width: 6),
              Text(
                framed ? 'Plein écran' : 'Châssis Mobile',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, Colors.transparent]),
        ),
      ),
    );
  }
}

class SuperAdminHome extends StatefulWidget {
  final String lang;
  final String Function(String) tr;
  final ValueChanged<String> onLangChanged;

  const SuperAdminHome({
    super.key,
    required this.lang,
    required this.tr,
    required this.onLangChanged,
  });

  @override
  State<SuperAdminHome> createState() => _SuperAdminHomeState();
}

class _SuperAdminHomeState extends State<SuperAdminHome>
    with TickerProviderStateMixin {
  late final AnimationController _splashCtrl;
  late final AnimationController _orbitCtrl;
  bool _showSplash = !kIsWeb;

  int _tabIndex = 0;
  String _filter = 'all';
  String _searchQuery = '';
  int _selectedMonth = 5;

  final List<TenantStore> _stores = initialStores();
  final List<SubscriptionPayment> _payments = initialPayments();
  final List<AuditEntry> _audits = initialAudit();

  int _selectedOfflineStoreId = 1;
  int _selectedOfflineDays = 30;
  String? _generatedCode;

  static const List<Map<String, dynamic>> _months = [
    {'m': 'Juin', 'v': 265000},
    {'m': 'Juil', 'v': 310000},
    {'m': 'Août', 'v': 348000},
    {'m': 'Sept', 'v': 392000},
    {'m': 'Oct', 'v': 438000},
    {'m': 'Nov', 'v': 482500},
  ];

  @override
  void initState() {
    super.initState();
    _splashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
    );
    _orbitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (_showSplash) {
      _splashCtrl.forward();
      _orbitCtrl.repeat();
      Future.delayed(const Duration(milliseconds: 1650), () {
        if (mounted) {
          _orbitCtrl.stop();
          setState(() => _showSplash = false);
        }
      });
    }
  }

  @override
  void dispose() {
    _splashCtrl.dispose();
    _orbitCtrl.dispose();
    super.dispose();
  }

  String t(String k) => widget.tr(k);

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: FTColors.greenOk, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(msg)),
            ],
          ),
        ),
      );
  }

  void _logAudit(String title, String sub) {
    final now = TimeOfDay.now();
    final hm =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    setState(() {
      _audits.insert(0, AuditEntry(title: title, subtitle: sub, time: hm));
    });
  }

  void _extendStore(TenantStore s, {int days = 30}) {
    setState(() {
      s.daysLeft += days;
      s.status = StoreStatus.active;
    });
    _logAudit('Licence +${days}j · ${s.name}', 'M. Taha · Prolongation Cloud');
    _toast('${s.name} : +$days jours activés');
  }

  void _toggleLock(TenantStore s) {
    setState(() {
      if (s.status == StoreStatus.locked) {
        s.status = s.daysLeft > 5 ? StoreStatus.active : StoreStatus.warn;
        _logAudit('Réactivation · ${s.name}', 'M. Taha · Déverrouillage Cloud');
        _toast('${s.name} réactivé');
      } else {
        s.status = StoreStatus.locked;
        _logAudit('Suspension · ${s.name}', 'M. Taha · Verrouillage distant');
        _toast('${s.name} suspendu à distance');
      }
    });
  }

  void _approvePayment(SubscriptionPayment p) {
    setState(() {
      _payments.removeWhere((x) => x.id == p.id);
      for (final s in _stores) {
        if (s.id == p.storeId) {
          s.daysLeft += 30;
          s.status = StoreStatus.active;
        }
      }
    });
    _logAudit(
      'Paiement ${p.method} · ${p.storeName}',
      'Réf. ${p.ref} · +${formatMru(p.amount)} MRU',
    );
    _toast('Paiement ${p.method} validé (+30j)');
  }

  void _generateOfflineCode() {
    final s = _stores.firstWhere(
      (x) => x.id == _selectedOfflineStoreId,
      orElse: () => _stores.first,
    );
    final rnd = math.Random();
    final p1 = 1000 + ((s.id * 1731 + _selectedOfflineDays * 47 + rnd.nextInt(900)) % 9000);
    final p2 = 1000 + ((s.id * 2917 + _selectedOfflineDays * 83 + rnd.nextInt(900)) % 9000);
    final code = '$p1-$p2';
    setState(() => _generatedCode = code);
    _logAudit(
      'Code Offline $code · ${s.name}',
      '+$_selectedOfflineDays jours sans Internet',
    );
    _toast('Code $code généré pour ${s.name}');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(76),
            child: _buildTopBar(),
          ),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: KeyedSubtree(
              key: ValueKey<int>(_tabIndex),
              child: _buildCurrentTab(),
            ),
          ),
          bottomNavigationBar: NavigationBar(
            height: 68,
            selectedIndex: _tabIndex,
            onDestinationSelected: (i) => setState(() => _tabIndex = i),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.space_dashboard_outlined),
                selectedIcon: const Icon(Icons.space_dashboard),
                label: t('nav_home'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.storefront_outlined),
                selectedIcon: const Icon(Icons.storefront),
                label: t('nav_stores'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.verified_user_outlined),
                selectedIcon: const Icon(Icons.verified_user),
                label: t('nav_pay'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.router_outlined),
                selectedIcon: const Icon(Icons.router),
                label: t('nav_fleet'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.shield_outlined),
                selectedIcon: const Icon(Icons.shield),
                label: t('nav_audit'),
              ),
            ],
          ),
        ),
        if (_showSplash) _buildSplashOverlay(),
      ],
    );
  }

  Widget _buildSplashOverlay() {
    return AnimatedBuilder(
      animation: Listenable.merge([_splashCtrl, _orbitCtrl]),
      builder: (context, _) {
        final v = _splashCtrl.value;
        return Opacity(
          opacity: v > 0.85 ? ((1.0 - v) / 0.15).clamp(0.0, 1.0) : 1.0,
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.16),
                radius: 0.95,
                colors: [Color(0xFF17303A), Color(0xFF0B161B)],
              ),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    CustomPaint(
                      size: const Size(128, 128),
                      painter: _OrbitRingPainter(angle: _orbitCtrl.value * 2 * math.pi),
                    ),
                    Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0x8C264653), Color(0xE60F1B20)],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: FTColors.ochre.withValues(alpha: 0.45),
                          width: 1.2,
                        ),
                        boxShadow: [
                          const BoxShadow(
                            color: Color(0x99000000),
                            blurRadius: 50,
                            offset: Offset(0, 24),
                          ),
                          BoxShadow(
                            color: FTColors.ochre.withValues(alpha: 0.22),
                            blurRadius: 40,
                          ),
                        ],
                      ),
                      child: Center(
                        child: FullTekPillsLogo(size: 62, progress: v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text.rich(
                    TextSpan(
                      text: 'Full·Tek ',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                      children: [
                        TextSpan(
                          text: 'Control',
                          style: TextStyle(color: FTColors.ochre),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  t('sp_sub'),
                  style: const TextStyle(fontSize: 12.5, color: FTColors.muted),
                ),
                const SizedBox(height: 18),
                Container(
                  width: 190,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: v.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        gradient: const LinearGradient(
                          colors: [FTColors.ochre, FTColors.market],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 6,
        left: 14,
        right: 14,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        color: FTColors.night.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: FTColors.night2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: FTColors.ochre.withValues(alpha: 0.45)),
            ),
            child: const Center(child: FullTekPillsLogo(size: 24)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text.rich(
                    TextSpan(
                      text: 'Full·Tek ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                      children: [
                        TextSpan(
                          text: 'Control',
                          style: TextStyle(color: FTColors.ochre),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: FTColors.greenOk,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        t('cloud_ok'),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: FTColors.greenOk,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Language Switcher FR | AR | EN
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: ['fr', 'ar', 'en'].map((code) {
                final active = widget.lang == code;
                return GestureDetector(
                  onTap: () => widget.onLangChanged(code),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: active ? FTColors.petrol : Colors.transparent,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      code.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: active ? Colors.white : FTColors.muted,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: 8),
          // + New Store Quick Button
          Material(
            color: FTColors.ochre,
            borderRadius: BorderRadius.circular(13),
            child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: _openCreateStoreModal,
              child: const SizedBox(
                width: 42,
                height: 42,
                child: Icon(Icons.add, color: Color(0xFF101916), size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_tabIndex) {
      case 0:
        return _buildCockpitTab();
      case 1:
        return _buildStoresTab();
      case 2:
        return _buildLicensesTab();
      case 3:
        return _buildFleetTab();
      case 4:
        return _buildAuditTab();
      default:
        return _buildCockpitTab();
    }
  }

  // ===========================================================================
  // TAB 1 : COCKPIT MRR
  // ===========================================================================
  Widget _buildCockpitTab() {
    final activeCnt = _stores.where((s) => s.status == StoreStatus.active).length;
    final trialCnt = _stores.where((s) => s.status == StoreStatus.trial).length;
    final warnCnt = _stores
        .where((s) => s.status == StoreStatus.warn || (s.status == StoreStatus.active && s.daysLeft <= 5))
        .length;
    final expCnt = _stores
        .where((s) => s.status == StoreStatus.expired || s.status == StoreStatus.locked)
        .length;
    final totalMrr = 465000 +
        _stores
            .where((s) => s.status != StoreStatus.expired && s.status != StoreStatus.locked)
            .fold<int>(0, (sum, s) => sum + s.mrr);
    final urgentStores = _stores
        .where((s) => s.status == StoreStatus.warn || s.status == StoreStatus.expired)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Hero MRR Card
        GlassCard(
          borderColor: FTColors.ochre.withValues(alpha: 0.4),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1D3B47), Color(0xFF102128), Color(0xFF1A2D25)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      t('mrr_lbl'),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: FTColors.ink2,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: FTColors.market.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: FTColors.market.withValues(alpha: 0.5)),
                    ),
                    child: const Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        '+18.4%',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: FTColors.greenOk,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: totalMrr.toDouble()),
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeOutCubic,
                builder: (context, val, _) => Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        formatMru(val.round()),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      t('cur'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: FTColors.ochre,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _kpiBox(activeCnt.toString(), t('st_active'), FTColors.greenOk),
                  const SizedBox(width: 8),
                  _kpiBox(trialCnt.toString(), t('st_trial'), const Color(0xFF7DD3FC)),
                  const SizedBox(width: 8),
                  _kpiBox(warnCnt.toString(), t('st_warn'), const Color(0xFFFCD34D)),
                  const SizedBox(width: 8),
                  _kpiBox(expCnt.toString(), t('st_exp'), const Color(0xFFFCA5A5)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Interactive 6-Month Bar Chart
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      t('chart_h'),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      t('chart_sub'),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: FTColors.muted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 112,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(_months.length, (i) {
                    final m = _months[i];
                    final ratio = (m['v'] as int) / 482500.0;
                    final isSel = i == _selectedMonth;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedMonth = i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 350),
                                    curve: Curves.easeOutCubic,
                                    height: 82 * ratio,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: isSel
                                            ? [FTColors.greenOk, FTColors.market]
                                            : [
                                                FTColors.ochre,
                                                FTColors.ochre.withValues(alpha: 0.3),
                                              ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                m['m'] as String,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: isSel ? Colors.white : FTColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_months[_selectedMonth]['m']} 2026',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        '${formatMru(_months[_selectedMonth]['v'] as int)} ${t('cur')}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: FTColors.ochre,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Payment Split Card
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      t('pay_split_h'),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Bankily · Masrivi · Sedad',
                    style: TextStyle(fontSize: 11.5, color: FTColors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: SizedBox(
                  height: 10,
                  child: Row(
                    children: [
                      Expanded(flex: 52, child: Container(color: FTColors.ochre)),
                      const SizedBox(width: 2),
                      Expanded(flex: 28, child: Container(color: FTColors.pharma)),
                      const SizedBox(width: 2),
                      Expanded(flex: 12, child: Container(color: FTColors.market)),
                      const SizedBox(width: 2),
                      Expanded(flex: 8, child: Container(color: Colors.blueGrey)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _legendChip('Bankily', '52%', FTColors.ochre),
                  _legendChip('Masrivi', '28%', FTColors.pharma),
                  _legendChip('Sedad', '12%', FTColors.market),
                  _legendChip(t('cash_lbl'), '8%', Colors.blueGrey),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Urgent Expirations
        Text(
          '${t('urgent_h')} (${urgentStores.length})',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        ...urgentStores.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildStoreCard(s),
            )),
      ],
    );
  }

  Widget _kpiBox(String val, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: [
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                val,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: FTColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendChip(String name, String pct, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(name, style: const TextStyle(fontSize: 12, color: FTColors.ink2)),
          const SizedBox(width: 6),
          Text(
            pct,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 2 : BOUTIQUES / TENANTS
  // ===========================================================================
  Widget _buildStoresTab() {
    final q = _searchQuery.trim().toLowerCase();
    final list = _stores.where((s) {
      final matchFilter = _filter == 'all' ||
          (_filter == 'warn'
              ? (s.status == StoreStatus.warn || s.status == StoreStatus.expired)
              : s.module.name == _filter);
      final matchQuery = q.isEmpty ||
          s.name.toLowerCase().contains(q) ||
          s.city.toLowerCase().contains(q) ||
          s.phone.contains(q);
      return matchFilter && matchQuery;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Search Bar
        TextField(
          onChanged: (v) => setState(() => _searchQuery = v),
          decoration: InputDecoration(
            hintText: t('search_ph'),
            prefixIcon: const Icon(Icons.search, color: FTColors.muted),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip('all', t('flt_all')),
              const SizedBox(width: 6),
              _filterChip('resto', 'Resto'),
              const SizedBox(width: 6),
              _filterChip('market', 'Market'),
              const SizedBox(width: 6),
              _filterChip('pharma', 'Pharma'),
              const SizedBox(width: 6),
              _filterChip('warn', t('flt_due')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...list.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildStoreCard(s, showLock: true),
            )),
      ],
    );
  }

  Widget _filterChip(String key, String label) {
    final selected = _filter == key;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = key),
      selectedColor: FTColors.ochre.withValues(alpha: 0.22),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: selected ? FTColors.ochre : FTColors.ink2,
      ),
    );
  }

  Widget _buildStoreCard(TenantStore s, {bool showLock = false}) {
    return Hero(
      tag: 'store-${s.id}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openStoreDetails(s),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xD9182D36), Color(0xF20E191E)],
              ),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 6,
                      height: 40,
                      decoration: BoxDecoration(
                        color: s.moduleColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${s.moduleName} · ${s.city} · ${s.tills} ${t('tills')}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: FTColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _statusBadge(s),
                  ],
                ),
                const Divider(height: 18, color: Colors.white10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        '${formatMru(s.mrr)} ${t('cur')}',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: FTColors.ochre,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        if (showLock)
                          TextButton.icon(
                            onPressed: () => _toggleLock(s),
                            icon: Icon(
                              s.status == StoreStatus.locked
                                  ? Icons.lock_open
                                  : Icons.lock_outline,
                              size: 15,
                              color: s.status == StoreStatus.locked
                                  ? FTColors.greenOk
                                  : FTColors.danger,
                            ),
                            label: Text(
                              s.status == StoreStatus.locked
                                  ? t('btn_unlock')
                                  : t('btn_lock'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: s.status == StoreStatus.locked
                                    ? FTColors.greenOk
                                    : FTColors.danger,
                              ),
                            ),
                          ),
                        FilledButton.tonal(
                          onPressed: () => _extendStore(s),
                          style: FilledButton.styleFrom(
                            backgroundColor: FTColors.ochre,
                            foregroundColor: const Color(0xFF101916),
                            minimumSize: const Size(0, 38),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: Text(
                            t('btn_extend'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(TenantStore s) {
    Color bg;
    Color fg;
    String label;
    if (s.status == StoreStatus.locked) {
      bg = Colors.blueGrey.withValues(alpha: 0.25);
      fg = Colors.white70;
      label = t('b_lock');
    } else if (s.status == StoreStatus.expired || s.daysLeft <= 0) {
      bg = FTColors.danger.withValues(alpha: 0.2);
      fg = const Color(0xFFFCA5A5);
      label = t('b_exp');
    } else if (s.status == StoreStatus.trial) {
      bg = FTColors.pharma.withValues(alpha: 0.2);
      fg = const Color(0xFF7DD3FC);
      label = t('b_trial').replaceAll('{d}', s.daysLeft.toString());
    } else if (s.status == StoreStatus.warn || s.daysLeft <= 5) {
      bg = FTColors.warn.withValues(alpha: 0.2);
      fg = const Color(0xFFFCD34D);
      label = t('b_warn').replaceAll('{d}', s.daysLeft.toString());
    } else {
      bg = FTColors.market.withValues(alpha: 0.2);
      fg = FTColors.greenOk;
      label = t('b_active').replaceAll('{d}', s.daysLeft.toString());
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: fg.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }

  // ===========================================================================
  // TAB 3 : LICENCES OFFLINE & PAIEMENTS BANKILY/MASRIVI
  // ===========================================================================
  Widget _buildLicensesTab() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        GlassCard(
          borderColor: FTColors.ochre.withValues(alpha: 0.35),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('off_gen_h'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              Text(
                t('off_gen_s'),
                style: const TextStyle(fontSize: 12, color: FTColors.muted),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: _selectedOfflineStoreId,
                dropdownColor: FTColors.night2,
                decoration: InputDecoration(
                  labelText: t('sel_store'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                items: _stores
                    .map((s) => DropdownMenuItem(
                          value: s.id,
                          child: Text('${s.name} (${s.city})'),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedOfflineStoreId = v);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _selectedOfflineDays,
                dropdownColor: FTColors.night2,
                decoration: InputDecoration(
                  labelText: t('sel_dur'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 30, child: Text('+30 jours (1 mois)')),
                  DropdownMenuItem(value: 90, child: Text('+90 jours (3 mois)')),
                  DropdownMenuItem(value: 365, child: Text('+365 jours (1 an)')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _selectedOfflineDays = v);
                },
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _generateOfflineCode,
                  icon: const Icon(Icons.vpn_key),
                  label: Text(
                    t('btn_gen'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              if (_generatedCode != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: FTColors.bg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: FTColors.ochre),
                  ),
                  child: Column(
                    children: [
                      Text(
                        t('code_lbl'),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: FTColors.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          _generatedCode!,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            color: FTColors.ochre,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _generatedCode!));
                          _toast(t('copy_btn'));
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: Text(t('copy_btn')),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${t('pending_pay_h')} (${_payments.length})',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        ..._payments.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.storeName,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${p.method} · ${p.ref} · ${p.time}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: FTColors.muted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              '${formatMru(p.amount)} ${t('cur')}',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: FTColors.ochre,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: () => _approvePayment(p),
                      child: Text(
                        t('btn_val'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  // ===========================================================================
  // TAB 4 : PARC & MONITORING VPS
  // ===========================================================================
  Widget _buildFleetTab() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      t('vps_h'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      '99.98% UP',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: FTColors.greenOk,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Row(
                children: [
                  Expanded(
                    child: GaugeRing(
                      percent: 0.28,
                      color: FTColors.market,
                      valueText: '28%',
                      label: 'CPU Hetzner',
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: GaugeRing(
                      percent: 0.48,
                      color: FTColors.pharma,
                      valueText: '48%',
                      label: 'RAM 4 GB',
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: GaugeRing(
                      percent: 0.92,
                      color: FTColors.ochre,
                      valueText: '14 ms',
                      label: 'PostgreSQL',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          t('fleet_h'),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        ..._stores.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                child: Row(
                  children: [
                    Icon(
                      s.online ? Icons.cloud_done : Icons.wifi_off,
                      color: s.online ? FTColors.greenOk : FTColors.warn,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${s.city} · ${s.tills} ${t('tills')}${!s.online ? ' · ${s.pendingSync} tickets LAN' : ''}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: FTColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        _logAudit(
                          'Support Sécurisé · ${s.name}',
                          'Diagnostic distant ouvert (${s.city})',
                        );
                        _toast('Session support tracée pour ${s.name}');
                      },
                      child: Text(
                        t('btn_support'),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  // ===========================================================================
  // TAB 5 : JOURNAL D'AUDIT & PROFIL M. TAHA
  // ===========================================================================
  Widget _buildAuditTab() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        GlassCard(
          borderColor: FTColors.ochre.withValues(alpha: 0.4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      t('admin_h'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: FTColors.ochre.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      'SUPER-ADMIN',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: FTColors.ochre,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _infoRow(t('adm_tel'), '+222 42 74 42 42'),
              const SizedBox(height: 6),
              _infoRow(t('adm_bk'), 'FT-22242'),
              const SizedBox(height: 6),
              _infoRow(t('adm_ms'), 'MS-4274'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${t('audit_h')} (${_audits.length})',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        GlassCard(
          child: Column(
            children: _audits
                .map((a) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: FTColors.ochre.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.verified_outlined,
                              size: 18,
                              color: FTColors.ochre,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.title,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${a.subtitle} · ${a.time}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: FTColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: FTColors.ink2)),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            val,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // HERO STORE DETAILS SCREEN
  // ===========================================================================
  void _openStoreDetails(TenantStore store) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => StoreDetailScreen(
          store: store,
          lang: widget.lang,
          tr: t,
          onExtend: () {
            _extendStore(store);
            setState(() {});
          },
          onToggleLock: () {
            _toggleLock(store);
            setState(() {});
          },
          onChanged: () => setState(() {}),
        ),
      ),
    );
  }

  // ===========================================================================
  // ASSISTANT PROFESSIONNEL : NOUVEAU CLIENT / BOUTIQUE (3 ÉTAPES)
  // ===========================================================================
  Future<void> _openCreateStoreModal() async {
    final created = await Navigator.of(context).push<TenantStore>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => NewStoreWizard(lang: widget.lang),
      ),
    );
    if (created == null || !mounted) return;
    setState(() => _stores.insert(0, created));
    final payNote = created.initialPayMethod.isNotEmpty
        ? ' · ${created.initialPayMethod}${created.initialPayRef.isNotEmpty ? ' (${created.initialPayRef})' : ''}'
        : '';
    _logAudit(
      'Nouveau client · ${created.name}',
      '${created.moduleName} · ${created.tenantId} · ${created.tills} caisses$payNote',
    );
    _toast('${created.name} activé (${created.tenantId})');
  }
}

class _OrbitRingPainter extends CustomPainter {
  final double angle;

  _OrbitRingPainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect.deflate(1), const Radius.circular(36));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..shader = SweepGradient(
        transform: GradientRotation(angle),
        colors: [
          Colors.transparent,
          FTColors.ochre.withValues(alpha: 0.3),
          FTColors.ochre,
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 0.72, 1.0],
      ).createShader(rect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _OrbitRingPainter oldDelegate) =>
      oldDelegate.angle != angle;
}
