import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/external_link.dart';

/// Fiche client complète : infos gérant, NIF/RC, matériel, fonctions, thèmes, édition & WhatsApp.
class StoreDetailScreen extends StatefulWidget {
  final TenantStore store;
  final String lang;
  final String Function(String) tr;
  final VoidCallback onExtend;
  final VoidCallback onToggleLock;
  final VoidCallback onChanged;

  const StoreDetailScreen({
    super.key,
    required this.store,
    required this.lang,
    required this.tr,
    required this.onExtend,
    required this.onToggleLock,
    required this.onChanged,
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

  String _offlineCode = '';
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
        'Bonjour ${s.manager.isNotEmpty ? s.manager : s.name}, suivi Full·Tek POS (${s.name}) : il reste ${s.daysLeft} jour(s) sur votre licence ${s.plan}. Règlement Bankily : FT-22242 ou Masrivi : MS-4274. Support M. Taha : +222 42 74 42 42.';
    Clipboard.setData(ClipboardData(text: msg));
    if (canOpenUrlDirectly) {
      openExternalUrl('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(msg)}');
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Rappel WhatsApp prêt (copié)')));
  }

  void _genOfflineCode() {
    final s = widget.store;
    final p1 = 1000 + ((s.id * 1731 + 30 * 47) % 9000);
    final p2 = 1000 + ((s.id * 2917 + 30 * 83) % 9000);
    setState(() => _offlineCode = '$p1-$p2');
    Clipboard.setData(ClipboardData(text: _offlineCode));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Code hors-ligne $_offlineCode copié')));
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Hero(
            tag: 'store-${s.id}',
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
                        Text(
                          '${s.moduleName}${s.subType.isNotEmpty ? ' · ${s.subType}' : ''}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: s.moduleColor),
                        ),
                        if (s.tenantId.isNotEmpty)
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
                        Text('Licence ${s.plan}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        Text('${s.daysLeft} jours restants',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: s.daysLeft <= 5 ? FTColors.warn : FTColors.greenOk,
                            )),
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
                            onPressed: _genOfflineCode,
                            icon: const Icon(Icons.vpn_key, size: 17, color: FTColors.ochre),
                            label: const Text('Code 8 chiffres'),
                          ),
                        ),
                      ],
                    ),
                    if (_offlineCode.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: FTColors.bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: FTColors.ochre),
                        ),
                        child: Center(
                          child: Directionality(
                            textDirection: TextDirection.ltr,
                            child: SelectableText(
                              _offlineCode,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3,
                                color: FTColors.ochre,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
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
                            Directionality(
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

          // Matériel & Moyens de paiement
          if (s.hardware.isNotEmpty || s.payMethods.isNotEmpty)
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
                    const SizedBox(height: 12),
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
                  ],
                ],
              ),
            ),
          if (s.hardware.isNotEmpty || s.payMethods.isNotEmpty) const SizedBox(height: 14),

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
    );
  }
}
