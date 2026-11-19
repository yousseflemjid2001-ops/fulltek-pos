import 'package:flutter/material.dart';
import '../models/pos_models.dart';
import '../state/pos_store.dart';
import '../theme/fulltek_themes.dart';

class FloorPlanView extends StatefulWidget {
  final PosStore store;
  final VoidCallback onTableSelected;

  const FloorPlanView({
    super.key,
    required this.store,
    required this.onTableSelected,
  });

  @override
  State<FloorPlanView> createState() => _FloorPlanViewState();
}

class _FloorPlanViewState extends State<FloorPlanView> {
  String _selectedZoneId = 'all';

  Future<void> _openNewReservationDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: '+222 ');
    final timeCtrl = TextEditingController(text: '21:00');
    final arbounCtrl = TextEditingController(text: '1500');
    String selectedTableId = widget.store.tables.last.id;
    int guests = 6;

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(widget.store.i18n.t('new_reservation')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nom client / Famille'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Téléphone'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedTableId,
                  decoration: const InputDecoration(labelText: 'Table / Khaima'),
                  items: widget.store.tables
                      .map((t) => DropdownMenuItem(
                            value: t.id,
                            child: Text('${t.code} (${t.capacity} places)'),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setD(() => selectedTableId = v);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: timeCtrl,
                        decoration: const InputDecoration(labelText: 'Heure'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: arbounCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: widget.store.i18n.t('arboun'),
                          suffixText: 'MRU',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(widget.store.i18n.t('cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                widget.store.addVipReservation(
                  customerName: nameCtrl.text,
                  phone: phoneCtrl.text,
                  tableId: selectedTableId,
                  guests: guests,
                  timeSlot: timeCtrl.text,
                  arbounMru: double.tryParse(arbounCtrl.text.trim()) ?? 0,
                );
                Navigator.of(ctx).pop(true);
              },
              child: Text(widget.store.i18n.t('confirm')),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    phoneCtrl.dispose();
    timeCtrl.dispose();
    arbounCtrl.dispose();
    if (created == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final i18n = store.i18n;
    final p = FullTekThemes.paletteOf(context);

    final visibleTables = store.tables
        .where((t) => _selectedZoneId == 'all' || t.zoneId == _selectedZoneId)
        .toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Zone Filter + New Reservation button
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    selected: _selectedZoneId == 'all',
                    onSelected: (_) => setState(() => _selectedZoneId = 'all'),
                    label: Text(i18n.t('floor_all')),
                  ),
                  ...store.zones.map((z) => ChoiceChip(
                        selected: _selectedZoneId == z.id,
                        onSelected: (_) =>
                            setState(() => _selectedZoneId = z.id),
                        label: Text(
                            '${z.isVip ? '👑 ' : ''}${z.label(store.lang)}'),
                      )),
                ],
              ),
              ElevatedButton.icon(
                key: const Key('new_vip_res_btn'),
                onPressed: _openNewReservationDialog,
                icon: const Icon(Icons.event_available_rounded, size: 18),
                label: Text(i18n.t('new_reservation')),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 820;
                final tablesGrid = _buildTablesGrid(store, visibleTables, p);
                final vipList = _buildReservationsPanel(store, p);
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 65, child: tablesGrid),
                      const SizedBox(width: 16),
                      SizedBox(width: 340, child: vipList),
                    ],
                  );
                }
                return Column(
                  children: [
                    Expanded(flex: 55, child: tablesGrid),
                    const SizedBox(height: 12),
                    Expanded(flex: 45, child: vipList),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTablesGrid(
      PosStore store, List<DiningTable> visibleTables, PosPalette p) {
    final i18n = store.i18n;
    return GridView.builder(
      itemCount: visibleTables.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 210,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.25,
      ),
      itemBuilder: (context, idx) {
        final t = visibleTables[idx];
        final order = store.orderForTable(t.id);
        final statusColor = switch (t.status) {
          TableStatus.free => p.success,
          TableStatus.occupied => p.warning,
          TableStatus.reserved => p.vipGold,
          TableStatus.billRequested => p.primary,
        };
        final statusText = switch (t.status) {
          TableStatus.free => i18n.t('status_free'),
          TableStatus.occupied => i18n.t('status_occupied'),
          TableStatus.reserved => i18n.t('status_reserved'),
          TableStatus.billRequested => i18n.t('status_bill'),
        };

        final shapeIcon = switch (t.shape) {
          TableShape.round => Icons.circle_outlined,
          TableShape.khaima => Icons.villa_rounded,
          TableShape.square => Icons.crop_square_rounded,
        };
        final isRound = t.shape == TableShape.round;

        return Material(
          color: p.surface,
          borderRadius: BorderRadius.circular(isRound ? 999 : p.radius),
          child: InkWell(
            key: Key('table_card_${t.id}'),
            onTap: () {
              store.openOrSelectTable(t.id);
              widget.onTableSelected();
            },
            borderRadius: BorderRadius.circular(isRound ? 999 : p.radius),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(isRound ? 999 : p.radius),
                border: Border.all(
                  color: t.status == TableStatus.free
                      ? p.border
                      : statusColor.withValues(alpha: 0.75),
                  width: t.status == TableStatus.free ? 1 : 1.8,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(shapeIcon, size: 14, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            t.code,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: p.textPrimary),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '👥 ${t.guests > 0 ? t.guests : t.capacity} ${i18n.t('guests')}',
                    style: TextStyle(fontSize: 12, color: p.textMuted),
                  ),
                  Text(
                    order != null
                        ? '${order.netTotal.toStringAsFixed(0)} ${i18n.t('mru')}'
                        : '—',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: p.primary),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReservationsPanel(PosStore store, PosPalette p) {
    final i18n = store.i18n;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_rounded, color: p.vipGold, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  i18n.t('vip_reservations'),
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: p.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              itemCount: store.reservations.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final r = store.reservations[idx];
                final table = store.tables.firstWhere((t) => t.id == r.tableId);
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: p.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              r.customerName,
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: p.textPrimary),
                            ),
                          ),
                          Text(
                            r.timeSlot,
                            style: TextStyle(
                                fontWeight: FontWeight.w800, color: p.vipGold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${table.code} · ${r.guests} ${i18n.t('guests')} · ${i18n.t('arboun')}: ${r.arbounMru.toStringAsFixed(0)} MRU',
                        style: TextStyle(fontSize: 12, color: p.textMuted),
                      ),
                      if (r.note != null && r.note!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(r.note!,
                            style: TextStyle(fontSize: 11.5, color: p.accent)),
                      ],
                      const SizedBox(height: 8),
                      if (r.status == 'confirmed')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            key: Key('seat_res_${r.id}'),
                            onPressed: () {
                              store.seatReservation(r.id);
                              widget.onTableSelected();
                            },
                            icon: const Icon(Icons.login_rounded, size: 16),
                            label: Text(i18n.t('seat_guests')),
                          ),
                        )
                      else
                        Text(
                          '✓ Installé',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, color: p.success),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
