import 'package:flutter/material.dart';
import '../models/pos_models.dart';
import '../state/pos_store.dart';
import '../theme/fulltek_themes.dart';
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

  Future<void> _onTapItem(MenuItem item) async {
    if (!item.available) return;
    if (!item.hasModifiers) {
      widget.store.addItemToActiveOrder(item);
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
      );
    }
  }

  Future<void> _openCheckout() async {
    final closed = await showDialog<PosOrder>(
      context: context,
      builder: (_) => CheckoutDialog(store: widget.store),
    );
    if (closed != null && mounted) {
      final receipt = buildReceiptForClosedOrder(closed);
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
        receiptText: buildReceiptForClosedOrder(closed),
      );
    }
  }

  void _sendToKitchen() {
    final kdsTicket = widget.store.sendActiveOrderToKitchen();
    if (kdsTicket == null) return;
    showReceiptPreviewDialog(
      context,
      title: widget.store.i18n.t('kitchen_sent'),
      receiptText: kdsTicket,
    );
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
          final ticket = SizedBox(width: 390, child: cartPane);
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
    if (!store.themeSpec.categoriesAsRail) {
      return _catalogInner(store, p);
    }
    final i18n = store.i18n;
    Widget railItem(String id, String icon, String label) {
      final sel = _selectedCategoryId == id;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: sel ? p.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(p.radius),
          child: InkWell(
            key: Key('rail_cat_$id'),
            borderRadius: BorderRadius.circular(p.radius),
            onTap: () => setState(() => _selectedCategoryId = id),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
              child: Column(
                children: [
                  Text(icon, style: const TextStyle(fontSize: 21)),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: sel ? p.onPrimary : p.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        Container(
          width: 84,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: p.surface,
            border: Border(right: BorderSide(color: p.border)),
          ),
          child: ListView(
            children: [
              railItem('all', '🍽', i18n.t('all_categories')),
              ...store.categories
                  .map((c) => railItem(c.id, c.icon, c.label(store.lang))),
            ],
          ),
        ),
        Expanded(child: _catalogInner(store, p)),
      ],
    );
  }

  Widget _catalogInner(PosStore store, PosPalette p) {
    final i18n = store.i18n;
    final items = _filteredItems;
    final showTabs = !store.themeSpec.categoriesAsRail;
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
                final cols = c.maxWidth >= 780
                    ? 4
                    : (c.maxWidth >= 520 ? 3 : 2);
                return GridView.builder(
                  itemCount: items.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.12,
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
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(p.radius),
                              border: Border.all(
                                  color: oos ? p.danger : p.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: p.surfaceAlt,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(item.icon,
                                          style: const TextStyle(fontSize: 18)),
                                    ),
                                    if (oos)
                                      Container(
                                        key: Key('badge_oos_${item.id}'),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
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
                                      )
                                    else if (item.isTop)
                                      Container(
                                        key: Key('badge_top_${item.id}'),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color:
                                              p.vipGold.withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          i18n.t('badge_top'),
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w900,
                                            color: p.vipGold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.nameFr,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: p.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      item.nameAr,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: p.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${item.priceMru.toStringAsFixed(0)} ${i18n.t('mru')}',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w900,
                                        color: p.primary,
                                      ),
                                    ),
                                    if (item.hasModifiers && !oos)
                                      Icon(Icons.tune_rounded,
                                          size: 16, color: p.accent),
                                  ],
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
          // Ticket Header
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: p.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  order?.tableCode != null
                      ? '${i18n.t('table_label')} ${order!.tableCode}'
                      : '${store.serviceMode.emoji} ${store.serviceMode.label(store.lang)}',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: p.primary,
                      fontSize: 12.5),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order?.ticketNumber ?? '',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: p.textMuted),
                ),
              ),
              IconButton(
                tooltip: i18n.t('counter_sale'),
                onPressed: store.startCounterOrder,
                icon: Icon(Icons.add_shopping_cart_rounded,
                    size: 20, color: p.textMuted),
              ),
            ],
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
                                  Text(
                                    line.isComp
                                        ? 'OFFERT'
                                        : '${line.lineTotal.toStringAsFixed(0)} ${i18n.t('mru')}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: line.isComp ? p.success : p.primary,
                                    ),
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
