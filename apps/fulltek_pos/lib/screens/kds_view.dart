import 'dart:async';

import 'package:flutter/material.dart';

import '../models/pos_models.dart';
import '../state/pos_store.dart';
import '../theme/fulltek_themes.dart';

/// Écran Cuisine KDS (Maquette écran 3) : postes Tout / Grill / Cuisine / Bar,
/// tickets en cartes avec chrono d'urgence, « Plat prêt », et bascule
/// Rupture (ÉPUISÉ / 86) synchronisée avec la caisse.
class KdsView extends StatefulWidget {
  final PosStore store;
  const KdsView({super.key, required this.store});

  @override
  State<KdsView> createState() => _KdsViewState();
}

class _KdsViewState extends State<KdsView> {
  KdsStationFilter _filter = KdsStationFilter.all;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _stationLabel(KdsStationFilter f) {
    final i18n = widget.store.i18n;
    return switch (f) {
      KdsStationFilter.all => i18n.t('kds_station_all'),
      KdsStationFilter.grill => '🔥 ${i18n.t('kds_station_grill')}',
      KdsStationFilter.kitchen => '🍳 ${i18n.t('kds_station_kitchen')}',
      KdsStationFilter.bar => '🍹 ${i18n.t('kds_station_bar')}',
      KdsStationFilter.poulet => '🍗 Poulet',
      KdsStationFilter.pizza => '🍕 Pizza',
      KdsStationFilter.snack => '🥪 Snack',
      KdsStationFilter.traditional => '🍲 Traditionnel',
    };
  }

  List<KdsStationFilter> _visibleFilters(PosStore store) {
    const core = {
      KdsStationFilter.all,
      KdsStationFilter.grill,
      KdsStationFilter.kitchen,
      KdsStationFilter.bar,
    };
    final activeStations = <String>{
      for (final m in store.menuItems) m.kitchenStation.trim().toUpperCase(),
      for (final t in store.activeKdsTickets())
        for (final it in t.items) it.kitchenStation.trim().toUpperCase(),
    };
    return KdsStationFilter.values.where((f) {
      if (core.contains(f)) return true;
      return activeStations.contains(f.name.toUpperCase());
    }).toList();
  }

  Color _urgencyColor(KdsUrgency u, PosPalette p) => switch (u) {
        KdsUrgency.green => const Color(0xFF16A34A),
        KdsUrgency.orange => const Color(0xFFD97706),
        KdsUrgency.red => const Color(0xFFDC2626),
      };

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final i18n = store.i18n;
    final p = FullTekThemes.paletteOf(context);
    final tickets = store.activeKdsTickets(_filter);
    final out = store.outOfStockItems;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _visibleFilters(store).map((f) {
                      final sel = _filter == f;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          key: Key('kds_filter_${f.name}'),
                          label: Text(_stationLabel(f)),
                          selected: sel,
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              Text(
                '${i18n.t('kds_avg_time')}: ${store.kdsAveragePrepMinutes.toStringAsFixed(1)} min',
                style: TextStyle(color: p.textMuted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (out.isNotEmpty)
            Container(
              key: const Key('kds_rupture_banner'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: p.danger.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(p.radius),
                border: Border.all(color: p.danger.withValues(alpha: 0.5)),
              ),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Text('⚠ ${i18n.t('kds_rupture_banner')}',
                      style: TextStyle(
                          color: p.danger,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5)),
                  ...out.map(
                    (m) => ActionChip(
                      key: Key('kds_restock_${m.id}'),
                      label: Text('${m.label(store.lang)} ✓ ${i18n.t('kds_available')}'),
                      onPressed: () =>
                          store.toggleItemAvailability(m.id, available: true),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth >= 1100
                  ? 4
                  : (c.maxWidth >= 800 ? 3 : (c.maxWidth >= 520 ? 2 : 1));
              final ticketsGrid = tickets.isEmpty
                  ? Center(
                      child: Text(i18n.t('kds_empty'),
                          style: TextStyle(color: p.textMuted)),
                    )
                  : GridView.builder(
                      itemCount: tickets.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.82,
                      ),
                      itemBuilder: (context, idx) =>
                          _ticketCard(tickets[idx], p),
                    );
              if (c.maxWidth < 900) return ticketsGrid;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: ticketsGrid),
                  const SizedBox(width: 12),
                  SizedBox(width: 250, child: _stockPanel(store, p)),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _ticketCard(KdsTicket t, PosPalette p) {
    final store = widget.store;
    final i18n = store.i18n;
    final urgency = t.urgency();
    final color = _urgencyColor(urgency, p);
    final items = t.itemsForFilter(_filter);

    return Container(
      key: Key('kds_ticket_${t.id}'),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(p.radius),
        border: Border.all(color: p.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: color,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    '${t.serviceMode.emoji} ${t.tableOrTargetLabel}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13),
                  ),
                ),
                Text(
                  t.formattedElapsed(),
                  key: Key('kds_timer_${t.id}'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${t.orderCode} · ${t.staffName}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, color: p.textMuted)),
                if (t.isTraining)
                  Text('🎓',
                      style: TextStyle(fontSize: 11, color: p.warning)),
              ],
            ),
          ),
          Divider(height: 1, color: p.border),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: items.map((i) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: p.border)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${i.quantity}× ${i.label(store.lang)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: i.ready ? p.textMuted : p.textPrimary,
                          decoration:
                              i.ready ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      for (final m in i.selectedModifiers)
                        Text('+ ${m.label(store.lang)}',
                            style: TextStyle(fontSize: 11, color: p.accent)),
                      if (i.kitchenNote != null && i.kitchenNote!.isNotEmpty)
                        Text('📝 ${i.kitchenNote}',
                            style: TextStyle(fontSize: 11, color: p.warning)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: ElevatedButton(
              key: Key('kds_ready_${t.id}'),
              onPressed: () => store.markKdsTicketReady(
                t.id,
                station: _filter == KdsStationFilter.all
                    ? null
                    : _filter.name.toUpperCase(),
              ),
              child: Text(i18n.t('kds_dish_ready')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stockPanel(PosStore store, PosPalette p) {
    final i18n = store.i18n;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(p.radius),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(i18n.t('kds_rupture_86'),
              style: TextStyle(
                  fontWeight: FontWeight.w900, color: p.textPrimary)),
          const SizedBox(height: 6),
          Expanded(
            child: ListView(
              children: store.menuItems.map((m) {
                return SwitchListTile(
                  key: Key('kds_86_${m.id}'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(m.label(store.lang),
                      style: const TextStyle(fontSize: 12.5),
                      overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    m.available ? i18n.t('kds_available') : 'ÉPUISÉ',
                    style: TextStyle(
                        fontSize: 10.5,
                        color: m.available ? p.success : p.danger,
                        fontWeight: FontWeight.w800),
                  ),
                  value: m.available,
                  onChanged: (v) =>
                      store.toggleItemAvailability(m.id, available: v),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
