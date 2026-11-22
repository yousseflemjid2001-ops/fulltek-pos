import 'package:flutter/material.dart';
import '../models/pos_models.dart';
import '../services/fullscreen_helper.dart';
import '../state/pos_store.dart';
import '../theme/fulltek_themes.dart';
import '../widgets/fulltek_logo.dart';
import 'back_office_view.dart';
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
  int _tabIndex = 0;
  bool _isFullscreen = isFullscreenActive();

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final i18n = store.i18n;
    final p = FullTekThemes.paletteOf(context);
    final staff = store.currentStaff;
    final wide = MediaQuery.of(context).size.width >= 960;

    final tabs = <({
      String id,
      Key navKey,
      IconData icon,
      IconData selectedIcon,
      String label,
      bool badge,
      Widget view,
    })>[
      (
        id: 'pos',
        navKey: const Key('nav_tab_pos'),
        icon: Icons.point_of_sale_outlined,
        selectedIcon: Icons.point_of_sale_rounded,
        label: i18n.t('nav_pos'),
        badge: false,
        view: PosRegisterView(
          store: store,
          onOpenFloorPlan: () => setState(() => _tabIndex = 1),
        ),
      ),
      (
        id: 'floor',
        navKey: const Key('nav_tab_floor'),
        icon: Icons.table_restaurant_outlined,
        selectedIcon: Icons.table_restaurant_rounded,
        label: i18n.t('nav_floor'),
        badge: false,
        view: FloorPlanView(
          store: store,
          onTableSelected: () => setState(() => _tabIndex = 0),
        ),
      ),
      (
        id: 'kds',
        navKey: const Key('nav_tab_kds'),
        icon: Icons.soup_kitchen_outlined,
        selectedIcon: Icons.soup_kitchen_rounded,
        label: i18n.t('nav_kds'),
        badge: true,
        view: KdsView(store: store),
      ),
      if (store.canCurrent(PosPermission.manageKarni))
        (
          id: 'karni',
          navKey: const Key('nav_tab_karni'),
          icon: Icons.menu_book_outlined,
          selectedIcon: Icons.menu_book_rounded,
          label: i18n.t('nav_karni'),
          badge: false,
          view: KarniView(store: store),
        ),
      if (store.canCurrent(PosPermission.viewStats))
        (
          id: 'dashboard',
          navKey: const Key('nav_tab_dashboard'),
          icon: Icons.analytics_outlined,
          selectedIcon: Icons.analytics_rounded,
          label: i18n.t('nav_dashboard'),
          badge: false,
          view: OwnerDashboardView(store: store),
        ),
      if (store.canCurrent(PosPermission.closeCashZ))
        (
          id: 'closing',
          navKey: const Key('nav_tab_closing'),
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long_rounded,
          label: i18n.t('nav_closing'),
          badge: false,
          view: ClosingZView(store: store),
        ),
      if (store.canCurrent(PosPermission.manageMenuStock) ||
          store.canCurrent(PosPermission.voidOrComp))
        (
          id: 'menu_stock',
          navKey: const Key('nav_tab_menu_stock'),
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2_rounded,
          label: 'Menu & Stock',
          badge: false,
          view: MenuStockView(store: store),
        ),
    ];

    final safeIndex = _tabIndex.clamp(0, tabs.length - 1);
    final body = tabs[safeIndex].view;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: p.headerBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 62,
        shape: Border(bottom: BorderSide(color: p.border)),
        title: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FullTekLogo(size: 30, variant: 'Resto', animate: false),
              const SizedBox(width: 10),
              if (MediaQuery.of(context).size.width >= 1220) ...[
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Text(
                    store.tenantName,
                    key: const Key('shell_tenant_name'),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: p.textMuted),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              if (store.canCurrent(PosPermission.accessBackOffice) ||
                  staff?.role == PosRole.owner) ...[
                const SizedBox(width: 6),
                FilledButton.tonalIcon(
                  key: const Key('shell_back_office_btn'),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF7C3AED).withValues(alpha: 0.16),
                    foregroundColor: const Color(0xFF7C3AED),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    visualDensity: VisualDensity.compact,
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
                  icon: const Icon(Icons.dashboard_customize_rounded, size: 16),
                  label: const Text(
                    'Back-Office',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (wide) ...[
            // LAN & Cloud indicators + Refresh catalog
            _dotIndicator('LAN', store.lanConnected ? p.success : p.danger, p),
            const SizedBox(width: 6),
            _dotIndicator(
                'Cloud', store.cloudConnected ? p.accent : p.warning, p),
            IconButton(
              key: const Key('refresh_catalog_btn'),
              tooltip: i18n.t('refresh_catalog'),
              onPressed: store.isLoadingCatalog ? null : store.fetchCloudCatalog,
              icon: Icon(Icons.cloud_download_outlined,
                  size: 18, color: p.textPrimary),
            ),
          ],

          // Language quick toggle
          PopupMenuButton<String>(
            key: const Key('shell_lang_menu'),
            tooltip: 'Langue',
            onSelected: store.setLanguage,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'fr', child: Text('🇫🇷 Français')),
              PopupMenuItem(value: 'ar', child: Text('🇲🇷 العربية (RTL)')),
              PopupMenuItem(value: 'en', child: Text('🇬🇧 English')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Chip(
                label: Text(store.lang.toUpperCase(),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 11)),
                backgroundColor: p.surfaceAlt,
                side: BorderSide(color: p.border),
              ),
            ),
          ),

          // Theme 5-model selector
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
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.palette_rounded, color: p.primary),
            ),
          ),

          // Offline Ed25519 License Status & Unlock Button
          IconButton(
            key: const Key('offline_license_btn'),
            tooltip: 'Licence Hors-Ligne (${store.license.daysRemaining}j)',
            onPressed: () async {
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
            },
            icon: Icon(
              Icons.verified_user_rounded,
              color: store.license.daysRemaining <= 5 ? p.warning : p.success,
            ),
          ),

          // SyncQueue indicator
          IconButton(
            tooltip: i18n.t('sync_queue'),
            onPressed: () {
              final zIdx = tabs.indexWhere((t) => t.id == 'closing');
              if (zIdx != -1) setState(() => _tabIndex = zIdx);
            },
            icon: Badge(
              isLabelVisible: store.pendingSyncCount > 0,
              label: Text('${store.pendingSyncCount}'),
              child: Icon(Icons.sync_rounded, color: p.textPrimary),
            ),
          ),

          // Fullscreen toggle (Web & Tablet POS)
          IconButton(
            key: const Key('fullscreen_btn'),
            tooltip: _isFullscreen ? 'Quitter plein écran' : 'Mode plein écran',
            onPressed: () async {
              final next = await toggleFullscreen();
              if (mounted) setState(() => _isFullscreen = next);
            },
            icon: Icon(
              _isFullscreen
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
              color: p.textPrimary,
            ),
          ),

          // Staff chip + Lock
          if (staff != null)
            Padding(
              padding: const EdgeInsets.only(right: 10, left: 4),
              child: OutlinedButton.icon(
                key: const Key('lock_pos_btn'),
                onPressed: store.lockPos,
                icon: const Icon(Icons.lock_outline_rounded, size: 16),
                label: Text(
                  MediaQuery.of(context).size.width >= 600
                      ? '${staff.name} · ${i18n.t('lock_pos')}'
                      : i18n.t('lock_pos'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
        ],
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        backgroundColor: p.surface,
        indicatorColor: p.primary.withValues(alpha: 0.2),
        onDestinationSelected: (idx) => setState(() => _tabIndex = idx),
        destinations: tabs.map((t) {
          final iconWidget = t.badge
              ? Badge(
                  isLabelVisible: store.activeKdsTickets().isNotEmpty,
                  label: Text('${store.activeKdsTickets().length}'),
                  child: Icon(t.icon),
                )
              : Icon(t.icon);
          return NavigationDestination(
            key: t.navKey,
            icon: iconWidget,
            selectedIcon: Icon(t.selectedIcon, color: p.primary),
            label: t.label,
          );
        }).toList(),
      ),
    );
  }

  Widget _dotIndicator(String label, Color color, PosPalette p) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: p.textMuted),
        ),
      ],
    );
  }
}
