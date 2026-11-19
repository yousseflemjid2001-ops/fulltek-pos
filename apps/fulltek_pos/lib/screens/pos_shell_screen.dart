import 'package:flutter/material.dart';
import '../state/pos_store.dart';
import '../theme/fulltek_themes.dart';
import '../widgets/fulltek_logo.dart';
import 'closing_z_view.dart';
import 'floor_plan_view.dart';
import 'karni_view.dart';
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

    final body = switch (_tabIndex) {
      0 => PosRegisterView(
          store: store,
          onOpenFloorPlan: () => setState(() => _tabIndex = 1),
        ),
      1 => FloorPlanView(
          store: store,
          onTableSelected: () => setState(() => _tabIndex = 0),
        ),
      2 => KarniView(store: store),
      _ => ClosingZView(store: store),
    };

    return Scaffold(
      appBar: AppBar(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 62,
        shape: Border(bottom: BorderSide(color: p.border)),
        title: Row(
          children: [
            const FullTekLogo(size: 32, variant: 'Resto', animate: false),
            const SizedBox(width: 12),
            if (MediaQuery.of(context).size.width >= 900)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: p.success.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: p.success.withValues(alpha: 0.45)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_user_rounded,
                        size: 14, color: p.success),
                    const SizedBox(width: 5),
                    Text(
                      'Ed25519 · ${store.license.daysRemaining}${i18n.t('days_left')}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: p.success,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
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
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Chip(
                label: Text(store.lang.toUpperCase(),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 11.5)),
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
            itemBuilder: (_) => FullTekThemes.all.values
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

          // SyncQueue indicator
          IconButton(
            tooltip: i18n.t('sync_queue'),
            onPressed: () => setState(() => _tabIndex = 3),
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
      body: body,
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
            key: const Key('nav_tab_karni'),
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded, color: p.primary),
            label: i18n.t('nav_karni'),
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
}
