import 'package:flutter/material.dart';
import '../models/pos_models.dart';
import '../state/pos_store.dart';
import '../theme/fulltek_themes.dart';
import '../widgets/dish_image.dart';
import '../widgets/touch_keyboard.dart';
import '../widgets/touch_numpad.dart';
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
  String? _selectedLineId;

  Future<void> _openQuantityDialog(OrderItem line) async {
    final store = widget.store;
    final p = FullTekThemes.paletteOf(context);
    String digits = '';
    String? error;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final currentVal = digits.isEmpty ? '${line.quantity}' : digits;
          void tapDigit(String d) {
            setD(() {
              error = null;
              if (digits.length < 4) digits += d;
            });
          }

          void applyQty(int qty) {
            if (qty <= 0) {
              setD(() => error = 'Quantité minimale : 1');
              return;
            }
            final ok = store.setLineQuantity(line.lineId, qty);
            if (!ok) {
              setD(() => error = store.lastVoidError ??
                  'Impossible de modifier la quantité.');
              return;
            }
            Navigator.of(ctx).pop();
          }

          Widget numBtn(String label, {VoidCallback? onTap, Color? bg}) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    key: Key('qty_pad_$label'),
                    onPressed: onTap ?? () => tapDigit(label),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: bg ?? p.surfaceAlt,
                      foregroundColor: p.textPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: p.border),
                      ),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          return AlertDialog(
            backgroundColor: p.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: p.border),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quantité · ${line.item.label(store.lang)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    color: p.textPrimary,
                  ),
                ),
                Text(
                  'Prix unitaire : ${line.unitPriceWithModifiers.toStringAsFixed(0)} MRU',
                  style: TextStyle(fontSize: 12, color: p.textMuted),
                ),
              ],
            ),
            content: SizedBox(
              width: 310,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: p.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: p.primary, width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Quantité :',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: p.textMuted,
                          ),
                        ),
                        Text(
                          currentVal,
                          key: const Key('qty_dialog_display'),
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: p.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [2, 3, 5, 10, 15, 20]
                        .map((preset) => ActionChip(
                              key: Key('qty_preset_$preset'),
                              label: Text(
                                '×$preset',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800),
                              ),
                              onPressed: () => applyQty(preset),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [numBtn('1'), numBtn('2'), numBtn('3')]),
                  Row(children: [numBtn('4'), numBtn('5'), numBtn('6')]),
                  Row(children: [numBtn('7'), numBtn('8'), numBtn('9')]),
                  Row(children: [
                    numBtn('C',
                        bg: p.danger.withValues(alpha: 0.14),
                        onTap: () => setD(() {
                              digits = '';
                              error = null;
                            })),
                    numBtn('0'),
                    numBtn('⌫',
                        bg: p.warning.withValues(alpha: 0.14),
                        onTap: () => setD(() {
                              error = null;
                              if (digits.isNotEmpty) {
                                digits =
                                    digits.substring(0, digits.length - 1);
                              }
                            })),
                  ]),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: TextStyle(
                        color: p.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(store.i18n.t('cancel')),
              ),
              ElevatedButton.icon(
                key: const Key('confirm_qty_btn'),
                onPressed: () {
                  final parsed = int.tryParse(currentVal) ?? line.quantity;
                  applyQty(parsed);
                },
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Valider'),
              ),
            ],
          );
        },
      ),
    );
  }

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
                  const SizedBox(height: 12),
                  TouchNumpadGrid(
                    keyHeight: 46,
                    onDigit: (d) => setD(() {
                      ctrl.text = (ctrl.text == '0') ? d : '${ctrl.text}$d';
                      err = null;
                    }),
                    onBackspace: () => setD(() {
                      if (ctrl.text.isNotEmpty) {
                        ctrl.text =
                            ctrl.text.substring(0, ctrl.text.length - 1);
                      }
                    }),
                    onClear: () => setD(() => ctrl.text = ''),
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

  void _handlePostCheckoutReceipt(PosOrder closed) {
    final receipt = buildReceiptForClosedOrder(closed, store: widget.store);
    final changeBanner = closed.changeDue > 0
        ? '💰 MONNAIE À RENDRE : ${closed.changeDue.toStringAsFixed(0)} MRU'
        : widget.store.i18n.t('open_drawer');
    if (widget.store.shouldAutoPrintLastReceipt) {
      showReceiptPreviewDialog(
        context,
        title: 'Ticket Final · ${widget.store.i18n.t('receipt_preview')}',
        subtitle: changeBanner,
        receiptText: receipt,
        logoDataUrl: widget.store.receiptLogoDataUrl,
        logoPosition: widget.store.receiptLogoPosition,
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          closed.changeDue > 0
              ? '✅ Encaissé · 💰 MONNAIE À RENDRE : ${closed.changeDue.toStringAsFixed(0)} MRU (Note déjà sortie)'
              : '✅ Encaissé (${closed.netTotal.toStringAsFixed(0)} MRU) · Note déjà sortie (ticket non réimprimé)',
        ),
        action: SnackBarAction(
          label: 'Imprimer Ticket Final',
          onPressed: () {
            if (!mounted) return;
            showReceiptPreviewDialog(
              context,
              title: 'Ticket Final · ${widget.store.i18n.t('receipt_preview')}',
              subtitle: changeBanner,
              receiptText: receipt,
              logoDataUrl: widget.store.receiptLogoDataUrl,
              logoPosition: widget.store.receiptLogoPosition,
            );
          },
        ),
      ),
    );
  }

  Future<void> _openCheckout() async {
    final closed = await showDialog<PosOrder>(
      context: context,
      builder: (_) => CheckoutDialog(store: widget.store),
    );
    if (closed != null && mounted) {
      _handlePostCheckoutReceipt(closed);
    }
  }

  void _quickPaySingle(PaymentMethod method) {
    final order = widget.store.activeOrder;
    if (order == null || order.items.isEmpty) return;
    final closed = widget.store.completeCheckout([
      PaymentEntry(method: method, amountMru: order.netTotal),
    ]);
    if (closed != null && mounted) {
      _handlePostCheckoutReceipt(closed);
    }
  }

  Future<bool> _openDeliveryClientDriverDialog({
    bool isBeforeKitchen = false,
  }) async {
    final store = widget.store;
    final i18n = store.i18n;
    final p = FullTekThemes.paletteOf(context);
    final order = store.activeOrder;
    final nameCtrl = TextEditingController(text: order?.customerName ?? '');
    final phoneCtrl =
        TextEditingController(text: order?.customerPhone ?? '+222 ');
    final addrCtrl = TextEditingController(text: order?.deliveryAddress ?? '');
    final driverCtrl =
        TextEditingController(text: order?.deliveryDriverName ?? '');
    DeliveryZone? selectedZone = order?.deliveryZone ??
        store.selectedDeliveryZone ??
        (store.deliveryZones.isNotEmpty ? store.deliveryZones.first : null);
    final initialFee = (order != null &&
            order.serviceMode == ServiceMode.delivery &&
            order.deliveryFeeMru > 0)
        ? order.deliveryFeeMru
        : (selectedZone?.feeMru ?? 100.0);
    final feeCtrl = TextEditingController(text: initialFee.toStringAsFixed(0));

    final driverSuggestions = <String>{
      for (final s in store.staff.where((s) => s.isActive)) s.name,
      'Livreur Moto 1',
      'Livreur Moto 2',
    }.toList();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: p.surface,
          title: Row(
            children: [
              Icon(Icons.delivery_dining_rounded, color: p.primary, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isBeforeKitchen
                      ? 'Informations Livraison avant cuisine'
                      : 'Livraison : Client, Zone & Livreur',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (store.deliveryZones.isNotEmpty && selectedZone != null) ...[
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedZone!.id,
                            decoration: const InputDecoration(
                              labelText: 'Zone de livraison',
                              prefixIcon: Icon(Icons.map_outlined),
                            ),
                            items: store.deliveryZones
                                .map(
                                  (z) => DropdownMenuItem(
                                    value: z.id,
                                    child: Text(
                                      '${z.label(store.lang)} (${z.feeMru.toStringAsFixed(0)} MRU)',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (id) {
                              if (id == null) return;
                              setD(() {
                                selectedZone = store.deliveryZones
                                    .firstWhere((e) => e.id == id);
                                feeCtrl.text =
                                    selectedZone!.feeMru.toStringAsFixed(0);
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            key: const Key('delivery_custom_fee_input'),
                            controller: feeCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Frais (MRU)',
                              suffixText: 'MRU',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    key: const Key('delivery_name_input'),
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nom du client',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('delivery_phone_input'),
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Téléphone (+222...)',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      suffixIcon: IconButton(
                        tooltip: 'Pavé tactile',
                        icon: const Icon(Icons.dialpad_rounded, size: 19),
                        onPressed: () => showTouchNumpad(
                          context: ctx,
                          controller: phoneCtrl,
                          title: 'Téléphone client',
                          allowDecimal: false,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('delivery_address_input'),
                    controller: addrCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Quartier / Point de repère',
                      prefixIcon: Icon(Icons.place_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('delivery_driver_input'),
                    controller: driverCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Livreur assigné',
                      hintText: 'Ex: Moussa, Livreur Moto 1...',
                      prefixIcon: Icon(Icons.two_wheeler_rounded),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: driverSuggestions.take(6).map((d) {
                      final sel = driverCtrl.text.trim() == d;
                      return ActionChip(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: sel
                            ? p.primary.withValues(alpha: 0.2)
                            : p.surfaceAlt,
                        side: BorderSide(color: sel ? p.primary : p.border),
                        label: Text(
                          '🏍️ $d',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: p.textPrimary,
                          ),
                        ),
                        onPressed: () => setD(() => driverCtrl.text = d),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(i18n.t('cancel')),
            ),
            ElevatedButton.icon(
              key: const Key('save_delivery_info_btn'),
              onPressed: () {
                final drv = driverCtrl.text.trim();
                final parsedFee = double.tryParse(
                    feeCtrl.text.trim().replaceAll(',', '.'));
                store.setDeliveryInfo(
                  customerName: nameCtrl.text.trim(),
                  customerPhone: phoneCtrl.text.trim(),
                  deliveryAddress: addrCtrl.text.trim(),
                  deliveryDriverName: drv.isEmpty ? null : drv,
                  clearDeliveryDriver: drv.isEmpty,
                  zone: selectedZone,
                  customDeliveryFeeMru: parsedFee,
                );
                Navigator.of(ctx).pop(true);
              },
              icon: const Icon(Icons.check_rounded, size: 18),
              label: Text(isBeforeKitchen
                  ? 'Valider & Envoyer Cuisine'
                  : i18n.t('confirm')),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    phoneCtrl.dispose();
    addrCtrl.dispose();
    driverCtrl.dispose();
    feeCtrl.dispose();
    return saved == true;
  }

  Future<void> _openManageDeliveryZonesDialog() async {
    final store = widget.store;
    final p = FullTekThemes.paletteOf(context);
    final nameCtrl = TextEditingController();
    final feeCtrl = TextEditingController(text: '100');
    final freeCtrl = TextEditingController(
      text: store.freeDeliveryAboveMru.toStringAsFixed(0),
    );
    String? editingId;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: p.surface,
          title: Row(
            children: [
              Icon(Icons.local_shipping_rounded, color: p.primary, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Tarifs & Zones de Livraison',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Adaptez les quartiers et tarifs (MRU) selon la localisation de votre restaurant :',
                    style: TextStyle(fontSize: 12, color: p.textMuted),
                  ),
                  const SizedBox(height: 10),
                  ...store.deliveryZones.map((z) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: p.surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: editingId == z.id ? p.primary : p.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              z.nameFr,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: p.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: p.primary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${z.feeMru.toStringAsFixed(0)} MRU',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: p.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: 'Modifier',
                            visualDensity: VisualDensity.compact,
                            icon: Icon(Icons.edit_rounded,
                                size: 17, color: p.primary),
                            onPressed: () {
                              setD(() {
                                editingId = z.id;
                                nameCtrl.text = z.nameFr;
                                feeCtrl.text = z.feeMru.toStringAsFixed(0);
                              });
                            },
                          ),
                          if (store.deliveryZones.length > 1)
                            IconButton(
                              tooltip: 'Supprimer',
                              visualDensity: VisualDensity.compact,
                              icon: Icon(Icons.delete_outline_rounded,
                                  size: 17, color: p.danger),
                              onPressed: () {
                                setD(() {
                                  if (editingId == z.id) {
                                    editingId = null;
                                    nameCtrl.clear();
                                    feeCtrl.text = '100';
                                  }
                                  store.deleteDeliveryZone(z.id);
                                });
                              },
                            ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          key: const Key('manage_dz_name_input'),
                          controller: nameCtrl,
                          decoration: InputDecoration(
                            labelText: editingId == null
                                ? 'Nouveau quartier / zone'
                                : 'Modifier le nom de zone',
                            hintText: 'Ex: Tevragh Zeina Nord...',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          key: const Key('manage_dz_fee_input'),
                          controller: feeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Tarif',
                            suffixText: 'MRU',
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        key: const Key('manage_dz_save_btn'),
                        onPressed: () {
                          final n = nameCtrl.text.trim();
                          final f = double.tryParse(
                                  feeCtrl.text.trim().replaceAll(',', '.')) ??
                              100.0;
                          if (n.isEmpty) return;
                          setD(() {
                            store.saveDeliveryZone(
                              existingId: editingId,
                              nameFr: n,
                              feeMru: f,
                            );
                            editingId = null;
                            nameCtrl.clear();
                            feeCtrl.text = '100';
                          });
                        },
                        child: Text(editingId == null ? '+' : 'OK'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('manage_dz_free_above_input'),
                          controller: freeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Livraison offerte dès (0 = désactivé)',
                            suffixText: 'MRU',
                            prefixIcon: Icon(Icons.card_giftcard_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () {
                          final v = double.tryParse(
                                  freeCtrl.text.trim().replaceAll(',', '.')) ??
                              0.0;
                          setD(() => store.setFreeDeliveryAboveMru(v));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(v > 0
                                  ? 'Livraison gratuite dès ${v.toStringAsFixed(0)} MRU.'
                                  : 'Livraison gratuite automatique désactivée.'),
                            ),
                          );
                        },
                        child: const Text('Appliquer'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Fermer'),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    feeCtrl.dispose();
    freeCtrl.dispose();
  }

  Future<void> _sendToKitchen() async {
    final store = widget.store;
    final order = store.activeOrder;
    if (order == null || order.items.isEmpty) return;

    // Prompt Delivery info (Client / Phone / Zone / Driver) if missing in Delivery mode
    if (order.serviceMode == ServiceMode.delivery) {
      final cleanPhone =
          (order.customerPhone ?? '').replaceAll('+222', '').trim();
      final cleanName = (order.customerName ?? '').trim();
      if (cleanPhone.isEmpty && cleanName.isEmpty) {
        final ok = await _openDeliveryClientDriverDialog(isBeforeKitchen: true);
        if (!ok || !mounted) return;
      }
    }

    // Mandatory table selection before sending to kitchen in Sur place (dineIn) mode
    // Strictly enforced even if 0 tables are configured yet (never sends without a table!)
    final isDineIn = order.serviceMode == ServiceMode.dineIn ||
        store.serviceMode == ServiceMode.dineIn;
    final hasTable = (order.tableId ?? '').trim().isNotEmpty &&
        (order.tableCode ?? '').trim().isNotEmpty;
    if (isDineIn && !hasTable) {
      final p = FullTekThemes.paletteOf(context);
      if (store.tables.isEmpty) {
        final action = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: p.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: p.border),
            ),
            title: Row(
              children: [
                Icon(Icons.table_restaurant_rounded,
                    color: p.warning, size: 24),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'N° de table obligatoire',
                    style:
                        TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            content: Text(
              'Impossible d\'envoyer une commande « Sur place » en cuisine sans numéro de table.\n\n'
              'Aucune table n\'est encore créée dans votre Plan de salle. Créez vos tables dans le Plan de salle ou passez cette commande en mode « Emporter ».',
              style: TextStyle(fontSize: 13, color: p.textPrimary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(store.i18n.t('cancel')),
              ),
              OutlinedButton.icon(
                key: const Key('switch_takeaway_from_table_guard_btn'),
                onPressed: () => Navigator.of(ctx).pop('takeaway'),
                icon: const Icon(Icons.takeout_dining_rounded, size: 17),
                label: const Text('Passer en Emporter'),
              ),
              ElevatedButton.icon(
                key: const Key('goto_floor_from_table_guard_btn'),
                onPressed: () => Navigator.of(ctx).pop('floor'),
                icon: const Icon(Icons.table_restaurant_rounded, size: 17),
                label: const Text('Créer une table'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (action == 'floor') {
          widget.onOpenFloorPlan();
          return;
        }
        if (action == 'takeaway') {
          store.setServiceMode(ServiceMode.takeaway);
        } else {
          return;
        }
      } else {
        final activeStaff = store.staff.where((s) => s.isActive).toList()
          ..sort((a, b) {
            final aw = a.role == PosRole.waiter ? 0 : 1;
            final bw = b.role == PosRole.waiter ? 0 : 1;
            if (aw != bw) return aw.compareTo(bw);
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
        String? selectedServer =
            (order.serverName != null && order.serverName!.trim().isNotEmpty)
                ? order.serverName!.trim()
                : store.currentStaff?.name;
        final commentCtrl =
            TextEditingController(text: order.orderComment ?? '');

        final chosen = await showDialog<
            ({String tableId, String? serverName, String comment})>(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setD) => Dialog(
              backgroundColor: p.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: p.border),
              ),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 580, maxHeight: 620),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.table_restaurant_rounded,
                              color: p.warning, size: 24),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Table, Serveur & Commentaire cuisine',
                              style: TextStyle(
                                  fontSize: 16.5, fontWeight: FontWeight.w900),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      if (activeStaff.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '1. Serveur en charge :',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: p.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: activeStaff.map((s) {
                            final isSel = selectedServer == s.name;
                            return ChoiceChip(
                              key: Key('pick_server_kitchen_${s.id}'),
                              selected: isSel,
                              selectedColor: p.primary,
                              backgroundColor: p.surfaceAlt,
                              side: BorderSide(
                                color: isSel ? p.primary : p.border,
                                width: isSel ? 1.6 : 1,
                              ),
                              avatar: Icon(
                                Icons.person_rounded,
                                size: 16,
                                color: isSel ? p.onPrimary : p.primary,
                              ),
                              label: Text(
                                s.name,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: isSel ? p.onPrimary : p.textPrimary,
                                ),
                              ),
                              onSelected: (_) =>
                                  setD(() => selectedServer = s.name),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Text(
                        '💬 Commentaire cuisine (optionnel) :',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: p.textMuted,
                        ),
                      ),
                      const SizedBox(height: 5),
                      TextField(
                        key: const Key('kitchen_dialog_comment_input'),
                        controller: commentCtrl,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText:
                              'Ex: Sans piment, client pressé, servir ensemble...',
                          prefixIcon: const Icon(Icons.chat_bubble_outline,
                              size: 18),
                          suffixIcon: commentCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () =>
                                      setD(() => commentCtrl.clear()),
                                )
                              : null,
                        ),
                        onChanged: (_) => setD(() {}),
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: store.quickComments.take(8).map((c) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ActionChip(
                                visualDensity: VisualDensity.compact,
                                backgroundColor: p.surfaceAlt,
                                side: BorderSide(color: p.border),
                                label: Text(c,
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: p.textPrimary)),
                                onPressed: () {
                                  setD(() {
                                    final cur = commentCtrl.text.trim();
                                    commentCtrl.text =
                                        cur.isEmpty ? c : '$cur, $c';
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        activeStaff.isNotEmpty
                            ? '2. Sélectionnez la table du client :'
                            : 'Sélectionnez la table du client pour envoyer la commande en cuisine :',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: p.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: GridView.builder(
                          shrinkWrap: true,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 1.7,
                          ),
                          itemCount: store.tables.length,
                          itemBuilder: (_, idx) {
                            final t = store.tables[idx];
                            final occ = t.status != TableStatus.free;
                            final col = occ ? p.warning : p.success;
                            return InkWell(
                              key: Key('pick_table_kitchen_${t.id}'),
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => Navigator.of(ctx).pop((
                                tableId: t.id,
                                serverName: selectedServer,
                                comment: commentCtrl.text.trim(),
                              )),
                              child: Container(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: col.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: col, width: 1.6),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Table ${t.code}',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w900,
                                        color: p.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      occ ? 'Occupée (ajouter)' : 'Libre',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: col,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        commentCtrl.dispose();
        if (chosen == null || !mounted) return;
        store.assignTableToActiveOrder(chosen.tableId);
        if (chosen.serverName != null && chosen.serverName!.trim().isNotEmpty) {
          store.setActiveOrderServer(chosen.serverName!.trim());
        }
        store.setActiveOrderComment(chosen.comment);
      }
    }

    final sentMode = order.serviceMode;
    final kdsTicket = store.sendActiveOrderToKitchenAndPark();
    if (kdsTicket == null || !mounted) return;
    if (sentMode == ServiceMode.delivery || sentMode == ServiceMode.takeaway) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Text(
            sentMode == ServiceMode.delivery
                ? '🛵 Livraison envoyée en cuisine ! Cliquez sur « En attente / Encaisser » en haut du panier pour l\'encaisser.'
                : '🛍️ Commande à emporter envoyée ! Cliquez sur « En attente / Encaisser » en haut du panier pour l\'encaisser.',
          ),
        ),
      );
    }
    showReceiptPreviewDialog(
      context,
      title: '${store.i18n.t('kitchen_sent')} · Mise en attente',
      receiptText: kdsTicket,
      isKitchenTicket: true,
    );
  }

  void _printAddition() {
    final additionTicket = widget.store.requestAdditionForActiveOrder();
    if (additionTicket == null) return;
    showReceiptPreviewDialog(
      context,
      title: '🧾 Note (sans encaissement)',
      subtitle: 'Table marquée « Note sortie » · Document non encaissé',
      receiptText: additionTicket,
      logoDataUrl: widget.store.receiptLogoDataUrl,
      logoPosition: widget.store.receiptLogoPosition,
    );
  }

  /// "Abandonner toute la commande" — clears the entire cart in 1 tap.
  /// Shows a simple confirmation if unsent, or Manager PIN + Reason if sent to kitchen.
  Future<void> _openAbandonOrderDialog() async {
    final store = widget.store;
    final order = store.activeOrder;
    if (order == null || order.items.isEmpty) return;
    final p = FullTekThemes.paletteOf(context);
    final hasSent = order.items.any((i) => i.sentToKitchen);
    final needsPin = hasSent && !store.canCurrent(PosPermission.voidOrComp);
    final reasonCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    String? error;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.delete_sweep_rounded, color: p.danger, size: 24),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Abandonner toute la commande ?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  hasSent
                      ? '⚠️ Attention : certains plats (${order.items.where((i) => i.sentToKitchen).length}) ont déjà été envoyés en cuisine.\n'
                          'Un motif et une validation gérant sont obligatoires. Un ticket d\'annulation sera imprimé en cuisine.'
                      : 'Voulez-vous vraiment abandonner cette commande (${order.items.length} ligne(s) · ${order.netTotal.toStringAsFixed(0)} MRU) ?',
                  style: TextStyle(fontSize: 13, color: p.textPrimary),
                ),
                if (hasSent) ...[
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('abandon_order_reason_input'),
                    controller: reasonCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Motif d\'abandon *',
                      hintText: 'Ex: Client parti / Erreur de table',
                    ),
                  ),
                  if (needsPin) ...[
                    const SizedBox(height: 10),
                    TextField(
                      key: const Key('abandon_order_pin_input'),
                      controller: pinCtrl,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      onTap: () => showTouchNumpad(
                        context: ctx,
                        controller: pinCtrl,
                        title: 'Code PIN Gérant / Propriétaire',
                        suffix: '',
                        obscure: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Code PIN Gérant / Propriétaire *',
                        prefixIcon: Icon(Icons.vpn_key_outlined),
                        suffixIcon: Icon(Icons.dialpad_rounded, size: 20),
                      ),
                    ),
                  ],
                ],
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    error!,
                    style: TextStyle(
                      color: p.danger,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(store.i18n.t('cancel')),
            ),
            ElevatedButton.icon(
              key: const Key('confirm_abandon_order_btn'),
              style: ElevatedButton.styleFrom(
                backgroundColor: p.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final res = store.abandonActiveOrder(
                  reason: reasonCtrl.text,
                  managerPin: pinCtrl.text,
                );
                if (res == null) {
                  setD(() => error =
                      store.lastVoidError ?? 'Abandon refusé.');
                  return;
                }
                Navigator.of(ctx).pop(res);
              },
              icon: const Icon(Icons.delete_forever_rounded, size: 18),
              label: const Text('Abandonner tout'),
            ),
          ],
        ),
      ),
    );
    reasonCtrl.dispose();
    pinCtrl.dispose();

    if (result != null && result.isNotEmpty && mounted) {
      showReceiptPreviewDialog(
        context,
        title: '❌ Annulation commande (Cuisine)',
        subtitle: 'À remettre en cuisine · Trace enregistrée dans l\'historique',
        receiptText: result,
        isKitchenTicket: true,
      );
    }
  }

  Future<void> _openCancelSentLineDialog(
    OrderItem line, {
    int? cancelQty,
  }) async {
    final store = widget.store;
    final p = FullTekThemes.paletteOf(context);
    final qty =
        (cancelQty == null || cancelQty >= line.quantity) ? line.quantity : cancelQty;
    final needsPin = !store.canCurrent(PosPermission.voidOrComp);
    final reasonCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    const quickReasons = [
      'Client a changé d\'avis',
      'Erreur de saisie',
      'Rupture ingrédient',
      'Attente trop longue',
      'Plat retourné',
    ];
    String? error;

    final cancelTicket = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.lock_outline_rounded, color: p.danger, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Annulation après envoi cuisine',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: p.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: p.danger.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '🔥 Article déjà envoyé en cuisine : ${qty}x ${line.item.label(store.lang)} (${(line.unitPriceWithModifiers * qty).toStringAsFixed(0)} MRU).\n'
                      'Un ticket d\'annulation sera imprimé en cuisine et enregistré dans l\'historique.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: quickReasons
                        .map(
                          (r) => ActionChip(
                            label: Text(r, style: const TextStyle(fontSize: 11)),
                            onPressed: () {
                              reasonCtrl.text = r;
                              setD(() => error = null);
                            },
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('void_kitchen_reason_input'),
                    controller: reasonCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Motif d\'annulation *',
                      hintText: 'Ex: Client a changé d\'avis / Erreur saisie',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (needsPin)
                    TextField(
                      key: const Key('void_kitchen_pin_input'),
                      controller: pinCtrl,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      onTap: () => showTouchNumpad(
                        context: ctx,
                        controller: pinCtrl,
                        title: 'Code PIN Gérant / Propriétaire',
                        suffix: '',
                        obscure: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Code PIN Gérant / Propriétaire *',
                        hintText: 'Touchez pour ouvrir le pavé numérique',
                        prefixIcon: Icon(Icons.vpn_key_outlined),
                        suffixIcon: Icon(Icons.dialpad_rounded, size: 20),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: p.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: p.success.withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        '✅ Autorisé par ${store.currentStaff?.name ?? 'Gérant'} (profil autorisé)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: p.success,
                        ),
                      ),
                    ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      error!,
                      style: TextStyle(
                        color: p.danger,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(store.i18n.t('cancel')),
            ),
            ElevatedButton.icon(
              key: const Key('confirm_void_kitchen_btn'),
              style: ElevatedButton.styleFrom(
                backgroundColor: p.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final ticket = store.voidSentLineWithAuth(
                  lineId: line.lineId,
                  cancelQty: cancelQty,
                  reason: reasonCtrl.text,
                  managerPin: pinCtrl.text,
                );
                if (ticket == null) {
                  setD(() => error =
                      store.lastVoidError ?? 'Annulation refusée.');
                  return;
                }
                Navigator.of(ctx).pop(ticket);
              },
              icon: const Icon(Icons.print_rounded, size: 16),
              label: const Text('Annuler & Imprimer cuisine'),
            ),
          ],
        ),
      ),
    );
    reasonCtrl.dispose();
    pinCtrl.dispose();

    if (cancelTicket != null && mounted) {
      showReceiptPreviewDialog(
        context,
        title: '❌ Ticket d\'annulation cuisine',
        subtitle: 'À remettre en cuisine · Trace enregistrée dans l\'historique',
        receiptText: cancelTicket,
        isKitchenTicket: true,
      );
    }
  }

  /// Large touch-first Waiter / Server selector modal (easy to tap with a finger).
  Future<void> _openServerPickerDialog() async {
    final store = widget.store;
    final p = FullTekThemes.paletteOf(context);
    final activeStaff = store.staff.where((s) => s.isActive).toList();
    final currentServer =
        store.activeOrder?.serverName ?? store.currentStaff?.name;

    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: p.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 500),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.badge_rounded, color: p.primary, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Choisir le Serveur (Tactile)',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: p.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.5,
                    ),
                    itemCount: activeStaff.length,
                    itemBuilder: (_, idx) {
                      final s = activeStaff[idx];
                      final selected = s.name == currentServer;
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          store.setActiveOrderServer(s.name);
                          Navigator.of(ctx).pop();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: selected
                                ? p.primary.withValues(alpha: 0.16)
                                : p.surfaceAlt,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected ? p.primary : p.border,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: selected
                                    ? p.primary
                                    : p.primary.withValues(alpha: 0.14),
                                child: Text(
                                  s.name.isNotEmpty
                                      ? s.name[0].toUpperCase()
                                      : 'S',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color:
                                        selected ? p.onPrimary : p.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w900,
                                        color: p.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      s.role.label(store.lang),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: p.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openWaitingOrdersDialog() async {
    final store = widget.store;
    final p = FullTekThemes.paletteOf(context);
    final waiting = store.waitingOrders;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Commandes en attente & Tables (${waiting.length})'),
        content: SizedBox(
          width: 540,
          height: 380,
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
                    final tbl = o.tableId != null
                        ? store.tables
                            .where((t) => t.id == o.tableId)
                            .firstOrNull
                        : null;
                    final since = tbl?.occupiedSince ?? o.createdAt;
                    final hm =
                        '${since.hour.toString().padLeft(2, '0')}:${since.minute.toString().padLeft(2, '0')}';
                    final mins = DateTime.now().difference(since).inMinutes;
                    final chrono = mins < 60
                        ? '${mins < 0 ? 0 : mins}m'
                        : '${mins ~/ 60}h ${(mins % 60).toString().padLeft(2, '0')}m';
                    final deliverySummary =
                        o.serviceMode == ServiceMode.delivery
                            ? [
                                if (o.deliveryZone != null)
                                  '📍 ${o.deliveryZone!.nameFr}',
                                if ((o.customerName ?? '').trim().isNotEmpty)
                                  '🧑 ${o.customerName!.trim()}',
                                if ((o.customerPhone ?? '').trim().isNotEmpty)
                                  '📞 ${o.customerPhone!.trim()}',
                                if ((o.deliveryDriverName ?? '')
                                    .trim()
                                    .isNotEmpty)
                                  '🏍️ ${o.deliveryDriverName!.trim()}',
                              ].join(' · ')
                            : '';
                    return ListTile(
                      leading: Icon(
                        o.serviceMode == ServiceMode.delivery
                            ? Icons.delivery_dining_rounded
                            : Icons.hourglass_top_rounded,
                      ),
                      title: Text(
                        '$label · ${o.netTotal.toStringAsFixed(0)} MRU',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${deliverySummary.isNotEmpty ? '$deliverySummary\n' : ''}👤 $srv · 🕒 Ouverte à $hm · ⏱ $chrono · ${o.items.length} article(s)',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Annuler la commande',
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              store.resumeWaitingOrder(o.id);
                              Navigator.of(ctx).pop();
                              _openAbandonOrderDialog();
                            },
                            icon: Icon(Icons.delete_outline_rounded,
                                size: 19, color: p.danger),
                          ),
                          OutlinedButton(
                            onPressed: () {
                              store.resumeWaitingOrder(o.id);
                              Navigator.of(ctx).pop();
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 6),
                            ),
                            child: const Text('Ouvrir',
                                style: TextStyle(fontSize: 12)),
                          ),
                          const SizedBox(width: 6),
                          FilledButton(
                            key: Key('waiting_pay_${o.id}'),
                            onPressed: () {
                              store.resumeWaitingOrder(o.id);
                              Navigator.of(ctx).pop();
                              _openCheckout();
                            },
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                            ),
                            child: const Text('Encaisser',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w800)),
                          ),
                        ],
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

  Future<String?> _showCommentPickerDialog({
    required String title,
    required String initialText,
    bool initialIsBar = false,
  }) async {
    final store = widget.store;
    final p = FullTekThemes.paletteOf(context);
    final ctrl = TextEditingController(text: initialText);
    bool isBarTab = initialIsBar;
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final activeList =
              isBarTab ? store.barComments : store.kitchenComments;
          return AlertDialog(
            backgroundColor: p.surface,
            title: Row(
              children: [
                Icon(
                  isBarTab
                      ? Icons.local_cafe_rounded
                      : Icons.restaurant_rounded,
                  color: p.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 2 tabs: Cuisine vs Café / Bar
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            key: const Key('comment_tab_kitchen'),
                            selected: !isBarTab,
                            selectedColor: p.primary,
                            label: Center(
                              child: Text(
                                '🍳 Cuisine (${store.kitchenComments.length})',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: !isBarTab
                                      ? p.onPrimary
                                      : p.textPrimary,
                                ),
                              ),
                            ),
                            onSelected: (_) => setD(() => isBarTab = false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            key: const Key('comment_tab_bar'),
                            selected: isBarTab,
                            selectedColor: p.primary,
                            label: Center(
                              child: Text(
                                '☕ Café / Bar (${store.barComments.length})',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color:
                                      isBarTab ? p.onPrimary : p.textPrimary,
                                ),
                              ),
                            ),
                            onSelected: (_) => setD(() => isBarTab = true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      key: const Key('comment_picker_input'),
                      controller: ctrl,
                      autofocus: true,
                      maxLines: 2,
                      onChanged: (_) => setD(() {}),
                      decoration: InputDecoration(
                        hintText: isBarTab
                            ? 'Ex: Sans sucre, peu sucré, sans glaçons, lait chaud...'
                            : 'Ex: Sans piment, bien cuit, sauce à part, client pressé...',
                        suffixIcon: ctrl.text.isNotEmpty
                            ? IconButton(
                                tooltip: 'Effacer',
                                icon:
                                    const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () => setD(() => ctrl.clear()),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isBarTab
                              ? 'Commentaires Café / Bar (1 clic) :'
                              : 'Commentaires Cuisine (1 clic) :',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: p.textMuted,
                          ),
                        ),
                        if (ctrl.text.trim().isNotEmpty &&
                            !activeList.any((c) =>
                                c.toLowerCase() ==
                                ctrl.text.trim().toLowerCase()))
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () {
                              store.addQuickComment(ctrl.text.trim(),
                                  isBar: isBarTab);
                              setD(() {});
                            },
                            icon: const Icon(Icons.bookmark_add_outlined,
                                size: 15),
                            label: const Text('Enregistrer favori',
                                style: TextStyle(fontSize: 11.5)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: activeList.map((c) {
                        return ActionChip(
                          backgroundColor: p.surfaceAlt,
                          side: BorderSide(color: p.border),
                          label: Text(
                            c,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: p.textPrimary,
                            ),
                          ),
                          onPressed: () {
                            setD(() {
                              final cur = ctrl.text.trim();
                              ctrl.text = cur.isEmpty ? c : '$cur, $c';
                            });
                          },
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
                child: Text(store.i18n.t('cancel')),
              ),
              ElevatedButton.icon(
                key: const Key('confirm_comment_btn'),
                onPressed: () => Navigator.of(ctx).pop(ctrl.text),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(store.i18n.t('confirm')),
              ),
            ],
          );
        },
      ),
    );
    ctrl.dispose();
    return saved;
  }

  Future<void> _editNote(OrderItem line) async {
    final isBar = widget.store.isBarMenuItem(line.item);
    final saved = await _showCommentPickerDialog(
      title: 'Commentaire · ${line.item.label(widget.store.lang)}',
      initialText: line.kitchenNote ?? '',
      initialIsBar: isBar,
    );
    if (saved != null) {
      widget.store.updateLineNote(line.lineId, saved);
    }
  }

  Future<void> _openOrderCommentDialog() async {
    final order = widget.store.activeOrder;
    if (order == null) return;
    final saved = await _showCommentPickerDialog(
      title: 'Commentaire cuisine (commande)',
      initialText: order.orderComment ?? '',
    );
    if (saved != null) {
      widget.store.setActiveOrderComment(saved);
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

      const catPalette = <Color>[
        Color(0xFF10B981),
        Color(0xFFF59E0B),
        Color(0xFF3B82F6),
        Color(0xFFEC4899),
        Color(0xFF8B5CF6),
        Color(0xFF06B6D4),
        Color(0xFFEF4444),
        Color(0xFF14B8A6),
        Color(0xFFF97316),
        Color(0xFF6366F1),
      ];
      final catIndex = category == null
          ? 0
          : store.categories.indexWhere((c) => c.id == category.id);
      final accentCol = id == 'all'
          ? p.primary
          : catPalette[(catIndex < 0 ? id.hashCode.abs() : catIndex) %
              catPalette.length];

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: sel ? accentCol : accentCol.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(p.radius),
          child: InkWell(
            key: Key('rail_cat_$id'),
            borderRadius: BorderRadius.circular(p.radius),
            onTap: () => setState(() => _selectedCategoryId = id),
            onLongPress: category != null
                ? () => _openQuickCategoryImageDialog(category)
                : null,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(p.radius),
                border: Border.all(
                  color: sel ? accentCol : accentCol.withValues(alpha: 0.45),
                  width: sel ? 2 : 1.2,
                ),
              ),
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
                              color: sel ? Colors.white : p.textPrimary,
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

    const catPalette = <Color>[
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFF3B82F6),
      Color(0xFFEC4899),
      Color(0xFF8B5CF6),
      Color(0xFF06B6D4),
      Color(0xFFEF4444),
      Color(0xFF14B8A6),
      Color(0xFFF97316),
      Color(0xFF6366F1),
    ];

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
                    suffixIcon: IconButton(
                      tooltip: 'Clavier tactile',
                      icon: const Icon(Icons.keyboard_rounded, size: 20),
                      onPressed: () => TouchKeyboardController.instance
                          .openForCurrentFocus(),
                    ),
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

          if (showTabs)
            SizedBox(
              height: 42,
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
                  ...store.categories.asMap().entries.map((entry) {
                    final cat = entry.value;
                    final col = catPalette[entry.key % catPalette.length];
                    final sel = _selectedCategoryId == cat.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: sel,
                        selectedColor: col,
                        backgroundColor: col.withValues(alpha: 0.14),
                        side: BorderSide(
                          color: sel ? col : col.withValues(alpha: 0.45),
                          width: sel ? 1.8 : 1,
                        ),
                        onSelected: (_) =>
                            setState(() => _selectedCategoryId = cat.id),
                        label: Text(
                          '${cat.icon} ${cat.label(store.lang)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: sel ? Colors.white : p.textPrimary,
                          ),
                        ),
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
                final aspect = c.maxWidth < 400 ? 0.84 : 0.90;
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
                                      const EdgeInsets.fromLTRB(10, 8, 10, 9),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        item.nameFr,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: p.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.nameAr,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: p.textMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          if (item.hasModifiers && !oos) ...[
                                            Icon(Icons.tune_rounded,
                                                size: 17, color: p.accent),
                                            const Spacer(),
                                          ],
                                          Text(
                                            '${item.priceMru.toStringAsFixed(0)} ${i18n.t('mru')}',
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              fontSize: 15.5,
                                              fontWeight: FontWeight.w900,
                                              color: p.primary,
                                            ),
                                          ),
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
          // Touch-friendly Ticket Header: Table | Large Waiter Button | Waiting Orders
          Row(
            children: [
              // Table / Counter selector button (opens floor plan on tap)
              Flexible(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: widget.onOpenFloorPlan,
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: p.primary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: p.primary.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.table_restaurant_rounded,
                            size: 16, color: p.primary),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            order?.tableCode != null
                                ? '${i18n.t('table_label')} ${order!.tableCode}'
                                : '${store.serviceMode.emoji} ${store.serviceMode.label(store.lang)}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: p.primary,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Large Touch Server / Waiter button (opens big touch grid dialog)
              if (store.staff.isNotEmpty)
                Expanded(
                  child: InkWell(
                    key: const Key('select_server_menu'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: _openServerPickerDialog,
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: p.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: p.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person_rounded,
                              size: 17, color: p.accent),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              order?.serverName ??
                                  store.currentStaff?.name ??
                                  'Serveur',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                                color: p.textPrimary,
                              ),
                            ),
                          ),
                          Icon(Icons.touch_app_rounded,
                              size: 15, color: p.textMuted),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              // Large Touch Waiting Orders button ("En attente")
              InkWell(
                key: const Key('waiting_orders_btn'),
                borderRadius: BorderRadius.circular(12),
                onTap: _openWaitingOrdersDialog,
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: store.waitingOrders.isNotEmpty
                        ? p.warning.withValues(alpha: 0.18)
                        : p.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: store.waitingOrders.isNotEmpty
                          ? p.warning
                          : p.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.hourglass_top_rounded,
                        size: 16,
                        color: store.waitingOrders.isNotEmpty
                            ? p.warning
                            : p.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${store.waitingOrders.length}',
                        style: TextStyle(
                          fontSize: 13,
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
              const SizedBox(width: 4),
              if (items.isNotEmpty)
                Tooltip(
                  message: 'Abandonner toute la commande',
                  child: InkWell(
                    key: const Key('abandon_order_btn'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: _openAbandonOrderDialog,
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 9),
                      decoration: BoxDecoration(
                        color: p.danger.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: p.danger.withValues(alpha: 0.45)),
                      ),
                      child: Icon(Icons.delete_sweep_rounded,
                          size: 20, color: p.danger),
                    ),
                  ),
                )
              else
                IconButton(
                  tooltip: i18n.t('counter_sale'),
                  onPressed: store.startCounterOrder,
                  icon: Icon(Icons.add_shopping_cart_rounded,
                      size: 20, color: p.textMuted),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // 3 Service Modes (Sur place | Emporter | Livraison) with generous touch height
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: p.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.border),
            ),
            child: Row(
              children: ServiceMode.values.map((m) {
                final active = store.serviceMode == m;
                return Expanded(
                  child: InkWell(
                    key: Key('service_mode_${m.name}'),
                    borderRadius: BorderRadius.circular(9),
                    onTap: () => store.setServiceMode(m),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 9),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active ? p.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${m.emoji} ${m.label(store.lang)}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
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
          // Prominent quick-access banner whenever there are pending Deliveries / Takeaway / Waiting orders
          Builder(builder: (_) {
            final waitingAll = store.waitingOrders;
            final waitingDelivery = waitingAll
                .where((o) => o.serviceMode == ServiceMode.delivery)
                .toList();
            final waitingTakeaway = waitingAll
                .where((o) => o.serviceMode == ServiceMode.takeaway)
                .toList();
            final showBanner = waitingDelivery.isNotEmpty ||
                waitingTakeaway.isNotEmpty ||
                (items.isEmpty && waitingAll.isNotEmpty);
            if (!showBanner) return const SizedBox.shrink();
            final parts = <String>[
              if (waitingDelivery.isNotEmpty)
                '🛵 ${waitingDelivery.length} Livraison(s)',
              if (waitingTakeaway.isNotEmpty)
                '🛍️ ${waitingTakeaway.length} Emporter',
            ];
            final bannerText = parts.isNotEmpty
                ? '${parts.join(' · ')} en cours'
                : '⏳ ${waitingAll.length} commande(s) en attente';
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: InkWell(
                key: const Key('waiting_delivery_banner_btn'),
                borderRadius: BorderRadius.circular(11),
                onTap: _openWaitingOrdersDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: p.warning.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: p.warning, width: 1.3),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          bannerText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: p.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: p.warning,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Encaisser →',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          if (store.serviceMode == ServiceMode.delivery) ...[
            const SizedBox(height: 8),
            Container(
              key: const Key('cart_delivery_card'),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: p.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: p.primary.withValues(alpha: 0.55),
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!store.deliveryFeeEnabled)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: p.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.delivery_dining_rounded,
                              size: 16, color: p.textMuted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Frais livraison désactivés (0 MRU · réglés au livreur)',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: p.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (store.deliveryZones.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.delivery_dining_rounded,
                            size: 18, color: p.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              key: const Key('delivery_zone_dropdown'),
                              isDense: true,
                              isExpanded: true,
                              value: store.deliveryZones.any((z) =>
                                      z.id ==
                                      (order?.deliveryZone ??
                                              store.selectedDeliveryZone ??
                                              store.deliveryZones.first)
                                          .id)
                                  ? (order?.deliveryZone ??
                                          store.selectedDeliveryZone ??
                                          store.deliveryZones.first)
                                      .id
                                  : store.deliveryZones.first.id,
                              items: store.deliveryZones.map((z) {
                                return DropdownMenuItem(
                                  value: z.id,
                                  child: Text(
                                    '${z.label(store.lang)} (+${z.feeMru.toStringAsFixed(0)} MRU)',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: p.textPrimary,
                                    ),
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
                        const SizedBox(width: 6),
                        InkWell(
                          key: const Key('manage_delivery_zones_btn'),
                          borderRadius: BorderRadius.circular(8),
                          onTap: _openManageDeliveryZonesDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 4),
                            decoration: BoxDecoration(
                              color: p.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: p.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.tune_rounded,
                                    size: 14, color: p.primary),
                                const SizedBox(width: 3),
                                Text(
                                  'Tarifs',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: p.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          key: const Key('delivery_client_btn'),
                          borderRadius: BorderRadius.circular(9),
                          onTap: _openDeliveryClientDriverDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 7),
                            decoration: BoxDecoration(
                              color: p.surface,
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: ((order?.customerName ?? '')
                                            .trim()
                                            .isNotEmpty ||
                                        (order?.customerPhone ?? '')
                                            .replaceAll('+222', '')
                                            .trim()
                                            .isNotEmpty)
                                    ? p.success
                                    : p.warning,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.person_pin_circle_rounded,
                                  size: 16,
                                  color: ((order?.customerName ?? '')
                                              .trim()
                                              .isNotEmpty ||
                                          (order?.customerPhone ?? '')
                                              .replaceAll('+222', '')
                                              .trim()
                                              .isNotEmpty)
                                      ? p.success
                                      : p.warning,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    (order?.customerName ?? '')
                                            .trim()
                                            .isNotEmpty
                                        ? '${order!.customerName!.trim()}${(order.customerPhone ?? '').trim().isNotEmpty ? ' · ${order.customerPhone!.trim()}' : ''}'
                                        : 'Client & Tél',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: p.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: InkWell(
                          key: const Key('delivery_driver_btn'),
                          borderRadius: BorderRadius.circular(9),
                          onTap: _openDeliveryClientDriverDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 7),
                            decoration: BoxDecoration(
                              color: p.surface,
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: p.border),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.two_wheeler_rounded,
                                    size: 16, color: p.accent),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    (order?.deliveryDriverName ?? '')
                                            .trim()
                                            .isNotEmpty
                                        ? order!.deliveryDriverName!.trim()
                                        : 'Livreur',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: p.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
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
                      final isSelected = _selectedLineId == line.lineId;
                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () =>
                            setState(() => _selectedLineId = line.lineId),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 4),
                          decoration: isSelected
                              ? BoxDecoration(
                                  color: p.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                )
                              : null,
                          child: Row(
                            children: [
                              Tooltip(
                                message: 'Toucher pour saisir la quantité',
                                child: InkWell(
                                  key: Key('line_qty_btn_${line.lineId}'),
                                  borderRadius: BorderRadius.circular(9),
                                  onTap: () {
                                    setState(
                                        () => _selectedLineId = line.lineId);
                                    _openQuantityDialog(line);
                                  },
                                  child: Container(
                                    constraints: const BoxConstraints(
                                        minWidth: 34, minHeight: 32),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6),
                                    alignment: Alignment.center,
                                    margin: const EdgeInsets.only(right: 10),
                                    decoration: BoxDecoration(
                                      color: p.primary.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(9),
                                      border: Border.all(
                                          color:
                                              p.primary.withValues(alpha: 0.5)),
                                    ),
                                    child: Text(
                                      '${line.quantity}',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w900,
                                        color: p.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    line.item.label(store.lang),
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: p.textPrimary,
                                      decoration: line.isComp
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  for (final m in line.selectedModifiers)
                                    Text('+ ${m.label(store.lang)}',
                                        style: TextStyle(
                                            fontSize: 11, color: p.accent)),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        line.isComp
                                            ? 'OFFERT'
                                            : '${line.lineTotal.toStringAsFixed(0)} ${i18n.t('mru')}',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: line.isComp
                                              ? p.success
                                              : p.primary,
                                        ),
                                      ),
                                      InkWell(
                                        key: Key('line_mode_${line.lineId}'),
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () => store
                                            .toggleLineTakeaway(line.lineId),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 9, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: line.isTakeaway
                                                ? p.warning
                                                    .withValues(alpha: 0.16)
                                                : p.primary
                                                    .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: line.isTakeaway
                                                  ? p.warning
                                                      .withValues(alpha: 0.4)
                                                  : p.primary
                                                      .withValues(alpha: 0.35),
                                            ),
                                          ),
                                          child: Text(
                                            line.isTakeaway
                                                ? '🥡 Emporter'
                                                : '🍽 Sur place',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: line.isTakeaway
                                                  ? p.warning
                                                  : p.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (line.sentToKitchen)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: p.danger
                                                .withValues(alpha: 0.14),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: p.danger
                                                  .withValues(alpha: 0.35),
                                            ),
                                          ),
                                          child: Text(
                                            '🔒 En cuisine',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800,
                                              color: p.danger,
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
                                          fontSize: 11.5, color: p.warning),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: i18n.t('add_note'),
                              onPressed: () => _editNote(line),
                              icon: Icon(Icons.edit_note_rounded,
                                  size: 20, color: p.textMuted),
                            ),
                            IconButton(
                              tooltip: line.sentToKitchen
                                  ? 'Annuler 1 unité (code gérant + motif)'
                                  : 'Diminuer quantité',
                              onPressed: () {
                                if (line.sentToKitchen) {
                                  _openCancelSentLineDialog(line, cancelQty: 1);
                                } else {
                                  store.updateLineQuantity(line.lineId, -1);
                                }
                              },
                              icon: Icon(
                                line.sentToKitchen
                                    ? Icons.lock_outline_rounded
                                    : Icons.remove_circle_outline,
                                size: 22,
                                color: line.sentToKitchen ? p.warning : null,
                              ),
                            ),
                            IconButton(
                              onPressed: () =>
                                  store.updateLineQuantity(line.lineId, 1),
                              icon: const Icon(Icons.add_circle_outline,
                                  size: 22),
                            ),
                            IconButton(
                              tooltip: line.sentToKitchen
                                  ? 'Annuler après cuisine (code gérant + motif)'
                                  : 'Supprimer la ligne',
                              onPressed: () {
                                if (line.sentToKitchen) {
                                  _openCancelSentLineDialog(line);
                                } else {
                                  store.removeLineFromActiveOrder(line.lineId);
                                }
                              },
                              icon: Icon(
                                line.sentToKitchen
                                    ? Icons.cancel_outlined
                                    : Icons.delete_outline_rounded,
                                size: 21,
                                color: p.danger,
                              ),
                            ),
                          ],
                        ),
                        ),
                      );
                    },
                  ),
          ),

          if (items.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      key: const Key('order_comment_btn'),
                      borderRadius: BorderRadius.circular(10),
                      onTap: _openOrderCommentDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: (order?.orderComment ?? '').trim().isNotEmpty
                              ? p.warning.withValues(alpha: 0.14)
                              : p.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color:
                                (order?.orderComment ?? '').trim().isNotEmpty
                                    ? p.warning
                                    : p.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 16,
                              color:
                                  (order?.orderComment ?? '').trim().isNotEmpty
                                      ? p.warning
                                      : p.textMuted,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                (order?.orderComment ?? '').trim().isNotEmpty
                                    ? '💬 ${order!.orderComment!.trim()}'
                                    : 'Ajouter un commentaire cuisine...',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: (order?.orderComment ?? '')
                                          .trim()
                                          .isNotEmpty
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: (order?.orderComment ?? '')
                                          .trim()
                                          .isNotEmpty
                                      ? p.warning
                                      : p.textMuted,
                                ),
                              ),
                            ),
                            Icon(Icons.edit_rounded,
                                size: 14, color: p.textMuted),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    key: const Key('cart_qty_btn'),
                    onPressed: () {
                      final target = items.firstWhere(
                        (l) => l.lineId == _selectedLineId,
                        orElse: () => items.last,
                      );
                      _openQuantityDialog(target);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      side: BorderSide(color: p.primary, width: 1.4),
                      foregroundColor: p.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.dialpad_rounded, size: 16),
                    label: const Text(
                      'Quantité',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
          ],

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
                if (store.tvaEnabled && store.tvaRatePercent > 0)
                  _totalRow(
                    'Dont TVA ${store.tvaRatePercent.toStringAsFixed(0)} %',
                    '${((order?.grossTotal ?? 0) <= 0 ? 0 : ((order!.grossTotal * store.tvaRatePercent) / (100.0 + store.tvaRatePercent)).round())} MRU',
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

          // Action row: Cuisine | Addition | Diviser | Retour/Offert
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('send_kitchen_btn'),
                  onPressed: hasUnsent ? _sendToKitchen : null,
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 9, horizontal: 4)),
                  child: Text(i18n.t('send_kitchen'),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11)),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: OutlinedButton(
                  key: const Key('print_addition_btn'),
                  onPressed: items.isNotEmpty ? _printAddition : null,
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 9, horizontal: 4)),
                  child: const Text('🧾 Note',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11)),
                ),
              ),
              const SizedBox(width: 5),
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
                      padding: const EdgeInsets.symmetric(
                          vertical: 9, horizontal: 4)),
                  child: Text(i18n.t('split_bill'),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11)),
                ),
              ),
              const SizedBox(width: 5),
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
                      padding: const EdgeInsets.symmetric(
                          vertical: 9, horizontal: 4)),
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

          // Primary Checkout Button (or Close 0 MRU Comp Ticket)
          if (items.isNotEmpty && (order?.netTotal ?? 0) <= 0.01)
            ElevatedButton.icon(
              key: const Key('close_comp_ticket_btn'),
              onPressed: store.canCurrent(PosPermission.checkout)
                  ? () {
                      final closed = store.completeCheckout(const []);
                      if (closed != null && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '🎁 Ticket ${closed.ticketNumber} clôturé (OFFERT · 0 MRU)',
                            ),
                          ),
                        );
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: p.success,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.card_giftcard_rounded),
              label: const Text(
                'CLÔTURER OFFERT · 0 MRU',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900),
              ),
            )
          else
            ElevatedButton.icon(
              key: const Key('open_checkout_btn'),
              onPressed: canPay ? _openCheckout : null,
              icon: const Icon(Icons.point_of_sale_rounded),
              label: Text(
                '${i18n.t('checkout').toUpperCase()} · ${(order?.netTotal ?? 0).toStringAsFixed(0)} ${i18n.t('mru')}',
                style:
                    const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900),
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
