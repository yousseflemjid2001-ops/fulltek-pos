import 'package:flutter/material.dart';
import '../models/backoffice_models.dart';
import '../models/pos_models.dart';
import '../state/pos_store.dart';
import '../theme/fulltek_themes.dart';
import '../widgets/fulltek_logo.dart';
import 'closing_z_view.dart';
import 'karni_view.dart';
import 'menu_stock_view.dart';
import 'owner_dashboard_view.dart';
import 'team_profiles_view.dart';

/// Full-Tek Resto Back-Office ERP (Fournisseurs, Achats, Facturation B2B,
/// Charges & Comptabilité TVA 16 % / Résultat Net, Menu/Stock, Journal Ventes,
/// Trésorerie & Z, Carnet Karni, Équipe & Accès Back-Office).
class BackOfficeScreen extends StatefulWidget {
  final PosStore store;
  final StaffMember? operatorStaff;

  const BackOfficeScreen({
    super.key,
    required this.store,
    this.operatorStaff,
  });

  @override
  State<BackOfficeScreen> createState() => _BackOfficeScreenState();
}

class _BackOfficeScreenState extends State<BackOfficeScreen> {
  int _sectionIndex = 0;
  String _salesQuery = '';
  int _supplierSubTab = 0; // 0 = Fournisseurs, 1 = Factures Achats
  int _accountingSubTab = 0; // 0 = Compte Résultat & TVA, 1 = Charges

  static const _expenseCategories = [
    'Loyer',
    'Salaires Équipe',
    'SOMELEC / SNDE',
    'Gaz & Charbon Cuisine',
    'Transport & Livraison',
    'Maintenance & Matériel',
    'Marketing & Pub',
    'Emballages & Hygiène',
    'Divers',
  ];

  static const _supplierCategories = [
    'Alimentaire',
    'Boucherie / Poissons',
    'Boissons & Café',
    'Fruits & Légumes',
    'Boulangerie / Farine',
    'Emballages',
    'Équipement & Gaz',
  ];

  static const _payMethods = [
    'Cash',
    'Bankily',
    'Masrivi',
    'Sedad',
    'Bimbank',
    'Click',
    'Virement Bancaire',
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() => widget.store.fetchBackOfficeData());
  }

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final store = widget.store;
        final p = FullTekThemes.paletteOf(context);
        final wide = MediaQuery.of(context).size.width >= 960;
        final actor = widget.operatorStaff ?? store.currentStaff;

        final sections = <({
          String id,
          String label,
          IconData icon,
          Widget view,
        })>[
          (
            id: 'dashboard',
            label: 'Tableau de Bord',
            icon: Icons.dashboard_rounded,
            view: OwnerDashboardView(store: store),
          ),
          (
            id: 'suppliers_purchases',
            label: 'Fournisseurs & Achats',
            icon: Icons.local_shipping_rounded,
            view: _buildSuppliersAndPurchases(store, p),
          ),
          (
            id: 'b2b_invoices',
            label: 'Facturation B2B / Traiteur',
            icon: Icons.description_rounded,
            view: _buildB2bInvoices(store, p),
          ),
          (
            id: 'accounting',
            label: 'Comptabilité, TVA & Charges',
            icon: Icons.account_balance_rounded,
            view: _buildAccountingAndExpenses(store, p),
          ),
          (
            id: 'menu_stock',
            label: 'Menu, Familles & Stock',
            icon: Icons.inventory_2_rounded,
            view: MenuStockView(store: store),
          ),
          (
            id: 'sales',
            label: 'Journal des Ventes Caisse',
            icon: Icons.receipt_long_rounded,
            view: _buildSalesJournal(store, p),
          ),
          (
            id: 'closing_z',
            label: 'Trésorerie & Clôtures Z',
            icon: Icons.account_balance_wallet_rounded,
            view: ClosingZView(store: store),
          ),
          (
            id: 'karni',
            label: 'Clients & Carnet Karni',
            icon: Icons.menu_book_rounded,
            view: KarniView(store: store),
          ),
          (
            id: 'team',
            label: 'Équipe & Accès Back-Office',
            icon: Icons.admin_panel_settings_rounded,
            view: TeamProfilesView(store: store),
          ),
        ];

        final safeIdx = _sectionIndex.clamp(0, sections.length - 1);

        Widget buildSidebar() {
          return Container(
            width: 258,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              border: Border(right: BorderSide(color: p.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FullTekLogo(
                        size: 32,
                        variant: 'Resto',
                        animate: false,
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: const Color(0xFF7C3AED)
                                  .withValues(alpha: 0.5)),
                        ),
                        child: const Text(
                          'BACK-OFFICE ERP RESTO',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: Color(0xFFC4B5FD),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        store.tenantName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      if (actor != null)
                        Text(
                          '${actor.name} · ${actor.role.label(store.lang)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFF1E293B)),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    itemCount: sections.length,
                    itemBuilder: (_, idx) {
                      final s = sections[idx];
                      final active = idx == safeIdx;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: ListTile(
                          key: Key('bo_nav_${s.id}'),
                          dense: true,
                          selected: active,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          selectedTileColor:
                              const Color(0xFF7C3AED).withValues(alpha: 0.22),
                          leading: Icon(
                            s.icon,
                            size: 18,
                            color: active
                                ? const Color(0xFFC4B5FD)
                                : const Color(0xFF94A3B8),
                          ),
                          title: Text(
                            s.label,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight:
                                  active ? FontWeight.w800 : FontWeight.w600,
                              color: active
                                  ? Colors.white
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                          onTap: () {
                            setState(() => _sectionIndex = idx);
                            if (!wide) Navigator.of(context).pop();
                          },
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 1, color: Color(0xFF1E293B)),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: OutlinedButton.icon(
                    key: const Key('bo_back_to_pos_btn'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF334155)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.point_of_sale_rounded, size: 17),
                    label: const Text('Retour à la Caisse'),
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            backgroundColor: p.headerBg,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            shape: Border(bottom: BorderSide(color: p.border)),
            title: Text(
              'Back-Office · ${sections[safeIdx].label}',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: p.textPrimary),
            ),
            actions: [
              if (store.isLoadingBackOffice)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              IconButton(
                tooltip: 'Synchroniser avec le serveur',
                onPressed: () {
                  store.fetchCloudCatalog();
                  store.fetchBackOfficeData();
                },
                icon: Icon(Icons.sync_rounded, color: p.textPrimary),
              ),
              const SizedBox(width: 6),
            ],
          ),
          drawer: wide ? null : Drawer(child: buildSidebar()),
          body: Row(
            children: [
              if (wide) buildSidebar(),
              Expanded(child: sections[safeIdx].view),
            ],
          ),
        );
      },
    );
  }

  // =========================================================================
  // 1. FOURNISSEURS & ACHATS
  // =========================================================================

  Widget _buildSuppliersAndPurchases(PosStore store, PosPalette p) {
    final totalDebt = store.restoSuppliers
        .fold<double>(0, (s, sup) => s + sup.balanceDueMru);
    final totalPurchases = store.restoPurchases
        .fold<double>(0, (s, pur) => s + pur.totalTtcMru);
    final unpaidPurchases = store.restoPurchases
        .fold<double>(0, (s, pur) => s + pur.remainingMru);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    selected: _supplierSubTab == 0,
                    onSelected: (_) => setState(() => _supplierSubTab = 0),
                    label: Text(
                        'Fournisseurs (${store.restoSuppliers.length})'),
                  ),
                  ChoiceChip(
                    selected: _supplierSubTab == 1,
                    onSelected: (_) => setState(() => _supplierSubTab = 1),
                    label: Text(
                        'Achats & Factures (${store.restoPurchases.length})'),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _openSupplierDialog(store),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 17),
                    label: const Text('Nouveau Fournisseur'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _openPurchaseDialog(store),
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 17),
                    label: const Text('Enregistrer un Achat'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _kpiChip('Fournisseurs', '${store.restoSuppliers.length}',
                  p.primary, p),
              _kpiChip('Total Achats TTC',
                  '${totalPurchases.toStringAsFixed(0)} MRU', p.accent, p),
              _kpiChip('Dettes Fournisseurs',
                  '${(totalDebt > unpaidPurchases ? totalDebt : unpaidPurchases).toStringAsFixed(0)} MRU',
                  p.danger, p),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _supplierSubTab == 0
                ? (store.restoSuppliers.isEmpty
                    ? Center(
                        child: Text(
                          'Aucun fournisseur enregistré. Cliquez sur "Nouveau Fournisseur".',
                          style: TextStyle(color: p.textMuted),
                        ),
                      )
                    : ListView.separated(
                        itemCount: store.restoSuppliers.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, idx) {
                          final sup = store.restoSuppliers[idx];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: p.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: p.border),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      p.primary.withValues(alpha: 0.14),
                                  child: Icon(Icons.storefront_rounded,
                                      color: p.primary, size: 19),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(sup.name,
                                          style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: p.textPrimary)),
                                      Text(
                                        '${sup.category}${sup.phone.isNotEmpty ? ' · ${sup.phone}' : ''}${sup.nif.isNotEmpty ? ' · NIF: ${sup.nif}' : ''}',
                                        style: TextStyle(
                                            fontSize: 12, color: p.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Solde dû: ${sup.balanceDueMru.toStringAsFixed(0)} MRU',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12.5,
                                        color: sup.balanceDueMru > 0
                                            ? p.danger
                                            : p.success,
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Modifier',
                                          icon: const Icon(Icons.edit_outlined,
                                              size: 18),
                                          onPressed: () => _openSupplierDialog(
                                              store,
                                              existing: sup),
                                        ),
                                        IconButton(
                                          tooltip: 'Supprimer',
                                          icon: Icon(Icons.delete_outline,
                                              size: 18, color: p.danger),
                                          onPressed: () async {
                                            final err = await store
                                                .deleteRestoSupplier(sup.id);
                                            if (err != null) {
                                              _toast(err, isError: true);
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ))
                : (store.restoPurchases.isEmpty
                    ? Center(
                        child: Text(
                          'Aucune facture d\'achat enregistrée.',
                          style: TextStyle(color: p.textMuted),
                        ),
                      )
                    : ListView.separated(
                        itemCount: store.restoPurchases.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, idx) {
                          final pur = store.restoPurchases[idx];
                          final isPaid = pur.status == 'PAID';
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: p.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: p.border),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(pur.docNumber,
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  color: p.textPrimary)),
                                          const SizedBox(width: 8),
                                          Text(pur.supplierName,
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: p.primary)),
                                          const SizedBox(width: 8),
                                          Text(pur.docDate,
                                              style: TextStyle(
                                                  fontSize: 11.5,
                                                  color: p.textMuted)),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'HT: ${pur.subtotalHtMru.toStringAsFixed(0)} · TVA: ${pur.tvaMru.toStringAsFixed(0)} · Payé: ${pur.paidMru.toStringAsFixed(0)} MRU (${pur.payMethod})',
                                        style: TextStyle(
                                            fontSize: 12, color: p.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${pur.totalTtcMru.toStringAsFixed(0)} MRU',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                          color: p.textPrimary),
                                    ),
                                    const SizedBox(height: 4),
                                    if (isPaid)
                                      Text('PAYÉ',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: p.success))
                                    else
                                      FilledButton.tonal(
                                        onPressed: () async {
                                          final err =
                                              await store.payRestoPurchase(
                                                  pur.id, pur.remainingMru);
                                          if (err != null) {
                                            _toast(err, isError: true);
                                          } else {
                                            _toast('Règlement fournisseur enregistré.');
                                          }
                                        },
                                        child: Text(
                                            'Régler ${pur.remainingMru.toStringAsFixed(0)} MRU'),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      )),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 2. FACTURATION B2B / ÉVÉNEMENTS / TRAITEUR
  // =========================================================================

  Widget _buildB2bInvoices(PosStore store, PosPalette p) {
    final totalB2b = store.restoInvoices
        .where((i) => i.docType == 'FACTURE')
        .fold<double>(0, (s, i) => s + i.totalTtcMru);
    final totalRemaining = store.restoInvoices
        .where((i) => i.docType == 'FACTURE')
        .fold<double>(0, (s, i) => s + i.remainingMru);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _kpiChip('Factures B2B',
                      '${totalB2b.toStringAsFixed(0)} MRU', p.primary, p),
                  _kpiChip('Reste à encaisser',
                      '${totalRemaining.toStringAsFixed(0)} MRU', p.warning, p),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        _openInvoiceDialog(store, docType: 'DEVIS'),
                    icon: const Icon(Icons.request_quote_outlined, size: 17),
                    label: const Text('Nouveau Devis'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () =>
                        _openInvoiceDialog(store, docType: 'FACTURE'),
                    icon: const Icon(Icons.receipt_rounded, size: 17),
                    label: const Text('Nouvelle Facture B2B'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: store.restoInvoices.isEmpty
                ? Center(
                    child: Text(
                      'Aucune facture B2B / Traiteur. Créez un devis ou une facture client entreprise.',
                      style: TextStyle(color: p.textMuted),
                    ),
                  )
                : ListView.separated(
                    itemCount: store.restoInvoices.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, idx) {
                      final inv = store.restoInvoices[idx];
                      final isPaid = inv.status == 'PAID';
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: p.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: (inv.docType == 'DEVIS'
                                                  ? p.warning
                                                  : p.primary)
                                              .withValues(alpha: 0.16),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          inv.docType,
                                          style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800,
                                              color: inv.docType == 'DEVIS'
                                                  ? p.warning
                                                  : p.primary),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(inv.docNumber,
                                          style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              color: p.textPrimary)),
                                      const SizedBox(width: 8),
                                      Text(inv.clientName,
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: p.textPrimary)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${inv.docDate} · HT: ${inv.subtotalHtMru.toStringAsFixed(0)} · TVA 16%: ${inv.tvaMru.toStringAsFixed(0)} MRU${inv.clientNif.isNotEmpty ? ' · NIF: ${inv.clientNif}' : ''}',
                                    style: TextStyle(
                                        fontSize: 12, color: p.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${inv.totalTtcMru.toStringAsFixed(0)} MRU',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      color: p.success),
                                ),
                                const SizedBox(height: 4),
                                if (isPaid)
                                  Text('ENCAISSÉ',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: p.success))
                                else
                                  FilledButton.tonal(
                                    onPressed: () async {
                                      final err =
                                          await store.payRestoB2bInvoice(
                                              inv.id, inv.remainingMru);
                                      if (err != null) {
                                        _toast(err, isError: true);
                                      } else {
                                        _toast('Facture encaissée !');
                                      }
                                    },
                                    child: Text(
                                        'Encaisser ${inv.remainingMru.toStringAsFixed(0)} MRU'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 3. COMPTABILITÉ, TVA 16 % DGI & CHARGES D'EXPLOITATION
  // =========================================================================

  Widget _buildAccountingAndExpenses(PosStore store, PosPalette p) {
    final posSalesTtc =
        store.completedOrders.fold<double>(0, (s, o) => s + o.grossTotal);
    final posTvaCollected =
        store.completedOrders.fold<double>(0, (s, o) => s + o.tvaAmountMru);
    final b2bSalesTtc = store.restoInvoices
        .where((i) => i.docType == 'FACTURE')
        .fold<double>(0, (s, i) => s + i.totalTtcMru);
    final b2bTvaCollected = store.restoInvoices
        .where((i) => i.docType == 'FACTURE')
        .fold<double>(0, (s, i) => s + i.tvaMru);

    final totalCaTtc = posSalesTtc + b2bSalesTtc;
    final totalTvaCollected = posTvaCollected + b2bTvaCollected;
    final totalCaHt = totalCaTtc - totalTvaCollected;

    final totalPurchasesTtc =
        store.restoPurchases.fold<double>(0, (s, pur) => s + pur.totalTtcMru);
    final totalPurchasesTva =
        store.restoPurchases.fold<double>(0, (s, pur) => s + pur.tvaMru);
    final totalPurchasesHt = totalPurchasesTtc - totalPurchasesTva;

    final totalExpensesTtc =
        store.restoExpenses.fold<double>(0, (s, e) => s + e.amountMru);
    final totalExpensesTva =
        store.restoExpenses.fold<double>(0, (s, e) => s + e.tvaMru);
    final totalExpensesHt = totalExpensesTtc - totalExpensesTva;

    final totalTvaDeductible = totalPurchasesTva + totalExpensesTva;
    final netTvaDue = totalTvaCollected - totalTvaDeductible;
    final netProfitHt = totalCaHt - totalPurchasesHt - totalExpensesHt;
    final netMarginPct = totalCaHt > 0 ? (netProfitHt / totalCaHt * 100) : 0.0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    selected: _accountingSubTab == 0,
                    onSelected: (_) => setState(() => _accountingSubTab = 0),
                    label: const Text('Compte de Résultat & TVA DGI 16 %'),
                  ),
                  ChoiceChip(
                    selected: _accountingSubTab == 1,
                    onSelected: (_) => setState(() => _accountingSubTab = 1),
                    label: Text(
                        'Charges d\'exploitation (${store.restoExpenses.length})'),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _openExpenseDialog(store),
                icon: const Icon(Icons.add_card_rounded, size: 17),
                label: const Text('Ajouter une Charge'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _accountingSubTab == 0
                ? ListView(
                    children: [
                      // Compte de Résultat Net
                      _accountingCard(
                        title: 'Compte de Résultat Synthétique (MRU)',
                        icon: Icons.trending_up_rounded,
                        p: p,
                        rows: [
                          ('Chiffre d\'Affaires Caisse (TTC)',
                              '${posSalesTtc.toStringAsFixed(0)} MRU', p.textPrimary),
                          ('Facturation Clients B2B (TTC)',
                              '${b2bSalesTtc.toStringAsFixed(0)} MRU', p.textPrimary),
                          ('Total Produits / CA Hors Taxes (HT)',
                              '${totalCaHt.toStringAsFixed(0)} MRU', p.primary),
                          ('(-) Achats Fournisseurs & Matières (HT)',
                              '- ${totalPurchasesHt.toStringAsFixed(0)} MRU', p.warning),
                          ('(-) Charges d\'Exploitation (HT)',
                              '- ${totalExpensesHt.toStringAsFixed(0)} MRU', p.danger),
                          ('= RÉSULTAT NET D\'EXPLOITATION',
                              '${netProfitHt.toStringAsFixed(0)} MRU (${netMarginPct.toStringAsFixed(1)} %)',
                              netProfitHt >= 0 ? p.success : p.danger),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Déclaration TVA Mauritanie DGI 16%
                      _accountingCard(
                        title: 'Déclaration TVA Mauritanie — DGI (16 %)',
                        icon: Icons.account_balance_rounded,
                        p: p,
                        rows: [
                          ('TVA Collectée — Ventes Caisse (16 %)',
                              '${posTvaCollected.toStringAsFixed(0)} MRU', p.textPrimary),
                          ('TVA Collectée — Factures B2B (16 %)',
                              '${b2bTvaCollected.toStringAsFixed(0)} MRU', p.textPrimary),
                          ('Total TVA Collectée',
                              '${totalTvaCollected.toStringAsFixed(0)} MRU', p.primary),
                          ('(-) TVA Déductible — Achats Fournisseurs',
                              '- ${totalPurchasesTva.toStringAsFixed(0)} MRU', p.success),
                          ('(-) TVA Déductible — Charges TTC',
                              '- ${totalExpensesTva.toStringAsFixed(0)} MRU', p.success),
                          (netTvaDue >= 0
                                  ? '= TVA NETTE À PAYER (DGI)'
                                  : '= CRÉDIT DE TVA À REPORTER',
                              '${netTvaDue.abs().toStringAsFixed(0)} MRU',
                              netTvaDue >= 0 ? p.warning : p.success),
                        ],
                      ),
                    ],
                  )
                : (store.restoExpenses.isEmpty
                    ? Center(
                        child: Text(
                          'Aucune charge enregistrée (Loyer, Salaires, SOMELEC, Gaz...).',
                          style: TextStyle(color: p.textMuted),
                        ),
                      )
                    : ListView.separated(
                        itemCount: store.restoExpenses.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, idx) {
                          final exp = store.restoExpenses[idx];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: p.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: p.border),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: p.danger
                                                  .withValues(alpha: 0.14),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(exp.category,
                                                style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: p.danger)),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(exp.label,
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  color: p.textPrimary)),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${exp.expenseDate} · ${exp.payMethod}${exp.tvaMru > 0 ? ' · TVA: ${exp.tvaMru.toStringAsFixed(0)} MRU' : ''}',
                                        style: TextStyle(
                                            fontSize: 12, color: p.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '- ${exp.amountMru.toStringAsFixed(0)} MRU',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      color: p.danger),
                                ),
                                IconButton(
                                  tooltip: 'Supprimer',
                                  icon: Icon(Icons.delete_outline,
                                      size: 18, color: p.danger),
                                  onPressed: () async {
                                    final err =
                                        await store.deleteRestoExpense(exp.id);
                                    if (err != null) _toast(err, isError: true);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      )),
          ),
        ],
      ),
    );
  }

  Widget _accountingCard({
    required String title,
    required IconData icon,
    required PosPalette p,
    required List<(String, String, Color)> rows,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: p.primary, size: 20),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: p.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          for (int i = 0; i < rows.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      rows[i].$1,
                      style: TextStyle(
                        fontSize: i == rows.length - 1 ? 13.5 : 13,
                        fontWeight: i == rows.length - 1
                            ? FontWeight.w900
                            : FontWeight.w600,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    rows[i].$2,
                    style: TextStyle(
                      fontSize: i == rows.length - 1 ? 15 : 13.5,
                      fontWeight: FontWeight.w900,
                      color: rows[i].$3,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // =========================================================================
  // 4. DIALOGS CRUD (Fournisseur, Achat, Charge, Facture B2B)
  // =========================================================================

  Future<void> _openSupplierDialog(PosStore store,
      {RestoSupplier? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final nifCtrl = TextEditingController(text: existing?.nif ?? '');
    final addrCtrl = TextEditingController(text: existing?.address ?? '');
    String cat = existing?.category ?? _supplierCategories.first;
    if (!_supplierCategories.contains(cat)) cat = _supplierCategories.first;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(existing == null
              ? 'Nouveau Fournisseur'
              : 'Modifier ${existing.name}'),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Nom / Société *'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: cat,
                    decoration: const InputDecoration(labelText: 'Catégorie'),
                    items: _supplierCategories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setD(() => cat = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Téléphone'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nifCtrl,
                    decoration: const InputDecoration(labelText: 'NIF / RC'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: addrCtrl,
                    decoration: const InputDecoration(labelText: 'Adresse'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final err = await store.saveRestoSupplier(
                  existingId: existing?.id,
                  name: nameCtrl.text,
                  phone: phoneCtrl.text,
                  category: cat,
                  nif: nifCtrl.text,
                  address: addrCtrl.text,
                );
                if (err != null) {
                  _toast(err, isError: true);
                  return;
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
                _toast('Fournisseur enregistré en base de données.');
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    phoneCtrl.dispose();
    nifCtrl.dispose();
    addrCtrl.dispose();
  }

  Future<void> _openPurchaseDialog(PosStore store) async {
    int? supId = store.restoSuppliers.isNotEmpty
        ? store.restoSuppliers.first.id
        : null;
    final supNameCtrl = TextEditingController(
        text: store.restoSuppliers.isNotEmpty
            ? store.restoSuppliers.first.name
            : '');
    final totalCtrl = TextEditingController();
    final paidCtrl = TextEditingController(text: '0');
    final notesCtrl = TextEditingController();
    bool includeTva = true;
    String payMethod = 'Cash';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Enregistrer un Achat / Facture Fournisseur'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (store.restoSuppliers.isNotEmpty)
                    DropdownButtonFormField<int>(
                      initialValue: supId,
                      decoration:
                          const InputDecoration(labelText: 'Fournisseur'),
                      items: store.restoSuppliers
                          .map((s) => DropdownMenuItem(
                              value: s.id, child: Text(s.name)))
                          .toList(),
                      onChanged: (v) {
                        setD(() {
                          supId = v;
                          final found = store.restoSuppliers
                              .where((s) => s.id == v)
                              .firstOrNull;
                          if (found != null) supNameCtrl.text = found.name;
                        });
                      },
                    )
                  else
                    TextField(
                      controller: supNameCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Nom du fournisseur *'),
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: totalCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Montant Total TTC (MRU) *'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: paidCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Montant payé immédiatement (MRU)'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: payMethod,
                    decoration:
                        const InputDecoration(labelText: 'Mode de paiement'),
                    items: _payMethods
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setD(() => payMethod = v);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: includeTva,
                    onChanged: (v) => setD(() => includeTva = v),
                    title: const Text('Inclure TVA 16 % déductible'),
                  ),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Détail / Produits achetés'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final total = double.tryParse(totalCtrl.text.trim()) ?? 0;
                final paid = double.tryParse(paidCtrl.text.trim()) ?? 0;
                final err = await store.createRestoPurchase(
                  supplierId: supId,
                  supplierName: supNameCtrl.text,
                  totalTtcMru: total,
                  paidMru: paid,
                  includeTva: includeTva,
                  payMethod: payMethod,
                  notes: notesCtrl.text,
                );
                if (err != null) {
                  _toast(err, isError: true);
                  return;
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
                _toast('Achat fournisseur enregistré.');
              },
              child: const Text('Valider Achat'),
            ),
          ],
        ),
      ),
    );
    supNameCtrl.dispose();
    totalCtrl.dispose();
    paidCtrl.dispose();
    notesCtrl.dispose();
  }

  Future<void> _openExpenseDialog(PosStore store) async {
    String cat = _expenseCategories.first;
    final labelCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String payMethod = 'Cash';
    bool includeTva = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Nouvelle Charge d\'Exploitation'),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: cat,
                    decoration: const InputDecoration(labelText: 'Catégorie'),
                    items: _expenseCategories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setD(() => cat = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: labelCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Libellé (ex: Loyer Novembre) *'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Montant (MRU) *'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: payMethod,
                    decoration:
                        const InputDecoration(labelText: 'Mode de paiement'),
                    items: _payMethods
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setD(() => payMethod = v);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: includeTva,
                    onChanged: (v) => setD(() => includeTva = v),
                    title: const Text('Charge avec TVA 16 % déductible'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                final err = await store.addRestoExpense(
                  category: cat,
                  label: labelCtrl.text,
                  amountMru: amount,
                  includeTva: includeTva,
                  payMethod: payMethod,
                );
                if (err != null) {
                  _toast(err, isError: true);
                  return;
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
                _toast('Charge enregistrée en comptabilité.');
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    labelCtrl.dispose();
    amountCtrl.dispose();
  }

  Future<void> _openInvoiceDialog(PosStore store,
      {required String docType}) async {
    final clientCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final nifCtrl = TextEditingController();
    final totalCtrl = TextEditingController();
    final paidCtrl = TextEditingController(text: '0');
    final notesCtrl = TextEditingController();
    bool includeTva = true;
    String payMethod = 'Bankily';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(docType == 'DEVIS'
              ? 'Nouveau Devis Traiteur / B2B'
              : 'Nouvelle Facture Client B2B'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: clientCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Client / Entreprise *'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Téléphone'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nifCtrl,
                    decoration: const InputDecoration(labelText: 'NIF Client'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: totalCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Montant Total TTC (MRU) *'),
                  ),
                  if (docType == 'FACTURE') ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: paidCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Acompte / Montant payé (MRU)'),
                    ),
                  ],
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: payMethod,
                    decoration:
                        const InputDecoration(labelText: 'Mode de règlement'),
                    items: _payMethods
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setD(() => payMethod = v);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: includeTva,
                    onChanged: (v) => setD(() => includeTva = v),
                    title: const Text('Appliquer TVA 16 % (DGI Mauritanie)'),
                  ),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Objet / Prestation (ex: Buffet 40 pers.)'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final total = double.tryParse(totalCtrl.text.trim()) ?? 0;
                final paid = double.tryParse(paidCtrl.text.trim()) ?? 0;
                final err = await store.createRestoB2bInvoice(
                  docType: docType,
                  clientName: clientCtrl.text,
                  clientPhone: phoneCtrl.text,
                  clientNif: nifCtrl.text,
                  totalTtcMru: total,
                  paidMru: paid,
                  includeTva: includeTva,
                  payMethod: payMethod,
                  notes: notesCtrl.text,
                );
                if (err != null) {
                  _toast(err, isError: true);
                  return;
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
                _toast('$docType enregistré en base de données.');
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    clientCtrl.dispose();
    phoneCtrl.dispose();
    nifCtrl.dispose();
    totalCtrl.dispose();
    paidCtrl.dispose();
    notesCtrl.dispose();
  }

  // =========================================================================
  // 5. JOURNAL DES VENTES CAISSE
  // =========================================================================

  Widget _buildSalesJournal(PosStore store, PosPalette p) {
    final q = _salesQuery.trim().toLowerCase();
    final orders = store.completedOrders.where((o) {
      if (q.isEmpty) return true;
      return o.ticketNumber.toLowerCase().contains(q) ||
          (o.tableCode ?? '').toLowerCase().contains(q) ||
          (o.serverName ?? '').toLowerCase().contains(q) ||
          (o.cashierName ?? '').toLowerCase().contains(q) ||
          o.staffName.toLowerCase().contains(q);
    }).toList();

    final totalCa = orders.fold<double>(0, (s, o) => s + o.grossTotal);
    final totalTva = orders.fold<int>(0, (s, o) => s + o.tvaAmountMru);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _kpiChip('Tickets', '${orders.length}', p.primary, p),
                  _kpiChip('CA TTC', '${totalCa.toStringAsFixed(0)} MRU',
                      p.success, p),
                  _kpiChip('TVA 16 %', '$totalTva MRU', p.accent, p),
                ],
              ),
              SizedBox(
                width: 280,
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded, size: 18),
                    hintText: 'Rechercher ticket, table, serveur...',
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _salesQuery = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: orders.isEmpty
                ? Center(
                    child: Text(
                      'Aucune vente encaissée pour le moment.',
                      style: TextStyle(color: p.textMuted, fontSize: 14),
                    ),
                  )
                : ListView.separated(
                    itemCount: orders.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, idx) {
                      final o = orders[idx];
                      final dt = o.paidAt ?? o.createdAt;
                      final hm =
                          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                      final hasMixed = o.items.any((l) => l.isTakeaway) &&
                          o.items.any((l) => !l.isTakeaway);
                      final modeLabel = hasMixed
                          ? '🍽/🥡 Mixte'
                          : '${o.serviceMode.emoji} ${o.serviceMode.label(store.lang)}';
                      final serverOrCashier = (o.serverName != null &&
                              o.serverName!.trim().isNotEmpty)
                          ? 'Serveur: ${o.serverName}'
                          : 'Caissier: ${o.cashierName ?? o.staffName}';
                      final pays = o.payments
                          .map((pe) =>
                              '${pe.method.name.toUpperCase()} (${pe.amountMru.toStringAsFixed(0)})')
                          .join(' + ');
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: p.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        o.ticketNumber,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: p.textPrimary),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        o.tableCode != null
                                            ? 'Table ${o.tableCode}'
                                            : modeLabel,
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: p.primary),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        hm,
                                        style: TextStyle(
                                            fontSize: 11.5, color: p.textMuted),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$serverOrCashier · ${o.items.length} article(s) · $pays',
                                    style: TextStyle(
                                        fontSize: 12, color: p.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${o.grossTotal.toStringAsFixed(0)} MRU',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: p.success,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _kpiChip(String label, String value, Color accent, PosPalette p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label : ',
              style: TextStyle(fontSize: 12, color: p.textMuted)),
          Text(value,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w900, color: accent)),
        ],
      ),
    );
  }
}
