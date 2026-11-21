import 'package:flutter/material.dart';
import '../models/commercial_models.dart';
import '../state/commercial_store.dart';
import '../theme/commercial_theme.dart';

class SuppliersView extends StatefulWidget {
  final CommercialStore store;
  const SuppliersView({super.key, required this.store});

  @override
  State<SuppliersView> createState() => _SuppliersViewState();
}

class _SuppliersViewState extends State<SuppliersView> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final filtered = store.suppliers.where((s) {
      if (_query.trim().isEmpty) return true;
      final q = _query.toLowerCase();
      return s.name.toLowerCase().contains(q) ||
          s.code.toLowerCase().contains(q) ||
          s.nif.toLowerCase().contains(q);
    }).toList();

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
                    Text('Fournisseurs',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    SizedBox(height: 2),
                    Text('Répertoire fournisseurs, NIF et dettes à payer',
                        style: TextStyle(
                            fontSize: 13, color: CommercialColors.textMuted)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _openCreateSupplierDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nouveau fournisseur'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Rechercher un fournisseur...',
                      prefixIcon: Icon(Icons.search, size: 18),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  const SizedBox(height: 14),
                  if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Text('Aucun fournisseur trouvé.',
                          style: TextStyle(color: CommercialColors.textMuted)),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                            const Color(0xFFF8FAFC)),
                        columns: const [
                          DataColumn(label: Text('Code')),
                          DataColumn(label: Text('Fournisseur')),
                          DataColumn(label: Text('NIF')),
                          DataColumn(label: Text('Téléphone & Ville')),
                          DataColumn(label: Text('Délai (j)'), numeric: true),
                          DataColumn(label: Text('Solde dû'), numeric: true),
                        ],
                        rows: filtered.map((s) {
                          return DataRow(
                            cells: [
                              DataCell(Text(s.code,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600))),
                              DataCell(Text(s.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600))),
                              DataCell(Text(s.nif.isEmpty ? '—' : s.nif)),
                              DataCell(Text(
                                  '${s.phone.isEmpty ? '—' : s.phone} • ${s.city}')),
                              DataCell(Text('${s.paymentTermsDays} j')),
                              DataCell(Text(
                                '${s.balanceDueMru.toStringAsFixed(0)} MRU',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: s.balanceDueMru > 0
                                      ? CommercialColors.warningAmber
                                      : CommercialColors.successGreen,
                                ),
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

  Future<void> _openCreateSupplierDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final nifCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final cityCtrl = TextEditingController(text: 'Nouakchott');
    final termsCtrl = TextEditingController(text: '30');

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouveau fournisseur'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration:
                    const InputDecoration(labelText: 'Nom du fournisseur *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nifCtrl,
                decoration: const InputDecoration(labelText: 'NIF'),
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
                      controller: cityCtrl,
                      decoration: const InputDecoration(labelText: 'Ville'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: termsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Délai de paiement (jours)'),
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
              final err = await widget.store.createSupplier(
                name: nameCtrl.text,
                nif: nifCtrl.text,
                phone: phoneCtrl.text,
                city: cityCtrl.text,
                paymentTermsDays: int.tryParse(termsCtrl.text) ?? 30,
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
    );
  }
}

class PurchaseDocsView extends StatefulWidget {
  final CommercialStore store;
  final String docType; // BC_ACHAT | RECEPTION | FACTURE_ACHAT | AVOIR_ACHAT

  const PurchaseDocsView({
    super.key,
    required this.store,
    required this.docType,
  });

  @override
  State<PurchaseDocsView> createState() => _PurchaseDocsViewState();
}

class _PurchaseDocsViewState extends State<PurchaseDocsView> {
  String _query = '';

  String get _title => switch (widget.docType) {
        'BC_ACHAT' => 'Commandes fournisseurs',
        'RECEPTION' => 'Réceptions & Entrées stock (PMP)',
        'FACTURE_ACHAT' => 'Factures fournisseurs',
        'AVOIR_ACHAT' => 'Avoirs fournisseurs',
        _ => 'Documents d\'achat',
      };

  @override
  Widget build(BuildContext context) {
    final docs = widget.store.purchaseDocs.where((d) {
      if (d.docType != widget.docType) return false;
      if (_query.trim().isEmpty) return true;
      final q = _query.toLowerCase();
      return d.docNumber.toLowerCase().contains(q) ||
          d.partyName.toLowerCase().contains(q);
    }).toList();

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
                    Text(_title,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    const Text(
                      'Chaîne achats : Commande → Réception (recalcul PMP) → Facture → Règlement',
                      style: TextStyle(
                          fontSize: 13, color: CommercialColors.textMuted),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _openCreatePurchaseDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nouveau document'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Rechercher par numéro ou fournisseur...',
                      prefixIcon: Icon(Icons.search, size: 18),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  const SizedBox(height: 14),
                  if (docs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Text('Aucun document d\'achat.',
                          style: TextStyle(color: CommercialColors.textMuted)),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                            const Color(0xFFF8FAFC)),
                        columns: const [
                          DataColumn(label: Text('Numéro')),
                          DataColumn(label: Text('Fournisseur')),
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Total HT'), numeric: true),
                          DataColumn(label: Text('Total TTC'), numeric: true),
                          DataColumn(label: Text('Reste dû'), numeric: true),
                          DataColumn(label: Text('Statut')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: docs.map((d) {
                          return DataRow(
                            cells: [
                              DataCell(Text(d.docNumber,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600))),
                              DataCell(Text(d.partyName)),
                              DataCell(Text(d.issueDate)),
                              DataCell(Text(
                                  '${d.totalHtMru.toStringAsFixed(0)} MRU')),
                              DataCell(Text(
                                '${d.totalTtcMru.toStringAsFixed(0)} MRU',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              )),
                              DataCell(Text(
                                '${d.remainingMru.toStringAsFixed(0)} MRU',
                                style: TextStyle(
                                  color: d.remainingMru > 0
                                      ? CommercialColors.warningAmber
                                      : CommercialColors.successGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                              )),
                              DataCell(_StatusChip(status: d.status)),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (d.docType == 'BC_ACHAT')
                                      TextButton(
                                        onPressed: () => widget.store
                                            .convertPurchaseDoc(
                                                d.id, 'RECEPTION'),
                                        child: const Text('→ Réception'),
                                      ),
                                    if (d.docType == 'RECEPTION')
                                      TextButton(
                                        onPressed: () => widget.store
                                            .convertPurchaseDoc(
                                                d.id, 'FACTURE_ACHAT'),
                                        child: const Text('→ Facture'),
                                      ),
                                    if (d.docType == 'FACTURE_ACHAT' &&
                                        d.remainingMru > 0)
                                      TextButton(
                                        onPressed: () =>
                                            _openPayPurchaseDialog(context, d),
                                        child: const Text('Régler'),
                                      ),
                                    IconButton(
                                      tooltip: 'Imprimer A4',
                                      icon: const Icon(Icons.print_outlined,
                                          size: 18),
                                      onPressed: () =>
                                          widget.store.printDocumentA4(d),
                                    ),
                                  ],
                                ),
                              ),
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

  Future<void> _openCreatePurchaseDialog(BuildContext context) async {
    final suppliers = widget.store.suppliers;
    final articles = widget.store.articles;
    if (suppliers.isEmpty || articles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Ajoutez d\'abord au moins un fournisseur et un article.'),
      ));
      return;
    }

    int supplierId = suppliers.first.id;
    int articleId = articles.first.id;
    final qtyCtrl = TextEditingController(text: '10');
    final costCtrl = TextEditingController(
      text: articles.first.pmpCostMru.toStringAsFixed(0),
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('Nouveau — $_title'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: supplierId,
                  decoration: const InputDecoration(labelText: 'Fournisseur'),
                  items: suppliers
                      .map((s) =>
                          DropdownMenuItem(value: s.id, child: Text(s.name)))
                      .toList(),
                  onChanged: (v) => setS(() => supplierId = v ?? supplierId),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: articleId,
                  decoration: const InputDecoration(labelText: 'Article'),
                  items: articles
                      .map((a) => DropdownMenuItem(
                          value: a.id, child: Text('${a.sku} — ${a.name}')))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    final art = articles.firstWhere((e) => e.id == v);
                    setS(() {
                      articleId = v;
                      costCtrl.text = art.pmpCostMru.toStringAsFixed(0);
                    });
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Quantité'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: costCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Coût unitaire HT'),
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
                final err = await widget.store.createPurchaseDoc(
                  docType: widget.docType,
                  supplierId: supplierId,
                  lines: [
                    {
                      'articleId': articleId,
                      'qty': double.tryParse(qtyCtrl.text) ?? 1,
                      'unitCostHt': double.tryParse(costCtrl.text) ?? 0,
                    }
                  ],
                );
                if (!ctx.mounted) return;
                if (err != null) {
                  ScaffoldMessenger.of(ctx)
                      .showSnackBar(SnackBar(content: Text(err)));
                } else {
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPayPurchaseDialog(
      BuildContext context, CommercialDoc d) async {
    final amountCtrl =
        TextEditingController(text: d.remainingMru.toStringAsFixed(0));
    String method = 'Cash';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('Régler ${d.docNumber}'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Montant (MRU)'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration:
                      const InputDecoration(labelText: 'Mode de règlement'),
                  items: const [
                    'Cash',
                    'Bankily',
                    'Masrivi',
                    'Virement',
                    'Chèque',
                  ]
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) => setS(() => method = v ?? 'Cash'),
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
                final err = await widget.store.payPurchaseDoc(
                    d.id, method, double.tryParse(amountCtrl.text) ?? 0);
                if (!ctx.mounted) return;
                if (err != null) {
                  ScaffoldMessenger.of(ctx)
                      .showSnackBar(SnackBar(content: Text(err)));
                } else {
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Confirmer règlement'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color color = switch (status) {
      'PAID' => CommercialColors.successGreen,
      'PARTIAL' => CommercialColors.warningAmber,
      'VALIDATED' => CommercialColors.primaryBlue,
      'DRAFT' => CommercialColors.textMuted,
      _ => CommercialColors.brandOrange,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
