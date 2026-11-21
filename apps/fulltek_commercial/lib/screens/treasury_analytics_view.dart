import 'package:flutter/material.dart';
import '../state/commercial_store.dart';
import '../theme/commercial_theme.dart';

class TreasuryView extends StatelessWidget {
  final CommercialStore store;
  const TreasuryView({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final total = store.treasuryAccounts
        .fold<double>(0, (s, a) => s + a.currentBalanceMru);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Trésorerie — Caisses & Banques',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    Text(
                      'Solde global consolidé : ${total.toStringAsFixed(0)} MRU',
                      style: const TextStyle(
                          fontSize: 13, color: CommercialColors.textMuted),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _openTransferDialog(context),
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Virement interne'),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _openMovementDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nouveau mouvement'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: store.treasuryAccounts.map((acc) {
              return SizedBox(
                width: 260,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(acc.code,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: CommercialColors.textMuted)),
                            Text(acc.accountType,
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: CommercialColors.primaryBlue)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(acc.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 8),
                        Text(
                          '${acc.currentBalanceMru.toStringAsFixed(0)} MRU',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: acc.currentBalanceMru >= 0
                                ? CommercialColors.successGreen
                                : CommercialColors.dangerRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Journal des mouvements de trésorerie',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  if (store.treasuryMovements.isEmpty)
                    const Text('Aucun mouvement récent.',
                        style: TextStyle(color: CommercialColors.textMuted))
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                            const Color(0xFFF8FAFC)),
                        columns: const [
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Compte')),
                          DataColumn(label: Text('Libellé')),
                          DataColumn(label: Text('Sens')),
                          DataColumn(label: Text('Montant'), numeric: true),
                        ],
                        rows: store.treasuryMovements.map((m) {
                          final isIn = m.direction == 'IN';
                          return DataRow(
                            cells: [
                              DataCell(Text(m.movementDate)),
                              DataCell(Text(m.accountName)),
                              DataCell(Text(m.label)),
                              DataCell(Text(
                                isIn ? 'Entrée' : 'Sortie',
                                style: TextStyle(
                                    color: isIn
                                        ? CommercialColors.successGreen
                                        : CommercialColors.dangerRed,
                                    fontWeight: FontWeight.w600),
                              )),
                              DataCell(Text(
                                '${isIn ? '+' : '-'}${m.amountMru.toStringAsFixed(0)} MRU',
                                style: TextStyle(
                                    color: isIn
                                        ? CommercialColors.successGreen
                                        : CommercialColors.dangerRed,
                                    fontWeight: FontWeight.w700),
                              )),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMovementDialog(BuildContext context) async {
    if (store.treasuryAccounts.isEmpty) return;
    int accountId = store.treasuryAccounts.first.id;
    String direction = 'IN';
    final amountCtrl = TextEditingController();
    final labelCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Nouveau mouvement de trésorerie'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: accountId,
                  decoration: const InputDecoration(labelText: 'Compte'),
                  items: store.treasuryAccounts
                      .map((a) =>
                          DropdownMenuItem(value: a.id, child: Text(a.name)))
                      .toList(),
                  onChanged: (v) => setS(() => accountId = v ?? accountId),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: direction,
                  decoration: const InputDecoration(labelText: 'Sens'),
                  items: const [
                    DropdownMenuItem(value: 'IN', child: Text('Entrée (+)')),
                    DropdownMenuItem(value: 'OUT', child: Text('Sortie (-)')),
                  ],
                  onChanged: (v) => setS(() => direction = v ?? 'IN'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Montant (MRU)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(labelText: 'Libellé'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                final err = await store.addTreasuryMovement(
                  accountId: accountId,
                  direction: direction,
                  amountMru: double.tryParse(amountCtrl.text) ?? 0,
                  label: labelCtrl.text,
                );
                if (!ctx.mounted) return;
                if (err != null) {
                  ScaffoldMessenger.of(ctx)
                      .showSnackBar(SnackBar(content: Text(err)));
                } else {
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openTransferDialog(BuildContext context) async {
    if (store.treasuryAccounts.length < 2) return;
    int fromId = store.treasuryAccounts.first.id;
    int toId = store.treasuryAccounts[1].id;
    final amountCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Virement interne'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: fromId,
                  decoration: const InputDecoration(labelText: 'Compte source'),
                  items: store.treasuryAccounts
                      .map((a) =>
                          DropdownMenuItem(value: a.id, child: Text(a.name)))
                      .toList(),
                  onChanged: (v) => setS(() => fromId = v ?? fromId),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: toId,
                  decoration:
                      const InputDecoration(labelText: 'Compte destination'),
                  items: store.treasuryAccounts
                      .map((a) =>
                          DropdownMenuItem(value: a.id, child: Text(a.name)))
                      .toList(),
                  onChanged: (v) => setS(() => toId = v ?? toId),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Montant (MRU)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                final err = await store.transferTreasury(
                  fromId: fromId,
                  toId: toId,
                  amountMru: double.tryParse(amountCtrl.text) ?? 0,
                );
                if (!ctx.mounted) return;
                if (err != null) {
                  ScaffoldMessenger.of(ctx)
                      .showSnackBar(SnackBar(content: Text(err)));
                } else {
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Transférer'),
            ),
          ],
        ),
      ),
    );
  }
}

class ChequesView extends StatelessWidget {
  final CommercialStore store;
  const ChequesView({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chèques & Traites à échéance',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    Text('Portefeuille clients / fournisseurs et encaissements',
                        style: TextStyle(
                            fontSize: 13, color: CommercialColors.textMuted)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _openCreateChequeDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nouvel effet / chèque'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: store.cheques.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text('Aucun chèque ou traite enregistré.',
                            style:
                                TextStyle(color: CommercialColors.textMuted)),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                            const Color(0xFFF8FAFC)),
                        columns: const [
                          DataColumn(label: Text('Numéro')),
                          DataColumn(label: Text('Type')),
                          DataColumn(label: Text('Sens')),
                          DataColumn(label: Text('Tiers')),
                          DataColumn(label: Text('Échéance')),
                          DataColumn(label: Text('Montant'), numeric: true),
                          DataColumn(label: Text('Statut')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: store.cheques.map((ch) {
                          return DataRow(
                            cells: [
                              DataCell(Text(ch.number,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600))),
                              DataCell(Text(ch.instrumentType)),
                              DataCell(Text(ch.direction == 'IN' ||
                                      ch.direction == 'CLIENT'
                                  ? 'À recevoir'
                                  : 'À payer')),
                              DataCell(Text(ch.partyName)),
                              DataCell(Text(ch.dueDate)),
                              DataCell(Text(
                                  '${ch.amountMru.toStringAsFixed(0)} MRU')),
                              DataCell(Text(ch.status,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600))),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (ch.status != 'ENCAISSE' &&
                                        ch.status != 'PAYE')
                                      TextButton(
                                        onPressed: () =>
                                            store.updateChequeStatus(
                                          ch.id,
                                          ch.direction == 'IN' ||
                                                  ch.direction == 'CLIENT'
                                              ? 'ENCAISSE'
                                              : 'PAYE',
                                          treasuryAccountId: store
                                                  .treasuryAccounts.isNotEmpty
                                              ? store.treasuryAccounts.first.id
                                              : null,
                                        ),
                                        child: Text(ch.direction == 'IN' ||
                                                ch.direction == 'CLIENT'
                                            ? 'Encaisser'
                                            : 'Payer'),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCreateChequeDialog(BuildContext context) async {
    String direction = 'IN';
    String instrumentType = 'CHEQUE';
    final numCtrl = TextEditingController();
    final dueCtrl = TextEditingController(
        text: DateTime.now()
            .add(const Duration(days: 30))
            .toIso8601String()
            .substring(0, 10));
    final amountCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Nouveau chèque / traite'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: direction,
                        decoration: const InputDecoration(labelText: 'Sens'),
                        items: const [
                          DropdownMenuItem(
                              value: 'IN', child: Text('Client (IN)')),
                          DropdownMenuItem(
                              value: 'OUT', child: Text('Fournisseur (OUT)')),
                        ],
                        onChanged: (v) => setS(() => direction = v ?? 'IN'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: instrumentType,
                        decoration: const InputDecoration(labelText: 'Type'),
                        items: const [
                          DropdownMenuItem(
                              value: 'CHEQUE', child: Text('Chèque')),
                          DropdownMenuItem(
                              value: 'TRAITE', child: Text('Traite')),
                        ],
                        onChanged: (v) =>
                            setS(() => instrumentType = v ?? 'CHEQUE'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                    controller: numCtrl,
                    decoration: const InputDecoration(labelText: 'Numéro *')),
                const SizedBox(height: 10),
                TextField(
                    controller: dueCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Échéance (YYYY-MM-DD)')),
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Montant (MRU)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                final err = await store.createCheque(
                  direction: direction,
                  instrumentType: instrumentType,
                  number: numCtrl.text,
                  dueDate: dueCtrl.text,
                  amountMru: double.tryParse(amountCtrl.text) ?? 0,
                );
                if (!ctx.mounted) return;
                if (err != null) {
                  ScaffoldMessenger.of(ctx)
                      .showSnackBar(SnackBar(content: Text(err)));
                } else {
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}

class ObjectivesView extends StatelessWidget {
  final CommercialStore store;
  const ObjectivesView({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    const months = [
      'Janvier',
      'Février',
      'Mars',
      'Avril',
      'Mai',
      'Juin',
      'Juillet',
      'Août',
      'Septembre',
      'Octobre',
      'Novembre',
      'Décembre',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Objectifs commerciaux ${store.objectivesYear}',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: () => store.loadObjectives(store.objectivesYear - 1),
                icon: const Icon(Icons.chevron_left),
              ),
              Text('${store.objectivesYear}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              IconButton(
                onPressed: () => store.loadObjectives(store.objectivesYear + 1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DataTable(
                headingRowColor:
                    WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                columns: const [
                  DataColumn(label: Text('Mois')),
                  DataColumn(label: Text('Objectif HT'), numeric: true),
                  DataColumn(label: Text('Réalisé HT'), numeric: true),
                  DataColumn(label: Text('Atteinte'), numeric: true),
                  DataColumn(label: Text('Action')),
                ],
                rows: List.generate(12, (idx) {
                  final m = idx + 1;
                  final obj = store.objectives.where((o) => o.month == m);
                  final item = obj.isNotEmpty ? obj.first : null;
                  final target = item?.targetCaHtMru ?? 0;
                  final actual = item?.realizedCaHtMru ?? 0;
                  final pct = item?.attainmentPct ?? 0;

                  return DataRow(
                    cells: [
                      DataCell(Text(months[idx],
                          style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(Text('${target.toStringAsFixed(0)} MRU')),
                      DataCell(Text('${actual.toStringAsFixed(0)} MRU')),
                      DataCell(Text(
                        '${pct.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: pct >= 100
                              ? CommercialColors.successGreen
                              : CommercialColors.primaryBlue,
                        ),
                      )),
                      DataCell(
                        TextButton(
                          onPressed: () =>
                              _editObjectiveDialog(context, m, target),
                          child: const Text('Définir'),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editObjectiveDialog(
      BuildContext context, int month, double current) async {
    final ctrl = TextEditingController(text: current.toStringAsFixed(0));
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Objectif mois $month/${store.objectivesYear}'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Objectif CA HT (MRU)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final err = await store.saveObjective(
                  store.objectivesYear, month, double.tryParse(ctrl.text) ?? 0);
              if (!ctx.mounted) return;
              if (err != null) {
                ScaffoldMessenger.of(ctx)
                    .showSnackBar(SnackBar(content: Text(err)));
              } else {
                Navigator.pop(ctx);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}

class AnalyticsView extends StatelessWidget {
  final CommercialStore store;
  final String mode; // 'sales' | 'purchases'
  const AnalyticsView({super.key, required this.store, required this.mode});

  @override
  Widget build(BuildContext context) {
    final d = store.dashboard;
    final k = d.kpis;
    final isSales = mode == 'sales';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isSales
                ? 'Analyse des Ventes & Marges'
                : 'Analyse des Achats & Valorisation Stock',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: isSales
                ? [
                    _AnalyticCard('CA HT', '${k.caHtMru.toStringAsFixed(0)} MRU'),
                    _AnalyticCard(
                        'Marge HT', '${k.grossMarginMru.toStringAsFixed(0)} MRU'),
                    _AnalyticCard('Taux de marge',
                        '${k.marginRatePct.toStringAsFixed(1)}%'),
                    _AnalyticCard('Encaissements',
                        '${k.receiptsMru.toStringAsFixed(0)} MRU'),
                    _AnalyticCard('Créances clients TTC',
                        '${k.clientReceivablesTtcMru.toStringAsFixed(0)} MRU'),
                  ]
                : [
                    _AnalyticCard('Achats HT',
                        '${k.purchasesHtMru.toStringAsFixed(0)} MRU'),
                    _AnalyticCard('Valeur Stock (PMP)',
                        '${k.stockValuePmpMru.toStringAsFixed(0)} MRU'),
                    _AnalyticCard('Dettes fournisseurs',
                        '${k.supplierDebtMru.toStringAsFixed(0)} MRU'),
                    _AnalyticCard(
                        'Alertes stock bas', '${d.lowStockCount} articles'),
                  ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSales ? 'Top articles / marge' : 'État du stock par article',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor:
                          WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                      columns: const [
                        DataColumn(label: Text('SKU')),
                        DataColumn(label: Text('Désignation')),
                        DataColumn(label: Text('Prix Détail HT'), numeric: true),
                        DataColumn(label: Text('PMP'), numeric: true),
                        DataColumn(label: Text('Stock'), numeric: true),
                        DataColumn(label: Text('Valeur PMP'), numeric: true),
                      ],
                      rows: store.articles.take(15).map((a) {
                        return DataRow(
                          cells: [
                            DataCell(Text(a.sku)),
                            DataCell(Text(a.name)),
                            DataCell(
                                Text('${a.priceRetailHt.toStringAsFixed(0)} MRU')),
                            DataCell(
                                Text('${a.pmpCostMru.toStringAsFixed(0)} MRU')),
                            DataCell(
                                Text('${a.stockQty.toStringAsFixed(1)} ${a.unit}')),
                            DataCell(Text(
                                '${a.stockValuePmpMru.toStringAsFixed(0)} MRU')),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticCard extends StatelessWidget {
  final String label;
  final String value;
  const _AnalyticCard(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: CommercialColors.textMuted)),
              const SizedBox(height: 6),
              Text(value,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
