import 'package:flutter/material.dart';
import '../models/commercial_models.dart';
import '../state/commercial_store.dart';
import '../theme/commercial_theme.dart';

class ClientsView extends StatefulWidget {
  final CommercialStore store;
  const ClientsView({super.key, required this.store});

  @override
  State<ClientsView> createState() => _ClientsViewState();
}

class _ClientsViewState extends State<ClientsView> {
  String _query = '';
  bool _onlyKarni = false;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final filtered = store.clients.where((c) {
      if (_onlyKarni && c.karniDebtMru <= 0) return false;
      if (_query.trim().isEmpty) return true;
      final q = _query.toLowerCase();
      return c.name.toLowerCase().contains(q) ||
          c.code.toLowerCase().contains(q) ||
          c.nif.toLowerCase().contains(q) ||
          c.phone.toLowerCase().contains(q);
    }).toList();

    final totalKarni =
        store.clients.fold<double>(0, (s, c) => s + c.karniDebtMru);
    final b2bCount = store.clients.where((c) => c.isB2b).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderBar(
            title: 'Clients & Comptes Karni',
            subtitle: 'Répertoire B2B / Particuliers, NIF / RC, délais et encours Karni',
            actionLabel: 'Nouveau client',
            onAction: () => _openClientDialog(context),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _MiniStatCard(
                label: 'Total Clients',
                value: '${store.clients.length}',
                color: CommercialColors.primaryBlue,
                icon: Icons.people_outline,
              ),
              _MiniStatCard(
                label: 'Clients B2B (NIF)',
                value: '$b2bCount',
                color: CommercialColors.brandViolet,
                icon: Icons.business_outlined,
              ),
              _MiniStatCard(
                label: 'Encours Karni total',
                value: fmtMru(totalKarni),
                color: totalKarni > 0
                    ? CommercialColors.warningAmber
                    : CommercialColors.successGreen,
                icon: Icons.account_balance_wallet_outlined,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'Rechercher par nom, code, NIF ou tél...',
                            prefixIcon: Icon(Icons.search, size: 18),
                          ),
                          onChanged: (v) => setState(() => _query = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilterChip(
                        label: const Text('Avec solde Karni'),
                        selected: _onlyKarni,
                        onSelected: (v) => setState(() => _onlyKarni = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'Aucun client trouvé.',
                        style: TextStyle(color: CommercialColors.textMuted),
                      ),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                            const Color(0xFFF8FAFC)),
                        columns: const [
                          DataColumn(label: Text('Code')),
                          DataColumn(label: Text('Client')),
                          DataColumn(label: Text('Type')),
                          DataColumn(label: Text('NIF / RC')),
                          DataColumn(label: Text('Téléphone & Ville')),
                          DataColumn(label: Text('Délai'), numeric: true),
                          DataColumn(label: Text('Solde Karni'), numeric: true),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: filtered.map((c) {
                          return DataRow(
                            cells: [
                              DataCell(Text(c.code,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600))),
                              DataCell(Text(c.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600))),
                              DataCell(_Badge(
                                text: c.isB2b ? 'B2B' : 'Particulier',
                                color: c.isB2b
                                    ? CommercialColors.primaryBlue
                                    : CommercialColors.textMuted,
                              )),
                              DataCell(Text(
                                c.nif.isEmpty
                                    ? '—'
                                    : '${c.nif}${c.rc.isNotEmpty ? ' / ${c.rc}' : ''}',
                              )),
                              DataCell(Text(
                                  '${c.phone.isEmpty ? '—' : c.phone} • ${c.city}')),
                              DataCell(Text('${c.paymentTermsDays} j')),
                              DataCell(Text(
                                fmtMru(c.karniDebtMru),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: c.karniDebtMru > 0
                                      ? CommercialColors.dangerRed
                                      : CommercialColors.successGreen,
                                ),
                              )),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (c.karniDebtMru > 0)
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            _openKarniPayDialog(context, c),
                                        icon: const Icon(
                                            Icons.payments_outlined,
                                            size: 16),
                                        label: const Text('Encaisser'),
                                      ),
                                    IconButton(
                                      tooltip: 'Modifier fiche client',
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 18),
                                      onPressed: () => _openClientDialog(
                                          context,
                                          editing: c),
                                    ),
                                    IconButton(
                                      tooltip: 'Supprimer',
                                      icon: const Icon(Icons.delete_outline,
                                          size: 18,
                                          color: CommercialColors.dangerRed),
                                      onPressed: () =>
                                          widget.store.deleteClient(c.id),
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

  Future<void> _openClientDialog(BuildContext context,
      {CommercialClient? editing}) async {
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    final nifCtrl = TextEditingController(text: editing?.nif ?? '');
    final rcCtrl = TextEditingController(text: editing?.rc ?? '');
    final phoneCtrl = TextEditingController(text: editing?.phone ?? '');
    final addressCtrl = TextEditingController(text: editing?.address ?? '');
    final cityCtrl =
        TextEditingController(text: editing?.city ?? 'Nouakchott');
    final termsCtrl = TextEditingController(
        text: '${editing?.paymentTermsDays ?? 30}');
    final limitCtrl = TextEditingController(
        text: (editing?.creditLimitMru ?? 0).toStringAsFixed(0));
    bool isB2b = editing?.isB2b ?? true;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(editing == null
              ? 'Nouvelle fiche client'
              : 'Modifier client · ${editing.code}'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Identité & Fiscalité',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Raison sociale / Nom complet *'),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Client professionnel / B2B (Assujetti NIF)'),
                    value: isB2b,
                    onChanged: (v) => setS(() => isB2b = v),
                  ),
                  if (isB2b) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: nifCtrl,
                            decoration: const InputDecoration(
                                labelText: 'NIF (Numéro d\'Identification Fiscale)'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: rcCtrl,
                            decoration: const InputDecoration(
                                labelText: 'RC (Registre de Commerce)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  const Text('Coordonnées',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: phoneCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Téléphone / WhatsApp'),
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
                    controller: addressCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Adresse / Quartier (ex: Tevragh Zeina)'),
                  ),
                  const SizedBox(height: 12),
                  const Text('Conditions commerciales & Karni',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: termsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Délai de paiement (jours)'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: limitCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Plafond crédit Karni (MRU)'),
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
                child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                final String? err;
                if (editing == null) {
                  err = await widget.store.createClient(
                    name: nameCtrl.text,
                    isB2b: isB2b,
                    nif: nifCtrl.text,
                    rc: rcCtrl.text,
                    phone: phoneCtrl.text,
                    address: addressCtrl.text,
                    city: cityCtrl.text,
                    creditLimitMru: double.tryParse(limitCtrl.text) ?? 0,
                  );
                } else {
                  err = await widget.store.updateClient(
                    editing.id,
                    name: nameCtrl.text,
                    isB2b: isB2b,
                    nif: nifCtrl.text,
                    rc: rcCtrl.text,
                    phone: phoneCtrl.text,
                    address: addressCtrl.text,
                    city: cityCtrl.text,
                    paymentTermsDays: int.tryParse(termsCtrl.text) ?? 30,
                    creditLimitMru: double.tryParse(limitCtrl.text) ?? 0,
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
              child: Text(editing == null ? 'Créer le client' : 'Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openKarniPayDialog(
      BuildContext context, CommercialClient c) async {
    final amountCtrl =
        TextEditingController(text: c.karniDebtMru.toStringAsFixed(0));
    String method = 'Cash';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('Encaissement Karni — ${c.name}'),
          content: SizedBox(
            width: 380,
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
                      const InputDecoration(labelText: 'Mode de paiement'),
                  items: const [
                    'Cash',
                    'Bankily',
                    'Masrivi',
                    'Sedad',
                    'Bimbank',
                    'Click',
                    'Virement',
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
                final amount = double.tryParse(amountCtrl.text) ?? 0;
                final err =
                    await widget.store.karniPayClient(c.id, amount, method);
                if (!ctx.mounted) return;
                if (err != null) {
                  ScaffoldMessenger.of(ctx)
                      .showSnackBar(SnackBar(content: Text(err)));
                } else {
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Valider encaissement'),
            ),
          ],
        ),
      ),
    );
  }
}

class ArticlesView extends StatefulWidget {
  final CommercialStore store;
  const ArticlesView({super.key, required this.store});

  @override
  State<ArticlesView> createState() => _ArticlesViewState();
}

class _ArticlesViewState extends State<ArticlesView> {
  String _query = '';
  bool _lowStockOnly = false;
  bool _showMovements = false;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final filtered = store.articles.where((a) {
      if (_lowStockOnly && !a.isLowStock) return false;
      if (_query.trim().isEmpty) return true;
      final q = _query.toLowerCase();
      return a.name.toLowerCase().contains(q) ||
          a.sku.toLowerCase().contains(q) ||
          a.barcode.toLowerCase().contains(q) ||
          a.category.toLowerCase().contains(q);
    }).toList();

    final totalStockVal =
        store.articles.fold<double>(0, (s, a) => s + a.stockValuePmpMru);
    final lowCount = store.articles.where((a) => a.isLowStock).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderBar(
            title: 'Catalogue Articles & Stock PMP',
            subtitle:
                'Tarifs Détail / Gros, TVA 16% ou Exonéré, suivi du stock, PMP & journal mouvements',
            actionLabel: 'Nouvel article',
            onAction: () => _openArticleDialog(context),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _MiniStatCard(
                label: 'Références',
                value: '${store.articles.length}',
                color: CommercialColors.primaryBlue,
                icon: Icons.inventory_2_outlined,
              ),
              _MiniStatCard(
                label: 'Valeur stock (PMP)',
                value: fmtMru(totalStockVal),
                color: CommercialColors.successGreen,
                icon: Icons.warehouse_outlined,
              ),
              _MiniStatCard(
                label: 'Alertes stock bas',
                value: '$lowCount',
                color: lowCount > 0
                    ? CommercialColors.dangerRed
                    : CommercialColors.successGreen,
                icon: Icons.warning_amber_outlined,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Catalogue Articles')),
                  ButtonSegment(
                      value: true, label: Text('Journal Mouvements Stock')),
                ],
                selected: {_showMovements},
                onSelectionChanged: (s) =>
                    setState(() => _showMovements = s.first),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_showMovements)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: store.stockMovements.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: Center(
                          child: Text('Aucun mouvement de stock enregistré.',
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
                            DataColumn(label: Text('SKU / Article')),
                            DataColumn(label: Text('Type')),
                            DataColumn(label: Text('Variation'), numeric: true),
                            DataColumn(label: Text('Stock après'), numeric: true),
                            DataColumn(label: Text('PMP après'), numeric: true),
                            DataColumn(label: Text('Motif / Source')),
                          ],
                          rows: store.stockMovements.map((m) {
                            return DataRow(cells: [
                              DataCell(Text(m.createdAt)),
                              DataCell(Text('${m.sku} · ${m.articleName}')),
                              DataCell(Text(m.movementType)),
                              DataCell(Text(
                                '${m.qtyDelta > 0 ? '+' : ''}${m.qtyDelta.toStringAsFixed(1)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: m.qtyDelta >= 0
                                      ? CommercialColors.successGreen
                                      : CommercialColors.dangerRed,
                                ),
                              )),
                              DataCell(Text(m.stockAfter.toStringAsFixed(1))),
                              DataCell(Text(fmtMru(m.pmpAfterMru))),
                              DataCell(Text(m.reason.isNotEmpty
                                  ? m.reason
                                  : m.sourceNumber)),
                            ]);
                          }).toList(),
                        ),
                      ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              hintText:
                                  'Rechercher par SKU, code-barres, désignation ou famille...',
                              prefixIcon: Icon(Icons.search, size: 18),
                            ),
                            onChanged: (v) => setState(() => _query = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilterChip(
                          label: const Text('Stock bas uniquement'),
                          selected: _lowStockOnly,
                          onSelected: (v) => setState(() => _lowStockOnly = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (filtered.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          'Aucun article trouvé.',
                          style: TextStyle(color: CommercialColors.textMuted),
                        ),
                      )
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                              const Color(0xFFF8FAFC)),
                          columns: const [
                            DataColumn(label: Text('SKU')),
                            DataColumn(label: Text('Désignation')),
                            DataColumn(label: Text('Famille')),
                            DataColumn(label: Text('TVA')),
                            DataColumn(label: Text('Détail HT'), numeric: true),
                            DataColumn(label: Text('Gros HT'), numeric: true),
                            DataColumn(label: Text('PMP'), numeric: true),
                            DataColumn(label: Text('Stock'), numeric: true),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: filtered.map((a) {
                            return DataRow(
                              cells: [
                                DataCell(Text(a.sku,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600))),
                                DataCell(Text(a.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600))),
                                DataCell(Text(a.category)),
                                DataCell(_Badge(
                                  text: a.isExempt ? 'Exonéré' : '16%',
                                  color: a.isExempt
                                      ? CommercialColors.textMuted
                                      : CommercialColors.primaryBlue,
                                )),
                                DataCell(Text(fmtMru(a.priceRetailHt))),
                                DataCell(Text(fmtMru(a.priceWholeHt))),
                                DataCell(Text(fmtMru(a.pmpCostMru))),
                                DataCell(Text(
                                  '${a.stockQty.toStringAsFixed(1)} ${a.unit}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: a.isLowStock
                                        ? CommercialColors.dangerRed
                                        : CommercialColors.textPrimary,
                                  ),
                                )),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            _openAdjustStockDialog(context, a),
                                        icon: const Icon(Icons.tune, size: 16),
                                        label: const Text('Stock'),
                                      ),
                                      IconButton(
                                        tooltip: 'Modifier article',
                                        icon: const Icon(Icons.edit_outlined,
                                            size: 18),
                                        onPressed: () => _openArticleDialog(
                                            context,
                                            editing: a),
                                      ),
                                      IconButton(
                                        tooltip: 'Supprimer',
                                        icon: const Icon(Icons.delete_outline,
                                            size: 18,
                                            color: CommercialColors.dangerRed),
                                        onPressed: () =>
                                            widget.store.deleteArticle(a.id),
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

  Future<void> _openArticleDialog(BuildContext context,
      {CommercialArticle? editing}) async {
    final skuCtrl = TextEditingController(text: editing?.sku ?? '');
    final barcodeCtrl = TextEditingController(text: editing?.barcode ?? '');
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    final catCtrl = TextEditingController(text: editing?.category ?? 'Général');
    final unitCtrl = TextEditingController(text: editing?.unit ?? 'unité');
    final retailCtrl = TextEditingController(
        text: editing != null ? editing.priceRetailHt.toStringAsFixed(0) : '');
    final wholeCtrl = TextEditingController(
        text: editing != null ? editing.priceWholeHt.toStringAsFixed(0) : '');
    final costCtrl = TextEditingController(
        text: editing != null ? editing.pmpCostMru.toStringAsFixed(0) : '');
    final stockCtrl = TextEditingController(
        text: editing != null ? editing.stockQty.toStringAsFixed(0) : '0');
    final minCtrl = TextEditingController(
        text: editing != null ? editing.minStock.toStringAsFixed(0) : '5');
    bool isExempt = editing?.isExempt ?? false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final rHt = double.tryParse(retailCtrl.text) ?? 0;
          final cPmp = double.tryParse(costCtrl.text) ?? 0;
          final rTtc = isExempt ? rHt : rHt * 1.16;
          final marginPct =
              CommercialMath.computeMarginPct(caHt: rHt, costMru: cPmp);

          return AlertDialog(
            title: Text(editing == null
                ? 'Nouvelle fiche article'
                : 'Modifier article · ${editing.sku}'),
            content: SizedBox(
              width: 580,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Identification',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: skuCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Réf. SKU *'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: barcodeCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Code-barres EAN-13'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Désignation complète *'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: catCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Famille'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: unitCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Unité (pièce, sac, kg, carton)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text('Tarification & TVA Mauritanie',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: retailCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Prix Détail HT *'),
                            onChanged: (_) => setS(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: wholeCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Prix Gros HT'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: costCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Coût d\'achat / PMP'),
                            onChanged: (_) => setS(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: CommercialColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Prix public TTC : ${fmtMru(rTtc)}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            'Marge brute Détail : ${marginPct.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: marginPct > 0
                                  ? CommercialColors.successGreen
                                  : CommercialColors.dangerRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Article exonéré de TVA (0%)'),
                      subtitle:
                          const Text('Sinon TVA standard Mauritanie 16%'),
                      value: isExempt,
                      onChanged: (v) => setS(() => isExempt = v),
                    ),
                    const SizedBox(height: 6),
                    const Text('Gestion de stock',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (editing == null) ...[
                          Expanded(
                            child: TextField(
                              controller: stockCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'Stock initial'),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: TextField(
                            controller: minCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Seuil d\'alerte stock bas'),
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
                  child: const Text('Annuler')),
              ElevatedButton(
                onPressed: () async {
                  final String? err;
                  if (editing == null) {
                    err = await widget.store.createArticle(
                      sku: skuCtrl.text,
                      name: nameCtrl.text,
                      category: catCtrl.text,
                      unit: unitCtrl.text,
                      priceRetailHt: double.tryParse(retailCtrl.text) ?? 0,
                      priceWholeHt: double.tryParse(wholeCtrl.text) ?? 0,
                      priceCostMru: double.tryParse(costCtrl.text) ?? 0,
                      stockQty: double.tryParse(stockCtrl.text) ?? 0,
                      minStock: double.tryParse(minCtrl.text) ?? 0,
                      isExempt: isExempt,
                    );
                  } else {
                    err = await widget.store.updateArticle(
                      editing.id,
                      sku: skuCtrl.text,
                      barcode: barcodeCtrl.text,
                      name: nameCtrl.text,
                      category: catCtrl.text,
                      unit: unitCtrl.text,
                      priceRetailHt: double.tryParse(retailCtrl.text) ?? 0,
                      priceWholeHt: double.tryParse(wholeCtrl.text) ?? 0,
                      priceCostMru: double.tryParse(costCtrl.text) ?? 0,
                      minStock: double.tryParse(minCtrl.text) ?? 0,
                      isExempt: isExempt,
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
                child:
                    Text(editing == null ? 'Créer l\'article' : 'Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openAdjustStockDialog(
      BuildContext context, CommercialArticle a) async {
    final deltaCtrl = TextEditingController(text: '0');
    final reasonCtrl = TextEditingController(text: 'Inventaire physique');

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Ajuster stock — ${a.name}'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Stock actuel : ${a.stockQty.toStringAsFixed(1)} ${a.unit} • PMP : ${fmtMru(a.pmpCostMru)}',
                style: const TextStyle(color: CommercialColors.textMuted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: deltaCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(signed: true),
                decoration: const InputDecoration(
                    labelText: 'Variation (+/- quantité)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(labelText: 'Motif'),
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
              final delta = double.tryParse(deltaCtrl.text) ?? 0;
              final err = await widget.store
                  .adjustArticleStock(a.id, delta, reasonCtrl.text);
              if (!ctx.mounted) return;
              if (err != null) {
                ScaffoldMessenger.of(ctx)
                    .showSnackBar(SnackBar(content: Text(err)));
              } else {
                Navigator.pop(ctx);
              }
            },
            child: const Text('Appliquer'),
          ),
        ],
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const _HeaderBar({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 13, color: CommercialColors.textMuted)),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: onAction,
          icon: const Icon(Icons.add, size: 18),
          label: Text(actionLabel),
        ),
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 12, color: CommercialColors.textMuted)),
                    const SizedBox(height: 2),
                    Text(value,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
