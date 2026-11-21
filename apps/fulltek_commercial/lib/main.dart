import 'package:flutter/material.dart';
import 'screens/clients_articles_view.dart';
import 'screens/dashboard_view.dart';
import 'screens/login_screen.dart';
import 'screens/pos_view.dart';
import 'screens/purchases_view.dart';
import 'screens/sales_docs_view.dart';
import 'screens/treasury_analytics_view.dart';
import 'state/commercial_store.dart';
import 'theme/commercial_theme.dart';

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
  final String label;
  final IconData icon;
  const _NavItem(this.id, this.label, this.icon);
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
      _NavItem('dashboard', 'Tableau de bord', Icons.dashboard_outlined),
    ],
    'ANALYSES & FINANCE': [
      _NavItem('analytics_sales', 'Ventes & Marges', Icons.trending_up),
      _NavItem('analytics_purchases', 'Achats & Stock', Icons.inventory),
      _NavItem('treasury', 'Trésorerie', Icons.account_balance_outlined),
      _NavItem('cheques', 'Chèques & Traites', Icons.receipt_long_outlined),
      _NavItem('objectives', 'Objectifs', Icons.flag_outlined),
    ],
    'POINT DE VENTE': [
      _NavItem('pos_register', 'Écran de caisse', Icons.point_of_sale),
      _NavItem('pos_sessions', 'Sessions & Rapports Z', Icons.history),
      _NavItem('pos_tickets', 'Tickets', Icons.confirmation_number_outlined),
    ],
    'VENTES': [
      _NavItem('clients', 'Clients & Karni', Icons.people_outline),
      _NavItem('articles', 'Articles & Stock', Icons.inventory_2_outlined),
      _NavItem('sales_devis', 'Devis', Icons.description_outlined),
      _NavItem('sales_commandes', 'Commandes clients', Icons.shopping_cart_outlined),
      _NavItem('sales_bl', 'Bons de livraison', Icons.local_shipping_outlined),
      _NavItem('sales_factures', 'Factures clients', Icons.receipt_outlined),
      _NavItem('sales_avoirs', 'Avoirs clients', Icons.assignment_return_outlined),
    ],
    'ACHATS': [
      _NavItem('suppliers', 'Fournisseurs', Icons.storefront_outlined),
      _NavItem('pur_bc', 'Commandes fourn.', Icons.shopping_bag_outlined),
      _NavItem('pur_rec', 'Réceptions (PMP)', Icons.move_to_inbox_outlined),
      _NavItem('pur_fac', 'Factures fourn.', Icons.request_quote_outlined),
      _NavItem('pur_av', 'Avoirs fourn.', Icons.undo_outlined),
    ],
  };

  void _navigate(String routeId) {
    setState(() => _routeId = routeId);
  }

  Widget _buildBody() {
    final s = widget.store;
    return switch (_routeId) {
      'dashboard' => DashboardView(store: s, onNavigate: _navigate),
      'analytics_sales' => AnalyticsView(store: s, mode: 'sales'),
      'analytics_purchases' => AnalyticsView(store: s, mode: 'purchases'),
      'treasury' => TreasuryView(store: s),
      'cheques' => ChequesView(store: s),
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
      _ => DashboardView(store: s, onNavigate: _navigate),
    };
  }

  Widget _buildSidebar({bool inDrawer = false}) {
    final t = widget.store.tenant;
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
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: CommercialColors.primaryBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.business_center,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Full·Tek',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700),
                      ),
                      Text(
                        t.name,
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
                  if (entry.key.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 14, 10, 6),
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          color: CommercialColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                  for (final item in entry.value)
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
                            color: _routeId == item.id
                                ? CommercialColors.sidebarActive
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item.icon,
                                size: 18,
                                color: _routeId == item.id
                                    ? Colors.white
                                    : const Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: _routeId == item.id
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: _routeId == item.id
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
                        t.plan,
                        style: const TextStyle(
                            color: Color(0xFF94A3B8), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Déconnexion',
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
    final t = widget.store.tenant;

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
                      Text(
                        t.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      if (t.nif.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${t.nif}${t.rc.isNotEmpty ? ' • ${t.rc}' : ''}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: CommercialColors.textMuted),
                          ),
                        ),
                      ],
                      if (widget.store.isOfflineDemo) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: CommercialColors.warningAmber
                                .withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Mode Démo',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: CommercialColors.warningAmber),
                          ),
                        ),
                      ],
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: widget.store.exportDashboardCsv,
                        icon: const Icon(Icons.download_outlined, size: 16),
                        label: const Text('Excel / CSV'),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Actualiser',
                        onPressed: widget.store.isBusy
                            ? null
                            : () => widget.store.refreshAll(),
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
