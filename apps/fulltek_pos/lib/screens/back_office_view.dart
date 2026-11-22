import 'package:flutter/material.dart';
import '../models/pos_models.dart';
import '../state/pos_store.dart';
import '../theme/fulltek_themes.dart';
import '../widgets/fulltek_logo.dart';
import 'closing_z_view.dart';
import 'karni_view.dart';
import 'menu_stock_view.dart';
import 'owner_dashboard_view.dart';
import 'team_profiles_view.dart';

/// Full-Tek Resto Back-Office (ERP-style layout inspired by Full-Tek Commercial).
/// Accessible to the Owner or any role/profile granted [PosPermission.accessBackOffice]
/// (e.g. Commercial, Manager, Accountant).
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
            id: 'menu_stock',
            label: 'Menu, Familles & Stock',
            icon: Icons.inventory_2_rounded,
            view: MenuStockView(store: store),
          ),
          (
            id: 'sales',
            label: 'Journal des Ventes',
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
            width: 245,
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
                          'BACK-OFFICE GESTION',
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
                        padding: const EdgeInsets.only(bottom: 4),
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
                            size: 19,
                            color: active
                                ? const Color(0xFFC4B5FD)
                                : const Color(0xFF94A3B8),
                          ),
                          title: Text(
                            s.label,
                            style: TextStyle(
                              fontSize: 13,
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
              IconButton(
                tooltip: 'Actualiser depuis le serveur',
                onPressed: store.isLoadingCatalog ? null : store.fetchCloudCatalog,
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
