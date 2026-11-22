import 'package:flutter/material.dart';
import '../models/commercial_models.dart';
import '../state/commercial_store.dart';
import '../theme/commercial_theme.dart';

class _PosCartLine {
  final CommercialArticle article;
  double qty;
  double discountPct = 0;
  _PosCartLine({required this.article, this.qty = 1});
}

class PosRegisterView extends StatefulWidget {
  final CommercialStore store;
  const PosRegisterView({super.key, required this.store});

  @override
  State<PosRegisterView> createState() => _PosRegisterViewState();
}

class _PosRegisterViewState extends State<PosRegisterView> {
  final _scanCtrl = TextEditingController();
  String _query = '';
  String _category = 'ALL';
  String _priceTier = 'retail';
  int? _selectedClientId;
  final List<_PosCartLine> _cart = [];

  @override
  void dispose() {
    _scanCtrl.dispose();
    super.dispose();
  }

  double _unitHt(CommercialArticle a) =>
      _priceTier == 'wholesale' ? a.priceWholeHt : a.priceRetailHt;

  double _unitTtc(CommercialArticle a) {
    final ht = _unitHt(a);
    return a.isExempt ? ht : ht * (1 + a.tvaRate / 100);
  }

  double get _totalHt => _cart.fold<double>(
      0,
      (s, l) =>
          s +
          CommercialMath.computeLineHt(
              qty: l.qty,
              unitPriceHt: _unitHt(l.article),
              discountPct: l.discountPct));

  double get _totalTtc => _cart.fold<double>(0, (s, l) {
        final lHt = CommercialMath.computeLineHt(
            qty: l.qty,
            unitPriceHt: _unitHt(l.article),
            discountPct: l.discountPct);
        final lTva = CommercialMath.computeLineTva(
            lineHt: lHt,
            isExempt: l.article.isExempt,
            tvaRate: l.article.tvaRate);
        return s + lHt + lTva;
      });

  double get _totalTva => _totalTtc - _totalHt;

  void _addArticle(CommercialArticle a) {
    setState(() {
      final idx = _cart.indexWhere((c) => c.article.id == a.id);
      if (idx >= 0) {
        _cart[idx].qty += 1;
      } else {
        _cart.add(_PosCartLine(article: a, qty: 1));
      }
    });
  }

  void _handleBarcodeSubmit(String raw) {
    final code = raw.trim().toLowerCase();
    if (code.isEmpty) return;
    final found = widget.store.articles.where((a) =>
        a.barcode.toLowerCase() == code || a.sku.toLowerCase() == code);
    if (found.isNotEmpty) {
      _addArticle(found.first);
      _scanCtrl.clear();
      setState(() => _query = '');
    }
  }

  Future<void> _openSplitCheckoutDialog(BuildContext context) async {
    final totalDue = _totalTtc;
    final tenders = <Map<String, dynamic>>[
      {'payMethod': 'Cash', 'amountMru': totalDue},
    ];
    final amountCtrl = TextEditingController(text: totalDue.toStringAsFixed(0));
    String nextMethod = 'Bankily';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final paid = tenders.fold<double>(
              0, (s, t) => s + ((t['amountMru'] as num?)?.toDouble() ?? 0));
          final remaining = (totalDue - paid).clamp(0.0, double.infinity);
          final change = (paid - totalDue).clamp(0.0, double.infinity);

          return AlertDialog(
            title: const Text('Encaissement Multi-Modes (Split Payment)'),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: CommercialColors.border),
                    ),
                    child: Column(
                      children: [
                        _TotalRow('Net à payer TTC', totalDue, bold: true),
                        _TotalRow('Total reçu', paid),
                        if (remaining > 0)
                          _TotalRow('Reste à encaisser', remaining),
                        if (change > 0)
                          _TotalRow('Monnaie à rendre', change, bold: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Règlements saisis :',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  const SizedBox(height: 6),
                  ...List.generate(tenders.length, (i) {
                    final t = tenders[i];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('${t['payMethod']}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(fmtMru((t['amountMru'] as num).toDouble()),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          IconButton(
                            icon: const Icon(Icons.close,
                                size: 16, color: CommercialColors.dangerRed),
                            onPressed: () => setS(() => tenders.removeAt(i)),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: nextMethod,
                          decoration:
                              const InputDecoration(labelText: 'Mode'),
                          items: const [
                            'Cash',
                            'Bankily',
                            'Masrivi',
                            'Sedad',
                            'Bimbank',
                            'Click',
                            'Karni',
                          ]
                              .map((m) =>
                                  DropdownMenuItem(value: m, child: Text(m)))
                              .toList(),
                          onChanged: (v) =>
                              setS(() => nextMethod = v ?? 'Cash'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: amountCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Montant MRU'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () {
                          final val = double.tryParse(amountCtrl.text) ?? 0;
                          if (val <= 0) return;
                          setS(() {
                            tenders.add(
                                {'payMethod': nextMethod, 'amountMru': val});
                            final newPaid = tenders.fold<double>(
                                0,
                                (s, t) =>
                                    s +
                                    ((t['amountMru'] as num?)?.toDouble() ?? 0));
                            final rem =
                                (totalDue - newPaid).clamp(0.0, double.infinity);
                            amountCtrl.text = rem.toStringAsFixed(0);
                          });
                        },
                        child: const Text('+ Ajouter'),
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
              ElevatedButton.icon(
                onPressed: paid < totalDue - 0.5 || tenders.isEmpty
                    ? null
                    : () async {
                        if (tenders.any((t) => t['payMethod'] == 'Karni') &&
                            _selectedClientId == null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                              content: Text(
                                  'Sélectionnez un client pour encaisser en Karni.')));
                          return;
                        }
                        final err = await widget.store.submitPosTicket(
                          priceTier: _priceTier,
                          clientId: _selectedClientId,
                          lines: _cart
                              .map((l) => {
                                    'articleId': l.article.id,
                                    'qty': l.qty,
                                    'discountPct': l.discountPct,
                                  })
                              .toList(),
                          payments: tenders,
                        );
                        if (!ctx.mounted) return;
                        if (err != null) {
                          ScaffoldMessenger.of(ctx)
                              .showSnackBar(SnackBar(content: Text(err)));
                        } else {
                          Navigator.pop(ctx);
                          setState(() => _cart.clear());
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(change > 0
                                ? 'Ticket encaissé ! Monnaie à rendre : ${fmtMru(change)}'
                                : 'Ticket encaissé avec succès !'),
                          ));
                        }
                      },
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Valider le ticket'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final session = store.openPosSession;
    final categories = <String>{
      'ALL',
      ...store.articles.map((a) => a.category),
    }.toList();

    final articles = store.articles.where((a) {
      if (_category != 'ALL' && a.category != _category) return false;
      if (_query.trim().isEmpty) return true;
      final q = _query.toLowerCase();
      return a.name.toLowerCase().contains(q) ||
          a.sku.toLowerCase().contains(q) ||
          a.barcode.toLowerCase().contains(q);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    session != null ? Icons.point_of_sale : Icons.lock_outline,
                    color: session != null
                        ? CommercialColors.successGreen
                        : CommercialColors.warningAmber,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: session == null
                        ? const Text(
                            'Aucune session de caisse ouverte. Ouvrez une caisse pour encaisser.',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          )
                        : Text(
                            'Session ${session.sessionNumber} (${session.registerCode}) • Caissier : ${session.cashierName} • Tickets : ${session.ticketsCount} • CA : ${fmtMru(session.totalSalesTtcMru)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                  ),
                  if (session == null)
                    ElevatedButton.icon(
                      onPressed: () => _openSessionDialog(context),
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('Ouvrir la caisse'),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () => _closeSessionDialog(context, session),
                      icon: const Icon(Icons.lock_clock, size: 18),
                      label: const Text('Clôturer (Rapport Z)'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _scanCtrl,
                                  decoration: const InputDecoration(
                                    hintText:
                                        'Scanner EAN-13 / SKU (Entrée) ou rechercher...',
                                    prefixIcon:
                                        Icon(Icons.qr_code_scanner, size: 18),
                                  ),
                                  onChanged: (v) => setState(() => _query = v),
                                  onSubmitted: _handleBarcodeSubmit,
                                ),
                              ),
                              const SizedBox(width: 10),
                              SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(
                                      value: 'retail', label: Text('Détail')),
                                  ButtonSegment(
                                      value: 'wholesale', label: Text('Gros')),
                                ],
                                selected: {_priceTier},
                                onSelectionChanged: (s) =>
                                    setState(() => _priceTier = s.first),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: categories.map((cat) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ChoiceChip(
                                    label: Text(cat == 'ALL' ? 'Toutes' : cat),
                                    selected: _category == cat,
                                    onSelected: (_) =>
                                        setState(() => _category = cat),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 210,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: 1.35,
                              ),
                              itemCount: articles.length,
                              itemBuilder: (ctx, i) {
                                final a = articles[i];
                                return InkWell(
                                  onTap: () => _addArticle(a),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: CommercialColors.border),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          a.sku,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color:
                                                  CommercialColors.textMuted),
                                        ),
                                        Text(
                                          a.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13),
                                        ),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${_unitTtc(a).toStringAsFixed(0)} MRU',
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: CommercialColors
                                                        .primaryBlue),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Stk ${a.stockQty.toStringAsFixed(0)}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: a.isLowStock
                                                    ? CommercialColors.dangerRed
                                                    : CommercialColors
                                                        .textMuted,
                                              ),
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
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Ticket en cours',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700)),
                              if (_cart.isNotEmpty)
                                TextButton(
                                  onPressed: () =>
                                      setState(() => _cart.clear()),
                                  child: const Text('Vider',
                                      style: TextStyle(
                                          color: CommercialColors.dangerRed)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int?>(
                            initialValue: _selectedClientId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                                labelText: 'Client (optionnel sauf Karni)'),
                            items: [
                              const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('Client comptoir',
                                      overflow: TextOverflow.ellipsis)),
                              ...store.clients.map((c) =>
                                  DropdownMenuItem<int?>(
                                      value: c.id,
                                      child: Text(c.name,
                                          overflow: TextOverflow.ellipsis))),
                            ],
                            onChanged: (v) =>
                                setState(() => _selectedClientId = v),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: _cart.isEmpty
                                ? const Center(
                                    child: Text(
                                      'Panier vide — scannez ou cliquez un article.',
                                      style: TextStyle(
                                          color: CommercialColors.textMuted),
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: _cart.length,
                                    separatorBuilder: (_, _) =>
                                        const Divider(height: 1),
                                    itemBuilder: (ctx, i) {
                                      final line = _cart[i];
                                      return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(line.article.name,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600)),
                                        subtitle: Text(
                                            '${_unitTtc(line.article).toStringAsFixed(0)} MRU TTC'),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.remove_circle_outline,
                                                  size: 18),
                                              onPressed: () => setState(() {
                                                if (line.qty > 1) {
                                                  line.qty -= 1;
                                                } else {
                                                  _cart.removeAt(i);
                                                }
                                              }),
                                            ),
                                            Text(line.qty.toStringAsFixed(0),
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w700)),
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.add_circle_outline,
                                                  size: 18),
                                              onPressed: () => setState(
                                                  () => line.qty += 1),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          const Divider(),
                          _TotalRow('Total HT', _totalHt),
                          _TotalRow('TVA (16% / Exonéré)', _totalTva),
                          _TotalRow('Net à payer TTC', _totalTtc, bold: true),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: session == null || _cart.isEmpty
                                ? null
                                : () => _openSplitCheckoutDialog(context),
                            icon: const Icon(Icons.payments_outlined),
                            label: Text(
                                'Encaisser ${fmtMru(_totalTtc)} (Multi-modes)'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSessionDialog(BuildContext context) async {
    final regCtrl = TextEditingController(text: 'CAISSE-01');
    final cashierCtrl = TextEditingController(
      text: widget.store.tenant.manager.isEmpty
          ? 'Caissier'
          : widget.store.tenant.manager,
    );
    final floatCtrl = TextEditingController(text: '5000');

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ouvrir une session de caisse'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: regCtrl,
                  decoration: const InputDecoration(labelText: 'Poste / Caisse')),
              const SizedBox(height: 10),
              TextField(
                  controller: cashierCtrl,
                  decoration: const InputDecoration(labelText: 'Caissier')),
              const SizedBox(height: 10),
              TextField(
                controller: floatCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Fond de caisse (MRU)'),
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
              final err = await widget.store.openNewPosSession(
                registerCode: regCtrl.text,
                cashierName: cashierCtrl.text,
                openingFloatMru: double.tryParse(floatCtrl.text) ?? 0,
              );
              if (!ctx.mounted) return;
              if (err != null) {
                ScaffoldMessenger.of(ctx)
                    .showSnackBar(SnackBar(content: Text(err)));
              } else {
                Navigator.pop(ctx);
              }
            },
            child: const Text('Ouvrir'),
          ),
        ],
      ),
    );
  }

  Future<void> _closeSessionDialog(
      BuildContext context, CommercialPosSession session) async {
    final countedCtrl = TextEditingController(
      text: session.expectedCashMru.toStringAsFixed(0),
    );
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final counted = double.tryParse(countedCtrl.text) ?? 0;
          final variance = counted - session.expectedCashMru;
          return AlertDialog(
            title: Text('Clôturer ${session.sessionNumber} · Rapport Z'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TotalRow('Fond d\'ouverture', session.openingFloatMru),
                  _TotalRow('Total ventes TTC', session.totalSalesTtcMru),
                  _TotalRow('Espèces attendues tiroir', session.expectedCashMru,
                      bold: true),
                  const SizedBox(height: 12),
                  TextField(
                    controller: countedCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Espèces comptées en tiroir (MRU)'),
                    onChanged: (_) => setS(() {}),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Écart de caisse : ${variance >= 0 ? '+' : ''}${fmtMru(variance)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: variance.abs() < 1
                          ? CommercialColors.successGreen
                          : CommercialColors.dangerRed,
                    ),
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
                  final err = await widget.store
                      .closePosSession(session.id, counted);
                  if (!ctx.mounted) return;
                  if (err != null) {
                    ScaffoldMessenger.of(ctx)
                        .showSnackBar(SnackBar(content: Text(err)));
                  } else {
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Valider Clôture Z'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class PosSessionsView extends StatelessWidget {
  final CommercialStore store;
  const PosSessionsView({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sessions de caisse & Rapports Z',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: store.posSessions.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text('Aucune session enregistrée.',
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
                          DataColumn(label: Text('Session')),
                          DataColumn(label: Text('Poste')),
                          DataColumn(label: Text('Caissier')),
                          DataColumn(label: Text('Statut')),
                          DataColumn(label: Text('Fond'), numeric: true),
                          DataColumn(label: Text('CA TTC'), numeric: true),
                          DataColumn(label: Text('Tickets'), numeric: true),
                        ],
                        rows: store.posSessions.map((s) {
                          return DataRow(
                            cells: [
                              DataCell(Text(s.sessionNumber,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600))),
                              DataCell(Text(s.registerCode)),
                              DataCell(Text(s.cashierName)),
                              DataCell(Text(s.status,
                                  style: TextStyle(
                                      color: s.status == 'OPEN'
                                          ? CommercialColors.successGreen
                                          : CommercialColors.textMuted,
                                      fontWeight: FontWeight.w600))),
                              DataCell(Text(fmtMru(s.openingFloatMru))),
                              DataCell(Text(fmtMru(s.totalSalesTtcMru))),
                              DataCell(Text('${s.ticketsCount}')),
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
}

class PosTicketsView extends StatelessWidget {
  final CommercialStore store;
  const PosTicketsView({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tickets de caisse',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: store.posTickets.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text('Aucun ticket de caisse.',
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
                          DataColumn(label: Text('Ticket')),
                          DataColumn(label: Text('Client')),
                          DataColumn(label: Text('Paiement')),
                          DataColumn(label: Text('Total TTC'), numeric: true),
                          DataColumn(label: Text('Statut')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: store.posTickets.map((t) {
                          return DataRow(
                            cells: [
                              DataCell(Text(t.ticketNumber,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600))),
                              DataCell(Text(t.customerName.isEmpty
                                  ? 'Comptoir'
                                  : t.customerName)),
                              DataCell(Text(t.payMethod)),
                              DataCell(Text(fmtMru(t.totalTtcMru))),
                              DataCell(Text(t.status,
                                  style: TextStyle(
                                      color: t.status == 'VOID'
                                          ? CommercialColors.dangerRed
                                          : CommercialColors.successGreen,
                                      fontWeight: FontWeight.w600))),
                              DataCell(
                                TextButton(
                                  onPressed: t.status == 'VOID'
                                      ? null
                                      : () => store.voidPosTicket(
                                          t.id, 'Annulation caisse'),
                                  child: const Text('Annuler (Void)'),
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
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool bold;
  const _TotalRow(this.label, this.amount, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                  fontSize: bold ? 15 : 13)),
          Text(fmtMru(amount),
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                  fontSize: bold ? 16 : 13,
                  color: bold ? CommercialColors.primaryBlue : null)),
        ],
      ),
    );
  }
}
