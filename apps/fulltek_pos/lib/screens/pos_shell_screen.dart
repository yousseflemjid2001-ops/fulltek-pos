import 'package:flutter/material.dart';
import '../models/pos_models.dart';
import '../state/pos_store.dart';
import '../theme/fulltek_themes.dart';
import '../widgets/fulltek_logo.dart';
import 'closing_z_view.dart';
import 'floor_plan_view.dart';
import 'karni_view.dart';
import 'kds_view.dart';
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

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final i18n = store.i18n;
    final p = FullTekThemes.paletteOf(context);
    final staff = store.currentStaff;
    final wide = MediaQuery.of(context).size.width >= 960;

    final body = switch (_tabIndex) {
      0 => PosRegisterView(
          store: store,
          onOpenFloorPlan: () => setState(() => _tabIndex = 1),
        ),
      1 => FloorPlanView(
          store: store,
          onTableSelected: () => setState(() => _tabIndex = 0),
        ),
      2 => KdsView(store: store),
      3 => KarniView(store: store),
      4 => OwnerDashboardView(store: store),
      _ => ClosingZView(store: store),
    };

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
              if (wide) ...[
                // 3 Service Modes (Sur place | Emporter | Livraison)
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: p.surfaceAlt,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: p.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: ServiceMode.values.map((m) {
                      final active = store.serviceMode == m;
                      return InkWell(
                        key: Key('service_mode_${m.name}'),
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => store.setServiceMode(m),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: active ? p.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${m.emoji} ${m.label(store.lang)}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: active ? p.onPrimary : p.textMuted,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
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
            onPressed: () => setState(() => _tabIndex = 5),
            icon: Badge(
              isLabelVisible: store.pendingSyncCount > 0,
              label: Text('${store.pendingSyncCount}'),
              child: Icon(Icons.sync_rounded, color: p.textPrimary),
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
        selectedIndex: _tabIndex,
        backgroundColor: p.surface,
        indicatorColor: p.primary.withValues(alpha: 0.2),
        onDestinationSelected: (idx) => setState(() => _tabIndex = idx),
        destinations: [
          NavigationDestination(
            key: const Key('nav_tab_pos'),
            icon: const Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale_rounded, color: p.primary),
            label: i18n.t('nav_pos'),
          ),
          NavigationDestination(
            key: const Key('nav_tab_floor'),
            icon: const Icon(Icons.table_restaurant_outlined),
            selectedIcon:
                Icon(Icons.table_restaurant_rounded, color: p.primary),
            label: i18n.t('nav_floor'),
          ),
          NavigationDestination(
            key: const Key('nav_tab_kds'),
            icon: Badge(
              isLabelVisible: store.activeKdsTickets().isNotEmpty,
              label: Text('${store.activeKdsTickets().length}'),
              child: const Icon(Icons.soup_kitchen_outlined),
            ),
            selectedIcon: Icon(Icons.soup_kitchen_rounded, color: p.primary),
            label: i18n.t('nav_kds'),
          ),
          NavigationDestination(
            key: const Key('nav_tab_karni'),
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded, color: p.primary),
            label: i18n.t('nav_karni'),
          ),
          NavigationDestination(
            key: const Key('nav_tab_dashboard'),
            icon: const Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics_rounded, color: p.primary),
            label: i18n.t('nav_dashboard'),
          ),
          NavigationDestination(
            key: const Key('nav_tab_closing'),
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded, color: p.primary),
            label: i18n.t('nav_closing'),
          ),
        ],
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
