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
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Trésorerie — Caisses & Banques',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  Text(
                    'Solde global consolidé : ${fmtMru(total)}',
                    style: const TextStyle(
                        fontSize: 13, color: CommercialColors.textMuted),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _openCreateAccountDialog(context),
                    icon: const Icon(Icons.account_balance_outlined, size: 18),
                    label: const Text('Nouveau compte'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openTransferDialog(context),
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: const Text('Virement interne'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _openMovementDialog(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nouveau mouvement'),
                  ),
                ],
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
                        if (acc.bankName.isNotEmpty)
                          Text(acc.bankName,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: CommercialColors.textMuted)),
                        const SizedBox(height: 8),
                        Text(
                          fmtMru(acc.currentBalanceMru),
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
                          DataColumn(label: Text('Mode')),
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
                              DataCell(Text(m.payMethod.isEmpty
                                  ? '—'
                                  : m.payMethod)),
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
                                '${isIn ? '+' : '-'}${fmtMru(m.amountMru)}',
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

  Future<void> _openCreateAccountDialog(BuildContext context) async {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final bankCtrl = TextEditingController();
    final balCtrl = TextEditingController(text: '0');
    String accType = 'BANQUE';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Nouveau compte de trésorerie'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: codeCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Code (ex: BNM-01) *'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: accType,
                        decoration: const InputDecoration(labelText: 'Type'),
                        items: const [
                          DropdownMenuItem(value: 'CAISSE', child: Text('Caisse')),
                          DropdownMenuItem(value: 'BANQUE', child: Text('Banque')),
                          DropdownMenuItem(
                              value: 'MOBILE_MONEY', child: Text('Mobile Money')),
                        ],
                        onChanged: (v) => setS(() => accType = v ?? 'BANQUE'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Intitulé du compte * (ex: BNM Courant / Bankily)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: bankCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Établissement (ex: BMCI, BNM, Attijari)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: balCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Solde d\'ouverture (MRU)'),
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
                final err = await store.createTreasuryAccount(
                  code: codeCtrl.text,
                  name: nameCtrl.text,
                  accountType: accType,
                  bankName: bankCtrl.text,
                  openingBalanceMru: double.tryParse(balCtrl.text) ?? 0,
                );
                if (!ctx.mounted) return;
                if (err != null) {
                  ScaffoldMessenger.of(ctx)
                      .showSnackBar(SnackBar(content: Text(err)));
                } else {
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Créer le compte'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMovementDialog(BuildContext context) async {
    if (store.treasuryAccounts.isEmpty) return;
    int accountId = store.treasuryAccounts.first.id;
    String direction = 'IN';
    String payMethod = 'Cash';
    final amountCtrl = TextEditingController();
    final labelCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Nouveau mouvement de trésorerie'),
          content: SizedBox(
            width: 420,
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
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: direction,
                        decoration: const InputDecoration(labelText: 'Sens'),
                        items: const [
                          DropdownMenuItem(
                              value: 'IN', child: Text('Entrée (+)')),
                          DropdownMenuItem(
                              value: 'OUT', child: Text('Sortie (-)')),
                        ],
                        onChanged: (v) => setS(() => direction = v ?? 'IN'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: payMethod,
                        decoration: const InputDecoration(labelText: 'Mode'),
                        items: const [
                          'Cash',
                          'Bankily',
                          'Masrivi',
                          'Sedad',
                          'Virement',
                          'Chèque',
                        ]
                            .map((m) =>
                                DropdownMenuItem(value: m, child: Text(m)))
                            .toList(),
                        onChanged: (v) => setS(() => payMethod = v ?? 'Cash'),
                      ),
                    ),
                  ],
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
                  decoration: const InputDecoration(
                      labelText: 'Libellé / Motif (ex: Loyer, Apport, Frais)'),
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
                  payMethod: payMethod,
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
          title: const Text('Virement interne entre comptes'),
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
                    Text(
                        'Cycle complet : En portefeuille → Déposé en banque → Encaissé / Payé / Impayé',
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
                          DataColumn(label: Text('Type / Banque')),
                          DataColumn(label: Text('Sens')),
                          DataColumn(label: Text('Tiers')),
                          DataColumn(label: Text('Échéance')),
                          DataColumn(label: Text('Montant'), numeric: true),
                          DataColumn(label: Text('Statut')),
                          DataColumn(label: Text('Workflow')),
                        ],
                        rows: store.cheques.map((ch) {
                          final isClient =
                              ch.direction == 'IN' || ch.direction == 'CLIENT';
                          final isClosed = ch.status == 'ENCAISSE' ||
                              ch.status == 'PAYE' ||
                              ch.status == 'IMPAYE';
                          return DataRow(
                            cells: [
                              DataCell(Text(ch.number,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600))),
                              DataCell(Text(ch.bankName.isEmpty
                                  ? ch.instrumentType
                                  : '${ch.instrumentType} · ${ch.bankName}')),
                              DataCell(
                                  Text(isClient ? 'À recevoir' : 'À payer')),
                              DataCell(Text(ch.partyName)),
                              DataCell(Text(ch.dueDate)),
                              DataCell(Text(fmtMru(ch.amountMru))),
                              DataCell(Text(ch.status,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: ch.status == 'IMPAYE'
                                          ? CommercialColors.dangerRed
                                          : (ch.status == 'ENCAISSE' ||
                                                  ch.status == 'PAYE')
                                              ? CommercialColors.successGreen
                                              : CommercialColors.primaryBlue))),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (ch.status == 'EN_PORTEFEUILLE')
                                      TextButton(
                                        onPressed: () => store
                                            .updateChequeStatus(ch.id, 'DEPOSE'),
                                        child: const Text('Déposer'),
                                      ),
                                    if (!isClosed) ...[
                                      TextButton(
                                        onPressed: () =>
                                            store.updateChequeStatus(
                                          ch.id,
                                          isClient ? 'ENCAISSE' : 'PAYE',
                                          treasuryAccountId: store
                                                  .treasuryAccounts.isNotEmpty
                                              ? store.treasuryAccounts.first.id
                                              : null,
                                        ),
                                        child: Text(
                                            isClient ? 'Encaisser' : 'Payer'),
                                      ),
                                      TextButton(
                                        onPressed: () => store
                                            .updateChequeStatus(ch.id, 'IMPAYE'),
                                        child: const Text('Impayé',
                                            style: TextStyle(
                                                color:
                                                    CommercialColors.dangerRed)),
                                      ),
                                    ],
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
    String direction = 'CLIENT';
    String instrumentType = 'CHEQUE';
    int? clientId = store.clients.isNotEmpty ? store.clients.first.id : null;
    int? supplierId =
        store.suppliers.isNotEmpty ? store.suppliers.first.id : null;
    final numCtrl = TextEditingController();
    final bankCtrl = TextEditingController(text: 'BMCI');
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
            width: 460,
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
                              value: 'CLIENT', child: Text('Client (À recevoir)')),
                          DropdownMenuItem(
                              value: 'FOURNISSEUR',
                              child: Text('Fournisseur (À payer)')),
                        ],
                        onChanged: (v) =>
                            setS(() => direction = v ?? 'CLIENT'),
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
                if (direction == 'CLIENT' && store.clients.isNotEmpty)
                  DropdownButtonFormField<int?>(
                    initialValue: clientId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Client'),
                    items: store.clients
                        .map((c) => DropdownMenuItem<int?>(
                            value: c.id,
                            child: Text(c.name,
                                overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) => setS(() => clientId = v),
                  )
                else if (direction == 'FOURNISSEUR' &&
                    store.suppliers.isNotEmpty)
                  DropdownButtonFormField<int?>(
                    initialValue: supplierId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Fournisseur'),
                    items: store.suppliers
                        .map((s) => DropdownMenuItem<int?>(
                            value: s.id,
                            child: Text(s.name,
                                overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) => setS(() => supplierId = v),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                          controller: numCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Numéro *')),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                          controller: bankCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Banque (BMCI, BNM...)')),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                          controller: dueCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Échéance (YYYY-MM-DD)')),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Montant (MRU) *'),
                      ),
                    ),
                  ],
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
                  bankName: bankCtrl.text,
                  dueDate: dueCtrl.text,
                  amountMru: double.tryParse(amountCtrl.text) ?? 0,
                  clientId: direction == 'CLIENT' ? clientId : null,
                  supplierId: direction == 'FOURNISSEUR' ? supplierId : null,
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

    final annualTarget =
        store.objectives.fold<double>(0, (s, o) => s + o.targetCaHtMru);
    final annualRealized =
        store.objectives.fold<double>(0, (s, o) => s + o.realizedCaHtMru);
    final annualPct =
        annualTarget > 0 ? (annualRealized / annualTarget) * 100 : 0.0;

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
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _AnalyticCard('Objectif Annuel HT', fmtMru(annualTarget)),
              _AnalyticCard('Réalisé Annuel HT', fmtMru(annualRealized)),
              _AnalyticCard(
                  'Atteinte Globale', '${annualPct.toStringAsFixed(1)}%'),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor:
                      WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                  columns: const [
                    DataColumn(label: Text('Mois')),
                    DataColumn(label: Text('Objectif HT'), numeric: true),
                    DataColumn(label: Text('Réalisé HT'), numeric: true),
                    DataColumn(label: Text('Progression')),
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
                            style:
                                const TextStyle(fontWeight: FontWeight.w600))),
                        DataCell(Text(fmtMru(target))),
                        DataCell(Text(fmtMru(actual))),
                        DataCell(
                          SizedBox(
                            width: 150,
                            child: Row(
                              children: [
                                Expanded(
                                  child: LinearProgressIndicator(
                                    value: (pct / 100).clamp(0.0, 1.0),
                                    minHeight: 7,
                                    borderRadius: BorderRadius.circular(6),
                                    color: pct >= 100
                                        ? CommercialColors.successGreen
                                        : CommercialColors.primaryBlue,
                                    backgroundColor: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('${pct.toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
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
                    _AnalyticCard('CA HT', fmtMru(k.caHtMru)),
                    _AnalyticCard('Marge HT', fmtMru(k.grossMarginMru)),
                    _AnalyticCard('Taux de marge',
                        '${k.marginRatePct.toStringAsFixed(1)}%'),
                    _AnalyticCard('Encaissements', fmtMru(k.receiptsMru)),
                    _AnalyticCard('Créances clients TTC',
                        fmtMru(k.clientReceivablesTtcMru)),
                  ]
                : [
                    _AnalyticCard('Achats HT', fmtMru(k.purchasesHtMru)),
                    _AnalyticCard(
                        'Valeur Stock (PMP)', fmtMru(k.stockValuePmpMru)),
                    _AnalyticCard(
                        'Dettes fournisseurs', fmtMru(k.supplierDebtMru)),
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
                            DataCell(Text(fmtMru(a.priceRetailHt))),
                            DataCell(Text(fmtMru(a.pmpCostMru))),
                            DataCell(Text(
                                '${a.stockQty.toStringAsFixed(1)} ${a.unit}')),
                            DataCell(Text(fmtMru(a.stockValuePmpMru))),
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
