import 'package:flutter/material.dart';
import '../models/pos_models.dart';
import '../state/pos_store.dart';
import '../theme/fulltek_themes.dart';
import 'checkout_dialog.dart';
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
          return Row(
            children: [
              Expanded(flex: 65, child: catalogPane),
              VerticalDivider(width: 1, color: p.border),
              SizedBox(width: 380, child: cartPane),
            ],
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
    final i18n = store.i18n;
    final items = _filteredItems;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          // Search bar + Counter / Table switcher
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
          const SizedBox(height: 10),

          // Category chips
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
          const SizedBox(height: 12),

          // Menu Grid
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
                    childAspectRatio: 1.28,
                  ),
                  itemBuilder: (context, idx) {
                    final item = items[idx];
                    return Material(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        key: Key('menu_item_${item.id}'),
                        onTap: () => store.addItemToActiveOrder(item),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: p.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item.sku,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: p.textMuted,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: p.surfaceAlt,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      item.kitchenStation,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: p.accent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                item.label(store.lang),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: p.textPrimary,
                                ),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${item.priceMru.toStringAsFixed(0)} ${i18n.t('mru')}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: p.primary,
                                    ),
                                  ),
                                  Icon(Icons.add_circle_rounded,
                                      color: p.primary, size: 22),
                                ],
                              ),
                            ],
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
                      : i18n.t('counter_sale'),
                  style: TextStyle(
                      fontWeight: FontWeight.w900, color: p.primary),
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

          // Cart Lines
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (line.sentToKitchen)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(right: 5),
                                          child: Icon(Icons.local_fire_department,
                                              size: 14, color: p.warning),
                                        ),
                                      Expanded(
                                        child: Text(
                                          line.item.label(store.lang),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: p.textPrimary,
                                            decoration: line.isComp
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
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
                                  size: 20),
                            ),
                            Text('${line.quantity}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () =>
                                  store.updateLineQuantity(line.lineId, 1),
                              icon: const Icon(Icons.add_circle_outline,
                                  size: 20),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Totals
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: p.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.border),
            ),
            child: Column(
              children: [
                _totalRow(i18n.t('subtotal'),
                    '${(order?.subtotal ?? 0).toStringAsFixed(0)} MRU', p),
                if ((order?.arbounDepositMru ?? 0) > 0)
                  _totalRow(
                    i18n.t('arboun_deducted'),
                    '-${order!.arbounDepositMru.toStringAsFixed(0)} MRU',
                    p,
                    color: p.vipGold,
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
          const SizedBox(height: 10),

          // Secondary action row: Kitchen | Split | Remake/Comp
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('send_kitchen_btn'),
                  onPressed: hasUnsent ? _sendToKitchen : null,
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10)),
                  child: Text(i18n.t('send_kitchen'),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5)),
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
                      padding: const EdgeInsets.symmetric(vertical: 10)),
                  child: Text(i18n.t('split_bill'),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5)),
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
                      padding: const EdgeInsets.symmetric(vertical: 10)),
                  child: Text(i18n.t('remake_comp'),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Primary Checkout Button
          ElevatedButton.icon(
            key: const Key('open_checkout_btn'),
            onPressed: items.isNotEmpty && store.canCurrent(PosPermission.checkout)
                ? _openCheckout
                : null,
            icon: const Icon(Icons.point_of_sale_rounded),
            label: Text(
              '${i18n.t('checkout')} · ${(order?.netTotal ?? 0).toStringAsFixed(0)} ${i18n.t('mru')}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String val, PosPalette p, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: p.textMuted)),
          Text(val,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: color ?? p.textPrimary)),
        ],
      ),
    );
  }
}
