import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/external_link.dart';
import '../utils/file_reader.dart';
import '../widgets/offline_license_card.dart';

/// Fiche client complète : infos gérant, NIF/RC, matériel, fonctions, thèmes, édition, catalogue & licence Ed25519.
class StoreDetailScreen extends StatefulWidget {
  final TenantStore store;
  final String lang;
  final String Function(String) tr;
  final VoidCallback onExtend;
  final VoidCallback onToggleLock;
  final VoidCallback onChanged;
  final VoidCallback? onLicenseGenerated;
  final VoidCallback? onCatalogImported;

  const StoreDetailScreen({
    super.key,
    required this.store,
    required this.lang,
    required this.tr,
    required this.onExtend,
    required this.onToggleLock,
    required this.onChanged,
    this.onLicenseGenerated,
    this.onCatalogImported,
  });

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  static const Map<String, String> _allThemes = {
    '01': '01 · Émeraude Night',
    '04': '04 · Aurora Glass',
    '06': '06 · Ocean Fintech',
    '07': '07 · Mauritanie Prestige',
    '11': '11 · Nordic Minimal',
  };

  static const Map<String, String> _hwLabels = {
    'printer': 'Imprimante 80mm FR/AR',
    'scanner': 'Douchette EAN-13',
    'scale': 'Balance COM1',
    'drawer': 'Tiroir-caisse RJ11',
    'tablet': 'Tablette / KDS',
    'kds_screen': 'Écran Cuisine KDS',
  };

  static const Map<String, String> _featureLabels = {
    'quotes_invoices': 'Devis & Factures A4',
    'sales_cycle': 'Commandes, BL & Avoirs',
    'purchases_pmp': 'Achats, Fournisseurs & PMP',
    'pos_register': 'Caisse intégrée & Rapports Z',
    'treasury': 'Trésorerie Caisse & Banques',
    'cheques_due': 'Chèques & traites à échéance',
    'objectives': 'Objectifs mensuels & Analyses',
    'karni_credit': 'Encours clients & Karni',
    'kds': 'Écran cuisine KDS',
    'khaima': 'Plan Khaima VIP',
    'tablet': 'Tablette serveur',
    'split': 'Division de note',
    'scale': 'Balance COM1',
    'barcode': 'Scanner EAN-13',
    'wholesale': 'Détail / Demi-gros',
    'karni': 'Carnet Karni',
    'fefo': 'Lots FEFO & blocage',
    'cnam': 'Tiers-payant CNAM',
    'cold': 'Chaîne froid +4°C',
    'generic': 'Équivalents génériques',
    'boss': 'App Mobile Boss',
    'offline': 'Mode hors-ligne',
    'lan': 'Synchro LAN locale',
    'printer': 'Ticket 80mm FR/AR',
  };

  OfflineLicenseResponse? _license;
  bool _generatingLicense = false;
  String? _licenseError;
  int _licenseDays = 30;

  bool _importingCatalog = false;
  CatalogImportResult? _lastImportResult;
  String? _lastImportFilename;
  String? _importError;
  List<CatalogImportRowError> _importRowErrors = const [];

  bool _showPassword = false;

  void _openEditDialog() {
    final s = widget.store;
    final nameCtrl = TextEditingController(text: s.name);
    final mgrCtrl = TextEditingController(text: s.manager);
    final phoneCtrl = TextEditingController(text: s.phone);
    final districtCtrl = TextEditingController(text: s.district);
    final userCtrl = TextEditingController(text: s.username);
    final passCtrl = TextEditingController(text: s.accountPassword);
    final pinCtrl = TextEditingController(text: s.ownerPin);
    final nifCtrl = TextEditingController(text: s.nif);
    final rcCtrl = TextEditingController(text: s.rc);
    final notesCtrl = TextEditingController(text: s.notes);
    int tills = s.tills;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: FTColors.night2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Modifier la fiche client',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nom commercial', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: mgrCtrl,
                  decoration: const InputDecoration(labelText: 'Nom du gérant', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: phoneCtrl,
                        decoration: const InputDecoration(labelText: 'WhatsApp', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: districtCtrl,
                        decoration: const InputDecoration(labelText: 'Quartier', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: userCtrl,
                        decoration: const InputDecoration(labelText: 'Identifiant compte', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: pinCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Code PIN', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passCtrl,
                  decoration: const InputDecoration(labelText: 'Mot de passe du compte', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: nifCtrl,
                        decoration: const InputDecoration(labelText: 'NIF', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: rcCtrl,
                        decoration: const InputDecoration(labelText: 'RC', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Caisses autorisées', style: TextStyle(fontWeight: FontWeight.w800)),
                    Row(
                      children: [
                        IconButton.filledTonal(
                          onPressed: tills > 1 ? () => setModalState(() => tills--) : null,
                          icon: const Icon(Icons.remove),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text('$tills', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                        ),
                        IconButton.filledTonal(
                          onPressed: tills < 20 ? () => setModalState(() => tills++) : null,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notes installation', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () {
                      setState(() {
                        if (nameCtrl.text.trim().isNotEmpty) s.name = nameCtrl.text.trim();
                        s.manager = mgrCtrl.text.trim();
                        if (phoneCtrl.text.trim().isNotEmpty) s.phone = phoneCtrl.text.trim();
                        s.district = districtCtrl.text.trim();
                        if (userCtrl.text.trim().isNotEmpty) s.username = userCtrl.text.trim();
                        if (passCtrl.text.trim().isNotEmpty) s.accountPassword = passCtrl.text.trim();
                        if (pinCtrl.text.trim().length == 4) s.ownerPin = pinCtrl.text.trim();
                        s.nif = nifCtrl.text.trim();
                        s.rc = rcCtrl.text.trim();
                        s.notes = notesCtrl.text.trim();
                        s.tills = tills;
                      });
                      widget.onChanged();
                      Navigator.of(ctx).pop();
                    },
                    child: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _sendReminderWhatsApp() {
    final s = widget.store;
    final cleanPhone = s.phone.replaceAll(RegExp(r'\D'), '');
    final msg =
        'Bonjour ${s.manager.isNotEmpty ? s.manager : s.name}, suivi ${s.moduleName} (${s.name}) : il reste ${s.daysLeft} jour(s) sur votre licence ${s.plan}. Règlement Bankily : FT-22242 ou Masrivi : MS-4274. Support M. Taha : +222 42 74 42 42.';
    Clipboard.setData(ClipboardData(text: msg));
    if (canOpenUrlDirectly) {
      openExternalUrl('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(msg)}');
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Rappel WhatsApp prêt (copié)')));
  }

  Future<void> _genOfflineCode() async {
    if (_generatingLicense) return;
    setState(() {
      _generatingLicense = true;
      _licenseError = null;
    });
    final res = await ApiService.generateOfflineCode(
      widget.store.id,
      _licenseDays,
    );
    if (!mounted) return;
    if (res.ok && res.data != null) {
      final lic = res.data!;
      setState(() {
        _license = lic;
        _generatingLicense = false;
      });
      Clipboard.setData(ClipboardData(text: lic.code));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '${widget.tr('code_lbl')}: ${lic.code} (${widget.tr('copied_ok')})',
            ),
          ),
        );
      widget.onLicenseGenerated?.call();
      return;
    }

    final msg = (res.error != null && res.error!.trim().isNotEmpty)
        ? res.error!
        : widget.tr('lic_err');
    setState(() {
      _licenseError = msg;
      _generatingLicense = false;
    });
    if (res.statusCode != 401) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF451616),
            content: Text(msg),
          ),
        );
    }
  }

  Future<void> _handleCatalogImportButton() async {
    if (_importingCatalog) return;
    try {
      final picked = await pickCatalogFile();
      if (!mounted) return;
      if (picked != null) {
        await _uploadCatalogFile(picked);
        return;
      }
      if (!canPickCatalogFileNatively) {
        _openCatalogImportSheet();
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e is FormatException ? e.message : e.toString();
      setState(() {
        _lastImportResult = null;
        _importError = msg;
        _importRowErrors = const [];
      });
    }
  }

  Future<void> _importSampleCatalog() async {
    final s = widget.store;
    final sample = PickedCatalogFile(
      filename: 'modele_${s.module.name}.csv',
      format: 'csv',
      csvText: catalogSampleCsvForModule(s.module),
    );
    await _uploadCatalogFile(sample);
  }

  Future<void> _uploadCatalogFile(PickedCatalogFile file) async {
    if (_importingCatalog) return;
    setState(() {
      _importingCatalog = true;
      _importError = null;
      _importRowErrors = const [];
      _lastImportResult = null;
      _lastImportFilename = file.filename;
    });

    final res = await ApiService.importCatalog(
      widget.store.id,
      filename: file.filename,
      format: file.format,
      csvText: file.csvText,
      contentBase64: file.contentBase64,
    );
    if (!mounted) return;

    if (res.ok && res.data != null) {
      final r = res.data!;
      setState(() {
        _importingCatalog = false;
        _lastImportResult = r;
        _importError = null;
        _importRowErrors = const [];
      });
      final summary = widget.tr('cat_ok')
          .replaceAll('{total}', '${r.totalRows}')
          .replaceAll('{created}', '${r.created}')
          .replaceAll('{updated}', '${r.updated}')
          .replaceAll('{cats}', '${r.categoriesCreated}');
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(summary)));
      widget.onCatalogImported?.call();
      return;
    }

    final msg = (res.error != null && res.error!.trim().isNotEmpty)
        ? res.error!
        : widget.tr('cat_err');
    setState(() {
      _importingCatalog = false;
      _lastImportResult = null;
      _importError = msg;
      _importRowErrors = res.errors;
    });
    if (res.statusCode != 401) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF451616),
            content: Text(msg),
          ),
        );
    }
  }

  void _openCatalogImportSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FTColors.night2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => _CatalogImportSheet(
        store: widget.store,
        tr: widget.tr,
        onImportSample: _importSampleCatalog,
        onUploadFile: _uploadCatalogFile,
      ),
    );
  }

  Widget _kv(String k, String v, {bool ltr = false}) {
    if (v.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 4, child: Text(k, style: const TextStyle(fontSize: 12.5, color: FTColors.muted))),
          Expanded(
            flex: 6,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: ltr
                  ? Directionality(
                      textDirection: TextDirection.ltr,
                      child: SelectableText(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    )
                  : Text(v, textAlign: TextAlign.end, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final progress = (s.daysLeft / 30.0).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: FTColors.night,
        title: Text(s.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Modifier',
            icon: const Icon(Icons.edit_outlined, color: FTColors.ochre),
            onPressed: _openEditDialog,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            padding: const EdgeInsets.all(16),
        children: [
          Hero(
            tag: 'store-${s.id}',
            flightShuttleBuilder: (
              BuildContext flightContext,
              Animation<double> animation,
              HeroFlightDirection flightDirection,
              BuildContext fromHeroContext,
              BuildContext toHeroContext,
            ) {
              final Hero toHero = toHeroContext.widget as Hero;
              return Material(
                color: Colors.transparent,
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: toHero.child,
                ),
              );
            },
            child: Material(
              color: Colors.transparent,
              child: GlassCard(
                borderColor: s.moduleColor.withValues(alpha: 0.5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${s.moduleName}${s.subType.isNotEmpty ? ' · ${s.subType}' : ''}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: s.moduleColor),
                          ),
                        ),
                        if (s.tenantId.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(s.tenantId,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: FTColors.ochre)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(s.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                      '${s.city}${s.district.isNotEmpty ? ' · ${s.district}' : ''} · ${s.tills} ${widget.tr('tills')}',
                      style: const TextStyle(fontSize: 12.5, color: FTColors.muted),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Licence ${s.plan}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.tr('lic_days_left').replaceAll('{d}', '${s.daysLeft}'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: s.daysLeft <= 5 ? FTColors.warn : FTColors.greenOk,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Colors.white10,
                        color: s.daysLeft <= 5 ? FTColors.warn : FTColors.greenOk,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              widget.onExtend();
                              setState(() {});
                            },
                            icon: const Icon(Icons.add_circle_outline, size: 17),
                            label: Text(widget.tr('btn_extend')),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              widget.onToggleLock();
                              setState(() {});
                            },
                            icon: Icon(s.status == StoreStatus.locked ? Icons.lock_open : Icons.lock_outline, size: 17),
                            label: Text(
                              s.status == StoreStatus.locked ? widget.tr('btn_unlock') : widget.tr('btn_lock'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [30, 90, 365].map((d) {
                        final selected = _licenseDays == d;
                        return ChoiceChip(
                          label: Text('+${d}j', style: const TextStyle(fontSize: 11.5)),
                          selected: selected,
                          onSelected: _generatingLicense
                              ? null
                              : (_) => setState(() => _licenseDays = d),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: _sendReminderWhatsApp,
                            icon: const Icon(Icons.chat, size: 17, color: FTColors.greenOk),
                            label: const Text('WhatsApp'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            key: const Key('store_generate_license_btn'),
                            onPressed: _generatingLicense ? null : _genOfflineCode,
                            icon: _generatingLicense
                                ? const SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.vpn_key, size: 17, color: FTColors.ochre),
                            label: Text(
                              _generatingLicense
                                  ? widget.tr('lic_generating')
                                  : widget.tr('lic_gen_btn'),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_licenseError != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        key: const Key('store_license_error'),
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: FTColors.danger.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: FTColors.danger),
                        ),
                        child: Text(
                          _licenseError!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFFCA5A5),
                          ),
                        ),
                      ),
                    ],
                    if (_license != null) ...[
                      const SizedBox(height: 12),
                      OfflineLicenseResultCard(
                        license: _license!,
                        tr: widget.tr,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 1-Click Catalog Import Card
          _buildCatalogImportCard(),
          const SizedBox(height: 14),

          // Coordonnées Gérant & Fiscalité
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dossier Client & Gérant',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                _kv('Gérant', s.manager),
                _kv('WhatsApp', s.phone, ltr: true),
                _kv('Identifiant', s.username, ltr: true),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      const Expanded(
                        flex: 4,
                        child: Text('Mot de passe compte',
                            style: TextStyle(fontSize: 12.5, color: FTColors.muted)),
                      ),
                      Expanded(
                        flex: 6,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Flexible(
                              child: Directionality(
                                textDirection: TextDirection.ltr,
                                child: SelectableText(
                                  s.accountPassword.isEmpty
                                      ? 'Non défini'
                                      : (_showPassword ? s.accountPassword : '••••••••'),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: FTColors.ochre,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                _showPassword ? Icons.visibility_off : Icons.visibility,
                                size: 17,
                              ),
                              onPressed: () => setState(() => _showPassword = !_showPassword),
                            ),
                            if (s.accountPassword.isNotEmpty)
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.copy, size: 16),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: s.accountPassword));
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(const SnackBar(content: Text('Mot de passe copié')));
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _kv(widget.tr('pin_h'), s.ownerPin, ltr: true),
                _kv('Raison sociale', s.legalName),
                _kv('NIF', s.nif, ltr: true),
                _kv('Registre Commerce', s.rc, ltr: true),
                _kv('Email', s.email, ltr: true),
                _kv('Adresse', s.address),
                _kv('Paiement initial',
                    s.initialPayMethod.isNotEmpty
                        ? '${s.initialPayMethod}${s.initialPayRef.isNotEmpty ? ' · ${s.initialPayRef}' : ''}'
                        : ''),
                _kv('Notes', s.notes),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Matériel, Fonctions & Moyens de paiement
          if (s.hardware.isNotEmpty || s.payMethods.isNotEmpty || s.features.isNotEmpty)
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (s.hardware.isNotEmpty) ...[
                    const Text('Matériel installé', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: s.hardware
                          .map((k) => Chip(label: Text(_hwLabels[k] ?? k, style: const TextStyle(fontSize: 11.5))))
                          .toList(),
                    ),
                    if (s.payMethods.isNotEmpty || s.features.isNotEmpty) const SizedBox(height: 12),
                  ],
                  if (s.payMethods.isNotEmpty) ...[
                    const Text('Paiements acceptés en caisse',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: s.payMethods
                          .map((p) => Chip(label: Text(p, style: const TextStyle(fontSize: 11.5))))
                          .toList(),
                    ),
                    if (s.features.isNotEmpty) const SizedBox(height: 12),
                  ],
                  if (s.features.isNotEmpty) ...[
                    const Text('Fonctions & modules activés',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: s.features
                          .map((f) => Chip(label: Text(_featureLabels[f] ?? f, style: const TextStyle(fontSize: 11.5))))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          if (s.hardware.isNotEmpty || s.payMethods.isNotEmpty || s.features.isNotEmpty) const SizedBox(height: 14),

          // Thèmes POS autorisés
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.tr('themes_h'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _allThemes.entries.map((e) {
                    final on = s.enabledThemes.contains(e.key);
                    return FilterChip(
                      label: Text(e.value),
                      selected: on,
                      onSelected: (val) {
                        setState(() {
                          final next = List<String>.from(s.enabledThemes);
                          if (val) {
                            next.add(e.key);
                          } else if (next.length > 1) {
                            next.remove(e.key);
                          }
                          s.enabledThemes = next;
                        });
                        widget.onChanged();
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }

  Widget _buildCatalogImportCard() {
    final r = _lastImportResult;
    return GlassCard(
      key: const Key('catalog_import_card'),
      borderColor: FTColors.market.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.upload_file_rounded, color: FTColors.ochre, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.tr('cat_h'),
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      widget.tr('cat_sub'),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: FTColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: const Key('catalog_import_btn'),
                onPressed: _importingCatalog ? null : _handleCatalogImportButton,
                style: FilledButton.styleFrom(
                  backgroundColor: FTColors.ochre,
                  foregroundColor: const Color(0xFF101916),
                ),
                icon: const Icon(Icons.file_upload_outlined, size: 18),
                label: Text(
                  _importingCatalog
                      ? widget.tr('cat_importing')
                      : widget.tr('cat_btn'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              OutlinedButton.icon(
                key: const Key('catalog_sample_btn'),
                onPressed: _importingCatalog ? null : _importSampleCatalog,
                icon: const Icon(Icons.bolt, size: 17, color: FTColors.greenOk),
                label: Text(
                  widget.tr('cat_sample_btn'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (_importingCatalog) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(minHeight: 3),
          ],
          if (r != null) ...[
            const SizedBox(height: 12),
            Container(
              key: const Key('catalog_import_result'),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FTColors.market.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: FTColors.greenOk),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_lastImportFilename ?? 'catalog'} · ${r.format.toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: FTColors.greenOk,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _statBadge('${widget.tr('cat_total')}: ${r.totalRows}'),
                      _statBadge('${widget.tr('cat_created')}: ${r.created}'),
                      _statBadge('${widget.tr('cat_updated')}: ${r.updated}'),
                      _statBadge(
                        '${widget.tr('cat_cats')}: ${r.categoriesCreated}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (_importError != null) ...[
            const SizedBox(height: 12),
            Container(
              key: const Key('catalog_import_error'),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FTColors.danger.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: FTColors.danger),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _importError!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFCA5A5),
                    ),
                  ),
                  if (_importRowErrors.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    ..._importRowErrors.map(
                      (err) => Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          widget.tr('cat_row_err')
                              .replaceAll('{row}', '${err.row}')
                              .replaceAll('{msg}', err.message),
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFFFECACA),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _CatalogImportSheet extends StatefulWidget {
  final TenantStore store;
  final String Function(String) tr;
  final Future<void> Function() onImportSample;
  final Future<void> Function(PickedCatalogFile) onUploadFile;

  const _CatalogImportSheet({
    required this.store,
    required this.tr,
    required this.onImportSample,
    required this.onUploadFile,
  });

  @override
  State<_CatalogImportSheet> createState() => _CatalogImportSheetState();
}

class _CatalogImportSheetState extends State<_CatalogImportSheet> {
  final TextEditingController _pathCtrl = TextEditingController();
  final TextEditingController _pasteCtrl = TextEditingController();
  String? _localErr;

  @override
  void dispose() {
    _pathCtrl.dispose();
    _pasteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.tr('cat_sheet_title'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              key: const Key('catalog_sheet_sample_btn'),
              onPressed: () {
                Navigator.of(context).pop();
                widget.onImportSample();
              },
              icon: const Icon(Icons.auto_awesome, color: FTColors.ochre),
              label: Text(
                '${widget.tr('cat_sample_btn')} · ${widget.store.moduleName}',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('catalog_path_input'),
              controller: _pathCtrl,
              decoration: InputDecoration(
                labelText: widget.tr('cat_path_lbl'),
                hintText: r'C:\data\catalogue.csv',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('catalog_path_submit'),
              onPressed: () async {
                try {
                  final picked = await readCatalogFileFromPath(_pathCtrl.text);
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  await widget.onUploadFile(picked);
                } catch (e) {
                  if (!mounted) return;
                  setState(() => _localErr = e.toString());
                }
              },
              icon: const Icon(Icons.folder_open),
              label: Text(widget.tr('cat_path_btn')),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('catalog_paste_input'),
              controller: _pasteCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: widget.tr('cat_paste_lbl'),
                hintText: 'name_fr,price_retail,category\n...',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('catalog_paste_submit'),
              onPressed: () {
                final csv = _pasteCtrl.text.trim();
                if (csv.isEmpty) {
                  setState(() => _localErr = widget.tr('cat_err'));
                  return;
                }
                Navigator.of(context).pop();
                widget.onUploadFile(
                  PickedCatalogFile(
                    filename: 'colle_${widget.store.module.name}.csv',
                    format: 'csv',
                    csvText: csv,
                  ),
                );
              },
              child: Text(widget.tr('cat_paste_btn')),
            ),
            if (_localErr != null) ...[
              const SizedBox(height: 10),
              Text(
                _localErr!,
                style: const TextStyle(
                  color: FTColors.danger,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
