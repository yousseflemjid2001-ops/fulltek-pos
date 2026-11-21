import 'package:flutter/material.dart';
import '../models/commercial_models.dart';
import '../services/export_helper.dart';
import '../state/commercial_store.dart';
import '../theme/commercial_theme.dart';

class SalesDocsView extends StatefulWidget {
  final CommercialStore store;
  final String docType; // DEVIS | COMMANDE | BL | FACTURE | AVOIR

  const SalesDocsView({
    super.key,
    required this.store,
    required this.docType,
  });

  @override
  State<SalesDocsView> createState() => _SalesDocsViewState();
}

class _SalesDocsViewState extends State<SalesDocsView> {
  String _query = '';

  String get _title => switch (widget.docType) {
        'DEVIS' => 'Devis clients',
        'COMMANDE' => 'Commandes clients',
        'BL' => 'Bons de livraison',
        'FACTURE' => 'Factures clients',
        'AVOIR' => 'Avoirs clients',
        _ => 'Documents de vente',
      };

  String? get _nextConversionTarget => switch (widget.docType) {
        'DEVIS' => 'COMMANDE',
        'COMMANDE' => 'BL',
        'BL' => 'FACTURE',
        _ => null,
      };

  String get _nextConversionLabel => switch (widget.docType) {
        'DEVIS' => 'Convertir en Commande',
        'COMMANDE' => 'Convertir en BL',
        'BL' => 'Facturer',
        _ => '',
      };

  Future<void> _openCreateDialog() async {
    final store = widget.store;
    if (store.clients.isEmpty || store.articles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Ajoutez au moins un client et un article d\'abord.')),
      );
      return;
    }

    int clientId = store.clients.first.id;
    int articleId = store.articles.first.id;
    final qtyCtrl = TextEditingController(text: '1');
    final discCtrl = TextEditingController(text: '0');
    bool validateNow = true;
    String? err;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Nouveau · $_title'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (err != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(err!,
                        style: const TextStyle(color: CommercialColors.dangerRed)),
                  ),
                DropdownButtonFormField<int>(
                  key: const Key('sales_doc_client_select'),
                  initialValue: clientId,
                  decoration: const InputDecoration(labelText: 'Client *'),
                  items: store.clients
                      .map((c) =>
                          DropdownMenuItem(value: c.id, child: Text(c.name)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setD(() => clientId = v);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  key: const Key('sales_doc_article_select'),
                  initialValue: articleId,
                  decoration: const InputDecoration(labelText: 'Article *'),
                  items: store.articles
                      .map((a) => DropdownMenuItem(
                            value: a.id,
                            child: Text(
                                '${a.name} (${fmtMru(a.priceRetailHt)} HT)'),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setD(() => articleId = v);
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('sales_doc_qty_input'),
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Quantité'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: discCtrl,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Remise (%)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Valider immédiatement'),
                  value: validateNow,
                  onChanged: (v) => setD(() => validateNow = v),
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
              key: const Key('save_sales_doc_btn'),
              onPressed: () async {
                final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0;
                final disc = double.tryParse(discCtrl.text.trim()) ?? 0;
                if (qty <= 0) {
                  setD(() => err = 'Quantité invalide.');
                  return;
                }
                final res = await store.createSalesDoc(
                  docType: widget.docType,
                  clientId: clientId,
                  globalDiscountPct: disc,
                  validateNow: validateNow,
                  lines: [
                    {'articleId': articleId, 'qty': qty}
                  ],
                );
                if (res != null) {
                  setD(() => err = res);
                  return;
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
    qtyCtrl.dispose();
    discCtrl.dispose();
  }

  Future<void> _openPayDialog(CommercialDoc doc) async {
    final store = widget.store;
    String method = store.tenant.payMethods.first;
    final amountCtrl =
        TextEditingController(text: doc.remainingMru.toStringAsFixed(0));
    final refCtrl = TextEditingController();
    String? err;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Règlement · ${doc.docNumber}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (err != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(err!,
                      style: const TextStyle(color: CommercialColors.dangerRed)),
                ),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(labelText: 'Mode de paiement'),
                items: [
                  ...store.tenant.payMethods,
                  'Chèque',
                ]
                    .toSet()
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setD(() => method = v);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Montant (MRU) *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: refCtrl,
                decoration: const InputDecoration(labelText: 'Référence'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
                final res = await store.paySalesDoc(
                  doc.id,
                  payMethod: method,
                  amountMru: amt,
                  ref: refCtrl.text.trim(),
                  dueDate: method == 'Chèque'
                      ? DateTime.now().toIso8601String().substring(0, 10)
                      : null,
                );
                if (res != null) {
                  setD(() => err = res);
                  return;
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Encaisser'),
            ),
          ],
        ),
      ),
    );
    amountCtrl.dispose();
    refCtrl.dispose();
  }

  void _exportCsv(List<CommercialDoc> docs) {
    final buf = StringBuffer(
        'Numéro;Type;Date;Client;Statut;Total HT;TVA;Total TTC;Payé;Reste\n');
    for (final d in docs) {
      buf.writeln(
          '${d.docNumber};${d.docType};${d.issueDate};${d.partyName};${d.status};${d.totalHtMru};${d.totalTvaMru};${d.totalTtcMru};${d.paidMru};${d.remainingMru}');
    }
    downloadCsvFile('${widget.docType.toLowerCase()}_export.csv', buf.toString());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export CSV / Excel généré.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docs = widget.store.salesDocs.where((d) {
      if (d.docType != widget.docType) return false;
      final q = _query.trim().toLowerCase();
      if (q.isEmpty) return true;
      return d.docNumber.toLowerCase().contains(q) ||
          d.partyName.toLowerCase().contains(q);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '$_title (${docs.length})',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: CommercialColors.textPrimary,
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  SizedBox(
                    width: 220,
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      decoration: const InputDecoration(
                        hintText: 'Rechercher N° ou client...',
                        prefixIcon: Icon(Icons.search_rounded, size: 18),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _exportCsv(docs),
                    icon: const Icon(Icons.download_rounded, size: 17),
                    label: const Text('Excel'),
                  ),
                  ElevatedButton.icon(
                    key: Key('new_${widget.docType.toLowerCase()}_btn'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CommercialColors.primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _openCreateDialog,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Nouveau'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: docs.isEmpty
                ? const Center(
                    child: Text(
                      'Aucun document pour le moment.',
                      style: TextStyle(color: CommercialColors.textMuted),
                    ),
                  )
                : ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final d = docs[i];
                      final target = _nextConversionTarget;
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              SizedBox(
                                width: 280,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${d.docNumber} · ${d.partyName}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13.5),
                                    ),
                                    Text(
                                      '${d.issueDate} · Statut: ${d.status}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: CommercialColors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'TTC: ${fmtMru(d.totalTtcMru)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: CommercialColors.primaryBlue),
                                  ),
                                  if (d.remainingMru > 0 &&
                                      d.docType == 'FACTURE')
                                    Text(
                                      'Reste: ${fmtMru(d.remainingMru)}',
                                      style: const TextStyle(
                                          fontSize: 11.5,
                                          color: CommercialColors.dangerRed,
                                          fontWeight: FontWeight.w700),
                                    ),
                                ],
                              ),
                              Wrap(
                                spacing: 6,
                                children: [
                                  if (d.status == 'BROUILLON')
                                    OutlinedButton(
                                      onPressed: () =>
                                          widget.store.validateSalesDoc(d.id),
                                      child: const Text('Valider'),
                                    ),
                                  if (target != null && d.status != 'CONVERTI')
                                    ElevatedButton(
                                      key: Key('convert_${d.id}'),
                                      onPressed: () => widget.store
                                          .convertSalesDoc(d.id, target),
                                      child: Text(_nextConversionLabel),
                                    ),
                                  if (d.docType == 'FACTURE' &&
                                      d.remainingMru > 0.01 &&
                                      d.status != 'BROUILLON')
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            CommercialColors.successGreen,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () => _openPayDialog(d),
                                      child: const Text('Encaisser'),
                                    ),
                                  IconButton(
                                    tooltip: 'Imprimer / PDF A4',
                                    onPressed: () =>
                                        widget.store.printDocumentA4(d),
                                    icon: const Icon(Icons.print_outlined),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
