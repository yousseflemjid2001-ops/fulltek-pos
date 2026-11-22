import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../state/commercial_store.dart';
import '../theme/commercial_theme.dart';
import '../utils/amount_in_words.dart';

class ExpensesView extends StatelessWidget {
  final CommercialStore store;
  const ExpensesView({super.key, required this.store});

  static const _categories = [
    'Loyer',
    'Électricité / Eau',
    'Salaires',
    'Carburant / Transport',
    'Douane / Transit',
    'Frais Bancaires',
    'Télécom / Internet',
    'Autres Charges',
  ];

  @override
  Widget build(BuildContext context) {
    final grossMargin = store.dashboard.kpis.grossMarginMru;
    final totalExp = store.totalExpensesMru;
    final netResult = store.netResultMru;

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
                    Text('Dépenses & Charges d\'exploitation',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    Text(
                        'Suivi des frais généraux (Somelec, loyers, salaires, transit) et calcul du Résultat Net',
                        style: TextStyle(
                            fontSize: 13, color: CommercialColors.textMuted)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _openAddExpenseDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nouvelle dépense'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _FinCard('Marge Brute Commerciale', fmtMru(grossMargin),
                  CommercialColors.primaryBlue),
              _FinCard('Total Charges d\'exploitation', fmtMru(totalExp),
                  CommercialColors.warningAmber),
              _FinCard(
                'Résultat Net Estimé',
                fmtMru(netResult),
                netResult >= 0
                    ? CommercialColors.successGreen
                    : CommercialColors.dangerRed,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: store.expenses.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text('Aucune dépense enregistrée.',
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
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Catégorie')),
                          DataColumn(label: Text('Libellé')),
                          DataColumn(label: Text('Bénéficiaire')),
                          DataColumn(label: Text('Paiement')),
                          DataColumn(label: Text('Montant'), numeric: true),
                          DataColumn(label: Text('Action')),
                        ],
                        rows: store.expenses.map((e) {
                          return DataRow(cells: [
                            DataCell(Text(e.date)),
                            DataCell(Text(e.category,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600))),
                            DataCell(Text(e.label)),
                            DataCell(Text(e.beneficiary.isEmpty
                                ? '—'
                                : e.beneficiary)),
                            DataCell(Text(e.payMethod)),
                            DataCell(Text(
                              '-${fmtMru(e.amountMru)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: CommercialColors.dangerRed),
                            )),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 18,
                                    color: CommercialColors.dangerRed),
                                onPressed: () => store.deleteExpense(e.id),
                              ),
                            ),
                          ]);
                        }).toList(),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddExpenseDialog(BuildContext context) async {
    String category = _categories.first;
    String payMethod = 'Cash';
    final labelCtrl = TextEditingController();
    final benefCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final refCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Enregistrer une dépense / charge'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: category,
                        isExpanded: true,
                        decoration:
                            const InputDecoration(labelText: 'Catégorie'),
                        items: _categories
                            .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c, overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (v) =>
                            setS(() => category = v ?? _categories.first),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: payMethod,
                        decoration:
                            const InputDecoration(labelText: 'Paiement'),
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
                  controller: labelCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Libellé * (ex: Facture Somelec)'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: benefCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Bénéficiaire'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Montant (MRU) *'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: refCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Référence justificatif / N° reçu'),
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
                final err = await store.addExpense(
                  category: category,
                  label: labelCtrl.text,
                  amountMru: double.tryParse(amountCtrl.text) ?? 0,
                  payMethod: payMethod,
                  beneficiary: benefCtrl.text,
                  ref: refCtrl.text,
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

class TvaAndAgingView extends StatelessWidget {
  final CommercialStore store;
  const TvaAndAgingView({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final tva = store.computeTvaSummary();
    final aging = store.computeAgedReceivables();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Déclaration TVA Mauritanie, Exports Comptables & Balance Âgée',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
              'Synthèse fiscale DGI (TVA 16% / Exonéré 0%), journaux Excel et suivi des impayés',
              style: TextStyle(fontSize: 13, color: CommercialColors.textMuted)),
          const SizedBox(height: 16),
          // Section 1: TVA
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('1. Synthèse TVA Mauritanie (Collectée − Déductible)',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      _FinCard('Ventes HT Taxables (16%)',
                          fmtMru(tva.salesHtTaxable), CommercialColors.textPrimary),
                      _FinCard('Ventes HT Exonérées (0%)',
                          fmtMru(tva.salesHtExempt), CommercialColors.textMuted),
                      _FinCard('TVA Collectée (Ventes)',
                          fmtMru(tva.salesTvaCollected), CommercialColors.primaryBlue),
                      _FinCard('TVA Déductible (Achats)',
                          fmtMru(tva.purchasesTvaDeductible),
                          CommercialColors.successGreen),
                      _FinCard(
                        tva.netTvaToPay >= 0
                            ? 'TVA Nette à reverser DGI'
                            : 'Crédit de TVA reportable',
                        fmtMru(tva.netTvaToPay.abs()),
                        tva.netTvaToPay >= 0
                            ? CommercialColors.warningAmber
                            : CommercialColors.successGreen,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Section 2: Exports Comptables
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('2. Exports Comptables (Excel / CSV)',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ElevatedButton.icon(
                        onPressed: store.exportSalesJournalCsv,
                        icon: const Icon(Icons.download_outlined, size: 17),
                        label: const Text('Journal des Ventes (CSV)'),
                      ),
                      OutlinedButton.icon(
                        onPressed: store.exportPurchasesJournalCsv,
                        icon: const Icon(Icons.download_outlined, size: 17),
                        label: const Text('Journal des Achats (CSV)'),
                      ),
                      OutlinedButton.icon(
                        onPressed: store.exportTreasuryJournalCsv,
                        icon: const Icon(Icons.download_outlined, size: 17),
                        label: const Text('Journal de Trésorerie (CSV)'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Section 3: Balance âgée
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('3. Balance Âgée des Factures Impayées & Relances',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      _FinCard('0 – 30 jours', fmtMru(aging.bucket0To30),
                          CommercialColors.primaryBlue),
                      _FinCard('31 – 60 jours', fmtMru(aging.bucket31To60),
                          CommercialColors.warningAmber),
                      _FinCard('Plus de 60 jours', fmtMru(aging.bucketOver60),
                          CommercialColors.dangerRed),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (aging.overdueInvoices.isEmpty)
                    const Text('Aucune facture impayée en cours.',
                        style: TextStyle(color: CommercialColors.textMuted))
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                            const Color(0xFFF8FAFC)),
                        columns: const [
                          DataColumn(label: Text('Facture')),
                          DataColumn(label: Text('Client')),
                          DataColumn(label: Text('Échéance')),
                          DataColumn(label: Text('Reste dû'), numeric: true),
                          DataColumn(label: Text('Relance WhatsApp')),
                        ],
                        rows: aging.overdueInvoices.map((d) {
                          return DataRow(cells: [
                            DataCell(Text(d.docNumber,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600))),
                            DataCell(Text(d.partyName)),
                            DataCell(Text(
                                d.dueDate.isEmpty ? d.issueDate : d.dueDate)),
                            DataCell(Text(fmtMru(d.remainingMru),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: CommercialColors.dangerRed))),
                            DataCell(
                              OutlinedButton.icon(
                                onPressed: () {
                                  final msg =
                                      'Bonjour ${d.partyName}, rappel amiable concernant la facture ${d.docNumber} (${store.companySettings.companyName}). Reste à régler : ${fmtMru(d.remainingMru)}. Bankily : ${store.companySettings.bankilyNumber}. Merci.';
                                  Clipboard.setData(ClipboardData(text: msg));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Message de relance WhatsApp copié !'),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.chat_outlined, size: 16),
                                label: const Text('Copier relance'),
                              ),
                            ),
                          ]);
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

class PartyStatementView extends StatefulWidget {
  final CommercialStore store;
  const PartyStatementView({super.key, required this.store});

  @override
  State<PartyStatementView> createState() => _PartyStatementViewState();
}

class _PartyStatementViewState extends State<PartyStatementView> {
  bool _isClient = true;
  int? _selectedId;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final clients = store.clients;
    final suppliers = store.suppliers;

    int? activeId = _selectedId;
    if (_isClient) {
      if (clients.isEmpty) {
        activeId = null;
      } else if (activeId == null || !clients.any((c) => c.id == activeId)) {
        activeId = clients.first.id;
      }
    } else {
      if (suppliers.isEmpty) {
        activeId = null;
      } else if (activeId == null || !suppliers.any((s) => s.id == activeId)) {
        activeId = suppliers.first.id;
      }
    }

    final docs = activeId == null
        ? const []
        : (_isClient ? store.salesDocs : store.purchaseDocs)
            .where((d) => d.partyId == activeId)
            .toList();

    final partyName = activeId == null
        ? '—'
        : (_isClient
            ? clients.firstWhere((c) => c.id == activeId).name
            : suppliers.firstWhere((s) => s.id == activeId).name);
    final partyNif = activeId == null
        ? ''
        : (_isClient
            ? clients.firstWhere((c) => c.id == activeId).nif
            : suppliers.firstWhere((s) => s.id == activeId).nif);

    final totalTtc =
        docs.fold<double>(0, (s, d) => s + (d.totalTtcMru as double));
    final totalPaid = docs.fold<double>(0, (s, d) => s + (d.paidMru as double));
    final balance = totalTtc - totalPaid;

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
                    Text('Relevés de Compte (Grand Livre Tiers)',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    Text(
                        'Historique complet des factures, avoirs, règlements et solde net par client ou fournisseur',
                        style: TextStyle(
                            fontSize: 13, color: CommercialColors.textMuted)),
                  ],
                ),
              ),
              if (activeId != null)
                ElevatedButton.icon(
                  onPressed: () => store.printPartyStatement(
                    isClient: _isClient,
                    partyId: activeId!,
                    partyName: partyName,
                    partyNif: partyNif,
                  ),
                  icon: const Icon(Icons.print_outlined, size: 18),
                  label: const Text('Imprimer Relevé A4'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: true, label: Text('Clients')),
                          ButtonSegment(
                              value: false, label: Text('Fournisseurs')),
                        ],
                        selected: {_isClient},
                        onSelectionChanged: (s) => setState(() {
                          _isClient = s.first;
                          _selectedId = null;
                        }),
                      ),
                      if (activeId != null)
                        SizedBox(
                          width: 340,
                          child: DropdownButtonFormField<int>(
                            initialValue: activeId,
                            isExpanded: true,
                            decoration: InputDecoration(
                                labelText: _isClient
                                    ? 'Sélectionner un client'
                                    : 'Sélectionner un fournisseur'),
                            items: _isClient
                                ? clients
                                    .map((c) => DropdownMenuItem(
                                        value: c.id,
                                        child: Text('${c.code} · ${c.name}',
                                            overflow: TextOverflow.ellipsis)))
                                    .toList()
                                : suppliers
                                    .map((s) => DropdownMenuItem(
                                        value: s.id,
                                        child: Text('${s.code} · ${s.name}',
                                            overflow: TextOverflow.ellipsis)))
                                    .toList(),
                            onChanged: (v) => setState(() => _selectedId = v),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      _FinCard('Total Facturé TTC', fmtMru(totalTtc),
                          CommercialColors.textPrimary),
                      _FinCard('Total Réglé', fmtMru(totalPaid),
                          CommercialColors.successGreen),
                      _FinCard(
                        'Solde Net',
                        fmtMru(balance),
                        balance > 0
                            ? CommercialColors.warningAmber
                            : CommercialColors.successGreen,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'En toutes lettres : ${amountToFrenchWords(balance)}',
                    style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 12.5,
                        color: CommercialColors.textMuted),
                  ),
                  const SizedBox(height: 14),
                  if (docs.isEmpty)
                    const Text('Aucune pièce comptable pour ce tiers.',
                        style: TextStyle(color: CommercialColors.textMuted))
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                            const Color(0xFFF8FAFC)),
                        columns: const [
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Numéro')),
                          DataColumn(label: Text('Type')),
                          DataColumn(label: Text('Débit TTC'), numeric: true),
                          DataColumn(label: Text('Payé'), numeric: true),
                          DataColumn(label: Text('Reste'), numeric: true),
                        ],
                        rows: docs.map((d) {
                          return DataRow(cells: [
                            DataCell(Text('${d.issueDate}')),
                            DataCell(Text('${d.docNumber}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600))),
                            DataCell(Text('${d.docType}')),
                            DataCell(Text(fmtMru(d.totalTtcMru as double))),
                            DataCell(Text(fmtMru(d.paidMru as double))),
                            DataCell(Text(fmtMru(d.remainingMru as double),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700))),
                          ]);
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

class _FinCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _FinCard(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 225,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: CommercialColors.textMuted)),
              const SizedBox(height: 4),
              Text(value,
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
