import 'package:flutter/material.dart';
import '../models/pos_models.dart';
import '../state/pos_store.dart';
import '../theme/fulltek_themes.dart';
import '../widgets/dish_image.dart';
import 'checkout_dialog.dart';
import 'modifiers_dialog.dart';
import 'remake_comp_dialog.dart';
import 'split_bill_dialog.dart';

class PosRegisterView extends StatefulWidget {
  final PosStore store;
  final VoidCallback onOpenFloorPlan;

  const PosRegisterView({
    super.key,
    required this.store,
    required this.onOpenFloorPlan,
  });

  @override
  State<PosRegisterView> createState() => _PosRegisterViewState();
}

class _PosRegisterViewState extends State<PosRegisterView> {
  String _selectedCategoryId = 'all';
  String _query = '';

  List<MenuItem> get _filteredItems {
    final q = _query.trim().toLowerCase();
    return widget.store.menuItems.where((m) {
      if (_selectedCategoryId != 'all' && m.categoryId != _selectedCategoryId) {
        return false;
      }
      if (q.isEmpty) return true;
      return m.nameFr.toLowerCase().contains(q) ||
          m.nameAr.toLowerCase().contains(q) ||
          m.nameEn.toLowerCase().contains(q) ||
          m.sku.toLowerCase().contains(q);
    }).toList();
  }

  Future<double?> _promptManualPrice(MenuItem item) async {
    final ctrl = TextEditingController(
      text: item.priceMru > 0 ? item.priceMru.toStringAsFixed(0) : '',
    );
    String? err;
    final res = await showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Prix manuel — ${item.label(widget.store.lang)}'),
          content: SizedBox(
            width: 320,
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
                  key: const Key('manual_price_input'),
                  controller: ctrl,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Montant (MRU) *',
                    suffixText: 'MRU',
                  ),
                  onSubmitted: (_) {
                    final v = double.tryParse(
                        ctrl.text.trim().replaceAll(',', '.'));
                    if (v == null || v <= 0) {
                      setD(() => err = 'Veuillez saisir un montant > 0.');
                      return;
                    }
                    Navigator.of(ctx).pop(v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(widget.store.i18n.t('cancel')),
            ),
            ElevatedButton(
              key: const Key('confirm_manual_price_btn'),
              onPressed: () {
                final v =
                    double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
                if (v == null || v <= 0) {
                  setD(() => err = 'Veuillez saisir un montant > 0.');
                  return;
                }
                Navigator.of(ctx).pop(v);
              },
              child: Text(widget.store.i18n.t('confirm')),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    return res;
  }

  Future<void> _onTapItem(MenuItem item) async {
    if (!item.available) return;
    double? customPrice;
    if (item.manualPrice) {
      customPrice = await _promptManualPrice(item);
      if (customPrice == null || !mounted) return;
    }
    if (!item.hasModifiers) {
      widget.store.addItemToActiveOrder(item, customPriceMru: customPrice);
      return;
    }
    final res = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => ModifiersDialog(item: item, lang: widget.store.lang),
    );
    if (res != null && mounted) {
      widget.store.addItemToActiveOrder(
        item,
        note: (res['note'] as String?)?.isEmpty == true
            ? null
            : res['note'] as String?,
        selectedModifiers:
            (res['modifiers'] as List<SelectedModifier>?) ?? const [],
        customPriceMru: customPrice,
      );
    }
  }

  Future<void> _openCheckout() async {
    final closed = await showDialog<PosOrder>(
      context: context,
      builder: (_) => CheckoutDialog(store: widget.store),
    );
    if (closed != null && mounted) {
      final receipt = buildReceiptForClosedOrder(closed, store: widget.store);
      showReceiptPreviewDialog(
        context,
        title: widget.store.i18n.t('receipt_preview'),
        subtitle: widget.store.i18n.t('open_drawer'),
        receiptText: receipt,
      );
    }
  }

  void _quickPaySingle(PaymentMethod method) {
    final order = widget.store.activeOrder;
    if (order == null || order.items.isEmpty) return;
    final closed = widget.store.completeCheckout([
      PaymentEntry(method: method, amountMru: order.netTotal),
    ]);
    if (closed != null && mounted) {
      showReceiptPreviewDialog(
        context,
        title: widget.store.i18n.t('receipt_preview'),
        subtitle: widget.store.i18n.t('open_drawer'),
        receiptText: buildReceiptForClosedOrder(closed, store: widget.store),
      );
    }
  }

  void _sendToKitchen() {
    final kdsTicket = widget.store.sendActiveOrderToKitchenAndPark();
    if (kdsTicket == null) return;
    showReceiptPreviewDialog(
      context,
      title: '${widget.store.i18n.t('kitchen_sent')} · Mise en attente',
      receiptText: kdsTicket,
    );
  }

  Future<void> _openWaitingOrdersDialog() async {
    final store = widget.store;
    final waiting = store.waitingOrders;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Commandes en attente & Tables (${waiting.length})'),
        content: SizedBox(
          width: 440,
          height: 360,
          child: waiting.isEmpty
              ? const Center(
                  child: Text('Aucune commande en attente.'),
                )
              : ListView.separated(
                  itemCount: waiting.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, idx) {
                    final o = waiting[idx];
                    final label = o.tableCode != null
                        ? 'Table ${o.tableCode}'
                        : '${o.serviceMode.emoji} ${o.serviceMode.label(store.lang)}';
                    final srv = o.serverName ?? o.staffName;
                    return ListTile(
                      leading: const Icon(Icons.hourglass_top_rounded),
                      title: Text(
                        '$label · ${o.ticketNumber}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        'Serveur: $srv · ${o.items.length} article(s) · ${o.netTotal.toStringAsFixed(0)} MRU',
                      ),
                      trailing: FilledButton.tonal(
                        onPressed: () {
                          store.resumeWaitingOrder(o.id);
                          Navigator.of(ctx).pop();
                        },
                        child: const Text('Ouvrir / Modifier'),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _openQuickCategoryImageDialog(MenuCategory cat) async {
    final store = widget.store;
    final imgCtrl = TextEditingController(text: cat.imageUrl);
    final nameCtrl = TextEditingController(text: cat.nameFr);
    final iconCtrl = TextEditingController(text: cat.icon);
    const presetImages = <String, String>{
      'Plats': 'assets/images/menu/resto_thieboudienne.jpg',
      'Grillades': 'assets/images/menu/resto_mechoui.jpg',
      'Burger/Sandwich': 'assets/images/menu/burger_chameau.jpg',
      'Poulet': 'assets/images/menu/poulet_braise.jpg',
      'Pizza/Snack': 'assets/images/menu/chawarma_royal.jpg',
      'Salades': 'assets/images/menu/salade_fattouch.jpg',
      'Boissons': 'assets/images/menu/jus_bissap.jpg',
      'Thé/Café': 'assets/images/menu/resto_atay.jpg',
      'Desserts': 'assets/images/menu/resto_dattes.jpg',
    };
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Catégorie · ${cat.nameFr}'),
          content: SizedBox(
            width: 390,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 64,
                        child: TextField(
                          controller: iconCtrl,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(labelText: 'Icône'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: nameCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Nom famille'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: imgCtrl,
                    onChanged: (_) => setD(() {}),
                    decoration: InputDecoration(
                      labelText: 'Image de la catégorie (URL ou Galerie)',
                      suffixIcon: imgCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () => setD(() => imgCtrl.clear()),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: presetImages.entries.map((e) {
                      return ChoiceChip(
                        label:
                            Text(e.key, style: const TextStyle(fontSize: 11)),
                        selected: imgCtrl.text.trim() == e.value,
                        onSelected: (_) => setD(() => imgCtrl.text = e.value),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                await store.saveCategory(
                  existingId: cat.id,
                  nameFr: nameCtrl.text,
                  icon: iconCtrl.text,
                  imageUrl: imgCtrl.text,
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    imgCtrl.dispose();
    nameCtrl.dispose();
    iconCtrl.dispose();
  }

  Future<void> _editNote(OrderItem line) async {
    final ctrl = TextEditingController(text: line.kitchenNote ?? '');
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.store.i18n.t('add_note')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Ex: Sans piment, bien cuit, extra sauce...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(widget.store.i18n.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: Text(widget.store.i18n.t('confirm')),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (saved != null) {
      widget.store.updateLineNote(line.lineId, saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final p = FullTekThemes.paletteOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 820;
        final catalogPane = _buildCatalogPane(store, p);
        final cartPane = _buildCartPane(store, p);
        if (wide) {
          final ticketLeft = store.themeSpec.ticketLeft;
          final ticketW = constraints.maxWidth >= 1200 ? 390.0 : 330.0;
          final ticket = SizedBox(width: ticketW, child: cartPane);
          final divider = VerticalDivider(width: 1, color: p.border);
          final catalog = Expanded(flex: 65, child: catalogPane);
          return Row(
            children: ticketLeft
                ? [ticket, divider, catalog]
                : [catalog, divider, ticket],
          );
        }
        return Column(
          children: [
            Expanded(flex: 55, child: catalogPane),
            Divider(height: 1, color: p.border),
            Expanded(flex: 45, child: cartPane),
          ],
        );
      },
    );
  }

  Widget _buildCatalogPane(PosStore store, PosPalette p) {
    final isNarrowPhone = MediaQuery.of(context).size.width < 600;
    if (isNarrowPhone) {
      return _catalogInner(store, p, showTopTabs: true);
    }
    final i18n = store.i18n;
    Widget railItem({
      required String id,
      required String icon,
      required String label,
      String imageUrl = '',
      MenuCategory? category,
    }) {
      final sel = _selectedCategoryId == id;
      final cleanImg = imageUrl.trim();
      Widget thumb;
      if (cleanImg.isNotEmpty) {
        final isNet = cleanImg.startsWith('http://') ||
            cleanImg.startsWith('https://') ||
            cleanImg.startsWith('data:');
        thumb = ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 46,
            height: 40,
            child: isNet
                ? Image.network(
                    cleanImg,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Center(child: Text(icon, style: const TextStyle(fontSize: 20))),
                  )
                : Image.asset(
                    cleanImg,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Center(child: Text(icon, style: const TextStyle(fontSize: 20))),
                  ),
          ),
        );
      } else {
        thumb = Text(icon, style: const TextStyle(fontSize: 22));
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: sel ? p.primary : p.surfaceAlt.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(p.radius),
          child: InkWell(
            key: Key('rail_cat_$id'),
            borderRadius: BorderRadius.circular(p.radius),
            onTap: () => setState(() => _selectedCategoryId = id),
            onLongPress: category != null
                ? () => _openQuickCategoryImageDialog(category)
                : null,
            child: Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Column(
                      children: [
                        thumb,
                        const SizedBox(height: 4),
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: sel ? p.onPrimary : p.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (category != null)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: InkWell(
                      onTap: () => _openQuickCategoryImageDialog(category),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.photo_camera_outlined,
                            size: 11, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        Container(
          width: 98,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: p.surface,
            border: Border(right: BorderSide(color: p.border)),
          ),
          child: ListView(
            children: [
              railItem(
                  id: 'all', icon: '🍽', label: i18n.t('all_categories')),
              ...store.categories.map((c) => railItem(
                    id: c.id,
                    icon: c.icon,
                    label: c.label(store.lang),
                    imageUrl: c.imageUrl,
                    category: c,
                  )),
            ],
          ),
        ),
        Expanded(child: _catalogInner(store, p, showTopTabs: false)),
      ],
    );
  }

  Widget _catalogInner(PosStore store, PosPalette p,
      {bool showTopTabs = false}) {
    final i18n = store.i18n;
    final items = _filteredItems;
    final showTabs = showTopTabs;
    final isDelivery = store.serviceMode == ServiceMode.delivery;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          // Search bar + Table switcher
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('menu_search_input'),
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: i18n.t('search_menu'),
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: widget.onOpenFloorPlan,
                icon: const Icon(Icons.table_restaurant_rounded, size: 18),
                label: Text(i18n.t('nav_floor')),
              ),
            ],
          ),

          // Nouakchott Delivery Zone Bar when in Delivery Mode
          if (isDelivery && store.deliveryZones.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(p.radius),
                border: Border.all(color: p.primary.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.delivery_dining_rounded,
                      size: 18, color: p.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        key: const Key('delivery_zone_dropdown'),
                        isDense: true,
                        value: (store.selectedDeliveryZone ??
                                store.deliveryZones.first)
                            .id,
                        items: store.deliveryZones.map((z) {
                          return DropdownMenuItem(
                            value: z.id,
                            child: Text(
                              '${z.label(store.lang)} (+${z.feeMru.toStringAsFixed(0)} MRU)',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: p.textPrimary),
                            ),
                          );
                        }).toList(),
                        onChanged: (id) {
                          if (id == null) return;
                          final z = store.deliveryZones
                              .firstWhere((e) => e.id == id);
                          store.setDeliveryZone(z);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    key: const Key('delivery_client_btn'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                    onPressed: () async {
                      final order = store.activeOrder;
                      final nameCtrl = TextEditingController(
                          text: order?.customerName ?? '');
                      final phoneCtrl = TextEditingController(
                          text: order?.customerPhone ?? '+222 ');
                      final addrCtrl = TextEditingController(
                          text: order?.deliveryAddress ?? '');
                      await showDialog<void>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Client & Adresse de livraison'),
                          content: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(
                                  key: const Key('delivery_name_input'),
                                  controller: nameCtrl,
                                  decoration: const InputDecoration(
                                      labelText: 'Nom du client'),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  key: const Key('delivery_phone_input'),
                                  controller: phoneCtrl,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                      labelText: 'Téléphone (+222...)'),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  key: const Key('delivery_address_input'),
                                  controller: addrCtrl,
                                  maxLines: 2,
                                  decoration: const InputDecoration(
                                      labelText: 'Quartier / Point de repère'),
                                ),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: Text(i18n.t('cancel')),
                            ),
                            ElevatedButton(
                              key: const Key('save_delivery_info_btn'),
                              onPressed: () {
                                store.setDeliveryInfo(
                                  customerName: nameCtrl.text.trim(),
                                  customerPhone: phoneCtrl.text.trim(),
                                  deliveryAddress: addrCtrl.text.trim(),
                                );
                                Navigator.of(ctx).pop();
                              },
                              child: Text(i18n.t('confirm')),
                            ),
                          ],
                        ),
                      );
                      nameCtrl.dispose();
                      phoneCtrl.dispose();
                      addrCtrl.dispose();
                    },
                    icon: const Icon(Icons.person_pin_circle_rounded, size: 16),
                    label: Text(
                      (store.activeOrder?.customerName?.isNotEmpty == true)
                          ? store.activeOrder!.customerName!
                          : 'Client / Adresse',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),

          if (showTabs)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: _selectedCategoryId == 'all',
                      onSelected: (_) =>
                          setState(() => _selectedCategoryId = 'all'),
                      label: Text(i18n.t('all_categories')),
                    ),
                  ),
                  ...store.categories.map((cat) {
                    final sel = _selectedCategoryId == cat.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: sel,
                        onSelected: (_) =>
                            setState(() => _selectedCategoryId = cat.id),
                        label: Text('${cat.icon} ${cat.label(store.lang)}'),
                      ),
                    );
                  }),
                ],
              ),
            ),
          if (showTabs) const SizedBox(height: 12),

          // Rich Bilingual Menu Grid (FR + AR, icon pill, TOP & ÉPUISÉ badges)
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth >= 1100
                    ? 5
                    : (c.maxWidth >= 780
                        ? 4
                        : (c.maxWidth >= 520 ? 3 : 2));
                final aspect = c.maxWidth < 400 ? 0.86 : 0.94;
                return GridView.builder(
                  itemCount: items.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: aspect,
                  ),
                  itemBuilder: (context, idx) {
                    final item = items[idx];
                    final oos = !item.available;
                    return Opacity(
                      opacity: oos ? 0.45 : 1.0,
                      child: Material(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(p.radius),
                        child: InkWell(
                          key: Key('menu_item_${item.id}'),
                          onTap: oos ? null : () => _onTapItem(item),
                          borderRadius: BorderRadius.circular(p.radius),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(p.radius),
                              border: Border.all(
                                  color: oos ? p.danger : p.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      DishImage(
                                        imageUrl: item.imageUrl,
                                        fallbackIcon: item.icon,
                                        backgroundColor: p.surfaceAlt,
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(
                                              (p.radius - 1).clamp(4, 24)),
                                        ),
                                      ),
                                      if (oos)
                                        Positioned(
                                          top: 6,
                                          right: 6,
                                          child: Container(
                                            key: Key('badge_oos_${item.id}'),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 7, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: p.danger,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              i18n.t('badge_out_of_stock'),
                                              style: const TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        )
                                      else if (item.isTop)
                                        Positioned(
                                          top: 6,
                                          right: 6,
                                          child: Container(
                                            key: Key('badge_top_${item.id}'),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 7, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: p.vipGold,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              i18n.t('badge_top'),
                                              style: const TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(9, 7, 9, 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.nameFr,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: p.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        item.nameAr,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: p.textMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${item.priceMru.toStringAsFixed(0)} ${i18n.t('mru')}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w900,
                                              color: p.primary,
                                            ),
                                          ),
                                          if (item.hasModifiers && !oos)
                                            Icon(Icons.tune_rounded,
                                                size: 15, color: p.accent),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartPane(PosStore store, PosPalette p) {
    final i18n = store.i18n;
    final order = store.activeOrder;
    final items = order?.items ?? const [];
    final hasUnsent = items.any((i) => !i.sentToKitchen);
    final canPay = items.isNotEmpty && store.canCurrent(PosPermission.checkout);

    return Container(
      color: p.surface,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ticket Header + Waiter Selector + Waiting Orders button
          Row(
            children: [
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: p.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    order?.tableCode != null
                        ? '${i18n.t('table_label')} ${order!.tableCode}'
                        : '${store.serviceMode.emoji} ${store.serviceMode.label(store.lang)}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: p.primary,
                        fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Server / Waiter selector dropdown
              if (store.staff.isNotEmpty)
                Flexible(
                  child: PopupMenuButton<String>(
                    key: const Key('select_server_menu'),
                    tooltip: 'Sélectionner le serveur qui gère la table',
                    onSelected: store.setActiveOrderServer,
                    itemBuilder: (_) => store.staff
                        .where((s) => s.isActive)
                        .map((s) => PopupMenuItem<String>(
                              value: s.name,
                              child: Text(
                                  '👤 ${s.name} (${s.role.label(store.lang)})'),
                            ))
                        .toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 5),
                      decoration: BoxDecoration(
                        color: p.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: p.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_outline_rounded,
                              size: 13, color: p.accent),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              order?.serverName ??
                                  store.currentStaff?.name ??
                                  'Serveur',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: p.textPrimary),
                            ),
                          ),
                          Icon(Icons.arrow_drop_down_rounded,
                              size: 15, color: p.textMuted),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 6),
              // Waiting Orders button ("En attente")
              InkWell(
                key: const Key('waiting_orders_btn'),
                borderRadius: BorderRadius.circular(8),
                onTap: _openWaitingOrdersDialog,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                  decoration: BoxDecoration(
                    color: store.waitingOrders.isNotEmpty
                        ? p.warning.withValues(alpha: 0.18)
                        : p.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: store.waitingOrders.isNotEmpty
                            ? p.warning
                            : p.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hourglass_top_rounded,
                          size: 13,
                          color: store.waitingOrders.isNotEmpty
                              ? p.warning
                              : p.textMuted),
                      const SizedBox(width: 3),
                      Text(
                        '${store.waitingOrders.length}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: store.waitingOrders.isNotEmpty
                              ? p.warning
                              : p.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: i18n.t('counter_sale'),
                onPressed: store.startCounterOrder,
                icon: Icon(Icons.add_shopping_cart_rounded,
                    size: 18, color: p.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 3 Service Modes (Sur place | Emporter | Livraison) right in the order panel
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: p.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: p.border),
            ),
            child: Row(
              children: ServiceMode.values.map((m) {
                final active = store.serviceMode == m;
                return Expanded(
                  child: InkWell(
                    key: Key('service_mode_${m.name}'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => store.setServiceMode(m),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active ? p.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${m.emoji} ${m.label(store.lang)}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: active ? p.onPrimary : p.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: p.border),

          // Cart Lines with square qty badge
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      i18n.t('cart_empty'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.textMuted, fontSize: 13),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: p.border),
                    itemBuilder: (context, idx) {
                      final line = items[idx];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: p.surfaceAlt,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Text('${line.quantity}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: p.primary)),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    line.item.label(store.lang),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: p.textPrimary,
                                      decoration: line.isComp
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  for (final m in line.selectedModifiers)
                                    Text('+ ${m.label(store.lang)}',
                                        style: TextStyle(
                                            fontSize: 10.5, color: p.accent)),
                                  const SizedBox(height: 2),
                                  Wrap(
                                    spacing: 6,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        line.isComp
                                            ? 'OFFERT'
                                            : '${line.lineTotal.toStringAsFixed(0)} ${i18n.t('mru')}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: line.isComp
                                              ? p.success
                                              : p.primary,
                                        ),
                                      ),
                                      InkWell(
                                        key: Key('line_mode_${line.lineId}'),
                                        borderRadius: BorderRadius.circular(6),
                                        onTap: () => store
                                            .toggleLineTakeaway(line.lineId),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: line.isTakeaway
                                                ? p.warning
                                                    .withValues(alpha: 0.16)
                                                : p.primary
                                                    .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            line.isTakeaway
                                                ? '🥡 Emporter'
                                                : '🍽 Sur place',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: line.isTakeaway
                                                  ? p.warning
                                                  : p.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (line.kitchenNote != null &&
                                      line.kitchenNote!.isNotEmpty)
                                    Text(
                                      '📝 ${line.kitchenNote}',
                                      style: TextStyle(
                                          fontSize: 11, color: p.warning),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: i18n.t('add_note'),
                              onPressed: () => _editNote(line),
                              icon: Icon(Icons.edit_note_rounded,
                                  size: 18, color: p.textMuted),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () =>
                                  store.updateLineQuantity(line.lineId, -1),
                              icon: const Icon(Icons.remove_circle_outline,
                                  size: 19),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () =>
                                  store.updateLineQuantity(line.lineId, 1),
                              icon: const Icon(Icons.add_circle_outline,
                                  size: 19),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Supprimer la ligne',
                              onPressed: () =>
                                  store.removeLineFromActiveOrder(line.lineId),
                              icon: Icon(Icons.delete_outline_rounded,
                                  size: 18, color: p.danger),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Totals + Dont TVA 16 % + Delivery Fee
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: p.surfaceAlt,
              borderRadius: BorderRadius.circular(p.radius),
              border: Border.all(color: p.border),
            ),
            child: Column(
              children: [
                _totalRow(i18n.t('subtotal'),
                    '${(order?.subtotal ?? 0).toStringAsFixed(0)} MRU', p),
                if ((order?.deliveryFeeMru ?? 0) > 0)
                  _totalRow(
                    i18n.t('delivery_fee'),
                    '+${order!.deliveryFeeMru.toStringAsFixed(0)} MRU',
                    p,
                    color: p.accent,
                  ),
                if ((order?.arbounDepositMru ?? 0) > 0)
                  _totalRow(
                    i18n.t('arboun_deducted'),
                    '-${order!.arbounDepositMru.toStringAsFixed(0)} MRU',
                    p,
                    color: p.vipGold,
                  ),
                _totalRow(
                  i18n.t('tva_included'),
                  '${order?.tvaAmountMru ?? 0} MRU',
                  p,
                  key: const Key('cart_tva_16_text'),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      i18n.t('total_to_pay'),
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: p.textPrimary),
                    ),
                    Text(
                      '${(order?.netTotal ?? 0).toStringAsFixed(0)} ${i18n.t('mru')}',
                      key: const Key('cart_net_total'),
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: p.primary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Action row: Cuisine | Diviser | Retour/Offert
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('send_kitchen_btn'),
                  onPressed: hasUnsent ? _sendToKitchen : null,
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 9)),
                  child: Text(i18n.t('send_kitchen'),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  key: const Key('split_bill_btn'),
                  onPressed: items.length >= 2
                      ? () => showDialog<void>(
                            context: context,
                            builder: (_) => SplitBillDialog(store: store),
                          )
                      : null,
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 9)),
                  child: Text(i18n.t('split_bill'),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  key: const Key('remake_comp_btn'),
                  onPressed: items.isNotEmpty
                      ? () => showDialog<void>(
                            context: context,
                            builder: (_) => RemakeCompDialog(store: store),
                          )
                      : null,
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 9)),
                  child: Text(i18n.t('remake_comp'),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 4 Colored 1-Click Payment Shortcuts (Maquettes: Cash | Bankily | Masrivi | Mixte)
          Row(
            children: [
              _quickPayChip(
                key: const Key('quick_pay_cash_btn'),
                label: 'Cash',
                color: const Color(0xFF059669),
                onTap: canPay ? () => _quickPaySingle(PaymentMethod.cash) : null,
              ),
              const SizedBox(width: 5),
              _quickPayChip(
                key: const Key('quick_pay_bankily_btn'),
                label: 'Bankily',
                color: const Color(0xFFD97706),
                onTap:
                    canPay ? () => _quickPaySingle(PaymentMethod.bankily) : null,
              ),
              const SizedBox(width: 5),
              _quickPayChip(
                key: const Key('quick_pay_masrivi_btn'),
                label: 'Masrivi',
                color: const Color(0xFF2563EB),
                onTap:
                    canPay ? () => _quickPaySingle(PaymentMethod.masrivi) : null,
              ),
              const SizedBox(width: 5),
              _quickPayChip(
                key: const Key('quick_pay_mixte_btn'),
                label: 'Mixte',
                color: const Color(0xFF7C3AED),
                onTap: canPay ? _openCheckout : null,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Primary Checkout Button
          ElevatedButton.icon(
            key: const Key('open_checkout_btn'),
            onPressed: canPay ? _openCheckout : null,
            icon: const Icon(Icons.point_of_sale_rounded),
            label: Text(
              '${i18n.t('checkout').toUpperCase()} · ${(order?.netTotal ?? 0).toStringAsFixed(0)} ${i18n.t('mru')}',
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickPayChip({
    required Key key,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Expanded(
      child: Material(
        color: onTap != null ? color : color.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: key,
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _totalRow(String label, String val, PosPalette p,
      {Color? color, Key? key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: p.textMuted)),
          Text(val,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color ?? p.textPrimary)),
        ],
      ),
    );
  }
}
