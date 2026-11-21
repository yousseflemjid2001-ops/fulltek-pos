import 'package:flutter/material.dart';
import '../models/commercial_models.dart';
import '../state/commercial_store.dart';
import '../theme/commercial_theme.dart';

class _PosCartLine {
  final CommercialArticle article;
  double qty;
  _PosCartLine({required this.article, this.qty = 1});
}

class PosRegisterView extends StatefulWidget {
  final CommercialStore store;
  const PosRegisterView({super.key, required this.store});

  @override
  State<PosRegisterView> createState() => _PosRegisterViewState();
}

class _PosRegisterViewState extends State<PosRegisterView> {
  String _query = '';
  String _priceTier = 'retail';
  String _payMethod = 'Cash';
  int? _selectedClientId;
  final List<_PosCartLine> _cart = [];

  double _unitHt(CommercialArticle a) =>
      _priceTier == 'wholesale' ? a.priceWholeHt : a.priceRetailHt;

  double _unitTtc(CommercialArticle a) {
    final ht = _unitHt(a);
    return a.isExempt ? ht : ht * (1 + a.tvaRate / 100);
  }

  double get _totalHt =>
      _cart.fold<double>(0, (s, l) => s + _unitHt(l.article) * l.qty);
  double get _totalTtc =>
      _cart.fold<double>(0, (s, l) => s + _unitTtc(l.article) * l.qty);
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

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final session = store.openPosSession;
    final articles = store.articles.where((a) {
      if (_query.trim().isEmpty) return true;
      final q = _query.toLowerCase();
      return a.name.toLowerCase().contains(q) ||
          a.sku.toLowerCase().contains(q);
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
                            'Session ${session.sessionNumber} (${session.registerCode}) • Caissier : ${session.cashierName} • Fond : ${session.openingFloatMru.toStringAsFixed(0)} MRU',
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
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(
                                    hintText: 'Scanner ou rechercher un article...',
                                    prefixIcon: Icon(Icons.search, size: 18),
                                  ),
                                  onChanged: (v) => setState(() => _query = v),
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
                          const SizedBox(height: 12),
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
                          const Text('Ticket en cours',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 10),
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
                                      'Panier vide — sélectionnez un article.',
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
                          _TotalRow('TVA (16%)', _totalTva),
                          _TotalRow('Net à payer TTC', _totalTtc, bold: true),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: _payMethod,
                            decoration: const InputDecoration(
                                labelText: 'Mode de paiement'),
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
                                setState(() => _payMethod = v ?? 'Cash'),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: session == null || _cart.isEmpty
                                ? null
                                : () async {
                                    final err =
                                        await widget.store.submitPosTicket(
                                      priceTier: _priceTier,
                                      clientId: _selectedClientId,
                                      lines: _cart
                                          .map((l) => {
                                                'articleId': l.article.id,
                                                'qty': l.qty,
                                              })
                                          .toList(),
                                      payments: [
                                        {
                                          'payMethod': _payMethod,
                                          'amountMru': _totalTtc,
                                        }
                                      ],
                                    );
                                    if (!context.mounted) return;
                                    if (err != null) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                              SnackBar(content: Text(err)));
                                    } else {
                                      setState(() => _cart.clear());
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content:
                                                  Text('Ticket encaissé !')));
                                    }
                                  },
                            icon: const Icon(Icons.check_circle_outline),
                            label: Text(
                                'Encaisser ${_totalTtc.toStringAsFixed(0)} MRU'),
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
      builder: (ctx) => AlertDialog(
        title: Text('Clôturer ${session.sessionNumber} (Rapport Z)'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'Espèces théoriques attendues : ${session.expectedCashMru.toStringAsFixed(0)} MRU'),
              const SizedBox(height: 10),
              TextField(
                controller: countedCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Montant compté en tiroir (MRU)'),
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
              final err = await widget.store.closePosSession(
                  session.id, double.tryParse(countedCtrl.text) ?? 0);
              if (!ctx.mounted) return;
              if (err != null) {
                ScaffoldMessenger.of(ctx)
                    .showSnackBar(SnackBar(content: Text(err)));
              } else {
                Navigator.pop(ctx);
              }
            },
            child: const Text('Clôturer Z'),
          ),
        ],
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
                              DataCell(Text(
                                  '${s.openingFloatMru.toStringAsFixed(0)} MRU')),
                              DataCell(Text(
                                  '${s.totalSalesTtcMru.toStringAsFixed(0)} MRU')),
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
                              DataCell(Text(
                                  '${t.totalTtcMru.toStringAsFixed(0)} MRU')),
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
          Text('${amount.toStringAsFixed(0)} MRU',
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                  fontSize: bold ? 16 : 13,
                  color: bold ? CommercialColors.primaryBlue : null)),
        ],
      ),
    );
  }
}
