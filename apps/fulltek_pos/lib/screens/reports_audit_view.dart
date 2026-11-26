import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/pos_models.dart';
import '../services/export_helper.dart';
import '../services/receipt_formatter.dart';
import '../services/web_printer.dart';
import '../state/pos_store.dart';
import '../theme/fulltek_themes.dart';

/// Centre de Rapports, Statistiques Graphiques, Facturation Tickets & Journal d'Audit Pro
/// Adapté des meilleurs standards caisse restauration (Aperçu split-screen, Mouchard couleur,
/// 6 graphiques CA, Facturation tickets A4, Export Multi-Rapports Excel/CSV/PDF).
class ReportsAuditView extends StatefulWidget {
  final PosStore store;
  final int initialTab;

  const ReportsAuditView({
    super.key,
    required this.store,
    this.initialTab = 0,
  });

  @override
  State<ReportsAuditView> createState() => _ReportsAuditViewState();
}

class _ReportsAuditViewState extends State<ReportsAuditView> {
  late int _tabIndex; // 0 = Aperçu & Facturation, 1 = Journal Audit, 2 = Graphiques, 3 = Exportation

  // Tab 0 — Aperçu des ventes & Facturation tickets
  String _salesStatusFilter = 'all'; // all | open | closed
  String _salesStaffFilter = 'ALL';
  String _salesPeriod = 'today'; // today | week | month | all
  String _salesQuery = '';
  String? _selectedOrderId;
  final Set<String> _checkedOrderIds = {};

  // Tab 1 — Journal d'audit
  String _auditStaffFilter = 'ALL';
  String _auditActionFilter = 'ALL';
  String _auditPeriod = 'today';

  // Tab 2 — Statistiques graphiques
  String _chartType = 'hourly'; // hourly | weekday | family | channel | monthly | seller

  // Tab 3 — Exportation rapports
  DateTime _exportFrom = DateTime(
      DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime _exportTo = DateTime.now();
  bool _expPayments = true;
  bool _expSellers = true;
  bool _expArticles = true;
  bool _expHourly = true;
  bool _expTicketStats = true;
  bool _expJournal = true;
  bool _expMerchandise = true;

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTab;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _fmtDateTime(DateTime d) =>
      '${_fmtDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  bool _inPeriod(DateTime dt, String period) {
    final now = DateTime.now();
    if (period == 'today') {
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    }
    if (period == 'week') {
      return now.difference(dt).inDays <= 7;
    }
    if (period == 'month') {
      return dt.year == now.year && dt.month == now.month;
    }
    return true;
  }

  String _esc(String s) => const HtmlEscape().convert(s);

  List<PosOrder> _ordersInExportRange(PosStore store) {
    final start =
        DateTime(_exportFrom.year, _exportFrom.month, _exportFrom.day);
    final end = DateTime(
        _exportTo.year, _exportTo.month, _exportTo.day, 23, 59, 59);
    return store.completedOrders.where((o) {
      if (o.isTraining) return false;
      final dt = o.paidAt ?? o.createdAt;
      return !dt.isBefore(start) && !dt.isAfter(end);
    }).toList();
  }

  // =========================================================================
  // FACTURATION D'UN OU PLUSIEURS TICKETS CAISSE -> FACTURE A4 OFFICIELLE
  // =========================================================================
  Future<void> _invoiceSelectedTickets(List<PosOrder> orders) async {
    if (orders.isEmpty) {
      _toast('Sélectionnez au moins un ticket clôturé à facturer.');
      return;
    }
    final store = widget.store;
    final clientCtrl = TextEditingController(
      text: orders.first.customerName?.trim().isNotEmpty == true
          ? orders.first.customerName!.trim()
          : 'Client Passage',
    );
    final nifCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Facturer ${orders.length} ticket(s) en Facture A4'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: clientCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom du Client / Société *',
                  prefixIcon: Icon(Icons.business_rounded),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nifCtrl,
                decoration: const InputDecoration(
                  labelText: 'NIF / RC Client (optionnel)',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.description_rounded, size: 17),
            label: const Text('Générer Facture A4'),
          ),
        ],
      ),
    );
    final clientName = clientCtrl.text.trim().isEmpty
        ? 'Client Passage'
        : clientCtrl.text.trim();
    final clientNif = nifCtrl.text.trim();
    clientCtrl.dispose();
    nifCtrl.dispose();
    if (ok != true) return;

    final invNo = store.createInvoiceNumberForOrders(orders);
    final grandTotal = orders.fold<double>(0, (s, o) => s + o.netTotal);
    final tvaRate = store.tvaEnabled ? store.tvaRatePercent : 0.0;
    final tvaAmt = tvaRate > 0 ? (grandTotal * tvaRate / (100 + tvaRate)) : 0.0;
    final htAmt = grandTotal - tvaAmt;

    final rowsHtml = StringBuffer();
    for (final o in orders) {
      for (final line in o.items) {
        rowsHtml.writeln(
          '<tr>'
          '<td>${_esc(o.ticketNumber)}</td>'
          '<td>${_esc(line.item.nameFr)}</td>'
          '<td class="num">${line.quantity}</td>'
          '<td class="num">${line.unitPriceWithModifiers.toStringAsFixed(0)} MRU</td>'
          '<td class="num">${line.isComp ? 'OFFERT' : '${line.lineTotal.toStringAsFixed(0)} MRU'}</td>'
          '</tr>',
        );
      }
    }

    final html = '''
<div class="header">
  <div>
    <h1>${_esc(store.tenantName)}</h1>
    <div class="meta">${_esc(store.storeAddress)} · Tél: ${_esc(store.storePhone)}</div>
    <div class="meta">${store.storeNif.isNotEmpty ? 'NIF: ${_esc(store.storeNif)} · ' : ''}${store.storeRc.isNotEmpty ? 'RC: ${_esc(store.storeRc)}' : ''}</div>
  </div>
  <div style="text-align:right;">
    <div style="font-size:16px;font-weight:900;color:#059669;">FACTURE $invNo</div>
    <div class="meta">Date : ${_fmtDate(DateTime.now())}</div>
    <div class="meta">Client : <b>${_esc(clientName)}</b>${clientNif.isNotEmpty ? ' · NIF: ${_esc(clientNif)}' : ''}</div>
  </div>
</div>
<h2>Détail des prestations (${orders.length} ticket(s) caisse)</h2>
<table>
  <thead><tr><th>N° Ticket</th><th>Désignation</th><th class="num">Qté</th><th class="num">P.U.</th><th class="num">Total</th></tr></thead>
  <tbody>
    $rowsHtml
    ${tvaRate > 0 ? '<tr><td colspan="4" class="num"><b>Sous-total HT</b></td><td class="num">${htAmt.toStringAsFixed(0)} MRU</td></tr><tr><td colspan="4" class="num"><b>TVA (${tvaRate.toStringAsFixed(0)}%)</b></td><td class="num">${tvaAmt.toStringAsFixed(0)} MRU</td></tr>' : ''}
    <tr class="total-row"><td colspan="4" class="num">TOTAL NET À PAYER (TTC)</td><td class="num">${grandTotal.toStringAsFixed(0)} MRU</td></tr>
  </tbody>
</table>
<p class="meta">Facture acquittée en caisse · Générée par Full-Tek Resto POS.</p>
''';

    final printed = printReportA4Html('Facture $invNo', html);
    _toast(printed
        ? 'Facture $invNo générée et prête à imprimer en PDF !'
        : 'Facture $invNo enregistrée.');
  }

  // =========================================================================
  // BUILD
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final store = widget.store;
        final p = FullTekThemes.paletteOf(context);
        return Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    key: const Key('reports_tab_sales'),
                    selected: _tabIndex == 0,
                    onSelected: (_) => setState(() => _tabIndex = 0),
                    label: const Text('🧾 Aperçu Ventes & Facturation'),
                  ),
                  ChoiceChip(
                    key: const Key('reports_tab_audit'),
                    selected: _tabIndex == 1,
                    onSelected: (_) => setState(() => _tabIndex = 1),
                    label: Text(
                        '🛡️ Journal d\'Audit (${store.fullAuditTimeline.length})'),
                  ),
                  ChoiceChip(
                    key: const Key('reports_tab_charts'),
                    selected: _tabIndex == 2,
                    onSelected: (_) => setState(() => _tabIndex = 2),
                    label: const Text('📊 Statistiques Graphiques'),
                  ),
                  ChoiceChip(
                    key: const Key('reports_tab_export'),
                    selected: _tabIndex == 3,
                    onSelected: (_) => setState(() => _tabIndex = 3),
                    label: const Text('📤 Exportation Rapports (Excel / PDF)'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: switch (_tabIndex) {
                  0 => _buildSalesOverviewTab(store, p),
                  1 => _buildAuditJournalTab(store, p),
                  2 => _buildGraphicalStatsTab(store, p),
                  _ => _buildExportReportsTab(store, p),
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================================
  // TAB 0 — APERÇU DES VENTES (SPLIT-SCREEN) & FACTURATION TICKETS
  // =========================================================================
  Widget _buildSalesOverviewTab(PosStore store, PosPalette p) {
    final openOrders =
        store.waitingOrders.where((o) => !o.isTraining).toList();
    final closedOrders =
        store.completedOrders.where((o) => !o.isTraining).toList();

    final combined = <({PosOrder order, bool isOpen})>[
      if (_salesStatusFilter != 'closed')
        ...openOrders.map((o) => (order: o, isOpen: true)),
      if (_salesStatusFilter != 'open')
        ...closedOrders.map((o) => (order: o, isOpen: false)),
    ];

    final allSellers = <String>{
      'ALL',
      ...store.staff.map((s) => s.name),
      ...combined.map((e) => e.order.cashierName ?? e.order.staffName),
    }.toList();

    final q = _salesQuery.trim().toLowerCase();
    final filtered = combined.where((entry) {
      final o = entry.order;
      final dt = o.paidAt ?? o.createdAt;
      if (!_inPeriod(dt, _salesPeriod)) return false;
      final seller = (o.cashierName ?? o.staffName).trim();
      if (_salesStaffFilter != 'ALL' && seller != _salesStaffFilter) {
        return false;
      }
      if (q.isNotEmpty) {
        final hay =
            '${o.ticketNumber} ${o.customerName ?? ''} ${o.tableCode ?? ''} $seller'
                .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();

    final selectedEntry = filtered
        .where((e) => e.order.id == _selectedOrderId)
        .firstOrNull ?? (filtered.isNotEmpty ? filtered.first : null);
    final selectedOrder = selectedEntry?.order;

    final totalMru =
        filtered.fold<double>(0, (s, e) => s + e.order.netTotal);

    final wide = MediaQuery.of(context).size.width >= 960;

    final listPane = Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: p.surfaceAlt,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 28),
                const Expanded(
                    flex: 2,
                    child: Text('N° Ticket / Date',
                        style: TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w900))),
                const Expanded(
                    flex: 2,
                    child: Text('Table / Client',
                        style: TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w900))),
                const Expanded(
                    flex: 2,
                    child: Text('Vendeur',
                        style: TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w900))),
                const SizedBox(
                    width: 85,
                    child: Text('Montant',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w900))),
                const SizedBox(
                    width: 72,
                    child: Text('Facture',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w900))),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text('Aucune vente pour ces critères.',
                        style: TextStyle(color: p.textMuted)))
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: p.border),
                    itemBuilder: (_, idx) {
                      final e = filtered[idx];
                      final o = e.order;
                      final isSel = selectedOrder?.id == o.id;
                      final invNo = store.invoicedTicketsByOrderId[o.id];
                      final dt = o.paidAt ?? o.createdAt;
                      return InkWell(
                        onTap: () => setState(() => _selectedOrderId = o.id),
                        child: Container(
                          color: isSel
                              ? p.primary.withValues(alpha: 0.14)
                              : (e.isOpen
                                  ? p.warning.withValues(alpha: 0.06)
                                  : null),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 28,
                                child: e.isOpen
                                    ? Icon(Icons.hourglass_top_rounded,
                                        size: 16, color: p.warning)
                                    : Checkbox(
                                        value: _checkedOrderIds.contains(o.id),
                                        onChanged: (v) => setState(() {
                                          if (v == true) {
                                            _checkedOrderIds.add(o.id);
                                          } else {
                                            _checkedOrderIds.remove(o.id);
                                          }
                                        }),
                                      ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(o.ticketNumber,
                                        style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w900,
                                            color: p.textPrimary)),
                                    Text(_fmtDateTime(dt),
                                        style: TextStyle(
                                            fontSize: 10.5,
                                            color: p.textMuted)),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  o.tableCode != null
                                      ? 'Table ${o.tableCode}'
                                      : (o.customerName?.isNotEmpty == true
                                          ? o.customerName!
                                          : 'PASSAGER'),
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: p.textPrimary),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  o.cashierName ?? o.staffName,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 11.5, color: p.textMuted),
                                ),
                              ),
                              SizedBox(
                                width: 85,
                                child: Text(
                                  '${o.netTotal.toStringAsFixed(0)} MRU',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w900,
                                      color: p.primary),
                                ),
                              ),
                              SizedBox(
                                width: 72,
                                child: Text(
                                  e.isOpen
                                      ? 'EN COURS'
                                      : (invNo ?? 'NF'),
                                  textAlign: TextAlign.right,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: e.isOpen
                                        ? p.warning
                                        : (invNo != null
                                            ? p.success
                                            : p.textMuted),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: p.surfaceAlt,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(13)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filtered.length} ticket(s) · Total : ${totalMru.toStringAsFixed(0)} MRU',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: p.textPrimary),
                ),
                ElevatedButton.icon(
                  key: const Key('invoice_selected_tickets_btn'),
                  onPressed: () {
                    final targets = _checkedOrderIds.isNotEmpty
                        ? closedOrders
                            .where((o) => _checkedOrderIds.contains(o.id))
                            .toList()
                        : (selectedEntry != null && !selectedEntry.isOpen
                            ? [selectedEntry.order]
                            : <PosOrder>[]);
                    _invoiceSelectedTickets(targets);
                  },
                  icon: const Icon(Icons.description_rounded, size: 16),
                  label: Text(_checkedOrderIds.isNotEmpty
                      ? 'Facturer (${_checkedOrderIds.length})'
                      : 'Facturer (A4)'),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final previewText = selectedOrder == null
        ? 'Sélectionnez un ticket dans la liste pour consulter son détail.'
        : ReceiptFormatter.formatOrderReceipt80mm(
            order: selectedOrder,
            storeName: store.tenantName,
            storeNameAr: store.storeNameAr,
            address: store.storeAddress,
            phone: store.storePhone,
            nif: store.storeNif,
            rc: store.storeRc,
            footer: store.receiptFooter,
            showTva: store.tvaEnabled,
            tvaRatePercent: store.tvaRatePercent,
          );

    final previewPane = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                selectedOrder == null
                    ? 'Aperçu Ticket'
                    : 'Ticket ${selectedOrder.ticketNumber}',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: p.textPrimary),
              ),
              if (selectedOrder != null)
                OutlinedButton.icon(
                  onPressed: () => printThermal80mm(
                    'Duplicata ${selectedOrder.ticketNumber}',
                    previewText,
                    logoDataUrl: store.receiptLogoDataUrl,
                    logoPosition: store.receiptLogoPosition,
                  ),
                  icon: const Icon(Icons.print_rounded, size: 15),
                  label: const Text('Duplicata 80mm'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD6D3D1)),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  previewText,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    height: 1.35,
                    color: Color(0xFF1C1917),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChoiceChip(
              selected: _salesStatusFilter == 'all',
              onSelected: (_) => setState(() => _salesStatusFilter = 'all'),
              label: const Text('Toutes'),
            ),
            ChoiceChip(
              selected: _salesStatusFilter == 'open',
              onSelected: (_) => setState(() => _salesStatusFilter = 'open'),
              label: Text('En Cours (${openOrders.length})'),
            ),
            ChoiceChip(
              selected: _salesStatusFilter == 'closed',
              onSelected: (_) => setState(() => _salesStatusFilter = 'closed'),
              label: Text('Clôturées (${closedOrders.length})'),
            ),
            DropdownButton<String>(
              value: _salesPeriod,
              items: const [
                DropdownMenuItem(value: 'today', child: Text('Aujourd\'hui')),
                DropdownMenuItem(value: 'week', child: Text('7 jours')),
                DropdownMenuItem(value: 'month', child: Text('Ce mois')),
                DropdownMenuItem(value: 'all', child: Text('Toute période')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _salesPeriod = v);
              },
            ),
            DropdownButton<String>(
              value: allSellers.contains(_salesStaffFilter)
                  ? _salesStaffFilter
                  : 'ALL',
              items: allSellers
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s == 'ALL' ? 'Vendeur : Tous' : s),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _salesStaffFilter = v);
              },
            ),
            SizedBox(
              width: 200,
              child: TextField(
                onChanged: (v) => setState(() => _salesQuery = v),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Ticket / Client...',
                  prefixIcon: Icon(Icons.search_rounded, size: 18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: wide
              ? Row(
                  children: [
                    Expanded(flex: 3, child: listPane),
                    const SizedBox(width: 12),
                    SizedBox(width: 350, child: previewPane),
                  ],
                )
              : Column(
                  children: [
                    Expanded(flex: 2, child: listPane),
                    const SizedBox(height: 10),
                    Expanded(child: previewPane),
                  ],
                ),
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 1 — JOURNAL D'AUDIT / ÉVÉNEMENTS CAISSE (MOUCHARD EN COULEURS)
  // =========================================================================
  Color _auditColor(String action) => switch (action) {
        'VENTE' => const Color(0xFFEC4899),
        'MISE EN ATTENTE' => const Color(0xFFEAB308),
        'EDITION NOTE' => const Color(0xFF0EA5E9),
        'OUVERTURE TIROIR' => const Color(0xFFF97316),
        'ANNULATION' => const Color(0xFFEF4444),
        'OFFERT' => const Color(0xFF10B981),
        'FACTURATION' => const Color(0xFF8B5CF6),
        _ => const Color(0xFF64748B),
      };

  Widget _buildAuditJournalTab(PosStore store, PosPalette p) {
    final allEvents = store.fullAuditTimeline;
    final staffList = <String>{
      'ALL',
      ...store.staff.map((s) => s.name),
      ...allEvents.map((e) => e.staffName),
    }.toList();
    const actionTypes = [
      'ALL',
      'VENTE',
      'MISE EN ATTENTE',
      'EDITION NOTE',
      'OUVERTURE TIROIR',
      'ANNULATION',
      'OFFERT',
      'FACTURATION',
    ];

    final filtered = allEvents.where((e) {
      if (!_inPeriod(e.timestamp, _auditPeriod)) return false;
      if (_auditStaffFilter != 'ALL' && e.staffName != _auditStaffFilter) {
        return false;
      }
      if (_auditActionFilter != 'ALL' && e.action != _auditActionFilter) {
        return false;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<String>(
                  value: staffList.contains(_auditStaffFilter)
                      ? _auditStaffFilter
                      : 'ALL',
                  items: staffList
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(
                                s == 'ALL' ? 'Tous les utilisateurs' : s),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _auditStaffFilter = v);
                  },
                ),
                DropdownButton<String>(
                  value: _auditActionFilter,
                  items: actionTypes
                      .map((a) => DropdownMenuItem(
                            value: a,
                            child: Text(
                                a == 'ALL' ? 'Tous les événements' : a),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _auditActionFilter = v);
                  },
                ),
                DropdownButton<String>(
                  value: _auditPeriod,
                  items: const [
                    DropdownMenuItem(
                        value: 'today', child: Text('Aujourd\'hui')),
                    DropdownMenuItem(value: 'week', child: Text('7 jours')),
                    DropdownMenuItem(value: 'month', child: Text('Ce mois')),
                    DropdownMenuItem(value: 'all', child: Text('Tout')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _auditPeriod = v);
                  },
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    store.recordCashDrawerOpen(
                        reason: 'Ouverture manuelle depuis Journal Audit');
                    _toast('Ouverture tiroir enregistrée dans le journal.');
                  },
                  icon: const Icon(Icons.point_of_sale_rounded, size: 16),
                  label: const Text('Tracer ouverture tiroir'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    final buf = StringBuffer(
                        'Date;Action;Utilisateur;N° Ticket;Commentaire\n');
                    for (final e in filtered) {
                      buf.writeln(
                        '"${_fmtDateTime(e.timestamp)}";"${e.action}";"${e.staffName}";"${e.ticketNumber}";"${e.comment.replaceAll('"', '""')}"',
                      );
                    }
                    final ok = downloadTextFile(
                      'journal_audit_${DateTime.now().millisecondsSinceEpoch}.csv',
                      buf.toString(),
                    );
                    _toast(ok
                        ? 'Journal d\'audit exporté en CSV / Excel !'
                        : 'Export CSV disponible sur la version Web.');
                  },
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Exporter CSV'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.border),
            ),
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'Aucun événement enregistré sur cette période.',
                      style: TextStyle(color: p.textMuted),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: p.border),
                    itemBuilder: (_, idx) {
                      final e = filtered[idx];
                      final c = _auditColor(e.action);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        color: c.withValues(alpha: 0.08),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 118,
                              child: Text(
                                _fmtDateTime(e.timestamp),
                                style: TextStyle(
                                    fontSize: 11.5, color: p.textMuted),
                              ),
                            ),
                            Container(
                              width: 132,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: c.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: c.withValues(alpha: 0.5)),
                              ),
                              child: Text(
                                e.action,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  color: c,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 150,
                              child: Text(
                                e.staffName,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: p.textPrimary),
                              ),
                            ),
                            SizedBox(
                              width: 82,
                              child: Text(
                                e.ticketNumber,
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: p.primary),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                e.comment,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12, color: p.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: const [
            'VENTE',
            'MISE EN ATTENTE',
            'EDITION NOTE',
            'OUVERTURE TIROIR',
            'ANNULATION',
            'OFFERT',
            'FACTURATION',
          ].map((act) {
            final c = _auditColor(act);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: c, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 4),
                Text(act,
                    style:
                        const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 2 — STATISTIQUES GRAPHIQUES (6 GRAPHES CA)
  // =========================================================================
  Widget _buildGraphicalStatsTab(PosStore store, PosPalette p) {
    final orders =
        store.completedOrders.where((o) => !o.isTraining).toList();
    final buckets = <String, double>{};

    if (_chartType == 'hourly') {
      for (final o in orders) {
        final h = (o.paidAt ?? o.createdAt).hour;
        final label = '${h.toString().padLeft(2, '0')}h - ${(h + 1).toString().padLeft(2, '0')}h';
        buckets[label] = (buckets[label] ?? 0) + o.netTotal;
      }
    } else if (_chartType == 'weekday') {
      const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
      for (final d in days) {
        buckets[d] = 0;
      }
      for (final o in orders) {
        final wd = (o.paidAt ?? o.createdAt).weekday; // 1..7
        final key = days[(wd - 1).clamp(0, 6)];
        buckets[key] = (buckets[key] ?? 0) + o.netTotal;
      }
    } else if (_chartType == 'family') {
      final catNames = {for (final c in store.categories) c.id: c.label(store.lang)};
      for (final o in orders) {
        for (final line in o.items) {
          final k = catNames[line.item.categoryId] ?? line.item.categoryId;
          buckets[k] = (buckets[k] ?? 0) + line.lineTotal;
        }
      }
    } else if (_chartType == 'channel') {
      for (final o in orders) {
        final k = switch (o.serviceMode) {
          ServiceMode.dineIn => 'Sur place (Salle / Khaima)',
          ServiceMode.takeaway => 'À emporter',
          ServiceMode.delivery =>
            'Livraison · ${o.deliveryZone?.nameFr ?? 'Nouakchott'}',
        };
        buckets[k] = (buckets[k] ?? 0) + o.netTotal;
      }
    } else if (_chartType == 'monthly') {
      const months = [
        'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
        'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'
      ];
      for (final o in orders) {
        final dt = o.paidAt ?? o.createdAt;
        final k = '${months[dt.month - 1]} ${dt.year}';
        buckets[k] = (buckets[k] ?? 0) + o.netTotal;
      }
    } else {
      // seller
      for (final o in orders) {
        final k = (o.cashierName ?? o.staffName).trim();
        buckets[k] = (buckets[k] ?? 0) + o.netTotal;
      }
    }

    final entries = buckets.entries.toList();
    if (_chartType != 'weekday' && _chartType != 'hourly') {
      entries.sort((a, b) => b.value.compareTo(a.value));
    } else if (_chartType == 'hourly') {
      entries.sort((a, b) => a.key.compareTo(b.key));
    }
    final maxVal =
        entries.fold<double>(0, (m, e) => e.value > m ? e.value : m);
    final sumVal = entries.fold<double>(0, (s, e) => s + e.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            ChoiceChip(
              selected: _chartType == 'hourly',
              onSelected: (_) => setState(() => _chartType = 'hourly'),
              label: const Text('🕒 CA par Tranches Horaires'),
            ),
            ChoiceChip(
              selected: _chartType == 'weekday',
              onSelected: (_) => setState(() => _chartType = 'weekday'),
              label: const Text('📅 CA par Jour de Semaine'),
            ),
            ChoiceChip(
              selected: _chartType == 'family',
              onSelected: (_) => setState(() => _chartType = 'family'),
              label: const Text('🍽 CA par Famille'),
            ),
            ChoiceChip(
              selected: _chartType == 'channel',
              onSelected: (_) => setState(() => _chartType = 'channel'),
              label: const Text('🗺 CA par Zone / Canal'),
            ),
            ChoiceChip(
              selected: _chartType == 'monthly',
              onSelected: (_) => setState(() => _chartType = 'monthly'),
              label: const Text('📈 Évolution CA Mensuel'),
            ),
            ChoiceChip(
              selected: _chartType == 'seller',
              onSelected: (_) => setState(() => _chartType = 'seller'),
              label: const Text('👤 Résultats par Vendeur'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.border),
            ),
            child: entries.isEmpty || sumVal <= 0
                ? Center(
                    child: Text(
                      'Aucune vente clôturée disponible pour ce graphique.',
                      style: TextStyle(color: p.textMuted),
                    ),
                  )
                : ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, idx) {
                      final e = entries[idx];
                      final pct = sumVal > 0 ? (e.value / sumVal * 100) : 0.0;
                      final ratio = maxVal > 0 ? (e.value / maxVal) : 0.0;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  e.key,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: p.textPrimary,
                                  ),
                                ),
                              ),
                              Text(
                                '${e.value.toStringAsFixed(0)} MRU (${pct.toStringAsFixed(1)}%)',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                  color: p.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: ratio.clamp(0.0, 1.0),
                              minHeight: 12,
                              backgroundColor: p.surfaceAlt,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                idx == 0 ? p.primary : const Color(0xFF0EA5E9),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 3 — EXPORTATION MULTI-RAPPORTS (EXCEL / CSV / PDF A4)
  // =========================================================================
  String _buildExportCsv(PosStore store, List<PosOrder> orders) {
    final buf = StringBuffer();
    buf.writeln(
        'FULL-TEK RESTO · EXPORT RAPPORTS (${_fmtDate(_exportFrom)} au ${_fmtDate(_exportTo)})');
    buf.writeln('Restaurant;${store.tenantName}');
    buf.writeln('');

    if (_expPayments) {
      buf.writeln('=== RECAPITULATIF DES REGLEMENTS ===');
      buf.writeln('Mode;Montant MRU');
      final byPay = <String, double>{};
      for (final o in orders) {
        for (final pay in o.payments) {
          final k = pay.displayLabel;
          byPay[k] = (byPay[k] ?? 0) + pay.amountMru;
        }
      }
      for (final e in byPay.entries) {
        buf.writeln('${e.key};${e.value.toStringAsFixed(0)}');
      }
      buf.writeln('');
    }

    if (_expSellers) {
      buf.writeln('=== RECAPITULATIF RESULTATS VENDEURS ===');
      buf.writeln('Vendeur;Nb Tickets;CA Total MRU;Panier Moyen MRU');
      final cnt = <String, int>{};
      final tot = <String, double>{};
      for (final o in orders) {
        final s = o.cashierName ?? o.staffName;
        cnt[s] = (cnt[s] ?? 0) + 1;
        tot[s] = (tot[s] ?? 0) + o.netTotal;
      }
      for (final s in tot.keys) {
        final avg = cnt[s]! > 0 ? tot[s]! / cnt[s]! : 0;
        buf.writeln('$s;${cnt[s]};${tot[s]!.toStringAsFixed(0)};${avg.toStringAsFixed(0)}');
      }
      buf.writeln('');
    }

    if (_expArticles) {
      buf.writeln('=== RECAPITULATIF VENTES PAR ARTICLES ===');
      buf.writeln('Article;Quantite;Total MRU');
      final qty = <String, int>{};
      final tot = <String, double>{};
      for (final o in orders) {
        for (final l in o.items) {
          qty[l.item.nameFr] = (qty[l.item.nameFr] ?? 0) + l.quantity;
          tot[l.item.nameFr] = (tot[l.item.nameFr] ?? 0) + l.lineTotal;
        }
      }
      for (final a in tot.keys) {
        buf.writeln('"$a";${qty[a]};${tot[a]!.toStringAsFixed(0)}');
      }
      buf.writeln('');
    }

    if (_expHourly) {
      buf.writeln('=== RECAPITULATIF VENTES PAR TRANCHE HORAIRE ===');
      buf.writeln('Tranche;Nb Tickets;CA MRU');
      final cnt = <int, int>{};
      final tot = <int, double>{};
      for (final o in orders) {
        final h = (o.paidAt ?? o.createdAt).hour;
        cnt[h] = (cnt[h] ?? 0) + 1;
        tot[h] = (tot[h] ?? 0) + o.netTotal;
      }
      final hours = tot.keys.toList()..sort();
      for (final h in hours) {
        buf.writeln('${h}h-${h + 1}h;${cnt[h]};${tot[h]!.toStringAsFixed(0)}');
      }
      buf.writeln('');
    }

    if (_expTicketStats) {
      final sum = orders.fold<double>(0, (s, o) => s + o.netTotal);
      final avg = orders.isEmpty ? 0 : sum / orders.length;
      buf.writeln('=== RECAPITULATIF NOMBRE DE TICKETS ===');
      buf.writeln('Nombre de tickets;${orders.length}');
      buf.writeln('Chiffre d\'affaires total;${sum.toStringAsFixed(0)}');
      buf.writeln('Panier moyen;${avg.toStringAsFixed(0)}');
      buf.writeln('');
    }

    if (_expJournal) {
      buf.writeln('=== JOURNAL DES TICKETS ===');
      buf.writeln('Ticket;Date;Table/Mode;Vendeur;Client;Total MRU');
      for (final o in orders) {
        buf.writeln(
          '${o.ticketNumber};${_fmtDateTime(o.paidAt ?? o.createdAt)};${o.tableCode ?? o.serviceMode.name};"${o.cashierName ?? o.staffName}";"${o.customerName ?? 'PASSAGER'}";${o.netTotal.toStringAsFixed(0)}',
        );
      }
      buf.writeln('');
    }

    if (_expMerchandise) {
      buf.writeln('=== CONSOMMATIONS MARCHANDISES (STOCK) ===');
      buf.writeln('Ingredient;Stock Actuel;Unite;Cout PMP MRU');
      for (final ing in store.ingredients) {
        buf.writeln(
          '"${ing.nameFr}";${ing.currentStock.toStringAsFixed(2)};${ing.unit};${ing.pmpCostMru.toStringAsFixed(0)}',
        );
      }
    }
    return buf.toString();
  }

  String _buildExportPdfHtml(PosStore store, List<PosOrder> orders) {
    final sum = orders.fold<double>(0, (s, o) => s + o.netTotal);
    final avg = orders.isEmpty ? 0.0 : sum / orders.length;
    final b = StringBuffer();
    b.writeln('''
<div class="header">
  <div>
    <h1>${_esc(store.tenantName)} · Rapport de Gestion</h1>
    <div class="meta">Période : Du ${_fmtDate(_exportFrom)} au ${_fmtDate(_exportTo)}</div>
  </div>
  <div style="text-align:right;">
    <div style="font-size:15px;font-weight:900;color:#059669;">CA : ${sum.toStringAsFixed(0)} MRU</div>
    <div class="meta">${orders.length} ticket(s) · Panier moyen : ${avg.toStringAsFixed(0)} MRU</div>
  </div>
</div>
''');

    if (_expPayments) {
      final byPay = <String, double>{};
      for (final o in orders) {
        for (final pay in o.payments) {
          byPay[pay.displayLabel] = (byPay[pay.displayLabel] ?? 0) + pay.amountMru;
        }
      }
      b.writeln('<h2>Récapitulatif des règlements</h2><table><thead><tr><th>Mode</th><th class="num">Montant</th></tr></thead><tbody>');
      for (final e in byPay.entries) {
        b.writeln('<tr><td>${_esc(e.key)}</td><td class="num">${e.value.toStringAsFixed(0)} MRU</td></tr>');
      }
      b.writeln('</tbody></table>');
    }

    if (_expSellers) {
      final cnt = <String, int>{};
      final tot = <String, double>{};
      for (final o in orders) {
        final s = o.cashierName ?? o.staffName;
        cnt[s] = (cnt[s] ?? 0) + 1;
        tot[s] = (tot[s] ?? 0) + o.netTotal;
      }
      b.writeln('<h2>Récapitulatif des résultats vendeurs</h2><table><thead><tr><th>Vendeur</th><th class="num">Tickets</th><th class="num">Total</th></tr></thead><tbody>');
      for (final s in tot.keys) {
        b.writeln('<tr><td>${_esc(s)}</td><td class="num">${cnt[s]}</td><td class="num">${tot[s]!.toStringAsFixed(0)} MRU</td></tr>');
      }
      b.writeln('</tbody></table>');
    }

    if (_expArticles) {
      final qty = <String, int>{};
      final tot = <String, double>{};
      for (final o in orders) {
        for (final l in o.items) {
          qty[l.item.nameFr] = (qty[l.item.nameFr] ?? 0) + l.quantity;
          tot[l.item.nameFr] = (tot[l.item.nameFr] ?? 0) + l.lineTotal;
        }
      }
      b.writeln('<h2>Récapitulatif des ventes par articles</h2><table><thead><tr><th>Article</th><th class="num">Qté</th><th class="num">Total</th></tr></thead><tbody>');
      for (final a in tot.keys) {
        b.writeln('<tr><td>${_esc(a)}</td><td class="num">${qty[a]}</td><td class="num">${tot[a]!.toStringAsFixed(0)} MRU</td></tr>');
      }
      b.writeln('</tbody></table>');
    }

    if (_expJournal) {
      b.writeln('<h2>Journal des tickets</h2><table><thead><tr><th>Ticket</th><th>Date</th><th>Vendeur</th><th class="num">Montant</th></tr></thead><tbody>');
      for (final o in orders.take(60)) {
        b.writeln('<tr><td>${_esc(o.ticketNumber)}</td><td>${_fmtDateTime(o.paidAt ?? o.createdAt)}</td><td>${_esc(o.cashierName ?? o.staffName)}</td><td class="num">${o.netTotal.toStringAsFixed(0)} MRU</td></tr>');
      }
      b.writeln('</tbody></table>');
    }
    return b.toString();
  }

  Widget _buildExportReportsTab(PosStore store, PosPalette p) {
    final orders = _ordersInExportRange(store);
    final totalMru = orders.fold<double>(0, (s, o) => s + o.netTotal);

    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 740),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Exportation Multi-Rapports (Excel / CSV / PDF A4)',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: p.textPrimary),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _exportFrom,
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setState(() => _exportFrom = picked);
                    },
                    icon: const Icon(Icons.calendar_today_rounded, size: 15),
                    label: Text('Du : ${_fmtDate(_exportFrom)}'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _exportTo,
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setState(() => _exportTo = picked);
                    },
                    icon: const Icon(Icons.event_rounded, size: 15),
                    label: Text('Jusqu\'au : ${_fmtDate(_exportTo)}'),
                  ),
                  ActionChip(
                    label: const Text('Aujourd\'hui'),
                    onPressed: () {
                      final now = DateTime.now();
                      setState(() {
                        _exportFrom = DateTime(now.year, now.month, now.day);
                        _exportTo = now;
                      });
                    },
                  ),
                  ActionChip(
                    label: const Text('Ce mois'),
                    onPressed: () {
                      final now = DateTime.now();
                      setState(() {
                        _exportFrom = DateTime(now.year, now.month, 1);
                        _exportTo = now;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: p.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Périmètre sélectionné : ${orders.length} ticket(s) clôturé(s) · CA total : ${totalMru.toStringAsFixed(0)} MRU',
                  style: TextStyle(
                      fontWeight: FontWeight.w900, color: p.primary),
                ),
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Récapitulatif des règlements (Cash, Bankily, Masrivi...)'),
                value: _expPayments,
                onChanged: (v) => setState(() => _expPayments = v ?? true),
              ),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Récapitulatif des résultats vendeurs / caissiers'),
                value: _expSellers,
                onChanged: (v) => setState(() => _expSellers = v ?? true),
              ),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Récapitulatif des ventes par articles'),
                value: _expArticles,
                onChanged: (v) => setState(() => _expArticles = v ?? true),
              ),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Récapitulatif des ventes par tranche horaire'),
                value: _expHourly,
                onChanged: (v) => setState(() => _expHourly = v ?? true),
              ),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Récapitulatif des ventes par nombre de tickets & panier moyen'),
                value: _expTicketStats,
                onChanged: (v) => setState(() => _expTicketStats = v ?? true),
              ),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Journal complet des tickets'),
                value: _expJournal,
                onChanged: (v) => setState(() => _expJournal = v ?? true),
              ),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Consommations & état par marchandises (Stock)'),
                value: _expMerchandise,
                onChanged: (v) => setState(() => _expMerchandise = v ?? true),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    key: const Key('export_reports_csv_btn'),
                    onPressed: () {
                      final csv = _buildExportCsv(store, orders);
                      final ok = downloadTextFile(
                        'rapports_fulltek_${_fmtDate(_exportFrom).replaceAll('/', '-')}.csv',
                        csv,
                      );
                      _toast(ok
                          ? 'Export Excel / CSV téléchargé !'
                          : 'Téléchargement disponible sur la version Web.');
                    },
                    icon: const Icon(Icons.table_chart_rounded, size: 18),
                    label: const Text('Exporter Excel / CSV'),
                  ),
                  ElevatedButton.icon(
                    key: const Key('export_reports_pdf_btn'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      final html = _buildExportPdfHtml(store, orders);
                      final ok = printReportA4Html(
                        'Rapports Full-Tek · ${_fmtDate(_exportFrom)}',
                        html,
                      );
                      _toast(ok
                          ? 'Rapport PDF A4 ouvert pour impression !'
                          : 'Impression PDF disponible sur la version Web.');
                    },
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                    label: const Text('Exporter / Imprimer PDF (A4)'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
