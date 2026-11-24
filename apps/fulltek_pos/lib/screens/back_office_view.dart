import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Full-Tek Resto Back-Office ERP Complet :
/// 1. Tableau de Bord & KPIs
/// 2. Fournisseurs & Achats Multi-Lignes (avec entrée en stock & recalcul PMP auto)
/// 3. Facturation B2B / Traiteur Multi-Lignes (Devis -> Facture, Aperçu A4 & Montant en lettres)
/// 4. Fiches Techniques & Marges (Recettes BOM, Food Cost MRU & % par plat)
/// 5. Inventaire Physique, Pertes & Casse (Waste)
/// 6. Comptabilité Pro (Compte de Résultat, TVA DGI 16 %, Charges, Grand Livre + Export CSV)
/// 7. Trésorerie Multi-Comptes (Espèces, Bankily, Masrivi, Sedad, Bimbank, Click) & Clôtures Z
/// 8. Menu, Familles, Suppléments & Stock
/// 9. Journal des Ventes Caisse
/// 10. Clients & Carnet Karni
/// 11. Équipe, Accès Back-Office & Identité Fiscale (NIF / RC)
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
  int _accountingSubTab = 0; // 0 = Résultat & TVA, 1 = Charges, 2 = Grand Livre
  int _treasurySubTab = 0; // 0 = Comptes & Flux, 1 = Clôtures Z
  int _teamSubTab = 0; // 0 = Équipe & Droits, 1 = Identité Fiscale (NIF/RC)
  String? _selectedBomProductId;

  static const _expenseCategories = [
    'Loyer',
    'Salaires Équipe',
    'SOMELEC / SNDE',
    'Gaz & Charbon Cuisine',
    'Transport & Livraison',
    'Maintenance & Matériel',
    'Marketing & Pub',
    'Emballages & Hygiène',
    'Pertes & Casse Stock',
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
            id: 'recipes_foodcost',
            label: 'Fiches Techniques & Marges',
            icon: Icons.restaurant_menu_rounded,
            view: _buildRecipesAndFoodCost(store, p),
          ),
          (
            id: 'inventory_waste',
            label: 'Inventaire & Pertes Stock',
            icon: Icons.fact_check_rounded,
            view: _buildInventoryAndWaste(store, p),
          ),
          (
            id: 'accounting',
            label: 'Comptabilité, TVA & Grand Livre',
            icon: Icons.account_balance_rounded,
            view: _buildAccountingAndExpenses(store, p),
          ),
          (
            id: 'treasury_z',
            label: 'Trésorerie Multi-Comptes & Z',
            icon: Icons.account_balance_wallet_rounded,
            view: _buildTreasuryAndClosings(store, p),
          ),
          (
            id: 'menu_stock',
            label: 'Menu, Familles & Suppléments',
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
            id: 'karni',
            label: 'Clients & Carnet Karni',
            icon: Icons.menu_book_rounded,
            view: KarniView(store: store),
          ),
          (
            id: 'team_fiscal',
            label: 'Équipe, Accès & Fiscalité',
            icon: Icons.admin_panel_settings_rounded,
            view: _buildTeamAndFiscalSettings(store, p),
          ),
        ];

        final safeIdx = _sectionIndex.clamp(0, sections.length - 1);

        Widget buildSidebar() {
          return Container(
            width: 262,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              border: Border(right: BorderSide(color: p.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FullTekLogo(
                        size: 30,
                        variant: 'Resto',
                        animate: false,
                      ),
                      const SizedBox(height: 8),
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
                          'BACK-OFFICE ERP PRO',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: Color(0xFFC4B5FD),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        store.tenantName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
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
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFF1E293B)),
                Expanded(
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    itemCount: sections.length,
                    itemBuilder: (_, idx) {
                      final s = sections[idx];
                      final active = idx == safeIdx;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: ListTile(
                          key: Key('bo_nav_${s.id}'),
                          dense: true,
                          visualDensity: const VisualDensity(vertical: -1),
                          selected: active,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9)),
                          selectedTileColor:
                              const Color(0xFF7C3AED).withValues(alpha: 0.24),
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
                              fontSize: 12.2,
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
                  padding: const EdgeInsets.all(10),
                  child: OutlinedButton.icon(
                    key: const Key('bo_back_to_pos_btn'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF334155)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
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
                  fontSize: 15.5,
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
  // 1. FOURNISSEURS & ACHATS MULTI-LIGNES (AVEC ENTRÉE EN STOCK & PMP AUTO)
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
                        'Factures & Réceptions (${store.restoPurchases.length})'),
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
                    label: const Text('Réception / Facture Achat (PMP)'),
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
              _kpiChip('Fournisseurs actifs', '${store.restoSuppliers.length}',
                  p.primary, p),
              _kpiChip('Volume Achats TTC',
                  '${totalPurchases.toStringAsFixed(0)} MRU', p.accent, p),
              _kpiChip(
                  'Dettes Fournisseurs',
                  '${(totalDebt > unpaidPurchases ? totalDebt : unpaidPurchases).toStringAsFixed(0)} MRU',
                  p.danger,
                  p),
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
                          final supPurchases = store.restoPurchases
                              .where((pur) =>
                                  pur.supplierId == sup.id ||
                                  pur.supplierName.toLowerCase() ==
                                      sup.name.toLowerCase())
                              .length;
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
                                        '${sup.category} · $supPurchases facture(s)${sup.phone.isNotEmpty ? ' · ${sup.phone}' : ''}${sup.nif.isNotEmpty ? ' · NIF: ${sup.nif}' : ''}',
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
                                      'Dette: ${sup.balanceDueMru.toStringAsFixed(0)} MRU',
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
                                          tooltip: 'Relevé Fournisseur',
                                          icon: const Icon(
                                              Icons.receipt_long_outlined,
                                              size: 18),
                                          onPressed: () =>
                                              _showSupplierStatement(
                                                  store, sup),
                                        ),
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
                                      if (pur.items.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 3),
                                          child: Text(
                                            'Matières reçues : ${pur.items.map((l) => '${l.name} (${l.qty} ${l.unit} × ${l.unitCostMru.toStringAsFixed(0)})').join(', ')}',
                                            style: TextStyle(
                                                fontSize: 11.5,
                                                color: p.accent,
                                                fontWeight: FontWeight.w600),
                                          ),
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
                                            _toast(
                                                'Règlement fournisseur enregistré.');
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
  // 2. FACTURATION B2B / TRAITEUR MULTI-LIGNES + APERÇU FACTURE A4 PRO
  // =========================================================================

  Widget _buildB2bInvoices(PosStore store, PosPalette p) {
    final totalB2b = store.restoInvoices
        .where((i) => i.docType == 'FACTURE')
        .fold<double>(0, (s, i) => s + i.totalTtcMru);
    final totalRemaining = store.restoInvoices
        .where((i) => i.docType == 'FACTURE')
        .fold<double>(0, (s, i) => s + i.remainingMru);
    final countDevis =
        store.restoInvoices.where((i) => i.docType == 'DEVIS').length;

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
                  _kpiChip('Factures B2B TTC',
                      '${totalB2b.toStringAsFixed(0)} MRU', p.primary, p),
                  _kpiChip('Créances Clients B2B',
                      '${totalRemaining.toStringAsFixed(0)} MRU', p.warning, p),
                  _kpiChip('Devis en cours', '$countDevis', p.accent, p),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        _openInvoiceDialog(store, docType: 'DEVIS'),
                    icon: const Icon(Icons.request_quote_outlined, size: 17),
                    label: const Text('Nouveau Devis Multi-Lignes'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () =>
                        _openInvoiceDialog(store, docType: 'FACTURE'),
                    icon: const Icon(Icons.receipt_rounded, size: 17),
                    label: const Text('Nouvelle Facture A4 B2B'),
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
                      'Aucune facture B2B / Traiteur. Créez un devis ou une facture multi-lignes avec aperçu A4.',
                      style: TextStyle(color: p.textMuted),
                    ),
                  )
                : ListView.separated(
                    itemCount: store.restoInvoices.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, idx) {
                      final inv = store.restoInvoices[idx];
                      final isPaid = inv.status == 'PAID';
                      final isDevis = inv.docType == 'DEVIS';
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
                                          color: (isDevis
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
                                              color: isDevis
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
                                  if (inv.items.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Text(
                                        inv.items
                                            .map((l) =>
                                                '${l.qty.toStringAsFixed(0)}× ${l.label}')
                                            .join(' · '),
                                        style: TextStyle(
                                            fontSize: 11.5, color: p.accent),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Wrap(
                              spacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                IconButton(
                                  tooltip: 'Aperçu Facture A4 & Impression',
                                  icon: const Icon(Icons.print_outlined,
                                      size: 19),
                                  onPressed: () =>
                                      _showA4InvoicePreview(store, inv),
                                ),
                                if (isDevis)
                                  OutlinedButton(
                                    onPressed: () async {
                                      final err = await store
                                          .convertRestoDevisToInvoice(inv.id);
                                      if (err != null) {
                                        _toast(err, isError: true);
                                      } else {
                                        _toast(
                                            'Devis converti en Facture B2B !');
                                      }
                                    },
                                    child: const Text('Convertir → Facture'),
                                  )
                                else if (!isPaid)
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
                                  )
                                else
                                  Text('ENCAISSÉ',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: p.success)),
                                IconButton(
                                  tooltip: 'Supprimer',
                                  icon: Icon(Icons.delete_outline,
                                      size: 18, color: p.danger),
                                  onPressed: () async {
                                    await store.deleteRestoB2bInvoice(inv.id);
                                  },
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
  // 3. FICHES TECHNIQUES & MARGES (RECETTES BOM & FOOD COST %)
  // =========================================================================

  Widget _buildRecipesAndFoodCost(PosStore store, PosPalette p) {
    final dishes = store.menuItems;
    if (_selectedBomProductId == null && dishes.isNotEmpty) {
      _selectedBomProductId = dishes.first.id;
    }

    double dishFoodCost(MenuItem d) {
      final lines = store.recipesBom
          .where((r) => r.productId == d.id || r.productSku == d.sku);
      double cost = 0;
      for (final l in lines) {
        final ing = store.ingredients
            .where((i) => i.id == l.ingredientId || i.sku == l.ingredientSku)
            .firstOrNull;
        if (ing != null) {
          cost += l.qtyPerUnit * ing.pmpCostMru;
        }
      }
      return cost;
    }

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
              Text(
                'Fiches Techniques, Coût Matière (PMP) & Simulateur de Marge par Plat',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: p.textPrimary),
              ),
              ElevatedButton.icon(
                onPressed: dishes.isEmpty || store.ingredients.isEmpty
                    ? null
                    : () => _openAddRecipeBomDialog(store),
                icon: const Icon(Icons.add_link_rounded, size: 17),
                label: const Text('Lier un Ingrédient à un Plat'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: dishes.isEmpty
                ? Center(
                    child: Text(
                      'Ajoutez d\'abord vos plats et ingrédients dans "Menu, Familles & Suppléments".',
                      style: TextStyle(color: p.textMuted),
                    ),
                  )
                : ListView.separated(
                    itemCount: dishes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, idx) {
                      final d = dishes[idx];
                      final cost = dishFoodCost(d);
                      final priceHt = d.priceMru - (d.priceMru * 16 / 116);
                      final marginMru = priceHt - cost;
                      final foodCostPct =
                          priceHt > 0 ? (cost / priceHt * 100) : 0.0;
                      final lines = store.recipesBom
                          .where((r) =>
                              r.productId == d.id || r.productSku == d.sku)
                          .toList();
                      final badgeColor = foodCostPct <= 32
                          ? p.success
                          : (foodCostPct <= 42 ? p.warning : p.danger);

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: p.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('${d.icon} ${d.nameFr}',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: p.textPrimary)),
                                const Spacer(),
                                _kpiChip(
                                    'Vente TTC',
                                    '${d.priceMru.toStringAsFixed(0)} MRU',
                                    p.primary,
                                    p),
                                const SizedBox(width: 8),
                                _kpiChip(
                                    'Coût Matière',
                                    '${cost.toStringAsFixed(1)} MRU',
                                    p.warning,
                                    p),
                                const SizedBox(width: 8),
                                _kpiChip(
                                    'Marge HT',
                                    '${marginMru.toStringAsFixed(0)} MRU (Food Cost ${foodCostPct.toStringAsFixed(1)}%)',
                                    badgeColor,
                                    p),
                              ],
                            ),
                            if (lines.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: lines.map((l) {
                                  final ing = store.ingredients
                                      .where((i) =>
                                          i.id == l.ingredientId ||
                                          i.sku == l.ingredientSku)
                                      .firstOrNull;
                                  final ingName =
                                      ing?.nameFr ?? l.ingredientId;
                                  final unit = ing?.unit ?? '';
                                  final lineCost =
                                      l.qtyPerUnit * (ing?.pmpCostMru ?? 0);
                                  return InputChip(
                                    label: Text(
                                      '$ingName: ${l.qtyPerUnit} $unit (${lineCost.toStringAsFixed(1)} MRU)',
                                      style: const TextStyle(fontSize: 11.5),
                                    ),
                                    onDeleted: () =>
                                        store.deleteRecipeBomLine(l.id),
                                  );
                                }).toList(),
                              ),
                            ] else
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Aucune fiche technique définie pour ce plat.',
                                  style: TextStyle(
                                      fontSize: 11.5, color: p.textMuted),
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

  // =========================================================================
  // 4. INVENTAIRE PHYSIQUE, VALORISATION PMP & PERTES / CASSE (WASTE)
  // =========================================================================

  Widget _buildInventoryAndWaste(PosStore store, PosPalette p) {
    final totalStockValue = store.ingredients
        .fold<double>(0, (s, i) => s + i.currentStock * i.pmpCostMru);
    final lowCount = store.ingredients.where((i) => i.isLowStock).length;

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
                  _kpiChip('Matières Premières',
                      '${store.ingredients.length}', p.primary, p),
                  _kpiChip('Valorisation Stock (PMP)',
                      '${totalStockValue.toStringAsFixed(0)} MRU', p.success, p),
                  _kpiChip('Alertes Rupture', '$lowCount',
                      lowCount > 0 ? p.danger : p.success, p),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: store.ingredients.isEmpty
                ? Center(
                    child: Text(
                      'Aucun ingrédient en stock. Ajoutez vos ingrédients dans "Menu, Familles & Suppléments".',
                      style: TextStyle(color: p.textMuted),
                    ),
                  )
                : ListView.separated(
                    itemCount: store.ingredients.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, idx) {
                      final ing = store.ingredients[idx];
                      final valMru = ing.currentStock * ing.pmpCostMru;
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: ing.isLowStock ? p.danger : p.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(ing.nameFr,
                                          style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: p.textPrimary)),
                                      if (ing.isLowStock) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: p.danger
                                                .withValues(alpha: 0.16),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text('STOCK BAS',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  color: p.danger)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Stock théorique: ${ing.currentStock.toStringAsFixed(2)} ${ing.unit} (Seuil min: ${ing.minStock} ${ing.unit}) · PMP: ${ing.pmpCostMru.toStringAsFixed(1)} MRU/${ing.unit} · Valeur: ${valMru.toStringAsFixed(0)} MRU',
                                    style: TextStyle(
                                        fontSize: 12, color: p.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            Wrap(
                              spacing: 6,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _openInventoryCountDialog(
                                      store, ing,
                                      isWaste: false),
                                  icon: const Icon(Icons.fact_check_outlined,
                                      size: 16),
                                  label: const Text('Inventaire Physique'),
                                ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                      foregroundColor: p.danger),
                                  onPressed: () => _openInventoryCountDialog(
                                      store, ing,
                                      isWaste: true),
                                  icon: const Icon(
                                      Icons.delete_sweep_outlined,
                                      size: 16),
                                  label: const Text('Perte / Casse'),
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
  // 5. COMPTABILITÉ, TVA 16 % DGI, CHARGES & GRAND LIVRE CSV
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
                runSpacing: 6,
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
                  ChoiceChip(
                    selected: _accountingSubTab == 2,
                    onSelected: (_) => setState(() => _accountingSubTab = 2),
                    label: const Text('Grand Livre & Export CSV'),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _exportAccountingCsv(store),
                    icon: const Icon(Icons.download_rounded, size: 17),
                    label: const Text('Exporter Grand Livre CSV'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _openExpenseDialog(store),
                    icon: const Icon(Icons.add_card_rounded, size: 17),
                    label: const Text('Ajouter une Charge'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _accountingSubTab == 0
                ? ListView(
                    children: [
                      _accountingCard(
                        title: 'Compte de Résultat Synthétique (MRU)',
                        icon: Icons.trending_up_rounded,
                        p: p,
                        rows: [
                          (
                            'Chiffre d\'Affaires Caisse (TTC)',
                            '${posSalesTtc.toStringAsFixed(0)} MRU',
                            p.textPrimary
                          ),
                          (
                            'Facturation Clients B2B (TTC)',
                            '${b2bSalesTtc.toStringAsFixed(0)} MRU',
                            p.textPrimary
                          ),
                          (
                            'Total Produits / CA Hors Taxes (HT)',
                            '${totalCaHt.toStringAsFixed(0)} MRU',
                            p.primary
                          ),
                          (
                            '(-) Achats Fournisseurs & Matières (HT)',
                            '- ${totalPurchasesHt.toStringAsFixed(0)} MRU',
                            p.warning
                          ),
                          (
                            '(-) Charges d\'Exploitation & Pertes (HT)',
                            '- ${totalExpensesHt.toStringAsFixed(0)} MRU',
                            p.danger
                          ),
                          (
                            '= RÉSULTAT NET D\'EXPLOITATION',
                            '${netProfitHt.toStringAsFixed(0)} MRU (${netMarginPct.toStringAsFixed(1)} %)',
                            netProfitHt >= 0 ? p.success : p.danger
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _accountingCard(
                        title: 'Déclaration TVA Mauritanie — DGI (16 %)',
                        icon: Icons.account_balance_rounded,
                        p: p,
                        rows: [
                          (
                            'TVA Collectée — Ventes Caisse (16 %)',
                            '${posTvaCollected.toStringAsFixed(0)} MRU',
                            p.textPrimary
                          ),
                          (
                            'TVA Collectée — Factures B2B (16 %)',
                            '${b2bTvaCollected.toStringAsFixed(0)} MRU',
                            p.textPrimary
                          ),
                          (
                            'Total TVA Collectée',
                            '${totalTvaCollected.toStringAsFixed(0)} MRU',
                            p.primary
                          ),
                          (
                            '(-) TVA Déductible — Achats Fournisseurs',
                            '- ${totalPurchasesTva.toStringAsFixed(0)} MRU',
                            p.success
                          ),
                          (
                            '(-) TVA Déductible — Charges TTC',
                            '- ${totalExpensesTva.toStringAsFixed(0)} MRU',
                            p.success
                          ),
                          (
                            netTvaDue >= 0
                                ? '= TVA NETTE À PAYER (DGI)'
                                : '= CRÉDIT DE TVA À REPORTER',
                            '${netTvaDue.abs().toStringAsFixed(0)} MRU',
                            netTvaDue >= 0 ? p.warning : p.success
                          ),
                        ],
                      ),
                    ],
                  )
                : _accountingSubTab == 1
                    ? (store.restoExpenses.isEmpty
                        ? Center(
                            child: Text(
                              'Aucune charge enregistrée (Loyer, Salaires, SOMELEC, Gaz...).',
                              style: TextStyle(color: p.textMuted),
                            ),
                          )
                        : ListView.separated(
                            itemCount: store.restoExpenses.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
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
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 7,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: p.danger
                                                      .withValues(alpha: 0.14),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(exp.category,
                                                    style: TextStyle(
                                                        fontSize: 10.5,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: p.danger)),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(exp.label,
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: p.textPrimary)),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '${exp.expenseDate} · ${exp.payMethod}${exp.tvaMru > 0 ? ' · TVA: ${exp.tvaMru.toStringAsFixed(0)} MRU' : ''}',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: p.textMuted),
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
                                        final err = await store
                                            .deleteRestoExpense(exp.id);
                                        if (err != null) {
                                          _toast(err, isError: true);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ))
                    : _buildGeneralLedgerView(store, p),
          ),
        ],
      ),
    );
  }

  List<({String date, String type, String ref, String label, double debit, double credit, String method})>
      _computeLedgerEntries(PosStore store) {
    final entries = <({
      String date,
      String type,
      String ref,
      String label,
      double debit,
      double credit,
      String method
    })>[];

    for (final o in store.completedOrders) {
      final dt = (o.paidAt ?? o.createdAt).toIso8601String().substring(0, 10);
      entries.add((
        date: dt,
        type: 'VENTE_CAISSE',
        ref: o.ticketNumber,
        label: 'Ticket Caisse (${o.serverName ?? o.cashierName ?? o.staffName})',
        debit: 0,
        credit: o.grossTotal,
        method: o.payments.isNotEmpty
            ? o.payments.first.method.name.toUpperCase()
            : 'CASH',
      ));
    }
    for (final inv in store.restoInvoices.where((i) => i.docType == 'FACTURE')) {
      entries.add((
        date: inv.docDate,
        type: 'FACTURE_B2B',
        ref: inv.docNumber,
        label: 'Facture Client ${inv.clientName}',
        debit: 0,
        credit: inv.totalTtcMru,
        method: inv.payMethod,
      ));
    }
    for (final pur in store.restoPurchases) {
      entries.add((
        date: pur.docDate,
        type: 'ACHAT_FOURNISSEUR',
        ref: pur.docNumber,
        label: 'Achat ${pur.supplierName}',
        debit: pur.totalTtcMru,
        credit: 0,
        method: pur.payMethod,
      ));
    }
    for (final exp in store.restoExpenses) {
      entries.add((
        date: exp.expenseDate,
        type: 'CHARGE',
        ref: 'CHG-${exp.id}',
        label: '${exp.category} · ${exp.label}',
        debit: exp.amountMru,
        credit: 0,
        method: exp.payMethod,
      ));
    }
    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  Widget _buildGeneralLedgerView(PosStore store, PosPalette p) {
    final entries = _computeLedgerEntries(store);
    if (entries.isEmpty) {
      return Center(
        child: Text('Aucune écriture comptable pour le moment.',
            style: TextStyle(color: p.textMuted)),
      );
    }
    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (_, idx) {
        final e = entries[idx];
        final isCredit = e.credit > 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.border),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 86,
                child: Text(e.date,
                    style: TextStyle(fontSize: 12, color: p.textMuted)),
              ),
              SizedBox(
                width: 95,
                child: Text(e.ref,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: p.textPrimary)),
              ),
              Expanded(
                child: Text('${e.label} (${e.method})',
                    style: TextStyle(fontSize: 12.5, color: p.textPrimary)),
              ),
              Text(
                isCredit
                    ? '+ ${e.credit.toStringAsFixed(0)} MRU'
                    : '- ${e.debit.toStringAsFixed(0)} MRU',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: isCredit ? p.success : p.danger,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportAccountingCsv(PosStore store) async {
    final entries = _computeLedgerEntries(store);
    final buf = StringBuffer(
        'Date;Type;Reference;Libelle;ModePaiement;Debit_MRU;Credit_MRU\n');
    for (final e in entries) {
      buf.writeln(
          '${e.date};${e.type};${e.ref};"${e.label.replaceAll('"', '\'')}";${e.method};${e.debit.toStringAsFixed(0)};${e.credit.toStringAsFixed(0)}');
    }
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    _toast(
        'Grand Livre CSV (${entries.length} écritures) copié dans le presse-papiers ! Collez-le dans Excel.');
  }

  // =========================================================================
  // 6. TRÉSORERIE MULTI-COMPTES & CLÔTURES Z
  // =========================================================================

  Widget _buildTreasuryAndClosings(PosStore store, PosPalette p) {
    final balances = <String, double>{
      for (final m in _payMethods) m: 0.0,
    };

    String normMethod(String raw) {
      final low = raw.toLowerCase();
      if (low.contains('bankily')) return 'Bankily';
      if (low.contains('masrivi')) return 'Masrivi';
      if (low.contains('sedad')) return 'Sedad';
      if (low.contains('bimbank')) return 'Bimbank';
      if (low.contains('click')) return 'Click';
      if (low.contains('virement') || low.contains('banque')) {
        return 'Virement Bancaire';
      }
      return 'Cash';
    }

    for (final o in store.completedOrders) {
      for (final pe in o.payments) {
        if (pe.method == PaymentMethod.karni) continue;
        final k = pe.method == PaymentMethod.otherWallet
            ? pe.displayLabel
            : normMethod(pe.method.name);
        balances[k] = (balances[k] ?? 0) + pe.amountMru;
      }
    }
    for (final inv in store.restoInvoices) {
      if (inv.paidMru > 0) {
        final k = normMethod(inv.payMethod);
        balances[k] = (balances[k] ?? 0) + inv.paidMru;
      }
    }
    for (final pur in store.restoPurchases) {
      if (pur.paidMru > 0) {
        final k = normMethod(pur.payMethod);
        balances[k] = (balances[k] ?? 0) - pur.paidMru;
      }
    }
    for (final exp in store.restoExpenses) {
      if (exp.payMethod.toLowerCase() == 'stock') continue;
      final k = normMethod(exp.payMethod);
      balances[k] = (balances[k] ?? 0) - exp.amountMru;
    }

    final totalLiquid =
        balances.values.fold<double>(0, (s, v) => s + v);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    selected: _treasurySubTab == 0,
                    onSelected: (_) => setState(() => _treasurySubTab = 0),
                    label: const Text('Comptes Trésorerie (Cash & Wallets)'),
                  ),
                  ChoiceChip(
                    selected: _treasurySubTab == 1,
                    onSelected: (_) => setState(() => _treasurySubTab = 1),
                    label: const Text('Clôtures de Caisse Z'),
                  ),
                ],
              ),
              _kpiChip('Trésorerie Nette Cumulée',
                  '${totalLiquid.toStringAsFixed(0)} MRU', p.success, p),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _treasurySubTab == 0
                ? GridView.extent(
                    maxCrossAxisExtent: 280,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.85,
                    children: balances.entries.map((e) {
                      final posVal = e.value >= 0;
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: p.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.account_balance_wallet_outlined,
                                    color: p.primary, size: 19),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    e.key,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: p.textPrimary),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${e.value.toStringAsFixed(0)} MRU',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: posVal ? p.success : p.danger,
                              ),
                            ),
                            Text(
                              'Solde net (Entrées − Sorties)',
                              style:
                                  TextStyle(fontSize: 11, color: p.textMuted),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  )
                : ClosingZView(store: store),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 7. ÉQUIPE, ACCÈS BACK-OFFICE & IDENTITÉ FISCALE (NIF / RC)
  // =========================================================================

  Widget _buildTeamAndFiscalSettings(PosStore store, PosPalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                selected: _teamSubTab == 0,
                onSelected: (_) => setState(() => _teamSubTab = 0),
                label: const Text('Équipe, Profils & Accès Back-Office'),
              ),
              ChoiceChip(
                selected: _teamSubTab == 1,
                onSelected: (_) => setState(() => _teamSubTab = 1),
                label: const Text(
                    'Identité Fiscale Restaurant (NIF / RC / Factures)'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _teamSubTab == 0
              ? TeamProfilesView(store: store)
              : _buildFiscalIdentityForm(store, p),
        ),
      ],
    );
  }

  Widget _buildFiscalIdentityForm(PosStore store, PosPalette p) {
    final nameCtrl = TextEditingController(text: store.tenantName);
    final arCtrl = TextEditingController(text: store.storeNameAr);
    final addrCtrl = TextEditingController(text: store.storeAddress);
    final phoneCtrl = TextEditingController(text: store.storePhone);
    final nifCtrl = TextEditingController(text: store.storeNif);
    final rcCtrl = TextEditingController(text: store.storeRc);
    final footerCtrl = TextEditingController(text: store.receiptFooter);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Coordonnées Légales & En-tête Factures A4 / Tickets 80mm',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: p.textPrimary),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameCtrl,
                decoration:
                    const InputDecoration(labelText: 'Nom du Restaurant (FR)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: arCtrl,
                decoration:
                    const InputDecoration(labelText: 'Nom du Restaurant (AR)'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: nifCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Numéro NIF (DGI Mauritanie)'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: rcCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Registre de Commerce (RC)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: phoneCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Téléphone'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: addrCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Adresse / Quartier'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: footerCtrl,
                decoration: const InputDecoration(
                    labelText: 'Message pied de ticket 80mm & Facture A4'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  final err = await store.updateRestaurantInfo(
                    name: nameCtrl.text,
                    nameAr: arCtrl.text,
                    address: addrCtrl.text,
                    phone: phoneCtrl.text,
                    nif: nifCtrl.text,
                    rc: rcCtrl.text,
                    footer: footerCtrl.text,
                  );
                  if (err != null) {
                    _toast(err, isError: true);
                  } else {
                    _toast(
                        'Identité fiscale enregistrée sur le serveur !');
                  }
                },
                icon: const Icon(Icons.save_rounded),
                label: const Text('Enregistrer l\'Identité Fiscale'),
              ),
            ],
          ),
        ),
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
  // 8. DIALOGS PRO (Fournisseur, Relevé, Achat Multi-Lignes PMP, Facture A4, BOM, Inventaire)
  // =========================================================================

  void _showSupplierStatement(PosStore store, RestoSupplier sup) {
    final purchases = store.restoPurchases
        .where((pur) =>
            pur.supplierId == sup.id ||
            pur.supplierName.toLowerCase() == sup.name.toLowerCase())
        .toList();
    final totalBought =
        purchases.fold<double>(0, (s, pur) => s + pur.totalTtcMru);
    final totalPaid = purchases.fold<double>(0, (s, pur) => s + pur.paidMru);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Relevé Fournisseur · ${sup.name}'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Total facturé: ${totalBought.toStringAsFixed(0)} MRU · Total réglé: ${totalPaid.toStringAsFixed(0)} MRU · Solde dû: ${sup.balanceDueMru.toStringAsFixed(0)} MRU',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const Divider(height: 18),
              if (purchases.isEmpty)
                const Text('Aucun achat enregistré pour ce fournisseur.')
              else
                SizedBox(
                  height: 240,
                  child: ListView.builder(
                    itemCount: purchases.length,
                    itemBuilder: (_, i) {
                      final pur = purchases[i];
                      return ListTile(
                        dense: true,
                        title: Text('${pur.docNumber} · ${pur.docDate}'),
                        subtitle: Text(
                            'Payé: ${pur.paidMru.toStringAsFixed(0)} / ${pur.totalTtcMru.toStringAsFixed(0)} MRU'),
                        trailing: Text(
                          'Reste: ${pur.remainingMru.toStringAsFixed(0)} MRU',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showA4InvoicePreview(PosStore store, RestoB2bInvoice inv) {
    final words = restoAmountToFrenchWords(inv.totalTtcMru);
    final previewText = '''
==========================================================
${store.tenantName.toUpperCase()}
${store.storeAddress.isNotEmpty ? store.storeAddress : 'Nouakchott, Mauritanie'}
Tél: ${store.storePhone} ${store.storeNif.isNotEmpty ? '· NIF: ${store.storeNif}' : ''} ${store.storeRc.isNotEmpty ? '· RC: ${store.storeRc}' : ''}
==========================================================
${inv.docType} N° : ${inv.docNumber}
Date       : ${inv.docDate}
Client     : ${inv.clientName} ${inv.clientPhone.isNotEmpty ? '(${inv.clientPhone})' : ''}
${inv.clientNif.isNotEmpty ? 'NIF Client : ${inv.clientNif}\n' : ''}----------------------------------------------------------
DÉSIGNATION                          QTÉ    P.U      TOTAL
----------------------------------------------------------
${inv.items.isNotEmpty ? inv.items.map((l) => '${l.label.padRight(34)} ${l.qty.toStringAsFixed(0).padLeft(4)}  ${l.unitPriceMru.toStringAsFixed(0).padLeft(6)}  ${l.lineTotalMru.toStringAsFixed(0).padLeft(8)} MRU').join('\n') : '${(inv.notes.isNotEmpty ? inv.notes : 'Prestation Restauration / Traiteur').padRight(34)}    1  ${inv.totalTtcMru.toStringAsFixed(0).padLeft(6)}  ${inv.totalTtcMru.toStringAsFixed(0).padLeft(8)} MRU'}
----------------------------------------------------------
Total Hors Taxes (HT) : ${inv.subtotalHtMru.toStringAsFixed(0)} MRU
TVA Mauritanie (16 %) : ${inv.tvaMru.toStringAsFixed(0)} MRU
TOTAL TTC             : ${inv.totalTtcMru.toStringAsFixed(0)} MRU
Montant réglé         : ${inv.paidMru.toStringAsFixed(0)} MRU (${inv.payMethod})
Reste à payer         : ${inv.remainingMru.toStringAsFixed(0)} MRU
----------------------------------------------------------
Arrêtée la présente ${inv.docType.toLowerCase()} à la somme de :
$words.
==========================================================
''';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Aperçu Officiel A4 · ${inv.docNumber}'),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: SelectableText(
              previewText,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fermer'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: previewText));
              if (ctx.mounted) Navigator.of(ctx).pop();
              _toast(
                  'Facture A4 copiée ! Vous pouvez l\'imprimer ou l\'envoyer sur WhatsApp.');
            },
            icon: const Icon(Icons.copy_rounded, size: 17),
            label: const Text('Copier / Imprimer / WhatsApp'),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddRecipeBomDialog(PosStore store) async {
    String prodId = store.menuItems.first.id;
    String ingId = store.ingredients.first.id;
    final qtyCtrl = TextEditingController(text: '0.20');

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Ajouter un Ingrédient à la Fiche Technique'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: prodId,
                  decoration: const InputDecoration(labelText: 'Plat du Menu'),
                  items: store.menuItems
                      .map((m) => DropdownMenuItem(
                          value: m.id, child: Text('${m.icon} ${m.nameFr}')))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setD(() => prodId = v);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: ingId,
                  decoration: const InputDecoration(
                      labelText: 'Matière Première / Ingrédient'),
                  items: store.ingredients
                      .map((i) => DropdownMenuItem(
                          value: i.id,
                          child: Text(
                              '${i.nameFr} (${i.unit} · PMP ${i.pmpCostMru.toStringAsFixed(0)} MRU)')))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setD(() => ingId = v);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Quantité consommée par portion (ex: 0.25)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final q = double.tryParse(qtyCtrl.text.trim()) ?? 0;
                final err = await store.saveRecipeBomLine(
                  productId: prodId,
                  ingredientId: ingId,
                  qtyPerUnit: q,
                );
                if (err != null) {
                  _toast(err, isError: true);
                  return;
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
                _toast('Fiche technique mise à jour en base de données.');
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    qtyCtrl.dispose();
  }

  Future<void> _openInventoryCountDialog(PosStore store, Ingredient ing,
      {required bool isWaste}) async {
    final valCtrl = TextEditingController(
        text: isWaste ? '1' : ing.currentStock.toStringAsFixed(2));
    final reasonCtrl = TextEditingController(
        text: isWaste ? 'Péremption / Casse cuisine' : 'Inventaire physique');

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isWaste
            ? 'Déclarer Perte / Casse · ${ing.nameFr}'
            : 'Inventaire Physique · ${ing.nameFr}'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'Stock théorique actuel : ${ing.currentStock.toStringAsFixed(2)} ${ing.unit} (PMP: ${ing.pmpCostMru.toStringAsFixed(1)} MRU)'),
              const SizedBox(height: 12),
              TextField(
                controller: valCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: isWaste
                      ? 'Quantité perdue (${ing.unit}) *'
                      : 'Stock réel compté (${ing.unit}) *',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reasonCtrl,
                decoration:
                    const InputDecoration(labelText: 'Motif / Observation'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final numVal = double.tryParse(valCtrl.text.trim()) ?? 0;
              final err = await store.adjustIngredientInventory(
                ingredientId: ing.id,
                newStock: isWaste ? null : numVal,
                wasteQty: isWaste ? numVal : null,
                reason: reasonCtrl.text,
                recordAsExpense: true,
              );
              if (err != null) {
                _toast(err, isError: true);
                return;
              }
              if (ctx.mounted) Navigator.of(ctx).pop();
              _toast(isWaste
                  ? 'Perte déduite du stock et imputée en charges.'
                  : 'Stock ajusté selon l\'inventaire physique.');
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    valCtrl.dispose();
    reasonCtrl.dispose();
  }

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
    final freightCtrl = TextEditingController(text: '0');
    final notesCtrl = TextEditingController();
    final lineQtyCtrl = TextEditingController(text: '10');
    final lineCostCtrl = TextEditingController(text: '150');
    String? selectedIngId =
        store.ingredients.isNotEmpty ? store.ingredients.first.id : null;
    final lines = <RestoPurchaseLine>[];
    bool includeTva = true;
    String payMethod = 'Cash';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final linesSum =
              lines.fold<double>(0, (s, l) => s + l.lineTotalMru);
          final freight = double.tryParse(freightCtrl.text.trim()) ?? 0;
          if (lines.isNotEmpty) {
            totalCtrl.text = (linesSum + freight).toStringAsFixed(0);
          }
          return AlertDialog(
            title: const Text(
                'Réception Marchandises / Facture Fournisseur (PMP Auto)'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    if (store.ingredients.isNotEmpty) ...[
                      const Divider(height: 20),
                      const Text(
                        'Lignes Matières Premières (Entrée en stock + Recalcul PMP)',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 12.5),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedIngId,
                              isDense: true,
                              decoration: const InputDecoration(
                                  labelText: 'Ingrédient'),
                              items: store.ingredients
                                  .map((i) => DropdownMenuItem(
                                      value: i.id,
                                      child: Text('${i.nameFr} (${i.unit})')))
                                  .toList(),
                              onChanged: (v) =>
                                  setD(() => selectedIngId = v),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: lineQtyCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'Qté', isDense: true),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: lineCostCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'P.U MRU', isDense: true),
                            ),
                          ),
                          IconButton.filledTonal(
                            icon: const Icon(Icons.add_rounded),
                            onPressed: () {
                              final ing = store.ingredients
                                  .where((i) => i.id == selectedIngId)
                                  .firstOrNull;
                              final q =
                                  double.tryParse(lineQtyCtrl.text.trim()) ??
                                      0;
                              final c =
                                  double.tryParse(lineCostCtrl.text.trim()) ??
                                      0;
                              if (ing == null || q <= 0 || c <= 0) return;
                              setD(() {
                                lines.add(RestoPurchaseLine(
                                  ingredientId: ing.id,
                                  name: ing.nameFr,
                                  unit: ing.unit,
                                  qty: q,
                                  unitCostMru: c,
                                ));
                              });
                            },
                          ),
                        ],
                      ),
                      if (lines.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: List.generate(lines.length, (i) {
                            final l = lines[i];
                            return InputChip(
                              label: Text(
                                '${l.name}: ${l.qty} ${l.unit} × ${l.unitCostMru.toStringAsFixed(0)} = ${l.lineTotalMru.toStringAsFixed(0)} MRU',
                                style: const TextStyle(fontSize: 11.5),
                              ),
                              onDeleted: () =>
                                  setD(() => lines.removeAt(i)),
                            );
                          }),
                        ),
                      ],
                      const Divider(height: 20),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: freightCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Frais Transport / Approche (MRU)'),
                            onChanged: (_) => setD(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: totalCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Montant Total TTC (MRU) *'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: paidCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Montant payé (MRU)'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: payMethod,
                            decoration: const InputDecoration(
                                labelText: 'Mode de paiement'),
                            items: _payMethods
                                .map((m) =>
                                    DropdownMenuItem(value: m, child: Text(m)))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setD(() => payMethod = v);
                            },
                          ),
                        ),
                      ],
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
                          labelText: 'Notes / N° BL Fournisseur'),
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
                  final fr = double.tryParse(freightCtrl.text.trim()) ?? 0;
                  final err = await store.createRestoPurchase(
                    supplierId: supId,
                    supplierName: supNameCtrl.text,
                    totalTtcMru: total,
                    paidMru: paid,
                    freightMru: fr,
                    includeTva: includeTva,
                    payMethod: payMethod,
                    notes: notesCtrl.text,
                    items: lines,
                  );
                  if (err != null) {
                    _toast(err, isError: true);
                    return;
                  }
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  _toast(lines.isNotEmpty
                      ? 'Achat enregistré + Stock & PMP mis à jour !'
                      : 'Achat fournisseur enregistré.');
                },
                child: const Text('Valider Réception & Achat'),
              ),
            ],
          );
        },
      ),
    );
    supNameCtrl.dispose();
    totalCtrl.dispose();
    paidCtrl.dispose();
    freightCtrl.dispose();
    notesCtrl.dispose();
    lineQtyCtrl.dispose();
    lineCostCtrl.dispose();
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
    final lineLabelCtrl = TextEditingController();
    final lineQtyCtrl = TextEditingController(text: '1');
    final linePriceCtrl = TextEditingController(text: '1500');
    final lines = <RestoInvoiceLine>[];
    bool includeTva = true;
    String payMethod = 'Bankily';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final linesSum =
              lines.fold<double>(0, (s, l) => s + l.lineTotalMru);
          if (lines.isNotEmpty) {
            totalCtrl.text = linesSum.toStringAsFixed(0);
          }
          return AlertDialog(
            title: Text(docType == 'DEVIS'
                ? 'Nouveau Devis Multi-Lignes (Traiteur / B2B)'
                : 'Nouvelle Facture Client B2B Multi-Lignes'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: clientCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Client / Entreprise / Institution *'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: phoneCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Téléphone'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: nifCtrl,
                            decoration:
                                const InputDecoration(labelText: 'NIF Client'),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    const Text(
                      'Lignes de Facturation (Prestations / Buffets / Plats)',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 12.5),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: TextField(
                            controller: lineLabelCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Désignation (ex: Buffet VIP)',
                                isDense: true),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: lineQtyCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Qté', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: linePriceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'P.U MRU', isDense: true),
                          ),
                        ),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.add_rounded),
                          onPressed: () {
                            final lbl = lineLabelCtrl.text.trim();
                            final q =
                                double.tryParse(lineQtyCtrl.text.trim()) ?? 0;
                            final pr =
                                double.tryParse(linePriceCtrl.text.trim()) ??
                                    0;
                            if (lbl.isEmpty || q <= 0 || pr <= 0) return;
                            setD(() {
                              lines.add(RestoInvoiceLine(
                                  label: lbl, qty: q, unitPriceMru: pr));
                              lineLabelCtrl.clear();
                            });
                          },
                        ),
                      ],
                    ),
                    if (lines.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: List.generate(lines.length, (i) {
                          final l = lines[i];
                          return InputChip(
                            label: Text(
                              '${l.qty.toStringAsFixed(0)}× ${l.label} (${l.lineTotalMru.toStringAsFixed(0)} MRU)',
                              style: const TextStyle(fontSize: 11.5),
                            ),
                            onDeleted: () => setD(() => lines.removeAt(i)),
                          );
                        }),
                      ),
                    ],
                    const Divider(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: totalCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Montant Total TTC (MRU) *'),
                          ),
                        ),
                        if (docType == 'FACTURE') ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: paidCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'Acompte payé (MRU)'),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: payMethod,
                      decoration: const InputDecoration(
                          labelText: 'Mode de règlement'),
                      items: _payMethods
                          .map(
                              (m) => DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setD(() => payMethod = v);
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: includeTva,
                      onChanged: (v) => setD(() => includeTva = v),
                      title:
                          const Text('Appliquer TVA 16 % (DGI Mauritanie)'),
                    ),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Conditions / Notes'),
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
                    items: lines,
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
          );
        },
      ),
    );
    clientCtrl.dispose();
    phoneCtrl.dispose();
    nifCtrl.dispose();
    totalCtrl.dispose();
    paidCtrl.dispose();
    notesCtrl.dispose();
    lineLabelCtrl.dispose();
    lineQtyCtrl.dispose();
    linePriceCtrl.dispose();
  }

  // =========================================================================
  // 9. JOURNAL DES VENTES CAISSE
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
