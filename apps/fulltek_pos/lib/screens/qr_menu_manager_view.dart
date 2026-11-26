import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/pos_models.dart';
import '../services/qr_print_helper.dart';
import '../state/pos_store.dart';
import '../theme/fulltek_themes.dart';
import '../widgets/qr_code_widget.dart';

class QrMenuManagerView extends StatefulWidget {
  final PosStore store;
  final int initialTab;
  final VoidCallback? onOrderAccepted;

  const QrMenuManagerView({
    super.key,
    required this.store,
    this.initialTab = 0,
    this.onOrderAccepted,
  });

  @override
  State<QrMenuManagerView> createState() => _QrMenuManagerViewState();
}

class _QrMenuManagerViewState extends State<QrMenuManagerView> {
  late int _tabIndex; // 0 = QR Codes & Chevalets, 1 = Commandes & Appels, 2 = Paramètres
  String _selectedZone = 'ALL';
  late final TextEditingController _waCtrl;
  late final TextEditingController _welcomeFrCtrl;
  late final TextEditingController _welcomeArCtrl;
  bool _savingSettings = false;

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTab;
    _waCtrl = TextEditingController(
      text: widget.store.qrWhatsappNumber.isNotEmpty
          ? widget.store.qrWhatsappNumber
          : widget.store.storePhone,
    );
    _welcomeFrCtrl = TextEditingController(text: widget.store.qrWelcomeFr);
    _welcomeArCtrl = TextEditingController(text: widget.store.qrWelcomeAr);
    Future.microtask(() async {
      await widget.store.fetchQrMenuSettings();
      await widget.store.fetchIncomingQrActivity();
      if (mounted) {
        _waCtrl.text = widget.store.qrWhatsappNumber.isNotEmpty
            ? widget.store.qrWhatsappNumber
            : widget.store.storePhone;
        _welcomeFrCtrl.text = widget.store.qrWelcomeFr;
        _welcomeArCtrl.text = widget.store.qrWelcomeAr;
      }
    });
  }

  @override
  void dispose() {
    _waCtrl.dispose();
    _welcomeFrCtrl.dispose();
    _welcomeArCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _escape(String s) => const HtmlEscape().convert(s);

  String _buildStandeeCardHtml({
    required String badgeLabel,
    required String url,
    bool singlePoster = false,
  }) {
    final svg = QrCodeEncoder.encode(url).toSvg(
      pixelSize: singlePoster ? 260 : 190,
      quietZone: 4,
    );
    final restName = _escape(
      widget.store.tenantName.trim().isNotEmpty
          ? widget.store.tenantName.trim()
          : 'FULL-TEK RESTO',
    );
    final safeBadge = _escape(badgeLabel);
    final safeUrl = _escape(url);
    final cls = singlePoster ? 'card-single' : 'card';
    return '''
<div class="$cls">
  <div class="rest-name">$restName</div>
  <div class="badge">$safeBadge</div>
  <div class="qr-wrap">$svg</div>
  <div class="cta-fr">Scannez pour voir le menu &amp; commander</div>
  <div class="cta-ar">امسح الرمز لتصفح القائمة والطلب مباشرة</div>
  <div class="url-foot">$safeUrl</div>
</div>
''';
  }

  void _printSinglePoster(String title, String badgeLabel, String url) {
    final card = _buildStandeeCardHtml(
      badgeLabel: badgeLabel,
      url: url,
      singlePoster: true,
    );
    final ok = printQrStandeeHtml(title, card);
    if (!ok) {
      _toast('Impression navigateur disponible sur la version Web.');
    }
  }

  String _zoneNameOf(DiningTable t) {
    final found = widget.store.zones.where((z) => z.id == t.zoneId);
    if (found.isNotEmpty) return found.first.label(widget.store.lang);
    return t.zoneId;
  }

  void _printAllTableStandees(List<DiningTable> tables) {
    if (tables.isEmpty) {
      _toast('Aucune table configurée dans le Plan de Salle.');
      return;
    }
    final cards = tables
        .map((t) => _buildStandeeCardHtml(
              badgeLabel: '🍽 TABLE ${t.code} · ${_zoneNameOf(t)}',
              url: widget.store.qrMenuUrl(tableCode: t.code),
            ))
        .join('\n');
    final ok = printQrStandeeHtml(
      'Chevalets QR · ${widget.store.tenantName}',
      '<div class="grid">$cards</div>',
    );
    if (!ok) {
      _toast('Impression navigateur disponible sur la version Web.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final store = widget.store;
        final p = FullTekThemes.paletteOf(context);
        final incomingCount = store.incomingQrTotalCount;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        key: const Key('qr_tab_codes'),
                        selected: _tabIndex == 0,
                        onSelected: (_) => setState(() => _tabIndex = 0),
                        label: const Text('📱 QR Codes & Chevalets A4'),
                      ),
                      ChoiceChip(
                        key: const Key('qr_tab_incoming'),
                        selected: _tabIndex == 1,
                        onSelected: (_) {
                          setState(() => _tabIndex = 1);
                          store.fetchIncomingQrActivity();
                        },
                        label: Text(
                          incomingCount > 0
                              ? '🔔 Commandes & Appels ($incomingCount)'
                              : '🔔 Commandes & Appels',
                        ),
                      ),
                      ChoiceChip(
                        key: const Key('qr_tab_settings'),
                        selected: _tabIndex == 2,
                        onSelected: (_) => setState(() => _tabIndex = 2),
                        label: const Text('⚙️ Paramètres Menu QR'),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          openExternalUrl(store.qrMenuUrl());
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text('Ouvrir le Menu Client'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        key: const Key('qr_print_all_tables_btn'),
                        onPressed: () => _printAllTableStandees(store.tables),
                        icon: const Icon(Icons.print_rounded, size: 17),
                        label: const Text('Imprimer tous les chevalets A4'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: _tabIndex == 0
                    ? _buildQrCodesTab(store, p)
                    : (_tabIndex == 1
                        ? _buildIncomingTab(store, p)
                        : _buildSettingsTab(store, p)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQrCodesTab(PosStore store, PosPalette p) {
    final generalUrl = store.qrMenuUrl();
    final zones = <String>{'ALL', ...store.tables.map(_zoneNameOf)}.toList();
    final filteredTables = _selectedZone == 'ALL'
        ? store.tables
        : store.tables.where((t) => _zoneNameOf(t) == _selectedZone).toList();

    return ListView(
      children: [
        // 1. General Restaurant QR Code Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.primary.withValues(alpha: 0.45)),
          ),
          child: Wrap(
            spacing: 18,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              QrCodeWidget(
                key: const Key('general_qr_widget'),
                data: generalUrl,
                size: 160,
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: p.primary.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'QR CODE GÉNÉRAL · MENU, EMPORTER & LIVRAISON',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: p.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      store.tenantName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: p.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Idéal pour votre vitrine, flyers, comptoir, bio Instagram et statut WhatsApp.',
                      style: TextStyle(fontSize: 12.5, color: p.textMuted),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      generalUrl,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: p.primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _printSinglePoster(
                            'Affiche QR · ${store.tenantName}',
                            '📱 MENU EN LIGNE & LIVRAISON',
                            generalUrl,
                          ),
                          icon: const Icon(Icons.print_rounded, size: 16),
                          label: const Text('Imprimer Affiche A4'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: generalUrl));
                            _toast('Lien Menu QR copié !');
                          },
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: const Text('Copier le lien'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => openExternalUrl(generalUrl),
                          icon: const Icon(Icons.smartphone_rounded, size: 16),
                          label: const Text('Tester sur navigateur'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 2. Per-Table / Khaima QR Codes
        Wrap(
          spacing: 10,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'QR Codes individuels par Table / Khaima (${filteredTables.length})',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w900,
                color: p.textPrimary,
              ),
            ),
            Wrap(
              spacing: 6,
              children: zones
                  .map((z) => ChoiceChip(
                        selected: _selectedZone == z,
                        onSelected: (_) => setState(() => _selectedZone = z),
                        label: Text(z == 'ALL' ? 'Toutes zones' : z),
                      ))
                  .toList(),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (filteredTables.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.border),
            ),
            child: Text(
              'Aucune table configurée. Ajoutez vos tables dans le Plan de Salle pour générer leurs QR codes automatiquement.',
              style: TextStyle(color: p.textMuted),
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: filteredTables.map((t) {
              final tUrl = store.qrMenuUrl(tableCode: t.code);
              return Container(
                width: 225,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Table ${t.code}',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            color: p.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: p.surfaceAlt,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _zoneNameOf(t),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: p.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    QrCodeWidget(
                      key: Key('table_qr_${t.code}'),
                      data: tUrl,
                      size: 150,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _printSinglePoster(
                              'Chevalet Table ${t.code}',
                              '🍽 TABLE ${t.code} · ${_zoneNameOf(t)}',
                              tUrl,
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            icon: const Icon(Icons.print_rounded, size: 15),
                            label: const Text('Imprimer',
                                style: TextStyle(fontSize: 11.5)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: 'Copier le lien Table ${t.code}',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: tUrl));
                            _toast('Lien Table ${t.code} copié !');
                          },
                          icon: const Icon(Icons.copy_rounded, size: 17),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildIncomingTab(PosStore store, PosPalette p) {
    final ordersList = store.incomingQrOrdersForRegister;
    final alertsList = store.incomingQrAlertsForRegister;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Commandes QR pour cette caisse (${ordersList.length}) · Appels Serveur (${alertsList.length}) · [${store.registerName}]',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: p.textPrimary,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed:
                  store.isLoadingQr ? null : () => store.fetchIncomingQrActivity(),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Actualiser'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ordersList.isEmpty && alertsList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.qr_code_scanner_rounded,
                          size: 48, color: p.textMuted),
                      const SizedBox(height: 8),
                      Text(
                        'Aucune commande QR ou appel serveur en attente pour cette caisse.',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: p.textMuted),
                      ),
                    ],
                  ),
                )
              : ListView(
                  children: [
                    if (alertsList.isNotEmpty) ...[
                      Text(
                        '🔔 Appels Serveur & Demandes d\'Addition',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: p.warning,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...alertsList.map((a) {
                        final id = (a['id'] as num?)?.toInt() ?? 0;
                        final isBill = a['kind'] == 'bill';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: p.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: p.warning.withValues(alpha: 0.45)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isBill
                                    ? Icons.receipt_long_rounded
                                    : Icons.notifications_active_rounded,
                                color: p.warning,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  isBill
                                      ? '🧾 Table ${a['tableName']} demande l\'addition'
                                      : '🔔 Table ${a['tableName']} appelle un serveur',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: p.textPrimary,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => store.ackQrAlert(id),
                                child: const Text('✓ Traité'),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                    ],
                    ...ordersList.map((o) {
                      final code = '${o['orderCode'] ?? ''}';
                      final mode = '${o['serviceMode'] ?? 'dine_in'}';
                      final items = (o['items'] as List?) ?? const [];
                      final total = (o['totalMru'] as num?)?.toDouble() ?? 0;
                      final modeBadge = mode == 'delivery'
                          ? '🛵 Livraison · ${o['deliveryZone'] ?? ''}'
                          : (mode == 'takeaway'
                              ? '🛍 Emporter'
                              : '🍽 Table ${o['tableName'] ?? ''}');
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: p.primary.withValues(alpha: 0.45)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$code · $modeBadge',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w900,
                                    color: p.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${total.toStringAsFixed(0)} MRU',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: p.primary,
                                  ),
                                ),
                              ],
                            ),
                            if ('${o['customerName'] ?? ''}'.isNotEmpty ||
                                '${o['customerPhone'] ?? ''}'.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Client : ${o['customerName'] ?? ''} · ${o['customerPhone'] ?? ''} ${'${o['deliveryAddress'] ?? ''}'.isNotEmpty ? '· ${o['deliveryAddress']}' : ''}',
                                style:
                                    TextStyle(fontSize: 12, color: p.textMuted),
                              ),
                            ],
                            const SizedBox(height: 8),
                            ...items.map((it) {
                              final m = (it as Map).cast<String, dynamic>();
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  '• ${m['qty']}x ${m['nameFr']} (${((m['unitPrice'] as num?) ?? 0).toStringAsFixed(0)} MRU)',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: p.textPrimary,
                                  ),
                                ),
                              );
                            }),
                            if ('${o['notes'] ?? ''}'.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                '📝 Note : ${o['notes']}',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: p.warning),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton(
                                  onPressed: () async {
                                    await store.rejectIncomingQrOrder(code);
                                    _toast('Commande $code refusée.');
                                  },
                                  style: OutlinedButton.styleFrom(
                                      foregroundColor: p.danger),
                                  child: const Text('✕ Refuser'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    await store.acceptIncomingQrOrder(o);
                                    _toast(
                                        'Commande $code importée dans la caisse !');
                                    widget.onOrderAccepted?.call();
                                  },
                                  icon: const Icon(Icons.check_rounded, size: 17),
                                  label:
                                      const Text('Accepter & Ouvrir en caisse'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildSettingsTab(PosStore store, PosPalette p) {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 660),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Multi-Caisses : Affectation des canaux sur ce poste
            Container(
              padding: const EdgeInsets.all(18),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.primary.withValues(alpha: 0.45)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.point_of_sale_rounded, color: p.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Affectation de cette Caisse (Multi-Caisses)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: p.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choisissez les canaux gérés par ce poste. Un poste « Salle uniquement » ne sera jamais dérangé par les commandes Emporter ou Livraison (et inversement).',
                    style: TextStyle(fontSize: 12, color: p.textMuted),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.all_inclusive_rounded, size: 15),
                        label: const Text('Caisse Unique (Tous canaux)'),
                        onPressed: () => store.setRegisterChannelConfig(
                          name: 'Caisse Principale (Tous canaux)',
                          dineIn: true,
                          takeaway: true,
                          delivery: true,
                        ),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.restaurant_rounded, size: 15),
                        label: const Text('Poste Salle uniquement (Sur place)'),
                        onPressed: () => store.setRegisterChannelConfig(
                          name: 'Poste Salle (Sur place)',
                          dineIn: true,
                          takeaway: false,
                          delivery: false,
                        ),
                      ),
                      ActionChip(
                        avatar:
                            const Icon(Icons.delivery_dining_rounded, size: 15),
                        label: const Text('Caisse Livraison & Emporter'),
                        onPressed: () => store.setRegisterChannelConfig(
                          name: 'Caisse Livraison & Emporter',
                          dineIn: false,
                          takeaway: true,
                          delivery: true,
                        ),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.two_wheeler_rounded, size: 15),
                        label: const Text('Caisse Livraison uniquement'),
                        onPressed: () => store.setRegisterChannelConfig(
                          name: 'Caisse Livraison',
                          dineIn: false,
                          takeaway: false,
                          delivery: true,
                        ),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.shopping_bag_rounded, size: 15),
                        label: const Text('Caisse Emporter uniquement'),
                        onPressed: () => store.setRegisterChannelConfig(
                          name: 'Caisse Emporter',
                          dineIn: false,
                          takeaway: true,
                          delivery: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('🍽 Sur place (Tables / Salle / Khaima)',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    value: store.registerHandlesDineIn,
                    onChanged: (v) => store.setRegisterChannelConfig(dineIn: v),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('🛍 À emporter (Takeaway)',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    value: store.registerHandlesTakeaway,
                    onChanged: (v) =>
                        store.setRegisterChannelConfig(takeaway: v),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('🛵 Livraison (Delivery)',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    value: store.registerHandlesDelivery,
                    onChanged: (v) =>
                        store.setRegisterChannelConfig(delivery: v),
                  ),
                ],
              ),
            ),

            // 2. Configuration Menu QR Public
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Configuration du Menu QR & Commande en Ligne',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: p.textPrimary,
                    ),
                  ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Activer le Menu QR public',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text(
                    'Permet aux clients de consulter votre carte en scannant les QR codes.'),
                value: store.qrMenuEnabled,
                onChanged: (v) => store.saveQrMenuSettings(enabled: v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Autoriser la prise de commande en ligne',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text(
                    'Désactivez pour passer en mode « Menu consultation uniquement ».'),
                value: store.qrAllowOrdering,
                onChanged: (v) => store.saveQrMenuSettings(allowOrdering: v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Validation caissier avant envoi en cuisine',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text(
                    'Recommandé : évite les fausses commandes ; vous validez en 1 clic.'),
                value: store.qrRequirePosValidation,
                onChanged: (v) =>
                    store.saveQrMenuSettings(requirePosValidation: v),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _waCtrl,
                decoration: const InputDecoration(
                  labelText: 'Numéro WhatsApp Restaurant (optionnel)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _welcomeFrCtrl,
                decoration: const InputDecoration(
                  labelText: 'Message d\'accueil (Français)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _welcomeArCtrl,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(
                  labelText: 'رسالة الترحيب (بالعربية)',
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _savingSettings
                    ? null
                    : () async {
                        setState(() => _savingSettings = true);
                        final ok = await store.saveQrMenuSettings(
                          whatsappNumber: _waCtrl.text,
                          welcomeFr: _welcomeFrCtrl.text,
                          welcomeAr: _welcomeArCtrl.text,
                        );
                        if (mounted) {
                          setState(() => _savingSettings = false);
                          _toast(ok
                              ? 'Paramètres Menu QR enregistrés !'
                              : 'Enregistré localement (hors ligne).');
                        }
                      },
                icon: const Icon(Icons.save_rounded),
                label: const Text('Enregistrer la configuration QR'),
              ),
            ],
          ),
        ),
          ],
        ),
      ),
    );
  }
}
