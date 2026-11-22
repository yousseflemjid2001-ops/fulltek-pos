import 'package:flutter/material.dart';
import '../models/commercial_models.dart';
import '../state/commercial_store.dart';
import '../theme/commercial_theme.dart';

class _DraftSalesLine {
  int articleId;
  double qty;
  double unitPriceHt;
  double discountPct = 0;
  _DraftSalesLine({
    required this.articleId,
    this.qty = 1,
    required this.unitPriceHt,
  });
}

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
  String _statusFilter = 'ALL';

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
        'FACTURE' => 'AVOIR',
        _ => null,
      };

  String get _nextConversionLabel => switch (widget.docType) {
        'DEVIS' => '→ Commande',
        'COMMANDE' => '→ Bon de livraison',
        'BL' => '→ Facturer',
        'FACTURE' => '→ Avoir',
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
    String priceTier = 'retail';
    final globalDiscCtrl = TextEditingController(text: '0');
    final dueDateCtrl = TextEditingController(
      text: DateTime.now()
          .add(Duration(days: store.clients.first.paymentTermsDays))
          .toIso8601String()
          .substring(0, 10),
    );
    bool validateNow = true;
    bool restock = true;
    String? err;

    final firstArt = store.articles.first;
    final lines = <_DraftSalesLine>[
      _DraftSalesLine(
        articleId: firstArt.id,
        qty: 1,
        unitPriceHt: firstArt.priceRetailHt,
      ),
    ];

    double computeNetHt() {
      final gDisc = (double.tryParse(globalDiscCtrl.text) ?? 0).clamp(0, 90);
      double sum = 0;
      for (final l in lines) {
        sum += CommercialMath.computeLineHt(
          qty: l.qty,
          unitPriceHt: l.unitPriceHt,
          discountPct: l.discountPct,
        );
      }
      return sum * (1 - gDisc / 100);
    }

    double computeTva() {
      final gDisc = (double.tryParse(globalDiscCtrl.text) ?? 0).clamp(0, 90);
      double sum = 0;
      for (final l in lines) {
        final art = store.articles.firstWhere((a) => a.id == l.articleId);
        final lHt = CommercialMath.computeLineHt(
              qty: l.qty,
              unitPriceHt: l.unitPriceHt,
              discountPct: l.discountPct,
            ) *
            (1 - gDisc / 100);
        sum += CommercialMath.computeLineTva(
          lineHt: lHt,
          isExempt: art.isExempt,
          tvaRate: art.tvaRate,
        );
      }
      return sum;
    }

    double computeCost() {
      double sum = 0;
      for (final l in lines) {
        final art = store.articles.firstWhere((a) => a.id == l.articleId);
        sum += l.qty * art.pmpCostMru;
      }
      return sum;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final selectedClient =
              store.clients.firstWhere((c) => c.id == clientId);
          final netHt = computeNetHt();
          final totalTva = computeTva();
          final totalTtc = netHt + totalTva;
          final cost = computeCost();
          final marginMru = netHt - cost;
          final marginPct = CommercialMath.computeMarginPct(
            caHt: netHt,
            costMru: cost,
          );

          return AlertDialog(
            titlePadding: const EdgeInsets.fromLTRB(24, 18, 20, 10),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: CommercialColors.primaryBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.description_outlined,
                      color: CommercialColors.primaryBlue, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nouveau · $_title',
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700)),
                      const Text(
                        'Éditeur multi-lignes · TVA 16% / Exonéré · Calcul marge temps réel',
                        style: TextStyle(
                            fontSize: 12, color: CommercialColors.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            content: SizedBox(
              width: 820,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (err != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: CommercialColors.dangerRed
                              .withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: CommercialColors.dangerRed
                                  .withValues(alpha: 0.4)),
                        ),
                        child: Text(err!,
                            style: const TextStyle(
                                color: CommercialColors.dangerRed,
                                fontWeight: FontWeight.w600)),
                      ),
                    // Section 1: En-tête client & conditions
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: CommercialColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('1. Client & Conditions',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<int>(
                                  key: const Key('sales_doc_client_select'),
                                  initialValue: clientId,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                      labelText: 'Client *'),
                                  items: store.clients
                                      .map((c) => DropdownMenuItem(
                                            value: c.id,
                                            child: Text(
                                              '${c.code} · ${c.name}${c.nif.isNotEmpty ? ' (NIF ${c.nif})' : ''}',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v == null) return;
                                    final cli = store.clients
                                        .firstWhere((c) => c.id == v);
                                    setD(() {
                                      clientId = v;
                                      dueDateCtrl.text = DateTime.now()
                                          .add(Duration(
                                              days: cli.paymentTermsDays))
                                          .toIso8601String()
                                          .substring(0, 10);
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  initialValue: priceTier,
                                  decoration: const InputDecoration(
                                      labelText: 'Grille tarifaire'),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'retail',
                                        child: Text('Tarif Détail HT')),
                                    DropdownMenuItem(
                                        value: 'wholesale',
                                        child: Text('Tarif Gros HT')),
                                  ],
                                  onChanged: (v) {
                                    if (v == null) return;
                                    setD(() {
                                      priceTier = v;
                                      for (final l in lines) {
                                        final a = store.articles.firstWhere(
                                            (x) => x.id == l.articleId);
                                        l.unitPriceHt = v == 'wholesale'
                                            ? a.priceWholeHt
                                            : a.priceRetailHt;
                                      }
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: dueDateCtrl,
                                  decoration: const InputDecoration(
                                      labelText: 'Échéance (YYYY-MM-DD)'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 110,
                                child: TextField(
                                  controller: globalDiscCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      labelText: 'Remise %'),
                                  onChanged: (_) => setD(() {}),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Client : ${selectedClient.name} • Délai : ${selectedClient.paymentTermsDays} j • Encours Karni : ${fmtMru(selectedClient.karniDebtMru)} / Plafond : ${fmtMru(selectedClient.creditLimitMru)}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: CommercialColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Section 2: Lignes articles
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('2. Lignes du document (${lines.length})',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13)),
                        OutlinedButton.icon(
                          onPressed: () {
                            final art = store.articles.first;
                            setD(() {
                              lines.add(_DraftSalesLine(
                                articleId: art.id,
                                qty: 1,
                                unitPriceHt: priceTier == 'wholesale'
                                    ? art.priceWholeHt
                                    : art.priceRetailHt,
                              ));
                            });
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Ajouter une ligne'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(lines.length, (i) {
                      final line = lines[i];
                      final art = store.articles
                          .firstWhere((a) => a.id == line.articleId);
                      final lHt = CommercialMath.computeLineHt(
                        qty: line.qty,
                        unitPriceHt: line.unitPriceHt,
                        discountPct: line.discountPct,
                      );
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
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
                                items: store.articles
                                    .map((a) => DropdownMenuItem(
                                          value: a.id,
                                          child: Text(
                                            '${a.sku} · ${a.name} (Stk ${a.stockQty.toStringAsFixed(0)})',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ))
                                    .toList(),
                                onChanged: (v) {
                                  if (v == null) return;
                                  final chosen = store.articles
                                      .firstWhere((a) => a.id == v);
                                  setD(() {
                                    line.articleId = v;
                                    line.unitPriceHt = priceTier == 'wholesale'
                                        ? chosen.priceWholeHt
                                        : chosen.priceRetailHt;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 78,
                              child: TextFormField(
                                initialValue: line.qty.toStringAsFixed(0),
                                keyboardType: TextInputType.number,
                                decoration:
                                    const InputDecoration(labelText: 'Qté'),
                                onChanged: (v) => setD(() {
                                  line.qty =
                                      (double.tryParse(v) ?? 1).clamp(0.1, 99999);
                                }),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 112,
                              child: TextFormField(
                                key: ValueKey(
                                    'pu_${i}_${line.articleId}_$priceTier'),
                                initialValue:
                                    line.unitPriceHt.toStringAsFixed(0),
                                keyboardType: TextInputType.number,
                                decoration:
                                    const InputDecoration(labelText: 'PU HT'),
                                onChanged: (v) => setD(() {
                                  line.unitPriceHt = double.tryParse(v) ?? 0;
                                }),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 78,
                              child: TextFormField(
                                initialValue:
                                    line.discountPct.toStringAsFixed(0),
                                keyboardType: TextInputType.number,
                                decoration:
                                    const InputDecoration(labelText: 'Rem %'),
                                onChanged: (v) => setD(() {
                                  line.discountPct =
                                      (double.tryParse(v) ?? 0).clamp(0, 95);
                                }),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 115,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(fmtMru(lHt),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13)),
                                  Text(
                                    art.isExempt ? 'TVA Exonéré' : 'TVA 16%',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: CommercialColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Supprimer ligne',
                              onPressed: lines.length <= 1
                                  ? null
                                  : () => setD(() => lines.removeAt(i)),
                              icon: const Icon(Icons.delete_outline,
                                  size: 18, color: CommercialColors.dangerRed),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 10),
                    // Section 3: Options & Récapitulatif financier
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                title: const Text(
                                    'Valider immédiatement le document'),
                                subtitle: Text(
                                  widget.docType == 'BL' ||
                                          widget.docType == 'FACTURE'
                                      ? 'Déstocke automatiquement les articles et met à jour l\'encours client.'
                                      : 'Passe le statut en VALIDEE dès la création.',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                value: validateNow,
                                onChanged: (v) => setD(() => validateNow = v),
                              ),
                              if (widget.docType == 'AVOIR')
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  title: const Text(
                                      'Réintégrer les quantités en stock'),
                                  value: restock,
                                  onChanged: (v) => setD(() => restock = v),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          width: 300,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: CommercialColors.border),
                          ),
                          child: Column(
                            children: [
                              _SumRow('Net HT', fmtMru(netHt)),
                              _SumRow('TVA (16% / Exonéré)', fmtMru(totalTva)),
                              const Divider(height: 14),
                              _SumRow('NET À PAYER TTC', fmtMru(totalTtc),
                                  bold: true,
                                  color: CommercialColors.primaryBlue),
                              const SizedBox(height: 6),
                              _SumRow(
                                'Marge brute estimée',
                                '${fmtMru(marginMru)} (${marginPct.toStringAsFixed(1)}%)',
                                color: marginMru >= 0
                                    ? CommercialColors.successGreen
                                    : CommercialColors.dangerRed,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final payloadLines = lines
                      .map((l) => {
                            'articleId': l.articleId,
                            'qty': l.qty,
                            'unitPriceHtMru': l.unitPriceHt,
                            'discountPct': l.discountPct,
                          })
                      .toList();
                  final res = await store.createSalesDoc(
                    docType: widget.docType,
                    clientId: clientId,
                    globalDiscountPct:
                        double.tryParse(globalDiscCtrl.text) ?? 0,
                    validateNow: validateNow,
                    restock: restock,
                    dueDate: dueDateCtrl.text.trim(),
                    lines: payloadLines,
                  );
                  if (!ctx.mounted) return;
                  if (res != null) {
                    setD(() => err = res);
                  } else {
                    Navigator.pop(ctx);
                  }
                },
                icon: const Icon(Icons.check, size: 18),
                label: Text(validateNow
                    ? 'Enregistrer & Valider'
                    : 'Enregistrer brouillon'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openDocDetailDialog(CommercialDoc summary) async {
    final full = await widget.store.getSalesDocDetail(summary.id) ?? summary;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Text('${full.docNumber} · ${full.partyName}',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            _StatusBadge(status: full.status),
          ],
        ),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 18,
                  runSpacing: 6,
                  children: [
                    Text('Date : ${full.issueDate}'),
                    if (full.dueDate.isNotEmpty)
                      Text('Échéance : ${full.dueDate}'),
                    if (full.partyNif.isNotEmpty)
                      Text('NIF client : ${full.partyNif}'),
                    Text(
                        'Stock déduit : ${full.stockApplied ? 'Oui' : 'Non'}'),
                  ],
                ),
                const SizedBox(height: 14),
                if (full.lines.isEmpty)
                  const Text('Détail des lignes disponible après validation.',
                      style: TextStyle(color: CommercialColors.textMuted))
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor:
                          WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                      columns: const [
                        DataColumn(label: Text('SKU')),
                        DataColumn(label: Text('Désignation')),
                        DataColumn(label: Text('Qté'), numeric: true),
                        DataColumn(label: Text('PU HT'), numeric: true),
                        DataColumn(label: Text('Rem %'), numeric: true),
                        DataColumn(label: Text('Total HT'), numeric: true),
                        DataColumn(label: Text('Total TTC'), numeric: true),
                      ],
                      rows: full.lines
                          .map((l) => DataRow(cells: [
                                DataCell(Text(l.sku)),
                                DataCell(Text(l.designation)),
                                DataCell(Text(l.qty.toStringAsFixed(1))),
                                DataCell(Text(fmtMru(l.unitPriceHtMru))),
                                DataCell(Text(
                                    '${l.discountPct.toStringAsFixed(0)}%')),
                                DataCell(Text(fmtMru(l.lineHtMru))),
                                DataCell(Text(fmtMru(l.lineTtcMru),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600))),
                              ]))
                          .toList(),
                    ),
                  ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 280,
                    child: Column(
                      children: [
                        _SumRow('Total HT', fmtMru(full.totalHtMru)),
                        _SumRow('TVA', fmtMru(full.totalTvaMru)),
                        _SumRow('Total TTC', fmtMru(full.totalTtcMru),
                            bold: true),
                        _SumRow('Déjà encaissé', fmtMru(full.paidMru),
                            color: CommercialColors.successGreen),
                        _SumRow('Reste à payer', fmtMru(full.remainingMru),
                            bold: true,
                            color: full.remainingMru > 0
                                ? CommercialColors.warningAmber
                                : CommercialColors.successGreen),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (full.status == 'BROUILLON')
            TextButton.icon(
              onPressed: () async {
                await widget.store.deleteSalesDoc(full.id);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              icon: const Icon(Icons.delete_outline,
                  color: CommercialColors.dangerRed, size: 18),
              label: const Text('Supprimer brouillon',
                  style: TextStyle(color: CommercialColors.dangerRed)),
            ),
          OutlinedButton.icon(
            onPressed: () => widget.store.printDocumentA4(full),
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text('Imprimer PDF A4'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _openPayDialog(CommercialDoc doc) async {
    final amountCtrl =
        TextEditingController(text: doc.remainingMru.toStringAsFixed(0));
    final refCtrl = TextEditingController();
    final dueCtrl = TextEditingController();
    String method = 'Cash';
    String? err;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Encaisser ${doc.docNumber}'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (err != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(err!,
                        style:
                            const TextStyle(color: CommercialColors.dangerRed)),
                  ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: CommercialColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Reste à encaisser :'),
                      Text(fmtMru(doc.remainingMru),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: CommercialColors.primaryBlue)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Montant encaissé (MRU)'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration:
                      const InputDecoration(labelText: 'Mode de règlement'),
                  items: const [
                    'Cash',
                    'Bankily',
                    'Masrivi',
                    'Sedad',
                    'Bimbank',
                    'Click',
                    'Virement',
                    'Chèque',
                  ]
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) => setD(() => method = v ?? 'Cash'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: refCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Référence transaction / N° Chèque'),
                ),
                if (method == 'Chèque') ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: dueCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Date d\'échéance (YYYY-MM-DD)'),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                final res = await widget.store.paySalesDoc(
                  doc.id,
                  payMethod: method,
                  amountMru: double.tryParse(amountCtrl.text) ?? 0,
                  ref: refCtrl.text.trim(),
                  dueDate: dueCtrl.text.trim(),
                );
                if (!ctx.mounted) return;
                if (res != null) {
                  setD(() => err = res);
                } else {
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Valider l\'encaissement'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allTypeDocs =
        widget.store.salesDocs.where((d) => d.docType == widget.docType).toList();
    final docs = allTypeDocs.where((d) {
      if (_statusFilter != 'ALL' && d.status != _statusFilter) return false;
      if (_query.trim().isEmpty) return true;
      final q = _query.toLowerCase();
      return d.docNumber.toLowerCase().contains(q) ||
          d.partyName.toLowerCase().contains(q);
    }).toList();

    final sumHt = allTypeDocs.fold<double>(0, (s, d) => s + d.totalHtMru);
    final sumTtc = allTypeDocs.fold<double>(0, (s, d) => s + d.totalTtcMru);
    final sumRem = allTypeDocs.fold<double>(0, (s, d) => s + d.remainingMru);

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
                    const Text(
                      'Cycle commercial complet : Devis → Commande → BL → Facture A4 → Encaissement',
                      style: TextStyle(
                          fontSize: 13, color: CommercialColors.textMuted),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _openCreateDialog,
                icon: const Icon(Icons.add, size: 18),
                label: Text('Nouveau ${widget.docType.toLowerCase()}'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _DocKpi('Documents', '${allTypeDocs.length}',
                  CommercialColors.primaryBlue),
              _DocKpi('Total HT', fmtMru(sumHt), CommercialColors.textPrimary),
              _DocKpi('Total TTC', fmtMru(sumTtc), CommercialColors.successGreen),
              if (widget.docType == 'FACTURE')
                _DocKpi('Reste à encaisser', fmtMru(sumRem),
                    CommercialColors.warningAmber),
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
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 300,
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'Rechercher N° document ou client...',
                            prefixIcon: Icon(Icons.search, size: 18),
                          ),
                          onChanged: (v) => setState(() => _query = v),
                        ),
                      ),
                      for (final st in const [
                        ('ALL', 'Tous'),
                        ('BROUILLON', 'Brouillons'),
                        ('VALIDEE', 'Validés'),
                        ('PARTIELLE', 'Partiels'),
                        ('PAYEE', 'Payés'),
                      ])
                        ChoiceChip(
                          label: Text(st.$2),
                          selected: _statusFilter == st.$1,
                          onSelected: (_) =>
                              setState(() => _statusFilter = st.$1),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (docs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text('Aucun document trouvé.',
                            style:
                                TextStyle(color: CommercialColors.textMuted)),
                      ),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                            const Color(0xFFF8FAFC)),
                        columns: const [
                          DataColumn(label: Text('Numéro')),
                          DataColumn(label: Text('Client')),
                          DataColumn(label: Text('Date / Échéance')),
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
                                  onTap: () => _openDocDetailDialog(d),
                                  child: Text(d.docNumber,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: CommercialColors.primaryBlue)),
                                ),
                              ),
                              DataCell(Text(d.partyName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600))),
                              DataCell(Text(
                                  '${d.issueDate}${d.dueDate.isNotEmpty && d.dueDate != d.issueDate ? ' → ${d.dueDate}' : ''}')),
                              DataCell(Text(fmtMru(d.totalHtMru))),
                              DataCell(Text(fmtMru(d.totalTtcMru),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600))),
                              DataCell(Text(
                                fmtMru(d.remainingMru),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: d.remainingMru > 0
                                      ? CommercialColors.warningAmber
                                      : CommercialColors.successGreen,
                                ),
                              )),
                              DataCell(_StatusBadge(status: d.status)),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Aperçu & Lignes',
                                      icon: const Icon(
                                          Icons.visibility_outlined,
                                          size: 18),
                                      onPressed: () => _openDocDetailDialog(d),
                                    ),
                                    if (d.status == 'BROUILLON')
                                      TextButton(
                                        onPressed: () =>
                                            widget.store.validateSalesDoc(d.id),
                                        child: const Text('Valider'),
                                      ),
                                    if (_nextConversionTarget != null)
                                      TextButton(
                                        onPressed: () =>
                                            widget.store.convertSalesDoc(
                                                d.id, _nextConversionTarget!),
                                        child: Text(_nextConversionLabel),
                                      ),
                                    if (widget.docType == 'FACTURE' &&
                                        d.remainingMru > 0)
                                      TextButton(
                                        onPressed: () => _openPayDialog(d),
                                        child: const Text('Encaisser'),
                                      ),
                                    IconButton(
                                      tooltip: 'Imprimer PDF A4',
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
}

class _DocKpi extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _DocKpi(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 215,
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

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color color = switch (status) {
      'PAYEE' || 'PAID' => CommercialColors.successGreen,
      'PARTIELLE' || 'PARTIAL' => CommercialColors.warningAmber,
      'VALIDEE' || 'VALIDATED' => CommercialColors.primaryBlue,
      'BROUILLON' || 'DRAFT' => CommercialColors.textMuted,
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

class _SumRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;
  const _SumRow(this.label, this.value, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: bold ? 13 : 12,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
          Text(value,
              style: TextStyle(
                  fontSize: bold ? 14 : 12,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }
}
