import 'dart:async';
import 'package:flutter/material.dart';
import '../models/pos_models.dart';
import '../state/pos_store.dart';
import '../theme/fulltek_themes.dart';
import '../widgets/touch_numpad.dart';
import 'shift_handover_dialog.dart';

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
  Timer? _chronoTimer;

  @override
  void initState() {
    super.initState();
    _chronoTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _chronoTimer?.cancel();
    super.dispose();
  }

  String _formatHm(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _formatChrono(DateTime since) {
    final diff = DateTime.now().difference(since);
    final mins = diff.inMinutes < 0 ? 0 : diff.inMinutes;
    if (mins < 60) return '${mins}m';
    final h = mins ~/ 60;
    final m = mins % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

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
                        onTap: () => showTouchNumpad(
                          context: ctx,
                          controller: arbounCtrl,
                          title: widget.store.i18n.t('arboun'),
                          showQuickBills: true,
                        ),
                        decoration: InputDecoration(
                          labelText: widget.store.i18n.t('arboun'),
                          suffixText: 'MRU',
                          suffixIcon:
                              const Icon(Icons.dialpad_rounded, size: 19),
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

  Future<void> _openTransferMergeDialog() async {
    final store = widget.store;
    final occupied = store.tables
        .where((t) =>
            t.activeOrderId != null &&
            store.orderForTable(t.id) != null)
        .toList();
    if (occupied.isEmpty) return;

    String fromId = occupied.first.id;
    String toId = store.tables.firstWhere((t) => t.id != fromId).id;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final targetTable = store.tables.firstWhere((t) => t.id == toId);
          final isMerge = targetTable.activeOrderId != null &&
              store.orderForTable(targetTable.id) != null;
          return AlertDialog(
            title: const Text('Transférer ou Fusionner une table'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  key: const Key('transfer_from_dropdown'),
                  initialValue: fromId,
                  decoration: const InputDecoration(labelText: 'Table source (occupée)'),
                  items: occupied
                      .map((t) => DropdownMenuItem(
                            value: t.id,
                            child: Text(t.code),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setD(() {
                        fromId = v;
                        if (toId == fromId) {
                          toId = store.tables
                              .firstWhere((t) => t.id != fromId)
                              .id;
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const Key('transfer_to_dropdown'),
                  initialValue: toId,
                  decoration: const InputDecoration(labelText: 'Table destination'),
                  items: store.tables
                      .where((t) => t.id != fromId)
                      .map((t) {
                        final occ = store.orderForTable(t.id) != null;
                        return DropdownMenuItem(
                          value: t.id,
                          child: Text('${t.code} (${occ ? "Occupée → Fusion" : "Libre → Transfert"})'),
                        );
                      })
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setD(() => toId = v);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(store.i18n.t('cancel')),
              ),
              ElevatedButton.icon(
                key: const Key('confirm_transfer_merge_btn'),
                onPressed: () {
                  final ok = isMerge
                      ? store.mergeTables(fromId, toId)
                      : store.transferTable(fromId, toId);
                  Navigator.of(ctx).pop();
                  if (ok && mounted) {
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isMerge
                            ? 'Tables fusionnées avec succès.'
                            : 'Table transférée avec succès.'),
                      ),
                    );
                  }
                },
                icon: Icon(isMerge ? Icons.merge_type_rounded : Icons.swap_horiz_rounded),
                label: Text(isMerge ? 'Fusionner' : 'Transférer'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openNewZoneDialog() async {
    final store = widget.store;
    final frCtrl = TextEditingController();
    final arCtrl = TextEditingController();
    bool isVip = false;
    String? err;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Nouvelle zone de salle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (err != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(err!,
                      style: const TextStyle(color: Colors.redAccent)),
                ),
              TextField(
                key: const Key('new_zone_name_input'),
                controller: frCtrl,
                decoration: const InputDecoration(
                    labelText: 'Nom de la zone (Français) *',
                    hintText: 'Ex: Étage, Jardin, Salon VIP...'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: arCtrl,
                decoration:
                    const InputDecoration(labelText: 'Nom (Arabe / عربي)'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Zone VIP / Khaima'),
                value: isVip,
                onChanged: (v) => setD(() => isVip = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(store.i18n.t('cancel')),
            ),
            ElevatedButton(
              key: const Key('save_zone_btn'),
              onPressed: () async {
                final res = await store.addDiningZone(
                  nameFr: frCtrl.text,
                  nameAr: arCtrl.text,
                  isVip: isVip,
                );
                if (res != null) {
                  setD(() => err = res);
                  return;
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: Text(store.i18n.t('confirm')),
            ),
          ],
        ),
      ),
    );
    frCtrl.dispose();
    arCtrl.dispose();
  }

  Future<void> _openTableDialog({DiningTable? existing}) async {
    final store = widget.store;
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    final capCtrl =
        TextEditingController(text: '${existing?.capacity ?? 4}');
    String zoneId = existing?.zoneId ??
        (store.zones.isNotEmpty ? store.zones.first.id : 'salle');
    if (!store.zones.any((z) => z.id == zoneId) && store.zones.isNotEmpty) {
      zoneId = store.zones.first.id;
    }
    TableShape shape = existing?.shape ?? TableShape.square;
    String? err;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(existing == null
              ? 'Nouvelle table'
              : 'Modifier table ${existing.code}'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (err != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(err!,
                          style: const TextStyle(color: Colors.redAccent)),
                    ),
                  TextField(
                    key: const Key('table_code_input'),
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Numéro / Code table *',
                      hintText: 'Ex: T7, VIP-4, TER-5...',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('table_capacity_input'),
                    controller: capCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de places (couverts) *',
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (store.zones.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: zoneId,
                      decoration: const InputDecoration(labelText: 'Zone'),
                      items: store.zones
                          .map((z) => DropdownMenuItem(
                                value: z.id,
                                child: Text(z.label(store.lang)),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setD(() => zoneId = v);
                      },
                    ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<TableShape>(
                    initialValue: shape,
                    decoration: const InputDecoration(labelText: 'Forme'),
                    items: const [
                      DropdownMenuItem(
                          value: TableShape.square, child: Text('Carrée')),
                      DropdownMenuItem(
                          value: TableShape.round, child: Text('Ronde')),
                      DropdownMenuItem(
                          value: TableShape.khaima, child: Text('Khaima VIP')),
                    ],
                    onChanged: (v) {
                      if (v != null) setD(() => shape = v);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (existing != null)
              TextButton.icon(
                key: const Key('delete_table_btn'),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: ctx,
                    builder: (c2) => AlertDialog(
                      title: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Colors.redAccent),
                          SizedBox(width: 8),
                          Expanded(child: Text('Supprimer la table')),
                        ],
                      ),
                      content: Text(
                        'Voulez-vous vraiment supprimer la table « ${existing.code} » ?\nCette action est irréversible.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(c2).pop(false),
                          child: Text(store.i18n.t('cancel')),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => Navigator.of(c2).pop(true),
                          child: const Text('Supprimer'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                  final res = await store.deleteDiningTable(existing.id);
                  if (res != null) {
                    setD(() => err = res);
                    return;
                  }
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.redAccent, size: 18),
                label: const Text('Supprimer',
                    style: TextStyle(color: Colors.redAccent)),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(store.i18n.t('cancel')),
            ),
            ElevatedButton(
              key: const Key('save_table_btn'),
              onPressed: () async {
                final cap = int.tryParse(capCtrl.text.trim()) ?? 4;
                final res = await store.saveDiningTable(
                  existingId: existing?.id,
                  code: codeCtrl.text,
                  zoneId: zoneId,
                  capacity: cap,
                  shape: shape,
                );
                if (res != null) {
                  setD(() => err = res);
                  return;
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: Text(store.i18n.t('confirm')),
            ),
          ],
        ),
      ),
    );
    codeCtrl.dispose();
    capCtrl.dispose();
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (store.canCurrent(PosPermission.voidOrComp) ||
                      store.canCurrent(PosPermission.manageMenuStock)) ...[
                    OutlinedButton.icon(
                      key: const Key('add_zone_btn'),
                      onPressed: _openNewZoneDialog,
                      icon: const Icon(Icons.add_location_alt_outlined,
                          size: 17),
                      label: const Text('+ Zone'),
                    ),
                    OutlinedButton.icon(
                      key: const Key('add_table_btn'),
                      onPressed: () => _openTableDialog(),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('+ Table'),
                    ),
                  ],
                  if (store.tables.any((t) => store.orderForTable(t.id) != null))
                    OutlinedButton.icon(
                      key: const Key('open_transfer_merge_btn'),
                      onPressed: _openTransferMergeDialog,
                      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: const Text('Transférer / Fusionner'),
                    ),
                  OutlinedButton.icon(
                    key: const Key('shift_transfer_btn'),
                    onPressed: () async {
                      await showShiftHandoverDialog(context, store);
                      if (mounted) setState(() {});
                    },
                    icon: const Icon(Icons.swap_horizontal_circle_outlined,
                        size: 18),
                    label: const Text('Transfert Service'),
                  ),
                  ElevatedButton.icon(
                    key: const Key('new_vip_res_btn'),
                    onPressed: _openNewReservationDialog,
                    icon: const Icon(Icons.event_available_rounded, size: 18),
                    label: Text(i18n.t('new_reservation')),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Active "Tables en cours" live bar (Montant, Serveur, Heure d'ouverture & Chrono occupé)
          Builder(
            builder: (context) {
              final activeTables = store.tables.where((t) {
                final o = store.orderForTable(t.id);
                return o != null && o.items.isNotEmpty;
              }).toList();
              if (activeTables.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: p.warning.withValues(alpha: 0.55), width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🔥 Tables en cours (${activeTables.length}) — Touchez pour consulter ou modifier à la caisse',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: p.warning),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: activeTables.map((t) {
                            final o = store.orderForTable(t.id)!;
                            final since = t.occupiedSince ?? o.createdAt;
                            final srv =
                                o.serverName ?? t.serverName ?? o.staffName;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () {
                                  store.openOrSelectTable(t.id);
                                  widget.onTableSelected();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: p.surfaceAlt,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: p.border),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Table ${t.code}',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12.5,
                                            color: p.textPrimary),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${o.netTotal.toStringAsFixed(0)} MRU',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12.5,
                                            color: p.primary),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '👤 $srv · 🕒 ${_formatHm(since)} · ⏱ ${_formatChrono(since)}',
                                        style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: p.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Color Legend for Floor Plan status clarity
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                _statusLegendChip('Libre', p.success, p),
                _statusLegendChip('En attente / Occupée', p.warning, p),
                _statusLegendChip('Note sortie', p.primary, p),
                _statusLegendChip('Réservée VIP', p.vipGold, p),
              ],
            ),
          ),
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
        final hasActiveOrder =
            (order != null && order.items.isNotEmpty) || t.arbounMru > 0;
        final effectiveStatus = (t.status == TableStatus.occupied && !hasActiveOrder)
            ? TableStatus.free
            : ((t.status == TableStatus.free && hasActiveOrder)
                ? TableStatus.occupied
                : t.status);
        final since = t.occupiedSince ?? order?.createdAt;
        final srv = order?.serverName ?? t.serverName;

        final statusColor = switch (effectiveStatus) {
          TableStatus.free => p.success,
          TableStatus.occupied => p.warning,
          TableStatus.reserved => p.vipGold,
          TableStatus.billRequested => p.primary,
        };
        final statusText = switch (effectiveStatus) {
          TableStatus.free => i18n.t('status_free'),
          TableStatus.occupied =>
              (order?.status == 'waiting_kitchen' ||
                      (order?.items.any((i) => i.sentToKitchen) ?? false))
                  ? '⏳ En attente'
                  : i18n.t('status_occupied'),
          TableStatus.reserved => i18n.t('status_reserved'),
          TableStatus.billRequested => '🧾 Note',
        };

        final shapeIcon = switch (t.shape) {
          TableShape.round => Icons.circle_outlined,
          TableShape.khaima => Icons.villa_rounded,
          TableShape.square => Icons.crop_square_rounded,
        };
        final isRound = t.shape == TableShape.round;

        return Material(
          color: effectiveStatus == TableStatus.free
              ? p.surface
              : Color.alphaBlend(
                  statusColor.withValues(alpha: 0.14), p.surface),
          borderRadius: BorderRadius.circular(isRound ? 999 : p.radius),
          child: InkWell(
            key: Key('table_card_${t.id}'),
            onTap: () {
              store.openOrSelectTable(t.id);
              widget.onTableSelected();
            },
            borderRadius: BorderRadius.circular(isRound ? 999 : p.radius),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(isRound ? 999 : p.radius),
                border: Border.all(
                  color: effectiveStatus == TableStatus.free
                      ? p.border
                      : statusColor,
                  width: effectiveStatus == TableStatus.free ? 1 : 2.2,
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
                    '👥 ${t.guests > 0 ? t.guests : t.capacity} ${i18n.t('guests')}${hasActiveOrder && srv != null ? ' · 👤 $srv' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: p.textMuted),
                  ),
                  if (hasActiveOrder && since != null)
                    Text(
                      '🕒 ${_formatHm(since)} · ⏱ ${_formatChrono(since)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: p.warning,
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        (order != null && order.items.isNotEmpty)
                            ? '${order.netTotal.toStringAsFixed(0)} ${i18n.t('mru')} (${order.items.length})'
                            : '—',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: p.primary),
                      ),
                      if (store.canCurrent(PosPermission.voidOrComp) ||
                          store.canCurrent(PosPermission.manageMenuStock))
                        InkWell(
                          key: Key('edit_table_${t.id}'),
                          onTap: () => _openTableDialog(existing: t),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: Icon(Icons.edit_outlined,
                                size: 16, color: p.textMuted),
                          ),
                        ),
                    ],
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
    // Hide completed/cancelled reservations and seated ones whose table is already free
    final visibleReservations = store.reservations.where((r) {
      if (r.status == 'completed' || r.status == 'cancelled') return false;
      if (r.status == 'seated') {
        final tbl = store.tables.where((t) => t.id == r.tableId).firstOrNull;
        return tbl != null && tbl.status != TableStatus.free;
      }
      return true;
    }).toList();

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
                  '${i18n.t('vip_reservations')} (${visibleReservations.length})',
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
            child: visibleReservations.isEmpty
                ? Center(
                    child: Text(
                      'Aucune réservation en attente.',
                      style: TextStyle(fontSize: 12.5, color: p.textMuted),
                    ),
                  )
                : ListView.separated(
                    itemCount: visibleReservations.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, idx) {
                      final r = visibleReservations[idx];
                      final table = store.tables.firstWhere(
                        (t) => t.id == r.tableId,
                        orElse: () => store.tables.first,
                      );
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

  Widget _statusLegendChip(String label, Color color, PosPalette p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: p.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
