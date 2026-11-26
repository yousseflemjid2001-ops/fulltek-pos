import 'dart:async';
import 'package:flutter/material.dart';
import '../models/pos_models.dart';
import '../services/fullscreen_helper.dart';
import '../state/pos_store.dart';
import '../theme/fulltek_themes.dart';
import '../widgets/fulltek_logo.dart';
import '../widgets/touch_keyboard.dart';
import 'back_office_view.dart';
import 'checkout_dialog.dart';
import 'closing_z_view.dart';
import 'floor_plan_view.dart';
import 'karni_view.dart';
import 'kds_view.dart';
import 'menu_stock_view.dart';
import 'owner_dashboard_view.dart';
import 'pos_register_view.dart';
import 'qr_menu_manager_view.dart';

class PosShellScreen extends StatefulWidget {
  final PosStore store;
  const PosShellScreen({super.key, required this.store});

  @override
  State<PosShellScreen> createState() => _PosShellScreenState();
}

class _PosShellScreenState extends State<PosShellScreen> {
  String _activeViewId = 'pos';
  bool _isFullscreen = isFullscreenActive();
  Timer? _qrPollTimer;

  @override
  void initState() {
    super.initState();
    if (widget.store.cloudJwtToken != null &&
        widget.store.cloudJwtToken!.isNotEmpty) {
      Future.microtask(() => widget.store.fetchIncomingQrActivity());
      _qrPollTimer = Timer.periodic(
        const Duration(seconds: 20),
        (_) => widget.store.fetchIncomingQrActivity(),
      );
    }
  }

  @override
  void dispose() {
    _qrPollTimer?.cancel();
    super.dispose();
  }

  void _openQrMenuModal() {
    final store = widget.store;
    final hasIncoming = store.incomingQrTotalCount > 0;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: SizedBox(
          width: 1020,
          height: 680,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_2_rounded),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Menu QR & Commandes en Ligne',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: QrMenuManagerView(
                  store: store,
                  initialTab: hasIncoming ? 1 : 0,
                  onOrderAccepted: () {
                    Navigator.of(ctx).pop();
                    if (mounted) setState(() => _activeViewId = 'pos');
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _defaultViewForRole(PosRole? role) {
    return switch (role) {
      PosRole.kitchen => 'kds',
      PosRole.stockKeeper => 'menu_stock',
      PosRole.accountant => 'closing',
      _ => 'pos',
    };
  }

  Future<void> _openLicenseDialog() async {
    final store = widget.store;
    final i18n = store.i18n;
    final ctrl = TextEditingController();
    String? err;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Licence Hors-Ligne Ed25519'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Établissement : ${store.license.tenantName}\n'
                'Code actif : ${store.license.code12}\n'
                'Jours restants : ${store.license.daysRemaining} j',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('offline_license_input'),
                controller: ctrl,
                decoration: InputDecoration(
                  labelText: 'Code déblocage ou Lease Token',
                  errorText: err,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(i18n.t('cancel')),
            ),
            ElevatedButton(
              key: const Key('activate_offline_license_btn'),
              onPressed: () {
                final msg = store.activateOfflineLicense(ctrl.text);
                if (msg != null) {
                  setD(() => err = msg);
                  return;
                }
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Licence prolongée (${store.license.daysRemaining}j).',
                    ),
                  ),
                );
              },
              child: const Text('Activer'),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
  }

  Future<void> _openFunctionsHub(
    List<({
      String id,
      Key navKey,
      IconData icon,
      IconData selectedIcon,
      String label,
      String subtitle,
      Color color,
      bool badge,
      Widget view,
    })> availableViews,
  ) async {
    final store = widget.store;
    final p = FullTekThemes.paletteOf(context);
    final staff = store.currentStaff;
    final canBackOffice = store.canCurrent(PosPermission.accessBackOffice) ||
        staff?.role == PosRole.owner;

    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: p.border),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 880,
            maxHeight: MediaQuery.of(ctx).size.height * 0.90,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: p.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.apps_rounded, color: p.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fonctions & Outils · ${store.tenantName}',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: p.textPrimary,
                            ),
                          ),
                          Text(
                            'Opérateur : ${staff?.name ?? ''} (${staff?.role.label(store.lang) ?? ''}) — Boutons activés selon vos droits',
                            style: TextStyle(fontSize: 12, color: p.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close_rounded, size: 24),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: p.border),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount:
                              MediaQuery.of(ctx).size.width >= 760
                                  ? 4
                                  : (MediaQuery.of(ctx).size.width >= 520
                                      ? 3
                                      : 2),
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.95,
                          children: [
                            for (final v in availableViews)
                              _buildFunctionTile(
                                p: p,
                                icon: v.selectedIcon,
                                title: v.label,
                                subtitle: v.subtitle,
                                color: v.color,
                                selected: _activeViewId == v.id,
                                badgeText: v.badge &&
                                        store.activeKdsTickets().isNotEmpty
                                    ? '${store.activeKdsTickets().length}'
                                    : null,
                                onTap: () {
                                  Navigator.of(ctx).pop();
                                  setState(() => _activeViewId = v.id);
                                },
                              ),
                            if (canBackOffice)
                              _buildFunctionTile(
                                p: p,
                                icon: Icons.dashboard_customize_rounded,
                                title: 'Back-Office ERP',
                                subtitle: 'Achats, Factures, Compta',
                                color: const Color(0xFF7C3AED),
                                onTap: () {
                                  Navigator.of(ctx).pop();
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => BackOfficeScreen(
                                        store: store,
                                        operatorStaff: staff,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            if (canBackOffice ||
                                store.canCurrent(PosPermission.voidOrComp) ||
                                store.canCurrent(
                                    PosPermission.manageMenuStock))
                              _buildFunctionTile(
                                p: p,
                                icon: Icons.account_balance_wallet_rounded,
                                title: 'Portefeuilles (16+)',
                                subtitle: '${store.activeWallets.length} actifs',
                                color: const Color(0xFF059669),
                                onTap: () {
                                  Navigator.of(ctx).pop();
                                  showWalletsConfigDialog(context, store);
                                },
                              ),
                            _buildFunctionTile(
                              p: p,
                              icon: Icons.tune_rounded,
                              title: 'Paramétrage X & Z',
                              subtitle: [
                                'Règlements',
                                if (store.xzShowByFamily) 'Familles',
                                if (store.xzShowByArticle) 'Articles',
                                if (store.xzShowByCustomer) 'Clients',
                              ].join(' · '),
                              color: const Color(0xFF0EA5E9),
                              onTap: () {
                                Navigator.of(ctx).pop();
                                showXzReportSettingsDialog(context, store);
                              },
                            ),
                            _buildFunctionTile(
                              p: p,
                              icon: Icons.qr_code_2_rounded,
                              title: 'Menu QR & Codes Tables',
                              subtitle: store.incomingQrTotalCount > 0
                                  ? '${store.incomingQrTotalCount} nouvelle(s) demande(s) QR !'
                                  : 'QR général, chevalets A4 & commandes en ligne',
                              color: const Color(0xFF10B981),
                              onTap: () {
                                Navigator.of(ctx).pop();
                                _openQrMenuModal();
                              },
                            ),
                            _buildFunctionTile(
                              p: p,
                              icon: Icons.chat_bubble_outline_rounded,
                              title: 'Commentaires',
                              subtitle:
                                  'Cuisine (${store.kitchenComments.length}) · Bar (${store.barComments.length})',
                              color: p.warning,
                              onTap: () {
                                Navigator.of(ctx).pop();
                                _openQuickCommentsDialog();
                              },
                            ),
                            _buildFunctionTile(
                              p: p,
                              icon: Icons.cloud_sync_rounded,
                              title: 'Synchroniser Cloud',
                              subtitle: store.pendingSyncCount > 0
                                  ? '${store.pendingSyncCount} en attente'
                                  : 'À jour',
                              color: p.accent,
                              badgeText: store.pendingSyncCount > 0
                                  ? '${store.pendingSyncCount}'
                                  : null,
                              onTap: () {
                                Navigator.of(ctx).pop();
                                store.fetchCloudCatalog();
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Paramètres rapides de la caisse',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: p.textMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // 3 compact setting cards side-by-side on wide screens
                        LayoutBuilder(
                          builder: (ctx, sc) {
                            final isWide = sc.maxWidth >= 640;
                            final noteCard = StatefulBuilder(
                              builder: (ctx, setOpt) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: p.surfaceAlt,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: p.border),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.print_outlined,
                                        color: p.primary, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Ticket après Note',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w900,
                                              color: p.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            store.printReceiptAfterNote
                                                ? 'Imprime 2ᵉ ticket'
                                                : 'Économie papier',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: p.textMuted),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      key: const Key('print_after_note_switch'),
                                      value: store.printReceiptAfterNote,
                                      onChanged: (v) {
                                        store.setPrintReceiptAfterNote(v);
                                        setOpt(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                            final tvaCard = StatefulBuilder(
                              builder: (ctx, setTva) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: p.surfaceAlt,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: p.border),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.percent_rounded,
                                        color: store.tvaEnabled
                                            ? p.primary
                                            : p.textMuted,
                                        size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'TVA (${store.tvaRatePercent.toStringAsFixed(0)} %)',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w900,
                                              color: p.textPrimary,
                                            ),
                                          ),
                                          if (store.tvaEnabled)
                                            DropdownButton<double>(
                                              key:
                                                  const Key('tva_rate_dropdown'),
                                              isDense: true,
                                              underline:
                                                  const SizedBox.shrink(),
                                              value: const [
                                                14.0,
                                                16.0,
                                                18.0,
                                                20.0
                                              ].contains(store.tvaRatePercent)
                                                  ? store.tvaRatePercent
                                                  : 16.0,
                                              items: const [
                                                14.0,
                                                16.0,
                                                18.0,
                                                20.0
                                              ]
                                                  .map(
                                                    (r) => DropdownMenuItem(
                                                      value: r,
                                                      child: Text(
                                                        'Taux ${r.toStringAsFixed(0)} %',
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          fontSize: 11.5,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                              onChanged: (r) {
                                                if (r == null) return;
                                                store.setTvaSettings(
                                                    ratePercent: r);
                                                setTva(() {});
                                              },
                                            )
                                          else
                                            Text(
                                              'Désactivée',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: p.textMuted),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      key: const Key('tva_enabled_switch'),
                                      value: store.tvaEnabled,
                                      onChanged: (v) {
                                        store.setTvaSettings(enabled: v);
                                        setTva(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                            final kbCard = StatefulBuilder(
                              builder: (ctx, setKb) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: p.surfaceAlt,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: p.border),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.keyboard_rounded,
                                        color: TouchKeyboardController
                                                .instance.autoOpenEnabled
                                            ? p.primary
                                            : p.textMuted,
                                        size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Clavier tactile',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w900,
                                              color: p.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            TouchKeyboardController
                                                    .instance.autoOpenEnabled
                                                ? 'Auto (FR/AR/123)'
                                                : 'Clavier physique',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: p.textMuted),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      key: const Key(
                                          'touch_keyboard_auto_switch'),
                                      value: TouchKeyboardController
                                          .instance.autoOpenEnabled,
                                      onChanged: (v) {
                                        TouchKeyboardController.instance
                                            .setAutoOpen(v);
                                        setKb(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                            final deliveryFeeCard = StatefulBuilder(
                              builder: (ctx, setDeliv) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: p.surfaceAlt,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: p.border),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.delivery_dining_rounded,
                                        color: store.deliveryFeeEnabled
                                            ? p.primary
                                            : p.textMuted,
                                        size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  'Frais de livraison',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w900,
                                                    color: p.textPrimary,
                                                  ),
                                                ),
                                              ),
                                              if (store.deliveryFeeEnabled) ...[
                                                const SizedBox(width: 6),
                                                InkWell(
                                                  key: const Key(
                                                      'settings_delivery_zones_btn'),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  onTap: () =>
                                                      _openDeliveryZonesSettingsDialog(
                                                          ctx),
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: p.primary
                                                          .withValues(
                                                              alpha: 0.14),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                    child: Text(
                                                      '⚙ Tarifs',
                                                      style: TextStyle(
                                                        fontSize: 10.5,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: p.primary,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          Text(
                                            store.deliveryFeeEnabled
                                                ? '${store.deliveryZones.length} zone(s) actives (MRU)'
                                                : 'Désactivé (0 MRU · géré avec livreur)',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: p.textMuted),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      key: const Key(
                                          'delivery_fee_enabled_switch'),
                                      value: store.deliveryFeeEnabled,
                                      onChanged: (v) {
                                        store.setDeliveryFeeEnabled(v);
                                        setDeliv(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                            if (isWide) {
                              return Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: noteCard),
                                      const SizedBox(width: 10),
                                      Expanded(child: tvaCard),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(child: deliveryFeeCard),
                                      const SizedBox(width: 10),
                                      Expanded(child: kbCard),
                                    ],
                                  ),
                                ],
                              );
                            }
                            return Column(
                              children: [
                                noteCard,
                                const SizedBox(height: 8),
                                tvaCard,
                                const SizedBox(height: 8),
                                deliveryFeeCard,
                                const SizedBox(height: 8),
                                kbCard,
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: p.border),
                const SizedBox(height: 10),
                // Secondary utility bar inside Functions Hub (Language, License, Fullscreen)
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final l in const [
                          ('fr', 'FR · Français'),
                          ('ar', 'AR · عربي'),
                          ('en', 'EN · English'),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                store.setLanguage(l.$1);
                                Navigator.of(ctx).pop();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: store.lang == l.$1
                                      ? p.primary
                                      : p.surfaceAlt,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: store.lang == l.$1
                                        ? p.primary
                                        : p.border,
                                  ),
                                ),
                                child: Text(
                                  l.$2,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: store.lang == l.$1
                                        ? p.onPrimary
                                        : p.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _openLicenseDialog();
                          },
                          icon: Icon(
                            Icons.verified_user_rounded,
                            size: 17,
                            color: store.license.daysRemaining <= 5
                                ? p.warning
                                : p.success,
                          ),
                          label: Text(
                            'Licence (${store.license.daysRemaining}j)',
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final next = await toggleFullscreen();
                            if (mounted) setState(() => _isFullscreen = next);
                          },
                          icon: Icon(
                            _isFullscreen
                                ? Icons.fullscreen_exit_rounded
                                : Icons.fullscreen_rounded,
                            size: 17,
                          ),
                          label: const Text('Plein écran'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openQuickCommentsDialog() async {
    final store = widget.store;
    final p = FullTekThemes.paletteOf(context);
    final ctrl = TextEditingController();
    bool isBarTab = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final currentList =
              isBarTab ? store.barComments : store.kitchenComments;
          return AlertDialog(
            backgroundColor: p.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: p.border),
            ),
            title: Row(
              children: [
                Icon(
                  isBarTab
                      ? Icons.local_cafe_rounded
                      : Icons.restaurant_rounded,
                  color: p.warning,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Paramétrer les commentaires (Cuisine & Café/Bar)',
                    style:
                        TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            key: const Key('cfg_comments_tab_kitchen'),
                            selected: !isBarTab,
                            selectedColor: p.primary,
                            label: Center(
                              child: Text(
                                '🍳 Cuisine (${store.kitchenComments.length})',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: !isBarTab
                                      ? p.onPrimary
                                      : p.textPrimary,
                                ),
                              ),
                            ),
                            onSelected: (_) => setD(() => isBarTab = false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            key: const Key('cfg_comments_tab_bar'),
                            selected: isBarTab,
                            selectedColor: p.primary,
                            label: Center(
                              child: Text(
                                '☕ Café / Bar (${store.barComments.length})',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color:
                                      isBarTab ? p.onPrimary : p.textPrimary,
                                ),
                              ),
                            ),
                            onSelected: (_) => setD(() => isBarTab = true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isBarTab
                          ? 'Commentaires affichés automatiquement pour les cafés, thés, jus, milkshakes et boissons du bar :'
                          : 'Commentaires affichés automatiquement pour les plats, grillades, pizzas et fast-food :',
                      style: TextStyle(fontSize: 12.5, color: p.textMuted),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('new_quick_comment_input'),
                            controller: ctrl,
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: isBarTab
                                  ? 'Nouveau commentaire Café / Bar'
                                  : 'Nouveau commentaire Cuisine',
                              hintText: isBarTab
                                  ? 'Ex: Sans sucre, lait d\'avoine, paille...'
                                  : 'Ex: Sans ail, bien doré, sans fromage...',
                              prefixIcon: const Icon(Icons.add_comment_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          key: const Key('add_quick_comment_btn'),
                          onPressed: () {
                            final txt = ctrl.text.trim();
                            if (txt.isEmpty) return;
                            store.addQuickComment(txt, isBar: isBarTab);
                            ctrl.clear();
                            setD(() {});
                          },
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Ajouter'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (currentList.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Aucun commentaire enregistré dans cette catégorie.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: p.textMuted),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: currentList.map((c) {
                          return Chip(
                            key: Key('quick_comment_chip_$c'),
                            backgroundColor: p.surfaceAlt,
                            side: BorderSide(color: p.border),
                            label: Text(
                              c,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: p.textPrimary,
                              ),
                            ),
                            deleteIcon: Icon(Icons.close_rounded,
                                size: 16, color: p.danger),
                            onDeleted: () {
                              store.removeQuickComment(c, isBar: isBarTab);
                              setD(() {});
                            },
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Terminé'),
              ),
            ],
          );
        },
      ),
    );
    ctrl.dispose();
  }

  Widget _buildFunctionTile({
    required PosPalette p,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool selected = false,
    String? badgeText,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.16) : p.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : p.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: p.textPrimary,
                          ),
                        ),
                      ),
                      if (badgeText != null)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: p.danger,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badgeText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: p.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final i18n = store.i18n;
    final p = FullTekThemes.paletteOf(context);
    final staff = store.currentStaff;
    final isKitchenOnly = staff?.role == PosRole.kitchen;

    // Build role-permitted views based on owner-granted permissions
    final tabs = <({
      String id,
      Key navKey,
      IconData icon,
      IconData selectedIcon,
      String label,
      String subtitle,
      Color color,
      bool badge,
      Widget view,
    })>[
      if (!isKitchenOnly &&
          (store.canCurrent(PosPermission.openRegister) ||
              store.canCurrent(PosPermission.takeOrders) ||
              staff?.role == PosRole.owner))
        (
          id: 'pos',
          navKey: const Key('nav_tab_pos'),
          icon: Icons.point_of_sale_outlined,
          selectedIcon: Icons.point_of_sale_rounded,
          label: i18n.t('nav_pos'),
          subtitle: 'Prise de commande & encaissement tactile',
          color: p.primary,
          badge: false,
          view: PosRegisterView(
            store: store,
            onOpenFloorPlan: () => setState(() => _activeViewId = 'floor'),
          ),
        ),
      if (!isKitchenOnly &&
          (store.canCurrent(PosPermission.openTable) ||
              store.canCurrent(PosPermission.serveTable) ||
              staff?.role == PosRole.owner))
        (
          id: 'floor',
          navKey: const Key('nav_tab_floor'),
          icon: Icons.table_restaurant_outlined,
          selectedIcon: Icons.table_restaurant_rounded,
          label: i18n.t('nav_floor'),
          subtitle: 'Tables, zones, réservations VIP & transfert',
          color: p.accent,
          badge: false,
          view: FloorPlanView(
            store: store,
            onTableSelected: () => setState(() => _activeViewId = 'pos'),
          ),
        ),
      (
        id: 'kds',
        navKey: const Key('nav_tab_kds'),
        icon: Icons.soup_kitchen_outlined,
        selectedIcon: Icons.soup_kitchen_rounded,
        label: i18n.t('nav_kds'),
        subtitle: 'Bons de préparation cuisine & grillades',
        color: p.warning,
        badge: true,
        view: KdsView(store: store),
      ),
      if (!isKitchenOnly && store.canCurrent(PosPermission.closeCashZ))
        (
          id: 'closing',
          navKey: const Key('nav_tab_closing'),
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long_rounded,
          label: i18n.t('nav_closing'),
          subtitle: 'Comptage caisse, impression Z & synchro',
          color: p.success,
          badge: false,
          view: ClosingZView(store: store),
        ),
      if (!isKitchenOnly && store.canCurrent(PosPermission.manageKarni))
        (
          id: 'karni',
          navKey: const Key('nav_tab_karni'),
          icon: Icons.menu_book_outlined,
          selectedIcon: Icons.menu_book_rounded,
          label: i18n.t('nav_karni'),
          subtitle: 'Carnet de crédit clients & règlements',
          color: p.vipGold,
          badge: false,
          view: KarniView(store: store),
        ),
      if (!isKitchenOnly &&
          (store.canCurrent(PosPermission.manageMenuStock) ||
              store.canCurrent(PosPermission.voidOrComp)))
        (
          id: 'menu_stock',
          navKey: const Key('nav_tab_menu_stock'),
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2_rounded,
          label: 'Menu & Stock',
          subtitle: 'Plats, familles, suppléments & ruptures 86',
          color: const Color(0xFF0EA5E9),
          badge: false,
          view: MenuStockView(store: store),
        ),
      if (!isKitchenOnly && store.canCurrent(PosPermission.viewStats))
        (
          id: 'dashboard',
          navKey: const Key('nav_tab_dashboard'),
          icon: Icons.analytics_outlined,
          selectedIcon: Icons.analytics_rounded,
          label: i18n.t('nav_dashboard'),
          subtitle: 'Chiffre d\'affaires, Food Cost & top plats',
          color: const Color(0xFF8B5CF6),
          badge: false,
          view: OwnerDashboardView(store: store),
        ),
    ];

    final preferredDefault = _defaultViewForRole(staff?.role);
    final activeTab = tabs.where((t) => t.id == _activeViewId).firstOrNull ??
        tabs.where((t) => t.id == preferredDefault).firstOrNull ??
        tabs.first;
    final body = activeTab.view;
    final occupiedCount =
        store.tables.where((t) => t.status == TableStatus.occupied).length;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: p.headerBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 64,
        shape: Border(bottom: BorderSide(color: p.border)),
        titleSpacing: 12,
        title: Row(
          children: [
            const FullTekLogo(size: 28, variant: 'Resto', animate: false),
            const SizedBox(width: 10),
            // Primary touch navigation pills: spacious, finger-friendly, always visible
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (!isKitchenOnly) ...[
                      if (tabs.any((t) => t.id == 'pos'))
                        _topTouchNavButton(
                          key: const Key('nav_tab_pos'),
                          p: p,
                          icon: Icons.point_of_sale_rounded,
                          label: store.lang == 'ar' ? 'الكاشير' : 'Caisse',
                          active: activeTab.id == 'pos',
                          onTap: () => setState(() => _activeViewId = 'pos'),
                        ),
                      if (tabs.any((t) => t.id == 'floor')) ...[
                        const SizedBox(width: 8),
                        _topTouchNavButton(
                          key: const Key('nav_tab_floor'),
                          p: p,
                          icon: Icons.table_restaurant_rounded,
                          label: occupiedCount > 0
                              ? '${store.lang == 'ar' ? 'الصالة' : 'Plan de salle'} ($occupiedCount)'
                              : (store.lang == 'ar' ? 'الصالة' : 'Plan de salle'),
                          active: activeTab.id == 'floor',
                          badgeColor: occupiedCount > 0 ? p.warning : null,
                          onTap: () => setState(() => _activeViewId = 'floor'),
                        ),
                      ],
                      const SizedBox(width: 8),
                      _topTouchNavButton(
                        key: const Key('nav_tab_kds'),
                        p: p,
                        icon: Icons.soup_kitchen_rounded,
                        label: store.activeKdsTickets().isNotEmpty
                            ? '${store.lang == 'ar' ? 'المطبخ' : 'Cuisine'} (${store.activeKdsTickets().length})'
                            : (store.lang == 'ar' ? 'المطبخ' : 'Cuisine'),
                        active: activeTab.id == 'kds',
                        badgeColor: store.activeKdsTickets().isNotEmpty
                            ? p.danger
                            : null,
                        onTap: () => setState(() => _activeViewId = 'kds'),
                      ),
                      if (tabs.any((t) => t.id == 'closing')) ...[
                        const SizedBox(width: 8),
                        _topTouchNavButton(
                          key: const Key('nav_tab_closing'),
                          p: p,
                          icon: Icons.receipt_long_rounded,
                          label: store.lang == 'ar' ? 'إغلاق Z' : 'Clôture Z',
                          active: activeTab.id == 'closing',
                          onTap: () =>
                              setState(() => _activeViewId = 'closing'),
                        ),
                      ],
                    ] else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: p.warning.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: p.warning),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.soup_kitchen_rounded,
                                size: 20, color: p.warning),
                            const SizedBox(width: 8),
                            Text(
                              'ÉCRAN CUISINE (KDS) · ${store.activeKdsTickets().length} bon(s) actif(s)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: p.warning,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Big Touch "Fonctions" button for Cashier / Manager / Owner
            if (!isKitchenOnly) ...[
              FilledButton.icon(
                key: const Key('open_functions_hub_btn'),
                style: FilledButton.styleFrom(
                  backgroundColor: p.surfaceAlt,
                  foregroundColor: p.textPrimary,
                  side: BorderSide(color: p.primary.withValues(alpha: 0.45)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _openFunctionsHub(tabs),
                icon: Icon(Icons.apps_rounded, size: 19, color: p.primary),
                label: const Text(
                  'Fonctions',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
                ),
              ),
              if (store.canCurrent(PosPermission.accessBackOffice) ||
                  staff?.role == PosRole.owner) ...[
                const SizedBox(width: 4),
                IconButton.filledTonal(
                  key: const Key('shell_back_office_btn'),
                  tooltip: 'Back-Office ERP',
                  style: IconButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF7C3AED).withValues(alpha: 0.16),
                    foregroundColor: const Color(0xFF7C3AED),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => BackOfficeScreen(
                          store: store,
                          operatorStaff: staff,
                        ),
                      ),
                    );
                  },
                  icon:
                      const Icon(Icons.dashboard_customize_rounded, size: 19),
                ),
              ],
            ],
            const SizedBox(width: 4),
            // Live incoming QR Orders & Waiter Calls alert pill (appears immediately when > 0)
            if (store.incomingQrTotalCount > 0) ...[
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    key: const Key('open_qr_menu_btn'),
                    tooltip:
                        'Menu QR · ${store.incomingQrTotalCount} nouvelle(s) demande(s)',
                    style: IconButton.styleFrom(
                      backgroundColor: p.danger.withValues(alpha: 0.18),
                      foregroundColor: p.danger,
                    ),
                    onPressed: _openQrMenuModal,
                    icon: const Icon(Icons.qr_code_2_rounded, size: 19),
                  ),
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: p.danger,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${store.incomingQrTotalCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
            ],
            // Compact In-app Zoom menu (like browser zoom: 80% .. 130%)
            PopupMenuButton<double>(
              key: const Key('zoom_menu_btn'),
              tooltip: 'Zoom interface (${(store.uiZoom * 100).round()}%)',
              onSelected: store.setUiZoom,
              itemBuilder: (_) => [0.80, 0.90, 1.00, 1.10, 1.20, 1.30]
                  .map(
                    (z) => PopupMenuItem<double>(
                      value: z,
                      child: Row(
                        children: [
                          Icon(
                            z < 1.0
                                ? Icons.zoom_out_rounded
                                : (z > 1.0
                                    ? Icons.zoom_in_rounded
                                    : Icons.center_focus_strong_rounded),
                            size: 18,
                            color: (store.uiZoom - z).abs() < 0.01
                                ? p.primary
                                : p.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(z * 100).round()}%${z == 1.0 ? ' (Normal)' : ''}',
                            style: TextStyle(
                              fontWeight: (store.uiZoom - z).abs() < 0.01
                                  ? FontWeight.w900
                                  : FontWeight.w600,
                              color: (store.uiZoom - z).abs() < 0.01
                                  ? p.primary
                                  : p.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.zoom_in_rounded,
                        color: (store.uiZoom - 1.0).abs() > 0.01
                            ? p.primary
                            : p.textPrimary,
                        size: 19),
                    Text(
                      '${(store.uiZoom * 100).round()}%',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: (store.uiZoom - 1.0).abs() > 0.01
                            ? p.primary
                            : p.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Theme quick button
            PopupMenuButton<FullTekThemeId>(
              key: const Key('shell_theme_menu'),
              tooltip: i18n.t('theme_label'),
              onSelected: store.setTheme,
              itemBuilder: (_) => store.availableThemes
                  .map(
                    (spec) => PopupMenuItem(
                      value: spec.id,
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: spec.palette.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(spec.label(store.lang)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.palette_rounded, color: p.primary, size: 22),
              ),
            ),
            // Fullscreen quick button in top bar
            IconButton(
              key: const Key('fullscreen_btn'),
              tooltip: _isFullscreen ? 'Quitter plein écran' : 'Mode plein écran',
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                final next = await toggleFullscreen();
                if (mounted) setState(() => _isFullscreen = next);
              },
              icon: Icon(
                _isFullscreen
                    ? Icons.fullscreen_exit_rounded
                    : Icons.fullscreen_rounded,
                color: p.primary,
                size: 24,
              ),
            ),
            // Large Touch Lock / Switch Staff button
            if (staff != null) ...[
              const SizedBox(width: 4),
              OutlinedButton.icon(
                key: const Key('lock_pos_btn'),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: store.lockPos,
                icon: const Icon(Icons.lock_outline_rounded, size: 17),
                label: Text(
                  i18n.t('lock_pos'),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ],
        ),
      ),
      body: Column(
        children: [
          if (store.trainingMode)
            Container(
              key: const Key('training_mode_banner'),
              width: double.infinity,
              color: p.warning.withValues(alpha: 0.18),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.school_rounded, size: 16, color: p.warning),
                  const SizedBox(width: 8),
                  Text(
                    i18n.t('training_banner'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: p.warning,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _topTouchNavButton({
    required Key key,
    required PosPalette p,
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
    Color? badgeColor,
  }) {
    return InkWell(
      key: key,
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: BoxDecoration(
          color: active ? p.primary : p.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? p.primary
                : (badgeColor?.withValues(alpha: 0.6) ?? p.border),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 17,
              color: active ? p.onPrimary : (badgeColor ?? p.textPrimary),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: active ? p.onPrimary : p.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDeliveryZonesSettingsDialog(BuildContext parentCtx) async {
    final store = widget.store;
    final p = FullTekThemes.paletteOf(parentCtx);
    final nameCtrl = TextEditingController();
    final feeCtrl = TextEditingController(text: '100');
    final freeCtrl = TextEditingController(
      text: store.freeDeliveryAboveMru.toStringAsFixed(0),
    );
    String? editingId;

    await showDialog<void>(
      context: parentCtx,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: p.surface,
          title: Row(
            children: [
              Icon(Icons.local_shipping_rounded, color: p.primary, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Paramétrage Zones & Frais de Livraison',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Appliquer des frais de livraison',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      store.deliveryFeeEnabled
                          ? 'Les frais de la zone choisie s\'ajoutent au ticket.'
                          : 'Désactivé : 0 MRU sur le ticket (réglé entre client et livreur).',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    value: store.deliveryFeeEnabled,
                    onChanged: (v) {
                      setD(() => store.setDeliveryFeeEnabled(v));
                    },
                  ),
                  const Divider(height: 14),
                  ...store.deliveryZones.map((z) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: p.surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: editingId == z.id ? p.primary : p.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              z.nameFr,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: p.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '${z.feeMru.toStringAsFixed(0)} MRU',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: p.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: 'Modifier',
                            visualDensity: VisualDensity.compact,
                            icon: Icon(Icons.edit_rounded,
                                size: 17, color: p.primary),
                            onPressed: () {
                              setD(() {
                                editingId = z.id;
                                nameCtrl.text = z.nameFr;
                                feeCtrl.text = z.feeMru.toStringAsFixed(0);
                              });
                            },
                          ),
                          if (store.deliveryZones.length > 1)
                            IconButton(
                              tooltip: 'Supprimer',
                              visualDensity: VisualDensity.compact,
                              icon: Icon(Icons.delete_outline_rounded,
                                  size: 17, color: p.danger),
                              onPressed: () {
                                setD(() {
                                  if (editingId == z.id) {
                                    editingId = null;
                                    nameCtrl.clear();
                                    feeCtrl.text = '100';
                                  }
                                  store.deleteDeliveryZone(z.id);
                                });
                              },
                            ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: nameCtrl,
                          decoration: InputDecoration(
                            labelText: editingId == null
                                ? 'Nouveau quartier / zone'
                                : 'Modifier la zone',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: feeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Tarif',
                            suffixText: 'MRU',
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        onPressed: () {
                          final n = nameCtrl.text.trim();
                          final f = double.tryParse(
                                  feeCtrl.text.trim().replaceAll(',', '.')) ??
                              100.0;
                          if (n.isEmpty) return;
                          setD(() {
                            store.saveDeliveryZone(
                              existingId: editingId,
                              nameFr: n,
                              feeMru: f,
                            );
                            editingId = null;
                            nameCtrl.clear();
                            feeCtrl.text = '100';
                          });
                        },
                        child: Text(editingId == null ? '+' : 'OK'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: freeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Livraison offerte dès (0 = désactivé)',
                            suffixText: 'MRU',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () {
                          final v = double.tryParse(
                                  freeCtrl.text.trim().replaceAll(',', '.')) ??
                              0.0;
                          setD(() => store.setFreeDeliveryAboveMru(v));
                        },
                        child: const Text('Appliquer'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Fermer'),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    feeCtrl.dispose();
    freeCtrl.dispose();
  }
}
