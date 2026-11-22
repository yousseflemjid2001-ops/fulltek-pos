import 'package:flutter/material.dart';
import 'i18n/commercial_i18n.dart';
import 'screens/clients_articles_view.dart';
import 'screens/dashboard_view.dart';
import 'screens/finance_pro_view.dart';
import 'screens/login_screen.dart';
import 'screens/pos_view.dart';
import 'screens/purchases_view.dart';
import 'screens/sales_docs_view.dart';
import 'screens/stock_pro_settings_view.dart';
import 'screens/treasury_analytics_view.dart';
import 'state/commercial_store.dart';
import 'theme/commercial_theme.dart';
import 'widgets/fulltek_logo.dart';

void main() {
  runApp(const FullTekCommercialApp());
}

class FullTekCommercialApp extends StatefulWidget {
  final CommercialStore? store;
  const FullTekCommercialApp({super.key, this.store});

  @override
  State<FullTekCommercialApp> createState() => _FullTekCommercialAppState();
}

class _FullTekCommercialAppState extends State<FullTekCommercialApp> {
  late final CommercialStore _store;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? CommercialStore();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _store,
      builder: (context, _) {
        return MaterialApp(
          title: 'Full·Tek Gestion Commerciale',
          debugShowCheckedModeBanner: false,
          theme: buildCommercialTheme(),
          builder: (context, child) => Directionality(
            textDirection:
                _store.isRtl ? TextDirection.rtl : TextDirection.ltr,
            child: child ?? const SizedBox.shrink(),
          ),
          home: _store.loggedIn
              ? CommercialShellScreen(store: _store)
              : CommercialLoginScreen(store: _store),
        );
      },
    );
  }
}

class _NavItem {
  final String id;
  final String i18nKey;
  final IconData icon;
  const _NavItem(this.id, this.i18nKey, this.icon);
}

class CommercialShellScreen extends StatefulWidget {
  final CommercialStore store;
  const CommercialShellScreen({super.key, required this.store});

  @override
  State<CommercialShellScreen> createState() => _CommercialShellScreenState();
}

class _CommercialShellScreenState extends State<CommercialShellScreen> {
  String _routeId = 'dashboard';

  static const _sections = <String, List<_NavItem>>{
    '': [
      _NavItem('dashboard', 'dashboard', Icons.dashboard_outlined),
    ],
    'sec_analytics': [
      _NavItem('analytics_sales', 'analytics_sales', Icons.trending_up),
      _NavItem('analytics_purchases', 'analytics_purchases', Icons.inventory),
      _NavItem('treasury', 'treasury', Icons.account_balance_outlined),
      _NavItem('cheques', 'cheques', Icons.receipt_long_outlined),
      _NavItem('expenses', 'expenses', Icons.money_off_csred_outlined),
      _NavItem('tva_report', 'tva_report', Icons.account_balance_wallet_outlined),
      _NavItem('statements', 'statements', Icons.summarize_outlined),
      _NavItem('objectives', 'objectives', Icons.flag_outlined),
    ],
    'sec_pos': [
      _NavItem('pos_register', 'pos_register', Icons.point_of_sale),
      _NavItem('pos_sessions', 'pos_sessions', Icons.history),
      _NavItem('pos_tickets', 'pos_tickets', Icons.confirmation_number_outlined),
    ],
    'sec_sales': [
      _NavItem('clients', 'clients', Icons.people_outline),
      _NavItem('articles', 'articles', Icons.inventory_2_outlined),
      _NavItem('sales_devis', 'sales_devis', Icons.description_outlined),
      _NavItem('sales_commandes', 'sales_commandes', Icons.shopping_cart_outlined),
      _NavItem('sales_bl', 'sales_bl', Icons.local_shipping_outlined),
      _NavItem('sales_factures', 'sales_factures', Icons.receipt_outlined),
      _NavItem('sales_avoirs', 'sales_avoirs', Icons.assignment_return_outlined),
    ],
    'sec_purchases': [
      _NavItem('suppliers', 'suppliers', Icons.storefront_outlined),
      _NavItem('pur_bc', 'pur_bc', Icons.shopping_bag_outlined),
      _NavItem('pur_rec', 'pur_rec', Icons.move_to_inbox_outlined),
      _NavItem('pur_fac', 'pur_fac', Icons.request_quote_outlined),
      _NavItem('pur_av', 'pur_av', Icons.undo_outlined),
      _NavItem('warehouses', 'warehouses', Icons.warehouse_outlined),
    ],
    'sec_system': [
      _NavItem('settings', 'settings', Icons.settings_outlined),
    ],
  };

  void _navigate(String routeId) {
    if (!widget.store.canAccessRoute(routeId)) return;
    setState(() => _routeId = routeId);
  }

  String _effectiveRoute() {
    if (widget.store.canAccessRoute(_routeId)) return _routeId;
    if (widget.store.activeRole == 'CASHIER') return 'pos_register';
    return 'dashboard';
  }

  Widget _buildBody() {
    final s = widget.store;
    return switch (_effectiveRoute()) {
      'dashboard' => DashboardView(store: s, onNavigate: _navigate),
      'analytics_sales' => AnalyticsView(store: s, mode: 'sales'),
      'analytics_purchases' => AnalyticsView(store: s, mode: 'purchases'),
      'treasury' => TreasuryView(store: s),
      'cheques' => ChequesView(store: s),
      'expenses' => ExpensesView(store: s),
      'tva_report' => TvaAndAgingView(store: s),
      'statements' => PartyStatementView(store: s),
      'objectives' => ObjectivesView(store: s),
      'pos_register' => PosRegisterView(store: s),
      'pos_sessions' => PosSessionsView(store: s),
      'pos_tickets' => PosTicketsView(store: s),
      'clients' => ClientsView(store: s),
      'articles' => ArticlesView(store: s),
      'sales_devis' => SalesDocsView(store: s, docType: 'DEVIS'),
      'sales_commandes' => SalesDocsView(store: s, docType: 'COMMANDE'),
      'sales_bl' => SalesDocsView(store: s, docType: 'BL'),
      'sales_factures' => SalesDocsView(store: s, docType: 'FACTURE'),
      'sales_avoirs' => SalesDocsView(store: s, docType: 'AVOIR'),
      'suppliers' => SuppliersView(store: s),
      'pur_bc' => PurchaseDocsView(store: s, docType: 'BC_ACHAT'),
      'pur_rec' => PurchaseDocsView(store: s, docType: 'RECEPTION'),
      'pur_fac' => PurchaseDocsView(store: s, docType: 'FACTURE_ACHAT'),
      'pur_av' => PurchaseDocsView(store: s, docType: 'AVOIR_ACHAT'),
      'warehouses' => WarehousesInventoryView(store: s),
      'settings' => CompanySettingsView(store: s),
      _ => DashboardView(store: s, onNavigate: _navigate),
    };
  }

  Widget _buildSidebar({bool inDrawer = false}) {
    final s = widget.store;
    final t = s.tenant;
    final lang = s.lang;
    final currentRoute = _effectiveRoute();

    return Container(
      width: 256,
      color: CommercialColors.sidebarBg,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: Color(0xFF1E293B), width: 1)),
            ),
            child: Row(
              children: [
                const FullTekCommercialMark(size: 38, darkBg: true),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Full·Tek',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800),
                      ),
                      const Text(
                        'COMMERCIAL',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: CommercialColors.brandViolet,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2),
                      ),
                      Text(
                        s.companySettings.companyName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFF94A3B8), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              children: [
                for (final entry in _sections.entries) ...[
                  if (entry.value.any((it) => s.canAccessRoute(it.id))) ...[
                    if (entry.key.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 14, 10, 6),
                        child: Text(
                          CommercialI18n.t(lang, entry.key),
                          style: const TextStyle(
                            color: CommercialColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ),
                    for (final item in entry.value)
                      if (s.canAccessRoute(item.id))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              _navigate(item.id);
                              if (inDrawer) Navigator.pop(context);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 9),
                              decoration: BoxDecoration(
                                color: currentRoute == item.id
                                    ? CommercialColors.sidebarActive
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    item.icon,
                                    size: 18,
                                    color: currentRoute == item.id
                                        ? Colors.white
                                        : const Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      CommercialI18n.t(lang, item.i18nKey),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: currentRoute == item.id
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: currentRoute == item.id
                                            ? Colors.white
                                            : const Color(0xFFCBD5E1),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                  ],
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              border:
                  Border(top: BorderSide(color: Color(0xFF1E293B), width: 1)),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFF1E293B),
                  child: Icon(Icons.person_outline,
                      size: 18, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.manager.isEmpty ? 'Administrateur' : t.manager,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${s.activeRole} · ${t.plan}',
                        style: const TextStyle(
                            color: Color(0xFF94A3B8), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: CommercialI18n.t(lang, 'logout'),
                  icon: const Icon(Icons.logout,
                      size: 18, color: Color(0xFF94A3B8)),
                  onPressed: widget.store.logout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 960;
    final s = widget.store;
    final cs = s.companySettings;
    final lang = s.lang;

    return Scaffold(
      drawer: isWide ? null : Drawer(child: _buildSidebar(inDrawer: true)),
      body: Row(
        children: [
          if (isWide) _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: const BoxDecoration(
                    color: CommercialColors.cardBg,
                    border: Border(
                      bottom: BorderSide(color: CommercialColors.border),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (!isWide)
                        Builder(
                          builder: (ctx) => IconButton(
                            icon: const Icon(Icons.menu),
                            onPressed: () => Scaffold.of(ctx).openDrawer(),
                          ),
                        ),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                cs.companyName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                              if (cs.nif.isNotEmpty) ...[
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${cs.nif}${cs.rc.isNotEmpty ? ' • ${cs.rc}' : ''}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: CommercialColors.textMuted),
                                  ),
                                ),
                              ],
                              if (s.isOfflineDemo) ...[
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: CommercialColors.warningAmber
                                        .withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    CommercialI18n.t(lang, 'demo_mode'),
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: CommercialColors.warningAmber),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: () =>
                            s.setLanguage(s.lang == 'fr' ? 'ar' : 'fr'),
                        child: Text(s.lang == 'fr' ? 'العربية' : 'FR'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: s.exportDashboardCsv,
                        icon: const Icon(Icons.download_outlined, size: 16),
                        label: Text(CommercialI18n.t(lang, 'export_csv')),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: CommercialI18n.t(lang, 'refresh'),
                        onPressed: s.isBusy ? null : () => s.refreshAll(),
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
