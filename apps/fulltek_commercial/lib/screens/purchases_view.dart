import 'package:flutter/material.dart';
import '../models/commercial_models.dart';
import '../state/commercial_store.dart';
import '../theme/commercial_theme.dart';

class _DraftPurchaseLine {
  int articleId;
  double qty;
  double unitCostHt;
  _DraftPurchaseLine({
    required this.articleId,
    this.qty = 10,
    required this.unitCostHt,
  });
}

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
                    Text('Répertoire fournisseurs, NIF / RC, délais et dettes à payer',
                        style: TextStyle(
                            fontSize: 13, color: CommercialColors.textMuted)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _openSupplierDialog(context),
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
                          DataColumn(label: Text('NIF / RC')),
                          DataColumn(label: Text('Téléphone & Ville')),
                          DataColumn(label: Text('Délai (j)'), numeric: true),
                          DataColumn(label: Text('Solde dû'), numeric: true),
                          DataColumn(label: Text('Actions')),
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
                              DataCell(Text(s.nif.isEmpty
                                  ? '—'
                                  : '${s.nif}${s.rc.isNotEmpty ? ' / ${s.rc}' : ''}')),
                              DataCell(Text(
                                  '${s.phone.isEmpty ? '—' : s.phone} • ${s.city}')),
                              DataCell(Text('${s.paymentTermsDays} j')),
                              DataCell(Text(
                                fmtMru(s.balanceDueMru),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: s.balanceDueMru > 0
                                      ? CommercialColors.warningAmber
                                      : CommercialColors.successGreen,
                                ),
                              )),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Modifier',
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 18),
                                      onPressed: () => _openSupplierDialog(
                                          context,
                                          editing: s),
                                    ),
                                    IconButton(
                                      tooltip: 'Supprimer',
                                      icon: const Icon(Icons.delete_outline,
                                          size: 18,
                                          color: CommercialColors.dangerRed),
                                      onPressed: () =>
                                          widget.store.deleteSupplier(s.id),
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

  Future<void> _openSupplierDialog(BuildContext context,
      {CommercialSupplier? editing}) async {
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    final nifCtrl = TextEditingController(text: editing?.nif ?? '');
    final rcCtrl = TextEditingController(text: editing?.rc ?? '');
    final phoneCtrl = TextEditingController(text: editing?.phone ?? '');
    final cityCtrl =
        TextEditingController(text: editing?.city ?? 'Nouakchott');
    final termsCtrl =
        TextEditingController(text: '${editing?.paymentTermsDays ?? 30}');

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(editing == null
            ? 'Nouveau fournisseur'
            : 'Modifier fournisseur · ${editing.code}'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration:
                    const InputDecoration(labelText: 'Raison sociale *'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: nifCtrl,
                      decoration: const InputDecoration(labelText: 'NIF'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: rcCtrl,
                      decoration: const InputDecoration(labelText: 'RC'),
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
              final String? err;
              if (editing == null) {
                err = await widget.store.createSupplier(
                  name: nameCtrl.text,
                  nif: nifCtrl.text,
                  phone: phoneCtrl.text,
                  city: cityCtrl.text,
                  paymentTermsDays: int.tryParse(termsCtrl.text) ?? 30,
                );
              } else {
                err = await widget.store.updateSupplier(
                  editing.id,
                  name: nameCtrl.text,
                  nif: nifCtrl.text,
                  rc: rcCtrl.text,
                  phone: phoneCtrl.text,
                  city: cityCtrl.text,
                  paymentTermsDays: int.tryParse(termsCtrl.text) ?? 30,
                );
              }
              if (!ctx.mounted) return;
              if (err != null) {
                ScaffoldMessenger.of(ctx)
                    .showSnackBar(SnackBar(content: Text(err)));
              } else {
                Navigator.pop(ctx);
              }
            },
            child: Text(editing == null ? 'Enregistrer' : 'Mettre à jour'),
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
                      'Chaîne achats : Commande → Réception (recalcul PMP pondéré) → Facture → Règlement',
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
                              DataCell(
                                InkWell(
                                  onTap: () => _openPurchaseDetail(context, d),
                                  child: Text(d.docNumber,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: CommercialColors.primaryBlue)),
                                ),
                              ),
                              DataCell(Text(d.partyName)),
                              DataCell(Text(d.issueDate)),
                              DataCell(Text(fmtMru(d.totalHtMru))),
                              DataCell(Text(fmtMru(d.totalTtcMru),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600))),
                              DataCell(Text(
                                fmtMru(d.remainingMru),
                                style: TextStyle(
                                  color: d.remainingMru > 0
                                      ? CommercialColors.warningAmber
                                      : CommercialColors.successGreen,
                                  fontWeight: FontWeight.w700,
                                ),
                              )),
                              DataCell(_StatusChip(status: d.status)),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Aperçu & Lignes',
                                      icon: const Icon(
                                          Icons.visibility_outlined,
                                          size: 18),
                                      onPressed: () =>
                                          _openPurchaseDetail(context, d),
                                    ),
                                    if (d.status == 'BROUILLON')
                                      TextButton(
                                        onPressed: () => widget.store
                                            .validatePurchaseDoc(d.id),
                                        child: const Text('Valider'),
                                      ),
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
    String currency = 'MRU';
    final rateCtrl = TextEditingController(text: '1');
    final freightCtrl = TextEditingController(text: '0');
    final dueCtrl = TextEditingController(
      text: DateTime.now()
          .add(Duration(days: suppliers.first.paymentTermsDays))
          .toIso8601String()
          .substring(0, 10),
    );
    bool validateNow = true;
    final lines = <_DraftPurchaseLine>[
      _DraftPurchaseLine(
        articleId: articles.first.id,
        qty: 10,
        unitCostHt: articles.first.pmpCostMru,
      ),
    ];

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final fxRate = (double.tryParse(rateCtrl.text) ?? 1).clamp(0.01, 10000);
          final freightMru =
              (double.tryParse(freightCtrl.text) ?? 0).clamp(0.0, 999999999);
          double rawGoodsMru = 0;
          for (final l in lines) {
            rawGoodsMru += l.qty * l.unitCostHt * fxRate;
          }
          double landedUnitMru(_DraftPurchaseLine l) {
            final baseMru = l.unitCostHt * fxRate;
            if (freightMru <= 0 || rawGoodsMru <= 0 || l.qty <= 0) return baseMru;
            final lineShare = (l.qty * baseMru) / rawGoodsMru;
            return baseMru + (freightMru * lineShare) / l.qty;
          }

          double totalHt = 0;
          double totalTva = 0;
          for (final l in lines) {
            final art = articles.firstWhere((a) => a.id == l.articleId);
            final lHt = CommercialMath.computeLineHt(
                qty: l.qty, unitPriceHt: landedUnitMru(l));
            totalHt += lHt;
            totalTva += CommercialMath.computeLineTva(
                lineHt: lHt, isExempt: art.isExempt, tvaRate: art.tvaRate);
          }

          return AlertDialog(
            title: Text('Nouveau · $_title (Multi-Devises, Frais d\'approche & PMP)'),
            content: SizedBox(
              width: 820,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<int>(
                            initialValue: supplierId,
                            isExpanded: true,
                            decoration:
                                const InputDecoration(labelText: 'Fournisseur *'),
                            items: suppliers
                                .map((s) => DropdownMenuItem(
                                    value: s.id,
                                    child: Text('${s.code} · ${s.name}',
                                        overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              final sup =
                                  suppliers.firstWhere((s) => s.id == v);
                              setS(() {
                                supplierId = v;
                                dueCtrl.text = DateTime.now()
                                    .add(Duration(days: sup.paymentTermsDays))
                                    .toIso8601String()
                                    .substring(0, 10);
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 96,
                          child: DropdownButtonFormField<String>(
                            initialValue: currency,
                            decoration:
                                const InputDecoration(labelText: 'Devise'),
                            items: const ['MRU', 'EUR', 'USD', 'MAD', 'XOF']
                                .map((c) => DropdownMenuItem(
                                    value: c, child: Text(c)))
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setS(() {
                                currency = v;
                                rateCtrl.text = switch (v) {
                                  'EUR' => '43',
                                  'USD' => '40',
                                  'MAD' => '4',
                                  'XOF' => '0.065',
                                  _ => '1',
                                };
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 92,
                          child: TextField(
                            controller: rateCtrl,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: 'Taux MRU'),
                            onChanged: (_) => setS(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 150,
                          child: TextField(
                            controller: freightCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Douane/Fret (MRU)'),
                            onChanged: (_) => setS(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        SizedBox(
                          width: 220,
                          child: TextField(
                            controller: dueCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Échéance (YYYY-MM-DD)'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Les frais d\'approche (Douane, Fret, Transit) sont ventilés au prorata dans le coût unitaire et le PMP.',
                            style: TextStyle(
                                fontSize: 11.5,
                                color: CommercialColors.textMuted),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Lignes d\'achat (${lines.length})',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13)),
                        OutlinedButton.icon(
                          onPressed: () => setS(() {
                            lines.add(_DraftPurchaseLine(
                              articleId: articles.first.id,
                              qty: 10,
                              unitCostHt: articles.first.pmpCostMru,
                            ));
                          }),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Ajouter ligne'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(lines.length, (i) {
                      final line = lines[i];
                      final art =
                          articles.firstWhere((a) => a.id == line.articleId);
                      final landed = landedUnitMru(line);
                      final newPmp = CommercialMath.computeWeightedPmp(
                        currentStock: art.stockQty,
                        currentPmp: art.pmpCostMru,
                        incomingQty: line.qty,
                        incomingCostHt: landed,
                      );
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: CommercialColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: DropdownButtonFormField<int>(
                                initialValue: line.articleId,
                                isExpanded: true,
                                decoration:
                                    const InputDecoration(labelText: 'Article'),
                                items: articles
                                    .map((a) => DropdownMenuItem(
                                        value: a.id,
                                        child: Text('${a.sku} · ${a.name}',
                                            overflow: TextOverflow.ellipsis)))
                                    .toList(),
                                onChanged: (v) {
                                  if (v == null) return;
                                  final a =
                                      articles.firstWhere((e) => e.id == v);
                                  setS(() {
                                    line.articleId = v;
                                    line.unitCostHt = a.pmpCostMru;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 82,
                              child: TextFormField(
                                initialValue: line.qty.toStringAsFixed(0),
                                keyboardType: TextInputType.number,
                                decoration:
                                    const InputDecoration(labelText: 'Qté'),
                                onChanged: (v) => setS(() {
                                  line.qty =
                                      (double.tryParse(v) ?? 1).clamp(0.1, 99999);
                                }),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 112,
                              child: TextFormField(
                                key: ValueKey('cost_${i}_${line.articleId}'),
                                initialValue:
                                    line.unitCostHt.toStringAsFixed(0),
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'Coût HT'),
                                onChanged: (v) => setS(() {
                                  line.unitCostHt = double.tryParse(v) ?? 0;
                                }),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 130,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(fmtMru(line.qty * line.unitCostHt),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12)),
                                  Text('PMP → ${fmtMru(newPmp)}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: CommercialColors.primaryBlue)),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: lines.length <= 1
                                  ? null
                                  : () => setS(() => lines.removeAt(i)),
                              icon: const Icon(Icons.delete_outline,
                                  size: 18, color: CommercialColors.dangerRed),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Valider immédiatement (Entrée stock & recalcul PMP)'),
                      value: validateNow,
                      onChanged: (v) => setS(() => validateNow = v),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Total HT : ${fmtMru(totalHt)}  •  TVA : ${fmtMru(totalTva)}  •  TTC : ${fmtMru(totalHt + totalTva)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: CommercialColors.primaryBlue),
                      ),
                    ),
                  ],
                ),
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
                    validateNow: validateNow,
                    dueDate: dueCtrl.text.trim(),
                    lines: lines
                        .map((l) => {
                              'articleId': l.articleId,
                              'qty': l.qty,
                              'unitCostHt': landedUnitMru(l),
                            })
                        .toList(),
                  );
                  if (!ctx.mounted) return;
                  if (err != null) {
                    ScaffoldMessenger.of(ctx)
                        .showSnackBar(SnackBar(content: Text(err)));
                  } else {
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Enregistrer le document'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openPurchaseDetail(
      BuildContext context, CommercialDoc summary) async {
    final full = await widget.store.getPurchaseDocDetail(summary.id) ?? summary;
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${full.docNumber} · ${full.partyName}'),
        content: SizedBox(
          width: 680,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Date : ${full.issueDate} • Statut : ${full.status} • Stock appliqué : ${full.stockApplied ? 'Oui' : 'Non'}'),
                const SizedBox(height: 12),
                if (full.lines.isNotEmpty)
                  DataTable(
                    columns: const [
                      DataColumn(label: Text('SKU')),
                      DataColumn(label: Text('Article')),
                      DataColumn(label: Text('Qté'), numeric: true),
                      DataColumn(label: Text('Coût HT'), numeric: true),
                      DataColumn(label: Text('Total TTC'), numeric: true),
                    ],
                    rows: full.lines
                        .map((l) => DataRow(cells: [
                              DataCell(Text(l.sku)),
                              DataCell(Text(l.designation)),
                              DataCell(Text(l.qty.toStringAsFixed(1))),
                              DataCell(Text(fmtMru(l.unitPriceHtMru))),
                              DataCell(Text(fmtMru(l.lineTtcMru))),
                            ]))
                        .toList(),
                  ),
                const SizedBox(height: 10),
                Text(
                  'HT : ${fmtMru(full.totalHtMru)} • TTC : ${fmtMru(full.totalTtcMru)} • Reste dû : ${fmtMru(full.remainingMru)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (full.status == 'BROUILLON')
            TextButton(
              onPressed: () async {
                await widget.store.deletePurchaseDoc(full.id);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Supprimer brouillon',
                  style: TextStyle(color: CommercialColors.dangerRed)),
            ),
          OutlinedButton.icon(
            onPressed: () => widget.store.printDocumentA4(full),
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text('Imprimer A4'),
          ),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
        ],
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
                    'Sedad',
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
      'PAID' || 'PAYEE' => CommercialColors.successGreen,
      'PARTIAL' || 'PARTIELLE' => CommercialColors.warningAmber,
      'VALIDATED' || 'VALIDEE' => CommercialColors.primaryBlue,
      'DRAFT' || 'BROUILLON' => CommercialColors.textMuted,
      _ => CommercialColors.brandViolet,
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
