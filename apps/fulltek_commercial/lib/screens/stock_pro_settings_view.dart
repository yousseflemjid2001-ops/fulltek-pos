import 'package:flutter/material.dart';
import '../models/commercial_models.dart';
import '../state/commercial_store.dart';
import '../theme/commercial_theme.dart';

class WarehousesInventoryView extends StatefulWidget {
  final CommercialStore store;
  const WarehousesInventoryView({super.key, required this.store});

  @override
  State<WarehousesInventoryView> createState() =>
      _WarehousesInventoryViewState();
}

class _WarehousesInventoryViewState extends State<WarehousesInventoryView> {
  int _tab = 0; // 0: Dépôts & Transferts, 1: Inventaire Physique, 2: Import/Export CSV
  final Map<int, TextEditingController> _invCtrls = {};
  final _csvCtrl = TextEditingController(
    text:
        'SKU;Designation;Famille;Unite;PrixDetailHT;PrixGrosHT;CoutPMP;Stock;StockMin;ExonereTVA\n'
        'IMP-01;Huile Végétale 5L;Alimentation;bidon;850;780;650;40;10;1\n'
        'IMP-02;Imprimante Thermique 80mm;Informatique;unité;6500;5800;4200;8;2;0',
  );

  @override
  void dispose() {
    for (final c in _invCtrls.values) {
      c.dispose();
    }
    _csvCtrl.dispose();
    super.dispose();
  }

  TextEditingController _ctrlFor(CommercialArticle a) {
    return _invCtrls.putIfAbsent(
      a.id,
      () => TextEditingController(text: a.stockQty.toStringAsFixed(0)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Multi-Dépôts, Inventaire Physique & Import Excel',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Dépôts & Transferts')),
              ButtonSegment(value: 1, label: Text('Inventaire Physique')),
              ButtonSegment(value: 2, label: Text('Import / Export CSV')),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
          const SizedBox(height: 16),
          if (_tab == 0) _buildWarehousesTab(context, store),
          if (_tab == 1) _buildInventoryTab(context, store),
          if (_tab == 2) _buildCsvTab(context, store),
        ],
      ),
    );
  }

  Widget _buildWarehousesTab(BuildContext context, CommercialStore store) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () => _openCreateWarehouseDialog(context),
              icon: const Icon(Icons.add_business_outlined, size: 18),
              label: const Text('Nouveau dépôt / magasin'),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: store.warehouses.length < 2 || store.articles.isEmpty
                  ? null
                  : () => _openTransferDialog(context),
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: const Text('Bon de transfert'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: store.warehouses.map((w) {
            return SizedBox(
              width: 260,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(w.code,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: CommercialColors.primaryBlue)),
                      const SizedBox(height: 4),
                      Text(w.name,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      Text(w.city,
                          style: const TextStyle(
                              fontSize: 12, color: CommercialColors.textMuted)),
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
                const Text('Historique des Bons de Transfert',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                if (store.stockTransfers.isEmpty)
                  const Text('Aucun transfert enregistré.',
                      style: TextStyle(color: CommercialColors.textMuted))
                else
                  DataTable(
                    columns: const [
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Article')),
                      DataColumn(label: Text('Origine → Destination')),
                      DataColumn(label: Text('Qté'), numeric: true),
                      DataColumn(label: Text('Note')),
                    ],
                    rows: store.stockTransfers
                        .map((t) => DataRow(cells: [
                              DataCell(Text(t.date)),
                              DataCell(Text('${t.sku} · ${t.articleName}')),
                              DataCell(
                                  Text('${t.fromWarehouse} → ${t.toWarehouse}')),
                              DataCell(Text(t.qty.toStringAsFixed(1))),
                              DataCell(Text(t.note.isEmpty ? '—' : t.note)),
                            ]))
                        .toList(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInventoryTab(BuildContext context, CommercialStore store) {
    final warehouseName = store.warehouses.isNotEmpty
        ? store.warehouses.first.name
        : 'Dépôt Principal';
    double totalVarValue = 0;
    for (final a in store.articles) {
      final counted = double.tryParse(_ctrlFor(a).text) ?? a.stockQty;
      totalVarValue += (counted - a.stockQty) * a.pmpCostMru;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Saisie Inventaire Physique · $warehouseName',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      Text(
                        'Impact valorisé des écarts (PMP) : ${totalVarValue >= 0 ? '+' : ''}${fmtMru(totalVarValue)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: totalVarValue >= 0
                              ? CommercialColors.successGreen
                              : CommercialColors.dangerRed,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final map = <int, double>{};
                    for (final a in store.articles) {
                      map[a.id] =
                          double.tryParse(_ctrlFor(a).text) ?? a.stockQty;
                    }
                    await store.applyPhysicalInventory(
                      warehouseName: warehouseName,
                      countedByArticleId: map,
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'Inventaire validé ! Stock et mouvements mis à jour.')));
                  },
                  icon: const Icon(Icons.fact_check_outlined, size: 18),
                  label: const Text('Valider l\'inventaire'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('SKU')),
                  DataColumn(label: Text('Article')),
                  DataColumn(label: Text('Stock théorique'), numeric: true),
                  DataColumn(label: Text('Stock compté')),
                  DataColumn(label: Text('Écart'), numeric: true),
                  DataColumn(label: Text('Valeur écart'), numeric: true),
                ],
                rows: store.articles.map((a) {
                  final ctrl = _ctrlFor(a);
                  final counted = double.tryParse(ctrl.text) ?? a.stockQty;
                  final delta = counted - a.stockQty;
                  return DataRow(cells: [
                    DataCell(Text(a.sku)),
                    DataCell(Text(a.name)),
                    DataCell(Text('${a.stockQty.toStringAsFixed(1)} ${a.unit}')),
                    DataCell(SizedBox(
                      width: 90,
                      child: TextField(
                        controller: ctrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                      ),
                    )),
                    DataCell(Text(
                      '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: delta == 0
                            ? CommercialColors.textMuted
                            : delta > 0
                                ? CommercialColors.successGreen
                                : CommercialColors.dangerRed,
                      ),
                    )),
                    DataCell(Text(fmtMru(delta * a.pmpCostMru))),
                  ]);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCsvTab(BuildContext context, CommercialStore store) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Import / Export Catalogue Articles (Excel CSV)',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                OutlinedButton.icon(
                  onPressed: store.exportArticlesCsv,
                  icon: const Icon(Icons.download_outlined, size: 17),
                  label: const Text('Exporter Catalogue CSV'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _csvCtrl,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Collez vos lignes CSV (séparateur ; ou ,)',
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () async {
                final res = await store.importArticlesCsv(_csvCtrl.text);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      'Import terminé : ${res.imported} article(s) importé(s), ${res.errors} erreur(s).'),
                ));
              },
              icon: const Icon(Icons.upload_file, size: 18),
              label: const Text('Importer ces articles'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCreateWarehouseDialog(BuildContext context) async {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final cityCtrl = TextEditingController(text: 'Nouakchott');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouveau dépôt / magasin'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: codeCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Code (ex: DEP-NDB) *')),
              const SizedBox(height: 10),
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nom du dépôt *')),
              const SizedBox(height: 10),
              TextField(
                  controller: cityCtrl,
                  decoration: const InputDecoration(labelText: 'Ville')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              widget.store.createWarehouse(
                code: codeCtrl.text,
                name: nameCtrl.text,
                city: cityCtrl.text,
              );
              Navigator.pop(ctx);
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }

  Future<void> _openTransferDialog(BuildContext context) async {
    final wh = widget.store.warehouses;
    final arts = widget.store.articles;
    String fromWh = wh.first.name;
    String toWh = wh[1].name;
    int artId = arts.first.id;
    final qtyCtrl = TextEditingController(text: '5');
    final noteCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Nouveau bon de transfert inter-dépôts'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: fromWh,
                  decoration: const InputDecoration(labelText: 'Dépôt source'),
                  items: wh
                      .map((w) =>
                          DropdownMenuItem(value: w.name, child: Text(w.name)))
                      .toList(),
                  onChanged: (v) => setS(() => fromWh = v ?? fromWh),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: toWh,
                  decoration:
                      const InputDecoration(labelText: 'Dépôt destination'),
                  items: wh
                      .map((w) =>
                          DropdownMenuItem(value: w.name, child: Text(w.name)))
                      .toList(),
                  onChanged: (v) => setS(() => toWh = v ?? toWh),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: artId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Article'),
                  items: arts
                      .map((a) => DropdownMenuItem(
                          value: a.id,
                          child: Text('${a.sku} · ${a.name}',
                              overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) => setS(() => artId = v ?? artId),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantité'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(labelText: 'Observation'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                final err = widget.store.transferStock(
                  fromWarehouse: fromWh,
                  toWarehouse: toWh,
                  articleId: artId,
                  qty: double.tryParse(qtyCtrl.text) ?? 0,
                  note: noteCtrl.text,
                );
                if (err != null) {
                  ScaffoldMessenger.of(ctx)
                      .showSnackBar(SnackBar(content: Text(err)));
                } else {
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Valider transfert'),
            ),
          ],
        ),
      ),
    );
  }
}

class CompanySettingsView extends StatefulWidget {
  final CommercialStore store;
  const CompanySettingsView({super.key, required this.store});

  @override
  State<CompanySettingsView> createState() => _CompanySettingsViewState();
}

class _CompanySettingsViewState extends State<CompanySettingsView> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _nifCtrl;
  late final TextEditingController _rcCtrl;
  late final TextEditingController _addrCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _ribCtrl;
  late final TextEditingController _bankilyCtrl;
  late final TextEditingController _masriviCtrl;
  late final TextEditingController _footerCtrl;

  @override
  void initState() {
    super.initState();
    final s = widget.store.companySettings;
    _nameCtrl = TextEditingController(text: s.companyName);
    _nifCtrl = TextEditingController(text: s.nif);
    _rcCtrl = TextEditingController(text: s.rc);
    _addrCtrl = TextEditingController(text: s.address);
    _cityCtrl = TextEditingController(text: s.city);
    _phoneCtrl = TextEditingController(text: s.phone);
    _ribCtrl = TextEditingController(text: s.bankRib);
    _bankilyCtrl = TextEditingController(text: s.bankilyNumber);
    _masriviCtrl = TextEditingController(text: s.masriviNumber);
    _footerCtrl = TextEditingController(text: s.invoiceFooter);
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _nifCtrl,
      _rcCtrl,
      _addrCtrl,
      _cityCtrl,
      _phoneCtrl,
      _ribCtrl,
      _bankilyCtrl,
      _masriviCtrl,
      _footerCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Paramètres Entreprise, Facturation A4 & Rôles',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Identité légale & Coordonnées bancaires (imprimées sur Factures A4)',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Raison sociale'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _nifCtrl,
                          decoration: const InputDecoration(labelText: 'NIF'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _rcCtrl,
                          decoration: const InputDecoration(labelText: 'RC'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _addrCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Adresse'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _cityCtrl,
                          decoration: const InputDecoration(labelText: 'Ville'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _phoneCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Téléphone'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _ribCtrl,
                          decoration:
                              const InputDecoration(labelText: 'RIB / IBAN'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _bankilyCtrl,
                          decoration:
                              const InputDecoration(labelText: 'N° Bankily'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _masriviCtrl,
                          decoration:
                              const InputDecoration(labelText: 'N° Masrivi'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _footerCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                        labelText: 'Mentions légales / Pied de facture A4'),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () {
                      store.saveCompanySettings(CompanySettings(
                        companyName: _nameCtrl.text.trim(),
                        nif: _nifCtrl.text.trim(),
                        rc: _rcCtrl.text.trim(),
                        address: _addrCtrl.text.trim(),
                        city: _cityCtrl.text.trim(),
                        phone: _phoneCtrl.text.trim(),
                        bankRib: _ribCtrl.text.trim(),
                        bankilyNumber: _bankilyCtrl.text.trim(),
                        masriviNumber: _masriviCtrl.text.trim(),
                        invoiceFooter: _footerCtrl.text.trim(),
                      ));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Paramètres entreprise enregistrés !')));
                    },
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Enregistrer les paramètres'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Langue (FR / العربية RTL) & Contrôle d\'Accès par Rôle',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'fr', label: Text('Français')),
                          ButtonSegment(
                              value: 'ar', label: Text('العربية (RTL)')),
                        ],
                        selected: {store.lang},
                        onSelectionChanged: (s) => store.setLanguage(s.first),
                      ),
                      SizedBox(
                        width: 280,
                        child: DropdownButtonFormField<String>(
                          initialValue: store.activeRole,
                          decoration: const InputDecoration(
                              labelText: 'Rôle actif (Permissions menus)'),
                          items: const [
                            DropdownMenuItem(
                                value: 'OWNER',
                                child: Text('Propriétaire (Accès total)')),
                            DropdownMenuItem(
                                value: 'MANAGER',
                                child: Text('Gérant (Accès total)')),
                            DropdownMenuItem(
                                value: 'COMMERCIAL',
                                child: Text('Commercial (Ventes, Clients, POS)')),
                            DropdownMenuItem(
                                value: 'ACCOUNTANT',
                                child: Text('Comptable (Finance, TVA, Factures)')),
                            DropdownMenuItem(
                                value: 'CASHIER',
                                child: Text('Caissier (POS uniquement)')),
                          ],
                          onChanged: (v) {
                            if (v != null) store.setActiveRole(v);
                          },
                        ),
                      ),
                    ],
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
