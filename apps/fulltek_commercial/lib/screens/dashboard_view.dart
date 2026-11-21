import 'package:flutter/material.dart';
import '../state/commercial_store.dart';
import '../theme/commercial_theme.dart';
import '../widgets/ca_chart.dart';

class DashboardView extends StatefulWidget {
  final CommercialStore store;
  final int initialTab;
  final void Function(String routeId)? onNavigate;

  const DashboardView({
    super.key,
    required this.store,
    this.initialTab = 0,
    this.onNavigate,
  });

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  late int _subTab;

  @override
  void initState() {
    super.initState();
    _subTab = widget.initialTab;
  }

  @override
  void didUpdateWidget(covariant DashboardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _subTab = widget.initialTab;
    }
  }

  static const _presets = [
    ('this_month', 'Ce mois'),
    ('last_month', 'Mois dernier'),
    ('this_quarter', 'Ce trimestre'),
    ('this_year', 'Cette année'),
    ('last_12_months', '12 derniers mois'),
    ('last_year', 'Année dernière'),
  ];

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final d = store.dashboard;
    final k = d.kpis;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title & range subtitle
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tableau de bord',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: CommercialColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      d.fromDate.isNotEmpty
                          ? 'Du ${d.fromDate} au ${d.toDate} — comparé à la même période de l\'année précédente'
                          : 'Vue d\'ensemble direction & pilotage commercial',
                      style: const TextStyle(
                          fontSize: 12.5, color: CommercialColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Sub-tabs (Direction | Ventes | Achats et stock | Trésorerie | Objectifs)
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: CommercialColors.border)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final entry in const [
                    (0, 'Direction'),
                    (1, 'Ventes'),
                    (2, 'Achats et stock'),
                    (3, 'Trésorerie'),
                    (4, 'Objectifs'),
                  ])
                    InkWell(
                      key: Key('dash_tab_${entry.$1}'),
                      onTap: () {
                        setState(() => _subTab = entry.$1);
                        if (entry.$1 > 0) store.loadAnalytics();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: _subTab == entry.$1
                                  ? CommercialColors.brandOrange
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                        ),
                        child: Text(
                          entry.$2,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _subTab == entry.$1
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: _subTab == entry.$1
                                ? CommercialColors.brandOrange
                                : CommercialColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Date Preset Filters
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ..._presets.map((p) {
                final active = store.activePreset == p.$1;
                return ChoiceChip(
                  key: Key('preset_${p.$1}'),
                  selected: active,
                  selectedColor: CommercialColors.sidebarBg,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : CommercialColors.textPrimary,
                  ),
                  onSelected: (_) => store.loadDashboard(preset: p.$1),
                  label: Text(p.$2),
                );
              }),
            ],
          ),
          const SizedBox(height: 16),

          if (_subTab == 0) ...[
            // 8 KPI Cards (5 top + 3 second row on wide screens)
            LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth >= 1080
                    ? 5
                    : (c.maxWidth >= 720 ? 3 : 2);
                final cards = [
                  _kpiCard(
                    key: const Key('kpi_ca_ht'),
                    title: 'CHIFFRE D\'AFFAIRES HT',
                    value: fmtMru(k.caHtMru),
                    deltaPct: k.caVsN1Pct,
                    sub: k.objectiveTargetMru > 0
                        ? 'Objectif ${fmtMru(k.objectiveTargetMru)} · ${(k.objectiveAttainmentPct ?? 0).toStringAsFixed(1)}%'
                        : 'Hors taxes · N vs N-1',
                    progress: k.objectiveAttainmentPct != null
                        ? (k.objectiveAttainmentPct! / 100).clamp(0.0, 1.0)
                        : null,
                  ),
                  _kpiCard(
                    key: const Key('kpi_margin'),
                    title: 'MARGE BRUTE',
                    value: fmtMru(k.grossMarginMru),
                    deltaPct: k.marginVsN1Pct,
                    sub:
                        'Taux ${k.marginRatePct.toStringAsFixed(1)}% (N-1 ${k.marginRatePrevPct.toStringAsFixed(1)}%)',
                  ),
                  _kpiCard(
                    key: const Key('kpi_receipts'),
                    title: 'ENCAISSEMENTS',
                    value: fmtMru(k.receiptsMru),
                    deltaPct: k.receiptsVsN1Pct,
                    sub: 'Décaissé ${fmtMru(k.disbursementsMru)}',
                  ),
                  _kpiCard(
                    key: const Key('kpi_purchases'),
                    title: 'ACHATS HT',
                    value: fmtMru(k.purchasesHtMru),
                    deltaPct: k.purchasesVsN1Pct,
                    sub: 'Dettes fournisseurs ${fmtMru(k.supplierDebtMru)}',
                  ),
                  _kpiCard(
                    key: const Key('kpi_receivables'),
                    title: 'ENCOURS CLIENTS TTC',
                    value: fmtMru(k.clientReceivablesTtcMru),
                    sub: 'Effets à encaisser ${fmtMru(k.pendingEffectsMru)}',
                  ),
                  _kpiCard(
                    key: const Key('kpi_treasury'),
                    title: 'TRÉSORERIE',
                    value: fmtMru(k.treasuryBalanceMru),
                    sub: 'Caisse, banques & mobile money',
                  ),
                  _kpiCard(
                    key: const Key('kpi_stock_pmp'),
                    title: 'VALEUR DU STOCK',
                    value: fmtMru(k.stockValuePmpMru),
                    sub: 'Au coût moyen pondéré (PMP)',
                  ),
                  _kpiCard(
                    key: const Key('kpi_quotes'),
                    title: 'DEVIS ÉMIS',
                    value: fmtMru(k.quotesEmittedHtMru),
                    sub:
                        '${k.quotesCount} devis · transformation ${k.quoteConversionRatePct != null ? '${k.quoteConversionRatePct!.toStringAsFixed(0)}%' : '—'}',
                  ),
                ];

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: cards.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 124,
                  ),
                  itemBuilder: (_, i) => cards[i],
                );
              },
            ),
            const SizedBox(height: 16),

            // Chart + "À traiter" alerts panel
            LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 880;
                final chartCard = Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Chiffre d\'affaires HT',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: CommercialColors.textPrimary,
                              ),
                            ),
                            Wrap(
                              spacing: 12,
                              children: const [
                                _LegendDot(
                                    color: CommercialColors.primaryBlue,
                                    label: 'Période'),
                                _LegendDot(
                                    color: Color(0xFFCBD5E1), label: 'N-1'),
                                _LegendDot(
                                    color: CommercialColors.dangerRed,
                                    label: 'Objectif'),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        CaComparisonChart(series: d.series),
                      ],
                    ),
                  ),
                );

                final alertsCard = Card(
                  key: const Key('alerts_panel'),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'À traiter',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: CommercialColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _alertRow(
                          count: d.overdueClientInvoices.count,
                          label: 'Factures clients échues non réglées',
                          amount: fmtMru(d.overdueClientInvoices.totalMru),
                          color: CommercialColors.dangerRed,
                          onTap: () => widget.onNavigate?.call('factures'),
                        ),
                        const SizedBox(height: 8),
                        _alertRow(
                          count: d.dueCheques7d.count,
                          label: 'Chèques et traites à échéance sous 7 j',
                          amount: fmtMru(d.dueCheques7d.totalMru),
                          color: CommercialColors.warningAmber,
                          onTap: () => widget.onNavigate?.call('cheques'),
                        ),
                        const SizedBox(height: 8),
                        _alertRow(
                          count: d.overdueSupplierInvoices.count,
                          label: 'Factures fournisseurs échues non réglées',
                          amount: fmtMru(d.overdueSupplierInvoices.totalMru),
                          color: CommercialColors.dangerRed,
                          onTap: () =>
                              widget.onNavigate?.call('factures_fournisseurs'),
                        ),
                        const SizedBox(height: 8),
                        _alertRow(
                          count: d.lowStockCount,
                          label: 'Articles en alerte stock minimum',
                          amount: '${d.lowStockCount} réf.',
                          color: CommercialColors.primaryBlue,
                          onTap: () => widget.onNavigate?.call('articles'),
                        ),
                      ],
                    ),
                  ),
                );

                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 64, child: chartCard),
                      const SizedBox(width: 14),
                      Expanded(flex: 36, child: alertsCard),
                    ],
                  );
                }
                return Column(
                  children: [
                    chartCard,
                    const SizedBox(height: 12),
                    alertsCard,
                  ],
                );
              },
            ),
          ] else
            _buildAnalyticsTab(_subTab, store),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab(int tab, CommercialStore store) {
    final k = store.dashboard.kpis;
    final title = switch (tab) {
      1 => 'Analyse détaillée des Ventes',
      2 => 'Analyse Achats & Valorisation Stock PMP',
      3 => 'Analyse Trésorerie & Encours',
      _ => 'Suivi des Objectifs Mensuels',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            if (tab == 1) ...[
              Text('Chiffre d\'affaires HT : ${fmtMru(k.caHtMru)}'),
              Text('Marge brute : ${fmtMru(k.grossMarginMru)} (${k.marginRatePct}%)'),
              Text('Devis émis : ${k.quotesCount} (${fmtMru(k.quotesEmittedHtMru)})'),
            ] else if (tab == 2) ...[
              Text('Achats HT période : ${fmtMru(k.purchasesHtMru)}'),
              Text('Valeur stock au PMP : ${fmtMru(k.stockValuePmpMru)}'),
              Text('Articles actifs : ${store.articles.length}'),
            ] else if (tab == 3) ...[
              Text('Solde total trésorerie : ${fmtMru(k.treasuryBalanceMru)}'),
              Text('Encaissements : ${fmtMru(k.receiptsMru)} · Décaissements : ${fmtMru(k.disbursementsMru)}'),
              Text('Encours clients TTC : ${fmtMru(k.clientReceivablesTtcMru)}'),
            ] else ...[
              Text('Objectif période : ${fmtMru(k.objectiveTargetMru)}'),
              Text('Réalisé : ${fmtMru(k.caHtMru)} (${(k.objectiveAttainmentPct ?? 0).toStringAsFixed(1)}%)'),
            ],
            const SizedBox(height: 14),
            CaComparisonChart(series: store.dashboard.series),
          ],
        ),
      ),
    );
  }

  Widget _kpiCard({
    Key? key,
    required String title,
    required String value,
    double? deltaPct,
    required String sub,
    double? progress,
  }) {
    final pos = (deltaPct ?? 0) >= 0;
    return Card(
      key: key,
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: CommercialColors.textMuted,
                letterSpacing: 0.3,
              ),
            ),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: CommercialColors.textPrimary,
              ),
            ),
            if (deltaPct != null)
              Text(
                '${pos ? '▲ +' : '▼ '}${deltaPct.toStringAsFixed(1)}% vs N-1',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: pos
                      ? CommercialColors.successGreen
                      : CommercialColors.dangerRed,
                ),
              ),
            if (progress != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: CommercialColors.border,
                  color: CommercialColors.brandOrange,
                ),
              ),
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 10.5, color: CommercialColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _alertRow({
    required int count,
    required String label,
    required String amount,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: color, width: 3.5)),
          color: CommercialColors.canvasBg,
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 12, color: color),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: CommercialColors.textPrimary),
              ),
            ),
            Text(
              amount,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: CommercialColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: CommercialColors.textMuted)),
      ],
    );
  }
}
