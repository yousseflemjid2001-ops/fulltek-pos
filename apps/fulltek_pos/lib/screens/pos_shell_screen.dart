import 'package:flutter/material.dart';
import '../models/pos_models.dart';
import '../services/fullscreen_helper.dart';
import '../state/pos_store.dart';
import '../theme/fulltek_themes.dart';
import '../widgets/fulltek_logo.dart';
import 'back_office_view.dart';
import 'checkout_dialog.dart';
import 'closing_z_view.dart';
import 'floor_plan_view.dart';
import 'karni_view.dart';
import 'kds_view.dart';
import 'menu_stock_view.dart';
import 'owner_dashboard_view.dart';
import 'pos_register_view.dart';

class PosShellScreen extends StatefulWidget {
  final PosStore store;
  const PosShellScreen({super.key, required this.store});

  @override
  State<PosShellScreen> createState() => _PosShellScreenState();
}

class _PosShellScreenState extends State<PosShellScreen> {
  String _activeViewId = 'pos';
  bool _isFullscreen = isFullscreenActive();

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
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 620),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: p.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.apps_rounded, color: p.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fonctions & Outils · ${store.tenantName}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: p.textPrimary,
                            ),
                          ),
                          Text(
                            'Opérateur : ${staff?.name ?? ''} (${staff?.role.label(store.lang) ?? ''}) — Boutons activés selon vos droits',
                            style: TextStyle(fontSize: 12.5, color: p.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close_rounded, size: 26),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: p.border),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.count(
                    crossAxisCount:
                        MediaQuery.of(ctx).size.width >= 680 ? 3 : 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.55,
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
                          subtitle: 'Fournisseurs, Achats, Factures, Compta',
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
                          store.canCurrent(PosPermission.manageMenuStock))
                        _buildFunctionTile(
                          p: p,
                          icon: Icons.account_balance_wallet_rounded,
                          title: 'Portefeuilles (16+)',
                          subtitle:
                              '${store.activeWallets.length} actifs · Bankily, Masrvi, BCI-Pay...',
                          color: const Color(0xFF059669),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            showWalletsConfigDialog(context, store);
                          },
                        ),
                      _buildFunctionTile(
                        p: p,
                        icon: Icons.cloud_sync_rounded,
                        title: 'Synchroniser Cloud',
                        subtitle: store.pendingSyncCount > 0
                            ? '${store.pendingSyncCount} élément(s) en attente'
                            : 'Catalogue & ventes à jour',
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
                ),
                const SizedBox(height: 12),
                // Option "Impression après Note" (save thermal paper)
                StatefulBuilder(
                  builder: (ctx, setOpt) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: p.surfaceAlt,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: p.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.print_outlined, color: p.primary, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Impression après Note (Ticket Final)',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                  color: p.textPrimary,
                                ),
                              ),
                              Text(
                                store.printReceiptAfterNote
                                    ? 'Activé : imprime automatiquement le Ticket Final après une Note.'
                                    : 'Désactivé : n\'imprime pas de 2ᵉ ticket après une Note (économie papier).',
                                style: TextStyle(
                                    fontSize: 11.5, color: p.textMuted),
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
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: p.border),
                const SizedBox(height: 12),
                // Secondary utility bar inside Functions Hub (Theme, Language, License, Fullscreen)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final l in const [
                          ('fr', '🇫🇷 FR'),
                          ('ar', '🇲🇷 AR'),
                          ('en', '🇬🇧 EN'),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(
                                l.$2,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800),
                              ),
                              selected: store.lang == l.$1,
                              onSelected: (_) {
                                store.setLanguage(l.$1);
                                Navigator.of(ctx).pop();
                              },
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
                            size: 18,
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
                            size: 18,
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
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.16) : p.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : p.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                if (badgeText != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: p.danger,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: p.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: p.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
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
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
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
}
